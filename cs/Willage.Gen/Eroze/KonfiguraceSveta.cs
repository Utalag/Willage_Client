using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Klima;
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
    /// <summary>Krok 7: klima (ParametrySveta.KlimaKrok07), jinak null. Vodníci jsou pak z dnešní (klimatické) sítě.</summary>
    public KlimaSvetaFn? Klima { get; init; }
    public HydrologieKlimatu? Hydrologie { get; init; }
    /// <summary>Oázy / artéské prameny v pouštích (jsou i v seznamu Vodnici).</summary>
    public List<Vodnik> Oazy { get; init; } = new();
    public ParametryKlimatu? ParametryKlimatu { get; init; }
    /// <summary>Vodníci kroku 6 (bez klimatu) – pro srovnání před/po.</summary>
    public List<Vodnik> VodniciBezKlimatu { get; init; } = new();

    /// <summary>Podzemní voda nad tímto světem; s VseKrok06 i s vodníky.</summary>
    public PodzemniVodaFn Voda(KatalogMaterialu kat, ParametryVody pv, string? prusakJson = null)
    {
        var fn = new PodzemniVodaFn(Geologie, kat, pv, prusakJson);
        if (Mapa is not null) fn.Prameny.Vodnici = new VodniciVeSvete(Vodnici, fn.Geologie).VOblasti;
        if (Klima is not null) NapojKlima(fn.Prameny);
        return fn;
    }

    /// <summary>Krok 7: prameny ze seedu podle odtoku klimatu (w omezené PramenWMax).</summary>
    public void NapojKlima(Prameny pr)
    {
        if (Klima is null || ParametryKlimatu is null) return;
        var k = Klima; double wmax = ParametryKlimatu.PramenWMax;
        pr.KlimaW = (x, y) => Math.Min(wmax, k.W(x, y));
        pr.KlimaPMax = ParametryKlimatu.PramenPravdepodobnostMax;
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
        var v6 = Vodnici.Najdi(m, sp, pe);
        if (!p.KlimaKrok07) return new SvetKrok06 { Geologie = g, Mapa = m, Eroze = ef, Vodnici = v6 };
        // krok 7: klima nad hotovou mapou; mapa eroze a její klíč se nemění (Jan 12:26)
        var pk = ParametryKlimatu.ZJson(File.ReadAllText(d.KlimaV1));
        var mk = MapaKlimatu.Spocti(m, pk, pk.Planeta(p.Klima), vlaken);
        mk.Klic = MapaKlimatu.KlicKlimatu(m.KlicKese, pk, p.Klima);
        var hk = HydrologieKlimatu.Spocti(m, mk, pe);
        var oazy = Oazy.Najdi(m, mk, pk, p.Seed); Oazy.Prekryj(mk, oazy, pk);
        var vod = hk.Vodnici(m, sp, pe); vod.AddRange(oazy);
        return new SvetKrok06 { Geologie = g, Mapa = m, Eroze = ef, Vodnici = vod, VodniciBezKlimatu = v6, Oazy = oazy,
            Klima = new KlimaSvetaFn(mk), Hydrologie = hk, ParametryKlimatu = pk };
    }
}
