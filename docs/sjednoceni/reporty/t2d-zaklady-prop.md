# T-2d: base_texture + receptury v2 vzorku (Dev 36ac11f) – PROP

Větev `mat-v1-t2d-zaklady` z `mat-v1-t2c-vpmg-fix` (`7332992`). Zadání: Willage-backend 23:43 (Dev main `36ac11f`, PR #19 + #20).

## Cíl
- Pin nástroje VPMG + zrcadla katalogu na `36ac11f1a057c08b587eab0a4a88c976e6edc3c5` (katalog má `baseTile` pro 1, 2, 3, 5, 6; dlaždice `Data/tiles/00x-<key>-v1.rgba8` = naše `data/vpmg/zaklady`).
- Výchozí receptury vzorku (`data/vpmg/receptury/<id>.json`, N8) = bajtové kopie `recipe-*-v2.json` (base_texture → palette_map mix 200 ‰ → smooth_noise → [grass_tufts]).
- Nástroj najde dlaždice: zdroj dlaždic = složka Data vedle katalogu Dev (kopie z projektu Materials při buildu), explicitně předaná runneru.
- Schéma operací dál z deskriptorů Dev (`--describe-ops`); `base_texture` (+ alias `tile_sample`) a `palette_map.mixPermille` dostanou český překryv.
- Návrh profilu v editoru (paleta, barva …) nesmí ztratit `baseTile` (`with` místo konstruktoru).
- Dočasný náhled z T-2c (`reporty/t2c-zaklady-nahled/`) je teď zbytečný → odstranit (historie: commit `51f2252`).

## Hypotézy / očekávání
| oblast | očekávání |
|---|---|
| goldeny | v2 5/5 (grass 3708330389, topsoil 4232278201, gravel_sand 589438081, cave_limestone 1867729526, granite 453757041) + v1 receptury 10/10 + legacy 52 = 1756279408, přes nástroj i fasádu |
| schéma | 12 spustitelných operací (+ base_texture, tile_sample), nesoulad překryv ↔ Dev 0 |
| svět | otisky beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`); M6/M7 se mění kvůli zrcadlu katalogu (jako T-2b/T-2c) |
| variace | seedy mění hlavně posun / otočení dlaždice; tint je pevný v receptuře (85–115 ‰) → očekávám malé rozdíly barvy mezi seedy |

## Rizika
- Token pro Willage_Dev v boxu chybí (23:44) → `priprav_dev.sh` nejde. Náhrada: kopie Dev rekonstruovaná z 04ed4d9 + patche GitHub API (compare 04ed4d9…36ac11f),
  binární dlaždice z našich souborů; ověřeno `git hash-object` proti stromu 36ac11f z GitHub API: 585/600 blobů shodných, chybí jen 15 náhledových PNG v `Docs/images/vpmg-v2` (build je nepotřebuje).
  Až bude token, složku smazat a stáhnout skriptem. Push bez tokenu také nepůjde → případně čeká.

## Výsledky
| oblast | výsledek |
|---|---|
| pin | `dev_pin.json` + `WillageDevCommit` → `36ac11f`; zrcadlo katalogu = Dev 36ac11f bez koncového `\n` (75/75 záznamů, `baseTile` u 1, 2, 3, 5, 6); `dev_pin.json` má nově `dlazdice` a `goldenReceptur.fixtureV2` |
| dlaždice | nástroj načítá zrcadlo loaderem Dev s kořenem Data vedle své sestavy (`Data/tiles` z projektu Materials) a předává `FileVpmgTileSource` runneru; loader Dev ověří SHA každé `baseTile`. Klient dlaždice nekopíruje: `data/vpmg/zaklady` (PNG) má stejné SHA RGBA8 jako `Data/tiles/00x-*.rgba8` (test 5/5) |
| receptury | `data/vpmg/receptury/{1,2,3,5,6}.json` = bajtové kopie `recipe-*-v2.json` (index `zdroj_receptur.json`, golden v2); v1 receptury zůstávají v Dev a testují se odtud |
| schéma | `operace_dev_v1.json` z deskriptorů Dev (= `--describe-ops`): 12 spustitelných (+ `base_texture`, `tile_sample`) + 6 zástupných; bool parametry Dev → druh `prepinac` (CheckBox v okně); český překryv pro `base_texture` / `tile_sample` / `mixPermille`; nesoulad 0 |
| editor | profil ukazuje řádek `baseTile` (asset, SHA, náhled PNG z `data/vpmg/zaklady`), návrh profilu (paleta …) `baseTile` zachová (`with` v nástroji i fasádě), přepínač `offsetEnabled` mění výstup a zpět vrací golden |
| goldeny | nástroj 16/16: v2 grass 3708330389, topsoil 4232278201, gravel_sand 589438081, cave_limestone 1867729526, granite 453757041; v1 10/10 beze změny; legacy 52 = 1756279408. Fasáda: v2 5/5 z `data/vpmg/receptury` + v1 5/5 + 5 operací z fixture Dev; okno: golden v2 u všech 5 |
| testy | dotnet **646 / 0** (2 min 23 s); Godot headless EditorMaterialuTest 40/0, VpmgTest 3/0, JadroTest 12/0, GeneratorSvetaTest 22/0, NahledyTest 17/0, NahledyM4M6Test 21/0; okno pod Xvfb a hra headless bez chyb, žádný osiřelý proces nástroje |
| svět | otisky beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`); M0–M5 beze změny, M6 `fbaaa68479227c85`, M7 `e17a705384e5feca` (+ navazující) – zrcadlo katalogu, jako T-2b/T-2c |
| T-2c náhled | `reporty/t2c-zaklady-nahled/` odstraněn (nahrazen skutečným `base_texture` v nástroji a okně) |
| snímky | `obrazky/t2d/01–05` okno per materiál se 4 variacemi, `06–09` stavy, `10-srovnani-v1-v2.png` (v1 procedurální / v2 / dlaždice), `20-variace.png` (dlaždice, golden v2, 4 variace) – archy skládá Godot test (C#) |

### Nálezy
- **Variace seedu jsou skoro jen posun dlaždice.** Rozdíl průměrného jasu mezi 4 seedy 0,3–0,7 (z 255); `tintPermille` je pevný v receptuře, `palette_map` (mix 200 ‰) a `smooth_noise` (17–20 ‰) jsou jemné. Návrh pro Dev (přes Willage-backend): volitelný rozptyl tintu ze StepSeed (např. `tintJitterPermille`, 0 = dnešní chování → goldeny beze změny) a případně `rotate90`/zrcadlení pro dlaždice bez směrového světla. Stojí za to, pokud má být sousední voxel téhož materiálu rozlišitelný i barvou; jinak posun stačí.
- `strata` (a `palette_map` s mix 1000) přepíše celý vstup → po přidání strata do receptury v2 se dlaždice ztratí (přepínač offset pak nic nemění). Návrh: `mixPermille` i pro strata.
- Token pro Willage_Dev v boxu chyběl → kopie Dev rekonstruovaná (viz Rizika), 585/600 blobů ověřeno; build ani testy chybějící náhledová PNG Dev nepotřebují.
- Receptury v2 mají rozlišení 64 px, dlaždice 128 px: `base_texture` při 1000 ‰ bere výřez 64 px (šev přes okraj ve 2×2 se v číslech neliší od vnitřku, ale je to jen čtvrtina dlaždice).

