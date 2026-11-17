# Studie trávy – Willage

Samostatný projekt v Godotu 4.7.2 (renderer Compatibility / OpenGL3), nezávislý na `godot-prototyp`. Rešerše je v `RESERSE.md`, zdroje v `ZDROJE.md` (v textu jen čísla [n]).

## Co studie ukazuje
Čtyři záhony 10 × 10 buněk v mřížce 2 × 2:

| záhon | technika | geometrie |
|---|---|---|
| **A** (vzadu vlevo) | hustá „srst“, shell texturing [1][2][4] | 24 vrstev v jednom meshi, 48 trojúhelníků, 1 draw call |
| **A2** (vzadu vpravo) | řidší „koberec“, shell texturing: méně a tlustších vláken (skoro válečky) s mezerami, prosvítá tmavý podklad | stejné jako A |
| **B** (vpředu vlevo) | jednotlivá stébla jako instance MultiMesh [5][6] | 72 500 stébel po 5 trojúhelnících |
| **C** (vpředu vpravo) | trsy trávy z prototypu (veg-v2: trs trávy, suchá tráva, kvítky [18]) jako instance MultiMesh, hustě | 3 738 instancí, 22,7 tisíce trojúhelníků |

Na každém záhonu:
- zadní řady mají vysokou trávu, přední nízkou;
- fouká vítr: posouvaný šum s poryvy a vlastní fází pro každé stéblo nebo trs [7][8];
- prochází stejná postavička stejnou trasou;
- tráva se od postavičky rozhrne, 0,35 s zůstane sklopená a za 1,6 s se pružně vrátí [9][10][11].

Ve variantě C se ohýbá celý trs stejným vzorcem jako stéblo v B.

**Hustota C oproti prototypu:**
- prototyp veg-v2 má na louce nejvýš 0,45 trsu na buňku (`veg.gd`, DENSITY "louka");
- C má 24 trsů na buňku ve vysoké trávě (53× hustší) a 50 v nízké (110× hustší);
- k tomu 3 % suchých trsů a 0,5 kvítku na buňku ve vysoké trávě.

**Výšky:**
- A, A2 a B: 0,15 a 0,05 × hrana buňky podle zadání.
- C: trsy 0,30 a 0,12 × hrana buňky (model v prototypu má 0,42 × 0,8–1,2). Při 0,15 a 0,05 jsou trsy drobné a z pohledu kamery splývají zase v mech, viz `shots/27_trava_trsy_C_vysky_0.15_0.05.png`. Výšky se nastavují parametry `tuft_tall_h` a `tuft_short_h`.

**Výklad jednotek:** „0,15 buňky“ beru jako 0,15 × hrana buňky (dnes 1 j.). Pro výšku buňky (0,5) zadej `--tall_h=0.075 --short_h=0.025`, pro pokusné rozlišení 0,5³ zadej `--cell_edge=0.5`.

**Stopa** je textura 12 px na jednotku (288 × 288 RGBAF) s časem otisku, směrem a silou. Návrat počítá shader, takže procesor přepisuje jen pixely pod postavičkami. Je to vlastní varianta podle [10][11], viz RESERSE §4.

## Spuštění
```sh
./run.sh shots                         # shots/27_trava_trsy_*.png (deterministické, ~12 s)
OUT=trava_trsy_demo ./run.sh movie     # shots/trava_trsy_demo.mp4, 12 s, 1280×720, 30 fps (~80 s na CPU)
./run.sh bench                         # měření → shots/bench.txt
./run.sh play                          # okno: 1 celek, 2–5 sleduj A/A2/B/C, mezerník pauza
./run.sh shots --prefix=28_test --tufts_tall=30 --carpet_fill=0.6   # jakýkoli parametr
```

## Parametry (všechny v `scripts/params.gd`)
| klíč | výchozí | význam |
|---|---|---|
| cell_edge | 1.0 | hrana buňky (j.) |
| tall_h / short_h | 0.15 / 0.05 | výška vysoké / nízké trávy pro A, A2, B (× hrana buňky) |
| patch_cells, tall_rows, seed | 10, 5, 1337 | velikost záhonu, řady vysoké trávy, seed |
| shell_layers | 24 | počet vrstev (A, A2) |
| shell_density / _short | 34 / 46 | chlupů na jednotku (A) |
| carpet_density / _short | 15 / 20 | vláken na jednotku (A2) |
| carpet_rad_root / _tip | 0.36 / 0.22 | tloušťka vlákna u kořene a u špičky (A2) |
| carpet_fill | 0.8 | podíl obsazených míst (A2); méně znamená víc mezer |
| blades_tall / _short, blade_w_* | 800 / 650, 0.042 / 0.032 | stébla na buňku, šířka (B) |
| tuft_tall_h / tuft_short_h | 0.30 / 0.12 | výška trsu (C) |
| tufts_tall / tufts_short | 24 / 50 | trsů na buňku (C) |
| tuft_w_tall / _short | 1.0 / 1.5 | šířka trsu vůči výšce (C) |
| tuft_dry, flowers_tall | 0.03, 0.5 | podíl suchých trsů, kvítků na buňku (C) |
| wind_* | 30°, 0.35, 0.45, 1.6, 0.22 | směr, síla, poryvy, rychlost, velikost poryvů |
| trail_px, trample_r, trample_hold, trample_recover, trample_bend | 12, 0.42, 0.35, 1.6, 1.25 | stopa a rozhrnutí |
| walk_time, char_h, char_r | 9, 0.7, 0.2 | postavička |

## Soubory
- **Skripty:**
  - `scripts/main.gd`: scéna se 4 záhony, trasa, režimy;
  - `scripts/trail.gd`: stopa;
  - `scripts/grass_build.gd`: shell mesh, stéblo, MultiMesh, trs a kvítek z prototypu.
- **Shadery:**
  - `shaders/grass_common.gdshaderinc`: vítr, rozhrnutí, stín, hash [17];
  - `shaders/meadow_proc.gdshaderinc` a `meadow_ground.gdshader`: procedurální louka (scéna `proc.tscn`, skript `scripts/proc.gd`);
  - `grass_shell` pro A a A2, `grass_blade` pro B, `grass_tuft` pro C, `toon`.
- **`shots/27_trava_trsy_*`:**
  - celek: `prehled`, `pruchod`, `po_obnove`;
  - srovnání 2 × 2 (A | A2 / B | C): `srovnani_klid`, `srovnani_pruchod`, `srovnani_nizka`;
  - detaily: `detail_C_klid`, `detail_A2_klid`, `pruchod_detail_C`, `pruchod_detail_A2`, `pruchod_nizka_C`, `po_obnove_detail_C`, `C_vysky_0.15_0.05`.
- **Videa a měření:** `shots/trava_trsy_demo.mp4` (17 MB), `bench.txt`.
- **Starší výstupy:** `shots/25_trava_*` a `trava_demo.mp4` jsou z první verze se dvěma záhony A a B.

## Výkon (box bez GPU: llvmpipe, softwarové OpenGL, 1280×720)
Absolutní čísla jsou softwarová, poměry mají vypovídací hodnotu. Prázdná scéna (zem, postavičky, stín) sama stojí zhruba 25–30 ms.

| varianta | celek | detail | geometrie |
|---|---|---|---|
| A srst | ~40 ms | ~227 ms | 48 trojúhelníků |
| A2 koberec | ~40 ms | ~221 ms | 48 trojúhelníků |
| B stébla | ~130 ms | ~114 ms | 72 500 instancí, ~363 tisíc trojúhelníků |
| **C trsy** | **~32 ms** | **~30 ms** | **3 738 instancí, ~22,7 tisíce trojúhelníků** |
| stopa (CPU) | 0,2–0,7 ms | | |

## Srovnání
- **A (srst):** zblízka nejvíc připomíná srst. Z dálky i podle Jana vypadá jako mech. Zblízka je drahá kvůli fill-rate (24 překreslení každého pixelu).
- **A2 (koberec):** čitelná vlákna s mezerami, působí jako vlas koberce nebo plyš. Z dálky je tmavší a zrnitá. Výkon je stejný jako u A.
- **B (stébla):** detailní stébla, a přesto z dálky kvůli malé výšce splývají v mech. Je nejdražší, protože má nejvíc vrcholů.
- **C (trsy):** jako jediná z dálky i zblízka čte jako tráva nebo louka (tvar trsů, kvítky, suché trsy, pastelový kawaii styl prototypu). Je zdaleka nejlevnější: 20× méně instancí a 16× méně trojúhelníků než B. Rozhrnutí je dobře vidět ve vysoké trávě. V nízké trávě je stopa slabá, stejně jako u B. Mezi trsy prosvítá podklad, takže to není „koberec“.

## Procedurální zem louky (17. 11. odpoledne, `proc.tscn`, `shots/32_trava_procedural_*`)
Jan po schválení procedurálního písku: „Když máme procedurální písek, co zkusit i procedurálně tu trávu?“ Trsy C zůstávají, procedurální je **zem pod nimi** (a ve variantě 3 i tón trsů). Bez textur, vše v shaderu, deterministické ze světových souřadnic.

Čtyři stejné záhony s trsy C (stejné rozmístění), liší se jen zemí:

| záhon | co | síla |
|---|---|---|
| 0 | dnešní plochá zem (`toon`, 0,30/0,50/0,30) | – |
| 1 | procedurální jemná | `pg_s1` 0,55 |
| 2 | procedurální výrazná | `pg_s2` 1,0 |
| 3 | sladěná: zem + trsy ze stejného šumu | `pg_s3` 0,8, `pg_match3` 0,8 |

Vrstvy (`shaders/meadow_proc.gdshaderinc` sdílí zem i trsy, `shaders/meadow_ground.gdshader` přidává drobný detail):
- méně sytá zelená (`pg_desat`);
- velké fleky přes ~6 buněk: světlejší do žlutozelena, tmavší do syté zelené, místy žlutější (fBm [19]);
- suchá místa (~16 % plochy) do slámové barvy a svěží tmavé skvrny (~12 %) s trojlístky jetele;
- drobné žíhání stébel po směru větru (anizotropní šum, čárky ~0,15 buňky; delší čárky vypadaly jako déšť) a zrno 22 na buňku jako u písku [20];
- z dálky se drobný detail podle `fwidth` utlumí, aby neblikal;
- sklopená tráva ve stopě postavičky je o 10 % světlejší, stín postavičky.

Ve variantě 3 trsy převezmou tón louky pod sebou (uniform `ground_match` v `grass_tuft.gdshader`, výchozí 0 = beze změny, scéna `main.tscn` dává stejný obraz jako dřív). Na suchém místě jsou pak suché i trsy, takže zem a tráva nepůsobí jako dvě vrstvy.

Spuštění:
```sh
SCENE=res://proc.tscn ./run.sh shots     # shots/32_trava_procedural_*.png (~12 s)
SCENE=res://proc.tscn ./run.sh bench     # shots/bench_procedural.txt
SCENE=res://proc.tscn ./run.sh shots --pg_s3=1.0 --pg_dry_cov=0.08 --prefix=33_test
```
Parametry `pg_*` jsou v `scripts/params.gd` (velikost a síla fleků, sucho, jetel, žíhání, zrno, sytost, síly variant).

Snímky: `prehled` (herní kamera, s trsy), `prehled_bez_trsu`, `srovnani_bez_trsu` (jen zem, 2 × 2), `srovnani_detail`, `srovnani_stredni`, `srovnani_pruchod`, `detail_1` až `detail_3`.

Výkon (llvmpipe, medián ze 3 běhů, ms na snímek; jeden záhon v záběru):

| | celek s trsy | detail s trsy | celek bez trsů | detail bez trsů |
|---|---|---|---|---|
| 0 plochá | 33,4 | 31,6 | 23,5 | 20,0 |
| 1 jemná | 35,5 | 38,9 | 24,9 | 26,2 |
| 2 výrazná | 39,5 | 40,3 | 25,0 | 25,1 |
| 3 sladěná | 39,9 | 44,3 | 25,0 | 27,0 |

Procedurální zem stojí softwarově asi +1–2 ms v celku a +5–7 ms, když zem vyplní celou obrazovku; sladění trsů přidá ještě 1–4 ms (šum ve vertex shaderu trsu). Měření kolísá o ±5 ms. Na skutečné grafice jde o pár desítek operací na pixel, tedy zanedbatelně.

**Doporučení:** varianta 3 (sladěná). Zem přestane být jednolitě zelená, z herní kamery jsou vidět fleky a suchá místa i přes trsy a trsy s nimi ladí. Varianta 2 je pro celý ostrov moc kontrastní (velké hnědé rohy), jemná 1 je bezpečná, ale zelené trsy suchá místa skoro zakryjí.

## Doporučení pro integraci do prototypu
1. **Tráva na loukách = C.** Rozšířit stávající veg-v2 MultiMesh: mnohem vyšší hustota (desítky trsů na buňku místo 0,45), ohyb ze stopy a vítr z `grass_tuft.gdshader`, jeden MultiMesh na druh a blok. Na blok 16 × 16 s celou loukou to dělá zhruba 6–13 tisíc instancí, což Compatibility zvládne.
2. **A2 (koberec) nebo A (srst) jen jako podklad pod trsy nebo pro speciální povrchy** (mech, trávník u domů). Z dálky stačí 8–12 vrstev.
3. **B nedoporučuji:** drahé a vizuálně nepřináší víc než C.
4. **Stopa:** jedna textura na ostrov, nebo rolovací clipmapa kolem kamery [12], se zápisem času otisku. Sdílejí ji všechny druhy a stopy můžou dělat i vesničani, zvířata a vozíky. Počítá se na klientovi a do stavu hry nepatří.
