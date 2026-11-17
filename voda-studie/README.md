# Studie vody a propustnosti (Willage)

Samostatná studie v Godotu 4.7.2 (Compatibility), nezávislá na `godot-prototyp`, stejně jako `trava-studie` a `napojeni-studie`.
Zadání Jana 2026-11-17 15:47 a 15:51: materiály dostanou propustnost, voda je **skutečná data v buňkách** (objem v každé buňce),
přetéká a odtéká, tvoří toky a rybníky, ovlivňuje průchodnost a kopání; zdroje vody jsou entity bloku.
Zdroje jen jako značky [n], plný seznam v `ZDROJE.md`, rešerše v `RESERSE.md`.

## Spuštění
```
./run.sh shots              # všech 6 scénářů -> shots/35_voda_*.png + shots/stats.txt
./run.sh shots --scen=5     # jen jeden scénář
./run.sh bench              # ms na tik, determinismus, bilance -> shots/bench.txt (bez okna)
./run.sh play --scen=2      # okno: mezerník běh/pauza, N jeden tik, V pohled (voda / nasycení v řezu / průchodnost), 1–6 scénář
```
Každý parametr jde přepsat: `./run.sh shots --scen=2 --res_grass=0.95 --perm_sand=0.5 --spring=0.4`.

## Soubory
| soubor | co dělá |
|---|---|
| `scripts/water_sim.gd` | **simulace** – čistá data, bez vykreslování a bez náhody (přenositelná na backend) |
| `scripts/materials.gd` | ID materiálů = stejná jako `godot-prototyp/scripts/mat.gd`, barvy z prototypu, vlastnosti vody z parametrů |
| `scripts/sources.gd` | rozmístění zdrojů v bloku ze seedu (top_flow / hillside_spring / underground_pocket) |
| `scripts/scenarios.gd` | 6 scénářů (terén, zdroje, plánované kopání) |
| `scripts/params.gd` | všechny parametry na jednom místě, CLI `--klic=hodnota` (stejný vzor jako napojeni-studie) |
| `scripts/main.gd` | vykreslení (kostky, voda, řez nasycením, průchodnost), snímky, bench |
| `shaders/water.gdshader` | voda převzatá a zjednodušená z `napojeni-studie/shaders/water.gdshader` (barva a průhlednost podle hloubky, odlesky) + pěna podle proudění |

## Model
Buňka 1 × 1 × 0,5 m nese materiál a objem vody `w` (jednotka = plná buňka). Vzduch pojme 1,0 (volná voda), materiál svou pórovitost (voda v zemi).
Tik má 5 kroků v pevném pořadí [4][14]:
1. **zdroje** – déšť na sloupec, entity zdrojů;
2. **pád a vsakování** shora dolů: volná voda propadne vzduchem celá, do materiálu nejvýš `propustnost × infil` za tik [9];
3. **do stran** z kopie stavu (nezávisí na pořadí buněk): volná voda podle rozdílu hladin × (1 − odpor povrchu pod ní) [8], voda v zemi podle rozdílu nasycení × propustnost (zjednodušený Darcy) [5]; voda tenčí než `film` se nerozlévá (kaluž); otevřené strany vzorku = **odtok mimo mapu**;
4. **přetlak** – co přeteče kapacitu, jde o buňku výš (stoupání hladiny, vyvěrání pramene, kapsa po prokopání) [2][4];
5. **odpar** z volné hladiny a mokrého povrchu.

**Bilance** se počítá každý tik: `přiteklo`, `odteklo`, `odpar` a chyba `|celkem − předchozí − in + out + odpar|`. Ve všech scénářích je max. chyba ≤ 1,6·10⁻⁶ buňky na tik (zaokrouhlení float32).
**Determinismus:** dva běhy od nuly dají bitově stejný stav (kontrolní součet v benchi = OK ve všech 6 scénářích).

### Výchozí tabulka materiálů (vše v `params.gd`, laditelné)
| materiál (ID z mat.gd) | propustnost `perm_` | pórovitost `por_` | odpor povrchu `res_` | význam (Jan) |
|---|---|---|---|---|
| vzduch (0) | 1 | 1 | 0 | volná voda |
| tráva / louka (1) | 0,25 | 0,40 | **0,85** | hodně zpomalí |
| hlína (2) | 0,30 | 0,40 | 0,40 | |
| písek (3) | **0,80** | 0,35 | 0,25 | neudrží, trochu zpomalí |
| jíl (4) | **0** | 0,45 | 0,10 | zadrží |
| vápenec = porézní skála (5) | **0,10** | 0,15 | 0,10 | mírný průsak |
| žula = pevná skála (6) | 0 | 0 | 0,05 | zadrží |
| čedič (7) | 0 | 0 | 0,05 | zadrží |

Další: `infil` 0,10 (vsak plně propustné buňky za tik), `flow_air` 1,0, `flow_ground` 1,0, `film` 0,03, `evap` 0,0005, `evap_soil` 0,0005, `rain`, `spring`, `tick_s` 0,5 s.
Pořadí propustností podle tabulky hydraulické vodivosti [6], pórovitost [7], odpor podle drsnosti [8].

### Průchodnost (Jan 15:47: po vodě se nesmí chodit)
Pro každý sloupec: hloubka volné vody nad povrchem. `≥ walk_deep_m` (0,30 m) = **neprůchozí**, `≥ walk_slow_m` (0,05 m) = pomalé, povrchová buňka nasycená `≥ walk_mud_s` (0,95) = bláto, pomalé (cena kroku × `walk_slow_cost` 2,5) [1]. Plná vrstva vody (0,5 m) je tedy vždy neprůchozí. Pohled „průchodnost“ to ukazuje zeleně / žlutě / červeně.

### Kopání u vody
`dig(x, y, z)` udělá z buňky vzduch; voda z jejích pórů zůstane jako volná a okolní voda do ní nateče dalšími tiky (žádné zvláštní pravidlo). Prokopnutí jílu pod rybníkem rybník vypustí do dutiny pod ním.

### Zdroje vody jako entity bloku (Jan 15:51)
`{type, poloha, rate}` – `top_flow` (přítok shora / z bloku proti proudu do sloupce x, y), `hillside_spring` (vyvěrá ze stěny svahu do sousední volné buňky), `underground_pocket` (uzavřená kapsa plná vody; dotéká do ní `pocket_recharge`, jen dokud je plná a uzavřená; po prokopání se dotok přes přetlak dere šachtou nahoru [12]). Rozmístění ze seedu bloku: `sources.gd`, parametry `src_seed`, `src_top`, `src_hill`, `src_pocket`, `top_rate`, `hill_rate`, `pocket_cells`, `pocket_recharge`. Odtok = otevřené strany vzorku (`edge_drain`).

## Scénáře a výsledky (shots/stats.txt)
Každý list má sloupce = tiky (0 / N / 2N / 4N, u 5 a 6 i mezifáze po kopání), řádky = voda · nasycení v řezu · průchodnost.

| # | snímek | vzorek | co ukazuje | výsledek |
|---|---|---|---|---|
| 1 | `35_voda_1_jilova_misa.png` | 10×10×4 | prší 60 tiků na písek nad jílovou mísou | rybník 4 × 4 vznikne do tiku 40 a po dešti zůstane (16 neprůchozích buněk i v tiku 160); voda nad valem odteče stranami (73,7 z 120) |
| 2 | `35_voda_2_svah_trava_pisek.png` | **11×12×6** (2 pruhy + hřbet, výška na svah) | stejný přítok 0,25/tik na louku a na písek, půda mokrá 95 % | louka drží vodu na povrchu a čelo postupuje pomalu (řada 8 → 9 z 12 v tiku 240), písek rychleji (9 → 11) a odvede 4× víc vody zemí (25,6 vs 6,5) |
| 3 | `35_voda_3_hraz_porezni.png` | 10×10×4 | nádrž za vápencovou hrází | hráz prosakuje pomalu: pod hrází je do tiku 200 mělká vrstva v korytě, k okraji dosáhne až po tiku 200, do tiku 400 odteče 1,1 (přítok 80) |
| 4 | `35_voda_4_skalni_panev.png` | 10×10×4 | žulová pánev s přelivem | pánev plná v tiku ~50, pak přeteče zářezem, potok po písku k východnímu okraji (odtok 6,5 do tiku 200) |
| 5 | `35_voda_5_kopani_u_vody.png` | 10×10×4 | tik 30 příkop do břehu, tik 60 průkop jílem pod rybníkem | příkop se zaplaví (neprůchozí 40 → 46), po průkopu rybník vyteče do chodby (neprůchozí 46 → 0, zbude bláto / mělká voda 46 buněk) |
| 6 | `35_voda_6_prameny.png` + `_detail.png` | **10×10×5** (kopec potřebuje vrstvu navíc) | přítok shora, pramen ve svahu, podzemní kapsa (ze seedu 77); tik 60 šachta ke kapse | přítok shora se rozlévá po horní plošině (tráva ho brzdí), pramen ve svahu vytéká na dolní terasu; po prokopání kapsa vyvěrá šachtou a vznikne tůň (neprůchozí 2 → 6) |
| – | `35_voda_srovnani.png` | | poslední stav všech 6 scénářů | |

## Výkon (shots/bench.txt, GDScript, 1 vlákno, box CPU)
| vzorek | ms / tik |
|---|---|
| 10×10×4 (scénáře 1, 3–5) | 0,15–0,32 |
| 11×12×6 (scénář 2) | 0,66 |
| 10×10×5 (scénář 6) | 0,30 |
| **blok 16×16×64 (16 384 buněk), déšť** – změřeno | **4,6–4,8** |
Lineární odhad z 10×10×4 (×41 buněk) by dal 6–13 ms; skutečný blok je levnější, protože suché a pevné buňky se rychle přeskočí.
Většinu času stojí průchod všemi buňkami v každém kroku (kontrola bilance, 2× součet, jen ~0,37 ms = 8 %) – návrhy zrychlení jsou v deníku (blok C, 7 Výkon).
Při 2 tikách za sekundu a 100 blocích by server v GDScriptu potřeboval ~1 s CPU za sekundu; s aktivními buňkami a C# řádově méně.

## Jak by to sedlo do backendu (návrh)
- **Voda jako samostatná vrstva na buňku, ne jako materiál.** Materiál zůstává (ID z mat.gd), voda je druhé pole `water[x,y,z]` (např. uint8/uint16 v setinách buňky). Buňka „písek s vodou“ je pak písek + 0,3; „vzduch s vodou“ je rybník. Jako materiál by voda nemohla být v pórech a kopání by ji ničilo.
- **Vlastnosti vody patří do katalogu materiálů** vedle skóre a váhy rarity: `perm`, `porosity`, `surface_res` (+ budoucí `LOAD`).
- **Zdroje jako entity bloku** (`water_sources[]`: typ, poloha, rate, seed), generované ze seedu bloku jako vegetace.
- **Tiky na serveru:** stav vody je deterministický z (terén, zdroje, kopání, počet tiků); pro shodu klient/server doporučuji celočíselný objem (fixed-point) místo float32.
- **Průchodnost a hledání cest** čtou hloubku vody (`walk()`); stavba na neprůchozí buňce zakázaná.
- **Okraje bloků:** voda teče i přes hranici bloku; v blocích to bude výměna pruhu buněk se sousedem (jako dorovnání stran), ne odtok mimo mapu.
