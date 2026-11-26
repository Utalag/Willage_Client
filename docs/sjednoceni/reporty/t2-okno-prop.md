# T-2 – okno Editor materiálů: seznam, profil, fyzika, konfigurátor receptury, 2D náhled, variace seedu (PROP)

Větev `mat-v1-t2-okno` (z `mat-v1-t1-vpmg` `eef5a82`). Plán 06 (T-2), plán 05 kap. 6 (strom okna 2), N5 (jen vzhled), Jan 15:58 (samostatná okna).

## Cíl
1. **Stav editoru bez Godotu** (`Willage.Materialy.Api/Editor/`): `StavEditoru` (materiál, profil, receptura, seed, návrh profilu, verze změn)
   s operacemi výběr materiálu / profilu, zapnout / vypnout krok, přidat (jen spustitelné operace; zástupné odmítne), odebrat, posunout krok,
   nastavit parametr kroku, rozlišení, seed, návrh profilu (kontrola barvy #RRGGBB a rozsahů ze schématu), zrušit návrh; validace;
   seedy variací. `PopisKonfiguratoruReceptury` = editory ze schématu operací (jako G-5 z G-2). Testy `TestyT2` v Willage.Gen.Testy.
2. **Okno** `godot-prototyp/nastroje/EditorMaterialu.tscn` – samostatná hlavní scéna (ne součást generátoru světa). Kořen
   `EditorMaterialuOkno` jen propojuje uzly (`[GlobalClass]`, `scripts/cs/EditorMaterialu/`):
   - `JadroMaterialu` – `MaterialyApi` + `FrontaPrace` (G-4, znovu použitá): VPMG na pozadí, zastaralé výsledky zahodí;
   - `HorniListaMaterialu` – commit Dev, SHA zrcadla, golden (ověří při startu), stav VPMG, Validovat; zástupné: Diff, Uložit recepturu, Export návrhu (T-4);
   - `SeznamMaterialu` – 75 materiálů (ID, název, barva), filtr skupiny + hledání;
   - `ProfilVzhledu` – výběr profilu, hodnoty z katalogu; úprava = **návrh jen pro náhled** (jasně označený, katalog se nemění, uložení T-4);
   - `FyzikaJenCteni` – sekce geology (jen čtení, N5);
   - `KonfiguratorReceptury` + `KrokReceptury` + `EditorParametruVpmg` – kroky z registru Dev, zapnuto, parametry generované ze schématu, pořadí,
     přidat krok (zástupné operace vidět, ale zamčené s popisem), seed, rozlišení;
   - `NahledTexturyVpmg` (T-1) – velký 2D náhled s dlaždicemi 1–3 × + checksum / čas; `VariaceSeedu` – stejný profil, 4 seedy;
   - zástupné: `Prednastaveni` (šablony), náhled vrstev a řezu (runner Dev vrací jen poslední vrstvu), mřížka variant modelů (T-3).
3. Headless test `nastroje/testy/EditorMaterialuTest.tscn` (instancuje okno) + snímky pod Xvfb; běh bez nástroje = zástupný stav.

## Zúžení rozsahu – vzorek 5 materiálů (Jan 21:44: „Udělej zatím jen vzorek třeba 5 materiálů.“)
Editor a pipeline VPMG pracují zatím jen pro **5 materiálů** (`data/vpmg/vzorek_materialu_v0.json`, třída `VzorekMaterialu`,
ID i klíč se kontrolují proti katalogu). Výběr = hlavní povrchové a horninové materiály terénu gen-v3, každý z jiné skupiny katalogu:

| ID | key | skupina | proč |
|---|---|---|---|
| 1 | grass | drn | povrch – tráva, nejčastější horní buňka |
| 2 | topsoil | hlina | půda – ornice / hlína (gen-v3 hlína) |
| 3 | gravel_sand | pisek | sediment – písek / štěrk (gen-v3 písek) |
| 5 | cave_limestone | vapenec | sedimentární hornina – vápenec, kras |
| 6 | granite | krystal | vyvřelá hornina – žula |

Ostatních 70 materiálů je v seznamu vidět (filtr „všechny“ / skupiny), ale šedě a s příponou **„(zástupné)“**; výběr stav odmítne
(`zástupné: materiál N je mimo vzorek…`, titulek okna červeně). Výchozí filtr seznamu = vzorek, výchozí materiál = 1 tráva.
Golden 52 (`1756279408`) se dál ověřuje přes nástroj (lišta, dotnet testy) – je to kontrola pipeline, ne editovaný materiál.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| stav (dotnet) | výchozí receptura = VpmgPreview; přidání zástupné operace odmítnuto; parametry ze schématu; návrh mimo rozsah / špatná barva odmítnut; seedy variací deterministické |
| okno headless | 75 materiálů, filtr skupiny; materiál 52 + seed 0xC0FFEE00 → náhled checksum **1756279408** (golden v okně); návrh grain 0 → jednobarevný náhled; vypnutý hash_grain → jiný checksum; 4 variace = 4 různé checksumy; katalog na disku beze změny |
| bez nástroje | okno běží, náhled zástupný (šrafy) a lišta to říká |
| čas | odezva náhledu po změně parametru (fronta + proces) < 50 ms pro 64 px |
| svět | Willage.Gen beze změny, otisky beze změny |

## Rizika
- Rychlé posuvníky zahltí frontu → bere se jen poslední požadavek na cíl (generace).
- Okno 1600 × 960 s mnoha panely → střed ve `ScrollContainer`.

## Výsledky
| Měření | Výsledek |
|---|---|
| dotnet `Willage.Gen.Testy` (vše) | **OK 585, chyb 0**, 2 min 18 s (TestyT2 26/0 vč. vzorku: 5 skupin, výchozí 1, 52 odmítnut, 5 různých checksumů) |
| Godot headless `EditorMaterialuTest` | **OK 29, chyb 0** |
| vzorek v okně (seed 49, 64 px, výchozí receptura) | 1 grass `3429273298`, 2 topsoil `1045625574`, 3 gravel_sand `2154415335`, 5 cave_limestone `2810929995`, 6 granite `791206911` – každý = checksum nástroje |
| seznam | výchozí 5 položek; „všechny“ 75, z toho 70 „(zástupné)“; materiál 52 odmítnut |
| golden | lišta: `1756279408 = Dev`, zrcadlo = Dev; tráva seed 0xC0FFEE00 v okně = nástroj |
| odezva | změna seedu → hlavní + 4 variace: průměr **14 ms** (< 50 ms) |
| ostatní Godot headless | VpmgTest 3/0, JadroTest 12/0, GeneratorSvetaTest 22/0, NahledyTest 17/0, NahledyM4M6Test 21/0; okno Xvfb a hra bez chyb; po testech žádný visící proces nástroje |
| svět | `klima otisky` beze změny (mapa `800d420bb00047de`, voda `377a8210f82c856a` / `8e239a68c6d01be0`, klima `cb11da8d141a2a5e`); manifest +1 soubor (vzorek) → mění se jen M7 |

**Negativní / poctivé nálezy**
- visualProfiles katalogu Dev jsou zatím zástupné: všech 5 má `style neutral`, grain 500, density 300, irregularity 200; barvy jsou
  ladicí (tráva šedá `#808080`, žula fialová `#8c236e`). Textury proto vypadají jako barevný šum – to je stav dat Dev, ne chyba editoru;
  editor umí návrh profilu jen pro náhled, uložení až T-4.
- VPMG v0 má jen `base_fill` + `hash_grain`; `layerDensity` a `irregularity` nečte žádná operace (v okně označeno).
- Náhled vrstev a řezu, přednastavení a 6 modelů (T-3) zůstávají zástupné.

Snímky (Xvfb): `docs/sjednoceni/obrazky/t2/01–05-vzorek-*.png` (okno pro každý materiál), `textura-<id>-<key>.png` (samotná textura 2×2, 8×),
`06` materiál mimo vzorek, `07` seed 0xC0FFEE00, `08` návrh profilu, `09` tři kroky, `10` písek 3×3, `11` bez nástroje.
