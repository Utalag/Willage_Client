namespace Willage.Gen.Geo2;

/// <summary>Příznaky vzorku (3.1). <c>HraniceOdhad</c>: o bodu rozhodla vzdálenost, která není zaručeně ≤ e_k (K1b: kontakt přes vrcholy u vyklínění).</summary>
[Flags]
public enum PriznakyVzorku : byte { Zadne = 0, HraniceOdhad = 1, DeformaceNekonv = 2 }

/// <summary>
/// Pracovní stav bodu během dopředného průchodu (kap. 2.1, zápis podle 3.1). Pole jako <see cref="Vzorek"/>, ale v int
/// (−1 = žádná událost / žádný hostitel). Výstupní kompaktní forma je <see cref="Vzorek"/>.
/// </summary>
public readonly record struct StavBodu(
    int Material, TypProstoru Typ,
    int GeoUdalost, Operace GeoOperace, uint GeoInstance, short Vrstva, int MaterialPuvodu,
    int PosledniTransformace, byte PocetTransformaci,
    int HostitelPuvodu = -1, TypProstoru TypHostitele = TypProstoru.Neurceno, PriznakyVzorku Priznaky = PriznakyVzorku.Zadne)
{
    public static readonly StavBodu Neurceno = new(0, TypProstoru.Neurceno, -1, Operace.Uloz, 0, -1, 0, -1, 0);
    public static readonly StavBodu NadPovrchem = new(0, TypProstoru.NadPovrchem, -1, Operace.Uloz, 0, -1, 0, -1, 0);
    public TridaCile Trida => Geo2Zaklad.Trida(Typ);
}
