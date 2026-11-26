using Willage.Gen.Geologie;

namespace Willage.Gen.Testy;

/// <summary>Syntetická geologie: vlnitý povrch a vrstvy z předpisu (zdola: [výška horní hrany, id]).</summary>
public sealed class SyntetickaGeologie : IGeologie
{
    public (double hi, byte id)[] Vrstvy = { (10, 6), (12, 52), (14, 12), (20, 3), (21, 12), (64, 3) };
    public Func<double, double, double> Pov = (x, y) => 40 + 6 * Math.Sin(x / 37.0) * Math.Cos(y / 29.0) + 0.02 * x;
    public long Volani;

    public double Povrch(double x, double y) { Volani++; return Pov(x, y); }
    public byte[] Sloupec(double x, double y)
    {
        var a = new byte[512]; double p = Pov(x, y);
        for (int k = 0; k < 512; k++)
        {
            double z = (k + 0.5) * 0.25;
            if (z > p) break;
            foreach (var (hi, id) in Vrstvy) if (z < hi) { a[k] = id; break; }
        }
        return a;
    }
    public int MaterialPovrchu(double x, double y) { var s = Sloupec(x, y); int k = (int)Math.Floor((Pov(x, y) - 1e-9) / 0.25); return s[Math.Clamp(k, 0, 511)]; }
    public double VyskaTvar(double x, double y) => Pov(x, y);
    public bool Mince82(double x, double y) => false;
}
