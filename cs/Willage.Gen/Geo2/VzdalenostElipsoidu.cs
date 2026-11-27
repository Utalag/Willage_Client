namespace Willage.Gen.Geo2;

/// <summary>
/// Přesná vzdálenost bodu k povrchu elipsoidu (K4, kontakt na tělesa 2.5): Eberly, „Distance from a Point to an Ellipse, an Ellipsoid,
/// or a Hyperellipsoid“ – robustní půlení kořene, pevný strop iterací, chyba ≪ e_k. Funguje uvnitř i vně.
/// </summary>
public static class VzdalenostElipsoidu
{
    private const int MaxIter = 256;

    /// <summary>
    /// Elipsoid se středem c a ortonormálními osami e_i (po řádcích v <paramref name="osy"/>) s poloosami r_i.
    /// Vrací nejbližší bod povrchu, jednotkovou vnější normálu a vzdálenost.
    /// </summary>
    public static double Nejblizsi(double x, double y, double z, double cx, double cy, double cz, ReadOnlySpan<double> osy,
        double r0, double r1, double r2, out double px, out double py, out double pz, out double nx, out double ny, out double nz)
    {
        Span<double> q = stackalloc double[3], e = stackalloc double[3], yy = stackalloc double[3], xx = stackalloc double[3];
        Span<int> perm = stackalloc int[3];
        double qx = x - cx, qy = y - cy, qz = z - cz;
        for (int i = 0; i < 3; i++) q[i] = qx * osy[3 * i] + qy * osy[3 * i + 1] + qz * osy[3 * i + 2];
        e[0] = r0; e[1] = r1; e[2] = r2;
        perm[0] = 0; perm[1] = 1; perm[2] = 2;
        // seřadit poloosy sestupně
        for (int a = 0; a < 2; a++) for (int b = a + 1; b < 3; b++) if (e[perm[b]] > e[perm[a]]) (perm[a], perm[b]) = (perm[b], perm[a]);
        double e0 = e[perm[0]], e1 = e[perm[1]], e2 = e[perm[2]];
        double y0 = Math.Abs(q[perm[0]]), y1 = Math.Abs(q[perm[1]]), y2 = Math.Abs(q[perm[2]]);
        Elipsoid3(e0, e1, e2, y0, y1, y2, out double x0, out double x1, out double x2);
        xx[perm[0]] = x0; xx[perm[1]] = x1; xx[perm[2]] = x2;
        for (int i = 0; i < 3; i++) yy[i] = q[i] < 0 ? -xx[i] : xx[i];
        double gx = yy[0] / (r0 * r0), gy = yy[1] / (r1 * r1), gz = yy[2] / (r2 * r2), gl = Math.Sqrt(gx * gx + gy * gy + gz * gz);
        if (gl > 0) { gx /= gl; gy /= gl; gz /= gl; } else { gx = 0; gy = 0; gz = 1; }
        px = cx; py = cy; pz = cz; nx = 0; ny = 0; nz = 0;
        for (int i = 0; i < 3; i++)
        {
            double ex = osy[3 * i], ey = osy[3 * i + 1], ez = osy[3 * i + 2], g = i == 0 ? gx : i == 1 ? gy : gz;
            px += yy[i] * ex; py += yy[i] * ey; pz += yy[i] * ez;
            nx += g * ex; ny += g * ey; nz += g * ez;
        }
        double dx = px - x, dy = py - y, dz = pz - z;
        return Math.Sqrt(dx * dx + dy * dy + dz * dz);
    }

    /// <summary>e0 ≥ e1 ≥ e2 &gt; 0, y_i ≥ 0 → nejbližší bod x_i ≥ 0.</summary>
    private static void Elipsoid3(double e0, double e1, double e2, double y0, double y1, double y2, out double x0, out double x1, out double x2)
    {
        if (y2 > 0)
        {
            if (y1 > 0)
            {
                if (y0 > 0)
                {
                    double z0 = y0 / e0, z1 = y1 / e1, z2 = y2 / e2, g = z0 * z0 + z1 * z1 + z2 * z2 - 1;
                    if (g != 0)
                    {
                        double ra = e0 / e2 * (e0 / e2), rb = e1 / e2 * (e1 / e2);
                        double s = Koren3(ra, rb, z0, z1, z2, g);
                        x0 = ra * y0 / (s + ra); x1 = rb * y1 / (s + rb); x2 = y2 / (s + 1);
                        return;
                    }
                    x0 = y0; x1 = y1; x2 = y2; return;
                }
                x0 = 0; Elipsa(e1, e2, y1, y2, out x1, out x2); return;
            }
            x1 = 0;
            if (y0 > 0) { Elipsa(e0, e2, y0, y2, out x0, out x2); return; }
            x0 = 0; x2 = e2; return;
        }
        double d0 = e0 * e0 - e2 * e2, d1 = e1 * e1 - e2 * e2, n0 = e0 * y0, n1 = e1 * y1;
        if (n0 < d0 && n1 < d1)
        {
            double a = n0 / d0, b = n1 / d1, disc = 1 - a * a - b * b;
            if (disc > 0) { x0 = e0 * a; x1 = e1 * b; x2 = e2 * Math.Sqrt(disc); return; }
        }
        x2 = 0; Elipsa(e0, e1, y0, y1, out x0, out x1);
    }

    /// <summary>e0 ≥ e1 &gt; 0, y_i ≥ 0.</summary>
    private static void Elipsa(double e0, double e1, double y0, double y1, out double x0, out double x1)
    {
        if (y1 > 0)
        {
            if (y0 > 0)
            {
                double z0 = y0 / e0, z1 = y1 / e1, g = z0 * z0 + z1 * z1 - 1;
                if (g != 0)
                {
                    double r = e0 / e1 * (e0 / e1), s = Koren2(r, z0, z1, g);
                    x0 = r * y0 / (s + r); x1 = y1 / (s + 1); return;
                }
                x0 = y0; x1 = y1; return;
            }
            x0 = 0; x1 = e1; return;
        }
        double n = e0 * y0, d = e0 * e0 - e1 * e1;
        if (n < d) { double a = n / d; x0 = e0 * a; x1 = e1 * Math.Sqrt(Math.Max(0, 1 - a * a)); return; }
        x0 = e0; x1 = 0;
    }

    private static double Koren2(double r0, double z0, double z1, double g)
    {
        double n0 = r0 * z0, s0 = z1 - 1, s1 = g < 0 ? 0 : Delka(n0, z1, 0) - 1, s = 0;
        for (int i = 0; i < MaxIter; i++)
        {
            s = 0.5 * (s0 + s1);
            if (s == s0 || s == s1) break;
            double a = n0 / (s + r0), b = z1 / (s + 1), gg = a * a + b * b - 1;
            if (gg > 0) s0 = s; else if (gg < 0) s1 = s; else break;
        }
        return s;
    }

    private static double Koren3(double r0, double r1, double z0, double z1, double z2, double g)
    {
        double n0 = r0 * z0, n1 = r1 * z1, s0 = z2 - 1, s1 = g < 0 ? 0 : Delka(n0, n1, z2) - 1, s = 0;
        for (int i = 0; i < MaxIter; i++)
        {
            s = 0.5 * (s0 + s1);
            if (s == s0 || s == s1) break;
            double a = n0 / (s + r0), b = n1 / (s + r1), c = z2 / (s + 1), gg = a * a + b * b + c * c - 1;
            if (gg > 0) s0 = s; else if (gg < 0) s1 = s; else break;
        }
        return s;
    }

    private static double Delka(double a, double b, double c)
    {
        double m = Math.Max(Math.Abs(a), Math.Max(Math.Abs(b), Math.Abs(c)));
        if (m == 0) return 0;
        a /= m; b /= m; c /= m;
        return m * Math.Sqrt(a * a + b * b + c * c);
    }
}
