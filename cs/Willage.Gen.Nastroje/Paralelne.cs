using System.Diagnostics;
using System.Security.Cryptography;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>Blok 128 m po 0,25 m (krok 3) na 1 a N vláknech: shoda otisku a čas.</summary>
public static class Paralelne
{
    public static int Spust(DataSveta d, bool puvodni, int[] vlakna)
    {
        var g = new GeologieCs(puvodni ? ParametrySveta.Puvodni() : new ParametrySveta(), d);
        string? prvni = null; int chyb = 0;
        foreach (int v in vlakna)
        {
            var sw = Stopwatch.StartNew();
            var buf = ParalelniSloupce.Oblast(g, 1792, 1792, 512, v);
            double ms = sw.Elapsed.TotalMilliseconds;
            string o = Convert.ToHexString(SHA256.HashData(buf))[..16].ToLowerInvariant();
            prvni ??= o; if (o != prvni) chyb++;
            Console.WriteLine($"blok 14,14 po 0,25 m ({buf.LongLength} buněk), vláken {v}: {ms:F0} ms, otisk {o}{(o == prvni ? "" : " ≠ !")}");
        }
        return chyb;
    }
}
