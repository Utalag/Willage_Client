namespace Willage.Gen.Planeta;

/// <summary>Jak se načtená planeta hodí k tomuto generátoru.</summary>
public enum UrovenKompatibility
{
    /// <summary>Stejná gen_ver a podporovaný formát: klíče sedí, planeta je totožná (při stejných datech).</summary>
    Plna,
    /// <summary>Známá starší gen_ver: sada parametrů se načte, všechny moduly se přepočítají (klíč nese gen_ver), výsledek se může lišit.</summary>
    Prepocet,
    /// <summary>Neznámá gen_ver nebo novější formát: odmítnout.</summary>
    Nepodporovana,
}

/// <summary>
/// G-3 review (bod 7): explicitní pravidlo kompatibility WPLN místo tvrdého „gen_ver musí být V1.0“.
/// 1. Formát: verze souboru ≤ <see cref="SouborPlanety.Verze"/> se čte (dnes jen 1), novější se odmítne (InvalidDataException při čtení).
/// 2. gen_ver: rovná aktuální (<see cref="Pipeline.KlicModulu.GenVer"/>) → Plna; v seznamu <see cref="ZnameGenVer"/> → Prepocet; jinak Nepodporovana.
/// Nová gen_ver se přidá do ZnameGenVer, jakmile vyjde; starou nikdy neodebírat.
/// </summary>
public static class KompatibilitaPlanety
{
    public static readonly string[] ZnameGenVer = { "V1.0" };

    public static UrovenKompatibility Urci(PlanetaV1 p) =>
        p.GenVer == Pipeline.KlicModulu.GenVer ? UrovenKompatibility.Plna
        : Array.IndexOf(ZnameGenVer, p.GenVer) >= 0 ? UrovenKompatibility.Prepocet
        : UrovenKompatibility.Nepodporovana;
}
