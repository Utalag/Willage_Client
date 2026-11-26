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

## Doplnění zadání během práce
- **Jan 10:03:** moře ≈ 30 % planety (parametr, měřit skutečný podíl). Jezera: (a) prohlubně vyplněné priority-floodem zůstávají jezery, hladina = úroveň vyplnění, měřit počet a plochy; (b) velké pánve pro velká jezera za přepínačem (výchozí vypnuto), měřit velká jezera s ním i bez něj.
- **Jan 10:11:** podíl moře a počet pánví jsou ladicí parametry v datovém JSON, vstupují do klíče keše; test, že změna parametru změní výsledek.
- **Jan 10:12:** odchylka podílu moře ±5 p. b. deterministicky ze seedu planety (parametr v JSON, výchozí 5).

Úprava metody proti PROP: šířka mořského pásu se už nezadává, počítá se z podílu moře f = PodilMore ± odchylka: (Px − 2P)(Py − 2P) = (1 − f)·Px·Py. Střed pásu je posunutý od švu automaticky tak, aby šev i s pásem prolnutí (512 m) ležel v moři a start svět 3 × 3 byl na pevnině; s šumem ořezaným na ±A je to zaručené geometricky (rezerva 2 × 40 m). Sklon začíná až 1400 m za pobřežím (pobřežní rovina), takže start svět má posun přesně 0. Hloubka moře je 25 m, aby se do moře nedostalo moc kopců jako ostrovů.

## Výsledky (2026-11-26 10:17 SEČ, 8 CPU, .NET 9 Release, seed 49, mřížka 32 m)
Kód: `Svet/MoreSklon.cs`, `Svet/Panve.cs`, `Svet/ParametryMore.cs` (+ `data/v1/more_v1.json`), `Eroze/Reky.cs`, `Eroze/Jezera.cs`, interpolace v `Eroze/ErozeSvetaFn.cs`, hladina v `Voda/RegionalniHladina.cs` (+ `IGeologie.PovrchBezEroze/ErozeHruba`), WGER v2 (+ vyplněný povrch = hladiny jezer). Testy 70/70 (`TestyKrok06b`).

| měření | bez moře (krok 6) | moře + sklon | moře + sklon + pánve |
|---|---|---|---|
| podíl moře: cíl / skutečný | – (odtok 2 %) | 32,4 % / 30,2 % | 32,4 % / 30,2 % |
| řeky (ústí → nejdelší pramen) | 415 | 61 | 61 |
| délka řeky max / medián | 3,3 km / 309 m | **14,6 km** / 1,4 km | 12,6 km / 1,4 km |
| řek > 5 km / > 10 km | 0 / 0 | **17 / 6** | 16 / 4 |
| největší povodí (km²) | 3,9; 2,3; 2,3 | **33,4; 26,2; 22,8** | 33,4; 26,3; 26,2 |
| jezera: počet / plocha | 6481 / 30 km² (6,2 %) | 4940 / 45 km² (9,2 %) | 4690 / 52 km² (10,6 %) |
| jezera > 0,1 km² / > 1 km² | 10 / 0 | 81 / 0 | 78 / **4** (3,18; 2,34; 2,27; 1,90 km², hloubka 12–14 m) |
| největší jezero | 0,26 km² | 0,66 km² | 3,18 km² |
| vodníci | 189 | 99 | 100 |
| čas 8 vláken / 1 vlákno | 6,1 s / 6,6 s | 5,3 s / 6,2 s | 5,9 s / 5,9 s |
| špička paměti | 216 MB | 215 MB | 224 MB |
| otisk mapy (8 vl. = 1 vl., 2 procesy) | `f24cec93a004192f` | `183c8276866d4e55` | `e25ede7117c261d3` |
| soubor WGER v2 | 5,0 MB | 4,9 MB | 4,9 MB |
| šev: skok 0,25 m přes šev / běžný krok | 0,08 / 0,13 m | 0,08 / 0,14 m | 0,08 / 0,14 m |
Mřížka 16 m s mořem pro srovnání: 20,2 s, 594 MB, řeky max 13,9 km, 17 > 5 km.

Podíl moře pro více seedů (cíl = 30 % ± 5 p. b. ze seedu, skutečný = podíl uzlů moře v mapě):

| seed | 49 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| cíl | 32,4 % | 28,8 % | 30,1 % | 34,1 % | 27,0 % | 25,5 % | 31,4 % | 31,1 % |
| skutečný | 30,2 % | 26,9 % | 28,6 % | 31,9 % | 25,4 % | 24,0 % | 29,3 % | 29,1 % |
| řeky max / > 5 km | 14,6 km / 17 | 17,8 km / 18 | 13,3 km / 16 | 17,2 km / 14 | 17,3 km / 15 | 14,7 km / 14 | 16,9 km / 15 | 13,5 km / 16 |
| největší povodí | 33 km² | 36 km² | 24 km² | 31 km² | 52 km² | 30 km² | 32 km² | 29 km² |
Start svět 3 × 3 je pro všechny seedy na pevnině a beze změny (test 12 seedů).

Otisky start světa (mapa s mořem, seed 49):

| | krok 3 | voda 14,14 | prameny 14,14 | prameny 3 × 3 |
|---|---|---|---|---|
| výchozí (vše vypnuto) | `c8eeb7964d1ddd85` | `7714d1a1d34e00ad` | 2 | 18 |
| moře + sklon (+ pánve) | `c8eeb7964d1ddd85` beze změny | `7714d1a1d34e00ad` beze změny | 2 | 18 |
| eroze (+ vodníci), hladina sleduje erozi | `f237940e2f749147` | `71b31c6399afba0c` | 1 + 1 posunutý o 2 m do bloku 13,14 | 20 |
| eroze, hladina jako krok 4 | `f237940e2f749147` | `6c42e1f192b88309` | 0 | 21 |
Ve start světě 3 × 3 není žádný vodník.

Interpolace E (20 000 bodů, mapa s mořem):

| | odchylka v uzlech průměr / max | skok gradientu na hraně buňky průměr / max | max E | čas dotazu |
|---|---|---|---|---|
| bilineární (krok 6) | 0 / 0 | 0,0105 / 0,584 | 9,3 m | 28 ns |
| **Catmull-Rom (nově výchozí)** | 0 / 0 | 0,0001 / 0,042 | 10,8 m | 78 ns |
| B-spline | 0,099 / 4,7 m | 0 / 0 | 7,8 m | ~390 ns |

Hypotézy:
- H1 platí: s mořem a sklonem je řeka max 14,6 km, 17 řek > 5 km (6 > 10 km), největší povodí 33 km² (bez moře 3,3 km / 0 / 3,9 km²).
- H2 platí: 32 m 5–6 s, paměť ~220 MB, otisk stejný na 1 i 8 vláknech a ve 2 procesech. (Vlákna moc nepomáhají, eroze je sekvenční.)
- H3 platí, dokonce silněji: díky pobřežní rovině se s mořem otisky start světa vůbec nemění (krok 3 i voda 14,14).
- H4 **částečně**: s hladinou, která sleduje erozi, prameny nezmizí. Pramen 1801,1801 zůstal, druhý se posunul o 2 m (1793 → 1791) přes hranici do bloku 13,14. Ve 3 × 3 je 20 pramenů místo 18. S hladinou jako v kroku 4 je v 14,14 0 pramenů.
- H5 platí: Catmull-Rom hvězdy odstraní (skok gradientu 100× menší, prochází uzly, překmit +16 % v max E). B-spline je hladký úplně, ale vrcholy E sníží až o 4,7 m.

Příčina ztráty pramenů v kroku 6: eroze v jezerech (vyplněné prohlubně) neprobíhá, okolí se snížilo → vyhlazený průměr (hladina) klesl víc než povrch v prohlubni → zóna vývěru zmizela (63 → 3 bodů). Oprava: hladina se počítá z povrchu před erozí a pak se sníží o hrubou erozi E (bez koryta), takže koryto hladinu odkryje (`ParametryVody.HladinaSledujeErozi`, výchozí zapnuto; bez eroze je výsledek bitově stejný).

Negativní / omezení:
- Skutečný podíl moře je o 1,5–2 p. b. menší než cíl: kopce v mořském pásu zůstávají ostrovy. Šlo by korigovat (hlubší moře, nebo podíl kalibrovat po vzorkování) – otázka.
- Pánve s jezery zkracují nejdelší řeky (14,6 → 12,6 km), protože řeky končí v jezerech. Jezera mají jen hladinu (vyplnění), přepad je D8 přes jezero (rovné čáry v obrázku).
- Pobřeží je obdélník se zvlněnými okraji (vzdálenost ke švu přes min(dx, dy)), rohy jsou zaoblené jen šumem.
- Rezerva pro start svět je jen 2 × 40 m; při jiných parametrech (šum pobřeží, přechod, rezerva švu) se nemusí vejít. `StartNaPevnine` to hlásí a test to hlídá.
- Mřížka 16 m s mořem: 594 MB (nad 500 MB).
- Godot adaptér stále není.

Co by změnilo zapnutí eroze (+ vodníků): otisk kroku 3 `c8ee…` → `f237…`, voda 14,14 `7714…` → `71b3…`, prameny 3 × 3 18 → 20, v 14,14 jeden pramen přejde o 2 m do 13,14; povrch start světa níž průměrně o 0,29 m (max ~3 m), vodník ve start světě žádný. **Návrh:** zapnout erozi + vodníky + moře spolu, až Jan odsouhlasí změnu otisků; přepínače zatím zůstávají vypnuté.

TODO (Jan 9:59, bod 7): **náplavy a delty** jako samostatný další krok: ukládání sedimentu (např. Yuan et al. / FastScape s depozicí) v jezerech a u ústí do moře; zapsáno v DENIK.

Obrázky `godot-prototyp/shots/krok06b/`: `toky_more.png`, `toky_more_panve.png`, `toky_bez_more.png`, `vyska_pred_po.png`, `detail_bloku_interpolace.png`, `sev_v_mori.png`.

## Otázky pro Jana
1. Podíl moře: korigovat ostrovy, aby skutečný podíl seděl s cílem (dnes −1,5 až −2 p. b.), nebo stačí cíl?
2. Zapnout moře, erozi a vodníky jako výchozí najednou (otisky viz tabulka), nebo nejdřív jen moře (otisky beze změny)?
3. Pánve: výchozí 4 × R 1500 m × 15 m vyhovují? Mají být výchozí zapnuté s mořem?
4. Pramen, který přejde o 2 m do sousedního bloku, je v pořádku (svět ho má), nebo chceš stabilnější polohu pramenů vůči erozi?
5. Tvar kontinentu: stačí „obdélník“ se zvlněným pobřežím, nebo chceš členitější pobřeží / víc ostrovů?
