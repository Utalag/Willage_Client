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
