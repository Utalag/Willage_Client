using Willage.Gen.Katalogy;

namespace Willage.Gen.Planeta;

/// <summary>
/// U-1 (fáze 3): úprava s regionem – zatím zástupná, WPLN v1 drží jen prázdný seznam (formát je připravený).
/// G-3 review: obdélník [X0, X1) × [Y0, Y1) v jednotkách Q16 (2⁻¹⁶ m, long) – stejně jako SouradniceQ16 na hranici fasády, bez double.
/// </summary>
public sealed record UpravaRegionu(string Druh, string Modul, long X0, long Y0, long X1, long Y1, string ParametryJson);

/// <summary>
/// G-3: obsah souboru planety WPLN v1 – co planetu jednoznačně určuje: verze generátoru, seed, verze dat (manifest),
/// kanonická sada parametrů všech modulů (JSON G-2), klíče modulů a potvrzení. Odvozené mapy (WGER, klima) jsou keš vedle.
/// </summary>
public sealed record PlanetaV1
{
    public string GenVer { get; init; } = Pipeline.KlicModulu.GenVer;
    public long Seed { get; init; }
    public string ManifestSouhrn { get; init; } = "";
    public IReadOnlyList<PolozkaManifestu> Manifest { get; init; } = Array.Empty<PolozkaManifestu>();
    /// <summary>Sada parametrů (formát willage-sada-parametru-v1), všechny hodnoty.</summary>
    public string SadaJson { get; init; } = "";
    /// <summary>Klíče modulů v topologickém pořadí (id → klíč).</summary>
    public IReadOnlyList<KeyValuePair<string, string>> Klice { get; init; } = Array.Empty<KeyValuePair<string, string>>();
    public bool Potvrzena { get; init; }
    /// <summary>Zástupné (U-1): úpravy s regiony, ve v1 vždy prázdné.</summary>
    public IReadOnlyList<UpravaRegionu> Upravy { get; init; } = Array.Empty<UpravaRegionu>();
}
