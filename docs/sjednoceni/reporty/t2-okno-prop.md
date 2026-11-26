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
*(doplní se po implementaci)*
