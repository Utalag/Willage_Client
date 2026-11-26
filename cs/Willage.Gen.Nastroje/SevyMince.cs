using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>
/// Skok vrstev na švech bloků (mince E82) před / po opravě: pro švy v okně bloků porovná sousední sloupce 0,25 m
/// přes šev a uvnitř bloku (kontrola). Metriky: počet různých buněk 0,25 m mezi sloupci a skok stropu vápence.
/// Uloží řez švem (materiály) pro obrázek.
/// </summary>
public static class SevyMince
{
    private static readonly int[] Vap = { 5, 44, 49 };

    public static void Spust(DataSveta d, string vystup)
    {
        Directory.CreateDirectory(vystup);
        var gp = new GeologieCs(ParametrySveta.Puvodni(), d);
        var go = new GeologieCs(new ParametrySveta(), d);
        Console.WriteLine("mince bloků 12..17 (řádky y od 17 dolů):");
        for (int by = 17; by >= 12; by--)
            Console.WriteLine("  " + string.Join(" ", Enumerable.Range(12, 6).Select(bx => gp.Geo.Mince.Blok(bx, by) ? "V" : ".")));
        var radky = new List<string> { "rezim;sev;ruzne_mince;par;sloupcu;bunek_ruznych_prumer;bunek_ruznych_max;skok_vapence_prumer_m;skok_vapence_max_m" };
        foreach (var (jm, g) in new[] { ("puvodni", gp), ("opravy", go) })
            for (int bx = 13; bx <= 16; bx++)                    // svislé švy x = bx·128 v pásu y 14..16
            {
                double xs = bx * 128.0;
                bool ruzne = g.Geo.Mince.Blok(bx - 1, 15) != g.Geo.Mince.Blok(bx, 15);
                foreach (var (par, dx0, dx1) in new[] { ("sev", -0.125, 0.125), ("uvnitr", -32.125, -31.875) })
                {
                    double sum = 0, mx = 0, sv = 0, mv = 0; int n = 0;
                    for (double y = 15 * 128 + 1.0; y < 16 * 128; y += 2.0)
                    {
                        var a = g.Sloupec(xs + dx0, y); var b = g.Sloupec(xs + dx1, y);
                        int r = 0; for (int k = 0; k < a.Length; k++) if (a[k] != b[k]) r++;
                        double va = StropVap(a), vb = StropVap(b), dv = Math.Abs(va - vb);
                        sum += r; mx = Math.Max(mx, r); sv += dv; mv = Math.Max(mv, dv); n++;
                    }
                    radky.Add($"{jm};{bx};{(ruzne ? 1 : 0)};{par};{n};{sum / n:F2};{mx};{sv / n:F2};{mv:F2}");
                }
            }
        File.WriteAllLines(Path.Combine(vystup, "sevy_mince.csv"), radky);
        foreach (var r in radky) Console.WriteLine(r);
    }

    /// <summary>Strop nejvyššího vápence ve sloupci (m), 0 když chybí.</summary>
    public static double StropVap(byte[] s)
    {
        for (int k = s.Length - 1; k >= 0; k--) if (Vap.Contains(s[k])) return (k + 1) * 0.25;
        return 0.0;
    }

    /// <summary>Řez napříč švem x = xs v řádku y: materiály 0,25 m × 0,25 m, x od xs − pul do xs + pul (binárně: nx, nz, bajty).</summary>
    public static void Rez(DataSveta d, string soubor, bool opravy, double xs, double y, double pul)
    {
        var g = new GeologieCs(opravy ? new ParametrySveta() : ParametrySveta.Puvodni(), d);
        int nx = (int)(2 * pul / 0.25);
        using var w = new BinaryWriter(File.Create(soubor));
        w.Write(nx); w.Write(512); w.Write(xs - pul); w.Write(y);
        for (int i = 0; i < nx; i++)
        {
            double x = xs - pul + (i + 0.5) * 0.25;
            w.Write(g.Povrch(x, y)); w.Write(g.Mince82Sila(x, y));
            w.Write(g.Sloupec(x, y));
        }
    }
}
