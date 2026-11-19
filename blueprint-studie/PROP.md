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

## E66 integrace terénu a vody do prototypu (plán 2026-11-19 14:30; Jan 14:21 „Studií terénu a vody implementuj do prototyp projektu.“)
- **Cíl:** prototyp (`../godot-prototyp/`) umí ostrov z blueprintů studie (vrstvy jako funkce, navázání na sousedy, klíny)
  a vodu studie (prameny, priority-flood + D8, tůně, podzemí auto, vodopád přes okraj do mlhy, lokální přepočet po kopání).
  Studie zůstávají beze změny a jejich hashe platí dál (E61: v1 dda863feffe6f611, sled46 d8af7f59b6f8da70, svet8 ec0681cc6426,
  voda a14136754dd1, voda_b 5ae2b366e84a, voda_b --b e8cbbc78ca88). Těžba (`tezba-studie`) se nepřenáší.
- **Postup:**
  1. Verze přes git (Jan 14:35: žádné záložní kopie): výchozí stav prototypu jako samostatný commit v `Utalag/Willage_Client`, pak práce po logických krocích.
  2. **Přenos modulů skriptem** `godot-prototyp/tools/port_studie.py`: kopie beze změny logiky, změní se jen cesty `preload`
     a výstupní cesty testů. Rozdělení: `scripts/teren/` (bp: funkce vrstev, navázání, minerály, dutiny), `scripts/teren/zaklad/`
     (kopie studie gen_v3 / ore_v0 / mat 256 id …), `scripts/teren/svet/` (svet8, potřebuje ho tok), `scripts/voda/` (prameny, tok, strže,
     tůně), `scripts/voda/povrch/` (E60 tok60), `scripts/voda/podzemi/` (E52 ug_funkce + auto E55, E58 ug58, E64 alg64),
     `scripts/voda/eroze/` (E51, E54). Testy studie jdou do `scripts/studie_testy/` jen pro test parity.
  3. **Jediná změna logiky = opt-in příznak:** okraj ostrova u chybějícího slotu (mlha) se chová jako okraj mapy
     (`edge_wall`, výchozí vypnuto), aby kruhový ostrov přepadal do mlhy všude, ne jen na okraji obdélníku. Ve studijních
     světech je vypnutý, takže parita platí.
  4. **Adaptér do hry:** `--gen=bp` (výchozí zůstává v3, dokud Jan nerozhodne). Blok ostrova = blueprint (typ → tvar),
     navázání na už vložené sousedy přes svět studie (sloty ostrova posunuté do kladných souřadnic). Hra dál pracuje s Mat 0–12:
     `Block.cells` = herní třída materiálu (horniny → žula / vápenec / čedič / písek / jíl, rudy → měď / železo), `Block.geo` = plné id 0–255
     pro vzhled (paleta hornin) a pro vodu. Podzemí skryté, rentgen (stávající přepínač) ukáže vrstvy.
  5. **Voda ostrova:** mřížka 16 sloupců na blok přes celý ostrov, prameny, `strze.run` s podzemím `ug_funkce` v režimu auto
     (nepropustné dno → preliv / pramen, propustné → nádrž s průsakem), po kopání `tok60.update` jen kolem změny (A+C),
     podzemí E64 K+I+P(+R kroky po počtu operací) jako ve studii. Déšť jen vizuální, počasí ne, svah limit vypnutý (E56 výchozí).
     Eroze / usazování E51 a dohnání E54 se přenesou jako moduly, ve hře se zatím nespouštějí (jen po kopání koryto).
  6. **Ověření:** prototyp headless bez chyb; test parity v prototypu (stejných 6 hashů ze stejných světů, navíc hash buněk
     a vody adaptéru proti `pipeline.run_sync` pro sled46); časy vložení bloku a kopání proti číslům studie;
     snímky `shots/66_*.png` (řeka, tůň, pramen, vodopád na okraji, rentgen řez). README prototypu.
- **Hypotéza:** parita bit po bitu (kopie se mění jen v cestách). Vložení bloku bp ≈ 0,25–0,4 s jako E49 detail
  (+ povrch a tráva prototypu ~0,4 s), voda ostrova 7 bloků (≈ 112 × 112 sloupců) plně < 1 s, kopání u vody desítky ms.

## E72 slučování drobných výstupů a průsaků E71 pod prahem p67_prune_min (výsledky 2026-11-19 22:35, větev `e68-orchestrator`; Jan 22:24 „malé průsaky a přelivy pod prahem se slučují“, TODO Voda „Slučování drobných výstupů z pastí“)
- **Pozn. k postupu:** Jan chtěl opravu hned, před E68; plán a výsledky jsou proto v jednom zápisu (napsáno po pokusu).
- **Příčina (E71):** práh `p67_prune_min` (0,1 l/s, E67b) se použil jen při dělení do stran. Nové cesty E71 ho obcházely:
  dělení kapacitou dolů (dolů / zbytek), průsak protékané vody dnem a výstupy pastí. Navíc zdroje na ostrově jsou samy
  malé (desítky tůní po 0,02–0,05 l/s), takže i bez E71 končily drobnými výstupy (E70: 67 výstupů 0,02–0,05 l/s).
- **Co je nového (`ug67.gd`, studie i prototyp; přepínače `p72_slucovat` (výchozí zapnuto), `p72_prusak` (výchozí zapnuto); práh
  je stávající `p67_prune_min`, žádný nový):**
  - dělení kapacitou: menší z větví (dolů / dál) pod prahem → celá do větší (dolů smí přetéct kapacitu nejvýš o < práh);
  - průsak protékané vody: průsak nebo zbytek pod prahem → do větší části;
  - výstupy: výstup pod prahem se přičte nejbližšímu silnému výstupu (≥ práh) téhož volání; shoda vzdálenosti i průtoku →
    rovným dílem. Když silný není, vše do největšího (shoda → rovným dílem, např. plochá vrstva zůstane 80 × 0,0125);
  - vypnuto = bitově E71 (ostrov otisk výstupů 43943a241bcaf1d0, výkopy e704e819891f87e7).
- **Chyba nalezená testem (E71, opraveno zvlášť `1c7fe14`):** past rozdělovala znovu průsak, který už odeslala do pásma, jež
  pak padlo do pasti. Ostrov „pretok bez O“: Σ výstupů 4,417 l/s při vstupu 4,100 (hmota navíc +0,317). Po opravě 4,100.
  Varianta „pretok + O“ (hra) se nemění. Tvrzení E71 „Σ 4,10 zachováno ve všech variantách“ neplatilo.
- **Ostrov (`tools/e67.gd`, pretok + O, výchozí K + P):**

  | | E71 (vyp) | E72 (zap) |
  |---|---|---|
  | výstupů | 150 | 6 |
  | < 0,02 l/s | 119 | 0 |
  | 0,02–0,1 l/s | 24 | 0 |
  | ≥ 0,1 l/s | 7 | 6 (0,22–1,79) |
  | Σ výstupy | 4,100 | 4,100 |
  | mokrá pásma | 1225 | 868 |
  | pod hladinou / pasti s vodou | 478 / 37 | 414 / 31 |
  | objem | 7,0 m³ | 7,0 m³ |
  | výpočet podzemí | 88–92 ms | 78–82 ms |
  | výkop průměr / max | 60–66 / 61–70 ms | 49–54 / 52–56 ms |
  | neshody, dvě pořadí | 0, stejný otisk | 0, stejný otisk e8deb156254e1840 |

  Sloučeno 96 drobných výstupů, nejdál 19,3 sloupce řídicí mřížky. Starý řešič (otisk 23b823aa710c9942) beze změny.
- **Testy E69:** bilance chyba 0 a symetrie 0 ve všech případech (plocha, kupole, mísa; i s ponorem 0,3). Reference
  (vrstvy 1,0 … 0,2 l/s) beze změny 5 × 0,2. Kupole: 16 → 8 výstupů, voda vyjde z L3 (dřív 0,742 L4 + 0,258 L5).
- **Prototyp (`voda_e66 --bp.voda_e67=true`, 12 výkopů):** povrch beze změny (5 pramenů, 8 vodopádů, 5 na okraji 9,65 l/s,
  0 neshod); výstupy podzemí 4 (0,0808 / 0,0787 / 0,002 / 0,0) → 2 (0,0808 v 18,09 m, 0,0808 v 12,53 m). Výchozí hra (E58)
  řešič ug67 nepoužívá → beze změny.
- **Negativa:** (1) průsak protékané vody (E71 P) se slučováním prakticky zmizí: průsak jednoho pásma je wq · A (≈ 0,0004 l/s),
  vždy pod prahem → zůstane v toku. Kupole 0,045 → 0, plocha 0,032 → 0 l/s; průsak pastí zůstává (mísa 0,162). Pro P se dá
  vypnout `p72_prusak=false` (pak slučuje jen kapacita a výstupy). (2) výstupy se slučují i přes 19 sloupců – „nejbližší
  silný“ může být daleko; voda se tak objeví jinde, než by drobně vytekla. (3) symetrické drobné výstupy (plocha) sloučit
  nejde bez porušení symetrie, zůstanou.
- **Doporučení:** nechat zapnuto (Jan to chtěl, hmota a symetrie přesné, rychlejší). Jan rozhodne, jestli průsak protékané
  vody slučovat (`p72_prusak`), a jestli omezit vzdálenost slučování výstupů.

## E68 jednotný orchestrátor hydrologie povrch + podzemí (plán, zapsáno před pokusem 2026-11-19 22:07; TODO Voda E68, Jan 21:3x „V ToDo máš úkoly půst se do nich…“)
- **Co už existuje (nenavrhuje se znovu):** jeden krok povrch ↔ podzemí už je v `voda/tok.gd route()` a `alg60/tok60.gd update()`:
  priority-flood + D8 → `_apply_drains` (odtok mokrých tůní do tělesa, volání podzemí seskupená podle `members`, výstupy
  `outs67` / `out` → `src2` pramenů a `st.under`) → znovu povrch. Lokální přepočet po výkopu: v prototypu
  `ostrov_voda.edit()` = výkop podzemí (E64 K+I+P+R, `UGO.dig`) → `_add_drains` → `tok60.update` (okno + po proudu).
  Kontrola proti plnému výpočtu `check_full()`. Pořadí teren → povrch + podzemí → (události tůní `fill_events`) → lokální
  přepočet tedy už platí.
- **Co chybí (E68 doplní):**
  1. smyčka povrch ↔ podzemí má pevně **4 kola** a končí jen při bitové shodě `extra` / `src2`; nikdo neví, jestli
     doběhla. Smyčka tůň → průsak → pramen → tůň (pramen nad tůní ji znovu plní) konverguje pomalu (každé kolo přidá
     další průtok), takže výsledek po 4 kolech závisí na počtu kol a neodpovídá ustálenému stavu;
  2. **společná bilance** neexistuje: zdroje, ztráty v ponorech, odtok přes okraj, odtok tůní do podzemí, výstupy podzemí
     (prameny / stěna), průsak do hloubky, `lost_deep`;
  3. **otisk stavu** (hash) celé hydrologie pro shodu mezi běhy a pořadím výkopů;
  4. jedno místo, kde se to volá (dnes kopie v `route`, `update`, prototypu).
- **Návrh `scripts/hydro68/hydro68.gd` (za přepínačem `p68_hydro`, vypnuto = bitově dnešní stav):**
  - `full(st, kola, tol)`: stejné kroky jako `tok.route`, ale smyčka povrch ↔ podzemí do ustálení: kolo = odtoky tůní +
    podzemí (`_apply_drains`) → povrch po proudu; konec, když se `extra` / `src2` nezmění o víc než `p68_tol` (l/s), nejvýš
    `p68_kola` kol. Vrací počet kol, poslední změnu, `ustaleno`.
  - lokální přepočet: `tok60.update` s parametry `KOLA` / `TOL` (statické proměnné jako `FAST_POND`; výchozí 4 / 0 = beze změny).
  - `bilance(st)`: povrch (Σ zdroje + Σ prameny z podzemí = okraj + ponory + odtoky tůní), podzemí (vstup = výstupy +
    průsak + `lost_deep`), svět (zdroje = okraj + ponory + výstupy ve stěně + průsak do hloubky). Chyba svět / povrch / spoj.
  - `otisk(st)`: hash `fill`, `eff`, `to`, `extra`, `src2` a seřazených `under`.
  - `udalosti(st)`: události plnění tůní (`fill_events`) seřazené podle času (pevné pořadí).
- **Test smyčky (`tools/e68.gd`):** malá mísa: zdroj na svahu → tůň na dně nad polopropustnou vrstvou → zvodeň (písek)
  vychází na svah nad tůní → pramen teče zpět do tůně; přelivem tůně voda odtéká k okraji mapy. Měří se: počet kol do
  ustálení, chyba bilance po 4 kolech a po ustálení, analytická kontrola (ustálený přeliv = zdroj − ztráty), otisk mezi
  běhy. Varianty: E58 (auto) a E67 (pretok, K+P).
- **Ostrov (prototyp `tools/voda_e66.gd`):** před / po (vypnuto / zapnuto): Σ průtok přes okraj, mokrá koryta, tůně,
  prameny, výstupy podzemí, objem, kola, bilance, čas plného výpočtu, čas výkopu, neshody proti plnému výpočtu, otisk
  ve dvou pořadích výkopů a dvou bězích.
- **Hypotéza:** ostrov má smyčku (stará E58: pramen 29,27 m nad tůní, E67 poznámka „4 volání → 2“); po 4 kolech zbude
  chyba bilance, ustálení potřebuje víc kol. Každé kolo s jiným průtokem je nové registrované volání podzemí → výkop
  opravuje víc volání (riziko času). Výchozí zapnout jen při 0 neshod, přesné bilanci a rozumném čase.

## E71 výsledky (2026-11-19 22:40, větev `e71-kapacita-dolu` z `e70-harmonicky-prumer`, do main až po schválení Janem)
- **Co je nového (`ug67.gd`, studie i prototyp, CLI `--bp.p71_*`):**
  - `p71_kapacita` (K): dolů nejvýš `K · A · 1000 · p71_cas` l/s na rozhraní, K = 10^(6·perm − 9) m/s (mapování tabulky v4),
    K_eff = K spodní vrstvy (`p70_prumer = pomer`) nebo harmonický průměr K obou. Pořadí v pásmu: dolů (do kapacity) →
    výstup ve výšce dna → do stran → past. V pasti jsou svislé spoje dolů průsak (ne práh): přítok se dělí po skupinách
    klíče floodu (nejníž první, uvnitř skupiny poměrně), pak průsak do okolí, zbytek přetéká. Dna pastí ve stejné výšce se
    zakládají až po ostatních pásmech té výšky (jinak plochá vrstva závisí na id pásem – nesymetrie 0,014 l/s, opraveno).
    Výstupy ve stejném sloupci v různé výšce se drží zvlášť. Pásmo se do haldy vkládá jen jednou (bez toho test plochy
    narazil na pojistku kroků a ztratil 0,89 l/s – opraveno, `cut67` se teď v E69 hlásí).
  - `p71_prusak` (P): protékané pásmo nad polopropustným materiálem (ne těleso, wq > 0) ztratí průsak dnem `wq · A`.
  - Výchozí: **K zapnuto, P zapnuto, p70 pomer**; vše platí jen pro E67 pretok (`p67_rezim = "pretok"`), výchozí hra / studie
    bez pretok je bitově beze změny (testy studie `tools/test.gd` beze změny kromě časů, otisk staré varianty `23b823aa710c9942`).
- **(1) Referenční sloupec (1 sloupec, zkušební vrstvy s kapacitou 1,0 / 0,8 / 0,6 / 0,4 / 0,2 l/s, nepropustné podloží, 1 l/s):**

  | vrstva | L1 | L2 | L3 | L4 | L5 |
  |---|---|---|---|---|---|
  | bez K (E70) | 1,0 | 0 | 0 | 0 | 0 |
  | **K, pomer** | **0,200** | **0,200** | **0,200** | **0,200** | **0,200** |
  | K, harmonicky | 0,111 | 0,203 | 0,206 | 0,213 | 0,267 |

- **(2) Testy E69 (21 × 21, plocha / kupole / mísa, se slučováním i bez):** symetrie 0 a bilance ≤ 2e-12 l/s ve všech
  kombinacích K, K + harmonicky, P (ponor 0,3), K + P, i s referenčními kapacitami. Kupole s vrstvami 1,0 … 0,2 (K): výstup
  0,742 z L4 + 0,258 z L5 (dřív 1,0 z L5), harmonicky 0,515 / 0,485. **Průsak protékané vody (P, ponor 0,3) kupole: 0 →
  0,045 l/s se slučováním, 0,163 bez slučování (E58 0,176)**; mísa beze změny 0,162 (průsak pasti už byl).
- **(3) Startovní ostrov (`tools/e67.gd`, pretok + O, Σ 4,10 l/s – zachováno ve všech variantách):**

  | | mokrá | pod hladinou | pasti | výstupy (okraj + povrch) | z vážené průtokem | výstupů < 0,02 l/s | objem | podzemí ms | výkop ms (prům. / max) |
  |---|---|---|---|---|---|---|---|---|---|
  | E70 (K, P vyp.) | 791 | 414 | 31 | 85 + 1 | 18,34 m | 8 | 7,0 m³ | 79 | 46 / 50 |
  | P | 791 | 414 | 31 | 85 + 1 | – | – | 7,0 | 84 | 51 / 57 |
  | **K (+ P, výchozí)** | **1225** | **478** | **37** | **148 + 2** | **17,74 m** | **119** | **7,0** | **94–100** | **63–74 / 85–107** |
  | K + harmonicky | 1165 | 472 | 38 | 149 + 2 | 17,67 m | 121 | 7,0 | 86 | 61 / 64 |

  Výkopy: 0 neshod s plným výpočtem a obě pořadí stejný otisk ve všech variantách (K `e704e819891f87e7`). P na ostrově nic
  nemění: v ostrovních horninách není polopropustné netěleso (0 < perm < 0,3 jen kras, a ten je těleso).
- **Prototyp (`voda_e66 --bp.voda_e67=true`, 12 výkopů):** souhrn beze změny (5 pramenů, 8 vodopádů, 5 na okraji 9,65 l/s,
  0 neshod); výstupy podzemí E70: 2 × 0,081 l/s (18,09 a 12,53 m), K: 0,081 (18,09 m) + 0,079 / 0,002 / < 0,0001 (12,5 m).
  Plný výpočet vody 426–500 ms obojí (šum).
- **Rozhodnutí:** K zapnout (splní referenci přesně, symetrie a bilance přesné, výkopy přesné, čas +20–40 % v podzemí, stále
  < 0,1 s), P zapnout (opravuje negativum E69 a nic nerozbije). `p70_prumer` nechat `pomer`: K spodní vrstvy odpovídá
  gravitačnímu průsaku vrstvou při spádu 1 (definice reference), harmonicky ostrov skoro nemění a referenci posune.
- **Negativa a otevřené:**
  - **Hypotéza „voda vyteče výš“ neplatí:** průměrná výška výstupů klesla 18,34 → 17,74 m. Hlavní vliv má pořadí „nejdřív dolů“:
    dřív vzal výstup ve stěně celý průtok hned v prvním pásmu u stěny, teď písek (≈ 3,6 l/s na sloupec) pustí ukázkové zdroje
    0,02 l/s dolů a zastaví je až pískovec / spraš (≈ 0,004 l/s) a vápenec (≈ 0,001 l/s).
  - Drobení: výstupů 86 → 150, z toho 119 pod 0,02 l/s (kreslení je skryje, `p67_min_vytok_render`); průsaky pastí se dělí
    poměrně a slučování `p67_prune` je zatím nezná. Kandidát: slučovat i průsaky pastí.
  - Plochá vrstva rozdělí průsak pasti poměrně po celé vrstvě (degenerovaný případ, symetrický, ale nefyzikální).
  - P závisí na slučování (sloučené větve = méně mokrých pásem → menší průsak: 0,045 vs 0,163 l/s).
  - Jednotky toku vs. čas hry (`p71_cas` = 144) jsou předpoklad; při 1 by kapacity byly 144× menší.
  - Do stran kapacita není (jen poměr), čas průchodu se nepočítá.

## E71 omezení průtoku dolů podle propustnosti vrstvy, průsak z protékané vody (plán, zapsáno před pokusem 2026-11-19 22:15; negativa E69, TODO Voda, Jan 21:3x „V ToDo máš úkoly půst se do nich…“)
- **Problém (E69):** E67 pretok pošle dolů vždy celý průtok, dokud pod pásmem je těleso; propustnosti mění jen dělení do
  stran. Referenční test (1 l/s, vrstvy 1,0 / 0,8 / 0,6 / 0,4 / 0,2, nepropustné podloží) proto dá 1 l/s až z nejspodnější
  vrstvy. Druhé negativum: protékaná (mokrá) pásma nad polopropustnou vrstvou neprosakují (kupole 0 vs E58 0,176 l/s).
- **Varianta K (`p71_kapacita`, výchozí podle výsledků; vypnuto = bitově E70):** kapacita rozhraní dolů (pásmo → pásmo
  tělesa těsně pod ním) podle Darcyho při jednotkovém spádu: `Q = K_eff · A · 1 · 1000 · p71_cas` (l/s), A = plocha sloupce,
  K z propustnosti tabulky přesně podle mapování tabulky (`perm = (log10 K + 9) / 6` → K = 10^(6·perm − 9) m/s, sdílená
  `sdilene/materialy_voda.json` v4), `p71_cas = 144` (`cas_faktor` tabulky: 1 herní den = 10 min). K_eff: `p70_prumer`
  `pomer` = K přijímající (spodní) vrstvy, `harmonicky` = harmonický průměr K obou vrstev.
  - Sestup: nejdřív dolů nejvýš zbývající kapacita (využití se pamatuje po pásmech), zbytek jako dosud: výstup ve výšce dna
    (pramen / stěna), jinak do stran, jinak past (zavěšená voda nad pomalou vrstvou).
  - Past: svislé spoje členů pasti dolů nejsou práh, ale průsak pasti do pásma pod ní (voda pokračuje sestupem, neztrácí
    se). Rozdělení přítoku pasti: skupiny členů podle klíče floodu (nejníž první, uvnitř skupiny poměrně → symetrie),
    pak dosavadní průsak do okolí, zbytek přetéká výstupem / prahem. Spojení pastí přenese už odeslané průsaky.
- **Varianta P (`p71_prusak`, protékaná voda prosakuje):** mokré pásmo, pod kterým je polopropustný materiál (ne těleso,
  0 < perm < ponor_perm), ztratí průsak dnem `wq · A` (stejný vzorec jako dno pasti v `_leak` / E58), nejvýš průtok pásma;
  jen v krocích výstup / do stran (dno pasti už průsak má).
- **Ověření:** (1) referenční jeden sloupec (`tools/e71.gd`), zkušební vrstvy s kapacitou přesně 1,0 / 0,8 / 0,6 / 0,4 / 0,2 l/s
  (propustnost dopočtená z kapacity): očekávání pomer = z každé vrstvy vyteče 0,2 l/s; (2) testy E69 (symetrie D4,
  bilance) s K, P, K+P, K+harmonicky; (3) startovní ostrov `tools/e67.gd` (Σ průtok, objem, mokrá, výstupy, výkopy 0 neshod,
  dvě pořadí) a prototyp `voda_e66 --bp.voda_e67=true` (prameny, vodopády); (4) čas.
- **Hypotéza:** reference přesně 5 × 0,2 l/s; symetrie a bilance zůstanou přesné. Na ostrově se změní hodně: písek (K 1e-4)
  propustí ~3,6 l/s na sloupec 0,5 × 0,5 m, ale pískovec / spraš (K 1e-7) jen ~0,004 l/s a vápenec (3e-8) ~0,001 l/s, takže
  ukázkové zdroje 0,02 l/s se nad nimi zastaví, rozlijí do stran a vytečou výš (víc pramenů / výstupů ve stěně výš).
  Riziko: jednotky toku řešiče vs. čas hry (p71_cas) – laditelné.

## E70 výsledky (2026-11-19 22:10, větev `e70-harmonicky-prumer` z `e69-symetrie-test`, do main až po schválení Janem)
- **Co je nového:** `p70_prumer = "pomer"` (výchozí, beze změny) | `"harmonicky"`: v kroku 3 sestupu `ug67.gd` váha souseda
  `H(k₁, k₂) × překryv`, H = 2·k₁·k₂ / (k₁ + k₂), k₁ = pásmo, odkud voda teče, k₂ = soused (podlaha 0,01 jako dosud).
  Stejná váha jde do slučování (`p67_prune`). Prototyp přes `port_studie.py`, CLI `--bp.p70_prumer`, `tools/e67.gd --prumer= --prune=`
  (nově i otisk rozdělení výstupů `vystupy_otisk`, nejen součty), `tools/e69.gd --prumer=`, nový `tools/e70.gd`.
- **(b) malý případ `tools/e70.gd`** (řada 5 sloupců, zdroj 1 l/s uprostřed, sousedé o 0,25 m níž; podíl západ / východ):

  | střed | západ | východ | poměr | harmonicky |
  |---|---|---|---|---|
  | písek | písek | písek | 0,50 / 0,50 | 0,50 / 0,50 |
  | písek | písek | jíl 0,05 | 0,943 / 0,057 | **0,898 / 0,102** |
  | jíl | písek | jíl | 0,943 / 0,057 | **0,654 / 0,346** |
  | vápenec 0,246 | písek | vápenec | 0,772 / 0,228 | **0,607 / 0,393** |
  | písek | písek | vápenec | 0,772 / 0,228 | 0,687 / 0,313 |

  Bilance chyba 0 ve všech případech. Zamýšlený efekt platí jen napůl: voda **v jílu** (nebo vápenci) už není tolik
  „vysávaná“ sousedním pískem (písek je brzděn jílem, 94 → 65 %). Voda **v písku** ale pošle do jílu víc než dřív
  (5,7 → 10,2 %): harmonický průměr rozdíly propustností vždy zmenšuje a dělení je normované (Σ = 1), takže skutečné
  zpomalení nebo menší průtok model bez času a kapacity vyjádřit neumí. Fyzikálně to odpovídá Darcyho vodivosti
  rozhraní, ale ne představě „jíl brzdí“.
- **(a) testy E69:** pomer bitově jako E69; harmonicky symetrie 0, bilance ≤ 1e-12 l/s (rozdíly proti poměru jen 1e-17 –
  v testu E69 mají sousedé do stran vždy stejný materiál, H(k, k) = k).
- **(c) startovní ostrov (`tools/e67.gd`, pretok + O, Σ 4,10 l/s):**
  - se slučováním (výchozí 0,1 l/s): **bitově beze změny** – mokrá 791, pod hladinou 414, pasti 31, výstupy 85 okraj
    3,95 + 1 povrch 0,15 l/s, objem 7,0 m³, otisk výkopů `beac247bf8881952`, výkopy 0 neshod, obě pořadí stejně;
    totéž kras jen perm ≥ 0,3 (731 / 444 / 28 / 83 + 1 / 8,8 m³). Zdroje 0,02 l/s jsou pod prahem slučování, rozhoduje
    jen nejsilnější větev a ta se nezmění (H je pro dané k₁ rostoucí v k₂).
  - bez slučování: mokrá 1548 → 1559, výstupy 94 + 14 beze změny, objem 7,1 m³, přesune se 0,0089 l/s z 4,1 (0,2 %,
    max 0,0035 l/s na výstup); výkopy 0 neshod, obě pořadí stejný otisk.
  - prototyp (`voda_e66 --bp.voda_e67=true`, 12 výkopů): souhrn beze změny (5 pramenů, 5 vodopádů na okraji 9,65 l/s), 0 neshod.
- **(d) čas:** bez měřitelného rozdílu (šum ±10 %): studie pretok + O 71 / 72 ms poměr vs 67 / 74 ms harmonicky, výkop
  ~43–48 ms obojí; prototyp plný výpočet 459 / 432 ms vs 468 / 429 ms.
- **Rozhodnutí: výchozí zůstává `pomer` (harmonický průměr jen jako přepínač).** Důvody: na startovním ostrově se nic
  nezmění; cíl „jíl brzdí i sousední písek“ splní jen pro vodu, která už je v jílu, opačným směrem pošle do jílu víc;
  skutečné brzdění potřebuje čas průchodu nebo svislou / boční kapacitu (navazuje na negativum E69: chybí kapacita vrstev).
  Až bude kapacita nebo Darcy dolů, má smysl zapnout harmonický průměr spolu s ní (pak je konzistentní).
- **Negativa:** v tělese jsou jen pásma perm ≥ 0,3, kras 0,246 a rozpustné s perm 0 (podlaha 0,01) – skutečný jíl (perm 0)
  není tělesem, takže „jíl vedle písku“ ve hře do dělení vůbec nevstupuje; test používá zkušební těleso perm 0,05.

## E70 harmonický průměr propustností pro dělení do stran v E67 (plán, zapsáno před pokusem 2026-11-19 21:50; TODO Voda, Jan 21:3x „V ToDo máš úkoly půst se do nich…“)
- **Zadání (TODO):** dělení vody do stran v E67 (`ug67.gd`, krok 3 sestupu) dnes váží sousední pásmo `perm(cíl) × překryv`
  (prostý poměr propustností cílů). Návrh: propustnost rozhraní = harmonický průměr obou materiálů
  `2·k₁·k₂ / (k₁ + k₂)` (k₁ = pásmo, ze kterého voda teče, k₂ = soused), aby jíl brzdil i sousední písek.
- **Varianta (příznak, výchozí zatím „pomer“ → parita):** `p70_prumer = "pomer" | "harmonicky"` (studie `scripts/bp/params.gd`,
  kontext `prumer70`, prototyp přes `port_studie.py`, CLI `--bp.p70_prumer`). Váha se použije i ve slučování (`p67_prune`).
- **Očekávání z rozboru:** dělení je normované (Σ váh = 1), takže absolutní „brzdění“ (zpomalení, menší průtok) model bez
  času a kapacity neumí; mění se jen poměr mezi směry. Pro zdroj v písku se harmonický průměr k jílu *zvýší* proti poměru
  (H(0,833; 0,05) = 0,094 > 0,05 → jíl dostane víc), pro zdroj v jílu se rozdíl mezi pískem a jílem zmenší (písek už
  vodu „nevysaje“: poměr 94 / 6 %, harmonicky 65 / 35 %). Ve hře jsou tělesem jen pásma s perm ≥ 0,3, kras (0,246) a
  rozpustné s perm 0 (podlaha 0,01), takže efekt čekám malý – hlavně rozhraní kras / písek.
- **Ověření:** (a) testy E69 (symetrie, bilance) beze změny; (b) malý případ `tools/e70.gd`: řada sloupců, zdroj uprostřed,
  vlevo / vpravo různé materiály (písek / jíl jako zkušební tělesa, a skutečné vápenec / písek) – podíl vody na stranách
  pomer vs harmonicky; (c) startovní ostrov `tools/e67.gd` (Σ průtok, objem, mokrá pásma, výstupy, výkopy 0 neshod, obě
  pořadí) a prototyp `voda_e66 --bp.voda_e67=true`; (d) čas řešení (ms).
- **Rozhodnutí:** zapnout výchozí jen tehdy, když (a) i (c) zůstanou v pořádku a (b) ukáže zamýšlený efekt bez vedlejších
  škod; jinak nechat vypnuté a zapsat proč.

## E69 výsledky (2026-11-19 21:50, větev `e69-symetrie-test` z `e67-podzemi-okraje`, do main až po schválení Janem)
- **Nástroj:** `tools/e69.gd` (`./run.sh e69 [--n=21 --t=1 --sklon=0.25 --q=1 --ponor=0.1 --remizy=1 …]`), výsledky
  `shots/e69/vysledky_pred*.json` (před opravou) a `vysledky*.json` (po). Čtverec 21 × 21 v prstenci zdi, zdroj 1 l/s
  do vrstvy 1,0 prostředního sloupce, 5 vrstev po 1 m, nepropustné podloží, sklon 0,25 m/m.
- **Bilance (všechny tvary a řešiče, před i po):** vstup 1 l/s = výstupy + průsak, chyba ≤ 1e-12 l/s. **Voda se neztrácí**
  (ani slučováním větví, ani v pastech). Se zkušebním `ponor=0,3` (vrstva 0,2 není těleso, jen průsak): pretok mísa
  0,838 výstup + 0,162 průsak, E58 0,8236 + 0,1764, chyba 0.
- **Symetrie před opravou (max rozdíl po sloupcích přes 7 transformací D4):**

  | tvar | pretok + O (slučování 0,1) | pretok + O bez slučování | E58 A+B+C / base + O |
  |---|---|---|---|
  | plocha | výstup 1,0 l/s v 1 rohu (nesym.) | totéž | 1 výstup (roh −10,−10) |
  | kupole | **tok 0,50 l/s, 97 nesym. položek; výstupy 0,127 l/s (8)** | **symetrické (0)**, 76 výstupů | 1 výstup (roh) |
  | mísa | výstup 1,0 l/s v 1 bodě okraje mísy | totéž | 1 výstup (−10, 0) |

  Hladiny (`wt`) a objemy symetrické všude (mísa 7,0355 m, 78,48 m³; E58 i E67 shodně).
- **Příčiny (chyba = remízy rozhodované podle id pásma):**
  1. `p67_prune`: slabé větve se přičtou do „nejsilnější“ – při stejné váze vyhraje první (nejmenší id) → celý tok šel
     jedním směrem (kupole: 0,5 l/s na jedné straně, nic na druhé).
  2. `_pit_fill`: past bere první výstup z haldy – při více výstupech ve stejné výšce (plochá vrstva, okraj mísy) vyteče
     všechno v jednom (sloupec s nejmenším id).
- **Oprava (`p69_remizy`, výchozí true, false = chování E67b; studie i prototyp přes `port_studie.py`):** (1) přebytek
  sloučených větví se dělí rovným dílem mezi všechny větve se stejnou největší vahou; (2) past po prvním výstupu dobere
  z haldy všechny výstupy ve stejné výšce (± 1e-6 m) a přetok dělí rovným dílem. Hmota se nemění.
- **Po opravě:** pretok + O je symetrický ve všech tvarech (chyba 0, i bez slučování), plocha 80 výstupů po 1/80 l/s, mísa
  4 výstupy po 0,25 l/s, kupole 8 výstupů (se slučováním) / 76 (bez). Ověřeno i n = 15 / sklon 0,1 a n = 31 / sklon 0,4 /
  vrstvy 0,5 m (s `--remizy=0` kupole znovu nesym. 0,065 l/s). `--remizy=0` dá bitově stejné výsledky jako před opravou.
- **Dopad na startovní ostrov (`tools/e67.gd`, pretok + O, zdroje 0,02 l/s v minimech, Σ 4,10 l/s beze změny):** mokrá pásma
  700 → 791, pod hladinou 376 → 414, pasti s vodou 26 → 31, výstupy 80 → 86 (okraj 3,94 → 3,95, povrch 0,16 → 0,15 l/s),
  objem 7,0 m³ beze změny; výkopy 0 neshod, obě pořadí stejný otisk (nový `beac247bf8881952`, dřív `f1d92535cd350dcb`).
  Remízy na skutečném terénu tedy nastávají (kvantovaná geometrie); skoro celý rozdíl dělá (1), (2) přidá 1 výstup.
  Prototyp (`voda_e66 --bp.voda_e67=true`, 12 výkopů): souhrn beze změny (5 pramenů, 5 vodopádů na okraji 9,65 l/s), 0 neshod.
- **E58 A+B+C (main):** bilance přesná, hladina a objem symetrické; výstup je z konstrukce jeden (rozhraní `out`), takže
  u symetrického terénu leží v jednom z rovnocenných bodů (nejmenší vzdálenost / id). To není chyba výpočtu, ale omezení
  modelu „jedna hladina, jeden výstup“; neopravoval jsem (E67 už vrací všechny výstupy).
- **Negativa a otevřené:**
  - **Referenční profil vrstev 1,0 / 0,8 / 0,6 / 0,4 / 0,2 se neprojeví:** řešič nemá svislou kapacitu vrstvy, dolů jde
    vždy celý průtok, dokud pod pásmem je těleso. Celý 1 l/s projde až do nejspodnější vrstvy a vyteče z ní (L5 okraj 1,0);
    propustnosti mění jen dělení do stran mezi sousedními pásmy. „Kapacitní“ referenci (každá vrstva propustí dolů jen svou
    kapacitu, zbytek do stran) E67 z konstrukce nesplní – návrh na samostatný úkol (svislá kapacita / Darcy dolů).
  - Pretok nepočítá průsak z protékaných (mokrých) pásem nad polopropustnou vrstvou, jen z pastí: kupole s `ponor=0,3`
    průsak 0 (E58 0,176 l/s). Bilance sedí, ale model průsak podhodnocuje.
  - Oprava (1) nechá stejně silné slabé větve rozdělené (symetrie má přednost před sloučením) → na ostrově +13 % mokrých
    pásem a +6 výstupů pod prahem 0,1 l/s; prahy kreslení (`p67_min_*_render`) je dál skryjí.
  - Remízy prahů pasti (víc prahů ve stejné výšce) zatím berou první; v testech se neprojevily.

## E69 test symetrie a referenční test podzemí (plán, zapsáno před pokusem 2026-11-19 21:45; TODO Voda, Jan 21:3x „V ToDo máš úkoly půst se do nich, ověř je…“)
- **Zadání (TODO):** zdroj 1 l/s nad sloupcem, propustné vrstvy 1,0 / 0,8 / 0,6 / 0,4 / 0,2, nepropustné podloží; symetrický
  terén musí dát symetrický výsledek a voda se nesmí ztratit. Na řešič E67 / E67b (`p67_rezim = "pretok"`, `ug67.gd`) a, pokud
  to jde snadno, na E58 A+B+C (`ug58.gd`, režim auto, jedna hladina na těleso).
- **Postup (nástroj `tools/e69.gd`, `./run.sh e69`, vše laditelné `--klic=hodnota`):** syntetický kontext přímo nad pásmy
  `ug_funkce` (`_new` → sloupce [spodek, vršek, materiál] → `_finish`), bez generátoru bloků. Čtverec N × N (výchozí 21)
  uvnitř prstence zdi (stěna = výstup „okraj“, `p67_okraj`), zdroj 1 l/s do vstupního pásma prostředního sloupce.
  Vrstvy shora: 1,0 / 0,8 / 0,6 / 0,4 / 0,2 (zkušební materiály s touto propustností vložené do tabulky jen v testu,
  `ponor_perm` testu 0,1, aby všech 5 bylo tělesem), pod nimi nepropustné podloží (perm 0). Tvary (všechny symetrické
  podle grupy čtverce D4 kolem středu, hranice závisí jen na r² = dx² + dy²):
  1. **plocha** – vodorovné vrstvy (degenerovaný případ: všechna dna stejně vysoko),
  2. **kupole** – vrstvy klesají od středu (voda musí téct do stran),
  3. **mísa** – vrstvy stoupají od středu (past ve středu, plnění a přeliv přes okraj mísy).
  Varianty řešiče: pretok + O se slučováním (E67b výchozí), pretok + O bez slučování, E58 A+B+C (auto) + O, E58 base.
- **Metriky:**
  - *Symetrie:* pro každou z 8 transformací D4 rozdíl veličin po sloupcích (průtok mokrými pásmy podle vrstvy, výstupy
    podle sloupce, hladina `wt`): max |f(s) − f(T s)| v l/s (resp. m) a počet nesymetrických sloupců.
  - *Bilance:* vstup 1 l/s = Σ výstupů + průsak pastí (min(přítok, průsak)) + zbytek; chyba |vstup − výstup| (l/s).
  - *Referenční profil:* kolik vody vyteče z které vrstvy a kolik projde dolů do další vrstvy (výsledek pro TODO tabulku).
- **Hypotéza:** bilance přesně (chyba < 1e-9 l/s), slučování ani pasti hmotu neztrácejí. Symetrie: kupole bez slučování
  symetrická (dělení perm × překryv je symetrické); se slučováním (`p67_prune`, nejsilnější větev = při shodě nejmenší id
  pásma) a v plochém / mísovém případě (výstup pasti = jeden, při shodě výšky nejmenší id) čekám nesymetrii z rozhodování
  remíz podle id. Řešič nemá svislou kapacitu vrstvy (dolů jde celý průtok), takže propustnosti 1,0 … 0,2 se projeví jen
  v dělení do stran – referenční „kapacitní“ profil (každá vrstva propustí dolů jen svou kapacitu) E67 nesplní z konstrukce.
- **Když test najde chybu:** minimální oprava na větvi `e69-symetrie-test`, znovu změřit, čísla před / po sem.

## E67b prahy: slučování slabých větví a prahy kreslení (2026-11-19, větev `e67-podzemi-okraje`; Jan 16:21 → oprava 16:22, 16:23, 16:25)

- **Zadání:** malé výstupy se ze simulace NEZAHAZUJÍ (hmota beze změny), práh jen pro kreslení; stovky drobných větví přetoku:
  (a) práh kreslení, (b) slučování v simulaci `p67_prune` – **zapnuto** (Jan 16:23: „deci-/centilitry v přetocích neřešíme“), práh
  v řádu desetin litru za sekundu, slabá větev se přičte do nejsilnější sousední cesty (zachová hmotu). Všechny prahy laditelné (16:25).
- **Parametry (bp `scripts/bp/params.gd`, prototyp `HRA` v `ostrov_teren.gd`, CLI `--bp.<klíč>`, ladicí panel „Voda E67“):**
  `p67_prune = true`, `p67_prune_min = 0.1` l/s (jednotka toku řešiče = l/s; 0,1 l/s ≈ 6 l/min, menší větev hráč neuvidí a nevyužije),
  `p67_min_vytok_render = 0.02` l/s, `p67_min_tok_render = 0.02` l/s (= jeden ukázkový zdroj 0,02 l/s; slabší je jen odštěpek).
- **Histogram výstupů (ostrov 4 bloky, ukázkové zdroje 0,02 l/s v každém místním minimu, součet 4,10 l/s):**

  | q (l/s) | <0,001 | 0,001–0,005 | 0,005–0,01 | 0,01–0,02 | 0,02–0,05 | 0,05–0,1 | 0,1–1 | ≥1 |
  |---|---|---|---|---|---|---|---|---|
  | bez slučování | 13 | 4 | 5 | 7 | 68 | 3 | 6 | 1 |
  | slučování 0,1 | 0 | 0 | 0 | 0 | 69 | 3 | 7 | 1 |

  Zbylo kreslených výstupů při prahu kreslení 0,01 / 0,02 / 0,05 / 0,1: bez slučování 85 / 78 / 10 / 7 ze 107, se slučováním 80 / 80 / 11 / 8 z 80.
  Tůně hry (1 výstup 0,153 l/s) se nemění.
- **Vliv slučování (b), ukázkové zdroje:**

  | p67_prune_min | výstupů | Σ q l/s | protékaných pásem | stojatých vod | podzemí ms |
  |---|---|---|---|---|---|
  | vypnuto | 107 | 4,100 | 1548 | 46 | 74 |
  | 0,01 | 86 | 4,100 | 813 | 31 | 51 |
  | 0,05 | 81 | 4,100 | 743 | 30 | 51 |
  | **0,1** | **80** | **4,100** | **700** | **26** | **56** |
  | 0,2 | 80 | 4,100 | 698 | 26 | 51 |

  Hra (`voda_e66 --bp.voda_e67=true`, 12 výkopů): plný výpočet podzemí 271 → 248 ms, výkop podzemí max 114 → 91 ms, průměr 53 → 48 ms,
  neshod s plným výpočtem 0, souhrn (5 pramenů, 5 vodopádů na okraji 9,64 l/s) beze změny. Studie `tools/e67.gd`: neshod 0, obě pořadí stejný otisk.
- **Závěr:** slučování ubere ~55 % protékaných pásem a čtvrtinu výstupů bez ztráty hmoty; nad 0,05 l/s se už skoro nic nemění, 0,1 je
  bezpečně „litrový“ řád podle Jana. Se zapnutým slučováním pod 0,02 l/s nic nezbude, prahy kreslení jsou pojistka pro `p67_prune=false`.
  Jediná větev slabší než práh, která nemá souseda, se neslučuje (teče dál celá) – proto zůstávají výstupy 0,02 l/s z jednotlivých zdrojů.
- **Obrázky:** `godot-prototyp/shots/rez/e67/po_minima/prehled.png`, `po_hra/prehled.png`, pro srovnání `po_minima_bez_prune/prehled.png`.

## E67 výsledky (2026-11-19 16:40, větev `e67-podzemi-okraje`, do main až po schválení Janem)
- **Co je nového** (výchozí vypnuto, parita):
  - `scripts/podzemi52/ug67.gd`: režim `p67_rezim = "pretok"` – sestup od zdroje (halda: dno sestupně, id vzestupně) dolů,
    jinak do stran do pásem s nižším dnem podle perm × výšky překryvu; výstup ve výšce dna bere celý průtok; dno pasti →
    priority-flood (stejný klíč i `_outs` jako preliv) do výstupu nebo prahu; vzájemný přeliv dvou pastí a „práh, který steče
    zpět“ se spojí (sonda `_probe` po hranách sestupu); stopa `_fp67` (sloupce navštívených pásem).
  - `p67_okraj` (O): výstup „okraj“ i u zdi (stěna ostrova) ve výšce dna pásma – v `_outs`, `_solve_nadrz`, `ug58._cands_b`.
  - `p67_kras` (výchozí true = beze změny): false → rozpustná hornina je tělesem jen s perm ≥ `ponor_perm`. Tabulka materiálů beze změny.
  - `ug58._one` / `ug58.edit`: při pretok plný výpočet volání; výkop přepočítá jen volání, jejichž stopa obsahuje sloupec
    výkopu nebo jeho 4 sousedy (výsledek čte jen tato data → jinak bitově stejný). `tok60`: když výsledek nese `outs67`,
    přidá všechny prameny (ne jen jeden).
  - Nástroj `tools/e67.gd` (startovní ostrov 4 bloky bp jako prototyp, zdroje = místní minima povrchu 0,02 l/s, po tělesech),
    výsledky `shots/e67/ostrov.json`, testy `shots/e67/testy/`.
- **Studie, startovní ostrov, zdroje v místních minimech (1 volání, 4,1 l/s)** – mokrá = pásma, kudy voda opravdu teče:

  | varianta | těles / největší (pásem) | stojatá voda (pásem pod hladinou) | mokrá (protékající) | hladiny | výstupy (počet, l/s) | objem m³ | ms |
  |---|---|---|---|---|---|---|---|
  | stará (auto, preliv) | 30 / 7690 | 6137 | – | 1: 19,24 m | 1 pramen 4,1 | 179,9 | 467 |
  | stará + O | 30 / 7690 | 0 | – | 1: 12,33 m (= dno pánve u stěny) | 1 okraj 4,1 | 0,0 | 180 |
  | **pretok + O** | 30 / 7690 | **506** | **1548** | **46 pastí** (18,11 / 18,39 / 21,6 … m), všechny „vana po práh“ | **93 okraj 3,95 + 14 pramenů 0,15** | 7,1 | 91 |
  | pretok bez O | 30 / 7690 | 6151 | 1993 | 6 (hlavní 19,24 m, 6137 pásem) | 15 pramenů 4,1 | 180,1 | 4442 |
  | stará, kras jen perm ≥ 0,3 | **224 / 4228** | 2677 | – | 1: 19,24 m | 1 pramen 4,1 | 153,1 | 33 |
  | pretok + O, kras jen perm ≥ 0,3 | 224 / 4228 | 502 | 1111 | 35 | 88 okraj 3,94 + 14 pramenů 0,15 | 9,4 | 58 |

  - **Dosažená pásma vs. těleso:** pretok + O zasáhne 1548 + 506 = 2054 ze 7690 pásem tělesa (27 %), stojatá voda jen 506
    (6,6 %, stará 6137 = 80 %); objem stojaté vody 7,1 m³ místo 179,9 m³.
  - **Kontrola smyslu:** pretok bez O dá znovu přesně starou vanu (19,2435 m, 6137 pásem, 179,9 m³) – bez výstupu ve stěně je
    celý ostrov uzavřená miska (sloupce mimo ostrov jsou zeď), takže se vana tvoří správně jen tam, kde má (Jan 16:00).
- **Prototyp (`--bp.voda_e67=true` = O + pretok; `--bp.p67_okraj=true` samotné O s E64 K+I+P+R), skutečné tůně hry,
  `tools/voda_e66.gd --vykopu=12`, logy `godot-prototyp/shots/67/`:**

  | | plný výpočet vody | podzemí při výkopu (ms) | kroky R | neshod s plným výpočtem |
  |---|---|---|---|---|
  | stará | 2,6 s | 277–906 (průměr ~670) | 22–66, max krok 474 ms | 0 |
  | O (E64 K+I+P+R) | 1,07 s | 2–11 | 0–11, max 13 ms | 0 |
  | **E67 (O + pretok)** | **0,77 s** | **0,2–114** (bez zásahu stopy 0,2) | 0 | **0** |

  - Hra: stará = 1 těleso, hladina 19,56 m přes 1024 sloupců (6746 pásem, 210 m³), pramen 29,27. E67: tůň u stěny (0,18)
    vyteče hned ve stěně ve 18,19 m (vodopád do mlhy, 0,153 l/s), stojatá voda 2 pásma (0,01 m³), mokrá 3 pásma.
    Do podzemí jde 0,153 místo 0,173 l/s: dřív pramen 29,27 vracel vodu na povrch a ta zčásti znovu tekla do podzemí (4 volání → 2).
- **Parita:** hashe testů studie (v1, sled46, svet8, voda, voda_b, voda_b --b) beze změny (`shots/e67/testy/` = `shots/e64/testy/`).
  O ve světech bez zdí (svet64 8 × 8) nemá vliv z konstrukce (`wedge` je vždy false); záznam alg64 jsem znovu nepouštěl.
- **Důkazy E64:** O mění jen množinu výstupů floodu (čte sloupec + 4 sousedy, zeď se výkopem nemění) → K, I, P, R platí beze
  změny; potvrzeno 0 neshod u 12 výkopů s K+I+P+R. Pretok lokální opravu I / kroky R **nepoužívá**: výkop = plný přepočet
  dotčených volání, výsledek je čistá funkce dat ve stopě → přesnost i nezávislost na pořadí výkopů triviálně (studie: 2 pořadí
  12 výkopů → stejný otisk, 0 neshod; prototyp 0 neshod). Lokální oprava pro pretok zatím není.
- **Negativa a otevřené:**
  - Bez O je pretok pomalý (4,4 s): opakovaná spojování pastí se sondou `_probe` (velká vana přes celý ostrov). S O 58–91 ms.
  - Rozdělení do stran je jen váha perm × překryv (ne Darcy); dolů jde vždy celý průtok, když pod pásmem je těleso.
  - Výstupy po stovkách drobných větví (93 vodopádů na okraji, 14 pramenů, další < 1 ml/s) – pro hru asi sloučit / prahovat.
  - Mokrá pásma = film 0,5 m u dna (`p67_film_m`), jen pro zobrazení; čas průchodu se nepočítá (jen časy plnění pastí).
  - Kras vždy propustný: vypnutí (p67_kras=false) rozpadne 1 těleso na 224 (největší 4228 pásem), ale vana tělesa ve staré
    variantě zůstane (19,24 m); s pretok skoro beze změny výstupů. Výchozí ponecháno (tabulka materiálů nezměněna).
  - `rez_gif.sh` vodu nekreslí (jen tělesa), GIF před / po je stejný; vizuály jsou svislé řezy.
- **Obrázky:** `godot-prototyp/shots/rez/e67/` – `pred_hra/`, `po_hra/` (tůně hry), `pred_minima/`, `po_minima/` (ukázkové zdroje
  v místních minimech, `--zdroje=minima`), každý s `prehled.png`; srovnání `pred_po_minima_x12.png`, `pred_po_hra_x12.png`.

## E67 podzemní voda vytéká z vrstev na okraji, zavěšená voda, přetoky ve 3D (plán, zapsáno před pokusem 2026-11-19 16:00; Jan 15:54 „Ano voda na krajích bloku měla vytékat z vrstev kam se dostane.“, 15:56 přetoky ve 3D)
- **Problém (E66b, řezy `godot-prototyp/shots/rez/profil_ostrov/`):** startovní ostrov má jedno těleso s vodou a jednu hladinu
  19,56 m přes celý ostrov („vana“): voda z tůní se v režimu auto/preliv rozlije do nejnižšího dosažitelného pásma celého
  souvislého tělesa a hladina stoupá, dokud nenarazí na nejnižší výchoz na povrchu (pramen 29,27). Tři příčiny v kódu:
  1. **Okraj ostrova není výstup.** `_outs`, `_solve_nadrz` a `ug58._cands_b` znají jen okraj řídicí mřížky světa (x = 0 / W−1)
     a nižší povrch souseda; sloupce mimo ostrov jsou zeď (`wall`), takže stěna ostrova nikdy nepustí vodu ven.
  2. **Žádná zavěšená voda.** Preliv bere jako pánev globálně nejnižší dosažitelné pásmo a plní jen ji; mezilehlé nepropustné
     čočky (misky) se nenaplní a nepřetečou, nevznikne víc hladin.
  3. **Okamžité „rozlití“:** sestup s kapacitou (cap) navštíví vše, co je pod hladinou vstupu, ne cestu, kudy voda skutečně teče.
- **Cíl (Jan):** podzemní voda se chová jako povrchové přetoky, ale ve 3D: od zdroje nejdřív **dolů**, pak dolů a do stran
  podle propustnosti vrstev; v pastech na nepropustném dně se drží (zavěšená voda), po naplnění přeteče do další; mokré jsou
  jen pásma, kam voda opravdu doteče; ven vyteče z odkryté vrstvy na okraji (stěna ostrova → vodopád do mlhy) nebo v prameni,
  ve výšce té vrstvy (na nepropustném dně, nejnižší odkryté místo vrstvy). Událostně / předpočítaně, ne simulace po krocích.
- **Varianty (příznaky v parametrech, výchozí vypnuto → parita):**
  - **O (`p67_okraj`):** výstup „okraj“ i tam, kde soused pásma je zeď (mimo ostrov): z = spodek pásma (voda sedí na dně
    vrstvy a vyteče ve stěně). Stejně v `_outs`, `_solve_nadrz` a `ug58._cands_b`, takže platí pro preliv, nádrž i uzly B
    a celé E64 (K+I+P+R) beze změny: sestup O nečte, flood čte výstupy jen ze sloupce a 4 sousedů a zeď se výkopem nemění.
  - **Z (`p67_rezim = "pretok"`, nový režim podzemí, soubor `scripts/podzemi52/ug67.gd`):** přetoky ve 3D nad stejnými pásmy:
    1. *Sestup (tok):* pásma v pořadí spodku shora dolů (halda: lo sestupně, id vzestupně). Pásmo s vodou pošle průtok
       **dolů**, když se ho dotýká pásmo tělesa pod ním ve stejném sloupci; jinak **do stran** do sousedních pásem s nižším dnem,
       rozdělené vahou perm × výška překryvu (jako D∞ na povrchu). Výstup ve výšce dna (okraj / nižší povrch souseda ≤ dno)
       vezme celý průtok pásma (vývěr ve stěně / prameni). Mokrá = navštívená pásma (film u dna).
    2. *Past:* pásmo bez cesty dolů a bez výstupu = dno pasti. Priority-flood z ní (stejný jako preliv: klíč max(hladina,
       spodek překryvu), výstupy `_outs`): hladina stoupá, dokud (a) nenarazí na výstup → vyteče, nebo (b) nenarazí na pásmo,
       jehož dno je pod hladinou a které do pasti nepatří (přeliv přes práh) → past je plná na hladině prahu (zavěšená voda),
       přebytek (průtok − průsak) teče sestupem dál z toho pásma.
    3. *Spojení (fill-spill-merge [Barnes]):* když hladina pozdější pasti dosáhne hladiny dřívější sousední pasti, spojí se
       v jedno jezero a hladina stoupá dál.
    4. *Ustálený stav:* každá past na cestě, do které teče víc než průsak, je plná po práh; časy plnění = objem / čistý průtok
       (události po 0,5 m jako dosud). Výsledek: pasti (hladina, pásma, práh / výstup), mokrá pásma sestupu, všechny výstupy
       s průtokem; `out` = výstup s největším průtokem (rozhraní tok60 beze změny), `outs67` = všechny (tok60 je přidá, když existují).
  - **Kras (`p67_kras`):** dnes je rozpustná hornina tělesem vždy (`UG._soluble`, i sádrovec s perm 0). Změřit vliv, kdyby
    kras musel mít perm ≥ `ponor_perm`; tabulku materiálů neměnit (jen pokusný přepínač, výchozí beze změny).
- **Hypotéza:**
  1. O: na startovním ostrově vyteče voda ve stěně ostrova pod úrovní 19,56 m (dno pískovce / vápence ~13–16 m);
     hladina klesne o metry, objem v tělese řádově klesne; pramen 29,27 zmizí nebo zeslábne.
  2. Z: mokrá pásma ≪ velikost tělesa (řádově jednotky až desítky % ze 7690 pásem); víc hladin (zavěšená voda nad čočkami);
     výstupy hlavně „okraj“ na stěně ostrova.
  3. Parita: O i Z vypnuté → hashe testů studie a prototypu beze změny; O ve světech bez zdí (svet64 8 × 8) beze změny výsledků.
  4. Výkop: O nemění E64 důkazy (K, I, P, R). Z zatím bez lokální opravy: výkop = plný přepočet registrovaných volání
     (čistá funkce stavu → přesnost i nezávislost na pořadí triviálně), odhad pod současných 0,45–0,95 s, protože navštíví
     jen mokrou část místo celého tělesa.
- **Metriky:** počet těles, pasti s vodou, hladiny, výstupy (pramen / okraj) a průtoky, mokrá pásma vs. velikost tělesa,
  objem, čas řešení a výkopu (ms), parita (hashe testů, shoda se starým výsledkem při vypnutí), vliv krasu na tělesa.
  Obrázky: `tools/rez_profil.sh` a `tools/rez_gif.sh` před / po (`prehled.png`).

## E66b podzemní těleso, bok ostrova, řezy GIF (2026-11-19 15:45; Jan 15:20 „Proč je tam velké podzemní těleso? Skryj texturu na boku dlaždice.“, 15:26 GIF řezů)
- **Proč jedno velké těleso (diagnostika `godot-prototyp/tools/teleso_e66.gd`, obrázek `shots/66b_teleso.png`):**
  - Startovní ostrov (4 bloky, 1024 sloupců, 18886 pásem): 30 těles, z toho **jedno má 7690 pásem ve všech 1024 sloupcích**
    (objem pórů 312 m³), ostatních 29 jsou zbytky po 2–5 pásmech.
  - Těleso tvoří **souvislé propustné vrstvy z tabulky pořadí hornin**, které blueprint v2 navazuje přes švy (navázání mocností):
    křemenný pískovec 52 (perm 0,333, por 0,20; samotný souvisle v 95 % sloupců), jeskynní vápenec 5 (kras, perm 0,246; 91 %),
    hlubinný vápenec 44 (kras; 90 %), dál štěrk 3 (0,833), spraš 54 (0,333), dolomit 49 (kras). Shora je spojí **drn 1 (0,667)
    a ornice 2 (0,595)** ve všech sloupcích (81 %). Práh `ponor_perm` 0,30, kras se počítá vždy (i sádrovec 48 s perm 0).
  - **Není to artefakt prototypu:** studie svet64 (8 × 8 bloků) má totéž – „1375 těles“, ale jedno přes **16358 z 16384 sloupců**
    (127916 pásem), zbytek jsou drobty; pásma drnu / ornice jsou tělesem ve 100 %. Plná id buněk a pásma funkcí sedí:
    91 % buněk v pásmu tělesa je propustný materiál, 9 % jsou skarn 42 a minerály (funkce `bands()` tělesa pně / žíly vědomě
    vynechává); propustné buňky mimo pásmo 0,2 %. Celočíselná výška, třídy hry, skrytí podzemí ani příkop v mlze tvar tělesa
    neovlivňují (podzemí se staví z funkcí vrstev a plných id, mlha je v podzemí stěna).
  - Pokusy se souvislostí (jen počítání): bez drnu a ornice dál 1 těleso přes 100 % sloupců (5830 pásem); bez sádrovce totéž;
    **řez po švech bloků** → největší 2095 pásem / 256 sloupců (25 %).
- **Možnosti (odhad dopadu na kopání ~0,45–0,95 s v podzemí):**
  1. *Nechat fyziku, zrychlit adaptér:* výkop jen v drnu / ornici nad tělesem často výsledek nemění (neověřeno; 3 z 6 výkopů E66 byly v suchu
     a povrch se nepřepočítal, podzemí ano) → rychlý test „výsledek se nezmění“ před `ug64.edit`, čištění registru volání (dnes jen roste). Odhad: běžný výkop
     desítky ms, výkop do pískovce dál ~0,5 s. Bez změny studie.
  2. *Rozdělit těleso po blocích s výměnou přes švy* (těleso bloku + tok přes hranu jako vstup / výstup): pásem na výpočet ~4× méně
     → odhad 0,1–0,25 s. Nová logika v podzemí (studie), parita E61 by se musela přeměřit.
  3. *Hrubší mřížka podzemí* (`p52_ug_n` 8 místo 16, studie to umí): 4× méně sloupců → odhad 4× rychleji, hrubší hladiny.
  4. *Návrh vrstev:* pískovec a vápence s vyklíněním / čočkami místo souvislé vrstvy přes celý ostrov → víc menších těles
     (i geologicky věrnější); mění terén a hashe studie.
  5. Vyřadit drn a ornici z těles nepomůže (těleso dál přes celý ostrov); zvýšit `ponor_perm` nad 0,333 odstraní pískovec,
     ale krasové vápence (91 %) zůstanou.
- **Bok ostrova:** rozmazaný hnědý vzor na boku byl ze dvou věcí: (a) skutečné vrstvy (buňky boku jsou „odkryté“, sousedí se vzduchem)
  a hlavně (b) 18 průsvitných vrstev mlhy ve slotech kolem ostrova (1,5–16,8 m) s okraji po slotech → kosočtverce přes bok
  (ověřeno snímkem bez mlhy). Nové nastavení `side_plain` (výchozí zap.: bok jednou barvou `col_side` bez textury, horní buňka zůstává)
  a `fog_side` (výchozí vyp.: mlha před bokem skrytá; zapnutím zpět původní mlha). Rentgen a řez beze změny. Snímek `shots/66b_bok.png`
  (vlevo před, vpravo po). **Negativum:** s `fog_side` vyp. kolem ostrova není mlha vůbec (i horní příkrov dělal kosočtverce).
- **Řezy GIF** (Jan 15:26): `godot-prototyp/tools/rez_gif.sh` – jeden příkaz, bez GPU (~3 s): data `tools/rez_data.gd`, obrázky
  `tools/rez_gif.py` (Pillow). Příklady `godot-prototyp/shots/rez/ostrov.gif` (30 snímků) a `shots/rez/blok_0_0.gif` (blok s velkým tělesem, 21 snímků).

## E66 výsledky (2026-11-19 15:10)
- **Git** (Jan 14:35 / 14:37): výchozí stav prototypu = commit `ca6afdf` v `Utalag/Willage_Client`, práce na větvi
  `e66-integrace-prototypu` po malých commitech (modul po modulu, testy, snímky). Záložní kopie se nedělají.
- **Přenos modulů** (`godot-prototyp/tools/port_studie.py`): 76 souborů (73 skriptů) z `scripts/{bp, kopie, svet8, svah56, svet64,
  voda, alg60, alg58, alg64, podzemi52, eroze51, dohnani54}` → `scripts/teren/…`, `scripts/voda/…`, testy do `scripts/studie_testy/`.
  Mění se jen cesty (`preload`, `res://data/` → `res://data/teren/`, výstupy → `shots/66_parita/`), `--check` ověří, že kopie
  sedí se studií (po integraci: změněno 0). **Logika se nemění vůbec** – plánovaný příznak `edge_wall` (bod 3) nebyl potřeba, viz níže.
- **Parita** (`tools/parita_e66.gd`, stejné světy a testy jako studie): **6 / 6 hashů E61 bit po bitu** – v1 dda863feffe6f611
  (2,9–3,1 s), sled46 d8af7f59b6f8da70 (19 s), svet8 ec0681cc6426 (34 s), voda a14136754dd1 (39 s), voda_b 5ae2b366e84a (8 s),
  voda_b --b e8cbbc78ca88 (45 s); opakovaný běh STEJNÉ. **E64 s16** (`tools/studie_alg64_ug.gd`, A+B+C+D+K+I+P+R nad záznamem E61):
  všechny čítače (výběry 205592, navštíveno, S, kroky, neshod K 0, otisk OK 31, líných 11, pásem) shodné se studií;
  plný 2830 ms (studie 2576), výkop průměr 26,3 ms (26,9), max 348 ms (355). Studie sama beze změny, její testy dál dávají stejné hashe.
- **Adaptér terénu** (`scripts/teren/ostrov_teren.gd`, `tridy.gd`): blok ostrova → blueprint (louka → louka, kopec → kopec, hora →
  hora_zvrasnena, piscina → prohlubeň; minerály podle tvaru, ×1,5 u unikátních; každý 5. seed rezervoár vody, každý 3. jeskyně),
  slot ostrova + (3, 3) = slot světa 8 × 8, navázání na už vložené sousedy přes `world.commit` při `Island.place`.
  `Block.cells` = herní třída Mat 0–12, `Block.geo` = plné id; rentgen kreslí plná id paletou studie (snímek 66_xray_rez).
  Generování bloku 205–240 ms (E49: ~0,25 s) – **sedí s hypotézou**.
- **Adaptér vody** (`scripts/voda/ostrov_voda.gd`, `podzemi_ostrov.gd`, `ostrov_voda_render.gd`): mřížka 128 × 128 sloupců (16 na blok,
  buňka 0,5 m), prameny jen na ostrově, `tok.make(…, losses(springs), edge_out)`, podzemí `ug_funkce.from_world` + auto + E64
  (A+B+C+D+K+I+P+R, rozpočet 5000 operací na krok R). Volání podzemí z toku se registrují (vstupy, q, vyloučené sloupce),
  výkop jde přes `ug64.edit` nad všemi registrovanými voláními, kroky R po snímcích. Kopání i položení → `tok60.update` kolem změny.
  Když se změní výsledek podzemí, přidají se do přepočtu odtoky tůní a vývěry (jinak by výkop v suchu změnu podzemí na povrch nepustil –
  první verze měla 102 neshod průtoku, oprava → 0).
- **Okraj ostrova místo `edge_wall`:** mlha kolem ostrova je v mřížce **příkop** (dno 0, žula, sklon 0,01 buňky na sloupec k okraji mapy).
  Voda z okraje ostrova do něj spadne (vodopád do mlhy) a odteče přes okraj mapy (`edge_out` studie) → moduly beze změny.
  Bez sklonu se okno `tok60` na plochém příkopu zvětšovalo až na celou mapu (povrch 1 s na výkop); se sklonem okno 13 × 13.
- **Kontrola správnosti:** po každém výkopu / položení stav proti čerstvému plnému výpočtu (stejné výkopy přehrané do nového podzemí):
  `--e66-bench` 8 výkopů + 1 položení, `tools/voda_e66.gd` 6 výkopů → **0 neshod** (fill, průtok, směr odtoku).
- **Časy ve hře** (`shots/66_parita/66_bench.txt`, box bez GPU): start 4 bloky – voda plně 2,5 s (prameny 9 ms, pásma podzemí 285 ms,
  povrch + podzemí 2,2 s); vložení dalšího bloku celkem 3,6–3,8 s (generování 0,22 s, voda 2,9–3,0 s, zbytek síť a tráva).
  Kopání u vody: celkem průměr 1,1 s, max 2,0 s (povrch 0–0,9 s, podzemí 0,45–0,95 s) + kroky R 27–66 × ~60 ms (max ~320 ms) po snímcích.
  Položení 177 ms.
- **Negativa / co neplatí z hypotézy:**
  - **Voda ostrova plně 2,5–3 s místo < 1 s a kopání u vody ~1 s místo desítek ms.** Podzemí: každý výkop rozdělí uzel B
    (`splits`/`gone` 1 na výkop) → všechna volání jdou přes přesný výpočet (`fallback` = `exact` = počet volání), čas výkopu roste
    s počtem výkopů (0,45 → 0,95 s). Ve studii E64 byla tělesa menší a výkopy ze záznamu; tady je jedno velké těleso pod celým ostrovem.
    Registr volání jen roste (nový průtok tůně = nové volání; 4 → 11 po 6 výkopech), staré se neodebírají. Varianty bez R jsou horší
    (K+I+P 2,2–3,1 s na výkop, A+C 2,6–3,6 s). Povrch: výkop v tůni zvětší okno přes celou tůň (0,5–0,9 s).
  - Kroky R mají ~60 ms (max ~320 ms) → na snímek je to znát; `p64_budget` se dá snížit (víc kroků).
  - Výchozí generátor je **bp** (plán bod 4 říkal „výchozí zůstává v3“); `--gen=v3` / Inspector Island.generator vrací gen-v3.
  - Voda bere celočíselnou výšku bloku (`hm`), ne `hm_f` studie; ve hře se nevyřezávají strže (koryto jen uložené), E51 / E54 se nespouštějí.
  - Otočení / zrcadlení bloku a režimy stran (`sides`) v bp nejsou; prahy rarity nejsou kalibrované pro bp.
  - Export hry: parametry vody studie bere z `data/teren`, fallback na `../sdilene` (jako studie) chybí.
  - `teren/zaklad/gen_v3.gd` je druhá kopie vedle `scripts/gen3/` prototypu (duplicita, sjednotit později).
  - Hladina vody je na mřížce kostek (čtverce), duální povrch trávy ji místy překrývá; rentgen ukazuje plná id jen v řezu / rentgenu.
- **Snímky:** `shots/66_reka.png`, `66_tun.png`, `66_pramen.png`, `66_vodopad_okraj.png`, `66_vodopad.png`, `66_xray_rez.png`, `66_celek.png`.

## E64 výsledky (2026-11-19 13:50)
- **Co je nového** (kód `scripts/alg64/`, výchozí chování beze změny, zapíná se jen příznakem `K` ve variantě):
  - `heap64.gd`: halda s pevným pořadím (hodnota sestupně, id vzestupně).
  - `sestup64.gd`: sestup K, oprava I, řetězce V, práce po krocích.
  - `pre64.gd`: preliv jako úloha po krocích (sestup → priority-flood → průsak → souhrn) a cache P.
  - `ug64.gd`: řízení variant, výkop, krok R, otisky.
  - Háčky v `ug58.gd`: 2 řádky, jen při `c._useK`.
  - Nástroje: `tools/alg64_ug.gd`, `alg64_fuzz.gd`, `alg64_info.gd`, `alg64.sh`, `shots_e64.py`.
- **Stejné vstupy jako E63:** záznam `_e61`, 3 × 20 výkopů (s16 / s32 / s64), 4 běhy souběžně.
- **Výkop ms (průměr / p95 / max), 0 neshod všude:**

  | varianta | s16 | s32 | s64 | max krok s64 | kroků max s64 | stav MB s64 |
  |---|---|---|---|---|---|---|
  | E63 +E+I | 94 / 131 / 144 | 111 / 179 / 461 | 90 / 133 / 164 | 164 | 1 | 16,3 (I) + 15 (D) |
  | K (plný sestup) | 1098 / 1500 / 1810 | 1027 / 1513 / 1528 | 1083 / 1575 / 1613 | 1613 | 1 | 40,1 |
  | K+I | 64 / 68 / 387 | 53 / 112 / 128 | 75 / 108 / 599 | 599 | 1 | 40,1 |
  | K+I+V | 66 / 84 / 421 | 55 / 120 / 145 | 85 / 101 / 731 | 731 | 1 | 40,4 |
  | K+I+R (5k) | 62 / 63 / 418 | 51 / 110 / 121 | 77 / 117 / 594 | 66 | 64 | 40,1 |
  | K+I+R+V | 66 / 121 / 400 | 53 / 112 / 129 | 77 / 105 / 652 | 62 | 64 | 40,4 |
  | **K+I+P** | **27** / 14 / 368 | **20** / 82 / 84 | **38** / 45 / 540 | 540 | 1 | 40,1 |
  | **K+I+P+R (5k)** | 27 / 14 / 355 | 22 / 79 / 88 | 42 / 46 / 597 | **42** | 63 | 40,1 |
  | K+I+P+R+V | 28 / 20 / 363 | 20 / 73 / 87 | 46 / 44 / 693 | 51 | 63 | 40,4 |

  - Max u R = součet všech kroků výkopu. Délku jednoho kroku ukazuje sloupec „max krok“.
  - p95 je 19. nejhorší z 20 výkopů. U s16 je menší než průměr, protože průměr táhne jeden výkop (#15).
  - Navštíveno (sestup) průměrně 1 546 / 713 / 2 487 pásem na výkop. Plný sestup K má ~150 000 výběrů.
- **Výkop z E63 za 461 ms** (s32 #13): K+I 71 ms, K+I+R 58 ms, K+I+P 10 ms, K+I+P+R 17 ms.
- **Nejhorší výkop teď** je s64 #18 (540–600 ms) a s16 #15 (~370 ms):
  - Výkop přetne kmen sestupu.
  - S = 44 822 / 30 237 pásem a jejich hodnoty se opravdu mění (semínko vstupu kleslo).
  - Prořezání (ponechat potomka s jinou bezpečnou oporou se stejnou hodnotou) S skoro nezmenší (47 393 → 44 822).
  - Tuhle práci jde jen rozložit (R), ušetřit ne.
- **R, rozpočet operací na krok** (K+I+P+R):

  | rozpočet | max krok s16 / s32 / s64 | kroků nejhoršího výkopu s16 / s64 |
  |---|---|---|
  | 2 000 | 14 / 33 / 16 ms | 78 / 158 |
  | 5 000 | 33 / 64 / 42 ms | 32 / 63 |
  | 10 000 | 62 / – / 80 ms | 17 / 32 |

  - Konečný stav = plný přepočet (otisky).
  - Krok 0 má pevnou režii ~10–25 ms (ug58.edit: delta uzlů B, pravidla D), tu R nerozloží.
  - Na s32 je operace floodu ~5× dražší než operace sestupu, proto tam má krok 33 ms i při 2k.
- **K: důkaz a fuzz.**
  - Permutace pořadí sousedů v CSR a pořadí vstupů (6 pořadí, s16 i s64): K dává 1 otisk sestupu.
  - E63 E dává 2 různé otisky. Závislost na pořadí u ε-sestupu je tedy skutečná, ne jen teoretická.
  - Po každém výkopu: otisk stavu sestupu (capv všech pásem + pool) = čerstvý plný K. Shoda 31 / 29 / 32 čistých
    stavů, 0 neshod výsledků s tol 0.
  - Proti starému F.solve (tol 1e-9): 0 neshod (K+I na všech mapách, K+I+P+R 2k na s32). Pevné pořadí (lo, id) při
    volbě pool tedy na těchto datech výsledek nemění.
- **M, dva až tři hráči** (`tools/alg64_fuzz.gd`, `shots/e64/fuzz_s16.json`, `fuzz_s64.json`):
  - Nejhorší výkop + výkopy v sousedních sloupcích (x+1, y+1).
  - 8 scénářů: sync a, b / b, a / b, c, a; R s 2k: výkop během rozpracovaných kroků, výkop hned po výkopu,
    tři výkopy prokládané 1–3 kroky.
  - Po každém dokončení všech kroků je otisk = čerstvý plný výpočet pro danou množinu výkopů. 20 / 20 kontrol OK.
  - Na konci mají všechna pořadí stejný otisk (s16 i s64).
- **Kde pořadí oprávněně záleží:**
  - Zveřejněný výsledek během rozpracovaných kroků: platí starý výsledek, dokud úloha nedoběhne.
  - Počet kroků (17–152 podle pořadí).
  - Vnitřní čítače (gen, lab, id uzlů B).
  - Líné stavy: D přeskočí volání, jehož výsledek se nezměnil, a jeho stav sestupu nese jen špinavá pásma. Na s64
    jsou 2 na konci každého scénáře. Výsledek je správný, stav se opraví při dalším přepočtu.
  - Výkop sám je komutativní (h = min(h, nh)). Zasypání zatím neumíme, tam by pořadí záleželo.
- **V (vertikální komprese): negativní.**
  - Vnitřní článek řetězce (bez bočních sousedů, nejvýš 1 nad a 1 pod) je jen 1 897 ze 130 862 pásem tělesa (1,45 %)
    (`tools/alg64_info.gd`).
  - Plný sestup ušetří 85 výběrů z 207 410. Čas se nezlepšil, někde se zhoršil (šum + režie).
  - Odhad Gemini 10⁵ → 10⁴ na našich datech neplatí. Pásma mají skoro vždy boční sousedy.
- **P (navíc, není v zadání), priority-flood z paměti:**
  - Po opravě I zbyly floody a průsak (~35–45 ms na výkop).
  - Když se pool nezměnil a výkop nesáhl na data, která flood četl, výsledek se vezme z paměti. Ta data jsou: sloupce
    pásem tůně + 4 sousedé, sloupec výstupu a sousedé pásem tůně v CSR.
  - Přeskočí se na s16 / s64 skoro vždy, na s32 jen někdy.
  - Navíc se `vb` pro D udržuje průběžně ve stavu místo průchodu 118 000 pásmy (~10 ms na flood).
- **Server, jen podzemí** (s64, 5 % výkopů do podzemí, % jednoho jádra):

  | | E63 +E+I | K+I | K+I+R | K+I+P | K+I+P+R |
  |---|---|---|---|---|---|
  | 50 × 20/min | 7,5 | 6,3 | 6,4 | **3,2** | 3,5 |
  | 50 × 4/min | 1,5 | 1,3 | 1,3 | **0,63** | 0,69 |
  | 10 × 4/min | 0,3 | 0,25 | 0,26 | **0,13** | 0,14 |

- **Paměť:**
  - Stav K+I je 33 B na pásmo a volání: capv 8 B; par, děti (3×), pos, mk po 4 B; vb 1 B. Plus cl.
  - Na s64 (4 volání) je to 40 MB, v E63 16 MB. Peak 299–344 MB (E63 282–294 MB).
- **Negativa:**
  - Nejhorší výkop se bez R nezlepšil (s64 164 → 540–600 ms). Strom rodičů z haldy (max-first) má pro kmenový výkop
    větší podstrom než FIFO strom E63. Průměr a s32 se zlepšily. R to drží pod 16 ms na krok (2k).
  - Paměť stavu 2,5× víc než E63.
  - Úplné K (bez I) je 1,0–1,1 s na výkop. Halda v GDScript je dražší než FIFO E (~0,65 s).
  - „Okamžitá část“ R (prameny, odtoky a časy plnění hned u výkopu) **není** udělaná. Zveřejní se až celý výsledek.
    Do té doby platí starý výsledek s příznakem `_pending`.
  - Rozpočet počítá operace stejně, i když operace floodu je ~5× dražší. Vážení je nápad do C.
  - Měřeno při 4 souběžných bězích. Časy kolísají ±20 % (K+I s64 průměr 75–92 ms mezi běhy).
- **Testy a hashe po změně:** v1 dda863feffe6f611, sled46 d8af7f59b6f8da70, svet8 ec0681cc6426, voda a14136754dd1,
  voda_b 5ae2b366e84a, voda_b --b e8cbbc78ca88. Všechny beze změny, 2× stejné (`shots/e64/testy/`). Běhy alg58
  (E58–E63) jsem znovu nepouštěl, aby nepřepsaly `shots/alg58/`. Háčky v ug58 jsou jen za `c._useK`.
- **Shot:** `shots/64_podzemi.png`. Tabulka `shots/e64/tabulka.md`, logy a json `shots/e64/`.

## E64 kanonický sestup, oprava se zárukou shody, kroky R, dva hráči, komprese V (plán 2026-11-19 12:40; Jan 12:36 „Jon určitě to zkus.“, podle rešerše Gemini [42])
- **Problém (E63):**
  - Sestup s tolerancí E závisí na pořadí zpracování, takže lokální oprava I je shodná jen empiricky.
  - Nejhorší výkop trval 461 ms.
  - Chybí test, kde kope víc hráčů.
- **Varianty** (příznaky ve variantě, např. `A+B+C+D+K+I+R`, výchozí hodnoty beze změny, kód `scripts/alg64/`):
  - **K:** halda s klíčem (capv sestupně, id vzestupně). Pravidla hran stejná jako E63 (`_p1_edge`). Zlepšení se přijme
    jen ostře (nc > capv), bez tolerance E. Pool = nejmenší (lo, id).
  - **I:** S = změněná pásma X + jejich potomci ve stromu rodičů. S se vynuluje, osadí ze **všech** hran z dosažených
    pásem mimo S do S (max f(capv(u))) a ze vstupů v S. Pak běží stejný sestup, který smí zlepšit i pásma mimo S.
  - **R:** oprava, flood a průsak po krocích s pevným počtem operací (2k / 5k / 10k), nikdy podle času. Výsledek se
    zveřejní po doběhnutí. Nový výkop během kroků se přidá do rozpracované haldy.
  - **M:** 2–3 výkopy u sebe v různém pořadí a prokládané nedokončenými kroky R. Po každém dokončení se porovná otisk
    s čerstvým plným výpočtem.
  - **V:** články svislých řetězců (bez bočních sousedů) se zpracují hned bez haldy.
  - Kombinace: K+I, K+I+R, K+I+V, K+I+R+V.
- **Náčrt důkazu (K, I):**
  1. Hrana je f(x) = (x > práh) ? min(x, strop) : −∞, kde práh a strop jsou jen z dat pásem. Funkce je neklesající
     a f(x) ≤ x. Jde o „superior function“ ve smyslu zobecněného Dijkstry [43].
  2. Optimum opt(b) = max přes cesty od vstupů je jediné. Hodnoty vznikají jen přes min / max ze vstupních čísel,
     takže jsou to přesně ta samá čísla (bitově).
  3. **Lemma:** když je každý štítek dosažitelný platnou cestou (zdravý) a žádná hrana už nezlepší (uzavřený), pak
     štítky = opt. Důkaz: na optimální cestě vezmi první pásmo se štítkem < opt. Jeho předchůdce má štítek ≥ opt
     předchůdce. Z monotonie by hrana štítek zlepšila, a to je spor.
  4. Na pořadí zpracování tedy nezáleží, halda jen šetří práci. Plný výpočet = oprava s S = vše.
  5. **I:** mimo S vede řetězec rodičů jen přes nezměněná pásma a semínka, takže zůstává zdravý. Hrany mimo S
     s nezměněnými konci zůstaly uzavřené. Hrany do S se osadí všechny. Každé změněné pásmo jde do haldy a zpracuje
     se s konečnou hodnotou. Na konci je stav zdravý a uzavřený, tedy = plný výpočet.
  6. X stačí jen ze změněných pásem (hi, body) a ze všech vstupů ve sloupci, kde se změnil povrch (semínko min(hi, h)).
     Ostatní pásma sloupce mají stejné hrany.
  7. Prořezání (navíc): potomek si hodnotu nechá, když má oporu mimo S s ostře vyšší hodnotou, nebo už ponechanou.
     Kandidáti jdou v pořadí hodnot sestupně, takže taková opora už do S nepřibude. To je obdoba [44].
- **Metriky:** ms na výkop (průměr, p95, max), max ms na krok a počet kroků u R, navštívená pásma, paměť stavu,
  neshody proti čerstvému plnému K (tol 0 + otisk stavu) a proti starému F.solve (tol 1e-9), zátěž serveru jako E63.
- **Kritéria úspěchu:**
  - 0 neshod a bitová shoda otisků na všech výkopech.
  - Fuzz pořadí: 1 otisk.
  - M: shoda po každém dokončení.
  - R: max krok ≤ ~30 ms u nejhoršího výkopu.
  - Průměr ≤ E63.
  - Hashe E61 beze změny.

## E63 výsledky (2026-11-19 09:40)
- **Profil fází prelivu** (s64, A+B+C+D, 32 volání), součet za běh:

  | fáze | ms celkem | podíl |
  |---|---|---|
  | kapilární sestup (fáze 1) | 51 993 | 98 % |
  | priority-flood | 807 | 1,5 % |
  | průsak | 297 | 0,6 % |
  | souhrn | 25 | 0,05 % |

  Sestup projde ~118 000 pásem, tůň má jen 676 pásem.
- **Plán se změnil:** pokračování floodu od t* by ušetřilo nejvýš 1,5 %. **Nedělal jsem ho.** Místo toho:
  - **E** = stejný sestup (stejné pořadí fronty), jen s lokálními packed poli a bez `F._nbrs`.
  - **I** = lokální oprava sestupu přes strom rodičů:
    - S = pásma ve vykopaných sloupcích (i ve sloupcích výkopů, kdy se volání přeskočilo) + vstupy v nich + jejich
      potomci ve stromu.
    - S se vynuluje, osadí ze sousedů mimo S (hrana musí být v CSR souseda) a pak běží stejný sestup.
    - Průměrná velikost S: 282 pásem (s64), 522 (s16), 2 697 (s32).
- **Výkop, průměr / max ms, 20 výkopů, 0 neshod všude:**

  | varianta | s16 | s32 | s64 |
  |---|---|---|---|
  | base | 6191 / 6653 | 6204 / 6738 | 5802 / 6310 |
  | A+B+C | 3503 / 4170 | 3460 / 3764 | 3423 / 3987 |
  | +D (E62) | 2541 / 3588 | 2393 / 3480 | 2320 / 3346 |
  | +E | 682 / 947 | 672 / 984 | 649 / 998 |
  | **+E+I** | **94 / 144** | **111 / 461** | **90 / 164** |

  Plné řešení: base 6,1 s, D 4,5 s, E 2,1 s, E+I 2,4 s (zapisuje strom rodičů).
- **Paměť:**
  - D: 15,0 MB navíc (beze změny).
  - Stav I: 13 B na pásmo a volání + cl. Při 312 028 pásmech je to 8,5 MB (2 volání, s16 / s32) a 16,3 MB
    (4 volání, s64).
  - Peak 282–294 MB, dřív 283–290 MB.
- **Server, jen podzemí** (s64, 5 % výkopů do podzemí, % jednoho jádra):

  | | base | A+B+C | +D | +E | +E+I |
  |---|---|---|---|---|---|
  | 50 × 20/min | 484 | 285 | 193 | 54 | **7,5** |
  | 50 × 4/min | 97 | 57 | 39 | 11 | **1,5** |
  | 10 × 4/min | 19 | 11 | 7,7 | 2,2 | **0,3** |

- **Negativa:**
  - I není dokázaně bit po bitu shodná. Sestup s tolerancí E závisí na pořadí uvnitř E, takže se hodnoty capv mohou
    lišit o méně než E. Shoda výsledků (60 výkopů × volání) je ověřená jen empiricky.
  - Max na s32 461 ms: výkop 13 s velkým S. Na s32 je průměrná velikost S 2 697 pásem.
  - Plné řešení s I je o ~0,3 s pomalejší než s E.
  - Měřeno při 3–4 souběžných bězích. Dvě zastavení boxu (249 s a 355 s, ve všech souběžných bězích naráz) jsem
    přeměřil: D na s16 / s32, base na s32 / s64.
  - PF + průsak (~35 ms na volání) zůstávají plné a jsou teď většinou zbylého času.
- **Shot:** `shots/63_podzemi.png`. Logy: `shots/e63/`, json `shots/alg58/ug_*_e61.json`.
- **Příznaky:** E, I jen ve variantě (`A+B+C+D+E+I`). Výchozí hodnoty beze změny. Instrumentace `U.PROF` jen měří.

## E63 lokální oprava prelivu po výkopu (plán 2026-11-19 08:45; Jan 08:39 „Zkus tu optimalizaci o které jsi psal“)
- **Problém (E62):** s tabulkami v4 je hlavní těleso v režimu preliv. Každý výkop u vstupu znovu pustí celý
  priority-flood tělesa: 2,7–3,0 s na výkop (A+B+C+D).
- **Klíčová vlastnost priority-flood prelivu:**
  - Pořadí výběru je dané jen klíči (hladina, id) a daty pásem, která vybrané pásmo čte. To jsou `_nbrs` a `_outs`,
    tedy pásma ve stejném sloupci a ve 4 sousedních sloupcích, a výška povrchu těchto sloupců.
  - Výkop ve sloupci cc mění jen pásma a povrch ve sloupci cc. Až do prvního výběru pásma ze sloupců cc + 4
    sousedé (množina A) je proto průběh flood **přesně stejný**.
  - Stav fronty v tom okamžiku jde složit ze záznamu: vložené položky před t*, které ještě nebyly vybrány.
- **Plán (příznak E, varianta `A+B+C+D+E`, výchozí hodnoty beze změny):**
  1. Preliv si při výpočtu zapíše záznam:
     - pořadí výběru pásem a pořadí každého pásma v něm;
     - vložené položky (klíč, id, kdo je vložil);
     - spotřebované položky fronty;
     - výstupy.
     Fronta nese i index vložení. Pořadí mezi stejnými (klíč, id) na výsledek nemá vliv.
  2. Po výkopu: t* = nejmenší pořadí výběru pásma z A.
     - Prefix 0..t* zůstane, frontu složím z položek vložených před t* a nespotřebovaných.
     - Flood pokračuje od t* s novými daty a dál zapisuje záznam (řetězí se přes další výkopy).
     - Když v A nebylo vybráno žádné pásmo, výsledek se nemění.
  3. Kapilární sestup (fáze 1: vstupy → nejnižší pásmo tůně) se přepočte celý, jen pokud ho výkop zasáhne
     (pravidla E62). Změní-li se nejnižší pásmo, pustí se celý flood.
  4. Průsak a souhrn (objem, události) se přepočtou nad tůní. `_leak` znovu jen u pásem z A a u pásem, kterých se
     týká změna hladiny L. Ostatní hodnoty se vezmou z paměti.
- **Ověření:**
  - 0 neshod proti čerstvému plnému řešení po každém výkopu, s16 / s32 / s64, stejných 20 výkopů včetně výkopů
    u odtoků tůní.
  - Časy výkopu průměr / max pro base, A+B+C, +D, +E. Paměť záznamu.
  - Znovu tabulka zátěže serveru za podzemí.
  - Testy a hashe E61 beze změny.

## E62 výsledky (2026-11-19 05:15)
- **Závislost prelivu na pásmech (příznak D) je přesná, ale skoro nepomáhá.** Tabulky v4, 20 výkopů, záznam `_e61`:

  | mapa | varianta | výkop průměr / max | floodů | ponecháno / přepočteno | neshod |
  |---|---|---|---|---|---|
  | s16 | A+B+C | 3929 / 6084 ms | – | – | 0 |
  | s16 | A+B+C+D | 2862 / 4222 ms | 31 | 11 / 29 | 0 |
  | s32 | A+B+C | 3778 / 4062 ms | – | – | 0 |
  | s32 | A+B+C+D | 2961 / 4730 ms | 29 | 13 / 27 | 0 |
  | s64 | A+B+C+D | 2687 / 3894 ms | 32 | 12 / 28 | 0 |
  | s64 | A+B+C (E61) | 3401 / 3913 ms | 44 | 0 / 44 | 0 |
  | s64 | base (E61) | 5967 / 7138 ms | – | – | 0 |

- **Proč nepomáhá:**
  - Polovina výkopů je schválně u vstupů těles (tak se hraje: kope se u vody).
  - Vstupy jsou místa, kde tůň na povrchu odtéká do tělesa, takže tam tůň prelivu sahá k povrchu.
  - Pravidla 3 a 4 tedy oprávněně hlásí změnu. Přeskočit přepočet tam nejde, výsledek se opravdu může změnit.
  - Ms rozsah by vyžadoval lokální opravu priority-flood prelivu (přeplavit jen kolem výkopu a navázat na staré
    hladiny). To jsem do konce noci neudělal.
- **Zátěž serveru za podzemí** (50 hráčů × 20 úprav/min, 5 % výkopů do podzemí, s64):

  | | % jednoho jádra |
  |---|---|
  | base | 497 % |
  | A+B+C | 283 % |
  | A+B+C+D | 224 % |
  | A+B+C s v3 (E60) | 0,08 % |

  Při 50 × 4 / min je to 45 %, při 10 × 4 / min 9 % (A+B+C+D).
- **Příčina průsaku 0,378 → 0 (ověřeno, `tools/e62_dno.gd`):**
  - Hlavní těleso (26 vstupů) je ve v4 v režimu preliv, dno je celé nepropustné (13 758 m²). Režim ve v3 jsem
    znovu nespouštěl (sdílené tabulky už jsou v4), běh E60 ve v3 měl 4 floody prelivu.
  - Průsak v preliv počítá `_leak` jen do slabě propustného okolí: pásma s 0 < perm < `ponor_perm` 0,3, váha
    perm · leak_m2.
  - Okolí tělesa tvoří hlavně prachovec (id 45, 1680 m² dna) a flyš (id 58). Ve v3 měly perm 0,1 a 0,15, takže
    prosakovaly. Ve v4 mají K = 1e-9, tedy perm 0, a neprosakují.
  - Naopak černé uhlí, zvětralý granit a zvětralý vulkanit přešly nad 0,3 a staly se tělesy (1345 → 1375 těles).
- **Negativa:**
  - Cíl „zpět na ms“ jsem **nesplnil**. D dává jen 1,27× (3,4 → 2,7 s).
  - Pravidla D jsou konzervativní (sloupec + 4 sousedé). Přesnost je ověřená jen na 3 × 20 výkopech.
  - Výchozí hodnoty beze změny. D je jen v `scripts/alg58/ug58.gd` (`has_flag(v, "D")`) a v `tools/alg58_ug.gd`.

## E62 graf těles B pro režim preliv (plán 2026-11-19 05:05; Jan noční mandát)
- **Problém (E61):** s v4 je hlavní těleso v režimu preliv. A+B+C po výkopu znovu zaplaví celé těleso, protože
  sloupcová stopa (sloupce navštívených pásem + 4 sousedé) pokryje skoro celou mapu. Výsledek: 3,4 s na výkop.
- **Plán (varianta příznak D, `A+B+C+D`, výchozí hodnoty beze změny):**
  - Místo sloupcové stopy zjistit závislost výsledku prelivu na pásmech. Výsledek se po výkopu ve sloupci cc
    přepočítá jen když:
    1. změněné pásmo (hi nebo body) bylo navštíveno (kapilární sestup nebo priority-flood);
    2. navštívené pásmo ve sloupci cc nebo u 4 sousedů má změněné pásmo v seznamu sousedů;
    3. pásmo tůně ve sloupci cc nebo u 4 sousedů sahá k nové výšce povrchu (hi ≥ nh − E), kde se mění výstupy
       na povrch a průsak;
    4. některý vstup je ve sloupci cc.
  - Jinak výsledek čte jen nezměněná data, takže je stejný.
  - Ověřit 0 neshod proti čerstvému plnému řešení při s16 / s32 / s64 s tabulkami v4.
  - Přepočítat zátěž serveru za podzemí.
- **Příčina průsaku 0,378 → 0 l/s:** ověřit materiál dna hlavního tělesa v3 proti v4.

## E61 výsledky (2026-11-19 04:50)
- **Tabulky:**
  - `materialy_voda.json` v4: 10 materiálů.
  - `horniny_voda.json` v2: 56 hornin.
  - Přehled změn je v `shots/e61/zmeny_tabulek.md`.
  - Zálohy: `shots/e61/materialy_voda_v3.json`, `horniny_voda_v1.json`. Staré výsledky testů jsou
    v `shots/e61/pred/`.
  - Nejdůležitější změny:

    | materiál | perm | por | ret | ero_v | sed_v |
    |---|---|---|---|---|---|
    | tráva | 0,25 → 0,667 | 0,4 → 0,45 | 0,15 → 0,3 | 1,2 → 1,5 | 0,03 → 0,003 |
    | hlína | 0,3 → 0,595 | 0,4 → 0,43 | 0,15 → 0,28 | 0,35 → 0,4 | 0,03 → 0,003 |
    | písek | 0,8 → 0,833 | 0,35 | 0,05 → 0,09 | 0,25 | 0,08 → 0,03 |
    | jíl | 0 | 0,45 → 0,5 | 0 → 0,48 | 0,8 → 1,2 | 0,01 → 0,0005 |
    | vápenec | 0 → 0,246 | 0 → 0,05 | 0 → 0,03 | 4 | 0 |
    | křemenný pískovec | 0,5 → 0,333 | | | | |

- **Testy po změně** (všechny projdou, hashe se podle očekávání změnily):

  | test | starý hash | nový hash | výsledek |
  |---|---|---|---|
  | test (blueprint v1) | 45f42cd597c0f8c9 | dda863feffe6f611 | 2× stejné |
  | horniny (sled46) | 00dc4dc614729194 | d8af7f59b6f8da70 | 2× stejné, validátor vody OK |
  | svet8 | f08f56000feb | ec0681cc6426 | 2× stejné, jinak beze změny |
  | voda (eroze okraj) | 36236d38becf | a14136754dd1 | 2× stejné |
  | voda_b (E47c prameny) | 604e5080a046 | 5ae2b366e84a | 2× stejné |
  | voda_b --b (E47b) | e89b4b1dd59c | e8cbbc78ca88 | 2× stejné |
  | dohnani54 tůň / koryto | f83967a30e688676 / fca8f43966daedc9 | 37312ef4b728d6c0 / 1c63729c43fa012d | VŠE OK |
  | podzemi, eroze51, podzemi55, plosne53, podzemi52 testy | – | – | VŠE OK |
  | tun (Janův příklad) | – | – | VŠE OK po úpravě testu |

- **Co se změnilo ve vodě:**

  | měření | před (v3) | po (v4) | proč |
  |---|---|---|---|
  | E47b déšť (svět): odteklo / kaluže / mokré sloupce | 683 / 9,36 m³ / 102 | 320 / 2,64 m³ / 29 | tráva a hlína propustnější (vsak) |
  | E47b strže: odteklo / kaluže / ponory pohltily | 583 / 44,9 m³ / 100 buněk | 213 / 27,2 m³ / 52 | totéž |
  | E47c prameny: ponory pohltily | 0,73 l/s | 0,26 l/s | jiný tok, méně ztrát v korytě |
  | E47c hráz přes potok: okno / dotčeno | 558 / 585 | 247 / 280 | potok jinde (32, 10) místo (5, 15) |
  | E51 události: živé položky / fronta max | 2893 / 14113 | 893 / 8018 | nižší sed_v → méně nánosu, vyšší ero_v jílu a trávy |
  | E54 tůň 60 dní: události / nános / velikost tůně | 223 / 216 / 114 sloupců | 97 / 90 / 195 sloupců (3/3 vrstvy) | nižší sed_v, víc vody v tůni |
  | E54 koryto 60 dní | 511 událostí, 2,63 m³ do tůně | 511, 2,60 m³ | skoro beze změny |
  | podzemí svet64 (s64): průsak světa / výtok / tělesa | 0,378 / 2,48 l/s / 1345 | 0,000 / 2,17 l/s / 1375 | pravděpodobně dno z prachovce nebo flyše: perm 0,1–0,15 → 0 (K 1e-9), neověřeno |

- **Úprava testu:**
  - `scripts/voda/tests_tun.gd` počítal s perm křemenného pískovce 0,5 (Janův příklad: odtok 0,5 za t).
  - Teď pit_q dopočítá z perm v tabulce (odtok = perm · pit_q · 4), takže čísla Janova příkladu (16 t, 0,5 / 0,5)
    zůstávají a test nezávisí na hodnotě perm.
- **Negativa:**
  - Sdílenou tabulku čte i prototyp (`godot-prototyp/scripts/gen3/water_table.gd`), voda-studie a lozika-studie.
    Změní se i u nich. Jejich kód jsem neměnil ani nespouštěl.
  - Snímky v `shots/` jsem nepřekreslil (testy jsem pouštěl bez renderu), obrázky E45–E58 ukazují hodnoty v3.
    Bench / json soubory testů jsou přepsané novými, staré jsou v `shots/e61/pred/`.
  - Horniny mají ero_v, ale ero_vol jen měkké (spraš, kopcový písek, suť), takže ostatní dál neerodují.
  - Režim (okamzite / udalost / nepropustne) je zatím jen pole v tabulce. Kód ho nečte, simulace dál používá perm.
  - Dlouhý běh `podzemi52` (slovník 64, ~10 min) jsem znovu nespouštěl, jen jeho testy.
  - Časy E58 / E60 byly měřené s tabulkami v3.
  - **Podzemí A+B+C s novými materiály ztratilo náskok.** Hlavní těleso (26 vstupů) má teď dno s perm 0, takže
    režim je preliv. B (graf těles) umí jen nádrž / směs. V preliv po každém výkopu ve stopě znovu zaplaví celé
    těleso (44 floodů na 20 výkopů).

    | s64, 20 výkopů | výkop průměr / max | neshod |
    |---|---|---|
    | base | 5967 / 7138 ms | 0 |
    | A+B+C | 3401 / 3913 ms | 0 |
    | A+B+C v3 (pro srovnání) | 1,0 / 10,3 ms | 0 |

    Zátěž serveru E60 (podzemí 5 % výkopů) tak s v4 neplatí: 50 × 20 / min na 512² ≈ 17 % + 283 % za podzemí.
    Další krok je B pro režim preliv (lokální re-flood), zatím neudělané.

## E60 výsledky (2026-11-19 04:40; tabulky materiálů ještě v3, před E61)
1. **Σ průsak 0,756 při s16 / s32 byla chyba měření, ne A+B+C.**
   - `tok.route` volá podzemí v každém kole smyčky povrch ↔ podzemí (až 4 kola) s novým q. Záznam ukládal všechna
     kola a součet je sčítal. Svět bere jen poslední kolo (`st.ug_bodies`).
   - **Oprava:** `alg58_rec` označí volání posledního kola (`final`) a uloží průsak světa. `alg58_ug` sčítá jen
     `final`, starý součet je dál v `leak_all_calls`. Záznam `_e60`, staré soubory E58 zůstávají.

   | mapa | průsak světa | A+B+C | base | neshod | A+B+C výkop průměr / max | base výkop |
   |---|---|---|---|---|---|---|
   | s16 | 0,378 | 0,378 | 0,378 | 0 | 1,9 / 10,8 ms | 3471 ms |
   | s32 | 0,378 | 0,378 | 0,378 | 0 | 2,0 / 11,0 ms | 2725 ms |
   | s64 | 0,378 | 0,378 | 0,378 | 0 | 1,0 / 10,3 ms | 1837 ms |

   - Průsak je teď nezávislý na rozlišení (dřív 0,756 / 0,756 / 0,378).
2. **Povrch, lokální přepočet `scripts/alg60/tok60.gd` (kopie `tok.update`, `tok.gd` beze změny).**
   - 60 výkopů u vody. Pole fill, eff, to, ain, pw, extra, src2, sink, tůně a under se po každém výkopu shodují bit
     po bitu s `tok.update` (C+A): **0 neshod** na 128², 256² i 512².
   - Změny:
     - D8 jen u buněk, kde se změnila fill buňky nebo souseda.
     - `_cell` jen tam, kde se změnil vstup (fill, cíl odtoku, přítok shora). Mimo okno beze změny.
     - Flood okna s haldou ve dvou packed polích (pořadí (fill, index) stejné jako reky.gd, takže stejný výsledek).
     - Okno a kontrola okraje přes lokální pole.
     - Seřazené klíče tůní se drží, dokud se množina tůní nezmění.
     - Měkký přepočet tůně (stejné buňky) nepočítá znovu propustnost dna (materiály se výkopem nemění).

   | mapa | tok.update průměr / max | tok60 průměr / max | zrychlení |
   |---|---|---|---|
   | 128² | 3,1 / 9,0 ms | 1,1 / 6,0 ms | 2,8× |
   | 256² | 11,8 / 22,9 ms | 3,4 / 9,4 ms | 3,5× |
   | 512² | 41,8 / 82,7 ms | 10,2 / 26,1 ms | 4,1× |

   - **Fáze na 512²** (ms na výkop, `tok_prof` / `tok60`):

     | fáze | tok_prof | tok60 |
     |---|---|---|
     | okno + flood | 15,2 | 6,3 |
     | D8 + průtok v okně | 14,8 | 1,7 |
     | odtoky tůní | 14,5 | 1,9 |

   - **Zátěž serveru znovu** (% jednoho jádra, podzemí A+B+C 1,0 ms na 5 % výkopů):

     | mapa | 50 × 20 / min | 50 × 4 / min | 10 × 4 / min |
     |---|---|---|---|
     | 128² | 5,3 → 2,0 | 1,1 → 0,4 | 0,2 → 0,1 |
     | 256² | 19,7 → 5,7 | 3,9 → 1,1 | 0,8 → 0,2 |
     | 512² | 69,8 → 17,1 | 14,0 → 3,4 | 2,8 → 0,7 |

3. **Graf pánví B je přesný, rozdíl dělá jen ε.**
   - B proti priority-flood bez ε (vlastní kopie, ε = 0): **0 rozdílných buněk** na 128², 256² i 512²
     (Barnes 2014 [36]).
   - Buňky tůní:

     | mapa | PF bez ε | B | tok.gd s ε = 1e-3 | jen kvůli ε |
     |---|---|---|---|---|
     | 128² | 1818 | 1818 | 1878 | 60 |
     | 256² | 7720 | 7720 | 7927 | 207 |
     | 512² | 31950 | 31950 | 32845 | 895 |

   - ε zvedá roviny a dna tůní o ε na krok, max o 0,064 / 0,12 / 0,24 buňky. Ploché místo delší než ~10 kroků tak
     přeleze práh tůně 0,01. Jsou to tedy „tůně z ε“, ne prohlubně.
   - **B + ε je přesné:** fill tok.gd je pevný bod F = max(hm, min souseda F + ε), protože první vytažený soused má
     nejmenší fill. Zvedání zdola od B (`tools/alg60_b.gd`) dá bit po bitu stejnou fill jako tok.gd: 0 rozdílů na
     128². Je ale pomalé: 2,1 s proti 0,14 s PF, 35 054 zvednutí. 256² a 512² jsem nedoměřil (ukončeno kvůli E61).
- **Negativa:**
  - Menší počáteční okno (okraj 4 nebo 12 místo 24 s automatickým zvětšením) je rychlejší (7,7 ms), ale **špatně**:
    proti plnému route eff až o 2,24 l/s, fill o 0,24. Kontrola odtoku na okraji okna nestačí, okraj 24 zůstává.
  - `tok60` vrací v `touched` / `cells` jen buňky, které se opravdu přepočítaly (méně než tok.update). Pro E51
    přeplánování je to méně práce, ale rozhraní se liší.
  - Mezipaměť klíčů tůní předpokládá, že se na stejném stavu nemíchá tok60 s tok.update.
  - Flood okna je pořád 62 % času. Přesné rané zastavení floodu s ε jsem nenašel (pořadí závisí na ε řetězcích).
  - Odchylky E51b proti plnému route (fill až 0,91 na 2 buňkách, eff 0,000625) zůstávají. Mají je obě verze stejně,
    jsou to staré vlastnosti okna.
  - Měřeno při 3–5 souběžných bězích, absolutní časy kolísají ±15 %. Poměr je ze stejného procesu.
- Shot `shots/60_povrch.png`. Spuštění `./run.sh alg60`.

## E61 převzetí reálných vodních hodnot do sdílených tabulek (plán 2026-11-19 04:42; Jan 04:39)
- **Zadání (Jan 04:39):** dosavadní hodnoty materiálů byly zkušební a smí se přepsat. Převzít výsledky výzkumu E59 do
  `sdilene/materialy_voda.json` a `sdilene/horniny_voda.json`, vápenec včetně (dřívější „vápenec nepropustný“ byla
  zkušební hodnota). Ponechat log škálu perm, tři režimy a čas hry (1 herní den = 10 min reálně).
  Číslo E61, protože E60 už je noční optimalizace.
- **Plán:**
  - Zálohovat staré tabulky do `shots/e61/` (v3 a v1) i s výsledky testů (bench a json v `shots/`).
  - Převzít z `materialy_voda_navrh.json` (`tools/materialy61.py`):
    - perm = (log10 K + 9) / 6
    - por = n
    - ret = n − Sy
    - ero_v a sed_v (Hjulström)
    - nová pole K_ms, Sy, skupina, t_1m_realne_min, rezim
  - V hlavičce: mapování, faktor času 144, prahy režimů (okamžitě < 10 min reálně, nepropustné > 30 dní reálně).
  - Beze změny: res, load, cantilever, ero_vol, vzduch, sníh, minerály (id ≥ 100).
  - Horniny dostanou ero_v a sed_v. Měkké (spraš, kopcový písek, suť) i ero_vol podle hlíny / písku, ostatní ho dál
    nemají, takže zůstanou tvrdé.
  - Spustit všechny testy znovu a zapsat staré a nové hashe a co se změnilo: průsak / výtok, časy tůní, eroze.
  - Prototyp ani jeho kód se nemění. Čte ale sdílenou tabulku za běhu, takže se změna projeví i v něm (jen konstatuji).

## E60 doladění E58: dvojí volání podzemí, lokální přepočet povrchu 512², přesnost grafu pánví (plán 2026-11-19 04:22; Jan t586u)
- **Plán:**
  1. **Σ průsak 0,756 při s16 / s32.**
     - Zjistit, proč má jedno těleso 2 volání. Předpoklad: smyčka povrch ↔ podzemí v `tok.route` (až 4 kola) volá
       solve znovu s novým q, záznam ukládá všechna kola.
     - Opravit součet tak, aby se počítalo jen poslední volání na těleso (to, které je ve `st.ug_bodies` na konci
       běhu). Ověřit proti průsaku světa (Σ `ug_bodies`).
     - Spustit znovu base a A+B+C při 16 / 32 / 64. Očekávám 0 neshod a stejné časy.
  2. **Povrch 512²: lokální přepočet C+A (44,6 ms).**
     - Změřit, kolik stojí jednotlivé části `tok.update`: okno, flood, D8, průtok po proudu, odtoky tůní, tůně.
     - Optimalizovat samostatnou kopií `scripts/alg60/tok60.gd`, `tok.gd` se nemění:
       - znovupoužití pomocných polí místo slovníků
       - ohraničená oblast
       - ladění ranného zastavení
     - Ověřit bit po bitu proti `tok.update`: fill, eff, to, ain, pw, extra, src2.
     - Přepočítat tabulku zátěže serveru.
  3. **Graf pánví B (1818 / 1878 buněk tůní při 128²).**
     - Ověřit předpoklad, že B je přesné vůči priority-flood bez ε (Barnes 2014) a rozdíl dělá jen ε spád 1e-3
       na rovinách a v tůních.
     - Zkusit B + lokální ε dopočet. Pokud nebude bit po bitu stejný, popsat proč.
- Výchozí hodnoty ani `tok.gd` se nemění, hashe musí zůstat stejné.

## E59 materiály podle skutečných hodnot, čas průsaku ve hře (plán a výsledek 2026-11-19 04:05; Jan 03:47)
- **Plán:**
  - Ke každému materiálu ze `sdilene/materialy_voda.json` a `sdilene/horniny_voda.json` najít skutečné hodnoty:
    - hydraulická vodivost K
    - pórovitost n
    - specifická vydatnost Sy a zadržení n − Sy
    - práh eroze a usazování (Hjulström)
  - Spočítat průsak 1 m v herním čase (1 herní den = 10 min reálně, × 144).
  - Navrhnout herní hodnoty do **samostatného** souboru `sdilene/materialy_voda_navrh.json`. Sdílené tabulky zůstávají
    beze změny, Jan rozhodne.
- **Postup:** `tools/materialy59.py`. Materiály jsou zařazené do 18 skupin. K je střed rozsahu v log10 podle Freeze
  & Cherry tab. 2.2 [38]. Půdy podle Rawls 1982 [40]. Sy podle Johnson 1967 [39]. ero_v / sed_v jsou odečtené řádově
  z Hjulströmova diagramu [32]. Pórová rychlost v = K · i / Sy při spádu i = 1, čas na 1 m t = Sy / K.
- **Výsledek** (výběr, celá tabulka je `shots/materialy59.md`, 66 materiálů; „nyní“ = současná hodnota ve sdílené
  tabulce):

  | materiál | skupina | K m/s | n | Sy | perm návrh (nyní) | ero_v návrh (nyní) | sed_v návrh (nyní) | 1 m: herní dny | 1 m: reálně |
  |---|---|---|---|---|---|---|---|---|---|
  | grass | drn | 1e-05 | 0.45 | 0.15 | 0.667 (0.25) | 1.5 (1.2) | 0.003 (0.03) | 0.174 | 2 min |
  | dirt | hlina | 4e-06 | 0.43 | 0.15 | 0.595 (0.3) | 0.4 (0.35) | 0.003 (0.03) | 0.469 | 5 min |
  | sand | pisek | 1e-04 | 0.35 | 0.26 | 0.833 (0.8) | 0.25 (0.25) | 0.03 (0.08) | 0.0301 | 18 s |
  | clay | jil | 1e-10 | 0.5 | 0.02 | 0.0 (0) | 1.2 (0.8) | 0.0005 (0.01) | 2.31e+03 | 16 dní |
  | limestone | vapenec | 3e-08 | 0.05 | 0.02 | 0.246 (0) | 4.0 (4) | 0.0 (0) | 7.72 | 77 min |
  | granite | krystal | 1e-12 | 0.01 | 0.005 | 0.0 (0) | 6.0 (6) | 0.0 (0) | 5.79e+04 | 402 dní |
  | basalt | cedic | 1e-09 | 0.05 | 0.02 | 0.0 (0) | 6.0 (6) | 0.0 (0) | 231 | 39 h |
  | deep_limestone | vapenec | 3e-08 | 0.05 | 0.02 | 0.246 (0) | 4.0 (—) | 0.0 (—) | 7.72 | 77 min |
  | siltstone | prachovec | 1e-09 | 0.15 | 0.03 | 0.0 (0.1) | 1.5 (—) | 0.0 (—) | 347 | 2 dní |
  | conglomerate | slepenec | 1e-06 | 0.2 | 0.1 | 0.5 (0.4) | 2.0 (—) | 0.0 (—) | 1.16 | 12 min |
  | rock_salt | evaporit | 1e-13 | 0.01 | 0.005 | 0.0 (0) | 1.0 (—) | 0.0 (—) | 5.79e+05 | 11 let |
  | black_coal | uhli | 1e-07 | 0.08 | 0.03 | 0.333 (0.02) | 1.5 (—) | 0.0 (—) | 3.47 | 35 min |
  | shale | bridlice | 1e-11 | 0.05 | 0.01 | 0.0 (0) | 2.0 (—) | 0.0 (—) | 1.16e+04 | 80 dní |
  | quartz_sandstone | piskovec | 1e-07 | 0.2 | 0.1 | 0.333 (0.5) | 2.0 (—) | 0.0 (—) | 11.6 | 116 min |
  | loess | spras | 1e-07 | 0.45 | 0.08 | 0.333 (0.35) | 0.3 (—) | 0.002 (—) | 9.26 | 93 min |
  | hill_sand | pisek | 1e-04 | 0.35 | 0.26 | 0.833 (0.7) | 0.25 (—) | 0.03 (—) | 0.0301 | 18 s |
  | weathered_volcanic | vulk_zvetr | 1e-05 | 0.25 | 0.1 | 0.667 (0.15) | 2.0 (—) | 0.0 (—) | 0.116 | 1 min |
  | weathered_granite | krystal_pukl | 1e-06 | 0.05 | 0.02 | 0.5 (0.2) | 3.0 (—) | 0.0 (—) | 0.231 | 2 min |
  | subalpine_scree | sterk | 1e-02 | 0.3 | 0.22 | 1.0 (0.7) | 1.2 (—) | 0.4 (—) | 0.000255 | 0 s |

- **Co to znamená pro hru:**
  - **Rychlé (písek, štěrk, suť, kras):** sekundy až minuty reálně. Ustálený stav (jak to dělá tok.gd / podzemí), bez
    simulace.
  - **Střední (hlína, drn, vápenec nekrasový, rozpukané krystalinikum, pískovec):** minuty až hodiny. Událost v haldě
    E51 („voda prosákne za t“).
  - **Pomalé (jíl, břidlice, hutné krystalinikum, čedič, sůl):** dny až roky reálně. Ve hře nepropustné, souhlasí
    s `perm_leak`.
- **Návrh kalibrace (Jan rozhodne):**
  - `perm_navrh` = (log10 K + 9) / 6 omezené na [0, 1]: K ≤ 1e-9 → 0, K ≥ 1e-3 → 1. Lineární v log zachová pořadí
    a rozsah 13 řádů.
  - Doplnit pole `K_ms` (m/s) a z něj počítat čas průsaku vrstvou (t = Sy · tloušťka / K) jako událost.
  - Prahy podle reálného času: t < `t_okamzite` (např. 10 min reálně) = ustálený stav. t > `t_horizont` (např. 30 dní
    reálně) = nepropustné. Mezi tím událost.
  - `ret_navrh` = n − Sy (jíl 0,48, písek 0,09, hlína 0,28).
- **Negativa:**
  - Rozsahy K mají 3–6 řádů na skupinu, typická hodnota je jen střed. Zařazení 63 hornin do skupin je moje
    (např. horské pojmenované horniny = krystalinikum).
  - Hodnoty z Hjulströmova diagramu jsou odečtené řádově, nejsou z tabulky. Skály (ero_v 2–6 m/s) jsou herní odhad.
  - Návrh mění chování hry:
    - Drn a hlína by byly propustnější než teď (0,67 / 0,6 proti 0,25 / 0,3).
    - Vápenec (nekrasový) má podle K perm 0,25, ale Jan 19:18 rozhodl „vápenec nepropustný“. V návrhu je to
      uvedené jen jako konflikt, nepřijímám to.
  - Sníh, vzduch a minerály (id ≥ 100) návrh nemá.
  - Pole jsem nezkoušel ve hře ani ve studiích (žádný běh s novými hodnotami).

## E58 algoritmické varianty A / B / C a jejich kombinace: podzemí i povrch (plán, zapsáno před pokusem 2026-11-19 03:35; Jan 03:30)
- **Cíl:** odstranit úzké hrdlo E57: po výkopu nad tělesem se podzemí přepočítá celé, 6 řešení × ~260 ms ≈ 1,6 s.
  Výsledky (průsak, výtok, hladina, výstup, objem, režim tělesa) musí zůstat stejné jako u výchozí varianty 4 `auto` (E55).
- **Varianty** (samostatná studie `scripts/alg58/`, parametr `p58_var` = `base`, `A`, `B`, `C`, `A+B`, `A+C`, `B+C`, `A+B+C`):
  - **A, kbelíková fronta:** zaplavování (preliv) přes kbelíky po hladinách `p58_dz` m místo haldy. V aktuálním kbelíku
    je malá halda, takže pořadí (klíč, id) je přesně stejné jako u haldy. Pomocná pole místo slovníků.
    Cena O(N + Σ b log b) místo O(N log N).
  - **B, graf těles:** uzel = souvislé těleso se souhrny (Σ průsak, seznam kandidátů výstupu, plocha dna podle
    materiálu, objem po hladině). Volání = vyhledání nejnižšího kandidáta místo BFS celého tělesa. Výkop přestaví jen
    uzly, kterých se týká (pásma ve sloupci výkopu a 4 sousedních). Při shodě kandidátů v toleranci → přesný BFS.
  - **C, lokální přepočet s ranným zastavením:** volání si pamatuje stopu (sloupce navštívených pásem + sousedé).
    Výkop mimo stopu → výsledek beze změny, nic se nepočítá. Ve spojení s B: delta souhrnů jen za pásma změněných
    sloupců. Pokud se nezměnila souvislost (žádné pásmo nezmizelo, žádný překryv se nerozpojil), uzel se nepřestavuje.
    Zaplavení (preliv) se opakuje, jen když výkop zasáhne jeho stopu.
- **Měří se** (svět E52, povrch 64 / blok, dutiny 16; vítěz a base také při 16 / 32 / 64):
  - plné řešení všech volání ze záznamu běhu (ms)
  - lokální změna po `p58_edits` = 20 výkopech 1 m nad tělesy: průměr a max (ms)
  - paměť navíc (bajty struktur + peak procesu)
  - **shoda** s čerstvým plným řešením po každém výkopu (tolerance 1e-9): průsak, výtok, z, typ a sloupec výstupu,
    objem, režim
  - počet návratů k přesnému BFS
- **Povrch (D8 + prohlubně, `tok.gd`):**
  - A = kbelíkový priority-flood (plný route i okno update)
  - C = lokální okno s ranným zastavením (už E51b / E54, base update)
  - B = graf povrchových pánví. Kde to přesně nejde, zapíšu proč.
  - Srovnání s route (plný přepočet) a update (výkop), při 128² / 256² / 512² (svet64 při 16 / 32 / 64 na blok).
    Shoda fill / eff bit po bitu.
- **Hypotéza:**
  - A zrychlí jen tělesa v režimu preliv (2 ze 3), asi 1,5×.
  - B a C sníží změnu z ~1,6 s na jednotky až desítky ms, protože se přepočítá jen 1 těleso.
  - B+C pod 10 ms. A+B+C ≈ B+C, protože zaplavování se po výkopu skoro nespouští.
  - Na povrchu A zrychlí plný route asi 1,3–2×. Update už je lokální (2,8 ms), A tam pomůže málo.

### E58 výsledky (2026-11-19 ~04:00, `tools/alg58_rec.gd` + `tools/alg58_ug.gd` + `tools/alg58_tok.gd` → `shots/alg58/*.json`, grafy `shots/58_podzemi.png`, `58_povrch.png`, `58_server.png`)
**Podzemí** (svět E52, povrch 64 / blok, 312 028 pásem, 6 zaznamenaných volání, 20 výkopů 1 m nad tělesy).
Každá varianta se po každém výkopu porovná s čerstvým plným řešením (průsak, výtok, z, typ a sloupec výstupu, objem,
režim, počet pásem).

| varianta | plné řešení | výkop průměr / max | paměť navíc | neshod |
|---|---|---|---|---|
| base (E55 auto) | 1651 ms | 1704 / 1860 ms | 0 | 0 |
| A | 1708 ms | 1678 / 1837 ms | 4,8 MB | 0 |
| B | 1018 ms | 1016 / 1223 ms | 20,5 MB | 0 |
| C | 1742 ms | 1706 / 1858 ms | 0,1 MB | 0 |
| A+B | 996 ms | 996 / 1060 ms | 25,3 MB | 0 |
| A+C | 1767 ms | 1719 / 1837 ms | 4,9 MB | 0 |
| B+C | 1104 ms | **1,0 / 10,3 ms** | 8,9 MB | 0 |
| **A+B+C** | 945 ms | **0,9 / 8,8 ms** | 13,7 MB | 0 |

- **Rozlišení** (A+B+C, povrch 16 / 32 / 64): výkop 3,2 / 1,8 / 0,9 ms, 0 neshod ve všech. Base 3315 / 2458 / 1704 ms.
- **Delší test:** 100 výkopů (seed 581, 98 zásahů tělesa) → 1,3 ms průměr, 9,4 ms max, 0 neshod.
- **Povrch** (svet64, A = kbelíky `p58_sdz` 1 buňka, B = graf pánví, C = E51b update):

  | mapa | route / A | flood / A | B graf pánví | výkop C / C+A | plný route po výkopu |
  |---|---|---|---|---|---|
  | 128² | 378 / 344 ms | 131 / 98 | 44 ms (829 pánví) | 2,8 / 2,6 ms | 379 ms |
  | 256² | 1400 / 1211 ms | 613 / 476 | 167 ms (1617) | 12,5 / 11,6 ms | 1352 ms |
  | 512² | 5656 / 4884 ms | 2570 / 1834 | 590 ms (3464) | 54,7 / 44,6 ms | 5695 ms |

  - A je bit po bitu shodné (fill, eff, to, i po 20 výkopech). B je nepřesné (jezera 1818 vs. 1878 buněk při 128²,
    Δ fill do 0,24 buňky).
- **E57 znovu s vítězem:** 50 hráčů × 20 úprav / min, 5 % do podzemí. Povrch 128²: 146 % → 4,4 % jádra. Povrch 512²:
  216 % → 74 % jádra. Úzké hrdlo je teď povrch ve velkém rozlišení.
- **Hypotéza:**
  - A samo nezrychlilo podzemí vůbec (čekal jsem 1,5×). Většina času je BFS tělesa kvůli dnu a objemu, ne halda.
  - B+C pod 10 ms platí: 1 ms průměr.
  - A na povrchu 1,1–1,16× (čekal jsem 1,3–2×). Samotný flood 1,3–1,4×.
- **Negativa:**
  - A ani C samy nepomáhají. B samo jen 1,7× (přestavba celého uzlu).
  - První verze B+C přestavovala uzel při zmizení pásma (výkop max 1,05 s). Oboustranný omezený BFS to vyřešil.
    Počet pásem po odebrání malé části byl o 1 mimo (57 neshod při 32). Opraveno tak, že se počet bere ze seznamu.
  - Tabulka časů plnění (události) se po deltě nepřepočítává (příznak `events_stale`, dopočet při dotazu). V testu se
    neporovnává.
  - Počet skoků k výstupu (`out[1]`) B nepočítá (−1). Neporovnává se, je to jen informační pole.
  - Při rozpadu tělesa, kdy odpadlá část obsahuje vstup tůně, nebo nerozhodnutém v limitu 20 000 pásem → přestavba
    ~1 s. V testech 0×.
  - Graf pánví na povrchu není náhrada priority-flood (chybí ε spád pro D8). Jen rychlý odhad tůní.
  - Update E51b se od plného route liší o 0,000625 l/s eff (512²) a 0,13 buňky fill (128²) na pár buňkách. Je to stará
    vlastnost okna, ne nového kódu.
  - Σ průsak / výtok v tabulkách je součet přes zaznamenaná volání. Při 16 a 32 má jedno těleso 2 volání s různým q,
    takže je to 0,756 l/s, ne průsak světa.
  - Měřeno v GDScriptu na 1 jádře. Běhy jely po 2–6 současně na 8 jádrech, časy plného řešení kolísají ±10 %.
- **Doporučení (Jan rozhodne):** podzemí A+B+C jako náhrada přepočtu po výkopu (stejný výsledek, 1900× rychleji).
  Na povrchu zapnout A (`tok.FLOOD_DZ`, zatím výchozí 0 = vypnuto, hashe beze změny). B na povrchu jen pro náhled.

## E57 odhad zátěže serveru pro 10–50 hráčů (rychlý přepočet z E54 / E55, nic nového neměřeno)
Předpoklady (moje, ne Janovy):
- **Úpravy terénu:** 4 / min na hráče je běžná hra, 20 / min je hromadné kopání.
- **Přepočet povrchové vody po úpravě:** E54 průměr 2,6 ms, max 7,5 ms.
- **Úpravy, které zasáhnou podzemí:** 5 %. Každá stojí přestavbu podzemí jako v E55, ~1,3 s.
- Zátěž = úprav / min × ms / 60 000 ms (podíl jednoho jádra).

| hráči | úprav / min | povrch prům. | povrch max | + podzemí 5 % × 1,3 s |
|---|---|---|---|---|
| 10 | 40 | 0,2 % | 0,5 % | 4,5 % |
| 10 | 200 | 0,9 % | 2,5 % | 22 % |
| 50 | 200 | 0,9 % | 2,5 % | 22 % |
| 50 | 1000 | 4,3 % | 12,5 % | 108 % (přes 1 jádro) |

- Fronta událostí E51 (2,6 µs na pop + push) a dohnání (511 událostí za 0,77 s na 60 herních dní) jsou proti tomu
  zanedbatelné.
- **Závěr:** povrchová voda unese 50 hráčů i při hromadném kopání. Úzké hrdlo je přestavba podzemí 1,3 s. Ta potřebuje
  lokální přepočet jen dotčeného tělesa, nebo dávkování úprav (1× za N s).
- **Negativa:** četnost úprav i podíl úprav v podzemí jsou odhad. Měřeno na jednom jádru boxu v GDScriptu.

## E56 mírnější výškové přechody (plán, zapsáno před pokusem v noci 18./19. 11.; Jan 21:12)
- **Co:** samostatná malá studie `scripts/svah56/`, `./run.sh svah56`, nad světem 8 × 8 (E49). Povrch bloku = hrubý
  svět bilineárně + šum 0,6 buňky, takže přechody určuje hrubý svět. Všechno je za přepínačem `s56_on` (výchozí
  false → svet8, svet64 a hashe beze změny).
- **Parametry:**
  - `s56_max_slope`: největší sklon v m/m (1,0 = 45°). Omezovač jako tepelná eroze. Průchody celou hrubou mapou, kde
    rozdíl sousedů nad sklon · vzdálenost se vyrovná napůl (hmota se zachová → hora se rozšíří, nesníží se jen
    oříznutím). Nejvýš `s56_pasy` průchodů. Po hrubém terénu i po erozi řek.
  - `s56_hladit`: počet průchodů vyhlazení 3 × 3 (měkčí reliéf hrubého světa), váha `s56_hladit_w`.
  - `s56_paty`: širší paty hor. Spodní mez masky hor smoothstep(0,05 → 0,05 − paty, 0,45), maska roste pozvolna.
  - `s56_hreben`: mocnina profilu hřbetu (rd^2 → rd^hreben, výška vrcholu stejná). Zatím jen jako možnost.
- **Měří se (před / po):**
  - sklon povrchu jemných buněk (0,5 m): p50 / p95 / max ve stupních
  - podíl buněk nad 45° a nad 30°, největší schod v buňkách
  - šířka paty nejvyšší hory: vodorovná vzdálenost od vrcholu k místu, kde výška klesne na čtvrtinu převýšení
  - výška vrcholu, počet horských dlaždic, čas
  - švy povrchu (E49 musí zůstat 0,00), validátor 64/64
- **Snímky `56_*`:**
  - `56_profil.png`: řez přes nejvyšší vrchol před / po, s postavou 2 m v měřítku
  - `56_mapa.png`: stínovaný reliéf před / po, strmé buňky nad 45° zvýrazněné
- **Hypotéza:**
  - Omezovač 1,0 sníží podíl buněk nad 45° skoro na 0 a pata hory se rozšíří zhruba o polovinu. Vrchol klesne
    o 1–2 m.
  - Typy dlaždic se mohou posunout (méně hor, víc kopců), protože typ určuje průměr a maximum výšky. To je možná
    negativum.

### E56 výsledky (2026-11-19 ~03:00, `./run.sh svah56` → `shots/bench_svah56.txt`; `--s56_max_slope=0.6` → `shots/bench_svah56_s06.txt`)
Svět 8 × 8 (E49), povrch 128 × 128 buněk 0,5 m. „Před“ = výchozí parametry (hash `f08f56000feb` = beze změny).

| | před | po, ≤ 1,0 (45°) | po, ≤ 0,6 (31°) |
|---|---|---|---|
| sklon p50 / p95 / max | 23° / 63° / 82° | 29° / 50° / 64° | 28° / 42° / 66° |
| buněk nad 45° | 21,3 % | 15,9 % | 2,4 % |
| buněk nad 30° | 38,5 % | 48,7 % | 43,7 % |
| největší schod | 7 buněk (3,5 m) | 2 (1 m) | 3 (1,5 m) |
| vrchol / převýšení | 29,9 / 11,5 m | 29,8 / 11,5 m | 29,0 / 10,7 m |
| pata nejvyšší hory | 12,1 m | 17,0 m (+40 %) | 15,7 m |
| louka / kopec / svah / hory | 24 / 6 / 5 / 19 | 10 / 17 / 0 / 23 | 8 / 20 / 1 / 20 |
| švy povrchu, validátor | 0,00, 64/64 | 0,00, 64/64 | 0,00, 64/64 |
| čas hrubý + detail | 13,6 s | 15,6 s | 16,3 s |

- Snímky: `shots/56_profil.png` (řez vrcholem 1 : 1, postava 2 m), `shots/56_mapa.png` (stínování, červeně > 45°).
- **Hypotéza jen zčásti:** se sklonem 1,0 zůstalo nad 45° 16 % buněk, ne „skoro 0“. Teprve 0,6 (31°) dá 2,4 %.
  Pata se rozšířila o 30–40 % a vrchol klesl o 0–0,9 m.
- **Negativa:**
  - Omezovač hrubé mapy nestačí na jemný povrch: šum 0,6 buňky na 0,5 m a bilineární lom dál dělají místa přes 60°.
    Na tvrdý strop by bylo třeba omezit i jemný povrch (`hm_f`) nebo zmenšit šum na svazích.
  - Medián sklonu a podíl nad 30° **vzrostly**: strmost se rozprostřela do širšího pásu (hmota se zachová).
  - Hmota sesypaná dolů zvedla údolí kolem hor o 1,5–2 m (viz řez), pláně jsou vlnitější.
  - Typy dlaždic se posunuly: louk 24 → 10/8, kopců 6 → 17/20, svahy skoro zmizely. Typ určuje hrubá výška, takže
    by se muselo přeladit `s8_*` prahy typů, nebo omezovač pouštět až po určení typů.
  - Při 0,6 je na stínování vidět mřížka bloků 8 m (lom bilineárního povrchu na švech). Metrika švů 0,00 měří
    jen shodu výšek, ne lom.
  - `s56_hreben` jsem neladil (nechán 2 = dřívější profil).
- Otevřené pro Jana: jaký strop sklonu chce (45°, 31°?), a jestli smí omezovač měnit typy dlaždic.

## E55 podzemí: režim podle dna tělesa (plán, zapsáno před pokusem v noci 18./19. 11.; Jan schválil 02:52)
- **Co:** ve variantě 4 (funkce nad vrstvami) se `nadrz` / `preliv` nevolí globálně, ale **pro každé těleso zvlášť**
  podle materiálu přímo pod propustnou vrstvou. Nový režim `p52_rezim = "auto"` (výchozí zůstává `nadrz`, aby se
  E52 a regrese neměnily).
- **Dno tělesa:** pásma tělesa, pod kterými ve stejném sloupci není další pásmo tělesa. Materiál pásma přímo pod nimi
  (perm ze `sdilene/materialy_voda.json`), plocha = plocha sloupce řídicí mřížky. Spodek ostrova (pod pásmem nic) =
  propustné (voda odchází ven z ostrova).
- **Práh** `p55_perm_dno` = 0,05 (= `perm_leak` sdílené tabulky: perm ≤ 0,05 vodu nepropustí). Dno s perm ≤ práh je
  nepropustné.
- **Pravidla:**
  - **celé dno nepropustné → `preliv`**: hladina stoupá k nejnižšímu výchozu, přebytek tam vyvěrá jako pramen
    (`out_q` → `src2` povrchu)
  - **celé dno propustné → `nadrz`**: průsak dolů / ven z ostrova
  - **smíšené dno:** podíl propustné plochy f = A_prop / A_dna. Průsak = f · průsak `nadrz` (nejvýš přítok), zbytek
    jde nejnižším výstupem tělesa jako pramen. Hladina a výstup jako `nadrz`.
- **Měří se:** svět E52 (povrch 64 / blok) s dutinami 16 / 32 / 64 (musí dát stejné l/s). Pro informaci celý běh při
  16 / 32 / 64.
  - průsak vs. pramen (l/s)
  - počty těles podle režimu
  - čas, paměť
  - vodní bilance každého tělesa: přítok = průsak + výtok (+ plnění u uzavřených)
- **Výstup:** `shots/test_podzemi55.txt`, `shots/podzemi52/funkce_auto_*.json`, snímek `55_prameny_prusak.png`
  (mapa: dno propustné / nepropustné, výstupy pramenů, průsak).
- **Hypotéza:** část vody, která se v E52 celá ztratila v průsaku, vyteče prameny tam, kde je pod vrstvou žula nebo jíl.
  Výsledek zůstane nezávislý na rozlišení, protože dno je funkce na řídicí mřížce.

### E55 výsledky (2026-11-19 ~02:56, `tools/test_podzemi55.gd` → `shots/test_podzemi55.txt`, VŠE OK)
Režim `p52_rezim=auto`, práh `p55_perm_dno` 0,05. Svět E52, povrch 64 / blok.

| dutiny / blok | průsak | výtok pramenem | bilance |
|---|---|---|---|
| 16 | 0,378 l/s | 2,484 l/s | 2e-15 |
| 32 | 0,377 l/s | 2,485 l/s | 2e-15 |
| 64 | 0,377 l/s | 2,485 l/s | 2e-15 |
| E52 `nadrz` (pro srovnání) | 2,86 | 0 | |

- Tělesa: 1 `smes` (propustné dno 13,2 %) a 2 `preliv`.
- Nezávislé na rozlišení: rozdíl 0,3 %.
- Paměť špička 287 MB. Podzemí 5,1–5,6 s (stavba ~3,6 s + řešení 1,2–1,6 s). Lokální změna ~1,3 s.
- Celý běh při povrchu 32: přítok 2,04, průsak 0,38, výtok 1,66 l/s. Při 16: 2,52 / 0,38 / 2,13 l/s.
- Ukázkové testy (čočka, dutina, uzavřená čočka) dávají v `auto` totéž co `preliv`. Tři případy dna (nepropustné
  → preliv, tráva perm 0,25 → nadrz, půl na půl → smes, f 0,5, průsak 0,5 × plný) jsou OK.
- Snímek `shots/55_prameny_prusak.png` ukazuje mapu dna (hnědá = nepropustné, zelená = propustné, hvězda = výstup)
  a sloupce průsak / výtok pro 16, 32 a 64.
- **Odchylka od plánu:** průsak smíšeného dna = Σ plocha · perm · `leak` jen přes propustné dno, ne f · průsak `nadrz`.
  Průsak `nadrz` obsahuje i boky, takže by se dno započítalo dvakrát (první verze to dělala).
- **Negativa:**
  - Mapa dna má hrany po blocích, protože materiály vrstev jsou po blocích.
  - Výtok vychází jen na stěně ostrova („okraj“), žádný pramen na povrchu v tomto světě.
  - Smíšené dno počítá jen průsak dnem. Boční kontakty s propustnou horninou se ignorují.
  - Jediný práh 0,05, žádný přechodový pás.
  - První verze závisela na rozlišení (0,82 / 0,77 / 0,68), protože pásma dutin se nepárovala s pásmem pod nimi.
    Opraveno hledáním pásma, které obsahuje z těsně pod dnem.

## E54 klient / server: uložený tok, přepočet s ranným zastavením, dohnání nepozorovaného (plán, zapsáno před pokusem 2026-11-18 23:05; Jan 22:52–22:59)
- **Zásady (Jan):**
  1) Vesnice se počítá na klientu, sdílený svět výpravy na serveru. Proto levné a deterministické: žádné tiky, žádná
     náhoda mimo seed, stejné pořadí.
  2) Ustálený tok se spočítá jednou a uloží. Po změně se přepočítá jen od změny po proudu a skončí, jakmile tok sedí
     s uloženým stavem (`TOK.update`, E51b: fronta po proudu jen dokud se průtok mění).
  3) Dohnání: když hráč odhalí oblast nebo se vrátí tam, kde nikdo nebyl, efekt uplynulého času se spočítá naráz
     (plné tůně, odnesené buňky, nános) z uloženého toku a časů událostí. Mimo pozorování se nic nesimuluje.
- **Test** `./run.sh dohnani54` → `shots/test_dohnani54.txt`:
  - **Dohnání:** scénáře E51 tůň a koryto, 60 dní. Pozorovaná oblast (`run_until` po dnech) vs. nepozorovaná (jeden
    skok). Stav musí mít stejný otisk. Cena = počet událostí, ne tiků. Hladina tůně v čase z předpočítaných událostí
    plnění.
  - **Ranné zastavení:** 40 výkopů v korytech mapy perf 128². Přepočet v ms, přeplánované sloupce vs. délka cesty po proudu.
- **Body z GPT review:**
  - **Vodní bilance po každém přepočtu:** kontinuita v buňce (ain = src + src2 + Σ přítoků) a celková bilance
    (přítok = ztráty + okraj). Kontrola v testu, `tok.gd` beze změny, hashe zůstanou.
  - **Transport sedimentu:** E51 dnes odnesenou hmotu posílá celou do první tůně po proudu (`_carry`), jinak přes okraj.
    Chybí kapacita unosu a usazování cestou (koryto se zpomalí → nános). Jen zapsat jako další krok, Jan rozhodne.
  - **Vsak oddělit od kapacity / šířky koryta:** dnes `TOK._cell` bere ztrátu vsakem z perm materiálu (L.inf · perm)
    a šířka koryta je zvlášť (Manning b ~ √Q v E51, pravidlo ceil(Q/k) v E53). V E53 propustnost k určuje šířku i bez
    vsaku, takže by se to míchalo. Návrh: dvě různá pole v tabulce materiálu (`vsak` a `kap_bunky`). Zapsat, Jan
    rozhodne.

### E54 výsledky (2026-11-18 23:15, `./run.sh dohnani54` → `shots/test_dohnani54.txt`, VŠE OK)
- **Dohnání 60 dní:**
  - **Tůň:** po dnech 223 událostí za 546 ms. Jeden skok 223 událostí za 554 ms. Otisk stavu **shodný**
    `f83967a30e688676`. Eroze 7, nános 216, do tůně 0,53 m³. Vrstvy plnění tůně 2/2 jsou z událostí plnění, bez
    simulace.
  - **Koryto:** 511 událostí za 773 / 754 ms, otisk shodný `fca8f43966daedc9`.
  - Cena = jen události (5,2 M tiků po 1 s se nepočítá). Dohnání je tedy zadarmo už dnes: halda událostí s absolutními
    časy (E51).
- **Ranné zastavení** (40 výkopů v korytech 128²): přepočet průměr **2,6 ms**, medián 2,1, max 7,5. Přeplánuje se
  průměrně 90 sloupců (okno ± okraj + po proudu), cesta po proudu je průměrně 34 sloupců, mapa má 16 384.
- **Bilance po každém přepočtu:** kontinuita v buňce i celková bilance 0 (do 1e-9 l/s). Přítok 61,83 l/s = ztráty
  11,31 (vsak 0,84 + do podzemí 10,47) + okraj 50,52.
- **Negativa:**
  - Dohnání platí jen pro to, co je v haldě (eroze, nános, plnění tůní). Nové prameny nebo podzemní výtoky změněné
    mezitím jinde se samy nedoženou, potřebují vlastní událost.
  - Transport sedimentu je pořád zjednodušený: celá odnesená hmota jde do první tůně po proudu, bez usazování cestou.
  - Vsak a kapacita / šířka koryta zatím sdílí perm materiálu (E53 ceil(Q/k)). Rozdělení na dvě pole čeká na Jana.

## E53 plošný tok maticemi: celá pole naráz místo fronty po buňkách (plán, zapsáno před pokusem 2026-11-18 22:35; Jan 22:11–22:26)
- **Směr (Jan 22:26):** povrchová voda se nemá počítat po buňkách (fronty, procházky po proudu), ale průchody přes celé
  pole. Každý průchod mění všechny buňky naráz (Jacobi: čte jen předchozí stav). Samostatná studie `scripts/plosne53/`,
  `./run.sh plosne53`; srovnání s dnešním tokem (`voda/tok.gd`, priority-flood + D8 + fronta).
- **A) Mělká voda (Jan 22:11):** výška vody + průtoky po hranách buněk (virtuální trubky, jako Stam / „pipe model“ [34]),
  explicitní krok, všechna pole každý krok. Běží jen lokálně po změně hráče (okno + okraj), dokud se neustálí. Pak se
  uloží koryto a časy událostí jako dnes. Varianty: studený start (prázdno, tůně se musí naplnit) a teplý start (hladiny
  tůní z priority-flood). Měří se: ustálené průtoky vs. `tok.gd`, rychlost pro erozi vs. Manning (E51), kroky a čas do
  ustálení, paměť.
- **B) Vektorové pole jako funkce (Jan 22:14):** směr a síla toku na řídicí mřížce 0,5 m (vx, vy), mezi body
  bilineárně jako vrstvy. Rychlost z gradientu hladiny. Test: vzorkování na 16/32/64 buňkách na blok dá stejné pole;
  srovnání se směry D8 jemné mřížky.
- **C) Pravidlo rozlévání (Jan 22:18–22:24), bez simulace:**
  - Buňka vodu buď nese, nebo ne (žádné částečné plnění, hladina v buňce je jen vizuální).
  - Propustnost = kolik buňka přenese za jednotku času. Šířka toku = **ceil(přítok / propustnost)** celých buněk vedle
    sebe, pokud jsou volné. Přebytek jde do další volné buňky do strany, ne dopředu.
  - Málo volných buněk → přebytek se hromadí (stoupá hladina) nebo přeteče jinam.
  - Testy na malých vzorcích. Jan 22:23: přítok 4 do písku perm 0,5 → 8 buněk, na perm 0,25 → 16 buněk (pokud jsou
    volné), s menším místem hromadění / přeliv.
  - Zpětná vazba koryta (22:24): stejný průtok se v zahloubeném korytě soustředí (hlubší = víc na buňku → užší, rychlejší
    → víc eroze), dokud tvrdší materiál nezpomalí a tok se znovu rozšíří.
  - Vše jako průchody celým polem: rozlévání, směr z gradientu, eroze.
- **Měří se:** výsledky vs. `tok.gd` (koryta, průtoky, šířky), čas, paměť, počet průchodů do ustálení. Poznámka
  k paralelizaci: Jacobi průchody jdou rozdělit na vlákna / GPU compute shader, fronta priority-flood ne. Odhad přes numpy
  (vektorově) jako náhrada GPU.
- **Hypotéza:**
  - C je levné a dá Janovy šířky přesně.
  - A je v GDScriptu pomalé (tisíce kroků) a se studeným startem se tůně plní hodiny simulace → jen teplý start a lokálně.
  - B je nezávislé na rozlišení, ale rozmaže ostré koryto (≤ 0,5 m).
- **Výstup:** `shots/bench_plosne53.txt`, `shots/test_plosne53.txt`, snímky `53_*`.

### E53 výsledky (2026-11-18 23:15, `./run.sh plosne53`, mapa perf z E51 64², testy `shots/test_plosne53.txt`, měření `shots/bench_plosne53_n64.json`, `shots/bench_plosne53_numpy.json`)
- **C) pravidlo rozlévání, celé pole naráz** (`scripts/plosne53/rozliv.gd`), testy VŠE OK:
  - **Jan 22:23:** přítok 4 do písku k 0,5 → přesně **8 buněk** (všechny 0,5). Na k 0,25 → přesně **16 buněk**.
    Ustálí se za **67 průchodů**, odtok okrajem 4,000, 0,6 s v GDScriptu (50 × 41).
  - **Málo místa** (koryto 12 buněk mezi břehy +1, potřeba 16): přebytek se hromadí, hladina +1 buňka, voda přeteče
    přes břehy (151 mokrých buněk za břehy). Při α 0,5 (hlubší = víc na buňku) má koryto šířku 11 = ceil(4 / 0,375),
    ustálí se za 750 průchodů. Při α 0 šířka 10 a 502 průchodů.
  - **Zpětná vazba koryta** (hlína k 0,5 dvě buňky nad žulou, dál žula k 0,25 o stupeň níž). Epocha = ustálit tok
    od nuly, pak jeden průchod eroze (plná buňka v měkkém → o buňku níž). Ep0 šířka 8 / žula 16. Po prvním vyhloubení
    **6 / 16**: hlubší koryto nese 0,75 na buňku, užší, rychlejší. Na žule zůstává široké.
- **A) mělká voda (trubky)** `mvoda.gd`: **8 ms na krok** v GDScriptu (64²). Za 4000 kroků (200 s simulace) se
  neustálí ani studený, ani teplý start (tůně z priority-flood). Odtok 25 (studený) / 49 (teplý) z 61,8 l/s.
  Rychlost vůči Manningu z E51 na korytech: medián 0,65 ×, p10–p90 0,04–3,3 ×.
- **B) vektorové pole jako funkce na řídicí mřížce:** průtok řezem při vzorkování 1× / 2× / 4× (bilineárně) je
  **3,846 l/s pokaždé** (přesně ze toků na hranách 3,854). Pás toku se rozmaže jen 13,5 → 13,9 m. Nezávislost na
  rozlišení platí.
- **Srovnání s dnešním tokem na 64²:**
  - `tok.gd`: celý `route` 93 ms, lokální změna (výkop v korytě 15 l/s) 2,8 ms, 88 sloupců.
  - Rozlévání: 12–15 ms na průchod, studený i teplý start ani za 3000 průchodů (37–44 s) neustálené.
  - Mělká voda: lokální okno 25 × 25 = 625 buněk, 4000 kroků za 5 s, neustálená.
  - Paměť na buňku: rozlévání 213 B (float64; float32 ~105 B), mělká voda 65 B, tok.gd ~63 B + tůně.
- **Paralelizace:** každý průchod je Jacobi (čte jen minulý stav), takže jde rozdělit na pruhy pro vlákna nebo jako
  compute shader. Rozlévání je zapsané jako rozptyl (+=) a pro GPU by se muselo přepsat na sběr od sousedů. Fronta
  priority-flood v `tok.gd` je sekvenční.
  - numpy (vektorově, 1 jádro) na 64²: rozlévání 3,3 ms na průchod (GDScript 12–15), mělká voda 0,17 ms na krok
    (GDScript 8 → 47 ×).
  - Na 256² 28,6 / 2,1 ms, na 1024² 646 / 65 ms.
  - Vlákna nebo GPU zrychlí jeden průchod, ale počet průchodů do ustálení (stovky až tisíce) zůstává.
- **Negativa:**
  - Na skutečném terénu (celé buňky, schody, ploché úseky, jámy) se rozlévání ani mělká voda za 3000 průchodů /
    4000 kroků **neustálí**. Tůně se plní fyzicky a pakety na rovinách kmitají (rozlévání zbývá hromadit 9 l/s).
  - Mokré buňky nesedí s `tok.gd` (Jaccard 0,13–0,16). Pravidlo dělá široké pásy (15 l/s při k 2 → 8 buněk), tok.gd
    má stopu D8 o šířce 1. Nejde tedy o chybu, je to jiné pravidlo.
  - Zpětná vazba funguje jen s ustálením toku od nuly v každé epoše (teplý start drží starou šířku). Pokus
    o „smršťování“ okraje pásu kmital a je vyřazený. Druhá a další epocha dělá schody a jámy (vyhloubení po celých
    buňkách), tok se neustálí a šířka zase roste.
  - Lokální přepočet po změně trvá u obou maticových metod sekundy, `tok.gd` 2,8 ms.
  - Rychlost z mělké vody se od Manningu liší o řád v obou směrech (mělká voda na schodech).
- **Doporučení (Jan rozhodne):**
  - Celá pole naráz se vyplatí jen tam, kde se ustálí za málo průchodů: rozlévání na hladkém svahu (67 průchodů)
    a vektorové pole jako funkce (B).
  - Pro koryta a tůně na herní mapě zůstat u fronty (`tok.gd`, ms). Šířku podle pravidla ceil(Q / k) dopočítat nad
    hotovou stopou D8 jako příčný průchod.
  - Mělkou vodu jen jako vizuál (GPU), ne jako zdroj stavu.

## E52 podzemní voda: srovnání variant (plán, zapsáno před pokusem 2026-11-18 21:55; Jan 21:14–21:31)
- **Co:** samostatná studie `scripts/podzemi52/`, `./run.sh podzemi52`. Svět svet64 (8 × 8 bloků po 64 buňkách) se vygeneruje
  jednou do cache (`.cache52/`, jemné buňky + záznamy bloků hm_f, bs) a každá varianta běží ve **vlastním procesu**, aby
  peak paměti (VmHWM) patřil jen jí. Kontroly: demo testy E47d (čočka → tůň 4 × 4, dutina = jezero, uzavřená čočka)
  pro každou variantu.
- **Varianty** (všechny se zapojí do `tok.gd` stejným rozhraním `entry` / `solve`, tok si vybere `ctx.impl`):
  1) **slovník** = dnešní `voda/podzemi.gd` na 64/blok (základ, E50: 129 s, 3,4 GB)
  2) **pole**: stejný algoritmus BFS, ale plochá pole (stav/štítek u8, vzdálenost u16, fronta i32, objem po z), plné
     rozlišení; těleso omezené na dosah do hloubky vstupu (buňky nejvýš `p52_hloubka_m` pod povrchem sloupce)
  3) **hrubá mřížka 32/blok** (Jan 21:14: podzemí smí být hrubší → nový výchozí `s64_ug_n` = 32), povrchová voda dál
     64/blok; sloupce se mezi mřížkami převádějí (vstup tůně → hrubý sloupec, výtok → jemný sloupec). Algoritmus 1 i 2.
  4) **FUNKCE nad vrstvami (Janova hlavní):** hranice vrstev jsou už 2D matice (hm_f, bs[k] na řídicí mřížce 0,5 m).
     Každá propustná vrstva (+ půda a kůže hor podle stejných pravidel jako `geo_fn.material`) = intervaly [spodek, vršek]
     ve sloupci řídicí mřížky. Souvislé oblasti = intervaly sousedních sloupců s překryvem v z. Plní se od nejnižšího z
     (objem pórů po hladinách) do nejnižšího výstupu (výchoz na povrch, stěna ostrova, tůň). Hladina = další 2D funkce na
     řídicí mřížce; buňky ji jen vzorkují jako horniny → nezávislé na rozlišení. Dutiny a čočky zůstávají buňkové
     (zvláštní případ). Dva režimy: `nadrz` (jedna nádrž na celé těleso, stejná sémantika jako 1 → shoda) a `preliv`
     (plnění a přelévání pánví od vstupu, Janův popis; průsak jen ze zaplavené části).
  5) volitelně Darcy: relaxace hladiny ve 2D vrstvě (rozdělení výtoku mezi víc výstupů); 3D jen pokud zbude čas.
- **Měří se pro každou variantu:** peak paměti, čas celého světa, čas jedné lokální změny (vykopání sloupce nad tělesem →
  přepočet podzemí), výtoky (stěna / prameny z podzemí / průsak v l/s), shoda se základem (přítok, průsak, výstup, hladina).
- **Nezávislost na rozlišení:** pevné vstupy (stejná místa v metrech, stejný přítok) řešené na 16/32/64 buňkách na blok:
  varianta 4 musí dát stejné výtoky, buňkové varianty pro srovnání.
- **Vodopád v metrech:** pravidlo `vodopad_m` se měří jako spád na vodorovné vzdálenosti `vodopad_dx_m` po proudu
  (ne na jednu buňku). Výchozí 0,5 m = jedna buňka řídicí mřížky → staré testy beze změny; na 0,125 m se spád měří přes
  4 buňky a souvislý spád se slije do jednoho vodopádu. Kontrola: počet vodopádů povrchu při 16/32/64 na blok.
- **Hypotéza:**
  - 2 ušetří paměť ~10 × (pár B na buňku místo slovníků), čas 2–3 ×.
  - 3 ~8 × méně buněk.
  - 4 je o řády rychlejší (128 × 128 sloupců × pár intervalů) a výtoky stejné na 16/32/64. Shoda s 1 v režimu `nadrz`
    blízká, rozdíly z těles (pně, kupole, žíly) a hranic buněk.
  - Základ 1 „rozpustí“ všechnu vodu v průsaku (E50), protože průsak počítá i suché buňky obřího tělesa. `preliv` ve 4
    to ukáže.
- **Výstup:** `shots/bench_podzemi52.txt` (tabulka), `shots/test_podzemi52.txt` (demo testy × varianty), 2–3 snímky `52_*`.

### E52 výsledky (2026-11-18 23:20, `./run.sh podzemi52`, tabulka `shots/bench_podzemi52.txt`, snímky `shots/52_pamet_cas.png`, `52_vystupy.png`, `52_vodopady.png`)
- **Demo testy E47d** (čočka → tůň, dutina = jezero, uzavřená čočka): VŠE OK pro slovník, pole, funkce `nadrz` i `preliv`.
- **Srovnání** (svět 8 × 8, povrch 64 / blok, přítok do podzemí 2,87 l/s):

  | varianta | peak paměti | podzemí (sestavení + řešení) | průsak / výtok l/s | lokální změna |
  |---|---|---|---|---|
  | 1 slovník 64 (základ) | 4002 MB | 3,1 + 155,5 s | 2,87 / 0 | 0,4 s |
  | 2 pole 64, limit 6 m | 575 MB | 2,9 + 36,5 s | 2,87 / 0 (shoda) | 0,4 s |
  | 2 pole 64, bez limitu | 588 MB | 3,7 + 56,9 s | 2,87 / 0 (shoda) | 0,4 s |
  | 3 pole 32 | 271 MB | 0,4 + 4,4 s (28 řešení) | **0,42** / 0 | 5,3 s |
  | 3 slovník 32 | 698 MB | 0,4 + 17,0 s | 0,42 / 0 (= pole 32) | 17,3 s |
  | 3 pole 16 | 269 MB | 0,06 + 0,7 s | 2,62 / 0 | 1,1 s |
  | **4 funkce `nadrz`** (dutiny 64) | **288 MB** | 4,2 + **0,6 s** | **2,86** / 0 | 1,1 s |
  | 4 funkce `preliv` | 288 MB | 4,0 + 4,7 s | 0 / **2,86** | 4,7 s |
  | 5a Darcy 2D (vrstva, SOR), K 1e-4 | 288 MB | 3,8 + 4,6 s | 2,85 průsak u vstupu, mound 9 m | 5,7 s |
  | 5a Darcy 2D, K 1e-2 | 288 MB | 4,0 + 7,0 s (3200 it.) | 2,69 průsak + 0,15 stěna (5 %) | 7,3 s |
  | 5b Darcy 3D, konečné objemy + CG, 16 / blok | 270 MB | CG 58 s (99 k neznámých, **1333 it.**) | viz negativa | 116 s |

- **Nezávislost na rozlišení (varianta 4):** dutiny 16 / 32 / 64 → průsak 2,86 / 2,86 / 2,86 l/s. Varianty 1–3
  se mezi 64 / 32 / 16 liší: 2,87 / 0,42 / 2,62.
- **Vodopád v metrech** (`vodopad_dx_m` 0,5): vodopádů 12 / 13 / 19 při 16 / 32 / 64 (staré pravidlo na buňku
  12 / 5 / 1). Okraj beze změny. Regrese beze změny: sled 46, v1, voda_b, `--b`, voda, svet8, test_podzemi, test_tun,
  E51 VŠE OK.
- **svet64:** výchozí podzemí je nově hrubá mřížka `s64_ug_n` 32 s `s64_ug_alg` pole (Jan 21:14). Celý svet64 jsem
  znovu nespustil. Odpovídá řádku „pole 32“.
- **Negativa:**
  - **Hrubá mřížka 32 nesedí se základem.** Průsak 0,42 místo 2,87 l/s, zbytek teče do uzavřených těles, která se plní.
    Slovník 32 dává totéž, takže to dělá rozlišení, ne algoritmus. Tenké propustné vrstvy se v hrubých buňkách spojí
    nebo rozpadnou. Mezi 16 a 32 je to nemonotónní.
  - Lokální změna na 32 trvá 5,3 s: přepočte se všech 28 těles, cache se zneplatní příliš široce.
  - `preliv` mění smysl výsledku (voda vyteče výstupem místo průsaku). Jan rozhodne, která sémantika platí.
  - Darcy 2D: s malým K vytvoří kupu 9 m a téměř všechno prosákne u vstupu. Výsledek silně závisí na K.
  - **Darcy 3D** (Jan 22:40: K z tabulky, harmonický průměr stěn, ΣQ = 0, CG, pevná výška na vstupu a na výchozech):
    - CG konverguje: 1333 iterací do rel. 1e-6, 44 ms na iteraci v GDScriptu.
    - Pevná výška = nadmořská výška na **všech** výchozech ale protéká tělesem mezi výchozy (vysoké výchozy vodu
      dodávají, nízké odebírají): 85 m³/s oběhu proti 3,6 l/s ze vstupu, bilance −20 %.
    - Chybí podmínka průsakové plochy (výchoz jen pro odtok, přítok vypnout a řešit znovu). Každé další řešení by
      stálo dalších ~60 s.
    - Na 32 / blok (800 k neznámých) jsem běh ukončil: odhad ~0,35 s na iteraci, ~15 min na jedno řešení, 4 řešení
      na běh.
    - Přítok z pevné výšky (3,6 l/s) je řádově stejný jako odtok tůně z BFS (2,61 l/s).
- **Doporučení (Jan rozhodne):**
  - Varianta 4 `nadrz` jako výchozí podzemí: 14 × méně paměti než základ, řešení 0,6 s, shoda 99,7 %, nezávislá na
    rozlišení.
  - Rozdělení odtoku mezi víc výstupů řešit Darcy 2D nad vrstvou (sekundy), ne 3D v GDScriptu.
  - Darcy 3D jen s podmínkou průsakové plochy a v nativním kódu nebo na GPU.
  - Hrubou mřížku 32 pro buňkové podzemí nedoporučuji, protože mění výsledek.

## E51 mechanika toku: eroze a usazování událostmi (plán, zapsáno před pokusem 2026-11-18 21:10; Jan 20:18–20:37, schváleno 20:23)
- **Co:** samostatná malá studie (`scripts/eroze51/`, `./run.sh eroze51`) nad tokem E47c (`voda/tok.gd`).
  - **Odpočet:** každý materiál má citlivost na erozi = **kolik m³ vody musí přes buňku protéct, než ji odnese**
    (odpočet událostí, žádné tiky). Vykopání nebo položení buňky odpočet vynuluje.
  - **Rozhodnutí podle rychlosti:** rychlost proudu rozhoduje mezi erozí a usazováním. Ve stojaté vodě (tůň) se materiál usazuje.
- **Hydraulika (zjednodušená, ne CFD):**
  - **Koryto:** Manningova rovnice [31] pro široké obdélníkové koryto: šířka b = max(buňka, k_b · √Q), hloubka
    h = (n · Q / (b · √S))^(3/5), rychlost v = Q / (b · h). S je sklon k buňce po proudu, min. `e51_s_min`.
  - **Tůň:** v = Q_tůně / (hloubka · √plocha).
- **Pravidla podle rychlosti** (prahy v m/s a objemy v m³ jako DATA ve sdílené tabulce `sdilene/materialy_voda.json`,
  nová pole `ero_v`, `ero_vol`, `sed_v`, inspirace Hjulströmův diagram [32]):
  - **Eroze:** v ≥ ero_v vrchní buňky → odpočet R klesá rychlostí Q (m³/s), volitelně × (v/ero_v)^k (`e51_k`, výchozí 0
    = čistě objem podle Jana). R = 0 → buňka odnesena: sloupec −1, nový vrch dostane plný odpočet. Objem odnesené
    pevné hmoty (1 − por) jde jako nános do první tůně po proudu, jinak přes okraj ostrova do mlhy (počítá se).
  - **Usazování:** sloupec tůně s v < sed_v nánosu (`e51_nanos`) sbírá usazeninu rychlostí
    c0 · Q_tůně / počet sloupců (+ nános z eroze nad tůní). Plná buňka (objem buňky · (1 − por)) → sloupec +1 (nános).
  - Mezi prahy se nic neděje (transport).
- **Fronta:** jedna globální halda událostí (čas, buňka, generace; zastaralé položky se přeskočí podle generace).
  - Položku mají jen sloupce s tekoucí nebo stojatou vodou.
  - Změna (odnesení, nános, kopání hráče) → `TOK.update` (lokálně po proudu, E47c). Dotčeným sloupcům se dopočítá
    postup starou rychlostí do „teď“ a naplánuje se nová událost.
- **Scénáře:**
  1) koryto v měkké vs. tvrdé hornině (dva souběžné pruhy, stejný pramen)
  2) tůň se postupně zanáší
  3) kopání hráče vynuluje odpočet (test s přesným časem)
  4) protržení hráze z písku změní tok po proudu (tůň zmizí → odtok do podzemí 19:48 zmizí → po proudu víc vody)
  5) výkon: velikost fronty, události/s, čas přepočtu, syntetická fronta 1 M položek
- **Hypotéza:**
  - V měkkém pruhu se koryto zahloubí o metry za týdny, v tvrdém skoro nic.
  - Tůň se zanese za měsíce a zmizí.
  - Událost ~1 ms (malá mřížka, přepočet okna). Halda 1 M: push + pop ≈ jednotky s v GDScriptu.
- **Výstup:**
  - `shots/51_*.png` (2–3 nejlepší)
  - `shots/bench_eroze51.txt`
  - `shots/test_eroze51.txt` (VŠE OK)

### E51 výsledky (2026-11-18 ~21:35, `shots/bench_eroze51.txt`, `shots/test_eroze51.txt`, `./run.sh eroze51`)
- **Testy VŠE OK:**
  - A: odpočet hlíny 1500 m³ / 4,98 l/s = 301 447 s přesně
  - B: kopání v 48 h vynuluje R (zbývalo 644 → 1500 m³, přeplánováno 86 sloupců)
  - C: položení hlíny → plný odpočet
  - D: determinismus 2×
  - E: protržení zvýší průtok po proudu 2,43 → 2,83 l/s
  - F: halda 1 M v pořadí
- **Koryto (60 dní, pramen 5 l/s):** měkký pruh (hlína na písku) se zahloubil v průměru o 6,2 m (max 7,5 m, až na žulu),
  tvrdý jen o 0,5 m (odnesla se jen 1 buňka hlíny, žula drží). 511 událostí, 296 událostí/s, přepočet medián 3,4 ms,
  přeplánováno 75 sloupců na událost. Z odnesené hmoty 2,6 m³ do tůní, 38 m³ přes okraj do mlhy. Snímek `51_koryto.png`.
- **Tůň (přítok 2 l/s, c0 0,002):** 27,9 m³ (129 sloupců, 2 m hluboká), polovina zanesená za 30 dní, < 5 % za 50 dní.
  223 událostí (216 nánosů), přepočet medián 2,7 ms. Snímek `51_tun.png`.
- **Písková hráz (přítok 3 l/s):** koruna 18 → 11 buněk za 30 dní, tůň 11,3 m³ pod 5 % za 27,5 dne. Odtok do podzemí
  0,44 → 0,01 l/s, po proudu 2,43 → 2,83 l/s. Největší přeplánování 290 sloupců. Snímek `51_hraz.png`.
- **Výkon 128 × 128 × 48, 16 pramenů:** start 0,62 s; 2 971 mokrých sloupců = 2 893 živých položek, fronta max 14 113.
  Jen **5 událostí/s**: přepočet medián 229 ms (max 0,5 s), průměrně 313 přeplánovaných sloupců (max 4 009).
- **Halda 1 M (GDScript):** push 0,33 µs/položka, pop + push v ustáleném stavu 2,6 µs, pop 3,1 µs, ~15 MB. Fronta tedy
  není úzké hrdlo.
- **Úprava během pokusu:** sloupec se stejným režimem a rychlostmi si nechá svou položku (bez nové generace). Zastaralých
  položek je pak v korytu 5 463 místo 6 234 (fronta max 299 místo 314) a ve výkonu fronta max 14 113 místo 33 247.
- **Negativa:**
  - **TOK.update není lokální v ceně:** má globální průchody O(n) (porovnání zdrojů, pole „uvnitř“, pond_mask a ponds
    přes celou mřížku, `_apply_drains` až 4×). Na 128² to stojí ~200 ms na událost. To je první věc k optimalizaci
    (okno po proudu, inkrementální tůně) před větší mapou.
  - Rychlosti jsou se zvolenými čísly rychlé: měkké koryto je na žule za týdny, c0 0,002 je velmi kalná voda. Prahy
    `ero_v`/`ero_vol`/`sed_v` jsou odhad (inspirace Hjulström [32]), ne kalibrace.
  - Zastaralé položky pořád převažují nad událostmi zhruba 10 : 1 (každá událost přeplánuje celé okno po proudu).
  - V korytu se nic neusazuje (nános jen v tůních, mezi prahy je transport).
  - Ustálený tok: vypuštění tůně nedá přechodnou povodňovou vlnu.
  - Celočíselné výšky sloupců vyžadují průměrný sklon přes 4 buňky (`e51_s_len`), jinak sklon skáče 0 ↔ 1 buňka.
  - Pole `ero_*`/`sed_v` jsou jen u 12 základních materiálů; horniny 20+ (`horniny_voda.json`) je nemají a berou se
    jako tvrdé [6,0 m/s, 1e8 m³].
  - Kopie tabulky v prototypu (`godot-prototyp/data/materialy_voda.json`) se lišila už od 16:59 (load/cantilever),
    nesahal jsem na ni.
- **Regrese** (`tok.gd`: `update` navíc vrací `cells`) beze změny: sled 46 `00dc4dc614729194`, v1 `45f42cd597c0f8c9`, test_voda_b c `604e5080a046`, `--b` `e89b4b1dd59c`, test_voda `36236d38becf`, svet8 `f08f56000feb`, test_podzemi a test_tun VŠE OK.

### E51b lokální přepočet toku (Jan 22:09; 2026-11-18 ~22:20, `tools/bench_e51b.gd`, `voda/tok.gd`)
- **Co:** `TOK.update` už nemá průchody celou mřížkou.
  - Okno + okraj se zpracuje jen v obdélníku okna. Pomocná pole (`_ins`, `_done`, `_seen`) se znovu používají a nulují
    se jen zapsané buňky. Stará fill se ukládá jen pro obdélník.
  - Tůně (seznam jako `ponds(…, false)` a `pw`) se drží v cache (`_pk` buňka → tůň, `_pd`). Přepočítají se jen tůně u
    změněných buněk. Když buňka nepřešla mokrá ↔ suchá, přepočte se jen přítok, přeliv a dno bez BFS.
  - Odtoky tůní (`_apply_drains`) pamatují nenulové indexy `extra` / `src2` a porovnávají jen je. Nejbližší okraj
    k přelivu je v cache.
  - Porovnání pramenů je nativní (`src_new != st.src`).
- **Výsledek (128², mapa perf E51):**
  - 400 událostí: `TOK.update` průměr **230 → 9,1 ms**, medián **232 → 4,2 ms**.
  - Otisk stavu (hm, eff, fill, ain, to, pw, extra, src2, log událostí, podzemní výtoky) je **shodný** `6187d1c10aac6b46`.
  - V `test_eroze51` výkon **5 → 124 událostí/s** (přepočet průměr 210 → 6,7 ms, medián 3,8). Koryto 296 → 630 událostí/s.
  - `eroze51.json` je bajtově shodné, testy E51 VŠE OK.
- **Regrese beze změny:** sled 46 `00dc4dc614729194`, v1 `45f42cd597c0f8c9`, voda_b c `604e5080a046`, `--b` `e89b4b1dd59c`,
  voda `36236d38becf`, svet8 `f08f56000feb`, test_podzemi a test_tun VŠE OK.
- **Negativa:**
  - Max je pořád 40–100 ms: událost, která pošle změnu daleko po proudu přes velkou tůň (stovky sloupců), a přepočet těles
    podzemí v `_apply_drains` (ten je globální podle tělesa, viz E52).
  - `route()` (start) zůstává plný.
  - Cache tůní předpokládá, že `fill` / `hm` / `ain` mění jen `update` / `route`. Kdo je změní jinde, musí zavolat
    `pond_mask(st)`.

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

### E50 výsledky (2026-11-18 ~21:00, `shots/bench_svet64.txt`, `./run.sh svet64`)
- **Celkem generování 516 s (8,6 min)** na 1 jádře boxu (Xeon, 8 vCPU, GDScript 1 vlákno). Svět 512 × 512 × 256 =
  67 M buněk. Render je oddělený: GIF v Pythonu 3,1 s, izo v Godotu 1,7 s.
- **Časy fází** (čas na stěnu):

  | fáze | čas |
  |---|---|
  | hrubý svět celkem | 0,60 s |
  | – z toho eroze + řeky | 0,55 s |
  | – terén, počasí, biomy, dlaždice | 4 / 7 / 21 / 11 ms |
  | detail 64 bloků celkem | 354 s |
  | – navázání (Σ) | 5,6 s |
  | – vrstvy + vzorky (Σ) | 182 s |
  | – minerály (Σ) | 57 s |
  | – dutiny (Σ) | 109 s |
  | voda celkem | 161 s |
  | – mřížka | 3,2 s |
  | – prameny | 1,1 s |
  | – povrch (koryto + strže) | 13,9 s |
  | – podzemí navíc | 129 s |

- **Časy na blok** (min / medián / max):

  | část bloku | min | medián | max |
  |---|---|---|---|
  | celý blok | 2,8 s | 5,3 s | 10,4 s |
  | navázání | 72 ms | 83 ms | 148 ms |
  | vrstvy | 2,3 s | 2,7 s | 4,1 s |
  | minerály | 0,25 s | 0,66 s | 2,1 s |
  | dutiny (jen 30 bloků s dutinou) | 2,8 s | 3,4 s | 4,7 s |

  Medián bloku podle typu:
  - louka 3,2 s
  - prohlubeň 2,9 s
  - sopka 4,2 s
  - svah 6,4 s
  - hora vyzdvižená 7,2 s
  - kopec 7,4 s
  - hora zvrásněná 9,3 s
- **Paměť:**
  - RSS po hrubém světě 131 MB, po detailu 361 MB, po mřížce vody 425 MB, po podzemí 3,57 GB
  - **peak 4,02 GB** (VmHWM)
  - Godot static 1,97 GB
  - Podzemí je jedno propustné těleso u povrchu o **9,7 M buněk** ve slovnících BFS.
- **Hypotéza:**
  - 64 × buněk dalo jen **23 ×** času proti E49: E49 detail 15,4 s, blok 0,24 s → E50 5,3 s. Náklad na sloupec se rozloží.
  - Hrubý svět je stejný.
  - Detail 6 min je pod odhadem 10–20 min.
  - Podzemí je výrazně nad odhadem: 129 s a 3,4 GB.
  - Švy jemných buněk: povrch |Δ| 0,00 (uvnitř 0,35). Jiné buňky ve sloupci přes šev 2,79 % (uvnitř 2,58 %) → spojité
    funkce drží i ve 4 × jemnějším vzorkování.
- **Determinismus a regrese:**
  - hash jemných buněk `0c4c96e0a1888ae8` je stejný ve 3 bězích
  - prvních 3 bloků 2× stejně
  - minerály: cíl 136 448 buněk (× 64), schodek 1 792 (stejný hostitel chybí jako v E49 57/64)
  - dutiny 76 800 / 76 800
- **Varianta voda 32 na blok** (`--s64_voda_n=32`, `bench_svet64_v32.txt`):
  - voda 22,7 s (podzemí 16,7 s), peak 678 MB
  - 5 vodopádů, okraj 29,5 l/s, největší těleso 1,2 M buněk
- **Negativy:**
  1) **Podzemí** je hlavní náklad času i paměti. Těleso je celá propustná půda u povrchu (9,7 M buněk, Dictionary
     dist / par). 2,87 l/s z tůní se v jemných buňkách celé rozpustí v průsaku, výtok ze stěny je 0. V E47d to bylo
     2,06 l/s ze stěny. Model průsaku (počet stěn · perm) závisí na rozlišení i po přepočtu / f².
  2) **Vodopády:** 1 místo 14 (16/blok) a 5 (32/blok). Pravidlo „spád ≥ 1,5 m mezi sousedními buňkami“ závisí na
     rozlišení; spád se má měřit na vodorovnou vzdálenost v metrech.
  3) Jedna dlaždice prohlubně v horách má jiný vrch materiálu ostře po hranici bloku (hnědý čtverec v GIFu i v izo).
     Je to stejné v E49, pravidlo podle typu dlaždice.
  4) Krajní jemné buňky bloku interpolují řídicí body souseda, jen pokud už soused existuje (jinak se zrcadlí). Výsledek
     tedy závisí na pořadí (geo_fn to zaručuje jen při 16). Šev je měřitelně čistý (viz výše), ale není to bit po bitu
     nezávislé.
  5) Vsakování a validátor gen-v3 jsou jen pro 16 × 16 × 64, v E50 se nespouští. Strže jen mění výšku vodní mřížky,
     buňky se po nich znovu nevzorkují.
  6) Dlaždice E49 dutiny nemají. Kvůli měření dostal kopec, svah a hory jednu jeskyni o 40 základních buňkách
     (`s64_dutina*`).
  7) Box je sdílený: v běhu `v32` trval jeden blok 104 s místo 7,8 s (zátěž jiných procesů). Proto se uvádí medián.
- **Telefon (hrubý odhad, generování na klientu):**
  - Střední telefon (Snapdragon 7 Gen 3, GB6 1 jádro ≈ 1 140) je na 1 jádro asi 1,5–2 × pomalejší než box. GDScript
    na telefonu by tedy byl ~13–17 min a s podzemím ve 4 GB paměti by spadl.
  - **C#:** těsné numerické smyčky 10–50 × ([28] 30–58 × na čisté smyčce), Godot Dictionary skoro nic. Android C# je
    zatím experimentální [29]. Realisticky ~10 × při převodu hlavních smyček na pole.
  - **Vlákna:** navázání (83 ms/blok) musí jít v pořadí BFS. Vzorky, minerály a dutiny bloku čtou jen řídicí mřížku
    sebe a sousedů, takže jdou paralelně (WorkerThreadPool [30]). Na 4 velkých jádrech ~3 ×.
  - **Odhad C# + 4 vlákna:**
    - detail 354 s × 1,75 / 10 / 3 ≈ **20 s** pro 64 bloků, první blok ~1 s
    - hrubý svět < 0,1 s
    - voda povrch ~2–3 s
    - podzemí v dnešní podobě ~20 s a GB paměti → **na telefonu neprojde bez změny algoritmu**
  - **Optimalizovat napřed:**
    1) Podzemí: pole místo slovníků (PackedInt32 / bitmapy), těleso jen do hloubky vstupu, nebo podzemí na hrubší
       mřížce (32/blok: 17 s a 0,68 GB už v GDScriptu).
    2) Vzorkování: v každém sloupci spočítat hranice jednou a plnit úseky z mezi hranicemi, místo `material()` na
       každou z 1 M buněk (2,5 µs/buňka).
    3) Dutiny: růst z haldy místo průchodu celé fronty (O(cíl · fronta)).
    4) Minerály: jen buňky v dosahu R od středů místo třídění všech hostitelských buněk.
- **Otevřené pro Jana:**
  - Má podzemí/voda běžet v plném rozlišení buněk, nebo na hrubší vodní mřížce (32/blok)?
  - Má být pravidlo vodopádu v metrech na vzdálenost?

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

## E65 přesunuto do tezba-studie (2026-11-19 13:55, Jan)

Těžba a rozklad hornin jsou samostatná studie. Návrh E65 je teď **T01 (dříve E65)** v `../tezba-studie/` (`README.md`, `PROP.md`, `DENIK.md`, `ZDROJE.md` [1]–[28], tabulka v `data/horniny_tezba_navrh.json`).
Zdroje [45]–[72] níže v tomto souboru zůstávají jen jako zástupné číslo, aby se neposunulo číslování blueprint-studie.
