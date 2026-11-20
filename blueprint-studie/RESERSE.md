# Rešerše: jak vědci a vývojáři modelují vrstvy terénu

2026-11-18, k `blueprint-studie/`. Čísla v hranatých závorkách odkazují na `ZDROJE.md`. Kód studie se v tomto kroku neměnil.

## Co už studie dělá
Hranice vrstev jsou spojité funkce v metrech (blok 16 × 16 × 64 buněk po 0,5 m), buňky se z nich jen vzorkují. Na okraji začínají přesně u souseda (Dirichlet) a dovnitř se prolnou s tvarem blueprintu; bez souseda od regionální desky. Chybějící vrstva se vyklíní. Typy tvaru: mírné ohnutí, vyzdvižená hora s jádrem, zvrásněná antiklinála, sopka se sopouchem, prohnutí pod jezerem. Minerály jen do povolených hostitelů, voda a vzduch jako položky seznamu (rezervoár / jeskyně), pevnost zatím jen údaj v tabulce.

## 1 Implicitní geologické modelování

### 1.1 Potenciálové pole a ko-kriging (Lajaunie, Calcagno, GeoModeller, GemPy)
Lajaunie et al. interpolují jedno bezrozměrné skalární pole \(Z(x,y,z)\), jehož gradient sleduje změřené sklony vrstev a body na stejném rozhraní sdílejí stejnou (neznámou) hodnotu \(Z\). Rozhraní jsou izoplochy tohoto pole; vrstvy jedné depoziční série se proto nemohou křížit [16]. Calcagno et al. to spojili s geologickými pravidly a nasadili v GeoModelleru: víc sérií, zlomy a nesouhlasnosti se skládají z několika polí podle stratigrafického sloupu [17]. GemPy je otevřená implementace téhož (univerzální ko-kriging); série je skupina rozhraní počítaných společně, mladší série překryje starší za nesouhlasností, zlomy se přidávají jako další pole s posunem [18][19].

**Pro nás:** je to vědecký protějšek našich hranic vrstev. My ale nemáme vrtné body a sklony, máme blueprint, sousedy a tabulku pořadí. Ko-kriging celého bloku by byl zbytečně těžký a hůř deterministický. Myšlenka „jedno pole na sérii, izoplochy = vrstvy“ a skládání sérií je ale přímo použitelná.

**Doporučení: přeskočit** samotný ko-kriging a GemPy jako knihovnu. **Převzít** model „jedno pole na sérii“ (viz 1.3 a 4).

### 1.2 RBF a diskrétní implicitní plochy (LoopStructural, Hillier, Laurent)
LoopStructural skládá implicitní foliace, zlomy, nesouhlasnosti a vrásy. Interpoluje buď po částech lineárně na tetraedrech (DSI / Gocad), konečnými diferencemi na pravidelné mřížce, nebo RBF (SURFE, Hillier et al.): stejné omezení (body na ploše, gradienty, nerovnosti nad/pod vrstvou) dají spojité skalární pole, typicky znaménkovou vzdálenost od referenční plochy; mocnost pak posune izohodnotu [21][22][23]. Vrásy řeší Laurent et al. a LoopStructural zvláštním *fold frame*: souřadnice podle osní plochy a osy vrásy, v ní se pole záměrně zakřiví, protože obyčejná implicitní interpolace zakřivení tlačí k nule [21][24].

**Pro nás:** RBF/DSI na tetraedrech je pro vložení jednoho bloku zbytečné. *Fold frame* formalizuje to, co už kreslíme: antiklinála je souřadnicová deformace regionálního pole, která s hloubkou slábne; vyzdvižená hora je jiné pole (zdvih jádra) s erozním vztahem k sedimentům, ne jen větší drape.

**Doporučení: přeskočit** RBF a tetraedry. **Převzít** vrásu jako deformaci souřadnic jednoho pole, ne jako nezávislé výšky každé vrstvy.

### 1.3 Stratigrafický sloup: onlap, erode, vyklínění, nesouhlasnost
V GeoModelleru/GemPy tvoří sloup série shora dolů. Formace uvnitř jedné série se počítají spolu a nekříží se. Mezi sériemi platí topologické pravidlo: **erode** = mladší plocha řeže starší (nesouhlasnost, intruze), **onlap** = mladší plocha se o starší zastaví a dál neřeže [17][20][18]. Vyklínění uvnitř série vzniká samo, když se dvě izoplochy téhož pole sblíží a mocnost klesne k nule. Sopouch, kimberlit a solný dóm jsou typicky série s relací *erode* nahoře ve sloupu [20].

**Pro nás:** vyklínění už máme a sedí to. Chybí nám formální vztahy *mezi* sériemi. Janova vyzdvižená hora (jádro protrhne hlínu a sedimenty) je *erode*/nesouhlasnost; kopec s ohnutými vrstvami je jedna série; sedimenty proti úpatí hory nebo výplň pánve jsou *onlap*; sopouch a komín jsou intruze (*erode*).

**Doporučení: převzít** sloup s relacemi onlap/erode mezi sériemi a vyklínění jako \(t \to 0\) u jedné funkce. **Nechat** pořadí hornin a typ blueprintu, jen je na relace navázat.

### 1.4 Zlomy a vrásy
Zlomy se v implicitním modelu počítají jako samostatné pole (rovina zlomu) a vrstvy se na něm posunou; sítě zlomů mají pořadí, který zlom řeže který [18]. Vrásy viz 1.2: bez fold frame vyjdou moc hladké [24].

**Pro nás:** antiklinálu a zdvih už navrhujeme. Pravý zlom (skok vrstev přes plochu) ve 8 × 8 m bloku zatím není v zadání a rozbil by plynulé švy.

**Doporučení: nechat** dva typy hory. **Přeskočit** sítě zlomů, dokud je Jan výslovně nebude chtít; pak jako těleso s relací *erode* a posunem izoploch, ne jako další Laplace na každé vrstvě.

## 2 Procesní simulace (sedimentace, eroze, zdvih)

### 2.1 Badlands
Badlands je model vývoje krajiny na geologických časech (tisíce až miliony let): fluviální řez stream-power zákonem, svahová difuze, transport a ukládání sedimentu, hladina moře, déšť a zadaný zdvih nebo 3D posun kůry. Povrch je TIN, stratigrafie pánve vzniká ukládáním v čase, ne interpolací [25][26].

**Pro nás:** umí krásné říční sítě a výplně pánví, ale běží na jiném měřítku a čase než vložení dlaždice. Hráčův blueprint by simulace přepsala.

**Doporučení: přeskočit** při ukládání bloku. Hodí se nanejvýš jednou při návrhu regionální desky, ne v pipeline.

### 2.2 Landlab
Landlab je stavebnice 2D modelů zemského povrchu: mřížka, směrování toku, `StreamPowerEroder` (\(E = K A^m S^n\)), difuze svahů, komponenty se skládají v Pythonu [27][28]. Samo o sobě vrstvy nepočítá, počítá vývoj výšky.

**Pro nás:** stejný problém měřítka jako u Badlands. Vzorec stream-power je ale jednoduchý a v grafice ověřený (2.4).

**Doporučení: přeskočit** Landlab jako knihovnu. **Převzít** později nanejvýš stream-power jako volitelnou erozi povrchu (u nás už jsou kapky [5]).

### 2.3 GOLEM a FastScape
V zadání je vedle Badlands a Landlab uvedeno „Goblin“. Ve vědecké trojici modelů vývoje krajiny k nim patří **GOLEM** (Tucker a Slingerland, 1994): evoluční model výšky, tloušťky půdy a průtoku pod deštěm a tektonikou, na časech roků až milionů let [29]. FastScape (Braun a další) je moderní, rychlý zásobník týchž procesů (směrování toku, řez, zdvih) [30]. Samostatný model pojmenovaný Goblin v této skupině není.

**Pro nás:** totéž jako Badlands: špatné měřítko pro jeden blok.

**Doporučení: přeskočit** v pipeline. FastScape-styl výpočtu (říční graf, rovnováha zdvih vs. řez) je inspirace jen pro případný regionální reliéf.

### 2.4 Zdvih a fluviální eroze v grafice (Cordonnier 2016, 2018)
Cordonnier et al. 2016 poprvé v grafice spojili uživatelskou mapu tektonického zdvihu se stream-power rovnicí \(\partial h/\partial t = u - k A^m S^n\) (typicky \(n=1\), \(m=0{,}5\)) na říčním grafu a výsledek převádějí na výškový model jádry tvarů [31]. *Sculpting Mountains* (2018) přidává vrstevnatou kůru: stlačení desek, vrásnění podle stratigrafie, objemový zdvih a erozi, jejíž řez závisí na **kompetenci** horniny; na útesech pak vyniknou tvrdé vrstvy [32].

**Pro nás:** 2016 je příbuzné naší volitelné erozi, ale na měřítku pohoří, ne bloku. 2018 je nejbližší Janovým řezům (vrstvy + zdvih + vrása). Kompetence = naše pevnost v tabulce; výpočet hroucení a eroze podle ní Jan zatím nechce.

**Doporučení: přeskočit** interaktivní simulaci pohoří při vkládání bloku. **Nechat** pevnost jako údaj. **Převzít později** (až se fyzika povolí) modulaci eroze kompetencí a případně stream-power místo/vedle kapek.

## 3 Hry a procedurální grafika

### 3.1 Dwarf Fortress
Po výšce a biomech hra skládá téměř vodorovné vrstvy v pevném pořadí: půda nahoře, pak sedimenty (nebo místo nich výlevné vyvřeliny u sopky — vzájemně se vylučují), pod nimi metamorfity, dole hlubinné vyvřeliny; nejhlubší vrstva je vždy intruzivní. Rudy a drahokamy visí na typu vrstvy a biomu, ne na čisté hloubce. Změna mezi vrstvami je ostrá; trojrozměrné vlnění vrstev autoři teprve plánují. Půda a některé sedimenty můžou nést zvodně [8][37].

**Pro nás:** tabulka hostitelů a zóny kůry už z DF (a z reálné geneze rud) bereme [8][9]. Pevné pořadí zón sedí; ostré vodorovné desky a vyloučení sedimentů u sopky jsou hrubší než naše funkce a profily.

**Doporučení: nechat** hostitele a pořadí zón. **Převzít** výběr podmnožiny hornin podle provincie/biotopu (vesnice), ne po blocích. **Nepřebírat** ostře vodorovné desky.

### 3.2 Minecraft 1.18 (noise router, zvodně, žíly)
Od 1.18 je terén stromem hustotních funkcí: `final_density > 0` je kámen, jinak vzduch nebo kapalina. Horniny nejsou vrstvy, jen povrchová pravidla (kámen / deepslate podle Y). Zvodně volí pro dutinu stav prázdná / zaplavená po hladině moře / **místní hladina** (šum výšky a „floodedness“, bariéra proti sousedním dutinám). Žíly jsou tři šumy: přepínač typu (měď vs. železo a rozsah Y), hřeben (tělo žíly) a mezera (hustota rudy v plnivu, žula resp. tuf) [35][36]. Jeskyně jsou 3D šum (sýr, špagety, nudle).

**Pro nás:** „vyhodnoť funkci ve světových souřadnicích a vzorkuj do buněk“ už děláme a je to správně. Jejich geologie (jeden kámen + nátěr podle Y) je chudší než naše. Místní hladina zvodně se hodí na rezervoár v nepropustné vrstvě; ridged šum na žíly je alternativa k růstu ore-v0, ale neumí přesný počet kusů.

**Doporučení: převzít** lokální hladinu pro vodu/vzduch pod stropem. **Nechat** přesné počty minerálů růstem do hostitele. **Přeskočit** surface rules jako model vrstev. Ridged žíly jen jako tvar semínka, ne místo kvót.

### 3.3 Vintage Story
Nejdřív šumové mapy včetně **geologické provincie**, pak tvary terénu, pak sloupce hornin. Skupiny sedimentární / metamorfní / vyvřelá mají stropy mocnosti podle provincie (štíty skoro jen vyvřeliny, pánve silné sedimenty). Vyvřeliny rostou od pláště nahoru, sedimenty leží nahoře, metamorfity mezi nimi; čedič může ležet nad čímkoli, halit tvoří dómy, mramor žíly ve fylitu a břidlici. Rudy se kladou až do hotových vrstev a jen do určitých hornin [38][39]. Šum může pořadí místy porušit.

**Pro nás:** provincie = odpověď na otevřenou otázku, jestli má mít podmnožinu hornin region, nebo každý blok. Speciální tělesa (dóm, žíla, výlevný čedič nad vším) máme nebo chceme.

**Doporučení: převzít** provincii/vesnici jako zdroj podmnožiny a typických mocností. **Nechat** speciální tělesa. **Nepřebírat** porušování pořadí šumem, pokud to není cílená relace *erode*.

### 3.4 Terraria
Svět vzniká desítkami po sobě jdoucích průchodů: nejdřív jen hlína (povrch a underground) a kámen (cavern), pak se malují biomy, díry, jeskyně, „shinies“ (náhodné žíly rud s kvótou podle vrstvy), drahokamy, kapaliny se nechají ustát [40]. Žádná stratigrafie, jen hloubkové pásy a přemalování.

**Pro nás:** kvóty rud podle zóny jsou vzdáleně podobné našim počtům, ale bez hostitelů a návaznosti přes šev.

**Doporučení: přeskočit** jako model vrstev. Ukazatel průběhu při dlouhém výpočtu máme; z průchodů si nebrat pořadí „nech to spadnout a ukliď“.

### 3.5 No Man's Sky
Planety se počítají za běhu z voxlů (řádově 1 m, chunky kolem 32³): hustota a materiál z procedurálních funkcí ve světových souřadnicích, síť marching cubes, velké tvary z výškového posunu, detaily z voxlů. O stratigrafii publikační zdroje nemluví [41][42].

**Pro nás:** potvrzuje „funkce → vzorek do buněk, stejný tvar v jemnějším rozlišení“. Geologii vrstev to nepřidává. Naši skálu už stavíme Surface Nets, ne jejich pipeline.

**Doporučení: přeskočit** jako model vrstev. Princip vzorkování funkcí **nechat**.

### 3.6 Vrstvený objemový terén (Arches, Santamaría-Ibirika, Galin 2019, Paris 2019)
Galin et al. v přehledu 2019 rozlišují výšková pole, **vrstvené reprezentace** (uspořádané funkce mocností nebo výšek materiálů) a plné objemové \(\mu:\mathbb{R}^3\to\) materiál. Vrstvy jako funkce jsou přesné, úsporné a vhodné k erozi; výška sama o sobě neunese vrásy, převisy ani jeskyně — k tomu je objem [33]. Peytavie et al. (*Arches*) ukládají v každém sloupci zásobník materiálů (skála, písek, vzduch, voda); vložený vzduch mezi skálami udělá jeskyni, převis nebo oblouk, povrch se vyhladí konvolucí zásobníku na implicitní plochu [34]. Santamaría-Ibirika et al. generují stejné zásobníky procedurálně (vrstvy, žíly, jeskyně, směsi) z parametrů návrháře [43]. Paris et al. skládají terén i geologii jako strom implicitních primitiv (vrstvy, zlomy, vrásy, odolnost \(\rho\)); střídání tvrdých a měkkých vrstev dá římsy a podemleté útesy [44].

**Pro nás:** naše hranice vrstev *jsou* vrstvená reprezentace z přehledu [33]. Vyplnění sloupce vzorkováním funkcí je krok *Arches*/Santamaría. Vzduch a voda v seznamu materiálů jako dutina pod stropem je přesně zásobníkový trik z *Arches*. Strom implicitních primitiv se hodí na sopouch, komín, dóm a žílu, ne na každou vrstvu.

**Doporučení: nechat** funkce vrstev a vzorkování do sloupců. **Převzít** dutiny jako vložený materiál v zásobníku a tělesa jako implicitní primitiva / SDF složená relací *erode*.

### 3.7 SDF a implicitní objemový terén
Implicitní povrch \(S=\{p\mid f(p)=0\}\), materiál znaménkem \(f\); výšku \(h(x,y)\) lze zapsat jako \(f=h(x,y)-z\) [33][34]. Obecnější SDF a CSG (sjednocení, řez, deformace) umí převisy a dutiny, jak to používají *Arches* a Paris. Plné 3D pole pro každou z 17 vrstev v bloku 16 × 16 × 64 by bylo dražší a k převislým vrstvám teď nemáme důvod.

**Pro nás:** 2,5D funkce výšky je SDF ve svislém směru a zůstane stejná při změně rozlišení. 3D SDF nechat na tělesa a jeskyně.

**Doporučení: nechat** 2,5D funkce pro vrstvy. **Převzít** 3D SDF jen pro komíny, dómy, žíly a dutiny.

### 3.8 E84: útvary nad vrstvami bez voxelů (2026-11-20)
Paris a kol. 2021 staví kras jako kostru (nejkratší cesty po horizontech a puklinách) a z ní strom SDF ze sweepů nebo koulí s blendingem a warpingem. Pole drží 1-Lipschitz, aby šly plochy rychle vyřadit; sweep 10 m tunelu má < 1 kB [77]. Quilez: kapsle a koule jsou přesné SDF, elipsoid jen dolní mez, sjednocení min přesné, warping pole zkřiví [78][79]. LoopStructural: mladší útvary první, nesouhlasnost jako maska [75].

**Pro nás:** prototyp E84 (`tools/implicit_e84.gd`, PROP E84) to ověřil na ostrově START: na švu 0 rozdílů, float32 0 buněk, +51 ms na blok při 0,5 m, útvar 176–296 B, intervaly ve sloupci = pásma vody.

**Doporučení: převzít** útvary jako SDF z hashe světové mřížky (místo dutin po buňkách) a intervaly ve sloupci pro vodu. **Přeskočit** kostru sítě nejkratší cestou a interpolaci z dat.

## 4 Doporučení vůči naší cestě

| Stav | Co | Proč |
|---|---|---|
| **Nechat** | Spojité funkce hranic, vzorkování do buněk | Shoda s [33][34][43]; stejný tvar v jemnějším rozlišení |
| **Nechat** | Dirichletův okraj + prolnutí s blueprintem, Laplace | Levný protějšek implicitní interpolace s danými kontakty [1][3][16] |
| **Nechat** | Vyklínění, dva typy hory, sopka, jezero, hostitelé, přesné počty, pevnost jen jako údaj | Sedí s geologií i se zadáním |
| **Převzít** | Jedno skalární pole (funkce) na sérii, mocnost \(\ge 0\), vyklínění v nule | GemPy/LoopStructural [18][21]; méně nezávislých SOR, vrstvy se nekříží |
| **Převzít** | Relace **onlap / erode** mezi sériemi | Formalizuje horu s jádrem, onlap na úpatí, sopouch a tělesa [17][20] |
| **Převzít** | Vrásu jako deformaci souřadnic pole (fold frame, slábne s hloubkou) | Laurent / LoopStructural [24]; ne 17 samostatných výšek |
| **Převzít** | Podmnožinu hornin a mocnosti podle provincie/vesnice | Vintage Story, Dwarf Fortress [38][37] |
| **Převzít** | Tělesa jako SDF/implicitní primitiva s relací erode | Paris, *Arches*, GeoModeller [44][34][20] |
| **Převzít** | Rezervoár/jeskyně jako vložený materiál + místní hladina pod nepropustným stropem | *Arches*, Minecraft aquifer [34][36] |
| **Přeskočit** | Ko-kriging, GemPy, RBF/tetraedry při vkládání bloku | Těžké, chtějí jiná vstupní data |
| **Přeskočit** | Badlands, Landlab, GOLEM, FastScape, Cordonnier 2016/2018 při uložení dlaždice | Špatné měřítko a čas; přepsaly by blueprint |
| **Přeskočit** | Geologii ve stylu Terrarie (přemalování pásů) a Minecraft surface rules | Bez návaznosti vrstev |
| **Přeskočit teď** | Výpočet hroucení a eroze z pevnosti / kompetence | Jan: fyziku zatím nepočítat; vzorec je v [32] až se povolí |
| **Přeskočit teď** | Sítě zlomů a recumbentní 3D vrásy | Nejsou v zadání; rozbily by švy |

Praktický důsledek pro algoritmus: regionální pole série + deformace podle typu blueprintu + korekce od sousedů na okraji, pak mocnosti (vyklínění), pak relace mezi sériemi a SDF těles, nakonec vzorek do buněk, minerály, voda/vzduch. To je pořád „funkce na vrstvu“, jen vrstvy jedné série sdílejí jedno pole.
