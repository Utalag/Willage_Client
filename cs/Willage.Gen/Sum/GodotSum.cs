namespace Willage.Gen.Sum;

/// <summary>
/// FastNoiseLite s chováním Godotu 4 (modules/noise/fastnoise_lite.cpp): parametry a souřadnice jako float (real_t),
/// doménová deformace v samostatném objektu se stejným seedem, výchozí hodnoty Godotu. Jen 2D a typy, které generátor V1 používá.
/// </summary>
public sealed class GodotSum
{
    private readonly FastNoiseLite _n = new();
    private readonly FastNoiseLite _w = new();
    private bool _warp;

    public GodotSum()
    {
        // výchozí hodnoty Godotu (fastnoise_lite.h)
        _n.SetNoiseType(FastNoiseLite.NoiseType.OpenSimplex2S);
        _n.SetSeed(0); _n.SetFrequency(0.01f);
        _n.SetFractalType(FastNoiseLite.FractalType.FBm); _n.SetFractalOctaves(5);
        _n.SetFractalLacunarity(2f); _n.SetFractalGain(0.5f); _n.SetFractalWeightedStrength(0f); _n.SetFractalPingPongStrength(2f);
        _w.SetDomainWarpType(FastNoiseLite.DomainWarpType.OpenSimplex2); _w.SetSeed(0); _w.SetDomainWarpAmp(30f);
        _w.SetFrequency(0.05f); _w.SetFractalType(FastNoiseLite.FractalType.DomainWarpProgressive);
        _w.SetFractalOctaves(5); _w.SetFractalLacunarity(6f); _w.SetFractalGain(0.5f);
    }

    public int Seed { set { _n.SetSeed(value); _w.SetSeed(value); } }
    public double Frequency { set => _n.SetFrequency((float)value); }
    public int FractalOctaves { set => _n.SetFractalOctaves(value); }
    public double FractalLacunarity { set => _n.SetFractalLacunarity((float)value); }
    public double FractalGain { set => _n.SetFractalGain((float)value); }
    public double FractalWeightedStrength { set => _n.SetFractalWeightedStrength((float)value); }
    public bool DomainWarpEnabled { set => _warp = value; }
    public double DomainWarpAmplitude { set => _w.SetDomainWarpAmp((float)value); }
    public double DomainWarpFrequency { set => _w.SetFrequency((float)value); }

    /// <summary>get_noise_2d(real_t x, real_t y): souřadnice se převedou na float jako v Godotu (offset 0).</summary>
    public double Noise2D(double x, double y)
    {
        float fx = (float)x, fy = (float)y;
        if (_warp) _w.DomainWarp(ref fx, ref fy);
        return _n.GetNoise(fx, fy);
    }
}
