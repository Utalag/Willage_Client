namespace Willage.Gen.Api.Dto;

/// <summary>Souhrn planety (M7).</summary>
public sealed record SouhrnPlanetyDto(string? OtiskMapy, string? OtiskKlimatu, int Vodniku, int Oaz, string ManifestSouhrn);

/// <summary>Výsledek generace: stavy modulů v pořadí a souhrn.</summary>
public sealed record VysledekGeneraceDto(IReadOnlyList<ModulDto> Moduly, SouhrnPlanetyDto Souhrn, double Ms);

/// <summary>Otisky pro kontrolu determinismu (jako nástroj „klima otisky“).</summary>
public sealed record OtiskyPlanetyDto(string? Mapa, string? Klima, int Vodniku, string VodaBlok, int BlokX, int BlokY, int Pramenu);

/// <summary>Informace o uložené / načtené planetě WPLN.</summary>
public sealed record PlanetaInfoDto(string GenVer, long Seed, bool Potvrzena, string ManifestSouhrn, IReadOnlyList<string> RozdilyDat,
    IReadOnlyList<string> NeplatneModuly, int Uprav);

/// <summary>U-1 (zástupné): úprava s regionem.</summary>
public sealed record UpravaRegionuDto(string Druh, string Modul, OblastQ16 Oblast, string ParametryJson);

/// <summary>Výsledek zástupné operace.</summary>
public sealed record ZastupnyVysledekDto(bool Zastupny, string Poznamka);
