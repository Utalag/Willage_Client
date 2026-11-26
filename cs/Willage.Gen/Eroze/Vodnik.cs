using Willage.Gen.Svet;

namespace Willage.Gen.Eroze;

/// <summary>Vodník = trvalý zdroj vody v prameni toku v kopcích. Q v l/s = plocha povodí (km²) × specifický odtok × srážky.</summary>
public readonly record struct Vodnik(int Uzel, int I, int J, double X, double Y, double QLs, double PlochaKm2);

public static class Vodnici
{
    /// <summary>Indexy biomů „kopců“ (pahorkatina, hornatina, sopečná) v pořadí MapaBiomu.</summary>
    public static double VahaKopcu(SvetFn svet, double x, double y)
    {
        var w = svet.Vahy(x, y);
        double s = 0;
        for (int b = 0; b < w.Length; b++) if (MapaBiomu.JeKopec(b)) s += w[b];
        return s;
    }

    public static List<Vodnik> Najdi(MapaEroze m, SvetFn svet, ParametryEroze p)
    {
        var v = new List<Vodnik>();
        for (int k = 0; k < m.T.N; k++)
        {
            if ((m.Priznaky[k] & MapaEroze.PramenToku) == 0) continue;
            var (x, y) = m.T.Poloha(k);
            if (VahaKopcu(svet, x, y) < p.VodnikVahaKopcu) continue;
            double km2 = m.A[k] / 1e6;   // A už obsahuje násobek srážek
            v.Add(new Vodnik(k, k % m.T.Nx, k / m.T.Nx, x, y, km2 * p.SpecifickyOdtokLsKm2, km2));
        }
        return v;
    }
}
