using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda;

/// <summary>
/// Skutečný výkon pramene (1.8): součet toků přes 6 stěn buňky pramene. Stěna do vzduchu/vody je otevřená,
/// jinak X(soused) (rozhraní = minimum; buňka pramene sama propustnost nemá). Jednoduchý model: spád 1,
/// nevydaný výkon se ztratí. Tlakový model: nevydaný výkon zvedá tlakovou výšku Ht ≤ strop (výška doplňování − z),
/// spád = 1 + Ht / 0,25 m.
/// </summary>
public static class VykonPramene
{
    public readonly record struct Vysledek(double Vykon, double Kapacita1, double TlakovaVyskaM, bool Otevreny);

    /// <param name="sousede">materiály 6 sousedních buněk (nahoru, dolů, ±x, ±y)</param>
    public static Vysledek Spocti(double jmenovity, ReadOnlySpan<int> sousede, Propustnost pr, bool tlakovy, double stropTlakuM)
    {
        double cap = 0; bool otevreny = false;
        foreach (int m in sousede)
        {
            if (m == Propustnost.Vzduch) { otevreny = true; continue; }
            cap += pr.X(m);
        }
        if (otevreny) return new Vysledek(jmenovity, double.PositiveInfinity, 0, true);
        if (!tlakovy || cap <= 0) return new Vysledek(Math.Min(jmenovity, cap), cap, 0, false);
        double L = GeologyGridConstants.CellM;
        double spadPotreba = jmenovity / cap;
        double ht = Math.Clamp((spadPotreba - 1.0) * L, 0.0, Math.Max(0.0, stropTlakuM));
        return new Vysledek(Math.Min(jmenovity, cap * (1.0 + ht / L)), cap, ht, false);
    }
}
