# PROP – Krok 6c: nepravidelné kontinenty z periodické masky, konfigurace „vše zapnuto“

Větev `gen-v1-krok06c-kontinenty` z `gen-v1-krok06b-more-sklon` (df4673d). Napsáno 2026-11-26 10:28 SEČ, před kódem. Bez merge do main.
Zadání: Jan 10:25 (t932u): kontinent nepravidelný, může jich být víc; doporučení k otázkám 6b platí jako návrh.

## Cíl
1. Obdélníkový kontinent 6b nahradit **maskou pevniny** na torusu: periodický nízkofrekvenční šum + domain warp; moře = maska pod prahem, práh z histogramu podle cílového podílu moře (30 % ± 5 p. b. ze seedu).
2. Parametry: **počet kontinentů** (výchozí 2–4 podle seedu) a **členitost pobřeží**; ostrovy vzniknou samy.
3. Podmínky: šev torusu s pásem prolnutí (512 m) celý v moři; start 3 × 3 na pevnině a beze změny povrchu; mírný sklon od pobřeží (jako 6b). Všechny parametry v `more_v1.json` a v klíči keše.
4. Konfigurace **„vše zapnuto“** (moře, sklon, pánve 4 × 1500 m × 15 m, eroze, vodníci) jako jeden přepínač, výchozí vypnuto; uvést nové otisky.

## Metoda
- **Periodický šum bez švu:** součet vln `cos(2π(kx·x/Px + ky·y/Py) + φ)` s celými kx, ky (přesně periodické na torusu), směry, fáze a amplitudy ze seedu (hash). Vlnová délka od ~8 km do ~0,5 km, amplituda ∝ λ^β; β (členitost) a počet vln jsou parametry. FastNoiseLite periodický není, proto vlastní Fourierův šum.
- **Maska:** `m(p) = Σ_i g_i(w(p)) + C·F(p)`, kde g_i jsou hladké „hroudy“ kontinentů (Gauss v periodické vzdálenosti, středy a velikosti ze seedu, počet N = 2–4 ze seedu), F je periodický šum (členitost), w(p) = p + A_w·(Fx, Fy) periodický domain warp.
- **Šev:** v pásu švu (x mod Px < 512 m, y mod Py < 512 m) a přechodu za ním se od masky odečte velká penalizace → vždy moře. Středy kontinentů se kladou mimo šev.
- **Start:** první kontinent má střed u startu; k masce se přičte hladké „zvednutí startu“ (kruh kolem startu), jehož síla se ze seedu dopočítá tak, aby celý start 3 × 3 ležel nad prahem + přechodem (k = 1).
- **Práh:** histogram masky na mřížce (128 m) → kvantil = cílový podíl moře. Moře = maska pod prahem (k < 0,5).
- **Výška:** pevnina `h + sklon`, moře plynule k dnu `hladina − H` (k = smoothstep přechodu v jednotkách masky). Při k = 1 a nulovém sklonu se povrch nemění (start beze změny).
- **Sklon od pobřeží:** vzdálenost k moři z hrubé mřížky (64 m, Dijkstra 8-sousedů na torusu, bilineárně), `S·max(0, D − D0)`, kde D0 = max(parametr, největší vzdálenost ve startu) → start má sklon 0.
- **Pánve:** středy jen na pevnině dál než R + přechod od moře.
- **Kontinenty a ostrovy:** souvislé oblasti pevniny v mapě eroze (4-sousedství, periodicky); kontinent = plocha ≥ 50 km² (jen pro měření), menší = ostrov.
- **Vše zapnuto:** `ParametrySveta.VseKrok06` (zapne moře + pánve) + `KonfiguraceSveta.Sestav` (mapa eroze z keše, eroze do světa, vodníci do pramenů).

## Hypotézy
- H1: Skutečný podíl moře sedí s cílem do ±1 p. b. (v 6b −1,5 až −2 p. b.).
- H2: 2–4 kontinenty nepravidelného tvaru + desítky ostrovů; řeky max > 10 km.
- H3: Start beze změny (otisky krok 3 a voda 14,14) se zapnutým mořem pro všechny seedy; šev v moři.
- H4: Čas mapy 32 m < 10 s, paměť < 300 MB, determinismus 1 = N vláken, 2 procesy.

## Měření
Podíl moře cíl/skutečný pro 8+ seedů, počet kontinentů a ostrovů (plochy), řeky, povodí, jezera, čas, paměť, determinismus, otisky startu (vypnuto / moře / vše zapnuto). Obrázky `godot-prototyp/shots/krok06c/` (mapa planety pro 4 seedy, toky).

## Výsledky (2026-11-26 10:45 SEČ)

### Změna metody proti plánu (negativní výsledek)
Gaussovy „hroudy“ kontinentů (max i super-Gauss, 6 pokusů s velikostí 0,6–1,2 a členitostí 0,12–0,5) **nedávaly oddělené kontinenty**: při 70 % pevniny se hroudy slily v jednu pevninu s „děravým“ vnitrozemím (vnitrozemská moře) a moře se drželo hlavně v pásu kolem švu (rovné pobřeží). Silný warp (1500 m, λ ≥ 3 km) dělal prstencová moře (přeložení souřadnic).
Použito místo toho: **Voronoi kontinentů** – středy na mřížce buněk, jejichž hranice leží na švu (N = 2 → 2 × 1, 3 → 3 × 1, 4 → 2 × 2; posun středu ±15 % buňky ze seedu, buňka se startem má střed přitažený ke startu). Maska `m = tanh(e / (velikost·2500 m)) + C·F`, kde e = min(vzdálenost k ose mezi dvěma nejbližšími středy, vzdálenost ke švu), obojí na zkřivených souřadnicích (warp 700 m, λ ≥ 4 km). Moře tak tvoří průlivy mezi kontinenty a pás kolem švu, vnitrozemí je ploché a bez děr. Tvrdá penalizace pásu švu (512 m + přechod 400 m) zůstává, měkký spád švu je vypnut (`SevMekkySpad` 0).

Výchozí `more_v1.json`: KontinentuMin 2, KontinentuMax 4, KontinentVelikost 1,0, Clenitost (β) 1,0, ClenitostSila 0,12, šum 48 vln λ 600–4000 m, warp 24 vln λ ≥ 4000 m, 700 m.

### Měření (mapa 32 m, 980 × 488, 8 vláken, jen moře)
| seed | středů | pevniny ≥ 50 km² (km²) | ostrovů (≥ 1 km²) | moře cíl → skut. | řeky max / > 5 km / > 10 km | největší povodí | jezer > 0,1 km² (> 1 km²) | čas | paměť |
|---|---|---|---|---|---|---|---|---|---|
| 49 | 3 | 1: 333 (šíje) | 6 (0) | 32,4 → 31,5 % | 10,6 km / 13 / 1 | 16,1 km² | 74 (2) | 5,3 s | 219 MB |
| 1 | 4 | 1: 352 (šíje) | 3 (1) | 28,8 → 27,7 % | 9,1 / 11 / 0 | 23,9 | 76 (2) | 5,7 s | 218 MB |
| 2 | 2 | 2: 177, 166 | 9 (1) | 30,1 → 29,5 % | 10,6 / 16 / 2 | 21,4 | 80 (0) | 5,9 s | 218 MB |
| 3 | 2 | 2: 179, 146 | 11 (0) | 34,1 → 33,4 % | 11,8 / 11 / 3 | 24,8 | 76 (0) | 5,6 s | 184 MB |
| 4 | 3 | 2: 259, 101 | 9 (0) | 27,0 → 26,3 % | 18,4 / 13 / 1 | 46,0 | 91 (0) | 5,4 s | 163 MB |
| 5 | 3 | 1: 368 (šíje) | 4 (0) | 25,5 → 24,7 % | 11,0 / 13 / 2 | 28,1 | 88 (0) | 5,7 s | 145 MB |
| 6 | 3 | 3: 134, 102, 100 | 11 (1) | 31,4 → 30,6 % | 12,5 / 14 / 2 | 28,3 | 79 (0) | 5,5 s | 218 MB |
| 7 | 3 | 3: 135, 107, 95 | 12 (2) | 31,1 → 30,2 % | 11,8 / 15 / 1 | 20,3 | 73 (1) | 5,6 s | 156 MB |
| 8 | 3 | 2: 226, 107 | 6 (0) | 32,4 → 31,6 % | 10,0 / 14 / 0 | 23,6 | 81 (1) | 5,7 s | 219 MB |
| 9 | 4 | 1: 368 (šíje) | 12 (0) | 25,6 → 24,5 % | 9,8 / 16 / 0 | 14,8 | 77 (1) | 5,1 s | 214 MB |

- **H1 částečně:** odchylka skutečného moře od cíle −0,6 až −1,1 p. b. (6b: −1,5 až −2). Systematická: maska se láme přesně v prahu, ale uzly těsně pod prahem (k < 0,5, g ≈ 0) mají ještě povrch nad hladinou 60 m → nejsou moře. Opravitelné posunem prahu (otázka).
- **H2 částečně:** středů 2–4 ze seedu, ale samostatných pevnin ≥ 50 km² 1–3: ve 4 z 10 seedů spojí kontinenty úzká šíje (warp + šum přeruší průliv). Ostrovů 3–12, skoro všechny < 1 km² (největší 2,1 km²). Řeky max 9,1–18,4 km, 11–16 řek > 5 km.
- **H3 ano:** start 3 × 3 na pevnině (k = 1, posun 0) pro všech 10 seedů; testy 12 seedů pro pás švu.
- **H4 ano:** mapa 5,1–5,9 s, paměť 145–219 MB; 1 vlákno = 8 vláken = 2. proces (otisk d33086ee83412a74, seed 49).
- **Negativní:** u švu je pobřeží místy rovné (tvrdý pás 512 + 400 m, kde pevnina dosahuje až ke švu) – viz `sev_v_mori.png`.
- Bez moře (seed 49) pro srovnání: řeky max 3,3 km, 10 jezer > 0,1 km².

### Pánve (moře + 4 × 1500 m × 15 m)
| seed | jezer > 1 km² | největší jezera (km²/hloubka m) | řeky max |
|---|---|---|---|
| 49 | 6 | 2,49/12,5, 2,35/11,8, 1,78/11,3 | 10,6 km |
| 1 | 5 | 2,86/14,1, 2,82/14,7, 2,51/15,4, 1,98/12,9 | 11,8 km |
| 2 | 4 | 2,94/12,1, 2,87/13,0, 2,15/13,3, 2,10/11,0 | 13,5 km |
| 3 | 4 | 2,90/14,3, 2,45/13,2, 2,23/11,5, 1,87/12,2 | 11,8 km |

### Otisky startu (seed 49, start 14,14)
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 |
|---|---|---|---|
| vše vypnuto (výchozí) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| moře + sklon (6c) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| moře + eroze (+ vodníci) | f237940e2f749147 | bbdd487c64daf6b7 | 20 |
| **vše zapnuto** (`VseKrok06`: moře, sklon, pánve, eroze, vodníci) | f237940e2f749147 | bbdd487c64daf6b7 | 20 |

Mapa „vše zapnuto“ f6cd566ebcce8717, 103 vodníků (ve startu 0); sestavení 5,4 s, z keše 1,0 s. Výchozí přepínač vypnuto.

### Obrázky
`godot-prototyp/shots/krok06c/planeta_4_seedy.png` (seedy 49, 2, 6, 4), `toky_seed2.png`, `toky_vse_zapnuto_seed49.png`, `sev_v_mori.png`.

### Testy
80/80 (nové: periodicita a normování šumu, počet kontinentů v rozmezí a mění se se seedem, podíl pod prahem na jiné mřížce ± 1 p. b., počet kontinentů a členitost mění otisk i klíč, přepínač vše zapnuto výchozí vypnutý a start beze změny).

### Otázky pro Jana
1. Šíje: mají být kontinenty vždy oddělené (vynutit minimální šířku průlivu podél os Voronoi), nebo šíje nechat jako přirozenou variantu?
2. Ostrovy jsou malé (< 2 km²). Přidat samostatné „ostrovní“ hroudy v průlivech / vyšší členitost, nebo stačí?
3. Kompenzovat systematickou odchylku moře (−0,8 p. b.) posunem prahu?
4. Rovné pobřeží u švu: rozšířit/zvlnit tvrdý pás švu šumem, nebo nechat?
5. `more_v1.json` je teď v klíči keše vždy (i bez moře) – změna JSON zneplatní i mapy bez moře. OK?
6. Zapnout „vše zapnuto“ jako výchozí? (zatím ne, čeká na Janovo ano)
