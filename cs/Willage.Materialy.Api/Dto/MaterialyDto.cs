namespace Willage.Materialy.Api.Dto;

/// <summary>Vizuální profil materiálu z katalogu Dev (visualProfiles) – vzhled, nikdy fyzika.</summary>
/// <summary>T-2d: ruční dlaždice profilu (baseTile katalogu Dev) – jen ke čtení.</summary>
public sealed record DlazdiceProfiluDto(string Asset, string Format, int WidthPx, int HeightPx, string Sha256, string Source);

public sealed record ProfilVzhleduDto(string Style, string BaseColor, int GrainScalePermille, int LayerDensityPermille, int IrregularityPermille, IReadOnlyList<string>? Palette = null,
    DlazdiceProfiluDto? BaseTile = null)
{
    /// <summary>Paleta jako text „#a, #b“ (prázdná = žádná).</summary>
    public string PaletaText => Palette is { Count: > 0 } p ? string.Join(", ", p) : "";
}

/// <summary>Návrh profilu jen pro náhled (null = beze změny). Katalog se nemění; uložení návrhu až T-4.</summary>
public sealed record NavrhProfiluDto(string? Style = null, string? BaseColor = null, int? GrainScalePermille = null, int? LayerDensityPermille = null, int? IrregularityPermille = null,
    IReadOnlyList<string>? Palette = null)
{
    public bool Prazdny => Style is null && BaseColor is null && GrainScalePermille is null && LayerDensityPermille is null && IrregularityPermille is null && Palette is null;
}

/// <summary>Jeden údaj fyziky (sekce geology) – jen ke čtení.</summary>
public sealed record UdajFyzikyDto(string Nazev, string Hodnota);

/// <summary>Materiál katalogu: ID je u8 buňky (nikdy se v editoru nemění), klíč, název, stav ID, skupina, profily, fyzika jen čtení.</summary>
public sealed record MaterialVzhleduDto(byte Id, string Key, string Nazev, string IdStatus, string Skupina,
    IReadOnlyDictionary<string, ProfilVzhleduDto> Profily, IReadOnlyList<UdajFyzikyDto> Fyzika);

/// <summary>Krok receptury VPMG (schéma Dev: id, type, enabled, params).</summary>
public sealed record KrokVpmgDto(string Id, string Type, bool Enabled, IReadOnlyDictionary<string, string> Params);

/// <summary>Receptura VPMG ve schématu Dev (schemaVersion 1).</summary>
public sealed record RecepturaVpmgDto(int SchemaVersion, byte MaterialId, string VisualProfile, int Resolution, IReadOnlyList<KrokVpmgDto> Kroky);

/// <summary>Výstup VPMG: RGBA8 (poslední vrstva runneru Dev) + FNV checksum Dev. Zastupna = nástroj není k dispozici.</summary>
public sealed record TexturaVpmgDto(bool Ok, string? Chyba, int Sirka, int Vyska, string Vrstva, uint Checksum, byte[] Rgba, double MsNastroj, double MsCelkem, bool Zastupna = false);

/// <summary>Stav nástroje VPMG: commit Dev, katalog, operace registru Dev, runtime.</summary>
public sealed record InfoVpmgDto(bool Dostupny, string Popis, string DevCommit, string Katalog, int Materialu, IReadOnlyList<string> Operace, string Runtime);

/// <summary>Kontrola zrcadla katalogu proti katalogu Dev v pinu.</summary>
public sealed record KontrolaZrcadlaDto(bool BajtyBezKonce, bool Zaznamy, int Pocet, int PocetDev, string Rozdil);

/// <summary>Připnutí Willage_Dev (data/vpmg/dev_pin.json) + SHA zrcadla spočtená teď.</summary>
public sealed record PinDevDto(string Repo, string Commit, string Popis, string KatalogDevSha, string ZrcadloCesta, string ZrcadloSha, uint GoldenChecksum, byte GoldenMaterial, uint GoldenSeed, int GoldenRozliseni);

/// <summary>Druh editoru parametru konfigurátoru receptury (T-2 generuje editory z toho).</summary>
public enum DruhParametruVpmg { Text, Volba, Cele, Barva, Prepinac, Paleta }

/// <summary>Parametr operace nebo profilu ze schématu operací.</summary>
/// <param name="VychoziDev">výchozí výraz v kódu Dev (prázdné Vychozi = Dev bere hodnotu z profilu / rozměru)</param>
/// <param name="BezPrekryvu">parametr je v Dev, ale klientský překryv ho nepopisuje (obecný editor)</param>
public sealed record ParametrVpmgDto(string Nazev, DruhParametruVpmg Druh, string Vychozi, string Popis, IReadOnlyList<string> Moznosti, int? Min, int? Max, string Jednotka,
    string VychoziDev = "", bool BezPrekryvu = false);

/// <summary>Operace VPMG pro konfigurátor: z registru Dev (Zastupna=false) nebo návrh pro backend (Zastupna=true, nejde spustit).</summary>
public sealed record OperaceVpmgDto(string Type, string Nazev, string Skupina, string Popis, bool Zastupna, IReadOnlyList<ParametrVpmgDto> Params, IReadOnlyList<string> CtiProfil,
    string? AliasOf = null, string Trida = "");
