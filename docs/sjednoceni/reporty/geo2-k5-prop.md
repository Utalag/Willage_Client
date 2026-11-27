# PROP GEO2 K5: adaptivní mřížka hranic (6.3) místo pevné 0,5 m

*Zapsáno před prací 2026-11-27 ~16:50 (Jan t1042u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 2.5 (plocha vrstev, τ ≤ e_k), 6.3, V5,
krok K5 v kap. 5. Větev `geo2-k5-mrizka` z `geo2-k4-intervaly`. Kritérium: GEO2 lepší než GEO1, výkon ne výrazně pod K3/K4.*

## Návrh
1. **Kořeny 1 m na světové mřížce, dělení 0,5 → 0,25 m (quadtree).** Uzly mřížky (sloučené cílové intervaly zásobníku) na mřížce 1/8 m,
   počítají se jen ty, které dělení potřebuje.
2. **Přijetí buňky:** rohy mají stejný počet cílových intervalů a v kontrolních bodech – střed (na úhlopříčce 00–11 trojúhelníků) a středy
   4 hran – mají přesné intervaly stejný počet a |interpolace − přesně| ≤ τ (`tau_m`, výchozí 0,125). Jinak dělit. Buňka 0,25 m, která
   nevyhoví, zůstane s příznakem odhadu (`BodPlochy.Odhad` → `HraniceOdhad` u kontaktu).
3. **Švy:** rozhodnutí kořene závisí jen na uzlech světové mřížky → stejné v každém bloku (bitově).
4. **Volba v datech:** `tvar.mrizka` zásobníku `adaptivni` (výchozí, příklad kontraktu) / `pevna` (0,5 m); `MoznostiKompilace.KrokMrizkyHranicM`
   = vynucená pevná mřížka (testy K1b/K3, srovnání). Neznámá hodnota = chyba `MRIZKA_NEZNAMA`.
5. **Sdílený kód:** trojúhelníky, vzdálenost, rozsah z a intervaly uzlu jsou jeden kód (`HledaniPlochy`) pro pevnou i adaptivní mřížku;
   pevná dává stejný výsledek jako dosud.
6. Okraj kontextu: + velikost největší buňky (1 m) místo kroku 0,5 m.

## Kritéria
| Test | Očekávání |
|---|---|
| V5 | proti přesnému `Hranice` po 0,25 m (sloupce na mřížce 0,25 m i mimo ni): sled cílových vrstev 0 neshod mimo buňky s odhadem, max \|Δz\| ≤ τ ve sloupcích na mřížce; vykázat p99 a max, zvlášť strmé svahy > 20° a rychlé změny mocnosti; počet buněk s odhadem |
| srovnání | chyba hranic pevné 0,5 m × adaptivní (p99, max) – adaptivní musí být lepší |
| švy | listy kořene spočtené ve dvou různých blocích (kontext) bitově stejné; V7 otisk bloku 1 / N vláken |
| kontakt | V4 bloku E84 s adaptivní mřížkou: 0 vynechaných tětiv ≥ t_det; skarn × pevná mřížka po kategoriích |
| výkon | kontext (uzly) a blok K4 s adaptivní × pevnou 0,5 m |
| regrese | celá sada 0 chyb, otisky GEO1 beze změny |

## Rizika
- kontrolní body jen ve středu a středech hran: mezi nimi může chyba τ překročit (měří V5 na mřížce 0,25 m i mimo);
- víc uzlů v členitých místech → dražší kontext (měří se).

## Výsledky
*(doplní se po měření)*
