namespace Willage.Gen.Geo2;

/// <summary>Přesné vzdálenosti pro kontaktní plochu (2.5): bod–trojúhelník (Ericson, Real-Time Collision Detection 5.1.5).</summary>
public static class Geometrie3
{
    /// <summary>Nejbližší bod trojúhelníku ABC k P a čtverec vzdálenosti.</summary>
    public static double NejblizsiNaTrojuhelniku(
        double px, double py, double pz,
        double ax, double ay, double az, double bx, double by, double bz, double cx, double cy, double cz,
        out double qx, out double qy, out double qz)
    {
        double abx = bx - ax, aby = by - ay, abz = bz - az, acx = cx - ax, acy = cy - ay, acz = cz - az;
        double apx = px - ax, apy = py - ay, apz = pz - az;
        double d1 = abx * apx + aby * apy + abz * apz, d2 = acx * apx + acy * apy + acz * apz;
        if (d1 <= 0 && d2 <= 0) { qx = ax; qy = ay; qz = az; return D2(px, py, pz, qx, qy, qz); }
        double bpx = px - bx, bpy = py - by, bpz = pz - bz;
        double d3 = abx * bpx + aby * bpy + abz * bpz, d4 = acx * bpx + acy * bpy + acz * bpz;
        if (d3 >= 0 && d4 <= d3) { qx = bx; qy = by; qz = bz; return D2(px, py, pz, qx, qy, qz); }
        double vc = d1 * d4 - d3 * d2;
        if (vc <= 0 && d1 >= 0 && d3 <= 0)
        {
            double v = d1 / (d1 - d3);
            qx = ax + v * abx; qy = ay + v * aby; qz = az + v * abz; return D2(px, py, pz, qx, qy, qz);
        }
        double cpx = px - cx, cpy = py - cy, cpz = pz - cz;
        double d5 = abx * cpx + aby * cpy + abz * cpz, d6 = acx * cpx + acy * cpy + acz * cpz;
        if (d6 >= 0 && d5 <= d6) { qx = cx; qy = cy; qz = cz; return D2(px, py, pz, qx, qy, qz); }
        double vb = d5 * d2 - d1 * d6;
        if (vb <= 0 && d2 >= 0 && d6 <= 0)
        {
            double w = d2 / (d2 - d6);
            qx = ax + w * acx; qy = ay + w * acy; qz = az + w * acz; return D2(px, py, pz, qx, qy, qz);
        }
        double va = d3 * d6 - d5 * d4;
        if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0)
        {
            double w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
            qx = bx + w * (cx - bx); qy = by + w * (cy - by); qz = bz + w * (cz - bz); return D2(px, py, pz, qx, qy, qz);
        }
        double den = 1.0 / (va + vb + vc), vv = vb * den, ww = vc * den;
        qx = ax + abx * vv + acx * ww; qy = ay + aby * vv + acy * ww; qz = az + abz * vv + acz * ww;
        return D2(px, py, pz, qx, qy, qz);
    }

    public static double D2(double ax, double ay, double az, double bx, double by, double bz)
    {
        double dx = ax - bx, dy = ay - by, dz = az - bz; return dx * dx + dy * dy + dz * dz;
    }

    /// <summary>Jednotková normála trojúhelníku (orientace +z, u svislého libovolná).</summary>
    public static (double, double, double) Normala(double ax, double ay, double az, double bx, double by, double bz, double cx, double cy, double cz)
    {
        double ux = bx - ax, uy = by - ay, uz = bz - az, vx = cx - ax, vy = cy - ay, vz = cz - az;
        double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
        if (nz < 0) { nx = -nx; ny = -ny; nz = -nz; }
        double l = Math.Sqrt(nx * nx + ny * ny + nz * nz);
        return l < 1e-15 ? (0, 0, 1) : (nx / l, ny / l, nz / l);
    }
}
