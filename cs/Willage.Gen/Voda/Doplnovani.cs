using Willage.Gen.Geologie;

namespace Willage.Gen.Voda;

/// <summary>
/// Výška oblasti doplňování (1.8.1): nejvyšší povrch v okolí R, kde stejná hornina vychází na povrch
/// (uzly světové mřížky). Tlaková výška sevřené vrstvy = tato výška; neukládá se.
/// Zjednodušení: totožnost vrstvy = ID horniny (stejná hornina v jiném pásmu se nerozliší).
/// </summary>
public sealed class Doplnovani
{
    private readonly IGeologie _g;
    private readonly ParametryVody _p;

    public Doplnovani(IGeologie g, ParametryVody p) { _g = g; _p = p; }

    /// <summary>Výška doplňování, nebo null, když hornina v okolí nevychází.</summary>
    public (double vyska, double x, double y)? Vyska(double x, double y, int material)
    {
        double s = _p.MrizkaDoplnM, R = _p.PolomerDoplnM, R2 = R * R;
        int i0 = (int)Math.Ceiling((x - R) / s), i1 = (int)Math.Floor((x + R) / s);
        int j0 = (int)Math.Ceiling((y - R) / s), j1 = (int)Math.Floor((y + R) / s);
        (double, double, double)? best = null;
        for (int i = i0; i <= i1; i++)
        for (int j = j0; j <= j1; j++)
        {
            double nx = i * s, ny = j * s, dx = nx - x, dy = ny - y;
            if (dx * dx + dy * dy > R2) continue;
            if (_g.MaterialPovrchu(nx, ny) != material) continue;
            double h = _g.Povrch(nx, ny);
            if (best is null || h > best.Value.Item1) best = (h, nx, ny);
        }
        return best;
    }
}
