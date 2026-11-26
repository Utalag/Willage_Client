using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>svet_fn.gd::_masiv, _masiv_h, _vaha_masivu – masiv E87 a podhůří.</summary>
public sealed class Masiv
{
    private readonly ParametrySveta _p; private readonly long _sd; private readonly Sumy _s;
    public readonly double Amp, Det, Zdvih, Freq, PodAmp;
    public readonly GodotSum PodNoise;
    // šumy z cache geo2 uložené při stavbě: dotaz už do cache nesahá (vláknově bezpečné, stejný objekt jako GDScript)
    private readonly GodotSum _na, _nd;

    public Masiv(ParametrySveta p, long sd, Sumy s)
    {
        _p = p; _sd = sd; _s = s;
        double freq = p.P87Freq;
        var na = s.G2(sd, "MASSIF87", 0, freq);
        double ga = 0.5 * Sumy.GradSumu(na, freq);
        double rozpocet = p.RezervaSklonu * p.MasivPodilStropu * Math.Tan(Gd.DegToRad(p.Biomy[3].StropDeg));
        double aWant = p.P87AmpM, aMax = ga > 1e-15 ? rozpocet / ga : aWant;
        int it = 0;
        while (aWant > aMax * 1.001 && aMax > 1e-15 && it < 3)
        {
            freq *= aMax / aWant;
            na = s.G2(sd, "MASSIF87", 0, freq);
            ga = 0.5 * Sumy.GradSumu(na, freq);
            aMax = rozpocet / ga; it++;
        }
        _na = s.G2(sd, "MASSIF87", 0, freq); _nd = s.G2(sd, "MASSIF87D", 0, p.P87Dfreq);
        Freq = freq; Amp = Gd.Minf(aWant, aMax); Det = Gd.Minf(p.P87DetailM, p.DetailMaxM); Zdvih = p.MasivZdvihM;
        var nd = s.G2(sd, "MASSIF87D", 0, p.P87Dfreq);
        Sumy.GradSumu(nd, p.P87Dfreq);   // jen záznam v GDScriptu; volá se kvůli stejnému stavu cache
        double fp = 1.0 / p.PodhuriVlnaM;
        var pn = Sumy.Bg(sd, "V1_PODHURI", 0, fp, 3);
        double gp = Sumy.GradSumu(pn, fp);
        double podWant = p.PodhuriM, podMax = gp > 1e-15 ? 0.5 * rozpocet / gp : podWant;
        int itp = 0;
        while (podWant > podMax * 1.001 && podMax > 1e-15 && itp < 3)
        {
            fp *= podMax / podWant;
            pn = Sumy.Bg(sd, "V1_PODHURI", 0, fp, 3);
            gp = Sumy.GradSumu(pn, fp);
            podMax = 0.5 * rozpocet / gp; itp++;
        }
        PodNoise = pn; PodAmp = Gd.Minf(podWant, podMax);
    }

    public double Vaha(double wh) => Gd.Smoothstep(_p.MasivM0, _p.MasivM1, wh);

    public double H(double x, double y, bool detaily)
    {
        double h = Zdvih + Amp * Sumy.N01(_na, x, y);
        if (detaily && Det != 0.0) h += Det * (2.0 * Sumy.N01(_nd, x, y) - 1.0);
        return h;
    }
}
