using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Klima;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>G-1: zmrazená kopie původního KonfiguraceSveta.Sestav (před pipeline, e2d55d2) – reference pro test „pipeline = původní“.</summary>
public static class SestavPuvodni
{
    public static SvetKrok06 Sestav(ParametrySveta p, DataSveta d, string? kes = null, int vlaken = 8)
    {
        ErozePlanety.NactiMore(p, d);
        var g = new GeologieCs(p, d);
        if (!p.VseKrok06) return new SvetKrok06 { Geologie = g };
        var pe = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1));
        var pp = ErozePlanety.NactiMore(new ParametrySveta { Seed = p.Seed, VseKrok06 = true, StartBlok = p.StartBlok }, d);
        var sp = ErozePlanety.SvetPlanety(pp, d, pe);
        var m = ErozePlanety.Mapa(sp, d, pe, kes, vlaken);
        var ef = new ErozeSvetaFn(m, pe);
        g.Svet.Eroze = ef;
        var v6 = Vodnici.Najdi(m, sp, pe);
        if (!p.KlimaKrok07) return new SvetKrok06 { Geologie = g, Mapa = m, Eroze = ef, Vodnici = v6 };
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
