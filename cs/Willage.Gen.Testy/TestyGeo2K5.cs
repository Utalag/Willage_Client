using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K5: adaptivní mřížka hranic (6.3). V5 – chyba cílových hranic proti přesnému <c>Hranice</c> po 0,25 m (sled, p99, max, strmé svahy,
/// rychlé změny mocnosti) pro adaptivní × pevnou 0,5 m, švy bloků, kontakt (skarn) proti jemné referenci 0,125 m, výkon kontextu a bloku.
/// </summary>
public static class TestyGeo2K5
{
    private static readonly (double X, double Y)[] Bloky = { (1024, 512), (3000, 2000), (0, 0), (2048, 1024), (512, 3072), (1664, 1728), (3904, 1344) }; // poslední dva: nejvíc svahů > 20° (--jen=GEO2K5S)

    /// <summary>Najde bloky 64 m s nejvíc svahy &gt; 20° (hrubé vzorkování po 8 m v oblasti 8 km); pro výběr kategorie V5.</summary>
    public static List<(double X, double Y, int N)> StrmeBloky(SvetFn s, int kolik)
    {
        var o = new List<(double, double, int)>(); double tg = Math.Tan(20 * Math.PI / 180);
        for (double bx = 0; bx < 8192; bx += 64)
        for (double by = 0; by < 8192; by += 64)
        {
            int n = 0;
            for (double x = bx + 4; x < bx + 64; x += 8)
            for (double y = by + 4; y < by + 64; y += 8)
            {
                double sx = (s.Vyska(x + 0.25, y) - s.Vyska(x - 0.25, y)) / 0.5, sy = (s.Vyska(x, y + 0.25) - s.Vyska(x, y - 0.25)) / 0.5;
                if (Math.Sqrt(sx * sx + sy * sy) > tg) n++;
            }
            if (n > 0) o.Add((bx, by, n));
        }
        return o.OrderByDescending(q => q.Item3).Take(kolik).ToList();
    }

    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var g = new GeologieCs(new ParametrySveta(), d);
        V5(kat, d, g);
        Svy(kat, d, g);
        Kontakt(kat, d, g);
    }

    private static KontaktniPasmo Skarn(KontextBloku k) => (KontaktniPasmo)k.Chronologie.Udalosti[k.Chronologie.IndexUdalosti("skarn_kontakt")].Kontakt!;

    private static (KontextBloku k, double t) Kontext(GeologieCs g, KatalogGeo2 kat, DataSveta d, OblastBloku o, double? krok)
    {
        var sw = Stopwatch.StartNew();
        var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, SadaE84.Json(d), o, new MoznostiKompilace(krok));
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        return (k, sw.Elapsed.TotalSeconds);
    }

    private sealed class Stat
    {
        public readonly List<double> Dz = new(); public long Sloupcu, Neshod, NeshodOdhad, Odhad, NadTau; public double MaxOdhad;
        public void Pridej(double[] e, double[]? u, bool odhad, double tau)
        {
            Sloupcu++;
            if (odhad) Odhad++;
            if (u is null || u.Length != e.Length) { if (odhad) NeshodOdhad++; else Neshod++; return; }
            double m = 0; for (int k = 0; k < e.Length; k++) m = Math.Max(m, Math.Abs(u[k] - e[k]));
            if (odhad) { MaxOdhad = Math.Max(MaxOdhad, m); return; }
            Dz.Add(m); if (m > tau) NadTau++;
        }
        public string Text()
        {
            var s = Dz.OrderBy(v => v).ToArray();
            double P(double q) => s.Length == 0 ? 0 : s[Math.Min(s.Length - 1, (int)(q * s.Length))];
            return $"sloupců {Sloupcu,7:N0}, neshod sledu {Neshod}, p99 {P(0.99):F3}, max {(s.Length > 0 ? s[^1] : 0):F3} m, > τ {NadTau}; v listech s odhadem {Odhad} (neshod {NeshodOdhad}, max {MaxOdhad:F3} m)";
        }
    }

    /// <summary>V5 na 5 blocích 64 m: sloupce na mřížce 0,25 m a náhodné mimo ni; adaptivní × pevná 0,5 m; kategorie svah > 20°, rychlá změna mocnosti.</summary>
    private static void V5(KatalogGeo2 kat, DataSveta d, GeologieCs g)
    {
        T.Sekce("GEO2 K5: V5 chyba cílových hranic (skarn: granitoidy) proti přesnému Hranice, adaptivní × pevná 0,5 m");
        var zas = new ZasobnikVrstvySloupce(g.Geo); var s = g.Svet;
        var aM = new Stat(); var aN = new Stat(); var aS = new Stat(); var aR = new Stat(); var pM = new Stat(); var pN = new Stat();
        long l1 = 0, l05 = 0, l025 = 0, lOdh = 0; double tA = 0, tP = 0; long uA = 0, uP = 0;
        double tau = 0;
        foreach (var (bx, by) in Bloky)
        {
            var o = OblastBloku.Ctverec(bx, by, 64);
            var (ka, ta) = Kontext(g, kat, d, o, null); var (kp, tp) = Kontext(g, kat, d, o, 0.5);
            tA += ta; tP += tp;
            var pa = (PlochaVrstevAdaptivni)Skarn(ka).Plochy[0]; var pp = (PlochaVrstev)Skarn(kp).Plochy[0];
            tau = pa.TauM; uA += pa.SpoctenychUzlu; uP += pp.PredpocitanychUzlu;
            var st = pa.Statistika(); l1 += st.L1; l05 += st.L05; l025 += st.L025; lOdh += st.Odhad;
            var cil = new bool[kat.MaxId + 1]; foreach (var gr in SadaE84.Granitoidy) cil[kat.PodleKlice(gr)!.Id] = true;
            var lk = new object();
            Parallel.For(0, 256, i =>
            {
                var zs = new ZasobnikVrstvySloupce(g.Geo);
                var am = new Stat(); var an = new Stat(); var aS2 = new Stat(); var aR2 = new Stat(); var pm = new Stat(); var pn = new Stat();
                var rnd = new Random(i * 7919 + (int)bx);
                for (int j = 0; j < 256; j++)
                {
                    double x = bx + i * 0.25, y = by + j * 0.25;
                    var e = HledaniPlochy.CiloveIntervaly(zs, cil, x, y);
                    var u = pa.Interpoluj(x, y, out var l);
                    am.Pridej(e, u, l.Odhad, tau); pm.Pridej(e, pp.Interpoluj(x, y), false, tau);
                    // kategorie: svah > 20°, rychlá změna mocnosti (cílová hranice se mění > 0,25 m na 0,25 m)
                    double sx = (s.Vyska(x + 0.25, y) - s.Vyska(x - 0.25, y)) / 0.5, sy = (s.Vyska(x, y + 0.25) - s.Vyska(x, y - 0.25)) / 0.5;
                    if (Math.Sqrt(sx * sx + sy * sy) > Math.Tan(20 * Math.PI / 180)) aS2.Pridej(e, u, l.Odhad, tau);
                    var e2 = HledaniPlochy.CiloveIntervaly(zs, cil, x + 0.25, y);
                    if (e2.Length == e.Length && e.Zip(e2).Any(q => Math.Abs(q.First - q.Second) > 0.25)) aR2.Pridej(e, u, l.Odhad, tau);
                    // mimo mřížku
                    double xr = bx + rnd.NextDouble() * 64, yr = by + rnd.NextDouble() * 64;
                    var er = HledaniPlochy.CiloveIntervaly(zs, cil, xr, yr);
                    an.Pridej(er, pa.Interpoluj(xr, yr, out var lr), lr.Odhad, tau); pn.Pridej(er, pp.Interpoluj(xr, yr), false, tau);
                }
                lock (lk)
                {
                    void Sl(Stat a, Stat b) { a.Dz.AddRange(b.Dz); a.Sloupcu += b.Sloupcu; a.Neshod += b.Neshod; a.NeshodOdhad += b.NeshodOdhad; a.Odhad += b.Odhad; a.NadTau += b.NadTau; a.MaxOdhad = Math.Max(a.MaxOdhad, b.MaxOdhad); }
                    Sl(aM, am); Sl(aN, an); Sl(aS, aS2); Sl(aR, aR2); Sl(pM, pm); Sl(pN, pn);
                }
            });
        }
        long L = l1 + l05 + l025;
        Console.WriteLine($"  listy adaptivní: 1 m {100.0 * l1 / L:F1} %, 0,5 m {100.0 * l05 / L:F1} %, 0,25 m {100.0 * l025 / L:F1} % (s odhadem {lOdh}); uzlů adaptivní {uA:N0} × pevná {uP:N0}; kontext {tA:F2} s × {tP:F2} s ({Bloky.Length} bloků)");
        Console.WriteLine($"  adaptivní, mřížka 0,25 m: {aM.Text()}");
        Console.WriteLine($"  adaptivní, mimo mřížku:   {aN.Text()}");
        Console.WriteLine($"  adaptivní, svah > 20°:    {aS.Text()}");
        Console.WriteLine($"  adaptivní, rychlá mocnost:{aR.Text()}");
        Console.WriteLine($"  pevná 0,5, mřížka 0,25 m: {pM.Text()}");
        Console.WriteLine($"  pevná 0,5, mimo mřížku:   {pN.Text()}");
        T.Je(aM.Neshod == 0, "V5: sled cílových vrstev bez neshod (mimo listy s odhadem) ve sloupcích po 0,25 m");
        T.Je(aM.NadTau == 0, $"V5: max |Δz| ≤ τ = {tau} m ve 100 % sloupců po 0,25 m (mimo listy s odhadem)");
        T.Je(aM.Dz.Max() <= pM.Dz.Max() && aN.NadTau <= pN.NadTau, "adaptivní mřížka je přesnější než pevná 0,5 m");
    }

    /// <summary>Švy: dva sousední bloky (kontexty) dají v překryvu stejné listy i uzly (bitově).</summary>
    private static void Svy(KatalogGeo2 kat, DataSveta d, GeologieCs g)
    {
        T.Sekce("GEO2 K5: švy bloků – listy a uzly kořenů v překryvu dvou kontextů bitově stejné");
        var (k1, _) = Kontext(g, kat, d, OblastBloku.Ctverec(1024, 512, 64), null);
        var (k2, _) = Kontext(g, kat, d, OblastBloku.Ctverec(1088, 512, 64), null);
        var p1 = (PlochaVrstevAdaptivni)Skarn(k1).Plochy[0]; var p2 = (PlochaVrstevAdaptivni)Skarn(k2).Plochy[0];
        long korenu = 0, rozdil = 0;
        for (long I = 1080; I < 1096; I++)
        for (long J = 512; J < 576; J++)
        {
            korenu++;
            var a = p1.Listy(I, J); var b = p2.Listy(I, J);
            if (!a.AsSpan().SequenceEqual(b)) { rozdil++; continue; }
            foreach (var l in a)
                if (!p1.Uzel(l.I, l.J).AsSpan().SequenceEqual(p2.Uzel(l.I, l.J)) || !p1.Uzel(l.I + l.S, l.J + l.S).AsSpan().SequenceEqual(p2.Uzel(l.I + l.S, l.J + l.S))) rozdil++;
        }
        Console.WriteLine($"  kořenů ve švu {korenu}, rozdílných {rozdil}");
        T.Je(rozdil == 0 && korenu > 0, "švy bloků: listy i uzly stejné");
    }

    /// <summary>Skarn (kontakt na vrstvy) adaptivní × pevná 0,5 m proti jemné referenci pevné 0,125 m; V4; výkon bloku K4.</summary>
    private static void Kontakt(KatalogGeo2 kat, DataSveta d, GeologieCs g)
    {
        T.Sekce("GEO2 K5: kontakt (skarn) s adaptivní mřížkou × pevná 0,5 m proti referenci 0,125 m; V4; výkon");
        var o = OblastBloku.Ctverec(1024, 512, 64);
        var (kr, _) = Kontext(g, kat, d, o, 0.125); var (ka, ta) = Kontext(g, kat, d, o, null); var (kp, tp) = Kontext(g, kat, d, o, 0.5);
        const int n = 64; const int nz = 512; int sk = kat.PodleKlice("skarn")!.Id;
        Vzorek[] Blok(KontextBloku k, out double t)
        {
            var v = new Vzorek[n * n * nz]; var sw = Stopwatch.StartNew();
            Parallel.For(0, n, i => { for (int j = 0; j < n; j++) k.SloupecZBehu(o.X0 + i + 0.5, o.Y0 + j + 0.5, 0, 0.25, v.AsSpan((i * n + j) * nz, nz)); });
            t = sw.Elapsed.TotalSeconds; return v;
        }
        var vr = Blok(kr, out _); var va = Blok(ka, out _); var vp = Blok(kp, out _);
        va = Blok(ka, out var tba); vp = Blok(kp, out var tbp); // zahřáté
        long skR = 0, rA = 0, rP = 0, odhA = 0;
        for (int i = 0; i < vr.Length; i++)
        {
            bool r = vr[i].Material == sk; if (r) skR++;
            if ((va[i].Material == sk) != r) rA++;
            if ((vp[i].Material == sk) != r) rP++;
            if ((va[i].Priznaky & PriznakyVzorku.HraniceOdhad) != 0) odhA++;
        }
        Console.WriteLine($"  skarn v referenci 0,125 m {skR:N0} buněk; jinak než reference: adaptivní {rA:N0}, pevná 0,5 m {rP:N0}; buněk s příznakem odhadu (adaptivní) {odhA:N0}");
        Console.WriteLine($"  čas: kontext adaptivní {ta:F2} s × pevná {tp:F2} s; blok 64 m po 1 m (K4 běhy + raster) adaptivní {tba:F2} s × pevná {tbp:F2} s");
        T.Je(skR > 0 && rA <= rP, "skarn s adaptivní mřížkou je blíž referenci 0,125 m než s pevnou 0,5 m");
        TestyGeo2K4.V4(ka, "E84 adaptivní mřížka", 16, 128, 17);
    }

    /// <summary>Blok 128 m: kontext a K4 s adaptivní × pevnou 0,5 m (výkon); <c>--jen=GEO2K5B</c>.</summary>
    public static void Blok(string data, double ox, double oy, int vlaken, double krokXy = 0.5)
    {
        T.Sekce($"GEO2 K5: blok 128 m od ({ox}, {oy}), sloupce po {krokXy} m, z po 0,25 m, {vlaken} vláken: adaptivní × pevná 0,5 m");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        int n = (int)Math.Round(128 / krokXy); const int nz = 512; var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        var o = OblastBloku.Ctverec(ox, oy, 128);
        var vys = new Dictionary<string, (double tk, double tb, Vzorek[] v)>();
        foreach (var (nazev, krok, plna) in new (string, double?, bool)[] { ("pevna", 0.5, true), ("adaptivni", null, true), ("rychla", null, false), ("pevna", 0.5, true), ("adaptivni", null, true), ("rychla", null, false) })
        {
            var sw = Stopwatch.StartNew();
            var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, SadaE84.Json(d), o, new MoznostiKompilace(krok, plna), vlaken);
            double tk = sw.Elapsed.TotalSeconds; sw.Restart();
            var v = new Vzorek[(long)n * n * nz];
            Parallel.For(0, n, opt, i => { for (int j = 0; j < n; j++) k.SloupecZBehu(ox + (i + 0.5) * krokXy, oy + (j + 0.5) * krokXy, 0, 0.25, v.AsSpan((i * n + j) * nz, nz)); });
            vys[nazev] = (tk, sw.Elapsed.TotalSeconds, v);
            if (k.Chronologie.Udalosti[k.Chronologie.IndexUdalosti("skarn_kontakt")].Kontakt is KontaktniPasmo kp && kp.Plochy[0] is PlochaVrstevAdaptivni pa)
            {
                var s = pa.Statistika(); Console.WriteLine($"  listy 1 / 0,5 / 0,25 m: {s.L1:N0} / {s.L05:N0} / {s.L025:N0}, s odhadem {s.Odhad}; uzlů {pa.SpoctenychUzlu:N0}");
            }
        }
        var (a, b, c) = (vys["adaptivni"].v, vys["pevna"].v, vys["rychla"].v); long ruz = 0, ruzR = 0;
        for (long i = 0; i < a.LongLength; i++) { if (a[i] != b[i]) ruz++; if (a[i] != c[i]) ruzR++; }
        Console.WriteLine($"  buněk {a.LongLength:N0}, adaptivní ≠ pevná {ruz:N0} ({100.0 * ruz / a.LongLength:F4} %), adaptivní ≠ rychlá {ruzR:N0}");
        foreach (var kl in new[] { "pevna", "adaptivni", "rychla" })
            Console.WriteLine($"  čas (druhý průchod) {kl,-9}: kontext {vys[kl].tk:F2} s, blok {vys[kl].tb:F2} s, celkem {vys[kl].tk + vys[kl].tb:F2} s");
    }
}
