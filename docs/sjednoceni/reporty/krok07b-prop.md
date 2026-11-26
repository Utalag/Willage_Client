# PROP – Krok 7b: klimatická pásma, oázy, klima výchozí zapnuto

Větev `gen-v1-krok07b-pasma` z `gen-v1-krok07-klima-biomy` (c733dba). Napsáno 2026-11-26 12:55 SEČ, před experimenty. Bez merge do main.
Rozhodnutí Jana 12:47 / 12:49 k otázkám z kroku 7:
1. **ANO** – `KlimaKrok07` výchozí zapnuto; očekávané otisky se aktualizují, předvolba bez klimatu musí dál dávat staré.
2. **ANO** – herní gradient výšky 0,05 °C/m zůstává.
3. **ANO** – mírná planeta se zúží, aby byla většinou mírná. Přes **konfigurovatelná klimatická pásma** (Jan 12:46) místo kosinové křivky. Upřesnění 12:49: **předdefinované složení pásem** (tropy, subtropy, mírné, chladné, polární), u každého pásma nastavitelná šířka a rozsah teplot od–do, každé pásmo jde **vypnout** (`Zapnuto`), zbylá pásma planetu vyplní poměrně. Není to volný seznam.
4. **ANO** – průměrné w ≈ 0,72 je v pořádku.
5. **ANO** – vítr jen po pásech (po řádcích osy x), zůstává.
6. **ANO** – oázy / artéské prameny jako zdroje vlhkosti na pouštní planetě a obecně v pouštích, laditelné.
7. **ANO** – zamrzání a led později v povrchových jevech (jen TODO).
8. **NE** – reliéf eroze se klimatem nemění (planeta eroze dál vždy z presetu `mirne`; mapa eroze a její klíč beze změny).

## Návrh
- **Pásma.** `klima_v1.json`: u každé planety (`mirne`, `poust`, `step`, `tundra`, `ledovec`) pět pevně pojmenovaných pásem v pořadí od rovníku k pólu. Každé: `Zapnuto`, `Podil` (váha šířky, po vypnutí některých se zbylé normalizují na půlperiodu), `TOdC` (teplota na rovníkové hraně) a `TDoC` (na polární hraně), `SrazkyK` (násobek srážek planety v pásmu), `Vitr` (+1 od západu, −1 od východu). Torus: rovník v `u = 0`, pól v `u = 0,5`, druhá polovina je zrcadlo (teplota je tak periodická a spojitá). Teplota v pásmu lineární; mezi sousedními pásmy **krátký plynulý přechod** `PrechodPasmaM` (smoothstep, šířka v m, ořezaný na polovinu nejužšího pásma) pro teplotu, srážky i vítr. Pásmo startu (`StartPasmo`, výchozí `mirne`) se umístí tak, aby start 3 × 3 ležel uprostřed jeho prvního výskytu. Nahrazuje kosinovou křivku, zeměpisnou šířku v ° a větrné pásy ve stupních (parametry `StartSirkaDeg`, `ARovnik…`, `PasatyDoDeg…` zanikají).
- **Oázy.** Nový `Klima/Oazy.cs`: mřížka buněk `OazaBunkaM` (výchozí 1000 m), deterministicky ze seedu pravděpodobnost `OazaPravdepodobnost` (0,2); v buňce se vybere pouštní uzel (biom poušť, volitelně step `OazaVeStepi`) s nejnižší výškou (pánev = vývěr podzemní vody), ne moře ani jezero. Oáza je trvalý zdroj (jako vodník, jmenovitý výkon `OazaQLs` × (0,5 + hash)) v seznamu vodníků, a okolí `OazaPolomerM` v mapě biomů dostane biom **oáza**. Laditelné v `klima_v1.json`, `OazaZapnuta` přepíná.
- **Výchozí zapnuto.** `ParametrySveta.KlimaKrok07 = true`. Předvolby `Krok5()` a `Puvodni()` (`VseKrok06 = false`) dávají staré otisky; nová předvolba `Krok06()` = `VseKrok06` zapnuto, klima vypnuto (stav po kroku 6).

## Hypotézy
- H1: s `Krok5()` / `Krok06()` otisky seedu 49 beze změny (krok 3 c8eeb7964d1ddd85 a 9f32311e046f8b6a, voda 7714d1a1d34e00ad / 8e239a68c6d01be0, 18 / 20 pramenů, mapa 800d420bb00047de, 92 vodníků). Nové výchozí (klima zap) mění jen vodu.
- H2: na mírné planetě bude mírný les + tajga ≥ 70 % pevniny a poušť pod 5 %.
- H3: na pouštní planetě bude oáz řádově desítky (~0,2 / km² pouště) a všechny v biomu poušť.
- H4: průměrné w mírné planety se pohybuje kolem 0,7–0,9.
- H5: přechod mezi pásmy je plynulý (skok teploty < 0,1 °C na 8 m), vypnutí pásma zbylá vyplní poměrně.

## Měření
Testy C# (main i větev), otisky vyp/zap, podíly biomů pro 4 seedy a 5 planet, počty oáz, obrázky `godot-prototyp/shots/krok07b/` (pásma a teplota, biomy 4 seedy, pouštní planeta s oázami), `git merge-tree` proti main. Negativní výsledky zapsat.

## Výsledky (2026-11-26 13:20 SEČ)

### Implementace a výchozí hodnoty pásem (`klima_v1.json`)
Pásma od rovníku k pólu, `Podil` = váha půlperiody (po vypnutí se zbylá normalizují), teploty `TOd → TDo` (°C, rovníková → polární hrana), `K` = násobek srážek planety, vítr `+` od západu / `−` od východu. Přechod mezi pásmy `PrechodPasmaM` = 400 m. `—` = vypnuto.

| planeta (srážky mm) | tropy | subtropy | mírné | chladné | polární |
|---|---|---|---|---|---|
| **mírné** (800) | — | 15 %: 18→15, K 0,8, − | **60 %**: 15→8, K 1,1, + | 25 %: 8→5, K 1,0, + | — |
| poušť (300) | 20 %: 34→32, K 0,5, − | 60 %: 32→28, K 0,6, − | 20 %: 28→22, K 1,0, + | — | — |
| step (450) | — | 25 %: 24→20, K 0,8, − | 50 %: 20→14, K 1,0, + | 25 %: 14→10, K 1,0, + | — |
| tundra (500) | — | — | 20 %: 8→4, K 1,0, + | 40 %: 4→−4, K 1,0, + | 40 %: −4→−14, K 0,6, − |
| ledovec (400) | — | — | 10 %: −2→−8 | 30 %: −8→−15 | 60 %: −15→−30, K 0,6, − |

Vypnuté pásmo má v JSON dál své hodnoty (stačí přepnout `Zapnuto`). Další výchozí: `OazaPravdepodobnost` 0,3, `OazaBunkaM` 1000 m, `OazaQLs` 3 l/s, `OazaPolomerM` 96 m, `OazaVeStepi` false, `StartPasmo` mirne.

### Negativní / mezivýsledky
- První mírná planeta (srážky 1000 mm): w průměr **1,27** (příliš vlhká), mírný les 93 %. 650 mm: w 0,54, step 11 %, vodníků jen 42. Zvoleno **800 mm** (w ≈ 0,7–0,84, vodníků 78–97). Odtok podle Turca je ve studených pásmech velmi nelineární.
- Oázy nejdřív s pravděpodobností buňky nezávislou na ploše pouště: na stepi 0,77 oáz/km² pouště (poušť tvoří jen skvrny). Opraveno: pravděpodobnost × podíl pouštních uzlů v buňce. Pak na pouštní planetě 44 oáz (0,15 /km²) při 0,2, proto výchozí **0,3** (71 oáz, 0,24 /km²).
- Porovnání otisku klimatu při 1 a 8 vláknech nejdřív „nesedělo“ jen v nástroji (1 vlákno bez překrytí oáz); ne chyba v knihovně.

### Podíly biomů mírné planety (% pevniny)
| seed | mírný les | tajga | step | mírný deštný les | poušť | w průměr | T °C |
|---|---|---|---|---|---|---|---|
| 49 | 91,0 | 5,4 | 3,6 | 0,1 | 0 | 0,83 | 2,9…18,0 |
| 2 | 86,7 | 6,4 | 6,7 | 0,2 | 0 | 0,73 | 2,5…18,0 |
| 4 | 87,9 | 4,9 | 7,0 | 0,3 | 0 | 0,71 | 2,8…18,0 |
| 8 | 91,9 | 5,9 | 2,1 | 0,2 | 0 | 0,84 | 2,5…18,0 |

Mírný les + tajga 91–98 % (H2 ano, poušť 0 %), srážkový stín: návětří 1,22–1,31×, závětří za hřbetem 0,57–0,64×. Koryta z eroze: aktivní 73–79 %, suchá 20–26 %. Vodníci před → po (bez klimatu → s klimatem): 49: 92 → 86, 2: 94 → 78, 4: 114 → 86, 8: 103 → 97.

### Ostatní planety (seed 49, stejná eroze)
| planeta | poušť | step | led | tundra | tajga | mírný les | oázy | aktivní koryta | vodníci |
|---|---|---|---|---|---|---|---|---|---|
| poušť | 93,4 | 5,9 | 0 | 0 | 0 | 0 | **71** (0,24 / km² pouště; biom oáza 0,57 % pevniny, Q 203 l/s) | 0 | 71 (jen oázy) |
| step | 15,7 | 59,8 | 0 | 0 | 0 | 23,4 | 11 (0,22 / km²) | 17 % | 15 |
| tundra | 0 | 0 | 32,4 | 43,3 | 19,3 | 5,0 | 0 | 72 % | 54 |
| ledovec | 0 | 0 | 94,3 | 5,7 | 0 | 0 | 0 | 72 % | 49 |

Všechna koryta pouštní planety jsou suchá (pozůstatek eroze), vodu tam dávají jen oázy. Poznámka: ledová planeta má pořád hodně vody (chybí zamrzání, TODO bod 7).

### Otisky seedu 49
| konfigurace | mapa eroze | krok 3 | voda 14,14 | prameny 3×3 | vodníci |
|---|---|---|---|---|---|
| `Krok5()` | – | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 | – |
| `Krok06()` / `--bez-klimatu` (klima vyp) | 800d420bb00047de | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 | 92 |
| **nový výchozí** (klima zap, pásma, oázy) | 800d420bb00047de | 9f32311e046f8b6a | **377a8210f82c856a** | **21** | **86** |

Klíč keše eroze d61ed38d70cfced9 beze změny, otisk klimatu cb11da8d141a2a5e, start: mírný les, T 10,1 °C, P 943 mm, w 1,35 (prameny ve 3×3: 20 → 21, výkon 52 → 83 l/s). Na mírné planetě žádné oázy (poušť 0 %).

### Testy
Větev c733dba (krok 7): 141. Nová větev: **OK 156, chyb 0** (+15 testů 7b: pásma, vypínání, normalizace, přechod, symetrie, oázy, výchozí zapnuto). `main` 5e4f1f0: 110.

### Obrázky (`godot-prototyp/shots/krok07b/`)
`pasma_teplota_seed49.png` (mapa teploty s hranicemi pásem a profil po ose y), `biomy_4_seedy.png` (49, 2, 4, 8), `poust_oazy_seed49.png` (biomy pouštní planety, suchá koryta a oázy), `pasma_teplota_poust_seed49.png`.
