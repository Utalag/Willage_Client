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
    /// <summary>Volba --prusak: zapne ParametryVody.PrusakKoeficient (otisky musí zůstat stejné).</summary>
    public static bool Prusak;

    public static PodzemniVodaFn Fn(bool opravy, DataSveta d, Func<ParametryVody, ParametryVody>? uprav = null, Action<GeologieCs>? geo = null, ParametrySveta? svet = null)
    {
        var ps = svet ?? (opravy ? new ParametrySveta() : ParametrySveta.Puvodni());
        var pv = ParametryVody.ZJson(File.ReadAllText(d.VodaV1)) with { SopkaNepropustna = opravy };
        if (Prusak) pv = pv with { PrusakKoeficient = true };
        if (uprav is not null) pv = uprav(pv);
        var g = new GeologieCs(ps, d); geo?.Invoke(g);
        return new PodzemniVodaFn(g, KatalogMaterialu.ZeSouboru(d.KatalogMaterialu), pv, pv.PrusakKoeficient ? File.ReadAllText(d.PrusakV1) : null);
    }

    public static (string otisk, int pramenu, double msInit, double msBlok) Spust(bool opravy, DataSveta d, int bx = 14, int by = 14, Action<PodzemniVodaFn>? uprav = null, Action<GeologieCs>? geo = null, ParametrySveta? svet = null, Func<ParametryVody, ParametryVody>? voda = null)
    {
        var sw = Stopwatch.StartNew();
        var fn = Fn(opravy, d, voda, geo, svet);
        uprav?.Invoke(fn);
        double init = sw.Elapsed.TotalMilliseconds; sw.Restart();
        var bl = fn.Blok(bx, by, 2.0, true);
        double ms = sw.Elapsed.TotalMilliseconds;
        return (OtiskVody.Blok(bl), bl.Prameny.Count, init, ms);
    }
}
