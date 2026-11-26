using System.Diagnostics;
using System.Security.Cryptography;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>Otisk kroku 3 jako tools/geo_v1.gd::_det: svět 3 × 3 od start_m, 2 m v XY, 1 m v Z, SHA-256 bajtů (prvních 16 hex).</summary>
public static class OtiskKrok3
{
    public static (string otisk, long bunek, double ms) Spocti(ParametrySveta p, DataSveta d, double krokXy = 2.0, double krokZ = 1.0, double strana = 384.0)
    {
        var sw = Stopwatch.StartNew();
        var g = new GeologieCs(p, d);
        double ox = p.StartBlok[0] * p.BlokM, oy = p.StartBlok[1] * p.BlokM;
        int n = (int)(strana / krokXy), zmax = (int)(128.0 / krokZ);
        var buf = new byte[(long)n * n * zmax]; long i = 0;
        for (int ix = 0; ix < n; ix++)
        for (int iy = 0; iy < n; iy++)
        {
            var sl = g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, krokZ, 128.0);
            for (int iz = 0; iz < zmax; iz++) buf[i++] = iz < sl.Length ? sl[iz] : (byte)0;
        }
        Console.WriteLine($"  kolize cache _zs (klíč 0,25 m, jiný přesný střed útvaru): {g.Geo.Utvary.Tvorba.KolizeZs}");
        var hx = Convert.ToHexString(SHA256.HashData(buf)).ToLowerInvariant();
        return (hx[..16], buf.LongLength, sw.Elapsed.TotalMilliseconds);
    }
}
