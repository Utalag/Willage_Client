namespace Willage.Gen.Testy;

/// <summary>Minimální běžec testů (bez NuGet).</summary>
public static class T
{
    public static int Chyb, Ok;
    public static void Je(bool c, string co) { if (c) Ok++; else { Chyb++; Console.WriteLine("  CHYBA: " + co); } }
    public static void Blizko(double a, double b, double tol, string co) => Je(Math.Abs(a - b) <= tol, $"{co}: {a} ≠ {b} (±{tol})");
    public static void Sekce(string s) => Console.WriteLine("- " + s);
}
