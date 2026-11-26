using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6b: moře v pásu kolem švu torusu (x ≡ 0, y ≡ 0) a mírný sklon pevniny od pobřeží.
/// d = vzdálenost ke středové čáře mořského pásu (posunuté o StredMoreM od švu, min přes osy, periodicky),
/// dn = d + A·šum (zvlněné pobřeží), k = smoothstep(P − T, P + T, dn) (podíl pevniny), posun O = S·max(0, dn − P) − (1 − k)·H.
/// Polovina šířky pásu P plyne z podílu moře f: (Px − 2P)(Py − 2P) = (1 − f)·Px·Py (bez šumu).
/// </summary>
public sealed class MoreSklon
{
    private readonly ParametrySveta _p;
    private readonly GodotSum _n;

    public MoreSklon(ParametrySveta p, long sd)
    {
        _p = p;
        _n = Sumy.Bg(sd, "V1_POBREZI", 0, 1.0 / p.PobreziVlnaM, 3);
        double sx = p.PlanetaXM + p.PlanetaYM;
        Pas = (sx - Math.Sqrt(sx * sx - 4.0 * p.PodilMore * p.PlanetaXM * p.PlanetaYM)) / 4.0;
    }

    /// <summary>Polovina šířky mořského pásu P (m) z podílu moře.</summary>
    public double Pas { get; }

    /// <summary>Kanonický zápis parametrů (klíč keše eroze).</summary>
    public string Kanonicky() => FormattableString.Invariant(
        $"more|{_p.PlanetaXM}|{_p.PlanetaYM}|{_p.HladinaMoreM}|{_p.PodilMore}|{_p.StredMoreM}|{_p.MorePrechodM}|{_p.HloubkaMoreM}|{_p.PobreziSumM}|{_p.PobreziVlnaM}|{_p.SklonKontinentu}");

    public static double Zabal(double v, double per) { double r = v % per; return r < 0 ? r + per : r; }

    /// <summary>Vzdálenost ke švu torusu se zvlněním pobřeží (m).</summary>
    public double Dn(double x, double y)
    {
        double xs = Zabal(x + _p.StredMoreM, _p.PlanetaXM), ys = Zabal(y + _p.StredMoreM, _p.PlanetaYM);
        double d = Math.Min(Math.Min(xs, _p.PlanetaXM - xs), Math.Min(ys, _p.PlanetaYM - ys));
        return d + _p.PobreziSumM * Math.Clamp(_n.Noise2D(x, y), -1.0, 1.0);
    }

    /// <summary>Podíl pevniny 0 (moře) … 1 (pevnina).</summary>
    public double Pevnina(double x, double y) => Gd.Smoothstep(Pas - _p.MorePrechodM, Pas + _p.MorePrechodM, Dn(x, y));

    /// <summary>Posun výšky (m) přičtený k povrchu světa před stropem.</summary>
    public double Posun(double x, double y)
    {
        double dn = Dn(x, y);
        double k = Gd.Smoothstep(Pas - _p.MorePrechodM, Pas + _p.MorePrechodM, dn);
        return _p.SklonKontinentu * Math.Max(0.0, dn - Pas) - (1.0 - k) * _p.HloubkaMoreM;
    }

    /// <summary>Moře: v mořském pásu (k &lt; 0,5) a pod hladinou moře.</summary>
    public bool JeMore(double x, double y, double vyska) => vyska < _p.HladinaMoreM && Pevnina(x, y) < 0.5;
}
