using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Eroze;

/// <summary>
/// Povrch světa jako periodická funkce na torusu Px × Py. Funkce světa (krok 2) periodická není, proto se v pásu šířky W
/// u švu (0 ≤ x' &lt; W) míchá h(x', y) s h(x' + Px, y) vahou 1 − smoothstep(0, W, x') (obdobně y, v rohu bilineárně).
/// Spojité a periodické; mimo pás přesně povrch světa. Svět se staví s svet_max_m ≥ max(Px, Py) + W.
/// </summary>
public sealed class PeriodickyPodklad
{
    public SvetFn Svet { get; }
    public double Px { get; }
    public double Py { get; }
    public double W { get; }

    public PeriodickyPodklad(SvetFn svet, double px, double py, double w)
    {
        if (svet.SvetM < Math.Max(px, py) + w) throw new ArgumentException("svet_max_m musí pokrýt planetu + pás prolnutí");
        Svet = svet; Px = px; Py = py; W = w;
    }

    public static double Zabal(double v, double p) { double r = v % p; return r < 0 ? r + p : r; }

    public double Vyska(double x, double y)
    {
        double xs = Zabal(x, Px), ys = Zabal(y, Py);
        double ax = xs < W ? 1.0 - Gd.Smoothstep(0, W, xs) : 0.0, ay = ys < W ? 1.0 - Gd.Smoothstep(0, W, ys) : 0.0;
        double h = (1 - ax) * (1 - ay) * Svet.Vyska(xs, ys);
        if (ax > 0) h += ax * (1 - ay) * Svet.Vyska(xs + Px, ys);
        if (ay > 0) h += (1 - ax) * ay * Svet.Vyska(xs, ys + Py);
        if (ax > 0 && ay > 0) h += ax * ay * Svet.Vyska(xs + Px, ys + Py);
        return h;
    }
}
