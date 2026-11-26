namespace Willage.Gen.Klima;

/// <summary>Klima v řádku (poloze y): teplota hladiny moře, srážky planety × K pásma (mm), podíl větru od západu 0–1, index segmentu pásma.</summary>
public readonly record struct KlimaRadku(double TC, double SrazkyMm, double PodilZapadu, int Segment);

/// <summary>
/// Klimatická pásma na torusu (Jan 12:46 / 12:49): předdefinované složení (tropy, subtropy, mírné, chladné, polární) od rovníku
/// k pólu, vypnutá pásma vypadnou a zbylá se poměrně roztáhnou na půlperiodu. Rovník v u = 0, pól v u = 0,5, druhá polovina je
/// zrcadlo (periodické a spojité). Teplota v pásmu lineárně TOd → TDo, mezi segmenty krátký plynulý přechod (smoothstep).
/// </summary>
public sealed class Zemepis
{
    public readonly double Py, Y0;
    private readonly KlimaPlanety _k; private readonly ParametryKlimatu _p;
    private readonly List<(string id, PasmoKlimatu p)> _pasma;
    private readonly double[] _hrana;          // 2n + 1 hran segmentů v u ∈ [0, 1]
    private readonly int _n;
    public IReadOnlyList<(string id, PasmoKlimatu p)> Pasma => _pasma;
    /// <summary>Id pásma segmentu (0..2n−1; druhá polovina zrcadlí první).</summary>
    public string IdSegmentu(int s) => _pasma[s < _n ? s : 2 * _n - 1 - s].id;
    public int Segmentu => 2 * _n;
    public double Hrana(int s) => _hrana[s];

    public Zemepis(ParametryKlimatu p, KlimaPlanety k, double py)
    {
        _p = p; _k = k; Py = py;
        _pasma = k.Zapnuta();
        if (_pasma.Count == 0) _pasma.Add(("mirne", new PasmoKlimatu()));
        _n = _pasma.Count;
        double suma = _pasma.Sum(x => x.p.Podil);
        _hrana = new double[2 * _n + 1]; double c = 0;
        for (int i = 0; i < _n; i++) { c += 0.5 * _pasma[i].p.Podil / suma; _hrana[i + 1] = c; }
        for (int i = 0; i < _n; i++) _hrana[_n + i + 1] = 1.0 - _hrana[_n - 1 - i];
        _hrana[2 * _n] = 1.0;
        int sp = _pasma.FindIndex(x => x.id == k.StartPasmo); if (sp < 0) sp = _pasma.FindIndex(x => x.id == "mirne"); if (sp < 0) sp = 0;
        StartPasmoIndex = sp;
        double uc = 0.5 * (_hrana[sp] + _hrana[sp + 1]);
        Y0 = Frac((p.StartYM - uc * py) / py) * py;
    }

    public int StartPasmoIndex { get; }
    static double Frac(double a) => a - Math.Floor(a);
    static double Hlad(double x) { x = Math.Clamp(x, 0, 1); return x * x * (3 - 2 * x); }

    /// <summary>Poloha na periodě u ∈ [0, 1): 0 = rovník, 0,5 = pól.</summary>
    public double U(double y) => Frac((y - Y0) / Py);

    int Najdi(double u) { int s = 0; while (s < 2 * _n - 1 && u >= _hrana[s + 1]) s++; return s; }

    (PasmoKlimatu p, bool zrcadlo) Seg(int s) => s < _n ? (_pasma[s].p, false) : (_pasma[2 * _n - 1 - s].p, true);

    /// <summary>Teplota přímky segmentu v u (neořezaná – v přechodu se prodlužuje, kink se vyhladí).</summary>
    double TLine(int s, double u)
    {
        var (p, zr) = Seg(s); double a = _hrana[s], b = _hrana[s + 1], t = (u - a) / (b - a);
        return zr ? p.TDoC + (p.TOdC - p.TDoC) * t : p.TOdC + (p.TDoC - p.TOdC) * t;
    }

    public KlimaRadku Radek(double y)
    {
        double u = U(y); int s = Najdi(u);
        double minSirka = double.MaxValue; for (int i = 0; i < 2 * _n; i++) minSirka = Math.Min(minSirka, _hrana[i + 1] - _hrana[i]);
        double h = Math.Min(0.5 * _p.PrechodPasmaM / Py, 0.5 * minSirka);   // polovina šířky přechodu v u
        // sousedé přes hranu (periodicky: segment −1 = 2n−1, 2n = 0)
        double wl = 0, wr = 0; int sl = (s + 2 * _n - 1) % (2 * _n), sr = (s + 1) % (2 * _n);
        if (h > 0)
        {
            if (u - _hrana[s] < h) wl = 1 - Hlad((u - _hrana[s] + h) / (2 * h));      // podíl levého souseda 0–0,5
            if (_hrana[s + 1] - u < h) wr = 1 - Hlad((_hrana[s + 1] - u + h) / (2 * h));
        }
        // u hrany periody (u≈0 nebo u≈1) pracuje se zalomeným u souseda
        double ul = u, ur = u; if (s == 0 && wl > 0) ul = u + 1.0; if (s == 2 * _n - 1 && wr > 0) ur = u - 1.0;
        double T0 = TLine(s, u), TL = wl > 0 ? TLine(sl, ul) : 0, TR = wr > 0 ? TLine(sr, ur) : 0;
        double t = (1 - wl - wr) * T0 + wl * TL + wr * TR;
        var (p0, _) = Seg(s); var (pl, _) = Seg(sl); var (pr, _) = Seg(sr);
        double k = (1 - wl - wr) * p0.SrazkyK + wl * pl.SrazkyK + wr * pr.SrazkyK;
        double wz = (1 - wl - wr) * (p0.Vitr >= 0 ? 1 : 0) + wl * (pl.Vitr >= 0 ? 1 : 0) + wr * (pr.Vitr >= 0 ? 1 : 0);
        return new KlimaRadku(t, _k.SrazkyMmRok * k, wz, s);
    }

    /// <summary>Teplota v bodě: pásmo − výškový gradient nad hladinou moře.</summary>
    public double Teplota(double tPasma, double vyskaM) => tPasma - _p.VyskovyGradientCNaM * Math.Max(0, vyskaM - _p.HladinaMoreM);
}
