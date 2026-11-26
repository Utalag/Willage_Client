using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>svet_fn.gd: mapa biomů (stanice ze seedu) a měkké Voroného váhy. Sopky si později přepíšou bod své buňky.</summary>
public sealed class MapaBiomu
{
    public const int Sopecna = 4;
    public readonly double S, B; public readonly int N;
    public readonly double[] X, Y; public readonly byte[] T;

    public MapaBiomu(ParametrySveta p, HashSveta h, double svetM)
    {
        if (p.BiomVelkeOblasti) throw new NotSupportedException("biom_velke_oblasti není přeneseno do C# (výchozí svět ho nepoužívá)");
        S = p.BiomRoztecM; B = p.BiomPrechodM; N = (int)Math.Ceiling(svetM / S) + 4;
        X = new double[N * N]; Y = new double[N * N]; T = new byte[N * N];
        var cum = new double[p.Podil.Length]; double s = 0.0;
        for (int i = 0; i < p.Podil.Length; i++) { s += p.Podil[i]; cum[i] = s; }
        for (int a = 0; a < N; a++)
        for (int b = 0; b < N; b++)
        {
            int i = a - 2, j = b - 2, k = a * N + b;
            X[k] = (i + 0.15 + 0.7 * h.U("V1_BIOM_X", i, j)) * S;
            Y[k] = (j + 0.15 + 0.7 * h.U("V1_BIOM_Y", i, j)) * S;
            double u = h.U("V1_BIOM_T", i, j) * s;
            int typ = 0; while (typ < 4 && u >= cum[typ]) typ++;
            T[k] = (byte)typ;
        }
    }

    public double[] Vahy(double x, double y)
    {
        var w = new double[5];
        long ci = Gd.Floori(x / S) + 2, cj = Gd.Floori(y / S) + 2;
        Span<double> ds = stackalloc double[25]; Span<byte> ts = stackalloc byte[25]; int n = 0;
        double dmin = 1e30;
        for (long a = ci - 2; a < ci + 3; a++)
        for (long b = cj - 2; b < cj + 3; b++)
        {
            if (a < 0 || b < 0 || a >= N || b >= N) continue;
            long k = a * N + b;
            double d = Math.Sqrt((x - X[k]) * (x - X[k]) + (y - Y[k]) * (y - Y[k]));
            ds[n] = d; ts[n] = T[k]; n++;
            if (d < dmin) dmin = d;
        }
        double sum = 0.0;
        for (int i = 0; i < n; i++)
        {
            double q = 1.0 - (ds[i] - dmin) / B;
            if (q > 0.0) { w[ts[i]] += q * q; sum += q * q; }
        }
        for (int t = 0; t < 5; t++) w[t] /= sum;
        return w;
    }
}
