# PROP – G-1: moduly M0–M7, pipeline, manifest katalogů, klíče modulů

Větev `gen-v1-g1-moduly` (z `gen-v1-plan05` 3cb5f7c, základ main `e2d55d2`). Podle [`05-plan-generator-editory.md`](../05-plan-generator-editory.md), fáze 1, krok G-1. Jan schválil plán 05 revize 2 včetně N1–N6 (2026-11-26 16:50 SEČ). Napsáno 2026-11-26 17:00 SEČ, před implementací. Během práce (17:02) se main posunul na `9d4f2b8` (krok 7c, 254/0); větev ho má sloučený (merge 20e8763) a chrání otisky `9d4f2b8`.

## Cíl
Obalit **stávající** generátor do modulů M0–M7 bez nových funkcí:
- každý modul = malá třída (vlastní soubor) nad dnešními třídami, s id, verzí algoritmu, závislostmi (`dependsOn` jako GeoLab), seznamem datových souborů a kanonickými parametry;
- graf modulů (kontrola cyklů, deterministické topologické pořadí, tranzitivně závislé moduly);
- **klíč modulu** = SHA-256(`gen_ver` | id | verze algoritmu | kanonické parametry modulu | SHA jeho souborů z manifestu | klíče vstupních modulů);
- **manifest katalogů** = SHA-256 každého souboru v `godot-prototyp/data` (rekurzivně) + souhrnná SHA; uložení `data/manifest_katalogu_v1.json`;
- pipeline: spustí moduly v topologickém pořadí, výstup drží v paměti podle klíče; při dalším běhu přepočítá jen moduly se změněným klíčem;
- `KonfiguraceSveta.Sestav` = tenký obal nad pipeline (podpis i výsledek beze změny).

## Co se znovu použije (průzkum kódu)
| Modul | Dnešní kód (beze změny) | Soubory, které kód opravdu čte |
|---|---|---|
| M0 Planeta | `ParametrySveta` (seed, rozměry, start, klima planety, přepínače), `ErozePlanety.NactiMore` | – |
| M1 Funkce světa | `SvetFn` (biomy, reliéf, masiv, sopky, mapa hornin) – izolace bez moře | `klima_presety.csv` |
| M2 Moře a kontinenty | `SvetFn` s `MoreSklon`, `MaskaPevniny`, `Panve` | `v1/more_v1.json` |
| M3 Geologie | `GeologieCs`, `GeoVrstvy`, útvary, mince, nitro sopky | `teren/poradi_hornin.json`, `materialy_v1.csv`, `v1/utvary_hostitele.json`, `v1/sum_hornin_v1.csv`, `teren/mineraly_hostitele.json` |
| M4 Eroze | `ErozePlanety.SvetPlanety/Mapa` (WGER keš s dnešním klíčem), `ErozeSvetaFn`, `Vodnici.Najdi` | `v1/eroze_v1.json` |
| M5 Klima a biomy | `MapaKlimatu`, `HydrologieKlimatu`, `Oazy`, `KlimaSvetaFn` | `v1/klima_v1.json` |
| M6 Voda a průsak | `NapajeniVody` (dobití hladiny 7c), `ParametryVody`, `PrusakKoeficient`, `KatalogMaterialu` (výpočet vody v blocích je dál líný přes `SvetKrok06.Voda`) | `v1/voda_v1.json`, `v1/prusak_v1.json`, `v1/materials-catalog-v1.json` |
| M7 Výstup planety | sestaví `SvetKrok06` (napojí erozi do geologie) + souhrn otisků | – |

Odchylka od tabulky 3.3 plánu: `poradi_hornin.json` čte geologie (`HostiteleUtvaru`, `KatalogHornin`), ne funkce světa → patří k M3. Dnešní klíč WGER ho obsahuje navíc (konzervativně) a zůstává beze změny.

## Nalezená rizika a jejich řešení
1. **`DataSveta.SouborySveta` má jen 3 soubory** (klima_presety, poradi_hornin, more_v1). Klíč WGER tedy nereaguje na `eroze_v1.json` jinak než přes kanonické parametry a vůbec ne na soubory geologie, klimatu a vody. Oprava v G-1: klíče modulů berou SHA **všech** souborů, které modul čte, z manifestu; test ověří, že každá cesta z `DataSveta` je v manifestu a patří aspoň jednomu modulu, a že změna každého souboru změní klíč právě dotčených modulů a jejich závislých. Klíč WGER se **nemění** (staré keše platí, plán 05: „zapojí se beze změny hodnot“).
2. **Planeta eroze nebere parametry z `p`:** `Sestav` staví svět planety z `new ParametrySveta { Seed, VseKrok06, StartBlok }` + `more_v1.json`, ostatní parametry `p` (reliéf, klima planety) do mapy eroze nevstupují. G-1 to zachová (otisky beze změny) a jen zapíše; klíč M4 přesto závisí na M1 a M2 (konzervativně, aby budoucí oprava nevyžadovala změnu grafu).
3. **Mutace:** `Sestav` nastavuje `g.Svet.Eroze` a `NactiMore` mění vstupní `p`. Pipeline pracuje na kopii parametrů; erozi do geologie napojuje jen M7 (vždy, i na null). Obal `Sestav` dál volá `NactiMore(p)` na vstupu (stejný vedlejší účinek pro dnešní volající).

## Testy a kritéria (tvrdá podmínka: otisky beze změny, všechny testy projdou)
| Test | Prošlo, když |
|---|---|
| celá sada `Willage.Gen.Testy` | 228/228 jako před změnou + nové testy, 0 chyb |
| golden mapa eroze (6d) | `800d420bb00047de` beze změny |
| segmenty GDScript (krok 5) | `059d807ab04b7f00`, `4391f413f91891ef` beze změny |
| pipeline = původní `Sestav` | otisk mapy, otisk klimatu, vodníci (uzly, výkony), oázy, sloupce geologie, otisk bloku vody shodné s referenční kopií původního `Sestav` (v testech) pro výchozí svět, `Krok06()` a `Krok5()` |
| graf modulů | 8 modulů, unikátní id, závislosti existují, bez cyklu (umělý cyklus odmítnut), topologické pořadí M0…M7, závislé moduly správně |
| izolace klíčů | změna parametru modulu N změní klíč N a jeho závislých, klíče modulů před ním ne (pro každý modul); stejné vstupy → stejné klíče |
| přepočet jen dotčených | druhý běh se stejnými vstupy: 0 přepočtů; změna parametru M5: přepočet jen M5–M7 |
| manifest | všechny soubory dat (rekurzivně) s SHA; každá cesta `DataSveta` v manifestu a v souborech aspoň jednoho modulu; změna 1 bajtu v kopii dat změní SHA souboru, souhrn a klíče právě modulů, které soubor čtou (+ závislé); uložený `manifest_katalogu_v1.json` odpovídá datům |
| rozdělení parametrů | každé pole `ParametrySveta` patří právě jednomu modulu |
| determinismus | klíče a výstupy stejné pro 1 a 8 vláken |

Výsledky (i negativní) se doplní níže.

## Výsledky (2026-11-26 17:15 SEČ)
**Prošlo: 307 / 307, 0 chyb** (`dotnet run -c Release --project cs/Willage.Gen.Testy`, 2 min 06 s). Před změnou: 228/0 na `e2d55d2` (2 min 04 s); main `9d4f2b8` má 254/0; nových testů G-1 je 53.

### Otisky (beze změny proti `9d4f2b8`)
- golden mapa eroze výchozího světa `800d420bb00047de`; segmenty GDScript `059d807ab04b7f00`, `4391f413f91891ef` (i ze segmentu geologie M3 pro `Puvodni()`).
- Nezávisle nástrojem `Willage.Gen.Nastroje klima otisky` na `9d4f2b8` i na této větvi (stejné řádky):
  - klima zap: mapa `800d420bb00047de`, 86 vodníků, krok 3 `9f32311e046f8b6a`, voda 14,14 `377a8210f82c856a` (1 pramen, 3 × 3: 21), klima `cb11da8d141a2a5e`, start mírný les 10,1 °C 943 mm;
  - klima vyp: mapa `800d420bb00047de`, 92 vodníků, krok 3 `9f32311e046f8b6a`, voda 14,14 `8e239a68c6d01be0` (3 × 3: 20).
- Pipeline = zmrazená kopie původního `Sestav` (`9d4f2b8`) pro výchozí svět, `Krok06()` a `Krok5()`: otisk a klíč mapy, vodníci, oázy, vodníci bez klimatu, parametry klimatu, dobití hladiny 7c (pole E), 200 sloupců geologie a povrch s erozí, otisk bloku vody 14,14.

### Co vzniklo
- `cs/Willage.Gen/Katalogy/ManifestKatalogu.cs` – SHA-256 všech 15 souborů `godot-prototyp/data` (CRLF → LF u .json/.csv/.txt/.md), souhrn, JSON tam a zpět, rozdíly; `godot-prototyp/data/manifest_katalogu_v1.json` (souhrn `9be889b7…`).
- `cs/Willage.Gen/Pipeline/`: `IModul`, `KontextBehu`, `NastaveniModulu` (parametry M4–M6 z JSON, přepsatelné v paměti pro G-2), `GrafModulu` (Kahn, ordinálně, cykly, závislé, předchůdci), `KlicModulu`, `KanonickeParametry` + `RozdeleniParametru`, `PipelineSveta` (keš v paměti podle klíče, stavy a časy modulů).
- `cs/Willage.Gen/Pipeline/Moduly/M0Planeta … M7VystupPlanety` – každý modul vlastní soubor, jen volá dnešní třídy; `ModulySveta.Graf()`.
- `ParametrySveta.Kopie()` (hluboká kopie), `KonfiguraceSveta.Sestav` = obal nad pipeline, testy `TestyG1.cs` + `SestavPuvodni.cs`, nástroj `manifest [--kontrola]` a `moduly`.
- Obrázek grafu: [`obrazky/g1/01-graf-modulu.png`](../obrazky/g1/01-graf-modulu.png).

### Graf (podle kódu)
M0 → M1 → M2; M2 → M3 (geologie) a M2 → M4 (eroze) souběžně; M4 → M5; M6 ← M3, M5; M7 ← M3, M4, M5, M6. Plán 05 kreslí řetěz M2 → M3 → M4; v kódu eroze na geologii nezávisí, změna geologie tedy erozi ani klima nepřepočítá.

### Časy (výchozí svět, mapa z keše WGER)
Původní `Sestav` 455–567 ms, pipeline 620–816 ms (+~170–300 ms). Moduly: M0 0, M1 0 (líně), M2 176, M3 169, M4 253 (načtení WGER + vodníci), M5 32, M6 28, M7 37 ms. Rozdíl je hlavně druhá stavba `SvetFn` startu (M2 a M3 staví každý svou, aby M7 mutací eroze neměnil výstup M2) a SHA manifestu. Případná úspora později: M3 nad SvetFn M2 s kopií pro erozi.

### Negativní a zvláštní nálezy
1. **Parametry moře (M2) v `ParametrySveta` nejdou změnit**: `NactiMore` je vždy přepíše z `more_v1.json` (test: `PodilMore = 0,1` v parametrech nezmění žádný klíč). Změna jde jen přes soubor – pro konfigurátor (G-2/G-5) je potřeba to vyřešit (návrh: nastavení M2 jako M4–M6 v `NastaveniModulu`).
2. **Mapa eroze nebere parametry reliéfu z `p`**: planeta se staví z `{Seed, VseKrok06, StartBlok}` + `more_v1.json`. Klíč M4 přesto závisí na M1/M2 (konzervativně) – změna reliéfu M1 přepočítá M4, i když mapa vyjde stejně.
3. **Klimatický preset se dřív zapisoval do vstupního `p`** (`SvetFn` násobí biomy na místě, opakované použití stejného `p` u ne-mírného klimatu by násobilo dvakrát). Pipeline staví z kopií, obal `Sestav` zachovává jen zápis `more_v1.json` do `p`. Žádný volající preset z `p` nečte (prohledáno).
4. Klíč WGER (`DataSveta.SouborySveta`, 3 soubory) zůstal beze změny kvůli platnosti starých keší; obsahuje navíc `poradi_hornin.json`, který erozi neovlivňuje. Klíče modulů pokrývají 12 souborů; 3 soubory C# nečte (`krajina_remap_v1.csv`, `materialy_voda.json`, `teren/port_manifest.json`) – mění jen klíč M7.
5. Parametry dobití hladiny 7c (`Hladina*`) jsou v `klima_v1.json`, tedy v klíči M5; jejich změna přepočítá i M5 (konzervativně, výsledek klimatu stejný). Při G-2 je lze přesunout do nastavení M6.
6. `ParametryKlimatu` je record s `Dictionary` → `==` porovnává odkaz; první běh testu proto hlásil 1 falešnou chybu (279/1), test porovnává kanonický text.
7. Git bez `.gitattributes`: na Windows s `autocrlf` by SHA dat bez normalizace nesouhlasila; manifest normalizuje CRLF. Doporučení: `godot-prototyp/data/** text eol=lf` (rozhodne Jan).
