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
| Měření | Výsledek |
|---|---|
| dotnet `Willage.Gen.Testy` (vše) | **OK 617, chyb 0**, 2 min 20 s (nová sada TestyT2b 32/0; T1 35/0, T2 26/0 upravené na v1) |
| goldeny přes nástroj (`goldeny`, `golden`) | **11/11**: 52 `1756279408`; grass `1626840554`, topsoil `2349117034`, gravel_sand `1787062125`, cave_limestone `3569558091`, granite `981040943`; smooth_noise `1923118788`, palette_map `3556819305`, strata `2013300739`, warp `618139878`, grass_tufts `1781956391` |
| goldeny přes fasádu | 5 materiálů z `data/vpmg/receptury/<id>.json` + 5 operací (fixture Dev → DTO → JSON fasády → nástroj) + 52 – vše = Dev |
| goldeny v okně (Godot) | každý z 5 materiálů: výchozí receptura v1 + seed 0xC0FFEE00 → checksum = golden, okno ukazuje „golden v1 Dev ✓“ |
| shoda s náhledy Dev | levá horní dlaždice okna = `Docs/images/vpmg-v1/material-*.png` bajt po bajtu (5/5) |
| schéma | 10 spustitelných operací = registr Dev (vč. aliasů value_noise→smooth_noise, color_variation→palette_map, irregularity→warp), 6 zástupných; parametry a výchozí hodnoty z rozboru zdrojů Dev; `operace_dev_v1.json` = živý rozbor; překryv bez nesouladu |
| receptury | 5 kopií = fixture Dev bajtově (SHA), platné proti schématu; materiál bez receptury → v0 |
| Godot headless | EditorMaterialuTest 27/0, VpmgTest 3/0, JadroTest 12/0, GeneratorSvetaTest 22/0, NahledyTest 17/0, NahledyM4M6Test 21/0; okno Xvfb a hra bez chyb; žádný visící proces nástroje |
| čas | textura 64 px v1: nástroj 0,9–1,2 ms, s přenosem 1,7–2,4 ms |
| otisky světa | **beze změny**: mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e` |
| klíče modulů | M0–M5 beze změny; **M6 `6316e43f…` → `6324df34…`** (a navazující M6d, M7, M8, M9) – viz níže |

**Negativní nálezy**
1. **v1 textury Dev jsou vizuálně rozbité, ale deterministické** – žluté / modré pruhy (topsoil, vápenec, žula) a téměř binární šum.
   Stejné to je v náhledech Dev a goldeny to obsahují, takže editor Dev zrcadlí věrně. Příčiny v `VpmgIntNoise` / `StrataOperation`:
   - `SmoothStep` vrací `u²(3L − 2u) / L` místo `/ L²` (L = 1024) → hodnota až ~1 048 576 místo ≤ 1024, `Lerp` extrapoluje až ~1000×
     (u druhého `Lerp` hrozí i přetečení int). `Fbm` pak ořízne na 0/1023 → binární šum v palette_map / smooth_noise.
   - `strata`: `mix = n * irregularity / 1500` s `n` 0…1023 (necentrované) → R/G +, B − → do žluta; s přestřelem z bodu 1 až do čisté žluté/modré.
   Lokální pokus (kopie pinu v `/tmp`, **Dev nezměněn**): `/ (L·L)` + `(n − 512)` → tráva a písek vypadají přirozeně, vápenec / žula
   pořád moc kontrastní (`shadeDelta`, `− mix/3` v modré). Viz poslední sloupec srovnávacího archu.
2. **Klíč M6 se mění**, protože M6 deklaruje celý soubor katalogu; data světa ne (otisky beze změny). Ve skutečnosti se změnily jen
   `visualProfiles` 5 materiálů. Návrh pro G-řadu: M6 bude klíčovat projekci `geology` (ID, K, pórovitost, skupina), ne celý soubor.
3. Explicitní parametry receptur v1 přebíjejí profil: v receptuře žuly (`bandMinPx` 4, `strengthPermille` 460) se `layerDensityPermille`
   profilu vůbec neprojeví; `irregularityPermille` jen přes okraje pásem strata. Bez parametrů kroku čtou výchozí hodnoty z profilu (test).
4. `style` (`willage_v1`) dál nečte žádná operace.
5. Dev formální schéma parametrů nemá; rozbor zdrojů regexem je funkční (test hlídá shodu), ale křehký.

**Návrhy pro Willage-backend (Dev neměníme)**
- A. Oprava `VpmgIntNoise.SmoothStep` na `(long)u*u*(3L−2u) / (L*L)` + přepočet goldenů v1 (a náhledů).
- B. `StrataOperation`: centrovat šum `(n − 512)`, zvážit shadeDelta / modrou složku; totéž ověřit v `palette_map`.
- C. Deskriptor parametrů v `IVpmgStepOperation` (např. `IReadOnlyList<VpmgParamInfo> Parameters` s názvem, typem, min/max,
  výchozí hodnotou nebo odkazem na pole profilu), aby klient nemusel rozebírat zdroje.
- D. Test v Dev, který hlídá rozsah barev / histogram textur (golden checksum chybu bodu A nezachytí).
- E. Operace, které čte `style`, nebo ho z profilu vyřadit.

Snímky (Xvfb): `docs/sjednoceni/obrazky/t2b/01–05-v1-*.png` (okno pro každý materiál vzorku, golden), `textura-v1-*.png`,
`06` návrh palety, `07` tráva + strata s parametry ze schématu Dev, `08` písek 3×3, `09` bez nástroje,
`10-srovnani-v0-v1.png` (v0 / v1 v okně / náhled Dev / pokus s opravou; skript `reporty/t2b_srovnani.py`).
