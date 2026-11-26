using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Nastroje;

/// <summary>Krok 4 nad C# geologií: blok 128 m (mřížka 2 m, profily), otisk OtiskVody a čas.</summary>
public static class VodaBlok
{
    public static PodzemniVodaFn Fn(bool opravy, DataSveta d, Func<ParametryVody, ParametryVody>? uprav = null, Action<GeologieCs>? geo = null)
    {
        var ps = opravy ? new ParametrySveta() : ParametrySveta.Puvodni();
        var pv = ParametryVody.ZJson(File.ReadAllText(d.VodaV1)) with { SopkaNepropustna = opravy };
        if (uprav is not null) pv = uprav(pv);
        var g = new GeologieCs(ps, d); geo?.Invoke(g);
        return new PodzemniVodaFn(g, KatalogMaterialu.ZeSouboru(d.KatalogMaterialu), pv);
    }

    public static (string otisk, int pramenu, double msInit, double msBlok) Spust(bool opravy, DataSveta d, int bx = 14, int by = 14, Action<PodzemniVodaFn>? uprav = null, Action<GeologieCs>? geo = null)
    {
        var sw = Stopwatch.StartNew();
        var fn = Fn(opravy, d, geo: geo);
        uprav?.Invoke(fn);
        double init = sw.Elapsed.TotalMilliseconds; sw.Restart();
        var bl = fn.Blok(bx, by, 2.0, true);
        double ms = sw.Elapsed.TotalMilliseconds;
        return (OtiskVody.Blok(bl), bl.Prameny.Count, init, ms);
    }
}
