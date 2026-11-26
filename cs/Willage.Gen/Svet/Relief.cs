using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>svet_fn.gd::_relief a _rel – reliéf z parametrů biomu se stropem sklonu (1.13).</summary>
public sealed class Relief
{
    public readonly GodotSum[] Noise = new GodotSum[5];
    public readonly double[] Posun = new double[5], Amp = new double[5], TanStrop = new double[5];
    public readonly bool[] Hreben = new bool[5];

    public Relief(ParametrySveta p, long sd)
    {
        for (int t = 0; t < 5; t++)
        {
            var b = p.Biomy[t];
            double f = 1.0 / b.VlnaM;
            var n = Sumy.Bg(sd, $"V1_RELIEF_{t}", 0, f, p.Oktav); n.FractalGain = b.Drsnost;
            double hk = b.Hreben ? 2.0 : 1.0;
            TanStrop[t] = Math.Tan(Gd.DegToRad(b.StropDeg));
            double podil = p.RezervaSklonu * (1.0 - (t == 3 ? p.MasivPodilStropu : 0.0));
            double rozpocet = podil * TanStrop[t];
            double aWant = b.PrevyseniM;
            double g = Sumy.GradSumu(n, f);
            double aMax = g > 1e-15 ? rozpocet / (g * hk) : aWant;
            int it = 0;
            while (aWant > aMax * 1.001 && aMax > 1e-15 && it < 3)
            {
                f *= aMax / aWant;
                n = Sumy.Bg(sd, $"V1_RELIEF_{t}", 0, f, p.Oktav); n.FractalGain = b.Drsnost;
                g = Sumy.GradSumu(n, f);
                aMax = rozpocet / (g * hk);
                it++;
            }
            Noise[t] = n; Amp[t] = Gd.Minf(aWant, aMax); Posun[t] = b.PosunM; Hreben[t] = b.Hreben;
        }
    }

    public double Rel(int t, double x, double y)
    {
        double n = Noise[t].Noise2D(x, y);
        if (Hreben[t]) { double rd = 1.0 - Math.Abs(n); return Posun[t] + Amp[t] * rd * rd; }
        return Posun[t] + Amp[t] * n;
    }
}
