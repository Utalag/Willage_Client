namespace Willage.Gen.Geologie;

/// <summary>Hranice vrstvy ve sloupci (zdola): materiál, z0–z1 po ořezu povrchem, mocnost definice.</summary>
public readonly record struct Hranice(int Id, double Z0, double Z1, double DefiniceM);

/// <summary>Vrstva při stavbě sloupce (mění se mocnost).</summary>
internal sealed class Vrstva
{
    public int Id; public double Thick;
    public Vrstva(int id, double t) { Id = id; Thick = t; }
}
