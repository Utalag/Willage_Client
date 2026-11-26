using Willage.Gen.Sum;

namespace Willage.Gen.Geologie;

/// <summary>utvary.gd: SDF útvarů, skarn na kontaktu granitoidu, materiál útvaru a hostitelé (A1). Pořadí E84: skarn → útvary.</summary>
public sealed class Utvary
{
    public const int Peg = 38, Skarn = 42, Kimb = 21, Sul = 47;
    private static readonly int[] Karst = { 44, 49, 5 };
    private static bool Granitoid(int id) => id is 6 or 36 or 37;
    public bool Fast = true;
    private readonly long _sd;
    public HostiteleUtvaru Host { get; }
    public TvorbaUtvaru Tvorba { get; }

    public Utvary(long sd, HostiteleUtvaru host, TvorbaUtvaru tvorba) { _sd = sd; Host = host; Tvorba = tvorba; }

    public double Sdf(Utvar f, double X, double Y, double Z)
    {
        var P = f.P;
        double qx = X - P[0], qy = Y - P[1], qz = Z - P[2];
        switch (f.K)
        {
            case DruhUtvaru.Zila:
            {
                double fr = P[16];
                double s = qx * P[3] + qy * P[4] + qz * P[5];
                double a = (qx * P[6] + qy * P[7] + qz * P[8]) / P[13];
                double b = (qx * P[9] + qy * P[10] + qz * P[11]) / P[14];
                double tail = P[12] * Gd.Maxf(1.0 - (a * a + b * b), 0.0) - Gd.Maxf(Math.Sqrt(a * a + b * b) - 1.0, 0.0) * Gd.Minf(P[13], P[14]);
                if (Fast && Math.Abs(s) - P[15] - tail > 0.0) return Math.Abs(s) - P[15] - tail;
                return Math.Abs(s + P[15] * VNoise.Noise(f.Seed, X * fr, Y * fr, Z * fr)) - tail;
            }
            case DruhUtvaru.Kras:
            {
                double fr = P[28], A = P[27];
                if (Fast) { double d0 = KrasD(P, X, Y, Z); if (d0 - A * 2.165 > 0.0) return d0 - A * 2.165; }
                double wx = X + A * VNoise.Noise(f.Seed, X * fr, Y * fr, Z * fr);
                double wy = Y + A * VNoise.Noise(f.Seed + 1, X * fr, Y * fr, Z * fr);
                double wz = Z + A * VNoise.Noise(f.Seed + 2, X * fr, Y * fr, Z * fr);
                return KrasD(P, wx, wy, wz);
            }
            default:
            {
                double x = (qx * P[3] + qy * P[4] + qz * P[5]) / P[12];
                double y = (qx * P[6] + qy * P[7] + qz * P[8]) / P[13];
                double z = (qx * P[9] + qy * P[10] + qz * P[11]) / P[14];
                double k0 = Math.Sqrt(x * x + y * y + z * z);
                double k1 = Math.Sqrt(x * x / (P[12] * P[12]) + y * y / (P[13] * P[13]) + z * z / (P[14] * P[14]));
                return k0 * (k0 - 1.0) / Gd.Maxf(k1, 1e-12);
            }
        }
    }

    private static double KrasD(double[] P, double wx, double wy, double wz)
    {
        double d = 1e9;
        for (int i = 0; i < 5; i++)
        {
            int o = i * 4;
            double bax = P[o + 4] - P[o], bay = P[o + 5] - P[o + 1], baz = P[o + 6] - P[o + 2];
            double pax = wx - P[o], pay = wy - P[o + 1], paz = wz - P[o + 2];
            double denom = bax * bax + bay * bay + baz * baz;
            double h = Gd.Clampf((pax * bax + pay * bay + paz * baz) / Gd.Maxf(denom, 1e-15), 0.0, 1.0);
            double dx = pax - bax * h, dy = pay - bay * h, dz = paz - baz * h;
            d = Gd.Minf(d, Math.Sqrt(dx * dx + dy * dy + dz * dz) - Gd.Lerpf(P[o + 3], P[o + 7], h));
        }
        double x = (wx - P[8]) / P[24], y = (wy - P[9]) / P[25], z = (wz - P[10]) / P[26];
        double k0 = Math.Sqrt(x * x + y * y + z * z);
        double k1 = Math.Sqrt(x * x / (P[24] * P[24]) + y * y / (P[25] * P[25]) + z * z / (P[26] * P[26]));
        return Gd.Minf(d, k0 * (k0 - 1.0) / Gd.Maxf(k1, 1e-12));
    }

    private double SkarnD(double x, double y, double z, List<Hranice> hr)
    {
        const double W = 1.5;
        double d = 1e9; bool prevG = false; double prevZ1 = 0.0;
        foreach (var e in hr)
        {
            bool g = Granitoid(e.Id);
            if (g != prevG) d = Gd.Minf(d, Math.Abs(z - (g ? e.Z0 : prevZ1)));
            prevG = g; prevZ1 = e.Z1;
        }
        if (d >= 1e8) return 1e9;
        return d - W * (1.0 + 0.5 * VNoise.Noise(_sd ^ 84, x * 0.5, y * 0.5, z * 0.5));
    }

    public int FeatMat(Utvar f, double z, int vrstvaId)
    {
        switch (f.K)
        {
            case DruhUtvaru.Kras: return 0;
            case DruhUtvaru.Dome: return Sul;
            case DruhUtvaru.Pipe: return Kimb;
            default:
                if (VNoise.U(StableHash.Mix(f.Seed, "MIN", (long)Math.Floor(z * 4.0))) < 0.08)
                {
                    int m = VNoise.U(StableHash.Mix(f.Seed, "MIN2", 0)) < 0.5 ? 8 : 9;
                    if (vrstvaId < 0 || Host.MineralOk(m, vrstvaId)) return m;
                }
                return Peg;
        }
    }

    public bool HostOk(string kd, int vrstvaId, double povrchM, double z)
    {
        if (!Host.Povoleno)
            return kd switch { "skarn" or "cocka" or "zila" or "dome" or "pipe" => true, "kras" => Karst.Contains(vrstvaId) && povrchM - z >= 2.0, _ => false };
        return Host.JeHostitel(kd, vrstvaId, povrchM - z);
    }

    /// <summary>Materiál útvaru v bodě, nebo −1 (utvary.gd::mat_feats).</summary>
    public int MatFeats(List<Utvar> feats, double x, double y, double z, int vrstvaId, double povrchM, List<Hranice> hr)
    {
        double best = 1e9; int bm = -1;
        double sd0 = SkarnD(x, y, z, hr);
        if (sd0 < 0.0 && !Granitoid(vrstvaId) && HostOk("skarn", vrstvaId, povrchM, z)) { best = sd0; bm = Skarn; }
        foreach (var f in feats)
        {
            var bx = f.Box;
            if (z < bx[2] || z > bx[5]) continue;
            if (!HostOk(f.Klic, vrstvaId, povrchM, z)) continue;
            double d = Sdf(f, x, y, z);
            if (d < 0.0 && d <= best) { best = d; bm = FeatMat(f, z, vrstvaId); }
        }
        return bm;
    }
}
