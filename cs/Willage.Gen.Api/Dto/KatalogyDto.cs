namespace Willage.Gen.Api.Dto;

public sealed record PolozkaKataloguDto(string Cesta, long Velikost, string Sha256, IReadOnlyList<string> CtouModuly);

public sealed record ManifestDto(string Souhrn, IReadOnlyList<PolozkaKataloguDto> Polozky);

/// <summary>Kontrola dat: rozdíly proti uloženému manifestu a moduly, které by se přepočítaly.</summary>
public sealed record KontrolaKataloguDto(bool Aktualni, IReadOnlyList<string> Rozdily, IReadOnlyList<string> DotceneModuly);

/// <summary>Zástupné (C, okno 2): popis grafického bloku 0,5 m.</summary>
public sealed record GrafickyBlokDto(SouradniceQ16 Poloha, int Material, string Varianta);
