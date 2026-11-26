# PROP – Šířka pobřežního pásu podzemní vody z koeficientu průsaku

Větev `gen-v1-prusak-pobrezi` z `gen-v1-prusak-koeficient` (0c23f5f). Napsáno 2026-11-26 12:45 SEČ, před experimentem. Bez merge do main.
Zadání: Jan 12:35 (t959u): funkce z koeficientu průsaku (útlum / dosah z materiálového sloupce) a napojit ji na pobřeží místo konstantní `HladinaPrechodM = 5 m`. Šířka pásu mořské hladiny do vnitrozemí závisí na materiálech u břehu (štěrk široký, písek užší, jíl/žula skoro nic), pak smoothstep do spádové hladiny jako dosud; kde terén nemá vlastní vodu, čára končí na okraji pásu. Za přepínačem (výchozí vypnuto = konstanta 5 m a otisky seed 49 beze změny), ladící parametry v JSON. Upřesnění Jan 12:36: **šířka pásu = jak daleko vnikne mořská voda do vnitrozemí za časový horizont (výchozí 30 dnů); dál se nic nepočítá; horizont je ladící parametr.**

## Co už existuje (reuse)
- `RegionalniHladina.Surova`: u moře `hladina = hm + (l − hm) · smoothstep(d / HladinaPrechodM)`, d = vzdálenost od skutečného břehu (`MoreSklon.VzdalenostOdMoreJemna`, 6g; hledá `JeMore` po 1 m do 16 m).
- Koeficient průsaku 0–255 (`PrusakKoeficient`, `PrusakUtlum`, Q24; větev gen-v1-prusak-koeficient), K a porozita z katalogu (`Material.KMs`, `Porovitost`).

## Návrh
- **Funkce dosahu** `Voda/Prusak/PrusakDosah`: jak daleko dojde čelo mořské vody za horizont H v homogenní vrstvě materiálu m. Blok délky ℓ = 0,25 m (buňka). Doba přes čistý blok (Darcy) τ₀ = ℓ · n / (K · i) (n porozita z katalogu, i spád `PobrezSpad`). Čelo prochází blokem k s propustností T_k = ∏ b/255 (Q24, celočíselně, dolů), proto τ_k = τ₀ / T_k. Dosah = největší počet bloků, jehož součet τ_k ≤ H, plus zlomek posledního bloku (lineárně, celočíselně v mm). Materiál s koeficientem 255 postupuje stálou rychlostí, materiál s menším koeficientem zpomaluje geometricky (tlustá vrstva = těsná). K = 0 nebo koeficient 0 = dosah 0.
- **Materiálový sloupec** `PobrezniPas.Sirka`: u skutečného břehu (nejbližší bod `JeMore`) se vezmou pevné buňky od povrchu o `PobrezOknoM` dolů; platí materiál s největším dosahem (voda proniká nejpropustnější vrstvou). Vrstva se předpokládá pokračující do vnitrozemí. Strop `PobrezMaxM` (musí být ≤ ~30 m kvůli oknu hledání břehu).
- **Napojení**: `RegionalniHladina.Surova`: když `PrusakPobrezi` zapnuto, šířka pásu W = `PobrezniPas.Sirka` z břehu nejbližšího k bodu místo konstanty; dál `smoothstep(d / W)`; d ≥ W beze změny (hladina = původní spád, kde terén vlastní vodu nemá, čára končí na okraji pásu); v moři d = 0 → hladina moře. W = 0 (žula, jíl) = pás nulový.
- **Přepínač a JSON** (`voda_v1.json`): `prusakPobrezi: false`, `pobrezHorizontDni: 30`, `pobrezSpad`, `pobrezPorovitost` (náhradní, když katalog nemá), `pobrezMaxM`, `pobrezOknoM`. Vypnuto: kód cesta `HladinaPrechodM` beze změny (i hledání břehu s oknem 16 m).
- Šířky se cacheují po 1 m bodu břehu.

## Doplnění zadání 12:39: tlak (rozdíl hydraulické výšky)
Průsak roste se spádem, takže voda hnaná z kopce projde dál než na ploše. Celočíselně a ladící (`ParametryVody`, voda_v1.json):
- **Pobřeží:** spád i (v promile) = |hladina ze spádu terénu − hladina moře| / `PobrezTlakDelkaM` (100 m), v mezích `PobrezSpadMin` (10 ‰) … `PobrezSpadMax` (500 ‰). Rychlost čela v = K·i/n, takže doba přes blok τ₀ ∝ 1/i. Bez tlaku (`PrusakTlak = false`) stálý `PobrezSpad` 50 ‰. Spád se kvantuje na celé promile a šířka se cacheuje podle (bod břehu, spád).
- **Dutina:** s tlakem je spád skutečný hydraulický: i = (H − max(h, z buňky)) / tloušťka stěny, nejvýš `PrusakSpadMax` (10); tok = X · T · i. Tenčí stěna a větší rozdíl hladin = rychlejší průsak. Díra zůstává na poměru výšek. Bez tlaku původní model (poměr výšek).
- `PrusakTlak` je ve výchozím stavu zapnuto, ale působí jen v dutině a v pobřežním pásu, které jsou samy za přepínači (PrusakKoeficient pro koeficient v dutině není podmínkou pro spád; model dutiny se používá jen při vytváření staveb). Generátor světa tím při vypnutých příznacích nezměněn.

## Hypotézy
- H1: štěrk (K 1e-2) dosáhne stropu, písek (K 1e-4) několik metrů, spraš a jíl necelý metr až nic, žula 0.
- H2: bez koeficientu (jen Darcy) by písek v 30 dnech dosáhl desítek metrů; koeficient jej kvůli geometrickému zpomalování stlačí na jednotky metrů.
- H3: příznak vypnut: otisky seed 49 (krok 3, voda 14,14, prameny 3 × 3, mapa) a další seedy beze změny. Zapnuto: otisk kroku 3 a mapa beze změny (voda nemění terén), otisk vody a prameny se mohou lišit jen poblíž moře; start 3 × 3 je daleko od moře → beze změny.
- H4 (možný problém): šířka závisí na materiálu u konkrétního bodu břehu a mezi sousedními body se skokově mění → v hladině podél břehu skoky. Změřit.
- H5 (možný problém): pás větší než 16 m vyžaduje větší okno hledání břehu (cena).

## Měření
Šířky pásu pro materiály a horizonty 7/30/90 dnů; řezy: strmé a pozvolné z 6g, hledat štěrkový / písčitý břeh; otisky a prameny seed 49 a další seedy zapnuto/vypnuto; testy; `git merge-tree`.

## Výsledky
(2026-11-26 13:05 SEČ)

### Šířky pásu podle materiálu (30 dnů; `shots/prusak-pobrezi/sirky_pasu.md`, obrázek `sirka_pasu_podle_materialu.png`)
| materiál | koef. | 30 d, 10 ‰ (plochý) | 50 ‰ | 200 ‰ (z kopce) | 7 d, 50 ‰ | 90 d, 50 ‰ | bez koef. 50 ‰ |
|---|---|---|---|---|---|---|---|
| subalpine_scree (štěrk) | 255 | 16,00 (strop) | 16,00 | 16,00 | 16,00 | 16,00 | 16,00 |
| gravel_sand / hill_sand (písek) | 178 | 1,59 | 2,65 | 3,60 | 1,69 | 3,40 | 16,00 (strop) |
| weathered_volcanic | 128 | 0,39 | 0,86 | 1,34 | 0,43 | 1,25 | 5,18 |
| grass | 128 | 0,27 | 0,68 | 1,13 | 0,29 | 1,04 | 2,88 |
| weathered_granite | 77 | 0,16 | 0,41 | 0,69 | 0,18 | 0,61 | 2,59 |
| topsoil | 77 | 0,07 | 0,28 | 0,52 | 0,08 | 0,48 | 1,11 |
| conglomerate | 77 | 0,04 | 0,20 | 0,41 | 0,04 | 0,35 | 0,65 |
| loess | 38 | 0,00 | 0,00 | 0,02 | 0,00 | 0,01 | 0,03 |
| clay_deposit, weathered_clay | 13 | 0 | 0 | 0 | 0 | 0 | 0 |
| granite, orthogneiss | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

H1 potvrzena: štěrk strop, písek jednotky metrů, spraš a jíl nic, žula 0. **H2 potvrzena, výrazněji:** bez koeficientu by písek za 30 dnů dosáhl stropu 16 m, s koeficientem 2,65 m. Čelo se geometricky zpomaluje, proto se dosah s časem nasycuje: písek 7 d 1,69 m, 30 d 2,65 m, 90 d 3,40 m. Horizont je tedy ladící parametr s malým vlivem u písku a velkým u materiálů s koeficientem 255.
**Tlak:** písek 1,59 m (plochý) → 2,65 m (50 ‰) → 3,60 m (200 ‰, voda z kopce).

### Břehy seed 49 (sken mřížkou 64 m po ose x, 2316 přechodů moře/pevnina; spád pro statistiku 50 ‰)
- šířka < 0,01 m: 1441 (62 %), 0,01–1 m: 578 (25 %), 1–3 m: 297 (13 %), nad 3 m: 0.
- Dominantní materiál v okně 2 m: topsoil 512 břehů (0,28 m), cave_limestone 472 (0,01 m), deep_limestone 345 (0,01 m), gravel_sand 297 (2,65 m), dolomite 194, loess 148 (0,00 m), quartz_sandstone 74, black_coal 66.
- Seedy 1, 2, 3: stejné rozložení (62 % pod 0,01 m, 25–27 % pod 1 m, 12–14 % 1–3 m, žádný břeh nad 3 m). **Břeh se štěrkem (subalpine_scree) se nevyskytl ani v jednom seedu** (štěrk je podhorský materiál); „štěrkový“ řez proto není, použil jsem dva písčité (gravel_sand).
- **Negativní / pozor:** (1) výchozí pás je na většině břehů užší než dosavadních 5 m (nejširší 2,65–3,6 m u písku). Pás 5 m už nikde nevzniká, jen strop 16 m u štěrku. (2) Vápence (cave_limestone, deep_limestone, dolomite) mají K matrice 3e-8 m/s, ale jsou krasové (v `Propustnost` je to „těleso“); proto vycházejí těsně (0,01 m), i když by mořská voda v krasu pronikala daleko. Chtělo by to koeficient krasu (255) nebo vlastní dosah; nechávám na rozhodnutí Jana. (3) Šířka je po materiálech skoková: sousední body břehu s jiným materiálem mají jiný pás (H4 potvrzena, ale v hladině vznikají jen malé skoky, v testu na syntetickém břehu max 0,5 m na 5 cm).

### Řezy (`shots/prusak-pobrezi/rezy_pobrezi_prusak.png`)
Čtyři řezy po 100 m seed 49, vždy celek a detail 20 m u břehu, oranžová čárkovaně = stávající pás 5 m, modrá = nově: strmé a pozvolné z 6g (topsoil/jíl u břehu: nový pás ~0,3 m, čára hned navazuje na spádovou hladinu), písčité A (od x 29113,5 y 4576) a B (od x 8117 y 2400, směr −x): pás 2,65 m (vs. 5 m), mořská hladina se pak skokem, ale plynule smoothstepem srovná s hladinou terénu (~51 m v písku, kde je terénní voda hluboko pod mořem).

### Otisky a prameny
Příznak `PrusakPobrezi` **vypnut**: otisky bloků 128 m u pobřeží shodné s `main` 5e4f1f0 (porovnáno nezávislým programem nad main): seed 49 bloky 65,7 / 23,22 / 158,44 / 166,16 / 227,35 / 63,18 (3455751b3c168aa4, b8d1562caa309cc9, 94788ffe572cd8a2, b4b4b612e304cf5f, b6810d3c21342704, f08d9c5b76d571e2), seed 1 (68,7; 219,26), seed 2 (188,7; 8,19), seed 3 (150,7) beze změny. Start 3 × 3 / krok 3 / mapa: c8eeb7964d1ddd85, 9f32311e046f8b6a, voda 7714d1a1d34e00ad, 8e239a68c6d01be0, prameny 18 / 20, mapa 800d420bb00047de: **stejné vypnuto, zapnuto i zapnuto bez tlaku** (start je stovky metrů od moře).
**Zapnuto**, bloky u pobřeží (otisk vody se mění, počet pramenů ne):
| seed, blok | změněných bodů hladiny z 4096 | max / průměr změny | prameny vypnuto → zapnuto |
|---|---|---|---|
| 49, 65,7 | 101 | 20,3 / 11,1 m | 14 → 14 |
| 49, 23,22 | 74 | 5,9 / 3,0 m | 20 → 20 |
| 49, 158,44 | 132 | 6,4 / 2,0 m | 11 → 11 |
| 49, 166,16 | 30 | 2,6 / 1,2 m | 4 → 4 |
| 49, 227,35 | 156 | 10,6 / 4,8 m | 12 → 12 |
| 49, 63,18 | 158 | 9,6 / 2,4 m | 15 → 15 |
| 1, 68,7 | 25 | 25,1 / 15,0 m | 7 → 7 |
| 1, 219,26 | 166 | 3,5 / 0,95 m | 5 → 5 |
| 2, 188,7 | 100 | 27,3 / 14,0 m | 11 → 11 |
| 2, 8,19 | 127 | 9,9 / 4,9 m | 9 → 9 |
| 3, 150,7 | 77 | 31,8 / 15,1 m | 13 → 13 |
Změny jsou jen u břehu (původní pás 5 m se zúžil, tam se vrátila spádová hladina, někde o desítky metrů pod mořem). Počet pramenů se nezměnil v žádném z 11 bloků; otisk se mění (hladina). Otisky se liší i mezi „zapnuto“ a „bez tlaku“ jen tam, kde je rozdíl hladin velký.

### Dutina s tlakem (`shots/prusak-pobrezi/dutina_tlak.md`)
Dutina 2 × 2 × 6 m, venku 60 m. Do 50 %: písek 1 blok koeficient + tlak 7,5 min (bez tlaku 1,8 h); písek 5 bloků 2,4 h (7,7 h); písek 10 bloků 1,2 dne (1,9 dne); spraš 1 blok 25 dnů (nedosaženo za 30); zvětralá žula 5 bloků nedosaženo (stávající + tlak 1,7 dne). Tlak zrychluje o řád u tenkých stěn (spád > 1), u tlustých stěn méně.

### Testy
`main` 5e4f1f0: OK 110, chyb 0. Předchozí větev gen-v1-prusak-koeficient (0c23f5f): OK 135. Tato větev: **OK 165, chyb 0** (nových 30).
