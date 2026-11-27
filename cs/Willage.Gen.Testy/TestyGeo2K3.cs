using System.Diagnostics;
using System.Runtime.InteropServices;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K3: index těles proti <c>Features</c>, přesné obálky (fuzz), bitová shoda GEO2 před/po K3 (všechna pole vzorku),
/// V7 determinismus (1 / N vláken, opačné pořadí), V6 odstraněná práce. Celý blok 128 m je zvlášť (<c>--jen=GEO2K3B</c>, <see cref="Blok"/>).
/// </summary>
public static class TestyGeo2K3
{
    private static readonly DruhUtvaru[] Druhy = { DruhUtvaru.Zila, DruhUtvaru.Cocka, DruhUtvaru.Kras, DruhUtvaru.Dome, DruhUtvaru.Pipe };

    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var g = new GeologieCs(new ParametrySveta(), d);
        var o = OblastBloku.Ctverec(1024, 512, 64);
        IndexProtiFeatures(g, o);
        Obalky(g, o);
        Shoda(kat, d, g, o);
    }

    /// <summary>Kandidáti indexu ⊆ Features (stejné pořadí) a žádný zásah (SDF &lt; 0) nechybí; počet vyhodnocení SDF před × po.</summary>
    private static void IndexProtiFeatures(GeologieCs g, OblastBloku o)
    {
        T.Sekce("GEO2 K3: index těles po dlaždicích 8 m proti Features staré cesty");
        var rnd = new Random(31); var u = g.Geo.Utvary; var tv = u.Tvorba;
        var pole = new int[4096];
        foreach (var druh in Druhy)
        {
            var ix = IndexUtvaruE84.Sestav(g.Svet, druh, o.Rozsir(4));
            long stare = 0, nove = 0, zasahu = 0, chybi = 0, poradi = 0;
            for (int k = 0; k < 20000; k++)
            {
                double x = o.X0 + rnd.NextDouble() * 64, y = o.Y0 + rnd.NextDouble() * 64, z = rnd.NextDouble() * 70;
                var st = tv.Features(x, y).Where(f => f.K == druh && z >= f.Box[2] && z <= f.Box[5]).ToList();
                int n = ix.Kandidati(x, y, z, pole);
                var nv = Enumerable.Range(0, n).Select(i => ix.Polozky[pole[i]].F).ToList();
                stare += st.Count; nove += n;
                int j = 0; foreach (var f in nv) { while (j < st.Count && !ReferenceEqualsP(st[j], f)) j++; if (j == st.Count) poradi++; }
                foreach (var f in st)
                    if (u.Sdf(f, x, y, z) < 0) { zasahu++; if (!nv.Any(h => ReferenceEqualsP(h, f))) chybi++; }
            }
            Console.WriteLine($"  {druh,-6} instancí {ix.Polozky.Count,4}, max v dlaždici {ix.MaxVDlazdici,3}; vyhodnocení SDF na 20 000 bodů: Features {stare,6:N0} → index {nove,6:N0} ({100.0 * (stare - nove) / Math.Max(stare, 1),5:F1} % ušetřeno), zásahů {zasahu:N0}");
            T.Je(chybi == 0, $"{druh}: žádný zásah (SDF < 0) mimo kandidáty indexu ({chybi})");
            T.Je(poradi == 0, $"{druh}: kandidáti indexu jsou podposloupnost Features ({poradi})");
        }
        static bool ReferenceEqualsP(Utvar a, Utvar b) => a.Seed == b.Seed && a.K == b.K && a.P.AsSpan().SequenceEqual(b.P);
    }

    /// <summary>Fuzz přesné obálky: bod s SDF &lt; 0 v obálce staré cesty leží v přesné obálce.</summary>
    private static void Obalky(GeologieCs g, OblastBloku o)
    {
        T.Sekce("GEO2 K3: přesné obálky (fuzz proti SDF)");
        var rnd = new Random(7); var u = g.Geo.Utvary;
        foreach (var druh in Druhy)
        {
            var ix = IndexUtvaruE84.Sestav(g.Svet, druh, o);
            long bodu = 0, uvnitr = 0, mimo = 0; double objS = 0, objN = 0;
            foreach (var p in ix.Polozky)
            {
                var b = p.F.Box;
                objS += (b[3] - b[0]) * (b[4] - b[1]) * (b[5] - b[2]); objN += (p.X1 - p.X0) * (p.Y1 - p.Y0) * (p.Z1 - p.Z0);
                for (int k = 0; k < 4000; k++)
                {
                    double x = b[0] + rnd.NextDouble() * (b[3] - b[0]), y = b[1] + rnd.NextDouble() * (b[4] - b[1]), z = b[2] + rnd.NextDouble() * (b[5] - b[2]);
                    bodu++;
                    if (u.Sdf(p.F, x, y, z) >= 0) continue;
                    uvnitr++;
                    if (x < p.X0 || x > p.X1 || y < p.Y0 || y > p.Y1 || z < p.Z0 || z > p.Z1) mimo++;
                }
            }
            Console.WriteLine($"  {druh,-6} bodů {bodu:N0}, uvnitř tělesa {uvnitr:N0}, objem obálky staré cesty → přesné {100.0 * objN / Math.Max(objS, 1e-9):F1} %");
            T.Je(mimo == 0, $"{druh}: žádný bod tělesa mimo přesnou obálku ({mimo})");
        }
    }

    /// <summary>Otisk vzorků sloupce (FNV-1a 64 přes 20 B vzorku).</summary>
    internal static ulong Otisk(ReadOnlySpan<Vzorek> s)
    {
        ulong h = 14695981039346656037UL;
        foreach (byte b in MemoryMarshal.AsBytes(s)) { h ^= b; h *= 1099511628211UL; }
        return h;
    }

    /// <summary>Sloupce bloku (x, y středů po krokXy, z po 0,25 m do 128 m) přes kontext: otisky sloupců, materiály.</summary>
    internal static void SloupceK3(KontextBloku k, double ox, double oy, int n, double krokXy, int vlaken, ulong[] otisky, byte[]? mat, bool obracene = false)
    {
        const int nz = 512;
        Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, ii =>
        {
            int ix = obracene ? n - 1 - ii : ii;
            Span<Vzorek> s = stackalloc Vzorek[nz];
            for (int jj = 0; jj < n; jj++)
            {
                int iy = obracene ? n - 1 - jj : jj;
                k.Sloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0, 0.25, s);
                otisky[ix * n + iy] = Otisk(s);
                if (mat is not null) { long o = ((long)ix * n + iy) * nz; for (int z = 0; z < nz; z++) mat[o + z] = (byte)s[z].Material; }
            }
        });
    }

    /// <summary>Totéž cestou před K3: chronologie a <c>GeologieCs.Klon()</c> na vlákno (keš Features, uzly na vlákno).</summary>
    internal static void SloupcePred(GeologieCs g0, KatalogGeo2 kat, DataSveta d, double ox, double oy, int n, double krokXy, int vlaken, double krokMrizky,
        ulong[] otisky, byte[]? mat, Action<PlochaVrstev>? plocha = null)
    {
        const int nz = 512;
        Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, () => { var g = g0.Klon(); return TestyGeo2K1b.E84(g, kat, d, krokMrizky).c; }, (ix, _, c) =>
        {
            var s = new Vzorek[nz];
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy, zPov = c.Povrch!(x, y);
                for (int z = 0; z < nz; z++) s[z] = c.Vzorek(x, y, (z + 0.5) * 0.25, zPov);
                otisky[ix * n + iy] = Otisk(s);
                if (mat is not null) { long o = ((long)ix * n + iy) * nz; for (int z = 0; z < nz; z++) mat[o + z] = (byte)s[z].Material; }
            }
            return c;
        }, c => plocha?.Invoke((PlochaVrstev)((KontaktniPasmo)c.Udalosti[c.IndexUdalosti("skarn_kontakt")].Kontakt!).Plochy[0]));
    }

    private static void Shoda(KatalogGeo2 kat, DataSveta d, GeologieCs g, OblastBloku o)
    {
        T.Sekce("GEO2 K3: bitová shoda před/po K3, V7 determinismus, V6 odstraněná práce (blok 64 m po 1 m)");
        const int n = 64; const double kr = 1.0; int vl = Environment.ProcessorCount;
        var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, SadaE84.Json(d), o);
        T.Je(r.Ok, $"kontext E84 se sestaví ({r.Zprava})");
        if (!r.Ok) return;
        Console.WriteLine($"  okraj {k.OkrajM:F3} m, připravených objektů {k.Pripravenych}");
        var a = new ulong[n * n]; var b = new ulong[n * n]; var c1 = new ulong[n * n]; var c2 = new ulong[n * n];
        var ma = new byte[n * n * 512]; var mb = new byte[n * n * 512];
        long uzlyPred = 0;
        SloupcePred(g, kat, d, o.X0, o.Y0, n, kr, vl, 0.5, a, ma, p => Interlocked.Add(ref uzlyPred, p.DopocitanychUzlu));
        SloupceK3(k, o.X0, o.Y0, n, kr, vl, b, mb);
        int ruzne = 0; for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) ruzne++;
        long ruzneM = 0; for (long i = 0; i < ma.Length; i++) if (ma[i] != mb[i]) ruzneM++;
        var hist = new long[256]; foreach (var m in mb) hist[m]++;
        Console.WriteLine($"  sloupců {a.Length}, různých otisků vzorků {ruzne}, různých materiálů {ruzneM}; skarn {hist[42]:N0}, pegmatit {hist[38]:N0}, kimberlit {hist[21]:N0}, sůl {hist[47]:N0}");
        T.Je(ruzne == 0 && ruzneM == 0, "Vzorek (všech 20 B) po K3 == před K3 na každé buňce");
        T.Je(hist[42] > 0 && hist[21] + hist[47] + hist[38] > 0, "blok obsahuje skarn i tělesa (test není prázdný)");
        SloupceK3(k, o.X0, o.Y0, n, kr, 1, c1, null);
        SloupceK3(k, o.X0, o.Y0, n, kr, vl, c2, null, obracene: true);
        T.Je(a.AsSpan().SequenceEqual(c1) && a.AsSpan().SequenceEqual(c2), $"V7: stejný otisk při 1 a {vl} vláknech a v opačném pořadí sloupců");
        var pl = (PlochaVrstev)((KontaktniPasmo)k.Chronologie.Udalosti[k.Chronologie.IndexUdalosti("skarn_kontakt")].Kontakt!).Plochy[0];
        Console.WriteLine($"  V6 uzly plochy kontaktu: před K3 {uzlyPred:N0} (součet keší {vl} vláken), po K3 předpočteno {pl.PredpocitanychUzlu:N0}, dopočteno mimo oblast {pl.DopocitanychUzlu:N0}");
        T.Je(pl.DopocitanychUzlu == 0, "okraj kontextu stačí: žádný uzel mimo předpočtenou oblast");
    }

    /// <summary>Blok 128 m: stará cesta × GEO2 před K3 (Klon na vlákno) × GEO2 K3 (kontext bloku); bitová shoda a výkon.</summary>
    public static void Blok(string data, double ox, double oy, int vlaken, double krokXy = 0.25, double krokMrizky = 0.5)
    {
        T.Sekce($"GEO2 K3: blok 128 × 128 m od ({ox}, {oy}), sloupce po {krokXy} m, z po 0,25 m, {vlaken} vláken");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g0 = new GeologieCs(new ParametrySveta(), d);
        int n = (int)Math.Round(128 / krokXy); const int nz = 512;
        var stary = new byte[(long)n * n * nz]; var mPred = new byte[stary.Length];
        var oPred = new ulong[n * n]; var oPo = new ulong[n * n];
        var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        var sw = Stopwatch.StartNew();
        Parallel.For(0, n, opt, () => g0.Klon(), (ix, _, g) =>
        {
            for (int iy = 0; iy < n; iy++)
                Array.Copy(g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0.25, 128.0), 0, stary, ((long)ix * n + iy) * nz, nz);
            return g;
        }, _ => { });
        double tStary = sw.Elapsed.TotalSeconds; sw.Restart();
        SloupcePred(g0, kat, d, ox, oy, n, krokXy, vlaken, krokMrizky, oPred, mPred);
        double tPred = sw.Elapsed.TotalSeconds; sw.Restart();
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), new MoznostiKompilace(krokMrizky), vlaken);
        double tKontext = sw.Elapsed.TotalSeconds; sw.Restart();
        var mPo = new byte[stary.Length];
        SloupceK3(k, ox, oy, n, krokXy, vlaken, oPo, mPo);
        double tPo = sw.Elapsed.TotalSeconds;
        int ruzne = 0; for (int i = 0; i < oPred.Length; i++) if (oPred[i] != oPo[i]) ruzne++;
        long shodaPred = 0, shodaPo = 0, ruzneM = 0;
        for (long i = 0; i < stary.Length; i++) { if (stary[i] == mPred[i]) shodaPred++; if (stary[i] == mPo[i]) shodaPo++; if (mPred[i] != mPo[i]) ruzneM++; }
        double c = stary.Length;
        Console.WriteLine($"  buněk {stary.LongLength:N0}; shoda se starou cestou: před K3 {100.0 * shodaPred / c:F3} %, po K3 {100.0 * shodaPo / c:F3} %");
        Console.WriteLine($"  bitově: různých otisků sloupců (20 B vzorku) {ruzne}, různých materiálů {ruzneM}");
        var zas = (ZasobnikVrstvySloupce)k.Chronologie.Udalosti[0].Zasobnik!;
        Console.WriteLine($"  V6 volání Hranice (bodové sloupce) po K3: {zas.VolaniHranic:N0} = {zas.VolaniHranic / (double)(n * n):F2} na sloupec");
        Console.WriteLine($"  čas: stará cesta {tStary:F1} s; GEO2 před K3 {tPred:F1} s (×{tPred / tStary:F1}); GEO2 K3 {tPo:F1} s + kontext {tKontext:F2} s (×{(tPo + tKontext) / tStary:F1})");
        T.Je(ruzne == 0 && ruzneM == 0 && shodaPred == shodaPo, "blok: GEO2 po K3 bitově == před K3");
    }
}
