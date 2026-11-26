# PROP – Krok 6 (nové pořadí), eroze světa v C#

Větev `gen-v1-krok06-eroze-sveta` z `gen-v1-krok04b-geologie-cs` (da61ba6). Napsáno 2026-11-26 9:40 SEČ, před kódem. Bez merge do main.
Zadání: Jan 9:08–9:11 (plán 04, krok 6, větev `sjednoceni` 8c7fc4d) a 9:35 ([pt924u]: pokračovat dalším bodem).

## Cíl
1. **Hrubá mapa eroze celé planety** (torus, výchozí 31 360 × 15 616 m, velikost je parametr), jednou ze seedu: srážky → směrování toku → akumulace → hydraulická eroze. Mřížka 16 m a 32 m, změřit obě a jednu vybrat.
2. **Uložení s planetou:** binární formát + klíč keše (stejný klíč → stejná mapa, jiný → přepočet).
3. **Jemný detail jako funkce** nad mapou: výška a koryto v libovolném bodě, spojitá, bez švů bloků i torusu.
4. **Vodníci:** trvalé zdroje vody na pramenech toků v kopcích (poloha + průtok), deterministicky, napojené na prameny kroku 4.
5. Eroze do výšek světa jen za přepínačem (výchozí **vypnuto**), dokud se neukáže, že nic nerozbije. Otisky kroku 3 a vody 14,14 se při vypnutí nesmí změnit.

Mimo rozsah: eroze ostrova během hry (krok vody na ostrově), náplavy a delty jako samostatná tělesa (jen návrh), klima mimo parametr srážek.

## Co se znovu použije
- `SvetFn` (povrch, biomy) a `GeologieCs` (krok 5), `GeologyHash`/`StableHash`, `Q16` pro otisky, `Pramen`/`Prameny`/`PodzemniVodaFn` (krok 4), `ParalelniSloupce` (vzor paralelizace s pevným pořadím zápisu).
- Metoda E49 `blueprint-studie/scripts/svet8/reky.gd`: priority-flood [20], D8 po vyplněném povrchu, akumulace srážek – zde na torusu a v C#.

## Metoda
- **Periodický podklad.** Funkce světa kroků 1–3 periodická není (mapy stanic a FastNoiseLite jen ve čtverci `svet_max_m`). Podklad pro torus: `h_p(x, y)` = povrch světa s měkkým prolnutím v pásu šířky W (výchozí 512 m) u švu: u x < W se míchá `h(x, y)` s `h(x + Px, y)` vahou smoothstep (obdobně y, v rohu bilineárně). Výsledek je spojitý a periodický; mimo pás je přesně povrch světa. Funkce světa se staví s `svet_max_m` = max(Px, Py) + W, aby měla stanice po celé planetě (ověřit, že se tím nezmění výchozí svět). **Otázka pro Jana:** nativně periodická funkce světa (torus v šumu) je větší zásah do kroku 2 – zatím jen toto prolnutí.
- **Odtok (base level).** Torus nemá okraj. Výchozí: odtokem je nejnižší podíl buněk podkladu (parametr, 2 %), tam voda mizí (jezera/moře). Ostatní bezodtoká místa vyplní priority-flood s ε [20] (jezera). **Otázka pro Jana:** moře / hladina moře je rozhodnutí světa.
- **Směrování:** D8 nejstrmější spád po vyplněném povrchu [86] (periodické indexy, shoda → nižší směr), akumulace plochy × srážky v pořadí výšky (deterministické).
- **Eroze:** stream power `∂h/∂t = −K A^m S^n` [87][31], n = 1, m = 0,5, implicitní schéma Braun & Willett [85] (O(N) na krok, stabilní pro libovolný dt, jen eroze bez ukládání), opakovaně s přepočtem toků. Proč: stejná rovnice jako FastScape [30] a Cordonnier [31], krátké a deterministické; kapková eroze E49 je náhodná a závislá na pořadí.
- **Toky:** buňka s plochou povodí ≥ A_krit je koryto. Pramen toku = koryto bez přítoku z koryta. Délka toku = od pramene po soutok nebo odtok.
- **Vodníci:** prameny toků, kde je váha kopcovitých biomů (pahorkatina + hornatina + sopečná) ≥ 0,5. Průtok = plocha povodí × specifický odtok (l/s/km², parametr × srážky). Napojení: nový druh pramene `Vodnik`, přidá se do `Prameny.VOblasti` za přepínačem (výchozí vypnuto).
- **Jemný detail:** `h(x, y) = povrch světa − E(x, y) − koryto(x, y)`; E bilineárně z uzlů světové mřížky (periodicky), koryto = vzdálenost k úsečkám toku (uzel → příjemce) s šířkou a hloubkou podle průtoku (hydraulická geometrie w ∝ Q^0,5, d ∝ Q^0,4 [88]), profil (1 − t²)². Spojité, bez švů (uzly jsou světové).
- **Formát:** `WGER` verze 1, hlavička (nx, ny, krok, Px, Py, seed, klíč keše), pole E (float32), A (float32), příjemce (sbyte), příznaky (byte), Deflate. Klíč keše = SHA-256 z verze generátoru, seedu, rozměrů planety, kroku mřížky, parametrů eroze a hashů datových souborů světa.
- **Paralelizace:** vzorkování podkladu a výpočet směrů po buňkách (pevné místo zápisu); priority-flood, akumulace a eroze sekvenčně v deterministickém pořadí.

## Hypotézy
- H1: Mapa 32 m na celou planetu < 30 s na 8 vláknech, 16 m < 2 min; paměť < 500 MB.
- H2: Otisk mapy je stejný ve 2 procesech a na 1 i N vláknech.
- H3: Toky i výšky jsou periodické: přes šev torusu žádný skok (rozdíl E na švu = rozdíl uvnitř).
- H4: S vypnutým přepínačem se otisky kroku 3 (`c8eeb7964d1ddd85`) a vody 14,14 (`7714d1a1d34e00ad`) nezmění.
- H5: 16 m dá podobnou síť toků jako 32 m (počet pramenů na km² v řádu stejný), detail údolí je ale u 32 m příliš hrubý pro ostrov 128 m.

## Měření
Čas mapy (1 a N vláken), paměť (peak working set), otisk ve 2 procesech a 1 vs N vláken, periodicita na švu (E i výška), počet a délky toků, počet vodníků, otisky kroku 3 a vody 14,14 s přepínačem vyp/zap, obrázky (výška před/po, toky, vodníci, detail bloku) do `godot-prototyp/shots/krok06/`.

## Výsledky (2026-11-26 9:50 SEČ, 8 CPU, .NET 9 Release)
Kód: `cs/Willage.Gen/Eroze/` (13 malých souborů: ParametryEroze, Torus, PeriodickyPodklad, PriorityFlood, Smerovani, StreamPower, VypocetEroze, MapaEroze, SitToku, Vodnik, VodniciVeSvete, ErozeSvetaFn, SouborMapy, ErozePlanety), parametry `godot-prototyp/data/v1/eroze_v1.json`, nástroj `dotnet run -c Release -- eroze svetmax|mapa <krok> <vláken> [dir]|otisky <wger> <krok>|detail …`, testy `TestyKrok06` (61/61 celkem).

| měření | 32 m (980 × 488) | 16 m (1960 × 976) |
|---|---|---|
| čas celkem, 1 vlákno | 5,8 s | 23,5 s |
| čas celkem, 8 vláken | 5,1 s (podklad 0,5 s, eroze 4,3 s) | 21,1 s (podklad 0,6 s, eroze 20,2 s) |
| špička paměti procesu | 196–211 MB | 527 MB |
| mapa v paměti / soubor WGER | 6,4 MB / 3,5 MB (uložení 0,15 s, načtení 0,02 s) | 25,5 MB / 14,1 MB (0,6 s / 0,06 s) |
| otisk mapy (1 vl., 8 vl., 2 procesy) | `779c6542f74b8fd8` všude | `bb14220287472c9a` všude |
| eroze E: průměr / max / uzlů s E > 0,5 m | 0,55 m / 11,1 m / 41 % | 0,38 m / 11,9 m / 24 % |
| jezera (vyplněno) / odtok / koryta | 6,2 % / 2,0 % / 1,2 % | 6,1 % / 2,0 % / 0,4 % |
| toky (pramen → soutok/odtok) | 555, medián 245 m, průměr 375 m, max 3,1 km; koryta 208 km | 467, medián 225 m, max 2,2 km; koryta 155 km |
| největší povodí | 4,05 km² (≈ 41 l/s) | 2,3 km² |
| vodníci | 189 (0,39 /km²), Q medián 2,8 l/s, max 4,7 l/s | 165 (0,34 /km²), Q medián 2,7 l/s |
| šev torusu: max \|f(x) − f(x + P)\| | 1·10⁻¹² m | 1·10⁻¹² m |
| šev: skok na 0,25 m přes šev X / Y vs. běžný krok 0,25 m | 0,077 / 0,082 m vs. max 0,131 m | 0,081 / 0,087 m vs. 0,138 m |

Vliv na start svět (mapa 32 m):
| | vypnuto (výchozí) | eroze zapnutá | eroze + vodníci |
|---|---|---|---|
| svět s `svet_max_m` 31 872 místo 4096 | povrch start 3 × 3 (1 m): Δ = 0, sopek 2 = 2, krok 3 `c8eeb7964d1ddd85` | | |
| otisk kroku 3 | `c8eeb7964d1ddd85` | `228ca49484243cbd` | – |
| voda 14,14 | `7714d1a1d34e00ad` (2 prameny) | `0539639851b4890b` (0 pramenů) | stejné (ve start 3 × 3 není vodník) |
| blok 12,13 (nejbližší vodník ke startu, 1568,1696, 3,5 l/s) | – | `d11bec1ebdb554e3` (2) | `f7633a00afe067d3` (3 = + vodník) |
Eroze ve start světě 3 × 3: průměr 0,61 m, max 3,2 m.

Hypotézy:
- H1 **platí pro čas** (32 m 5 s, 16 m 21 s; eroze je sekvenční → 8 vláken pomáhá jen u vzorkování podkladu). **Paměť u 16 m 527 MB > 500 MB – neplatí** (proces včetně runtime, halda priority-flood a pole double; mapa sama 25 MB).
- H2 platí (otisk stejný na 1/8 vláknech a ve 2 procesech, i po uložení a načtení WGER).
- H3 platí: funkce je přesně periodická (10⁻¹² m = zaokrouhlení float), skok přes šev je menší než běžný krok uvnitř.
- H4 platí: s vypnutým přepínačem se otisky nemění; i větší `svet_max_m` start svět nemění. Se zapnutou erozí se mění krok 3 i voda (2 prameny v 14,14 zmizí – snížený povrch pod hladinou vývěru) → **přepínač zůstává vypnutý**.
- H5 **spíš neplatí**: 16 m má méně toků (467 vs 555) a 3× méně koryt podle podílu buněk – A_krit je stejná plocha, ale D8 na jemnější mřížce víc rozptyluje a mělčí sklony erodují méně (průměr E 0,38 vs 0,55 m). Detail koryta i tak dělá funkce, ne mřížka.

Negativní / omezení:
- **Toky jsou krátké (max 3 km, povodí max 4 km²).** Svět kroku 2 nemá velkorozměrový sklon (reliéf kolem neutrální výšky 64 m), takže nejnižší 2 % buněk (odtok) jsou rozeseté po celé planetě a vzniká mnoho malých povodí místo řek. Velké řeky chtějí moře / sklon kontinentu – rozhodnutí světa (otázka pro Jana).
- Bilineární E dává v detailu bloku viditelné „hvězdy“ kolem uzlů s velkou erozí (`detail_bloku.png`); hladší by bylo bikubicky nebo smoothstep váhy – návrh.
- Koryto (max 3 m, šířka ≤ krok) je u tak malých průtoků (≤ 41 l/s) mělké (desítky cm) – v obrázku detailu skoro neviditelné.
- Celá planeta má jen 2 sopky (počet sopek v kroku 2 nezávisí na ploše světa) – ke kontrole, mimo krok 6.
- Godot adaptér (vizualizace přes most) zatím není – obrázky jsou z C# výpisů a Pythonu.

Volba mřížky: **32 m** (návrh) – 4× rychlejší (5 s), 4× menší soubor, determinismus i periodicita stejné, síť toků hustší; jemný tvar koryta dává funkce. 16 m nechat jako parametr (`KrokM`). Rozhodne Jan.

Obrázky: `godot-prototyp/shots/krok06/vyska_pred_po.png`, `toky_vodnici.png`, `vyrez_start.png`, `sev_torusu.png`, `detail_bloku.png`.

## Otázky pro Jana
1. **Moře / odtok:** nechat odtok jako nejnižší 2 % buněk, nebo zavést hladinu moře / velkorozměrový sklon kontinentu, aby vznikly delší řeky? (Dnes max tok 3 km, povodí 4 km².)
2. **Mřížka:** 32 m (návrh: 5 s, 3,5 MB) nebo 16 m (21 s, 14 MB, 527 MB paměti)?
3. **Přepínač eroze:** zůstává vypnutý. Zapnout až po rozhodnutí, jak se mají přizpůsobit prameny kroku 4 (v 14,14 se se zapnutou erozí ztratí oba)?
4. **Vodníci:** filtr „kopce ≥ 0,5“ a Q = plocha × 10 l/s/km² vyhovuje? Zapnout vodníky ve výchozím nastavení spolu s erozí?
5. **Periodicita:** stačí prolnutí u švu (pás 512 m), nebo udělat funkci světa nativně periodickou (zásah do kroku 2, mění svět)?
6. **Interpolace E:** přejít z bilineární na hladší (bikubickou / smoothstep), aby v detailu nebyly „hvězdy“? Mění jen zapnutý režim.
7. **Náplavy a delty:** nechat mimo (jen eroze bez ukládání), nebo je navrhnout jako další krok?
