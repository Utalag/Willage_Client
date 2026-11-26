using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>Krok 6c: periodický šum, maska pevniny (kontinenty, práh z histogramu), parametry v klíči, přepínač „vše zapnuto“.</summary>
public static class TestyKrok06c
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var json = ParametryMore.ZJson(File.ReadAllText(data.MoreV1));

        T.Sekce("krok 6c: periodický šum na torusu");
        var h = new HashSveta(49);
        var f = new PeriodickySum(h, "T6C", 31360, 15616, 32, 600, 8000, 1.0);
        double maxd = 0, s = 0, s2 = 0; var r = new Random(1);
        for (int i = 0; i < 2000; i++)
        {
            double x = r.NextDouble() * 31360, y = r.NextDouble() * 15616, v = f.Hodnota(x, y);
            maxd = Math.Max(maxd, Math.Max(Math.Abs(v - f.Hodnota(x + 31360, y)), Math.Abs(v - f.Hodnota(x, y - 2 * 15616))));
            s += v; s2 += v * v;
        }
        double sd = Math.Sqrt(s2 / 2000 - (s / 2000) * (s / 2000));
        T.Je(maxd < 1e-9, $"šum přesně periodický (max rozdíl {maxd:G2})");
        T.Je(sd > 0.8 && sd < 1.2, $"šum normován (směrodatná odchylka {sd:F2})");

        T.Sekce("krok 6c: maska pevniny – kontinenty, práh z histogramu");
        bool okPocet = true, okPodil = true; var kont = new HashSet<int>();
        foreach (long seed in new long[] { 49, 1, 2, 3, 4, 5, 6, 7 })
        {
            var p = json.Uplatni(new ParametrySveta { Seed = seed, More = true, VseKrok06 = false });
            var m = new MaskaPevniny(p, new HashSveta(seed));
            kont.Add(m.Kontinentu);
            okPocet &= m.Kontinentu >= p.KontinentuMin && m.Kontinentu <= p.KontinentuMax;
            // podíl moře na nezávislé jemnější mřížce (posunuté uzly) ≈ cíl
            int n = 0, mo = 0;
            for (double x = 37; x < p.PlanetaXM; x += 97) for (double y = 41; y < p.PlanetaYM; y += 97) { n++; if (m.M(x, y) < m.Prah) mo++; }
            okPodil &= Math.Abs((double)mo / n - m.Podil) < 0.01;
        }
        T.Je(okPocet, "počet kontinentů v rozmezí KontinentuMin..Max (8 seedů)");
        T.Je(kont.Count > 1, $"počet kontinentů se mění se seedem ({string.Join(", ", kont.OrderBy(k => k))})");
        T.Je(okPodil, "podíl pod prahem na jiné mřížce = cílový podíl ± 1 p.b. (8 seedů)");

        T.Sekce("krok 6c: změna parametrů kontinentů mění výsledek i klíč");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 8192, PlanetaYM = 4096, KrokuCasu = 3 };
        (string otisk, string klic) Beh(ParametryMore pm)
        {
            var ps = new ParametrySveta { More = true, VseKrok06 = false, StartBlok = new[] { 20, 12 } };
            var sv = ErozePlanety.SvetPlanety(ps, data, pe);
            pm.Uplatni(sv.P);
            sv = new SvetFn(sv.P, data);
            var m = VypocetEroze.Spocti(ErozePlanety.Podklad(sv, pe), pe, 4, out _);
            return (SouborMapy.Otisk(m), ErozePlanety.Klic(sv, data, pe));
        }
        var zakl = json with { OdchylkaMoreProcBodu = 0 };
        var a = Beh(zakl);
        var b = Beh(zakl with { KontinentuMin = 4, KontinentuMax = 4 });
        var c = Beh(zakl with { ClenitostSila = zakl.ClenitostSila * 2 });
        T.Je(b.otisk != a.otisk && b.klic != a.klic, "počet kontinentů: jiný otisk i klíč");
        T.Je(c.otisk != a.otisk && c.klic != a.klic, "členitost: jiný otisk i klíč");

        T.Sekce("krok 6c: přepínač vše zapnuto");
        T.Je(new ParametrySveta().VseKrok06 && !ParametrySveta.Krok5().VseKrok06, "výchozí od 6d: vše zapnuto (Krok5() = vypnuto)");
        var p0 = ParametrySveta.Krok5(); var pv = KonfiguraceSveta.VseZapnuto(data);
        var s0 = new SvetFn(p0, data); var sv1 = new SvetFn(pv, data);
        T.Je(sv1.More is not null && sv1.Panve is not null, "VseKrok06 zapne moře i pánve");
        double md = 0; for (double x = 1792; x < 2176; x += 3.7) for (double y = 1792; y < 2176; y += 5.3) md = Math.Max(md, Math.Abs(s0.Vyska(x, y) - sv1.Vyska(x, y)));
        T.Je(md == 0, "start 3 × 3 s mořem, sklonem a pánvemi (bez eroze) beze změny");
    }
}
