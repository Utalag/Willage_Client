using System.Diagnostics;
using System.Security.Cryptography;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>Časy a otisky segmentů 8 m (jako tools/geo_cs_cas.gd) a bloku 128 m po 0,25 m (krok 3), jedno vlákno.</summary>
public static class Casy
{
    public static readonly (double x, double y)[] Segmenty = { (1792, 1792), (1856, 1920), (2000, 1800), (2104, 2104) };

    public static void Spust(DataSveta d, bool opravy, bool blok)
    {
        var sw = Stopwatch.StartNew();
        var g = new GeologieCs(opravy ? new ParametrySveta() : ParametrySveta.Puvodni(), d);
        Console.WriteLine($"init_ms {sw.Elapsed.TotalMilliseconds:F0} ({(opravy ? "opravy" : "puvodni")})");
        foreach (var (ox, oy) in Segmenty)
        {
            sw.Restart();
            var (o, _) = Oblast(g, ox, oy, 32);
            Console.WriteLine($"segment {ox},{oy} ms {sw.Elapsed.TotalMilliseconds:F0} otisk {o}");
        }
        if (!blok) return;
        sw.Restart();
        var (ob, n) = Oblast(g, 1792, 1792, 512);
        Console.WriteLine($"blok 14,14 po 0,25 m ({n} buněk) ms {sw.Elapsed.TotalMilliseconds:F0} otisk {ob}");
    }

    public static (string, long) Oblast(GeologieCs g, double ox, double oy, int n)
    {
        using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256); long bunek = 0;
        for (int ix = 0; ix < n; ix++)
        for (int iy = 0; iy < n; iy++)
        {
            var s = g.Geo.VyplnSloupec(ox + (ix + 0.5) * 0.25, oy + (iy + 0.5) * 0.25, 0.25, 128.0);
            sha.AppendData(s); bunek += s.Length;
        }
        return (Convert.ToHexString(sha.GetHashAndReset())[..16].ToLowerInvariant(), bunek);
    }
}
