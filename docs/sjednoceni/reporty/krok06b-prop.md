# PROP – Krok 6b: moře a sklon kontinentu, prameny na erodovaném povrchu, hladší eroze

Větev `gen-v1-krok06b-more-sklon` z `gen-v1-krok06-eroze-sveta` (659b905). Napsáno 2026-11-26 10:02 SEČ, před kódem. Bez merge do main.
Zadání: Jan 9:59 (t926u, [pt926u] „přidat moře … mírný sklon … šev torusu by mohl být právě v moři“), rozhodnutí 1–7 ke kroku 6.

## Cíl
1. **Moře a mírný sklon kontinentu** ve funkci světa (krok 2): moře v pásu kolem švu torusu (x = 0 ≡ Px, y = 0 ≡ Py), pevnina uvnitř stoupá mírně od pobřeží. Odtok eroze = moře (místo nejnižších 2 %). Za přepínačem (mění svět); start svět 3 × 3 na pevnině. Hladina moře a šířka mořského pásu jsou parametry.
2. Mřížka eroze 32 m výchozí (beze změny).
3. **Prameny kroku 4 na erodovaném povrchu:** zjistit, proč v bloku 14,14 se zapnutou erozí zmizí, a přizpůsobit (bez změny výchozího stavu). Přepínač eroze zůstává vypnutý; uvést, co by zapnutí změnilo.
4. Vodníci: váha kopců ≥ 0,5, 10 l/s/km², zapínají se spolu s erozí (jeden přepínač).
5. Šev: prolnutí zůstává (teď v moři).
6. **Hladší interpolace E** (bez „hvězd“ bilineáru): Catmull-Rom a kubický B-spline, změřit a vybrat.
7. Náplavy a delty → jen poznámka do TODO (DENIK, PROP).

## Metoda
- **Moře a sklon (nová třída `Svet/MoreSklon.cs`, přepínač `ParametrySveta.More`, výchozí vypnuto).**
  - Vzdálenost ke švu: `d = min(dx, dy)`, `dx = min(x mod Px, Px − x mod Px)` (obdobně y). Pobřeží zvlní nízkofrekvenční šum: `dn = d + A_p·n(x, y)` (A_p 300 m, vlna 1,5 km).
  - Podíl pevniny `k = smoothstep(P − T, P + T, dn)` (mořský pás P 1100 m, přechod T 300 m).
  - Posun výšky `O = S·max(0, dn − P) − (1 − k)·H_m` (sklon S 2 ‰, hloubka moře H_m 12 m) se přičte v `VyskaW` před stropem povrchu – pro tvar i detail, takže vrstvy geologie jdou s ním; sopky se umisťují z výšky bez posunu (beze změny).
  - Moře = `k < 0,5` a výška < hladina moře (60 m). Pás prolnutí švu (512 m) leží celý v moři (dn ≤ 812 m < P − T).
  - Start svět (1792–2176 m) má dn ≥ 1492 m > P + T → celý na pevnině, posun jen sklonem (~0,8–2 m).
  - Proč tak: jednoduché, periodické (vzdálenost ke švu je periodická, šum jen v moři u švu řeší prolnutí), čistá funkce bez stavu; sklon dá vodě směr k pobřeží → delší řeky.
- **Odtok eroze:** uzly moře (podle `MoreSklon`) místo nejnižšího podílu; bez moře zůstává podíl (krok 6).
- **Prameny:** diagnostika kandidátů v 14,14 s erozí (povrch, hladina, materiál, druh). Hypotéza: eroze snižuje jen povrch, vrstvy (tvar) zůstávají → povrchová vrstva se ztenčí/zmizí a mění se druh/propustnost, nebo hladina (vyhlazený povrch) klesne jinak než povrch. Úpravy zkoušet od nejmenší: (a) hladina z neerodovaného tvaru, (b) eroze posune i horní vrstvy (půda se obnoví), (c) parametry kandidátů.
- **Interpolace E:** bilineární (krok 6) / Catmull-Rom (interpoluje uzly, může překmitnout → ořez ≥ 0) / kubický B-spline (C², neinterpoluje, nepřekmitne). Měřit: skok gradientu přes hrany buněk, odchylka v uzlech, max E, vzhled detailu.

## Hypotézy
- H1: S mořem a sklonem jsou řeky delší: max > 5 km, několik toků > 5 km, největší povodí > 10 km².
- H2: Čas mapy 32 m < 10 s, paměť < 300 MB, determinismus (2 procesy, 1 vs 8 vláken) platí.
- H3: S vypnutým mořem i erozí se otisky nemění (krok 3 `c8eeb7964d1ddd85`, voda 14,14 `7714d1a1d34e00ad`); se zapnutým mořem se mění jen o sklon, start svět zůstane pevninou.
- H4: Prameny 14,14 lze se zapnutou erozí udržet (≥ 1) bez zásahu do výchozího stavu.
- H5: B-spline odstraní hvězdy (skok gradientu → 0) za cenu snížení vrcholů E o desítky %, Catmull-Rom je zachová s malým překmitem.

## Měření
Délky řek (max, medián, počet > 5 km), největší povodí, čas, paměť, determinismus, otisky vyp/zap (moře, eroze, vodníci), prameny v 14,14, interpolace. Obrázky `godot-prototyp/shots/krok06b/` (toky + moře, výška před/po, detail bloku).
