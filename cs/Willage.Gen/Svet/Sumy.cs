using System.Globalization;
using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>Továrny šumů jako block_gen.gd::noise a geo2.gd::_noise / n01 (včetně cache geo2 podle klíče "%d_%s_%d_%f").</summary>
public sealed class Sumy
{
    private readonly Dictionary<string, GodotSum> _nc = new();

    /// <summary>BG.noise: OpenSimplex2S, FBm, lacunarita 2, gain 0,5, bez deformace.</summary>
    public static GodotSum Bg(long seed, string ucel, long vrstva, double freq, int oktav = 5) => new()
    {
        Seed = StableHash.NoiseSeed(seed, ucel, vrstva), Frequency = freq, FractalOctaves = oktav,
        FractalLacunarity = 2.0, FractalGain = 0.5, FractalWeightedStrength = 0.0, DomainWarpEnabled = false,
    };

    /// <summary>geo2._noise: 3 oktávy, doménová deformace 5 m s frekvencí freq/2; cache podle "%f" jako v GDScriptu.</summary>
    public GodotSum G2(long seed, string ucel, long k, double freq)
    {
        string key = $"{seed}_{ucel}_{k}_{freq.ToString("F6", CultureInfo.InvariantCulture)}";
        if (_nc.TryGetValue(key, out var n)) return n;
        n = new GodotSum
        {
            Seed = StableHash.NoiseSeed(seed, ucel, k), Frequency = freq, FractalOctaves = 3,
            DomainWarpEnabled = true, DomainWarpAmplitude = 5.0, DomainWarpFrequency = freq * 0.5,
        };
        _nc[key] = n;
        return n;
    }

    public static double N01(GodotSum n, double x, double y) => Gd.Clampf(n.Noise2D(x, y) * 0.5 + 0.5, 0.0, 1.0);

    public double N01(long seed, string ucel, long k, double freq, double x, double y) =>
        Gd.Clampf(G2(seed, ucel, k, freq).Noise2D(x, y) * 0.5 + 0.5, 0.0, 1.0);

    /// <summary>svet_fn._grad_sumu: max |∇n| na pevné sadě bodů.</summary>
    public static double GradSumu(GodotSum n, double freq, int vzorku = 8000)
    {
        double g = 0.0, e = 0.001 / freq;
        for (int i = 0; i < vzorku; i++)
        {
            double x = ((double)(i % 61) * 7.31 + (double)i * 0.137) / freq;
            double y = ((double)(i / 61) * 5.77 + (double)(i % 7) * 0.71) / freq;
            double gx = (n.Noise2D(x + e, y) - n.Noise2D(x - e, y)) / (2.0 * e);
            double gy = (n.Noise2D(x, y + e) - n.Noise2D(x, y - e)) / (2.0 * e);
            g = Gd.Maxf(g, Math.Sqrt(gx * gx + gy * gy));
        }
        return g;
    }
}
