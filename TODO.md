# TODO (Willage studie)

Seznam nápadů a úkolů, které čekají na Janovo rozhodnutí nebo na zařazení. Hotové položky se odškrtnou a odkáží na commit nebo tag.

## Pořadí práce po blocích (Jan 2026-11-19 22:44)

Nejdřív se dořeší všechno s vodou, pak další bloky. V rámci bloku se nepřeskakuje na jiné téma.

1. **Voda:** ~~slučování~~ → ~~E68~~ → ~~nálezy E68 (E73)~~ → ~~plocha `gw` (E74)~~ → ~~kras (E75)~~ → ~~voda po přenosu (E76)~~ → ~~čas hry 1 den = 1 h (E77)~~. **Blok vody hotový**; E74–E77 sloučené (větev `voda-e74-e77-slouceni`, tag `voda-e74-e77-ready`, Jan 2026-11-20 03:26): zapnuté `p74_gw`, `p74_vyzvednout` + `p74_hladina`, `p76_prameny`, limit slučování 8 m; E75 a studie těžby berou čas z `cas_hry.gd`.
2. **Model světa a kopání:** překryv změn po kopání + hash → kde končí funkce a pásma → tenké vrstvy a převzorkování → determinismus celého světa → rešerše implicitní geologie.
3. **Geologie bloků a přenos výřezu:** otočení výřezu po 90° → jádro vyzdvižené hory přes více bloků → `TerrainSource` a datový kontrakt (jen návrhy, s Willage-backend).
4. **Měřítko a zobrazení:** oddělené typy jednotek v kódu → plán vzorkování a LOD (test 3 × 3 km) → průhlednost překážek v izometrii → test měřítka v izometrii a blok 128 m → výkon na telefonu.
5. **Janovo rozhodnutí:** charakter krajiny.

## Voda

- [x] **E68 – sjednocení výpočtu povrchu a podzemí (hydrologický orchestrátor).** Podnět: konverzace s ChatGPT 2026-11-19 ([sdílený chat](https://chatgpt.com/share/6aff2aa3-865c-83ed-a19c-63720302f8cf)). Hotovo (tag `e68-orchestrator`, větev `e68-orchestrator`): modul `hydro68.gd`, `p68_hydro` zapnuto, kola do ustálení (max 64), bilance a otisk; smyčka tůň→průsak→pramen chyba 61 % → 0; ostrov bitově stejný.
  - Jeden společný krok pro povrch, podzemí, tůně, prameny a události: sdílená vodní bilance, jedno pořadí výpočtů a jedno místní přepočítání po změně terénu.
  - Algoritmy zůstávají: povrch priority-flood + D8, podzemí pásma a tělesa (E58 A+B+C, E67).
  - Pořadí: terén a geologie → povrch a podzemí → vodní bilance → události → místní invalidace.
  - Ohlídat smyčku rybník → průsak → pramen → rybník: předávání vody oběma směry s limitem počtu kol, zachování hmoty, deterministický výsledek (hash).
  - Postup: nejdřív krátký návrh (PROP), pak větev s měřením.
- [x] **Harmonický průměr propustností** – ověřeno v E70 (tag `e70-harmonicky`). Jen přepínač `p70_prumer`, výchozí zůstává prostý poměr: na ostrově beze změny, brzdění splní jen jedním směrem. Zapnout spolu s kapacitou vrstev.
- [x] **Test symetrie a referenční test** – hotovo v E69 (tag `e69-symetrie`, větev `e69-symetrie-test`, nesloučeno). Bilance přesná (chyba ≤ 1e-12 l/s). Nalezena a opravena nesymetrie při shodných váhách větví (`p69_remizy`, rovný díl).
- [x] **Omezení průtoku dolů podle propustnosti vrstvy** – hotovo v E71 (tag `e71-kapacita`, větev `e71-kapacita-dolu`). Přepínače `p71_kapacita` a `p71_prusak` zapnuté ve výchozím stavu (jen nový výpočet podzemí E67), čas `p71_cas` = 144 (1 herní den = 10 min). Referenční sloupec: z každé vrstvy 0,2 l/s; kupole průsak 0,163 l/s (E58 0,176); ostrov 150 výstupů, kopnutí ~70 ms, 0 neshod.
- [x] **Slučování drobných výstupů z pastí** – hotovo v E72 (tag `e72-slucovani`): stejný práh `p67_prune_min` 0,1 l/s i pro cesty z E71 (`p72_slucovat`, `p72_prusak`); ostrov 150 → 6 výstupů, Σ 4,10 l/s zachováno; opravena chyba E71 (+0,317 l/s ve variantě přetok bez okraje).
- [x] **Pramen v prohlubni, kterou sám zavodní** – E73 (`p73_vyver`), ostrov bez cyklu, bilance 0.
- [x] **Odtok tůně ze součtu všech přítoků** – E73 (`p73_pritok`).
- [x] **Zrychlit pomalé smyčky** – E73 (`p73_zrychleni`), 68 → 17 kol.
- [x] **E67: rozlišit „zavřené“ a „vše prosákne“** – E73 (`p73_prusak_tok`).
  - E73: tag `e73-nalezy`, větev `e73-nalezy-e68`, výchozí zapnuto, sloučeno do main (Jan 2026-11-20 00:10). Opravena i chyba: plný výpočet bral z E67 jen hlavní výstup.
- [ ] **Měřit objem vody v `voda_e66`** (drobnost z E73).
- [x] **Jan rozhodl (2026-11-20 03:26):** slučovat i průsak tekoucí vody (`p72_prusak` zapnout) a omezit vzdálenost slučování výstupů na 8 m.
  - [x] Implementovat limit vzdálenosti slučování 8 m a zapnout `p72_prusak` – `p72_dosah_m` 8 (výchozí); `p72_prusak` byl zapnutý už od E72. Ostrov E67 (pretok + O): nejdál 19,3 → 16 sloupců (8 m), výstupů 6 → 18 (12 drobných po 0,02 l/s v řadě na okraji, dál než 8 m od silného), Σ 4,10 l/s beze změny, 0 neshod. Výchozí hra (E58) beze změny.
  - [ ] Jan: slučovat drobné výstupy v dosahu 8 m i mezi sebou (do největšího ze skupiny), když silný není blízko?

## Architektura světa

Podnět: druhá odpověď ChatGPT 2026-11-19 (Jan ji poslal do chatu). Jde o návrhy k posouzení, ne o rozhodnutí.

- [ ] **Datový kontrakt mezi generováním světa, geologií, vodou a změnami od hráčů.** Kdo vlastní která data, kdo je smí měnit a jak se změny šíří. Týká se i serveru, takže ve spolupráci s Willage-backend.
  - Funkce vrstev zůstávají jediným zdrojem pravdy o geologii. Buňky, kolize a vykreslování jsou z nich jen vzorkované. Stav vody, eroze a událostí je odvozený stav, který nemusí znovu vyhodnocovat geologické funkce.
  - Místo přímých volání mezi systémy typy změn (`SurfaceChanged`, `LayerBoundaryChanged`, `MaterialChanged`, `CavityCreated`, `CavityRemoved`, `HydraulicConnectivityChanged`) a resolver závislostí: každý systém deklaruje, na které změny reaguje. Navazuje na E68.
- [x] **Determinismus celého světa, nejen jednoho bloku.** Ujasnit `Hash(seed, změny, pořadí)`: u kterých operací pořadí nesmí hrát roli a u kterých ano (vykopat a zasypat). Navazování bloků je rozhodnuté (Jan 2026-11-17): sousedé se nikdy nemění, přizpůsobuje se jen nový blok. Pořadí pokládání tedy výsledek ovlivňuje záměrně; platí jen, že stejný výřez, transformace a sousedé dají stejný výsledek.
  - 🧪 E83 (tag `e83-determinismus`, nesloučeno, výsledky v PROP „E83 výsledky“): stejná definice + seed + překryv → bitově stejné buňky, překryv a otisky ve 2 bězích i 2 procesech; blok závisí jen na sousedech položených před ním (12/12, diagonála a vzdálený blok 0); pořadí vložení mění záměrně ~1,9 % buněk u švů; změny na různých buňkách nezávisí na pořadí. Opraven klíč mezipaměti podzemí (otisky beze změny). Jediná skutečná závislost na pořadí: výchozí lokální přepočet vody bez `p79_chodby`.
  - [ ] Jan: zapnout `p76_prameny` + `p79_chodby` jako výchozí (p76 už zapnutý při sloučení vody, p79 je na větvi E79)?
  - [ ] Jan: otisk vody – surové bity (shoda jen na stejné platformě), nebo zaokrouhlit kvůli serveru a telefonu?
  - [ ] Jan: má server opakovat buňky klienta bitově přesně? „Stejní sousedé“ jen 4 hrany, nebo i rohy?
- [ ] **Jádro vyzdvižené hory přes více bloků:** geologická kontinuita masivu přes švy.
- [x] **Tenké vrstvy a převzorkování mezi rozlišeními:** vrstva tenčí než buňka nesmí zmizet nebo se objevovat podle rozlišení.
  - 🧪 E81 (tag `e81-tenke`, nesloučeno, příznak `p81_tenke` vypnutý): vrstva > 0,05 m dostane aspoň jednu buňku. Chybění 60 % → 7,6 % (0,5 m), 48 % → 2,3 % (0,25 m); díry v nepropustné 64 % → 8 %. Vady: nafouknutí na celou buňku, 3 tenké vrstvy v jedné buňce 0,5 m (206 konfliktů).
  - [x] Jan rozhodl (2026-11-20 03:26): v blueprintu zakázat vrstvy tenčí než 25 cm.
  - [ ] Implementovat v blueprintu minimum tloušťky vrstvy 25 cm.
- [ ] **Výkon na telefonu:** hierarchie rozlišení (region, blok, sekce 16³ nebo 32³, jemné buňky jen u hráče), všechny úrovně ze stejných funkcí. Změřit generování bloku na slabém zařízení.

## Přenos terénu z průzkumného světa na ostrov

Podnět: třetí odpověď ChatGPT 2026-11-19. Dva světy se společnou geologií a vodou: velký průzkumný svět po chunkech a osobní ostrov (začíná na 4 blocích, nejvýš asi 16), který hráč rozšiřuje výřezy z průzkumného světa.

- [ ] **Výřez terénu jako samostatný přenositelný datový objekt:** `TerrainSource` (původní definice), `TerrainTransform` (otočení, svislý posun), `TerrainPlacement` (místo na ostrově), `TerrainInstance` (výsledek po napojení na sousedy). Navázat na formát bloku WVB1 a blueprint, ve spolupráci s Willage-backend.
- [ ] **Otočení výřezu po 90°:** ověřit, že funkce vrstev, minerály a dutiny se otočí bez rozdílu proti vygenerování na místě.
- [x] **Voda se nepřenáší hotová:** přenesou se zdroje, materiály a geometrie, stav vody se po vložení přepočítá v novém okolí a z ustáleného stavu se znovu naplánují události (příchod vody, plnění tůní, eroze).
  - 🧪 Ověřeno v E76 (tag `e76-prenos`, větev `e76-voda-po-prenosu`, nesloučeno): lokální vložení = plný výpočet (0 neshod, bilance 0) i s posunem ±4; přeplánování událostí jen dotčených sloupců 61–104 ms; uložení 4 bloků + 12 výkopů 524 B.
  - [x] Jan rozhodl (2026-11-20 03:26): zapnout `p76_prameny` a sloučit E74–E77 do main.
  - [x] Sloučeno a zapnuto (větev `voda-e74-e77-slouceni`): nové postavení i načtení ostrova = lokální stav (0 neshod), vložení výřezu lokálně = plně (0 neshod, bilance 0). `place76` nově obsazuje výtoky, staví plochu `gw` a dutiny krasu.
  - [ ] Po vložení stavět podzemí jen pro nový blok (dnes lokální vložení jen o 10–40 % rychlejší než plné).
  - [ ] Do datové smlouvy výřezu s backendem patří i uložené prameny a výkopy.

## Model světa a kopání

Podnět: čtvrtá odpověď ChatGPT 2026-11-19, popis je v [devlog/model-sveta.md](devlog/model-sveta.md).

- [x] **Přechod mezi funkcí, vzorkovanou buňkou a trvalou změnou po kopání:** definice zůstane, změny hráče jako překryv. Ujasnit vztah k WVB1, který dnes ukládá celé pole bloku. Malý experiment: vykopat chodbu, uložit jen překryv, znovu načíst a porovnat hash.
  - 🧪 Ověřeno v E78 (tag `e78-prekryv`, nesloučeno): `prekryv78.gd`, překryv = buňka 0,25 m → materiál, kanonický (rovno definici = smazat). Načtení = živý stav ve všech 6 scénářích. 1000 buněk 1,8 kB, chodba 70 m 244 B proti 13–17 kB pole. Poslední zápis na buňku vyhrává.
  - [x] Lokální přepočet vody nevidí chodbu se vstupem z povrchu – opraveno v E79 (tag `e79-chodby`, nesloučeno, příznak `p79_chodby` vypnutý): 0 neshod v 11 scénářích, bilance 0.
  - [ ] Zrychlit lokální přepočet (E79 jen o 10–35 % rychlejší než plný, ~1,1–1,5 s): přestavba pásem jen v dotčených sloupcích, menší okno přepočtu, přeskočit dutinu nesousedící s tělesem ani povrchem, přepočet po dávkách za herní tik.
  - [ ] Kopání v prototypu převést na 0,25 m přes `prekryv78` + `edit79`, pak zapnout `p79_chodby`.
  - [ ] Návrh pro WVB1 (Willage-backend): definice bloku + kanonický překryv místo celého pole, hash přes obojí, vodu neukládat.
- [x] **Kde končí funkce a pásma:** kritérium, kdy změna (převis, oblouk, nepravidelná jeskyně) potřebuje lokální oblast s plnými buňkami, a jak takovou oblast uložit (řídký objem, octree, komprimované intervaly).
  - 🧪 E80 (tag `e80-hranice`, nesloučeno): funkce platí do buňky 0,5 m, jemnější = překryv hráče. Uložení: seřazené klíče + komprese (nejmenší nebo ≤1,6×), octree/řídký objem zatím ne. Švy bez skoku, pořadí bloků nic nemění.
  - [ ] Voda: víc dutin v jednom sloupci jako víc pásem, případně podzemí po 0,25 m kolem výkopů (pásma nestačí u dvou dutin nad sebou a změn jemnějších než 0,5 m).
  - [x] Jan rozhodl (2026-11-20 03:26): mřížku 0,25 m počítat z funkcí a při nové verzi přepočítat i staré bloky; zakázat prokopání dna i okraje ostrova.
  - [ ] Implementovat: vzorkování 0,25 m z funkcí + zákaz prokopání dna a okraje ostrova.
- [ ] **Rešerše implicitního geologického modelování:** jak do vrstev doplnit nepravidelné útvary (žíly, pegmatity, skarny, krasové dutiny) bez plných voxelů. Výchozí zdroj: [A Review of Digital Terrain Modeling](https://doi.org/10.1111/cgf.13657).

## Měřítko

Podnět: odpověď ChatGPT 2026-11-19 o měřítku. Nic z toho není rozhodnuté. Dosavadní hypotézy (postava ~2 m, buňka 0,5 m, blok vesnice 128 × 128 m) jsou v [devlog/svet-a-meritko.md](devlog/svet-a-meritko.md).

- [ ] **Rozhodnout charakter krajiny** (kompaktní, vyvážená, velkolepá). Od toho se odvodí výšky kopců a hor na ostrově a ve světě výprav.
- [x] **Základní herní jednotka 0,25 m: rozhodnuto (Jan 2026-11-19 20:12).** Kopací buňka 0,25 m (~15,6 l), postava 1,75 m = 7 jednotek, dveře 8. Hierarchie: 1 m hrubý svět, 0,5 m řídicí mřížka geologie, 0,25 m herní prostor a kopání, 0,125 m jen jemná geometrie stěn. Terén sám rozlišení nemá (funkce v metrech), to vzniká až vzorkováním. Varianta 20 cm zamítnuta (nesedí na 0,5 m a kousky 16/32/64).
- [ ] **Velikost bloku osobního ostrova:** Jan 2026-11-19 19:56 považuje za optimální **128 × 128 m** (ostrov 4 × 4 bloky = 512 × 512 m). Je to jeho preference, ne konečné rozhodnutí; ověřit testem v izometrii. Blok ostrova se určuje nezávisle na chunku světa výprav.
- [ ] **Test měřítka v izometrické kameře:** jedna postava, modelový dům, kopec a hora ve stejné scéně, pro každou variantu jednotky a bloku. Porovnat podle snímků.
- [ ] **Oddělené typy jednotek v kódu:** metry pro fyziku a vodu (m, s, l/s), herní jednotky po 0,25 m, hustota vzorkování a celočíselné souřadnice mřížky. Hydrauliku nepřevádět na herní jednotky.
- [x] **Kopání zůstává po 0,25 m** (Jan 2026-11-19 20:40). Studie kopání po 0,125 m se nedělá. Kdyby se Jan rozmyslel: jemné buňky jen vizuálně/pro tvar, ale buňka 0,25 m se pro výpočty (voda, propustnost, pevnost) chová jako celá, dokud z ní nezmizí všech 8 jemných buněk.
- [x] **Hladina podzemní vody jako plocha funkce** (Jan 2026-11-19 20:47, hypotéza). Při položení bloku se spočítá jen hrubý ustálený stav po tělesech (objem, výtok, prameny pro povrch). Voda v podzemí se pak drží jako další plocha funkce `gw(x, y)` uvnitř propustné vrstvy (nebo jako tvar v prostoru tam, kde jedna výška nestačí), stejně jako `bs[k]`. Buňky s vodou (hladina, mokré stěny, kapání) se vzorkují až při kontaktu: obnažená vrstva nebo výkop. Ověřit: paměť plochy proti pásmům, čas vzorkování při kontaktu, shoda s E52/E58 a hashem. Výtoky (Jan 20:49): kde `gw` protne povrch nebo stěnu výkopu (kontakt se vzduchem), vznikne výtok, který se jen vykreslí; voda se materializuje do buněk a průtoků až při obsazení pramene (zachycení, napojení na koryto, kopání u něj).
  - 🧪 Ověřeno v E74 (tag `e74-gw`, větev `e74-gw-plocha`, nesloučeno): kompaktní plocha 9,4 kB místo 1,6 MB pásem, stavba ~30 ms, vzorek stěny 44–63 µs, objem sedí s E52/E58/E67, 0 neshod. Jedna výška nestačí (2–3 intervaly, pravidlo z geologie + 27 výjimek); výtoky E67 dál z řešiče. Přepínače `p74_gw`, `p74_vyzvednout` vypnuté.
  - [x] Jan rozhodl (2026-11-20 01:49): neobsazený pramen zvedá hladinu tělesa a obsazování pramenů zapnout (při sloučení E74).
  - [x] Sloučeno a zapnuto (`p74_gw`, `p74_vyzvednout`, nový `p74_hladina`): neobsazený povrchový výtok se vyřadí, těleso se vyřeší znovu jen s obsazenými prameny a okrajem (hladina stoupne, plné těleso nic nepřijímá a tůně přetečou). Voda ze světa neodchází (`podzemi_vyver74_ven` 0). Ostrov beze změny otisku (pramen podzemí se obsadí hned), plný výpočet ~1,7 → ~2,3 s.
  - [ ] Po výkopu stavět plochu jen pro dotčené těleso.
  - [x] Při novém postavení ostrova po výkopech se povrchové prameny našly znovu – vyřešeno v E76 uloženými prameny (`p76_prameny`).
- [x] **Eroze v podzemí po tělesech** (Jan 2026-11-19 20:53, hypotéza). Nematerializované podzemí se neeroduje po buňkách. Průsak pórovitou vrstvou je zanedbatelný; u rozpustných hornin (vápenec, kras) se z průtoku tělesem počítá rozpuštěný objem za čas jako hodnota u tělesa. Po překročení prahu vznikne nebo se zvětší dutina (tvar v prostoru jako u blueprint dutin), buňky se materializují až při prokopání. Navázat na event erozi (E51) a materiálovou tabulku (rozpustnost).
  - 🧪 Ověřeno v E75 (tag `e75-kras`, větev `e75-kras`, nesloučeno): modul `kras75`, rozpustnost v tabulce materiálů, dutina u hladiny ve výstupním pásmu, lokální přepočet přes E68 9–15 ms. Test 0,742 l/s: první dutina vápenec 331 herních dní (55 h), sádrovec 22,5, sůl 0,15. Na ostrově bez efektu (hladina v půdě/písku). `p75_kras` vypnuto.
  - [x] Jan rozhodl (2026-11-20 01:55 a 03:26): kras doladit později; vápenec 50/50 pro jeskynní i hluboký vápenec a dolomit v hloubce 2 m.
  - [x] E75 sloučeno do main (větev `voda-e74-e77-slouceni`), `p75_kras` dál vypnutý (hra kras nespouští, ladí se po konečné délce dne), nástroje E75 berou čas z `cas_hry.gd`: první dutina testu 331 herních dní = 13,8 reálného dne (dřív při 10 min / den 55 h).
  - [ ] Pozor: se zapnutým `p74_hladina` neobsazený pramen syntetického testu E75 tělesem nic nepouští → kras nevzniká, dokud hráč pramen neobsadí.
  - [ ] Propojení těles dutinou a zobrazení dutiny ve scéně při kopání.
- [ ] **Plán vzorkování a LOD** (Jan 2026-11-19 20:58, hypotéza). Svět zůstává funkcí; vzorkuje se jen povrchová slupka (viditelné buňky + 1–2 vrstvy pod nimi), zbytek až při interakci. LOD podle vzdálenosti kamery: zblízka 0,25 m, dál 0,5 m, zdálky/oddálení 1 m, vše ze stejných funkcí. Vyřešit švy mezi úrovněmi (bez děr). Test: mapa 3 × 3 km (~550 bloků po 128 m) jen jako hrubá data a funkce, detail kolem několika hráčů; změřit paměť a čas.
- [ ] **Průhlednost překážek v izometrii** (Jan 2026-11-19 21:03). Při cestování nebo kopání za překážkou zprůhlednit (nebo nevykreslit) buňky v kuželu mezi kamerou a postavou. V podzemí řez do výšky: terén nad úrovní postavy se skryje (styl Dwarf Fortress / The Sims). Navázat na skrývání vrstev a xray přepínač v prototypu.

## Rozhodnutí Jana
- 2026-11-20 01:49: neobsazený pramen zvedá hladinu svého tělesa (místo odtoku ze světa) a obsazování pramenů je zapnuté (pramen se jen kreslí, dokud ho hráč nevykope, nenapojí nebo nezachytí). Zapnout v E74 při sloučení do main. **Hotovo** ve větvi `voda-e74-e77-slouceni` (`p74_hladina`).
- 2026-11-20 01:55: rozpustnost a zrychlení krasu doladit až po konečné délce dne. Generátor dává vápenec k hladině zhruba v 50 % případů (náhodně podle seedu bloku).
  - [x] Implementovat 50/50 vápenec k hladině v generátoru – E82 (tag `e82-vapenec`, nesloučeno, `p82_vapenec` vypnutý): mince 495/1000, vršek 2 m pod povrchem, jíl nad ním se vyklíní (`p82_tesneni`). V podzemí E58 kras skoro nevzniká, v E67 na 19/30 ostrovech (i v blocích „ne“). START: 6 pramenů místo 3.
  - [ ] Jan (zbývá rozhodnout): vyklínit jíl nad vápencem a přepnout podzemí na E67?
- 2026-11-20 03:26: E72 `p72_prusak` zapnout + limit slučování 8 m; E76 `p76_prameny` zapnout + sloučit E74–E77 do main; mřížka 0,25 m z funkcí (přepočítávat i staré bloky); zákaz prokopání dna i okraje ostrova; v blueprintu zakázat vrstvy < 25 cm; E82 mince pro jeskynní i hluboký vápenec a dolomit v hloubce 2 m.
  - [x] Hotovo ve větvi `voda-e74-e77-slouceni`: E72 limit 8 m (`p72_dosah_m`), `p72_prusak` zapnutý (už od E72), `p76_prameny` zapnutý, E74–E77 sloučené. Zbytek (mřížka 0,25 m, zákaz prokopání, vrstvy < 25 cm, E82 mince pro další vápence) čeká na implementaci.
