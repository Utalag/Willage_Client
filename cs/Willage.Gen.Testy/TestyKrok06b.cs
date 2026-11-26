using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>Krok 6b: moře a sklon, ladicí parametry v JSON (změna → jiný výsledek i klíč), odchylka moře ze seedu, pánve, jezera, interpolace.</summary>
public static class TestyKrok06b
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var json = ParametryMore.ZJson(File.ReadAllText(data.MoreV1));

        T.Sekce("krok 6b: moře – start na pevnině, šev v moři, odchylka ze seedu");
        bool vse = true; var podily = new HashSet<double>();
        foreach (long seed in new long[] { 49, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 })
        {
            var p = json.Uplatni(new ParametrySveta { Seed = seed, More = true, VseKrok06 = false });
            var ms = new MoreSklon(p, seed, new HashSveta(seed));
            podily.Add(ms.Podil);
            bool ok = ms.StartNaPevnine && ms.StartBezPosunu && Math.Abs(ms.Podil - json.PodilMore) <= 0.05 + 1e-12;
            for (double x = 1792; x < 2176 && ok; x += 16) for (double y = 1792; y < 2176 && ok; y += 16)
                if (ms.Pevnina(x, y) != 1.0 || ms.Aplikuj(x, y, 50.0, 60.0) != 50.0) ok = false;
            for (double x = 0; x < 512 && ok; x += 16) for (double y = 0; y < 15616 && ok; y += 97)
                if (ms.Pevnina(x, y) != 0.0 || ms.Pevnina(y * 2, x) != 0.0) ok = false;
            vse &= ok;
        }
        T.Je(vse, "12 seedů: podíl 30 ± 5 %, start 3 × 3 pevnina s posunem 0, pás prolnutí švu celý v moři");
        T.Je(podily.Count == 12, "odchylka podílu moře se mění se seedem");

        T.Sekce("krok 6b: moře vypnuté / zapnuté ve start světě");
        var s0 = new SvetFn(ParametrySveta.Krok5(), data);
        var s1 = new SvetFn(json.Uplatni(new ParametrySveta { More = true, VseKrok06 = false }), data);
        double md = 0; for (double x = 1792; x < 2176; x += 3.7) for (double y = 1792; y < 2176; y += 5.3) md = Math.Max(md, Math.Abs(s0.Vyska(x, y) - s1.Vyska(x, y)));
        T.Je(md == 0, "start svět s mořem a sklonem beze změny (pobřežní rovina)");

        T.Sekce("krok 6b: ladicí parametry v JSON mění výsledek i klíč keše (Jan 10:11)");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 8192, PlanetaYM = 4096, KrokuCasu = 3 };
        (string otisk, string klic, double more, int panvi) Beh(ParametryMore pm)
        {
            var ps = new ParametrySveta { More = true, Panve = true, VseKrok06 = false, StartBlok = new[] { 20, 12 } };
            var sv = ErozePlanety.SvetPlanety(ps, data, pe);
            pm.Uplatni(sv.P);                       // přepsat hodnoty ze souboru testovanými
            sv = new SvetFn(sv.P, data);
            var m = VypocetEroze.Spocti(ErozePlanety.Podklad(sv, pe), pe, 4, out _);
            int o = 0; for (int k = 0; k < m.T.N; k++) if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) o++;
            return (SouborMapy.Otisk(m), ErozePlanety.Klic(sv, data, pe), (double)o / m.T.N, sv.Panve!.Stredy.Count);
        }
        var zakl = json with { PanevPolomerM = 600, PanviPocet = 2, OdchylkaMoreProcBodu = 0, PodilMore = 0.25 };
        var a = Beh(zakl);
        var b = Beh(zakl with { PodilMore = 0.35 });
        var c = Beh(zakl with { PanviPocet = 4 });
        var a2 = Beh(zakl);
        T.Je(a.otisk == a2.otisk && a.klic == a2.klic, "stejné parametry → stejný otisk i klíč");
        T.Je(b.otisk != a.otisk && b.klic != a.klic && b.more > a.more, $"podíl moře 25 → 35 %: jiný otisk i klíč, moře {100 * a.more:F1} → {100 * b.more:F1} %");
        T.Je(c.otisk != a.otisk && c.klic != a.klic && c.panvi > a.panvi, $"pánví 2 → 4: jiný otisk i klíč ({a.panvi} → {c.panvi} pánví)");

        T.Sekce("krok 6b: jezera a interpolace");
        var pe2 = pe with { PlanetaXM = 2048, PlanetaYM = 1024, KrokuCasu = 3 };
        var sv2 = ErozePlanety.SvetPlanety(ParametrySveta.Krok5(), data, pe2);
        var m2 = VypocetEroze.Spocti(ErozePlanety.Podklad(sv2, pe2), pe2, 2, out _);
        var jez = Jezera.Najdi(m2);
        bool hl = jez.Count > 0;
        for (int k = 0; k < m2.T.N; k++) if ((m2.Priznaky[k] & MapaEroze.Jezero) != 0 && m2.Vypln[k] <= m2.H[k]) hl = false;
        T.Je(hl, $"jezera: {jez.Count}, hladina (vyplnění) nad dnem v každém uzlu jezera");
        var cr = new ErozeSvetaFn(m2, pe2 with { InterpolaceE = "catmullrom" });
        double odch = 0, skok = 0; var r = new Random(3);
        for (int i = 0; i < 2000; i++)
        {
            int k = r.Next(m2.T.N); var (x, y) = m2.T.Poloha(k);
            odch = Math.Max(odch, Math.Abs(cr.ErozeE(x, y) - Math.Max(0, m2.E(k))));
            double yy = y + 5.3, e = 1e-3;
            double gl = (cr.ErozeE(x, yy) - cr.ErozeE(x - e, yy)) / e, gp = (cr.ErozeE(x + e, yy) - cr.ErozeE(x, yy)) / e;
            if (cr.ErozeE(x - 1, yy) > 0.01 && cr.ErozeE(x + 1, yy) > 0.01) skok = Math.Max(skok, Math.Abs(gp - gl));
        }
        T.Je(odch < 1e-5, $"Catmull-Rom prochází uzly (max odchylka {odch:G3} m)");
        T.Je(skok < 0.01, $"Catmull-Rom: gradient spojitý přes hranu buňky (max skok {skok:G3})");
    }
}
