# T-1 – VPMG z připnutého Dev jako samostatný nástroj + fasáda materiálů (PROP)

Větev `mat-v1-t1-vpmg` (z `main` `b4bc92d`). Plán 06 (krok T-1), plán 05 kap. 6, N7, N8. Zadání Jana 21:17 [t999u].

## Cíl
1. **Připnutí Dev:** `godot-prototyp/data/vpmg/dev_pin.json` (repo, commit `3476488…`, SHA katalogu Dev, golden) a skript
   `cs/Willage.Vpmg.Nastroj/priprav_dev.sh` – stáhne přesný commit do `.willage-dev/<commit>/` (fetch s tokenem jen v URL příkazu, výstup
   maskovaný, token nikdy v git configu; nebo `--zdroj <lokální klon>`), ověří HEAD.
2. **Nástroj `cs/Willage.Vpmg.Nastroj`** (net10.0, ProjectReference na `Willage.World.Materials` a `Willage.World.Vpmg` v připnuté kopii,
   žádná kopie kódu Dev). Příkazy: `info` (commit, operace registru zjištěné reflexí nad sestavou Dev + `CanResolve`), `golden` (fixture Dev),
   `katalog <zrcadlo>` (zrcadlo vs. katalog Dev: bajty bez koncových bílých znaků + záznamy po načtení loaderem Dev), `kanon` (receptura →
   `VpmgRecipeJson.ToJson`), `spust` (receptura + seed + volitelný návrh profilu → PNG / checksum), `server` (JSON řádky).
   Návrh profilu = jiný `MaterialVisualProfile` jen v paměti nástroje (katalog se nemění).
3. **Fasáda `cs/Willage.Materialy.Api`** (net9, bez Godotu, bez Dev): DTO, `IKatalogVzhledu` (zrcadlo → materiály, profily, fyzika jen
   čtení), `RecepturyVpmg` (výchozí receptura = VpmgPreview, JSON ve formátu Dev, validace proti schématu), `SchemaOperaciVpmg`
   (`data/vpmg/operace_vpmg_v0.json`: parametry operací pro konfigurátor T-2; operace z inspirace jako `zastupna`), `IZdrojVpmg` +
   `ZdrojVpmgProces` (server mimo proces, zámek, líný start; chybí-li nástroj → `Dostupny=false`, zástupný popis).
4. **Godot:** jen ukázková scéna `nastroje/testy/VpmgTest.tscn` (net9 Godot volá nástroj přes fasádu, dlaždice textur 12 materiálů), headless + Xvfb snímek. Okno až T-2.
5. Willage.Gen (svět) beze změny; katalog-zrcadlo beze změny.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| golden | nástroj `golden` i fasáda (server) → 1756279408 pro materiál 52, seed 0xC0FFEE00, 64 px |
| determinismus | stejný vstup = stejné bajty; jiný seed = jiný checksum; návrh profilu s grain 0 = celá plocha baseColor |
| zrcadlo | 75 záznamů = Dev; liší se jen koncovým `\n`; každý materiál má profil `default` |
| receptura JSON | serializace fasády = `VpmgRecipeJson.ToJson` bajt po bajtu (výchozí i náhodné receptury) |
| registr | nezástupné operace schématu = operace registru Dev (`base_fill`, `hash_grain`); neznámý typ → chyba z nástroje, ne pád |
| klíče světa | manifest s novými soubory `data/vpmg/*` → klíče M0–M6 beze změny; otisky světa beze změny |
| čas | start serveru (studený) a jedna textura 64 px / 256 px (měřím) |

## Rizika
- Dev je soukromé repo → skript potřebuje token v proměnné prostředí; bez sítě jde `--zdroj`.
- Sestavení Dev projektů (analyzéry, `TreatWarningsAsErrors`, Vogen) může na jiném SDK selhat → nástroj sestavuji SDK 10.0.402 (box).
- Schéma parametrů operací v Dev neexistuje (operace čtou `params` ad hoc) → popis je náš (`operace_vpmg_v0.json`), shodu typů hlídá test; parametry samotné hlídat nejde (negativní nález, návrh pro backend).

## Výsledky
**Postaveno:** cíl 1–5. Pin `data/vpmg/dev_pin.json` + `priprav_dev.sh`; nástroj `cs/Willage.Vpmg.Nastroj` (5 souborů, jen obal nad Dev:
`PinDev`, `KatalogSNavrhem`, `PrikazyVpmg`, `ServerVpmg`, `Program`); fasáda `cs/Willage.Materialy.Api` (`MaterialyApi`, `KatalogVzhledu`,
`RecepturyVpmg`, `SchemaOperaciVpmg`, `ZdrojVpmgProces`, `PinDev`, DTO); schéma operací `data/vpmg/operace_vpmg_v0.json` (2 spustitelné + 7 zástupných);
Godot uzel `EditorMaterialu/NahledTexturyVpmg` (TextureRect, dlaždice) a test `nastroje/testy/VpmgTest.tscn`. Willage.Gen beze změny, zrcadlo katalogu beze změny.

| Ověření | Výsledek |
|---|---|
| dotnet celá sada | **OK 559, chyb 0** (2 min 21 s); z toho T1 **35/0** |
| testy Dev v připnuté kopii (`dotnet test` Willage.World.Vpmg.Tests) | 6/6 |
| golden | nástroj `golden` (katalog Dev i zrcadlo) **1756279408 = Dev**; fasáda přes server 1756279408; Godot → fasáda → nástroj 1756279408 |
| zrcadlo | bajty bez koncových bílých znaků = Dev, záznamy po loaderu Dev 75/75 shodné, Dev má o 1 B víc (koncové `\n`) |
| receptura JSON | fasáda = `VpmgRecipeJson.ToJson` bajt po bajtu 8/8 (výchozí, 128 px, vypnutý krok s diakritikou v params, 5 náhodných) |
| registr | operace Dev zjištěné reflexí + `CanResolve` = `base_fill, hash_grain` = spustitelné ve schématu; `perlin` → `KeyNotFoundException` z registru Dev, proces běží dál |
| návrh profilu (jen paměť) | grain 0 → celá plocha baseColor; `#102030` se projeví; po návrhu znovu golden; zrcadlo na disku beze změny |
| klíče světa | bez `data/vpmg/*` se klíče **M0–M6 nemění**, mění se jen M7 (souhrn manifestu – návrh G-1); otisky `klima otisky` beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`; segment `059d807ab04b7f00` v testech) |
| Godot headless | VpmgTest **3/0**; JadroTest 12/0, GeneratorSvetaTest 22/0, NahledyTest 17/0, NahledyM4M6Test 21/0 |
| Godot Xvfb | VpmgTest 3/0, snímek `obrazky/t1/01-vpmg-materialy.png` (12 materiálů, dlaždice 2×2) |

**Časy:** studený start serveru (.NET 10 + katalog + registr) 86–133 ms; textura 64 px v nástroji 0,3 ms, s přenosem přes proces ≈ 11 ms
(první), všech 75 materiálů 64 px 55 ms (75 různých checksumů); 256 px 1,2 ms v nástroji, 18,7 ms s přenosem (base64 přes JSON). Manifest: 18 souborů, souhrn `ba79f3fb…` (přibyly `vpmg/dev_pin.json`, `vpmg/operace_vpmg_v0.json`).

**Negativní nálezy / odchylky:**
1. **Dev nemá schéma parametrů operací** – `base_fill` čte jen `layer`, `hash_grain` nic; popis pro konfigurátor je náš a test hlídá jen typy, ne parametry. Návrh pro backend: `IVpmgStepOperation` s popisem parametrů.
2. **VPMG v0 skoro nic nenastavuje v receptuře:** vzhled dělá profil katalogu (`baseColor`, `grainScalePermille`); `layerDensity`, `irregularity` a `style` žádná operace nečte (test to potvrzuje: návrh s nimi = golden).
3. Runner Dev vrací jen **poslední vrstvu** (`GetLastOrEmpty`) – náhled více vrstev / řezu zatím nejde bez kopie runneru; zůstává zástupné (návrh: `Run` vracející všechny vrstvy).
4. Profily katalogu Dev jsou z velké části zástupné barvy (tráva `#808080` šedá, vzduch `#2f8bbf`, svor `#d8365d` sytě červený) – je vidět na snímku; oprava je věc návrhu profilů (T-4), ne editoru.
5. Klíč M7 se mění s každým novým souborem v `data/` (souhrn manifestu) – recepturami tedy M7 ano, M0–M6 ne. README receptur to říká správně.
6. `/tmp/wdev` (starší klon Dev jiným agentem) má token v `remote.origin.url` – nepoužívám ho (používám `.willage-dev` bez tokenu), nesahal jsem na něj.
