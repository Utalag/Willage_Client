# 06 – Plán: editor materiálů / generátor textur terénu (fáze 2 plánu 05)

Stav: 2026-11-26 21:30 SEČ. Zadání Jana 21:17 [t999u]: „Udělej ten generátor textur terénu.“ Výchozí bod `main` `b4bc92d`
(tag `gen-v1-g7`, G-2..G-7 sloučené, 524/0). Navazuje na plán 05 (kap. 6, tabulka E-1..E-4, N4, N5, N7, N8).

## Co už existuje (znovu nepíšu)
| Kde | Co | Jak použiju |
|---|---|---|
| Willage_Dev `main` `3476488` (jen čtení) | `Willage.World.Materials` (katalog `materials-catalog-v1.json`, 75 materiálů, `geology` + `visualProfiles`, loader), `Willage.World.Vpmg` (receptura schemaVersion 1, registr operací v0 `base_fill` + `hash_grain`, deterministický runner, RGBA8 vrstvy, FNV checksum, `RgbaPngWriter`), `tools/VpmgPreview`, golden `vpmg-golden-v1.json` (materiál 52, seed `0xC0FFEE00`, 64 px → 1756279408) | VPMG **voláme, nekopírujeme**: náš nástroj odkazuje projekty Dev z připnuté kopie a jen je obaluje |
| Client `godot-prototyp/data/v1/materials-catalog-v1.json` | zrcadlo katalogu Dev (= Dev bez koncového `\n`), čte ho M6 (fyzika) → je v klíči M6 | jen čtení; editor ho **nikdy nemění** (vzhled se navrhuje zvlášť, viz T-4) |
| Client `IKatalogy` / `PinKataloguDto` (G-3) | manifest, SHA připnutého katalogu | editor ukazuje pin + SHA; přibude pin commitu Dev |
| Client `data/vpmg/receptury/README.md` | místo pro naše receptury (N8) | T-4 sem ukládá |
| Client `Willage.Gen.Jadro.GeologyHash` | zrcadlo hashe Dev (golden vektory) | VPMG ho nepotřebuje (počítá Dev), nepřepisuju operace do net9 |
| Client `Willage.Gen.Api.Fronta.FrontaPrace` (G-4) | fronta na pozadí s dispečerem | jádro editoru ji použije znovu |

## Rozhodnutí N7 (net10 Dev × net9 klient) – jak VPMG konzumujeme
- **Mimo proces, z připnutého commitu.** `cs/Willage.Vpmg.Nastroj` je samostatný nástroj **net10.0**, který přes `ProjectReference`
  odkazuje projekty Dev v připnuté kopii `.willage-dev/<commit>/` (kopie se stáhne skriptem `cs/Willage.Vpmg.Nastroj/priprav_dev.sh`
  z `data/vpmg/dev_pin.json`; adresář je v `.gitignore`, je to obnovitelná keš). Kód Dev se nekopíruje ani neupravuje.
- Klient (net9: fasáda `cs/Willage.Materialy.Api`, Godot) s nástrojem mluví **JSON řádky přes stdin/stdout** (režim `server`, jeden
  dlouho žijící proces) – textura se vrací jako RGBA8 (base64) + FNV checksum Dev. Bez sestaveného nástroje editor běží dál,
  náhled je jasně označený jako zástupný.
- Přímý odkaz na projekty Dev (balíček / net10 v klientu) až po dohodě s backendem – stačí vyměnit adaptér `IZdrojVpmg`.

## Kroky (každý: PROP, vlastní větev řetězená, C#, uzly viditelné v editoru, testy dotnet + Godot headless, otisky světa beze změny, golden VPMG, snímky Xvfb, maskovaný push, bez merge)
| Krok | Větev | Cíl | Hlavní testy |
|---|---|---|---|
| **T-1** | `mat-v1-t1-vpmg` (z `main` b4bc92d) | připnutí Dev (`dev_pin.json`, skript), nástroj `Willage.Vpmg.Nastroj` (info, golden, katalog, kanon, spust, server), fasáda `Willage.Materialy.Api` (katalog vzhledu ze zrcadla, receptury ve schématu Dev, schéma operací pro konfigurátor, adaptér procesu), Godot jen ukázková scéna textur | golden 1756279408 přes nástroj i fasádu; zrcadlo = Dev; receptura JSON = `VpmgRecipeJson` bajtově; operace schématu = registr Dev; klíče M0–M6 beze změny |
| **T-2** | `mat-v1-t2-okno` | samostatné okno `nastroje/EditorMaterialu.tscn`: seznam materiálů, profil vzhledu (jen čtení + návrh pro náhled), fyzika jen čtení, konfigurátor receptury generovaný ze schématu operací, seed, 2D náhled textury (dlaždice), variace 4 seedů; zástupné: přednastavení, vrstvy/řez, mřížka variant, uložení | headless test okna, snímky, náhled = checksum nástroje |
| **T-3** | `mat-v1-t3-modely` | šest syntetických vzorků variant (plochý blok, okraj ostrova, svah a schody, jáma, přechod materiálů, pod vodou) + `SubViewport` s ortografickou izometrií, textura z VPMG | deterministické vzorky, očekávané hrany, snímky 6 variant × 5 materiálů |
| **T-4** | `mat-v1-t4-ulozeni` | uložení receptur do `data/vpmg/receptury/<id>.json` (manifest), návrhy profilů vzhledu zvlášť (`data/vpmg/navrhy_profilu.json`), export návrhu pro backend, napojení vizuálních dat pro svět (jen vzhled: nikdy ID materiálu ani fyzika) | uložit → načíst bajtově; klíče M0–M6 beze změny; zrcadlo katalogu beze změny |

Nové operace VPMG (šum, vrstvení, kořeny, praskliny, vlhkost, akvarel z inspirace) píše jen Willage-backend do Dev; editor je
ukazuje jako zástupné položky schématu, dokud nejsou v registru.

## Zúžení (Jan 21:44)
„Udělej zatím jen vzorek třeba 5 materiálů.“ – T-2 až T-4 pracují jen se vzorkem `data/vpmg/vzorek_materialu_v0.json`
(1 grass, 2 topsoil, 3 gravel_sand, 5 cave_limestone, 6 granite; zdůvodnění v `reporty/t2-okno-prop.md`). Ostatní materiály jsou
v editoru zástupné (vidět, nejde je vybrat). Rozšíření = přidat ID do souboru vzorku (žádná změna kódu).
