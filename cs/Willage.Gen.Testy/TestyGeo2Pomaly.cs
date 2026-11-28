using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// Diagnostika pomalých bloků GEO2 (<c>--jen=GEO2POMALY --seed=7 --blok=ox,oy[,krokXy[,vlaken]] [--csv=soubor]</c>):
/// čas <c>KontextBloku.Sloupec</c>, počet volání <c>Bod</c>, kroků chůze kontaktu, alokací a běhů na sloupec; rozdělení nákladů.
/// Jen měření, geologii nemění.
/// </summary>
public static class TestyGeo2Pomaly
{
    public static void Spust(string data, long seed, double ox, double oy, double krokXy, int vlaken, string? csv)
    {
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g0 = new GeologieCs(new ParametrySveta { Seed = seed }, d);
        var sw = Stopwatch.StartNew();
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), null, vlaken);
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        double tKontext = sw.Elapsed.TotalSeconds;
        int n = (int)Math.Round(128 / krokXy), N = n * n;
        var cas = new double[N]; var bod = new int[N]; var chuze = new int[N]; var alok = new long[N]; var behy = new int[N]; var plati = new int[N]; var nejbl = new int[N]; var pred = new int[N]; var dot = new int[N]; var hran = new int[N]; var hranMs = new float[N]; var zp = new float[N];
        var cpuVlakno = new List<double>();
        ZasobnikVrstvySloupce.DiagCas = true;
        sw.Restart();
        Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, () => (new Vzorek[512], new List<Beh>(), 0.0, Environment.CurrentManagedThreadId), (ix, _, st) =>
        {
            var (v2, bl, t, id) = st; var s2 = new Stopwatch();
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy; int i = ix * n + iy;
                long b0 = SloupecGeo2.VolaniBod, c0 = KontaktniPasmo.KrokuChuze, a0 = GC.GetAllocatedBytesForCurrentThread(), p0 = KontaktniPasmo.DiagPlati, n0 = KontaktniPasmo.DiagNejblizsi, r0 = KontaktniPasmo.DiagPred, d0 = ZasobnikVrstvySloupce.DiagDotazy, h0 = ZasobnikVrstvySloupce.DiagHranic, t0 = ZasobnikVrstvySloupce.DiagTiku;
                s2.Restart(); k.Sloupec(x, y, 0, 0.25, v2); s2.Stop();
                alok[i] = GC.GetAllocatedBytesForCurrentThread() - a0; bod[i] = (int)(SloupecGeo2.VolaniBod - b0); chuze[i] = (int)(KontaktniPasmo.KrokuChuze - c0);
                cas[i] = s2.Elapsed.TotalSeconds; plati[i] = (int)(KontaktniPasmo.DiagPlati - p0); nejbl[i] = (int)(KontaktniPasmo.DiagNejblizsi - n0); pred[i] = (int)(KontaktniPasmo.DiagPred - r0); dot[i] = (int)(ZasobnikVrstvySloupce.DiagDotazy - d0); hran[i] = (int)(ZasobnikVrstvySloupce.DiagHranic - h0); hranMs[i] = (float)((ZasobnikVrstvySloupce.DiagTiku - t0) * 1e3 / Stopwatch.Frequency); t += cas[i]; zp[i] = (float)k.Povrch(x, y);
                k.Behy(x, y, 128, bl); behy[i] = bl.Count;
            }
            return (v2, bl, t, id);
        }, st => { lock (cpuVlakno) cpuVlakno.Add(st.Item3); });
        double wall = sw.Elapsed.TotalSeconds;
        Console.WriteLine($"- seed {seed}, blok ({ox}, {oy}), {n}×{n} sloupců, {vlaken} vláken: kontext {tKontext:F2} s, sloupce stěna {wall:F2} s, součet času sloupců {cas.Sum():F2} s");
        Console.WriteLine($"  součet času po vláknech: max {cpuVlakno.Max():F2} s, min {cpuVlakno.Min():F2} s");
        var idx = Enumerable.Range(0, N).OrderByDescending(i => cas[i]).ToArray(); double tot = cas.Sum();
        foreach (var p in new[] { 0.001, 0.01, 0.1, 0.5 })
        {
            int m = Math.Max(1, (int)(N * p)); double s = 0; for (int j = 0; j < m; j++) s += cas[idx[j]];
            Console.WriteLine($"  nejdražších {p * 100:F1} % sloupců ({m}) = {100 * s / tot:F1} % času");
        }
        var sorted = cas.OrderBy(v => v).ToArray();
        Console.WriteLine($"  čas sloupce: medián {sorted[N / 2] * 1e3:F3} ms, p90 {sorted[(int)(N * 0.9)] * 1e3:F3} ms, p99 {sorted[(int)(N * 0.99)] * 1e3:F3} ms, max {sorted[^1] * 1e3:F1} ms")
            ;
        Console.WriteLine($"  Bod na sloupec: součet {bod.Sum(v => (long)v):N0}, medián {bod.OrderBy(v => v).ElementAt(N / 2)}, max {bod.Max()}; chůze kontaktu součet {chuze.Sum(v => (long)v):N0}, max {chuze.Max()}; alokace {alok.Sum() / 1e6:F0} MB, max na sloupec {alok.Max() / 1e3:F0} kB; běhů součet {behy.Sum(v => (long)v):N0}, max {behy.Max()}");
        int nch = chuze.Count(v => v > 0);
        Console.WriteLine($"  sloupců s chůzí kontaktu: {nch:N0} z {N:N0} ({100.0 * nch / N:F1} %), jejich podíl času {100 * Enumerable.Range(0, N).Where(i => chuze[i] > 0).Sum(i => cas[i]) / tot:F1} %");
        Console.WriteLine($"  Plati {plati.Sum(v => (long)v):N0}, Nejblizsi {nejbl.Sum(v => (long)v):N0}, Pred {pred.Sum(v => (long)v):N0}, dotazů na hranice {dot.Sum(v => (long)v):N0}, volání Hranice {hran.Sum(v => (long)v):N0} (čas v Hranice {hranMs.Sum() / 1e3:F2} s z {tot:F2} s = {100 * hranMs.Sum() / 1e3 / tot:F1} %)");
        double cB = Korel(cas, bod.Select(v => (double)v).ToArray()), cC = Korel(cas, chuze.Select(v => (double)v).ToArray()), cA = Korel(cas, alok.Select(v => (double)v).ToArray()), cR = Korel(cas, behy.Select(v => (double)v).ToArray());
        Console.WriteLine($"  korelace času s: Bod {cB:F2}, chůze {cC:F2}, alokace {cA:F2}, běhy {cR:F2}");
        Console.WriteLine("  top 10 sloupců (x, y, ms, Bod, chůze, běhů, kB, zPov):");
        for (int j = 0; j < 10; j++) { int i = idx[j]; Console.WriteLine($"    ({ox + (i / n + 0.5) * krokXy:F2}, {oy + (i % n + 0.5) * krokXy:F2}) {cas[i] * 1e3:F1} ms, {bod[i]}, {chuze[i]}, {behy[i]}, {alok[i] / 1e3:F0}, {zp[i]:F1}");}
        // prostorové rozložení: 8×8 dlaždic, podíl času
        var dl = new double[64]; for (int i = 0; i < N; i++) dl[(i / n) * 8 / n * 8 + (i % n) * 8 / n] += cas[i];
        Console.WriteLine("  podíl času po dlaždicích 16 m (řádky = x, sloupce = y), %:");
        for (int a = 0; a < 8; a++) Console.WriteLine("    " + string.Join(' ', Enumerable.Range(0, 8).Select(b => (100 * dl[a * 8 + b] / tot).ToString("F1").PadLeft(5))));
        if (!string.IsNullOrWhiteSpace(csv))
        {
            var f = Path.GetFullPath(csv); Directory.CreateDirectory(Path.GetDirectoryName(f)!);
            using var w = new StreamWriter(f);
            w.WriteLine("x;y;cas_ms;bod;chuze;behy;alok_kb;zpov;plati;nejblizsi;pred;dotazy;hranic;hranice_ms");
            var ci = System.Globalization.CultureInfo.InvariantCulture;
            for (int i = 0; i < N; i++) w.WriteLine(string.Join(';', (ox + (i / n + 0.5) * krokXy).ToString("F3", ci), (oy + (i % n + 0.5) * krokXy).ToString("F3", ci), (cas[i] * 1e3).ToString("F4", ci), bod[i], chuze[i], behy[i], alok[i] / 1000, zp[i].ToString("F2", ci), plati[i], nejbl[i], pred[i], dot[i], hran[i], hranMs[i].ToString("F4", ci)));
        }
    }

    private static double Korel(double[] a, double[] b)
    {
        double ma = a.Average(), mb = b.Average(), sab = 0, saa = 0, sbb = 0;
        for (int i = 0; i < a.Length; i++) { double x = a[i] - ma, y = b[i] - mb; sab += x * y; saa += x * x; sbb += y * y; }
        return saa > 0 && sbb > 0 ? sab / Math.Sqrt(saa * sbb) : double.NaN;
    }
}
