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
