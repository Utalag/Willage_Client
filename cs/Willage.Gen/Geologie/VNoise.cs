using Willage.Gen.Sum;

namespace Willage.Gen.Geologie;

/// <summary>Hodnotový 3D šum útvarů (utvary.gd::vnoise, _lat, _u) nad splitmix64.</summary>
public static class VNoise
{
    public static double U(long h) => StableHash.Shr(h, 40) / 16777216.0;

    private static double Lat(long seed, long i, long j, long k) =>
        U(StableHash.SplitMix64(StableHash.SplitMix64(StableHash.SplitMix64(seed ^ i) ^ j) ^ k)) * 2.0 - 1.0;

    public static double Noise(long seed, double x, double y, double z)
    {
        long xi = Gd.Floori(x), yi = Gd.Floori(y), zi = Gd.Floori(z);
        double tx = x - xi, ty = y - yi, tz = z - zi;
        tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty); tz = tz * tz * (3.0 - 2.0 * tz);
        double a = Gd.Lerpf(Lat(seed, xi, yi, zi), Lat(seed, xi + 1, yi, zi), tx);
        double b = Gd.Lerpf(Lat(seed, xi, yi + 1, zi), Lat(seed, xi + 1, yi + 1, zi), tx);
        double c = Gd.Lerpf(Lat(seed, xi, yi, zi + 1), Lat(seed, xi + 1, yi, zi + 1), tx);
        double d = Gd.Lerpf(Lat(seed, xi, yi + 1, zi + 1), Lat(seed, xi + 1, yi + 1, zi + 1), tx);
        return Gd.Lerpf(Gd.Lerpf(a, b, ty), Gd.Lerpf(c, d, ty), tz);
    }
}
