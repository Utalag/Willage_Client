# PROP – blueprint-studie (2026-11-18)

## Cíl
Ověřit Janův směr „blueprint“ (2026-11-18 15:5x): divák vloží jen **tvar povrchu + seed + počty minerálů/kovů**.
Okraje povrchu se v náhledu dorovnají na sousedy, po potvrzení se **vrstvy hornin sousedů protáhnou** do nového bloku,
minerály se vtisknou v přesných počtech jen do povolených hostitelských hornin a vodu dopočítá gen-v3 vsakování.

## Hypotéza
1. Harmonická (Laplaceova) korekce hranic vrstev s hodnotami sousedů jako Dirichletovou podmínkou dá švy vrstev
   srovnatelné s drsností uvnitř bloku (skok na švu ≲ 1,5 × skok mezi sousedními sloupci uvnitř), zatímco nezávislé
   bloky gen-v3 mají skoky výrazně větší.
2. Dorovnání okraje povrchu v pásu 4 buněk sníží skok povrchu na švu na ≤ 1 buňku a vnitřek bloku zůstane beze změny.
3. Minerály sedí přesně (schodek 0), pokud blok má dost hostitele; jinak se schodek nahlásí (žádné tiché přesouvání).
4. Výsledek je čistá funkce (stav sousedů, tvar, seed, pořadí vložení): dva běhy i běh po snímcích vs. naráz → stejný hash.
5. Vložení bloku trvá < 3 s (jednorázově, s ukazatelem průběhu), volitelná hydraulická eroze přidá < 1 s.

## Metriky
- skok hranice vrstvy přes šev (průměr a max, buňky) pro 3 varianty: nezávislé gen-v3 / regionální základ bez navázání / blueprint s navázáním; reference = skok uvnitř bloku
- skok povrchu přes šev před a po dorovnání okraje; změna vnitřku (buňky mimo pás)
- minerály: cíl vs. umístěno vs. schodek podle hostitele
- determinismus: SHA-256 celého světa (buňky + voda) ve 2 bězích a sync vs. po snímcích
- časy jednotlivých kroků (ms)

## Výsledky
Naměřeno 2026-11-18 16:11, výchozí parametry, sled 5 blueprintů na mřížce 3 × 3 (`shots/bench.txt`).

**Švy vrstev** (průměrný skok rozhraní přes stranu bloku, v buňkách, průměr přes 5 vrstev, 64 dvojic sloupců):
- A, nezávislé gen-v3 se stejným povrchem a počty: **2,65** (max 12)
- B, regionální deska + charakter bez navázání: **0,17** (max 1)
- C, blueprint s Laplaceovým navázáním: **0,07** (max 2). Uvnitř bloků je to 0,26, takže šev je hladší než vnitřek (poměr 0,25). **Hypotéza 1 platí.**
- Svah vložený do mezery mezi dva *staré* bloky gen-v3: bez navázání 1,74, s navázáním **0,47**. Písek zůstává na 1,53, protože gen-v3 má písek jako vrstvu u povrchu, ne jako souvislou vrstvu.
- Silný vlastní charakter (šum vrstev 2,5, drape × 1,5): bez navázání 0,61, s navázáním 0,28.

**Negativní nebo neočekávané:** pokud všechny bloky stojí na stejné regionální desce, švy navazují skoro samy (B 0,17).
Laplace pak přidá málo. Hodně pomáhá u sousedů, kteří z desky nevznikli (staré bloky, jiný seed světa, silný charakter
blueprintu). Okrajový sloupec povrchu je přesně ve výšce souseda, takže skok na švu je 0 a vnitřek bloku má 0,59.
Šev tak může působit „vyrovnaně“.

**Povrch:** skok na švu u šablon průměrně 3,86 (max 12), po dorovnání 0 (max 0). Změněno 194 sloupců, všechny v pásu
4 buněk, mimo pás 0. **Hypotéza 2 platí.**

**Minerály:** 12 položek v 5 blocích přesně (schodek 0), validátor gen-v3 OK. U negativního testu (měď 4000 jen v žule)
se umístilo 2 072 kusů, což je všechna žula, a zbylých 1 928 je nahlášených jako schodek. Jinam se nic nedalo. **Hypotéza 3 platí.**

**Determinismus:** dva běhy dávají stejný hash `45f42cd597c0f8c9` a běh po snímcích (Placer, 0,5 ms na snímek) je stejný
jako běh naráz. Jiné pořadí vložení dá jiný hash, což se čekalo. Eroze je 2× stejná. **Hypotéza 4 platí.**

**Časy** (box, llvmpipe, GDScript): blok bez sousedů 21–24 ms, se sousedy 45–95 ms. Nejvíc trvá navázání vrstev
(20–74 ms, 5 × SOR). Eroze s 3 000 kapkami přidá 43–103 ms na blok a zjemní povrch (vnitřní drsnost z 0,59 na 0,25).
Celý sled 5 bloků trvá 274 ms, s erozí 691 ms. **Hypotéza 5 platí s velkou rezervou** (na limit 3 s zbývá zhruba 30×).

## Otevřené otázky pro Jana
1. **Nedostatek hostitele:** teď se nahlásí schodek a blueprint dostane méně. Možnosti: (a) odmítnout vložení už v náhledu,
   (b) nabídnout jiný slot, (c) povolit záložní hostitele (jako ore-v0 L4), (d) přenést zbytek jako „nevtisknutý“ na příští blok.
2. **Šev povrchu:** okraj má přesně výšku souseda. Má tam zůstat malý přirozený schod (≤ 1 buňka), nebo je rovný šev v pořádku?
3. **Strany bez souseda:** vrstvy pokračují (Neumann), nebo se mají vracet k regionální desce (`--free_face=zero`)?
4. **Regionální deska:** stačí jedna deska pro celý svět (pak švy navazují skoro samy), nebo má mít každá vesnice vlastní seed?
5. **Odebrání nebo přesun bloku:** bloky vložené později se odvozovaly od něj. Mají zůstat, nebo se mají přepočítat?
6. **Server v C#:** Laplace je v desetinných číslech. Stačí pro ověření stejné pořadí operací, nebo přejít na celá čísla či pevnou řádovou čárku?


# v2: tabulka pořadí hornin a profily deformace (2026-11-18 16:26–16:45)

## Cíl v2
Nahradit pět vrstev gen-v3 Janovou tabulkou pořadí 64 hornin [10]. Každá hornina má v tabulce zónu, rozsah hloubky,
mocnost, četnost, vlastnosti vody a minerály, které hostí. Na místě se z pořadí vybere jen podmnožina. Vrstvy se mají
přizpůsobit terénu podle Janovy skici [11] a představy řezu [12]: hora prorazí sedimenty jádrem z hlubokých hornin
a nahoře má sníh, přes kopec se vrstvy ohnou, pod prohlubní se prohnou, sopka má vrstvy sbíhavé ke kráteru a sopouch.
Navazování na sousedy musí dál fungovat.

## Hypotéza v2
1. Uspořádaná podmnožina zhruba 17 hornin s vlnitými hranicemi zón i vrstev zůstane na švech spojitá (C < 0,5 buňky).
2. Deformace podle profilu (mírné, hora, sopka) změní jádro hory z „horské kůže“ na krystalinikum a švy přitom nezhorší víc než o 0,2.
3. Minerály půjdou přesně do hostitelů z tabulky. Diamanty do kimberlitu, drahokamy a vzácné kovy do pegmatitu, Fe-Ti do gabra a magnetitové zóny, uhlí do slojí v sedimentech.

## Výsledky v2
Naměřeno 2026-11-18 16:39, sled 7 blueprintů (`shots/bench_horniny.txt`, `./run.sh horniny-test`).
- **Tabulka:** 65 hornin (64 od Gemini [10] a navíc sopouch), 17 aktivních vrstev ve výchozím stavu (`--rocks_on` / `--rocks_off`),
  10 horských hornin vybraných podle typu blueprintu a relativní výšky, 11 minerálů. Nová id 20–75 se vejdou do u8.
- **Švy vrstev (průměr přes 17 vrstev):** A nezávislé bloky 1,91 · B společná deska a zdvih bez navázání 1,18 ·
  **C s Laplacem 0,38** (uvnitř bloků 0,99, povrch 0). Bez deformace C 0,28. **Hypotéza 1 platí, hypotéza 2 platí** (+0,10).
- **Jádro hory nad výškou 46:** krystalinikum 40 %, horské horniny 39 %, sedimenty 6 %, sníh 11 %. Bez deformace
  bylo 85 % horské kůže. Sopka: horské horniny 39 %, tělesa (sopouch) 29 %, sedimenty 18 %, sníh 7 %.
- **Minerály:** 24 položek, 22 přesně, validátor OK u všech 7 bloků. 2 schodky: hora má drahokamy 8→0 a vzácné kovy 12→0,
  protože v bloku není pegmatit. **Hypotéza 3 platí** (schodek je nahlášený, nic nešlo jinam).
- **Determinismus:** 2 běhy `8277d3669ff4bc34` stejné, po snímcích = naráz.
- **Čas:** 7 bloků 1 639 ms, nejpomalejší blok 386 ms (vrstvy, 17 × SOR). Limit 3 s na blok drží, rezerva je ale jen asi 8× (ve v1 30×).

**Negativní nebo neočekávané:**
- Šev C 0,38 je horší než ve v1 (0,08), protože vrstvy jsou tenké (často 1–3 buňky) a zaokrouhlení na buňku je vidět víc. Poměr šev/uvnitř (0,38) je ale stejný jako v1.
- Pegmatitové žíly se náhodně v hoře neobjevily, takže drahokamy a vzácné kovy mají schodek. Hustota náhodných těles je ve výchozím stavu 0 (`body_freq_scale`), komín a dóm jsou jen ukázkové pozice (`demo_pipes`, `demo_domes`).
- Skarn se hledá jen uvnitř bloku (BFS od granitoidů do karbonátů), přes šev nepokračuje.
- Horská kůže tvoří pořád 39 % jádra hory. Janova představa [12] má celou horu z hlubokých hornin.
- Při buňce 0,5 m jsou „velehory“ a mocnosti z tabulky jen symbolické. Mocnosti jsou přepočtené na buňky a ořezané na výšku bloku 64.
- Kvůli zdvihu pod sopkou je v řezu hodně peridotitu (plášťová zóna se natáhne). Hluboké vrstvy proto zvedám jen z 35 %.

## Otevřené otázky v2 pro Jana
1. **Podmnožina hornin:** má se vybírat pro region nebo vesnici (pak všechny bloky sdílí stejných 17), nebo zvlášť pro každý blok (horší švy)?
2. **Schodek hostitele** (drahokamy bez pegmatitu): má blueprint s drahokamy pegmatit vynutit, nebo zůstat u schodku?
3. **Horská kůže vs. jádro:** má hora mít povrch z horských hornin 41–61, nebo celá z hlubokých hornin podle tvé představy [12]?
4. **Šev hora↔kopec:** horské horniny na švu končí skokem. Mají se na kopci dotahovat, nebo je to v pořádku?
5. **Tělesa:** jak často mají být komíny, dómy a žíly náhodně (teď 0, jen ukázkové)? Má skarn přecházet přes šev?
6. **Sdílená tabulka:** nová id jsou v `sdilene/horniny_voda.json` (rozšíření, původní `materialy_voda.json` se nezměnil, protože ho prototyp porovnává). Sloučit je do hlavní tabulky?

# v2.1: funkce nezávislé na rozlišení, sousedé jako výchozí bod, klíny, dva typy hor, dutiny (2026-11-18 16:40–17:20)
Naměřeno 2026-11-18 ~17:15, sled 8 blueprintů (`shots/bench_horniny.txt`).
- **Rozlišení** (Jan 16:42): blok se navzorkuje funkcemi při 16 × 16 × 64 a 32 × 32 × 128. Jemný výsledek se zmenší
  většinou z 8 buněk. Shoda s hrubým je **94,9 %**, pevné/vzduch 99,7 %, hrubá hodnota je mezi 8 jemnými v 99,6 %.
  Vzorky při 16 jsou **přesně** buňky pipeline. Počty minerálů a dutin jsou při 32 přesně 8× (např. jeskyně 90 → 720).
  Zbylých 5 % neshody leží na hranicích vrstev, kde buňka 0,5 m padne na rozhraní (viz `46_horniny_rozliseni.png`).
- **Sousedé jako výchozí bod** (Jan 16:44): okraj = přesně mocnost souseda, chybí-li soused, regionální základ, do 3 m se
  rozplyne do tvaru blueprintu. Šev vrstev C **0,08** (A 1,74, B 1,13), skok mocnosti na švu **0,00**, povrch 0.
- **Klíny** (Jan 16:46/16:49): případ ze skici [16] sedí. 2 a 4 přejdou šev a do ~3 m se vyklíní, 3 roste od švu, 1/5/6/7
  navazují. Na švu je 0 náhlých objevení vrstvy (bez navázání 40).
- **Hory:** vyzdvižená má nad 46 krystalinikum 77 % a sedimenty 8 %. Zvrásněná má sedimenty 45 % a horniny hor 41 %,
  protože vrstvy se klenou celé.
- **Dutiny:** jeskyně 90→90 a rezervoár 60→60, validátor vody OK (rezervoár plný, uzavřený).
- **Čas:** 8 bloků 2,2 s, blok 0,23–0,57 s. Vzorkování 32 trvá 0,4–1 s na blok.
- **Determinismus:** 2× stejný hash, po snímcích = naráz.

**Negativní:**
- Uvnitř bloků je pořád 112 „náhlých“ objevení vrstvy na 0,5 m (šum přítomnosti vrstvy má přechod jen ±0,12, takže je strmý).
  Jde to zjemnit širším přechodem.
- Skarn je teď spojitá svislá vzdálenost od granitoidu, ne BFS do stran.
- Rezervoár a jeskyně mají jeden střed na blok.
- Voda se při 32 nevzorkuje (gen-v3 vsakování umí jen 16 × 16 × 64).
- Funkce u švu bere pozdějšího souseda jen mimo středy buněk. Při 16 je výsledek nezávislý na pořadí, při 32 ho okraj
  bloku vloženého dřív „vidí“.

**Otevřené otázky v2.1:**
1. Taper 3 m stačí, nebo má být klín delší nebo podle mocnosti?
2. ~~Regionální základ na volné straně~~ → **rozhodnuto Janem 17:38:** strana bez souseda má vrstvy, které definuje blueprint (jeho podmnožina hornin), tak jak je to teď.
3. Pevnost: Jan psal „bloky“, beru jako buňky 0,5 m. Výpočet zřícení zatím není (Jan 17:01).
4. ~~Víc dutin nebo tvar?~~ → **rozhodnuto Janem 17:38:** v bloku je buď nic, nebo jeden rezervoár, nebo jedna jeskyně, tvar je jedno. Blueprint s VODOU i VZDUCHEM se odmítne (viz v2.2).

# v2.2: rozhodnutí Jana 17:38 (volná strana, nejvýš jedna dutina na blok) (2026-11-18 17:38–18:15)
Naměřeno 2026-11-18 ~18:00, stejný sled 8 blueprintů (`shots/bench_horniny.txt`).
- **Volná strana:** strana bez souseda bere vrstvy, které definuje sám blueprint (jeho podmnožina hornin). Takhle to
  fungovalo už ve v2.1, teď je to výslovně v README. Nic se nepřepočítalo.
- **Nejvýš jedna dutina:** `BP.validate` odmítne blueprint s VODOU (250) i VZDUCHEM (0) zároveň
  (`blueprint.cavity_conflict`, záporný počet → `blueprint.negative_count`). Generátor (pipeline i `FN.minerals`)
  pak dutinu nevytvoří a chybu zapíše do `rep.blueprint`. Jeskyně se přesunula do vlastního bloku: svah (1,1) má VZDUCH 90,
  kopec (2,2) jen VODU 60.
- **Jedna souvislá dutina:** test odhalil, že jeskyně ve (1,1) měla 2 oddělené kusy. Dutina se teď vybere růstem
  od nejlepší buňky (6-sousedství, podle φ), takže vždy vznikne jedna komponenta. Počty sedí dál: jeskyně 90/90 (32: 720/720),
  rezervoár 60/60 (32: 480/480).
- **Test pravidla** (`tests_horniny.gd`, `cavity_rule_test`): VODA + VZDUCH → validace ODMÍTNUT a generátor 0 dutin s chybou → OK.
  Jen voda, jen vzduch i bez dutiny → validace OK. Souvislé dutiny na blok jsou 0/0/1/0/0/1/0/0 → OK.
- **Ostatní beze změny:** shoda 16 vs. 32 94,9 %, šev C 0,09, skok mocnosti na švu 0,00, náhlé vrstvy na švu 0.
  Determinismus 2× `00dc4dc614729194`, po snímcích = naráz. v1 test OK (C 0,08, hash s erozí 2× stejný).
- Snímek `46_horniny_rezervoar_jeskyne.png` se přegeneroval: vlevo rezervoár (2,2), vpravo jeskyně (1,1).

**Otevřené:** délka klínu (taper 3 m) zůstává, jak je (Jan 17:38). Pevnost jsou jen data.

# v3: voda a eroze na blocích v2, 3D grafy funkcí, malý svět 8 × 8 (Jan 2026-11-18 17:47–18:05)
Pořadí podle Jana: 1 voda + eroze, 2 grafy funkcí vrstev (GIF), 3 svět 8 × 8 (hrubě celý svět → dlaždice → detail od první).

## E47 voda a eroze po vrstvách (plán, zapsáno před pokusem 18:35)
- **Co:** na 8 blocích v2 (louka, obě hory, sopka, prohlubeň, kopce, svah) se po výpočtu vrstev pustí kapková eroze
  (`erosion.gd` zobecněná na libovolnou mřížku) na funkci povrchu hm_f. Hranice vrstev bs zůstanou (jsou absolutní
  ve výšce), buňky se znovu navzorkují. Odebraný povrch odkryje hlubší vrstvy, nános = štěrk/písek (gravel_sand).
  Půda a kůže hor se měří od PŮVODNÍHO povrchu, takže koryto prořízne půdu a odkryje horninu.
  Pak déšť a tok vody simulací voda-studie (`voda_sim.gd`, kopie) přes celý svět naráz, s vlastnostmi hornin ze sdílené tabulky.
- **Varianty eroze:** A každý blok sám (zavřené okraje), B každý blok sám s okrajem připnutým (změna × smoothstep od švu,
  pás taper 3 m), C celý svět naráz (jen když se svět generuje celý najednou, viz E49).
- **Hypotéza:** A rozbije šev povrchu (skok > 1 buňka), B i C nechají šev povrchu spojitý (≤ 0,1). Švy vrstev se nezmění,
  protože bs se nemění. Voda se po erozi víc soustředí do koryt (méně mokrých sloupců, víc toku v nejsilnějších 5 %).
- **Metriky:** průměrná a max. změna povrchu, objem odběru/nánosu, šev povrchu a vrstev (MT.seams) před/po, podíl sloupců
  s odkrytou jinou horninou na povrchu, ztracené minerály, voda: kaluže (sloupce, objem), soustředění toku, odtok, čas.

### E47 výsledky (naměřeno 2026-11-18 ~18:40, `shots/bench_voda.txt`, `./run.sh voda`)
Výchozí: 800 kapek na blok, `ero_cap` 1,0, `ero_erode` 0,1, `ero_deposit_rate` 0,1 (pravidla erosion.gd). Bouřka 0,02 buňky × 60 tiků,
400 tiků voda_sim přes celý svět 48 × 48 × 37 buněk.
- **Síla eroze:** původní konstanty erosion.gd (cap 4, erode 0,3, 3000 kapek) jsou na blocích v2 moc silné: vrchol hory
  −8,6 m, průměr −1,3 m. Proto slabší výchozí. Teď průměrná změna 0,31 U (okraj) / 0,61 U (blok), max. odběr 6,4 U = 3,2 m
  (strž na hoře), max. nános 3,5 U. 20–30 % odebraného zůstane jako nános, zbytek odteče z bloku.
- **Vrstvy:** hranice bs se nemění, eroze jen sníží povrch. Řezy (`47_voda_eroze_rezy.png`) ukazují, že vrcholy a svahy hor a sopky
  prořízne napříč vrstvami. Na povrchu se objeví hlubší horniny: 13 % sloupců má navrchu jiný materiál (okraj), z toho 2 %
  odkrytá vrstva z tabulky, zbytek horniny hor nebo hlína místo drnu. Nános (štěrk/písek) leží pod drnem, hlavně v prohlubni
  (jezírko se zmenší: v kalužích 14,6 → 10,1 m³). Minerálů odneseno 0–1 (z ~600).
- **Švy:** švy vrstev 0,09 před i po ve všech režimech (bs se nemění) → **platí**. Šev povrchu (skok hm_f přes šev):
  B okraj připnutý **0,00** (max 0), A blok sám 0,24 (max 2,47 U = 1,2 m), C svět naráz 0,23 (max 2,5), ale to je jen sklon
  terénu (uvnitř 0,72). Zlom přes šev (2. diference) A 0,65, B 0,73, C 0,46, uvnitř 0,70–0,78.
  **Negativní / jinak, než jsem čekal:** při slabé erozi A šev viditelně nerozbije (skoky do 1,2 m na pár místech). Při silné
  erozi (3000 kapek, cap 4) ano: šev 1,12 až 1,55 U proti 0,11–0,49 uvnitř. B je jediný režim s nulovým skokem a nezávislý
  na pořadí vkládání. C je nejhladší, ale jen pro svět generovaný celý naráz (E49).
- **Voda:** před erozí odteče 631 z 2458 buněk deště, zbytek se vsákne do půdy a propustných sedimentů. Mokrých sloupců 102,
  jezírko v prohlubni, stružky na svazích kopců. Po erozi odteče 655 (B) / 683 (C). **Hypotéza o soustředění toku neplatí:**
  podíl toku v nejsilnějších 5 % sloupců klesl ze 42 % na 37 % (B) / 34 % (C). Eroze na 16 × 16 bodech koryta spíš rozšíří
  a zahladí, než prohloubí. Chyba bilance vody 1e-5, eroze je deterministická (2× stejný hash).
- **Čas:** eroze 0,2 s (blok/okraj) a 0,3 s (svět) na 8 bloků, převzorkování buněk 0,4 s. Voda 400 tiků 15 s. Celý bench 51 s.
- **Artefakt:** chybějící blok (0,2) je nepropustná stěna, takže voda z kopce (0,1) se o něj opře a teče podél.

## E48 3D grafy funkcí vrstev (plán, zapsáno před pokusem 18:45)
- **Co:** funkce povrchu a hranic vrstev (`FN.surface_m`, `FN.boundary_m`) navzorkované HUSTĚJI, než je řídicí mřížka
  (25 × 25 bodů na blok, krok 0,33 m, řídicí body 0,5 m), vykreslené jako sítě v krychli bloku 8 × 8 × 32 m. Barva = hornina vrstvy,
  bez textur a bez popisků. GIF: vrstvy přibývají zdola nahoru, nakonec povrch, pomalá rotace. Typy: nížina (louka),
  hora vyzdvižená, hora zvrásněná, sopka, prohlubeň (jezero), klín (2 bloky).
- **Očekávání:** plochy jsou spojité (bilineární mezi řídicími body), vyklíněná vrstva končí tam, kde mocnost klesne na 0.
  Jádro vyzdvižené hory, sopouch a tělesa NEJSOU hranice vrstev (jsou to tvary ve funkci materiálu), takže v grafu nebudou.
  Hranice nad povrchem se oříznou (vrstva tam chybí, odnesla ji šablona povrchu).
- **Limit:** GIF < 8 MB.

### E48 výsledky (2026-11-18 ~18:45, `./run.sh funkce` = `tools/dump_funkce.gd` + `tools/gif_funkce.py`)
- 6 GIFů `shots/48_funkce_{nizina,hora_vyzdvizena,hora_zvrasnena,sopka,jezero,klin}.gif`, 88 snímků, 8 fps (11 s),
  440 px, 1,9–2,7 MB (limit 8 MB). Navíc `_vrstvy.png` (všechny vrstvy) a `_still.png` (s povrchem).
- Plán snímků: 20 vrstev po 2 snímcích zdola nahoru, 8 snímků povrch, 40 snímků rotace (napůl bez povrchu, napůl s ním).
  Rotace 1,6° na snímek, u klínu 0,7° a nízký pohled ze strany na šev.
- Svisle je krychle stlačená na ½ (`FN_ZSCALE`), jinak je blok 8 × 8 × 32 m úzký sloup. Barva vrstvy = barva horniny z tabulky,
  stínování podle normály, povrch barvený výškou. Žádný text, osy ani legenda.
- Vzorkování 25 × 25 na blok (krok 0,33 m) dává hladké plochy i mezi řídicími body (bilineárně). Na hranici bloku se bere soused.
  Dump funkcí trvá 3,2 s (včetně stavby 8 + 2 bloků), vykreslení 6 GIFů 31 s na 8 jádrech.
- **Vidět je:** vrstvy se pod horami zvedají (vyzdvižená: horní sedimenty kopírují kopec a končí na povrchu, zvrásněná: klenba
  se s hloubkou tlumí). U sopky se vrstvy zvedají ke kráteru, pod prohlubní se prohýbají. Vyklíněné vrstvy jsou díry v ploše
  (mocnost < 3 cm se nekreslí).
- **Negativní:** jádro vyzdvižené hory, sopouch a tělesa (dóm, komín, žíly) nejsou hranice vrstev, takže v grafech nejsou.
  Malířský algoritmus matplotlibu občas prostrčí kus nižší plochy přes vyšší (drobné světlé skvrny). U klínu je vyklínění
  vidět jen z nízkého pohledu, shora splyne.

## E49 malý svět 8 × 8 bloků: hrubě celý svět → dlaždice → detail od první (plán, zapsáno před pokusem 18:50)
- **Co (Janův spojený nápad 17:47–18:05):** 1) hrubý svět naráz na mřížce 64 × 64 (1 bod = 1 m = 2 řídicí body bloku):
  výšková mapa (šum + hřbety hor + jedna sopka), 2) jednoduché počasí (západní vítr, vlhkost ubývá s výstupem → návětrné srážky,
  teplota z výšky), 3) eroze kapkami (`eroze_mrizka.gd`) + řeky (tok podle srážek po vyplnění bezodtokých míst, koryto
  se zahloubí) a jezera, 4) biomy z výšky, teploty, vlhkosti a řek, 5) řez na 8 × 8 dlaždic: každé dlaždici typ blueprintu
  (louka, kopec, svah, prohlubeň, hora vyzdvižená / zvrásněná, sopka) a podmnožinu hornin z biomu a výšky, 6) detailní dlaždice
  pipeline v2 jedna po druhé od PRVNÍ dlaždice do šířky (BFS) s navázáním na sousedy. Povrch dlaždice = hrubá výška
  (bilineárně na 16 × 16) + jemný šum, geologie podle typu.
- **Hypotéza:** švy povrchu i vrstev zůstanou jako v sledu 46 (šev vrstev ≲ 0,1, povrch 0), protože hrubá výška je spojitá
  a navázání ji jen dorovná. Typ dlaždice podle hrubého světa dá souvislé pohoří a údolí. Celkový čas < 60 s
  (hrubý svět < 2 s, 64 dlaždic po ~0,3 s).
- **Výstup:** `shots/49_svet_8x8_faze.gif` (bez textu) + snímky fází, časy fází v `shots/bench_svet8.txt`.

### E49b typ hory po masivech (plán, 18:58)
- **Zjištění z E49:** švy vrstev 0,65 (uvnitř 0,55), max skok 17 buněk u horních vrstev. Když jsou všechny hory zvrásněné
  (`--s8_force_mtn=hora_zvrasnena`), je šev 0,04. Příčina: vyzdvižená hora nemá kůži horských hornin a nad poslední hranicí
  má jádro (krystalinikum), ostatní typy tam mají horské horniny. Hranice bs navazují (skok mocnosti 0), ale tohle pravidlo
  výplně podle typu přes šev nenavazuje.
- **Pokus:** typ hory se určí pro celý souvislý masiv horských dlaždic (průměr tektoniky masivu), ne po dlaždicích.
  Odpadnou švy vyzdvižená | zvrásněná, zůstanou švy vyzdvižená | kopec / louka na okraji masivu.
- **Hypotéza:** šev vrstev klesne zhruba na polovinu, ne na 0,04.

### E49 + E49b výsledky (2026-11-18 ~18:55, `shots/bench_svet8.txt`, `./run.sh svet8`)
- **Čas celkem 15–17 s** pro 8 × 8 bloků (hypotéza < 60 s **platí**). Hrubý svět 0,54–0,67 s (terén 4 ms, počasí 7 ms,
  eroze 8 dávek + řeky 0,6 s, biomy 28 ms, dlaždice 19 ms). Detail 64 dlaždic od (3, 4) do šířky 15–16 s, průměr 0,25 s
  a max 0,39 s na dlaždici. GIF a snímky v Pythonu 4 s, 3D snímek v Godotu 20 s.
- **Hrubý svět:** 2 pohoří, 9 dlaždic s jezerem, sopka v (1, 4), řeky 5,7 % bodů, jezera 322 bodů (7,9 %).
  Biomy: niva 1049, step 916, louka 452, skály 448, sníh 420, jezero 322, řeka 235, les 225, mokřad 29.
  Typy dlaždic: louka 24, hora zvrásněná 12, prohlubeň 9, hora vyzdvižená 7, kopec 6, svah 5, sopka 1.
- **Švy:** povrch **0,00** (max 0). Skok mocnosti vrstev na švu 0,00 a náhlé objevení vrstvy na švu 0 z 1792 dvojic.
  Švy vrstev v buňkách: **0,16** (uvnitř 0,53) s typem hory po masivech. Validátor OK 64/64, minerály přesně 57/64
  (schodek nahlášen, chybí hostitel v jádru hory). Determinismus 2× stejný hash.
- **Opravy během pokusu:**
  1) Volná strana povrchu brala rovinu surf_ref, takže každá dlaždice byla „kopeček“ uprostřed roviny. Když blueprint nese
     `base_hm` (hrubý svět), je regionální základ povrchu = hrubý svět na vlastním okraji. Pro vrstvy platí dál Janovo
     pravidlo 17:38: podmnožina blueprintu.
  2) Roh mezi skutečným sousedem a regionálním základem se průměroval (skok až 1,3 buňky jen v rozích). Teď má skutečný
     soused přednost (`surface.gd adapt(real)`, stejně jako u mocností). Sled 46 má hash beze změny (00dc4dc614729194),
     v1 taky (45f42cd597c0f8c9).
- **E49b (negativní → zlepšeno):** typ hory po dlaždicích dává šev vrstev 0,48 (max 17 buněk), po masivech 0,16, všechny
  hory zvrásněné 0,03 (minerály pak 64/64). Hypotéza „zhruba polovina“ platí (0,48 → 0,16; v prvním světě 0,65 → 0,30).
  Zbytek je na švech vyzdvižená hora | kopec / louka. Pravidlo výplně nad poslední hranicí (jádro vs. kůže horských hornin)
  podle typu se přes šev nenavazuje. Návrh: jádro jako další spojitá funkce s navázáním (otázka pro Jana).
- **Negativní / omezení:** eroze v dávkách má vlastní seed na dávku, takže počet dávek (`s8_frames`) mění svět. Řeky jsou
  v detailu jen vyhloubené koryto, vodu v GIFu kreslím z hrubé fáze (voda_sim na 128 × 128 × 64 jsem nespouštěl). Biomy se
  zatím promítnou jen do podmnožiny hornin, ne do vegetace. Počet minerálů je podle typu, ne podle biomu.

## E50 svět 8 × 8 ve větším rozlišení: 64 × 64 × 256 buněk na blok (plán, zapsáno před pokusem 2026-11-18 20:15)
- **Co (Jan 20:04–20:09):** stejný běh jako E49 (`svet8`), ale detailní bloky se vzorkují v **64 × 64 × 256 buňkách**.
  Stavět 256 × 256 bloků se nemá. Výsledkem je svět 512 × 512 × 256 buněk (67 M), tj. 64 × víc buněk než E49.
- **Měřítko (Janova spojitá funkční API 16:42):** blok zůstává 8 × 8 × 32 m s řídicí mřížkou 16 × 16 (U 0,5 m).
  Mění se jen vzorkování `geo_fn.sample(n = 64)`, buňka má 0,125 m. Minerály a dutiny drží objem: cíl × (n/16)³.
  Hrubý svět, eroze, řeky, biomy, dlaždice a navázání sousedů na řídicí mřížce jsou stejné jako v E49, takže E49 a E50
  dají stejný svět v jiném rozlišení.
- **Parametry:** vše přepsatelné `--klic=hodnota`.
  - `s64_n` = buňky na stranu bloku (výška 4n)
  - `s64_voda_n` = rozlišení vodní mřížky na blok (výchozí = `s64_n`)
  - `s64_podzemi` = zapnout podzemí
  - `s64_det` = determinismus 2 ×
  - `s64_bloky` = kolik bloků (0 = všechny)
  - `s64_hash` = hash buněk
  - parametry vody v buňkách a na sloupec se přepočtou koeficientem f = n/16 a předají se dál (`voda_cell_m`):
    pram_dist, ug_hloubka, tok_margin, pit_drain_q, ug_leak_q, ug_cell_m3
- **Fáze a měření** (každá zvlášť, čas na stěnu, RSS z /proc/self/status, peak = VmHWM):
  1) hrubý terén
  2) počasí
  3) eroze + řeky
  4) biomy
  5) dlaždice
  6) každý detailní blok zvlášť:
     - navázání na sousedy (povrch + mocnosti vrstev)
     - vrstvy (cíle + vzorkování 64³ · 4)
     - minerály
     - dutiny
     - min / medián / max na blok
  7) voda:
     - povrch: prameny + koryto + strže (`strze.gd`) na mřížce 512 × 512
     - podzemí (`podzemi.gd`) ve 3D 512 × 512 × 256
  8) render zvlášť: GIF v Pythonu a izo PNG v Godotu (načte uložená data, negeneruje znovu)
- **Hypotéza:** vzorkování roste lineárně s počtem buněk (64 ×).
  - E49 blok 0,25 s → E50 blok 8–20 s, celý detail 10–20 min v GDScriptu na jednom jádru
  - hrubý svět stejný (~0,6 s)
  - voda povrch ~1–3 s, podzemí desítky s (BFS tělesa ~64 × buněk)
  - paměť: buňky 64 MB + 3D podzemí 67 MB + slovníky BFS, peak < 2 GB
  - švy povrchu u jemných buněk ≈ uvnitř (spojitá funkce)
- **Výstup:**
  - `shots/50_svet64_faze.gif` (hrubý svět, eroze, řeky, biomy, dlaždice, detailní bloky přibývají, voda), bez snímků jednotlivých vrstev
  - `shots/50_svet64_iso.png`
  - `shots/bench_svet64.txt`
  - `./run.sh svet64`
- **Telefon:** odhad z měření (GDScript, 1 jádro Xeon) → C#, vlákna, co optimalizovat napřed.

### Regrese po v3 (2026-11-18 19:00)
Sled 46: determinismus 2× `00dc4dc614729194` a po snímcích = naráz (`00dc4dc61472`), švy a ostatní čísla v2.2 beze změny.
v1 (`./run.sh test`): C 0,08, hash 45f42cd597c0f8c9 2×. Změny v `geo_fn` (nános, `hm_pre`), `blueprint` (`base_hm`)
a `surface.adapt(real)` se bez nových vstupů neprojeví.

**Otevřené otázky v3:**
1. Eroze ve hře: po blocích s připnutým okrajem (E47 B, nezávislé na pořadí), nebo jen jednou na hrubém světě (E49)?
2. Jádro vyzdvižené hory: navazovat ho přes šev jako další funkci, nebo typ hory určovat jen pro celý masiv?
3. Síla eroze: 800 kapek / cap 1 dává strže do 3 m na horách. Chce Jan víc, nebo míň?
4. Má hrubý svět určovat i počty minerálů a vodu dlaždice (teď jsou minerály podle typu a voda podle srážek)?

## E47b strže ~2 m, ponory a vodopády (Jan 19:14; plán zapsán před pokusem 19:16)
- **Janovo zadání:** strže typicky ~2 m, hloubka proměnná podle materiálu, sklonu a průtoku. Na propustné nebo rozpustné
  hornině se potok může ztratit do podzemí (ponor). Přes útes teče vodopád. Zkusit opravit negativní výsledek E47
  (tok se nesoustředil do koryt).
- **Postup (`scripts/voda/strze.gd`, režim eroze `strze`):**
  1) Tok po povrchu celého světa naráz: vyplnění bezodtokých míst (priority-flood [20]), D8, akumulace deště (sloupce).
     Kvůli povodí jde jen po celém světě. Varianta po blocích s připnutým okrajem se tu netestuje, otázka per-blok vs. hrubý svět zůstává otevřená.
  2) Koryto: akumulace A ≥ `strz_thr`. Zahloubení podle stream-power [23] E = K · k_mat · A^m · S^n (m 0,5, n 1).
     K se kalibruje tak, aby **medián hloubky koryt = `strz_target_m` (2 m)**. Strop je 2,5 × cíl, břehy (4-sousedé) dostanou 0,35 E.
     k_mat = erodovatelnost horniny 2 m pod povrchem: půda, písek, štěrk, spraš 1,3, sedimenty 1,0, horské horniny 0,7,
     krystalinikum 0,5, plášť 0,4, sníh 0,3.
  3) **Ponor:** buňka koryta, kde je 2 m pod povrchem propustná hornina (perm ≥ `ponor_perm` ze sdílené tabulky) nebo
     rozpustná (krasová: vápence, dolomit, sádrovec, sůl). Nejjednodušší varianta: voda **zmizí do podzemí** (zvodeň se
     nemodeluje). Ponor pohltí až `ponor_cap` průtoku, po proudu je koryto suché nebo mělčí. Ve voda_sim se z ponorových sloupců
     odebírá volná voda (`ponor_rate` za tik) a počítá se zvlášť.
  4) **Vodopád:** buňka koryta, kde je spád k dalšímu bodu po proudu ≥ `vodopad_m` (1,5 m). Pod vodopádem tůň:
     prohloubení o min(0,5 · spád, 1 m), okolí 0,4 ×. Ve 3D svislá vodní stěna a pěna.
- **Hypotéza:** medián strže 2 m, rozptyl podle materiálu (měkké hlubší). Tok se soustředí: podíl toku v nejsilnějších 5 %
  sloupců > 42 % (E47 před erozí). Ponory hlavně v nížině (spraš, štěrk/písek, vápenec), vodopády na úbočí hor a sopky.
- **Metriky:** hloubky koryt (medián, p90, max, po třídách materiálu), počet ponorů a vodopádů, výšky vodopádů, soustředění toku,
  voda pohlcená ponory, šev povrchu, čas.

### E47c plán (Jan 19:16–19:31): voda jen z pramenů, tok jako uložené koryto, lokální přepočet, plnění tůní událostmi, okraj ostrova = vodopád
- **Déšť je jen vizuální, vodu nedává.** Voda jen z pramenů (stálý průtok l/s). Generují se jednoduše a nastavitelně (`pram_*`): (a) sníh / vrcholy (horní kvantil výšky), (b) styk propustné nad nepropustnou na svahu (2 m pod povrchem perm ≥ ponor_perm, 4 m pod povrchem perm ≤ 0,05), (c) krasová vyvěračka (nejnižší svahový sloupec rozpustné horniny). Min. rozestup, max počet.
- **Tok = vygenerované koryto** (D8 nad priority-flood [20], průtok z pramenů, ztráty v ponorech jako E47b) uložené ve stavu; strže E47b se teď řídí průtokem z pramenů (místo plochy povodí z deště).
- **Nic se nemění → nic se nesimuluje.** Při změně terénu: pokud změna nesahá na mokrý sloupec (± 1), práce 0. Jinak lokální okno (změna + okraj `tok_margin`): nový priority-flood uvnitř okna (okraj okna drží staré hodnoty), přepočet průtoku v okně a pak jen po proudu, dokud se průtok nepřestane měnit (ustálení). Když tůň dosáhne okraje okna, okno se zvětší. Ověření proti plnému přepočtu.
- **Plnění tůní:** pro každou tůň předpočítat po vrstvách výšky (po U = 0,5 m) plochu, objem a čas naplnění z přítoku (události „hladina dosáhla vrstvy k v čase t“), žádné periodické tiky.
- **Plovoucí ostrov:** voda, která dojde na okraj mapy, přepadá přes okraj jako vodopád do mlhy pod ostrovem a dál se nesimuluje (okraj = odtok). Chybějící slot zůstává zdí (blok, který ještě není vygenerovaný, není okraj ostrova) – zapsat jako předpoklad.
- Měřit: počet a druh pramenů, délka koryt, hloubky strží, ponory, vodopády (vnitřní i okrajové, průtok přes okraj), tůně s časy plnění, lokální přepočet (dotčené sloupce vs 2304, čas vs plný, rozdíl vs plný přepočet). Snímky 47b_* včetně okrajového vodopádu.
- **Jan 19:33: pramen = zvláštní typ buňky** (gx, gy, z = výška buňky pramene, q l/s, druh). Když je pramen zasypaný / uzavřený v dutině, kam voda nemůže (nad buňkou pramene není volný vzduch otevřený ven), **neteče nic** (žádný tlak, žádné prosakování). Po otevření teče znovu se stejným q. Na mřížce 2,5D: aktivní ⇔ povrch sloupce ≤ z pramene + 1 (buňka nad pramenem je volná). Demo: zasypat → koryto po proudu vyschne lokálním přepočtem, odkopat → teče znovu, obojí shodné s plným přepočtem.
- **Jan 19:48: propustnost prohlubně (schváleno).** Prohlubeň jako celek má odtok do podzemí D (jednotky vody za čas).
  Implementace: D = Σ perm(buňka) · `pit_drain_q` přes buňky tůně (perm ze sdílené tabulky, kras = 1). Plnění =
  přítok Q − D. Čas vrstvy = objem vrstvy / (Q − D). Po naplnění jde D do propustné vrstvy a podzemím
  k vyvěračce v nejbližší stěně ostrova (vodopád do mlhy). Zbytek Q − D přepadá nejnižším okrajem a teče dál po povrchu.
  Ustálený stav ukládá jen toto rozdělení. D ≥ Q → nenaplní se (ponor). D = 0 → všechno přepadá. Test na Janově
  příkladu (pramen 1/t, jáma 2 × 2 × 2 = 8, D 0,5 → plná za 16 t, pak 0,5 + 0,5).

### E47b + E47c výsledky (2026-11-18 ~19:51; `./run.sh voda47b` = `shots/bench_voda_c.txt`, `bench_voda_b.txt`, `test_tun.txt`)
**E47b (voda z plochy, srovnávací varianta `voda_zdroj=plocha`; po přepnutí na prameny už to není výchozí model):**
- Strže: 129 sloupců koryta (6,3 %). Hloubka **medián 2,00 m**, p10 0,73, p90 4,00 m (= strop `strz_max_k` · 2 m).
  Podle materiálu: měkké (půda, spraš, štěrk) medián 2,47 m, sedimenty 1,22 m, tvrdé 2,14 m (málo vzorků, 9 sloupců).
- **Soustředění toku (negativ E47 opraven):** podíl toku v nejsilnějších 5 % sloupců **42 % → 57 %** (E47 okraj 37 %).
  Voda v kalužích 14,6 → 44,9 m³, ale skoro všechna stojí v korytech (stružka v korytě, ne plošné kaluže). Měřeno
  na mezistupni: mimo koryta 43 % → 9 %.
- Ponory 10 (štěrk/písek, konec ztrácejícího se toku). Vodopády 4 (sopka 3, kopec 1), 1,76–1,78 m, tůň pod nimi 0,89 m.
- **Negativy:** (1) Koryta jsou krátké úseky, ne síť: svět 24 × 24 m má malá povodí (max 131 sloupců i bez ponorů).
  Říční síť dává až hrubý svět (E49). (2) Pevný γ = 0,5 (hloubka = cíl · (E/medián)^γ). Čistý stream power (γ = 1) dával
  p90 na stropu kvůli 50× rozdílu sklonů. (3) Spádový profil koryta (`strz_mono`) kaluže zhoršil (29,9 → 33,9 m³),
  proto je vypnutý. (4) Šev povrchu 0,45 U (celý svět naráz, bez připnutí okraje). Otázka per-blok vs hrubý svět
  zůstává otevřená.

**E47c (výchozí: voda jen z pramenů, déšť jen vizuální):**
- **Prameny 7, celkem 18 l/s:** sníh/vrchol 3 × 4 l/s (žula, subalpínské sutě, sopouch) a styk propustná/nepropustná na svahu
  4 × 1,5 l/s (spraš, štěrk nad nepropustnou). **Krasová vyvěračka 0 (negativ):** v tomhle světě není okraj krasového
  tělesa níž než nekrasový soused.
- Pramen je zvláštní buňka (gi, z, q, druh). Uzavřený (buňka nad ním není volná) **neteče vůbec**, po otevření teče znovu:
  ověřeno zasypáním a odkopáním, shodné s plným přepočtem.
- Tok: mokrých sloupců 81 (4 %), zahloubené koryto 35. **Strže medián 2,00 m**, p10 0,35, p90 3,77, max 4,00 m.
  Vodopády ve strži 7 (medián 2,0 m, max 4,1 m, tůň pod nimi max 1,0 m).
- **Okraj ostrova:** 7 přepadů po povrchu přes okraj (15,3 l/s = 85 %) a 4 vyvěračky ve stěně z podzemí (2,47 l/s). Ztráty
  po cestě 0,23 l/s. Ustálené rozdělení se uloží a dál se nic nepočítá. Ve 3D svislá stěna vody do mlhy (`47b_okraj.png`).
- **Plnění tůní (události, žádné tiky):** jezero v prohlubni 639 sloupců, 4,65 m, 162 m³, přítok 3,99 l/s, odtok do
  podzemí 2,41 l/s → **plná za 28,5 h**, 10 událostí po 0,5 m (0,5 m za 21 min … 4,0 m za 16,5 h). Ustáleno: 2,41 l/s
  podzemím a 1,58 l/s přelivem. Malé tůně se plní 6–33 min.
- **Lokální přepočet (nic se nemění → nic se nepočítá):**
  - kopeček 2 m 8 sloupců od vody: 0 sloupců, 0,2 ms
  - hráz 2 m: okno 558, dotčeno 585 z 2304 sloupců, 20 ms (plný přepočet 42 ms), okno se jednou zvětšilo
  - zasypaný / odkopaný pramen: 203 sloupců, 12 ms

  Ve všech případech je **rozdíl proti plnému přepočtu 0,000 l/s a mokré sloupce se shodují na 100 %**. Deterministické.
- **Test Janova příkladu (`tools/test_tun.gd`):** D 0,5 → plná za 16,016 t (+0,1 % kvůli EPS priority-flood nad
  okrajem), pak 0,5 podzemím a 0,5 přepadem. D 1,0 → nenaplní se (ponor), 1,0 podzemím. D 0 → plná za 8 t, všechno přepadá.
  **VŠE OK.**
- **Negativy a předpoklady:**
  - Hráz 2 m přes potok na svahu tůň nevytvořila: potok hráz obtekl (7 sloupců napříč nestačí).
  - Chybějící slot je stěna (blok, který ještě není vygenerovaný), ne okraj ostrova.
  - Podzemní tok jde přímo k nejbližšímu okraji, propustná vrstva se zatím nesleduje.
  - V tůni platí jen odtok tůně. Krasová buňka v jezeře proto už není samostatný ponor, je součástí D jezera.
  - Jednotky: buňka 0,5 × 0,5 m, vrstva 0,5 m, průtok v l/s. `pit_drain_q` 0,01 l/s na sloupec je odhad.
- Časy: celý E47c bench 5,2 s (strže 47 ms, převzorkování 0,39 s, plný výpočet koryta 42 ms). Regrese: sled 46
  00dc4dc614729194 a v1 45f42cd597c0f8c9 beze změny (19:48).
- **Otevřené otázky (nerozhodnuto):**
  - eroze po blocích vs hrubý svět
  - jádro hory přes šev
  - minerály z hrubého světa
  - Nové: jak daleko vede podzemní tok (nejbližší okraj vs sledovat propustnou vrstvu)? Má mít krasová vyvěračka vlastní pravidlo?

## E47d podzemní voda po propustné vrstvě (Jan 20:00; plán zapsán před pokusem 20:02)
- **Janovo rozhodnutí:** voda z odtoku tůně (19:48) nejde k nejbližšímu okraji, ale **sleduje propustnou vrstvu**. (a) Narazí-li na dutinu,
  zaplní ji → podzemní jezero / nádrž. (b) Propustné těleso obklopené nepropustnou horninou se časem zaplní a pak přeteče
  nejnižším výstupem, např. do tůně 4 × 4 nebo pramenem ve svahu / stěně. Okraj ostrova dál = výtok do mlhy. Krasová vyvěračka zůstává otevřená.
- **Model (`scripts/voda/podzemi.gd`, 3D buňky celého světa):**
  - **Podzemní těleso** = souvislá (6-sousedé) množina buněk s propustnou horninou (perm ≥ `ponor_perm`, sdílená tabulka) nebo
    vzduchem pod povrchem (dutina). Chybějící slot a nepropustná hornina = stěna.
  - **Vstup:** odtok D tůně (19:48) vstoupí do nejvyšší buňky tělesa pod tůní (hledá se do `ug_hloubka` buněk). Bez tělesa
    se voda ztratí do hloubky (nemodeluje se, počítá se zvlášť).
  - **Objem buňky (jednoduše):** dutina = celá buňka (0,125 m³), propustná hornina = pórovitost `por` ze sdílené tabulky × buňka.
  - **Plnění** jako tůň: hladina tělesa stoupá po vrstvách z (jedna nádrž, předpoklad spojitých pórů). Události = objem vrstev /
    (přítok − odtok tělesa). Odtok tělesa = průsak do slabě propustného okolí (0 < perm < `ponor_perm`): Σ stěn · perm · `ug_leak_q`.
    Odtok ≥ přítok → nenaplní se.
  - **Výstup** = nejnižší buňka tělesa sousedící s otevřeným vzduchem nad terénem (pramen ve svahu / stěně, výtok do tůně)
    nebo ležící na okraji ostrova (vyvěračka ve stěně → mlha). Při shodě rozhoduje kratší cesta. Bez výstupu se těleso naplní
    a pak už nic nepřijímá (odtok tůně → 0, všechno přetéká po povrchu).
  - **Ustálení:** výstup na povrchu = nový zdroj na povrchu (přidá se ke zdrojům koryta). Iteruje se povrch ↔ podzemí, dokud se zdroje
    nemění (max 4×). Tůň, do které ústí plné těleso, do něj už neodtéká (smyčka). Cesta po vrstvě = nejkratší cesta v tělese
    od vstupu k výstupu (kvůli kreslení).
- **Testy (`tools/test_podzemi.gd`):** (1) uzavřená propustná čočka se plní a pak přetéká do tůně 4 × 4. (2) Tok narazí na
  dutinu v propustné vrstvě, zaplní ji (podzemní jezero), pak teče po vrstvě k okraji ostrova. Čísla se ověří ručně.
- **Svět (bench E47c/d):** kam tečou odtoky tůní, kolik podzemních jezer a výstupů, časy plnění, cesty. Snímky `47d_*`:
  řez s cestou po vrstvě, zaplněná čočka nebo podzemní jezero, přetok.

### E47d výsledky (2026-11-18 ~20:15; `./run.sh voda47d` = `shots/test_podzemi.txt`, `bench_voda_c.txt`, snímky `47d_*`)
- **Testy `tools/test_podzemi.gd` – VŠE OK** (jednotky: buňka 1, průtok 1/t; pískovec por 0,20, okolí perm 0):
  1) **uzavřená čočka 8 × 6 × 4 → tůň 4 × 4:** 192 buněk, 38,4 objemu pórů, plná za 38,4 t (4 události po vrstvách).
     Pak přetéká nejnižším výstupem = dnem tůně (z 10). Tůň 4 × 4 × 3 = 48 je plná za dalších 48 t. Přeliv přes okraj
     ostrova 1/t, celkem 86,5 t.
  2) **dutina 3 × 3 × 3 pod vrstvou:** zaplní se jako **podzemní jezero** (27 buněk). Objem do výstupu 40,2 (27 + 66 · 0,2)
     = 40,2 t. Pak voda teče po vrstvě k okraji ostrova (z 5) a 1/t vytéká ze stěny do mlhy.
  3) **uzavřená čočka bez výstupu:** plná za 6,4 t (32 · 0,2), pak nepřijímá nic (odtok tůně → 0, vše přeteče po povrchu).
- **Svět (sled 46, E47c + E47d):** odtok jezera 2,47 l/s vstoupí do propustného tělesa pod jezerem. Je to 15 940 buněk
  (souvislá půda, spraš, písek a pískovec u povrchu). Voda jde **po vrstvě 54 buněk** k východní stěně ostrova a vytéká
  v z 24 **2,06 l/s** do mlhy. Průsak do slabě propustného okolí je 0,41 l/s. Plnění tělesa do výstupu: 1,3 m³ za 10 min
  (výstup je nízko, nasytí se jen spodek tělesa z 22–24). Podzemní jezero ani přetékající čočka ve světě **nevznikly
  (negativ):** pod jezerem není dutina ani uzavřená čočka, proto jsou ukázané na demo blocích (`47d_cocka`, `47d_jezero`).
- Rozdělení 18 l/s z pramenů:
  - přes okraj po povrchu 15,30
  - ze stěny z podzemí 2,06
  - průsak a ztráty po cestě 0,64
- **Lokální přepočet s podzemím** vždy sedí s plným přepočtem: rozdíl 0,000 l/s a mokré sloupce 100 %, včetně výtoků
  z podzemí.
  - sucho: 5 ms
  - zasypaný / odkopaný pramen: 16–18 ms (plný přepočet 290 ms)
  - hráz: 267 ms. Hráz leží nad propustným tělesem, takže se těleso počítá znovu (mezipaměť těles se zneplatní).
- **Časy:** plný výpočet koryta s podzemím 0,3 s (bez podzemí 42 ms; BFS tělesa ~16 tis. buněk). Strže s podzemím 0,5 s.
  Bench E47c/d 7,9 s.
- **Předpoklady a negativy:**
  - Těleso se plní jako jedna nádrž po vrstvách z (spojité póry). Část tělesa za výš položeným sedlem se tedy počítá jako
    zaplněná, i když by se tam voda nedostala.
  - Objem buňky: dutina celá, hornina = por ze sdílené tabulky (kras bez por 0,05).
  - Terén změněný hráčem se do 3D buněk podzemí zatím nepromítá (podzemní ctx se staví ze světa). Lokální změna jen
    zneplatní mezipaměť těles.
  - Výtok do zdrojové tůně = smyčka, nepočítá se.
  - Body na cestě (`path`) jsou nejkratší cesta tělesem (pro kreslení), ne proudnice.
- **Otevřené (nerozhodnuto):**
  - krasová vyvěračka (vlastní pravidlo)
  - eroze po blocích vs hrubý svět
  - jádro hory přes šev
  - minerály z hrubého světa
