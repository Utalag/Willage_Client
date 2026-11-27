namespace Willage.Gen.Geo2;

/// <summary>
/// Přímka p(t) = O + t·D (1.7, K4): analytické průniky závorek jsou pro obecnou přímku, svislý sloupec je zvláštní případ
/// (<see cref="Svisla"/>, t = z). Etapa D je použije na šikmé úseky.
/// </summary>
public readonly record struct Primka(double Ox, double Oy, double Oz, double Dx, double Dy, double Dz)
{
    public static Primka Svisla(double x, double y) => new(x, y, 0, 0, 0, 1);
}

/// <summary>Průniky přímky s primitivy závorek (2.8). Vrací false = prázdný průnik; [t0, t1] uzavřený.</summary>
public static class PrunikyPrimky
{
    /// <summary>Kořeny A t² + B t + C ≤ 0 (A &gt; 0) jako interval; A ≈ 0 → lineární.</summary>
    public static bool Kvadratika(double a, double b, double c, out double t0, out double t1)
    {
        t0 = double.NegativeInfinity; t1 = double.PositiveInfinity;
        if (Math.Abs(a) < 1e-300)
        {
            if (Math.Abs(b) < 1e-300) return c <= 0;
            double t = -c / b;
            if (b > 0) t1 = t; else t0 = t;
            return true;
        }
        double disc = b * b - 4 * a * c;
        if (disc < 0) return false;
        double s = Math.Sqrt(disc);
        double q = -0.5 * (b + (b >= 0 ? s : -s)); // numericky stabilní
        double r1 = q / a, r2 = Math.Abs(q) > 0 ? c / q : r1;
        t0 = Math.Min(r1, r2); t1 = Math.Max(r1, r2);
        return true;
    }

    /// <summary>Elipsoid Σ ((q·e_i)/r_i)² ≤ s² (q = p − c), osy e_i po řádcích [e0, e1, e2] (ortonormalitu nevyžaduje – je to kvadratika v t).</summary>
    public static bool Elipsoid(in Primka p, double cx, double cy, double cz, ReadOnlySpan<double> osy, double r0, double r1, double r2, double s,
        out double t0, out double t1)
    {
        double qx = p.Ox - cx, qy = p.Oy - cy, qz = p.Oz - cz, a = 0, b = 0, c = -s * s;
        for (int i = 0; i < 3; i++)
        {
            double r = i == 0 ? r0 : i == 1 ? r1 : r2;
            double ex = osy[3 * i], ey = osy[3 * i + 1], ez = osy[3 * i + 2];
            double qe = (qx * ex + qy * ey + qz * ez) / r, de = (p.Dx * ex + p.Dy * ey + p.Dz * ez) / r;
            a += de * de; b += 2 * qe * de; c += qe * qe;
        }
        return Kvadratika(a, b, c, out t0, out t1);
    }

    /// <summary>Deska |q·n| ≤ T.</summary>
    public static bool Deska(in Primka p, double cx, double cy, double cz, double nx, double ny, double nz, double tl, out double t0, out double t1)
    {
        double s0 = (p.Ox - cx) * nx + (p.Oy - cy) * ny + (p.Oz - cz) * nz, ds = p.Dx * nx + p.Dy * ny + p.Dz * nz;
        // −T ≤ s0 + t·ds ≤ T
        return Kvadratika(0, ds, s0 - tl, out var a0, out var a1) & Kvadratika(0, -ds, -s0 - tl, out var b0, out var b1)
            ? Prunik(a0, a1, b0, b1, out t0, out t1) : Prazdny(out t0, out t1);
    }

    /// <summary>Eliptický válec ((q·u)/A)² + ((q·v)/B)² ≤ 1.</summary>
    public static bool Valec(in Primka p, double cx, double cy, double cz, double ux, double uy, double uz, double ra, double vx, double vy, double vz, double rb,
        out double t0, out double t1)
    {
        double qx = p.Ox - cx, qy = p.Oy - cy, qz = p.Oz - cz;
        double qa = (qx * ux + qy * uy + qz * uz) / ra, da = (p.Dx * ux + p.Dy * uy + p.Dz * uz) / ra;
        double qb = (qx * vx + qy * vy + qz * vz) / rb, db = (p.Dx * vx + p.Dy * vy + p.Dz * vz) / rb;
        return Kvadratika(da * da + db * db, 2 * (qa * da + qb * db), qa * qa + qb * qb - 1, out t0, out t1);
    }

    /// <summary>Kapsle (úsečka AB rozšířená koulí poloměru r): konvexní, průnik = [min vstupů, max výstupů] složek.</summary>
    public static bool Kapsle(in Primka p, double ax, double ay, double az, double bx, double by, double bz, double r, out double t0, out double t1)
    {
        double lo = double.PositiveInfinity, hi = double.NegativeInfinity;
        void Pridej(double a, double b) { if (a <= b) { lo = Math.Min(lo, a); hi = Math.Max(hi, b); } }
        if (Koule(p, ax, ay, az, r, out var s0, out var s1)) Pridej(s0, s1);
        if (Koule(p, bx, by, bz, r, out s0, out s1)) Pridej(s0, s1);
        double ux = bx - ax, uy = by - ay, uz = bz - az, l2 = ux * ux + uy * uy + uz * uz;
        if (l2 > 1e-24)
        {
            // nekonečný válec kolem osy: |w − (w·û)û|² ≤ r², w = O + tD − A
            double wx = p.Ox - ax, wy = p.Oy - ay, wz = p.Oz - az;
            double wu = (wx * ux + wy * uy + wz * uz) / l2, du = (p.Dx * ux + p.Dy * uy + p.Dz * uz) / l2;
            double px = wx - wu * ux, py = wy - wu * uy, pz = wz - wu * uz, ex = p.Dx - du * ux, ey = p.Dy - du * uy, ez = p.Dz - du * uz;
            if (Kvadratika(ex * ex + ey * ey + ez * ez, 2 * (px * ex + py * ey + pz * ez), px * px + py * py + pz * pz - r * r, out var c0, out var c1))
            {
                // omezení projekcí na úsečku: 0 ≤ wu + t·du ≤ 1
                if (Kvadratika(0, -du, -wu, out var g0, out var g1) && Kvadratika(0, du, wu - 1, out var h0, out var h1)
                    && Prunik(c0, c1, Math.Max(g0, h0), Math.Min(g1, h1), out var k0, out var k1)) Pridej(k0, k1);
            }
        }
        t0 = lo; t1 = hi; return lo <= hi;
    }

    public static bool Koule(in Primka p, double cx, double cy, double cz, double r, out double t0, out double t1)
    {
        double qx = p.Ox - cx, qy = p.Oy - cy, qz = p.Oz - cz;
        return Kvadratika(p.Dx * p.Dx + p.Dy * p.Dy + p.Dz * p.Dz, 2 * (qx * p.Dx + qy * p.Dy + qz * p.Dz), qx * qx + qy * qy + qz * qz - r * r, out t0, out t1);
    }

    public static bool Prunik(double a0, double a1, double b0, double b1, out double t0, out double t1)
    {
        t0 = Math.Max(a0, b0); t1 = Math.Min(a1, b1); return t0 <= t1;
    }

    private static bool Prazdny(out double t0, out double t1) { t0 = 1; t1 = 0; return false; }
}
