# PROP GEO2 K1b: kontaktní pásmo 2.5 a napojení na tvary E84 a VrstvySloupce

*Zapsáno před prací 2026-11-27 ~13:05 (Jan t1035u). Kontrakt: `docs/sjednoceni/06-geologie-geo2.md` (v3), navazuje na K1a (`geo2-k1-prop.md`). Větev `geo2-k1b-kontakt` z `geo2-k1-chronologie`.*

## Cíl
1. Skutečné kontaktní pásmo podle 2.5 místo zástupného `KONTAKT_K1B`:
   - w(q) = w₀ · (1 + a · N(f·q)), N = `VNoise` se seedem události; v pásmu ⇔ d̃(q) ≤ w(q), strana sedí a `hostitel_okoli` platí;
   - R_max = w₀(1 + a) + e_k (`tolerancKontaktu_m`) jako dosah hledání;
   - členství v cíli T ze stavu bodu těsně před událostí (původ ve vrstvě z `cil.vrstvy`, nebo `GeoUdalost` ∈ `cil.udalosti`);
   - π(q) = nejbližší bod plochy S, q′ = π(q) + η·u, stav v q′ prefixem (události starší než kontakt), musí být `Pevne` a materiál z `hostitel_okoli`;
   - skarn jen v karbonátech (`nahrazuje` = vápence / dolomit, O1).
2. Plocha S obecně v `Geo2` (bez závislosti na staré cestě):
   - vrstvy: výšková plocha cílových intervalů z mřížky hranic, buňka = 2 trojúhelníky s pevnou úhlopříčkou, přesná vzdálenost bod–trojúhelník;
   - tělesa: tvar, který umí nejbližší bod primitivu bez šumu (`ITvarSVzdalenosti`); jinak validace `KONTAKT_CIL_BEZ_VZDALENOSTI`;
   - validace τ ≤ e_k (`KONTAKT_TAU`).
3. Adaptéry na starou cestu jen čtením (stará cesta se nemění): zásobník z `VrstvySloupce.Hranice`, tvary E84 (`Utvary.Sdf`, `TvorbaUtvaru.Features`, `FeatMat`), nitro sopky (`NitroSopky.Mat`), povrch ze `SvetFn`.
4. Sada událostí „E84 v GEO2“ (pořadí 2.7) z dat hostitelů `utvary_hostitele.json`.
5. Srovnání GEO2 × stará cesta na skutečném bloku 128 × 128 m (sloupce po 1 m, z po 0,25 m) a orientační výkon.

## Mimo K1b
- adaptivní mřížka hranic 1 / 0,5 / 0,25 m s kontrolním bodem (6.3): K1b má pevný krok mřížky jako parametr;
- přesná vzdálenost k E84 tělesům (elipsoid iteracemi, deska, kapsle): kontakt na tělesa E84 jako cíl validace odmítne;
- index těles a kontext bloku (K3), intervaly a závorky (K4), plný vzorek (K2).

## Kritéria
| Test | Očekávání |
|---|---|
| rovina | vodorovná i šikmá hranice granit / vápenec: d̃ = přesná eukleidovská vzdálenost (chyba < 1e-9), pásmo podle d, ne svisle |
| modulace | a > 0: d ≤ w₀(1−a) vždy v pásmu, d > w₀(1+a) nikdy; w se mění s polohou |
| strana | `vne` mění jen vápenec vně, `uvnitr` jen cíl, `obe` obojí |
| hostitel_okoli | granit změněný starší transformací nebo dutina na kontaktu → žádný skarn; mladší událost kontakt neovlivní (prefix) |
| tělesa | koule jako cíl `cil.udalosti`: pásmo kolem koule podle eukleidovské vzdálenosti |
| chyba d̃ | na skutečných hranicích VrstvySloupce: max a 99. percentil |d̃(krok g) − d̃(jemná reference)|, cíl ≤ e_k = 0,125 m |
| adaptéry | jen zásobník = stará cesta „jen vrstvy“ bitově; zásobník + sopka = stará cesta bez útvarů |
| srovnání | shoda materiálu bloku po třídách; rozdíly vysvětlené (skarn eukleidovsky a jen v karbonátech, pořadí místo nejmenšího SDF) |
| regrese | celá sada 0 chyb, staré otisky beze změny |

## Rizika
- Vyklínění vrstvy (jiný počet cílových intervalů v rozích buňky): trojúhelníky nejde spárovat; náhrada vzdáleností k vrcholům, chyba až ~g/√2. Změří se.
- Výkon: kontakt čte desítky sloupců kolem bodu; bez indexu bloku (K3) bude GEO2 pomalejší než stará cesta.
- `VrstvySloupce` / `TvorbaUtvaru` nejsou vláknově bezpečné: chronologie s adaptéry jedna na vlákno (jako `GeologieCs.Klon`).

## Výsledky
*(doplní se po měření)*
