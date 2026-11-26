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
    /// <summary>G-5: parametry jednoho modulu na výchozí hodnoty (ostatní moduly beze změny). Vrátí zneplatněné moduly.</summary>
    ZmenaParametruDto VychoziModulu(string modul);
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
    /// <summary>G-4: generace s průběhem po modulech a zrušením (kontrola mezi moduly; OperationCanceledException).</summary>
    VysledekGeneraceDto Generuj(IProgress<ModulDto>? prubeh, CancellationToken zruseni);
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

/// <summary>
/// G-6: náhledy a izolace modulů M1–M3 nad výstupy posledního běhu (po Generuj). M4–M6 přijdou v G-7 (dnes IDotazySveta.Mapa).
/// </summary>
public interface INahledyModulu
{
    /// <summary>Moduly s vlastním náhledem (dnes M1, M2, M3).</summary>
    IReadOnlyList<string> Moduly();
    IReadOnlyList<VrstvaNahleduDto> Vrstvy(string modul);
    /// <summary>Izolační vrstva modulu (M1 Relief, M2 RozdilM2M1), M3 izoluje řezem (RezimRezuDto); null = bez izolace mapy.</summary>
    VrstvaNahleduDto? Izolace(string modul);
    /// <summary>Mapa vrstvy na oblasti funkce světa (výchozí 0…SvetMaxM), rozliseni × rozliseni vzorků.</summary>
    NahledMapyDto Mapa(string modul, VrstvaNahleduDto vrstva, int rozliseni = 256, OblastQ16? oblast = null);
    /// <summary>Řez úsečkou (Q16): M1/M2 profil povrchu, M3 svislý řez materiálů 0,25 m v režimu izolace.</summary>
    RezModuluDto Rez(string modul, SouradniceQ16 od, SouradniceQ16 @do, double krokM, RezimRezuDto rezim = RezimRezuDto.Vse);
    IReadOnlyList<MaterialDto> Materialy();
}
