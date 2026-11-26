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
*(doplní se po implementaci)*
