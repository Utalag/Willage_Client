# PROP – G-1: moduly M0–M7, pipeline, manifest katalogů, klíče modulů

Větev `gen-v1-g1-moduly` (z `gen-v1-plan05` 3cb5f7c, základ main `e2d55d2`). Podle [`05-plan-generator-editory.md`](../05-plan-generator-editory.md), fáze 1, krok G-1. Jan schválil plán 05 revize 2 včetně N1–N6 (2026-11-26 16:50 SEČ). Napsáno 2026-11-26 17:00 SEČ, před implementací.

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
| M6 Voda a průsak | `ParametryVody`, `PrusakKoeficient`, `KatalogMaterialu` (načtení a kontrola; výpočet vody je dál líný přes `SvetKrok06.Voda`) | `v1/voda_v1.json`, `v1/prusak_v1.json`, `v1/materials-catalog-v1.json` |
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

## Výsledky
*(doplní se po implementaci)*
