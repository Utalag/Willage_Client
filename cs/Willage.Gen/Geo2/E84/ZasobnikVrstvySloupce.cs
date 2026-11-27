using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Zásobník <c>Uloz</c> nad starou cestou: vrstvy sloupce z <see cref="GeoVrstvy.Hranice"/> (VrstvySloupce), jen čtení.
/// Materiál v bodě jako <see cref="VrstvySloupce.VrstvaMat"/>, index vrstvy = pořadí zdola. Pamatuje si poslední 4 sloupce
/// v paměti lokální vláknu (K3, 3.6), takže jedna instance slouží všem vláknům bez zámků (<see cref="GeoVrstvy.Hranice"/> je čistá).
/// </summary>
public sealed class ZasobnikVrstvySloupce : ITvarZasobnikuSHranicemi
{
    private readonly GeoVrstvy _g;
    private const int N = 4; // malá paměť sloupců: bod q, q′ kontaktu a sousedé

    private sealed class Kes
    {
        public ZasobnikVrstvySloupce? Vlastnik;
        public readonly double[] Cx = new double[N], Cy = new double[N];
        public readonly List<Hranice>[] Hr = new List<Hranice>[N];
        public int Dalsi;
        public void Pro(ZasobnikVrstvySloupce z) { Vlastnik = z; Array.Fill(Cx, double.NaN); Array.Fill(Cy, double.NaN); Dalsi = 0; }
    }
    [ThreadStatic] private static Kes? t_kes;
    private long _hranic;
    /// <summary>Počet volání <see cref="GeoVrstvy.Hranice"/> pro bodový sloupec (diagnostika V6; jen přibližně při více vláknech).</summary>
    public long VolaniHranic => Interlocked.Read(ref _hranic);

    public ZasobnikVrstvySloupce(GeoVrstvy g) => _g = g;

    public List<Hranice> HraniceSloupce(double x, double y)
    {
        var k = t_kes ??= new Kes();
        if (!ReferenceEquals(k.Vlastnik, this)) k.Pro(this);
        for (int i = 0; i < N; i++) if (k.Cx[i] == x && k.Cy[i] == y) return k.Hr[i];
        int d = k.Dalsi; k.Dalsi = (d + 1) % N;
        k.Hr[d] = _g.Hranice(x, y); k.Cx[d] = x; k.Cy[d] = y;
        _hranic++;
        return k.Hr[d];
    }

    public bool Vrstva(double x, double y, double z, out int material, out short vrstva)
    {
        var hr = HraniceSloupce(x, y);
        for (int i = 0; i < hr.Count; i++)
            if (z >= hr[i].Z0 && z < hr[i].Z1) { material = hr[i].Id; vrstva = (short)i; return true; }
        if (hr.Count > 0 && z >= hr[^1].Z1 - 1e-9) { material = hr[^1].Id; vrstva = (short)(hr.Count - 1); return true; }
        material = 0; vrstva = -1; return true; // jako VrstvaMat (z < 0)
    }

    public IReadOnlyList<IntervalVrstvy> Sloupec(double x, double y)
    {
        var hr = _g.Hranice(x, y); // uzly mřížky: nekazit paměť bodového sloupce
        var o = new IntervalVrstvy[hr.Count];
        for (int i = 0; i < hr.Count; i++) o[i] = new IntervalVrstvy(hr[i].Id, hr[i].Z0, hr[i].Z1);
        return o;
    }
}
