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
```
Všechny parametry jsou v `scripts/bp/params.gd`. Hlavní jdou ladit i v Inspectoru na uzlu `Svet`.

## Scéna (uzly, žádný monolit)
`main.tscn`: `Main` → `World` (WorldEnvironment, Sun) · `CameraRig` (Camera3D) · `Svet` (stav světa a parametry) ·
`Placer` (vkládání po snímcích, signály `progress` a `finished`) · `BlockViews` (kreslení bloků a řezů) · `Preview`
(průhledný náhled) · `UI` (Hud a panel Prubeh s ProgressBar) · `Scenario` (ukázkový sled, režimy).

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
