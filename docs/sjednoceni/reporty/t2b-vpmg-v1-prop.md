# T-2b – přepnutí editoru materiálů na Dev VPMG ops v1 + skutečné visualProfiles (PROP)

Větev `mat-v1-t2b-vpmg-v1` (z `mat-v1-t2-okno` `75c4a46`). Podnět: Willage-backend dokončil VPMG ops v1 a profily vzhledu
(Willage_Dev `main` `12c3e6b`, squash PR #16, na žádost Jana). Plán 06 (T-2b vložen mezi T-2 a T-3), plán 05 N7 / N8.

## Cíl
1. **Přepnutí pinu** Dev `3476488` → `12c3e6b05305c9ec6d0c9ed170791643f477871f`: `dev_pin.json`, `WillageDevCommit` nástroje,
   `priprav_dev.sh` (beze změny logiky), **zrcadlo katalogu** `data/v1/materials-catalog-v1.json` = Dev (bez koncového `\n`, jako dosud).
   Dev mění jen `visualProfiles` materiálů 1, 2, 3, 5, 6 (nové volitelné pole `palette`, `schemaVersion` zůstává 1); geologie beze změny.
2. **Schéma operací generované z Dev.** Dev formální schéma parametrů nemá (operace čtou `params` přes `VpmgStepParams.GetInt`).
   Nástroj (net10) dostane příkaz `parametry`: registr Dev (reflexe) + rozbor zdrojů operací v pinu (`VpmgStepParams.Get*`,
   `Params.TryGetValue`, `context.VisualProfile.*`, aliasy přes `_inner`). Výstup se uloží do `data/vpmg/operace_dev_v1.json`
   (generovaný soubor, test hlídá shodu s živým rozborem). Fasáda skládá konfigurátor **z generovaného souboru**; klientský
   `operace_vpmg_v1.json` je jen překryv (české názvy, rozsahy, jednotky, zástupné návrhy). Parametr z Dev bez překryvu se zobrazí
   obecným editorem; parametr v překryvu, který Dev nečte, = chyba testu. Nic se nekóduje v UI.
3. **Výchozí receptury vzorku = receptury v1 z Dev** (N8): `data/vpmg/receptury/<materialId>.json` = bajtová kopie
   `tests/Willage.World.Vpmg.Tests/Fixtures/recipes/recipe-*-v1.json` + `receptury/zdroj_receptur.json` (cesta v Dev, SHA, golden).
   Výběr materiálu v editoru načte jeho recepturu v1; „Výchozí receptura“ vrátí na ni. Materiály mimo vzorek zůstávají zástupné.
4. **Profil** – nové pole `palette` (seznam #RRGGBB) v DTO, návrhu jen pro náhled a editoru profilu.
5. **Goldeny** přes nástroj i fasádu: legacy 52 `1756279408`; 5 materiálů (grass `1626840554`, topsoil `2349117034`,
   gravel_sand `1787062125`, cave_limestone `3569558091`, granite `981040943`); 5 operací (smooth_noise `1923118788`,
   palette_map `3556819305`, strata `2013300739`, warp `618139878`, grass_tufts `1781956391`). Fixture se čte z pinu Dev.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| goldeny | 11/11 přes nástroj (`goldeny`) i přes fasádu (receptura z `data/vpmg/receptury` / kopie fixture, katalog = zrcadlo) |
| schéma | spustitelné operace = registr Dev (10: v0 2 + v1 8 vč. aliasů); parametry každé operace = rozbor zdrojů Dev; generovaný soubor = živý rozbor |
| receptury | kopie v `receptury/` = Dev fixture bajtově; validní proti schématu |
| okno | 5 materiálů: náhled seed 0xC0FFEE00 = golden materiálu; nabídka „Přidat krok“ ukazuje operace v1 s parametry ze schématu |
| svět | otisky `klima otisky` beze změny (geologie se nemění) |

## Rizika / očekávané negativní nálezy
- **Klíč M6 se změní**: M6 (voda a průsak) deklaruje celý soubor `v1/materials-catalog-v1.json`, ne jen geologii → změna
  `visualProfiles` změní jeho SHA, tedy klíč M6 (a M7). Data světa (otisky) se nezmění. Návrh pro G-řadu: klíč M6 z projekce
  `geology`, ne z celého souboru (neřeším teď – změna definice klíče je mimo editor materiálů).
- Rozbor zdrojů regexem je křehký vůči přepisu Dev → proto návrh pro backend: deskriptor parametrů v `IVpmgStepOperation`.
- Výchozí hodnoty závislé na profilu (`scalePermille` = `grainScalePermille` …) se v receptuře nevyplňují (prázdné = výchozí Dev).

## Výsledky
*(doplní se po implementaci)*
