namespace Willage.Gen.Eroze;

/// <summary>
/// Jeden krok stream-power eroze ∂h/∂t = −K A^m S (n = 1) implicitně podle Braun & Willett 2013 [85]:
/// h_i ← (h_i + F h_r) / (1 + F), F = K dt A^m / L, v pořadí od odtoků nahoru. Jen eroze (žádné zvednutí, žádné ukládání),
/// celkově nejvýš MaxEroseM pod podklad.
/// </summary>
public static class StreamPower
{
    public static void Krok(Torus t, double[] h, float[] h0, float[] a, sbyte[] prij, int[] vzestupne, ParametryEroze p)
    {
        double kdt = p.K * p.DtRoku;
        foreach (int k in vzestupne)
        {
            int d = prij[k];
            if (d < 0) continue;
            int r = t.Soused(k, d);
            if (h[r] >= h[k]) continue;                    // jezero / rovina: neerodovat ani neukládat
            double f = kdt * Math.Pow(a[k], p.M) / (Torus.Delka[d] * t.Krok);
            double nh = (h[k] + f * h[r]) / (1.0 + f);
            double dno = h0[k] - p.MaxEroseM;
            h[k] = nh < dno ? dno : nh;
        }
    }
}
