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
