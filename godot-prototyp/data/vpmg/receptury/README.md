# Receptury VPMG (naše, návrhy)

Sem patří receptury VPMG pro okno 2 (editor materiálů): jeden soubor `<materialId>.json` ve schématu receptury Willage_Dev
(`Willage.World.Vpmg`, `VpmgRecipeJson`, schemaVersion 1: `materialId`, `visualProfile`, `resolution`, kroky `id/type/enabled/params`).

- VPMG se spouští jako samostatný nástroj z **připnutého commitu Willage_Dev** (rozhodnutí N7, Jan 17:24); Willage_Dev je pro nás jen ke čtení.
- Receptury se ukládají jen tady (rozhodnutí N8). Do Willage_Dev jdou jen jako návrh přes Willage-backend; nové operace VPMG také.
- Soubory jsou v manifestu katalogů (`data/manifest_katalogu_v1.json`); klíče světa (M0–M6) nemění, jen klíč M7 a vizuální keš.
- **T-2b:** `1.json`, `2.json`, `3.json`, `5.json`, `6.json` = bajtové kopie receptur v1 z Willage_Dev `12c3e6b`
  (`tests/Willage.World.Vpmg.Tests/Fixtures/recipes/recipe-*-v1.json`), index se zdrojem, SHA a goldenem v `zdroj_receptur.json`.
  Editor je bere jako výchozí recepturu materiálu vzorku. Vlastní uložené receptury až T-4.
- **T-2d:** stejné soubory = bajtové kopie receptur **v2** z Willage_Dev `36ac11f` (`recipe-*-v2.json`): `base_texture` nad ruční dlaždicí
  `baseTile` z katalogu (dlaždice = `data/vpmg/zaklady`, v Dev `Data/tiles/00x-<key>-v1.rgba8`) → `palette_map` (mix 200 ‰) → `smooth_noise` [→ `grass_tufts`].
