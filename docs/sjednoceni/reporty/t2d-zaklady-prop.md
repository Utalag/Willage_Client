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
*(doplní se po implementaci)*
