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
