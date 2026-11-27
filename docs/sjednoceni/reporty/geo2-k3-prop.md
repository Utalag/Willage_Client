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

## Výsledky (2026-11-27 ~15:35)

Větev `geo2-k3-index` (z `geo2-k2-vzorek`): 4ec1010 PROP, 2b582d7 `KontextBloku` + předpočtené uzly plochy, 4f935eb zásobník s keší lokální vláknu,
ac08a09 přesné obálky + index po dlaždicích + `TvarE84Index`, 99065ab testy a blok `--jen=GEO2K3B`, c677b96 odmítnutí celé buňky plochy rozsahem z,
2f5298b výpis volání `Hranice`. Push neproběhl (token není k dispozici). Mimo `Geo2/` a `TestyGeo2*` se mění jen `Program.cs`; stará cesta nedotčena.

**Testy:** GEO2 158/158 (K1a + K1b + K2 + K3), celá sada 682/682, chyb 0, staré otisky beze změny.

| Kritérium | Výsledek |
|---|---|
| bitová shoda (celý blok (1024, 512) po 0,25 m, 134 M buněk) | 0 různých otisků sloupců (všech 20 B vzorku), 0 různých materiálů; shoda se starou cestou 99,771 % před i po |
| bitová shoda (test, blok 64 m po 1 m) | 0 / 4 096 sloupců; blok obsahuje skarn 11 502, pegmatit 2 954, kimberlit 1 225, sůl 11 085 buněk |
| index × `Features` | 5 druhů × 20 000 bodů: žádný zásah (SDF &lt; 0) nechybí, kandidáti jsou podposloupnost `Features` (pořadí = shody nejmenší SDF) |
| fuzz obálek | 428 000 bodů v obálkách staré cesty, 20 810 uvnitř těles, 0 mimo přesnou obálku |
| V7 | stejný otisk při 1 a 8 vláknech a v opačném pořadí sloupců |
| okraj | 3,0 m (R_max + η + uzel); 0 uzlů plochy dopočtených mimo kontext |

**V6 – odstraněná práce**
| Co | Před K3 | Po K3 |
|---|---|---|
| vyhodnocení SDF (20 000 bodů do 70 m) | žíla 2 538, čočka 341, kras 1 610, dóm 2 838, komín 2 008 (celkem 9 335) | 522 / 92 / 1 610 / 632 / 40 (celkem 2 896, −69 %; komín −98 %) |
| objem obálky proti staré cestě | 100 % | žíla 22 %, čočka 25 %, dóm 23 %, komín 1,3 %, kras 100 % |
| stavby `Features` za výpočtu | na každý sloupec a vlákno | 0 (index jednou za blok, 127 instancí v bloku 64 m + okraj) |
| uzly plochy kontaktu (blok 64 m) | 51 724–52 945 (8 keší vláken, `ConcurrentDictionary` s růstem) | 20 164 jednou, v poli |
| `GeologieCs.Klon()` + chronologie | 1 na vlákno | 0, jedna sdílená |
| `Hranice` bodového sloupce | – | 1,02 na sloupec (q′ kontaktu skoro vždy v keši) |

**Výkon** (blok (1024, 512) po 0,25 m, 8 vláken, 3 běhy po sobě; čas K3 obsahuje i otisk sloupců testu, ~9 %):
| Běh | stará cesta | GEO2 před K3 | GEO2 K3 (výpočet + kontext) | K3 / stará |
|---|---|---|---|---|
| 1 | 5,1 s | 23,4 s | 6,1 + 0,47 s | ×1,3 |
| 2 | 5,5 s | 22,7 s | 5,4 + 0,46 s | ×1,1 |
| 3 | 5,0 s | 22,1 s | 5,8 + 0,46 s | ×1,3 |

Bez odmítnutí buněk plochy (jen index + kontext): 34,6 s → 9,8 + 0,75 s. Vlákna (blok po 0,5 m): 1 vlákno 7,3 s + kontext 2,0 s, 8 vláken 1,5 s + 0,46 s (×4,9).
Zbytek GEO2 K3 (profil): ~50 % `VrstvySloupce.Hranice` staré cesty (1× na sloupec, stejná práce jako stará cesta), kontakt ~12 %, tělesa ~9 %.

**Negativní / omezení:**
- Ořez čočky obálkou staré cesty (±ra, rb může být větší) zůstává kvůli bitové shodě; oprava změní výsledek, rozhodne Jan.
- Kras má dál obálku staré cesty (deformace šumem); úspora 0 %.
- Výčet instancí bere `Features` ve středu instance a kopii tabulky mřížky útvarů (5 řádků). Kdyby se tabulka staré cesty změnila, `Sestav` hodí výjimku a test indexu selže; čistší je veřejná metoda staré cesty (změna staré cesty → jen se souhlasem Jana).
- Diagnostika `Nesparovanych` teď počítá jen vyhodnocené trojúhelníky (odmítnuté buňky ne), číslo je proto menší než v K1b; výsledky se nemění. `VolaniHranic` je mezi vlákny jen přibližný.
- Komín: kontrakt uvádí ~60 % vyhodnocení SDF; v tomto vzorku (body do 70 m) byl podíl komínu 21,5 %. Po K3 0,4 % (40 / 2 896).
- Měřeno na sdíleném boxu, kde od 12:44 běží cizí dlouhé procesy `grep` (2–3 jádra na 100 %, ~5 GB RAM). Absolutní časy jsou proto zašuměné (týká se i měření K1b a K2); poměry před/po jsou ze stejných běhů.
- Dál zrychlit jde už jen omezením práce na buňku: intervaly sloupce a kontakt v intervalech (K4), adaptivní mřížka (K5).
