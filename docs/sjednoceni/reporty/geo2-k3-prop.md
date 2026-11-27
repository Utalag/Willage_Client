# PROP GEO2 K3: kontext bloku, index těles, přesné obálky, bez Klon(), vlákna

*Zapsáno před prací 2026-11-27 ~15:30 (Jan t1037u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 3.5, 3.6, 2.6, kritéria V6 a V7, krok K3 v kap. 5. Větev `geo2-k3-index` z `geo2-k2-vzorek`.*

## Výchozí stav (měřeno před prací)
- Blok (1024, 512) po 0,25 m (134 M buněk, 8 vláken): stará cesta ~6 s, GEO2 K2 ~32 s (×5). Po 1 m: 1,9 s × 5,1 s.
- Profil GEO2 (1 m): kontakt `PlochaVrstev.Nejblizsi` 33 % (z toho `Uzel` = `ConcurrentDictionary` + jeho růst a volání `Hranice` v uzlech ~20 %),
  `Features` / `Make` staré cesty 9 %, hranice sloupce (`Zastupci`) zbytek. Každé vlákno má vlastní `GeologieCs.Klon()`, vlastní chronologii a vlastní
  keš uzlů (uzly se počítají až 8×).
- `TvarE84` čte `TvorbaUtvaru.Features` (keš posledního sloupce, není vláknově bezpečná) a obálku staré cesty: komín má v xy obálku max(ra, rc) místo ra (~6×).

## Cíl
1. `KontextBloku`: neměnný, postavený předem pro blok + okraj (okraj ≥ R_max + η + 1 uzel mřížky). Obsahuje chronologii, index těles po dlaždicích
   8 × 8 m (instance s obálkou přes blok, ve stejném pořadí jako `Features`), předpočítané uzly plochy kontaktu.
2. Přesné obálky (2.6): komín a dóm (osové elipsoidy) ±(ra, rb, rc), čočka AABB natočeného elipsoidu, žíla AABB disku s tloušťkou t₀ + amplituda šumu;
   kras zůstává na obálce staré cesty (deformace šumem). Obálka je průnik s obálkou staré cesty, aby se nezměnil výsledek (čočka dnes 4,8 % ořezaná – oprava je změna výsledku, ne K3).
3. Bez `Klon()`: jedna chronologie pro všechna vlákna. Tvary čtou jen kontext; pracovní paměť je lokální vláknu (keš hranic sloupce `[ThreadStatic]`), žádné zámky.
4. Vlákna: blok po sloupcích přes `Parallel.For`, sdílený kontext.
5. Stará cesta se nemění (žádný soubor mimo `Geo2/` a testy); výčet útvarů v oblasti jen přes veřejné `Features` (bez reflexe).

## Mimo K3
- intervaly `Beh` a kontakt v intervalech (K4), adaptivní mřížka (K5), oprava ořezu čočky (rozhodne Jan).

## Kritéria
| Test | Očekávání |
|---|---|
| bitová shoda | Vzorek (všech 20 B) GEO2 před K3 (Klon na vlákno) == po K3 na každé buňce bloku; shoda se starou cestou zůstane 99,771 % |
| index | kandidáti indexu v bodě = `Features(x, y)` (stejné instance, stejné pořadí) po filtru obálky staré cesty; přesná obálka nevyřadí žádný bod s SDF < 0 |
| V6 odstraněná práce | vyhodnocení SDF na buňku (po druzích, hlavně komín), stavby `Features`, výpočty uzlů a `Hranice` – před × po |
| V7 determinismus | stejný otisk bloku při 1 a 8 vláknech a v opačném pořadí sloupců |
| výkon | blok (1024, 512) po 0,25 m: GEO2 před × po × stará cesta; cíl přiblížit se staré cestě |
| regrese | celá sada 0 chyb, staré otisky beze změny |

## Rizika
- kontakt (nejbližší bod plochy v okruhu R_max pro každý karbonátový bod) zůstane drahý i s předpočtenými uzly; skutečné odstranění je K4 (intervaly);
- sdílený čítač nespárovaných trojúhelníků mezi vlákny = soupeření o cache linku → čítač lokální vláknu;
- bod mimo kontext (q′ kontaktu za okrajem) → tvar s indexem hodí výjimku, ne tichou chybu.

## Výsledky
*(doplní se po měření)*
