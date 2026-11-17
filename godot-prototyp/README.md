# Willage – hratelný prototyp ostrova (Godot 4.7.2)

Ostrov z bloků **16 × 16 × 64 buněk** (buňka 1 × 1 × 0,5), kostkový vzhled, ortografická izometrická kamera.
Na začátku 4 bloky, kolem mlha. Z lišty dole se vybírá další blok, před vložením jde zrcadlit, otočit, posunout výškou
a nastavit napojení každé strany. Starý test `../godot-3d-test/` zůstal beze změny, tento projekt z něj převzal mesher, vrstvy a mlhu.

## Spuštění
```
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
$G --path /workspace/willage-ideas/godot-prototyp            # interaktivně (s oknem)
./shoot.sh                                                     # demo bez okna -> shots/*.png (1280 × 800)
$G --headless --path . -- --export-vectors                     # testovací vektory -> vectors/vectors.json
$G --headless --path . -s res://tools/rarity_stats.gd          # statistika skóre rarity (kalibrace prahů)
$G --headless --path . --export-release "Linux" ../build/linux/WillagePrototyp.x86_64          # export (šablony 4.7.2)
$G --headless --path . --export-release "Windows Desktop" ../build/win/WillagePrototyp.exe
# video: dočasně override.cfg s viewport 1280×720, pak
xvfb-run -a $G --path . --write-movie /tmp/vid/f.png --fixed-fps 30 -- --video
```
Hotové buildy: `../build/willage-prototyp-windows.zip`, `../build/willage-prototyp-linux.zip` (uvnitř `HRAJ.txt`), video `../build/demo.mp4`.
V exportované hře jdou screenshoty dema a delta do `user://` (Linux `~/.local/share/godot/app_userdata/Willage prototyp ostrova/`).
Renderer **Compatibility (OpenGL 3)**. `shoot.sh` potřebuje `xvfb-run`.

## Ovládání
| Akce | Ovládání |
|---|---|
| otočit kameru o 90° | Q / E |
| zoom | kolečko myši |
| posun | WASD / šipky, tažení prostředním nebo pravým tlačítkem |
| řez (Z-úroveň jako v DF) | PageDown zapne / sníží, PageUp zvýší (nad 63 vypne), Home vypne |
| vybrat blok | klik na kartu v liště dole |
| náhled | najetí myší na zvýrazněné (žluté) místo v mlze; klik místo zamkne |
| rotace / zrcadlení / výška | R / F / + a − (nebo tlačítka v panelu vpravo) |
| napojení stran | rozbalovací menu S / V / J / Z v panelu: Auto, Dorovnat 1–4, Ponechat |
| uložit / zrušit | Enter nebo „Uložit“ / Esc nebo „Zrušit“ |
| info o vloženém bloku | klik na blok ostrova (když není vybraný kandidát) |
| vzhled kawaii / původní | T |
| textury materiálů zap / vyp | X (jen v kawaii vzhledu; výchozí vypnuto = čisté barvy) |
| zaoblené hrany zap / vyp | B (světlý lem horních hran, tmavší okraj bočních stěn; výchozí vypnuto) |
| kopání | M zapne režim; klik = vykopat vrchní buňku sloupce (do inventáře), Shift+klik = položit materiál z inventáře na vrch, 1–9 = výběr materiálu, Esc konec |
| stavby | záložka „Stavby“ v liště dole: Domek, Studna, Větrný mlýn, Políčko; najetí = zelený/červený náhled, klik = postavit, R otočit, Esc zrušit |
| cesty | C zapne režim; klik = bod (klik na domek = jeho dveře), první = start, poslední = cíl, mezi nimi průjezdní body; Enter postaví, Esc zruší |
| ladicí okno (jen vývoj) | F1 zap / vyp; spuštění s `-- --dev` (a `--dev-panel` = otevřít hned); jen když existuje `addons/dev_tuning/` |

Strany: **S** = sever (−z), **V** = východ (+x), **J** = jih (+z), **Z** = západ (−x). V náhledu jsou popisky stran přímo u bloku.

## Co je hotové
- **Generátor** typ + seed (FastNoiseLite): louka, kopec, hora, písčina. Stejný typ s jiným seedem je podobný, ne stejný.
- **Vrstvy (DF)**: tráva → hlína 1–3 → jíl/písek 1–3 → vápenec (s žulovými intruzemi) → žula → čedič; žíly mědi a železa; sníh nad buňkou 49; strmé svahy holý kámen (u kopce a hory v2.2 místo toho holý kámen od výšky 46, police travnaté až k útesu).
- **Ostrov**: 24 slotů v přibližném kruhu (poloměr 2,6 slotu kolem středu 2 × 2), 4 startovní bloky, zbytek mlha (materiál `FOG` = 11, nehratelná; vykreslená vrstvami `fog.gdshader`).
- **Platná místa**: jen mlha sousedící **hranou** s ostrovem; zvýrazněná žlutým rámečkem, místo pod myší růžově.
- **Vkládání** v pořadí zrcadlení → rotace → posun výšky → strany; vždy jen jeden blok; po uložení slot opustí mlhu,
  sousední bloky se nemění (jen se u nich skryjí stěny na společné hraně). Spotřebovaný kandidát nahradí nový náhodný běžný blok.
- **Napojení stran**: Auto = rozdíl ≤ 6 buněk se dorovná na 3 buňkách, větší zůstane útes (po sloupcích);
  Dorovnat n = vynucené dorovnání na n buňkách; Ponechat = beze změny.
- **Posun výšky ±1–4**: nahoru = spodní řady se dogenerují ze seedu (hlubší vrstvy), dolů = spodní řady se odeberou. Výška bloku zůstává 64.
- **Katalog** v liště: běžné (seed), pevný („Hora Prvního dne“, seed 1000, modrý okraj), unikátní („★ Grrrrův štít“, pojmenovaný seed, zlatý okraj, bohatší žíly).
- **Souhrn materiálů** a **rarita** (původní / aktuální; teď stejné, protože se ještě nekope). Skóre buňky v `scripts/mat.gd`
  (rudy 25–40, sníh 8, kámen 2–3, půda 1–2), rarita = **rarity-v2** (Jan 2026-11-17): vážený průměr `R = Σ(n·w·s) / Σ(n·w)`, váha `WEIGHT` = s² (laditelná, vzduch a mlha se nepočítají), prahy `RARITY_THRESHOLDS` [0; 15,9; 19,4; 26,1; 29,9] z `tools/rarity_calib.gd` (stejné podíly tříd jako dřívější prostý průměr na 240 blocích, zatímní). Vegetace stejně (váha s², prahy [0; 4,37; 4,90; 5,39; 6,48]).
- **Pastelová paleta** (kawaii směr), AO ve vrcholech, měkké stíny. Nosnost materiálů je zatím jen v tabulce (`LOAD`).
- **Domky z Blenderu** (`blender/domek.py` → `assets/domek.glb`, načtené za běhu přes `GLTFDocument`, ztlumené materiály).
  Půdorys 3 × 3 sloupce, dveře na +z; v demu 3 domky (místo hledá `_find_site`: rovný půdorys, dosažitelné dveře).
- **Vegetace** (vrstva nad buňkami, `scripts/veg.gd`, vykreslení `scripts/veg_render.gd`): trsy trávy, suchá tráva a květiny
  jako MultiMesh s vlněním ve větru (`veg_wind.gdshader`), mech; keř, jehličnan, listnáč a kaktus z Blenderu (`blender/vegetace.py` → `assets/*.glb`).
  V panelu je souhrn druhů a „Rarita vegetace (původní / aktuální)“ jako samostatná skupina (zatímní). Pod domky a cestami se nevykresluje.
  Algoritmus přesně viz „Vegetace – specifikace“ níže.
- **Tráva C na loukách** (2026-11-17, schválil Jan 13:05; převzato ze studie `../trava-studie/`, varianta C): každý travnatý sloupec
  nese hustě instancované trsy z veg-v2 (24 na buňku ve vysoké, 50 v nízké trávě, výška 0,30 / 0,12 hrany buňky) a kvítky,
  vítr ze šumu a rozhrnování postavičkou (stopa v textuře: 0,35 s položená, návrat za 1,6 s). Jen vzhled, data vegetace se nemění.
  Podrobně viz „Tráva C“ níže.
- **Kawaii vzhled** (`terrain_toon.gdshader`, T přepíná): měkký dvoustupňový toon ramp, posun k pastelu a obrysy hran srázů.
  Obrysy jsou levné: mesher u každé stěny uloží do CUSTOM0, které její hrany sousedí se vzduchem, a shader je ztmaví podle UV (žádný post-process, běží v Compatibility).
  **Objekty** (stromy, keře, kaktusy, domky, cesty) mají stejný ramp (`object_toon.gdshader`) a obrys metodou inverted hull (`outline.gdshader`,
  obal posunutý podél průměru normály a směru od středu, takže se zavře i na ostrých hranách). Tráva/květiny mají toon ve `veg_wind.gdshader` bez obrysu.
  Vše řídí `scripts/toon.gd` (T přepíná terén i objekty najednou).
- **Zaoblené hrany** (B): v toon shaderu podle vzdálenosti k obrysové hraně (stejná data CUSTOM0 + UV) zesvětlí lem horní plochy a ztmaví okraj boční stěny.
- **Cesty** (`scripts/roads.gd`): A* po povrchových sloupcích ostrova (4-okolí). Průchozí krok: |Δ výšky| ≤ 4 buňky (2 m);
  větší útesy, mlha, mezery mezi bloky a půdorysy staveb neprojdou. Cena kroku: rovina 1, Δ1 = 1,5 (rampa), Δ2–4 = 1 + 2,5·Δ (schody, penalizace),
  heuristika Manhattan. Trasa přes průjezdní body = spojené úseky.
  Vrstva cesty je jeden mesh: plochá dlaždice na rovině; na sloupci, ze kterého trasa stoupá k vyššímu sousedovi, stojí místo dlaždice
  **rampa** (klín, Δ1) nebo **schody** (Δ2–4, stupeň 0,25 m, 2 stupně na buňku výšky, se sloupky). **Terén se nemění** (vše jsou objekty vrstvy cesty).
  Vegetace na trase zmizí. Když cesta neexistuje, nápověda to řekne. Kawaii materiál + obrys jako u ostatních objektů.
  **Delší schody:** A* má stav (sloupec, směr příchodu) a výstup/sestup o 3–4 buňky bez rovného nájezdu/výjezdu má přirážku 2,
  takže trasa dá přednost rovnému úseku a schody se roztáhnou na 2 sloupce (stupeň 0,125 m). **Údolí** (sloupec stoupá k oběma sousedům):
  kusy se sloučí do plošiny ve výšce nižšího souseda + jedny schody/rampa k vyššímu, nic se nepřekrývá.
  **Dlažba:** podklad (spárovací malta) + 2 × 2 kameny s drobnou odchylkou výšky a barvy (deterministicky z polohy), spáry jsou záměrné.
- **Kopání a stavění (M)**: odebere/položí vždy vrchní buňku sloupce, materiál se zachovává (inventář ostrova vlevo nahoře).
  Aktuální rarita bloku se přepočítá, původní zůstává. Vegetace na změněném sloupci zmizí. Mlha, pod lz 0, nad lz 63, pod stavbou a cestou nelze.
  Každá změna se zapíše do delty bloku (index buňky, starý/nový materiál) – ukázka formátu ve `vectors/delta_sample.json` (viz níže).
- **Stavby z lišty** (`blender/stavby.py` → `assets/studna.glb`, `mlyn.glb`, `pole.glb`; domek z `blender/domek.py`): půdorys 3 × 3 (studna 1 × 1),
  dveře před přední stranou (otočené s R). Postavit lze, když je půdorys na ostrově, volný, rozdíl výšek ≤ 1 buňka, nezakrývá dveře jiné stavby
  a sloupec před dveřmi je volný a nejvýš o 1 buňku jinde. Cesty se přichytí ke dveřím libovolné stavby.
- **Panel vpravo** ukazuje blok pod posledním kliknutím (cesta, kopání, stavba) včetně popisu „Stavba: … / Cesta · Sloupec (lx, ly) v bloku (x, y)“.
- **Textury materiálů** (Gemini v2, X přepíná): `tools/textury_pripravit.py` ořízne okraj, prolne švy (posun o půl + maska) a uloží `assets/tex/01..10.png`;
  shader je bere jako Texture2DArray, mapuje podle normály (4 m na opakování) a používá je jen jako **detail**: barva a stínování zůstávají z materiálu.
- **Demo** (`-- --demo`): screenshoty a na konci simulovaná myš (najetí, klik, R, Enter) s výpisem `SELFTEST`.

## Co hotové není
Kopání do strany / tunely (jen vrchní buňka sloupce), výběr materiálu k položení (bere se první dostupný), ukládání delty na server, sázení vegetace hráčem, fyzika, ukládání na server,
kombinované typy bloků, dorovnání přes rohy (diagonální sousedé), animace, stavění domků hráčem (zatím jen demo rozmístění),
mosty, skutečně zaoblená geometrie kostek (teď jen stínovací trik), vyhlazení (merge) obrysů mezi sousedními objekty.

## Struktura
| Soubor | Obsah |
|---|---|
| `scripts/main.gd` | scéna, kamera, vstup, výběr kandidáta a vkládání, demo, `--export-vectors` |
| `scripts/island.gd` | sloty, bloky, mlha, rámečky platných míst, náhled, řez, objekty na povrchu |
| `scripts/block.gd` | data bloku (typ, seed, volby, výšky, buňky, souhrn materiálů) |
| `scripts/block_gen.gd` | generátor v2: výšky, transformace, napojení stran, vrstvy |
| `scripts/mesher.gd` | kostkový mesh s obalem okrajů sousedů (bez děr a z-fightingu na hranách), AO, výška buňky 0,5 |
| `scripts/mat.gd` | materiály: ID, názvy, barvy, skóre, nosnost, rarita |
| `scripts/stable_hash.gd` | SplitMix64, FNV-1a 64, `mix(seed, purpose, layer)`, pojmenované seedy |
| `scripts/vectors.gd` | export testovacích vektorů (VY-070) |
| `scripts/ui.gd` | lišta kandidátů, panel úprav, materiály, rarita, nápověda |
| `fog.gdshader`, `highlight.gdshader` | mlha, rámeček platného slotu |
| `blender/domek.py` | skript pro Blender 5.3 (bpy) vytvářející domek |
| `tools/rarity_stats.gd` | skóre rarity přes typy a seedy |
| `scripts/veg.gd`, `scripts/veg_render.gd`, `veg_wind.gdshader` | generátor vegetace, vykreslení (MultiMesh), vítr |
| `scripts/grass.gd`, `scripts/grass_params.gd`, `scripts/grass_trail.gd`, `grass_tuft.gdshader`, `grass_common.gdshaderinc` | tráva C: stavba trsů na blok, parametry, stopa rozhrnutí, shader (vítr, ohyb, stopa) |
| `scripts/grass_demo.gd` | `--grass-shots` (snímky 28) a `--grass-bench` (měření), testovací postavička |
| `scripts/roads.gd` | A* cesty, dosažitelnost, vrstva cesty (dlaždice, rampy, schody), půdorys a dveře domku |
| `scripts/toon.gd`, `object_toon.gdshader`, `outline.gdshader` | kawaii materiály a obrysy objektů, společný přepínač |
| `tools/objekty_srovnani.py` | skládá dvojice screenshotů (18, 19, 21) |
| `blender/stavby.py` | studna, větrný mlýn, políčko pro Blender 5.3 → `assets/*.glb` |
| `terrain_toon.gdshader` | kawaii toon + obrysy + volitelné textury |
| `blender/vegetace.py` | stromy, keř, kaktus pro Blender 5.3 → `assets/*.glb` |
| `tools/veg_stats.gd` | statistika skóre vegetace (kalibrace prahů) |
| `tools/textury_kontrola.py`, `tools/textury_pripravit.py` | kontrola švů textur, příprava dlaždic |
| `tools/kawaii_srovnani.py` | skládá `14_kawaii_pred_po.png` |
| `scripts/tunable_params.gd`, `scripts/param_registry.gd` | základ laděných parametrů (Resource, CLI `--prefix.klic=`), registr, přes který je najde ladicí okno |
| `scripts/surface/surface_params.gd`, `shore_fields.gd`, `dual_grid_mesher.gd`, `surface_renderer.gd` | povrch louka/písek/voda: parametry, okno tříd a vzdálenostních polí, duální síť a voda, materiály a přestavby |
| `terrain_surface.gdshader`, `water_surface.gdshader`, `surface_common.gdshaderinc`, `surface_look.gdshaderinc`, `meadow_proc.gdshaderinc` | shadery povrchu, vody, písku a procedurální louky (sdílí je i `terrain_toon` a `grass_tuft`) |
| `scripts/napojeni_demo.gd` | `--napojeni-shots` (snímky 34) a `--napojeni-bench` (měření) |
| `addons/dev_tuning/` | ladicí okno (samostatný doplněk, do exportu nejde) |

## Specifikace generátoru (pro sladění s backendem)
- **Osy:** `lx`, `ly` vodorovně 0–15, `lz` výška 0–63. V Godotu `lx → x`, `ly → z`, `lz → y` (svět: y = lz · 0,5).
- **Index:** `(lx * 16 + ly) * 64 + lz`, smyčky vždy `lx, ly, lz`; 1 bajt = `MaterialId` (0 vzduch … 10 sníh, 11 mlha – v generátoru se mlha nevyskytuje).
- **Seedy vrstev:** `noise_seed = mix(seed, purpose, layer) & 0x7FFFFFFF`,
  `mix = splitmix64(splitmix64(splitmix64(seed) ^ fnv1a64(purpose)) ^ layer)` (64bitově, přetečení mod 2^64; ověřeno proti Pythonu).
  Účely a vrstvy: `HEIGHT` 0 (tvar, f 0,07) a 1 (detail, f 0,18); `STRATA` 0–3 (vlnění, hranice, 3D zkroucení, intruze);
  `ORE` 0 měď, 1 železo; `SOIL` 0 hlína, 1 podloží, 2 jíl/písek; `SPOT` pro výběr kontrolních buněk.
- **FastNoiseLite:** Simplex Smooth, FBM, 5 oktáv, lacunarity 2, gain 0,5, weighted strength 0, bez domain warpu, offset 0. 3D vzorek `(lx, lz, ly)`.
- **Reliéf kopce a hory (proto-v2.2, výchozí):** technika z devlogu JohnBrx (makro-šum → po částech lineární výškový profil → malý detail).
  Louka a písčina beze změny. v2.1 zůstává v kódu (`BlockGen.relief_version = "v2.1"`), popis níže.
  1. **Makro-šum** `M = noise(seed, "HEIGHT", 5, f = 0,045, octaves = 2)` (ostatní parametry FastNoiseLite jako všude:
     Simplex Smooth, FBM, lacunarity 2, gain 0,5). Vzorky `v(lx, ly) = M(lx, ly)` pro všech 256 sloupců (zdrojové souřadnice).
  2. **Normalizace na blok:** `lo = min v`, `hi = max v`, `span = max(hi − lo, 0,05)`, `t = (v − lo) / span` (double).
  3. **Posun podle seedu:** `off = 0,12 · (2·u − 1)`, kde `u = (mix(seed, "HEIGHT", 6) & 0xFFFFFF) / 2^24`.
  4. **Okrajový pokles** (aby vysoká patra netvořila krabici na hraně bloku): `ax = |lx − 7,5| / 8`, `ay = |ly − 7,5| / 8`,
     `r = (ax⁴ + ay⁴)^(1/4)`, `fall = E · clamp((r − 0,6) / 0,4, 0, 1)`, E = 0,20 (kopec) / 0,35 (hora).
  5. `m = clamp(t + off − fall, 0, 1)`.
  6. **Profil** (řídicí body `[m, lz]`, lineární interpolace, mimo rozsah krajní hodnota):
     - kopec: `[0, 30] [0,30, 30] [0,36, 34] [0,62, 34] [0,68, 39] [1, 39]` → police 30 / 34 / 39, útesy 4–5 buněk;
     - hora: `[0, 31] [0,24, 31] [0,30, 37] [0,48, 37] [0,54, 43] [0,72, 43] [0,78, 47] [1, 48]` → police 31 / 37 / 43 / 47–48, útesy 4–6 buněk.
  7. **Detail** (vzorky v `lx, ly`): kopec `h = P + 0,8·HEIGHT/0 + 0,4·HEIGHT/1`;
     hora `h = P + 0,9·HEIGHT/0 + 0,5·HEIGHT/1`, a pokud `P ≥ 46`: `h += 1,6 · max(HEIGHT/1(lx, ly), 0)` (skalnaté vršky).
     (`HEIGHT/0` f 0,07, `HEIGHT/1` f 0,18, 5 oktáv – beze změny.)
  8. `round`, `clamp(1, 63)`; pak zrcadlení, rotace, posun a strany jako dřív.
  9. **Povrch (jen v2.2, kopec a hora):** pravidlo „strmý svah = holý kámen“ se nepoužije; police mají trávu až k hraně útesu.
     Holý kámen, když `h ≥ 46` (`ROCK_LZ`); sníh dál od `h ≥ 49`. Louka a písčina mají pravidlo svahu jako dřív.
- **Reliéf kopce a hory (proto-v2.1, jen pro srovnání):** louka a písčina beze změny. Pro kopec a horu:
  - náhodná čísla `u(k) = (mix(seed, "PEAK", k) & 0xFFFFFF) / 2^24`; vrchol `i` používá `k = i*8 + j`;
  - vrcholy: hora 3, kopec 2. Střed `cx = 3 + 10·u(k+0)`, `cy = 3 + 10·u(k+1)`; úhel `π·u(k+3)`;
    `rx = 5,5 + 4·u(k+4)`, `ry = rx·(0,55 + 0,45·u(k+5))`; nesouměrnost `skew = 0,6·(2·u(k+6) − 1)`;
    výška hlavního vrcholu: hora `12 + 8·u(2)`, kopec `5 + 5·u(2)`; vedlejší = hlavní × (hora `0,35 + 0,4·u`, kopec `0,3 + 0,5·u`);
  - ruční domain warp: `w = HEIGHT/2` (f 0,08), `wx = lx + A·w(lx, ly)`, `wy = ly + A·w(lx + 40, ly − 40)`, A = 3 (hora) / 2 (kopec);
  - vrchol: `a = dx·cos + dy·sin`, `b = −dx·sin + dy·cos`, `a /= (1 + skew)` pro a > 0, jinak `a /= (1 − skew)`;
    `q = √((a/rx)² + (b/ry)²)`, `f = max(0, 1 − q)`, hora `f^1,3`, kopec `f²(3 − 2f)`; hodnota `amp·f`;
  - `h = základ + max + 0,15·(součet − max)`, základ hora 33 / kopec 32;
  - hora navíc hřebeny `HEIGHT/3` (f 0,10): `r = 1 − |n(wx, wy)|`, `h += 4·r²·(0,3 + 0,7·clamp(max/hlavní_amp))`, detail `+1,5·HEIGHT/0 + 1,2·HEIGHT/1`;
    kopec detail `+1,6·HEIGHT/0 + 0,6·HEIGHT/1` (vzorky v `lx, ly`, ne ve warpu);
  - římsy `HEIGHT/4` (f 0,06): `m = clamp((n(lx, ly) − 0,1)·3, 0, 1)·0,8`, krok 3 (hora) / 2 (kopec), `h = lerp(h, floor(h/krok)·krok, m)`;
  - nakonec `round` a `clamp(1, 63)` jako dřív. Pořadí generátoru, transformace i schéma `mix` beze změny.
- **Pojmenovaný seed:** `fnv1a64(UTF-8 jméno) & 0x7FFF…FFFF`.
- **Transformace:** zrcadlení X (`lx → 15 − lx`), rotace k × 90°, dopředně `(lx, ly) → (15 − ly, lx)`, posun výšky ±4, strany S/V/J/Z.
  Kámen se počítá ze zdrojové výšky `lz − posun`, takže posun nahoru dogeneruje spodní řady ze seedu.
- **Vektory:** `vectors/vectors.json`: 3 recepty × 2 seedy (louka 101/404, kopec 303/2302, hora 202/1000) + 2 případy s transformací;
  pro každý FNV-1a 64 objemu (16 384 B) a povrchu (256 B), souhrn materiálů, 20 kontrolních buněk (10 u povrchu, 10 kdekoli).
  - nejvyšší úroveň: `generatorVersion` = `"proto-v2.2"`, `volumeHashAlgo` (přesný popis hashe), `transformFormat` (popis transformací);
    původní klíče (`generator_version`, `volume_hash`, …) zůstaly.
  - `volumeHashAlgo`: *FNV-1a 64 (offset 0xcbf29ce484222325, prime 0x100000001b3, mod 2^64) over the 16384 material bytes
    (1 byte = MaterialId) in index order (lx*16+ly)*64+lz, lx,ly in 0..15, lz in 0..63; lowercase 16-digit hex*. Ověřeno proti Pythonu na `case0_volume.bin`.
  - každý případ má `transform`: `mirror` (bool), `rotation` (stupně 0/90/180/270), `heightShift` (−4…4),
    `sides` = `{N, E, S, W}` s hodnotami `auto` / `blend1`–`blend4` / `keep` (u netransformovaných případů identita: false, 0, 0, vše `auto`;
    vektory nemají sousedy, takže strany nemají vliv). N = −ly (sever), E = +lx, S = +ly, W = −lx.
  `vectors/case0_volume.bin` = surový objem prvního případu. Výstup je deterministický (dva běhy = stejný soubor).
- **Pozor:** výšky používají `float` (exp, round) a FastNoiseLite ve float; bitová shoda s C# vyžaduje port FastNoiseLite 1:1.

## Vegetace – specifikace (veg-v2, pro backend)
Vegetace **není** ve `vectors/vectors.json` (ten je beze změny, proto-v2.2); má vlastní `vectors/veg_vectors.json`.
Generuje se po celém terénu (po transformacích a napojení stran) pro každý výsledný sloupec `(lx, ly)`, pořadí lx 0..15, uvnitř ly 0..15:
1. `h = hm[lx*16+ly]`; když `h ≤ 0`, nic. Povrch `surf = cell(lx, ly, h−1)`.
2. Zdrojový sloupec `src` = inverze transformace: `rot`-krát `(x, y) → (y, 15−x)`, pak při zrcadlení `x → 15−x`.
3. Stromy (jehličnan, listnáč) jen když `src.x` i `src.y` jsou sudé.
4. `r = mix(seed, "VEG", src.x*16 + src.y)`, `u = (r & 0xFFFFFF) / 2^24`.
5. Druhy v pořadí ID 1..8 (trs trávy, květiny, keř, jehličnan, listnáč, kaktus, suchá tráva, mech); přeskoč nepovolené pro `surf`
   (tráva: trs, květiny, keř, jehličnan, listnáč; hlína: keř; písek: kaktus, suchá tráva; vápenec/žula/čedič: mech; sníh a ostatní: nic)
   a stromy mimo sudou mřížku. Sčítej hustotu `acc += DENSITY[recept][druh]`; první druh s `u < acc` vyhrává, jinak nic.
6. Posun v buňce ve zdrojovém rámci: `ox = (((r>>>24)&0xFF)/255 − 0,5)·0,6`, `oy = (((r>>>32)&0xFF)/255 − 0,5)·0,6`;
   při zrcadlení `ox = −ox`, pak `rot`-krát `(ox, oy) → (−oy, ox)`.
7. `yaw = ((r>>>40)&0xFF)/256·360`, `scale = 0,8 + ((r>>>48)&0xFF)/255·0,4`. Záznam `{s, lx, ly, lz = h, ox, oy, yaw, scale}`.

Hustoty `[–, trs, květiny, keř, jehličnan, listnáč, kaktus, suchá tráva, mech]`:
louka `[0, .45, .10, .03, .04, .16, .03, .25, .15]`, kopec `[0, .35, .06, .03, .14, .14, .03, .25, .15]`,
hora `[0, .25, .03, .02, .30, .04, .03, .25, .15]`, písčina `[0, .20, .02, .03, 0, .04, .11, .42, .15]` (veg-v2; ve veg-v1 kaktus .08, suchá tráva .30).
Skóre druhů `[0, 1, 3, 4, 6, 6, 5, 1, 2]` (veg-v2: kaktus 8 → 5, na písčině je běžný; mediány: louka 1,84, kopec 2,09, hora 2,35, písčina 1,89); rarita vegetace = průměrné skóre na rostlinu, prahy `[0; 1,8; 2,1; 2,5; 2,9]` (zatímní).
Vektory: `recordsHash` = FNV-1a 64 nad UTF-8 řetězcem záznamů `"s,lx,ly,lz,ox,oy,yaw,scale;"` (4 desetinná místa, tečka, i `-0.0000`), plus prvních 12 záznamů jako text.
Vlastnost: náhoda závisí jen na zdrojovém sloupci, takže zrcadlení/rotace porost jen přenesou; posun výšky a napojení stran ho mění jen tam,
kde se změní povrchový materiál (např. kámen/sníh nad výškou 46/49).

## Tráva C (louky)
Převzato ze studie `../trava-studie/` (varianta C), studie zůstává samostatně pro další ladění vegetace.
- **Kde:** povrchová buňka z trávy (`Mat.GRASS`), ne pod stavbami a cestami (`island.occ_fn`). Vysoká / nízká tráva podle hodnotového šumu
  ze seedu bloku (`mix(seed, "GRASS", …)`, skvrny ≈ 4 sloupce, ve zdrojových souřadnicích, takže zrcadlení a rotace trávu jen přenesou);
  podíl vysoké podle receptu: louka 0,55, kopec 0,40, hora 0,20, písčina 0,15. Rozmístění trsů v buňce: `RandomNumberGenerator` se seedem
  `mix(seed, "GRASS_I", src.x*16+src.y)`. **Jen klient:** data vegetace, `veg_vectors.json`, rarita i delta beze změny.
- **Rostliny z dat:** „květiny“ a „suchá tráva“ (písčina) kreslí stejný shader jako louka (sdílený vítr i stopa), „trs trávy“ je teď
  součástí louky (bez zvláštního velkého trsu). Mech, keř, stromy a kaktus beze změny (`veg_render.gd`).
- **Parametry** (`scripts/grass_params.gd`, z příkazové řádky `-- --grass.klic=hodnota`, např. `--grass.tufts_tall=30 --grass.tuft_short_h=0.15`):
  výšky `tuft_tall_h` 0,30 / `tuft_short_h` 0,12, hustoty `tufts_tall` 24 / `tufts_short` 50, `flowers_tall` 0,5, `tuft_dry` 0,03,
  podíly vysoké `tall_<recept>`, vítr `wind_*`, stopa `trail_size` 32, `trail_px` 12, `trample_r` 0,42, `trample_hold` 0,35, `trample_recover` 1,6,
  `trample_bend` 1,25, úroveň detailu `lod_full_size` 20, `lod_min` 0,125; `--grass.enabled=0` = původní vykreslení veg-v2.
- **Postavičky:** `Grass.touch(id, pozice_xz, směr)` každý snímek, `Grass.tick(dt)` volá `main._process`. Okno stopy 32 × 32 jednotek jede za první
  postavičkou (posouvá se, když se přiblíží okraji), stín pod postavičkou až pro 4 postavičky. V prototypu zatím žádná herní postavička není,
  testovací je v `grass_demo.gd`.
- **Úroveň detailu:** trsy jsou v bufferu po osminách (každý 8. trs každého sloupce), při oddálení kamery (`cam.size` nad 20) se kreslí jen
  část (`visible_instance_count`), kvítky a rostliny z dat vždy celé.
- **Ukázka a měření:** `xvfb-run … --path . -- --grass-shots` → `shots/28_trava_C_*.png`; `-- --grass-bench --tag=po` → `shots/28_trava_C_bench_po.txt`.

Výkon (llvmpipe, bez GPU, 1280 × 800; „před“ = checkpoint `cp13-pred-trava-C-1313.tgz`):

| Pohled | před | tráva C |
|---|---|---|
| startovní ostrov (4 bloky), celek | 99 ms, 549 instancí | 120 ms, 38 033 instancí (kreslí se 14 500) |
| startovní ostrov, detail louky | 53 ms | 98 ms |
| plný ostrov (24 bloků), celek | 145 ms, 3 352 instancí | 240 ms, 202 765 instancí (kreslí se 52 514); bez úrovně detailu 588 ms |
| plný ostrov, detail louky | 66 ms | 154 ms |
| stavba vegetace 1 bloku | 0,3 ms | 14–17 ms |

## Povrch louka / písek / voda (napojení ze studie `../napojeni-studie/`)
Studie `../napojeni-studie/` a `../trava-studie/` zůstávají samostatně, kód je do prototypu zkopírovaný a upravený.
- **Duální mřížka jen pro měkký povrch.** Rohy dlaždic leží ve středech buněk. Dlaždice je duální, když jsou všechny 4 rohy louka, písek
  nebo dno, nic na nich nestojí a rozdíl výšek je nejvýš `slope_max_layers` = 2 vrstvy (svah). Větší rozdíl = stěna z kostek.
  Kámen, útesy, kopání, stavby a cesty zůstávají na kostkách (`mesher.gd` vynechá čtvrtiny horních ploch a poloviny boků v duálních dlaždicích,
  na rozhraní dlaždic doplní „sukně“ `DualGridMesher`). Tvar: vyhlazený bilineár (ve studii `dual_shape` 0, zde `dual_ease` 1), měkkost `dual_soft` 0,06, bez hybridních bloků, bez iso posunu.
- **Bez švů mezi bloky.** `ShoreFields` čte okno (16 + 2·4)² sloupců z ostrova včetně úhlopříčných sousedů. Z něj počítá třídy, výšky
  a vzdálenostní pole (vzdálenost k vodě, od okraje louky, k louce; 4 texely na buňku, dvouprůchodový chamfer). Vložení bloku přestaví i 8 sousedů,
  kopání jen sousedy, k jejichž okraji má sloupec blíž než 5.
- **Písek:** šedobéžový (`sand_look` 1), procedurální zrno a vlnky (`sand_detail` 2). Pásy: mokrý utužený písek u vody `band_water` 0,75,
  písek s řídkou trávou před loukou `band_grass` 1,1, podíl trsů `mix_tufts` 0,18. Pěna, vlny a ztenčení trávy jdou z polí.
- **Louka přímo u vody:** travnatý břeh, pás bláta (`mud_w`), slabší pěna (`foam_bank` 0,3). **Rákos v terénu není,** bude samostatná entita vegetace (TODO).
- **Procedurální louka, varianta 3 „sladěná“:** stejný šum `pg_*` barví zem (`terrain_toon` / `terrain_surface`) i trsy (`grass_tuft`, `ground_match`).
- **Hladina vody (jen vykreslení, nová věc):** prototyp vodu neměl. Měkký sloupec pod vrstvou `water_lz` = 30 se kreslí jako dno a hladina leží
  na 30 · 0,5 − 0,15 = **14,85 m**. Poměr odpovídá studii (hladina 0,85 m = 0,35 nad dnem a 0,15 pod souší). Přírodní bloky mají povrch 30–32,
  takže voda je jen v blocích posunutých dolů a ve vykopaných jamách. Data, vektory, rarita ani delta se nemění (`vectors/` beze změny).
- **Parametry** (Resource s `@export`, české popisky): `SurfaceParams` (`scripts/surface/surface_params.gd`, CLI `-- --surface.klic=hodnota`,
  např. `--surface.water_lz=31 --surface.dual_soft=0.1 --surface.dual_enabled=0`), `GrassParams` (`--grass.klic=`). Barvy shaderů jdou z parametrů.
  Parametry označené ⟳ potřebují přestavbu: sítě se přestaví 0,4 s po poslední změně, ostatní se projeví hned (uniformy).
- **Ukázka a měření:** `xvfb-run -a -s "-screen 0 1280x800x24" $G --rendering-driver opengl3 --path . --resolution 1280x800 -- --napojeni-shots`
  → `shots/34_napojeni_{ostrov,plaz_detail,louka_u_vody_detail,sev_bloku,louka_procedural_detail,kopec_utesy}.png`
  (`--only=…` výběr, `--tag=x` přípona, `--only=paramtest --dev` vyzkouší živou změnu a předvolby); `-- --napojeni-bench --tag=po`
  → `shots/34_napojeni_bench_po.txt`. Srovnání s checkpointem `cp14-pred-napojeni-1456.tgz`: `shots/34_napojeni_pred_po.png`.
  Ukázka přidá 3 bloky posunuté dolů (písčina 4504 −1, louka 1201 −1, louka 5000 −2), aby vznikla jezírka.
- **Omezení:** v řezu (PageDown) je duální povrch vypnutý (jen kostky). Náhled kandidáta je jen z kostek.
  Prošlapání země a stín postavičky z `meadow_ground` studie zatím nejsou. Louka si drží světlou paletu prototypu, takže procedurální tón je jemnější než ve studii.

Výkon (llvmpipe, bez GPU, 1280 × 800, stejný skript `napojeni_demo.gd`; „před“ = checkpoint cp14):

| Měření | před | po |
|---|---|---|
| 7 bloků, celek | 155 ms/snímek, 310 k trojúhelníků | 173 ms, 357 k |
| 7 bloků, detail pláže | 123 ms | 129 ms |
| plný ostrov (24 bloků), celek | 264 ms, 913 k | 301 ms, 1 184 k |
| plný ostrov, detail pláže | 154 ms | 176 ms |
| vložení bloku (gen + sítě + sousedé + vegetace) | 81–114 ms | 434–543 ms |
| doplnění 17 bloků | 116 ms/blok | 575 ms/blok |
| kopání uprostřed / u hrany bloku | 41 / 59 ms | 123 / 253 ms |
| kostková síť bloku | 40,5 ms | 32,3 ms |
| povrch bloku (pole + duální síť a voda) | – | 37,9 + 11,4 ms |

Vložení je dražší hlavně proto, že se přestaví i 8 sousedů (pole, sítě, tráva). Návrhy zrychlení jsou v `../DENIK.md`, blok C.

## Ladicí okno (`addons/dev_tuning/`, jen pro vývoj)
- Samostatný doplněk. Hra o něm neví: `ParamRegistry` jen sbírá parametry (`register`) a statistiky (`register_stat`).
  S `-- --dev` hra načte `res://addons/*/dev_runtime.gd`, jen pokud existuje. Bez složky hra běží stejně (ověřeno).
  Export obě předvolby vylučují (`exclude_filter` … `addons/dev_tuning/*`).
- **Ovládání:** F1 zap / vyp, `-- --dev --dev-panel` = otevřené hned. Záložky Povrch a Tráva, sbalitelné sekce podle `@export_group`, posuvník
  s hodnotou, zaškrtávátko, výběr barvy; ⟳ = přestavba (zpožděná, nebo hned tlačítkem **Aplikovat**). **Reset na výchozí**, **Uložit předvolbu**
  (`user://presety/<záložka>_<název>.tres`), **Načíst předvolbu** (pro aktuální záložku). Nahoře FPS, ms snímku, instance vegetace, bloky, trojúhelníky.
- Snímek: `shots/34_ladici_okno.png` (`-- --napojeni-shots --only=panel --dev --dev-panel`).

## Delta bloku (návrh formátu, `vectors/delta_sample.json`)
```
{ "deltaFormat": "delta-v0", "generatorVersion": "proto-v2.2",
  "cellIndex": "i = (lx*16+ly)*64+lz", "islandInventory": {"hlína": 14, ...},
  "blocks": [ { "slot": [1,1], "recipe": "louka", "seed": 404,
                "transform": {"mirror": false, "rotation": 0, "heightShift": 0},
                "sides": {"N": "auto", "E": "auto", "S": "auto", "W": "auto"},
                "neighborEdgeProfiles": {"N": [16 výšek], "E": null, "S": null, "W": [16 výšek]},
                "placedVolumeHash": "…", "resultVolumeHash": "…",
                "ops": [ {"i": 2206, "lx": 2, "ly": 2, "lz": 30, "old": 1, "new": 0, "oldName": "tráva", "newName": "vzduch"}, … ] } ] }
```
**Výchozí objem (baseline)** = objem hned po vložení: přegeneruje se z receptu a seedu, použije se transformace a dorovnání stran
podle `sides` a `neighborEdgeProfiles` uložených **v okamžiku vložení** (16 výšek povrchu sousedních sloupců podél společné hrany,
klíče N/E/S/W, `t` podél hrany v souřadnicích nového bloku, `null` = soused nebyl). Pozdější změny sousedů baseline neovlivní.
`placedVolumeHash` (FNV-1a 64 nad 16 384 bajty) slouží jako kontrola přegenerování. Operace se aplikují v pořadí, `old` musí odpovídat
aktuální buňce, jinak se operace odmítne; `resultVolumeHash` = po všech operacích. Bilance materiálu: každá operace přesouvá 1 buňku
mezi blokem a inventářem. Vegetace a stavby/cesty v deltě zatím nejsou. (Dohodnuto s Willage-backendem 2026-11-17.)

## Screenshoty (`./shoot.sh`)
`01_start`, `02_nahled_hora`, `03_nahled_louka`, `04_vlozeno`, `05_detail_hran` (útes vs. dorovnání), `06_detail_otoceno`, `07_domek`, `08_rez`,
`09_selftest_mys`, `10_hory_kopce_seedy` (v2.1), `11_terasy_seedy` (v2.2, stejné seedy), `12_srovnani_v21_v22` (skládá `tools/srovnani.py`),
`13_vegetace` (louka/kopec/hora/písčina), `14a_plochy` + `14_kawaii_pred_po` (skládá `tools/kawaii_srovnani.py`), `15_cesty` (3 domky, 2 trasy),
`16_textury`, `16b_textury_detail`, `17_schody_detail` (schody a rampy na terasy), `18_kawaii_objekty` (z `18a`/`18b`),
`19_hrany` (z `19a`/`19b`), `20_hero` (celý ostrov bez UI), `20b_hero_hrany` (totéž se zaoblenými hranami),
`21_kopani` (z `21a`/`21b`: jáma 3 × 3 × 6, 3 buňky zpět, inventář a rarita před → po), `22_stavby` (studna, mlýn, políčko, zelený náhled domku, záložka Stavby). Tráva C (`-- --grass-shots`): `28_trava_C_prehled`, `28_trava_C_detail`, `28_trava_C_pruchod` (postavička ve vysoké trávě), `28_trava_C_pruchod_po_1_5s`, `28_trava_C_pruchod_obnova`, `28_trava_C_pruchod_nizka`. Napojení (`-- --napojeni-shots`): `34_napojeni_*`, `34_napojeni_pred_po`, `34_ladici_okno`. Demo vypisuje také `SELFTEST cesty picking` a `SELFTEST cesty útes` (sloupec za útesem > 4 buňky: A* cestu nenajde) a cestu na terasu hory (počet schodů).

## Výkon (box bez GPU, llvmpipe, GDScript)
Generování bloku včetně vegetace průměr ≈ 18 ms, mesh bloku (s obrysovými daty) průměr ≈ 37–41 ms, A* dvou tras ≈ 4–5 ms. Náhled se přepočítá při každé změně volby, odezva je okamžitá.

## Experiment: rozlišení bloku (`-- --res-test`)
Samostatný režim jen pro srovnávací render, hra a `--demo` zůstávají na 16 × 16 × 64 (buňka 1 × 1 × 0,5). Soubory: `scripts/res_gen.gd` (generátor), `scripts/res_mesher.gd` (kopie `mesher.gd` s proměnnou mřížkou), `scripts/res_test.gd` (scéna a snímky), `tools/res_combine.py` (spojí dvojice snímků s popisky). V `main.gd` je jen 5řádkový přepínač na začátku `_ready()`.

Knoflíky (všechny volitelné):

| přepínač | výchozí | význam |
|---|---|---|
| `--res-xy=N` | 32 | buněk na stranu bloku |
| `--res-z=N` | 64 | buněk na výšku |
| `--cell-xy=F` | 16 / res-xy | šířka buňky v jednotkách (bez zadání blok zůstane 16 široký) |
| `--cell-z=F` | 0,5 | výška buňky |
| `--res-blocks=typ:seed,…` | `hora:7777,kopec:2302` | které bloky (louka, kopec, hora, piscina) |
| `--res-ref=nxy,nz,cxy,cz` | `16,64,1,0.5` | levá (referenční) strana srovnání |

Fyzický blok = `res-xy·cell-xy × res-xy·cell-xy × res-z·cell-z`. Generátor počítá šum, výškový profil (terasy v2.2), vrstvy hornin, žíly rud, půdu (tráva/hlína/podloží) i prahy kamene a sněhu ve fyzických jednotkách (vztaženo k referenční buňce 1 × 0,5), takže tvar bloku zůstává stejný při jakémkoli rozlišení, jen jemnější. Referenční mřížka dává buňku po buňce totéž co `block_gen.gd` (v logu `RES kontrola … = true`). Textury se mapují na světové souřadnice (`tex_scale` 0,25), takže při buňce 0,5 vychází 64 px na stranu buňky.

```sh
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
X='xvfb-run -a -s "-screen 0 1280x800x24"'
# 32 × 32 × 64, buňka 0,5 (krychle)
eval $X $G --rendering-driver opengl3 --path . -- --res-test
# 32 × 32 × 128, buňka 0,5 × 0,5 × 0,25, jen hora
eval $X $G --rendering-driver opengl3 --path . -- --res-test --res-xy=32 --res-z=128 --cell-z=0.25 --res-blocks=hora:7777
# 24 × 24 × 64 při stejné šířce bloku
eval $X $G --rendering-driver opengl3 --path . -- --res-test --res-xy=24
python3 tools/res_combine.py   # spojí _L/_R snímky do shots/23_rozliseni_*.png
```

Výstup: `shots/23_rozliseni_<ref>_vs_<test>_<typ><seed>_{bez_textur,textury}[_detail].png` (vlevo reference, vpravo test, 2 × 1280 × 800) a časy v `shots/23_rozliseni_<ref>_vs_<test>_casy.txt`.

Omezení: bez vegetace, bez zrcadlení, rotace, posunu výšky a sousedů (dorovnání stran), bez cest, staveb a kopání. Obrys stěny má šířku v rámci buňky, takže u menších buněk je fyzicky tenčí.
