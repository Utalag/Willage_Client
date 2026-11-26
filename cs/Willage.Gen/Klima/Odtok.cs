namespace Willage.Gen.Klima;

/// <summary>Roční výpar a odtok podle Turca (1954): ET = P / √(0,9 + (P/L)²), L = 300 + 25T + 0,05T³ (mm, °C); odtok = max(0, P − ET).</summary>
public static class Odtok
{
    public static double L(double t) => Math.Max(50.0, 300 + 25 * t + 0.05 * t * t * t);
    public static double Vypar(double p, double t) { double l = L(t); return p <= 0 ? 0 : p / Math.Sqrt(0.9 + (p / l) * (p / l)); }
    public static double OdtokMm(double p, double t) => Math.Max(0, p - Vypar(p, t));
}
