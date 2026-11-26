using Willage.Gen.Data;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Gen.Testy;

/// <summary>T-2: stav okna Editor materiálů a konfigurátor receptury generovaný ze schématu operací (bez Godotu).</summary>
public static class TestyT2
{
    static string S<X>(IEnumerable<X> x) => string.Join(",", x);

    public static void Spust()
    {
        T.Sekce("T-2: stav editoru materiálů, konfigurátor receptury ze schématu");
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        using var api = new MaterialyApi(data.Koren);
        var st = new StavEditoru(api.Katalog, api.Schema);
        int zmen = 0; st.Zmeneno += _ => zmen++;

        T.Je(RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(RecepturyVpmg.Vychozi(52)) && st.Seed == 49, "výchozí stav: materiál 52, receptura VpmgPreview, seed 49");
        var kp = PopisKonfiguratoruReceptury.Kroky(st.Receptura, api.Schema);
        T.Je(kp.Count == 2 && kp[0].Editory.Count == 1 && kp[0].Editory[0].Nazev == "layer" && kp[0].Editory[0].Hodnota == "albedo" && kp[1].Editory.Count == 0,
            "konfigurátor ze schématu: base_fill 1 editor (layer = albedo), hash_grain 0");
        var pp = PopisKonfiguratoruReceptury.Profil(st.ProfilNahledu, api.Schema);
        T.Je(pp.Count == 5 && pp[1].Druh == DruhParametruVpmg.Barva && pp[1].Hodnota == "#d8ba36" && pp[2].Druh == DruhParametruVpmg.Cele && pp[2].Max == 1000, "editory profilu: 5 (barva, celá ‰ s rozsahem)");
        var nab = PopisKonfiguratoruReceptury.Nabidka(api.Schema);
        T.Je(nab.Count(n => !n.Zamcena) == 2 && nab.Count(n => n.Zamcena) == 7, "nabídka přidat krok: 2 spustitelné + 7 zástupných zamčených");
        T.Je(S(PopisKonfiguratoruReceptury.CtenyProfil(st.Receptura, api.Schema).OrderBy(x => x)) == "baseColor,grainScalePermille", "čtené parametry profilu: baseColor, grainScalePermille");

        T.Je(st.PridejKrok("roots") != null && st.PridejKrok("perlin") != null && st.Receptura.Kroky.Count == 2 && zmen == 0, "zástupná / neznámá operace odmítnuta, stav beze změny");
        T.Je(st.PridejKrok("hash_grain") == null && st.Receptura.Kroky[2].Id == "s3" && zmen == 1, "přidán krok hash_grain s id s3");
        T.Je(st.PosunKrok(2, -1) == null && st.Receptura.Kroky[1].Id == "s3" && st.PosunKrok(0, -1) != null, "posun kroku (mimo rozsah odmítnut)");
        T.Je(st.OdeberKrok(1) == null && S(st.Receptura.Kroky.Select(k => k.Id)) == "s1,s2", "odebrání kroku");
        T.Je(st.NastavParametrKroku(0, "layer", "albedo2") == null && st.Receptura.Kroky[0].Params["layer"] == "albedo2" && st.NastavParametrKroku(1, "x", "1") != null, "parametr kroku ze schématu; neznámý odmítnut");
        st.NastavParametrKroku(0, "layer", "albedo");
        T.Je(st.NastavNavrh("baseColor", "zelena") != null && st.NastavNavrh("grainScalePermille", "1200") != null && st.NastavNavrh("grainScalePermille", "x") != null && st.Navrh.Prazdny,
            "návrh: špatná barva / mimo rozsah / nečíslo odmítnuto");
        T.Je(st.NastavNavrh("grainScalePermille", "0") == null && st.Navrh.GrainScalePermille == 0 && st.ProfilNahledu.GrainScalePermille == 0 && st.ProfilKatalogu.GrainScalePermille == 500, "návrh grain 0 (katalog 500 beze změny)");
        T.Je(st.NastavNavrh("grainScalePermille", "500") == null && st.Navrh.Prazdny, "návrh = hodnota katalogu → návrh zrušen");
        T.Je(st.NastavNavrh("baseColor", "#A0B0C0") == null && st.Navrh.BaseColor == "#a0b0c0", "návrh barvy (malá písmena)");
        T.Je(st.VyberMaterial(1) == null && st.Navrh.Prazdny && st.Receptura.MaterialId == 1 && st.Receptura.Kroky.Count == 2 && st.VyberMaterial(200) != null, "výběr materiálu: návrh zrušen, receptura přenesena; neznámý odmítnut");
        T.Je(st.VyberProfil("mokry") != null && st.NastavRozliseni(4) != null && st.NastavRozliseni(128) == null && st.Receptura.Resolution == 128, "profil mimo katalog / rozlišení mimo rozsah odmítnuto");
        T.Je(S(st.SeedyVariaci()) == S(st.SeedyVariaci()) && st.SeedyVariaci().Distinct().Count() == 4 && !st.SeedyVariaci().Contains(st.Seed), "4 seedy variací, deterministické, jiné než seed");
        T.Je(st.Validace().Count == 0, "validace receptury v okně OK");
        long v = st.Verze; st.NastavSeed(st.Seed); T.Je(st.Verze == v, "stejný seed = žádná změna");

        // vzorek 5 materiálů (Jan 21:44)
        var vz = api.Vzorek;
        T.Je(S(vz.Materialy.Select(m => m.Id)) == "1,2,3,5,6" && vz.Materialy.Select(m => api.Katalog.Material(m.Id)!.Skupina).Distinct().Count() == 5,
            "vzorek: 1 tráva, 2 ornice, 3 štěrk/písek, 5 vápenec, 6 žula – 5 různých skupin");
        var sv = new StavEditoru(api.Katalog, api.Schema, vz);
        T.Je(sv.Material == 1 && sv.Receptura.MaterialId == 1, "stav se vzorkem: výchozí materiál 1 (tráva)");
        var mimo = sv.VyberMaterial(52);
        T.Je(mimo != null && mimo.StartsWith("zástupné") && sv.Material == 1 && sv.VyberMaterial(6) == null && sv.Material == 6, "materiál mimo vzorek odmítnut jako zástupný; 6 žula ve vzorku jde: " + mimo);

        // s nástrojem: stav → VPMG
        if (!api.Zdroj.Dostupny) { T.Je(false, "nástroj VPMG chybí: " + api.Zdroj.Popis); return; }
        var s2 = new StavEditoru(api.Katalog, api.Schema); s2.NastavSeed(0xC0FFEE00u);
        T.Je(api.Zdroj.Spust(s2.Receptura, s2.Seed, s2.Navrh).Checksum == 1756279408u, "stav okna (52, 0xC0FFEE00, 64) → golden 1756279408");
        s2.PrepniKrok(1, false);
        uint bezZrna = api.Zdroj.Spust(s2.Receptura, s2.Seed, s2.Navrh).Checksum;
        s2.PrepniKrok(1, true); s2.NastavNavrh("grainScalePermille", "0");
        T.Je(api.Zdroj.Spust(s2.Receptura, s2.Seed, s2.Navrh).Checksum == bezZrna, "vypnutý hash_grain = návrh grain 0 (stejné bajty)");
        var var4 = s2.SeedyVariaci().Select(x => api.Zdroj.Spust(s2.Receptura with { }, x).Checksum).ToList();
        T.Je(var4.Distinct().Count() == 4, "4 variace seedu = 4 různé checksumy");
        var vzt = vz.Materialy.Select(m => api.Zdroj.Spust(RecepturyVpmg.Vychozi(m.Id), 49)).ToList();
        T.Je(vzt.All(t => t.Ok) && vzt.Select(t => t.Checksum).Distinct().Count() == 5, "5 materiálů vzorku → 5 textur, 5 různých checksumů: " + S(vzt.Select(t => t.Checksum)));
    }
}
