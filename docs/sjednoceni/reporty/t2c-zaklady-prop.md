# T-2c (doplněk): podkladové dlaždice Gemini – PROP + výsledky

## Cíl
Jan (23:14, 23:17): připravit 5 ručních dlaždic (Gemini, 1024 JPEG) jako bezešvé neprůhledné 128×128 RGBA8 pro budoucí `base_texture` Dev
a ukázat, co z nich generátor udělá. Jen vzhled – ID, fyzika ani svět se nemění.

## Výjimka „jen C#“
`tools/priprava_dlazdic.py` (Python 3 + Pillow + numpy) – **výslovná výjimka Jana (23:14) jen pro offline přípravu assetů**; do hry, pipeline
světa ani testů nevstupuje (testy C# čtou jen hotové PNG/manifest). C# varianta nástroje se nedělala (Jan zvolil Python dřív, než vznikla),
srovnání C# ↔ Python proto není. Místo něj je nezávislá kontrola nástrojem Dev 04ed4d9 `VpmgPreview --import-tile` (C#): sha256 RGBA8 i PNG 5/5 shodné.

## Postup nástroje (deterministický, celá čísla)
1. střed čtverce (vstupy jsou 1024×1024 → beze změny), 2. box filtr 1024 → 128 (přesný plošný průměr, bez mezizaokrouhlení),
3. bezešvost: prolnutí s obrazem posunutým o 64 px, nejdřív X, pak Y, váha posunutého w = d·256/63 (d = vzdálenost od středu) → přes okraj
navazují sousední pixely původního obrazu, 4. alfa 255, 5. PNG + sha256 PNG + sha256 surových RGBA8.

## Výsledky
Soubory v Client `godot-prototyp/data/vpmg/zaklady/`, manifest `zaklady_v1.json` (zdroj + jeho sha256, rozměry, sha256, pngSha256, `baseTile` úryvek z `--import-tile`).

| materiál | soubor | sha256 RGBA8 | pngSha256 | zdroj |
|---|---|---|---|---|
| 1 grass | `1-grass-v1.png` | `ec468bfc4886dee4dcca923fc139f1fde783e901349b9ff2ab350f1a1c7aea6a` | `f8fc4085e004fbf57243b66c7a1af9089c930e688a5edb4b7709c895aea1f32d` | `zaklad-1-grass.jpg` `4c8cb705045b3e51…` |
| 2 topsoil | `2-topsoil-v1.png` | `16a7f13cc8f865b88c62763514873ab02b6683667a17d2ac68007e1e59292f6d` | `bafa3d6e98a5d6f682cfc7758d5450951714c6eb8d0bdf4958aaade860eb8531` | `zaklad-2-topsoil.jpg` `86aa7b894116a477…` |
| 3 gravel_sand | `3-gravel_sand-v1.png` | `552743b862c1ba9f49f8f114651c5ef44bb9bb1c2629ded48aca36a362f69083` | `c06995651ccaad3f101b2b8834ef7199d22fd920596a67e5e111d22ec871729a` | `zaklad-3-gravel_sand.jpg` `0301f197a03852d9…` |
| 5 cave_limestone | `5-cave_limestone-v1.png` | `f8f7dbfff2d678f7b45c75a1a3848eb3486092ca0f0111a1ea6f130d584f2d40` | `922156d5da9968847b4bc256dc7782d6ed89acf0177b9d1702c64a59a00659c2` | `zaklad-5-cave_limestone.jpg` `791bcc5ad6cbc7bd…` |
| 6 granite | `6-granite-v1.png` | `743b27dd70bff346a6c10d59a696172d576500b8d14df23cc0137a1f42aac28c` | `8ea9c353a27e2cc4d248e49441cd1980c6f83322d84d5cbd99f9d774593bbc93` | `zaklad-6-granite.jpg` `3437c056f2075028…` |

- kontrola bezešvosti (průměrný rozdíl sousedních pixelů přes okraj vs. uvnitř): X 3,4–8,1 vs 2,0–6,8, Y 1,8–7,3 vs 4,3–9,2 – šev není viditelný (viz arch, sloupec 2×2).
- `data/vpmg/*` je v manifestu katalogů (32 souborů, souhrn `ad961209…`) → mění se jen souhrn manifestu a klíč M7; otisky světa beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`); testy dotnet 623/0, Godot EditorMaterialuTest 27/0.
- pin klienta zůstává **42e7475** (přepnutí na 04ed4d9 není triviální: nový katalog s `baseTile`, zdroj dlaždic, receptury v2 → samostatný krok T-2d).

## Dočasný náhled (není operace klienta ani Dev) – ODSTRANĚN v T-2d
T-2d (Dev 36ac11f) má `base_texture` v nástroji i editoru, program byl smazán (zůstává v historii commitu `51f2252`).

`docs/sjednoceni/reporty/t2c-zaklady-nahled/` – malý C# program nad Dev 04ed4d9 (jen čtení): dočasná kopie katalogu Dev, do které se vloží
`baseTile` těchto 5 dlaždic, a běh receptur `recipe-*-v2.json`. Arch `obrazky/t2c/20-zaklady-variace.png`: originál | dlaždice 2×2 | 4 variace
(seedy editoru = seed + i·7919) receptur v2 **bez kroku palette_map** | v2 Dev beze změny | procedurální v1.

### Negativní nález → návrh pro Dev
- `base_texture` sám dlaždici zachová přesně (směr. odchylka = dlaždice), ale **`palette_map` v recepturách v2 obraz celý přemaže** šumem palety
  (arch `obrazky/t2c/21-v2-kroky.png`: řádek = materiál, sloupce = receptura po krocích base_texture → palette_map → smooth_noise [→ grass_tufts]).
  Návrh: parametr míchání `mixPermille` (0 = beze změny) pro `palette_map`, nebo v2 recepturám palette_map vypustit.
- Variace samotných `base_texture` + `smooth_noise` (amplituda 25–40 ‰) jsou velmi jemné – hlavně posun dlaždice podle seedu.
