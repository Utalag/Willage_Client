using System.Collections.Concurrent;
using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda.Prusak;

/// <summary>
/// Šířka pobřežního pásu mořské hladiny do vnitrozemí z materiálů u břehu (<see cref="PrusakDosah"/> za horizont
/// <see cref="ParametryVody.PobrezHorizontDni"/>). Voda proniká nejpropustnější vrstvou ve sloupci do hloubky
/// <see cref="ParametryVody.PobrezOknoM"/> pod povrchem; vrstva se předpokládá pokračující do vnitrozemí.
/// Tlak: spád i (v promile) závisí na rozdílu hladin; větší rozdíl = rychlejší čelo = širší pás (celočíselně).
/// </summary>
public sealed class PobrezniPas
{
    private readonly KatalogMaterialu _kat;
    private readonly PrusakKoeficient _koef;
    private readonly ParametryVody _p;
    private readonly long _horizontMs, _maxMm, _tlakDelkaMm;
    private readonly int _spadMinPm, _spadMaxPm, _spadStalyPm;
    private readonly int _okno;
    private readonly ConcurrentDictionary<(int id, int spadPm), long> _mm = new();
    public double MaxM { get; }
    public double HorizontDni { get; }

    public PobrezniPas(KatalogMaterialu kat, PrusakKoeficient koef, ParametryVody p)
    {
        _kat = kat; _koef = koef; _p = p;
        MaxM = p.PobrezMaxM; HorizontDni = p.PobrezHorizontDni;
        _okno = Math.Max(1, (int)Math.Ceiling(p.PobrezOknoM / GeologyGridConstants.CellM));
        _horizontMs = (long)Math.Round(p.PobrezHorizontDni * PrusakDosah.MsDen);
        _maxMm = (long)Math.Round(p.PobrezMaxM * 1000.0);
        _tlakDelkaMm = Math.Max(1, (long)Math.Round(p.PobrezTlakDelkaM * 1000.0));
        _spadMinPm = Math.Max(1, (int)Math.Round(p.PobrezSpadMin * 1000.0));
        _spadMaxPm = Math.Max(_spadMinPm, (int)Math.Round(p.PobrezSpadMax * 1000.0));
        _spadStalyPm = Math.Max(1, (int)Math.Round(p.PobrezSpad * 1000.0));
    }

    /// <summary>Spád v promile pro rozdíl hladin dhMm (mm): s tlakem |dh| / délka v mezích, bez tlaku stálý.</summary>
    public int SpadPm(long dhMm)
    {
        if (!_p.PrusakTlak) return _spadStalyPm;
        long pm = Math.Abs(dhMm) * 1000 / _tlakDelkaMm;
        return (int)Math.Clamp(pm, _spadMinPm, _spadMaxPm);
    }

    private long Mm(int id, int spadPm) => _mm.GetOrAdd((id, spadPm), k =>
    {
        var m = _kat.Najdi(k.id);
        if (m is null) { _kat.NeznamaId.Remove(k.id); return 0; }
        double n = m.Porovitost > 0 ? m.Porovitost : _p.PobrezPorovitost;
        long tau0 = m.KMs is double kk ? PrusakDosah.CasCistehoBlokuMs(kk, n, k.spadPm / 1000.0) : -1;
        return PrusakDosah.DosahMm(_koef.Koef(k.id), tau0, _horizontMs, _maxMm);
    });

    /// <summary>Dosah materiálu v metrech při spádu spadPm (promile); 0 = těsný.</summary>
    public double Material(int id, int spadPm) => Mm(id, spadPm) / 1000.0;

    /// <summary>
    /// Šířka pásu (m) pro sloupec (512 buněk po 0,25 m zdola), povrch (m) a rozdíl hladin dhMm (mm):
    /// největší dosah pevných buněk v okně pod povrchem.
    /// </summary>
    public double Sirka(byte[] sloupec, double povrch, long dhMm = 0)
    {
        int spad = SpadPm(dhMm);
        int top = Math.Min(sloupec.Length - 1, (int)Math.Floor((povrch - 1e-9) / GeologyGridConstants.CellM));
        long best = 0;
        for (int k = top; k >= 0 && k > top - _okno; k--)
            if (sloupec[k] != 0) best = Math.Max(best, Mm(sloupec[k], spad));
        return best / 1000.0;
    }

    /// <summary>Materiál s největším dosahem v okně (pro statistiku a výběr řezů); 0 = žádný.</summary>
    public int Dominantni(byte[] sloupec, double povrch, long dhMm = 0)
    {
        int spad = SpadPm(dhMm);
        int top = Math.Min(sloupec.Length - 1, (int)Math.Floor((povrch - 1e-9) / GeologyGridConstants.CellM));
        long best = -1; int id = 0;
        for (int k = top; k >= 0 && k > top - _okno; k--)
            if (sloupec[k] != 0 && Mm(sloupec[k], spad) > best) { best = Mm(sloupec[k], spad); id = sloupec[k]; }
        return id;
    }
}
