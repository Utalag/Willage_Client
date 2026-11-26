using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Sluzby;
using Willage.Gen.Api.Vizual;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>
/// G-7 (bez Godotu): náhledy a izolace M4–M6 – shoda s nezávisle sestaveným světem (KonfiguraceSveta.Sestav jako nástroje „klima mapa“ a „eroze rez“),
/// čísla = reporty kroků 6–7c, izolace, 7d zástupné, determinismus, otisky beze změny. Godot část: nastroje/testy/NahledyM4M6Test.tscn.
/// Bajtová shoda řezu M6 s výstupem nástroje: Willage.Gen.Nastroje „nahled porovnej-rez-vody“.
/// </summary>
public static class TestyG7
{
    static bool Bit(double a, double b) => BitConverter.DoubleToInt64Bits(a) == BitConverter.DoubleToInt64Bits(b);
    static bool BitF(float a, float b) => BitConverter.SingleToInt32Bits(a) == BitConverter.SingleToInt32Bits(b);

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        T.Sekce("G-7: náhledy M4 eroze, M5 klima, M6 voda (shoda se světem nástrojů, izolace, 7d zástupné)");
        var g = new GeneratorSveta(data, kes);
        g.Sluzba.Generuj();
        var n = g.Nahledy;
        T.Je(string.Join(",", n.Moduly()) == "M1,M2,M3,M4,M5,M6", "moduly s náhledem M1–M6");
        T.Je(n.Vrstvy("M4").Count == 5 && n.Vrstvy("M5").Count == 6 && n.Vrstvy("M6").Count == 8 && n.Vrstvy("M7").Count == 0, "vrstvy M4 5, M5 6, M6 8 (vč. zástupné 7d), M7 žádné");
        T.Je(n.Izolace("M4") == VrstvaNahleduDto.PosunEroze && n.Izolace("M5") == VrstvaNahleduDto.BiomBezOaz
             && n.IzolaceVrstvy("M6").SequenceEqual(new[] { VrstvaNahleduDto.JenHladina, VrstvaNahleduDto.JenPrameny }) && n.IzolaceVrstvy("M3").Count == 0,
            "izolace: M4 posun eroze, M5 biom bez oáz, M6 jen hladina / jen prameny, M3 řezem");

        // nezávislý svět jako nástroje (KlimaNastroj.Ps: vše zapnuto, seed 49, klima mírné)
        var p = KonfiguraceSveta.VseZapnuto(data, 49); p.KlimaKrok07 = true;
        var sv = KonfiguraceSveta.Sestav(p, data, kes, 8);
        var m = sv.Mapa!; var mk = sv.Klima!.Mapa; var hk = sv.Hydrologie!; var t = m.T;
        double px = t.Nx * t.Krok, py = t.Ny * t.Krok;
        int Uzel(double x, double y) => t.K((int)Math.Round(PeriodickyPodklad.Zabal(x, px) / t.Krok), (int)Math.Round(PeriodickyPodklad.Zabal(y, py) / t.Krok));

        // M4 / M5 mapy = pole modulů v uzlech
        foreach (var (modul, v) in n.Vrstvy("M4").Select(v => ("M4", v)).Concat(n.Vrstvy("M5").Select(v => ("M5", v))))
        {
            var q = n.Mapa(modul, v, 128);
            int chyb = 0;
            for (int j = 0; j < q.Ny; j += 3)
            for (int i = 0; i < q.Nx; i += 3)
            {
                int k = Uzel(q.X0M + (i + 0.5) * q.KrokM, q.Y0M + (j + 0.5) * q.KrokM);
                bool more = (m.Priznaky[k] & MapaEroze.Odtok) != 0;
                float c = v switch
                {
                    VrstvaNahleduDto.VyskaPlanety => m.H[k],
                    VrstvaNahleduDto.PosunEroze => m.H0[k] - m.H[k],
                    VrstvaNahleduDto.Toky => (float)Math.Log10(Math.Max(1.0, m.A[k])),
                    VrstvaNahleduDto.Jezera => (m.Priznaky[k] & MapaEroze.Jezero) != 0 ? Math.Max(0f, m.Vypln[k] - m.H[k]) : 0f,
                    VrstvaNahleduDto.Koryta => more ? -1f : (m.Priznaky[k] & MapaEroze.Koryto) != 0 ? 1f : 0f,
                    VrstvaNahleduDto.Teplota => mk.Teplota[k],
                    VrstvaNahleduDto.Srazky => mk.Srazky[k],
                    VrstvaNahleduDto.OdtokW => mk.W[k],
                    VrstvaNahleduDto.BiomKlimatu => (float)mk.Biom[k],
                    VrstvaNahleduDto.BiomBezOaz => (float)KlasifikaceBiomu.Urci(mk.Teplota[k], mk.Srazky[k], more, sv.ParametryKlimatu!),
                    _ => more ? -1f : (hk.Stav[k] & HydrologieKlimatu.Aktivni) != 0 ? 1f : (hk.Stav[k] & HydrologieKlimatu.Suche) != 0 ? 2f : (hk.Stav[k] & HydrologieKlimatu.BezKoryta) != 0 ? 3f : 0f,
                };
                if (!BitF(c, q.Hodnoty[q.Nx * j + i])) chyb++;
            }
            T.Je(chyb == 0 && q.Nx == 128 && q.Ny == 64, $"{modul}.{v}: {q.Nx}×{q.Ny} po {q.KrokM:0.#} m = pole modulu v uzlech ({chyb} rozdílů), {q.Ms:F0} ms");
        }

        // M4 čísla = otisky / report 6
        var m4 = n.Mapa("M4", VrstvaNahleduDto.PosunEroze, 256);
        var m4b = n.Mapa("M4", VrstvaNahleduDto.Toky, 256);
        T.Je(m4.Popis.Contains("800d420bb00047de") && m4.Cisla["vodniku"] == 92 && m4.Izolace && m4.Body is null && m4b.Body!.Count == 92 && !m4b.Izolace,
            $"M4: otisk mapy 800d420bb00047de, vodníků bez klimatu 92 (body {m4b.Body?.Count}); izolace posunu bez bodů");
        T.Je(m4.Cisla["min"] >= 0 && m4.Cisla["eroze_max_m"] > 0, $"M4 posun eroze ≥ 0 (min {m4.Cisla["min"]:F3}, max {m4.Cisla["eroze_max_m"]:F2}, průměr pevniny {m4.Cisla["eroze_prumer_m"]:F3} m)");

        // M5 čísla = nástroj „klima mapa“ (stejné vzorce nad nezávislým světem) a report 7b
        int nPev = 0; var bc = new int[11]; double sW = 0;
        for (int k = 0; k < t.N; k++) { if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue; nPev++; bc[(int)mk.Biom[k]]++; sW += mk.W[k]; }
        var m5 = n.Mapa("M5", VrstvaNahleduDto.BiomKlimatu, 128).Cisla;
        double mles = 100.0 * bc[(int)BiomKlimatu.MirnyLes] / nPev;
        T.Je(Bit(m5["biom_mírný_les_%"], mles) && Bit(m5["w_prumer"], sW / nPev) && m5["vodniku"] == 86 && m5["oaz"] == 0,
            $"M5: mírný les {m5["biom_mírný_les_%"]:F1} %, tajga {m5["biom_tajga_%"]:F1} %, step {m5["biom_step_%"]:F1} %, w {m5["w_prumer"]:F2}, T {m5["t_min"]:F1}…{m5["t_max"]:F1}, aktivní koryta {m5["koryta_aktivni_%"]:F1} % = výpočet nástroje; 86 vodníků, 0 oáz");
        T.Je(Math.Abs(mles - 91.0) < 0.05 && Math.Abs(m5["biom_tajga_%"] - 5.4) < 0.05 && Math.Abs(m5["biom_step_%"] - 3.6) < 0.05 && m5["koryta_aktivni_%"] >= 73 && m5["koryta_aktivni_%"] <= 79,
            "M5 = report 7b (mírný les 91,0 %, tajga 5,4 %, step 3,6 %, aktivní koryta 73–79 %)");
        var izo5 = n.Mapa("M5", VrstvaNahleduDto.BiomBezOaz, 128); var b5 = n.Mapa("M5", VrstvaNahleduDto.BiomKlimatu, 128);
        T.Je(izo5.Hodnoty.SequenceEqual(b5.Hodnoty) && izo5.Body is null && b5.Body!.Count == 86, "M5 izolace: na mírné planetě (0 oáz) biom bez oáz = biom klimatu, bez bodů");

        // tabulka pásem
        var tp = n.TabulkaPasem();
        T.Je(tp.Count == 3 && string.Join(",", tp.Select(x => x.Id)) == "subtropy,mirne,chladne" && Math.Abs(tp.Sum(x => x.UDo - x.UOd) - 0.5) < 1e-12 && tp[1].HlavniBiom == "mírný les",
            "tabulka pásem mírné planety: subtropy, mírné, chladné, půlperioda 0,5; v mírném převládá mírný les");
        T.Je(tp[0].TPrumerC > tp[1].TPrumerC && tp[1].TPrumerC > tp[2].TPrumerC, $"teplota pásem klesá k pólu ({string.Join(" > ", tp.Select(x => x.TPrumerC.ToString("F1")))} °C)");

        // M6: hladina, dobití, prameny = nezávislá voda nad stejným světem
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var fn = sv.Voda(KatalogMaterialu.ZeSouboru(data.KatalogMaterialu), pv, File.ReadAllText(data.PrusakV1));
        var h6 = n.Mapa("M6", VrstvaNahleduDto.Hladina, 48);
        int ch6 = 0;
        for (int j = 0; j < h6.Ny; j += 5)
        for (int i = 0; i < h6.Nx; i += 5)
        {
            double x = h6.X0M + (i + 0.5) * h6.KrokM, y = h6.Y0M + (j + 0.5) * h6.KrokM;
            if (!BitF((float)(fn.Geologie.Povrch(x, y) - fn.Hladina.Surova(x, y)), h6.Hodnoty[j * h6.Nx + i])) ch6++;
        }
        var pr = fn.Prameny.VOblasti(1792, 1792, 2176, 2176);
        T.Je(ch6 == 0 && h6.X0M == 1792 && h6.KrokM == 8, $"M6 hladina 48×48 (start 3 × 3) = surová hladina nezávislé vody ({ch6} rozdílů), {h6.Ms:F0} ms");
        T.Je(h6.Body!.Count == 21 && pr.Count == 21 && h6.Body.Zip(pr).All(z => z.First.X == z.Second.X && z.First.Y == z.Second.Y && z.First.QLs == z.Second.Jmenovity),
            "M6 prameny startu 3 × 3: 21 = 21 (report 7c), stejné polohy a výkony");
        T.Je(Math.Abs(h6.Cisla["planeta_bez_hladiny_%"] - 0.3) < 0.05 && Math.Abs(h6.Cisla["planeta_castecne_%"] - 16.9) < 0.05 && Math.Abs(h6.Cisla["planeta_plne_%"] - 82.8) < 0.05,
            $"M6 dobití pevniny {h6.Cisla["planeta_bez_hladiny_%"]:F1} / {h6.Cisla["planeta_castecne_%"]:F1} / {h6.Cisla["planeta_plne_%"]:F1} % = report 7c (0,3 / 16,9 / 82,8)");
        var jh = n.Mapa("M6", VrstvaNahleduDto.JenHladina, 48); var jp = n.Mapa("M6", VrstvaNahleduDto.JenPrameny, 48);
        T.Je(jh.Hodnoty.Zip(h6.Hodnoty).All(z => BitF(z.First, z.Second)) && jh.Body is null && jh.Izolace && jp.Izolace && jp.Body!.Count == 21,
            "M6 izolace: jen hladina = hodnoty hladiny bez bodů, jen prameny = 21 bodů");
        var z7 = n.Mapa("M6", VrstvaNahleduDto.ZvodnelaZona7d, 32);
        T.Je(z7.Zastupny && z7.Hodnoty.All(float.IsNaN) && z7.Cisla["zastupny"] == 1 && z7.Popis.Contains("ZÁSTUPNÁ") && z7.Body is null, "7d zvodnělá zóna: zástupná vrstva (NaN, bez logiky, označená)");
        var dob = n.Mapa("M6", VrstvaNahleduDto.Dobiti, 32);
        T.Je(BitF(dob.Hodnoty[5 * 32 + 7], (float)sv.Napajeni!.Dobiti(1792 + 7.5 * 12, 1792 + 5.5 * 12)), "M6 dobití = NapajeniVody.Dobiti");

        // řez s hladinou M6 = nezávislá voda (materiály erodované geologie, povrch, surová hladina) + prameny do 150 m
        var r6 = n.Rez("M6", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2096, 1984), 0.25);
        int rm = 0, rp = 0, rh = 0;
        for (int i = 0; i < r6.Nx; i++)
        {
            double x = 2000 + (i + 0.5) * 0.25;
            var sl = sv.Geologie.Sloupec(x, 1984); for (int k = 0; k < r6.Nz; k++) if (sl[k] != r6.Material(i, k)) rm++;
            if (!Bit(sv.Geologie.Povrch(x, 1984), r6.PovrchM[i])) rp++;
            if (!Bit(fn.Hladina.Surova(x, 1984), r6.HladinaPodzemniM![i])) rh++;
        }
        T.Je(r6.Nx == 384 && r6.Nz == 512 && rm + rp + rh == 0 && r6.Body!.Count == 12 && r6.Zastupne.Count == 1 && r6.Zastupne[0].Contains("7d"),
            $"řez M6 384×512 = voda nástroje (materiály {rm}, povrch {rp}, hladina {rh} rozdílů), 12 pramenů do 150 m (jako „eroze rez“), 7d zástupné; {r6.Ms:F0} ms");
        // řezy M4 / M5 (profily) = svět planety M4 a klima
        var r4 = n.Rez("M4", SouradniceQ16.ZMetru(0, 1984), SouradniceQ16.ZMetru(31360, 1984), 61.25);
        var r5 = n.Rez("M5", SouradniceQ16.ZMetru(0, 1984), SouradniceQ16.ZMetru(31360, 1984), 61.25);
        double xs = (100 + 0.5) * 61.25;
        T.Je(r4.Nx == 512 && Bit(r4.PovrchM1![100] - r4.PovrchM[100], r4.Rady!["eroze_m"][100]) && Bit(r4.Rady["eroze_m"][100], sv.Eroze!.Hloubka(xs, 1984))
             && Bit(r5.Rady!["teplota_c"][100], sv.Klima.Teplota(xs, 1984)) && (int)r5.Rady["biom"][100] == (int)sv.Klima.Biom(xs, 1984),
            "řez M4 před − po = eroze, M5 řady teplota / biom = klima světa");
        bool chyba7 = false; try { n.Rez("M7", default, SouradniceQ16.ZMetru(10, 0), 1); } catch (ArgumentException) { chyba7 = true; }
        T.Je(chyba7, "řez M7 není → ArgumentException");

        // determinismus, 1 = 8 vláken
        var gs = new GeneratorSveta(data, kes, 1); gs.Sluzba.Generuj();
        T.Je(gs.Nahledy.Mapa("M6", VrstvaNahleduDto.Hladina, 24).Hodnoty.SequenceEqual(n.Mapa("M6", VrstvaNahleduDto.Hladina, 24).Hodnoty)
             && gs.Nahledy.Mapa("M4", VrstvaNahleduDto.Toky, 64).Hodnoty.SequenceEqual(n.Mapa("M4", VrstvaNahleduDto.Toky, 64).Hodnoty)
             && gs.Nahledy.Rez("M6", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2032, 1984), 0.25).Materialy.SequenceEqual(n.Rez("M6", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2032, 1984), 0.25).Materialy),
            "1 vlákno = 8 vláken (M6 hladina, M4 toky, řez M6)");

        // barvy
        var mat = n.Materialy();
        foreach (var q in new[] { m4, b5, h6, z7, dob }) T.Je(BarvyNahledu.Rgba(q, mat).Length == q.Hodnoty.Length * 4, $"RGBA {q.Modul}.{q.Vrstva}");
        var zr = BarvyNahledu.Rgba(z7, mat);
        T.Je(zr[0] != zr[4 * 6] || zr[1] != zr[4 * 6 + 1], "zástupná vrstva 7d má šrafu");
        T.Je(BarvyNahledu.RgbaRezu(r6, mat).Length == 384 * 512 * 4, "řez M6 RGBA");

        // pouštní planeta: izolace M5 se liší jen v oázách (report 7b: 71 oáz)
        var gp = new GeneratorSveta(data, kes);
        var zp = gp.Moduly.Nastav("ParametrySveta.Klima", "\"poust\"");
        T.Je(zp.Prijato, "nastavení planety poušť přijato" + (zp.Duvod is null ? "" : ": " + zp.Duvod));
        gp.Sluzba.Generuj();
        var pb = gp.Nahledy.Mapa("M5", VrstvaNahleduDto.BiomKlimatu, 512); var pi = gp.Nahledy.Mapa("M5", VrstvaNahleduDto.BiomBezOaz, 512);
        int oazaUzlu = 0, jinde = 0;
        for (int k = 0; k < pb.Hodnoty.Length; k++)
        {
            if (pb.Hodnoty[k] == (float)BiomKlimatu.Oaza) { oazaUzlu++; if (pi.Hodnoty[k] != (float)BiomKlimatu.Poust) jinde++; }
            else if (pb.Hodnoty[k] != pi.Hodnoty[k]) jinde++;
        }
        T.Je(pb.Cisla["oaz"] == 71 && oazaUzlu > 0 && jinde == 0, $"poušť: {pb.Cisla["oaz"]} oáz (report 7b 71), biom bez oáz = poušť v {oazaUzlu} vzorcích oáz, jinde stejný ({jinde} chyb)");
        var d6 = gp.Nahledy.Mapa("M6", VrstvaNahleduDto.Dobiti, 16).Cisla;
        T.Je(Math.Abs(d6["planeta_bez_hladiny_%"] - 71.9) < 0.05, $"poušť: bez hladiny {d6["planeta_bez_hladiny_%"]:F1} % pevniny (report 7c 71,9 %)");

        // náhledy nemění otisky
        var o = g.Sluzba.Otisky();
        T.Je(o.Mapa == "800d420bb00047de" && o.Klima == "cb11da8d141a2a5e" && o.Vodniku == 86 && o.VodaBlok == "377a8210f82c856a", "po náhledech M4–M6 otisky beze změny");
    }
}
