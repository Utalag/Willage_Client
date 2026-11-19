# Blueprint-studie: vkládání bloku jako pokračování sousedů

Samostatná studie v Godotu 4.7.2 (Compatibility). Ověřuje Janův směr z 2026-11-18: divák vloží **blueprint**, tedy jen
tvar povrchu (louka, kopec, svah, prohlubeň), seed a počty minerálů a kovů. Rarita se počítá jen z nich, základní horniny
se nepočítají. Zdroje jsou uvedené jako [n] v `ZDROJE.md`. Cíl, hypotéza, metriky a výsledky jsou v `PROP.md`.

## Postup vložení
1. **Náhled:** šablona povrchu se ukáže průhledně. Okraje se dorovnají na sousedy: okrajový sloupec dostane výšku
   přiléhajícího sloupce souseda a korekce je harmonická v pásu `band` (výchozí 4 buňky) [1][2][3]. Vnitřek se nemění.
2. **Potvrzení:** hranice vrstev (vršek čediče, žuly, vápence, jílu a písku) se počítají jako **pokračování sousedů**:
   `B = cíl + c`. Cíl je regionální deska ve světových souřadnicích (vlnité vrstvy z fBm s domain warpem [4], Janova skica 1),
   k ní se přičte zvednutí vrstev pod kopcem (`drape`) a malý šum ze seedu blueprintu. Korekce `c` je harmonická funkce
   s hodnotami sousedů za stranou bloku (Dirichlet). Strany bez souseda mají nulový spád (Neumann), takže vrstva prostě
   pokračuje dál [7]. Osamocený blok vznikne jen z regionální desky.
3. **Minerály:** vtisknou se v **přesných počtech** a jen do povolených hostitelů podle `data/mineraly_hostitele.json`
   (Jan 16:02). Použije se růst ore_v0 a dosazení gen-v3 `_sweep`, záložní hostitelé nejsou. Když hostitel nestačí, vznikne
   **schodek**, který se nahlásí a validátor ho dostane jako hlášený.
4. **Voda:** vsakování gen-v3 (`infiltrate`) pro nový blok, pak validátor gen-v3 (počty a stabilita vody).

Volitelně: hydraulická eroze kapkami na šabloně před dorovnáním (`--erosion=1`) [5].

## Spuštění
```
./run.sh shots      # snímky shots/45_blueprint_*.png + kontrola hash po snímcích vs. naráz (shots/hash_snimky.txt)
./run.sh test       # testy a měření bez okna -> shots/bench.txt
./run.sh play       # okno: sled 5 vložení s ukazatelem průběhu
./run.sh test --band=3 --strata_band=6 --free_face=zero --drape=0,0.1,0.3,0.5,0.6 --erosion=1 --droplets=5000
./run.sh voda       # E47 eroze po vrstvách + déšť (voda_sim) → shots/bench_voda.txt, 47_voda_eroze_*.png
./run.sh funkce     # E48 3D grafy funkcí vrstev → shots/48_funkce_*.gif
./run.sh voda47d    # E47d podzemní voda po propustné vrstvě: testy čočka → tůň 4 × 4, dutina → podzemní jezero; svět; snímky 47d_*
./run.sh voda47b    # E47b/c strže, ponory, vodopády; voda jen z pramenů, okraj ostrova, lokální přepočet, plnění tůní → shots/bench_voda_c.txt, bench_voda_b.txt, 47b_*.png, 47b_vodopad.gif
./run.sh svet64     # E50 svět 8 × 8 po 64 × 64 × 256 buňkách: časy fází a bloků, paměť → shots/bench_svet64.txt, 50_svet64_faze.gif, 50_svet64_iso.png
./run.sh eroze51    # E51 eroze a usazování událostmi (odpočet objemu vody, Manning, halda) → shots/test_eroze51.txt, bench_eroze51.txt, 51_koryto/51_tun/51_hraz.png
./run.sh podzemi52  # E52 podzemní voda: varianty slovník / pole / hrubá mřížka / funkce nad vrstvami / Darcy 2D a 3D (CG) → shots/podzemi52/*.json, tabulka.md, bench_podzemi52.txt, 52_*.png
./run.sh plosne53   # E53 plošný tok celými poli: pravidlo rozlévání ceil(Q/k), mělká voda, vektorové pole → shots/test_plosne53.txt, bench_plosne53_*.json, 53_*.png
./run.sh dohnani54  # E54 dohnání nepozorovaného (jeden skok = stejný stav), ranné zastavení přepočtu, vodní bilance → shots/test_dohnani54.txt
./run.sh podzemi55  # E55 režim podzemí podle dna tělesa (preliv / nadrz / smes, práh p55_perm_dno) → shots/test_podzemi55.txt, 55_prameny_prusak.png
./run.sh svah56     # E56 mírnější přechody (s56_on, s56_max_slope …) před / po → shots/bench_svah56.txt, 56_profil.png, 56_mapa.png
python3 tools/materialy59.py   # E59 návrh vodních vlastností z reálných K / Sy → ../sdilene/materialy_voda_navrh.json, shots/materialy59.md (sdílené tabulky nemění)
./run.sh alg58      # E58 varianty A / B / C a kombinace: záznam volání podzemí, každá varianta zvlášť, povrch 128²–512² → shots/alg58/*.json, 58_*.png
./run.sh svet8      # E49 svět 8 × 8 (hrubě → dlaždice → detail) → shots/bench_svet8.txt, 49_svet_8x8_faze.gif, 49_svet_8x8_*.png
```
Všechny parametry jsou v `scripts/bp/params.gd`. Hlavní jdou ladit i v Inspectoru na uzlu `Svet`.

## Scéna (uzly, žádný monolit)
`main.tscn`: `Main` → `World` (WorldEnvironment, Sun) · `CameraRig` (Camera3D) · `Svet` (stav světa a parametry) ·
`Placer` (vkládání po snímcích, signály `progress` a `finished`) · `BlockViews` (kreslení bloků a řezů) · `Preview`
(průhledný náhled) · `UI` (Hud a panel Prubeh s ProgressBar) · `Scenario` (ukázkový sled, režimy) · `ScenarioHorniny`
(`--horniny`) · `ScenarioVoda` (`--voda`, 3D před/po erozi s vodou) · `ScenarioSvet8` (`--svet8`, 3D svět 8 × 8) · `ScenarioSvet64` (`--svet64`, izo E50 z uložených dat, render měřený zvlášť) · `ScenarioPodzemi` (`--voda47d`, rentgen propustné vrstvy, řez u výtoku, demo čočka a dutina) · `ScenarioVodaB` (`--voda47b`, 3D prameny, strže, vodopády, ponor/odtok tůně, okraj ostrova).

| soubor | co dělá |
|---|---|
| `scripts/bp/pipeline.gd` | vložení jako seznam kroků; stejné kroky běží naráz (server, testy) i po snímcích (Placer) |
| `scripts/bp/surface.gd` | dorovnání okrajů povrchu (náhled) |
| `scripts/bp/strata.gd` | cíl vrstev, harmonické navázání, monotónnost, vyplnění buněk |
| `scripts/bp/harmonic.gd` | Laplace / SOR na mřížce 16 × 16 s obalem 18 × 18 |
| `scripts/bp/region.gd` | regionální deska ve světových souřadnicích |
| `scripts/bp/minerals.gd`, `hostitele.gd` | vtisknutí minerálů podle tabulky hostitelů, schodek |
| `scripts/bp/blueprint.gd` | šablony tvarů, rarita z minerálů |
| `scripts/bp/erosion.gd` | volitelná eroze |
| `scripts/bp/world.gd` | sloty, sousedé, SHA-256 světa |
| `scripts/bp/metrics.gd`, `naive.gd`, `tests.gd` | metriky švů, srovnání s nezávislým gen-v3, testy |
| `scripts/kopie/` | **kopie beze změny logiky** z `lozika-studie/scripts` (gen_v3, ore_v0, gen3_server, gen3_stack, mesher, block_gen, …), změněné jsou jen cesty `preload` |
| `scripts/voda/eroze_mrizka.gd` | E47 kapková eroze na libovolné mřížce W × H (pravidla erosion.gd, `ero_*`) |
| `scripts/voda/eroze_svet.gd` | E47 eroze PO vrstvách na hotovém světě: režimy `blok` / `okraj` (švy připnuté) / `svet`, převzorkování buněk, minerály zůstanou |
| `scripts/voda/voda_svet.gd` | E47 déšť a tok vody přes celý svět (kopie voda_sim.gd, vlastnosti hornin ze sdílené tabulky, `voda_*`) |
| `scripts/voda/tests_voda.gd`, `tools/test_voda.gd`, `tools/compose_voda.py` | E47 měření a snímky |
| `scripts/voda/strze.gd` | E47b strže podle průtoku (stream power [23], cíl medián `strz_target_m`), ponory, vodopády a tůně pod nimi (`strz_*`, `ponor_*`, `vodopad_m`, `tun_*`) |
| `scripts/voda/prameny.gd` | E47c prameny = jediný zdroj vody: sníh/vrchol, styk propustná/nepropustná, krasová vyvěračka (`pram_*`); uzavřený pramen neteče |
| `scripts/voda/tok.gd` | E47c uložené koryto: plný výpočet, lokální přepočet po změně terénu, tůně s odtokem do podzemí (`pit_drain_q`) a událostmi plnění, odtok přes okraj ostrova |
| `scripts/voda/tests_voda_b.gd`, `tools/test_voda_b.gd`, `tools/compose_voda_b.py`, `scripts/uzly/scenario_voda_b.gd` | E47b/c měření, mapy a 3D snímky |
| `scripts/voda/podzemi.gd` | E47d podzemní tělesa ve 3D buňkách: propustná hornina / kras / dutina, plnění po vrstvách z, nejnižší výstup (svah, tůň, stěna ostrova), průsak (`ug_*`) |
| `scripts/voda/tests_podzemi.gd`, `tools/test_podzemi.gd`, `scripts/uzly/scenario_podzemi.gd` | E47d testy (čočka → tůň 4 × 4, dutina → jezero, uzavřená čočka) a 3D snímky `47d_*` |
| `scripts/voda/tests_tun.gd`, `tools/test_tun.gd` | test Janova příkladu plnění prohlubně (1/t, 2 × 2 × 2, odtok 0,5 → 16 t) → `shots/test_tun.txt` |
| `tools/dump_funkce.gd`, `tools/gif_funkce.py` | E48 husté vzorky funkcí povrchu a hranic → 3D GIFy (matplotlib + ffmpeg, bez textu) |
| `scripts/svet8/hruby_teren.gd`, `pocasi.gd`, `reky.gd`, `biomy.gd`, `dlazdice.gd`, `beh.gd` | E49 fáze hrubého světa, řez na dlaždice, detail od první dlaždice (`s8_*`) |
| `scripts/svet64/beh64.gd`, `blok64.gd`, `voda64.gd`, `mereni.gd` | E50 svět 8 × 8 v jemných buňkách: běh a tabulka časů, jeden blok n × n × 4n (navázání, vrstvy, minerály, dutiny), voda na jemné mřížce (povrch + podzemí), čas a paměť (`s64_*`) |
| `tools/test_svet64.gd`, `tools/gif_svet64.py`, `scripts/uzly/scenario_svet64.gd` | E50 měření, GIF po fázích, izo snímek z `shots/svet64/` |
| `scripts/eroze51/mech.gd`, `hydro.gd`, `halda.gd`, `scenare.gd`, `beh51.gd` | E51 mechanika toku: odpočty eroze a nánosu ve frontě událostí, Manning a rychlost v tůni, halda s generacemi, scénáře koryto/tůň/hráz/výkon, běh a tabulka (`e51_*`, prahy v `sdilene/materialy_voda.json`) |
| `tools/test_eroze51.gd`, `tools/shots_eroze51.py` | E51 testy + měření, snímky `51_*` z `shots/eroze51.json` |
| `scripts/podzemi52/cache.gd`, `ug_slovnik.gd`, `ug_pole.gd`, `ug_mrizka.gd`, `ug_funkce.gd`, `ug_darcy3d.gd`, `testy52.gd`, `beh52.gd` | E52 podzemí: cache světa svet64, obal slovníkové verze, plochá pole s limitem hloubky, převod hrubé mřížky, funkce nad vrstvami (`nadrz` / `preliv` / `darcy` 2D), Darcy 3D konečnými objemy + CG (Jan 22:40), demo testy E47d, běh jedné varianty (`p52_*`, `s64_ug_n`, `s64_ug_alg`) |
| `tools/podzemi52.sh`, `tools/podzemi52.py`, `tools/test_podzemi52.gd`, `tools/cache_podzemi52.gd` | E52 všechny varianty po procesech, tabulka a snímky `52_*` |
| `scripts/plosne53/rozliv.gd`, `mvoda.gd`, `beh53.gd`, `tools/plosne53.gd`, `tools/plosne53_np.py`, `tools/plosne53_roz.py`, `tools/shots_plosne53.py` | E53 průchody celým polem: pravidlo rozlévání (celé buňky, šířka ceil(Q/k), hromadění, zpětná vazba koryta), mělká voda (trubky), vektorové pole, numpy odhad paralelizace (`p53_*`) |
| `scripts/dohnani54/beh54.gd`, `tools/test_dohnani54.gd` | E54 klient / server: dohnání 60 dní jedním skokem vs. po dnech (otisk), přepočet s ranným zastavením po výkopech, bilance (kontinuita + celková) po každém přepočtu (`e54_*`) |
| `scripts/podzemi52/ug_funkce.gd` (`auto`, `floor_of`), `scripts/podzemi52/testy52.gd` (`run_e55`), `tools/test_podzemi55.gd`, `tools/shots_podzemi55.py` | E55 režim podle materiálu pod tělesem: nepropustné dno (perm ≤ `p55_perm_dno` 0,05) → preliv, propustné → nadrz, smíšené → průsak dnem, zbytek nejnižším výstupem |
| `scripts/svah56/svah.gd`, `beh56.gd`, `tools/svah56.gd`, `tools/shots_svah56.py` (+ `s56_*` v `svet8/hruby_teren.gd`, `svet8/beh.gd`) | E56 omezovač sklonu hrubého světa (tepelná eroze, zachová hmotu), vyhlazení, širší paty hor; výchozí vypnuto |
| `scripts/alg58/bq58.gd`, `ug58.gd`, `povrch58.gd`, `rec58.gd`, `tools/alg58_rec.gd`, `alg58_ug.gd`, `alg58_tok.gd`, `alg58.sh`, `shots_alg58.py` (+ `voda/tok.gd` `FLOOD_DZ`, výchozí 0) | E58 A kbelíková fronta (stejné pořadí jako halda), B graf těles (souhrny + kandidáti výstupu), C stopa a delta po výkopu; povrch A / B (graf pánví) / C |
| `tools/materialy59.py` → `../sdilene/materialy_voda_navrh.json` | E59 návrh: K, n, Sy, ret, perm (log škála), ero_v / sed_v, čas průsaku 1 m v herních dnech a reálných minutách; jen návrh |
| `tools/test_svet8.gd`, `tools/gif_svet8.py` | E49 měření a GIF po fázích |
| `data/mineraly_hostitele.json` | minerál → povolení hostitelé, tvar a parametry růstu (názvy materiálů ze `sdilene/materialy_voda.json`) |

## Determinismus (server)
Výsledek je čistá funkce (stav sousedů, tvar, seed, pořadí vložení). Server by mohl ukládat jen pořadí
(slot, blueprint, seed) a svět přehrát. Pole hranic vrstev jde držet jako mezivýsledek pro rychlost. Výpočet je v desetinných
číslech (float64, pevné pořadí operací). Shoda klientů v C# a GDScript se zatím neověřovala (viz otevřené otázky v `PROP.md`).

## v2: tabulka pořadí hornin a profily vrstev
Vrstvy už nejsou pět vrstev gen-v3. Berou se z Janovy tabulky pořadí 64 hornin [10] v `data/poradi_hornin.json`:
zóny 0–12 plášť, 13–25 krystalinikum, 26–39 sedimenty, 40 ornice, 41–61 hory, 62–63 vzduch. U každé horniny je
pořadí, zóna, hloubka, mocnost, četnost, vlastnosti vody a hostěné minerály. Na místě je aktivní jen uspořádaná podmnožina
(výchozí 17, `--rocks_on=…`, `--rocks_off=…`). Mocnost vrstvy se mění podle světového šumu a hranice zón jsou vlnité.
Pak se přidá deformace podle typu blueprintu (Janova skica [11] a představa [12]):
- **mírné** (louka, kopec, svah, prohlubeň): vrstvy se ohnou s povrchem, hluboko méně, pod prohlubní se prohnou;
- **hora**: antiklinála, vršek krystalinika se v jádru zvedne pod povrch, sedimenty se na úbočí ztenčí, nahoře horské horniny podle výšky a sníh;
- **sopka** (nový typ): vrstvy se ke kráteru strmě zvedají a sbíhají, uprostřed sopouch (id 75) až ke dnu kráteru.

Speciální tělesa: kimberlitový komín (diamanty), solný dóm, pegmatitové žíly (drahokamy, Li/Sn/Ta), skarn na kontaktu
granitoidu s vápencem (Cu, Fe, granáty) [14][15]. Hostitelé minerálů jsou v `data/mineraly_hostitele.json` (v2, 11 minerálů).

```
./run.sh horniny        # snímky shots/46_horniny_*.png s legendou + kontrola hash (shots/hash_horniny.txt)
./run.sh horniny-test   # měření v2 -> shots/bench_horniny.txt
python3 tools/make_tables.py   # znovu vygeneruje obě tabulky v data/
```
Snímky: `46_horniny_rez_nizina.png`, `46_horniny_rez_hora.png`, `46_horniny_rez_sopka.png`, `46_horniny_iso.png`,
srovnání se skicou `46_horniny_srovnani_skica.png`. v1 (`./run.sh shots`, `./run.sh test`) běží dál s `PR.v1()`.

| soubor v2 | co dělá |
|---|---|
| `scripts/bp/horniny.gd` | načte tabulku pořadí, aktivní vrstvy zóny, horské horniny, tělesa, paleta barev |
| `scripts/bp/geo2.gd` | zdvih, hranice zón, profily mirne/hora/sopka, vyplnění sloupců, tělesa |
| `scripts/bp/tests_horniny.gd`, `tools/test_horniny.gd` | měření v2 |
| `scripts/uzly/scenario_horniny.gd`, `legend.gd` | sled 7 blueprintů, řezy a legenda |
| `../sdilene/horniny_voda.json` | **nový** soubor s vlastnostmi vody pro nová id. Původní `materialy_voda.json` je beze změny. Kopie `voda_params` obě tabulky sloučí. |

## Funkční API (v2, nezávislé na rozlišení, Jan 16:42–16:56)
Buňky jsou jen **vzorky**. Materiál se počítá funkcí bodu světa v **metrech** ve středu buňky (`scripts/bp/geo_fn.gd`).
Parametry funkcí leží na řídicí mřížce s roztečí 0,5 m (16 × 16 bodů na blok 8 × 8 m): povrch `hm_f` a hranice vrstev
`bs[k]`. Mezi body se interpoluje bilineárně a u švu se berou body souseda, takže funkce je spojitá i přes šev [18].
Šumy mají frekvenci v 1/m a vstup ve světových metrech.

| funkce | co vrací |
|---|---|
| `world_fn(slots, own)` | kontext světa: záznamy bloků (`hm_f`, `bs`) a rozpracovaný blok |
| `block_info(wf, slot, bp, p)` | konstanty bloku: profil tvaru, vrstvy zásoby, tělesa se středy v m, šumy |
| `surface_m(wf, slot, X, Y)` / `boundary_m(wf, slot, k, X, Y)` | výška povrchu / vršek vrstvy k v m |
| `column(wf, info, X, Y)` | povrch a všechny hranice v jednom sloupci (cache) |
| `material(info, col, X, Y, Z)` | MaterialId v bodě: sníh, tráva, půda, horská kůže, vrstvy, tělesa (komín, dóm, žíly, skarn), sopouch |
| `sample(wf, info, n, x0, x1, cells)` / `sample_all(wf, info, n)` | buňky n × n × 4n (buňka 8/n m), index `(x · n + y) · 4n + z` |
| `minerals(cells, n, wf, info, materials, seed)` | minerály, potom dutiny. Cíl = počet × (n/16)³, takže objem zůstává |
| `mineral_one(...)` / `cavity_one(...)` | jedno ložisko / jedna dutina: střed ve spojitém prostoru, výběr buněk podle potenciálu φ, schodek |

**Navázání na sousedy** (`pipeline.gd steps_v2`, `strata.gd continue_thick`) se počítá v **mocnostech** vrstev.
Okrajový řídicí bod dostane přesně mocnost souseda (Dirichlet). **Strana bez souseda** (rozhodnutí Jana 17:38) má vrstvy,
které definuje sám blueprint: regionální funkce hranic bez tvaru a šumu blueprintu, ale s **jeho vlastní podmnožinou hornin**
(`rocks_on`/`rocks_off`). U volné strany se tedy nic nevyklíní. V rohu má skutečný soused přednost. Do vzdálenosti `taper_m`
(výchozí 3 m) se rozdíl harmonicky rozplyne do vlastního tvaru blueprintu, dál platí jen tvar a šum. Hranice jsou součtem
mocností. Povrch se dorovnává stejně (`band`), na volné straně k `surf_ref`.

**Klíny** [16][17]: všechny bloky mají hranice pro celou *zásobu* vrstev (`HR.pool`: výchozí aktivní + `layer_pool`).
Vrstva, kterou blueprint nemá (`rocks_off`), má mocnost 0. Když ji soused má, okraj převezme jeho mocnost a klín se
do `taper_m` ztenčí na 0. Když ji naopak nemá soused, vrstva se k té straně vyklíní. Vynucení vrstvy: `rocks_on`.

**Dutiny** (Jan 16:56): v seznamu materiálů blueprintu je klíč `250` = VODA (podzemní rezervoár) a `0` = VZDUCH (jeskyně).
- Rezervoár je dutina v nepropustné hornině (perm = 0 ve sdílené tabulce). Každá buňka má do 0,5 m ve všech 6 směrech jen
  nepropustného hostitele. Dutina se celá zaplní vodou a validátor gen-v3 ji počítá do vody.
- Jeskyně je dutina v nosné hornině, ne v půdě, písku, štěrku, spraši, jílu, slepenci ani prachovci. Je ≥ 2 m pod povrchem
  a ≥ 2 m nade dnem, nad každou buňkou je nosný strop ≥ 1 m. Přednostně leží v karbonátech (kras) [19].
- Počty se škálují stejně jako u minerálů. Když hostitel chybí, vznikne schodek.
- **Nejvýš jedna dutina na blok** (Jan 17:38): blok má buď nic, nebo právě jeden rezervoár, nebo právě jednu jeskyni.
  Tvar je jedno, generátor vytvoří jednu souvislou dutinu kolem jednoho středu. Blueprint s VODOU i VZDUCHEM
  **`BP.validate` odmítne** (`blueprint.cavity_conflict`). Generátor (`pipeline` i `FN.minerals`) pak neudělá žádnou
  dutinu a chybu nahlásí v `rep.blueprint`. Za autora nevybírá, protože nevíme, co chtěl. Test je v `bench_horniny.txt`, sekce Dutiny.

**Pevnost** (Jan 16:58, jen data, výpočet ne, Jan 17:01): `load` (kolik buněk 0,5 m unese nad sebou) a `cantilever`
(kolik buněk převisne). Jsou v `sdilene/materialy_voda.json` (nová pole, staří čtenáři je ignorují), v
`sdilene/horniny_voda.json` a v `data/poradi_hornin.json`.

**Typy hor:** `hora_vyzdvizena` má jádro z hluboké horniny až k vrcholu, sedimenty a hlína zbydou jen na úpatí [12].
`hora_zvrasnena` je antiklinála, ve které se všechny vrstvy klenou celé a hlubší méně [11]. Dál `sopka` a mírné tvary
(louka, kopec, svah, prohlubeň = jezero, pod ním se vrstvy prohnou).

Snímky: `46_horniny_klin.png` (skica, profil mocností a 3D řez), `46_horniny_rozliseni.png` (16 vs. 32 a neshoda),
`46_horniny_rezervoar_jeskyne.png`, `46_horniny_rez_hora_vyzdvizena.png`, `46_horniny_rez_hora_zvrasnena.png`.
`./run.sh horniny` po snímcích spustí `tools/compose_shots.py`, které použije `shots/bench_horniny.txt` z `./run.sh horniny-test`.

## v3: eroze po vrstvách, voda, grafy funkcí, svět 8 × 8 (Jan 17:47–18:05, výsledky v PROP.md E47–E49)
**Eroze po vrstvách (E47):** eroze mění jen funkci povrchu `hm_f`. Původní povrch se uloží jako `hm_pre`, hranice vrstev `bs`
se nemění. `geo_fn.material` pak: nad `hm_pre` je nános (`ero_deposit`, výchozí štěrk/písek) pod drnem. V korytě se půda
a kůže hor měří od původního povrchu, takže eroze prořízne půdu a odkryje horninu. Bez eroze se chová stejně jako dřív.
Režim `okraj` násobí změnu smoothstepem od švu (pás `taper_m`), takže okraj zůstane přesně hodnota souseda. Jen tenhle
režim je nezávislý na pořadí vkládání. `svet` je pro svět generovaný celý naráz.
Voda: `voda_sim` (beze změny pravidel) na výřezu celého světa, okraje světa otevřené, chybějící blok = nepropustná stěna.

**Voda E47b/c (Jan 19:14–19:48):** déšť je jen vizuální. Voda teče jen z **pramenů** (zvláštní buňka, stálý průtok l/s; zasypaný neteče,
odkopaný teče znovu). Tok je **uložené koryto** (priority-flood + D8 + ztráty) a strže se z něj zahloubí, medián ~2 m. Když se nic nemění,
nic se nepočítá. Po změně terénu u vody se přepočítá jen okno a cesta po proudu, dokud se průtok mění. **Prohlubeň** má odtok
D = Σ perm · `pit_drain_q`. Plní se rychlostí přítok − D a časy vrstev jsou předpočítané události. Plná pošle D podzemím
k vyvěračce ve stěně ostrova a zbytek přeteče. D ≥ přítok → ponor. **Okraj mapy = okraj plovoucího ostrova:** voda tam přepadá
do mlhy a dál se nesimuluje. Chybějící slot je stěna. Varianta `voda_zdroj=plocha` je srovnání s vodou z plochy (E47b).

**Svět 64 (E50, Jan 20:04–20:09):**
- Stejný svět jako E49, ale bloky se vzorkují v 64 × 64 × 256 buňkách (0,125 m). Funkce na řídicí mřížce 16 × 16 se
  nemění a minerály i dutiny drží objem (× (n/16)³).
- Voda běží na jemné mřížce. Parametry v buňkách a na sloupec se přepočtou f = n/16 (`voda64.scaled`, `voda_cell_m`).
- `--s64_voda_n=32` spustí vodu a podzemí na hrubší mřížce.
- Časy fází a bloků, RSS a peak jsou v `shots/bench_svet64.txt`.
- GIF a izo se renderují z `shots/svet64/` zvlášť od generování.

**Eroze E51 (Jan 20:18–20:37):**
- Každý materiál má odpočet = kolik m³ vody musí přes buňku protéct, než ji odnese (`ero_vol`), ale jen když rychlost
  proudu v ≥ `ero_v`. Ve stojaté vodě (v < `sed_v`) se usazuje nános. Rychlost z Manningovy rovnice, v tůni Q / (hloubka · √plocha).
- Žádné tiky: jedna halda událostí, položku mají jen mokré sloupce. Odnesení, nános nebo kopání → `TOK.update` po proudu
  a přeplánování dotčených sloupců. Kopání a položení odpočet vynuluje.

**Podzemí E47d (Jan 20:00):** odtok tůně vstoupí do nejbližšího propustného tělesa pod ní (propustná hornina, kras nebo
dutina, 6-sousedé ve 3D buňkách). Voda **sleduje vrstvu**: těleso se plní po vrstvách z jako tůň (dutina celá buňka,
hornina pórovitost) do nejnižšího výstupu. Výstup je pramen ve svahu nebo stěně, výtok do tůně (např. 4 × 4) nebo stěna
ostrova (do mlhy). Výtok na povrchu se stane novým zdrojem koryta a povrch s podzemím se iterují do ustálení. Zaplněná
dutina = podzemní jezero. Uzavřené těleso bez výstupu se naplní a dál nic nepřijímá.

**Grafy funkcí (E48):** `FN.surface_m` a `FN.boundary_m` vzorkované 25 × 25 na blok. Vrstva se nekreslí, kde má mocnost
< 3 cm (vyklínění) nebo leží nad povrchem. Jádro hory, sopouch a tělesa nejsou hranice, takže v grafech nejsou.

**Svět 8 × 8 (E49):** blueprint může nést `base_hm` (povrch z hrubého světa, 16 × 16 v buňkách), `base_off` a `base_seed`.
Šablona tvaru se pak nepoužije, typ (`shape`) řídí jen geologii a jemný šum je ve světových souřadnicích. **Volná strana povrchu**
takového blueprintu = hrubý svět na vlastním okraji (regionální základ). Vrstvy na volné straně dál podle podmnožiny blueprintu
(Jan 17:38). **Roh povrchu:** skutečný soused má přednost před regionálním základem (`surface.gd adapt(..., real)`, jako
u mocností). Sled 46 i v1 dávají stejný hash jako dřív. Typ hory se volí po souvislých masivech (`s8_massif`).
Barvy typů v `49_svet_8x8_dlazdice.png`: světle zelená louka, olivová kopec, béžová svah, modrá prohlubeň, cihlová
hora vyzdvižená, fialová hora zvrásněná, červená sopka. Biomy: modrá jezero/řeka, světle zelená niva, tyrkys mokřad,
zelená louka, tmavě zelená les, písková step, šedá skály, bílá sníh.
