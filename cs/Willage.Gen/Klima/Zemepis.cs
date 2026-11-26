namespace Willage.Gen.Klima;

/// <summary>Zeměpisná šířka a pásmová teplota na torusu: šířka = 180°·min(u, 1 − u), u = frac((y − yRovník)/Py)
/// (rovník a pól jednou, pásma stejně široká; teplota spojitá, na pólu a rovníku jen zlom/vrchol gradientu).</summary>
public sealed class Zemepis
{
    public readonly double Py, RovnikY;
    private readonly ParametryKlimatu _p; private readonly KlimaPlanety _k;

    public Zemepis(ParametryKlimatu p, KlimaPlanety k, double py)
    {
        _p = p; _k = k; Py = py;
        // start na šířce StartSirkaDeg: u = φ/180
        double u = Math.Clamp(p.StartSirkaDeg, 0, 90) / 180.0;
        RovnikY = Frac((p.StartYM - u * py) / py) * py;
    }

    static double Frac(double a) => a - Math.Floor(a);

    public double SirkaDeg(double y) { double u = Frac((y - RovnikY) / Py); return 180.0 * Math.Min(u, 1 - u); }

    /// <summary>Teplota hladiny moře podle šířky (°C).</summary>
    public double TPasmo(double sirka) => _k.TPolC + (_k.TRovnikC - _k.TPolC) * Math.Cos(sirka * Math.PI / 180.0);

    /// <summary>Teplota v bodě: pásmo − výškový gradient nad hladinou moře.</summary>
    public double Teplota(double sirka, double vyskaM) => TPasmo(sirka) - _p.VyskovyGradientCNaM * Math.Max(0, vyskaM - _p.HladinaMoreM);

    /// <summary>Základ srážek podle šířky (mm/rok).</summary>
    public double SrazkyPasmo(double s)
    {
        static double G(double x, double m, double sg) => Math.Exp(-((x - m) / sg) * ((x - m) / sg));
        double f = 1 + _p.ARovnik * G(s, 0, _p.SigmaRovnikDeg) - _p.ASubtropy * G(s, _p.SubtropyDeg, _p.SigmaSubtropyDeg)
                 + _p.AMirne * G(s, _p.MirneDeg, _p.SigmaMirneDeg) - _p.APol * (s / 90.0) * (s / 90.0);
        return _k.SrazkyMmRok * Math.Max(_p.MinPodilSrazek, f);
    }

    /// <summary>Podíl větru od západu (vlhkost k +x) 0–1; na hranicích pásů plynulý přechod ±PrechodPasuDeg (bez skoku srážek).</summary>
    public double PodilZapadu(double s)
    {
        if (!_p.VetrnePasy) return _p.VitrSmer >= 0 ? 1.0 : 0.0;
        double d = Math.Max(1e-9, _p.PrechodPasuDeg);
        static double S(double x) { x = Math.Clamp(x, 0, 1); return x * x * (3 - 2 * x); }
        return S((s - _p.PasatyDoDeg + d) / (2 * d)) * (1 - S((s - _p.ZapadniDoDeg + d) / (2 * d)));
    }

    /// <summary>Směr větru v pásu: +1 = vlhkost k +x (od západu), −1 = k −x (od východu).</summary>
    public int Vitr(double s) => !_p.VetrnePasy ? Math.Sign(_p.VitrSmer == 0 ? 1 : _p.VitrSmer)
        : s < _p.PasatyDoDeg ? -1 : s < _p.ZapadniDoDeg ? 1 : -1;
}
