# G-3 PROP – fasáda `Willage.Gen.Api` a soubor planety WPLN

Větev `gen-v1-g3-api` (z `gen-v1-g2-schema`), plán 05 krok G-3, Jan 17:39: postupně, čekající věci jako **zástupné** (placeholder) moduly a panely, bez čekání na schválení mezi kroky.

## Cíl
1. Nový projekt `cs/Willage.Gen.Api` (net9.0, bez Godotu, odkazuje `Willage.Gen`): jen rozhraní, DTO a tenké implementace nad pipeline G-1 a schématem G-2.
   - `IModuly` – seznam modulů (i zástupných), schéma parametrů modulu, klíče a stav, nastavení parametru, `Prepocitej`, `PrepocitejOblast` (U-2, zástupné = přepočet celého modulu), `Napoveda` (zástupné, prázdné texty).
   - `ISluzbaSveta` – `Generuj`, `Uloz`/`Nacti` (WPLN), `PotvrdPlanetu` (zamkne parametry), `Otisky`.
   - `IDotazySveta` – `Sloupec`, `Bod`, `Rez`, `Mapa` (vrstva výšky, eroze, teploty, srážek, biomu).
   - `IKatalogy` – manifest, kontrola proti uloženému, rozdíly, dotčené moduly souboru; návrh verze zástupně.
   - `IVizualniData` (C, okno 2) a `IUpravyRegionu` (U-1, fáze 3) – **zástupné**: vrací prázdné výsledky s příznakem `Zastupny`.
   - Souřadnice v DTO jako `SouradniceQ16` (2⁻¹⁶ m, `long`) – stejná jednotka jako `FxQ16` v Dev Geology.Core G0.
2. `cs/Willage.Gen/Planeta/SouborPlanety` – WPLN v1 (Deflate jako WGER): magie, verze, gen_ver, seed, manifest (souhrn + položky), kanonická sada parametrů (JSON G-2), klíče modulů, potvrzení, seznam úprav (zástupný U-1, prázdný).
3. Zástupné moduly v grafu (průchozí, verze 0, výstup `ZastupnyVystup`): **M6d nasycená zóna 7d** (← M6), **M8 povrchové jevy** (← M7), **M9 vegetace** (← M8). Nikdo z M0–M7 na nich nezávisí → klíče M0–M7 a otisky beze změny. Základní graf `ModulySveta.Graf()` zůstává 8 modulů (testy G-1), fasáda používá `GrafSeZastupnymi()`.
4. Nástroj `api otisky` – otisky přes fasádu (porovnat s `klima otisky`).
5. `cs/Willage.Gen.Api/README.md` – návrh fasády pro Willage-backend **jen k připomínkám** (O11) + poznámka ke sladění s Geology.Core G0.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| CLI přes fasádu | mapa 800d420bb00047de, klima cb11da8d141a2a5e, 86 vodníků, voda 14,14 shodná s pipeline |
| uložit → načíst → uložit | bitově stejné bajty; načtená sada dá stejné klíče |
| změněný manifest | `Nacti` vrátí rozdíly (soubor), potvrzená planeta se pozná jako neaktuální |
| zástupné moduly | klíče M0–M7 se zástupnými = bez nich; zástupné mají příznak a průchozí výstup |
| potvrzení | po `PotvrdPlanetu` nastavení parametru odmítnuto |
| Geology.Core G0 | hash = golden vektory Dev (29bffc0), perioda planety = Dev výchozí (31 360 × 15 616 m), Q16 = 65 536/m |
| všechny testy | 338 + nové, 0 chyb, otisky 9d4f2b8 |

## Rizika
- Deflate není mezi verzemi .NET zaručeně bajtově stejný → „bitově stejné“ platí v jednom běhovém prostředí; obsah se porovnává i po rozbalení.
- Dotazy používají `double` (dnešní knihovna); Q16 je zatím jen na hranici fasády.

## Výsledky (26. 11. 2026)

**Postaveno**
- `cs/Willage.Gen.Api` (nový projekt): `Dto/` (SouradniceQ16, moduly, planeta, dotazy, katalogy), `Rozhrani/` (IModuly, ISluzbaSveta, IDotazySveta, IKatalogy, IVizualniData, IUpravyRegionu), `Sluzby/` (StavGeneratoru + tenká služba na rozhraní, zástupné služby), vstup `GeneratorSveta`; `README.md` = návrh pro Willage-backend jen k připomínkám + sladění s Geology.Core G0 + 3 otázky.
- `cs/Willage.Gen/Planeta/` – `PlanetaV1`, `SouborPlanety` (WPLN v1, Deflate), `UpravaRegionu` (U-1, prázdný seznam).
- `Pipeline/Moduly/ZastupneModuly.cs` – M6d nasycená zóna 7d, M8 povrchové jevy, M9 vegetace (průchozí, verze 0); `ModulySveta.GrafSeZastupnymi()`. Základní graf G-1 beze změny.
- Zástupné ve fasádě: `PrepocitejOblast` (U-2), `Napoveda` (texty), `NavrhVerze`, `IVizualniData`, `IUpravyRegionu`.
- Nástroj `api otisky|moduly|uloz|nacti`.
- PNG `docs/sjednoceni/obrazky/g3/01-fasada-api.png` (`kresli_g3.py`).

**Testy:** 375/0 (G-2 338 + G-3 37); běh 2 min 21 s (bez souběhu), 4 min 12 s při souběžné zátěži boxu.

**Otisky přes fasádu = CLI = 9d4f2b8:** klima zap: mapa 800d420bb00047de, klima cb11da8d141a2a5e, 86 vodníků, voda 14,14 377a8210f82c856a; klima vyp (sada `KlimaKrok07=false`): 92 vodníků, voda 8e239a68c6d01be0. `klima otisky` na stromu G-3 stejné (krok 3 9f32311e046f8b6a).

**WPLN:** výchozí planeta 4 896 B; uložit → načíst → uložit bitově stejné; načtená sada dá stejné klíče; jiná magie odmítnuta; změna `klima_v1.json` v kopii dat → rozdíl dat `v1/klima_v1.json`, neplatné M5, M6, M6d, M7, M8, M9.

**Negativní nálezy / zvláštnosti**
- První běh: 2 chyby (uložit → načíst neshodné). Příčina: `SadaParametru.Nastav` pro tabulku průsaku přeformátovala JSON a klíč M6 bere text průsaku → po načtení jiný klíč M6. Oprava: stejný obsah ponechá původní text. (Dlouhodobě: klíč M6 by měl brát kanonický JSON průsaku, ne text – změnilo by klíče, odloženo.)
- Otisk vody přes fasádu musí použít stejný blok jako nástroj (mřížka 2 m s profily); s 4 m bez profilů vychází jiný otisk (7361d922c8b5a9d1) – to není změna světa, jen jiný vzorek.
- Dev používá seed `uint`, klient `long` – otázka v README.
- Deflate: bitová shoda ověřena v jednom běhovém prostředí (.NET 9); mezi verzemi .NET se porovnává obsah (`SouborPlanety.Kanonicky`).
- `GeologyCellIndex`/`TorusWrap` z Dev zatím nepoužité (fasáda nevrací buňky); `SouradniceQ16` je jen na hranici, knihovna počítá v `double`.
- Fasáda není vláknově bezpečná – řazení do fronty je úkol Godot jádra (G-4).
