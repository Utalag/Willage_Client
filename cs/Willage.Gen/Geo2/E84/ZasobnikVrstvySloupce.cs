using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Zásobník <c>Uloz</c> nad starou cestou: vrstvy sloupce z <see cref="GeoVrstvy.Hranice"/> (VrstvySloupce), jen čtení.
/// Materiál v bodě jako <see cref="VrstvySloupce.VrstvaMat"/>, index vrstvy = pořadí zdola. Pamatuje si poslední 4 sloupce;
/// instance není vláknově bezpečná (jako GeoVrstvy) – jedna chronologie na vlákno.
/// </summary>
public sealed class ZasobnikVrstvySloupce : ITvarZasobnikuSHranicemi
{
    private readonly GeoVrstvy _g;
    private const int N = 4; // malá paměť sloupců: bod q, q′ kontaktu a sousedé
    private readonly double[] _cx = Enumerable.Repeat(double.NaN, N).ToArray(), _cy = Enumerable.Repeat(double.NaN, N).ToArray();
    private readonly List<Hranice>[] _hr = Enumerable.Range(0, N).Select(_ => new List<Hranice>()).ToArray();
    private int _dalsi;

    public ZasobnikVrstvySloupce(GeoVrstvy g) => _g = g;

    public List<Hranice> HraniceSloupce(double x, double y)
    {
        for (int i = 0; i < N; i++) if (_cx[i] == x && _cy[i] == y) return _hr[i];
        int k = _dalsi; _dalsi = (_dalsi + 1) % N;
        _hr[k] = _g.Hranice(x, y); _cx[k] = x; _cy[k] = y;
        return _hr[k];
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
