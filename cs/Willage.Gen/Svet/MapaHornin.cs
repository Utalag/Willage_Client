using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>svet_fn.gd::_mapa_hornin a horniny – zastoupení hornin (koncentrace jsou float32 jako PackedFloat32Array).</summary>
public sealed class MapaHornin
{
    private readonly ParametrySveta _p;
    public readonly double S, B; public readonly int N;
    private readonly double[] _x, _y; private readonly float[][] _c;

    public MapaHornin(ParametrySveta p, HashSveta h, double svetM)
    {
        _p = p; S = p.HorninyRoztecM; B = p.HorninyPrechodM; N = (int)Math.Ceiling(svetM / S) + 4;
        _x = new double[N * N]; _y = new double[N * N]; _c = new float[N * N][];
        var hb = p.HorninyBiomu;
        for (int a = 0; a < N; a++)
        for (int b = 0; b < N; b++)
        {
            int i = a - 2, j = b - 2;
            _x[a * N + b] = (i + 0.15 + 0.7 * h.U("V1_HORN_X", i, j)) * S;
            _y[a * N + b] = (j + 0.15 + 0.7 * h.U("V1_HORN_Y", i, j)) * S;
            var c = new List<float>();
            for (int t = 0; t < 5; t++)
            {
                var z = hb[t]; double s = 0.0; var row = new float[z.Length];
                for (int m = 0; m < z.Length; m++) { double u = h.U("V1_HORN_C", i, j, t * 16 + m); row[m] = (float)(u * u); s += u * u; }
                for (int m = 0; m < z.Length; m++) c.Add((float)(row[m] / s));
            }
            _c[a * N + b] = c.ToArray();
        }
    }

    /// <summary>[(id, podíl)] seřazené sestupně (shoda → nižší id).</summary>
    public List<(int id, double podil)> Horniny(double x, double y, double[] w)
    {
        var hb = _p.HorninyBiomu;
        long ci = Gd.Floori(x / S) + 2, cj = Gd.Floori(y / S) + 2;
        var ks = new List<long>(25); var ds = new List<double>(25); double dmin = 1e30;
        for (long a = ci - 2; a < ci + 3; a++)
        for (long b = cj - 2; b < cj + 3; b++)
        {
            if (a < 0 || b < 0 || a >= N || b >= N) continue;
            long k = a * N + b;
            double d = Math.Sqrt((x - _x[k]) * (x - _x[k]) + (y - _y[k]) * (y - _y[k]));
            ks.Add(k); ds.Add(d); dmin = Gd.Minf(dmin, d);
        }
        var konc = new OrderedMap();
        double sw = 0.0; var wp = new double[ks.Count];
        for (int n = 0; n < ks.Count; n++) { double q = Gd.Maxf(0.0, 1.0 - (ds[n] - dmin) / B); wp[n] = q * q; sw += q * q; }
        for (int n = 0; n < ks.Count; n++)
        {
            if (wp[n] <= 0.0) continue;
            var c = _c[ks[n]]; int o = 0;
            for (int t = 0; t < 5; t++)
            {
                var z = hb[t];
                if (w[t] > 0.0)
                    for (int m = 0; m < z.Length; m++) konc.Add(z[m], w[t] * wp[n] / sw * c[o + m]);
                o += z.Length;
            }
        }
        var arr = konc.Polozky();
        arr.Sort((a, b) => a.v > b.v || (a.v == b.v && a.k < b.k) ? -1 : (b.v > a.v || (a.v == b.v && b.k < a.k) ? 1 : 0));
        return arr.Select(e => (e.k, e.v)).ToList();
    }
}

/// <summary>Slovník int → double s pořadím vložení (jako Dictionary v GDScriptu).</summary>
public sealed class OrderedMap
{
    private readonly List<int> _keys = new();
    private readonly Dictionary<int, double> _v = new();
    public void Add(int k, double d) { if (_v.TryGetValue(k, out var o)) _v[k] = o + d; else { _keys.Add(k); _v[k] = 0.0 + d; } }
    public void Set(int k, double d) { if (!_v.ContainsKey(k)) _keys.Add(k); _v[k] = d; }
    public bool Has(int k) => _v.ContainsKey(k);
    public double Get(int k, double def = 0.0) => _v.TryGetValue(k, out var v) ? v : def;
    public IReadOnlyList<int> Keys => _keys;
    public List<(int k, double v)> Polozky() => _keys.Select(k => (k, _v[k])).ToList();
}
