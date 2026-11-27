using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Přesné obálky těles E84 (2.6, K3): AABB množiny, kde <see cref="Utvary.Sdf"/> může být &lt; 0, s rezervou <see cref="Rezerva"/>.
/// Vždy průnik s obálkou staré cesty (<see cref="Utvar.Box"/>), aby se výsledek nezměnil (dnešní ořez čočky zůstává, K3 ho neopravuje).
/// <list type="bullet">
/// <item>komín, dóm (osový elipsoid, SDF &lt; 0 ⇔ k0 &lt; 1): ±(ra, rb, rc) kolem středu; stará obálka komínu má v xy max(ra, rc).</item>
/// <item>čočka (natočený elipsoid s ortonormálními osami u, v, n): poloosa AABB v ose k = √Σ (r_i·e_i,k)².</item>
/// <item>žíla: SDF &lt; 0 ⇒ a² + b² &lt; 1 a |s| &lt; t₀ + amp (|šum| ≤ 1): AABB elipsy v rovině (u, v) + |n_k|·(t₀ + amp).</item>
/// <item>kras: obálka staré cesty (deformace šumem amplitudy A).</item>
/// </list>
/// </summary>
public static class ObalkaE84
{
    public const double Rezerva = 1e-6;

    /// <summary>[x0, y0, z0, x1, y1, z1].</summary>
    public static double[] Presna(Utvar f)
    {
        var P = f.P; var b = f.Box;
        double hx, hy, hz;
        switch (f.K)
        {
            case DruhUtvaru.Pipe or DruhUtvaru.Dome when Osove(P):
                hx = P[12]; hy = P[13]; hz = P[14];
                break;
            case DruhUtvaru.Cocka when Ortonormalni(P, 3, 6, 9):
                hx = Elips(P[12] * P[3], P[13] * P[6], P[14] * P[9]);
                hy = Elips(P[12] * P[4], P[13] * P[7], P[14] * P[10]);
                hz = Elips(P[12] * P[5], P[13] * P[8], P[14] * P[11]);
                break;
            case DruhUtvaru.Zila when Ortonormalni(P, 3, 6, 9):
            {
                double t = P[12] + P[15];
                hx = Elips(P[13] * P[6], P[14] * P[9], 0) + Math.Abs(P[3]) * t;
                hy = Elips(P[13] * P[7], P[14] * P[10], 0) + Math.Abs(P[4]) * t;
                hz = Elips(P[13] * P[8], P[14] * P[11], 0) + Math.Abs(P[5]) * t;
                break;
            }
            default:
                return (double[])b.Clone();
        }
        double r = Rezerva;
        return new[]
        {
            Math.Max(b[0], P[0] - hx - r), Math.Max(b[1], P[1] - hy - r), Math.Max(b[2], P[2] - hz - r),
            Math.Min(b[3], P[0] + hx + r), Math.Min(b[4], P[1] + hy + r), Math.Min(b[5], P[2] + hz + r),
        };
    }

    private static double Elips(double a, double b, double c) => Math.Sqrt(a * a + b * b + c * c);

    private static bool Osove(double[] P) =>
        P[3] == 1 && P[4] == 0 && P[5] == 0 && P[6] == 0 && P[7] == 1 && P[8] == 0 && P[9] == 0 && P[10] == 0 && P[11] == 1;

    private static bool Ortonormalni(double[] P, int a, int b, int c)
    {
        double D(int i, int j) => P[i] * P[j] + P[i + 1] * P[j + 1] + P[i + 2] * P[j + 2];
        const double e = 1e-9;
        return Math.Abs(D(a, a) - 1) < e && Math.Abs(D(b, b) - 1) < e && Math.Abs(D(c, c) - 1) < e
            && Math.Abs(D(a, b)) < e && Math.Abs(D(a, c)) < e && Math.Abs(D(b, c)) < e;
    }
}
