using System.Diagnostics;
using System.Globalization;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>Krok 6: měření eroze světa (mapa, časy, paměť, otisk, šev, toky, vodníci, vliv na otisky, výpisy pro obrázky).</summary>
public static class ErozeNastroj
{
    static readonly CultureInfo C = CultureInfo.InvariantCulture;

    public static ParametryEroze Parametry(DataSveta d, double krok) =>
        ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)) with { KrokM = krok };

    /// <summary>Start svět s planetárním svet_max_m: povrch na mřížce 1 m a otisk kroku 3 musí zůstat stejné.</summary>
    public static int SvetMax(DataSveta d)
    {
        var pe = Parametry(d, 32);
        var a = new SvetFn(new ParametrySveta(), d);
        var b = ErozePlanety.SvetPlanety(new ParametrySveta(), d, pe);
        double max = 0; var p = new ParametrySveta();
        double ox = p.StartBlok[0] * p.BlokM - p.BlokM, oy = p.StartBlok[1] * p.BlokM - p.BlokM;
        for (int i = 0; i < 384; i++) for (int j = 0; j < 384; j++)
            max = Math.Max(max, Math.Abs(a.Vyska(ox + i + 0.5, oy + j + 0.5) - b.Vyska(ox + i + 0.5, oy + j + 0.5)));
        Console.WriteLine($"svet_max {a.SvetM} vs {b.SvetM}: max |Δ povrch| start 3×3 (1 m) = {max:G6}; sopek {a.Sopky.Seznam.Count} vs {b.Sopky.Seznam.Count}");
        var pp = new ParametrySveta { SvetMaxM = b.SvetM };
        var (o, _, _) = OtiskKrok3.Spocti(pp, d);
        Console.WriteLine($"det3 s svet_max {b.SvetM}: {o}");
        return max == 0 ? 0 : 1;
    }

    public static int Mapa(string[] a, DataSveta d)
    {
        // eroze mapa <krok> <vlaken> [vystup_dir]
        double krok = double.Parse(a[2], C); int vl = int.Parse(a[3]); string? outDir = a.Length > 4 ? a[4] : null;
        var pe = Parametry(d, krok);
        var sw = Stopwatch.StartNew();
        var svet = ErozePlanety.SvetPlanety(new ParametrySveta(), d, pe);
        long tSvet = sw.ElapsedMilliseconds;
        var m = VypocetEroze.Spocti(ErozePlanety.Podklad(svet, pe), pe, vl, out var casy);
        m.KlicKese = SouborMapy.KlicKese(svet.Sd, pe, d.SouborySveta);
        sw.Restart();
        var toky = SitToku.Toky(m);
        var vod = Vodnici.Najdi(m, svet, pe);
        long tSit = sw.ElapsedMilliseconds;
        var proc = Process.GetCurrentProcess(); proc.Refresh();
        Console.WriteLine($"mapa {krok} m {m.T.Nx}×{m.T.Ny} ({m.T.N} uzlů), vláken {vl}");
        Console.WriteLine($"  čas: svět {tSvet} ms, podklad {casy.PodkladMs} ms, eroze {casy.ErozeMs} ms, síť {casy.SitMs + tSit} ms, celkem {tSvet + casy.PodkladMs + casy.ErozeMs + casy.SitMs + tSit} ms");
        Console.WriteLine($"  paměť: špička pracovní sady {proc.PeakWorkingSet64 / 1048576} MB, mapa {m.PametBajtu / 1048576.0:F1} MB");
        Console.WriteLine($"  otisk {SouborMapy.Otisk(m)}  klíč keše {m.KlicKese[..16]}");
        Statistiky(m, toky, vod, pe);
        Sev(m, svet, pe);
        if (outDir is not null)
        {
            Directory.CreateDirectory(outDir);
            string f = Path.Combine(outDir, $"eroze_{krok}.wger");
            sw.Restart(); SouborMapy.Uloz(f, m, svet.Sd); long tU = sw.ElapsedMilliseconds;
            sw.Restart(); var n = SouborMapy.Nacti(f, m.KlicKese)!; long tN = sw.ElapsedMilliseconds;
            Console.WriteLine($"  soubor {new FileInfo(f).Length / 1048576.0:F1} MB, uložení {tU} ms, načtení {tN} ms, otisk po načtení {SouborMapy.Otisk(n)}");
            Vypis(Path.Combine(outDir, $"mapa_{krok}"), m);
            File.WriteAllLines(Path.Combine(outDir, $"vodnici_{krok}.csv"),
                vod.Select(v => FormattableString.Invariant($"{v.X},{v.Y},{v.QLs:F3},{v.PlochaKm2:F4}")).Prepend("x,y,q_ls,plocha_km2"));
            File.WriteAllLines(Path.Combine(outDir, $"toky_{krok}.csv"),
                toky.Select(t => FormattableString.Invariant($"{t.Pramen},{t.Konec},{t.DelkaM:F1},{t.Uzlu}")).Prepend("pramen,konec,delka_m,uzlu"));
        }
        return 0;
    }

    static void Statistiky(MapaEroze m, List<Tok> toky, List<Vodnik> vod, ParametryEroze pe)
    {
        int n = m.T.N; double sE = 0, maxE = 0; int e05 = 0, jez = 0, kor = 0, odt = 0;
        for (int k = 0; k < n; k++)
        {
            double e = m.E(k); sE += e; if (e > maxE) maxE = e; if (e > 0.5) e05++;
            if ((m.Priznaky[k] & MapaEroze.Jezero) != 0) jez++;
            if ((m.Priznaky[k] & MapaEroze.Koryto) != 0) kor++;
            if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) odt++;
        }
        var l = toky.Select(t => t.DelkaM).OrderBy(x => x).ToArray();
        double Med(double[] x) => x.Length == 0 ? 0 : x[x.Length / 2];
        Console.WriteLine($"  eroze: průměr {sE / n:F3} m, max {maxE:F2} m, uzlů s E>0,5 m {100.0 * e05 / n:F1} %; jezera {100.0 * jez / n:F2} %, odtok {100.0 * odt / n:F2} %, koryta {100.0 * kor / n:F2} %");
        Console.WriteLine($"  toky: {toky.Count}, délka medián {Med(l):F0} m, průměr {(l.Length > 0 ? l.Average() : 0):F0} m, max {(l.Length > 0 ? l[^1] : 0):F0} m, koryta celkem {SitToku.DelkaKoryt(m) / 1000:F1} km");
        var q = vod.Select(v => v.QLs).OrderBy(x => x).ToArray();
        Console.WriteLine($"  vodníci: {vod.Count} (z {toky.Count} pramenů toků), Q medián {Med(q):F2} l/s, max {(q.Length > 0 ? q[^1] : 0):F2} l/s, hustota {vod.Count / (pe.PlanetaXM * pe.PlanetaYM / 1e6):F2} /km²");
    }

    /// <summary>Periodicita: f(x) = f(x + Px) a skok přes šev vs. běžný krok 0,25 m (jemná funkce s erozí).</summary>
    static void Sev(MapaEroze m, SvetFn svet, ParametryEroze pe)
    {
        var pod = ErozePlanety.Podklad(svet, pe); var ef = new ErozeSvetaFn(m, pe);
        double F(double x, double y) => pod.Vyska(x, y) - ef.Hloubka(x, y);
        double maxPer = 0, maxSevX = 0, maxSevY = 0, maxBezny = 0;
        var rnd = new Random(6);
        for (int s = 0; s < 4000; s++)
        {
            double x = rnd.NextDouble() * pe.PlanetaXM, y = rnd.NextDouble() * pe.PlanetaYM;
            maxPer = Math.Max(maxPer, Math.Abs(F(x, y) - F(x + pe.PlanetaXM, y - pe.PlanetaYM)));
            maxSevX = Math.Max(maxSevX, Math.Abs(F(pe.PlanetaXM - 0.125, y) - F(0.125, y)));
            maxSevY = Math.Max(maxSevY, Math.Abs(F(x, pe.PlanetaYM - 0.125) - F(x, 0.125)));
            maxBezny = Math.Max(maxBezny, Math.Abs(F(x - 0.125, y) - F(x + 0.125, y)));
        }
        Console.WriteLine($"  šev: max |f(x)−f(x+P)| {maxPer:G4} m; skok přes šev X {maxSevX:F3} m, Y {maxSevY:F3} m; běžný krok 0,25 m max {maxBezny:F3} m");
    }

    static void Vypis(string zaklad, MapaEroze m)
    {
        using var w = new BinaryWriter(File.Create(zaklad + ".bin"));
        w.Write(m.T.Nx); w.Write(m.T.Ny); w.Write(m.T.Krok);
        foreach (var x in m.H0) w.Write(x);
        foreach (var x in m.H) w.Write(x);
        foreach (var x in m.A) w.Write(x);
        w.Write(m.Priznaky);
    }

    /// <summary>Otisky kroku 3 a vody 14,14 s erozí zapnutou (mapa ze souboru) a vypnutou.</summary>
    public static int Otisky(string[] a, DataSveta d)
    {
        string f = a[2]; double krok = double.Parse(a[3], C);
        var pe = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(new ParametrySveta(), d, pe);
        var m = SouborMapy.Nacti(f, SouborMapy.KlicKese(svet.Sd, pe, d.SouborySveta)) ?? throw new Exception("mapa nesedí s klíčem");
        var ef = new ErozeSvetaFn(m, pe); var vod = Vodnici.Najdi(m, svet, pe);
        var (o0, _, _) = OtiskKrok3.Spocti(new ParametrySveta(), d);
        var (o1, _, _) = OtiskKrok3.Spocti(new ParametrySveta(), d, uprav: g => g.Svet.Eroze = ef);
        Console.WriteLine($"det3: vypnuto {o0}, eroze {o1}");
        var v0 = VodaBlok.Spust(true, d);
        var v1 = VodaBlok.Spust(true, d, geo: g => g.Svet.Eroze = ef);
        var v2 = VodaBlok.Spust(true, d, geo: g => g.Svet.Eroze = ef,
            uprav: fn => fn.Prameny.Vodnici = new VodniciVeSvete(vod, fn.Geologie).VOblasti);
        Console.WriteLine($"voda 14,14: vypnuto {v0.otisk} ({v0.pramenu} pramenů), eroze {v1.otisk} ({v1.pramenu}), eroze+vodníci {v2.otisk} ({v2.pramenu})");
        int vStart = vod.Count(v => v.X >= 1792 && v.X < 2176 && v.Y >= 1792 && v.Y < 2176);
        Console.WriteLine($"vodníků ve start světě 3×3: {vStart}");
        var bl = vod.OrderBy(v => (v.X - 2048) * (v.X - 2048) + (v.Y - 2048) * (v.Y - 2048)).First();
        int bx = (int)Math.Floor(bl.X / 128), by = (int)Math.Floor(bl.Y / 128);
        var b0 = VodaBlok.Spust(true, d, bx, by, geo: g => g.Svet.Eroze = ef);
        var b1 = VodaBlok.Spust(true, d, bx, by, geo: g => g.Svet.Eroze = ef,
            uprav: fn => fn.Prameny.Vodnici = new VodniciVeSvete(vod, fn.Geologie).VOblasti);
        Console.WriteLine(FormattableString.Invariant($"nejbližší vodník ke startu ({bl.X},{bl.Y}) Q {bl.QLs:F2} l/s, blok {bx},{by}: bez vodníků {b0.otisk} ({b0.pramenu}), s vodníky {b1.otisk} ({b1.pramenu})"));
        return 0;
    }

    /// <summary>Detail bloku: povrch 0,25 m před a po erozi (float32 výpis pro obrázek).</summary>
    public static int Detail(string[] a, DataSveta d)
    {
        // eroze detail <mapa.wger> <krok> <x0> <y0> <strana> <vystup.bin>
        string f = a[2]; double krok = double.Parse(a[3], C), x0 = double.Parse(a[4], C), y0 = double.Parse(a[5], C), s = double.Parse(a[6], C);
        var pe = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(new ParametrySveta(), d, pe);
        var m = SouborMapy.Nacti(f, SouborMapy.KlicKese(svet.Sd, pe, d.SouborySveta))!;
        var pod = ErozePlanety.Podklad(svet, pe); var ef = new ErozeSvetaFn(m, pe);
        int n = (int)(s / 0.25);
        using var w = new BinaryWriter(File.Create(a[7]));
        w.Write(n);
        var h0 = new float[n * n]; var h1 = new float[n * n];
        Parallel.For(0, n, j => { for (int i = 0; i < n; i++) { double x = x0 + (i + 0.5) * 0.25, y = y0 + (j + 0.5) * 0.25; double b = pod.Vyska(x, y); h0[j * n + i] = (float)b; h1[j * n + i] = (float)(b - ef.Hloubka(x, y)); } });
        foreach (var v in h0) w.Write(v);
        foreach (var v in h1) w.Write(v);
        return 0;
    }
}
