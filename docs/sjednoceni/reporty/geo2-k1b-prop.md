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

## Výsledky (2026-11-27 13:15)

**Hotovo** (nové soubory v `cs/Willage.Gen/Geo2/`, stará cesta beze změny – mimo GEO2 se změnil jen `Program.cs` testů):
- `KontaktniPasmo.cs`: pásmo 2.5 (w = w₀(1 + a·N(f·q)), R_max = w₀(1 + a) + e_k, strana ze stavu před událostí, π, q′ = π + η·u, u normálou na ploše, `hostitel_okoli` prefixem);
- `PlochaVrstev.cs` + `Geometrie3.cs`: výšková plocha cílových vrstev, 2 trojúhelníky na buňku, přesná vzdálenost bod–trojúhelník, dno světa vynechané, paměť uzlů (vláknově bezpečná);
- `Tvary.cs`: `ITvarZasobnikuSHranicemi`, `IPlochaKontaktu`, `ITvarSVzdalenosti`; kontakt čte prefix přes chronologii; továrna dodává povrch a seed;
- kompilátor: zástupný `KONTAKT_K1B` odstraněn, nová validace `KONTAKT_TAU`, `KONTAKT_VRSTVY_BEZ_HRANIC`, `KONTAKT_CIL_BEZ_VZDALENOSTI`, `KONTAKT_BEZ_PLOCHY`;
- `E84/`: `ZasobnikVrstvySloupce`, `TvarE84` (žíla, čočka, kras, dóm, komín), `TvarSopky`, `TovarnaE84`, `SadaE84` (8 událostí v pořadí 2.7 z `utvary_hostitele.json`, skarn jen v karbonátech).

**Testy** (lokálně): `--jen=GEO2` **111 OK, 0 chyb** (K1a 74 + K1b 37). Celá sada **635 OK, 0 chyb** (2 min 42 s), zlaté otisky staré cesty (krok 5, G-1, G-3) beze změny. Kontrola citlivosti: vypnutá podmínka `hostitel_okoli` → 3 testy selžou.

| Kritérium | Výsledek |
|---|---|
| rovina | ✔ vodorovná i šikmá: |d̃ − d| < 1e-9; svisle 1,6 m / kolmo 1,40 m = skarn |
| modulace | ✔ d ≤ 0,75 m vždy, d > 2,25 m nikdy, mezi tím přesně d ≤ w(q); w ∈ [0,75; 2,25] m |
| strana | ✔ vne / uvnitr / obe |
| hostitel_okoli | ✔ starší přeměna granitu i dutina na kontaktu skarn zruší; mladší přeměna ne (prefix) |
| tělesa | ✔ koule jako cíl, sjednocení koule + vrstvy (rozhoduje nejbližší) |
| chyba d̃ (150 bodů do 2 m od skutečné hranice granitoidu, reference g = 0,125 m) | g = 1 m: p99 0,027, max 0,243 m ✘; **g = 0,5 m: p99 0,000, max 0,063 m ✔**; g = 0,25 m: max 0,034 m ✔. Výchozí krok 0,5 m |
| adaptéry | ✔ jen zásobník = stará „jen vrstvy“ bitově (3 072/3 072 buněk); zásobník + sopka = stará skladba (12 800/12 800) |
| regrese | ✔ 635/635 |

**Srovnání bloku 128 × 128 m** (`--jen=GEO2B`, výchozí svět, 8 vláken, mřížka hranic 0,5 m):

| Blok | Rozlišení | Shoda materiálu | Stará cesta | GEO2 | Skarn stará → GEO2 |
|---|---|---|---|---|---|
| (0, 0) | sloupce 1 m × z 0,25 m (8,4 mil. buněk) | 99,847 % | 1,6 s | 3,4 s (×2,1) | 14 223 → 1 892 |
| (1024, 512) | 1 m × 0,25 m | 99,771 % | 1,5 s | 4,5 s (×3,0) | 45 973 → 29 947 |
| (1024, 512) | **0,25 m × 0,25 m (134 mil. buněk)** | **99,771 %** | **6,1 s** | **27,0 s (×4,4)** | 736 483 → 479 671 |

Rozdíly jsou vysvětlené rozhodnutími kontraktu, ne chybou:
- skarn → amfibolit / svor (281 tis. buněk na plném bloku): stará cesta dělá skarn i v amfibolitu a svoru, GEO2 jen v karbonátech (O1);
- sůl → skarn (16 tis.), dutina → skarn (6,6 tis.): skarn je starší (20) než dóm (50) a kras (70) a ty ho nemají v `nahrazuje` / mají `transformace: false`; stará cesta brala nejmenší SDF;
- vápenec → skarn (2 tis.): GEO2 měří kolmo k ploše, stará cesta svisle (eukleidovská vzdálenost je kratší → pásmo je o kus širší na šikmých hranicích);
- skarn → kimberlit / pegmatit (stovky): komín a žíly jsou mladší a skarn mají v `nahrazuje` (komín `*`).
- Mřížka 1 m / 0,25 m mění skarn v bloku (0, 0) jen o ±2 % (1 860 / 1 892 / 1 904).

**Negativa / co chybí:**
- výkon: GEO2 je 2–4,4× pomalejší než stará cesta (bez indexu těles a kontextu bloku, každý bod prochází všechny události; kontakt čte ~100 trojúhelníků). Index bloku je K3;
- vyklínění vrstev: trojúhelníky s různým počtem cílových intervalů v rozích se měří k vrcholům (13 mil. takových testů v plném bloku); chyba se v měření schovává do max 0,063 m při g = 0,5 m, ale není zaručená ≤ e_k – zaručí ji až adaptivní mřížka s kontrolním bodem (6.3, K5);
- pevný krok mřížky hranic (0,5 m) místo adaptivní 1 / 0,5 / 0,25 m;
- kontakt na tělesa E84 jako cíl (`cil.udalosti` s elipsoidem / deskou / kapslí) validace odmítne (`KONTAKT_CIL_BEZ_VZDALENOSTI`): vzdálenost k primitivům E84 je K4;
- tělesa E84 používají paritní `nejmensi_sdf` a hostitele čtou z materiálu v bodě; minerály v žíle dál podle vrstvy (FeatMat);
- push neproveden (token není k dispozici), do main nic.

