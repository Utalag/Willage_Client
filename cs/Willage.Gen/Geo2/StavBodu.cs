namespace Willage.Gen.Geo2;

/// <summary>
/// Stav bodu během dopředného průchodu (kap. 2.1, zápis podle 3.1). K1 nese jen to, co čtou pravidla a testy původu;
/// plný <c>Vzorek</c> (hostitel původu, typ hostitele, příznaky) doplní K2.
/// </summary>
public readonly record struct StavBodu(
    int Material, TypProstoru Typ,
    int GeoUdalost, Operace GeoOperace, uint GeoInstance, short Vrstva, int MaterialPuvodu,
    int PosledniTransformace, byte PocetTransformaci)
{
    public static readonly StavBodu Neurceno = new(0, TypProstoru.Neurceno, -1, Operace.Uloz, 0, -1, 0, -1, 0);
    public static readonly StavBodu NadPovrchem = new(0, TypProstoru.NadPovrchem, -1, Operace.Uloz, 0, -1, 0, -1, 0);
    public TridaCile Trida => Geo2Zaklad.Trida(Typ);
}
