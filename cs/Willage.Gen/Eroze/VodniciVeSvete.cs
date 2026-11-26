using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Voda;

namespace Willage.Gen.Eroze;

/// <summary>
/// Napojení vodníků na systém pramenů (Prameny.Vodnici): vodník → Pramen druhu Vodnik v nejvyšší buňce terénu,
/// jmenovitý výkon = Q (l/s). Poloha je uzel hrubé mapy na torusu (0 ≤ x &lt; Px, 0 ≤ y &lt; Py).
/// </summary>
public sealed class VodniciVeSvete
{
    private readonly IGeologie _g;
    private readonly Dictionary<(int, int), List<Vodnik>> _bunky = new();
    private const double Bunka = 128.0;

    public VodniciVeSvete(IEnumerable<Vodnik> vodnici, IGeologie g)
    {
        _g = g;
        foreach (var v in vodnici)
        {
            var key = ((int)Math.Floor(v.X / Bunka), (int)Math.Floor(v.Y / Bunka));
            if (!_bunky.TryGetValue(key, out var l)) _bunky[key] = l = new();
            l.Add(v);
        }
    }

    public IEnumerable<Pramen> VOblasti(double x0, double y0, double x1, double y1)
    {
        var r = new List<Pramen>();
        for (int cx = (int)Math.Floor(x0 / Bunka); cx <= (int)Math.Floor((x1 - 1e-9) / Bunka); cx++)
        for (int cy = (int)Math.Floor(y0 / Bunka); cy <= (int)Math.Floor((y1 - 1e-9) / Bunka); cy++)
        {
            if (!_bunky.TryGetValue((cx, cy), out var l)) continue;
            foreach (var v in l)
            {
                if (v.X < x0 || v.X >= x1 || v.Y < y0 || v.Y >= y1) continue;
                int kz = (int)Math.Floor((_g.Povrch(v.X, v.Y) - 1e-9) / GeologyGridConstants.CellM);
                r.Add(new Pramen(v.X, v.Y, kz, DruhPramene.Vodnik, v.QLs, v.I, v.J, uint.MaxValue, -1));
            }
        }
        r.Sort((a, c) => a.X != c.X ? a.X.CompareTo(c.X) : a.Y.CompareTo(c.Y));
        return r;
    }
}
