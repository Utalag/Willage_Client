using Willage.Gen.Api.Dto;

namespace Willage.Gen.Api;

/// <summary>Moduly generátoru: seznam, schéma parametrů a hodnoty, klíče a stav, přepočet. Okno 1 (G-5) staví konfigurátory odsud.</summary>
public interface IModuly
{
    /// <summary>Moduly v topologickém pořadí včetně zástupných (7d, M8, M9) s klíčem a stavem posledního běhu.</summary>
    IReadOnlyList<ModulDto> Seznam();
    /// <summary>Parametry modulu ze schématu G-2 s aktuální hodnotou sady.</summary>
    IReadOnlyList<ParametrDto> Parametry(string modul);
    /// <summary>Nastaví parametr (hodnota v JSON); po potvrzení planety odmítne. Vrátí zneplatněné moduly.</summary>
    ZmenaParametruDto Nastav(string idParametru, string hodnotaJson);
    /// <summary>Vrátí všechny parametry na dnešní výchozí hodnoty (data/v1).</summary>
    ZmenaParametruDto Vychozi();
    /// <summary>Přepočítá neplatné moduly (s keší); stejné jako ISluzbaSveta.Generuj.</summary>
    VysledekGeneraceDto Prepocitej();
    /// <summary>U-2 (zástupné): přepočet jen oblasti; dnes přepočte celý modul a vrátí Zastupny = true.</summary>
    PrepocetOblastiDto PrepocitejOblast(string modul, OblastQ16 oblast);
    /// <summary>Nápověda parametru (zástupné: texty nejsou ve v1, Napoveda = "").</summary>
    NapovedaDto Napoveda(string idParametru);
}

/// <summary>Planeta jako celek: generace, soubor WPLN, potvrzení, otisky.</summary>
public interface ISluzbaSveta
{
    VysledekGeneraceDto Generuj();
    OtiskyPlanetyDto Otisky(int blokX = 14, int blokY = 14);
    PlanetaInfoDto Uloz(string cesta);
    /// <summary>Načte WPLN: sadu parametrů a potvrzení; vrátí rozdíly dat proti aktuálnímu manifestu a moduly s jiným klíčem.</summary>
    PlanetaInfoDto Nacti(string cesta);
    /// <summary>Potvrdí planetu: zamkne parametry (další změny jen herní, krok 13 / fáze 3).</summary>
    PlanetaInfoDto PotvrdPlanetu();
    PlanetaInfoDto Info();
}

/// <summary>Dotazy na hotovou planetu (po Generuj).</summary>
public interface IDotazySveta
{
    SloupecDto Sloupec(SouradniceQ16 p);
    BodDto Bod(SouradniceQ16 p);
    RezDto Rez(SouradniceQ16 od, SouradniceQ16 @do, double krokM);
    MapaDto Mapa(VrstvaMapyDto vrstva);
}

/// <summary>Katalogy (datové soubory): manifest, kontrola proti uloženému, dotčené moduly.</summary>
public interface IKatalogy
{
    ManifestDto Manifest();
    KontrolaKataloguDto Kontrola();
    IReadOnlyList<string> DotceneModuly(string cesta);
    /// <summary>Zástupné: návrh verze katalogu (diff, semver) přijde s oknem 2.</summary>
    ZastupnyVysledekDto NavrhVerze();
}

/// <summary>Zástupné (C, okno 2): grafické bloky okna a varianty modelů.</summary>
public interface IVizualniData
{
    IReadOnlyList<GrafickyBlokDto> BlokyOkna(OblastQ16 oblast);
    IReadOnlyList<string> VariantyModelu();
}

/// <summary>Zástupné (U-1, fáze 3): úpravy s regiony před potvrzením planety.</summary>
public interface IUpravyRegionu
{
    IReadOnlyList<UpravaRegionuDto> Seznam();
    ZastupnyVysledekDto Pridej(UpravaRegionuDto u);
}
