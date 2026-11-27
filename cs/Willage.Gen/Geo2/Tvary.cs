using Willage.Gen.Sum;

namespace Willage.Gen.Geo2;

/// <summary>Prostorový popis materiálové události nebo oblasti transformace. K1: bodový test; závorky a intervaly přidá K4 (kap. 2.6, 2.8).</summary>
public interface ITvar
{
    /// <summary>Leží bod v tvaru? <paramref name="instance"/> = nejmenší id instance, která bod obsahuje (sourozenci <c>unie</c>, 1.4).</summary>
    bool Obsahuje(double x, double y, double z, out uint instance);
}

/// <summary>Tvar, který určuje materiál sám (např. nitro sopky, <c>vysledek.material_z_tvaru</c>).</summary>
public interface ITvarSMaterialem : ITvar
{
    int Material(double x, double y, double z, uint instance);
}

/// <summary>Zásobník vrstev události <c>Uloz</c>: materiál a index vrstvy v bodě. Pod povrchem MUSÍ pokrýt celý sloupec.</summary>
public interface ITvarZasobniku
{
    bool Vrstva(double x, double y, double z, out int material, out short vrstva);
}

/// <summary>Vrstva sloupce zdola: materiál a interval [Z0, Z1) v m (po ořezu povrchem).</summary>
public readonly record struct IntervalVrstvy(int Material, double Z0, double Z1);

/// <summary>Zásobník, který umí vydat hranice vrstev sloupce (mřížka hranic 6.3, pro kontakt 2.5).</summary>
public interface ITvarZasobnikuSHranicemi : ITvarZasobniku
{
    /// <summary>Vrstvy sloupce (x, y) zdola nahoru. Volající seznam nemění.</summary>
    IReadOnlyList<IntervalVrstvy> Sloupec(double x, double y);
}

/// <summary>Nejbližší bod π kontaktní plochy S k bodu q: poloha, jednotková normála plochy v π, vzdálenost D = |π − q| [m].</summary>
public readonly record struct BodPlochy(double X, double Y, double Z, double Nx, double Ny, double Nz, double D);

/// <summary>Kontaktní plocha S (2.5): nejbližší bod do vzdálenosti <c>rMax</c>. Chyba vzdálenosti MUSÍ být ≤ e_k.</summary>
public interface IPlochaKontaktu
{
    bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy b);
}

/// <summary>Těleso, které umí vzdálenost k primitivu bez šumu (2.5, 2.6 <c>Vzdalenost(q)</c>). Jen taková tělesa smí být cílem kontaktu.</summary>
public interface ITvarSVzdalenosti : ITvar
{
    IPlochaKontaktu Plocha { get; }
}

/// <summary>Kontaktní pásmo (kap. 2.5). Prefixový stav v q′ čte přes chronologii (události s indexem &lt; <paramref name="index"/>).</summary>
public interface IKontaktniPasmo
{
    bool Plati(double x, double y, double z, in StavBodu stav, ChronologieGeo2 chronologie, int index, double zPov);
}

/// <summary>Dodává tvary podle <c>tvar.druh</c>. Stará cesta (E84, VrstvySloupce) se napojí adaptéry (<c>Geo2.E84</c>).</summary>
public interface ITovarnaTvaru
{
    /// <summary><see cref="ITvar"/>, <see cref="ITvarZasobniku"/>, nebo null = neznámý druh.</summary>
    object? Vytvor(UdalostData udalost);

    /// <summary>Výška konečného povrchu (pro bod q′ v jiném sloupci), nebo null = povrch bodu q (syntetické testy).</summary>
    Func<double, double, double>? Povrch => null;

    /// <summary>Seed šumu události (šířka kontaktu N). Výchozí: z id události, nezávislý na pořadí.</summary>
    long SeedUdalosti(UdalostData udalost) => StableHash.Fnv1a64("geo2:" + udalost.Id);
}

/// <summary>Tvar celého prostoru (<c>oblast</c>, <c>kontakt</c>: o zásahu rozhodnou jen pravidla).</summary>
public sealed class TvarVsude : ITvar
{
    public static readonly TvarVsude Instance = new();
    public bool Obsahuje(double x, double y, double z, out uint instance) { instance = 0; return true; }
}
