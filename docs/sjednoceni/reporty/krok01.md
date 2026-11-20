# Report – Krok 1: Základy generátoru V1.0

Větev `gen-v1-krok01-zaklady` (ze `sjednoceni` 08d82db). Plán: `04-implementace-generatoru.md`, krok 1. PROP: [`krok01-prop.md`](krok01-prop.md). Datum 2026-11-21 00:20 SEČ. Testy běžely lokálně na boxu (Godot 4.7.2 headless, Python 3), bez CI.

## Proč tento krok jako první
Krok 1 nezávisí na 6.1 ani 6.3 (ty patří do kroku 10). Ostatní kroky z něj berou jednotky, rozměry, verzi a id materiálů.

## Co se udělalo a odkud je kód
| Změna | Soubor | Odkud |
|---|---|---|
| jednotky v metrech, jeden převod l → m³, scéna 1 m | `godot-prototyp/scripts/jednotky.gd`, `scripts/voda/litry.gd` a 40 commitů převodu | sloučená větev `e94-metry` 96f2310 (E89 + E94), beze změny logiky |
| rozměry modelu V1.0 jako parametry s kontrolou mocnin 2 a dělitelnosti | `scripts/v1/rozmery.gd` | nové, podle 1.1, 1.2, 1.3, 1.4; index stejný jako `jednotky.gd` |
| verze `Vmajor.minor`, porovnání, kompatibilita, u16 (major·256 + minor) | `scripts/v1/verze.gd` | nové, podle 6.2; výchozí V1.0 |
| jedna tabulka materiálů, načtení podle id | `scripts/v1/materialy.gd`, `data/materialy_v1.csv` | kopie `docs/sjednoceni/materialy.csv` (1.6) |
| test základů | `tools/zaklad_v1.gd` | nové; otisk přes `scripts/stable_hash.gd` (main) |
| kontrola tabulky a graf | `tools/materialy_v1.py` | nové; srovnání se `sdilene/materialy_voda.json` a `horniny_voda.json` v4 |

Dnešní konstanty hry (`jednotky.gd`: segment 8 m, sloupec 32 m, `BH` 64) se nemění. Hra je zatím potřebuje a nový generátor je převezme až v dalších krocích. Proto výchozí hra zůstala bitově stejná.

## Výsledky testů
| Test | Výsledek | Kritérium | Stav |
|---|---|---|---|
| `tools/voda_e66.gd --vykopu=12` | otisk d7aedf3a6d9d10e8 → 63d7b89a91385a79, neshod s plným výpočtem 0, 63,5 s | stejný otisk, 0 neshod | prošlo |
| `tools/port_studie.py --check` | 82 souborů (79 skriptů), změněno 0 | 0 změn | prošlo |
| `tools/jednotky_e89.gd` | tam a zpět, vnoření, index: 0 chyb pro hustoty 16–128 | 0 chyb | prošlo |
| `tools/litry_e94.gd` | 79 496 řádků, 1 rozdíl proti `e94-metry` (jen `build_ms` 245,3 / 237,3 ms) | hodnoty vody stejné | prošlo |
| `tools/zaklad_v1.gd` rozměry | 9 platných kombinací (32/64/128 m × 8/16/32 m) bez chyby; 9 neplatných odmítnuto (blok 100 a 96 m, sloupec 48 m, segment 12 m, buňka 0,3 m, jemná 0,2 m, svět 3000 m, start 64 bloků, slupka 5) | všechny správně | prošlo |
| `zaklad_v1.gd` index | 524 288 jemných buněk segmentu 8 m při sloupci 128 m tam a zpět, 0 chyb, 144–174 ms; 19 bitů (1.3: 19) | 0 chyb, 19 bitů | prošlo |
| `zaklad_v1.gd` verze | 5 porovnání, 9 chybných zápisů odmítnuto, kompatibilita, u16 tam a zpět; V1.0 = u16 256 | 0 chyb | prošlo |
| `tools/materialy_v1.py` | 78 materiálů, 0 chyb (id, skupiny, rozsahy, vzorec propustnosti, X = K · 0,25 m² · 1000); 75 id shodných s vodní tabulkou v4, 0 rozdílných | 0 chyb | prošlo |
| determinismus | `zaklad_v1` ve dvou procesech: otisk cc9e412759114af1 oba | shoda | prošlo |

**Známé nálezy, beze změny (z E89):** převod l → m³ dělením a násobením se liší v posledním bitu u 133 127 z 1 000 000 náhodných a 4 z 319 skutečných průtoků (max. relativně 2,2e-16); `ug_funkce.from_cells` má výchozí objem buňky 1,0 místo 0,125. Proto platí jeden tvar převodu v `litry.gd`.

**K řešení v kroku 3 (tabulka se tam poprvé použije pro geologii):**
- id 0 má v `poradi_hornin.json` dva klíče (`cloud_line`, `map_ceiling`),
- 53 lignit a 250 voda v dutině nejsou ve vodní tabulce v4,
- 18 pásem krajiny (id 57–74) přemapovat nebo odstranit (1.7.1),
- konflikty starých seznamů z 1.6 (stejné id, jiný materiál v `mat.gd`).

**Otevřená otázka pro Jana (příloha A.1 bod 1 v 04):** buňka dat 0,5, nebo 0,25 m. Krok 1 zavádí obě velikosti jako parametry (`bunka_m` 0,5, `jemna_m` 0,25) a nic nevolí. Před krokem 6 je potřeba potvrzení.

## Obrázky a data
- `godot-prototyp/shots/krok01/materialy_propustnost.png` – log10 K a X (l/s) pro 74 materiálů s K, barvy z tabulky.
- `godot-prototyp/shots/krok01/rozmery_v1.png` – velikost segmentu a bity indexu pro všech 9 kombinací.
- `godot-prototyp/shots/krok01/zaklad_v1.json`, `zaklad_v1_beh2.json`, `materialy_v1.json`, `voda_e66.json`, `voda_e66.log`, `jednotky_e89.json`, `litry_srovnani.txt`, `port_check.txt`.

## Další krok
Krok 2 (funkce světa I) se nezačíná, čeká na Janovo schválení. Do `main` nic nejde.
