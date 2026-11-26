namespace Willage.Gen.Jadro;

/// <summary>Kvantování metrů na 2⁻¹⁶ m (jednotka FxQ16 z Willage_Dev) pro otisky a výměnu dat.</summary>
public static class Q16
{
    public const int UnitsPerMetre = 65_536;
    public static long FromMetres(double m) => (long)Math.Round(m * UnitsPerMetre, MidpointRounding.ToEven);
    public static double ToMetres(long u) => u / (double)UnitsPerMetre;
}
