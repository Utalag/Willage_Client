namespace Willage.Gen.Testy.Vykon;

/// <summary>Statistika opakovaných měření času: medián, min, max, relativní rozptyl (max − min) / medián.</summary>
public readonly record struct Statistika(double Median, double Min, double Max, int N)
{
    public double RelRozptyl => Median <= 0 ? 0 : (Max - Min) / Median;

    public static Statistika Z(IReadOnlyList<double> v)
    {
        var s = v.OrderBy(q => q).ToArray(); int n = s.Length;
        double med = n % 2 == 1 ? s[n / 2] : 0.5 * (s[n / 2 - 1] + s[n / 2]);
        return new Statistika(med, s[0], s[^1], n);
    }

    public override string ToString() => $"{Median:F2} s (min {Min:F2}, max {Max:F2}, rozptyl {100 * RelRozptyl:F0} %)";
}
