using Willage.Gen.Eroze;

namespace Willage.Gen.Klima;

/// <summary>Klima jako funkce světa: bodové dotazy nad mapou klimatu (bilineárně periodicky; biom z nejbližšího uzlu).</summary>
public sealed class KlimaSvetaFn
{
    public MapaKlimatu Mapa { get; }
    private readonly double _px, _py;
    public KlimaSvetaFn(MapaKlimatu m) { Mapa = m; _px = m.T.Nx * m.T.Krok; _py = m.T.Ny * m.T.Krok; }

    double Bil(float[] f, double x, double y)
    {
        var t = Mapa.T;
        double fx = PeriodickyPodklad.Zabal(x, _px) / t.Krok, fy = PeriodickyPodklad.Zabal(y, _py) / t.Krok;
        int i = (int)Math.Floor(fx), j = (int)Math.Floor(fy); double u = fx - i, v = fy - j;
        return (f[t.K(i, j)] * (1 - u) + f[t.K(i + 1, j)] * u) * (1 - v) + (f[t.K(i, j + 1)] * (1 - u) + f[t.K(i + 1, j + 1)] * u) * v;
    }

    public double Teplota(double x, double y) => Bil(Mapa.Teplota, x, y);
    public double Srazky(double x, double y) => Bil(Mapa.Srazky, x, y);
    /// <summary>Váha odtoku (1 = dnešních 10 l/s/km²).</summary>
    public double W(double x, double y) => Bil(Mapa.W, x, y);
    public BiomKlimatu Biom(double x, double y)
    {
        var t = Mapa.T;
        int i = (int)Math.Round(PeriodickyPodklad.Zabal(x, _px) / t.Krok), j = (int)Math.Round(PeriodickyPodklad.Zabal(y, _py) / t.Krok);
        return Mapa.Biom[t.K(i, j)];
    }
}
