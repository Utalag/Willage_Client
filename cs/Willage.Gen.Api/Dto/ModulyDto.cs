namespace Willage.Gen.Api.Dto;

public enum StavModuluDto { Neznamy, Ceka, ZPameti, Spocitano, Zastupny }

/// <summary>Modul generátoru pro seznam v okně 1.</summary>
public sealed record ModulDto(string Id, string Nazev, int Verze, IReadOnlyList<string> Zavislosti, IReadOnlyList<string> Soubory,
    bool Zastupny, string? Popis, string Klic, StavModuluDto Stav, double Ms);

/// <summary>Parametr modulu (zrcadlo schématu G-2) s aktuální hodnotou sady.</summary>
public sealed record ParametrDto(string Id, string Modul, string Skupina, string Typ, string Hodnota, string Vychozi,
    double? Min, double? Max, double? Krok, string Jednotka, IReadOnlyList<string>? Volby, bool JenCteni, string? Poznamka, string Napoveda);

/// <summary>Výsledek změny parametru: které moduly zneplatnila (jejich klíč se změnil).</summary>
public sealed record ZmenaParametruDto(bool Prijato, string? Duvod, IReadOnlyList<string> Neplatne);

/// <summary>Nápověda parametru (zástupná: texty nejsou ve v1).</summary>
public sealed record NapovedaDto(string Id, string Text, bool Zastupny);

/// <summary>Výsledek přepočtu oblasti (U-2 zástupně: přepočte se celý modul).</summary>
public sealed record PrepocetOblastiDto(string Modul, OblastQ16 Oblast, bool Zastupny, string Poznamka, IReadOnlyList<string> Prepocitane);
