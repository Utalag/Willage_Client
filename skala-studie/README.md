# Willage – studie skály (Godot 4.7.2, Compatibility)

Samostatný projekt podle Janova zadání: aby skála vypadala jako skála, ne jako otexturované kostičky. Hra ani `godot-prototyp` se nemění. Odsud jsou zkopírované jen `scripts/mat.gd` (paleta), `terrain_toon.gdshader`, `assets/tex/` (textury z Gemini) a mesher kostek (`scripts/cube_mesher.gd`, kopie `res_mesher.gd`).

## Vzorek
Voxelová mřížka 10 × 10 × 4 buněk (vápenec a žula), deterministicky ze seedu (`scripts/chunk.gd`). Obsahuje tři situace:
- **souvislou skálu**: útes vzadu se stupni dolů, souvislou spodní vrstvou a výklenky (chybějícími buňkami);
- **shluky 2–6 buněk**, které se ničeho nedotýkají, ani úhlopříčně;
- **osamocené buňky** (1 buňka).

Pod sloupci s plnou spodní buňkou je podloží, takže kameny sedí v zemi a prázdná místa nemají skalní podlahu.

## Přístupy
| | Co to je | Soubor |
|---|---|---|
| A | Dnešní kostky z prototypu, AO ve vrcholech [3], textura z Gemini, obrys hran | `cube_mesher.gd` + `terrain_toon.gdshader` |
| B | Kostky s rozbitím: vrchol mřížky se posune k těžišti okolních plných buněk (sražené hrany a rohy, osamocená buňka se zaoblí), deterministický šum vrcholů [5], každá stěna se rozdělí na 8 trojúhelníků s vysunutým nebo vpadlým středem. Mřížka zůstává vodotěsná. | `breakup_mesher.gd` |
| C | Souvislý povrch nad voxely, Surface Nets [1][2]: hustota = zostřená trilineární plnost buněk + šum [9] + vodorovné římsy [13]. Šum a římsy slábnou podle „hmotnosti“ okolí, takže osamocená buňka je oblý kámen, shluk balvan a souvislá vrstva členitá skála. Ploché fazety. | `nets_mesher.gd` |
| D | Hybrid podle souvislých komponent: 1 buňka = kámen z Blenderu, 2–6 buněk = jeden balvan z Blenderu natažený na obal shluku, víc buněk = skála z C. Kameny jsou odštípnuté kvádry (8 variant, řezy rovinou [11]). | `pieces.gd`, `blender/kameny.py` |

Skalní shader `rock.gdshader` (B, C, D):
- ploché fazety z derivací polohy [10];
- triplanární textura [8];
- vrstvy (pruhy a tenké spáry, jen na bocích) [13];
- řídké praskliny z buněčného šumu [4][6][7];
- tmavší dutiny (AO z vrcholů) a kontaktní stín u země;
- stejný pastelový toon ramp jako terén v prototypu.

Obrys je inverted hull [12] (`outline.gdshader`).

## Spuštění
```sh
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
xvfb-run -a -s "-screen 0 1280x800x24" $G --rendering-driver opengl3 --path .                                 # buňka 0,5 × 0,5 × 0,5
xvfb-run -a -s "-screen 0 1280x800x24" $G --rendering-driver opengl3 --path . -- --cell=1,0.5 --suffix=_c1x1x05
xvfb-run -a -s "-screen 0 1280x800x24" $G --rendering-driver opengl3 --path . -- --scale-test                  # časy pro 32 × 32 × 64
python3 tools/sheet.py "" "" "" "popisek"        # 2 × 2 srovnání + detail; s příponou: tools/sheet.py _c1x1x05
/workspace/tools/blender-5.3.0-linux-x64/blender -b -P blender/kameny.py -- assets 8   # znovu vygenerovat kameny
```
Přepínače: `--cell=šířka,výška`, `--seed=7`, `--size=10,10,4`, `--only=ABCD`, `--suffix=…`.

Knoflíky v kódu:
- B: `round_amt`, `jitter`, `bulge`;
- C: `res` (vzorků na buňku), `noise_amp`, `ledges`, `facet_jitter`, `sharpen`;
- D: `cluster_max`.

## Výstupy (`shots/`)
- `24_skala_srovnani.png`: A–D vedle sebe, buňka 0,5 × 0,5 × 0,5. Detail je v `24_skala_detail.png`.
- `24_skala_srovnani_c1x1x05.png` a `24_skala_detail_c1x1x05.png`: totéž s buňkou 1 × 1 × 0,5.
- `24_skala_<A–D>[_c1x1x05][_detail].png`: jednotlivé snímky 1280 × 800.
- `24_skala_casy*.txt` a `24_skala_skalovani_32x32x64.txt`: časy.

## Výsledky (box bez GPU, llvmpipe, GDScript)
| | vzorek 10 × 10 × 4: stavba / trojúhelníky | blok 32 × 32 × 64 (20 373 plných buněk): stavba / trojúhelníky |
|---|---|---|
| A | 5 ms / 660 | 129 ms / 18 528 |
| B | 11 ms / 2 112 | 397 ms / 69 688 |
| C | 121 ms / 2 230 | 7,3 s / 103 386 |
| D | 112 ms / 2 048 (2 kameny, 4 balvany, 1 skála) | 7,2 s / 103 204 |

## Zjištění
- **A**: čisté a čitelné, ale pořád „kostičky“. Osamocená buňka, shluk i skála vypadají stejně.
- **B**: hodně za málo. Je rychlé (asi 3× A), drží voxelovou čitelnost (je vidět, kde je buňka, a dobře se to kope) a sražené hrany s vrstvami už působí jako skála. Osamocená buňka je hranatý kámen, ale shluk je pořád poskládaný z kostek a nevypadá jako jeden balvan.
- **C**: vypadá nejvíc jako skála a samo řeší Janovu podmínku: buňky se slijí podle sousedství, kámen, balvan i útes vzniknou bez zvláštních pravidel. Nevýhody:
  - je 25–50× pomalejší v GDScriptu (pro hru by chtělo C#/GDExtension nebo výpočet po částech v pozadí);
  - hrana buňky není přesně vidět, takže kopání bude muset ukazovat zvýrazněnou buňku;
  - na blok má asi 100 tis. trojúhelníků (bude chtít zjednodušení nebo LOD na dálku).
- **D**: kameny a balvany mají jasný tvar „předmětu“ a skála je z C. Balvan je ale jen kámen natažený na obal shluku, takže tvar shluku (L, T) se ztratí. Kousky z Blenderu jsou levné a variabilní, ale potřebují víc ruční práce.

Poznámky k implementaci:
- Ploché fazety se kreslí v shaderu z derivací, normály v meshi jsou hladké kvůli obrysu.
- V C se náhodný posun vrcholů tlumí u země. Jinak se okraj sítě překládal a vznikaly tmavé trojúhelníky.
- Úhlopříčka každého quadu se volí tak, aby oba trojúhelníky mířily ven.

## Co chybí
- Vegetace, sousední bloky (okraje), kopání a LOD.
- Marching Cubes [14] jsem nezkoušel, Surface Nets dávají pro low-poly vzhled méně trojúhelníků a pravidelnější fazety.
- Shader neumí přepnout texturu podle výšky vrstvy (vrstvy jsou jen pruhy, ne jiný materiál).

Zdroje: viz `ZDROJE.md`.

---

## Přístup C na celém bloku (Janova volba): jen buňky u povrchu
Režim `-- --block` (`scripts/block_test.gd`) vezme horu seed 7777 32 × 32 × 64 (buňka 0,5³, reliéf v2.2 jako v prototypu: kopie `res_gen.gd` a části `block_gen.gd` ve `scripts/hora/`) a postaví ji novým `scripts/rock_volume.gd`.

**Janův nápad v praxi:**
- Vnitřek zůstává jen v 3D poli buněk. Navíc má každý sloupec 64bitovou masku (bit y = plná buňka), takže se „smíšené“ bloky 2 × 2 × 2 buněk u povrchu najdou několika bitovými operacemi na sloupec, bez procházení vnitřku.
- Hustota (šum [9], římsy [13]) se počítá jen ve vzorcích smíšených bloků. Jinde je znaménko jasné (plno nebo vzduch), takže se nic nepočítá. Výsledky se ukládají do mezipaměti.
- Surface Nets [1][2] běží jen nad kandidátními krychlemi. Normála je gradient z 8 rohů krychle, dutiny se berou z rozmazané obsazenosti, takže se nemusí znovu vzorkovat.
- Blok je rozdělený na podbloky (chunky 16³ nebo 8³, `--chunk=`). Úprava buňky zneplatní jen vzorky v okolí ±2 buněk a přestaví jen dotčené chunky. Švy mezi chunky sedí, protože vrcholy jsou deterministické ze stejné mezipaměti.
- Materiál je ve shaderu `flat`, aby se mezi trávou a kamenem nemíchaly indexy textur. Vrstvy a praskliny se kreslí jen na horninách.

**Čísla** (box bez GPU, hora 7777 32 × 32 × 64):

| | čas | trojúhelníků |
|---|---|---|
| dřív `nets_mesher.gd` (celá mřížka) | 7 021 ms | 93 044 |
| teď GDScript, jen okolí povrchu | 983 ms (7×) | 93 270 |
| teď C# benchmark (stejný algoritmus [17][18]) | 65–120 ms | 93 270 (stejně jako GDScript) |
| LOD 1 vzorek/buňku, GDScript / C# | 274 ms / 9–15 ms | 22 762 |
| kopání, chunk 16³, GDScript | průměr 167 ms, max 219 ms (3,3 chunku na úpravu) | |
| kopání, chunk 8³, GDScript | průměr 29 ms, max 52 ms (4,4 chunku na úpravu) | |
| přestavba 1 chunku 16³, C# | 2,8 ms | |

- Buňky: 65 536 celkem, 39 773 plných, z toho jen 6 049 (15 %) sousedí se vzduchem. Smíšených bloků je 7 828. Šum se počítá jen v 57 344 vzorcích z 623 691 (9 %).
- Profil GDScript (první stavba): hustota 432 ms, vrcholy 226 ms, quady 188 ms, hledání kandidátů 28 ms, nahrání meshe do GPU 4 ms. Druhá stavba s plnou mezipamětí trvá 541 ms, takže zbytek je cena GDScriptu ve smyčkách.
- C# benchmark (`csharp_bench/`, `dotnet run -c Release -- hora7777.bin`) běží mimo Godot jen na .NET SDK. Godot .NET (sestavení s C#) na boxu není, je jen standardní Godot 4.7.2 [15], takže C# zatím nemohl běžet uvnitř hry. Druhá cesta je GDExtension v C++ [16].

**Snímky** (`shots/`):
- `26_skala_C_blok.png`, `26_skala_C_blok_zezadu.png`: celý blok;
- `26_skala_C_blok_vs_lod.png`: plné rozlišení proti LOD;
- `26_skala_C_detail.png`: detail;
- `26_skala_C_kopani_pred_po.png`: před a po vykopání 3 × 3 × 3 buněk;
- `26_skala_C_casy.txt`: časy.

**Co chybí pro zapojení do hry:**
1. Horkou smyčku přepsat do C# (nebo GDExtension) a spouštět ji ve vlákně po chuncích.
2. Švy mezi bloky: dnes je okraj bloku „řez“ (stěna do vzduchu). Pro ostrov se musí hustota u hrany číst ze sousedního bloku, tedy obal o 1–2 buňky, stejně jako mesher prototypu načítá okraje sousedů.
3. LOD: vzdálené bloky s 1 vzorkem na buňku (4× méně trojúhelníků), přepínat podle kamery.
4. Výběr buňky při kopání: Surface Nets nemají přesné hrany buněk, proto potřebujeme zvýraznění (rámeček) a raycast do voxelů, ne do meshe.
5. Na hranách teras zůstávají drobné travnaté schůdky (stejně jako v `--res-test` prototypu). Pomohlo by vyhlazení výškové mapy nebo převod strmých buněk na skálu.
