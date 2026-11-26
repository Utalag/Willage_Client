using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>
/// utvary.gd::features_u a _make: útvary ze světové mřížky podle druhu (rozteč, četnost, dosah), parametry z hashe.
/// Výška tvaru ve středu útvaru se pamatuje podle klíče round(4·c) jako v GDScriptu (_zs) – viz PROP krok05 (pořadí dotazů).
/// </summary>
public sealed class TvorbaUtvaru
{
    private static readonly (DruhUtvaru d, string k, double g, double cet, double r)[] Grid =
    {
        (DruhUtvaru.Zila, "zila", 10.0, 0.7, 7.0), (DruhUtvaru.Cocka, "cocka", 12.0, 0.6, 4.5), (DruhUtvaru.Kras, "kras", 14.0, 0.8, 22.0),
        (DruhUtvaru.Dome, "dome", 16.0, 0.35, 8.0), (DruhUtvaru.Pipe, "pipe", 20.0, 0.25, 10.0),
    };
    private readonly SvetFn _s;
    private readonly Dictionary<(long, long), (double v, double cx, double cy)> _zs = new();
    private double _cx = 1e300, _cy = 1e300; private List<Utvar> _cf = new();
    /// <summary>Kolikrát klíč round(4·c) vrátil výšku spočtenou pro jiný přesný střed (závislost na pořadí dotazů).</summary>
    public long KolizeZs { get; private set; }

    public TvorbaUtvaru(SvetFn s) => _s = s;

    private static double Rr(long hsh, long k) => VNoise.U(StableHash.Mix(hsh, "R", k));

    public List<Utvar> Features(double x, double y)
    {
        if (x == _cx && y == _cy) return _cf;
        var o = new List<Utvar>();
        foreach (var g in Grid)
        {
            long gi0 = Gd.Floori((x - g.r) / g.g), gi1 = Gd.Floori((x + g.r) / g.g);
            long gj0 = Gd.Floori((y - g.r) / g.g), gj1 = Gd.Floori((y + g.r) / g.g);
            for (long gi = gi0; gi <= gi1; gi++)
            for (long gj = gj0; gj <= gj1; gj++)
            {
                long hsh = StableHash.Mix(_s.Sd, "E84_" + g.k, gi * 7919 + gj);
                if (VNoise.U(hsh) >= g.cet) continue;
                double cx = gi * g.g + Rr(hsh, 1) * g.g, cy = gj * g.g + Rr(hsh, 2) * g.g;
                var f = Make(g.d, hsh, cx, cy);
                var b = f.Box;
                if (x >= b[0] && x <= b[3] && y >= b[1] && y <= b[4]) o.Add(f);
            }
        }
        _cx = x; _cy = y; _cf = o;
        return o;
    }

    private double Zs(double cx, double cy)
    {
        var k = ((long)Gd.Round(cx * 4.0), (long)Gd.Round(cy * 4.0));
        if (_zs.TryGetValue(k, out var e)) { if (e.cx != cx || e.cy != cy) KolizeZs++; return e.v; }
        double v = _s.VyskaTvar(cx, cy); _zs[k] = (v, cx, cy);
        return v;
    }

    private static double[] Norm(double a, double b, double c)
    {
        double l = Math.Sqrt(a * a + b * b + c * c);
        return l < 1e-15 ? new[] { 0.0, 0.0, 1.0 } : new[] { a / l, b / l, c / l };
    }
    private static double[] Cross(double[] a, double[] b) =>
        new[] { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };

    private Utvar Make(DruhUtvaru kd, long hsh, double cx, double cy)
    {
        double zs = Zs(cx, cy);
        var P = new List<double>(); double[] box;
        var z1 = new[] { 0.0, 0.0, 1.0 };
        switch (kd)
        {
            case DruhUtvaru.Zila:
            {
                double cz = Gd.Clampf(zs * (0.35 + 0.30 * Rr(hsh, 3)), 4.0, Gd.Maxf(zs - 2.0, 4.0));
                var n = Norm(Rr(hsh, 4) * 2.0 - 1.0, Rr(hsh, 5) * 2.0 - 1.0, (Rr(hsh, 6) * 2.0 - 1.0) * 0.4);
                var uu = Cross(n, z1); var u = Norm(uu[0], uu[1], uu[2]); var v = Cross(n, u);
                double t0 = 0.15 + 0.25 * Rr(hsh, 7), a = 3.0 + 3.0 * Rr(hsh, 8), b = 2.0 + 2.0 * Rr(hsh, 9);
                P.AddRange(new[] { cx, cy, cz }); P.AddRange(n); P.AddRange(u); P.AddRange(v); P.AddRange(new[] { t0, a, b, 0.3, 0.35 });
                double e = Gd.Maxf(a, b) + 0.3 + t0;
                box = new[] { cx - e, cy - e, cz - e, cx + e, cy + e, cz + e };
                break;
            }
            case DruhUtvaru.Cocka:
            {
                double cz = Gd.Clampf(zs * (0.30 + 0.35 * Rr(hsh, 3)), 3.0, Gd.Maxf(zs - 2.0, 3.0));
                var n = Norm(Rr(hsh, 4) * 2.0 - 1.0, Rr(hsh, 5) * 2.0 - 1.0, Rr(hsh, 6) * 2.0 - 1.0);
                var uu = Cross(n, z1); var u = Norm(uu[0], uu[1], uu[2]); var v = Cross(n, u);
                double ra = 2.0 + 2.0 * Rr(hsh, 7), rb = 1.5 + 1.5 * Rr(hsh, 8), rc = 0.5 + 0.7 * Rr(hsh, 9);
                P.AddRange(new[] { cx, cy, cz }); P.AddRange(u); P.AddRange(v); P.AddRange(n); P.AddRange(new[] { ra, rb, rc });
                box = new[] { cx - ra, cy - ra, cz - ra, cx + ra, cy + ra, cz + ra };
                break;
            }
            case DruhUtvaru.Dome:
            {
                double cz; var p = _s.P;
                if (p.DomPasmoSedimenty)
                {
                    double p0 = p.PasmoSpodek, p1 = p.PasmoKrystalinikum, p2 = p.PasmoSedimenty, p3 = p.PasmoSvrchni;
                    double ps = p0 + p1 + p2 + p3; if (ps <= 0.0) ps = 1.0;
                    double a0 = zs * (p0 + p1) / ps, a1 = zs * (p0 + p1 + p2) / ps;
                    cz = Gd.Lerpf(a0, a1, 0.15 + 0.70 * Rr(hsh, 3));
                }
                else cz = Gd.Clampf(zs * (0.55 + 0.20 * Rr(hsh, 3)), 6.0, Gd.Maxf(zs - 3.0, 6.0));
                double ra = 3.0 + 4.0 * Rr(hsh, 7), rb = 3.0 + 4.0 * Rr(hsh, 8), rc = 6.0 + 8.0 * Rr(hsh, 9);
                P.AddRange(new[] { cx, cy, cz, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, ra, rb, rc });
                double e = Gd.Maxf(ra, Gd.Maxf(rb, rc));
                box = new[] { cx - e, cy - e, cz - e, cx + e, cy + e, cz + e };
                break;
            }
            case DruhUtvaru.Pipe:
            {
                double cz = Gd.Clampf(zs * 0.35, 8.0, Gd.Maxf(zs * 0.5, 8.0));
                double ra = 0.8 + 1.2 * Rr(hsh, 7), rb = ra, rc = cz * (0.7 + 0.4 * Rr(hsh, 9));
                P.AddRange(new[] { cx, cy, cz, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, ra, rb, rc });
                double e = Gd.Maxf(ra, rc);
                box = new[] { cx - e, cy - e, 0.0, cx + e, cy + e, cz + rc };
                break;
            }
            default:
            {
                var dir = Norm(Rr(hsh, 3) * 2.0 - 1.0, Rr(hsh, 4) * 2.0 - 1.0, 0.0);
                double z0 = Gd.Clampf(zs * (0.65 + 0.15 * Rr(hsh, 5)) - 2.0, 2.0, Gd.Maxf(zs - 2.5, 2.0));
                double x = cx, y = cy; var nodes = new List<double[]>();
                for (int i = 0; i < 6; i++)
                {
                    nodes.Add(new[] { x, y, z0 + (Rr(hsh, 10 + i) - 0.5) * 1.2, 0.5 + 0.6 * Rr(hsh, 20 + i) });
                    dir = Norm(dir[0] + 0.6 * (Rr(hsh, 30 + i) * 2.0 - 1.0), dir[1] + 0.6 * (Rr(hsh, 40 + i) * 2.0 - 1.0), 0.0);
                    x += 3.0 * dir[0]; y += 3.0 * dir[1];
                }
                double zmin = 1e9;
                foreach (var nd in nodes) { P.AddRange(nd); zmin = Gd.Minf(zmin, nd[2]); }
                P.AddRange(new[] { 2.2, 1.8, 1.2, 0.25, 0.5, zmin + 0.4 });
                double e = 2.2 + 0.25 + 0.1;
                box = new[] { 1e9, 1e9, 1e9, -1e9, -1e9, -1e9 };
                foreach (var nd in nodes)
                    for (int k = 0; k < 3; k++) { box[k] = Gd.Minf(box[k], nd[k] - e); box[k + 3] = Gd.Maxf(box[k + 3], nd[k] + e); }
                break;
            }
        }
        return new Utvar { K = kd, P = P.ToArray(), Box = box, Seed = hsh & 0x7FFFFFFF };
    }
}
