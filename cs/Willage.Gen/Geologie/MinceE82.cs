using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>
/// Mince E82 (krok 3): 50/50 podle světového bloku 128 m. Oprava kroku 5 (Jan 2026-11-26, rozhodnutí 7):
/// síla mince c ∈ [0, 1] je spojitá – kolem švu bloků v pásu šířky PrechodM přechází smoothstepem mezi mincemi
/// sousedních bloků (bilineárně v rohu). Mimo pás je c = mince bloku; PrechodM = 0 vrací původní skok.
/// </summary>
public sealed class MinceE82
{
    private readonly ParametrySveta _p;
    public MinceE82(ParametrySveta p) => _p = p;

    /// <summary>Původní mince bloku (bx, by).</summary>
    public bool Blok(long bx, long by)
    {
        if (!_p.P82Vapenec) return false;
        long h = StableHash.Mix(_p.Seed, "P82_VAPENEC", bx * 7919 + by);
        return (h & 0xFFFF) / 65536.0 < _p.P82Podil;
    }

    /// <summary>Původní mince bodu (geo_vrstvy.gd::mince82).</summary>
    public bool Puvodni(double x, double y) => Blok(Gd.Floori(x / _p.BlokM), Gd.Floori(y / _p.BlokM));

    /// <summary>Síla mince 0–1 (1 = vápenec zvednut a jíl vyklíněn naplno).</summary>
    public double Sila(double x, double y)
    {
        if (!_p.P82Vapenec) return 0.0;
        double w = _p.P82PrechodM, b = _p.BlokM;
        if (w <= 0.0) return Puvodni(x, y) ? 1.0 : 0.0;
        long ax = (long)Math.Round(x / b), ay = (long)Math.Round(y / b);     // nejbližší šev
        double tx = Gd.Smoothstep(-0.5 * w, 0.5 * w, x - ax * b), ty = Gd.Smoothstep(-0.5 * w, 0.5 * w, y - ay * b);
        double m00 = Blok(ax - 1, ay - 1) ? 1 : 0, m10 = Blok(ax, ay - 1) ? 1 : 0;
        double m01 = Blok(ax - 1, ay) ? 1 : 0, m11 = Blok(ax, ay) ? 1 : 0;
        return Gd.Lerpf(Gd.Lerpf(m00, m10, tx), Gd.Lerpf(m01, m11, tx), ty);
    }
}
