using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Katalogy;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline;

/// <summary>Stav modulu po běhu: klíč, zda byl výstup z paměti (klíč beze změny) a čas výpočtu.</summary>
public sealed record StavModulu(string Id, string Nazev, string Klic, bool ZPameti, double Ms);

/// <summary>Výsledek běhu pipeline: stavy modulů v topologickém pořadí a jejich výstupy.</summary>
public sealed class VysledekBehu
{
    private readonly IReadOnlyDictionary<string, object> _vystupy;
    public IReadOnlyList<StavModulu> Moduly { get; }
    public ManifestKatalogu Manifest { get; }
    internal VysledekBehu(IReadOnlyList<StavModulu> s, IReadOnlyDictionary<string, object> v, ManifestKatalogu m) { Moduly = s; _vystupy = v; Manifest = m; }
    public T Vystup<T>(string id) => (T)_vystupy[id];
    public IReadOnlyDictionary<string, string> Klice => Moduly.ToDictionary(m => m.Id, m => m.Klic);
    public IReadOnlyList<string> Prepocitane => Moduly.Where(m => !m.ZPameti).Select(m => m.Id).ToList();
    /// <summary>Hotový svět ve tvaru dnešního KonfiguraceSveta.Sestav.</summary>
    public SvetKrok06 Svet => Vystup<VystupPlanety>(M7VystupPlanety.Id_).Svet;
}

/// <summary>
/// G-1: pipeline modulů M0–M7. Spočte klíče v topologickém pořadí, modul se stejným klíčem jako v minulém běhu
/// vezme výstup z paměti, ostatní přepočítá. Výstupy modulů jsou sdílené – volající je nemá měnit.
/// </summary>
public sealed class PipelineSveta
{
    private readonly Dictionary<string, (string klic, object vystup)> _pamet = new(StringComparer.Ordinal);
    public DataSveta Data { get; }
    public GrafModulu Graf { get; }
    /// <summary>Parametry M4–M6 (null = načíst z data/v1 při každém běhu).</summary>
    public NastaveniModulu? Nastaveni { get; set; }

    public PipelineSveta(DataSveta d, GrafModulu? graf = null) { Data = d; Graf = graf ?? ModulySveta.Graf(); }

    /// <summary>Kontext s efektivními parametry: kopie p + more_v1.json (jako KonfiguraceSveta.Sestav). Vstup p se nemění.</summary>
    private KontextBehu Kontext(ParametrySveta p, string? kes, int vlaken, Func<string, object> vystup, ManifestKatalogu? man = null) =>
        new(Data, man ?? ManifestKatalogu.Spocti(Data), ErozePlanety.NactiMore(p.Kopie(), Data), Nastaveni ?? NastaveniModulu.ZDat(Data), kes, vlaken, vystup);

    /// <summary>Jen klíče modulů (bez výpočtu).</summary>
    public IReadOnlyDictionary<string, string> Klice(ParametrySveta p) => Klice(Kontext(p, null, 1, _ => throw new InvalidOperationException("klíč nesmí číst výstup")));

    private Dictionary<string, string> Klice(KontextBehu k)
    {
        var kl = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var m in Graf.Poradi) kl[m.Id] = KlicModulu.Spocti(m, m.Parametry(k), k.Manifest, kl);
        return kl;
    }

    public VysledekBehu Spust(ParametrySveta p, string? kes = null, int vlaken = 8)
    {
        var vys = new Dictionary<string, object>(StringComparer.Ordinal);
        var k = Kontext(p, kes, vlaken, id => vys[id]);
        var kl = Klice(k);
        var stavy = new List<StavModulu>();
        foreach (var m in Graf.Poradi)
        {
            string klic = kl[m.Id];
            if (_pamet.TryGetValue(m.Id, out var c) && c.klic == klic) { vys[m.Id] = c.vystup; stavy.Add(new(m.Id, m.Nazev, klic, true, 0)); continue; }
            var sw = Stopwatch.StartNew();
            var o = m.Spust(k);
            sw.Stop();
            vys[m.Id] = o; _pamet[m.Id] = (klic, o);
            stavy.Add(new(m.Id, m.Nazev, klic, false, sw.Elapsed.TotalMilliseconds));
        }
        return new VysledekBehu(stavy, vys, k.Manifest);
    }

    /// <summary>Zahodí výstupy v paměti (další běh přepočítá vše).</summary>
    public void Vycisti() => _pamet.Clear();
}
