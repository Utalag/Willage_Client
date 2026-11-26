using System.Globalization;
using System.Text;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;
using Willage.Gen.Voda.Prusak;

namespace Willage.Gen.Nastroje;

/// <summary>Měření šířky pobřežního pásu z koeficientu průsaku: tabulka materiálů, statistika břehů seedu, vliv na otisky a prameny.</summary>
public static class PobrezniNastroj
{
    static readonly CultureInfo C = CultureInfo.InvariantCulture;

    /// <summary>Šířky pásu podle materiálu, horizontu a spádu (promile); sloupec „bez koef.“ = jen Darcy (koeficient 255).</summary>
    public static int Tabulka(DataSveta d)
    {
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var pv0 = ParametryVody.ZJson(File.ReadAllText(d.VodaV1)) with { PrusakPobrezi = true };
        var koef = new PrusakKoeficient(kat, File.ReadAllText(d.PrusakV1));
        var ids = new[] { 66, 3, 55, 5, 44, 49, 56, 46, 57, 60, 54, 2, 1, 12, 4, 6, 33, 47, 48 };
        int[] dny = { 7, 30, 90 }; int[] spady = { 10, 50, 200 };
        var sb = new StringBuilder();
        sb.AppendLine("| materiál | koef. | K (m/s) | 30 d, spád 10 ‰ | 30 d, 50 ‰ | 30 d, 200 ‰ | 7 d, 50 ‰ | 90 d, 50 ‰ | 30 d, 50 ‰ bez koef. |");
        sb.AppendLine("|---|---|---|---|---|---|---|---|---|");
        var pasy = dny.ToDictionary(x => x, x => new PobrezniPas(kat, koef, pv0 with { PobrezHorizontDni = x }));
        foreach (int id in ids)
        {
            var m = kat.Najdi(id)!;
            double n = m.Porovitost > 0 ? m.Porovitost : pv0.PobrezPorovitost;
            long tau0 = m.KMs is double k ? PrusakDosah.CasCistehoBlokuMs(k, n, 0.05) : -1;
            long bez = PrusakDosah.DosahMm(255, tau0, 30 * PrusakDosah.MsDen, (long)(pv0.PobrezMaxM * 1000));
            sb.AppendLine(FormattableString.Invariant($"| {id} {m.Key} | {koef.Koef(id)} | {m.KMs:E1} | {pasy[30].Material(id, spady[0]):F2} | {pasy[30].Material(id, spady[1]):F2} | {pasy[30].Material(id, spady[2]):F2} | {pasy[7].Material(id, 50):F2} | {pasy[90].Material(id, 50):F2} | {bez / 1000.0:F2} |"));
        }
        Console.Write(sb);
        return 0;
    }

    /// <summary>Břehy seedu: sken mřížky 64 m, přechod moře/pevnina po osách, šířka pásu a dominantní materiál; kandidáti řezů.</summary>
    public static int Brehy(string[] a, DataSveta d)
    {
        // pobrezi brehy <seed> <kesdir> [krok_m]
        long seed = long.Parse(a[2]); string kes = a[3]; double krok = a.Length > 4 ? double.Parse(a[4], C) : 64;
        var p = new ParametrySveta { Seed = seed };
        var pe0 = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)); p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(pe0.PlanetaXM, pe0.PlanetaYM) + pe0.PasProlnutiM);
        var sv = KonfiguraceSveta.Sestav(p, d, kes, 8);
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var pv = VodaBlok.Priznaky(ParametryVody.ZJson(File.ReadAllText(d.VodaV1))) with { PrusakPobrezi = true };
        var fn = sv.Voda(kat, pv, File.ReadAllText(d.PrusakV1));
        var pas = fn.Pas!; var g = sv.Geologie; var more = g.Svet.More!;
        bool Mo(double x, double y) => more.JeMore(x, y, g.Povrch(x, y));
        int nx = (int)(g.Svet.P.PlanetaXM / krok), ny = (int)(g.Svet.P.PlanetaYM / krok);
        var body = new List<(double x, double y, double ux, double uy, double w, int mat, double h)>();
        for (int j = 0; j < ny; j++)
        for (int i = 0; i + 1 < nx; i++)
        {
            double x = i * krok, y = (j + 0.5) * krok;
            bool s0 = Mo(x, y), s1 = Mo(x + krok, y);
            if (s0 == s1) continue;
            double lo = x, hi = x + krok;   // hranice moře/pevnina
            for (int it = 0; it < 7; it++) { double m = 0.5 * (lo + hi); if (Mo(m, y) == s0) lo = m; else hi = m; }
            double sx = s0 ? lo : hi, ux = s0 ? 1 : -1;   // bod moře u břehu, směr z moře na pevninu
            double sp = g.Povrch(sx, y); var col = g.Sloupec(sx, y);
            if (!s0) { sx = hi; }
            // pevnina o 3 m dál (kvůli povrchu a sloupci)
            double lx = sx + ux * 3; double lh = g.Povrch(lx, y);
            var lc = g.Sloupec(lx, y);
            double w = pas.Sirka(lc, lh, 5000); int mat = pas.Dominantni(lc, lh, 5000);
            body.Add((sx, y, ux, 0, w, mat, lh));
        }
        Console.WriteLine($"seed {seed}: přechodů moře/pevnina po ose x: {body.Count}");
        var hist = new[] { (0.0, 0.01), (0.01, 1.0), (1.0, 3.0), (3.0, 6.0), (6.0, 10.0), (10.0, 15.99), (15.99, 1e9) };
        foreach (var (lo, hi) in hist) Console.WriteLine($"  šířka {lo:F2}–{hi:F2} m: {body.Count(b => b.w >= lo && b.w < hi)}");
        foreach (var gr in body.GroupBy(b => b.mat).OrderByDescending(x => x.Count()).Take(8))
            Console.WriteLine($"  materiál {gr.Key} {kat.Najdi(gr.Key)?.Key}: {gr.Count()} břehů, šířka {gr.Average(b => b.w):F2} m (min {gr.Min(b => b.w):F2}, max {gr.Max(b => b.w):F2})");
        var bl = body.Select(b => ((int)Math.Floor(b.x / 128.0), (int)Math.Floor(b.y / 128.0))).Distinct().ToList();
        Console.WriteLine("bloky u břehu (bx,by): " + string.Join(" ", bl.Where((_, i) => i % Math.Max(1, bl.Count / 5) == 0).Take(5).Select(t => $"{t.Item1},{t.Item2}")) + $"  (celkem {bl.Count})");
        // kandidáti řezů: pro mat 66, 3/55, ostatní: pevnina stoupá (povrch +10 m do 60 m od břehu), blízko startu mimo
        foreach (var (jm, ids) in new[] { ("štěrk", new[] { 66 }), ("písek", new[] { 3, 55 }), ("kras", new[] { 5, 44, 49, 56 }), ("zvětralé", new[] { 57, 60, 46 }) })
        {
            var kand = body.Where(b => ids.Contains(b.mat)).Take(400).ToList();
            Console.WriteLine($"kandidáti {jm}: {kand.Count}");
            foreach (var b in kand.Where((_, i) => i % Math.Max(1, kand.Count / 6) == 0).Take(6))
                Console.WriteLine(FormattableString.Invariant($"  řez od x {b.x - 40 * b.ux:F1} y {b.y:F1} směr {b.ux:F0} 0: šířka {b.w:F2} m, povrch u břehu {b.h:F1} m"));
        }
        return 0;
    }

    /// <summary>Vliv zapnutí na bloky 128 m kolem pobřeží: otisk vody a počet pramenů, vypnuto vs. zapnuto.</summary>
    public static int Vliv(string[] a, DataSveta d)
    {
        // pobrezi vliv <seed> <kesdir> <bx,by> [<bx,by> ...]
        long seed = long.Parse(a[2]); string kes = a[3];
        var p = new ParametrySveta { Seed = seed };
        var pe0 = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)); p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(pe0.PlanetaXM, pe0.PlanetaYM) + pe0.PasProlnutiM);
        var sv = KonfiguraceSveta.Sestav(p, d, kes, 8);
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var pv0 = ParametryVody.ZJson(File.ReadAllText(d.VodaV1)); var json = File.ReadAllText(d.PrusakV1);
        var vyp = sv.Voda(kat, pv0, json); var zap = sv.Voda(kat, pv0 with { PrusakPobrezi = true }, json);
        var zapB = sv.Voda(kat, pv0 with { PrusakPobrezi = true, PrusakTlak = false }, json);
        foreach (var s in a.Skip(4))
        {
            var t = s.Split(','); int bx = int.Parse(t[0]), by = int.Parse(t[1]);
            var b0 = vyp.Blok(bx, by, 2.0, true); var b1 = zap.Blok(bx, by, 2.0, true); var b2 = zapB.Blok(bx, by, 2.0, true);
            int zm = 0; double mx = 0, sum = 0; int more = 0;
            for (int k = 0; k < b0.L.Length; k++) { double dl = Math.Abs(b1.Surova[k] - b0.Surova[k]); if (dl > 1e-9) { zm++; mx = Math.Max(mx, dl); sum += dl; } if (b0.Povrch[k] < 60) more++; }
            Console.WriteLine($"seed {seed} blok {bx},{by}: otisk vypnuto {OtiskVody.Blok(b0)} ({b0.Prameny.Count} pramenů), zapnuto {OtiskVody.Blok(b1)} ({b1.Prameny.Count}), zapnuto bez tlaku {OtiskVody.Blok(b2)} ({b2.Prameny.Count}); změněných bodů hladiny {zm}/{b0.L.Length} (max {mx:F2} m, průměr {(zm > 0 ? sum / zm : 0):F2} m), bodů v moři {more}");
        }
        return 0;
    }
}
