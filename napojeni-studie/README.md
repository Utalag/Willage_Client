# Studie napojování terénu (louka, písek, voda)

Samostatná větev nezávislá na `godot-prototyp/` (stejně jako `skala-studie/` a `trava-studie/`). Z prototypu je jen převzatá logika dorovnání stran (`block_gen.gd`), toon shader s obrysy a tráva C z `trava-studie/`. Dobré výsledky se do prototypu zapojí později.

Rešerše je v `RESERSE.md`, zdroje v `ZDROJE.md` (v textu jen značky [n]).

## Co se srovnává

Oba přístupy stojí vedle sebe nad **stejnými daty** a se **stejnými pohledy kamery**: 2 × 2 vzorky (zmenšené bloky) po 10 × 10 × 4 buňkách (buňka 1 × 1 × 0,5):

| vzorek | obsah | přechod uvnitř vzorku |
|---|---|---|
| SZ louka | tráva, výška 3–4 vrstvy | – |
| SV píščina | písek 2–3 vrstvy | ostrůvky trávy o vrstvu výš |
| JZ voda | dno 1 vrstva pod hladinou | písečný ostrůvek s 1 travnatou buňkou |
| JV pobřeží | voda → písek → louka po úhlopříčce | celé pobřeží |

Švy mezi vzorky: louka | píščina, louka / voda, píščina / pobřeží, voda | pobřeží a křížení všech čtyř uprostřed. Vzorky se vkládají postupně a každý nový dorovná výšku svých stran k už vloženým sousedům stejně jako `block_gen.gd` (auto 3 buňky, max 6 vrstev rozdílu, `--side_mode` = 0 auto | 1–4 blend | 5 keep) [24]. Nové pravidlo studie: voda a souš mají pevné meze výšky (souš vždy nad hladinou, dno pod ní), takže dorovnání nezaplaví trávu ani nevysuší dno.

**1 · Klasická mřížka s přechodem na hranách buněk** (vlevo). Materiál i výška jsou jeden na buňku, povrch jsou schody jako v prototypu. Přechod řeší každá buňka na svých 4 hranách a 4 rozích: „silnější“ soused (tráva > písek > dno) do ní zasáhne nepravidelným pásem 0,3 buňky, to je princip Wang / blob dlaždic s prioritou [8][9][10]. Břeh je tvořen stěnami buněk.

**2 · Duální mřížka (Oskar Stålberg / Townscaper)** (vpravo). Zobrazovací dlaždice jsou posunuté o půl buňky, roh dlaždice = střed datové buňky. Materiál dlaždice vzniká ze 4 rohů (marching squares, váhy rohů + šum, ostrá toon hranice) a výška se mezi středy buněk interpoluje (smoothstep: středy buněk rovné, svah u hrany) [1][2][4][11]. Data zůstávají celé buňky a vrstvy, mění se jen zobrazení.

**Doplňky** (vrstva navíc, zapínají se nad oběma přístupy): mokrý písek u vody [18][19][20], pěna a vlnky postupující k břehu ze vzdálenostního pole [15][16][17], řídnutí trávy C k okraji louky (méně, nižší a sušší trsy, kvítky jen uvnitř) [21]. Voda samotná (průhlednost a barva podle hloubky, tyrkysové dno) je v obou přístupech stejná.

Mesh se staví **po vzorcích** jako po blocích. Přístup 1 čte výšku sousedního vzorku pro stěny (jako obal 18 × 18 v `mesher.gd`), přístup 2 čte 1 řadu buněk od východního a jižního souseda; dlaždici na hranici vlastní vzorek s jejím levým horním rohem [22][23]. Na hranicích vzorků nejsou švy v žádném z přístupů.

## Výsledky (screenshoty v `shots/`)

| soubor | co ukazuje |
|---|---|
| `29_napojeni_prehled.png` | oba přístupy vedle sebe, s doplňky |
| `29_napojeni_prehled_srovnani.png` | 2 × 2: přístup 1 / 2, bez doplňků / s doplňky |
| `29_napojeni_sev_louka_pisek.png` | šev vzorků louka \| píščina |
| `29_napojeni_sev_louka_voda.png` | šev vzorků louka / voda (velký výškový rozdíl) |
| `29_napojeni_kriz_vzorku.png` | křížení hranic 4 vzorků |
| `29_napojeni_pobrezi_vzorek.png` | voda → písek → louka uvnitř jednoho vzorku |
| `29_napojeni_ostrov.png` | ostrůvek ve vodě (jednobuněčný travnatý vršek) |
| `29_napojeni_pisek_ostruvky.png` | jednotlivé travnaté buňky v písku |
| `29_napojeni_shora_mrizky.png` | pohled shora: bílá = datové buňky, červeně = duální dlaždice a jejich rohy |
| `29_napojeni_doplnky_detail.png` | doplňky zblízka (bez / s) v obou přístupech |
| `29_napojeni_demo.mp4` | 14 s: oba → křížení vzorků v 1 → totéž ve 2 → pobřeží ve 2 → zpět (vlny, pěna, vítr) |

**Přístup 1 (mřížka).** Čitelné buňky a čitelná pravidla, jedna travnatá buňka = jasný kvádr. Břeh je zubatý (schody po buňkách) a louka u vody končí útesem; pás přesahu trávy do písku pomůže jen trochu. Vnitřní rohy jsou ostré a vnější zubaté, jak popisuje [4].

**Přístup 2 (duální).** Pobřeží i hranice louky jsou plynulé křivky, vnější i vnitřní rohy stejně kulaté. Mezi loukou a vodou sám vznikne mírný svah s pláží (výška se interpoluje mezi středy), tedy profil pláže z [18] bez dalších pravidel. Švy mezi vzorky nejsou vidět. Nevýhody: osamělá buňka se zmenší na kulatou skvrnu menší než buňka a ztratí výšku (ostrůvky trávy v písku, vršek ostrova); kopání a výběr buňky musí ukazovat datovou buňku, ne dlaždici; strmé rozdíly (louka 4 vrstvy vedle dna) jsou svah místo útesu.

**Doplňky.** Pěna a vlnky dělají největší rozdíl ve vzhledu vody a fungují v obou přístupech (u 1 kopírují zuby). Mokrý písek je nenápadný pruh, ve 2 přirozený, v 1 jen podél stěn. Řídnutí trávy změkčí okraj louky v obou.

## Vzhled písku a přechodových pásů (30_*, Janova zpětná vazba 14:14)

Jan: písek je moc sytý, nemá texturu a hranice louka–písek–voda se slévají. Úpravy (vše přepínatelné):

- **Méně sytý písek** (`--sand_look=1`, výchozí): šedobéžová místo sytě žluté; boky dioramatu taky méně syté. `0` = původní.
- **Detail písku** (`--sand_detail`): `1` = textura Gemini z prototypu (`assets/tex/03.png`, čeřiny a mušličky) [27], `2` = procedurální zrno + čeřiny v shaderu (výchozí), `0` = bez. `--sand_tex_scale`, `--sand_tex_contrast`.
- **Přechodové pásy jako samostatný materiál** (`--bands=1`): u vody pás **uježděného mokrého písku** (`--band_water` 0,75 buňky; tmavší a šedší, jemné čeřiny souběžně s břehem, nepravidelný okraj), před loukou pás **písku prorostlého trávou** (`--band_grass` 1,1 buňky; zelené skvrny, hustší k louce, a řídké nízké trsy `--mix_tufts` 0,18). Pásy nahrazují původní „mokrý písek“ z doplňků. Potřebují jedno pole navíc (vzdálenost k louce, kanál A).

| soubor | co ukazuje |
|---|---|
| `30_napojeni_mekkost_pisek.png` | 3 × 2: původní písek / nový + Gemini + pásy / nový + procedurální + pásy, přístup 1 a 2 |
| `30_napojeni_mekkost_detail_2.png` | totéž zblízka v přístupu 2 (pláž mezi vodou a loukou) |
| `30_napojeni_mekkost_pasy.png` | nový písek bez pásů / s pásy |
| `30_napojeni_mekkost_prehled.png` | celek: původní / nový písek |
| `30_napojeni_mekkost_hrana.png` | měkkost hrany materiálu: ostrá (0,01) / výchozí (0,05–0,06) / měkká (0,20–0,25) |

**Co vypadá nejlíp:** nový šedobéžový písek + **procedurální zrno a čeřiny** + **oba pásy**, v duální mřížce. Procedurální čeřiny jsou vidět i z dálky. Textura Gemini je zblízka hezčí (mušličky), ale z izometrické kamery skoro zmizí. Pás uježděného písku dělá z břehu čitelnou čáru (voda | mokrý písek | suchý písek). Pás trávy v písku odliší louku od pláže a nevznikne ostrá hrana. Měkkost hrany: výchozí nebo ostrá. Měkká rozmaže obrys a hranice se zase slévá. Je to v toon stylu horší.

Spuštění: `./run.sh mekkost` (vytvoří všechny `30_*`). Screenshoty `29_*` a video jsou ještě s původním pískem.

## Samostatné buňky a méně agresivní přechody (31_*, Jan 14:20)

Problém: v duální mřížce se osamělá buňka (tráva v písku, ostrůvek ve vodě) smrskne na kulatý flek a ztratí výšku, protože roh dlaždice je průměr 4 buněk. Parametr `dual_shape` (vše jen v této studii):

| `dual_shape` | varianta | co dělá | výsledek |
|---|---|---|---|
| 0 | současná | marching squares z rohů, výška smoothstep mezi středy | osamělá buňka = nízký kulatý flek |
| 1 | posun izočáry (`iso_bias` 0,5) | váha silnějšího materiálu (louka > písek > dno) se zvětší | flek je větší, ale pořád plochý; rovné hrany se posunou do písku |
| 2 | plošina + zkosení (`bevel` 0,3) | buňka drží svou výšku, přechod jen v pásu šířky `bevel` u hrany | výška i skoro čtvercový tvar zůstanou, ale celý terén je hranatý jako mřížka; zkosení jako hliněné stěnky |
| 3 | hybrid (`hyb_small` 2, `hyb_step` 2, `hyb_bevel` 1,0) | prvky do `hyb_small` buněk, které nejsou níž než okolí, jsou kvádry s obrysem; rozdíl ≥ `hyb_step` vrstev je svislá stěna; zbytek duální | osamělá buňka = jasný kvádr (tráva nahoře, plná stopa a výška), útes = stěna, ostatní hladké |

Screenshoty (řádky: klasická / současná / izočára / plošina / hybrid):
- `31_napojeni_samostatne_pisek_ostruvky.png`: tráva v písku (stejný pohled jako `29_napojeni_pisek_ostruvky`).
- `31_napojeni_samostatne_ostrov.png`: ostrůvek ve vodě (jako `29_napojeni_ostrov`).
- `31_napojeni_samostatne_sev_louka_voda.png`: hrana louka / voda.
- `31_napojeni_samostatne_prehled.png`: celky 5 variant + hybrid shora s mřížkou.

**Nejlepší: hybrid (3).** Odpovídá pravidlu „1 buňka = kvádr“ i schválenému „skála a útesy na buňkách“. Velké plochy zůstanou měkké. Plošina + zkosení je záloha, pokud by Jan chtěl méně oblé přechody všude. Hybrid jde zkombinovat s částečným zkosením (`--hyb_bevel=0.5`). Posun izočáry sám nestačí.

Cena (`shots/bench_samostatne.txt`, softwarově):

| varianta | splat | mesh | trojúhelníky | snímek celek / detail |
|---|---|---|---|---|
| klasická | 645 ms | 5 ms | 1 736 | 36,6 / 40,1 ms |
| duální současná | 465 ms | 244 ms | 13 440 | 37,8 / 41,3 ms |
| posun izočáry | 481 ms | 253 ms | 13 440 | 39,6 / 46,3 ms |
| plošina + zkosení | 920 ms | 117 ms | 29 760 | 66,3 / 58,5 ms |
| hybrid | 1 235 ms | 128 ms | 29 840 | 61,9 / 63,6 ms |

Plošina i hybrid mají 2,2× víc trojúhelníků, protože mesh má nerovnoměrné dělení kolem hran. Plochá místa by šla dělit méně. Splat hybridu je dražší kvůli hledání prvků a výšce podkladu. Obojí patří do C# nebo do shaderu. Spuštění: `./run.sh samostatne`.

## Louka přímo u vody (33_*, Jan 14:34)

Rozložení `--layout=1`: SZ nízká louka (plochý břeh, 0,15 m nad hladinou), SV vyšší louka (vlevo o 1 vrstvu, vpravo o 2 vrstvy výš), JZ voda s travnatým jazykem, JV voda s ostrůvkem z jedné buňky. Bez písku. Vzhled břehu (`-1` = automaticky zapnuto jen v layoutu 1):

- `bank`: dno nad hladinou u louky (do `bank_reach` 2,2 buňky) je travnaté, s řídkými trsy. Strmý svah je hlína místo písku a obrys louka / dno tam zmizí.
- Bahno: nízký tmavší pás mokré hlíny přímo u vody (`mud_w` 0,16 buňky, skvrnitý, ne souvislá čára).
- `reeds`: rákos (7 listů + palice, ve větru) v trsech na čáře vody jen tam, kde je břeh louka (`reed_density` 8, `reed_h` 0,8).
- `foam_bank` 0,3: pěna u louky je slabší než u pláže (vodní shader pozná podle pole vzdálenosti k louce, že nejbližší břeh je tráva).

Screenshoty:
- `33_napojeni_louka_voda_prehled.png`: klasická / duální × bez úprav / s břehem, bahnem a rákosem.
- `33_napojeni_louka_voda_plochy_breh.png`, `_breh_1_vrstva.png`, `_breh_2_vrstvy.png`: podle výšky břehu (klasická | duální).
- `33_napojeni_louka_voda_jazyk_ostruvek.png`: travnatý jazyk a ostrůvek z jedné buňky.
- `33_napojeni_louka_voda_moznosti.png`: duální zblízka: bez úprav / břeh + bahno + slabší pěna / + rákos / + rákos s pěnou jako u pláže.

**Nejlepší:** duální mřížka + travnatý břeh + bahno + slabší pěna + rákos. Bez úprav vypadá louka u vody jako pláž (světlý proužek dna a plná bílá pěna). Plochý břeh v duální mřížce vypadá přirozeně. Břeh o 1 vrstvu je travnatý svah. Břeh o 2 vrstvy je zatím hliněný svah. Podle pravidla „útesy na buňkách“ by to v hybridu (`dual_shape=3`) byla stěna. Ostrůvek z 1 buňky se v duální mřížce smrskne, řeší to hybrid z 31_*.

Cena (`shots/bench_louka_voda.txt`): břeh a rákos se staví 6–13 ms a mají 77–91 instancí na 4 vzorky. Bahno a slabší pěna jsou jen v shaderu. Snímek: klasická 27,4 → 29,5 ms, duální 37,4 → 38,6 ms. To je v rámci šumu. Spuštění: `./run.sh louka_voda`.

## Výkon (box, softwarové vykreslování llvmpipe, GDScript; `shots/bench.txt`)

| krok | 1 mřížka | 2 duální |
|---|---|---|
| materiálová mapa (splat 16 px/buňku, 320 × 320) | 640–780 ms | 470–490 ms |
| vzdálenostní pole (3 × chamfer) | ~105 ms | ~105 ms |
| mesh 4 vzorků | 5 ms, 1 736 trojúhelníků | 244 ms, 13 440 trojúhelníků (dělení 4); s `--dual_sub=2` 68 ms, 3 520 |
| tráva C (s řídnutím) | 31 ms, 3 226 instancí | 36 ms, 2 924 instancí |
| snímek, celek / detail (bez doplňků) | 24,6 / 32,1 ms | 36,4 / 36,3 ms |
| snímek, celek / detail (s doplňky) | 24,4 / 30,3 ms | 31,4 / 34,4 ms |

Data 4 vzorků (včetně dorovnání stran) 0,7 ms. Nový písek a pásy: pole o ~25 ms delší (4. chamfer), 160 trojúhelníků trsů navíc v pásech a snímek přístupu 2 softwarově asi o 3–7 ms pomalejší (39–44 ms), přístup 1 beze změny (26–35 ms). Doplňky nic měřitelného nestojí (jsou v shaderu a pole se stejně počítá). Snímky jsou softwarové a kolísají o ±5 ms; na GPU budou zlomky. Splat a pole jsou v GDScriptu pomalé; pro hru patří do C# / GDExtension nebo do shaderu (splat přístupu 2 je čistá funkce 4 rohů, dá se počítat přímo v pixel shaderu z malé textury materiálů buněk). Při rozlišení 0,5 m (`--sample_n=20 --cell_xy=0.5 --cell_z=0.25 --layers=8 --splat_px=8`) má přístup 2 52 480 trojúhelníků a mesh 1 048 ms v GDScriptu, přístup 1 6 676 trojúhelníků a 19 ms.

## Spuštění

```sh
./run.sh shots                 # screenshoty do shots/29_napojeni_*.png
./run.sh bench                 # měření do shots/bench.txt
./run.sh stats                 # jen časy stavby
FRAMES=420 ./run.sh movie      # video shots/29_napojeni_demo.mp4
./run.sh samostatne            # 31_*: samostatné buňky (5 variant)
./run.sh louka_voda            # 33_*: louka přímo u vody (--layout=1)
./run.sh play                  # interaktivně: 1 celek, 2 křížení v přístupu 1, 3 ve 2; E doplňky; G mřížky
./run.sh shots -- --cell_xy=0.5 --sample_n=20 --cell_z=0.25 --layers=8   # jiné rozlišení
```

## Parametry (`scripts/params.gd`, vše přes `-- --klic=hodnota`)

- Rozlišení: `sample_n`, `cell_xy`, `cell_z`, `layers`; šum je ve fyzických souřadnicích, takže tvar zůstává.
- Výšky: `water_level` 0,85 m, `meadow_h`, `sand_h`, `bed_h`; dorovnání: `side_mode`, `blend_max`, `auto_cells`.
- Přístup 1: `edge_band` 0,30, `edge_noise`, `edge_soft`.
- Přístup 2: `dual_sub` 4, `dual_ease` (0 lineární svah, 1 smoothstep), `dual_noise`, `dual_soft`.
- Splat: `splat_px` 16.
- Doplňky: `wet_w`, `wet_h`, `wet_dark`, `foam_w`, `wave_reach`, `wave_freq`, `wave_speed`, `thin_w`, `thin_min`.
- Písek a pásy: `sand_look`, `sand_detail`, `sand_tex_scale`, `sand_tex_contrast`, `bands`, `band_water`, `band_grass`, `mix_tufts`.
- Samostatné buňky: `dual_shape` (0–3), `iso_bias`, `bevel`, `hyb_small`, `hyb_step`, `hyb_bevel`.
- Louka u vody: `layout` (0/1), `bank`, `bank_reach`, `mud_w`, `reeds`, `reed_density`, `reed_h`, `foam_bank`.
- Tráva C: `tufts` 24 na buňku, `tuft_h` 0,30, `tuft_dry`, `flowers`, vítr `wind_*`. Počet trsů je na buňku, při buňce 0,5 m je jich tedy 4× víc na m².

## Soubory

- `scripts/data.gd`: vzorky, dorovnání stran, výška pro oba přístupy.
- `scripts/builder.gd`: splat, vzdálenostní pole, meshe obou přístupů, voda.
- `scripts/grass.gd`: tráva C po vzorcích, s řídnutím i bez.
- `scripts/main.gd`: scéna, kamera, screenshoty, video, měření.
- `shaders/terrain.gdshader` (toon + obrysy + splat + mokrý písek + mřížky), `shaders/water.gdshader` (hloubka, pěna, vlnky), `shaders/grass_tuft.gdshader` a `grass_common.gdshaderinc` (z trava-studie).

## Doporučení

1. Pro louku, písek a vodu použít **duální mřížku (2) jen pro zobrazení povrchu**; data, kopání, stavby a cesty zůstanou na buňkách [2][6]. Vypadá výrazně líp a pobřeží vznikne samo.
2. **Útesy a skálu nechat na buňkách** (přístup 1 / Surface Nets ze skala-studie): duální svah se hodí jen na malé rozdíly. Pravidlo: rozdíl výšek rohů do 2 vrstev = svah, víc = stěna.
3. Samostatné buňky a útesy: **hybrid** (`dual_shape=3`), prvky do 2 buněk a schody od 2 vrstev jako kvádry.
4. Louka přímo u vody: travnatý břeh, bahno, slabší pěna a rákos (layout 1).
5. Doplňky (pěna, vlnky, řídnutí trávy) zapnout vždy, jsou skoro zadarmo. Písek: šedobéžový, procedurální zrno a čeřiny, pásy uježděného písku u vody a trávy v písku před loukou (výchozí nastavení).
6. Splat přístupu 2 počítat v shaderu z malé textury materiálů buněk místo v GDScriptu.
