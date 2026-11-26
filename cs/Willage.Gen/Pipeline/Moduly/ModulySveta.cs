namespace Willage.Gen.Pipeline.Moduly;

/// <summary>G-1: standardní graf modulů M0–M7 (stávající kroky generátoru, bez nových funkcí).</summary>
public static class ModulySveta
{
    public static IReadOnlyList<IModul> Vse() => new IModul[]
    {
        new M0Planeta(), new M1FunkceSveta(), new M2MoreAKontinenty(), new M3Geologie(),
        new M4Eroze(), new M5KlimaABiomy(), new M6VodaAPrusak(), new M7VystupPlanety(),
    };

    public static GrafModulu Graf() => new(Vse());
}

/// <summary>Společný základ: id, název, verze, závislosti a soubory jako data.</summary>
public abstract class ModulZaklad : IModul
{
    public abstract string Id { get; }
    public abstract string Nazev { get; }
    public virtual int VerzeAlgoritmu => 1;
    public abstract IReadOnlyList<string> Zavislosti { get; }
    public virtual IReadOnlyList<string> Soubory => Array.Empty<string>();
    public abstract string Parametry(KontextBehu k);
    public abstract object Spust(KontextBehu k);
}
