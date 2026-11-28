# PROP GEO2: zlevnění kontaktního pásma ve skarnovém bloku (1024, 512)

*Zapsáno před experimentem 2026-11-28 ~02:55 (Jan t1044u, bod 2). Větev `geo2-kontakt-rychle` z `geo2-vychozi`. Cíl: levnější kontaktní pásmo
BEZ změny výsledku (nebo s rozdílem v toleranci 0,125 m, zdokumentovaným); změřit před/po. Kontrakt (mez detekce t_det, h = t_det/2, ε) se nemění.*

## Výchozí stav (měřeno 2026-11-28 02:35 na boxu, zátěž cizím `grep` PID 295547 / 297041, load ~6)
- Blok 128 m od (1024, 512), sloupce 0,25 m: K3 `Sloupec` 4,2 s, K4 běhy + raster **5,2 s (×1,23)**; 49,9 `Bod` na sloupec, 11,9 běhů na sloupec.
- Profil `dotnet-trace` (inkluzivně v `SloupecGeo2.Behy`): `ZasobnikVrstvySloupce.HraniceSloupce` (GEO1 `Hranice`) 60 %, `ChronologieGeo2.Pruchod` 41 %,
  z toho `KontaktniPasmo.Plati` 34 % (`Nejblizsi` 10,6 %, zbytek hostitel okolí = `Pred` → `Povrch(x′, y′)` = `SvetFn.VyskaW` ~ 20 %).
- Zkouška (neplatný zkrat, jen měření horní meze): `Pred` s povrchem sloupce místo `Povrch(x′, y′)` → K4 3,6–3,9 s (z 5,2 s), tedy ~ 1,4 s je povrch v `Pred`.

## Návrh
1. **Přesný zkrat povrchu v `Pred`:** vrstvy sloupce jsou ořezané povrchem, takže horní hranice zásobníku v (x′, y′) je **dolní mez** povrchu
   (`min(z1, zPov) ≤ zPov`). Pokud `z ≤ horní hranice` a prefixové události nemají pravidlo hloubky, bod je jistě pod povrchem a přesný povrch se nepočítá
   (zásobník `HraniceSloupce(x′, y′)` se čte tak jako tak a je v paměti sloupců). Jinak (z nad horní hranicí zásobníku, nebo pravidlo hloubky) se povrch počítá přesně jako dnes.
   Výsledek je **bitově stejný** (jen vynechání zbytečného výpočtu).
2. Pokud zbude znatelný podíl: `Nejblizsi` (10,6 %) – rozsah plochy předem, kdy nemá smysl ptát se plochy (zkoumat až po kroku 1).

## Kritéria
| Test | Očekávání |
|---|---|
| shoda | K4 běhy + raster × dnešní: 0 rozdílů buněk (bloky (1024, 512), (3000, 2000), (0, 0)), V4 / V7 beze změny, celá sada 0 chyb, otisky GEO1 beze změny |
| výkon | blok (1024, 512): K4 běhy + raster čas před/po, medián z ≥ 3 běhů na stejném stavu boxu; počet výpočtů povrchu v `Pred` před/po |
| ostatní bloky | žádné zhoršení |

## Rizika
- Zásobník jiného druhu než `VrstvySloupce` (jiný tvar zásobníku) nemusí mít horní hranici ≤ povrch → zkrat jen přes rozhraní, které to garantuje (jen `ZasobnikVrstvySloupce`).
- Zátěž boxu cizími procesy zkresluje čas → před/po měřit střídavě, uvést zátěž.

## Výsledky *(2026-11-28 ~03:05)*
Commity: `PROP` před experimentem, přesný zkrat povrchu (`IZasobnikSDolniMezi`, `ChronologieGeo2.BodPredSPovrchemSloupce`, `KontaktniPasmo.Pred`) + otisk bloku v `GEO2K4B`.

**Shoda: bitově stejná.** Otisk celého bloku (po sloupcích, 134 217 728 buněk na blok) před a po je shodný ve 4 blocích:
(1024, 512) `CB5E93702313A0E2`, (3000, 2000) `F9696D1DFD21AC63`, (0, 0) `0F956A8A505FB87F`, (3904, 1344) `395D525F269149CE`; K3 == K4 v každém.
Celá sada **742 / 742 OK**, otisky GEO1 beze změny. Rozdíl výsledku: **0** (žádná tolerance nebyla potřeba).

**Výkon** (K4 běhy + raster, blok 128 m, sloupce 0,25 m, 8 vláken; box zatížen cizími `grep` PID 295547 / 297041, load 4–8; střídavě před / po na stejném stavu boxu):
| Blok | před (`geo2-vychozi`) | po | poměr K4 / K3 před → po |
|---|---|---|---|
| (1024, 512) skarn, 3 měření | 5,5; 5,2; 5,4 s (medián 5,4) | 3,7; 3,8; 3,2 s (medián 3,7) | ×1,24 → ×0,90 |
| (3000, 2000) | 2,4 s | 2,8 s | v šumu (load 7,7) |
| (0, 0) | 2,5 s | 2,5 s | beze změny |

Skarnový blok je o ~ 31 % rychlejší (medián 5,4 → 3,7 s) a už není pomalejší než K3 (`Sloupec` po bodech 4,1–4,4 s). Ostatní bloky beze změny (povrch v hostiteli okolí se tam skoro nevolá).
Odpovídá zkoušce horní meze (3,6–3,9 s s neplatným zkratem): zkrat zachytil prakticky celý výpočet povrchu.

**Co zbývá v pásmu** (profil před úpravou, kap. Výchozí stav): `Nejblizsi` ~ 10 % a `Plati` bez povrchu; dominuje `VrstvySloupce.Hranice` (GEO1, ~ 56 % času) – ten je společný oběma cestám (GEO1 platí totéž) a mimo rozsah tohoto bodu (GEO1 se nemění).
Negativní / neprovedeno: úprava `Nejblizsi` (rozsah plochy předem) nebyla dělána, protože cíl (skarnový blok ne pomalejší než K3) je splněn jedním zkratem.

**Rozhodnutí pro Jana:** žádné. Změna je čistě výkonová a výsledek je bitově stejný.
