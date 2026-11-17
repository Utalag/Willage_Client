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

## 7 Výkon

### 🧪 Úroveň detailu trávy podle přiblížení (2026-11-17 13:40 · `godot-prototyp/scripts/grass.gd`)
- **Směr:** trsy každého bloku jsou v bufferu MultiMesh po osminách (každý 8. trs každého sloupce). Při oddálení ortografické kamery se kreslí jen část (`visible_instance_count`, plná hustota do záběru 20 jednotek, minimum 1/8), kvítky vždy celé.
- **Zlepšení:** plný ostrov celkem 588 → 240 ms na snímek (softwarově), startovní ostrov 189 → 120 ms. Z dálky rozdíl vidět není, nic se nepřepočítává.
- **Komplikace:** v detailu nepomáhá, tam se kreslí vše včetně bloků v zákrytu.

### 🧪 Horká smyčka v C# (2026-11-17 12:40 · `skala-studie/csharp_bench/`)
- **Zlepšení:** celý blok 65–120 ms, 1 chunk 2,8 ms, stejný výsledek jako GDScript.
- **Komplikace:** na boxu není Godot .NET, takže C# zatím neběží uvnitř hry.

---

# B. Zamítnuté směry

## 1 Prototyp a buildy
- **Jeden Windows zip jako příloha:** přes 25 MB, nahrazeno 7z ve dvou částech.

## 2 Terén a tvar
- **Hybrid s kvádry, posun izočáry a plošina se zkosením pro samostatné buňky (napojeni-studie, 14:41, zamítnuto Janem 14:55):** zůstává současná duální mřížka (`dual_shape=0`); samostatné buňky se slijí do flíčků a břehy jsou svahy. Varianty zůstávají ve studii jako volba.
- **Hory jako jednoduché kopečky (původní generátor):** Jan: příliš pravidelné.
- **Relief v2.1: nepravidelné eliptické vrcholy:** byl to krok správným směrem („mnohem lepší“), nahradily ho terasy v2.2. Zůstává dostupný přes `relief_version`.
- **Klasická mřížka pro povrch louky, písku a vody (napojeni-studie, přístup 1, 13:30, zamítnuto Janem 14:04 pro povrch):** přechod se řeší na hranách buněk. Silnější materiál přesahuje pásem do sousední buňky, princip Wang / blob dlaždic [8][10]. Je levná a čitelná, jenže břeh je zubatý a louka končí u vody útesem. Pro útesy a skálu zůstává.
- **Posun izočáry jako řešení samostatných buněk (napojeni-studie, 14:41):** osamělá buňka je větší, ale pořád plochá a bez výšky. Rovné hrany louky se posunou do písku. Nahrazeno hybridem.
- **Plošina + zkosení jako výchozí tvar duální mřížky (14:41):** drží výšku, ale celý terén je zase hranatý jako mřížka. Síť má 2,2× víc trojúhelníků. Zůstává jako `dual_shape=2` pro případ, že Jan chce méně oblé přechody všude.
- **Louka u vody bez úprav břehu (14:41):** světlý proužek dna a plná pěna vypadají jako pláž. Nahrazeno travnatým břehem s bahnem a slabší pěnou.
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

## 6 Vzhled a textury
- 💡 **Texturový atlas nebo pole textur** pro materiály, aby šel celý blok jedním draw callem.
- 💡 **Procedurální louka: velké pole předpočítat:** fleky, sucho a jetel (fBm, 3 × 3 oktávy) uložit do malé textury na blok (např. 32 × 32 px) a tón trsů zapéct do barvy instance při stavbě MultiMesh. Ve snímku zůstane jen drobné žíhání a zrno, sladění trsů pak nestojí nic.

## 7 Výkon
- 💡 **Měření na skutečné grafice:** všechna čísla jsou zatím ze softwarového vykreslování (llvmpipe). Udělat build a změřit na Janově GPU.
- 💡 **Profilovací přepínač v buildu:** výpis času na snímek a počtu instancí, ať se dá měřit přímo u Jana.

