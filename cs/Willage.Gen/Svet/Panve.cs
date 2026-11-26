namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6b (Jan 10:03 b): několik velkých pánví v terénu pro velká jezera. Středy ze seedu (hash), jen na pevnině
/// (s mořem: dn > P + T + R), mimo start svět (vzdálenost od středu startu > R + 300 m) a od sebe ≥ 2R.
/// Profil −D·(1 − (r/R)²)², hladký. Přepínač ParametrySveta.Panve, výchozí vypnuto.
/// </summary>
public sealed class Panve
{
    private readonly double _r, _d;
    public List<(double X, double Y)> Stredy { get; } = new();

    public Panve(ParametrySveta p, HashSveta h, MoreSklon? more)
    {
        _r = p.PanevPolomerM; _d = p.PanevHloubkaM;
        double sx = (p.StartBlok[0] + 0.5) * p.BlokM, sy = (p.StartBlok[1] + 0.5) * p.BlokM;
        for (int i = 0; i < 256 && Stredy.Count < p.PanviPocet; i++)
        {
            double x = h.U("V1_PANEV_X", i, 0) * p.PlanetaXM, y = h.U("V1_PANEV_Y", i, 0) * p.PlanetaYM;
            if (more is not null && more.Dn(x, y) <= more.Pas + p.MorePrechodM + _r) continue;
            if (Math.Sqrt((x - sx) * (x - sx) + (y - sy) * (y - sy)) <= _r + 300.0 + p.BlokM * 1.5) continue;
            if (Stredy.Any(s => Math.Sqrt((x - s.X) * (x - s.X) + (y - s.Y) * (y - s.Y)) < 2 * _r)) continue;
            Stredy.Add((x, y));
        }
    }

    public double Posun(double x, double y)
    {
        double o = 0;
        foreach (var (cx, cy) in Stredy)
        {
            double dx = x - cx, dy = y - cy, q = (dx * dx + dy * dy) / (_r * _r);
            if (q < 1) o -= _d * (1 - q) * (1 - q);
        }
        return o;
    }

    public string Kanonicky() => FormattableString.Invariant($"panve|{Stredy.Count}|{_r}|{_d}|{string.Join(";", Stredy.Select(s => $"{s.X:R},{s.Y:R}"))}");
}
