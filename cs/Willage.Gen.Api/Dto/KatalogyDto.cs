namespace Willage.Gen.Api.Dto;

public sealed record PolozkaKataloguDto(string Cesta, long Velikost, string Sha256, IReadOnlyList<string> CtouModuly);

/// <summary>G-3 review (bod 7): připnutý katalog materiálů (zrcadlo Dev) – verze schématu a SHA; receptury VPMG přibudou stejně.</summary>
public sealed record PinKataloguDto(string Cesta, int SchemaVersion, string Sha256);

public sealed record ManifestDto(string Souhrn, IReadOnlyList<PolozkaKataloguDto> Polozky, PinKataloguDto KatalogMaterialu);

/// <summary>Kontrola dat: rozdíly proti uloženému manifestu a moduly, které by se přepočítaly.</summary>
public sealed record KontrolaKataloguDto(bool Aktualni, IReadOnlyList<string> Rozdily, IReadOnlyList<string> DotceneModuly);

/// <summary>Zástupné (C, okno 2): popis grafického bloku 0,5 m.</summary>
public sealed record GrafickyBlokDto(SouradniceQ16 Poloha, byte Material, string Varianta);
