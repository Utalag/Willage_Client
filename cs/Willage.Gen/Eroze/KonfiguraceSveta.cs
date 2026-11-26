using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Eroze;

/// <summary>
/// Krok 6c: konfigurace „vše zapnuto“ jedním přepínačem ParametrySveta.VseKrok06 (moře + sklon + pánve ve funkci světa,
/// eroze z mapy planety a vodníci v pramenech). Výchozí vypnuto (do Janova ano). Bez přepínače vrací svět kroku 5 beze změny.
/// </summary>
public sealed class SvetKrok06
{
    public GeologieCs Geologie { get; init; } = null!;
    public MapaEroze? Mapa { get; init; }
    public ErozeSvetaFn? Eroze { get; init; }
    public List<Vodnik> Vodnici { get; init; } = new();

    /// <summary>Podzemní voda nad tímto světem; s VseKrok06 i s vodníky.</summary>
    public PodzemniVodaFn Voda(KatalogMaterialu kat, ParametryVody pv)
    {
        var fn = new PodzemniVodaFn(Geologie, kat, pv);
        if (Mapa is not null) fn.Prameny.Vodnici = new VodniciVeSvete(Vodnici, fn.Geologie).VOblasti;
        return fn;
    }
}

public static class KonfiguraceSveta
{
    /// <summary>Parametry „vše zapnuto“ (ladicí hodnoty z more_v1.json).</summary>
    public static ParametrySveta VseZapnuto(DataSveta d, long seed = 49) =>
        ErozePlanety.NactiMore(new ParametrySveta { Seed = seed, VseKrok06 = true }, d);

    public static SvetKrok06 Sestav(ParametrySveta p, DataSveta d, string? kes = null, int vlaken = 8)
    {
        ErozePlanety.NactiMore(p, d);
        var g = new GeologieCs(p, d);
        if (!p.VseKrok06) return new SvetKrok06 { Geologie = g };
        var pe = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1));
        // svět planety: stejné přepínače a seed, větší svet_max_m (start svět se tím nemění – ověřeno v kroku 6)
        var pp = ErozePlanety.NactiMore(new ParametrySveta { Seed = p.Seed, VseKrok06 = true, StartBlok = p.StartBlok }, d);
        var sp = ErozePlanety.SvetPlanety(pp, d, pe);
        var m = ErozePlanety.Mapa(sp, d, pe, kes, vlaken);
        var ef = new ErozeSvetaFn(m, pe);
        g.Svet.Eroze = ef;
        return new SvetKrok06 { Geologie = g, Mapa = m, Eroze = ef, Vodnici = Vodnici.Najdi(m, sp, pe) };
    }
}
