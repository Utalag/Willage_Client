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
        T.Je(new[] { "mirne", "poust", "step", "tundra", "ledovec" }.All(pk.Planety.ContainsKey) && pk.Planety.Values.All(pl => ParametryKlimatu.IdPasem.All(pl.Pasma.ContainsKey)), "planety pro všechny presety kroku 2, každá s pěti pásmy");
        T.Je(pk.Planeta("neznamy") == mir, "neznámé klima → mirne");
        T.Je(pk.Kanonicky("mirne") != pk.Kanonicky("poust") && pk.Kanonicky("mirne") != (pk with { OrografieZesileni = 1 }).Kanonicky("mirne"), "kanonický zápis rozliší planetu i parametr");

        T.Sekce("krok 7b: klimatická pásma (předdefinované složení, vypínání, přechod)");
        var z = new Zemepis(pk, mir, 15616);
        T.Je(z.Pasma.Select(x => x.id).SequenceEqual(new[] { "subtropy", "mirne", "chladne" }), "mírná planeta: zapnutá pásma subtropy, mírné, chladné (tropy a polární vypnuto)");
        T.Je(z.IdSegmentu(z.Radek(pk.StartYM).Segment) == "mirne", "start 3 × 3 leží v pásmu mírné");
        double mn = 1e9, mx = -1e9, skok = 0, skokK = 0;
        for (double y = 0; y < 15616; y += 8)
        {
            var r0 = z.Radek(y); var r1 = z.Radek(y + 8); mn = Math.Min(mn, r0.TC); mx = Math.Max(mx, r0.TC);
            skok = Math.Max(skok, Math.Abs(r0.TC - r1.TC)); skokK = Math.Max(skokK, Math.Abs(r0.SrazkyMm - r1.SrazkyMm));
        }
        T.Je(skok < 0.1 && skokK < 15, $"teplota i srážky spojité i přes hrany pásem a švy periody (max skok {skok:F3} °C, {skokK:F1} mm na 8 m)");
        T.Je(Math.Abs(z.Radek(10).TC - z.Radek(10 + 15616).TC) < 1e-9, "periodické v y");
        T.Blizko(mx, mir.Pasma["subtropy"].TOdC, 0.2, "nejteplejší místo = rovníková hrana subtropů");
        T.Blizko(mn, mir.Pasma["chladne"].TDoC, 0.2, "nejchladnější místo = polární hrana chladného pásma");
        // zrcadlo: pól uprostřed periody, teplota symetrická kolem rovníku
        T.Je(Math.Abs(z.Radek(z.Y0 + 3000).TC - z.Radek(z.Y0 - 3000).TC) < 1e-9, "symetrie kolem rovníku (zrcadlo)");
        // vypnutí pásma: zbylá se poměrně roztáhnou
        var bezSub = mir with { Pasma = mir.Pasma.ToDictionary(kv => kv.Key, kv => kv.Key == "subtropy" ? kv.Value with { Zapnuto = false } : kv.Value) };
        var z2 = new Zemepis(pk, bezSub, 15616);
        T.Je(z2.Pasma.Count == 2 && Math.Abs(z.Hrana(1) - 0.5 * 0.15 / 1.0) < 1e-12 && Math.Abs(z2.Hrana(1) - 0.5 * 0.60 / 0.85) < 1e-12, $"vypnuté pásmo vypadne, zbylá se normalizují (hrana {z.Hrana(1):F3} → {z2.Hrana(1):F3})");
        T.Je(Math.Abs(z2.Hrana(2) - 0.5) < 1e-12 && Math.Abs(z2.Hrana(4) - 1.0) < 1e-12, "zbylá pásma vyplní celou půlperiodu");
        // změna šířky pásma a rozsahu teplot
        var uzke = mir with { Pasma = mir.Pasma.ToDictionary(kv => kv.Key, kv => kv.Key == "mirne" ? kv.Value with { Podil = 0.3, TOdC = 20, TDoC = 0 } : kv.Value) };
        var z3 = new Zemepis(pk, uzke, 15616);
        T.Je(z3.Hrana(2) < z.Hrana(2) && z3.Radek(z3.Y0 + 0.5 * (z3.Hrana(1) + 0.01) * 15616).TC > 10, "podíl a rozsah teplot pásma jsou laditelné");
        var bez = mir with { Pasma = new() };
        T.Je(new Zemepis(pk, bez, 15616).Pasma.Count == 1, "planeta bez zapnutého pásma → jedno záložní mírné pásmo");
        // vítr a srážky podle pásem
        T.Je(z.Radek(z.Y0 + 0.5 * 0.15 * 15616 * 0.5).PodilZapadu == 0 && z.Radek(pk.StartYM).PodilZapadu == 1, "vítr: subtropy od východu, mírné od západu");
        T.Je(Math.Abs(z.Radek(pk.StartYM).SrazkyMm - mir.SrazkyMmRok * mir.Pasma["mirne"].SrazkyK) < 1e-6, "srážky = planeta × K pásma");
        T.Je(pk.Planety.Values.All(pl => pl.Zapnuta().Count >= 1), "každá planeta má aspoň jedno zapnuté pásmo");

        T.Sekce("krok 7: výškový gradient");
        T.Blizko(z.Teplota(10, 80) - z.Teplota(10, 60), -20 * pk.VyskovyGradientCNaM, 1e-9, "výškový gradient 0,05 °C/m nad hladinou moře");

        T.Sekce("krok 7: odtok podle Turca a biomy");
        T.Je(Odtok.OdtokMm(0, 10) == 0 && Odtok.OdtokMm(2000, 10) > Odtok.OdtokMm(1000, 10) && Odtok.OdtokMm(1000, 25) < Odtok.OdtokMm(1000, 5), "odtok roste se srážkami a klesá s teplotou");
        T.Je(Odtok.OdtokMm(150, 25) < 1, "horká suchá oblast ~ bez odtoku");
        BiomKlimatu B(double t, double p, bool m = false) => KlasifikaceBiomu.Urci(t, p, m, pk);
        T.Je(B(10, 800, true) == BiomKlimatu.More && B(-12, 300) == BiomKlimatu.Led && B(-3, 300) == BiomKlimatu.Tundra && B(3, 600) == BiomKlimatu.Tajga, "moře, led, tundra, tajga");
        T.Je(B(25, 100) == BiomKlimatu.Poust && B(25, 500) == BiomKlimatu.Step && B(25, 1000) == BiomKlimatu.Savana && B(25, 2500) == BiomKlimatu.TropickyDestnyLes && KlasifikaceBiomu.NazevCs.Length == 11, "poušť / step / savana / tropický les podle Köppenovy meze");
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
        T.Je(new ParametrySveta().KlimaKrok07 && KonfiguraceSveta.VseZapnuto(data).KlimaKrok07 && !ParametrySveta.Krok06().KlimaKrok07 && ParametrySveta.Krok06().VseKrok06 && !ParametrySveta.Krok5().VseKrok06, "klima výchozí zapnuto (Jan 12:47); Krok06() = stav po kroku 6, Krok5() bez kroku 6");
        var psK = new ParametrySveta { More = true, VseKrok06 = false, StartBlok = new[] { 20, 12 }, KlimaKrok07 = true };
        var svK = ErozePlanety.SvetPlanety(psK, data, pe);
        T.Je(ErozePlanety.Klic(svK, data, pe) == ErozePlanety.Klic(sv, data, pe), "klíč keše eroze nezávisí na klimatu (eroze = pozůstatek)");
        string k1 = MapaKlimatu.KlicKlimatu(m.KlicKese, pk, "mirne");
        T.Je(k1 != MapaKlimatu.KlicKlimatu(m.KlicKese, pk, "poust") && k1 != MapaKlimatu.KlicKlimatu(m.KlicKese, pk with { KontinentalitaM = 1000 }, "mirne") && k1 != MapaKlimatu.KlicKlimatu("x", pk, "mirne"), "klíč klimatu: planeta, parametry i mapa eroze");

        T.Sekce("krok 7b: oázy / artéské prameny v pouštích");
        var mkO = MapaKlimatu.Spocti(m, pk, pk.Planeta("poust"), 4);
        var mkS = MapaKlimatu.Spocti(m, pk, pk.Planeta("poust"), 4);
        var oa = Oazy.Najdi(m, mkO, pk, 49); var oa2 = Oazy.Najdi(m, mkS, pk, 49); var oa3 = Oazy.Najdi(m, mkS, pk, 50);
        T.Je(oa.Count > 0 && oa.SequenceEqual(oa2), $"oázy na pouštní planetě deterministické ({oa.Count})");
        T.Je(!oa.Select(o => o.Uzel).SequenceEqual(oa3.Select(o => o.Uzel)), "jiný seed → jiné oázy");
        T.Je(oa.All(o => mkO.Biom[o.Uzel] == BiomKlimatu.Poust && (m.Priznaky[o.Uzel] & (MapaEroze.Odtok | MapaEroze.Jezero)) == 0 && o.QLs >= 0.5 * pk.OazaQLs && o.QLs <= 1.5 * pk.OazaQLs), "oáza jen v poušti, ne v moři ani jezeře, výkon 0,5–1,5 × OazaQLs");
        T.Je(Oazy.Najdi(m, mkO, pk with { OazaZapnuta = false }, 49).Count == 0 && Oazy.Najdi(m, mkO, pk with { OazaPravdepodobnost = 0 }, 49).Count == 0, "oázy jdou vypnout (příznak, pravděpodobnost 0)");
        T.Je(Oazy.Najdi(m, mkO, pk with { OazaPravdepodobnost = 0.6 }, 49).Count > oa.Count, "víc oáz při vyšší pravděpodobnosti (laditelné)");
        T.Je(Oazy.Najdi(m, MapaKlimatu.Spocti(m, pk, mir, 4), pk, 49).Count <= oa.Count / 4 + 1, "mírná planeta (skoro bez pouští): oáz nanejvýš zlomek");
        int prekryto = Oazy.Prekryj(mkO, oa, pk);
        T.Je(prekryto >= oa.Count && oa.All(o => mkO.Biom[o.Uzel] == BiomKlimatu.Oaza), $"okolí oáz v mapě biomů = oáza ({prekryto} uzlů)");

        T.Sekce("krok 7: prameny ze seedu podle klimatu (háček)");
        var pv = new ParametryVody();
        List<Pramen> Pr(Func<double, double, double>? w) { var f = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv); f.Prameny.KlimaW = w; return f.Prameny.VOblasti(0, 0, 256, 256); }
        var p0 = Pr(null); var p1 = Pr((x, y) => 1.0); var pz = Pr((x, y) => 0.0); var p2 = Pr((x, y) => 1.5);
        T.Je(p0.SequenceEqual(p1), $"w = 1 → stejné prameny jako bez klimatu ({p0.Count})");
        T.Je(pz.Count == 0, "w = 0 → žádné prameny ze seedu");
        T.Je(p2.Count >= p0.Count && p2.Where(s => p0.Any(o => o.BunkaX == s.BunkaX && o.BunkaY == s.BunkaY)).All(s => s.Jmenovity > 0), $"w = 1,5 → víc nebo stejně pramenů ({p2.Count} ≥ {p0.Count})");
    }
}
