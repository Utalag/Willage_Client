namespace Willage.Gen.Geo2;

/// <summary>Osová obálka [m]. Mimo ni deformace nic nemění (1.8).</summary>
public readonly record struct ObalkaOsova(double X0, double Y0, double Z0, double X1, double Y1, double Z1)
{
    public bool Obsahuje(double x, double y, double z) => x >= X0 && x <= X1 && y >= Y0 && y <= Y1 && z >= Z0 && z <= Z1;
}

/// <summary>Afinní zobrazení q′ = A·q + t (A po řádcích). Jen + − × (determinismus 1.9).</summary>
public readonly record struct AfinniZobrazeni(
    double A00, double A01, double A02, double A10, double A11, double A12, double A20, double A21, double A22,
    double Tx, double Ty, double Tz)
{
    public static AfinniZobrazeni Identita => new(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0);

    public (double X, double Y, double Z) Pouzij(double x, double y, double z) =>
        (A00 * x + A01 * y + A02 * z + Tx, A10 * x + A11 * y + A12 * z + Ty, A20 * x + A21 * y + A22 * z + Tz);

    /// <summary>Obraz přímky: počátek se zobrazí celým zobrazením, směr jen lineární částí (stejný parametr t).</summary>
    public Primka Pouzij(in Primka p)
    {
        var (ox, oy, oz) = Pouzij(p.Ox, p.Oy, p.Oz);
        return new Primka(ox, oy, oz,
            A00 * p.Dx + A01 * p.Dy + A02 * p.Dz, A10 * p.Dx + A11 * p.Dy + A12 * p.Dz, A20 * p.Dx + A21 * p.Dy + A22 * p.Dz);
    }
}

/// <summary>Úsek [T0, T1) parametru přímky sloupce; <c>Starsi</c> = tentýž úsek ve starších souřadnicích (obecně šikmá přímka, průniky K4).</summary>
public readonly record struct UsekDeformace(double T0, double T1, Primka Starsi, AfinniZobrazeni Zobrazeni);

/// <summary>
/// Modifikátor geometrie (deformace, kap. 1.8). K6 = JEN rozhraní: kompilátor ho nevolá, aktivní <c>Deformuj</c> validace odmítne
/// (<c>DEFORMACE_AZ_D</c>). Vyhodnocení (D1 bod, D2 intervaly, D3 V9) je etapa D.
/// Poloha v čase i: inverze deformací mladších než i, od nejmladší. Inverze MUSÍ být deterministická (vzorec nebo pevný počet iterací).
/// </summary>
public interface IDeformace
{
    /// <summary>Stáří události (pořadí v chronologii).</summary>
    int Stari { get; }

    /// <summary>Obálka v souřadnicích po deformaci; mimo ni je deformace identita.</summary>
    ObalkaOsova Obalka { get; }

    /// <summary>Převede bod na polohu před deformací (na místě). Vrací true = přesně, false = odhad (→ hranice <c>Odhad</c>).</summary>
    bool Inverze(ref double x, ref double y, ref double z);

    /// <summary>
    /// Rozloží přímku <paramref name="p"/> v obálce na úseky s afinním zobrazením do starších souřadnic (pokryjí celý rozsah t, seřazeně).
    /// Vrací false = <c>NeAfinni</c>: volající použije zálohu (body krokem &lt; t_det + půlení, hranice <c>Odhad</c>).
    /// </summary>
    bool UsekySloupce(in Primka p, List<UsekDeformace> useky);
}
