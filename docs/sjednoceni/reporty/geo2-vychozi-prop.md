# PROP GEO2: výchozí volby po K4–K6 (Jan t1043u)

*Zapsáno 2026-11-27 ~17:40, před commitem změn. Větev `geo2-vychozi` z `geo2-k6-modifikatory`.*

## Rozhodnutí Jana (t1043u)
1. Zaručená adaptivní mřížka (úplná kontrola 0,25 m) zůstává výchozí – dražší kontext je přijatelný, jde jen o generování.
2. Buňky 0,25 m, kde vrstva vykliňuje uvnitř buňky (`HraniceOdhad`), jsou uznaná výjimka V5 → zapsat do kontraktu
   (`docs/sjednoceni/06-geologie-geo2.md` na `geo2-kontrakt-docs`, `studie-hybridni-geologie/KONTRAKT-GEO2.md`) a do PROP K5.
3. `KontextBloku.Sloupec` = mřížka z běhů K4 jako výchozí.

## Návrh
- `KontextBloku.Sloupec` = dosavadní `SloupecZBehu` (běhy + rasterizace, u hranice ±ε rozhodne Bod); K3 cesta zůstane jako
  `SloupecPoBodech` (reference, srovnání K3 a V4). Jméno `SloupecZBehu` zmizí (žádní uživatelé mimo testy).
- Testy K3 (shoda s cestou před K3) dál volají K3 cestu; K4/K5 testy a bench volají výchozí.

## Kritéria
| Test | Očekávání |
|---|---|
| GEO2 testy | 0 chyb; V4 výchozí × `SloupecPoBodech` 0 rozdílů mimo tětivy < t_det; V7 otisk výchozího 1 / N vláken stejný |
| regrese | celá sada 0 chyb, otisky GEO1 beze změny |
| výkon | blok 128 m: výchozí (běhy) × K3 cesta; kontext pevná × zaručená adaptivní; uvést zátěž boxu cizími procesy |

## Výsledky *(2026-11-27 ~17:50)*
Commity: `39e154e` PROP, `6810fbe` `Sloupec` z běhů výchozí (K3 cesta = `SloupecPoBodech`), `dcaee12` PROP K5 – rozhodnutí;
kontrakt `c86c978` na `geo2-kontrakt-docs` (V5 výjimka, 6.3 výchozí volby) + `KONTRAKT-GEO2.md` ve studii.

| Test | Výsledek |
|---|---|
| GEO2 (`--jen=GEO2`) | 218 / 218 OK (V4 výchozí × K3 cesta, V7, V5 s výjimkou vykázanou zvlášť) |
| celá sada | **742 / 742 OK**, otisky GEO1 beze změny (krok 5, G-1, G-3) |

**Výkon** (box zatížen cizími procesy `grep` – 2 jádra na 100 %, ~5 GB, load 8,8 na 8 jádrech; časy jsou orientační):

| Blok 128 m, sloupce 0,25 m (pevná 0,5 m) | K3 cesta | výchozí (běhy + raster) | poměr |
|---|---|---|---|
| (1024, 512) skarn | 4,6 s | 5,6 s | ×1,21 |
| (3000, 2000) | 5,1 s | 2,6 s | ×0,51 |
| (0, 0) | 3,6 s | 2,5 s | ×0,70 |

Raster ≠ Bod 0 buněk ve všech třech blocích; uložení běhů 18–20 MiB proti 2560 MiB hustých vzorků; Bod na sloupec 40–50 (K3 512).

| Kontext (blok 128 m, sloupce 0,5 m) | pevná | zaručená adaptivní (výchozí) | rychlá |
|---|---|---|---|
| (1024, 512) kontext / celkem | 0,40 / 2,22 s | 1,77 / 3,59 s | 0,58 / 2,47 s |
| (3000, 2000) kontext / celkem | 0,43 / 1,15 s | 1,59 / 2,31 s | 0,58 / 1,31 s |

Odhad celku výchozích voleb proti K3 (kontext + sloupce 0,25 m): skarnový blok ~7,4 s × 5,1 s (×1,45), ostatní ×0,6–0,75.
Dražší je skarnový blok (pásmo kontaktu po t_det/2 + zaručená mřížka); Jan přijal (jde jen o generování).
