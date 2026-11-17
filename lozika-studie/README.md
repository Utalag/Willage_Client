# Studie generování podzemí: ore-v0 → cave-v0 → **gen-v3** (zásobník ze serveru) – Willage

Samostatná studie v Godotu 4.7.2 (Compatibility), nezávislá na `godot-prototyp` (ten se neměnil, git také ne). Generátor terénu je zkopírovaný
z prototypu (`scripts/block_gen.gd`, jediná změna: přepínač `legacy_ore`, který vypne šumové rudy prototypu).

**Stav 20:05:** gen-v3 (verze `gen-v3-study-4`) (`willage-backend/generovani-bloku-v3.md`, Jan 18:45–18:58) **nahrazuje** horniny STRATA, ore-v0 i cave-v0.
ore-v0 a cave-v0 zůstávají ve studii jako archiv a zdroj kódu (růst semínek, záložní stupně, schodek, maska jeskyní, kontrola vody).
Nic z toho není schválené Janem ani zapojené v prototypu.

## Spuštění
```
./run.sh gen3          # vectors/gen_v3_vectors.json (11 případů: zásobník dovnitř, počty ven)
./run.sh gen3-stress   # shots/gen3_stress.txt: 15 seedů × 4 recepty × 6 měřítek
./run.sh gen3-sim      # shots/gen3_sim.txt: simulace voda-studie, negativní testy validátoru a zásobníku
./run.sh gen3-shots    # shots/39_genv3_*_v3.png
./run.sh gen3-ablation # shots/gen3_ablace.txt: vliv (a), (b), (c), (e) zvlášť
./run.sh caves | cave-sim | cave-stress | cave-shots     # cave-v0 (archiv)
./run.sh vectors | stress | bench | shots                # ore-v0 (archiv)
```

## Soubory
| soubor | co dělá |
|---|---|
| `scripts/gen_v3.gd` | **gen-v3 generátor** (materiálově agnostický): `generate_bytes(terén, hm, seed, bajty zásobníku, voda)`, vsakování, `validate` |
| `scripts/gen3_stack.gd` | binární zásobník: tabulky tvarů, `encode` / `decode` (+ `world.stack_invalid`), `hash` (SHA-256) |
| `scripts/gen3_server.gd` | **zástupce serveru**: katalog materiál → tvar + parametry, sestaví a seřadí zásobník |
| `scripts/gen3_tests.gd` | souhrn ze zástupce serveru, vektory, zátěž, simulace, negativní testy, míra vrstevnatosti |
| `scripts/ore_v0.gd` | růst semínek (čočka / sloj / žíla / sál), záložní stupně L1–L5, schodek – sdílené s gen-v3 |
| `scripts/cave_v0.gd`, `cave_tests.gd` | cave-v0 (archiv): jeskyně, rezervoáry, pánve, kontrola vody |
| `scripts/voda_sim.gd`, `voda_mat.gd`, `voda_params.gd` | kopie simulace z `voda-studie` (jen cesta preload) |
| `scripts/main.gd` | režimy a snímky |
| `scripts/block_gen.gd`, `block.gd`, `mat.gd`, `stable_hash.gd`, `veg.gd`, `mesher.gd` | kopie z prototypu (`mat.gd`: + ložiskový jíl 12 a barvy náhledu 13–15) |

# gen-v3: zásobník materiálů do neurčeného objemu (stav 20:05, `gen-v3-study-4`)

Rozhodnutí: Jan 18:45–18:59 (zásobník ze serveru, jedna fáze, binární kódování), **19:18** (jedna tabulka propustnosti, varianta 2: kámen = zbytek, hlína jen u povrchu),
**19:19** (a) voda podle nejnižšího okraje bloku, (b) zadržená voda nad jílem a v písku, (c) rudy i v kameni, (d) kontrola Σ na serveru, (e) rychlost).

## Tok
1. **Tvar:** povrch z receptu a seedu (generátor prototypu). Povrchová slupka (tráva, sníh) zůstává. Všechny buňky pod povrchem jsou **neurčené** (`UNSET`, interně `Mat.FOG` id 11, nikdy v zásobníku ani v bloku). `V` = počet buněk pod povrchem bez slupky.
2. **Server** vydá **zásobník** (seřazený, klient neřadí) a objem vody `W`. Pořadí zástupce serveru (`gen3_server.build_stack`):
   skupina 0 = běžné položky od nejméně početné (při shodě MaterialId), skupina 1 = kameny `stratum` odspodu (čedič, žula, vápenec), skupina 2 = rudy v kameni (`host`).
3. **Klient** zpracuje položky v daném pořadí. Každá položka se šíří jen do `UNSET`, ruda s `host ≥ 0` jen do svého hostitele (přepíše ho). Stream náhody = `mix(seed, "GEN3", pořadí)`.
4. **Pravidlo objemu:** Σ počtů položek bez hostitele = `V` přesně (jinak `world.stack_invalid volume_mismatch`). Hlína je běžná položka (vrstva u povrchu), kámen dostane zbytek.
5. **Voda:** `W` se nalije na povrch a vsákne (viz níže). **Kontrola** jako na serveru: přesné počty, voda podle pravidel stability.

## Zásobník: binární kódování (dohoda s Willage-backend 18:59, beze změny)
Položka: `u16 mat_id, u32 count, u8 shape, u16 params_len (= 4·n), n × i32` (vše little-endian). Zásobník = `u16 počet` + položky. `stack_hash` = SHA-256 bajtů zásobníku.
Chyby `world.stack_invalid`: `unknown_shape`, `params_len`, `truncated`, `trailing_bytes`, `material` (FOG nebo id ≥ 13), `param_range`, `lz_band`, `host_order`, `volume_mismatch`.

### Tabulka tvarů (pořadí parametrů)
| tvar | id | parametry (i32) | význam |
|---|---|---|---|
| pocket | 1 | `maxHeap, lzMin, lzMax, host` | čočky; `host` = −1 → do UNSET, jinak MaterialId hostitele (**nové 19:19, dřív 3 parametry**) |
| layer | 2 | `maxHeap, lzMin, lzMax, pH_u16, pV_u16` | sloj; pravděpodobnost růstu do strany / svisle × 65535 |
| vein | 3 | `maxHeap, lzMin, lzMax, inertia_permille, branch_permille, host` | žíla; `host` jako u pocket (**nové 19:19**) |
| chamber | 4 | `maxHeap, lzMin, lzMax, pH_u16, pV_u16, roof, margin` | jeskyně (vzduch); `roof` = min. buněk nad stropem, `margin` od stěn bloku |
| stratum | 5 | `amp_tenths, scale` | **nové 19:19 (e):** velká vrstva kamene po sloupcích; zvlnění ± amp/10 buněk, měřítko šumu v buňkách |

Rozsahy: `maxHeap` 1..4096, `lz` −63..63, `host` −1..12, `amp_tenths` 0..160, `scale` 1..64, permille 0..1000.
**`lz` záporné = hloubka pod vlastním povrchem sloupce** (−1 = první buňka pod povrchem; dřív hloubka od nejvyššího bodu bloku), kladné = absolutní výška buňky v bloku.
Pravidla hostitele: hostitel musí být v zásobníku dřív (`host_order`), rudy s hostitelem se nepočítají do `V`, výsledný počet hostitele = vydáno − Σ jeho rud.

### Katalog zástupce serveru (`gen3_server.gd`) a příklad louka 101
| materiál | tvar | parametry |
|---|---|---|
| hlína 2 | layer | 200, −4, −1, 58982, 3276 |
| písek 3 | layer | 80, −6, −1, 52428, 6553 |
| jíl 4 | layer | 80, −7, −2, 52428, 6553 |
| ložiskový jíl 12 | layer | 120, −10, −3, 52428, 6553 |
| vzduch 0 (jeskyně) | chamber | 60, 3, 44, 40632, 19660, 2, 1 |
| čedič 7 / žula 6 / vápenec 5 | stratum | 25, 6 / 30, 5 / 20, 7 (odspodu v tomto pořadí) |
| měď 8 | vein | 18, 8, 40, 700, 80, **6 (žula)** |
| železo 9 | pocket | 22, 4, 36, **7 (čedič)** |

Zásobník louka 101 (pořadí, materiál × počet): ložiskový jíl 43 · vzduch 132 · jíl 181 · písek 267 · hlína 534 · čedič 2692 · žula 2650 · vápenec 1133 · měď 31 (v žule) · železo 33 (v čediči).
Σ bez rud = 7632 = `V`; 264 bajtů, `stack_hash feb39c4c…d1d152`. Celé bajty v `vectors/gen_v3_vectors.json` (`stackBytesHex`).

## Rozmístění
- Běžné položky: maska pásma (`depth_mask` po sloupcích, `chamber_mask` pro jeskyně) → `ore_v0.place` (semínka, L1–L3, schodek) → L4 dosazení bez masky do nejbližších volných buněk, aby počet seděl vždy přesně → u vrstev `_fill_holes` (záměna osamělých děr).
- **Stratum (e):** klíč = z + hladký 2D šum (amp, scale), buňky UNSET seřazené podle klíče (přihrádky), vezme se prvních `count` odspodu. Žádné BFS, přesný počet zadarmo.
- Na konci `_swap_specks` (místní hledání do vzdálenosti 4): osamělé buňky kamene a hlíny se vymění se sousedem stejného materiálu, počty se nemění.

## Jedna tabulka vlastností (Jan 19:18, `../sdilene/materialy_voda.json`, verze 3)
Jediný zdroj pravdy pro gen-v3, cave-v0 i voda-studie (`voda_params.apply_shared_table`, bez souboru chyba). Vápenec **perm 0, por 0** (dřív 0,10 / 0,15).
| materiál | perm | por | res | ret |
|---|---|---|---|---|
| tráva | 0,25 | 0,40 | 0,85 | 0,15 |
| hlína | 0,30 | 0,40 | 0,40 | 0,15 |
| písek | 0,80 | 0,35 | 0,25 | 0,05 |
| jíl, ložiskový jíl | 0 | 0,45 | 0,10 | 0 |
| vápenec, žula, čedič, rudy | 0 | 0 | 0,05–0,10 | 0 |
`perm_leak` 0,05 (pod tím buňka vodu nepustí), `perched_depth` 2. Kapacita buňky pro gen-v3 = `por`, jen když `perm > perm_leak`.

## Voda
1. **(a) Přidělení podle nejnižšího okraje bloku (Jan 19:19, varianta C):** server dá `W = min(voda z receptu, přidělení)`,
   `přidělení = ⌊buňky v hloubce 2..D pod okrajem × 0,40 × podíl hlíny + písku mezi položkami u povrchu × 0,4⌋` (`gen3_server.water_allotment`).
   Každý blok je tak stabilní sám o sobě. **Tok mezi bloky není implementovaný**: až v simulaci voda-studie po načtení sousedů (hrany pod povrchem zavřené, voda nad okrajem by přetekla k sousedovi).
2. **(b) Zadržená voda:** písek nad hladinou drží `ret` (0,05 × buňka); hlína a tráva drží `ret` (0,15), jen když je do 2 buněk pod ní jíl nebo ložiskový jíl a mezi nimi jen propustné buňky (voda „visí“ nad jílem).
   Vsakování: oblast propustných buněk spojených s povrchem (a vzduch pod okrajem), iteruje hladinu: nad hladinou se nejdřív plní zadržení shora, zbytek pod hladinu odspodu. Co se nevejde = odtok (`shortfall.water_units`, celé jednotky).
3. Simulace voda-studie zná `ret` taky: voda ≤ `ret` se nehýbe (nepadá, neteče do stran), takže zadržená voda v simulaci nestéká.

## Kontrola
- **Server při vydání (d)** `gen3_server.check_stack(items, V, W, přidělení)`: `world.summary_over_volume` (Σ > V − slupka), `world.summary_under_volume`, `world.summary_host_overflow` (rudy > hostitel), `world.water_over_rim_allotment`.
- **Blok (`gen_v3.validate`, jeden průchod, e):** jedna smyčka přes 16 384 buněk spočítá materiály, vzduch jeskyní, součet vody, kontroly buněk a seznam mokrých buněk; BFS jen z mokrých buněk.
  Hladina = nejvyšší buňka s vodou nad `ret`; pod ní vše nasycené, nad ní voda ≤ `ret` a žádná volná voda. Chyby `world.summary_mismatch`, `world.water_mismatch`, `world.water_unstable` (`water_in_impermeable`, `not_saturated_below_level`, `above_block_rim`, …).

## Výsledky (20:02)
### Vektory (`vectors/gen_v3_vectors.json`, 11 případů, deterministické: dva běhy, `cmp` shodné)
Všech 11 přesně, validátor OK, kontrola serveru čistá, odtok 0 ve všech případech (i voda ×5 a ×20: přidělení 171 a 244 místo 470 a 2520).
Čistota vrstev 0,93–0,96 (prototyp 0,91–0,96), hranice 0,017–0,026, tečky kamene 0–9, zadrženo 8–55 objemů na blok.

### Ablace (`shots/gen3_ablace.txt`, 21 bloků, voda ×1 / ×5)
| varianta | čistota | tečky kamene | odtok ×1 / ×5 (objemy na blok) | zadrženo | Cu+Fe v kameni | ms rozmístění / voda / kontrola |
|---|---|---|---|---|---|---|
| v3 vše | 0,946 | 2,6 | 0,0 / 1,1 | 25,3 | 63 % | 22,3 / 4,7 / 5,1 |
| bez (a) | 0,946 | 2,6 | 5,6 / 418,6 | 24,4 | 63 % | 23,2 / 4,8 / 5,1 |
| bez (b) | 0,946 | 2,6 | 1,5 / 3,3 | 0 | 63 % | 22,6 / 3,1 / 3,9 |
| bez (c) | 0,947 | 2,5 | 5,3 / 5,3 | 23,5 | 47 % | 25,4 / 5,2 / 5,7 |
| bez (e) (kámen přes BFS) | 0,809 | 4,4 | 0,0 / 3,5 | 22,3 | 58 % | 93,2 / 4,5 / 4,8 |
„Cu+Fe v kameni“ = podíl buněk rudy, které mají aspoň 4 ze 6 sousedů kámen (sousední ruda se nepočítá, proto ani v (c) není 100 %). Bez (c) jdou rudy do UNSET dřív než kámen a 3/21 bloků má odtok, protože rudy ubírají propustný objem u povrchu.

### Zátěž (`shots/gen3_stress.txt`, 360 bloků)
360/360 přesně, validátor 360/360. Čistota 0,93–0,96 proti prototypu 0,92–0,94. Tečky kamene 1,3–9,9 na blok, hlíny ≤ 1,5, hlína > 4 pod povrchem 0–17.
Rozmístění 16,7–28,8 ms, voda 3,5–8,7 ms, kontrola 4,4–6,4 ms. Odtok zůstává jen u kopce a hory (27–73 objemů na 15 bloků), i když voda je pod přidělením, protože odhad přidělení počítá s průměrným podílem hlíny.

### Srovnání verzí (zátěž 360 bloků)
| verze | čistota vrstev | tečky kamene / blok | rozmístění | voda | kontrola |
|---|---|---|---|---|---|
| v1 18:59 (hlína = zbytek) | 0,80–0,86 | 7–32 | 36–64 ms | 15–40 ms | 15–20 ms |
| v2 19:30 (kámen = zbytek, BFS) | 0,80–0,83 | 3–18 | 75–104 ms | 13–47 ms | 17–22 ms |
| **v3 20:02 (a–e)** | **0,93–0,96** | **1–10** | **17–29 ms** | **3,5–8,7 ms** | **4,4–6,4 ms** |
| prototyp STRATA | 0,91–0,96 | – | 17–21 ms | – | – |

### Simulace voda-studie (`shots/gen3_sim.txt`, 400 tiků, odpar 0, strany zavřené, sdílená tabulka)
Posun objemu ~0, přesunuto 0,003–0,065 objemu, odtok 0, ve vápenci 0. Kontrola: simulace **bez** `ret` by z louky 101 přesunula 14,8 a z piscina 4504 52,4 objemu (zadrženo 17,1 / 54,8), takže `ret` v simulaci je nutné.
Negativní testy: 3 úpravy bloku, 7 úprav zásobníku a 4 chyby `check_stack` – vše odmítnuto se správným kódem.

## Snímky
`39_genv3_rez_{louka,kopec,hora,piscina}_v3.png` (řez, vlevo prototyp, vpravo gen-v3), `39_genv3_mokro_v3.png` (voda ×5), `39_genv3_jeskyne_v3.png`. Verze `_v2` (19:30) zůstávají pro srovnání.

## Problémy a návrh řešení
1. **Hlína hluboko při L4 dosazení:** louka 404 má 83 buněk hlíny > 4 pod povrchem (ostatní 0–17), protože L4 kvůli přesnému počtu běží bez masky. Návrh: L4 v rozšiřujících se pásmech hloubky (−1..−8, pak −1..−16, …).
2. **Odhad přidělení vody** (bezpečnost 0,4) je konzervativní (louka 404: 244 proti ~288 skutečné kapacitě) a u kopce a hory přesto občas něco odteče. Přesné by bylo, kdyby server spočítal kapacitu z tvaru stejně jako klient (stojí 4–9 ms), nebo kdyby odtok uznal.
3. **Tok mezi bloky** jen v pozdější simulaci (viz Voda bod 1).
4. **Jednotka vody ve WVB1** (65535 vs 4096 za plnou buňku) zůstává otevřená, studie používá 4096.

## Co je znovu použité
`ore_v0.place` (semínka, L1–L3, schodek), `_grow`, `_grow_vein`, `_grow_bodies`, `_scan_host`, `_tall`; maska jeskyní z `cave_v0.eligibility` (zobecněná na `roof`, `margin`);
`cave_v0.cave_air`, myšlenka pánví a kontroly stability; `cave_tests.make_sim` (simulace voda-studie); vykreslení `_water_mesh`, `_cave_ghost`, `_add_block`.

# cave-v0: jeskyně a vodní rezervoáry (archiv, nahrazeno gen-v3)

Jan 18:33: „Přidej do generování země i vzduch jako jeskyně a vodní rezervoáry. Seznam zemin bude obsahovat i vodu a vzduch. Voda však musí splňovat podmínky, aby neodtekla.“
Pořadí: terén → jeskyně → voda → rudy (rudy jeskyně nevyplní). Voda je samostatná vrstva u16 (4096 = plná buňka).
- **Tvary:** rezervoár (sál v žule/čediči, 125 % objemu vody, vyřezaný první z rozpočtu jeskyní), sál, chodba výšky 2, šachta. Maska: `ROOF = 2` buňky pod nejnižším povrchem sloupce a sousedů, `MARGIN = 1` od stran, ne lz = 0.
- **Voda:** pánve (souvislý jeskynní vzduch), únik = hrana bloku, dno bloku, povrch nebo propustný soused (perm > 0,05). Hladina = únik − 1, plní se odspodu vodorovně.
  Když pánev uniká přes propustného souseda, ten se zapečetí jílem (W1).
- **Výsledky:** 13 vektorů (`vectors/cave_v0_vectors.json`) přesně (vzduch, voda, rudy), validátor OK, dva běhy stejné. Zátěž 15 seedů × 4 recepty × 7 měřítek: 100 % jeskyní, 100 % vody, validátor 15/15,
  pečetění vzácné (≤ 1 blok na měřítko). Simulace voda-studie 400 tiků (odpar 0): drift ±0,000000, odtok 0, přesunuto ≤ 0,0011; negativní test (pánve plné po strop) drift −65,8 a 176 chyb validátoru.
  Kopání do rezervoáru: hora 1000 chodba 16 buněk → 15,6 objemu vody v chodbě, validátor po prokopání hlásí 1 chybu (pánev otevřená). ms: jeskyně 1,3–10,8, voda 1,4–4,6.
- **Problémy a opravy:** vápenec (perm 0,10) je podle prahu 0,05 propustný, což odporuje návrhu „vápenec nepropustný“ → rezervoáry v žule a čediči a pečetění;
  sál navíc v záloze vody by rozbil počet vzduchu → rezervoár první; jeskyně u hrany a pod povrchem → MARGIN a ROOF; WVB1 má vodu jednou 0..65535 a jednou v 1/4096 → studie používá 4096 (sjednotit);
  voda-studie odpařuje jen nejvyšší buňku sloupce, podzemní voda se neodpaří (OK); horní neúplná vrstva se dělí rovnoměrně.
- Snímky `shots/38_jeskyne_*.png` (louka, kopec, hora, řez, kopání).

# ore-v0 (archiv, nahrazeno gen-v3)
Podklad: `willage-backend/lozika-a-zily-v0.md` a rozhodnutí Jana 18:22–18:25 (server určí souhrn rud, klient rozmístí přesně, bitová shoda C# není potřeba).

### Algoritmus
Vstup je objem bloku po terénu a horninách (bez šumových rud) a cílový souhrn `{materiál → počet}`. Pro každou rudu v pořadí receptu
(měď, železo, jíl) běží vlastní proud náhody SplitMix64 ze `mix(seed, "ORE", specIndex)`.

**L0 – semínka podle ore-v0.** Počet semínek `n` z rozsahu receptu, aspoň `ceil(cíl / max zásoba)` (nejvýš 64). Každé semínko dostane
podíl cíle (váhy z rozsahu zásoby, rozdělení beze ztráty, součet = cíl). Umístění: náhodné `lx, ly`, `lz` z rozsahu, buňka musí být
hostitel, nejvýš 8 pokusů, jinak se semínko zahodí a jeho podíl jde do schodku pro další stupně.

**Šíření:**
- čočka (pocket) a sloj (layer): fronta FIFO, směry v pevném pořadí +x, −x, +y, −y, +z, −z. Soused se zařadí s pravděpodobností
  podle tvaru (čočka 0,55 všude, sloj 0,8 vodorovně a 0,1 svisle). Přepíše se jen hostitel a šíří se jen z přepsaných buněk.
  Buňka se označí při zařazení, takže žádná nejde do fronty dvakrát; neúspěšný hod se může zopakovat od jiného souseda.
- žíla (vein): fronta „hlav“ (buňka a poslední směr). Hlava pokračuje stejným směrem s pravděpodobností 0,7, jinak vybere směr podle
  vah (vodorovný 2, svislý 3, bez couvání). Když je cíl blokovaný, zkusí až 4 jiné směry, pak hlava končí. S `branchChance` 0,08 přidá
  druhou hlavu jiným směrem.
- vždy: nikdy přes hranici bloku, nikdy do vzduchu, mlhy, trávy, sněhu ani rud (měď, železo, jíl včetně základního jílu z půdy).
  Pravděpodobnosti jsou celá čísla: přijmout, když `u16 < floor(p · 65536)`.

**Záložní stupně, když cíl není splněný** (každý se spustí jen při schodku, vše se zapisuje do výsledku):
1. **L1 další semínka**: stejný hostitel a rozsah `lz`, místo se hledá skenem od náhodné buňky (najde hostitele vždy, když existuje), nejvýš 16 semínek.
2. **L2 dorůst tělesa**: BFS bez náhody ze všech buněk rudy do sousedního hostitele, v libovolné výšce.
3. **L3 celá výška**: další semínka v `lz` 0–63.
4. **L4 uvolněný hostitel** po úrovních (měď: + čedič, pak + hlína a písek; železo: + vápenec, pak + hlína a písek; jíl: + vápenec, pak + žula a čedič).
   Na každé úrovni nejdřív dorůst, pak semínka, pak znovu dorůst.
5. **L5 schodek**: co se nevešlo, se vrátí jako `shortfall` (nikdy potichu).

Dorůstání (L2) je záměrně před uvolněním hostitele: ruda zůstane v hornině z receptu, dokud to jde.

### Výsledky

#### Přesnost (vektory)
`vectors/ore_v0_vectors.json`: 24 případů, hlavní kontrola u každé rudy je `placed == target` a zároveň rozdíl počtu buněk v objemu == `placed`.
22 případů je přesně, 2 mají výslovný schodek (oba záměrně nad kapacitu bloku):
- `zatez_velky_cil_louka` (Cu 3000, Fe 3000, jíl 1500 na louce): jílu chybí 153, protože měď a železo předtím spotřebovaly horniny, do kterých by se jíl mohl uvolnit.
- `zatez_nad_kapacitu` (Cu 20 000): umístěno 7451, schodek 12 549.

Případy: 3 recepty × 2 seedy (stejné seedy jako `vectors.json`) s bonusem 0 % a 25 %, každý tvar zvlášť (na hoře 202 a v čistém hostiteli),
zátěž (obří cíle, malý hostitel 27 buněk žuly, cíl nad kapacitu, prázdný cíl) a blok s transformací (zrcadlení, 90°, posun +2).
Ke každému případu je i cíl, umístění, schodek, buňky po stupních L0–L5, počty semínek (plánovaná, umístěná, zahozená, další), souhrn materiálů
před a po, rarita-v2 po a SHA-256 i FNV-1a 64 vrstvy materiálů. Hashe slouží jen k opakovatelnosti v Godotu.
**Dva běhy dávají bajtově stejný soubor** (`cmp` OK).

#### Zátěž (`shots/stress.txt`, 40 seedů × 4 recepty)
Měřítko = násobek cíle ze `server_target`. Sloupce L1–L5 = podíl rozmístění rud (ruda × blok), kde ten stupeň běžel.

| recept | cíl | naplnění | L1 | L2 | L3 | L4 | L5 schodek | ms/blok |
|---|---|---|---|---|---|---|---|---|
| louka | bonus 0 % | 100 % | 28 % | 0 | 0 | 0 | 0 | 1,6 |
| louka | bonus 200 % | 100 % | 44 % | 2 % | 0 | 0 | 0 | 3,4 |
| louka | ×5 | 100 % | 54 % | 13 % | 2 % | 9 % | 0 | 6,5 |
| louka | ×20 | 99,1 % | 96 % | 44 % | 4 % | 27 % | 4,5 % | 29 |
| hora | bonus 0 % | 100 % | 32 % | 0 | 0 | 0 | 0 | 1,1 |
| hora | ×5 | 100 % | 47 % | 21 % | 13 % | 11 % | 0 | 7,9 |
| hora | ×20 | 100 % | 96 % | 34 % | 27 % | 27 % | 0 | 29 |
| píščina | bonus 0 % | 100 % | 16 % | 0 | 0 | 0 | 0 | 1,1 |
| kopec, píščina, všechny | ×60 | 49–57 % | | | | | 51–63 % | 66–70 |

Celá tabulka i pro kopec je v `stress.txt`. Při běžných cílech (bonus 0–200 %) je naplnění vždy 100 %. L1 běží v 16–44 % případů,
skoro vždy kvůli jílu: jeho hostitel je tenký pás půdy, takže 8 náhodných pokusů o semínko často minou.
Schodek se objeví až od ×20, tedy kolem 5000 buněk rud na blok.

#### Srovnání s prototypem a rarita
Prototyp (šumové rudy) má průměrně 16–23 buněk mědi a 25 buněk železa na blok. Výchozí recepty ore-v0 při bonusu 0 % dají 81 buněk mědi a 77 železa.
Rarita-v2 se tím posune z tříd 0–1 (běžná a neobvyklá) do 2–4. Na 40 seedech louky: prototyp [19, 19, 2, 0, 0], ore-v0 [0, 1, 15, 15, 9].
Prahy rarity nebo výchozí zásoby je potřeba přepočítat.
**Aktualizace ore-v0.2 (18:40, rozhodnutí backendu):** zásoby snížené na úroveň prototypu (Cu 8–18 na semínko, Fe 12–22), cíle server omezuje na 5× běžného průměru,
pořadí rud od nejvzácnějšího hostitele (jíl → měď → železo), ložiskový jíl má vlastní MaterialId 12, schodek ≤ 1 % na rudu se přijme (hlavička WVB1 `shortfall`).
Výsledek: Cu 17,6 a Fe 24,2 buněk na blok (prototyp 16–23 a 25), rarita louka [20, 13, 7, 0, 0] (prototyp [19, 19, 2, 0, 0]), kopec [21, 15, 4, 0, 0], hora [21, 16, 3, 0, 0].
Bonus 0 %: naplnění 100 %, L1 15–22 %; ×5 (strop serveru): 100 %, L4 kolem 10 %. ore-v0.2 stojí 0,81–0,93 ms na blok. Vektory se přegenerovaly (24 případů, přesně všechny kromě `zatez_nad_kapacitu`).

#### Bench (`shots/bench.txt`, GDScript, headless)
| | ms na blok |
|---|---|
| generátor terénu bez rud (s vegetací) | 12,7–14,9 |
| **ore-v0, běžný cíl (bonus 25 %)** | **1,35–1,46** |
| generátor prototypu se šumovými rudami | 16,5–19,1 |
| ore-v0, obří cíle (Cu 3000, Fe 3000, jíl 1500) | 34,5 |
| ore-v0, cíl nad kapacitu (Cu 20 000, schodek) | 74 |

ore-v0 je asi 10× levnější než samotný terén a celý blok je rychlejší než v prototypu, protože odpadnou 2 šumy 3D na každou buňku kamene.

### Snímky (`shots/`)
- `37_lozika_louka.png`, `37_lozika_kopec.png`, `37_lozika_hora.png`: dva seedy vedle sebe, bonus 50 %. Kreslí se jen buňky, které ore-v0 přepsal, horniny jsou průsvitné.
- `37_lozika_tvary.png`: žíla, čočka a sloj po 150 buňkách v čistém hostiteli.
- `37_lozika_rez.png`: řez v lx = 8 (louka 101 a hora 202), plný toon terén.
- `37_lozika_srovnani.png`: hora 202, vlevo šumové rudy prototypu (Cu 20, Fe 21), vpravo ore-v0.
- `37_lozika_zatez.png`: obří cíle na hoře a malý hostitel (27 buněk žuly, zbytek mědi přes L4 do čediče).

### Odchylky od ore-v0 a nejasnosti (návrh řešení)
1. **„Zásoba propadá“ vs. přesný cíl:** ore-v0 zahodí semínko po 8 pokusech a souhrn počítá z výsledku. S novým tokem (Jan 18:25) to neplatí. Návrh: cíl se rozdělí mezi semínka a schodek řeší L1–L5 (viz výše).
2. **Šíření z neplatných buněk:** podle textu se sousedé přidávají po každém vybrání z fronty, i když buňka nebyla hostitel, a není tam seznam navštívených. Ruda by tak přeskakovala přes vzduch a jinou horninu a buňky by šly do fronty opakovaně. Návrh: šířit jen z přepsaných buněk a označit buňku při zařazení.
3. **Žíla:** chybí výchozí `branchChance` a `dirWeights` a pravidlo pro couvání a blokovaný cíl. Návrh: větvení 0,08, váhy vodorovně 2 a svisle 3, bez couvání, 4 náhradní směry. Náhodná procházka po 90° dává „trubkovou mříž“. Realističtější je deska v jedné rovině [1] (verze ore-v1).
4. **8 pokusů je málo pro tenkého hostitele** (jíl v půdě): v případu `tvar_clay_hora202` se obě semínka zahodila. Návrh: místo pokusů hledat skenem od náhodné buňky (jako v L1), nebo z předpočítaného seznamu hostitelských buněk.
5. **Pořadí rud:** měď jde první a spotřebuje žulu, jíl je poslední a při velkých cílech má schodek. Návrh: rozmisťovat od rudy s nejvzácnějším hostitelem, nebo ať server omezí cíl kapacitou receptu.
6. **Jíl je ruda i základní materiál půdy** (stejné ID 4). Souhrn bloku pak míchá jíl z půdy a jíl z ložiska. Ve studii se žádná ruda (ani základní jíl) nepřepisuje a `placed` se počítá jako přírůstek. Návrh: server kontroluje rudy jako přírůstek proti základu, nebo ložiskový jíl dostane vlastní ID.
7. **Voda:** v `mat.gd` není materiál voda, voda je samostatná vrstva (`voda-studie`). Pravidlo „nepřepsat vodu“ se týká jen vzduchu. Otevřené: smí ruda ležet pod rybníkem?
8. **Transformace:** rudy se rozmisťují až v objemu po zrcadlení, rotaci a posunu, takže otočený blok má jiné rozmístění. Nevadí, když se nehledí na bitovou shodu, jen se tím mění náhled při otáčení.
9. **Hranice bloku:** šíření se zastaví a tělesa jsou u hrany „uříznutá“. Přes hranice bloků zatím nic nepokračuje.
10. **Rarita-v2:** výchozí recepty dávají asi 4× víc mědi než prototyp, třídy rarity se posunou nahoru (viz výše).
11. **Testy:** ore-v0 chce jako golden FNV-1a 64 objemu. Teď je hlavní kontrola cíl proti umístění, hashe jsou jen pro opakovatelnost v Godotu.
12. **Kontrola na serveru:** kontrolovat počet každé rudy přesně, součet plných buněk před a po (ore-v0 jen přepisuje), schodek jen tehdy, když ho klient nahlásí a server ho při ověření kapacity uzná. Horniny se při rozmisťování mění, takže jejich počty se přesně kontrolovat nedají.
