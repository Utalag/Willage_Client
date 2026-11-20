# PROP – Krok 1: Základy generátoru V1.0

Větev `gen-v1-krok01-zaklady` (ze `sjednoceni` 08d82db). Podle `04-implementace-generatoru.md`, krok 1. Napsáno 2026-11-20 23:58 SEČ, před experimentem.

## Proč krok 1 jako první
Na 6.1 ani 6.3 nezávisí (ty patří do kroku 10). Všechno další používá jednotky, rozměry, verzi a id materiálů.

## Plán
1. Sloučit `e94-metry` (96f2310): `scripts/jednotky.gd`, `scripts/voda/litry.gd`, převod scény na metry. Bez úprav logiky.
2. Nový modul `scripts/v1/rozmery.gd`: rozměry modelu V1.0 jako parametry s kontrolou mocnin 2 a dělitelnosti. Dnešní konstanty v `jednotky.gd` (segment 8 m, sloupec 32 m) zůstávají, hra je zatím potřebuje.
3. Nový modul `scripts/v1/verze.gd`: `gen_ver` ve tvaru `Vmajor.minor` (čtení, porovnání, kódování do u16 pro hlavičku).
4. Nový modul `scripts/v1/materialy.gd` + kopie `data/materialy_v1.csv` z `docs/sjednoceni/materialy.csv`: načtení podle id.
5. Testy: `tools/zaklad_v1.gd` (Godot), `tools/materialy_v1.py` (Python, graf).

## Testy a kritéria
| Test | Prošlo, když |
|---|---|
| `voda_e66` 12 výkopů | otisk d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod |
| `port_studie.py --check` | 0 změn |
| `jednotky_e89.gd`, `litry_e94.gd` | 0 chyb, 0 rozdílných bitů |
| `zaklad_v1.gd` rozměry | platné kombinace projdou, neplatné odmítnuté, index tam a zpět 0 chyb |
| `zaklad_v1.gd` verze | všechna porovnání správně, chybné zápisy odmítnuté |
| `materialy_v1.py` | unikátní id 0–255, rozsahy, vzorec propustnosti; konflikty jen vypsat |
| determinismus | dva procesy dají stejný hash |

## Výsledky (2026-11-21 00:20 SEČ)
Všechny testy prošly. Podrobnosti a cesty k souborům jsou v [`krok01.md`](krok01.md).
- `voda_e66`: d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod (12 výkopů, 63,5 s).
- `port_studie --check`: 82 souborů, 0 změn.
- `jednotky_e89`: 0 chyb; známé nálezy E89 beze změny (převod l → m³ dělením a násobením se liší v 133 127 z 1 000 000 náhodných a 4 z 319 skutečných průtoků v posledním bitu; `ug_funkce.from_cells` má výchozí objem buňky 1,0).
- `litry_e94`: 79 496 řádků, jediný rozdíl proti `e94-metry` je čas stavby v ms.
- `zaklad_v1`: 0 chyb, 9 platných kombinací, 9 neplatných odmítnuto, index 524 288 buněk tam a zpět bez chyby, 19 bitů.
- `materialy_v1`: 78 materiálů, 0 chyb, 75 shodných s vodní tabulkou v4, 1 konflikt k řešení v kroku 3.
- Determinismus: otisk cc9e412759114af1 ve dvou procesech.
Negativní nález: žádný nový.
