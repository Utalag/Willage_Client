# Jak generujeme geologické vrstvy (V1.0, krok 3)

Zdroj: větev `gen-v1-krok03-geologie` (d571153), soubory `scripts/v1/geo_vrstvy.gd`, `scripts/v1/utvary.gd`, `scripts/v1/svet_fn.gd`. Stav: krok 3 hotový, čeká na schválení Jana. Všechno je čistá funkce světových souřadnic v metrech (x, y, z), bez mřížky sousedů, takže výsledek přes švy bloků sedí a je deterministický (stejný seed → stejné bity).

## Pořadí výpočtu v bodě `bod(x, y, z)`

1. Povrch `z_pov = vyska_w(x, y, detaily=true)`. Když `z > z_pov`, je to vzduch (0).
2. Sopka: když bod leží v tělese sopky, vrátí průduch nebo slupku (viz kapitola 6).
3. Vrstvy: `hranice(x, y)` dá seznam vrstev zdola nahoru, z něj materiál ve výšce z.
4. Útvary (žíla, čočka, dóm, komín, kras, skarn): když je bod uvnitř útvaru, materiál útvaru přepíše vrstvu.

## 1. Mapa hornin (krok 2, vstup pro vrstvy)

Svět je pokrytý mřížkou středů hornin s roztečí `hS = 192 m`. Střed buňky (i, j) je posunutý náhodně v rozsahu 15–85 % buňky:

$$x_{ij} = (i + 0{,}15 + 0{,}7\,u)\,h_S,\quad y_{ij} = (j + 0{,}15 + 0{,}7\,u')\,h_S$$

Každý střed má pro každý biom koncentrace hornin `c_m = u_m² / Σ u²` (u je hash ze seedu).

V bodě se vezme okolí 5 × 5 středů, d_min je vzdálenost k nejbližšímu a přechod `hB = 160 m`:

$$q_n = \max\!\left(0,\ 1 - \frac{d_n - d_{min}}{h_B}\right),\qquad w_n = q_n^2$$

$$\text{konc}(id) = \sum_n \sum_t w_t^{biom}\,\frac{w_n}{\sum w}\,c_{n,t,id}$$

Výsledek je seznam `[id, podíl]` seřazený sestupně.

## 2. Pásma (1.7.1)

Výška sloupce `H = max(vyska_tvar(x, y), 0,25)`. `vyska_tvar` je tvar terénu bez drobného detailu, takže vrstvy sledují reliéf. Sloupec od z = 0 po H se dělí na 4 pásma podle úrovní katalogu `poradi_hornin.json` (0–40):

| Pásmo | Úrovně | Podíl výšky |
|---|---|---|
| spodek | 0–12 | 0,32 |
| krystalinikum | 13–25 | 0,35 |
| sedimenty | 26–36 | 0,25 |
| svrchní | 37–40 | 0,08 |

$$H_{pasmo} = H \cdot \frac{podil}{\sum podil}$$

Vrstvou jsou jen druhy `layer`, `soil` a `seam`. Druhy pipe, vein, dome a contact jdou do útvarů.

## 3. Zástupci pásma (1–3 horniny)

Pro každou horninu pásma se spočítá váha.

Přítomnost a mocnost ze seedu, jde o pomalé pole s buňkou 180 m a bilineární interpolací se smoothstepem:

$$pres = \text{smoothstep}(1 - f - 0{,}12,\ 1 - f + 0{,}12,\ n_{pres}(x,y))$$
$$t = \text{lerp}(t_0, t_1, n_{thick}(x,y))$$
$$v_{id} = \max(t \cdot pres, 0)$$

kde `f` je četnost (`freq`) a `[t0, t1]` je rozsah mocnosti z katalogu.

K tomu se přičte mapa hornin z kroku 2: `v_id += 2 · konc(id)`.

Kontrast z klimatického presetu je `v' = v^k`. Výchozí klima `mirne` má k = 1, takže se nic nemění.

Pak se váhy normalizují, vezmou se nejvýš 3 nejsilnější (`zastupcu = 3`), zahodí se ty s podílem pod 0,06 (vyklínění) a zbytek se znovu normalizuje na součet 1. Když nezbude nic, vezme se první aktivní vrstva pásma.

## 4. Mocnosti vrstev

$$th = H_{pasmo} \cdot podil_{zastupce}$$

- Když `th < 0,125 m` (polovina minima), vrstva v tomto místě vyklíní.
- Jinak se ořízne: `th = clamp(th, 0,25 m, H/4)`.

Dorovnání na výšku sloupce:
- Když je součet menší než H, rozdíl dostane spodní vrstva.
- Když je větší, ubírá se odshora, ale žádná vrstva nejde pod 0,25 m.

Pak se tenké vrstvy (pod 0,25 m) sloučí se silnějším sousedem. Definice tak má vždy aspoň jednu buňku.

## 5. Mince E82 (vápenec k hladině)

Mince se hází po světovém bloku 128 m:

$$ano \iff \frac{\text{hash}(seed,\ bx \cdot 7919 + by)\ \&\ \text{0xFFFF}}{65536} < 0{,}5$$

Když padne „ano“:
- cíl je `z_cil = vyska_tvar − 2 m` (odhad hladiny podle E82, skutečná hladina přijde až v kroku 4);
- nejvyšší vrstva vápence nebo dolomitu (id 5, 44, 49) se zvětší až k `z_cil`, a mocnost na to se bere z vrstev nad ní (bez zbytků pod 0,25 m), takže součet zůstane H;
- jíl (4, 12, 51) a nepropustné vrstvy (propustnost 0) nad vápencem vyklíní a jejich mocnost dostane nejbližší propustná vrstva nad nimi, jinak vápenec;
- znovu se sloučí tenké vrstvy.

Test: 521 z 1024 bloků „ano“ = 0,509, tedy v toleranci.

## 6. Z mocností souřadnice a ořez povrchem

Vrstvy se skládají od z = 0: `z0 = Σ předchozích`, `z1 = z0 + th`. Nahoře se ořízne skutečným povrchem (s detailem): `z1' = min(z1, z_pov)`. Vrstva, která tím zmizí, se vynechá. Zbytky po ořezu můžou být tenčí než 0,25 m: test našel 8 takových (0,246–0,250 m).

## 7. Vnitřek sopky (1.14)

Profil kužele (H výška, R poloměr, rc poloměr kráteru, d hloubka kráteru, γ tvar):

$$kuz(r) = \begin{cases} H\left(\frac{R - r}{R - r_c}\right)^{\gamma} & r_c \le r < R \\ H - d\,(1 - (r/r_c)^2) & r < r_c \end{cases}$$

Povrch kužele je `z_k = h_okoli + kuz(r)`.

- Průduch (id 75): `r < max(2 m, 0,35 · rc)` a `z ≤ h_okoli + H − d`, takže vede až do z = 0.
- Slupky: `k = floor((z_k − z) / 5 m)`. Sudé k je láva (zatím id 7, diabaz), liché popel (zatím id 57).
- Vrstvy pod tělesem sopky nepokračují.

## 8. Útvary jako SDF (E84)

Každý druh má vlastní světovou mřížku (rozteč G, četnost p, dosah R):

| Druh | G | p | R | Materiál |
|---|---|---|---|---|
| žíla | 10 m | 0,7 | 7 m | pegmatit 38, občas minerál 8/9 (8 %) |
| čočka/peň | 12 m | 0,6 | 4,5 m | pegmatit 38 |
| kras | 14 m | 0,8 | 22 m | vzduch (dutina) |
| dóm | 16 m | 0,35 | 8 m | sůl 47 |
| komín | 20 m | 0,25 | 10 m | kimberlit 21 |

V buňce (gi, gj) útvar existuje, když `u(hash(seed, druh, gi·7919 + gj)) < p`. Střed je `(gi + u1)·G, (gj + u2)·G`. Hloubka středu je podíl `vyska_tvar` ve středu, například u žíly `cz = clamp(zs · (0,35 + 0,30·u), 4, zs − 2)`. Bod se dívá jen do buněk, jejichž obálka ho může zasáhnout, takže výsledek je stejný z obou stran švu.

Vzdálenostní funkce (záporná = uvnitř):
- **Žíla** je deska s normálou n a tloušťkou t0 (0,15–0,40 m), tvar elipsy a × b, okraj zvlněný 3D šumem: `|s + 0,35·noise| − tail`, kde `s = q·n`.
- **Čočka, dóm, komín** jsou elipsoid s poloosami (ra, rb, rc), přibližná SDF: `k0(k0 − 1)/k1`, kde `k0 = |q/r|` a `k1 = |q/r²|`. Komín je úzký svislý elipsoid od z = 0.
- **Kras** je řetěz 6 uzlů (krok 3 m, náhodně se stáčí), mezi nimi kapsle s poloměrem 0,5–1,1 m plus jedna komora (elipsoid 2,2 × 1,8 × 1,2 m). Prostor je deformovaný šumem o amplitudě 0,25 m. Kras se vyhloubí jen ve vápenci nebo dolomitu (5, 44, 49) a aspoň 2 m pod povrchem.
- **Skarn** (42) je pás ±1,5 m (zvlněný šumem) kolem rozhraní granitoidu (6, 36, 37) s jinou horninou, a to jen na straně mimo granitoid.

Pořadí: skarn, pak útvary. Vyhraje nejzápornější SDF (bod nejhlouběji uvnitř).

## 9. Ověřeno testy (krok 3)

- 0 neshod na švu bloků i segmentů (vrstvy i útvary).
- 0 vrstev pod 0,25 m v definici.
- Determinismus: hash `59e4569309aa8500` ze dvou procesů (4,7 mil. buněk).
- Čas: segment 8 m při 0,25 m a výšce 128 m trvá 2614 ms. To je pomalé (E84 mělo 89 ms při 0,5 m / 32 m), zrychlení přijde později.

## Otevřené (rozhoduje Jan)

1. Má mince po kroku 4 brát skutečnou hladinu místo `vyska_tvar − 2 m`?
2. Má láva a popel dostat vlastní id místo 7 a 57?
3. Mají se pásma krajiny 57–74 z tabulky smazat, nebo jen nepoužívat?
