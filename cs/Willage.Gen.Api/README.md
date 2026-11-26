# Willage.Gen.Api – fasáda generátoru světa (G-3)

**Stav: návrh pro Willage-backend jen k připomínkám (plán 05, O11).** Nic se po vás nechce implementovat; prosíme o komentáře
k tvaru rozhraní, DTO a souboru planety, hlavně tam, kde by je jednou mohl použít server. Připomínky prosím do issue / PR
u větve `gen-v1-g3-api` nebo přímo Janovi; zapracují se v dalším kroku (G-4+), fasáda do té doby není zmrazená.

## Co to je
Čistá C# knihovna (net9.0, bez Godotu) nad `Willage.Gen`: rozhraní + DTO + tenké služby. Godot jádro (G-4), okno
Generátor světa (G-5), CLI (`Willage.Gen.Nastroje api …`) i případný server volají jen tohle.

| Rozhraní | Účel | Stav |
|---|---|---|
| `IModuly` | moduly M0–M7 + zástupné (M6d 7d, M8, M9), schéma parametrů (G-2) s hodnotami, `Nastav` → zneplatněné moduly, `Prepocitej` | hotové |
| `IModuly.PrepocitejOblast` | U-2 částečný přepočet oblasti | **zástupné** (přepočte celé moduly) |
| `IModuly.Napoveda` | nápověda parametru | **zástupné** (texty nejsou ve v1) |
| `ISluzbaSveta` | `Generuj`, `Otisky`, `Uloz`/`Nacti` WPLN, `PotvrdPlanetu` (zamkne parametry), `Info` | hotové |
| `IDotazySveta` | `Sloupec`, `Bod`, `Rez`, `Mapa` (výška, eroze, teplota, srážky, biom) | hotové |
| `IKatalogy` | manifest (SHA-256 dat), kontrola proti uloženému, dotčené moduly souboru | hotové; `NavrhVerze` **zástupné** |
| `IVizualniData` | grafické bloky 0,5 m, varianty modelů (okno 2) | **zástupné** |
| `IUpravyRegionu` | U-1 úpravy s regiony (fáze 3) | **zástupné** |

Vstupní bod: `GeneratorSveta.Otevri(cesta)` → `Moduly`, `Sluzba`, `Dotazy`, `Katalogy`, `Vizual`, `Upravy`.
Jedna instance = jedna planeta v paměti; není vláknově bezpečná (volající řadí volání do jedné fronty).

## Soubor planety WPLN v1 (jen autorský formát klienta)
Deflate (jako WGER). Pořadí: `WPLN`, verze formátu 1, `gen_ver` („V1.0“), seed (**i64**, nikdy se nezkracuje), souhrn manifestu,
položky manifestu (cesta, velikost, SHA-256), sada parametrů (JSON `willage-sada-parametru-v1`, všechny moduly), klíče modulů
(id → SHA), potvrzeno, úpravy s regiony (U-1, obdélník v Q16 `long`, ve v1 vždy 0). Odvozené mapy (WGER, klima) nejsou
v souboru – jsou to keše, které se z planety deterministicky přepočítají.
- **Totožnost planety** = `SouborPlanety.Otisk` = SHA-256 kanonického textu (`SouborPlanety.Kanonicky`), **ne bajtů Deflate**.
- **Kompatibilita** (`KompatibilitaPlanety`): formát ≤ podporovaný se čte, novější se odmítne; `gen_ver` = aktuální → Plna,
  známá starší (`ZnameGenVer`) → Prepocet (sada se načte, moduly se přepočítají), neznámá → odmítnout.
- Pro Dev / server je připravený **zástupný** verzovaný JSON export `PlanetaJson.Export` (`willage-planeta-export-v1`, s otiskem) – nezmrazený.

## Jednotky a souřadnice
- `SouradniceQ16` / `OblastQ16`: 2D bod / obdélník v jednotkách 2⁻¹⁶ m (`long`), převod z/do metrů jen na hranici fasády.
  Buňka 0,25 m: `MinRohBunky(ix, iy)` (index jako Dev), `StredBunky` = roh + 0,125 m.
- Úpravy s regiony (U-1) jsou v Q16. `PovrchM`, `KrokM` a hodnoty výšky jsou `double`/`float` **metry** (výška nad dnem sloupce
  0–128 m, krok vzorku/mřížky) – zdokumentováno, nepřevádí se.
- `MapaDto` je **hrubá mřížka** mapy eroze/klimatu (dnes 32 m), ne buňky 0,25 m.
- `SloupecDto.Bunky`: 2 B na buňku (MaterialId u8 + varianta, jako Dev `ShellCellPayload`), vzorek svisle ve středu buňky
  z = (i + 0,5) · 0,25 m, vodorovně přesně v zadaném bodě.
- MaterialId je všude `byte`. **Kolize:** klient používá id 57 pro sopečný popel (`ParametrySveta.SopkaPopelId`), Dev má v rozsahu
  57–74 vlastní materiály – zdokumentováno, nepřečíslováno.
- Seed světa je `long`. 32bitový seed pro celočíselné hashe (GeologyHash, budoucí VPMG) se odvozuje jen v `Jadro/SeedSveta.Hash32`
  (dolních 32 bitů, otisky beze změny). Šum má vlastní `StableHash.NoiseSeed`.

## Vztah k Willage_Dev (jen čtení)
- Klient na Dev **neodkazuje** (Dev net10.0 + Vogen, klient net9.0): žádná reference na `Willage.World.Geology.Core` ani jiný Dev projekt.
- Zrcadla se drží **jen pro čtení**: `Jadro/GeologyGridConstants`, `Jadro/GeologyHash` (+ golden vektory `geology-hash-golden-v1.json`
  z Dev `29bffc0` v testech), `data/v1/materials-catalog-v1.json` (připnutý v manifestu fasády: `schemaVersion` + SHA).
- Shoda hlídaná testy: hash = golden vektory, perioda planety = Dev `PlanetTorus.Default` (31 360 × 15 616 m), Q16 = 65 536/m.

## Zapracované připomínky Willage-backendu (G-3 review, 26. 11. 2026)
| # | Připomínka | Jak |
|---|---|---|
| 1 | WPLN jen autorský formát, hash z kanonického obsahu | `SouborPlanety.Otisk`, `PlanetaInfoDto.OtiskPlanety`; zástupný `PlanetaJson.Export` |
| 2 | Neodkazovat Geology.Core, Q16 jako 2D bod, MapaDto hrubá | bez reference; dokumentace výše |
| 3 | Seed 64 bit, 32bit odvození na jednom místě | `SeedSveta.Hash32` (oázy ho používají); WPLN i64 |
| 4 | SloupecDto 2 B na buňku, konvence vzorkování | `SloupecDto.Bunky`, `StredBunky`/`MinRohBunky` |
| 5 | MaterialId jako byte, kolize 57 | `BodDto`, `GrafickyBlokDto`; kolize zdokumentována |
| 6 | Q16 na hranici aspoň pro úpravy, metry dokumentovat | `UpravaRegionu` v Q16; `RezDto`/`MapaDto` doc |
| 7 | Verzování a připnutí katalogu | `KompatibilitaPlanety`; `ManifestDto.KatalogMaterialu` |
| 8 | Zrcadla jen pro čtení + golden vektory | beze změny, hlídá TestyG3 |

## Otázky pro Willage-backend (zbývající)
1. Má zástupný JSON export planety (`willage-planeta-export-v1`) nějaký požadovaný tvar na straně Dev?
2. Kdy a jak sjednotit kolizi materiálových id 57–74?
