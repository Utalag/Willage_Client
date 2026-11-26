namespace Willage.Gen.Geologie;

/// <summary>
/// Paměť dotazů do geologie podle přesné souřadnice (klíč v 1/1024 m). Most do GDScriptu stojí ~ms na sloupec,
/// proto se každý sloupec čte jen jednou. Výsledek nezávisí na pořadí dotazů (funkce je čistá).
/// </summary>
public sealed class KesGeologie : IGeologie
{
    private readonly IGeologie _g;
    private readonly Dictionary<(long, long), double> _pov = new();
    private readonly Dictionary<(long, long), byte[]> _sl = new();
    private readonly Dictionary<(long, long), int> _mp = new();
    public long Dotazu { get; private set; }
    public long DotazuSloupec { get; private set; }

    public KesGeologie(IGeologie g) => _g = g;

    private static (long, long) K(double x, double y) => ((long)Math.Round(x * 1024.0), (long)Math.Round(y * 1024.0));

    public double Povrch(double x, double y)
    {
        var k = K(x, y);
        if (!_pov.TryGetValue(k, out var v)) { v = _g.Povrch(x, y); _pov[k] = v; Dotazu++; }
        return v;
    }

    public byte[] Sloupec(double x, double y)
    {
        var k = K(x, y);
        if (!_sl.TryGetValue(k, out var v)) { v = _g.Sloupec(x, y); _sl[k] = v; DotazuSloupec++; }
        return v;
    }

    public int MaterialPovrchu(double x, double y)
    {
        var k = K(x, y);
        if (!_mp.TryGetValue(k, out var v)) { v = _g.MaterialPovrchu(x, y); _mp[k] = v; Dotazu++; }
        return v;
    }

    public double VyskaTvar(double x, double y) => _g.VyskaTvar(x, y);
    public bool Mince82(double x, double y) => _g.Mince82(x, y);
}
