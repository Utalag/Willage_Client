# PROP GEO2 K4: intervaly sloupce, závorky a detekce 2.8, kontakt v intervalech, kontakt na tělesa, rasterizace, běhy

*Zapsáno před prací 2026-11-27 ~16:20 (Jan t1042u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 1.7, 2.5 (tělesa), 2.6, 2.8, 3.3, 3.4,
kritéria V4, V7, krok K4 v kap. 5. Větev `geo2-k4-intervaly` z `geo2-k3-index`. Kritérium: GEO2 lepší než GEO1 (shoda není cíl), výkon ne výrazně pod K3.*

## Návrh
1. **Závorky pro obecnou přímku** (počátek + směr, 1.7): elipsoid (čočka, dóm, komín; kvadratika, V = O, `Presna`), deska žíly
   (O = {|s| ≤ t₀ + A} ∩ válec {a² + b² ≤ 1} – odvozeno přímo z SDF žíly, těsnější než obecná tabulka 2.8; V = ∅),
   kras (kapsle s poloměrem max(r₀, r₁) + δ a komora (1 + δ/r_min)·E, δ = 2,165·A = mez rychlé větve SDF; V = ∅).
   Svislý sloupec je zvláštní případ.
2. **Sloupec = segmentace přímky** (ekvivalent 1.7 přes invariant `Sloupec.Stav(z) == Bod`):
   - přesné body zlomu: hranice vrstev zásobníku, povrch, meze `hloubka` všech událostí, konce závorek bez šumu, řezy materiálu
     těles (z po 0,25 m a hranice vrstev u `FeatMat`), slupky a průduch sopky (z veřejných dat sopky);
   - nejisté oblasti: O ∖ V těles se šumem, překryv sourozenců, pásmo kontaktu;
   - kus bez nejistoty: jeden `Bod` ve středu; nejistá oblast: vzorky na světové mřížce z_k = k·h, h = t_det/2, a půlení
     ⌈log₂(h/ε)⌉ = 6 kroků mezi vzorky s různým stavem (`Certifikovana`), body zlomu jsou `Presna`.
3. **Kontakt v intervalech:** kandidátní pásmo z rozsahu z buněk plochy v okruhu R_max; v něm se vzorky přeskakují podle meze
   L = 1 + w₀·a·3f (vzdálenost je 1-lipschitzovská, |∂N/∂z| ≤ 3f ze smoothstepu a mřížky v [−1, 1], vzorec, ne měření).
4. **Kontakt na tělesa:** elipsoidová tělesa E84 vydají `ITvarSVzdalenosti` (přesná vzdálenost k povrchu elipsoidu pevným počtem
   iterací, normála analyticky). Tělesa se šumem (žíla, kras) vzdálenost k primitivu neumí → kompilátor odmítne kontakt
   (`KONTAKT_CIL_BEZ_VZDALENOSTI`); obecně platí mez šumu δ_S ≤ e_k (`KONTAKT_CIL_SUM`).
5. **Rasterizace (3.4):** buňka = běh přes střed; |zc − hranice| ≤ ε → `Bod`. Libovolná výška buňky (0,25 i 0,125 m).
6. **Ukládání po bězích (3.3):** blok = sloupce běhů, z začátku běhu (float) + index do palety vzorků (ushort); změřit bajty.

## Kritéria
| Test | Očekávání |
|---|---|
| závorka | ≥ 10⁶ bodů: V ⊆ těleso ⊆ O bez výjimky (všechny druhy E84) |
| V4 skutečné sloupce | proti hustému `Bod` po 1/64 m: 0 vynechaných tětiv ≥ t_det, konce do ε + 1/64; podlimitní vykázat zvlášť |
| V4 syntetika | deska se šumem tloušťky t_det·{0,5; 0,99; 1; 1,01; 2}, sklon 0–89°: 0 vynechaných tětiv ≥ t_det |
| raster == Bod | ve středech buněk 0,25 i 0,125 m, rozdíly jen v podlimitních tětivách (vykázat) |
| kontakt na tělesa | syntetický kontakt na dóm: pásmo kolem tělesa, sloupec == Bod |
| V7 | stejný otisk běhů při 1 / N vláknech a v opačném pořadí |
| výkon | blok (1024, 512): intervaly + raster 0,25 m proti K3 (bod po buňce); raster 0,125 m |
| paměť | bajty bloku po bězích proti 1 B/buňku a 20 B/buňku |
| regrese | celá sada 0 chyb, otisky GEO1 beze změny |

## Rizika
- vzorkování pásma kontaktu po 1/16 m může být dražší než bod po 0,25 m (měří se);
- sopka: body zlomu z veřejných dat sopky musí sedět s `NitroSopky.Mat` (V4 to ověří);
- sourozenci `nejmensi_sdf` (parita E84): vítěz se může měnit uvnitř tětivy, vzorkuje se, podlimitní změny smí zaniknout.

## Výsledky
*(doplní se po měření)*
