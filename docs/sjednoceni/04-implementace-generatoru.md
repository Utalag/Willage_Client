# 04 – Implementace generátoru V1.0

Stav: **návrh k odsouhlasení**, 2026-11-20 23:50 SEČ. Podklad pro stavbu nové verze generátoru podle kapitol 1–3. Žádné rozhodnutí se tu nemění ani nepřidává. Kde dokument narazí na rozpor nebo chybějící rozhodnutí, odkáže na přílohu A.

**Verze.** Nový generátor dostane `gen_ver` = **V1.0** (tvar `Vmajor.minor` podle 6.2). Je to první verze, která staví na sjednoceném modelu, a s dnešními bloky není kompatibilní (jiná velikost bloku, výška sloupce, ukládání jen rozdílu). Proto hlavní číslo 1. Kroky 1–8 běží pod označením V1.0-vývoj. Číslo V1.0 se uzavře až po povinném testu 2.7 (krok 9).

**Zásady pořadí**
- Od základů nahoru. Každý krok staví jen na předchozích a nic hotového se v pozdějším kroku nepřepisuje.
- Datový model je nezávislý na zobrazení. Prezentace přijde až v posledním kroku a z dat jen čte.
- Kód se nepíše znovu, kde už existuje. U každého kroku je uvedeno, odkud se bere (větev a soubor).
- Testy jsou jen lokální (Godot 4.7.2 headless na boxu, `/workspace/tools/Godot_v4.7.2-stable_linux.x86_64`, Python skripty). Žádné CI ani GitHub Actions.
- Výchozí hra se kontroluje otiskem `voda_e66` (d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod) a `port_studie --check` (0 změn). Kde krok výchozí hru mění záměrně (od kroku 2 dál, nový generátor), vznikne nová reference a stará se zapíše do reportu.

**Stavy:** *hotovo v kódu* = existuje a odpovídá rozhodnutí; *částečně* = kód je, ale jinak nebo jen na studijní větvi; *jen rozhodnuto* = pravidlo je v dokumentu, kód není; *otevřené* = chybí rozhodnutí.

---

## Přehled kroků

| Krok | Obsah | Stav | Závisí na | Schválení |
|---|---|---|---|---|
| 1 | Základy: jednotky, rozměry, verze, tabulka materiálů, determinismus | částečně | – | Jan po kroku |
| 2 | Funkce světa I: API, mapa biomů a hornin, reliéf, masiv, sopky | částečně | 1 | Jan po kroku |
| 3 | Funkce světa II: geologie a útvary | částečně | 2 | Jan po kroku |
| 4 | Funkce světa III: podzemní voda a prameny jako funkce | částečně | 3 | Jan po kroku |
| 5 | Vložení blueprintu a ostrov | částečně | 2–4 | Jan po kroku |
| 6 | Buňky: slupka, kopání, rozdíl a ukládání | částečně | 5 | Jan po kroku |
| 7 | Voda na ostrově: simulace, eroze, přepočet | částečně | 6 | Jan po kroku |
| 8 | Vegetace jako funkce a vrstva změn | částečně | 7 | Jan po kroku |
| 9 | Povinný test 3 × 3 a uzavření V1.0 | jen rozhodnuto | 1–8 | Jan: ano do main |
| 10 | Kontrakt se serverem | otevřené (6.1 zápis, 6.3 backend) | 6, 9 | Jan + Willage-backend |
| 11 | Prezentace | jen rozhodnuto (7.1 odloženo) | 9 | Jan po kroku |

---

## Krok 1 – Základy: jednotky, rozměry, verze, materiály, determinismus

**Obsah**
- Jednotky v metrech a jeden převod l → m³: převzít modul `scripts/jednotky.gd` a `scripts/voda/litry.gd` z větve `e94-metry` (E89 + E94, otisky beze změny).
- Nový modul rozměrů modelu V1.0 (vedle dnešních konstant, které hra zatím potřebuje): blok 128 m, segment 8 m (parametr 8 / 16 / 32), buňka 0,25 m, výška sloupce jako výčet 32 / 64 / 128 m (výchozí 128 m = 512 buněk), neutrální úroveň v polovině, maximální svět 4096 m, výchozí svět 3 × 3 bloky. Kontrola pravidla mocnin 2 a dělitelnosti (1.1, 1.3, 1.4).
- `gen_ver` ve tvaru `Vmajor.minor`: čtení, porovnání, uložení (6.2). Výchozí hodnota V1.0.
- Jedna tabulka materiálů: `materialy.csv` (78 id) jako jediný zdroj, načítání podle id, kontrola (unikátní id 0–255, rozsahy, propustnost podle vzorce (log10 K + 9) / 6) (1.6). Konflikty starých seznamů se jen vypíšou, opraví se v kroku 3, kde se tabulka poprvé použije pro geologii.
- Pravidla determinismu na jednom místě: float64, řazené klíče, celočíselné hashe (`stable_hash.gd`, main) (1.5).

**Odkud kód:** `e94-metry` 96f2310 (jednotky, litry, převod scény na metry), `main` 0e8aa00 (`stable_hash.gd`), `docs/sjednoceni/materialy.csv`.

**Proč tady:** všechny další kroky používají jednotky, rozměry, id materiálů a verzi. Kdyby se měnily později, přepisovalo by se všechno nad nimi.

**Stav:** částečně. Jednotky a litry hotové na `e94-metry` (mimo main). Rozměry V1.0, verze a načítání tabulky jen rozhodnuto. Výška sloupce je dnes natvrdo 32 m (`BH` 64).

**Testy**
1. *Výchozí hra beze změny* (`tools/voda_e66.gd`, `tools/port_studie.py --check`): otisk d7aedf3a6d9d10e8 → 63d7b89a91385a79 a 0 neshod; port 0 změn. Prošlo = obojí shodné.
2. *Jednotky* (`tools/jednotky_e89.gd`, `tools/litry_e94.gd` z `e94-metry`): tam a zpět pro hustoty 16–128, l → m³ bez rozdílu bitů. Prošlo = 0 chyb, 0 rozdílných bitů.
3. *Rozměry V1.0* (nový `tools/zaklad_v1.gd`): všechny kombinace výšky 32/64/128 a segmentu 8/16/32 projdou kontrolou, neplatné (např. blok 100 m) se odmítnou; index buňky tam a zpět na celém segmentu při sloupci 128 m. Prošlo = 0 chyb, neplatné kombinace odmítnuté.
4. *Verze* (`zaklad_v1.gd`): čtení a porovnání `V1.0 < V1.1 < V2.0`, chybný zápis odmítnut. Prošlo = všechny případy správně.
5. *Tabulka materiálů* (`tools/materialy_v1.py`): unikátní id, rozsahy, vzorec propustnosti, porovnání se `sdilene/materialy_voda.json` v4. Graf propustnosti podle materiálu (PNG). Prošlo = 0 chyb tabulky; nalezené konflikty se jen vypíšou do reportu.
6. *Determinismus*: dva procesy Godotu dají stejný hash rozměrů, verze a tabulky. Prošlo = shoda.

**Velikost:** malý (1–2 h práce agenta).

---

## Krok 2 – Funkce světa I: rozhraní, mapy, reliéf, masiv a sopky

**Obsah**
- Jedno rozhraní funkce světa v metrech: dotaz na bod `(x, y, z)` → materiál, dotaz na sloupec `(x, y)` → povrch, hranice vrstev, hladina (2.2). V kroku 2 vrací povrch a biom, vrstvy a hladinu doplní kroky 3 a 4 bez změny rozhraní.
- Mapa biomů (varianta C) a mapa hornin: hrubé body ze seedu na maximální ploše 4096 m, plynulá interpolace (2.1, 1.7.1).
- Reliéf z parametrů členitosti podle biomu: převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu (1.13). Žádné šablony povrchu, `p94_hora_k` ani omezovač E92 (1.4).
- Masiv E87 a podhůří u jeho stěny jako součást funkce (1.4, úkol 10 v kap. 3).
- Sopky: počet a rozteč jako parametry světa, polohy ze seedu, tvar mezi strato a štítovou (sklon ~17°), velikost mezi 20 m / 1 blok a 40 m / 2 bloky, kráter, vrchol aspoň 5 m pod okrajem sloupce (1.14).

**Odkud kód:** `lod90.gd` (`h_m`, E90/E96, větve `e95-async-voda` a `e96-blok128`), masiv `geo2.gd` + `geo_fn.gd` z `e87-jadro-hory` ff97a9f, sopka a biomy z `teren/svet/hruby_teren.gd` (E49, main), `blok96.gd` (E96) jako vzor sestavení bloku 128 m z funkce.

**Proč tady:** povrch a biom jsou vstup pro geologii (vrstvy podle terénu), vodu i vegetaci. Musí být hotové a pevné dřív než cokoli, co z nich čte.

**Stav:** částečně. Výšková funkce existuje (E90/E96), masiv jako funkce (E87, jen na větvi), sopka jen jako kužel E49. Mapa biomů a hornin podle 2.1 jen rozhodnuto.

**Testy**
1. *Spojitost*: výška na hranici bloků a segmentů bez skoku (rozdíl 0 m). Obrázek řezu přes šev (`tools/rez_profil.py`). Prošlo = 0 skoků.
2. *Sklony*: histogram sklonů (p50, p95, max) proti stropu sklonu (graf PNG). Prošlo = max ≤ strop + tolerance kvantování.
3. *Sopky*: počet = parametr, rozteč ± tolerance, vrchol ≤ okraj sloupce − 5 m, kráter na vrcholu. Mapa výšek s vyznačenými sopkami (PNG). Prošlo = všechna kritéria.
4. *Mapy biomů a hornin*: obrázek map na 4096 m a výřez 3 × 3 (`blueprint-studie/tools/gif_svet8.py` jako vzor). Prošlo = plynulé přechody, různé seedy dají různé mapy.
5. *Determinismus*: hash mřížky výšek 3 × 3 ze dvou procesů. Prošlo = shoda.
6. *Čas*: dotaz na sloupec a výšky bloku 128 m (graf). Kritérium jen záznam, cíl je srovnání s E90 (4,9 s / 3 km).

**Velikost:** střední až velký.

---

## Krok 3 – Funkce světa II: geologie a útvary

**Obsah**
- Pásma vrstev z úrovní 0–40 (`poradi_hornin.json`), 1–3 zástupci podle mapy hornin, vrstvy podle tvaru terénu, vyklínění, mocnost min. 0,5 m (2 buňky) a max. 1/4 výšky (1.7, 1.7.1).
- Mince E82 (jeskynní a hluboký vápenec a dolomit 50/50 až 2 m pod hladinu) a vyklínění jílu nad ní (1.8).
- Útvary jako funkce celého světa přes švy (SDF z hashe světové mřížky, E84): žíly, pně, skarny, dómy, kras, dutiny, minerály. `cavity_one` se ruší (1.7, 2.1).
- Sopka uvnitř: průduch id 75 od kráteru po z = 0, kuželovité slupky lávy a popela, těleso vrstvy propíchne (1.14).
- Oprava konfliktů id v tabulce materiálů a přemapování pásem krajiny id 57–74 (úkol 5 v kap. 3).

**Odkud kód:** `geo_fn.gd`, `strata.gd`, `geo2.gd` (main, E87), nástroj `tools/implicit_e84.gd` (SDF, `zkusebni-vse`), `tools/vapenec_e82.gd` a změny E82 (`e82-vapenec-hladina`), `tools/tenke_e81.gd`, `minerals.gd`, `hostitele.gd`, `tridy.gd` (main).

**Proč tady:** geologie potřebuje povrch z kroku 2 a sama je vstupem pro podzemní vodu (propustnost, hladina) v kroku 4. Mapování materiálů se opraví tady, protože tu se tabulka poprvé opravdu používá.

**Stav:** částečně. Vrstvy a klíny jsou v pipeline, ale po segmentech a s mřížkou sousedů. SDF útvary jen jako studijní nástroj E84. Mince E82 na větvi. Průduch a slupky sopky jen rozhodnuto.

**Testy**
1. *Řezy*: svislé řezy přes šev bloků, přes masiv a přes sopku (`tools/rez_gif.py`, `rez_profil.py`, `rez_data.gd`). Prošlo = vrstvy přes šev spojité, u sopky končí na tělese, průduch dosahuje z = 0.
2. *Tenké vrstvy*: počet vrstev tenčích než 0,5 m po ořezu povrchem (`tenke_e81.gd`). Prošlo = 0 v definici; zbytky po ořezu se jen vypíšou.
3. *Útvary přes šev*: stejný útvar z obou stran švu, stejná dutina při dotazu z různých bloků (`implicit_e84.gd`). Prošlo = 0 rozdílů.
4. *Mince vápence*: podíl bloků „ano“ (`vapenec_e82.gd`). Prošlo = 50 % ± statistická odchylka na 3 × 3 a víc seedech.
5. *Čas*: ms na segment (graf proti E84 ~89 ms). Kritérium jen záznam.
6. *Determinismus*: hash materiálů na mřížce 3 × 3 ze dvou procesů. Prošlo = shoda.

**Velikost:** velký.

---

## Krok 4 – Funkce světa III: podzemní voda a prameny

**Obsah**
- Hladina podzemí a propustnost jako funkce geologie, bez uložených buněk (1.2, 2.5). Výchozí model podzemí E67 (1.8).
- Prameny ze seedu: druhy, poloha, jmenovitý výkon; skutečný výkon omezený okolím; jednoduchý model výchozí, tlakový pod přepínačem (1.8).
- Artéská voda jako funkce sevřené vrstvy, jen ověřit, „pokud to model zvládne“ (1.8.1).

**Odkud kód:** `voda/podzemi/gw74.gd`, `ug67.gd`, `ug_funkce.gd`, `voda/prameny.gd` (main), převod litrů z kroku 1.

**Proč tady:** voda potřebuje geologii z kroku 3 a sama ještě nepotřebuje buňky. Je to poslední část funkce světa, takže krok 5 může vkládat blueprinty s kompletní funkcí.

**Stav:** částečně. `gw74`, `ug67` a `prameny.gd` jsou v main, ale pracují nad buňkami segmentu 8 m, ne nad funkcí světa. Jmenovitý výkon, tlakový model a artéská voda jen rozhodnuto.

**Testy**
1. *Hladina jako funkce*: mapa hladiny podzemí na 3 × 3 (PNG) a řez s hladinou (`rez_profil.py`). Prošlo = hladina spojitá přes švy, nikde nad povrchem mimo prameny a jezera.
2. *Prameny*: počet, druhy, žádný na okraji ostrova, výkon ≤ jmenovitý a ≤ propustnost okolí (tabulka). Prošlo = všechna pravidla.
3. *Artéská voda*: aspoň jeden případ sevřené vrstvy, tlaková výška = výška doplňování. Neprošlo = zapíše se jako „model nezvládne“, ne chyba.
4. *Determinismus*: hash hladiny a seznamu pramenů ze dvou procesů. Prošlo = shoda.

**Velikost:** střední.

---

## Krok 5 – Vložení blueprintu a ostrov

**Obsah**
- Objekty Source, Transform, Placement (E88): ostrov = seed + parametry + verze + seznam vložení v pořadí. Vložení nese souřadnice blueprintu ve světě, zrcadlení, otočení, výškový posun, režim napojení, seed a verzi zdrojového světa (1.4, 2.2).
- Inverzní transformace: dotaz na vložený blok se přepočte do souřadnic zdroje (2.2, E86).
- Napojení jen po stranách, rohy se neřeší (5.1). Výchozí režim Auto (rozdíl ≤ 6 buněk rampa na 3 buňkách, větší útes, po sloupcích), volitelně Blend 1–4 a Keep (5.2). Vrstvy se na švu zaklíní na 1/16 bloku (1.7.1).
- Sousedé se při vložení nemění.

**Odkud kód:** `teren/otoceni86.gd` a `tools/otoceni_e86.gd` (`e86-otoceni-90`), režimy napojení z `block_gen.gd` (`BLEND_MAX` 6, main) a `island.gd` (výběr režimu stran), `teren/sides.gd`, návrh objektů `navrhy/navrh-terrainsource-kontrakt.md` (`e88-kontrakt-navrh`).

**Proč tady:** vložení pracuje nad hotovou funkcí světa (kroky 2–4) a ještě nepotřebuje buňky. Krok 6 pak vzorkuje už vložený, napojený blok.

**Stav:** částečně. Otočení hotových dat změřené (0 neshod), dotaz inverzní transformací jen v nástroji E86. Režimy Auto / Blend / Keep jsou v prototypu jen pro povrch. Zrcadlení neměřeno. Objekty E88 jen návrh.

**Testy**
1. *Inverzní transformace*: otočený a zrcadlený blok dá na stejný dotaz stejnou odpověď jako originál (`otoceni_e86.gd`, rozšířit o zrcadlení). Prošlo = 0 neshod pro rot 0–3 × zrcadlení.
2. *Režimy švu*: řez přes šev pro Auto, Blend 1–4 a Keep (obrázek, `rez_profil.py`). Prošlo = Auto: rozdíl ≤ 6 buněk dorovnán na 3 buňkách, větší zůstane; Blend: rampa na zvoleném počtu; Keep: beze změny; sousedé beze změny (0 buněk).
3. *Pořadí vložení*: blok závisí jen na sousedech na 4 stranách položených před ním (`determinismus_e83.gd`). Prošlo = roh a vzdálený blok mění 0 buněk, dva procesy shodně.
4. *Cizí svět*: vložení blueprintu s jiným seedem a verzí. Prošlo = načte se a napojí bez chyby.

**Velikost:** střední.

---

## Krok 6 – Buňky: slupka, kopání, rozdíl a ukládání

**Obsah**
- Generuje se jen zorné pole + okraj (parametr) a slupka 2–3 buněk u vzduchu a pod průhlednou vodou, buňka 0,25 m přímo z funkce (1.2, 2.3).
- Obnažená buňka sousedí se vzduchem nebo je dnem průhledné vody. Hlubší buňky se donačtou při odkrytí (2.3).
- Kopání po 0,25 m (úkol 8 v kap. 3). Zákaz prokopání dna a okraje (`p85_okraj`, 1.13.1).
- Ukládá se jen rozdíl proti funkci po segmentech 8 m: překryv E78 (klíče + deflate), hlavička WTI1 s `gen_ver`, transformací a pořadím (2.4). Ostrov se uloží a načte jako seed + parametry + verze + seznam vložení + rozdíl (1.4, 1.10).
- Pole „původní materiál“ (+1 B) se v překryvu jen připraví za přepínačem, vypnuté, dokud nebude zapsané 6.1.

**Odkud kód:** `teren/prekryv78.gd` a `tools/prekryv_e78.gd` (`e78-prekryv` / `zkusebni-vse`), slupka z E90 (`lod90.gd`, výpočet „vrchní buňka + 2 pod ní“), `p85_okraj` (`e85-blok2-rozhodnuti`, `tools/okraj_hra_e85.gd`), formát WVB1 (`navrhy/format-bloku-wvb1.md`), hlavička WTI1 (E88).

**Proč tady:** buňky vznikají až z hotového vloženého bloku (krok 5). Simulace vody (krok 7) a vegetace (krok 8) potřebují buňky a uložený rozdíl.

**Stav:** částečně. Překryv E78 hotový na studijní větvi. Slupka jen pro výšku (E90). Hra kope po 0,5 m a vzorkuje celý sloupec. Zákaz dna a okraje hotový na větvi E85.

**Testy**
1. *Slupka*: počet buněk a čas slupky v zorném poli + okraj (graf podle velikosti okraje). Prošlo = žádná neobnažená buňka mimo slupku, každá obnažená ve slupce.
2. *Donačtení*: po výkopu se nové buňky shodují s funkcí. Prošlo = 0 rozdílů.
3. *Rozdíl*: velikosti překryvu (prázdný ostrov, 1 buňka, chodba 70 m, jeskyně) proti E78 (`prekryv_e78.gd`, graf). Prošlo = prázdný ostrov = jen hlavičky; chodba 70 m řádově ~244 B.
4. *Uložit a načíst*: ostrov po výkopech se uloží, načte a dá bitově stejné buňky. Prošlo = shoda hashů.
5. *Dno a okraj*: počet děr ve dně a okraji po náhodném kopání (`okraj_hra_e85.gd`). Prošlo = 0.
6. *Paměť*: RSS bez scény na bloku 128 m (graf proti E96 345 MB). Kritérium jen záznam.

**Velikost:** velký.

---

## Krok 7 – Voda na ostrově: simulace, eroze, přepočet

**Obsah**
- Výchozí podzemí E67 a kras E75 zapnutý (úkol 9 v kap. 3).
- Pravidla vsakování 1.8.1: zrušit násobitel `p71_cas` × 24, spád včetně výšky vody, spojení materiálů = minimum, boční tok X × spád (úkoly 1–3).
- Eroze: `e51_k` = 1,5 (úkol 4) a eroze jako samostatná vrstva posunu výšky nad funkcí, ne změněné buňky (4.1). Voda počítá na terénu s posunem.
- Přepočet: lokální = plný na sjednoceném povodí (oprava K5 včetně `p79_chodby` a `p85_voda`), asynchronně na pozadí, prodleva 2 s, strop 10 s, fronta výkopů (1.9, úkoly 6–7).
- Slučování výtoků pod prahem 0,1 l/s (laditelný parametr) v dosahu 8 m, i mezi sebou (3.2).
- Výchozí voda v ustáleném stavu po vygenerování, uloží se jen odchylka v celých litrech, rozsah 0–15,625 l (1 B) (2.5, 1.10).

**Odkud kód:** `voda/hydro68.gd`, `ostrov_voda.gd`, `ug67.gd`, `kras75.gd`, `prameny.gd`, `eroze/mech.gd` (main), `voda/async95.gd` a `tools/async_e95.gd` (`e95-async-voda`), `tools/chodby_e79.gd` (`e79-chodby-voda`), slučování E72 (`p72_*`, main).

**Proč tady:** simulace potřebuje buňky a rozdíl z kroku 6. Eroze jako posun výšky potřebuje hotovou vodu. Vegetace (krok 8) potřebuje znát tůně a koryta.

**Stav:** částečně. E67, kras, E68 a E72 jsou v main (E67 a kras vypnuté). Asynchronní voda jen na `e95-async-voda`, nikdy neběžela s blokem 128 m. K5 neopravené. Eroze dnes mění buňky (`mech.gd`), vrstva posunu jen rozhodnuto.

**Testy**
1. *Lokální = plný* (`voda_e66.gd` s chodbami a vyšší horou, scénáře E94 a E95). Prošlo = 0 neshod (dnes 162 a 43/38).
2. *Bilance*: součet přítoků a odtoků. Prošlo = ≤ 1e-12 l/s.
3. *Asynchronní běh*: blokování hlavního vlákna a čas do výsledku (graf, `async_e95.gd`). Prošlo = blokování < 1 ms; výsledek po frontě shodný s plným výpočtem.
4. *Scénář „dva hráči“*: časová řada průtoku v korytě po ucpání pramene (graf). Prošlo = voda nezmizí naráz, odtéká postupně, tůně zůstanou.
5. *Výtoky*: počet výstupů před a po slučování (E72: 150 → 6 → 18). Prošlo = součet průtoku beze změny, drobné výtoky v dosahu 8 m sloučené.
6. *Eroze*: vypnutí vrstvy posunu vrátí terén bitově na funkci; řez koryta po erozi (obrázek). Prošlo = shoda po vypnutí.
7. *Ustálený stav*: po vygenerování se voda bez zásahu nehýbe. Prošlo = 0 změn za N tiků.
8. *Determinismus*: otisk vody v celých litrech ze dvou procesů. Prošlo = shoda.

Výchozí hra se tu mění záměrně. Vznikne nová reference otisku `voda_e66`.

**Velikost:** velký.

---

## Krok 8 – Vegetace jako funkce a vrstva změn

**Obsah**
- Základní porost je funkce seedu, souřadnic původu, materiálu, sklonu a výchozí vody. Hustota na m², pravidlo pro každý biom, v tůních se nevysazuje, vyhodnocuje se jen ve slupce (2.6, 1.12).
- Ukládají se jen změny (vykácení, výsadba, růst) po segmentech. Vrstva se dá vypnout a terén na ní nezávisí.

**Odkud kód:** `veg.gd` a `teren/zaklad/veg.gd` (main, převod souřadnic `_to_src`), `tools/veg_stats.gd`.

**Proč tady:** vegetace čte povrch, materiál a vodu, tedy výsledky kroků 2–7. Nic jiného na ní nezávisí, takže nic nebude potřeba opravovat.

**Stav:** částečně. `veg.gd` je deterministický, ale hustota je na sloupec podle receptu a recept `hora_vyzdvizena` chybí.

**Testy**
1. *Hustota na m²*: stejný počet rostlin na m² při buňce 0,5 i 0,25 m (`veg_stats.gd`, graf podle biomu). Prošlo = rozdíl v toleranci náhody.
2. *Biomy*: každý biom včetně masivu a sopky má nenulový porost. Prošlo = žádný holý biom.
3. *Tůně*: počet rostlin ve vodě. Prošlo = 0.
4. *Otočení*: vložený otočený blok má porost ve stejných zdrojových bodech. Prošlo = 0 rozdílů.
5. *Nezávislost*: vypnutí vegetace nezmění otisk terénu ani vody. Prošlo = shoda.

**Velikost:** malý až střední.

---

## Krok 9 – Povinný test 3 × 3 a uzavření V1.0

**Obsah**
- Svět 3 × 3 bloky → řez na 9 blueprintů → ostrov (náhodné pořadí, otočení, zrcadlení, aspoň jeden blueprint z jiného světa). Tři režimy spuštění: celý, jen svět, jen ostrov (2.7).
- Měření do PROP: svět, řez, vložení, slupka, donačtení, rozdíl, voda, determinismus, paměť, segment 8 / 16 / 32 m.
- Uzavření verze V1.0 (tag), nová reference výchozí hry.

**Odkud kód:** výsledky kroků 1–8, `tools/blok128_e96.gd` a `tools/zkusebni_e95.gd` jako vzor měřicího běhu.

**Proč tady:** test ověřuje celý řetězec najednou, takže dává smysl až po všech datových krocích.

**Stav:** jen rozhodnuto, není postavený.

**Testy**
1. *Celý řetězec*: tři režimy doběhnou. Prošlo = bez chyby.
2. *Determinismus*: dva běhy a dva procesy, shoda buněk a vody. Prošlo = shoda hashů.
3. *Ustálená voda po generování*. Prošlo = 0 změn bez zásahu.
4. *Grafy*: časy kroků, paměť, velikost rozdílu, podíl tůní (proti 22 % v E96), segment 8 / 16 / 32 m. Kritérium jen záznam, doporučení velikosti segmentu pro Jana.

**Velikost:** střední. **Potřebuje Janovo ano** ke sloučení do main.

---

## Krok 10 – Kontrakt se serverem (s Willage-backend)

**Obsah**
- Kontrakt podle 1.10: server ukládá seed, parametry, verzi, seznam vložení a rozdíl; namátková kontrola generátorem jde vypnout.
- 6.1 (původní materiál +1 B na změněnou buňku, snímek buněk volitelný) a 6.3 (mazání ověřených dat, ponechání rozporů).
- Testovací vektory pro port generátoru do C# (determinismus .NET).

**Odkud kód:** WVB1 a návrh E88, formát rozdílu z kroku 6, vektory `godot-prototyp/vectors`.

**Proč tady:** formát rozdílu musí být hotový a ověřený testem 2.7, aby se backendu nedával pohyblivý cíl. Krok nezasahuje do generátoru, jen ho čte.

**Stav:** otevřené. 6.1 je s Janem domluvené v chatu, ale pole **Platí:** je prázdné (čeká na zápis). 6.3 čeká na Willage-backend. Návrh E88 s backendem neprojednaný.

**Testy:** testovací vektory (stejný hash v GDScriptu a C#), bilance materiálu bez generátoru z +1 B, simulace mazání ověřených buněk. Kritéria se doplní po dohodě s Willage-backend. Do Willage_Dev zapisuje jen Willage-backend.

**Velikost:** neurčeno. **Potřebuje Jana a Willage-backend.**

---

## Krok 11 – Prezentace

**Obsah**
- Vykreslení čte jen data. Pevný zoom 64 voxelů 0,25 m napříč, jedno rozlišení bez LOD (2.3, 7.2).
- Bok ostrova jako jednoduché bloky s texturou do 5 m pod nejnižší okrajovou buňkou, oblaka, voda padá do oblak (1.13.1).
- Průhlednost (válec od postavy ke kameře s mřížkou) a řez z prototypu, každý s vlastním přepínačem, výchozí vypnuto (7.3).
- Měřítko vegetace 0,5, jednotka scény 1 m.
- 2D nebo 3D (7.1) zůstává odložené; do rozhodnutí se použije stávající renderer prototypu.

**Odkud kód:** `game/pruhlednost91.gd` a `tools/pruhlednost_e91.gd` (`e91-pruhlednost`), mesher a `surface/` (main), `p94_meritko_veg` (`e94-metry`).

**Proč tady:** prezentace jen čte data, takže změna vykreslení nikdy nevynutí opravu datových kroků.

**Stav:** jen rozhodnuto (průhlednost a řez hotové na větvi E91, vypnuté). 7.1 odloženo.

**Testy:** snímky výchozího záběru (64 voxelů napříč), snímek boku ostrova a oblak, s přepínači průhlednosti a řezu vypnutými i zapnutými. Prošlo = při vypnutých přepínačích se otisk dat ani snímek výchozí hry nezmění.

**Velikost:** střední.

---

## Postup implementace

1. Kroky se dělají **striktně po jednom v pořadí 1 → 11**. Žádné přeskakování.
2. Každý krok má **vlastní novou větev** `gen-v1-krokNN-<název>`, vytvořenou z větve předchozího schváleného kroku (krok 1 ze `sjednoceni`).
3. Před experimentem se napíše krátký **PROP** do `docs/sjednoceni/reporty/` (nebo do PROP kroku). Výsledky se do něj zapíšou i když jsou negativní.
4. Malé logické commity, push jen na větev kroku. Žádné CI ani GitHub Actions, žádné zálohy složek.
5. Po každém kroku vznikne **report** `docs/sjednoceni/reporty/krokNN.md`: co se udělalo, odkud je kód, výsledky testů s čísly, cesty k obrázkům a grafům v repu.
6. Po reportu se čeká na **Janovo schválení**. Teprve pak začne další krok (hlídání usage, modely na Slow).
7. Do `main` jen s Janovým výslovným ano (nejdřív po kroku 9).
8. Krok 10 jen společně s Willage-backend.

---

## Příloha A – Kontrola rozporů a chybějících rozhodnutí

Nic z toho není rozhodnutí. Jde o návrhy úprav textu nebo otázky pro Jana. Obsah polí **Platí:** se tu nemění.

### A.1 Rozpory

1. **Velikost buňky v datech: 0,5 m, nebo 0,25 m?** **Rozhodnuto (Jan 2026-11-21 00:19):** datová buňka je **0,25 m**, stejně jako viditelný voxel a dlaždice (1.1, 2.3, 7.2). Segment 8 m = 32 × 32 buněk, blok 128 m = 512 × 512, sloupec 128 m = 512 buněk. Plná buňka vody je 15,625 l. Výřez okna je malý (pevný zoom 64 dlaždic), delší jsou jen vstupní výpočty. Starý návrh „definice a voda po 0,5 m, kopání po 0,25 m“ se nepoužije.
2. **Voda v buňce 0–125 l platí jen pro buňku 0,5 m.** **Vyřešeno s bodem 1:** u buňky 0,25 m je rozsah **0–15,625 l** a plocha stěny **0,0625 m²** (1.8.1, 1.10). Zůstává otevřené, jak skloubit maximum 15,625 l s krokem 1 l v 1 bytu.
3. **Voda v m³, nebo v celých litrech?** `01` 1.8: „Ukládá se v m³ na buňku“; 1.10: „celé číslo litrů (pevný krok 1 l)… v 1 bytu“. Návrh: 1.8 = jednotka výpočtu, 1.10 = uložený tvar; doplnit odkaz.
4. **Ukládání hotových dat segmentů (zastaralé, ale nepřeškrtnuté).**
   - `01` 1.4: „Segmenty uvnitř blueprintu vzorkují svou část funkce do buněk 0,25 m a ukládají výsledná data, ne funkci.“ (velikost buňky už je 0,25 m). O tři odrážky níž: „Tím se mění předchozí bod“ (uložení jen rozdílu, tohle zůstává zastaralé).
   - `01` 1.10: odrážka „Přenos dat… hotová data segmentu“ a „server pak jen ukládá a kontroluje bilanci materiálu“, níže „Změněno… nahrazuje odrážku Přenos dat“.
   - `01` 1.12: „Terén (s vodou) a rostliny se ukládají po segmentech… protože pocházejí z blueprintu“.
   - Návrh: přeškrtnout nebo označit „nahrazeno (t801u–t803u)“, aby se při implementaci nečetla stará verze.
5. **Napojení švů: funkce, nebo dorovnání?** `01` 1.4: „prolnutí švů je funkce sousedů“, ale v téže kapitole „sousedé na ostrově se napojují dorovnáním okrajů, ne funkcí“. Návrh: sjednotit na „dorovnání podle režimu 5.2 (Auto výchozí)“.
6. **Blend v 5.2: klín 1/16 bloku, nebo 1–4 buňky?** `03` 5.2, tabulka: „Blend (klín 1/16 bloku, 1.7.1)“ a doporučení „Výchozí Blend: klín… 1/16 bloku“; **Platí:** „Blend (dorovnat na 1–4 buňkách)“. Klín 1/16 bloku z 1.7.1 je pro vrstvy, Blend 1–4 pro povrch. Návrh: v textu oddělit napojení povrchu (Auto / Blend / Keep) a napojení vrstev (klín 1/16 bloku).
7. **Auto „6 buněk“ a „3 buňky“** pochází z prototypu s buňkou 0,5 m (3 m a 1,5 m). Bod 1 je rozhodnutý (buňka 0,25 m); pořád chybí, jestli Auto zůstane 6 a 3 buňky (teď 1,5 m a 0,75 m), nebo 3 m a 1,5 m (12 a 6 buněk).
8. **Eroze jako posun výšky (4.1) a kras.** `01` 1.8 a 1.8.2: kras E75 vzniká erozí během hry a „rozpouští se podle průtoku“ v podzemí; 1.8.2 má i usazování pod `sed_v`. Posun výšky povrchu nepopisuje dutinu pod povrchem ani usazeninu nad funkcí. **Chybí rozhodnutí:** kam se ukládá kras během hry (překryv, nebo jiná vrstva) a zda posun může být kladný (usazování).
9. **Mlha, nebo oblaka?** `01` 1.8: „voda padá jako vodopád do mlhy“; 1.13.1 **Platí:** „Voda z okraje dál padá do oblak“. Návrh: sjednotit na oblaka.
10. **Vegetace: s blokem, nebo jen ve slupce?** `01` 1.12: „Základní vegetace se generuje s blokem ze seedu“; `02` 2.6: „Vyhodnocuje se jen ve slupce“. Návrh: v 1.12 doplnit odkaz na 2.6.

### A.2 Zastaralé texty

1. Hlavičky `01`, `02`, `03`: „Stav: kostra… Pole Platí: je prázdné… Do té doby nic z tohoto souboru neplatí“. Návrh: „rozhodnuto (kromě 1.5 přepočtu, 1.11, 6.1, 6.3, 7.1)“.
2. `README.md` tabulka souborů: `03` „kostra, čeká na Jana“. Seznam „Pořadí otevřených bodů“ v `README.md` i v `03` stále vypisuje rozhodnuté body 6.2, 4.1, 5.1, 5.2, 3.2, 7.2, 7.3. Návrh: nechat jen 6.1, 6.3, 7.1 a přidat `04`.
3. `03` 3.2, současný stav: „Slučování mezi sebou… Jan ještě nerozhodl“. Návrh: „rozhodnuto, viz Platí“.
4. `03` 5.2, současný stav: věta o Auto je už opravená, ale doporučení „Auto zatím nezavádět“ zůstalo. Návrh: označit jako nahrazené rozhodnutím.
5. `03` 7.2, současný stav a varianty: pásma LOD E90 (16 / 48 m), „blízko 0,25 m, dál 0,5 m“. Platí ruší LOD. Označeno jako historie; datová buňka je 0,25 m (2026-11-21 00:19).
6. `02` 2.3: „Viditelnou oblast určuje prezentace podle zoomu“ vedle „zoom je pevný“. Není to rozpor v datech, ale věta o zoomu je zastaralá. Návrh: „podle pevného zoomu (64 voxelů)“.
7. `02` 2.2: „Zbylé otázky E88 (3, 4, 6, 7, 8, 11) patří do kapitol 3, 5 a 6.“ Otázka 8 je vyřešená v 1.9 (bod 3.1 zrušen), 6, 7 a 11 jsou rozhodnuté. Návrh: „zbývá 4 (6.1), 3 je odložená s 1.5“.
8. `01` 1.2: „Hra pořád kope po 0,5 m“ a odkaz na rozhodnutí 03:26 jsou historie; v pořádku, jen označit.
9. Starý práh 0,025 l/s v textu nezůstal. Hodnota 0,025 l/s v 1.8.1 byla propustnost písku při buňce 0,5 m; po 2026-11-21 00:19 je u buňky 0,25 m 0,00625 l/s. Odkazy na zrušené body 3.1 a 8.1 zůstaly jen jako poznámka „bod zrušen“, v pořádku.
10. `03` Úkoly implementace neobsahují nová rozhodnutí z hovoru: vrstva posunu eroze (4.1), Auto jako výchozí (5.2), slučování pod 0,1 l/s i mezi sebou (3.2), `gen_ver` V-tvar (6.2), přepínače průhlednosti (7.3). Jsou zařazené v krocích 1, 5, 7 a 11 tohoto dokumentu.

### A.3 Chybějící rozhodnutí

1. **6.1** – Jan souhlasil v chatu (+1 B původního materiálu na změněnou buňku, snímek jen pro ladění), pole **Platí:** je prázdné. Čeká na zápis.
2. **6.3** – návrh Jana zapsaný, **Platí:** prázdné. Čeká na Willage-backend.
3. **7.1** – 2D, nebo 3D: odloženo. Datový model na tom nezávisí.
4. **1.5** – přepočet světa při nové verzi generátoru: odloženo (t726u).
5. **1.11** – datový rozpočet: přeskočeno (t738u).
6. Velikost buňky dat (A.1 bod 1) je rozhodnutá (0,25 m, Jan 2026-11-21 00:19). Kras / usazování ve vrstvě posunu eroze (A.1 bod 8) pořád potřebuje potvrzení. Auto 6 / 3 buňky (A.1 bod 7) a krok vody 1 l při maximu 15,625 l také.
