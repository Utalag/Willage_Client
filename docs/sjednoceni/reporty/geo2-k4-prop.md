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
*Doplněno 2026-11-27 ~17:10. Větev `geo2-k4-intervaly`, commity fe131ff … (malé, po vrstvách). Lokální testy, bez CI. Měření při cizí zátěži
(dva cizí procesy `grep` od 12:57 drží ~2 jádra a ~5 GB RAM, nejsou moje, nezabíjel jsem je) → časy berte jako ±15 %.*

**Co je hotové (kód):**
- `Primka`, `PrunikyPrimky` – průniky obecné přímky (počátek + směr) s elipsoidem, deskou, eliptickým válcem, kapslí, koulí.
- `SegmentaceSloupce`, `IIntervalyTvaru`, `IIntervalyKontaktu`, `IPlochaSRozsahem`, `Beh`, `DruhHranice` (Presna / Certifikovana / Odhad).
- `SloupecGeo2` – sloupec jako segmentace přímky: body zlomu (vrstvy, meze hloubky, konce tětiv, řezy z·4 a hranice vrstev u čočky, sopka),
  nejisté oblasti (O šumových těles, překryv sourozenců, pásmo kontaktu, tvar bez intervalů = celý sloupec), jistý kus = 1 `Bod` ve středu,
  nejistý = vzorky na světové mřížce k·h (h = t_det/2) + okraje ±ε/4, hranice půlením na ε = 2⁻¹⁰ m. Kontakt čte prefixové běhy (rekurze s `pocet`),
  statická pravidla (`PravidloCile.PovolujeStav` – vyčleněná část `Povoluje` bez hloubky a kontaktu, chování beze změny) a interval hloubky.
- E84: `TvarE84Index.Sloupec` (přesné tětivy elipsoidů oříznuté obálkou, O žíly = válec ∩ deska t₀ + amp, O krasu = kapsle max r + δ a komora
  (1 + δ/r_min)·E při `Fast`, jinak celá obálka), `TvarSopky.Sloupec` (z veřejných `Sopky.Seznam`/`Kuzel`), `ZasobnikVrstvySloupce.Sloupec`, `TvarVsude`.
- Kontakt: `KontaktniPasmo.Sloupec` – rozsah z ploch do w_max, chůze f = min(d̃, R_max) − w s L = 1 + w₀·a·3f (přeskok f/L, hluboko v pásmu
  skok |f|/L, jinak [z, z + h] nejisté); `PlochaVrstev.RozsahZ` (rozsah z buněk v dosahu ± √(r² − d²)).
- Kontakt na tělesa: `VzdalenostElipsoidu` (Eberly, robustní půlení, strop 256 iterací), `TvarE84Elipsoid : ITvarSVzdalenosti` (čočka, dóm, komín)
  s `PlochaElipsoiduE84` (min přes instance v okolí; rozsah z = tětiva elipsoidu s poloosami r_i + r ⊇ E ⊕ B_r). Žíla a kras vzdálenost nevydají
  → kontakt na ně dál odmítne `KONTAKT_CIL_BEZ_VZDALENOSTI`. Kontrolu `KONTAKT_CIL_SUM` jsem nepřidal: žádné těleso se šumem vzdálenost nevydává,
  není co kontrolovat (přidá se s prvním takovým tvarem).
- `Rasterizace.DoMrizky` (3.4), `UlozisteBehu` (float z + ushort paleta), `KontextBloku.Behy` a `KontextBloku.SloupecZBehu`.
  `KontextBloku.Sloupec` (bod po buňce) zůstává; přepnutí výchozího vzorkování na běhy je rozhodnutí pro Jana (níže).

**Testy (`--jen=GEO2K4`, v `--jen=GEO2` i v celé sadě):**
| Test | Výsledek |
|---|---|
| primitiva | 1,6·10⁶ bodů na náhodných přímkách: interval = bodový test, 0 rozdílů |
| vzdálenost k elipsoidu | 400 případů (i uvnitř): π na povrchu do 2·10⁻¹⁴, nikdy horší než 40 000 vzorků povrchu, q − π ∥ normála do 2·10⁻¹⁵ |
| závorky E84 | 10⁶ bodů na druh: těleso ⊆ O bez výjimky (žíla 23 354, čočka 174 098, kras 25 940, dóm 187 934, komín 262 361 bodů v tělese); elipsoidy V = O |
| V4 E84 | 256 náhodných sloupců bloku (1024, 512), hustý `Bod` po 1/64 m (2,1·10⁶ bodů): 0 rozdílů; 12,1 běhu a 58 `Bod` na sloupec |
| V4 šumová deska | tloušťky t_det·{0,5; 0,99; 1; 1,01; 2}, sklon 0/30/60/80°: 0 vynechaných tětiv ≥ t_det (podlimitní se většinou také najdou) |
| kontakt na těleso | syntetický natočený elipsoid + aureola s `hostitel_okoli`: V4 0 rozdílů; skarn vzniká |
| kontakt na dóm E84 | sada E84 + syntetická událost aureoly dómu (Transformuj vápence → dolomit): zkompiluje se, V4 1 rozdíl v 1 tětivě 1/64 m (podlimitní), 0 ≥ t_det |
| raster == Bod | blok 32 × 32 sloupců, 0,25 i 0,125 m: 0 rozdílů |
| V7 | stejné otisky při 1 / N vláknech a v opačném pořadí |
| regrese | celá sada OK 726, chyb 0; otisky GEO1 (golden) beze změny; K3 testy beze změny |

Jedna chyba testu po cestě (záporný výsledek): u sklonu 80° test počítal tětivy desky i mimo sloupec [0, zPov) – chyba testu, ne kódu; opraveno ořezem.

**Výkon (`--jen=GEO2K4B`, blok 128 m, sloupce po 0,5 m, z po 0,25 m, 8 vláken, druhý průchod):**
| Blok | K3 bod po buňce | K4 běhy + raster | poměr | `Bod`/sloupec K4 | Hranice/sloupec K3 → K4 |
|---|---|---|---|---|---|
| (1024, 512) | 1,4 s | 1,9 s | ×1,36 | 50 | 1,02 → 1,13 |
| (3000, 2000) | 1,7 s | 0,7 s | ×0,45 | 40 | 1,00 → 1,03 |
| (0, 0) | 1,1 s | 0,9 s | ×0,84 | 42 | 1,02 → 1,08 |
| (2048, 1024) | 1,1 s | 0,8 s | ×0,69 | 42 | 1,00 → 1,00 |
| (512, 3072) | 1,0 s | 0,7 s | ×0,68 | 41 | 1,00 → 1,00 |
Raster po 0,125 m (sloupce po 1 m): (1024, 512) ×1,07, (3000, 2000) ×0,35. Rozdíl K4 raster × K3 bod: 0 buněk ve všech blocích.
Profil (1024, 512): ~58 % času K4 je `VrstvySloupce.Hranice` staré cesty (Dictionary v `Zastupci`, totéž co v K3); zbytek hlavně vzorky pásma
skarnu po h = 1/16 m (4× hustěji než buňka 0,25 m) a jejich bod q′ kontaktu (nový sloupec → další `Hranice`). Blok (1024, 512) je skarnem nejbohatší.

**Paměť:** blok 128 m po 0,5 m: 780 000 běhů (11,9 na sloupec), paleta 613 vzorků, 4,7 MiB proti 640 MiB hustých 20 B vzorků (1 B/buňku: 32 MiB).

**Rozhodnutí pro Jana:**
1. Přepnout `KontextBloku.Sloupec` na běhy + raster jako výchozí? Výsledek je v měřených blocích stejný, typicky rychlejší (×0,45–0,84), ve skarnovém
   bloku ×1,36. Navrhuji ano (K5 na tom staví); zatím nepřepnuto – nechávám na Janovi.
2. Pásmo kontaktu se vzorkuje po h = t_det/2 = 1/16 m (kontrakt 2.8). Zrychlení bez změny kontraktu: certifikovat i `hostitel_okoli` (q′) – vyžaduje
   meze na stav q′, odkládám. Změna h by byla změna kontraktu – nedělám.
3. Vzdálenost k tělesu se měří k primitivu (bez ořezu obálkou staré cesty a bez podmínky rozsahu buněk `Features`) – podle 2.5 „k primitivu bez šumu“.
