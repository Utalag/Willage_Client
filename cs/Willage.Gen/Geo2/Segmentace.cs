namespace Willage.Gen.Geo2;

/// <summary>
/// Sběr segmentace svislé přímky (K4): přesné body zlomu (členství nebo materiál události se mění jen v nich) a nejisté oblasti
/// (O ∖ V závorky, překryv sourozenců, pásmo kontaktu), kde se vzorkuje po h = t_det/2 a půlí.
/// </summary>
public sealed class SegmentaceSloupce
{
    public readonly List<double> Zlomy = new();
    public readonly List<(double A, double B)> Nejiste = new();
    public double Z0 { get; internal set; }
    public double Z1 { get; internal set; }

    public void Zlom(double z) { if (z > Z0 && z < Z1) Zlomy.Add(z); }

    public void Nejista(double a, double b)
    {
        a = Math.Max(a, Z0); b = Math.Min(b, Z1);
        if (a < b) Nejiste.Add((a, b));
    }

    internal void Vycisti(double z0, double z1) { Zlomy.Clear(); Nejiste.Clear(); Z0 = z0; Z1 = z1; }
}

/// <summary>
/// Tvar (nebo zásobník) umí segmentaci svislého sloupce (2.8, 1.7): přidá přesné body zlomu a nejisté oblasti v [s.Z0, s.Z1].
/// Mimo nejisté oblasti a mezi body zlomu MUSÍ být členství i materiál tvaru konstantní. Tvar bez tohoto rozhraní = celý sloupec nejistý.
/// </summary>
public interface IIntervalyTvaru
{
    void Sloupec(double x, double y, SegmentaceSloupce s);
}

/// <summary>Kontaktní pásmo v intervalech (1.7): nejisté oblasti kandidátního pásma v povolených úsecích sloupce.</summary>
public interface IIntervalyKontaktu
{
    /// <param name="povolene">úseky z, kde stav před kontaktem projde statickými pravidly (mimo nich kontakt nezasáhne)</param>
    void Sloupec(double x, double y, IReadOnlyList<(double A, double B)> povolene, double h, SegmentaceSloupce s);
}

/// <summary>Plocha kontaktu umí odhadnout, kde ve sloupci může být blíž než r (konzervativně, nadmnožina).</summary>
public interface IPlochaSRozsahem
{
    void RozsahZ(double x, double y, double r, List<(double A, double B)> cil);
}

/// <summary>Druh hranice běhu (3.3): analytická, certifikovaná půlením (±ε), odhad (jen etapa D).</summary>
public enum DruhHranice : byte { Presna, Certifikovana, Odhad }

/// <summary>Běh sloupce (3.3): [Z0, Z1) se stejným vzorkem; <see cref="HraniceZ0"/> = jak je určena dolní hranice.</summary>
public readonly record struct Beh(double Z0, double Z1, Vzorek Stav, DruhHranice HraniceZ0);
