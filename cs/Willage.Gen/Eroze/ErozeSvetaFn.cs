namespace Willage.Gen.Eroze;

/// <summary>Zdroj eroze pro funkci světa: kolik metrů odebrat v bodě (≥ 0).</summary>
public interface IErozeSveta { double Hloubka(double x, double y); }

/// <summary>
/// Jemný detail jako funkce nad hrubou mapou (žádné dlaždice → žádné švy): bilineárně E z periodických uzlů
/// ukotvených ve světě (i·krok) + zahloubení koryta podle vzdálenosti k úsekům uzel→příjemce. Šířka w = a·Q^0,5,
/// hloubka d = c·Q^0,4 (Leopold & Maddock 1953 [88]), profil d·(1 − t²)², t = vzdálenost/(w/2), přes úseky maximum.
/// </summary>
public sealed class ErozeSvetaFn : IErozeSveta
{
    private readonly MapaEroze _m; private readonly ParametryEroze _p;
    private readonly float[] _w, _d;    // polovina šířky a hloubka koryta v uzlu (0 = není koryto)
    private readonly double _px, _py;

    public ErozeSvetaFn(MapaEroze m, ParametryEroze p)
    {
        _m = m; _p = p; var t = m.T;
        _px = t.Nx * t.Krok; _py = t.Ny * t.Krok;
        _w = new float[t.N]; _d = new float[t.N];
        for (int k = 0; k < t.N; k++)
        {
            if ((m.Priznaky[k] & MapaEroze.Koryto) == 0 || m.Prijemce[k] < 0) continue;
            double q = Prutok(k) / 1000.0;   // m³/s
            _w[k] = (float)(0.5 * Math.Min(t.Krok, Math.Max(p.KorytoMinSirkaM, p.KorytoA * Math.Sqrt(q))));
            _d[k] = (float)Math.Min(p.KorytoMaxHloubkaM, p.KorytoC * Math.Pow(q, 0.4));
        }
    }

    /// <summary>Průtok v uzlu (l/s).</summary>
    public double Prutok(int k) => _m.A[k] / 1e6 * _p.SpecifickyOdtokLsKm2;

    public double ErozeE(double x, double y)
    {
        var t = _m.T;
        double fx = PeriodickyPodklad.Zabal(x, _px) / t.Krok, fy = PeriodickyPodklad.Zabal(y, _py) / t.Krok;
        int i = (int)Math.Floor(fx), j = (int)Math.Floor(fy); double u = fx - i, v = fy - j;
        double e00 = _m.E(t.K(i, j)), e10 = _m.E(t.K(i + 1, j)), e01 = _m.E(t.K(i, j + 1)), e11 = _m.E(t.K(i + 1, j + 1));
        return (e00 * (1 - u) + e10 * u) * (1 - v) + (e01 * (1 - u) + e11 * u) * v;
    }

    public double Koryto(double x, double y)
    {
        var t = _m.T; double s = t.Krok;
        double xs = PeriodickyPodklad.Zabal(x, _px), ys = PeriodickyPodklad.Zabal(y, _py);
        int i0 = (int)Math.Floor(xs / s), j0 = (int)Math.Floor(ys / s);
        double best = 0;
        for (int dj = -1; dj <= 2; dj++)
        for (int di = -1; di <= 2; di++)
        {
            int k = t.K(i0 + di, j0 + dj);
            if (_d[k] <= 0) continue;
            int dir = _m.Prijemce[k];
            double ax = (i0 + di) * s, ay = (j0 + dj) * s;            // nezabalené vůči bodu → bez švu
            double bx = ax + Torus.Dx[dir] * s, by = ay + Torus.Dy[dir] * s;
            int r = t.Soused(k, dir);
            double vx = bx - ax, vy = by - ay, l2 = vx * vx + vy * vy;
            double q = Math.Clamp(((xs - ax) * vx + (ys - ay) * vy) / l2, 0, 1);
            double dx = xs - (ax + q * vx), dy = ys - (ay + q * vy);
            // šířka a hloubka plynule mezi uzlem a příjemcem (příjemce mimo koryto → vlastní hodnoty)
            double hw = _w[k], hd = _d[k];
            if (_d[r] > 0) { hw += q * (_w[r] - hw); hd += q * (_d[r] - hd); }
            double tt = Math.Sqrt(dx * dx + dy * dy) / hw;
            if (tt >= 1) continue;
            double c = hd * (1 - tt * tt) * (1 - tt * tt);
            if (c > best) best = c;
        }
        return best;
    }

    public double Hloubka(double x, double y) => ErozeE(x, y) + Koryto(x, y);
}
