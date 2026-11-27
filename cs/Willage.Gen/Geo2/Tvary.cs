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

/// <summary>Stav bodu těsně před danou událostí (pro <c>hostitel_okoli</c>, kap. 2.5).</summary>
public delegate StavBodu PrefixVyhodnoceni(double x, double y, double z);

/// <summary>Kontaktní pásmo (kap. 2.5). Implementace je krok K1b; kompilátor bez ní událost s <c>kontakt</c> odmítne.</summary>
public interface IKontaktniPasmo
{
    bool Plati(double x, double y, double z, in StavBodu stav, PrefixVyhodnoceni predUdalosti);
}

/// <summary>Dodává tvary podle <c>tvar.druh</c>. Stará cesta (E84, VrstvySloupce) se sem napojí adaptéry v K1b.</summary>
public interface ITovarnaTvaru
{
    /// <summary><see cref="ITvar"/>, <see cref="ITvarZasobniku"/>, nebo null = neznámý druh.</summary>
    object? Vytvor(UdalostData udalost);

    /// <summary>Implementace kontaktního pásma, nebo null = zatím není (K1b).</summary>
    IKontaktniPasmo? Kontakt(UdalostData udalost);
}

/// <summary>Tvar celého prostoru (<c>oblast</c>, <c>kontakt</c>: o zásahu rozhodnou jen pravidla).</summary>
public sealed class TvarVsude : ITvar
{
    public static readonly TvarVsude Instance = new();
    public bool Obsahuje(double x, double y, double z, out uint instance) { instance = 0; return true; }
}
