using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K4: průniky přímky s primitivy, vzdálenost k elipsoidu, závorky těles E84 (fuzz ≥ 10⁶ bodů), V4 (běhy × hustý Bod po 1/64 m,
/// 0 vynechaných tětiv ≥ t_det), syntetická šumová deska (tloušťky t_det·{0,5; 0,99; 1; 1,01; 2}, sklony), kontakt na těleso (syntetické
/// i dóm E84), rasterizace = Bod, V7. Blok 128 m s výkonem proti K3 je zvlášť (<c>--jen=GEO2K4B</c>, <see cref="Blok"/>).
/// </summary>
public static class TestyGeo2K4
{
    private const double Eps = SloupecGeo2.Epsilon;

    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var g = new GeologieCs(new ParametrySveta(), d);
        Primitiva();
        Vzdalenost();
        var o = OblastBloku.Ctverec(1024, 512, 64);
        Zavorky(g, o);
        var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, SadaE84.Json(d), o);
        T.Je(r.Ok, $"kontext E84 se sestaví ({r.Zprava})");
        if (!r.Ok) return;
        V4(k, "E84 blok (1024, 512)", 16, 128, 7);
        Raster(k);
        TestSumoveDesky(kat);
        KontaktNaTeleso(kat);
        KontaktNaDom(kat, d, g);
    }

    // ---------- primitiva ----------
    private static (double, double, double) Jedn(Random r)
    {
        while (true)
        {
            double x = r.NextDouble() * 2 - 1, y = r.NextDouble() * 2 - 1, z = r.NextDouble() * 2 - 1, l = Math.Sqrt(x * x + y * y + z * z);
            if (l > 0.1 && l <= 1) return (x / l, y / l, z / l);
        }
    }

    /// <summary>Náhodná ortonormální báze (Gram–Schmidt), po řádcích.</summary>
    internal static double[] Baze(Random r)
    {
        var (ax, ay, az) = Jedn(r); var (bx, by, bz) = Jedn(r);
        double d = ax * bx + ay * by + az * bz; bx -= d * ax; by -= d * ay; bz -= d * az;
        double l = Math.Sqrt(bx * bx + by * by + bz * bz); bx /= l; by /= l; bz /= l;
        return new[] { ax, ay, az, bx, by, bz, ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx };
    }

    private static void Primitiva()
    {
        T.Sekce("GEO2 K4: průniky obecné přímky s primitivy závorek (proti bodovému testu)");
        var r = new Random(41); long chyb = 0, bodu = 0;
        for (int c = 0; c < 4000; c++)
        {
            var (dx, dy, dz) = Jedn(r);
            var p = new Primka(r.NextDouble() * 4 - 2, r.NextDouble() * 4 - 2, r.NextDouble() * 4 - 2, dx, dy, dz);
            double cx = r.NextDouble() - 0.5, cy = r.NextDouble() - 0.5, cz = r.NextDouble() - 0.5;
            var B = Baze(r); double r0 = 0.2 + r.NextDouble() * 2, r1 = 0.2 + r.NextDouble() * 2, r2 = 0.2 + r.NextDouble() * 2;
            var (ex, ey, ez) = Jedn(r);
            bool e = PrunikyPrimky.Elipsoid(p, cx, cy, cz, B, r0, r1, r2, 1, out var e0, out var e1);
            bool de = PrunikyPrimky.Deska(p, cx, cy, cz, B[0], B[1], B[2], r0, out var d0, out var d1);
            bool va = PrunikyPrimky.Valec(p, cx, cy, cz, B[3], B[4], B[5], r1, B[6], B[7], B[8], r2, out var v0, out var v1);
            bool ka = PrunikyPrimky.Kapsle(p, cx, cy, cz, cx + ex * 2, cy + ey * 2, cz + ez * 2, r0, out var k0, out var k1);
            for (int i = 0; i < 100; i++)
            {
                double t = r.NextDouble() * 10 - 5, x = p.Ox + t * dx - cx, y = p.Oy + t * dy - cy, z = p.Oz + t * dz - cz;
                double q0 = x * B[0] + y * B[1] + z * B[2], q1 = x * B[3] + y * B[4] + z * B[5], q2 = x * B[6] + y * B[7] + z * B[8];
                double fe = (q0 / r0) * (q0 / r0) + (q1 / r1) * (q1 / r1) + (q2 / r2) * (q2 / r2) - 1;
                double fd = Math.Abs(q0) - r0, fv = (q1 / r1) * (q1 / r1) + (q2 / r2) * (q2 / r2) - 1;
                double h = Math.Clamp((x * ex + y * ey + z * ez) / 2, 0, 1), fk = Math.Sqrt(Math.Pow(x - 2 * h * ex, 2) + Math.Pow(y - 2 * h * ey, 2) + Math.Pow(z - 2 * h * ez, 2)) - r0;
                void Kontrola(double f, bool ok, double a, double b)
                {
                    if (Math.Abs(f) < 1e-9) return;
                    bodu++;
                    if ((f < 0) != (ok && t >= a && t <= b)) chyb++;
                }
                Kontrola(fe, e, e0, e1); Kontrola(fd, de, d0, d1); Kontrola(fv, va, v0, v1); Kontrola(fk, ka, k0, k1);
            }
        }
        Console.WriteLine($"  bodů {bodu:N0}, nesouhlasí {chyb}");
        T.Je(chyb == 0, "elipsoid, deska, eliptický válec, kapsle: interval na přímce = bodový test");
    }

    private static void Vzdalenost()
    {
        T.Sekce("GEO2 K4: vzdálenost bod–elipsoid (Eberly) proti hrubé síle");
        var r = new Random(43); double maxNaPl = 0, maxHorsi = 0, maxKolm = 0;
        for (int c = 0; c < 400; c++)
        {
            var B = Baze(r); double r0 = 0.3 + r.NextDouble() * 5, r1 = 0.3 + r.NextDouble() * 5, r2 = 0.3 + r.NextDouble() * 3;
            double x = r.NextDouble() * 16 - 8, y = r.NextDouble() * 16 - 8, z = r.NextDouble() * 12 - 6;
            if (c % 4 == 0) { x *= 0.1; y *= 0.1; z *= 0.1; } // uvnitř
            double d = VzdalenostElipsoidu.Nejblizsi(x, y, z, 0, 0, 0, B, r0, r1, r2, out var px, out var py, out var pz, out var nx, out var ny, out var nz);
            double q0 = px * B[0] + py * B[1] + pz * B[2], q1 = px * B[3] + py * B[4] + pz * B[5], q2 = px * B[6] + py * B[7] + pz * B[8];
            maxNaPl = Math.Max(maxNaPl, Math.Abs((q0 / r0) * (q0 / r0) + (q1 / r1) * (q1 / r1) + (q2 / r2) * (q2 / r2) - 1));
            if (d > 1e-6)
            {
                // q − π ∥ normála
                double ux = (x - px) / d, uy = (y - py) / d, uz = (z - pz) / d, cr = Math.Abs(Math.Abs(ux * nx + uy * ny + uz * nz) - 1);
                maxKolm = Math.Max(maxKolm, cr);
            }
            double best = double.MaxValue;
            for (int i = 0; i < 40000; i++)
            {
                double th = Math.Acos(2 * r.NextDouble() - 1), ph = r.NextDouble() * 2 * Math.PI;
                double a = r0 * Math.Sin(th) * Math.Cos(ph), b = r1 * Math.Sin(th) * Math.Sin(ph), cc = r2 * Math.Cos(th);
                double sx = a * B[0] + b * B[3] + cc * B[6], sy = a * B[1] + b * B[4] + cc * B[7], sz = a * B[2] + b * B[5] + cc * B[8];
                best = Math.Min(best, Math.Sqrt((sx - x) * (sx - x) + (sy - y) * (sy - y) + (sz - z) * (sz - z)));
            }
            maxHorsi = Math.Max(maxHorsi, d - best);
        }
        Console.WriteLine($"  max |Σ(π_i/r_i)² − 1| = {maxNaPl:E2}, max (d − hrubá síla) = {maxHorsi:E2} m, max |1 − |u·n|| = {maxKolm:E2}");
        T.Je(maxNaPl < 1e-9 && maxHorsi < 1e-9 && maxKolm < 1e-6, "nejbližší bod leží na povrchu, není horší než 40 000 vzorků povrchu, q − π ∥ normála");
    }

    // ---------- závorky těles E84 ----------
    private static void Zavorky(GeologieCs g, OblastBloku o)
    {
        T.Sekce("GEO2 K4: závorky V ⊆ těleso ⊆ O těles E84 (fuzz 10⁶ bodů na druh)");
        var u = g.Geo.Utvary; var pole = new int[4096];
        foreach (var druh in new[] { DruhUtvaru.Zila, DruhUtvaru.Cocka, DruhUtvaru.Kras, DruhUtvaru.Dome, DruhUtvaru.Pipe })
        {
            var ix = IndexUtvaruE84.Sestav(g.Svet, druh, o.Rozsir(4));
            long vne = 0, vNeni = 0, uvnitr = 0, vnitrnich = 0; var nej = new List<(double, double)>();
            var rnd = new Random(47 + (int)druh);
            // body: polovina v obálkách instancí (aby fuzz trefoval tělesa), polovina rovnoměrně
            for (int i = 0; i < 1_000_000; i++)
            {
                double x, y, z;
                if ((i & 1) == 0 && ix.Polozky.Count > 0)
                {
                    var p = ix.Polozky[rnd.Next(ix.Polozky.Count)];
                    x = Math.Clamp(p.X0 + rnd.NextDouble() * (p.X1 - p.X0), o.X0, o.X1); y = Math.Clamp(p.Y0 + rnd.NextDouble() * (p.Y1 - p.Y0), o.Y0, o.Y1);
                    z = p.Z0 + rnd.NextDouble() * (p.Z1 - p.Z0);
                }
                else { x = o.X0 + rnd.NextDouble() * 64; y = o.Y0 + rnd.NextDouble() * 64; z = rnd.NextDouble() * 90; }
                int n = ix.Kandidati(x, y, z, pole);
                var pr = Primka.Svisla(x, y);
                for (int c = 0; c < n; c++)
                {
                    var f = ix.Polozky[pole[c]].F; double sdf = u.Sdf(f, x, y, z);
                    if (PrimkaE84.JeElipsoid(druh))
                    {
                        bool ok = PrimkaE84.Tetiva(f, pr, 0, out var a, out var b);
                        if (sdf < 0) { uvnitr++; if (!(ok && z >= a - 1e-9 && z <= b + 1e-9)) vne++; }
                        if (ok && z > a + 1e-7 && z < b - 1e-7) { vnitrnich++; if (!(sdf < 0)) vNeni++; }
                    }
                    else if (sdf < 0)
                    {
                        uvnitr++; nej.Clear(); PrimkaE84.Nejiste(f, pr, u.Fast, nej);
                        if (!nej.Any(q => z >= q.Item1 - 1e-9 && z <= q.Item2 + 1e-9)) vne++;
                    }
                }
            }
            Console.WriteLine($"  {druh,-6} bodů v tělese {uvnitr,9:N0}, mimo O {vne}; {(PrimkaE84.JeElipsoid(druh) ? $"bodů uvnitř tětivy {vnitrnich:N0}, z nich mimo těleso {vNeni}" : "V = ∅")}");
            T.Je(vne == 0 && vNeni == 0 && uvnitr > 0, $"{druh}: těleso ⊆ O{(PrimkaE84.JeElipsoid(druh) ? " a V = O (přesná tětiva)" : "")}");
        }
    }

    // ---------- V4: běhy proti hustému Bod ----------
    internal sealed record VysledekV4(long Bodu, long Ruzne, long Tetiv, long TetivNad, double MaxTetiva, double BehuNaSloupec, double BodNaSloupec);

    /// <summary>
    /// Sloupce v náhodných polohách; Bod po 1/64 m do zMax proti běhům. Rozdíl mimo ±ε od hranic běhu se sdruží do tětiv
    /// (souvislé úseky hustých bodů); tětiva délky ≥ t_det = vynechané těleso (V4 požaduje 0).
    /// </summary>
    internal static VysledekV4 V4(KontextBloku k, string nazev, int n, double zMax, int seed, bool tisk = true)
    {
        var c = k.Chronologie; double tdet = c.Konfigurace.MinTloustkaDetekceM;
        var rnd = new Random(seed); var o = k.Oblast;
        var pos = Enumerable.Range(0, n * n).Select(_ => (o.X0 + rnd.NextDouble() * (o.X1 - o.X0), o.Y0 + rnd.NextDouble() * (o.Y1 - o.Y0))).ToArray();
        long bodu = 0, ruzne = 0, tetiv = 0, nad = 0, behu = 0, bod = 0; double maxT = 0; var lk = new object();
        Parallel.For(0, pos.Length, () => (new List<Beh>(), 0L, 0L, 0L, 0L, 0.0, 0L, 0L), (i, _, s) =>
        {
            var (b, sb, sr, st, sn, sm, sbeh, sbod) = s;
            var (x, y) = pos[i]; double zPov = k.Povrch(x, y);
            long v0 = SloupecGeo2.VolaniBod;
            k.Behy(x, y, zMax, b);
            sbod += SloupecGeo2.VolaniBod - v0; sbeh += b.Count;
            int nz = (int)(zMax * 64), j = 0, delka = 0;
            for (int iz = 0; iz <= nz; iz++)
            {
                double z = iz / 64.0; bool liche = false;
                if (z < zMax)
                {
                    while (j + 1 < b.Count && b[j].Z1 <= z) j++;
                    bool blizko = (j > 0 && z - b[j].Z0 <= Eps) || (j + 1 < b.Count && b[j].Z1 - z <= Eps);
                    if (!blizko)
                    {
                        sb++;
                        if (b[j].Stav != c.Vzorek(x, y, z, zPov)) { liche = true; sr++; }
                    }
                }
                if (liche) delka++;
                else if (delka > 0)
                {
                    double L = delka / 64.0; st++; if (L >= tdet) sn++; sm = Math.Max(sm, L); delka = 0;
                }
            }
            return (b, sb, sr, st, sn, sm, sbeh, sbod);
        }, s => { lock (lk) { bodu += s.Item2; ruzne += s.Item3; tetiv += s.Item4; nad += s.Item5; maxT = Math.Max(maxT, s.Item6); behu += s.Item7; bod += s.Item8; } });
        var v = new VysledekV4(bodu, ruzne, tetiv, nad, maxT, behu / (double)pos.Length, bod / (double)pos.Length);
        if (tisk)
        {
            Console.WriteLine($"  V4 {nazev}: {pos.Length} sloupců, hustých bodů {bodu:N0}, různých {ruzne:N0} v {tetiv:N0} tětivách (max {maxT:F4} m), tětiv ≥ t_det {nad}; běhů na sloupec {v.BehuNaSloupec:F1}, Bod na sloupec {v.BodNaSloupec:F0}");
            T.Je(nad == 0, $"V4 {nazev}: žádná vynechaná tětiva ≥ t_det = {tdet} m");
        }
        return v;
    }

    private static void Raster(KontextBloku k)
    {
        T.Sekce("GEO2 K4: rasterizace běhů (3.4) = Bod ve středu buňky; V7");
        var c = k.Chronologie; double tdet = c.Konfigurace.MinTloustkaDetekceM;
        foreach (double hz in new[] { 0.25, 0.125 })
        {
            const int n = 32; int nz = (int)(128 / hz); long ruzne = 0, nad = 0, bunek = 0; var lk = new object();
            ulong[] ot1 = new ulong[n * n], ot2 = new ulong[n * n], ot3 = new ulong[n * n];
            Parallel.For(0, n * n, i =>
            {
                double x = k.Oblast.X0 + (i / n + 0.5) * 2, y = k.Oblast.Y0 + (i % n + 0.5) * 2, zPov = k.Povrch(x, y);
                var a = new Vzorek[nz]; var b = new Vzorek[nz];
                k.Sloupec(x, y, 0, hz, a); k.SloupecZBehu(x, y, 0, hz, b);
                ot1[i] = TestyGeo2K3.Otisk(b);
                long r = 0, nn = 0;
                for (int iz = 0; iz < nz; iz++)
                {
                    if (a[iz] == b[iz]) continue;
                    r++;
                    // rozdíl smí být jen v tětivě < t_det: úsek se stavem Bod(zc) kolem středu
                    double zc = (iz + 0.5) * hz, lo = zc, hi = zc; var s = a[iz];
                    while (hi - zc < tdet && c.Vzorek(x, y, hi + 1.0 / 1024, zPov) == s) hi += 1.0 / 1024;
                    while (zc - lo < tdet && c.Vzorek(x, y, lo - 1.0 / 1024, zPov) == s) lo -= 1.0 / 1024;
                    if (hi - lo >= tdet) nn++;
                }
                lock (lk) { ruzne += r; nad += nn; bunek += nz; }
            });
            Parallel.For(0, n * n, new ParallelOptions { MaxDegreeOfParallelism = 1 }, i => Ot(k, n, hz, nz, i, ot2));
            Parallel.For(0, n * n, i => Ot(k, n, hz, nz, n * n - 1 - i, ot3));
            Console.WriteLine($"  krok z {hz} m: buněk {bunek:N0}, různých od Bod {ruzne:N0}, z toho ve tětivě ≥ t_det {nad}");
            T.Je(nad == 0, $"rasterizace po {hz} m = Bod mimo tětivy < t_det");
            T.Je(ot1.AsSpan().SequenceEqual(ot2) && ot1.AsSpan().SequenceEqual(ot3), $"V7 ({hz} m): stejné běhy při 1 a N vláknech a v opačném pořadí");
        }

        static void Ot(KontextBloku k, int n, double hz, int nz, int i, ulong[] cil)
        {
            double x = k.Oblast.X0 + (i / n + 0.5) * 2, y = k.Oblast.Y0 + (i % n + 0.5) * 2;
            var b = new Vzorek[nz]; k.SloupecZBehu(x, y, 0, hz, b); cil[i] = TestyGeo2K3.Otisk(b);
        }
    }

    // ---------- syntetické tvary ----------
    /// <summary>Vrstvy s hranicemi a intervaly (zásobník testů K4).</summary>
    internal sealed class VrstvyK4 : ITvarZasobnikuSHranicemi, IIntervalyTvaru
    {
        public List<(double doZ, int mat)> V = new();
        public bool Vrstva(double x, double y, double z, out int m, out short v)
        {
            for (int i = 0; i < V.Count; i++) if (z < V[i].doZ) { m = V[i].mat; v = (short)i; return true; }
            m = V[^1].mat; v = (short)(V.Count - 1); return true;
        }
        public IReadOnlyList<IntervalVrstvy> Sloupec(double x, double y)
        {
            var o = new List<IntervalVrstvy>(); double z0 = -1e9;
            for (int i = 0; i < V.Count; i++) { double z1 = i == V.Count - 1 ? 1e9 : V[i].doZ; o.Add(new(V[i].mat, z0, z1)); z0 = z1; }
            return o;
        }
        public void Sloupec(double x, double y, SegmentaceSloupce s) { for (int i = 0; i + 1 < V.Count; i++) s.Zlom(V[i].doZ); }
    }

    /// <summary>Šumová deska: |s + A·N(f·p)| &lt; T/2, s = (p − c)·n; O = |s| ≤ T/2 + A, V = ∅.</summary>
    internal sealed class SumovaDeska : ITvar, IIntervalyTvaru
    {
        public double Cx, Cy, Cz, Nx, Ny, Nz, T, A, F; public long Seed;
        public bool Obsahuje(double x, double y, double z, out uint inst)
        {
            inst = 1;
            double s = (x - Cx) * Nx + (y - Cy) * Ny + (z - Cz) * Nz;
            return Math.Abs(s + A * VNoise.Noise(Seed, x * F, y * F, z * F)) < T / 2;
        }
        public void Sloupec(double x, double y, SegmentaceSloupce seg)
        {
            if (PrunikyPrimky.Deska(Primka.Svisla(x, y), Cx, Cy, Cz, Nx, Ny, Nz, T / 2 + A, out var a, out var b)) seg.Nejista(a, b);
        }
    }

    /// <summary>Elipsoid bez šumu s vzdáleností (cíl kontaktu).</summary>
    internal sealed class ElipsoidK4 : ITvarSVzdalenosti, IIntervalyTvaru, IPlochaKontaktu, IPlochaSRozsahem
    {
        public double Cx, Cy, Cz, R0, R1, R2; public double[] B = { 1, 0, 0, 0, 1, 0, 0, 0, 1 };
        public IPlochaKontaktu Plocha => this;
        private double F(double x, double y, double z)
        {
            double qx = x - Cx, qy = y - Cy, qz = z - Cz, a = (qx * B[0] + qy * B[1] + qz * B[2]) / R0, b = (qx * B[3] + qy * B[4] + qz * B[5]) / R1, c = (qx * B[6] + qy * B[7] + qz * B[8]) / R2;
            return a * a + b * b + c * c;
        }
        public bool Obsahuje(double x, double y, double z, out uint inst) { inst = 1; return F(x, y, z) < 1; }
        public void Sloupec(double x, double y, SegmentaceSloupce s)
        {
            if (PrunikyPrimky.Elipsoid(Primka.Svisla(x, y), Cx, Cy, Cz, B, R0, R1, R2, 1, out var a, out var b)) { s.Zlom(a); s.Zlom(b); }
        }
        public bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy bp)
        {
            double d = VzdalenostElipsoidu.Nejblizsi(x, y, z, Cx, Cy, Cz, B, R0, R1, R2, out var px, out var py, out var pz, out var nx, out var ny, out var nz);
            bp = new BodPlochy(px, py, pz, nx, ny, nz, d); return d <= rMax;
        }
        public void RozsahZ(double x, double y, double r, List<(double A, double B)> cil)
        {
            if (PrunikyPrimky.Elipsoid(Primka.Svisla(x, y), Cx, Cy, Cz, B, R0 + r, R1 + r, R2 + r, 1, out var a, out var b)) cil.Add((a, b));
        }
    }

    internal sealed class TovarnaK4 : ITovarnaTvaru
    {
        private readonly KatalogGeo2 _k; public readonly Dictionary<string, object> Tvary = new();
        public TovarnaK4(KatalogGeo2 k) => _k = k;
        private int Id(string klic) => _k.PodleKlice(klic)!.Id;
        public object? Vytvor(UdalostData u)
        {
            var t = u.Tvar; double D(string k) => t.GetProperty(k).GetDouble();
            object? o = u.TvarDruh switch
            {
                "test_vrstvy" => Vr(t),
                "test_deska_sum" => new SumovaDeska { Cx = 0, Cy = 0, Cz = D("z"), Nx = Math.Sin(D("sklon") * Math.PI / 180), Ny = 0, Nz = Math.Cos(D("sklon") * Math.PI / 180), T = D("t"), A = D("a"), F = D("f"), Seed = 77 },
                "test_elipsoid" => new ElipsoidK4 { Cx = D("x"), Cy = D("y"), Cz = D("z"), R0 = D("r0"), R1 = D("r1"), R2 = D("r2"), B = Baze(new Random(5)) },
                _ => null,
            };
            if (o is not null) Tvary[u.Id] = o;
            return o;
        }
        private VrstvyK4 Vr(JsonElement t)
        {
            var v = new VrstvyK4();
            foreach (var e in t.GetProperty("vrstvy").EnumerateArray()) v.V.Add((e.GetProperty("do_z").GetDouble(), Id(e.GetProperty("material").GetString()!)));
            return v;
        }
    }

    private static KontextBloku Synteticky(KatalogGeo2 kat, string udalosti, OblastBloku o, out TovarnaK4 tv)
    {
        tv = new TovarnaK4(kat);
        var r = KompilatorChronologie.Kompiluj(UdalostiJson.NactiPole(udalosti), kat, tv);
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        var c = new ChronologieGeo2(r.Chronologie!.Udalosti, r.Chronologie.Konfigurace, r.Chronologie.OtiskKatalogu, (_, _) => 100.0);
        return KontextBloku.Sestav(c, o, 0.5, Environment.ProcessorCount);
    }

    private const string Vapenec = """{"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":20,"material":"granite"},{"do_z":1000,"material":"cave_limestone"}]}}""";

    private static void TestSumoveDesky(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K4: syntetická šumová deska (V = ∅, O = deska ± A): garantovaná detekce ≥ t_det po h = t_det/2");
        var o = OblastBloku.Ctverec(-20, -20, 40);
        foreach (double sklon in new[] { 0.0, 30.0, 60.0, 80.0 })
        foreach (double kt in new[] { 0.5, 0.99, 1.0, 1.01, 2.0 })
        {
            double t = 0.125 * kt;
            string ud = "[" + Vapenec + ",{\"id\":\"d\",\"stari\":5,\"operace\":\"Vnikni\",\"tvar\":{\"druh\":\"test_deska_sum\",\"z\":50,\"sklon\":" + sklon.ToString(System.Globalization.CultureInfo.InvariantCulture)
                + ",\"t\":" + t.ToString("R", System.Globalization.CultureInfo.InvariantCulture) + ",\"a\":0.3,\"f\":0.7},\"vysledek\":{\"material\":\"quartzite\"}}]";
            var k = Synteticky(kat, ud, o, out var tv);
            var deska = (SumovaDeska)tv.Tvary["d"];
            // skutečné tětivy desky ve sloupci: hustě po 1/1024 m v O; tětiva ≥ t_det musí mít v bězích materiál desky
            var rnd = new Random(53); long tetiv = 0, vynech = 0, malych = 0, malychNalez = 0; var b = new List<Beh>();
            int iq = kat.PodleKlice("quartzite")!.Id;
            for (int s = 0; s < 60; s++)
            {
                double x = -15 + rnd.NextDouble() * 30, y = -15 + rnd.NextDouble() * 30;
                k.Behy(x, y, 100, b);
                if (!PrunikyPrimky.Deska(Primka.Svisla(x, y), 0, 0, 50, deska.Nx, deska.Ny, deska.Nz, t / 2 + 0.3, out var a0, out var a1)) continue;
                a0 = Math.Max(a0, 1); a1 = Math.Min(a1, 99); // tětivy uvnitř sloupce [0, zPov = 100)
                if (a0 >= a1) continue;
                double z0 = -1;
                for (double z = a0 - 0.01; z <= a1 + 0.01; z += 1.0 / 1024)
                {
                    bool in_ = deska.Obsahuje(x, y, z, out _);
                    if (in_ && z0 < 0) z0 = z;
                    if (!in_ && z0 >= 0)
                    {
                        double L = z - z0, zm = 0.5 * (z0 + z); bool nalez = b.Any(q => q.Stav.Material == iq && q.Z1 > z0 && q.Z0 < z);
                        if (L >= 0.125) { tetiv++; if (!nalez) vynech++; } else { malych++; if (nalez) malychNalez++; }
                        z0 = -1;
                    }
                }
            }
            Console.WriteLine($"  sklon {sklon,2}°, T = {kt:F2}·t_det: tětiv ≥ t_det {tetiv,4}, vynechaných {vynech}; menších {malych} (nalezeno {malychNalez})");
            T.Je(vynech == 0 && (kt < 1 || tetiv > 0), $"deska sklon {sklon}°, T = {kt}·t_det: žádná tětiva ≥ t_det nevynechána");
        }
    }

    private const string KontaktJson = """
      ,{"id":"teleso","stari":5,"operace":"Vnikni","tvar":{"druh":"test_elipsoid","x":0,"y":0,"z":50,"r0":8,"r1":5,"r2":3},"vysledek":{"material":"granite"}}
      ,{"id":"aureola","stari":10,"operace":"Transformuj","tvar":{"druh":"kontakt"},
        "pravidla":{"nahrazuje":{"materialy":["cave_limestone"]},"zdroje":{"vrstvy":true,"telesa":"zadna","transformace":false},
          "kontakt":{"cil":{"udalosti":["teleso"]},"strana":"vne","sirka_m":1.5,"modulace":{"amp_rel":0.5,"frekvence_1_m":0.5},
            "hostitel_okoli":{"materialy":["granite"],"hloubka_vzorku_m":0.125}}},
        "vysledek":{"mapa":{"cave_limestone":"skarn"}}}]
      """;

    private static void KontaktNaTeleso(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K4: kontakt na těleso (syntetický natočený elipsoid, vzdálenost Eberly) v intervalech");
        var k = Synteticky(kat, "[" + Vapenec + KontaktJson, OblastBloku.Ctverec(-12, -12, 24), out _);
        var v = V4(k, "kontakt na elipsoid", 16, 100, 11);
        // pásmo není prázdné
        int sk = kat.PodleKlice("skarn")!.Id; long skarnu = 0; var b = new List<Beh>();
        for (int i = 0; i < 24; i++) { k.Behy(-11.5 + i, 0.3, 100, b); skarnu += b.Count(q => q.Stav.Material == sk); }
        Console.WriteLine($"  běhů skarnu v řezu y = 0,3: {skarnu}");
        T.Je(skarnu > 0, "kontakt na těleso vytvoří pásmo");
    }

    private static void KontaktNaDom(KatalogGeo2 kat, DataSveta d, GeologieCs g)
    {
        T.Sekce("GEO2 K4: kontakt na těleso E84 (dóm soli, syntetická událost aureoly) v intervalech");
        // najdi dóm v rozumné hloubce
        var ix = IndexUtvaruE84.Sestav(g.Svet, DruhUtvaru.Dome, OblastBloku.Ctverec(0, 0, 4096));
        IndexUtvaruE84.Polozka? dom = null;
        foreach (var p in ix.Polozky)
        {
            double cx = 0.5 * (p.X0 + p.X1), cy = 0.5 * (p.Y0 + p.Y1);
            if (p.Z1 < g.Svet.Vyska(cx, cy) - 2 && p.Z0 > 1) { dom = p; break; }
        }
        T.Je(dom is not null, "v oblasti 4 km je dóm pod povrchem");
        if (dom is null) return;
        var q = dom.Value; Console.WriteLine($"  dóm [{q.X0:F1}, {q.Y0:F1}, {q.Z0:F1}] – [{q.X1:F1}, {q.Y1:F1}, {q.Z1:F1}]");
        var root = JsonNode.Parse(SadaE84.Json(d))!.AsObject(); var ud = root["udalosti"]!.AsArray();
        ud.Add(JsonNode.Parse("""
          {"id":"aureola_dom","stari":55,"operace":"Transformuj","tvar":{"druh":"kontakt"},
           "pravidla":{"nahrazuje":{"skupiny":["vapenec"]},"zdroje":{"vrstvy":true,"telesa":"zadna","transformace":true},
             "kontakt":{"cil":{"udalosti":["dome"]},"strana":"vne","sirka_m":1.0,"modulace":{"amp_rel":0.3,"frekvence_1_m":0.5}}},
           "vysledek":{"mapa":{}}}
          """));
        // mapa: všechny vápence skupiny → dolomit
        var vap = kat.IdSkupiny("vapenec").Select(i => kat.PodleId(i)!.Klic).Where(x => x != "dolomite").ToArray();
        ud[^1]!["pravidla"]!["nahrazuje"] = new JsonObject { ["materialy"] = new JsonArray(vap.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray()) };
        ud[^1]!["vysledek"]!["mapa"] = new JsonObject(vap.Select(x => KeyValuePair.Create(x, (JsonNode?)JsonValue.Create("dolomite"))));
        var o = new OblastBloku(Math.Floor(q.X0) - 2, Math.Floor(q.Y0) - 2, Math.Ceiling(q.X1) + 2, Math.Ceiling(q.Y1) + 2);
        var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, root.ToJsonString(), o);
        T.Je(r.Ok, $"sada E84 + aureola dómu se zkompiluje ({r.Zprava})");
        if (!r.Ok) return;
        V4(k, "E84 + aureola dómu", 12, Math.Min(128, q.Z1 + 4), 13);
        int iA = k.Chronologie.IndexUdalosti("aureola_dom"); long aur = 0; var b = new List<Beh>();
        for (int i = 0; i < 40; i++) { k.Behy(o.X0 + (i + 0.5) * (o.X1 - o.X0) / 40, 0.5 * (o.Y0 + o.Y1), 128, b); aur += b.Count(x => x.Stav.PosledniTransformace == iA); }
        Console.WriteLine($"  běhů aureoly v řezu středem dómu: {aur}");
    }

    // ---------- blok 128 m: výkon proti K3 ----------
    public static void Blok(string data, double ox, double oy, int vlaken, double krokXy = 0.25, double krokZ = 0.25)
    {
        T.Sekce($"GEO2 K4: blok 128 × 128 m od ({ox}, {oy}), sloupce po {krokXy} m, z po {krokZ} m, {vlaken} vláken: K3 (Bod po buňkách) × K4 (běhy + raster)");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g0 = new GeologieCs(new ParametrySveta(), d);
        int n = (int)Math.Round(128 / krokXy), nz = (int)Math.Round(128 / krokZ);
        var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        bool sStarou = krokZ == 0.25; // stará cesta vyplňuje po 0,25 m
        var stary = new byte[sStarou ? (long)n * n * nz : 0];
        var sw = Stopwatch.StartNew();
        if (sStarou) Parallel.For(0, n, opt, () => g0.Klon(), (ix, _, g) =>
        {
            for (int iy = 0; iy < n; iy++)
                Array.Copy(g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0.25, 128.0), 0, stary, ((long)ix * n + iy) * nz, nz);
            return g;
        }, _ => { });
        double tStary = sw.Elapsed.TotalSeconds; sw.Restart();
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), new MoznostiKompilace(0.5), vlaken);
        double tKontext = sw.Elapsed.TotalSeconds;
        var a = new Vzorek[(long)n * n * nz]; var b = new Vzorek[a.Length];
        var zas = (ZasobnikVrstvySloupce)k.Chronologie.Udalosti[0].Zasobnik!;
        // dvakrát po sobě (K3, K4, K3, K4): první průchod zahřeje JIT a keše, měří se druhý
        double tK3 = 0, tK4 = 0; long h3 = 0, h4 = 0, bodu = 0;
        for (int opak = 0; opak < 2; opak++)
        {
            long h0 = zas.VolaniHranic; sw.Restart();
            Parallel.For(0, n, opt, ix => { for (int iy = 0; iy < n; iy++) k.Sloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0, krokZ, a.AsSpan(((ix * n) + iy) * nz, nz)); });
            tK3 = sw.Elapsed.TotalSeconds; h3 = zas.VolaniHranic - h0; h0 = zas.VolaniHranic; sw.Restart();
            bodu = 0;
            Parallel.For(0, n, opt, () => 0L, (ix, _, s) =>
            {
                long v0 = SloupecGeo2.VolaniBod;
                for (int iy = 0; iy < n; iy++) k.SloupecZBehu(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0, krokZ, b.AsSpan(((ix * n) + iy) * nz, nz));
                return s + SloupecGeo2.VolaniBod - v0;
            }, s => Interlocked.Add(ref bodu, s));
            tK4 = sw.Elapsed.TotalSeconds; h4 = zas.VolaniHranic - h0;
        }
        sw.Restart();
        // jen běhy (bez rasteru) + uložení
        var ul = new UlozisteBehu(n * n, 128); var beh = new List<Beh>[n * n];
        Parallel.For(0, n * n, opt, i => { var l = new List<Beh>(); k.Behy(ox + (i / n + 0.5) * krokXy, oy + (i % n + 0.5) * krokXy, 128, l); beh[i] = l; });
        double tBehy = sw.Elapsed.TotalSeconds;
        for (int i = 0; i < n * n; i++) ul.Zapis(i, beh[i]);
        long ruzne = 0, sStary3 = 0, sStary4 = 0; var prech = new Dictionary<(int, int), long>();
        for (long i = 0; i < a.LongLength; i++)
        {
            if (sStarou && stary[i] == (byte)a[i].Material) sStary3++;
            if (sStarou && stary[i] == (byte)b[i].Material) sStary4++;
            if (a[i] == b[i]) continue;
            ruzne++; var kl = (a[i].Material, b[i].Material); prech[kl] = prech.GetValueOrDefault(kl) + 1;
        }
        string M(int id) => kat.PodleId(id)?.Klic ?? id.ToString();
        double c = a.LongLength;
        Console.WriteLine($"  buněk {a.LongLength:N0}; K4 raster ≠ K3 Bod: {ruzne:N0} ({100.0 * ruzne / c:F4} %); shoda materiálu se starou cestou K3 {100.0 * sStary3 / c:F3} %, K4 {100.0 * sStary4 / c:F3} %");
        foreach (var kv in prech.OrderByDescending(q => q.Value).Take(6)) Console.WriteLine($"    {M(kv.Key.Item1),-16} → {M(kv.Key.Item2),-16} {kv.Value,8:N0}");
        Console.WriteLine($"  Bod na sloupec K4 {bodu / (double)(n * n):F1} (K3 {nz}); běhů {ul.Behu:N0} = {ul.Behu / (double)(n * n):F1} na sloupec, paleta {ul.Paleta}; uložení {ul.Bajtu / 1048576.0:F1} MiB proti hustým vzorkům {a.LongLength * Vzorek.Velikost / 1048576.0:F0} MiB");
        Console.WriteLine($"  V6 volání Hranice na sloupec: K3 {h3 / (double)(n * n):F2}, K4 {h4 / (double)(n * n):F2}");
        Console.WriteLine($"  čas: stará cesta {tStary:F1} s; kontext {tKontext:F2} s; K3 Sloupec {tK3:F1} s; K4 běhy+raster {tK4:F1} s (×{tK4 / tK3:F2} proti K3); K4 jen běhy {tBehy:F1} s");
        T.Je(ruzne < c * 1e-3, "K4 raster se od K3 Bod liší v < 0,1 % buněk (tětivy < t_det)");
    }
}
