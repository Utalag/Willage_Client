using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Sluzby;
using Willage.Gen.Api.Vizual;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>G-6 (bez Godotu): náhledy a izolace M1–M3 – shoda s přímým voláním jádra (jako nástroje), řez M3 = nástroj „rez“, izolace, determinismus.
/// Godot část: nastroje/testy/NahledyTest.tscn. Bajtová shoda s výstupem nástroje: Willage.Gen.Nastroje „nahled porovnej-rez“.</summary>
public static class TestyG6
{
    static bool Bit(double a, double b) => BitConverter.DoubleToInt64Bits(a) == BitConverter.DoubleToInt64Bits(b);

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        T.Sekce("G-6: náhledy M1–M3 (shoda s jádrem, izolace, řez)");
        var g = new GeneratorSveta(data, kes);
        g.Sluzba.Generuj();
        var n = g.Nahledy;
        T.Je(string.Join(",", n.Moduly()) == "M1,M2,M3", "moduly s náhledem M1, M2, M3");
        T.Je(n.Vrstvy("M1").Count == 6 && n.Vrstvy("M2").Count == 6 && n.Vrstvy("M3").Count == 3 && n.Vrstvy("M4").Count == 0, "vrstvy M1 6, M2 6, M3 3, M4 žádné (G-7)");
        T.Je(n.Izolace("M1") == VrstvaNahleduDto.Relief && n.Izolace("M2") == VrstvaNahleduDto.RozdilM2M1 && n.Izolace("M3") is null, "izolace: M1 reliéf, M2 rozdíl M2−M1, M3 řezem");

        // nezávislé instance jádra jako v nástrojích (PorovnejVysku: new SvetFn(new ParametrySveta()); rez: new GeologieCs(new ParametrySveta()))
        var s2 = new SvetFn(new ParametrySveta(), data);
        var p1 = new ParametrySveta { More = false, Panve = false, VseKrok06 = false };
        var s1 = new SvetFn(p1, data);
        var g3 = new GeologieCs(new ParametrySveta(), data);

        int R = 64;
        var casy = new List<string>();
        foreach (var modul in n.Moduly())
            foreach (var v in n.Vrstvy(modul))
            {
                var m = n.Mapa(modul, v, R);
                casy.Add($"{modul}.{v} {m.Ms:F0} ms");
                int chyb = 0;
                for (int j = 0; j < m.Ny; j += 7)
                for (int i = 0; i < m.Nx; i += 5)
                {
                    double x = m.X0M + (i + 0.5) * m.KrokM, y = m.Y0M + (j + 0.5) * m.KrokM;
                    float c = (modul, v) switch
                    {
                        ("M1", VrstvaNahleduDto.Vyska) => (float)s1.Vyska(x, y),
                        ("M1", VrstvaNahleduDto.Biom) => s1.Sloupec(x, y).Biom,
                        ("M1", VrstvaNahleduDto.Horniny) => s1.Sloupec(x, y).Horniny[0].id,
                        ("M1", VrstvaNahleduDto.Sopky) => s1.SopkaV(x, y),
                        ("M1", VrstvaNahleduDto.Masiv) => (float)s1.Sloupec(x, y).Masiv,
                        ("M1", VrstvaNahleduDto.Relief) => (float)NahledyModuluApi.Relief(s1, x, y),
                        ("M2", VrstvaNahleduDto.Vyska) => (float)s2.Vyska(x, y),
                        ("M2", VrstvaNahleduDto.Pevnina) => (float)s2.More!.Pevnina(x, y),
                        ("M2", VrstvaNahleduDto.More) => s2.More!.JeMore(x, y, s2.Vyska(x, y)) ? 1f : 0f,
                        ("M2", VrstvaNahleduDto.Panve) => (float)s2.Panve!.Posun(x, y),
                        ("M2", VrstvaNahleduDto.Sev) => (float)s2.More!.Maska.DoSevu(x, y),
                        ("M2", VrstvaNahleduDto.RozdilM2M1) => (float)(s2.Vyska(x, y) - s1.Vyska(x, y)),
                        ("M3", VrstvaNahleduDto.MaterialPovrchu) => g3.MaterialPovrchu(x, y),
                        ("M3", VrstvaNahleduDto.Mince) => (float)g3.Mince82Sila(x, y),
                        _ => (float)g3.Povrch(x, y),
                    };
                    if (BitConverter.SingleToInt32Bits(c) != BitConverter.SingleToInt32Bits(m.Hodnoty[j * m.Nx + i])) chyb++;
                }
                T.Je(chyb == 0 && m.Nx == R && m.Ny == R && Bit(m.KrokM, 4096.0 / R), $"{modul}.{v}: {m.Nx}×{m.Ny} po {m.KrokM} m bitově = přímé volání jádra ({chyb} rozdílů)");
            }
        Console.WriteLine("  časy 64×64: " + string.Join(", ", casy));

        // čísla, determinismus, paralelně = sekvenčně (mapa se počítá po řádcích paralelně)
        var mm = n.Mapa("M2", VrstvaNahleduDto.More, 128);
        Console.WriteLine($"  M2 moře: podíl v náhledu {mm.Cisla["podil_more"]:F3}, cíl masky {mm.Cisla["podil_more_cil"]:F3}, kontinentů {mm.Cisla["kontinentu"]}, ostrovů {mm.Cisla["ostrovu"]}, pánví {mm.Cisla["panvi"]}");
        T.Je(mm.Cisla["podil_more"] > 0.05 && mm.Cisla["podil_more"] < 0.95, "M2: startovní svět má moře i pevninu");
        var a = n.Mapa("M3", VrstvaNahleduDto.MaterialPovrchu, 96); var b = n.Mapa("M3", VrstvaNahleduDto.MaterialPovrchu, 96);
        T.Je(a.Hodnoty.SequenceEqual(b.Hodnoty), "determinismus: dvakrát stejný náhled M3 (klony geologie na vláknech)");
        var gs = new GeneratorSveta(data, kes, 1); gs.Sluzba.Generuj();
        T.Je(gs.Nahledy.Mapa("M3", VrstvaNahleduDto.MaterialPovrchu, 96).Hodnoty.SequenceEqual(a.Hodnoty) && gs.Nahledy.Mapa("M1", VrstvaNahleduDto.Horniny, 96).Hodnoty.SequenceEqual(n.Mapa("M1", VrstvaNahleduDto.Horniny, 96).Hodnoty),
            "1 vlákno = 8 vláken (M1 horniny, M3 materiál)");
        var m256 = n.Mapa("M1", VrstvaNahleduDto.Biom, 256);
        Console.WriteLine($"  M1 biom 256×256: {m256.Ms:F0} ms");

        // řez M3 = nástroj „rez“ (SevyMince.Rez: x 2048 ± 48, y 1984, po 0,25 m, sloupec 512 buněk)
        var r = n.Rez("M3", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2096, 1984), 0.25);
        int rozd = 0, rozdP = 0;
        for (int i = 0; i < r.Nx; i++)
        {
            double x = 2048.0 - 48.0 + (i + 0.5) * 0.25;
            var sl = g3.Sloupec(x, 1984.0);
            for (int k = 0; k < r.Nz; k++) if (sl[k] != r.Material(i, k)) rozd++;
            if (!Bit(g3.Povrch(x, 1984.0), r.PovrchM[i])) rozdP++;
        }
        T.Je(r.Nx == 384 && r.Nz == 512 && rozd == 0 && rozdP == 0, $"řez M3 384×512 = výpočet nástroje rez (materiály {rozd} rozdílů, povrch {rozdP}); {r.Ms:F0} ms");

        // izolace řezu
        var rv = n.Rez("M3", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2096, 1984), 0.25, RezimRezuDto.JenVrstvy);
        var ru = n.Rez("M3", SouradniceQ16.ZMetru(2000, 1984), SouradniceQ16.ZMetru(2096, 1984), 0.25, RezimRezuDto.JenUtvary);
        int jinych = 0, spatne = 0, utv = 0;
        for (int k = 0; k < r.Materialy.Length; k++)
        {
            if (ru.Materialy[k] != 0) utv++;
            if (r.Materialy[k] != rv.Materialy[k]) { jinych++; if (ru.Materialy[k] != r.Materialy[k]) spatne++; }
            else if (ru.Materialy[k] != 0 && ru.Materialy[k] != r.Materialy[k]) spatne++;
        }
        T.Je(spatne == 0 && jinych > 0 && utv > 0, $"izolace řezu: {jinych} buněk útvarů/sopek se liší od „jen vrstvy“, „jen útvary“ je v nich = vše ({spatne} chyb, {utv} buněk útvarů)");
        var vseRezim = new GeologieCs(new ParametrySveta(), data);
        bool stejne = true;
        for (double x = 2000.125; x < 2096; x += 3.0)
            if (!vseRezim.Geo.VyplnSloupecRezim(x, 1984, GeologyGridConstants.CellM, GeologyGridConstants.ColumnM, GeoVrstvy.RezimSloupce.Vse).SequenceEqual(vseRezim.Sloupec(x, 1984))) stejne = false;
        T.Je(stejne, "VyplnSloupecRezim(Vse) = VyplnSloupec");

        // profil M1/M2
        var pr = n.Rez("M2", SouradniceQ16.ZMetru(0, 1984), SouradniceQ16.ZMetru(4096, 1984), 8);
        T.Je(pr.Nx == 512 && pr.PovrchM1 is not null && Bit(pr.PovrchM[100], s2.Vyska(4.0 + 100 * 8, 1984)) && Bit(pr.PovrchM1[100], s1.Vyska(804, 1984)) && pr.HladinaMoreM == s2.P.HladinaMoreM,
            $"profil M2 512 vzorků: povrch M2, M1 a hladina {pr.HladinaMoreM} m");
        bool chybaM4 = false; try { n.Rez("M4", default, SouradniceQ16.ZMetru(10, 0), 1); } catch (ArgumentException) { chybaM4 = true; }
        T.Je(chybaM4, "řez M4 v G-6 není (G-7) → ArgumentException");

        // barvy a materiály
        var mat = n.Materialy();
        T.Je(mat.Count >= 50 && mat.First(x => x.Id == 1).BarvaHex == "#8fcc78" && mat.First(x => x.Id == 0).BarvaHex == "#00000000", $"materiály z materialy_v1.csv: {mat.Count}, tráva #8fcc78, vzduch průhledný");
        var rg = BarvyNahledu.RgbaRezu(r, mat);
        T.Je(rg.Length == 384 * 512 * 4 && rg[3] == 0 && rg[(511 * 384) * 4 + 3] == 255, "řez RGBA: nahoře vzduch průhledný, dole hornina");
        T.Je(BarvyNahledu.Rgba(mm, mat).Length == mm.Hodnoty.Length * 4, "mapa RGBA");

        // náhledy nemění otisky
        var o = g.Sluzba.Otisky();
        T.Je(o.Mapa == "800d420bb00047de" && o.Klima == "cb11da8d141a2a5e" && o.Vodniku == 86 && o.VodaBlok == "377a8210f82c856a", "po náhledech otisky beze změny");
    }
}
