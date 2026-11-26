using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Krok 7: klima a biomy (zeměpis, Turc, biomy, srážkový stín, dnešní voda nad mapou eroze, přepínač, klíče).</summary>
public static class TestyKrok07
{
    public static void Spust(KatalogMaterialu kat)
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var pk = ParametryKlimatu.ZJson(File.ReadAllText(data.KlimaV1));
        var mir = pk.Planeta("mirne");

        T.Sekce("krok 7: parametry klimatu (klima_v1.json)");
        T.Je(new[] { "mirne", "poust", "step", "tundra", "ledovec" }.All(pk.Planety.ContainsKey), "planety pro všechny presety kroku 2");
        T.Je(pk.Planeta("neznamy") == mir, "neznámé klima → mirne");
        T.Je(pk.Kanonicky("mirne") != pk.Kanonicky("poust") && pk.Kanonicky("mirne") != (pk with { OrografieZesileni = 1 }).Kanonicky("mirne"), "kanonický zápis rozliší planetu i parametr");

        T.Sekce("krok 7: zeměpisná šířka a teplota na torusu");
        var z = new Zemepis(pk, mir, 15616);
        T.Blizko(z.SirkaDeg(pk.StartYM), pk.StartSirkaDeg, 1e-9, "start na StartSirkaDeg");
        double mn = 1e9, mx = -1e9, skok = 0;
        for (double y = 0; y < 15616; y += 8) { double s = z.SirkaDeg(y); mn = Math.Min(mn, s); mx = Math.Max(mx, s); skok = Math.Max(skok, Math.Abs(s - z.SirkaDeg(y + 8))); }
        T.Je(mn < 0.1 && mx > 89.9 && skok < 0.1 && Math.Abs(z.SirkaDeg(10) - z.SirkaDeg(10 + 15616)) < 1e-9, $"šířka 0–90°, spojitá, periodická ({mn:F2}…{mx:F2}, skok {skok:F3}°)");
        T.Blizko(z.TPasmo(0), mir.TRovnikC, 1e-9, "rovník = TRovnikC"); T.Blizko(z.TPasmo(90), mir.TPolC, 1e-9, "pól = TPolC");
        T.Blizko(z.Teplota(45, 80) - z.Teplota(45, 60), -20 * pk.VyskovyGradientCNaM, 1e-9, "výškový gradient nad hladinou moře");
        T.Je(z.SrazkyPasmo(pk.SubtropyDeg) < z.SrazkyPasmo(0) && z.SrazkyPasmo(pk.SubtropyDeg) < z.SrazkyPasmo(pk.MirneDeg), "subtropy sušší než rovník a mírné pásmo");
        T.Je(z.PodilZapadu(45) == 1 && z.PodilZapadu(10) == 0 && z.PodilZapadu(80) == 0 && z.PodilZapadu(30) > 0 && z.PodilZapadu(30) < 1, "větrné pásy s plynulým přechodem");

        T.Sekce("krok 7: odtok podle Turca a biomy");
        T.Je(Odtok.OdtokMm(0, 10) == 0 && Odtok.OdtokMm(2000, 10) > Odtok.OdtokMm(1000, 10) && Odtok.OdtokMm(1000, 25) < Odtok.OdtokMm(1000, 5), "odtok roste se srážkami a klesá s teplotou");
        T.Je(Odtok.OdtokMm(150, 25) < 1, "horká suchá oblast ~ bez odtoku");
        BiomKlimatu B(double t, double p, bool m = false) => KlasifikaceBiomu.Urci(t, p, m, pk);
        T.Je(B(10, 800, true) == BiomKlimatu.More && B(-12, 300) == BiomKlimatu.Led && B(-3, 300) == BiomKlimatu.Tundra && B(3, 600) == BiomKlimatu.Tajga, "moře, led, tundra, tajga");
        T.Je(B(25, 100) == BiomKlimatu.Poust && B(25, 500) == BiomKlimatu.Step && B(25, 1000) == BiomKlimatu.Savana && B(25, 2500) == BiomKlimatu.TropickyDestnyLes, "poušť / step / savana / tropický les podle Köppenovy meze");
        T.Je(B(12, 900) == BiomKlimatu.MirnyLes && B(12, 2500) == BiomKlimatu.MirnyDestnyLes && B(3, 50) == BiomKlimatu.Poust, "mírný les, deštný les, studená poušť");

        T.Sekce("krok 7: srážkový stín (syntetický řádek)");
        int nx = 400; var hs = new double[nx]; var more = new bool[nx];
        for (int i = 0; i < nx; i++) { more[i] = i < 60; hs[i] = 60 + (i >= 150 && i < 200 ? (i - 150) * 0.8 : i >= 200 && i < 250 ? (250 - i) * 0.8 : 0); }
        var r = new double[nx]; Srazky.Radek(hs, more, 1, 32, pk, r);
        double navetri = r[180], zavetri = r[280], pred = r[120];
        T.Je(navetri > pred && zavetri < pred, $"návětří {navetri:F2} > rovina před hřbetem {pred:F2} > závětří {zavetri:F2}");
        var rr = new double[nx]; var hsM = hs.Reverse().ToArray(); var moreM = more.Reverse().ToArray(); Srazky.Radek(hsM, moreM, -1, 32, pk, rr);
        double sym = 0; for (int i = 0; i < nx; i++) sym = Math.Max(sym, Math.Abs(r[i] - rr[nx - 1 - i]));
        T.Je(sym < 1e-6, $"zrcadlo: vítr od východu = zrcadlený vítr od západu ({sym:G2})");

        T.Sekce("krok 7: klima a dnešní voda nad malou mapou eroze (eroze beze změny)");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 8192, PlanetaYM = 4096, KrokuCasu = 3 };
        var ps = new ParametrySveta { More = true, VseKrok06 = false, StartBlok = new[] { 20, 12 } };
        var sv = ErozePlanety.SvetPlanety(ps, data, pe);
        var m = VypocetEroze.Spocti(ErozePlanety.Podklad(sv, pe), pe, 4, out _);
        string otiskMapy = SouborMapy.Otisk(m);
        var a1 = HydrologieKlimatu.Akumulace(m, _ => 1.0); double maxRel = 0;
        for (int k = 0; k < m.T.N; k++) maxRel = Math.Max(maxRel, Math.Abs(a1[k] - m.A[k]) / Math.Max(1, m.A[k]));
        T.Je(maxRel < 1e-5, $"akumulace s w = 1 = plocha povodí mapy (max rel. {maxRel:E1})");
        var mk8 = MapaKlimatu.Spocti(m, pk, mir, 8); var mk1 = MapaKlimatu.Spocti(m, pk, mir, 1);
        T.Je(mk8.Otisk() == mk1.Otisk(), "klima nezávisí na počtu vláken");
        T.Je(SouborMapy.Otisk(m) == otiskMapy, "výpočet klimatu mapu eroze nemění");
        int bad = 0; for (int k = 0; k < m.T.N; k++) if (((m.Priznaky[k] & MapaEroze.Odtok) != 0) != (mk8.Biom[k] == BiomKlimatu.More)) bad++;
        T.Je(bad == 0, "biom moře právě v moři (odtok)");
        var hk = HydrologieKlimatu.Spocti(m, mk8, pe);
        int kor = 0; for (int k = 0; k < m.T.N; k++) if ((m.Priznaky[k] & MapaEroze.Koryto) != 0 && (m.Priznaky[k] & MapaEroze.Odtok) == 0) kor++;
        T.Je(hk.Pocet(HydrologieKlimatu.Aktivni) + hk.Pocet(HydrologieKlimatu.Suche) == kor, "každé koryto z eroze je aktivní nebo suché");
        var suchy = new MapaKlimatu[] { mk8 }[0]; Array.Fill(suchy.W, 0f);
        var hs0 = HydrologieKlimatu.Spocti(m, suchy, pe);
        T.Je(hs0.Pocet(HydrologieKlimatu.Aktivni) == 0 && hs0.Pocet(HydrologieKlimatu.Suche) == kor && hs0.Vodnici(m, sv, pe).Count == 0, "bez odtoku: všechna koryta suchá, žádní vodníci (eroze zůstává)");
        Array.Fill(suchy.W, 1f);
        var hs1 = HydrologieKlimatu.Spocti(m, suchy, pe);
        var v6 = Vodnici.Najdi(m, sv, pe); var v7 = hs1.Vodnici(m, sv, pe);
        T.Je(hs1.Pocet(HydrologieKlimatu.Suche) == 0 && hs1.Pocet(HydrologieKlimatu.BezKoryta) == 0, $"w = 1: všechna koryta aktivní jako v kroku 6, žádný tok mimo koryto ({hs1.Pocet(HydrologieKlimatu.Suche)}/{hs1.Pocet(HydrologieKlimatu.BezKoryta)})");
        T.Je(v7.Select(v => v.Uzel).SequenceEqual(v6.Where(v => (m.Priznaky[v.Uzel] & MapaEroze.Odtok) == 0).Select(v => v.Uzel)), $"w = 1: vodníci ve stejných uzlech jako v kroku 6 na pevnině ({v7.Count} vs {v6.Count})");

        T.Sekce("krok 7: přepínač a klíče");
        T.Je(!new ParametrySveta().KlimaKrok07 && !ParametrySveta.Krok5().KlimaKrok07 && !KonfiguraceSveta.VseZapnuto(data).KlimaKrok07, "klima výchozí vypnuto (do Janova ano)");
        var psK = new ParametrySveta { More = true, VseKrok06 = false, StartBlok = new[] { 20, 12 }, KlimaKrok07 = true };
        var svK = ErozePlanety.SvetPlanety(psK, data, pe);
        T.Je(ErozePlanety.Klic(svK, data, pe) == ErozePlanety.Klic(sv, data, pe), "klíč keše eroze nezávisí na klimatu (eroze = pozůstatek)");
        string k1 = MapaKlimatu.KlicKlimatu(m.KlicKese, pk, "mirne");
        T.Je(k1 != MapaKlimatu.KlicKlimatu(m.KlicKese, pk, "poust") && k1 != MapaKlimatu.KlicKlimatu(m.KlicKese, pk with { KontinentalitaM = 1000 }, "mirne") && k1 != MapaKlimatu.KlicKlimatu("x", pk, "mirne"), "klíč klimatu: planeta, parametry i mapa eroze");

        T.Sekce("krok 7: prameny ze seedu podle klimatu (háček)");
        var pv = new ParametryVody();
        List<Pramen> Pr(Func<double, double, double>? w) { var f = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv); f.Prameny.KlimaW = w; return f.Prameny.VOblasti(0, 0, 256, 256); }
        var p0 = Pr(null); var p1 = Pr((x, y) => 1.0); var pz = Pr((x, y) => 0.0); var p2 = Pr((x, y) => 1.5);
        T.Je(p0.SequenceEqual(p1), $"w = 1 → stejné prameny jako bez klimatu ({p0.Count})");
        T.Je(pz.Count == 0, "w = 0 → žádné prameny ze seedu");
        T.Je(p2.Count >= p0.Count && p2.Where(s => p0.Any(o => o.BunkaX == s.BunkaX && o.BunkaY == s.BunkaY)).All(s => s.Jmenovity > 0), $"w = 1,5 → víc nebo stejně pramenů ({p2.Count} ≥ {p0.Count})");
    }
}
