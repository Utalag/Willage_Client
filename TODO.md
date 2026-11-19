# TODO (Willage studie)

Seznam nápadů a úkolů, které čekají na Janovo rozhodnutí nebo na zařazení. Hotové položky se odškrtnou a odkáží na commit nebo tag.

## Voda

- [ ] **E68 – sjednocení výpočtu povrchu a podzemí (hydrologický orchestrátor).** Podnět: konverzace s ChatGPT 2026-11-19 ([sdílený chat](https://chatgpt.com/share/6aff2aa3-865c-83ed-a19c-63720302f8cf)).
  - Jeden společný krok pro povrch, podzemí, tůně, prameny a události: sdílená vodní bilance, jedno pořadí výpočtů a jedno místní přepočítání po změně terénu.
  - Algoritmy zůstávají: povrch priority-flood + D8, podzemí pásma a tělesa (E58 A+B+C, E67).
  - Pořadí: terén a geologie → povrch a podzemí → vodní bilance → události → místní invalidace.
  - Ohlídat smyčku rybník → průsak → pramen → rybník: předávání vody oběma směry s limitem počtu kol, zachování hmoty, deterministický výsledek (hash).
  - Postup: nejdřív krátký návrh (PROP), pak větev s měřením.
- [ ] **Harmonický průměr propustností** sousedních materiálů pro dělení vody do stran v E67 (teď prostý poměr propustností), aby jíl brzdil i sousední písek.
- [ ] **Test symetrie a referenční test** (zdroj 1 l/s nad sloupcem, vrstvy 1,0 / 0,8 / 0,6 / 0,4 / 0,2 l/s, nepropustné podloží): symetrický terén musí dát symetrický výsledek a voda se nesmí ztratit.

## Architektura světa

Podnět: druhá odpověď ChatGPT 2026-11-19 (Jan ji poslal do chatu). Jde o návrhy k posouzení, ne o rozhodnutí.

- [ ] **Datový kontrakt mezi generováním světa, geologií, vodou a změnami od hráčů.** Kdo vlastní která data, kdo je smí měnit a jak se změny šíří. Týká se i serveru, takže ve spolupráci s Willage-backend.
  - Funkce vrstev zůstávají jediným zdrojem pravdy o geologii. Buňky, kolize a vykreslování jsou z nich jen vzorkované. Stav vody, eroze a událostí je odvozený stav, který nemusí znovu vyhodnocovat geologické funkce.
  - Místo přímých volání mezi systémy typy změn (`SurfaceChanged`, `LayerBoundaryChanged`, `MaterialChanged`, `CavityCreated`, `CavityRemoved`, `HydraulicConnectivityChanged`) a resolver závislostí: každý systém deklaruje, na které změny reaguje. Navazuje na E68.
- [ ] **Determinismus celého světa, nejen jednoho bloku.** Ujasnit `Hash(seed, změny, pořadí)`: u kterých operací pořadí nesmí hrát roli a u kterých ano (vykopat a zasypat). Navazování bloků je rozhodnuté (Jan 2026-11-17): sousedé se nikdy nemění, přizpůsobuje se jen nový blok. Pořadí pokládání tedy výsledek ovlivňuje záměrně; platí jen, že stejný výřez, transformace a sousedé dají stejný výsledek.
- [ ] **Jádro vyzdvižené hory přes více bloků:** geologická kontinuita masivu přes švy.
- [ ] **Tenké vrstvy a převzorkování mezi rozlišeními:** vrstva tenčí než buňka nesmí zmizet nebo se objevovat podle rozlišení.
- [ ] **Výkon na telefonu:** hierarchie rozlišení (region, blok, sekce 16³ nebo 32³, jemné buňky jen u hráče), všechny úrovně ze stejných funkcí. Změřit generování bloku na slabém zařízení.

## Přenos terénu z průzkumného světa na ostrov

Podnět: třetí odpověď ChatGPT 2026-11-19. Dva světy se společnou geologií a vodou: velký průzkumný svět po chunkech a osobní ostrov (začíná na 4 blocích, nejvýš asi 16), který hráč rozšiřuje výřezy z průzkumného světa.

- [ ] **Výřez terénu jako samostatný přenositelný datový objekt:** `TerrainSource` (původní definice), `TerrainTransform` (otočení, svislý posun), `TerrainPlacement` (místo na ostrově), `TerrainInstance` (výsledek po napojení na sousedy). Navázat na formát bloku WVB1 a blueprint, ve spolupráci s Willage-backend.
- [ ] **Otočení výřezu po 90°:** ověřit, že funkce vrstev, minerály a dutiny se otočí bez rozdílu proti vygenerování na místě.
- [ ] **Voda se nepřenáší hotová:** přenesou se zdroje, materiály a geometrie, stav vody se po vložení přepočítá v novém okolí a z ustáleného stavu se znovu naplánují události (příchod vody, plnění tůní, eroze).

## Model světa a kopání

Podnět: čtvrtá odpověď ChatGPT 2026-11-19, popis je v [devlog/model-sveta.md](devlog/model-sveta.md).

- [ ] **Přechod mezi funkcí, vzorkovanou buňkou a trvalou změnou po kopání:** definice zůstane, změny hráče jako překryv. Ujasnit vztah k WVB1, který dnes ukládá celé pole bloku. Malý experiment: vykopat chodbu, uložit jen překryv, znovu načíst a porovnat hash.
- [ ] **Kde končí funkce a pásma:** kritérium, kdy změna (převis, oblouk, nepravidelná jeskyně) potřebuje lokální oblast s plnými buňkami, a jak takovou oblast uložit (řídký objem, octree, komprimované intervaly).
- [ ] **Rešerše implicitního geologického modelování:** jak do vrstev doplnit nepravidelné útvary (žíly, pegmatity, skarny, krasové dutiny) bez plných voxelů. Výchozí zdroj: [A Review of Digital Terrain Modeling](https://doi.org/10.1111/cgf.13657).

## Měřítko

Podnět: odpověď ChatGPT 2026-11-19 o měřítku. Nic z toho není rozhodnuté. Dosavadní hypotézy (postava ~2 m, buňka 0,5 m, blok vesnice 128 × 128 m) jsou v [devlog/svet-a-meritko.md](devlog/svet-a-meritko.md).

- [ ] **Rozhodnout charakter krajiny** (kompaktní, vyvážená, velkolepá). Od toho se odvodí výšky kopců a hor na ostrově a ve světě výprav.
- [x] **Základní herní jednotka 0,25 m: rozhodnuto (Jan 2026-11-19 20:12).** Kopací buňka 0,25 m (~15,6 l), postava 1,75 m = 7 jednotek, dveře 8. Hierarchie: 1 m hrubý svět, 0,5 m řídicí mřížka geologie, 0,25 m herní prostor a kopání, 0,125 m jen jemná geometrie stěn. Terén sám rozlišení nemá (funkce v metrech), to vzniká až vzorkováním. Varianta 20 cm zamítnuta (nesedí na 0,5 m a kousky 16/32/64).
- [ ] **Velikost bloku osobního ostrova:** Jan 2026-11-19 19:56 považuje za optimální **128 × 128 m** (ostrov 4 × 4 bloky = 512 × 512 m). Je to jeho preference, ne konečné rozhodnutí; ověřit testem v izometrii. Blok ostrova se určuje nezávisle na chunku světa výprav.
- [ ] **Test měřítka v izometrické kameře:** jedna postava, modelový dům, kopec a hora ve stejné scéně, pro každou variantu jednotky a bloku. Porovnat podle snímků.
- [ ] **Oddělené typy jednotek v kódu:** metry pro fyziku a vodu (m, s, l/s), herní jednotky po 0,25 m, hustota vzorkování a celočíselné souřadnice mřížky. Hydrauliku nepřevádět na herní jednotky.
- [x] **Kopání zůstává po 0,25 m** (Jan 2026-11-19 20:40). Studie kopání po 0,125 m se nedělá. Kdyby se Jan rozmyslel: jemné buňky jen vizuálně/pro tvar, ale buňka 0,25 m se pro výpočty (voda, propustnost, pevnost) chová jako celá, dokud z ní nezmizí všech 8 jemných buněk.
- [ ] **Hladina podzemní vody jako plocha funkce** (Jan 2026-11-19 20:47, hypotéza). Při položení bloku se spočítá jen hrubý ustálený stav po tělesech (objem, výtok, prameny pro povrch). Voda v podzemí se pak drží jako další plocha funkce `gw(x, y)` uvnitř propustné vrstvy (nebo jako tvar v prostoru tam, kde jedna výška nestačí), stejně jako `bs[k]`. Buňky s vodou (hladina, mokré stěny, kapání) se vzorkují až při kontaktu: obnažená vrstva nebo výkop. Ověřit: paměť plochy proti pásmům, čas vzorkování při kontaktu, shoda s E52/E58 a hashem. Výtoky (Jan 20:49): kde `gw` protne povrch nebo stěnu výkopu (kontakt se vzduchem), vznikne výtok, který se jen vykreslí; voda se materializuje do buněk a průtoků až při obsazení pramene (zachycení, napojení na koryto, kopání u něj).
