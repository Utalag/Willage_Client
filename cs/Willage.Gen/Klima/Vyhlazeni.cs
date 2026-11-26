namespace Willage.Gen.Klima;

/// <summary>Periodické krabicové vyhlazení na torusu (oddělitelné, klouzavý součet; deterministické).</summary>
public static class Vyhlazeni
{
    public static double[] Box(double[] a, int nx, int ny, int rx, int ry)
    {
        var t = new double[a.Length]; var r = new double[a.Length];
        if (rx <= 0) Array.Copy(a, t, a.Length);
        else for (int j = 0; j < ny; j++)
        {
            int o = j * nx; double s = 0;
            for (int d = -rx; d <= rx; d++) s += a[o + Mod(d, nx)];
            for (int i = 0; i < nx; i++) { t[o + i] = s / (2 * rx + 1); s += a[o + Mod(i + rx + 1, nx)] - a[o + Mod(i - rx, nx)]; }
        }
        if (ry <= 0) return t;
        for (int i = 0; i < nx; i++)
        {
            double s = 0;
            for (int d = -ry; d <= ry; d++) s += t[Mod(d, ny) * nx + i];
            for (int j = 0; j < ny; j++) { r[j * nx + i] = s / (2 * ry + 1); s += t[Mod(j + ry + 1, ny) * nx + i] - t[Mod(j - ry, ny) * nx + i]; }
        }
        return r;
    }

    static int Mod(int a, int n) { int m = a % n; return m < 0 ? m + n : m; }
}
