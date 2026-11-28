using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;
using Willage.Gen.Testy.V8;

namespace Willage.Gen.Testy;

/// <summary>V8: rozdílová zpráva GEO2 × GEO1 po kategoriích (<c>--jen=GEO2V8</c>, volitelně <c>--blok=ox,oy[,krokXy]</c> jen jeden blok).</summary>
public static class TestyGeo2V8
{
    public static List<(string Kategorie, double X, double Y)> Kategorie(SvetFn s)
    {
        var l = new List<(string, double, double)>
        {
            ("náhodné", 1024, 512), ("náhodné", 3000, 2000), ("náhodné", 0, 0), ("náhodné", 2048, 1024), ("náhodné", 512, 3072),
            ("šev mince x = 1920", 1856, 1024), ("šev mince x = 2048", 1984, 2560),
            ("hornatina / strmé", 1664, 1728), ("hornatina / strmé", 3904, 1344),
        };
        var ss = s.Sopky.Seznam;
        if (ss.Count > 0)
        {
            var q = ss[0];
            l.Add(("svah sopky", Math.Floor(q.X + 0.4 * q.R - 64), Math.Floor(q.Y - 64)));
            l.Add(("okraj sopky", Math.Floor(q.X + q.R - 96), Math.Floor(q.Y - 64)));
        }
        return l;
    }

    public static void Spust(string data, double[]? jedenBlok, double krokXy, int vlaken, string? csv)
    {
        T.Sekce($"GEO2 V8: rozdíly GEO2 × GEO1 po kategoriích (bloky 128 m, sloupce po {krokXy} m, z po 0,25 m, {vlaken} vláken)");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        var bloky = jedenBlok is null ? Kategorie(g.Svet) : new List<(string, double, double)> { ("zadaný", jedenBlok[0], jedenBlok[1]) };
        var podle = new Dictionary<string, V8Soucty>(); var poradi = new List<string>();
        foreach (var (nazev, x, y) in bloky)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var s = V8Blok.Porovnej(g, kat, d, x, y, krokXy, vlaken);
            if (!podle.TryGetValue(nazev, out var cil)) { podle[nazev] = cil = new V8Soucty(); poradi.Add(nazev); }
            cil.Slouc(s);
            Console.WriteLine($"  blok ({x}, {y}) [{nazev}]: {s.Bunek:N0} buněk, různých {s.Ruznych:N0} ({100.0 * s.Ruznych / s.Bunek:F4} %), {sw.Elapsed.TotalSeconds:F1} s");
        }
        var vysl = poradi.Select(n => (n, podle[n])).ToList();
        V8Zprava.Vypis(vysl, kat);
        if (csv is not null) V8Zprava.Csv(csv, vysl);
        var vse = new V8Soucty(); foreach (var (_, s) in vysl) vse.Slouc(s);
        T.Je(vse.Bunek > 0 && vse.PodleVerdiktu().Values.Sum() == vse.Ruznych, "součet verdiktů = všechny různé buňky");
    }
}
