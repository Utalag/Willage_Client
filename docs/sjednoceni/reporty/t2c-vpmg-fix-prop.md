# T-2c – přepnutí na opravu VPMG v1 (Dev 42e7475) + schéma z deskriptorů Dev (PROP)

Větev `mat-v1-t2c-vpmg-fix` (z `mat-v1-t2b-vpmg-v1` `bba6873`). Podnět: Willage-backend sloučil opravu VPMG v1 (PR #17, `42e7475`)
podle návrhů A–E z T-2b: A SmoothStep v `long` / L³, B strata centrovaný šum + ClampToPaletteExtents, rovnoměrný jitter,
grass_tufts 2D centrovaný šum, receptura žuly bez natvrdo zadaných hodnot, C deskriptory parametrů (`VpmgOperationCatalog`,
`VpmgPreview --describe-ops`), D testy barev, E `style` rezervovaný.

## Cíl
1. Pin `12c3e6b` → `42e7475`: `dev_pin.json`, `WillageDevCommit`, zrcadlo katalogu (Dev mění visualProfiles 5 a 6), receptury
   `data/vpmg/receptury/<id>.json` = nové fixture Dev, `zdroj_receptur.json` (SHA + nové goldeny).
2. **Schéma operací z deskriptorů Dev** místo rozboru zdrojů: příkaz nástroje `parametry` volá `VpmgOperationCatalog.DescribeAll()`
   (stejný zdroj jako `--describe-ops`); typ, rozsah min/max, výchozí literál, pole profilu, popis Dev. Alias (prázdné Parameters v Dev)
   = reflexe na pole `_inner` operace v registru → parametry cílové operace. Rozbor zdrojů regexem se ruší.
   Český překryv `operace_vpmg_v1.json` zůstává (názvy, skupiny, popisy, jednotky, zástupné návrhy); rozsahy už nenese (bere Dev).
   Deskriptory neříkají, které pole profilu operace čte mimo výchozí hodnoty (base_fill → baseColor, hash_grain → grain,
   palette_map / strata → palette) → doplní překryv (`ctiProfil`), test hlídá jen existenci polí; návrh pro backend.
3. Goldeny: 52 `1756279408`; grass `756991887`, topsoil `2725408357`, gravel_sand `3628591702`, cave_limestone `2752359023`,
   granite `917430836`; smooth_noise `2914983316`, palette_map `2821145053`, strata `2813106466`, warp `887461636`, grass_tufts `2214710167`.
4. Srovnávací arch v0 / v1 rozbitá (12c3e6b) / v1 opravená (42e7475), dlaždice 2×2, 8× nejbližší soused; snímky okna pro 5 materiálů.
5. Nezávazně (necommitovat): nástroj C# PNG → bezešvá neprůhledná dlaždice 128×128 + SHA-256 (podklady Gemini).

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| goldeny | 11/11 nástroj, fasáda, okno; náhledy Dev = okno |
| schéma | `operace_dev_v1.json` = deskriptory Dev (živě přes nástroj) = výstup `VpmgPreview --describe-ops` (porovnání polí) |
| barvy | v1 opravená: žádné čistě žluté / modré pixely (kontrola v testu: podíl pixelů mimo rozsah palety ± jitter) |
| svět | otisky beze změny; klíč M6 (+ navazující) se změní kvůli zrcadlu katalogu, M0–M5 ne |

## Rizika
- Deskriptory a implementace se v Dev mohou rozejít → test hlídá, že každá operace registru má deskriptor a že goldeny sedí.

## Výsledky
| oblast | výsledek |
|---|---|
| pin | `dev_pin.json` + nástroj (`WillageDevCommit`) → `42e7475332b0bda06fa7b5097b4aac92ab4a95fe`; zrcadlo katalogu = Dev 42e7475 (liší se jen koncovým `\n`); receptury vzorku `data/vpmg/receptury/{1,2,3,5,6}.json` = bajtové kopie `recipe-*-v1.json` z 42e7475 (granit bez natvrdo zadaných parametrů) |
| schéma | zdroj přepnut na deskriptory Dev: příkaz nástroje `parametry` volá `VpmgOperationCatalog.DescribeAll()` → `data/vpmg/operace_dev_v1.json`; parsování zdrojáků C# z T-2b odstraněno. Test porovná soubor s živým výstupem nástroje i s `VpmgPreview --describe-ops` (pole + výchozí hodnoty). Český překryv `operace_vpmg_v1.json` zůstává (názvy, popisy, `ctiProfil`), test hlídá nesoulad překryv ↔ Dev = 0 |
| goldeny | 11/11 přes nástroj i fasádu: grass 756991887, topsoil 2725408357, gravel_sand 3628591702, cave_limestone 2752359023, granite 917430836; ops smooth_noise 2914983316, palette_map 2821145053, strata 2813106466, warp 887461636, grass_tufts 2214710167; legacy 52 = 1756279408 |
| barvy | čistě žluté / modré pixely 0 u všech 5; mimo rozsah palety (> 48) 0 % (granit 2,5 % – světlá zrna živce, v toleranci testu) |
| testy | dotnet **623 / 0** (2 min 26 s); Godot headless EditorMaterialuTest 27/0, VpmgTest 3/0, JadroTest 12/0, GeneratorSvetaTest 22/0, NahledyTest 17/0, NahledyM4M6Test 21/0; okno pod Xvfb a hra headless bez chyb; žádný osiřelý proces nástroje |
| svět | `klima otisky` beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`); klíče modulů po změně zrcadla: M0–M5 beze změny, M6 `2abafa4e9680bc40` / M7 `7d4c426747965a1d` (+ navazující) se mění – očekáváno, viz negativní nález T-2b (M6 řetězí celý soubor katalogu) |
| snímky | `obrazky/t2c/01–09` okno per materiál a stavy, `10-srovnani.png` sloupce v0 / v1 rozbitá (12c3e6b) / v1 opravená (42e7475), dlaždice 2×2, 8× nejbližší soused; poslední sloupec bajtově = náhledy Dev |

### Negativní / otevřené
- Deskriptory Dev neuvádějí, která pole profilu operace čte → `ctiProfil` zůstává v klientském překryvu (návrh pro Dev: pole `readsProfile` v deskriptoru).
- Nástroj na dlaždice: C# varianta se nedělala – Jan (23:14) zvolil Python (Pillow) jako výjimku pro offline přípravu assetů, viz `t2c-zaklady-prop.md`.

