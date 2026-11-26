namespace Willage.Gen.Sum;

/// <summary>Matematika GDScriptu / Godotu 4 (math_funcs.h) bitově stejně: MIN/MAX/CLAMP makra, lerp, smoothstep, floori.</summary>
public static class Gd
{
    public static double Minf(double a, double b) => a < b ? a : b;
    public static double Maxf(double a, double b) => a > b ? a : b;
    public static double Clampf(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
    public static int Clampi(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
    public static double Lerpf(double a, double b, double t) => a + (b - a) * t;
    public static long Floori(double x) => (long)Math.Floor(x);
    public static double DegToRad(double d) => d * (Math.PI / 180.0);
    public const double Tau = 6.2831853071795864769252867666;

    public static bool IsEqualApprox(double a, double b)
    {
        if (a == b) return true;
        double tol = 1e-5 * Math.Abs(a);
        if (tol < 1e-5) tol = 1e-5;
        return Math.Abs(a - b) < tol;
    }

    public static double Smoothstep(double from, double to, double s)
    {
        if (IsEqualApprox(from, to))
            return from <= to ? (s <= from ? 0.0 : 1.0) : (s <= to ? 1.0 : 0.0);
        double t = Clampf((s - from) / (to - from), 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
    }

    /// <summary>round() Godotu: od nuly při .5.</summary>
    public static double Round(double x) => Math.Round(x, MidpointRounding.AwayFromZero);
}
