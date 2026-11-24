# Algoritmy – detailní matematický popis (v0)

Konvence: Y nahoru, X/Z vodorovně, metry. Index událostí 0 = nejstarší.

## 1. Deterministický šum (`src/core/deterministic/noise.ts`)
```text
hashInt3(ix, iy, iz, seed) → uint32       (Math.imul + xor/rotace, finální avalanche)
s = h / 2^31 − 1  ∈ [−1, 1)
valueNoise2(x, y) = bilerp(s00, s10, s01, s11; fade(fx), fade(fy)),  fade(t) = 6t^5 − 15t^4 + 10t^3
fbm2 = Σ_o 0.5^o · valueNoise2(x f 2^o, y f 2^o, seed + 1013 o) / Σ_o 0.5^o
```
Periodicita: na periodické ose s periodou P se f nahradí \(f'=\max(1,\mathrm{round}(Pf))/P\) a lattice index se bere modulo \(Pf'2^o\). Pak `fbm2(x+P) == fbm2(x)` přesně (test 4).

## 2. Sedimentace
Vstup: \(y_s, y_e\), mocnosti \(t_i\), V, f_l, R, f_h, lokální změny \((x_m, z_m, \rho_m, f_m)\).
```text
S    = (y_e − y_s) / Σ t_i
L    = 1 + Σ f_m exp(−((x−x_m)² + (z−z_m)²) / ρ_m²)
h_0  = y_s + R·fbm(f_h, 3 okt.)
w_i  = t_i S · max(0.05, (1 + V·fbm_i(f_l, 2 okt.)) · L)
h_i  = max(h_{i−1}, h_0 + Σ_{j≤i} w_j + R·fbm'_i(f_h, 3 okt.))
classify(y) = −1 (pod) | i (h_i ≤ y < h_{i+1}) | −2 (nad)
```
```text
 y ▲   h_5 ~~~~~~~~~~~  břidlice
   │   h_4 ~~~~~~~~~~~  vápenec
   │   h_3 ~~~ ~~~~~~~  jílovec (může se vyklínit)
   │   h_2 ~~~~~~~~~~~  pískovec
   │   h_1 ~~~~~~~~~~~  slepenec
   │   h_0 ~~~~~~~~~~~  báze (yStart + šum)
   └──────────────────▶ x, z
```
Příklad (scénář A): yStart 6, yEnd 40, mocnosti 6/8/5/9/6 → S = 1, střední rozhraní 6, 12, 20, 25, 34, 40 m (± variace). Bod (10, 1, 10) → podloží (6), (10, 63, 10) → vzduch (0).
Známé problémy: max() může vytvořit nulovou mocnost (vyklínění) – záměrně; kladné lokální faktory zvětšují celkovou mocnost nad yEnd.

## 3. Vrásnění (svislý střih)
```text
k = 2π/λ (cos α, sin α)      (přichyceno k periodě na torusu)
F(x,z) = A·W(x,z)·sin(k·(x,z) + φ + I·π·fbm(x,z))
W = 1 − smoothstep(r_0, r_0 + falloff, |(x,z) − c|)   (r_0 ≤ 0 → W = 1)
g(y) = exp(γ (y − y_ref))
forward:  y' = y + F g(y)
inverse:  γ = 0 → y = y' − F   (přesně)
          γ ≠ 0 → Newton  y_{n+1} = y_n − (y_n + F g(y_n) − y') / (1 + F γ g(y_n)),
                  y_0 = y' − F g(y'), tol 1e-9 m, max 40 it., jinak bisekce na [y' − 4|F| − 64, y' + 4|F| + 64]
J = | 1        0          0      |
    | F_x g    1 + Fγg    F_z g  |
    | 0        0          1      |      det J = 1 + Fγg
```
Omezení: \(|A| \le 1.2/|k|\); γ se půlí, dokud \(|A\gamma|e^{|\gamma| \cdot span} \le 0.8\) (span = max |y − y_ref| v doméně [−32, sizeY + 32]).
Příklad: A = 3, λ = 40, α = 0: F(10, ·) = 3 sin(π/2) = 3 → bod (10, 20, 0) se posune na (10, 23, 0); inverze vrátí 20 přesně.
Proč nevzniká překrytí ve 3D: zobrazení zachovává (x, z) a je v y ostře rostoucí (det J > 0) → je to bijekce každého sloupce zvlášť, nezávisle na rovině průřezu.

## 4. Zlom
```text
s = (cos θ, 0, sin θ)                     směr (strike)
u = (sin θ cos δ, −sin δ, −cos θ cos δ)   po spádu dolů
n = (sin θ sin δ, cos δ, −cos θ sin δ)    normála (n_y ≥ 0)
d(p) = n·(p − p_0)
Δ = D_dip u + D_strike s,  normální: D_dip = D; reverzní: −D; horizontální: D_strike = D; kombinovaný: D sin(rake), D cos(rake)
forward: p' = p + Δ  pokud d(p) > 0
inverse: p  = p' − Δ pokud d(p') > 0      (n·Δ = 0 ⇒ d(p + Δ) = d(p))
drcená zóna: |d(p')| < w/2 → materiál 7
```
```text
        footwall │╲  hanging wall (d > 0) – posun po rovině
                 │ ╲
  ═══════════════│  ╲════════
                 │   ╲  ═══════  ← vrstvy posunuté o Δ
```
Příklad: θ = 90°, δ = 60°, D = 9 (normální) → Δ = (4.5, −7.79, 0).
Známé problémy: konstantní posun až do nekonečna; body na rovině (d = 0) patří podloží (footwall).

## 5. Skládání událostí – zpětný průchod
```text
walk(i, p, damage):
  for i = N−1 … 0:
    deformace:  damage |= op.damageAt(p);  p = op.inverse(p);  history[i] = p
    transformace: zapamatuj (i, p)
    materiál:   L = classify(p)
       L ≥ 0  → onlap: nejdřív walk(i−1); pokud vzduch → vrstva L.  erode: vrstva L
       L = −2 → erode: vzduch;  onlap: pokračuj
       L = −1 → walk(i−1); pokud vzduch → vrstva 0 (vyplnění prohlubně)
  konec → podloží
finish: damage ∧ ¬vzduch → brekcie; pak transformace chronologicky na jejich historických polohách
```

## 6. Voxelizace a mesh
Buňka (i, j, k) = vzorek ve \(((i+.5)r, (j+.5)r, (k+.5)r)\). Mesh: pro každou viditelnou buňku a každý ze 6 směrů se emituje quad, je-li soused neviditelný/mimo objem.

## 7. Vizualizace A (bez změny geologických algoritmů)
Řez v osách X/Y/Z přímo volá stejný evaluator; rozlišení řezu je nezávislé na objemové mřížce. Pixelový střed je `(u+0.5)/pxPerM`, `(v+0.5)/pxPerM`; svislé řezy převrací rasterovou Y, vodorovný řez má Z po směru řádků. `sectionCoordinates.ts` sdílí konvenci pro sampling, picking i umístění plochy. GPU clipping je pouze pohledové skrytí části povrchu; neomezuje geologické operace ani neřeší periodicitu. Viz `VISUALIZATION_A_RESULTS.md`.
