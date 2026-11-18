# Deník vývoje Willage (klient / terén)

Deník má tři bloky: **A. Použité směry**, **B. Zamítnuté směry** a **C. Návrhy optimalizací**. Všechny jsou členěné do stejných skupin podle toho, čeho se týkají. Optimalizační poznámky k hotovým směrům se píšou přímo k položce (Výkon / Optimalizace), nevyzkoušené návrhy do bloku C.
Každá položka obsahuje: **Směr** · **Zlepšení** · **Komplikace** · případně **Rozhodnutí** / **Další krok** a datum.
Stav u použitých směrů: ✅ rozhodnuto Janem · 🧪 ve zkoušce (zatím bez rozhodnutí).
Zdroje se uvádějí jen jako značky [n] podle `ZDROJE.md` dané studie.

Skupiny: 1 Prototyp a buildy · 2 Terén a tvar · 3 Rozlišení bloku · 4 Skála · 5 Tráva a vegetace · 6 Vzhled a textury · 7 Výkon

---

# A. Použité směry

## 1 Prototyp a buildy

### ✅ Hratelný prototyp ostrova v Godotu 4.7.2 (2026-11-17, noc · `godot-prototyp/`)
- **Směr:** krychlové buňky 1 × 1 × 0,5, blok 16 × 16 × 64, generátor typ + seed (FastNoiseLite), ortografická izometrická kamera.
- **Zlepšení:** vkládání bloků (zrcadlení, rotace, posun, strany), vegetace veg-v2, cesty A* (rampy, schody), kopání s inventářem, stavby z Blenderu, video demo.
- **Komplikace:** v exportu chyběly .glb a textury (opraveno přes `importer="keep"`).

### ✅ Buildy pro Windows a Linux (2026-11-17, noc · `build/`)
- **Zlepšení:** Jan si může prototyp pustit sám.
- **Komplikace:** Windows zip měl přes 25 MB, proto byl poslán jako 7z ve dvou částech; Windows build se na boxu nedá otestovat.

### ✅ Ladicí okno s posuvníky jako samostatný doplněk, na žádost Jana (2026-11-17 15:30 · `godot-prototyp/addons/dev_tuning/`, shot `34_ladici_okno.png`)
- **Směr:** Jan: „Připrav ladící okno pro ladění. S posuvníky.“ a „samostatný modul, který nepůjde do finální hry“. Parametry jsou Resource s `@export` (`TunableParams`). Hra je jen zapíše do registru `ParamRegistry` a o okně neví. Doplněk se načte jen s `-- --dev`, a jen když složka existuje.
- **Zlepšení:** F1 otevře okno se záložkami Povrch a Tráva a sbalitelnými sekcemi. Posuvníky mají české popisky. Uniformy se mění hned, parametry s přestavbou (⟳) se přestaví 0,4 s po poslední změně nebo tlačítkem Aplikovat. Má Reset na výchozí, Uložit a Načíst předvolbu (`user://presety/*.tres`). Ukazuje FPS, ms snímku, instance vegetace a trojúhelníky. Export složku vylučuje. Hra bez složky běží beze změny (ověřeno).
- **Komplikace:** objekty a lambdy uložené v `Engine` meta nebo ve statickém slovníku shazovaly Godot při ukončení. Registr proto drží jen slabé odkazy a v meta je jen cesta ke skriptu.

### 🧪 Prototyp rozdělený na uzly scény místo monolitu `main.gd`, na žádost Jana (2026-11-18 01:00 · `godot-prototyp/`, větev `refaktor-uzly`, shot `44_editor_uzly.png`)
- **Směr:** Jan: „vše vidím jen v kódu, ale nejsou tu žádné uzly“ a „hrozný monolit“. `main.tscn` má teď skutečné uzly, každý s vlastním skriptem: World (WorldEnvironment + Sun), Island (`@tool`), CameraRig (+ Camera3D), Placement, Buildings, Roads, Digging, WaterFlow, UI, DevPanel. Logika se jen přesunula, nepřepisovala. Uzly se propojují přes exportované `NodePath` a signály `hint_changed` a `cell_inspected`. Dema a měření jsou ve scéně `demo.tscn` (`scripts/demo/`). Přepínače `--demo`, `--*-shots`, `--*-bench`, `--res-test` a `--export-vectors` fungují dál, protože `main.tscn` na `demo.tscn` sám přesměruje.
- **Zlepšení:** `main.gd` se zmenšil z 1 326 řádků a 66 funkcí na 170 řádků a 8 funkcí, ostatní skripty uzlů mají 12–238 řádků. Island se v editoru vykreslí ve 3D pohledu (4 bloky za ~1,7 s). V Inspectoru jde zvolit generátor, startovní sloty, typy a seedy, náhled vypnout a přegenerovat. Kamera hry se dá zobrazit přes Preview.
- **Ověření:** demo s `--fixed-fps 30` vyšlo před i po refaktoru stejně: 9 z 27 snímků je pixelově shodných a u zbylých 18 se liší jen popisek časů „generování … ms · mesh … ms“ v panelu (nejvýš 0,04 % pixelů). Vektory včetně `delta_sample.json` jsou bajtově shodné. Výpisy demo, SELFTEST, validátorů a determinismu jsou stejné až na ms. Headless editor s čistou `.godot` proběhl bez chyb.
- **Komplikace:** aby šel ostrov generovat v editoru, mají knihovní skripty generátoru a vykreslení (`block*`, `mesher`, `mat`, `veg*`, `grass*`, `gen3/*`, `surface/*` …) nahoře `@tool`. U kopií z lozika-studie je to jediný rozdíl. Spuštění přes přesměrování (`-- --demo` bez scény) přidá pár snímků, takže animované shadery (mlha, vítr, voda) jsou v jiné fázi. Proto `shoot.sh` volá `res://demo.tscn` přímo.
- **Další krok:** Jan otestuje v editoru a rozhodne o sloučení větve `refaktor-uzly` do main.

## 2 Terén a tvar

### ✅ Relief v2.2: terasy (2026-11-17, noc)
- **Směr:** stupňovitý výškový profil + makro šum + detailní šum, podle videa JohnBrx (ez68sFkO6Qo).
- **Zlepšení:** hory a kopce už nejsou kopečky.
- **Komplikace:** při jemném rozlišení se strmé přechody teras rozpadají na drobné travnaté schůdky (návrh: strmé buňky převést na skálu).

### ✅ Posun výšky bloku o ±1 až 4 vrstvy (2026-11-17 13:02, rozhodnutí Jana)
- Celková výška bloku zůstává vždy 64 vrstev.
- Při posunu nahoru se dole přidají vrstvy dogenerované ze seedu a nahoře ubude vzduch.
- Při posunu dolů se spodní vrstvy odeberou a nahoře se doplní vzduch.
- Přínos: odpovídá tomu, jak už to dělá klient v prototypu. Backend podle toho opraví test B07-Tv2-04.
- Otevřené: sníh přibývající postupně od lz 49 místo ostré hranice (nespěchá).

### ✅ Napojování louky, písku a vody: duální mřížka, schváleno Janem 14:04 jen pro vykreslení povrchu, skála a útesy na buňkách (2026-11-17 13:30 · `napojeni-studie/`, přístup 2)
- **Směr:** Janova větev pro napojování terénu. Zobrazovací dlaždice jsou posunuté o půl buňky a roh dlaždice leží ve středu datové buňky (Oskar Stålberg, Townscaper [1][3][4]). Materiál dlaždice se počítá ze 4 rohů (marching squares) a výška se mezi středy buněk interpoluje. Data zůstávají celé buňky a vrstvy. Srovnáno s klasickou mřížkou na stejných 2 × 2 vzorcích 10 × 10 × 4 (louka, píščina, voda, pobřeží) se stejnými pohledy kamery.
- **Zlepšení:** pobřeží a okraje louky jsou plynulé křivky, vnitřní i vnější rohy jsou stejně kulaté. Mezi loukou a vodou sama vznikne pláž se svahem. Na hranicích vzorků nejsou švy: dlaždice čte 1 řadu buněk od souseda [22][23].
- **Komplikace:** osamělá buňka (tráva v písku, vršek ostrůvku) se zmenší na skvrnu a ztratí výšku. Velký výškový rozdíl dělá svah místo útesu. Výběr buňky pro kopání musí ukazovat datovou buňku. Mesh 4 vzorků trvá v GDScriptu 244 ms a má 13 440 trojúhelníků (s dělením 2 jen 68 ms a 3 520 trojúhelníků), přístup 1 má 5 ms a 1 736 trojúhelníků.
- **Další krok:** Jan vybírá. Doporučuji duální mřížku pro povrch louky, písku a vody, ale útesy a skálu nechat na buňkách (rozdíl do 2 vrstev = svah, víc = stěna). Splat počítat v shaderu.

### 🧪 Doplňky břehu: pěna, vlnky, mokrý písek, řídnutí trávy (2026-11-17 13:30 · `napojeni-studie/`)
- **Směr:** vzdálenostní pole k vodě z výškové mapy (chamfer) místo hloubkového bufferu [15][16]. Z pole vzniká pevný pás pěny, vlnky postupující k břehu a mokrý písek do 0,9 buňky a 0,35 m nad hladinou [18][19]. Tráva C v pásu 1,2 buňky od okraje louky řídne až na 15 %, je nižší a sušší [21].
- **Zlepšení:** funguje nad oběma přístupy a vykreslování to nezpomalí měřitelně (pole stojí asi 105 ms při stavbě).
- **Komplikace:** u klasické mřížky pěna kopíruje zuby po buňkách. Mokrý písek je nenápadný.
- **Pravidlo studie:** dorovnání stran nesmí zaplavit souš ani vysušit dno (souš je vždy nad hladinou, dno pod ní).

### ❌→B Samostatné buňky v duální mřížce: hybrid s kvádry (Jan 14:55: necháváme současnou duální mřížku, viz B) (2026-11-17 14:41 · `napojeni-studie/`, `dual_shape=3`, shots `31_napojeni_samostatne_*`)
- **Směr:** Jan 14:20: „Jde to udělat méně agresivní ty přechody?“ (osamělá buňka se smrskne a ztratí výšku). Srovnány 4 varianty duální mřížky a klasická mřížka na stejných pohledech: současná, posun izočáry k silnějšímu materiálu, plošina se zkosením a hybrid. Hybrid kreslí prvky do 2 buněk, které nejsou níž než okolí, jako kvádry s obrysem a schody od 2 vrstev jako svislé stěny. Zbytek zůstává duální.
- **Zlepšení:** osamělá buňka trávy v písku i ostrůvek ve vodě drží celou stopu i výšku. Útesy jsou stěny podle pravidla „skála a útesy na buňkách“ a velké plochy zůstanou hladké. Nejlepší ze 4 variant.
- **Komplikace:** síť má 29 840 trojúhelníků místo 13 440 a splat stojí 1,2 s místo 0,47 s v GDScriptu. Snímek softwarově 62–64 ms místo 38–41 ms. Kvádr v hladké louce působí trochu cize, pomůže částečné zkosení `hyb_bevel`.
- **Další krok:** Jan posoudí 31_*. Záloha je plošina + zkosení, pokud chce méně oblé přechody všude.

### ✅ Louka přímo u vody: travnatý břeh + bahno + slabší pěna, schváleno Janem 14:52 (rákos bude samostatná entita ve vrstvě vegetace, ne součást přechodu – Jan 14:52) (2026-11-17 14:41 · `napojeni-studie/`, `--layout=1`, shots `33_napojeni_louka_voda_*`)
- **Směr:** Jan 14:34: louka u vody bez písku. Nové vzorky: nízká louka (plochý břeh 0,15 m), louka o 1 a 2 vrstvy výš, travnatý jazyk a ostrůvek z jedné buňky ve vodě, v obou mřížkách.
- **Zlepšení:** dno nad hladinou u louky je travnaté a strmý svah hliněný místo písku. U vody leží skvrnitý pás bahna. Rákos roste v trsech jen u louky a pěna má 30 % síly pláže. Bez úprav vypadala louka u vody jako pláž. Cena: 6–13 ms stavby, 77–91 instancí na 4 vzorky, snímek v rámci šumu.
- **Komplikace:** břeh o 2 vrstvy je v duální mřížce svah, ne stěna (tu dá hybrid). Ostrůvek z 1 buňky se bez hybridu smrskne.

### ✅ Napojení louky, písku a vody zapojené do hlavního prototypu (2026-11-17 15:30 · `godot-prototyp/scripts/surface/`, záloha `cp14-pred-napojeni-1456.tgz`, shots `34_napojeni_*`)
- **Směr:** Jan: „Připrav implementaci všech změn do hlavního prototypu“. Studie `napojeni-studie/` a `trava-studie/` zůstávají samostatné. Duální mřížka [1][4] kreslí jen měkký povrch (louka, písek, dno). Rozdíl do 2 vrstev je svah, víc je stěna z kostek. Skála, útesy, kopání, stavby a cesty zůstávají na kostkách. Písek má vzhled 1 a detail 2 s pásy 0,75 / 1,1 a `mix_tufts` 0,18. Louka u vody má břeh, bahno a pěnu 0,3. Procedurální louka je ve variantě 3. Vzdálenostní pole [15] se počítají v okně bloku + 4 sloupce od sousedů, takže na hranicích bloků nejsou švy. Parametry jsou v `SurfaceParams` (`--surface.klic=`).
- **Zlepšení:** pobřeží jezírek je plynulé a přes hranice bloků bez švu. Kostková síť bloku je dokonce o něco rychlejší (40,5 → 32,3 ms). Data, vektory, rarita i delta jsou beze změny (`vectors/` ověřeno bajt po bajtu).
- **Komplikace:**
  - Prototyp neměl vodu. Přibyla jen vykreslovací hladina: měkký sloupec pod vrstvou 30 je dno a hladina leží na 14,85 m (poměr jako 0,85 m ve studii). Voda je tak jen v blocích posunutých dolů a ve vykopaných jamách. Kopání do louky pod 30 udělá jezírko.
  - Vložení bloku trvá 434–543 ms místo 81–114 ms (přestaví se i 8 sousedů). Kopání uprostřed bloku trvá 123 ms místo 41 ms. Celek plného ostrova trvá 301 ms místo 264 ms na snímek (softwarově).
  - V řezu je duální povrch vypnutý a náhled kandidáta je jen z kostek.
  - Louka drží světlou paletu prototypu, takže procedurální tón je jemnější než ve studii.
  - Prošlapání země a stín postavičky z `meadow_ground` přeneseny nejsou.
  - Rákos zatím není (bude samostatná entita vegetace).
- **Další krok:** Jan a backend potvrdí hladinu (vrstva 30, nebo jiná / vlastní materiál vody). Pak zrychlit vkládání (viz C2, C5).

### 🧪 Voda jako data v buňkách: propustnost materiálů, toky, rybníky, zdroje a kopání u vody (2026-11-17 16:05 · `voda-studie/`, shots `35_voda_*`)
- **Směr:** Jan 15:47: „Budeme muset materiálu přidat propustnost …“, voda musí být skutečná data (ne jen obraz – v prototypu se dalo chodit po vodě a kopat pod ní), 15:51: každá buňka má svůj objem, zdroje vody jako entity bloku. Hmotový buněčný automat na datových buňkách [4][14]: v každé buňce objem vody (vzduch pojme 1, materiál svou pórovitost), tik = zdroje → pád a vsak → do stran z kopie stavu → přetlak nahoru → odpar. Materiál má 3 čísla: propustnost, pórovitost, odpor povrchu [5][6][7][8]. Zdroje `top_flow`, `hillside_spring`, `underground_pocket` ze seedu bloku [11][12]. Průchodnost podle hloubky vody (0,05 m pomalé, 0,30 m neprůchozí) a bláta [1]. 6 scénářů (10 × 10 × 4, svah 11 × 12 × 6, prameny 10 × 10 × 5).
- **Zlepšení:** rybník nad jílem pod pískem, přeliv skalní pánve, pomalý průsak vápencovou hrází (od 19:18 je vápenec nepropustný a hráz drží, viz jedna tabulka níže), louka brzdí odtok (čelo vody řada 9 vs. 11 u písku v tiku 240, písek odvede zemí 4× víc). Kopání: příkop do břehu se zaplaví, průkop jílu pod rybníkem ho vypustí do chodby (neprůchozí 46 → 0). Prokopnutá kapsa vyvěrá šachtou. Deterministické (2 běhy = stejný kontrolní součet), bilance vody se měří každý tik (chyba ≤ 1,6·10⁻⁶).
- **Komplikace:** přetlak jen o 1 buňku za tik (žádné spojené nádoby, U-trubice) [2]; voda tenčí než `film` zůstane jako kaluž; potoky nemají setrvačnost; výchozí rychlosti jsou odhad (průsak vápencem je hodně pomalý – voda pod hrází až po ~200 tikách). Blok 16 × 16 × 64 stojí 4,6–4,8 ms na tik v GDScriptu.
- **Další krok:** Jan posoudí 35_*. Otevřené: voda jako vrstva na buňku v datech backendu (návrh v README), trvalost rybníků (odpar), zdroj deště, výměna vody mezi bloky. Nic z toho zatím není v `godot-prototyp`.

### ✅ Výnos kopání: vždy 1 blok materiálu + šance na nález (2026-11-17 17:53, rozhodnutí Jana)
- **Směr:** vykopaná buňka dá vždy jeden blok svého materiálu a navíc s určitou pravděpodobností minerál, poklad apod. (tabulka nálezů podle materiálu).
- **Další krok:** tabulky nálezů podle materiálu, šance podle hloubky a blízkosti ložiska, nález ze seedu buňky (aby se nedal „přehazovat“).

### 🧪 Ložiska a žíly ore-v0 s přesným cílovým souhrnem ze serveru (2026-11-17 18:33 · `lozika-studie/`, shots `37_lozika_*`) – nahrazuje gen-v3
- **Směr:** Jan 18:22: „Vytvoříme tedy simulaci ložisek a žil.“ Algoritmus ore-v0 od Willage-backend (semínka se zásobou, tvary čočka / sloj / žíla). Jan 18:24–18:25: server při vydání bloku určí souhrn rud (základ + bonus v %), klient rozmístí **přesně** tolik buněk každé rudy. Bitová shoda C# a GDScript už není potřeba. Když semínka nestačí, běží záložní stupně: další semínka → dorůst tělesa → celá výška → uvolněný hostitel → výslovný schodek.
- **Zlepšení:** ore-v0.2 (zásoby snížené na úroveň prototypu, strop serveru 5×, pořadí od nejvzácnějšího hostitele, ložiskový jíl vlastní ID 12): Cu 17,6 a Fe 24,2 buněk na blok (prototyp 16–23 a 25), rarita jako v prototypu. Naplnění 100 % do 5× běžného cíle. Stojí 0,8–0,9 ms na blok. Tvary čitelné: měď žíly, železo shluky, jíl sloje [1][2][3][6].
- **Komplikace:** žíla jako náhodná procházka působí jako trubková mříž. Kód růstu a záložních stupňů je teď základ gen-v3.
- **Další krok:** žádný samostatný, nahrazuje ho gen-v3 (Jan 18:45).

### 🧪 Jeskyně a vodní rezervoáry cave-v0 (2026-11-17 18:33–18:46 · `lozika-studie/`, shots `38_jeskyne_*`) – nahrazuje gen-v3
- **Směr:** Jan 18:33: „Přidej do generování země i vzduch jako jeskyně a vodní rezervoáry. Seznam zemin bude obsahovat i vodu a vzduch. Voda však musí splňovat podmínky, aby neodtekla.“ Jeskyně (sál, chodba, šachta, rezervoár) s přesným počtem buněk vzduchu, voda jako vrstva u16 v pánvích pod nejnižším únikem.
- **Zlepšení:** 13 vektorů přesně, zátěž 100 % (420 bloků), simulace voda-studie 400 tiků: drift 0, odtok 0. Kopání do rezervoáru vodu správně pustí do chodby.
- **Komplikace:** vápenec má ve voda-studii propustnost 0,10, takže rezervoár ve vápenci prosakuje (řešeno žulou/čedičem a pečetěním jílem). WVB1 má dvě různé jednotky vody (0..65535 a 1/4096).
- **Další krok:** žádný samostatný, maska jeskyní a kontrola vody jsou použité v gen-v3.

### 🧪 Generování bloku gen-v3: zásobník materiálů ze serveru + vsakování vody (2026-11-17 18:45–20:05 · `lozika-studie/`, shots `39_genv3_*_v3`)
- **Směr:** Jan 18:45–18:59: server vydá seřazený zásobník (materiál, počet, tvar a parametry; binární kódování a SHA-256 dohodnuté s Willage-backend), klient položky zpracuje v daném pořadí a sám neřadí. Rudy jsou položky (fáze B zrušena 18:56). Od 19:18 varianta 2 (níže): objem pod povrchem je neurčený, hlína je vrstva u povrchu a kámen zbytek. Od 19:19 body (a)–(e) níže. Tabulky tvarů a pravidla jsou v README studie.
- **Zlepšení (v3, 20:02):** 11 vektorů a 360 zátěžových bloků přesně, validátor OK, dva běhy stejné. Čistota vrstev kamene 0,93–0,96 (prototyp STRATA 0,91–0,96; v1 0,80–0,86, v2 0,80–0,83). Tečky kamene 1–10 na blok. Rozmístění 17–29 ms (prototyp 17–21 ms, v1 36–64, v2 75–104), vsakování 3,5–8,7 ms, kontrola 4,4–6,4 ms. Vsáknutá voda je v simulaci voda-studie stabilní (přesun ≤ 0,065 objemu, odtok 0). Odmítne se 3 × poškozený blok, 7 × neplatný zásobník a 4 chyby kontroly serveru.
- **Komplikace:** při L4 dosazení (kvůli přesnému počtu bez masky) může hlína skončit hluboko (louka 404: 83 buněk > 4 pod povrchem, jinak 0–17). Odhad vody podle okraje je konzervativní a u kopce a hory přesto občas něco odteče (27–73 objemů na 15 bloků). Jednotka vody ve WVB1 (65535 vs 4096) otevřená.
- **Další krok:** backend převezme změny smlouvy (host u pocket/vein, tvar stratum, hloubka lz po sloupcích, pravidlo objemu, přidělení vody, zadržená voda). L4 v rozšiřujících se pásmech hloubky. Přeneseno do prototypu 20:14 (položka níže).

### ✅ Jedna tabulka vlastností vody pro gen-v3 i voda-studii, vápenec nepropustný (2026-11-17 19:18 rozhodnutí Jana · `sdilene/materialy_voda.json`)
- **Směr:** jediný soubor (perm, por, res, ret, `perm_leak`, `perched_depth`) čtou gen-v3, cave-v0 i voda-studie; bez něj běh hlásí chybu. Vápenec perm 0, por 0.
- **Zlepšení:** v gen-v3 nic neprosakuje do vápence (dřív simulace přesunula 19–72 objemů do vápence); cave-v0 nemusí pečetit rezervoáry ve vápenci (zátěž hora 202: 272 → 0 pečetících buněk); scénář 3 voda-studie: hráz drží (v nádrži 73,7 v tiku 400, průsak 0).
- **Komplikace:** pomalý průsak vápencovou hrází zmizel; jde vrátit přepínačem na příkazové řádce. Krasové jeskyně se dělají tvarem chamber.

### ✅ gen-v3 varianta 2: kámen dostane zbytek, hlína jen vrstva u povrchu (2026-11-17 19:18 rozhodnutí Jana)
- **Směr:** pod povrchem je neurčený objem; hlína je položka `layer` v hloubce 1–4 pod vlastním povrchem sloupce; server dá kamenům zbytek, takže Σ položek bez hostitele = V − slupka přesně (`volume_mismatch`).
- **Zlepšení (v2, 19:30, 360 bloků):** žádné tečky hlíny v kameni (≤ 1,3 na blok, v1 0–6 % hlíny jako tečky); voda se lépe vsákne na horách, protože hlína je souvislá slupka (hora 1000: 0,8 → 106 objemů).
- **Komplikace:** kámen přes BFS hromady byl pomalý (75–104 ms) a vrstvy nečisté (0,80–0,83); vyřešeno vrstvami stratum (e).

### 🧪 gen-v3 (a): voda podle nejnižšího okraje bloku, tok mezi bloky až v simulaci (2026-11-17 19:19 rozhodnutí Jana, varianta C)
- **Směr:** server dá `W = min(voda z receptu, přidělení)`, přidělení = ⌊buňky v hloubce 2..D pod nejnižším okrajem × 0,40 × podíl hlíny a písku × 0,4⌋. Každý blok je stabilní sám o sobě. Tok mezi bloky není implementovaný (jen popsaný v README): až v simulaci voda-studie po načtení sousedů.
- **Zlepšení (ablace 21 bloků):** odtok při vodě ×5 z 418,6 na 1,1 objemu na blok, při ×1 z 5,6 na 0. Vektory ×5 a ×20 bez odtoku.
- **Komplikace:** bezpečnost 0,8 odhad přestřelila (louka 404: 489 proti ~288 kapacity), proto 0,4; u kopce a hory zbývá malý odtok. Přesné by bylo spočítat kapacitu na serveru stejně jako klient (4–9 ms).

### 🧪 gen-v3 (b): zadržená voda nad jílem a v písku nad hladinou (2026-11-17 19:19)
- **Směr:** sloupec `ret` v tabulce (hlína a tráva 0,15, písek 0,05). Písek nad hladinou drží `ret`; hlína drží `ret`, je-li do 2 buněk pod ní jíl. Simulace voda-studie: voda ≤ `ret` se nehýbe.
- **Zlepšení:** 8–55 (průměr 25) objemů na blok zůstane nad hladinou, jak je u polní kapacity běžné; odtok ×1 1,5 → 0. V simulaci stabilní; bez `ret` v simulaci by stekla (louka 101: 14,8 objemu, piscina 4504: 52,4).
- **Komplikace:** voda-studie se tím mírně změnila (scénář 1: v zemi 21,7 místo 19,1, odtok 70,2 místo 73,7). Vsakování +1,6 ms, kontrola +1,2 ms.

### 🧪 gen-v3 (c): rudy i uvnitř kamene (2026-11-17 19:19)
- **Směr:** parametr `host` u pocket a vein: měď roste jen v žule, železo jen v čediči a přepíše je; hostitel musí být v zásobníku dřív, jeho výsledný počet = vydáno − rudy.
- **Zlepšení:** rudy v kameni 47 % → 63 % buněk (aspoň 4 ze 6 sousedů kámen); odtok ×1 5,3 → 0, protože rudy už neubírají propustný objem u povrchu; čistota vrstev beze změny (0,946).
- **Komplikace:** smlouva se mění (pocket má 4 parametry, vein 6) a server musí hlídat rudy ≤ hostitel.

### 🧪 gen-v3 (d): kontrola Σ počtů na serveru při vydání (2026-11-17 19:19)
- **Směr:** `check_stack` vrátí `world.summary_over_volume` (Σ > V − slupka), `summary_under_volume`, `summary_host_overflow`, `water_over_rim_allotment`.
- **Zlepšení:** všechny 4 negativní testy odmítnuty se správným kódem, platné zásobníky ve vektorech i zátěži bez chyby.

### 🧪 gen-v3 (e): rychlost: velké kameny po sloupcích, vsakování jen propustnou oblastí, kontrola v jednom průchodu (2026-11-17 19:19)
- **Směr:** tvar stratum (výška vrstvy ze šumu, přesný počet přes seřazení podle klíče), oblast vsakování = propustné buňky spojené s povrchem, kontrola jedna smyčka + BFS jen z mokrých buněk.
- **Zlepšení:** rozmístění 93,2 → 22,3 ms (ablace), čistota 0,809 → 0,946, tečky 4,4 → 2,6; vsakování 13–47 → 3,5–8,7 ms; kontrola 17–22 → 4,4–6,4 ms (zátěž v2 vs. v3).

### 🧪 gen-v3 v hlavním prototypu, výchozí generátor podzemí (2026-11-17 20:14–20:30 · `godot-prototyp/scripts/gen3/`, shots `41_genv3_proto_*`)
- **Směr:** Jan 20:14: „Aplikuje to na prototip.“ Tvar povrchu, napojení stran, posun výšky a slupka zůstávají z prototypu; prototyp vyplní sloupce bez šumových rud, zástupce serveru z toho spočítá souhrn, vydá seřazený zásobník (bajty + SHA-256) a vodu podle nejnižšího okraje, klient gen-v3-study-4 rozmístí vrstvy, jeskyně, kameny stratum, rudy v hostiteli a vodu se zadržením. Sdílená tabulka `sdilene/materialy_voda.json` (kopie v `data/` pro export). Nový materiál ložiskový jíl 12. Starý generátor zůstává `--gen=proto`. Proti studii jediný rozdíl `SOIL_COLS`: hlína, písek a jíl jen ve sloupcích, kde má prototyp nahoře půdu (holý kámen a sníh hory zůstanou bez hlíny). Volná voda z dat (jeskyně, jezírko) se kreslí průhlednými kvádry, mokrá půda tmavší; neodkrytá jeskyně se kreslí jako plná neutrální buňka a odkryje se prokopáním (povrch sloupce klesne na dno jeskyně, `Discovery` projde vzduch od oblohy). Hladina prototypu ve vrstvě 30 se u bloků gen-v3 nekreslí nad vnitřní souší, takže jáma v louce se už vizuálně nezaplaví.
- **Zlepšení:** bez filtru `SOIL_COLS` je 7/7 bloků bit po bitu stejných jako vektory studie (zásobník, materiály i voda). Validátor 40/40 samostatných bloků, 8/8 bloků ostrova (s dorovnáním stran) a 10/10 vektorů; determinismus 40/40 a dva exporty `gen_v3_vectors.json` stejné. `vectors.json` (proto) beze změny objemů, jen o materiál delší pole skóre a vah. Vložení bloku 423–596 ms proti 396–566 ms u proto (většinu stojí povrch a tráva), kopání stejně (střed 141 / 137 ms, hrana 271 / 276 ms). Snímky `41_genv3_proto_{ostrov,rez,rez_xray,jama,jeskyne_odkryta,jeskyne_odkryta_rez}.png`, srovnání `*_gen_proto.png`.
- **Komplikace:** generování bloku 42–48 ms proti 15–20 ms (navíc generátor 25,6 ms, validátor 4,5 ms, zástupce serveru 2,1 ms; povrch, vyplnění a vegetace jako dřív). Jezírko na ostrově nevzniklo (přidělení podle okraje nechá vsáknout všechno), takže snímek jezírka není. Voda se nesimuluje: po prokopání zůstane voda v otevřené jeskyni, kde byla, i když jeskyni otevře jáma z boku. Rarita se počítá z jiných počtů rud (prahy kalibrované na proto). Výpočet odkrytí 0,2 → 0,55 ms (hledání otevřených jeskyní).
- **Rozhodnutí (Jan 20:39):** voda v otevřené jeskyni vyteče simulací voda-studie (položka níže), validátor poběží vždy, rarita-v2 se překalibruje na gen-v3 (níže) a starý generátor zůstává, jak je – gen-v3 ho nejspíš nahradí („Nech to, tohle asi nahradí starý generátor“).

### 🧪 Tok vody po kopání: simulace voda-studie jen ve výřezu kolem prokopu, do ustálení (2026-11-17 20:39–21:10 · `godot-prototyp/scripts/gen3/water_flow.gd`, shots `42_tok_*`)
- **Směr:** Jan 20:39: „Ano“ – když kopání otevře jeskyni, voda vyteče simulací z voda-studie, událostně a jen místně. Kopnutí spustí tok, jen když vykopaná buňka nebo její 6 sousedů má pohyblivou vodu (nad zadržením `ret`, nebo volnou ve vzduchu). Výřez = BFS z vykopané buňky přes vzduch jeskyní a prohlubní (jáma: pod povrchem sousedního sloupce) a buňky s pohyblivou vodou, nejvýš ±7 sloupců a ±16 vrstev, + okraj 2, nahoru po nejvyšší povrch + 1. V něm běží `voda_sim.gd` beze změny (kopie z lozika-studie, parametry ze sdílené tabulky, výchozí rychlosti voda-studie, bez odparu, strany zavřené), nepropustné buňky mají kapacitu 0 jako v gen-v3. Ustálení: největší změna buňky < 5·10⁻⁵ za tik 5 tiků po sobě (strop 1 500). Zápis zpět do `Block.water` v celých jednotkách 1/4096 se zachováním součtu (zbytky podle desetinné části, při shodě nižší index). Ve hře se tok krokuje v `_process` po 6 ms na snímek a překresluje se jen voda; další kopnutí rozběhnutý tok nejdřív dopočítá, takže výsledek nezávisí na snímcích. Delta kopání nese `flow` (výřez, tiky, přesunuté jednotky, seznam změn vody `[buňka, staré, nové]`). Kontrola jako delta: součet vody bloku po toku = před tokem (vykopaná voda zvlášť v `water_old`), mimo výřez beze změny, voda jen ve vzduchu a propustných buňkách do kapacity, a dalších 30 tiků z výsledku pohne buňkou nejvýš o 0,015 (půl filmu).
- **Zlepšení:** časová řada `42_tok_{0_jama_pred,1_otevreno,2_tik06,3_tik20,4_ustaleno}{,_rez}.png`: jáma 3 × 3 vedle jeskyně s 4,05 buňky vody (kopec 404), stěna prokopaná shora až po hladinu, voda přeteče do jámy (3,87 buňky, ustáleno po 460 tikách). Výřez 9 × 10 × 18 = 1 620 buněk, simulace 278 ms (0,60 ms/tik), kopnutí + tok + kontrola 832 ms synchronně; ve hře 39 snímků (≈ 0,7 s). Kontrola delty OK 25/25 toků na 15 místech (4 recepty × 6 seedů) + 4/4 v písčině, determinismus 15/15 a stejný hash synchronně 2× i po 1, 3 a 7 tikách na snímek. Kopání v suchu (spouštěč nic nenajde) stojí jako dřív (136 ms).
- **Komplikace:** tok mezi bloky zatím ne (výřez končí na hraně bloku, strany zavřené). Výřez s nasyceným pískem je velký (medián 3 120, max 5 040 buněk, tok 136–349 ms, písčina 8 kopnutí dolů 2,4 s synchronně); poslední snímek toku ve hře trvá ~85 ms (konečný zápis, kontrola 30 tiků a překreslení kostek). Voda tenčí než film 0,03 zůstane ležet jako kaluž (vlastnost simulace). Položení bloku do vody vodu v buňce smaže (zapsáno v `water_old`), nevytlačí ji. Simulace je float32 v GDScriptu – backend by musel buď přijmout seznam změn z delty, nebo mít bit po bitu stejnou simulaci.
- **Další krok:** Jan posoudí 42_*; rozhodnout tok přes hranu bloku, vytlačení vody položeným blokem a zda backend tok počítá sám, nebo přebírá změny z delty.

### ✅ Validátor gen-v3 při každém vložení bloku (2026-11-17 20:39 rozhodnutí Jana)
- **Směr:** Jan 20:39: „vždy, 4,5 ms není mnoho“. Přepínač `gen3_proto.validate_on_build` zrušen, validátor běží po každém vygenerování / vložení a výsledek je v `b.gen3.valid`.
- **Zlepšení:** 8/8 bloků ostrova a 40/40 samostatných bloků OK; vektory 7/7 (s `SOIL_COLS` i bez).
- **Komplikace:** 4,1–6,0 ms navíc na vložení (z 400–600 ms).

### 🧪 Prahy rarity-v2 pro gen-v3 (2026-11-17 20:39 · `tools/rarity_calib_v3.gd`)
- **Směr:** Jan 20:39 „můžeš“. Stejný vzorek jako původní kalibrace (4 recepty × bonus {0; 0,12} × 30 seedů = 240 bloků), prahy pro gen-v3 tak, aby podíl tříd odpovídal gen proto s dosavadními prahy rarity-v2 (práh v polovině mezi sousedními skóre, na 0,1). Prahy jdou s generátorem (`Mat.thresholds()`, `--gen=proto` dál používá staré).
- **Zlepšení:** nové prahy `[0; 16,9; 18,7; 19,0; 22,7]` (dosud `[0; 15,9; 19,4; 26,1; 29,9]`), třídy 55/55/11/88/31 proti 54/58/9/88/31 u proto. Se starými prahy by gen-v3 neměl žádný epický ani legendární blok (37/93/110/0/0) – skóre gen-v3 je jen 13,0–25,7 (proto až přes 30). `vectors.json` beze změny, `gen_v3_vectors.json` má nově `material_rarity` a `rarityThresholdsV3`.
- **Komplikace:** pásmo „vzácná“ je úzké (18,7–19,0). Bonus 50 % u gen-v3 třídy nerozděluje tolik jako u proto: proto dává bonusovým blokům epickou nebo legendární v 119/120, gen-v3 jen v 72 % (86/120) a 28 % bloků bez bonusu (33/120) vyjde epických.
- **Další krok:** rozhodnout, jestli má raritu dál určovat podíl tříd, nebo spíš bonus (pak větší bonus rud v zásobníku, nebo raritu počítat ze souhrnu zásobníku na serveru).

## 3 Rozlišení bloku

### 🧪 Nastavitelné rozlišení, test 32 × 32 × 64 s buňkou 0,5³ (2026-11-17 11:50 · `--res-test`)
- **Směr:** generátor počítá ve fyzických jednotkách, rozlišení a velikost buňky jsou parametry (`--res-xy`, `--res-z`, `--cell-xy`, `--cell-z`).
- **Zlepšení:** výrazně jemnější tvar se stejným reliéfem; dá se ladit jakákoli kombinace.
- **Komplikace:** generování asi 4× pomalejší, mesh asi 3×, 2,3× víc trojúhelníků; vegetace v testu chybí; generátor a mesher jsou kopie, které se musí udržovat souběžně s originálem.

## 4 Skála

### ✅ C: souvislý povrch přes voxely, Surface Nets (2026-11-17 12:10 · `skala-studie/`)
- **Směr:** tvar vychází jen z propojení buněk: jedna buňka = kámen, shluk = balvan, souvislá vrstva = skála (Janovo pravidlo).
- **Zlepšení:** pravidlo platí bez výjimek a vypadá to nejvíc jako skála.
- **Komplikace:** hladký povrch nemá přesné hrany buněk, proto bude při kopání potřeba zvýraznit buňku a vybírat ji podle voxelu.
- **Rozhodnutí:** Jan zvolil cestu C.

### ✅ C jen u povrchu (2026-11-17 12:40 · `scripts/rock_volume.gd`)
- **Směr:** Janův nápad: počítat jen buňky sousedící s povrchem, vnitřek nechat v 3D poli. Sloupcové bitové masky najdou smíšená místa 2 × 2 × 2 a šum se počítá jen tam.
- **Zlepšení:** celý blok 32 × 32 × 64: 7 021 ms → 983 ms (93 tisíc trojúhelníků); šum se počítá v 9 % vzorků, u povrchu je 15 % plných buněk.
- **Komplikace:** zbytek času je režie GDScriptu (s plnou mezipamětí pořád 541 ms).

### ✅ Přepočet po chuncích 8³ při kopání (2026-11-17 12:40)
- **Směr:** úprava buňky zneplatní okolí ±2 buňky a přestaví jen dotčené chunky.
- **Zlepšení:** 29 ms na úpravu (max 52 ms), švy mezi chunky sedí.
- **Komplikace:** úprava u hranice chunku přestaví 3–4 chunky. První testovací místo leželo na úzké římse, kde díra nebyla vidět (opraveno výběrem rovné plochy).

### 🧪 Zjednodušená verze pro vzdálené bloky (LOD) (2026-11-17 12:40)
- **Směr:** 1 vzorek na buňku místo jemného vzorkování.
- **Zlepšení:** 4× méně trojúhelníků (22 762), 274 ms v GDScriptu, 9–15 ms v C#.

### Další krok pro skálu
Godot .NET (nebo GDExtension) a stavba chunků ve vlákně, napojení bloků na sousedy (teď mají hranu rovně uříznutou jako diorama), zvýraznění a výběr buňky pro kopání, travnaté schůdky na hranách teras.

## 5 Tráva a vegetace

### ✅ A: vrstvená „srst“, shell texturing (2026-11-17 12:18 · `trava-studie/`)
- **Směr:** vysoká tráva 0,15 a nízká 0,05 hrany buňky, 24 vrstev v jednom meshi, vítr ze šumu.
- **Zlepšení:** hustá jako koberec, z dálky velmi levná (48 trojúhelníků na plochu 10 × 10), v nízké trávě čistá učesaná stopa.
- **Komplikace:** z blízka drahá (každý pixel se kreslí 24×), z dálky je potřeba méně vrstev (8–12).
- **Rozhodnutí:** Jan: A jako základ.
- **Zpětná vazba (12:47):** Jan o A i B: „Tahle tráva vypadá jako mech.“ Z pohledu kamery a ve výškách 0,15 / 0,05 splývá v jemný zrnitý povrch. Proto vznikly zkoušky A2 a C níže.

### 🧪 A2: řidší „koberec“, shell texturing (2026-11-17 12:58 · `trava-studie/`, záhon A2)
- **Směr:** stejný shell jako A, ale méně vláken (15 a 20 na jednotku místo 34 a 46). Vlákna jsou tlustší a skoro válcová, 20 % míst zůstává prázdných a mezi nimi prosvítá tmavý podklad. Nastavuje se `carpet_*`.
- **Zlepšení:** čitelná vlákna jako vlas koberce nebo plyš, pořád 48 trojúhelníků a stejně levné jako A (~40 ms celek, softwarově). Rozhrnutí tvoří výraznou učesanou stopu.
- **Komplikace:** z dálky působí tmavě a zrnitě a víc jako koberec než tráva. Zblízka je drahé stejně jako A (fill-rate).

### ✅ C: trsy z prototypu jako hustá instancovaná tráva, schváleno Janem 13:05 pro louky (2026-11-17 12:58 · `trava-studie/`, záhon C)
- **Směr:** algoritmus B (instance MultiMesh, vítr, ohyb ze stopy), ale místo stébel se použijí trsy z veg-v2 [18] (trs trávy, 3 % suché trávy, kvítky). Hustota je 24 trsů na buňku ve vysoké a 50 v nízké trávě, prototyp veg-v2 má 0,45 trsu na buňku (53× a 110× víc). Výška trsů je 0,30 a 0,12 × hrana buňky.
- **Zlepšení:** jediná varianta, která z dálky i zblízka čte jako tráva nebo louka v kawaii stylu. Je nejlevnější: 3 738 instancí a 22,7 tisíce trojúhelníků (~30 ms celek i detail, softwarově) proti B se 72 500 instancemi. Rozhrnutí je ve vysoké trávě dobře vidět.
- **Komplikace:** stopa v nízké trávě je slabá. Mezi trsy prosvítá podklad, takže to není hustý koberec. Výšky 0,15 a 0,05 ze zadání musely jít nahoru, jinak trsy zase splývají v mech.
- **Další krok:** Jan vybere mezi A, A2 a C, případně kombinaci C nad A2 jako podkladem.

### ✅ Tráva C zapojená do hlavního prototypu (2026-11-17 13:40 · `godot-prototyp/`, záloha `cp13-pred-trava-C-1313.tgz`)
- **Směr:** Jan 13:05: „Aktuální stav můžeš aplikovat do hlavního modelu“, studie `trava-studie/` zůstává jako samostatná větev pro ladění vegetace. Kód varianty C (trsy, kvítky, shader, stopa) je přenesený do `godot-prototyp/` (`scripts/grass*.gd`, `grass_tuft.gdshader`). Tráva roste na každém travnatém povrchu mimo stavby a cesty. Vysoká a nízká tráva jsou ve skvrnách podle šumu ze seedu bloku, podíl vysoké podle receptu (louka 0,55 … písčina 0,15). Květiny a suchá tráva z dat vegetace používají stejný shader, takže sdílí vítr i stopu. Všechny výšky, hustoty, vítr a stopa jdou nastavit (`--grass.klic=hodnota`).
- **Zlepšení:** ostrov poprvé vypadá jako louka a ne jako zelená plocha s jednotlivými trsy. Data vegetace, rarita, vektory i delta zůstávají beze změny, je to jen vzhled klienta. Postavička trávu rozhrne a ta se vrátí (`shots/28_trava_C_pruchod*.png`).
- **Komplikace:**
  - Na plném ostrově (24 bloků) je přes 200 tisíc instancí a celek trval softwarově 588 ms na snímek proti 145 ms. Proto přibyla úroveň detailu (viz skupina 7) a s ní je to 240 ms.
  - Detail louky trvá 154 ms místo 66 ms. Ortografická kamera kreslí i bloky za sebou v zákrytu.
  - Stavba vegetace bloku zabere 14–17 ms místo 0,3 ms, což se projeví při vkládání bloku a kopání.
  - Stopa v nízké trávě je slabá stejně jako ve studii.
  - Okno stopy 32 × 32 jede jen za první postavičkou, další postavičky mimo okno trávu nerozhrnou.
  - Herní postavička v prototypu zatím není, testovací je jen v `grass_demo.gd`.
- **Další krok:** stopa pro víc postaviček (víc oken nebo jedna textura na blok). Hustota podle vzdálenosti i v detailu. Stavbu trsů přesunout do vlákna nebo C# spolu se skálou.

### ✅ Dráha kroků a vítr sdílené pro všechnu vegetaci (2026-11-17 12:30)
- **Směr:** textura s časem šlápnutí; tráva se rozhrne, 0,35 s zůstane položená a za 1,6 s se vrátí; každý druh má jen vlastní parametry.
- **Zlepšení:** procesor zatíží jen 0,2–0,6 ms na snímek a výsledek je deterministický; stopy můžou dělat i vesničané, zvířata a vozy.
- **Rozhodnutí:** Jan souhlasí, stejný princip i pro další vegetaci.

## 6 Vzhled a textury

### ✅ Kawaii toon vzhled s obrysy (2026-11-17, noc)
- **Zlepšení:** jednotný pastelový styl terénu, objektů i vegetace.
- **Komplikace:** stěny při otočení kamery černaly kvůli `step()` v toon shaderu (opraveno, video natočeno znovu).

### 🧪 Textury materiálů z Gemini (2026-11-17, noc / 11:40)
- **Směr:** 512 px na materiál, opakování na 4 jednotky, tedy 128 px na buňku (při 0,5³ 64 px na stranu buňky).
- **Zlepšení:** zrnitost z blízka.
- **Komplikace:** z dálky skoro neviditelné; první sada měla rámečky a měď vypadala jako železo (předěláno na v2).

### ✅ Písek s procedurálním zrnem a přechodové pásy jako samostatný materiál, schváleno Janem 14:27 (2026-11-17 14:40 · `napojeni-studie/`, shots `30_napojeni_mekkost_*`)
- **Směr:** Jan (14:14): písek je moc sytý a bez textury, takže hranice louka–písek–voda se slévají. Změny: šedobéžový písek, procedurální zrno a čeřiny v shaderu, u vody pás uježděného mokrého písku (0,75 buňky, šedší, čeřiny podél břehu) a před loukou pás písku prorostlého trávou (1,1 buňky, zelené skvrny a řídké nízké trsy). Všechno se dá přepnout (`sand_look`, `sand_detail`, `bands`, `band_*`, `mix_tufts`).
- **Zlepšení:** břeh se čte jako čára voda | mokrý písek | suchý písek a louka už nesplývá s pláží. Nejlépe vychází v duální mřížce.
- **Komplikace:** je potřeba 4. vzdálenostní pole (asi +25 ms při stavbě) a snímek je o 3–7 ms pomalejší (softwarově). U klasické mřížky pásy kopírují zuby po buňkách.
- **Další krok:** Jan potvrdí vzhled, pak to přenést do terénního shaderu prototypu.

### ✅ Procedurální zem louky pod trsy C, varianta 3 „sladěná“ (zem i trsy ze stejného šumu), schváleno Janem 14:52 (2026-11-17 14:40 · `trava-studie/proc.tscn`, shots `32_trava_procedural_*`)
- **Směr:** Jan: „Když máme procedurální písek, co zkusit i procedurálně tu trávu?“ Trsy C zůstávají, procedurální je zem pod nimi: méně sytá zelená, velké fleky (světlejší/tmavší/žlutější), suchá místa, svěží skvrny s jetelem, žíhání stébel po větru, zrno 22 na buňku jako u písku, světlejší stopa. Varianty 0 plochá / 1 jemná / 2 výrazná / 3 sladěná (trsy převezmou tón louky ze stejného šumu, `ground_match`). Parametry `pg_*`.
- **Zlepšení:** louka už není jednolitá, fleky a suchá místa jsou vidět z herní kamery i přes trsy. Ve variantě 3 jsou na suchém místě suché i trsy, takže zem a tráva drží pohromadě. Doporučená varianta 3.
- **Komplikace:** softwarově +1–2 ms v celku, +5–7 ms při zemi přes celou obrazovku, sladění trsů dalších 1–4 ms (šum ve vertex shaderu). Varianta 2 je na celý ostrov moc kontrastní.
- **Další krok:** Jan vybere variantu, pak přenést `meadow_proc` do terénního shaderu prototypu (trávu i písek jednou sadou).

### ✅ Pec: sloty, recepty, poznámkový blok a minihra (2026-11-17 17:37–17:49, rozhodnutí Jana)
- **Směr:** pec je daná stavba se sloty pro materiál, palivo a příměsi a s nastavením teploty. Výsledek se počítá z vlastností materiálů, takže se dá experimentovat se slitinami. Kdo experimentovat nechce, recept najde nebo koupí a recept vyplní sloty. Data o tavení a slitinách se doplní z veřejných zdrojů (Wikipedie) do ZDROJE.md.
- **Poznámkový blok (17:37):** u pece je blok na recepty. Hráč si zapisuje, co a jak zkusil, a z poznámek si sestaví vlastní recept.
- **Minihra (17:39):** tavení v peci je zároveň minihra.
- **Ochrana receptů (17:49):** každý hráč má ideální bod (např. přesnou teplotu nebo čas přidání) posunutý jinam uvnitř povoleného rozsahu, odvozený ze seedu hráče. Recepty se tak nedají jednoduše opsat.

### 🧪 Skrytí podzemí na bocích a řezech bloku (2026-11-17 20:05 · `godot-prototyp/`, shots `40_skryti_*`)
- **Směr:** Jan (19:50, přes Willage-backend): při pohledu na blok jsou na bocích a řezech vidět vrstvy zeminy. Pod povrchem se boky a řezy kreslí jednou neutrální texturou (výchozí hlína, volitelně skála), skutečný materiál až když hráč buňku odkope a stěna sousedí se vzduchem spojeným s povrchem (obloha nebo jáma). Chybějící soused (mlha, okraj ostrova) buňku neodkryje. Řez (PageDown) materiál neodkryje. Data buněk zůstávají stejná, mění se jen vykreslování. Přepínače `hide_undiscovered`, `xray`, `undiscovered_look`, `col_undiscovered` a `undiscovered_darken` jsou v `SurfaceParams` (CLI `--surface.xray=1`, ladicí okno).
- **Zlepšení:** bok ostrova a řez už neukazují ložiska ani vrstvy kamenů; ve vykopané jámě je skutečný materiál vidět (`shots/40_skryti_{bok,rez,jama,xray}.png`). Výpočet odkrytí 0,2 ms. Stavba sítě 53 ms bez skrytí a 60 ms se skrytím, vložení bloku 449 / 424 ms, kopání uprostřed 172 / 138 ms a u hrany 316 / 267 ms (rozdíl je v šumu a v sousedech slotu, skrytí samo o sobě nezpomaluje).
- **Komplikace:** klient má v paměti celé pole, upravený klient by mohl vidět do země – teď se to neřeší. Přirozené srázy otevřené k obloze ukazují skutečný materiál té buňky. Od 20:14 (gen-v3 v prototypu) má prototyp jeskyně: neodkrytá se kreslí jako plná neutrální buňka, prokopaná se odkryje průchodem vzduchem od oblohy (výpočet odkrytí 0,2 → 0,55 ms).
- **Další krok:** Jan vybere texturu skryté stěny (hlína / skála) a sílu ztmavení s hloubkou.

### 🧪 2D tileset s duální mřížkou a rohovou rampou (2026-11-17 21:10 · `tileset2d-studie/`, shots `43_tileset2d_*`)
- **Směr:** Jan 20:42: ukázat malý vzorek buněk ve 2D přes tilesety, tři materiály, dvojitá mřížka; listy vygenerovat z assetů v knihovně. Materiály jsou tráva, písek a hlína. Přístup je vrstvená duální mřížka (16 rohových dlaždic na materiál, priorita hlína < písek < tráva) [1][4][10], ne 81 kombinací. Izometrie 2:1 s horní plochou a sukní, pastel podle Janova Gemini renderu [8] (pixely z něj použité, JPEG alfa vyčištěná) vedle texturované varianty z Gemini v2 [7]. Jan 21:05–21:07: rohová rampa ze skici [11] – buňka se rozdělí na podmřížku 4 × 4, hladiny 1–4 jako skládané vrstvy stejných 16 dlaždic (ne 4⁴ = 256). Počet hladin je parametr (`levels`). Tvar hladiny je `shaped` nebo `full` (`shape=`): varianta „všechny tvarované“ proti „1 a 3 plné desky, 2 a 4 rampa“.
- **Zlepšení:** přechody tří materiálů v duální mřížce, srovnání stylů, náznak výšek sukní. Rampa ukazuje sestup 4 → 1 v jedné buňce (schody po 0,125 m), mírnější svah přes 3 buňky, srovnání se schody po celých buňkách (0,5 m) a srovnání tvaru hladin.
- **Komplikace:** čtvrtinová hladina je jen vykreslení – data buňky zůstávají 1 × 1 × 0,5 m. Na ostrově 8 × 8 bloků by naivní 4 × 4 ve všech buňkách dala asi 1 milion zemních dlaždic; zjemňovat se mají jen svažité buňky. Plné liché hladiny neurazí počet vrstev, jen lomení okraje.
- **Další krok:** Jan vybere iso vs. pohled shora, velikost dlaždice, vodu / výšku, a která varianta tvaru hladin je čitelnější.


### 🧪 2D tileset gemini2 z nových Gemini assetů (2026-11-17 21:48 · `tileset2d-studie/`, shots `43_tileset2d_*_gemini2.png`)
- **Směr:** Jan 21:28: třetí vzhled `gemini2` z `gemini/tileset2d/` [12]. Horní plochy se stáhnou na velikost dlaždice a promítnou na kosočtverec; sukně je z `bok-hlina` po ořezu oblohy a vodorovném zacyklení. Snímky s gemini2 jako hlavním vzhledem a trojité srovnání pastel / textura / gemini2.
- **Zlepšení:** švy horních ploch i boku po offset-blendu klesly na max. rozdíl zhruba 2–7 (předtím desítky až 180). Obrys a ret trávy jen na hranici materiálu nebo výšky — souvislá hlína už není v mřížce. Rovné přední stěny a vnější stěny rampy berou pruh z bok-hlina; mezery ve stupních rampy jsou menší.
- **Komplikace:** tráva má periodu 256 px (na mapě každé 2 dlaždice) a opakování trsů je pořád vidět; na hlíně a písku méně. Na lomeném pobřeží sukně ještě zuby (spojovací stěna jen na úplné odhalené hraně, ať netrčí do prázdna). Na trávě zůstává slabší mřížka z navazování dlaždic.
- **Další krok:** Jan posoudí, jestli je opakování trávy a zuby na pobřeží přijatelné, nebo chce jiný zdroj / větší rozmanitost.



## 7 Výkon

### 🧪 Úroveň detailu trávy podle přiblížení (2026-11-17 13:40 · `godot-prototyp/scripts/grass.gd`)
- **Směr:** trsy každého bloku jsou v bufferu MultiMesh po osminách (každý 8. trs každého sloupce). Při oddálení ortografické kamery se kreslí jen část (`visible_instance_count`, plná hustota do záběru 20 jednotek, minimum 1/8), kvítky vždy celé.
- **Zlepšení:** plný ostrov celkem 588 → 240 ms na snímek (softwarově), startovní ostrov 189 → 120 ms. Z dálky rozdíl vidět není, nic se nepřepočítává.
- **Komplikace:** v detailu nepomáhá, tam se kreslí vše včetně bloků v zákrytu.

### 🧪 Rychlá cesta pro rovnou louku a jednotné dlaždice (2026-11-17 15:30 · `godot-prototyp/scripts/surface/shore_fields.gd`, `grass.gd`)
- **Směr:** sloupec, kolem kterého je 3 × 3 rovné louky daleko od okraje, vezme výšku přímo ze schodu, bez vzorkování polí po trsech. Dlaždice se 4 stejnými rohy vrací váhy bez šumu (výsledek je stejný).
- **Zlepšení:** kopání 312 → 123 ms, vložení bloku 907 → 575 ms na blok, pole bloku 56 → 38 ms.
- **Komplikace:** žádná viditelná, platí jen pro vnitřek louky.

### 🧪 Horká smyčka v C# (2026-11-17 12:40 · `skala-studie/csharp_bench/`)
- **Zlepšení:** celý blok 65–120 ms, 1 chunk 2,8 ms, stejný výsledek jako GDScript.
- **Komplikace:** na boxu není Godot .NET, takže C# zatím neběží uvnitř hry.

---

# B. Zamítnuté směry

## 1 Prototyp a buildy
- **Jeden Windows zip jako příloha:** přes 25 MB, nahrazeno 7z ve dvou částech.
- **Editor staveb s pohyblivými díly (vodní kolo, hřídele, převody), 2026-11-17 17:40:** Jan: příliš složitá mechanika, zamítnuto. Stavby budou předem dané.

## 2 Terén a tvar
- **Hybrid s kvádry, posun izočáry a plošina se zkosením pro samostatné buňky (napojeni-studie, 14:41, zamítnuto Janem 14:55):** zůstává současná duální mřížka (`dual_shape=0`); samostatné buňky se slijí do flíčků a břehy jsou svahy. Varianty zůstávají ve studii jako volba.
- **Hory jako jednoduché kopečky (původní generátor):** Jan: příliš pravidelné.
- **Relief v2.1: nepravidelné eliptické vrcholy:** byl to krok správným směrem („mnohem lepší“), nahradily ho terasy v2.2. Zůstává dostupný přes `relief_version`.
- **Klasická mřížka pro povrch louky, písku a vody (napojeni-studie, přístup 1, 13:30, zamítnuto Janem 14:04 pro povrch):** přechod se řeší na hranách buněk. Silnější materiál přesahuje pásem do sousední buňky, princip Wang / blob dlaždic [8][10]. Je levná a čitelná, jenže břeh je zubatý a louka končí u vody útesem. Pro útesy a skálu zůstává.
- **Posun izočáry jako řešení samostatných buněk (napojeni-studie, 14:41):** osamělá buňka je větší, ale pořád plochá a bez výšky. Rovné hrany louky se posunou do písku. Nahrazeno hybridem.
- **Plošina + zkosení jako výchozí tvar duální mřížky (14:41):** drží výšku, ale celý terén je zase hranatý jako mřížka. Síť má 2,2× víc trojúhelníků. Zůstává jako `dual_shape=2` pro případ, že Jan chce méně oblé přechody všude.
- **Louka u vody bez úprav břehu (14:41):** světlý proužek dna a plná pěna vypadají jako pláž. Nahrazeno travnatým břehem s bahnem a slabší pěnou.
- **gen-v3 v1: hlína jako zbytek pod povrchem (18:59, nahrazeno variantou 2 Jan 19:18):** zbytek hlíny zůstal jako tečky v kameni (0–6 %) a vrstvy nečisté (0,80–0,86).
- **gen-v3: fáze B „rudy do kamene“ (18:46, zrušeno Janem 18:56):** nahrazeno rudami jako položkami, později parametrem `host` (c).
- **gen-v3: kámen odspodu přes BFS hromady (19:30):** pořadí kamenů odspodu s BFS vrstvami dalo čistotu 0,778 proti 0,814 výchozího pořadí a 75–104 ms; nahrazeno tvarem stratum (0,946, 22 ms).
- **Pěna z hloubkového bufferu (rešerše):** u izometrické kamery a malých vod dává nerovnoměrný pás [14][15]. Nahrazeno vzdálenostním polem.

## 3 Rozlišení bloku
- **16 × 16 × 64 s buňkou 1 × 1 × 0,5 jako cílový vzhled:** Jan: „moc hrubé“. Zatím zůstává ve hře, jemnější rozlišení je ve zkoušce.

## 4 Skála
- **A: kostky s texturou:** kámen, balvan i skála vypadají stejně, vypadá to jako otexturované kostičky.
- **B: rozbité kostky (zkosení, šum, praskliny):** levné (asi 3× dražší než A) a mřížka zůstává čitelná, jenže shluk působí poskládaný z kostek. Zůstává jako levná záloha.
- **D: hybrid s kameny z Blenderu:** kámen shluku se roztáhne na jeho obdélník, takže se ztratí tvary L a T; výkon jako C. Dával by smysl jen pro ručně dělané kameny jako objekty.
- **C přes celou mřížku (bez omezení na povrch):** 7 s na blok, nahrazeno verzí jen u povrchu.
- **Mikrooptimalizace GDScriptu:** přinesly jen asi 10 %, cesta vede přes C# nebo GDExtension.
- **Chunky 16³ pro kopání:** 167 ms na úpravu oproti 29 ms u 8³.

## 5 Tráva a vegetace
- **C ve výškách 0,15 / 0,05 (12:55):** trsy byly drobné a řídké a z pohledu kamery působily zase jako mech (`trava-studie/shots/27_trava_trsy_C_vysky_0.15_0.05.png`). Nahrazeno výškami 0,30 / 0,12 a vyšší hustotou.
- **Louka z původních trsů veg-v2 (jeden velký trs na 45 % sloupců):** v prototypu nahrazeno trávou C (13:40). Zůstává jen jako přepínač `--grass.enabled=0` pro srovnání.
- **Stopa přes celý ostrov jednou texturou:** pro ostrov 128 × 128 jednotek by to bylo kolem 9 MB nahrávání za snímek. Nahrazeno oknem 32 × 32, které jede za postavičkou.
- **B: jednotlivá stébla jako základ:** nejpřirozenější rozhrnutí ve vysoké trávě, jenže nízká tráva je řídká, stopa slabá a na celý blok by bylo asi 180 tisíc instancí. Zůstává nanejvýš jako ozdoba vysoké trávy u postavy. Jan 13:05 vybral pro louky variantu C (trsy s kytičkami), takže B definitivně vyřazena.

## 6 Vzhled a textury
- **Sytý plochý písek bez detailu (napojeni-studie, 14:14):** Jan: hranice louka–písek–voda se slévají. Nahrazen šedobéžovým pískem s detailem a přechodovými pásy.
- **Textura písku z Gemini jako jediný detail písku (14:40):** zblízka hezká (čeřiny, mušličky), z izometrické kamery skoro zmizí. Procedurální zrno a čeřiny jsou čitelnější. Gemini zůstává jako volba `sand_detail=1`.
- **Měkká hranice materiálu (soft 0,20–0,25):** rozmaže toon obrys a hranice se zase slévá. Ponechána ostrá nebo výchozí (0,05).
- **Gemini v1: jeden list se všemi texturami:** dlaždice měly rámečky a měď vypadala jako železo; nahrazeno samostatnými texturami v2.
- **Toon shader s ostrým `step()` řezem:** černé stěny při otáčení kamery, odstraněno.
- **Dlouhé žíhání stébel na procedurální louce (14:40):** čárky přes ~0,3 buňky po směru větru vypadaly z izometrické kamery jako déšť. Zkráceno na ~0,15 buňky a slabší.

## 7 Výkon
- (zatím nic)

---

# C. Návrhy optimalizací

Nevyzkoušené nápady na zrychlení. Stav: 💡 návrh · 🔬 ověřuje se · po vyzkoušení se přesune do A (použito) nebo B (zamítnuto) s naměřeným výsledkem.

## 1 Prototyp a buildy
- 💡 **Godot .NET (C#) nebo GDExtension:** horké smyčky (stavba skály, trávy, sítí) přepsat z GDScriptu. Benchmark skály ukázal asi 10× zrychlení (983 ms na 65–120 ms na blok). Komplikace: na boxu zatím chybí Godot .NET.
- 💡 **Stavba bloků ve vlákně na pozadí:** síť, skála i tráva se staví mimo hlavní smyčku, aby položení bloku nebo kopání nezaseklo obraz.

## 2 Terén a tvar
- 💡 **Materiálová mapa duální mřížky v shaderu:** místo GDScriptu (teď 470–490 ms na 4 vzorky) počítat míchání ze 4 rohů přímo na grafice.
- 💡 **Nižší podrozdělení duální mřížky:** `--dual_sub=2` stáhne síť ze 244 ms a 13 440 trojúhelníků na 68 ms a 3 520 trojúhelníků. Ověřit, jestli je to vizuálně dost.
- 💡 **Hybrid a plošina: méně dělení na plochých místech:** síť má nerovnoměrné čáry kolem každé hrany (29 840 trojúhelníků). Na rovině by stačily 2 trojúhelníky na dlaždici, odhadem 2–3× méně.
- 💡 **Hybrid: hledání malých prvků a výšky podkladu v C# nebo předpočítat při změně buněk:** splat hybridu teď 1,2 s na 4 vzorky v GDScriptu. Výsledek (`pair_bevel` na hranu) cachovat po hranách.
- 💡 **Vzdálenostní pole k vodě jen pro okrajové bloky:** pole stojí asi 105 ms, bloky bez vody ho nepotřebují.
- 💡 **Při vložení bloku přestavět u sousedů jen pruh u hranice (prototyp, 15:30):** teď se sousedům přepočítá celé okno polí, síť i tráva (575 ms na blok). Stačí pruh široký 5 sloupců a jen trsy v něm.
- 💡 **Vzdálenostní pole na grafice nebo v C#:** chamfer 4 polí po 96 × 96 texelech stojí v GDScriptu kolem 38 ms na blok. Jump flooding v shaderu, nebo C# ve vlákně.
- 💡 **Kostkový mesher bez dělení ploch na čtvrtiny:** kvůli duální masce se horní plochy dělí na čtvrtiny a boky na poloviny. Dělit jen buňky na rozhraní duální oblasti.

- 💡 **Voda: skutečný tlak jen pro uzavřené nádrže (16:05, `voda-studie/`):** spojené nádoby a artéské prameny řešit hledáním hladiny souvislého tělesa vody (flood fill při změně), ne po buňkách každý tik [2].
- 💡 **Voda: „virtual pipes“ pro povrchové potoky:** tok mezi sloupci se setrvačností dá hladší potoky na výškové mapě [15]; buňkový model nechat jen pro vodu v zemi a dutiny.
- 💡 **Ložiska: seznam hostitelských buněk místo skenu (18:33, `lozika-studie/`):** semínka v L1/L3 hledají hostitele skenem celého objemu (až 16 384 buněk na semínko). Předpočítat jednou seznam buněk podle materiálu a vybírat z něj, při obřích cílech odhadem 2–3× rychlejší (teď 34 ms na blok).
- 💡 **Ložiska: jedno pole značek s čítačem místo nového pole na každé semínko:** šíření alokuje 16 KB na semínko; pole s číslem běhu ušetří alokace (při 50 semíncích na rudu znatelné).
- 💡 **Ložiska: dorůstání (L2/L4) jen z okraje tělesa:** teď BFS startuje ze všech buněk rudy, stačí okrajové buňky z předchozího běhu.
- (vrstvy kamene po sloupcích, vsakování jen v propustné oblasti a kontrola v jednom průchodu vyzkoušeny 19:19, přesunuto do A, gen-v3 (e))
- 💡 **gen-v3: L4 a `_fill_holes` / `_swap_specks` po sloupcích (20:05):** zbytek rozmístění (L4 dosazení, díry, tečky) stojí většinu z 17–29 ms; jedna fronta pro všechny vrstvové položky by ušetřila opakované skeny.
- 💡 **gen-v3: kapacita vody na serveru přesně jako klient (20:05):** místo odhadu přidělení se 0,4 spočítat oblast vsakování ze tvaru (4–9 ms v GDScriptu, v C# méně); pak nulový odtok bez rezervy.
- (validátor jen v testech: Jan 20:39 rozhodl, že validátor poběží vždy – viz A/2; zbývá souhrn brát hotový ze serveru místo zástupce, 2,1 ms)
- 💡 **Tok vody po kopání v C# nebo ve vlákně (21:05, `water_flow.gd`):** simulace stojí 0,6 ms/tik na 1 620 buněk v GDScriptu; v C# odhadem 10×, pak by šel celý tok v jednom snímku.
- 💡 **Tok vody: menší výřez v nasyceném písku:** BFS přes pohyblivou vodu bere celý nasycený pás (až 5 040 buněk); stačí buňky, jejichž hladina je nad vykopanou buňkou.
- 💡 **Tok vody: kontrola ustálení levněji:** 30 tiků ověření stojí ~18 ms na konci toku; ve hře ji pouštět jen v ladění a ponechat zachování součtu.
- 💡 **gen-v3 v C# ve vlákně:** generátor je čistá funkce (bajty zásobníku → bajty bloku), dá se pustit mimo hlavní smyčku a bez úprav otestovat proti `gen_v3_vectors.json`.
- 💡 **Ložiska v C# nebo ve vlákně:** běžný blok stojí 1,4 ms, jen zátěžové cíle (34–74 ms) by zasekly snímek; spouštět mimo hlavní smyčku spolu s generátorem.

## 3 Rozlišení bloku
- 💡 **Jemnější rozlišení jen u povrchu:** 32 × 32 stojí asi 4× generování a 3× síť. Hloubku nechat hrubou a jemné buňky držet jen v horních vrstvách.

## 4 Skála
- 💡 **Skála přes Surface Nets v C# a ve vlákně:** spojit s přepočtem chunků 8³ při kopání (teď 29 ms na zásah).
- 💡 **LOD skály podle vzdálenosti:** zjednodušená verze má 4× méně trojúhelníků, zapojit ji automaticky podle vzdálenosti kamery.

## 5 Tráva a vegetace
- 💡 **Stavba trsů v C# nebo ve vlákně:** teď 14–17 ms na blok, projeví se při kladení a kopání.
- 💡 **Ořez bloků schovaných za jinými (occlusion culling):** v přiblížení se kreslí i bloky zakryté jinými, takže řídnutí podle zoomu tam nepomáhá (detail louky 154 ms místo 66 ms).
- 💡 **Řídnutí trávy i podle vzdálenosti od středu obrazu**, nejen podle zoomu.
- 💡 **Stopa pro víc postaviček:** jedna stopová textura na blok místo jednoho okna 32 × 32 kolem první postavičky.
- 💡 **Tráva u břehu: pole předvzorkovat na mřížku sloupce (15:30):** trsy u vody a písku teď vzorkují výšku, váhy a pole po jednom (vegetace bloku 49 ms místo asi 16 ms). Stačí mřížka 4 × 4 na sloupec a z ní interpolovat.

## 6 Vzhled a textury
- 💡 **Texturový atlas nebo pole textur** pro materiály, aby šel celý blok jedním draw callem.
- 💡 **Procedurální louka: velké pole předpočítat:** fleky, sucho a jetel (fBm, 3 × 3 oktávy) uložit do malé textury na blok (např. 32 × 32 px) a tón trsů zapéct do barvy instance při stavbě MultiMesh. Ve snímku zůstane jen drobné žíhání a zrno, sladění trsů pak nestojí nic.

## 7 Výkon
- 💡 **Měření na skutečné grafice:** všechna čísla jsou zatím ze softwarového vykreslování (llvmpipe). Udělat build a změřit na Janově GPU.
- 💡 **Profilovací přepínač v buildu:** výpis času na snímek a počtu instancí, ať se dá měřit přímo u Jana.
  Částečně splněno ladicím oknem (`--dev`, FPS, ms, instance), to ale do release exportu nejde. Pro měření u Jana udělat build s doplňkem.
- 💡 **Voda jen v aktivních buňkách a uspávání chunků (16:05, `voda-studie/`):** teď se každý tik projdou všechny buňky (blok 16 × 16 × 64 = 4,6–4,8 ms/tik v GDScriptu). Seznam buněk s vodou a „ustálené“ chunky 8³ přeskakovat jako Noita [13][14]; odhad < 1 ms na blok.
- 💡 **Voda: kontrolu bilance jen v ladění:** dva součty všech buněk za tik stojí ~0,37 ms z 4,7 ms (8 %); na serveru počítat bilanci jen z přítoků a odtoků.
- 💡 **Voda v C# / na serveru v celých číslech:** fixed-point objem (např. setiny buňky v uint16) = shodný výsledek klient/server a menší paměť; C# podle skály ~10× rychlejší.
- 💡 **Voda: nižší frekvence tiků pro vzdálené bloky:** bloky bez hráčů počítat třeba 1× za 4 tiky s větším krokem.
