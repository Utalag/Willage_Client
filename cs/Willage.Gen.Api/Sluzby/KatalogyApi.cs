using Willage.Gen.Api.Dto;
using Willage.Gen.Katalogy;

namespace Willage.Gen.Api.Sluzby;

/// <summary>IKatalogy nad manifestem G-1 a grafem modulů.</summary>
public sealed class KatalogyApi : IKatalogy
{
    readonly StavGeneratoru _s;
    public KatalogyApi(StavGeneratoru s) => _s = s;

    public ManifestDto Manifest()
    {
        var m = _s.Manifest();
        return new ManifestDto(m.Souhrn, m.Polozky.Select(x => new PolozkaKataloguDto(x.Cesta, x.Velikost, x.Sha256,
            _s.Pipeline.Graf.Poradi.Where(mo => mo.Soubory.Contains(x.Cesta)).Select(mo => mo.Id).ToList())).ToList());
    }

    /// <summary>Moduly, které soubor čtou, a všechny závislé (soubor, který nečte nikdo, mění jen klíč M7 a dál).</summary>
    public IReadOnlyList<string> DotceneModuly(string cesta)
    {
        var g = _s.Pipeline.Graf;
        var ctou = g.Poradi.Where(m => m.Soubory.Contains(cesta)).Select(m => m.Id).ToList();
        if (ctou.Count == 0) ctou.Add(Pipeline.Moduly.M7VystupPlanety.Id_);
        var s = new SortedSet<string>(StringComparer.Ordinal);
        foreach (var c in ctou) { s.Add(c); foreach (var z in g.Zavisle(c)) s.Add(z); }
        return g.Poradi.Select(m => m.Id).Where(s.Contains).ToList();
    }

    public KontrolaKataloguDto Kontrola()
    {
        var m = _s.Manifest();
        string f = Path.Combine(_s.Data.Koren, ManifestKatalogu.NazevSouboru);
        var r = File.Exists(f) ? ManifestKatalogu.ZJson(File.ReadAllText(f)).Rozdily(m) : new[] { ManifestKatalogu.NazevSouboru };
        var dot = r.SelectMany(DotceneModuly).Distinct().OrderBy(x => x, StringComparer.Ordinal).ToList();
        return new KontrolaKataloguDto(r.Count == 0, r, dot);
    }

    public ZastupnyVysledekDto NavrhVerze() => new(true, "zástupné: návrh verze katalogu (diff, verze schématu) přijde s oknem 2");
}
