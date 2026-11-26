namespace Willage.Gen.Voda.Prusak;

/// <summary>Stěna dutiny: cesta bloků materiálů zevnitř ven (0 = vzduch/díra), počet bloků = tloušťka × 0,25 m.</summary>
public sealed record StenaDutiny(int[] Cesta)
{
    public static StenaDutiny Z(int material, int bloku) => new(Enumerable.Repeat(material, bloku).ToArray());
    /// <summary>Otevřená stěna (díra do volné vody).</summary>
    public static StenaDutiny Otevrena => new(new[] { 0 });
}

/// <summary>Dutina (kvádr v buňkách po 0,25 m) a stěny pro šest stran; stěny po jedné buňce mohou být přepsané (díra).</summary>
public sealed record ZadaniDutiny(
    int SirkaBunek, int HloubkaBunek, int VyskaBunek, double DnoM, double HladinaVenkuM,
    StenaDutiny Bocni, StenaDutiny Dno, StenaDutiny Strop, int DirBocnich = 0)
{
    public double VyskaM => VyskaBunek * Willage.Gen.Jadro.GeologyGridConstants.CellM;
}
