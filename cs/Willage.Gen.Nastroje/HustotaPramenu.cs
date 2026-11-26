using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Nastroje;

/// <summary>Hustota pramenů ve světě 3 × 3 podle parametrů velikost čtverce (BunkaPramenuM) a pravděpodobnost (PravdepodobnostBunky).</summary>
public static class HustotaPramenu
{
    public static void Spust(DataSveta d)
    {
        var geo = new KesGeologie(new GeologieCs(new ParametrySveta(), d));
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var pv0 = ParametryVody.ZJson(File.ReadAllText(d.VodaV1));
        Console.WriteLine("ctverec_m;pravdepodobnost;pramenu_3x3;na_km2;druhy;ms");
        foreach (var (b, p) in new[] { (32.0, 0.6), (32.0, 1.0), (24.0, 0.6), (16.0, 0.6), (16.0, 1.0) })
        {
            var sw = Stopwatch.StartNew();
            var fn = new PodzemniVodaFn(geo, kat, pv0 with { BunkaPramenuM = b, PravdepodobnostBunky = p, RozestupM = Math.Min(pv0.RozestupM, b / 2) });
            var ps = fn.Prameny.VOblasti(14 * 128, 14 * 128, 17 * 128, 17 * 128);
            var druhy = string.Join(" ", ps.GroupBy(s => s.Druh).OrderBy(g => g.Key).Select(g => $"{g.Key}:{g.Count()}"));
            Console.WriteLine($"{b};{p};{ps.Count};{ps.Count / (0.384 * 0.384):F0};{druhy};{sw.Elapsed.TotalMilliseconds:F0}");
        }
    }
}
