using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Krok 6e: hladina podzemní vody svázaná s mořem (60 m u pobřeží a v moři), start beze změny, podíl moře 35 %.</summary>
public static class TestyKrok06e
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var json = ParametryMore.ZJson(File.ReadAllText(data.MoreV1));
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        T.Sekce("krok 6e: výchozí hodnoty (35 % moře, zvlnění švu 400 m)");
        T.Je(json.PodilMore == 0.35 && json.SevZvlneniM == 400.0 && new ParametrySveta().PodilMore == 0.35 && new ParametrySveta().SevZvlneniM == 400.0, "podíl moře 0,35 a zvlnění 400 m v JSON i v C#");
        T.Je(pv.HladinaPrechodM > 0, $"HladinaPrechodM {pv.HladinaPrechodM} m ve voda_v1.json (ladící, krok 6f: 5 m)");

        T.Sekce("krok 6e: hladina podzemní vody u moře");
        bool start = true, more60 = true, plynule = true, vliv = false; int nMore = 0;
        foreach (long seed in new long[] { 49, 1, 2, 3, 4, 5, 6, 7, 8, 9 })
        {
            var g = new GeologieCs(new ParametrySveta { Seed = seed }, data);
            var h1 = new RegionalniHladina(g, pv); var h0 = new RegionalniHladina(g, pv with { HladinaPrechodM = 0 });
            for (double x = 1792; x < 2176 && start; x += 8) for (double y = 1792; y < 2176 && start; y += 8)
                if (h1.Surova(x, y) != h0.Surova(x, y)) start = false;
            var r = new Random((int)seed);
            double maxSkok = 0;
            for (int i = 0; i < 4000; i++)
            {
                double x = r.NextDouble() * 31360, y = r.NextDouble() * 15616, d = g.VzdalenostOdMore(x, y);
                if (d == 0) { nMore++; if (Math.Abs(h1.Surova(x, y) - 60.0) > 1e-9) more60 = false; }
                else if (d < pv.HladinaPrechodM) { vliv |= Math.Abs(h1.Surova(x, y) - h0.Surova(x, y)) > 0.01; double dx = 1.0; maxSkok = Math.Max(maxSkok, Math.Abs(h1.Surova(x + dx, y) - h1.Surova(x, y))); }
            }
            double mez = Math.Max(3.0, 50.0 / Math.Max(pv.HladinaPrechodM, 1e-6) * 1.5 + 1.0); plynule &= maxSkok < mez; if (maxSkok >= mez) Console.WriteLine($"SKOK seed {seed} {maxSkok:F2} mez {mez:F2}");
        }
        T.Je(start, "start 3 × 3: hladina s vazbou na moře = bez vazby (10 seedů)");
        T.Je(more60 && nMore > 100, $"v moři hladina přesně 60 m ({nMore} bodů, 10 seedů)");
        T.Je(vliv, $"do {pv.HladinaPrechodM} m od moře se hladina mění");
        T.Je(plynule, "hladina je spojitá u pobřeží (krok 1 m v mezích přechodu)");
        var gb = new GeologieCs(ParametrySveta.Krok5(), data);
        T.Je(double.IsPositiveInfinity(gb.VzdalenostOdMore(5000, 5000)) && new RegionalniHladina(gb, pv).Surova(5000, 5000) == new RegionalniHladina(gb, pv with { HladinaPrechodM = 0 }).Surova(5000, 5000), "bez moře beze změny");

        T.Sekce("krok 6e: zvlnění okraje pásu švu je ladící parametr (Jan 11:22)");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 8192, PlanetaYM = 4096, KrokuCasu = 3 };
        (string otisk, string klic) Beh(ParametryMore pm)
        {
            var ps = new ParametrySveta { StartBlok = new[] { 20, 12 } };
            var sv = ErozePlanety.SvetPlanety(ps, data, pe);
            pm.Uplatni(sv.P);
            sv = new SvetFn(sv.P, data);
            var m = VypocetEroze.Spocti(ErozePlanety.Podklad(sv, pe), pe, 4, out _);
            return (SouborMapy.Otisk(m), ErozePlanety.Klic(sv, data, pe));
        }
        var zakl = json with { OdchylkaMoreProcBodu = 0 };
        var a = Beh(zakl);
        var b = Beh(zakl with { SevZvlneniM = 900.0 });
        var c = Beh(zakl with { SevZvlneniLambdaMinM = 1200.0, SevZvlneniLambdaMaxM = 6000.0 });
        var nula = Beh(zakl with { SevZvlneniM = 0.0 });
        T.Je(a.otisk == Beh(zakl).otisk, "stejné parametry → stejný otisk");
        T.Je(b.otisk != a.otisk && b.klic != a.klic, "SevZvlneniM 400 → 900: jiný otisk i klíč");
        T.Je(c.otisk != a.otisk && c.klic != a.klic, "SevZvlneniLambdaMinM/MaxM: jiný otisk i klíč");
        T.Je(nula.otisk != a.otisk && nula.klic != a.klic, "SevZvlneniM 0 (bez zvlnění): jiný otisk i klíč");
    }
}
