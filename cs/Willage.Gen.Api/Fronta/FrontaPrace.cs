using System.Collections.Concurrent;

namespace Willage.Gen.Api.Fronta;

/// <summary>Výsledek úlohy doručený dispečerem: hotovo, chyba, nebo zrušeno.</summary>
public enum KonecUlohy { Hotovo, Chyba, Zruseno }

/// <summary>
/// G-4: jedna fronta práce nad fasádou – jedno vlákno na pozadí, úlohy přísně po sobě (fasáda není vláknově bezpečná),
/// zrušení přes CancellationToken. Výsledek, chybu i průběh doručí <c>dispecer</c> (v Godotu CallDeferred na hlavní vlákno,
/// v testech přímo nebo do vlastní fronty). Bez Godotu, proto testovatelné v Willage.Gen.Testy.
/// </summary>
public sealed class FrontaPrace : IDisposable
{
    sealed record Uloha(long Id, string Nazev, Func<CancellationToken, object?> Prace, Action<long, KonecUlohy, object?, Exception?>? Konec, CancellationTokenSource Zruseni);

    readonly BlockingCollection<Uloha> _fronta = new();
    readonly Action<Action> _dispecer;
    readonly Thread _vlakno;
    long _dalsi;
    volatile Uloha? _bezi;
    int _cekajicich;

    /// <param name="dispecer">Jak doručit zpětné volání (např. a => Callable.From(a).CallDeferred()).</param>
    public FrontaPrace(Action<Action> dispecer, string nazevVlakna = "WillageJadro")
    {
        _dispecer = dispecer;
        _vlakno = new Thread(Smycka) { IsBackground = true, Name = nazevVlakna };
        _vlakno.Start();
    }

    /// <summary>Počet úloh ve frontě + běžící.</summary>
    public int Cekajicich => Volatile.Read(ref _cekajicich);
    public string? Bezi => _bezi?.Nazev;
    public int IdVlakna => _vlakno.ManagedThreadId;

    /// <summary>Zařadí úlohu; vrátí id (okamžitě, nic nepočítá). <paramref name="konec"/> přijde přes dispečer.</summary>
    public long Zarad(string nazev, Func<CancellationToken, object?> prace, Action<long, KonecUlohy, object?, Exception?>? konec = null)
    {
        var u = new Uloha(Interlocked.Increment(ref _dalsi), nazev, prace, konec, new CancellationTokenSource());
        Interlocked.Increment(ref _cekajicich);
        _fronta.Add(u);
        return u.Id;
    }

    /// <summary>Zruší běžící úlohu a všechny čekající (doručí se jako Zruseno).</summary>
    public void ZrusVse()
    {
        _bezi?.Zruseni.Cancel();
        foreach (var u in _fronta.ToArray()) u.Zruseni.Cancel();
    }

    /// <summary>Doručí akci přes dispečer (např. průběh z běžící úlohy).</summary>
    public void Dorucit(Action a) => _dispecer(a);

    void Smycka()
    {
        foreach (var u in _fronta.GetConsumingEnumerable())
        {
            _bezi = u;
            KonecUlohy k; object? v = null; Exception? e = null;
            try
            {
                u.Zruseni.Token.ThrowIfCancellationRequested();
                v = u.Prace(u.Zruseni.Token); k = KonecUlohy.Hotovo;
            }
            catch (OperationCanceledException) { k = KonecUlohy.Zruseno; }
            catch (Exception ex) { k = KonecUlohy.Chyba; e = ex; }
            _bezi = null;
            Interlocked.Decrement(ref _cekajicich);
            // CTS se nedisposuje: ZrusVse ho může zrušit souběžně (bez časovače nic nedrží)
            if (u.Konec is { } kon) _dispecer(() => kon(u.Id, k, v, e));
        }
    }

    public void Dispose()
    {
        ZrusVse();
        _fronta.CompleteAdding();
        _vlakno.Join(TimeSpan.FromSeconds(30));
        _fronta.Dispose();
    }
}
