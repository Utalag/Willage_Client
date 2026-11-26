namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6c/6d: maska pevniny na torusu. Kontinenty = Voronoi buňky (2–4 ze seedu, hranice na švu): m = tanh(e / (velikost·2500 m)) + C·F,
/// e = vzdálenost k ose mezi dvěma nejbližšími středy nebo ke švu (na zkřivených souřadnicích, warp), F = periodický šum (členitost).
/// 6d: ostrovy v průlivech (kupky max(m, práh0 + A·(1 − (d/R)²) + C·F) celé v moři i s pásem 250 m), tvrdý pás švu se zvlněným okrajem (512 m + zvlnění·u, u ∈ [0, 1]),
/// práh = kvantil histogramu (kalibrace na hladinu podle Jana 10:54 vynechána).
/// Síla zvednutí startu se dopočítá, aby celý start 3 × 3 měl masku ≥ práh + přechod (k = 1).
/// </summary>
public sealed class MaskaPevniny
{
    private readonly ParametrySveta _p;
    private readonly PeriodickySum _f, _wx, _wy, _sev;
    private readonly double[] _ox = Array.Empty<double>(), _oy = Array.Empty<double>(), _or = Array.Empty<double>();
    private double _prah0 = double.NaN;
    private readonly double[] _cx, _cy, _s2;
    private readonly double _sx, _sy;
    public int Kontinentu => _cx.Length;
    public double Prah { get; }
    public double Zvednuti { get; }
    public double Podil { get; }
    public double StartMin { get; }
    public int Ostrovu => _ox.Length;

    public MaskaPevniny(ParametrySveta p, HashSveta h)
    {
        _p = p; double px = p.PlanetaXM, py = p.PlanetaYM;
        Podil = Math.Clamp(p.PodilMore + (2.0 * h.U("V1_MORE_PODIL", 0, 0) - 1.0) * p.OdchylkaMoreProcBodu / 100.0, 0.01, 0.9);
        _f = new PeriodickySum(h, "V1_PEV_SUM", px, py, p.SumVln, p.SumLambdaMinM, p.SumLambdaMaxM, p.Clenitost);
        _wx = new PeriodickySum(h, "V1_PEV_WX", px, py, p.WarpVln, p.WarpLambdaMinM, p.SumLambdaMaxM, 1.0);
        _wy = new PeriodickySum(h, "V1_PEV_WY", px, py, p.WarpVln, p.WarpLambdaMinM, p.SumLambdaMaxM, 1.0);
        _sev = new PeriodickySum(h, "V1_SEV_ZVL", px, py, 24, p.SevZvlneniLambdaMinM, p.SevZvlneniLambdaMaxM, 1.0);
        _sx = (p.StartBlok[0] + 1.5) * p.BlokM; _sy = (p.StartBlok[1] + 1.5) * p.BlokM;
        // kontinenty: počet ze seedu, první u startu (směrem od švu), ostatní mimo šev a od sebe
        int n = p.KontinentuMin + (int)Math.Floor(h.U("V1_KONT_N", 0, 0) * (p.KontinentuMax - p.KontinentuMin + 1));
        n = Math.Clamp(n, p.KontinentuMin, p.KontinentuMax);
        // středy na mřížce buněk (hranice buněk = šev x ≡ 0, y ≡ 0 → šev mezi kontinenty), posun ze seedu;
        // kontinent buňky se startem se přitáhne ke startu
        int cols = n == 4 ? 2 : n, rows = n == 4 ? 2 : 1;
        double cw = px / cols, ch = py / rows;
        var cx = new List<double>(); var cy = new List<double>(); var s2 = new List<double>();
        for (int i = 0; i < n; i++)
        {
            int c = i % cols, r = i / cols;
            double x = (c + 0.5 + 0.3 * (h.U("V1_KONT_X", i, 0) - 0.5)) * cw, y = (r + 0.5 + 0.3 * (h.U("V1_KONT_Y", i, 0) - 0.5)) * ch;
            double sig = p.KontinentVelikost * 0.3 * Math.Min(cw, ch) * (0.85 + 0.3 * h.U("V1_KONT_S", i, 0));
            if (_sx >= c * cw && _sx < (c + 1) * cw && _sy >= r * ch && _sy < (r + 1) * ch)
            { x = 0.5 * (x + _sx); y = 0.5 * (y + _sy); }
            cx.Add(x); cy.Add(y); s2.Add(sig * sig);
        }
        _cx = cx.ToArray(); _cy = cy.ToArray(); _s2 = s2.ToArray();
        // 6d: ostrovy v průlivech – kandidáti ze seedu v moři prvního prahu, dál od švu, startu a od sebe
        if (p.OstrovuPocet > 0)
        {
            _prah0 = Kvantil(Podil);
            var ox = new List<double>(); var oy = new List<double>(); var or = new List<double>();
            for (int i = 0; i < 512 && ox.Count < p.OstrovuPocet; i++)
            {
                double x = h.U("V1_OSTROV_X", i, 0) * px, y = h.U("V1_OSTROV_Y", i, 0) * py;
                double r = p.OstrovPolomerM * (0.6 + 0.8 * h.U("V1_OSTROV_R", i, 0));
                if (DoSevu(x, y) <= r + p.SevZvlneniM + p.SevPrechodM + 300.0) continue;
                if (Vzd(x, y, _sx, _sy) <= r + 2000.0) continue;
                bool blizko = false;
                for (int k = 0; k < ox.Count; k++) if (Vzd(x, y, ox[k], oy[k]) < r + or[k] + 1000.0) blizko = true;
                if (blizko || MZaklad(x, y) >= _prah0 - 0.05) continue;
                // celý ostrov i s pásem 250 m kolem musí ležet v moři (jinak by se přilepil ke kontinentu nebo přemostil průliv)
                bool vMori = true;
                for (int a = 0; a < 16 && vMori; a++)
                for (double rr = 0.5 * r; rr <= r + 250.0 && vMori; rr += 0.5 * r)
                    if (MZaklad(x + rr * Math.Cos(a * Math.PI / 8), y + rr * Math.Sin(a * Math.PI / 8)) >= _prah0 - 0.02) vMori = false;
                if (!vMori) continue;
                ox.Add(x); oy.Add(y); or.Add(r);
            }
            _ox = ox.ToArray(); _oy = oy.ToArray(); _or = or.ToArray();
        }
        // práh a zvednutí startu (iterace: zvednutí mění histogram)
        double zv = 0, smin;
        for (int it = 0; it < 12; it++)
        {
            Zv = zv;
            double prah = Kvantil(Podil);
            smin = double.MaxValue;
            for (double x = _sx - 192; x <= _sx + 192; x += 8) for (double y = _sy - 192; y <= _sy + 192; y += 8) smin = Math.Min(smin, M(x, y));
            double chyba = prah + p.MorePrechod + p.StartRezerva - smin;
            if (chyba <= 0) break;
            zv += chyba;
        }
        Zv = zv; Zvednuti = zv;
        Prah = Kvantil(Podil);
        smin = double.MaxValue;
        for (double x = _sx - 192; x <= _sx + 192; x += 8) for (double y = _sy - 192; y <= _sy + 192; y += 8) smin = Math.Min(smin, M(x, y));
        StartMin = smin;
    }

    private double Zv;   // aktuální zvednutí startu (během stavby)

    public double VzdalenostOdStartu(double x, double y) => Vzd(x, y, _sx, _sy);

    public static double Per(double d, double per) { d %= per; if (d < 0) d += per; return Math.Min(d, per - d); }
    private double Vzd(double ax, double ay, double bx, double by) { double dx = Per(ax - bx, _p.PlanetaXM), dy = Per(ay - by, _p.PlanetaYM); return Math.Sqrt(dx * dx + dy * dy); }

    /// <summary>Vzdálenost od pásu švu: pás = x mod Px &lt; RezervaSevuM (a totéž v y), uvnitř 0.</summary>
    public double DoSevu(double x, double y)
    {
        double W = _p.RezervaSevuM;
        double xs = x % _p.PlanetaXM; if (xs < 0) xs += _p.PlanetaXM;
        double ys = y % _p.PlanetaYM; if (ys < 0) ys += _p.PlanetaYM;
        double dx = xs < W ? 0 : Math.Min(xs - W, _p.PlanetaXM - xs), dy = ys < W ? 0 : Math.Min(ys - W, _p.PlanetaYM - ys);
        return Math.Min(dx, dy);
    }

    /// <summary>Maska bez prahu (vyšší = víc pevnina).</summary>
    public double M(double x, double y) => MSev(x, y, true);

    /// <summary>Maska bez ostrovů (výběr ostrovů).</summary>
    private double MZaklad(double x, double y) => MSev(x, y, false);

    private double MSev(double x, double y, bool ostrovy)
    {
        double wx = x + _p.WarpM * _wx.Hodnota(x, y), wy = y + _p.WarpM * _wy.Hodnota(x, y);
        // vzdálenost k hraně Voronoiovy buňky kontinentu (osa mezi dvěma nejbližšími středy) a ke švu, obojí na zkřivených
        // souřadnicích → moře tvoří průlivy mezi kontinenty a podél švu, vnitrozemí je ploché (tanh)
        double d1 = double.MaxValue, d2 = double.MaxValue;
        for (int i = 0; i < _cx.Length; i++)
        {
            double dx = Per(wx - _cx[i], _p.PlanetaXM), dy = Per(wy - _cy[i], _p.PlanetaYM);
            double d = Math.Sqrt(dx * dx + dy * dy);
            if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
        }
        double e = Math.Min(_cx.Length > 1 ? 0.5 * (d2 - d1) : double.MaxValue, DoSevu(wx, wy));
        double g = Math.Tanh(e / (_p.KontinentVelikost * 2500.0));
        double f = _p.ClenitostSila * _f.Hodnota(x, y);
        double m = g + f;
        if (ostrovy)
            for (int i = 0; i < _ox.Length; i++)
            {
                double dx = Per(x - _ox[i], _p.PlanetaXM), dy = Per(y - _oy[i], _p.PlanetaYM), q = (dx * dx + dy * dy) / (_or[i] * _or[i]);
                if (q < 1.0) m = Math.Max(m, _prah0 + _p.OstrovVyska * (1.0 - q) + f);
            }
        double ds = DoSevu(x, y);
        m -= _p.SevMekkySpad * (1 - Sum.Gd.Smoothstep(0, _p.SevMekkyPasM, ds));
        // 6d: zvlněný okraj tvrdého pásu (u ∈ [0, 1] → pás jen širší, šev zůstává v moři)
        double u = _p.SevZvlneniM > 0 ? 0.5 + 0.5 * Math.Tanh(0.5 * _sev.Hodnota(x, y)) : 0.0;
        m -= 10.0 * (1 - Sum.Gd.Smoothstep(0, _p.SevPrechodM, ds - _p.SevZvlneniM * u));
        double dst = Vzd(x, y, _sx, _sy);
        if (Zv > 0) m += Zv * (1 - Sum.Gd.Smoothstep(_p.StartPolomerM, _p.StartPolomerM + _p.StartPrechodM, dst));
        return m;
    }

    /// <summary>Podíl pevniny 0 … 1 (práh ± přechod v jednotkách masky).</summary>
    public double K(double x, double y) => Sum.Gd.Smoothstep(Prah - _p.MorePrechod, Prah + _p.MorePrechod, M(x, y));

    private double Kvantil(double f)
    {
        double s = _p.MrizkaPrahuM; int nx = (int)Math.Round(_p.PlanetaXM / s), ny = (int)Math.Round(_p.PlanetaYM / s);
        var v = new double[nx * ny];
        System.Threading.Tasks.Parallel.For(0, ny, j => { for (int i = 0; i < nx; i++) v[j * nx + i] = M((i + 0.5) * s, (j + 0.5) * s); });
        Array.Sort(v);
        return v[Math.Clamp((int)(f * v.Length), 0, v.Length - 1)];
    }

    public string Kanonicky() => FormattableString.Invariant($"maska|{Kontinentu}|{Prah:R}|{string.Join(";", _ox.Select((c, i) => $"{c:R},{_oy[i]:R},{_or[i]:R}"))}|{Zvednuti:R}|{Podil:R}|{string.Join(";", _cx.Select((c, i) => $"{c:R},{_cy[i]:R},{_s2[i]:R}"))}");
}
