using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;

namespace Willage.Gen.Testy.Vykon;

public enum Cesta { Geo1, K3, Geo2Vychozi }

/// <summary>Jedna měřená cesta pro blok 128 m: kontext (čas zvlášť) + sloupce; vrací kontrolní součet výstupu (součet otisků sloupců, nezávislý na pořadí vláken).</summary>
public static class VykonCesty
{
    public const int Nz = 512;

    public static (double Kontext, double Sloupce, ulong Soucet) Spust(Cesta cesta, GeologieCs g0, KatalogGeo2 kat, DataSveta d, double ox, double oy, double krokXy, int vlaken)
    {
        int n = (int)Math.Round(128 / krokXy); var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        long soucet = 0; double tk = 0;
        var sw = System.Diagnostics.Stopwatch.StartNew();
        if (cesta == Cesta.Geo1)
        {
            Parallel.For(0, n, opt, () => g0.Klon(), (ix, _, g) =>
            {
                long s = 0;
                for (int iy = 0; iy < n; iy++) s += (long)Hash(g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0.25, 128.0));
                Interlocked.Add(ref soucet, s); return g;
            }, _ => { });
            return (0, sw.Elapsed.TotalSeconds, (ulong)soucet);
        }
        var moz = cesta == Cesta.K3 ? new MoznostiKompilace(0.5) : null;
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), moz, vlaken);
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        tk = sw.Elapsed.TotalSeconds; sw.Restart();
        Parallel.For(0, n, opt, ix =>
        {
            long s = 0; var v = new Vzorek[Nz];
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy;
                if (cesta == Cesta.K3) k.SloupecPoBodech(x, y, 0, 0.25, v); else k.Sloupec(x, y, 0, 0.25, v);
                s += (long)TestyGeo2K3.Otisk(v);
            }
            Interlocked.Add(ref soucet, s);
        });
        return (tk, sw.Elapsed.TotalSeconds, (ulong)soucet);
    }

    private static ulong Hash(byte[] a) { ulong h = 14695981039346656037UL; foreach (var b in a) h = unchecked((h ^ b) * 1099511628211UL); return h; }
}
