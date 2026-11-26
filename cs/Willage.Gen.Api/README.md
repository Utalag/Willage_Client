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

## Soubor planety WPLN v1
Deflate (jako WGER). Pořadí: `WPLN`, verze 1, `gen_ver` („V1.0“), seed (i64), souhrn manifestu, položky manifestu
(cesta, velikost, SHA-256), sada parametrů (JSON `willage-sada-parametru-v1`, všechny moduly), klíče modulů (id → SHA),
potvrzeno, úpravy s regiony (U-1, ve v1 vždy 0). Odvozené mapy (WGER, klima) nejsou v souboru – jsou to keše, které se
z planety deterministicky přepočítají. `Nacti` vrátí rozdíly dat proti aktuálnímu manifestu a moduly s jiným klíčem.

## Sladění s Willage_Dev Geology.Core G0 (větev `cursor/geology-g0-g1-1ce6`, `29bffc0`, jen čtení)
| Dev | Klient | Stav |
|---|---|---|
| `FxQ16` (2⁻¹⁶ m, `long Units`) | `SouradniceQ16` v DTO, `Jadro/Q16` | stejná jednotka (65 536/m); knihovna uvnitř zatím `double` metry |
| `GeologyHash.HashInt3/DeriveSeed/HashString` | `Jadro/GeologyHash` | stejný algoritmus, test = golden vektory Dev `geology-hash-golden-v1.json` |
| `PlanetTorus.Default` 245 × 122 sloupců (31 360 × 15 616 m) | `eroze_v1.json` PlanetaXM/YM, `GeologyGridConstants` | shodné, hlídá test |
| `GeologyCellIndex`, `TorusWrap` | `Eroze/Torus` (mřížka eroze), buňky 0,25 m | zatím ne – převod přijde, až fasáda začne vracet buňky |
Návrh: až Dev vydá Geology.Core jako balíček / pinovaný commit, `SouradniceQ16` se nahradí přímo `FxQ16`
(nebo dostane převod) a `Jadro/GeologyHash` se odkáže na Dev. Žádné změny v Dev nenavrhujeme.

## Otázky pro Willage-backend
1. Vyhovuje serveru WPLN jako binární soubor, nebo chcete JSON variantu (sada je už JSON)?
2. Mají dotazy (`Sloupec`, `Mapa`) vracet rovnou typy Dev (`FxQ16`, `GeologyCellIndex`)?
3. Seed: Dev používá `uint`, klient `long` (dnes 49) – sjednotit na `uint`?
