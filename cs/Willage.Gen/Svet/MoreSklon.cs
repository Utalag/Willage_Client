using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6b: moře v pásu kolem švu torusu (x ≡ 0, y ≡ 0) a mírný sklon pevniny od pobřeží.
/// d = vzdálenost ke středové čáře mořského pásu (posunuté o Stred od švu; automaticky tak, aby start byl na pevnině a šev v moři, min přes osy, periodicky),
/// dn = d + A·šum (zvlněné pobřeží), k = smoothstep(P − T, P + T, dn) (podíl pevniny), posun O = S·max(0, dn − P) − (1 − k)·H.
/// Sklon začíná až SklonOdPobreziM za pobřežím (pobřežní rovina; start svět má posun 0).
/// Podíl moře f = PodilMore ± OdchylkaMoreProcBodu (ze seedu). Polovina šířky pásu P plyne z f: (Px − 2P)(Py − 2P) = (1 − f)·Px·Py (bez šumu).
/// </summary>
public sealed class MoreSklon
{
    private readonly ParametrySveta _p;
    private readonly GodotSum _n;

    public MoreSklon(ParametrySveta p, long sd, HashSveta h)
    {
        _p = p;
        _n = Sumy.Bg(sd, "V1_POBREZI", 0, 1.0 / p.PobreziVlnaM, 3);
        // Jan 10:12: podíl moře = PodilMore ± odchylka (p. b.) deterministicky ze seedu planety
        Podil = Math.Clamp(p.PodilMore + (2.0 * h.U("V1_MORE_PODIL", 0, 0) - 1.0) * p.OdchylkaMoreProcBodu / 100.0, 0.01, 0.9);
        double sx = p.PlanetaXM + p.PlanetaYM;
        Pas = (sx - Math.Sqrt(sx * sx - 4.0 * Podil * p.PlanetaXM * p.PlanetaYM)) / 4.0;
        // střed pásu: start 3 × 3 celý na pevnině (dn > P + T), šev s pásem prolnutí celý v moři (dn < P − T)
        double t = p.MorePrechodM, a = p.PobreziSumM;
        double s0 = Math.Min(p.StartBlok[0], p.StartBlok[1]) * p.BlokM, s1 = (Math.Max(p.StartBlok[0], p.StartBlok[1]) + 3) * p.BlokM;   // start svět 3 × 3 od StartBlok
        double od = Pas + t + a - s0, doo = Pas - t - a - p.RezervaSevuM;
        Stred = p.StredMoreM >= 0 ? p.StredMoreM : 0.5 * (od + doo);
        StartNaPevnine = Stred > od && Stred < doo;
        StartBezPosunu = StartNaPevnine && s1 + Stred + a - Pas <= p.SklonOdPobreziM;
    }

    /// <summary>Cílový podíl moře po odchylce ze seedu.</summary>
    public double Podil { get; }
    /// <summary>Polovina šířky mořského pásu P (m) z podílu moře.</summary>
    public double Pas { get; }
    /// <summary>Posun středové čáry pásu od švu (m).</summary>
    public double Stred { get; }
    /// <summary>Start svět 3 × 3 je celý na pevnině a šev s pásem prolnutí v moři (zaručeno geometricky, šum ořezán na ±A).</summary>
    public bool StartNaPevnine { get; }
    /// <summary>Start svět leží v pobřežní rovině (posun přesně 0 → svět beze změny).</summary>
    public bool StartBezPosunu { get; }

    /// <summary>Kanonický zápis parametrů (klíč keše eroze).</summary>
    public string Kanonicky() => FormattableString.Invariant(
        $"more|{_p.PlanetaXM}|{_p.PlanetaYM}|{_p.HladinaMoreM}|{_p.PodilMore}|{_p.OdchylkaMoreProcBodu}|{Podil:R}|{Stred:R}|{_p.RezervaSevuM}|{_p.MorePrechodM}|{_p.HloubkaMoreM}|{_p.PobreziSumM}|{_p.PobreziVlnaM}|{_p.SklonKontinentu}|{_p.SklonOdPobreziM}");

    public static double Zabal(double v, double per) { double r = v % per; return r < 0 ? r + per : r; }

    /// <summary>Vzdálenost ke švu torusu se zvlněním pobřeží (m).</summary>
    public double Dn(double x, double y)
    {
        double xs = Zabal(x + Stred, _p.PlanetaXM), ys = Zabal(y + Stred, _p.PlanetaYM);
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
        return _p.SklonKontinentu * Math.Max(0.0, dn - Pas - _p.SklonOdPobreziM) - (1.0 - k) * _p.HloubkaMoreM;
    }

    /// <summary>Moře: v mořském pásu (k &lt; 0,5) a pod hladinou moře.</summary>
    public bool JeMore(double x, double y, double vyska) => vyska < _p.HladinaMoreM && Pevnina(x, y) < 0.5;
}
