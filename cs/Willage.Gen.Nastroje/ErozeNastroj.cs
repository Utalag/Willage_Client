using System.Diagnostics;
using System.Globalization;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Nastroje;

/// <summary>Krok 6: měření eroze světa (mapa, časy, paměť, otisk, šev, toky, vodníci, vliv na otisky, výpisy pro obrázky).</summary>
public static class ErozeNastroj
{
    static readonly CultureInfo C = CultureInfo.InvariantCulture;
    /// <summary>Volby: --more (krok 6b moře + sklon), --sklon S, --interp bilinearni|catmullrom|bspline.</summary>
    public static bool More, Panve; public static long? Seed; public static double? Sklon; public static string? Interp;

    public static string[] Volby(string[] a)
    {
        var r = new List<string>();
        for (int i = 0; i < a.Length; i++)
        {
            if (a[i] == "--more") More = true;
            else if (a[i] == "--sklon") Sklon = double.Parse(a[++i], C);
            else if (a[i] == "--interp") Interp = a[++i];
            else if (a[i] == "--hladina-krok4") { PrizpusobPrameny = true; UpravaPramenu = pv => pv with { HladinaSledujeErozi = false }; }
            else if (a[i] == "--panve") Panve = true;
            else if (a[i] == "--seed") Seed = long.Parse(a[++i]);
            else r.Add(a[i]);
        }
        return r.ToArray();
    }

    public static DataSveta? D;
    public static ParametrySveta Ps()
    {
        var p = new ParametrySveta { More = More, Panve = Panve };
        if (D is not null) ErozePlanety.NactiMore(p, D);
        if (Seed is long sd) p.Seed = sd;
        if (Sklon is double s) p.SklonKontinentu = s;
        return p;
    }

    public static ParametryEroze Parametry(DataSveta d, double krok)
    {
        var p = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)) with { KrokM = krok };
        return Interp is null ? p : p with { InterpolaceE = Interp };
    }

    /// <summary>Start svět s planetárním svet_max_m: povrch na mřížce 1 m a otisk kroku 3 musí zůstat stejné.</summary>
    public static int SvetMax(DataSveta d)
    {
        var pe = Parametry(d, 32);
        var a = new SvetFn(new ParametrySveta(), d);
        var b = ErozePlanety.SvetPlanety(Ps(), d, pe);
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
        var svet = ErozePlanety.SvetPlanety(Ps(), d, pe);
        long tSvet = sw.ElapsedMilliseconds;
        var m = VypocetEroze.Spocti(ErozePlanety.Podklad(svet, pe), pe, vl, out var casy);
        m.KlicKese = ErozePlanety.Klic(svet, d, pe);
        sw.Restart();
        var toky = SitToku.Toky(m);
        var vod = Vodnici.Najdi(m, svet, pe);
        long tSit = sw.ElapsedMilliseconds;
        var proc = Process.GetCurrentProcess(); proc.Refresh();
        if (svet.More is { } ms) Console.WriteLine(FormattableString.Invariant($"  moře: seed {svet.Sd}, cílový podíl {100 * ms.Podil:F1} %, pás P {ms.Pas:F0} m, střed {ms.Stred:F0} m, start na pevnině {ms.StartNaPevnine}, start bez posunu {ms.StartBezPosunu}; pánví {svet.Panve?.Stredy.Count ?? 0}"));
        Console.WriteLine($"mapa {krok} m {m.T.Nx}×{m.T.Ny} ({m.T.N} uzlů), vláken {vl}");
        Console.WriteLine($"  čas: svět {tSvet} ms, podklad {casy.PodkladMs} ms, eroze {casy.ErozeMs} ms, síť {casy.SitMs + tSit} ms, celkem {tSvet + casy.PodkladMs + casy.ErozeMs + casy.SitMs + tSit} ms");
        Console.WriteLine($"  paměť: špička pracovní sady {proc.PeakWorkingSet64 / 1048576} MB, mapa {m.PametBajtu / 1048576.0:F1} MB");
        Console.WriteLine($"  otisk {SouborMapy.Otisk(m)}  klíč keše {m.KlicKese[..16]}");
        Statistiky(m, toky, vod, pe);
        RekyStat(m);
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

    static void RekyStat(MapaEroze m)
    {
        var r = Reky.Najdi(m);
        var l = r.Select(x => x.DelkaM).OrderBy(x => x).ToArray();
        var p = r.Select(x => x.PovodiM2 / 1e6).OrderByDescending(x => x).Take(5).Select(x => x.ToString("F1", C));
        int more = 0; for (int k = 0; k < m.T.N; k++) if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) more++;
        Console.WriteLine($"  řeky (ústí → nejdelší pramen): {r.Count}, max {(l.Length > 0 ? l[^1] / 1000 : 0):F1} km, medián {(l.Length > 0 ? l[l.Length / 2] : 0):F0} m, > 5 km: {l.Count(x => x > 5000)}, > 10 km: {l.Count(x => x > 10000)}; odtok/moře {100.0 * more / m.T.N:F1} %");
        Console.WriteLine($"  největší povodí řek (km²): {string.Join(", ", p)}");
        var j = Jezera.Najdi(m);
        double plocha = j.Sum(x => x.PlochaM2);
        Console.WriteLine($"  jezera: {j.Count}, plocha celkem {plocha / 1e6:F1} km² ({100 * plocha / (m.T.N * m.T.Krok * m.T.Krok):F1} %), > 0,1 km²: {j.Count(x => x.PlochaM2 > 1e5)}, > 1 km²: {j.Count(x => x.PlochaM2 > 1e6)}; největší (km²/hloubka m): {string.Join(", ", j.Take(5).Select(x => FormattableString.Invariant($"{x.PlochaM2 / 1e6:F2}/{x.MaxHloubkaM:F1}")))}");
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
        foreach (var x in m.Vypln) w.Write(x);
        w.Write(m.Priznaky);
    }

    /// <summary>Otisky kroku 3 a vody 14,14: výchozí, moře, moře + eroze, moře + eroze + vodníci (mapa ze souboru s --more).</summary>
    public static int Otisky(string[] a, DataSveta d)
    {
        string f = a[2]; double krok = double.Parse(a[3], C);
        var pe = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(Ps(), d, pe);
        var m = SouborMapy.Nacti(f, ErozePlanety.Klic(svet, d, pe)) ?? throw new Exception("mapa nesedí s klíčem");
        var ef = new ErozeSvetaFn(m, pe); var vod = Vodnici.Najdi(m, svet, pe);
        Func<ParametryVody, ParametryVody>? voda = PrizpusobPrameny ? UpravaPramenu : null;
        void Radek(string jmeno, ParametrySveta ps, bool eroze, bool vodnici)
        {
            var (o, _, _) = OtiskKrok3.Spocti(ps, d, uprav: eroze ? g => g.Svet.Eroze = ef : null);
            int p33 = 0;
            var v = VodaBlok.Spust(true, d, svet: ps, voda: eroze ? voda : null, geo: eroze ? g => g.Svet.Eroze = ef : null,
                uprav: fn =>
                {
                    if (vodnici) fn.Prameny.Vodnici = new VodniciVeSvete(vod, fn.Geologie).VOblasti;
                    p33 = fn.Prameny.VOblasti(1792, 1792, 2176, 2176).Count;
                });
            Console.WriteLine($"{jmeno,-28} krok 3 {o}   voda 14,14 {v.otisk} ({v.pramenu} pramenů; 3×3: {p33})");
        }
        Radek("výchozí (vše vypnuto)", new ParametrySveta(), false, false);
        if (More) Radek("moře + sklon", Ps(), false, false);
        Radek("eroze", Ps(), true, false);
        Radek("eroze + vodníci", Ps(), true, true);
        // start svět 3 × 3 na pevnině?
        var sv = new SvetFn(Ps(), d); int more = 0, n = 0; double minPev = 1, minH = 1e9, maxPos = -1e9, minPos = 1e9;
        for (double x = 1792; x < 2176; x += 4) for (double y = 1792; y < 2176; y += 4)
        {
            n++; double h = sv.Vyska(x, y); minH = Math.Min(minH, h);
            if (sv.More is { } ms) { minPev = Math.Min(minPev, ms.Pevnina(x, y)); if (ms.JeMore(x, y, h)) more++; double o = ms.Posun(x, y); maxPos = Math.Max(maxPos, o); minPos = Math.Min(minPos, o); }
        }
        Console.WriteLine($"start 3×3: moře {more}/{n} bodů, min podíl pevniny {minPev:F3}, min povrch {minH:F2} m, posun moře/sklonu {minPos:F2}…{maxPos:F2} m");
        int vStart = vod.Count(v => v.X >= 1792 && v.X < 2176 && v.Y >= 1792 && v.Y < 2176);
        Console.WriteLine($"vodníků ve start světě 3×3: {vStart}");
        return 0;
    }

    /// <summary>Krok 6b: interpolace E – odchylka v uzlech, skok gradientu přes hrany buněk, max E, čas.</summary>
    public static int InterpMer(string[] a, DataSveta d)
    {
        string f = a[2]; double krok = double.Parse(a[3], C);
        var pe0 = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(Ps(), d, pe0);
        var m = SouborMapy.Nacti(f, ErozePlanety.Klic(svet, d, pe0)) ?? throw new Exception("mapa nesedí s klíčem");
        foreach (var mode in new[] { "bilinearni", "catmullrom", "bspline" })
        {
            var ef = new ErozeSvetaFn(m, pe0 with { InterpolaceE = mode });
            var rnd = new Random(7); double odch = 0, odchMax = 0, skok = 0, skokMax = 0, maxE = 0; int n = 20000;
            for (int s = 0; s < n; s++)
            {
                int k = rnd.Next(m.T.N); var (x, y) = m.T.Poloha(k);
                double o = Math.Abs(ef.ErozeE(x, y) - m.E(k)); odch += o; odchMax = Math.Max(odchMax, o);
                double yy = y + rnd.NextDouble() * krok, e = 0.01;
                double gl = (ef.ErozeE(x, yy) - ef.ErozeE(x - e, yy)) / e, gr = (ef.ErozeE(x + e, yy) - ef.ErozeE(x, yy)) / e;
                double j = Math.Abs(gr - gl); skok += j; skokMax = Math.Max(skokMax, j);
                maxE = Math.Max(maxE, ef.ErozeE(x + rnd.NextDouble() * krok, yy));
            }
            var sw = Stopwatch.StartNew(); double sum = 0;
            for (int i = 0; i < 1_000_000; i++) sum += ef.ErozeE(1000 + i * 0.013, 2000 + i * 0.007);
            Console.WriteLine($"{mode,-11} odchylka v uzlech průměr {odch / n:F4} max {odchMax:F3} m; skok gradientu na hraně průměr {skok / n:F4} max {skokMax:F3}; max E {maxE:F2} m; {sw.Elapsed.TotalMilliseconds:F0} ns/dotaz");
        }
        return 0;
    }

    public static bool PrizpusobPrameny;
    public static Func<ParametryVody, ParametryVody> UpravaPramenu = pv => pv;

    /// <summary>Diagnostika pramenů bloku: vývěr, materiál povrchu v zóně vývěru, kandidáti buněk (vypnuto vs. eroze).</summary>
    public static int PramenyDiag(string[] a, DataSveta d)
    {
        string f = a[2]; double krok = double.Parse(a[3], C); int bx = a.Length > 4 ? int.Parse(a[4]) : 14, by = a.Length > 5 ? int.Parse(a[5]) : 14;
        var pe = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(Ps(), d, pe);
        var m = SouborMapy.Nacti(f, ErozePlanety.Klic(svet, d, pe)) ?? throw new Exception("mapa nesedí s klíčem");
        var ef = new ErozeSvetaFn(m, pe);
        foreach (bool er in new[] { false, true })
        {
            var fn = VodaBlok.Fn(true, d, PrizpusobPrameny && er ? UpravaPramenu : null, er ? g => g.Svet.Eroze = ef : null, Ps());
            int vyv = 0, n = 0; var mat = new SortedDictionary<int, int>(); double sE = 0;
            for (double x = bx * 128 + 1; x < bx * 128 + 128; x += 2)
            for (double y = by * 128 + 1; y < by * 128 + 128; y += 2)
            {
                n++; sE += ef.Hloubka(x, y);
                if (!fn.Hladina.Vyver(x, y)) continue;
                vyv++;
                var col = fn.Geologie.Sloupec(x, y); double pov = fn.Geologie.Povrch(x, y);
                int kt = Math.Clamp((int)Math.Floor((pov - 1e-9) / 0.25), 0, col.Length - 1);
                mat[col[kt]] = mat.GetValueOrDefault(col[kt]) + 1;
            }
            int kand = 0, b24 = 0;
            for (int cx = (int)Math.Floor(bx * 128 / 24.0); cx <= (int)Math.Floor((bx * 128 + 127.9) / 24.0); cx++)
            for (int cy = (int)Math.Floor(by * 128 / 24.0); cy <= (int)Math.Floor((by * 128 + 127.9) / 24.0); cy++)
            { b24++; if (fn.Prameny.Kandidat(cx, cy) is not null) kand++; }
            foreach (var pr in fn.Prameny.VOblasti(bx * 128, by * 128, bx * 128 + 128, by * 128 + 128))
                Console.WriteLine(FormattableString.Invariant($"   pramen {pr.X},{pr.Y} {pr.Druh} buňka {pr.BunkaX},{pr.BunkaY} povrch {fn.Geologie.Povrch(pr.X, pr.Y):F2} hladina {fn.Hladina.Surova(pr.X, pr.Y):F2} E {ef.Hloubka(pr.X, pr.Y):F2}"));
            for (int cx = (int)Math.Floor(bx * 128 / 24.0); cx <= (int)Math.Floor((bx * 128 + 127.9) / 24.0); cx++)
            for (int cy = (int)Math.Floor(by * 128 / 24.0); cy <= (int)Math.Floor((by * 128 + 127.9) / 24.0); cy++)
                if (fn.Prameny.Kandidat(cx, cy) is { } kd) Console.WriteLine(FormattableString.Invariant($"   kandidát {cx},{cy}: {kd.X},{kd.Y} {kd.Druh} výsledný {(fn.Prameny.Vysledny(cx, cy) is null ? "ne (rozestup)" : "ano")}"));
            Console.WriteLine($"{(er ? "eroze" : "vypnuto"),-8} vývěr {vyv}/{n} bodů 2 m; materiál povrchu ve vývěru: {string.Join(" ", mat.Select(k => $"{k.Key}:{k.Value}"))}; kandidátů {kand}/{b24} buněk; průměrná hloubka eroze {(er ? sE / n : 0):F2} m");
        }
        return 0;
    }

    /// <summary>Detail bloku: povrch 0,25 m před a po erozi (float32 výpis pro obrázek).</summary>
    public static int Detail(string[] a, DataSveta d)
    {
        // eroze detail <mapa.wger> <krok> <x0> <y0> <strana> <vystup.bin>
        string f = a[2]; double krok = double.Parse(a[3], C), x0 = double.Parse(a[4], C), y0 = double.Parse(a[5], C), s = double.Parse(a[6], C);
        var pe = Parametry(d, krok);
        var svet = ErozePlanety.SvetPlanety(Ps(), d, pe);
        var m = SouborMapy.Nacti(f, ErozePlanety.Klic(svet, d, pe))!;
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
