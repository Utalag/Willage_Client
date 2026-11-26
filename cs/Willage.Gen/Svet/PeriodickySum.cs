namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6c: periodický šum na torusu Px × Py jako součet vln cos(2π(kx·x/Px + ky·y/Py) + φ) s celými kx, ky
/// (přesně periodické, bez švu). Vlnové délky log-rovnoměrně mezi λmin a λmax, směr a fáze ze seedu, amplituda ∝ λ^β
/// (β = členitost: menší β → víc drobných zálivů). Normováno na směrodatnou odchylku 1.
/// </summary>
public sealed class PeriodickySum
{
    private readonly double[] _wx, _wy, _a, _f;

    public PeriodickySum(HashSveta h, string ucel, double px, double py, int vln, double lambdaMin, double lambdaMax, double beta)
    {
        _wx = new double[vln]; _wy = new double[vln]; _a = new double[vln]; _f = new double[vln];
        double s2 = 0;
        for (int i = 0; i < vln; i++)
        {
            double lam = lambdaMax * Math.Pow(lambdaMin / lambdaMax, h.U(ucel + "_L", i, 0));
            double th = 2 * Math.PI * h.U(ucel + "_T", i, 0);
            long kx = (long)Math.Round(px * Math.Cos(th) / lam), ky = (long)Math.Round(py * Math.Sin(th) / lam);
            if (kx == 0 && ky == 0) kx = 1;
            double lamSkut = 1.0 / Math.Sqrt((kx / px) * (kx / px) + (ky / py) * (ky / py));
            _wx[i] = 2 * Math.PI * kx / px; _wy[i] = 2 * Math.PI * ky / py;
            _a[i] = Math.Pow(lamSkut, beta); _f[i] = 2 * Math.PI * h.U(ucel + "_F", i, 0);
            s2 += 0.5 * _a[i] * _a[i];
        }
        double n = 1.0 / Math.Sqrt(s2);
        for (int i = 0; i < vln; i++) _a[i] *= n;
    }

    public double Hodnota(double x, double y)
    {
        double s = 0;
        for (int i = 0; i < _a.Length; i++) s += _a[i] * Math.Cos(_wx[i] * x + _wy[i] * y + _f[i]);
        return s;
    }
}
