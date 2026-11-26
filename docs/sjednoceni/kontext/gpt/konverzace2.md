# Architektura vykreslování terénu

Zdroj: https://chatgpt.com/share/6b04246b-4a10-83eb-816c-45acdc7b9fe8

Počet zachycených zpráv: 37

---

### 1. Uživatel

Projekt Willage: hra s plovoucími ostrovy (Godot 4.7, GDScript, později server v C#). Pracuju na procedurálním generátoru terénu V1.0 a chci probrat, jak vykreslovat data, která generuje.

HIERARCHIE
Svět → blueprint → ostrov → blok → segment → buňka.
- Svět je deterministická funkce ze seedu (max 4096 × 4096 m). Neukládá se, jen se z ní čte.
- Z výřezu světa se vezmou blueprinty (bloky 128 × 128 m). Ostrov je seznam vložených blueprintů, každý s posunem, otočením o 90°, zrcadlením a výškovým posunem; může pocházet i z jiného světa. Výchozí ostrov má 3 × 3 bloky.
- Blok se dělí na segmenty 8 m (parametr 8/16/32 m), segment na buňky (voxely) 0,25 m.
- Výška sloupce je 32/64/128 m (výchozí 128 m = 512 buněk), neutrální úroveň je v polovině.
- Jednotka scény je 1 m. Determinismus je povinný: stejný seed, parametry a verze generátoru dají bitově stejný svět (float64, celočíselné hashe).

FUNKCE SVĚTA (dotaz v metrech)
- Bod (x, y, z) vrátí materiál, sloupec (x, y) vrátí výšku povrchu, hranice vrstev a hladinu vody.
- Klima: každý svět má ze seedu základní klima (mírné, poušť, step, tundra, ledovec). Preset z tabulky upraví vstupní parametry (poušť je plošší a má méně vody) a určí, které biomy se v něm vyskytují. Pomalá mapa ho uvnitř světa mírně mění.
- Reliéf: mapa biomů a mapa hornin (hrubé body ze seedu a plynulá interpolace). Každý biom má parametry převýšení, vlnové délky, drsnosti a stropu sklonu; v přechodech platí vážený průměr. Drobné skály do ~2 m smí strop sklonu překročit.
- Dále masiv (vysoká hora se stěnou a podhůřím) a sopky s kráterem.
- Geologie: vrstvy hornin kopírují terén a vyklíňují (min. mocnost 0,25 m). Útvary (žíly, pně, dómy, kras, dutiny, minerály) jsou SDF z hashe světové mřížky, takže jsou spojité přes švy bloků. Sopka má uvnitř průduch a slupky lávy a popela. Materiály jsou v jedné tabulce (78 id, 1 B na buňku).
- Podzemní voda a prameny jsou také funkcí geologie, bez uložených buněk.

OSTROV A BUŇKY
- Bloky se napojují jen po stranách: malý výškový rozdíl jako rampa, větší jako útes; volitelně se prolnou i podzemní vrstvy.
- Buňky se generují jen v zorném poli plus okraji, a jen jako slupka 2–3 buněk u vzduchu nebo pod průhlednou vodou. Hlubší buňky se donačtou při odkrytí (kopání).
- Kope se po 0,25 m. Ukládá se jen rozdíl proti funkci, po segmentech (klíče + deflate).
- Voda na ostrově se simuluje (povrch i podzemí, vsakování, prameny, kras). Přepočet po výkopu běží asynchronně na pozadí. Eroze je samostatná vrstva posunu výšky nad funkcí (kladná i záporná).
- Pak povrchové jevy klimatu (písek, led, sníh, zamrzání) a vegetace jako funkce seedu, materiálu, sklonu a vody (ukládají se jen změny jako kácení nebo výsadba).

VYKRESLOVÁNÍ (to chci probrat)
- Vykreslení data jen čte, nesmí je měnit.
- Izometrický pohled, pevný zoom 64 buněk (16 m) na šířku obrazovky, jedno rozlišení bez LOD. Cílem je i telefon.
- Dnes je v prototypu mesher, který staví 3D povrch z voxelů. Zda bude finální prezentace 2D nebo 3D, je zatím odložené.
- Okraj ostrova: bok jako jednoduché bloky s texturou do 5 m pod nejnižší okrajovou buňkou, pod ním oblaka. Voda na okraji padá jako vodopád do oblak a dál se nesimuluje.
- Předměty mezi kamerou a postavou (a podzemí nad postavou) se zprůhlední nebo odříznou. Mám prototyp válce od postavy ke kameře s ditherem a řez, obojí za přepínačem.
- Styl: ručně malovaný stylizovaný izometrický look (Wakfu/Dofus), sytá tráva přetažená přes hranu, balvanité skalní vrstvy pod okrajem, visící kameny a kořeny pod ostrovem.

OTÁZKY K DISKUZI
Jak vykreslit voxely 0,25 m tak, aby to vypadalo měkce a malovaně, ne kostičkovaně (smooth meshing jako marching cubes nebo dual contouring, nebo bloky s texturou, shadery, triplanární texturování)? Jak dělat přechody materiálů, okraj s převislou trávou, vodu, vodopády a zprůhlednění, a jak to vše utáhnout na telefonu?

---

### 2. Asistent (shrnutí uvažování)

Přemýšlel po dobu 1m 8s

---

### 3. Asistent

# Willage V1.0 – architektura vykreslování voxelového terénu

Za mě je u Willage potřeba oddělit dvě věci, které se na první pohled zdají totožné:

1. **Reprezentace světa** – jak jsou terén, geologie, materiály, voda a změny matematicky definovány.
2. **Vizualizace světa** – jak tato data převedeme do grafické podoby, kterou hráč vidí.

Tohle oddělení bych považoval za jeden z nejdůležitějších architektonických principů celého projektu.

Z tvého popisu vyplývá, že máš poměrně propracovaný procedurální model. Byla by škoda, kdyby jeho výslednou podobu omezoval způsob, jakým dnes funguje prototypový voxelový mesher.

**Moje předběžné doporučení: zachovat voxelovou reprezentaci jako zdroj geometrie a materiálů, ale nevázat výsledný vzhled na klasický voxelový rendering.**

Pro Willage bych zvažoval hybridní renderer:

- Smooth geometry pro hlavní terén.
- Samostatnou stylizovanou geometrii pro hrany, převisy a dekorativní prvky.
- Vertex blending a shaderové přechody materiálů.
- Samostatný vodní renderer.
- Chunk-based aktualizace geometrie po editaci.
- Jednoduché, předpočítané geometrické reprezentace pro vzdálenější a nezměněné části.

Tím získáš možnost později přejít mezi 3D a 2D prezentací, aniž bys musel přepisovat generátor světa.

---

# 1. Jak převést voxelová data na měkký terén

Nejdříve je potřeba rozhodnout, co vlastně znamená buňka 0,25 m.

V současném návrhu je to především **výpočetní jednotka**, nikoliv nutně výsledný polygon.

To je důležité rozlišení.

Pokud máš například skalní stěnu vysokou 8 metrů, můžeš ji reprezentovat 32 buňkami, ale výsledná geometrie nemusí obsahovat 32 viditelných schodů.

## Tři hlavní přístupy

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="voxel terrain blocky minecraft style 3D terrain cliff" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **A. Block meshing**

      Každá buňka je krychle. Odstraňují se vnitřní stěny a vykreslují pouze viditelné plochy.

      <badge color="success">Jednoduché a rychlé</badge>
      - Výborné pro těžbu a přesné destrukce.
      - Přirozeně zachovává materiálové hranice.
      - Výsledkem je ale typický kostičkovaný vzhled.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="marching cubes smooth voxel terrain stylized 3D landscape" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **B. Marching Cubes**

      Z hodnot na rozích buněk vytváří polygonální povrch podle izoplochy.

      <badge color="success">Dobré pro organický terén</badge>
      - Plynulé svahy a skalní útvary.
      - Dobře se hodí pro kopce a jeskyně.
      - Materiálové hranice a ostré hrany vyžadují další řešení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="dual contouring voxel terrain sharp features smooth cave walls 3d" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **C. Dual Contouring**

      Využívá průsečíky a normály povrchu k umístění vrcholů polygonů.

      <badge color="info">Zajímavé pro geologii</badge>
      - Zachovává ostré hrany a zlomy.
      - Dobře reprezentuje jeskyně, žíly a skalní stěny.
      - Implementace a topologie jsou složitější.
    </box>
  </row>
</box>

### Co bych vybral?

Pro Willage bych jako první implementoval **Marching Cubes s rozšířenou materiálovou reprezentací**.

Dual Contouring bych nechal jako experimentální variantu.

Důvod je jednoduchý: hlavní vizuální charakter hry má být měkký, organický a malovaný. Nejde o geologický CAD systém, kde musí každá hrana přesně odpovídat geometrii vrstvy.

Zároveň ale nechceš ztratit možnost vytvářet ostré skalní zlomy.

Proto bych nepoužíval jeden univerzální povrchový algoritmus pro všechny vizuální prvky.

### Pozor na jednu věc: materiálová data

Pokud dnes každá buňka obsahuje pouze jedno ID materiálu, samotné Marching Cubes ti nevytvoří kvalitní přechody.

Například hranice mezi:
- půdou,
- jílem,
- kamenem,
- skalním podložím,

může být ve skutečnosti nepravidelná a plynulá.

Doporučil bych proto oddělit:

- `Density` – zda se v místě nachází pevná hmota.
- `MaterialId` – dominantní materiál.
- `MaterialWeights` – případné váhy okolních materiálů.
- `SurfaceNormal` – normála výsledného povrchu.

Nemusíš ukládat všechny tyto hodnoty do každé buňky. Mohou se dopočítávat při generování meshe z funkce světa a lokálních změn.

## 2. Jak dosáhnout ručně malovaného vzhledu

Tady bych oddělil geometrii od výtvarného zpracování.

Smooth mesh sám o sobě ještě neznamená malovaný vzhled. Může vypadat jako hladký plastový model.

Pro styl Wakfu/Dofus bych kombinoval čtyři vrstvy.

<AsyncImageGroup query={["Wakfu Dofus game stylized hand painted grass terrain cliff edge","stylized hand painted fantasy game terrain cross section layered rock cliff","Dofus Wakfu floating island terrain grass rock roots art","hand painted stylized fantasy game environment rocks grass texture"]} aspectRatio="5:4" layout="bento"/>

### Vrstva 1 – geometrie

Geometrie definuje:
- obrys terénu,
- sklon,
- převisy,
- jeskyně,
- skalní výčnělky,
- hrany vrstev.

Základní povrch bych generoval z voxelových dat, ale nevyžadoval bych, aby každý detail odpovídal přesně jedné buňce.

Například:

| Vlastnost | Rozměr |
|---|---:|
| Výpočetní buňka | 0,25 m |
| Vzorkování geometrie | 0,25 m |
| Velikost segmentu | 8 m |
| Rozsah segmentu | 32 × 32 buněk |
| Okrajový halo prostor | minimálně 1 buňka |

U Marching Cubes je halo důležité pro spojení sousedních segmentů. Bez něj vznikají švy.

### Vrstva 2 – materiálový vzhled

Tady bych použil kombinaci `Texture Array`, `Vertex Colors` a `Triplanar Mapping`.

Každý materiál bude mít vlastní vzhled:

- tráva – malované barevné plochy a jemné barevné variace,
- hlína – nepravidelné barevné skvrny,
- jíl – hladší plochy s barevnými přechody,
- kámen – větší nepravidelné barevné struktury,
- podloží – tmavší, výraznější skalní kresba.

Důležitá věc: nepoužíval bych klasické opakování malé textury přes celou plochu. Vznikne nepříjemný opakující se vzor.

Místo toho:

- základní textura s nízkou frekvencí detailů,
- barevná variace podle světového souřadnicového systému,
- nepravidelné přechody mezi materiály,
- drobné detaily přidané až shaderem.

### Jak udělat přechod dvou materiálů?

Představ si hranici trávy a kamene.

<AsyncImage query="stylized hand painted game terrain grass to stone seamless organic material transition" aspectRatio="16:9" width="100%"/>

Místo ostré hranice materiálů můžeš používat váhu přechodu:

\[
C = w_1 T_1 + w_2 T_2
\]

kde \(w_1+w_2=1\).

V praxi bych používal minimálně:

- dominantní materiál,
- sekundární materiál,
- blend váhu,
- případně masku nepravidelnosti.

Pro mobilní zařízení bych ale nedělal plnohodnotné triplanární čtyřmateriálové míchání na každém pixelu. To by bylo zbytečně nákladné.

**Moje doporučení:**

| Povrch | Způsob vykreslení |
|---|---|
| Horní povrch | UV / world-space mapping |
| Svislé skály | Triplanar mapping |
| Přechody vrstev | Vertex blending |
| Drobné barevné odchylky | Shader noise |
| Specifické útvary | Samostatné mesh objekty |

Triplanar bych navíc aktivoval podle normály. Horní plochy tak nemusí platit cenu za projekci ze tří směrů.

---

## 3. Okraj ostrova – tady bych udělal výjimku z univerzálního meshe

Tohle je podle mě jedna z nejdůležitějších vizuálních částí Willage.

Ostrov není klasická krajina. Hráč vidí jeho horní povrch, boční geologickou strukturu a spodní část zavěšenou v oblacích.

Nedělal bych proto celý okraj jako pokračování Marching Cubes meshe.

Použil bych samostatný systém.

<AsyncImageGroup query={["stylized floating island grass overhanging edge fantasy game art","hand painted floating island rocky underside roots fantasy game","stylized floating island cliff layered rock strata game asset","fantasy floating island hanging stones roots clouds game art"]} aspectRatio="5:4"/>

### Navrhovaná struktura okraje

<box border radius="lg" gap={2} padding={3}>
  <box background="#648C45" theme="dark" radius="md" padding={3} align=center>
    **A. Povrchová tráva**

    <text color="#FFFFFF" size="xs">Hlavní terrain mesh + samostatné převislé okraje</text>
  </box>
  <box background="#94764A" theme="dark" radius="md" padding={3} align=center>
    **B. Půdní vrstva**

    <text color="#FFFFFF" size="xs">Hlína, kořeny, menší výčnělky</text>
  </box>
  <box background="#777C83" theme="dark" radius="md" padding={3} align=center>
    **C. Skalní vrstvy**

    <text color="#FFFFFF" size="xs">Geologické pásy, balvany, převisy</text>
  </box>
  <box background="#545E72" theme="dark" radius="md" padding={3} align=center>
    **D. Spodní část**

    <text color="#FFFFFF" size="xs">Visící kameny, kořeny, dekorativní útvary</text>
  </box>
  <box background="#AAB5CB" theme="dark" radius="md" padding={3} align=center>
    **E. Oblaka**

    <text color="#FFFFFF" size="xs">Atmosférická vrstva pod ostrovem</text>
  </box>
</box>

### A. Převislá tráva

Nedělal bych ji pouze texturou.

Použil bych samostatný okrajový mesh, který se generuje podle horní siluety terénu.

Může mít například:
- nepravidelnou spodní linii,
- lokální převisy,
- trsy trávy,
- drobné kořeny,
- malé výstupky.

Důležité je, že tento mesh může být generovaný z profilu terénu a nemusí kopírovat každou voxelovou buňku.

### B. Skalní vrstvy

Tady bych využil geologický model, který už máš.

Horní a spodní hranice vrstev můžeš převést na geometrické pásy.

Každý pás může mít vlastní:
- tloušťku,
- barvu,
- profil hrany,
- drsnost,
- typ textury.

Výsledkem bude čitelná geologická struktura, nikoliv pouze barevně odlišené voxely.

### C. Visící kameny a kořeny

Ty bych generoval jako samostatné objekty.

Vstupy:
- seed,
- geologický materiál,
- sklon spodní plochy,
- vzdálenost od okraje,
- velikost ostrova.

Použil bych `MultiMeshInstance3D`, protože stovky dekorativních kamenů a kořenů nemusí znamenat stovky samostatných draw calls.

---

# 4. Voda – oddělit simulaci a rendering

Tvoje rozhodnutí, že voda bude samostatná simulační vrstva, je správné.

Stejně tak bych ji oddělil v rendereru.

Simulace by rendereru poskytovala pouze výsledná data:

- výšku hladiny,
- hloubku vody,
- směr proudění,
- rychlost,
- případně průhlednost nebo zákal.

Renderer z toho vytvoří vizuální reprezentaci.

<AsyncImageGroup query={["stylized hand painted fantasy game shallow river water surface","stylized fantasy game waterfall floating island clouds","cartoon hand painted water stream game environment"]} aspectRatio="5:4"/>

### Povrchová voda

Pro Willage bych použil vlastní vodní mesh.

Nedělal bych vodu jako průhlednou krychli v každé buňce.

Povrch vody může být:
- samostatná polygonální plocha,
- přizpůsobená terénu,
- rozdělená podle segmentů,
- s lokální deformací hladiny.

Shader může obsahovat:
- jednoduchou animaci UV,
- jemné normálové vlnění,
- barevný gradient podle hloubky,
- okrajovou světlejší linii,
- jednoduchý odlesk.

Pro ručně malovaný styl bych se vyhnul realistické vodě s výrazným Fresnelovým efektem a komplikovanou refraction.

Voda by měla působit jako stylizovaná malovaná plocha, nikoliv jako fyzikálně realistické sklo.

### Vodopády

Vodopád bych nikdy nesimuloval jako pokračování běžné povrchové vody.

Při překročení okraje ostrova vytvoříš událost:

`WaterfallEmitter`

Ten dostane:
- počáteční pozici,
- šířku,
- objemový průtok,
- směr,
- případně barvu vody.

A vytvoří:
1. Pádovou geometrii – zakřivený pás.
2. Animovanou texturu – proudění směrem dolů.
3. Částečky – rozstřik.
4. Mlhu – měkký oblak u spodního okraje.

Voda se v místě opuštění ostrova přestane simulovat. Vizuální vodopád může pokračovat do oblaků.

Tím získáš velmi výrazný vizuální efekt za relativně nízkou výpočetní cenu.

---

# 5. Zprůhlednění překážek mezi kamerou a postavou

Tvůj současný prototyp s válcem a ditherem je dobrý směr.

Pro izometrickou kameru bych ale zvážil trochu obecnější řešení.

<AsyncImageGroup query={["isometric game camera occlusion fade character behind trees cutaway","isometric game building roof transparency character visibility cutaway","isometric game terrain cave cutaway visibility character"]} aspectRatio="5:4"/>

Rozdělil bych problém na dvě situace.

### A. Objekt zakrývá postavu

Například strom, skála nebo budova.

Použil bych prostor mezi kamerou a postavou.

Objekt, který protíná tento prostor, dostane parametr `OcclusionFactor`.

Shader následně:
- sníží jeho viditelnost,
- použije dither,
- případně jej zcela odřízne.

Dither bych preferoval před klasickou průhledností.

Proč?

Klasická průhlednost způsobuje problémy s pořadím vykreslování, zejména u překrývajících se objektů. Dither umožňuje zachovat běžné depth testování.

### B. Podzemí zakrývá postavu

Tady bych nepoužíval stejný válec.

Vhodnější je definovat řeznou oblast kolem postavy a jejího okolí.

Například:

- postava vstoupí do jeskyně,
- nad ní se vytvoří oblast omezené viditelnosti,
- strop a okolní terén se lokálně zprůhlední,
- ostatní části ostrova zůstanou beze změny.

Pro oba případy bych vytvořil jeden společný systém:

`VisibilityController`

Ten nebude měnit geometrii ani světová data. Pouze předává rendereru parametry viditelnosti.

### Důležitý technický detail

Řez musí fungovat konzistentně pro:

- hlavní terrain mesh,
- dekorace,
- vegetaci,
- kameny,
- případně stíny.

Jinak se může stát, že například kámen zmizí, ale jeho stín zůstane na zemi.

---

# 6. Výkon na telefonu

Tady je podle mě zásadní výhoda tvého současného návrhu.

Při pevném zoomu 16 m na šířku obrazovky a buňce 0,25 m vychází:

\[
16 / 0{,}25 = 64
\]

Na šířku tedy hráč vidí přibližně 64 buněk.

To je relativně malá oblast.

Při segmentu 8 m odpovídá zorné pole přibližně dvěma segmentům na šířku. S okrajem pro sousední geometrii počítej s několika dalšími.

<box border radius="lg" padding={3} gap={3}>
  **Orientační prostorové rozdělení**
  <box gap={1}>
    <grid columns={4} gap={1}>
      {#each ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P"] as v}
        <grid-item>
          <box background={["F","G","J","K"].includes(v) ? "rgba(34,197,94,0.23)" : "surface-tertiary"} radius="sm" aspectRatio="1" align=center justify=center>
            <text size="xs" weight="medium">{v}</text>
          </box>
        </grid-item>
      {/each}
    </grid>
    <row align=center wrap="wrap" gap={3}>
      <row align=center gap={1}>
        <box background="rgba(34,197,94,0.4)" size="10px" radius="xs"/>
        <caption>Viditelná oblast</caption>
      </row>
      <row align=center gap={1}>
        <box background="surface-tertiary" size="10px" radius="xs"/>
        <caption>Sousední segmenty</caption>
      </row>
    </row>
  </box>
  <text color="secondary" size="xs">Ilustrativní rozdělení segmentů, nikoliv přesný výpočet kamerového frustumu.</text>
</box>

Doporučil bych následující optimalizace:

| Oblast | Optimalizace |
|---|---|
| Geometrie | Chunk meshing |
| Generování | Background workers |
| Aktualizace | Pouze dirty segmenty |
| Materiály | Texture Array |
| Dekorace | MultiMesh |
| Voda | Samostatný mesh |
| Stíny | Omezený počet světel |
| Viditelnost | Frustum + occlusion |
| Paměť | Cache generovaných meshů |
| Kolize | Samostatný zjednodušený mesh |

### Co bych rozhodně nedělal

- Negeneroval bych mesh pro celý ostrov najednou.
- Nepřepočítával bych sousední segmenty při každé změně jednoho voxelového sloupce.
- Nepoužíval bych drahé triplanární shaderové výpočty na všech površích.
- Nevytvářel bych samostatný Node pro každou buňku.
- Nespoléhal bych na průhledné materiály pro každé zakrytí.
- Neprováděl bych simulaci vody v grafickém vlákně.

### Aktualizace po kopání

Při vykopání buňky:

1. Změní se lokální override dat.
2. Označí se příslušný segment jako `Dirty`.
3. Pokud změna zasahuje hranici, označí se také sousední segment.
4. Background worker vypočítá nový mesh.
5. Výsledek se předá hlavnímu vláknu.
6. Hlavní vlákno vymění mesh.

Přitom bych oddělil aktualizaci geometrie od aktualizace materiálových dat. Změna barvy nebo materiálu nemusí vždy vyžadovat přepočet celé geometrie.

---

# 7. Jak bych to poskládal v Godot

Doporučuji, aby renderer nebyl součástí generátoru terénu.

Generátor poskytuje dotazovací rozhraní. Renderer z něj sestavuje grafickou reprezentaci.

Navrhovaná struktura:

```text
World
 ├── WorldGenerator
 │    ├── Climate
 │    ├── Biome
 │    ├── Terrain
 │    ├── Geology
 │    └── Materials
 │
 ├── Island
 │    ├── BlueprintInstances
 │    ├── TerrainOverrides
 │    ├── Erosion
 │    └── WaterSimulation
 │
 └── Presentation
      ├── Camera
      ├── TerrainRenderer
      │    ├── SegmentManager
      │    ├── DensitySampler
      │    ├── MeshBuilder
      │    └── MeshCache
      │
      ├── MaterialRenderer
      ├── WaterRenderer
      ├── IslandEdgeRenderer
      ├── VegetationRenderer
      ├── OcclusionRenderer
      └── AtmosphereRenderer
```

## Důležitý návrh: Rendering API

Zavedl bych abstraktní rozhraní mezi světovými daty a rendererem.

Například:

```gdscript
class_name ITerrainSource
extends RefCounted

func get_surface_height(x: float, y: float) -> float:
    pass

func get_material(x: float, y: float, z: float) -> int:
    pass

func get_density(x: float, y: float, z: float) -> float:
    pass

func get_material_weights(
    x: float,
    y: float,
    z: float
) -> PackedFloat32Array:
    pass
```

Tohle je pouze koncepční návrh API, ne hotová implementace.

Všimni si zejména `get_density()`.

Tvůj současný popis pracuje s materiálem a výškou, ale pro plnohodnotné 3D smooth meshing potřebuješ také skalární reprezentaci pevné hmoty.

Například:

- záporná hodnota = pevná hmota,
- kladná hodnota = vzduch,
- nula = povrch.

Přesná konvence znamének není důležitá, důležité je, aby byla jednotná.

Tímto získáš několik výhod:

1. Renderer neví, jestli data pocházejí z generátoru, uloženého override nebo simulace.
2. Stejná data může používat 3D renderer i budoucí 2D renderer.
3. Můžeš experimentovat s Marching Cubes a Dual Contouring bez zásahu do generátoru.
4. Server v C# může později používat stejné konceptuální rozhraní.

Jedna zásadní poznámka: `get_density()` nemusí být nutně přesná geometrická signed distance function. Pro Marching Cubes stačí konzistentní skalární pole s definovanou izoplochou. Pro Dual Contouring už je kvalita gradientů a lokální geometrické informace důležitější.

# 8. Jedna důležitá věc: nepočítej celý objem segmentu

Tady vidím potenciálně největší výkonnostní problém.

Segment 8 × 8 m při výšce 128 m obsahuje:

\[
32 \times 32 \times 512 = 524\,288
\]

prostorových buněk.

To je více než půl milionu buněk na jeden segment.

Kdybys při každé aktualizaci procházel celý objem a spouštěl nad ním Marching Cubes, nebylo by to pro mobilní zařízení rozumné.

Ale tvůj datový model už obsahuje řešení: generování slupky.

Doporučil bych následující strategii:

**1. Primární povrch**

Generovat geometrii v okolí známé povrchové výšky. Využít funkci terénu a hranice geologických vrstev.

**2. Podzemní povrch**

Neexistující geometrie se vytvoří až při odkrytí materiálu kopáním. Využít lokální výpočetní oblast kolem výkopu.

**3. Jeskyně a dutiny**

Generovat pouze skutečně exponované stěny a stropy dutin.

**4. Okraj ostrova**

Zpracovávat samostatně jako geometrii bočních stěn a dekorativních vrstev.

To znamená, že nebudeš potřebovat univerzálně zpracovávat všech 512 buněk výšky každého segmentu.

---

# 9. Moje výsledná doporučená kombinace

<box border radius="lg" padding={3} gap={3}>
  <title size="lg">Willage Hybrid Terrain Renderer</title>
  <badge color="success">Doporučený směr pro V1.0</badge>
  <box gap={1}>
    <AsyncImage query="smooth stylized hand painted fantasy terrain rolling hills 3d game" aspectRatio="16:9" width="100%"/>
    **01 – Terrain Mesh**

    Marching Cubes, 0,25m sampling, lokální mesh segmenty, hladké normály.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <AsyncImage query="stylized hand painted fantasy rocky cliff layered soil grass game art" aspectRatio="16:9" width="100%"/>
    **02 – Material System**

    Texture Arrays, Vertex Blending, UV Mapping, selektivní Triplanar.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <AsyncImage query="fantasy floating island grass edge rocks roots hand painted" aspectRatio="16:9" width="100%"/>
    **03 – Island Edge**

    Samostatné okrajové meshe, převislá tráva, skalní vrstvy a dekorace.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <AsyncImage query="stylized fantasy waterfall blue water flowing over rocky cliff game art" aspectRatio="16:9" width="100%"/>
    **04 – Water Renderer**

    Povrchové plochy, proudění, vodopády, částice a mlha.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <AsyncImage query="stylized isometric game character cave cutaway terrain view" aspectRatio="16:9" width="100%"/>
    **05 – Visibility System**

    Dither clipping, lokální řezy, zprůhledňování překážek.
  </box>
</box>

## 10. Co bych skutečně implementoval jako první

Nedoporučuji začínat vodou, vegetací ani dekorativními prvky. Nejdříve musíš ověřit, že základní geometrie funguje.

Navrhuji pět implementačních etap:

| Etapa | Implementace | Kritérium úspěchu |
|---|---|---|
| 1 | Density + Marching Cubes | Hladký terén bez švů |
| 2 | Materiály a Vertex Blending | Plynulé přechody |
| 3 | Editace segmentů | Kopání bez viditelného zpoždění |
| 4 | Ostrovní okraj | Stylizované vrstvy a převisy |
| 5 | Voda a Visibility | Kompletní prezentace |

Pro první prototyp bych použil pouze čtyři materiály: trávu, hlínu, kámen a podloží.

Otestoval bych především:
- hladký kopec,
- ostrou skalní stěnu,
- přechod dvou geologických vrstev,
- převis,
- otvor v terénu,
- kopání přes hranici dvou segmentů.

Až tohle bude fungovat, má smysl přidávat výtvarnou stránku.

---

# 11. Ještě jedno architektonické rozhodnutí: 2D versus 3D

Tady bych zatím vůbec nedělal definitivní rozhodnutí.

Vidím tři možnosti:

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="Wakfu Dofus isometric 3D stylized game landscape screenshot" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Plnohodnotné 3D**

      Volná rotace kamery, plnohodnotná geometrie a světlo.

      Největší flexibilita, ale vyšší náklady na rendering a výtvarné zpracování.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="Dofus isometric game landscape screenshot hand painted" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **2.5D izometrické 3D**

      Skutečná 3D geometrie, pevná ortografická kamera, stylizované textury a světlo.

      <badge color="success">Můj favorit</badge>
      Nejlepší kompromis mezi vzhledem, destrukcí a výkonem.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="hand painted 2D isometric fantasy floating island game environment" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Čisté 2D**

      Renderované izometrické plochy, sprite vrstvy a vlastní řešení hloubky.

      Největší kontrola nad výtvarným stylem, ale komplikovanější interakce s 3D geometrií a podzemím.
    </box>
  </row>
</box>

Osobně bych pro Willage začal variantou 2.5D.

Důvodem je především kombinace:
- kopání do terénu,
- podzemních prostor,
- vrstev hornin,
- vodopádů,
- prostorového okraje ostrova.

To všechno je ve skutečné 3D geometrii přirozenější. Pevná ortografická kamera přitom zachová izometrickou kompozici a nebude vyžadovat komplikovanou perspektivu.

---

## 12. Co bych chtěl rozhodnout před implementací

Vidím tři otázky, které mají zásadní vliv na další architekturu.

{@body const [surface,setSurface] = DIL.useState("hybrid")}
{@body const [geometry,setGeometry] = DIL.useState("mc")}
{@body const [art,setArt] = DIL.useState("painted")}
<box border radius="lg" padding={3} gap={3}>
  **1. Jaký charakter má mít výsledný povrch?**
  <radio-group direction="col" value={surface} onChange={setSurface}>
    <radio value="smooth">Maximálně hladký, organický terén</radio>
    <radio value="hybrid">Hladký terén, ale výrazné skalní hrany a zlomy</radio>
    <radio value="voxel">Viditelná voxelová struktura, ale změkčená texturami</radio>
  </radio-group>
  <divider color="subtle"/>
  **2. Kterým směrem začít s geometrií?**
  <radio-group direction="col" value={geometry} onChange={setGeometry}>
    <radio value="mc">Marching Cubes</radio>
    <radio value="dc">Dual Contouring</radio>
    <radio value="compare">Porovnat oba přístupy na stejném terénu</radio>
  </radio-group>
  <divider color="subtle"/>
  **3. Jak výrazný má být malovaný styl?**
  <radio-group direction="col" value={art} onChange={setArt}>
    <radio value="painted">Ruční malba, výrazné barevné plochy (Wakfu/Dofus)</radio>
    <radio value="toon">Stylizované 3D, výrazné světlo a toon shading</radio>
    <radio value="hybrid">Kombinace malovaných textur a stylizovaného 3D</radio>
  </radio-group>
  <button block onClick={()=>GenUI.issueNewTurn("Pro Willage volím následující směr vykreslování:\nPovrch: "+surface+"\nGeometrie: "+geometry+"\nVýtvarný styl: "+art+"\nNa základě toho navrhni konkrétní technickou architekturu a implementační postup v Godot 4.7.")}>Potvrdit směr</button>
</box>

**Moje hlavní doporučení:** Nejdříve bych vytvořil samostatný grafický testovací ostrov, který nebude závislý na finálním generátoru. Napojil bych ho na stejné datové rozhraní a ověřil, jak se chová hladká geometrie při kopání, změně materiálu a odkrývání podzemí. To ti pomůže rozhodnout o rendereru dříve, než se jeho implementace pevně propojí se zbytkem Willage.

---

### 4. Uživatel

Pro Willage volím následující směr vykreslování:
Povrch: voxel
Geometrie: compare
Výtvarný styl: hybrid
Na základě toho navrhni konkrétní technickou architekturu a implementační postup v Godot 4.7.

---

### 5. Asistent (shrnutí uvažování)

Přemýšlel po dobu 1m 26s

---

### 6. Asistent

# Willage – technická architektura Terrain Renderer V1.0
<badge color="success">Zvolený směr: Voxel + Hybrid Art + MC/DC benchmark</badge>

Tvoje volba mění jednu důležitou věc oproti předchozímu návrhu: **nebudeme se snažit voxelovou strukturu odstranit. Budeme ji používat jako základ výtvarného stylu.**

Cílem tedy není vytvořit dokonale hladký terén, ale terén, který:

- má rozpoznatelnou voxelovou strukturu,
- nemá působit jako Minecraft,
- má měkké a nepravidelné přechody,
- zachovává ostré geologické zlomy,
- působí jako ručně malované fantasy prostředí,
- umožňuje destrukci po 0,25 m.

To vede k trochu jiné architektuře než klasický Smooth Voxel Terrain.

## 1. Výtvarný a geometrický koncept

Doporučuji kombinaci tří vrstev geometrie:

<box gap={3}>
  <box gap={1}>
    <AsyncImage query="stylized hand painted voxel terrain fantasy game chunky rounded grass hills cliffs" aspectRatio="16:9" width="100%"/>
    **A. Základní voxelový terén**

    Viditelné, ale nepravidelné objemy. Mírně zaoblené hrany, větší barevné plochy, omezená geometrická detailnost.
  </box>
  <box gap={1}>
    <AsyncImage query="stylized fantasy game terrain low poly layered rock cliffs hand painted" aspectRatio="16:9" width="100%"/>
    **B. Geologická geometrie**

    Výraznější skalní hrany, vrstvy hornin, převisy a zlomy. Zde může být geometrie ostřejší.
  </box>
  <box gap={1}>
    <AsyncImage query="hand painted stylized fantasy game environment grass rocks flowers terrain details" aspectRatio="16:9" width="100%"/>
    **C. Výtvarná vrstva**

    Ručně malované textury, barevné přechody, drobné kameny, tráva a dekorace. Nemusí kopírovat voxelovou mřížku.
  </box>
</box>

Výsledkem bude voxelový svět s vlastním výtvarným charakterem, nikoliv klasická voxelová hra.

---

# 2. Geometrická architektura: tři samostatné režimy

Nedoporučuji implementovat Marching Cubes a Dual Contouring jako dvě varianty jednoho velkého mesheru.

Vytvořil bych společné rozhraní a dva nezávislé implementační moduly.

<box border radius="lg" padding={3} gap={2}>
  **Geometry Pipeline**
  <box background="surface-secondary" padding={3} radius="md" align=center>
    **Terrain Data Provider**

    <text color="secondary" size="xs">Density · Material · Overrides · Erosion</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="surface-secondary" padding={3} radius="md" align=center>
    **Sampling Layer**

    <text color="secondary" size="xs">Voxel samples · Gradients · Material weights</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box border radius="md" padding={2} align=center gap={1}>
        **Marching Cubes**
        <badge color="info">MC</badge>
        <text color="secondary" size="xs" textAlign="center">Smooth polygonization</text>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align=center gap={1}>
        **Dual Contouring**
        <badge color="discovery">DC</badge>
        <text color="secondary" size="xs" textAlign="center">Feature-preserving polygonization</text>
      </box>
    </grid-item>
  </grid>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="surface" border radius="md" padding={3} align=center>
    **Mesh Output**

    <text color="secondary" size="xs">Vertices · Normals · Indices · Material attributes</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="surface-secondary" radius="md" padding={3} align=center>
    **Terrain Renderer**

    <text color="secondary" size="xs">Godot ArrayMesh · Shader · Collision</text>
  </box>
</box>

## 2.1 Společné datové rozhraní

Každý mesher musí dostávat identická vstupní data.

Navrhuji:

```gdscript
class_name TerrainSample
extends RefCounted

var density: float
var material_id: int
var material_weights: PackedFloat32Array
var surface_flags: int
```

Vzorkovací rozhraní:

```gdscript
class_name ITerrainSampler
extends RefCounted

func sample_density(pos: Vector3) -> float:
    pass

func sample_material(pos: Vector3) -> int:
    pass

func sample_material_weights(
    pos: Vector3
) -> PackedFloat32Array:
    pass

func sample_gradient(pos: Vector3) -> Vector3:
    pass
```

Pro produkční verzi bych ale nedával jednotlivé `TerrainSample` objekty do každé buňky. To by v GDScriptu vytvářelo zbytečný počet objektů.

Používal bych `PackedFloat32Array`, `PackedByteArray` a další packed arrays. Sampling by mohl plnit předalokované buffery.

### Důležité: oddělení zdroje a vzorkování

`TerrainDataProvider` bude vědět, odkud se data získávají:

1. Procedurální funkce světa.
2. Transformace blueprintu.
3. Lokální override po kopání.
4. Eroze.
5. Simulace vody a geologické změny.

`TerrainSampler` z těchto zdrojů vytvoří konzistentní skalární pole pro mesher.

Renderer nesmí vědět, jak se materiál nebo výška vypočítaly.

## 2.2 Tři geometrické varianty pro srovnávací test

Přestože chceš porovnat MC a DC, přidal bych ještě třetí variantu jako referenční základ.

| Varianta | Úloha v testu | Charakter |
|---|---|---|
| Greedy Block Mesher | Referenční varianta | Zachování voxelových ploch |
| Marching Cubes | Kandidát A | Změkčené hrany |
| Dual Contouring | Kandidát B | Zachování hran a zlomů |

### Greedy Block Mesher

Spojuje sousední stejné plochy do větších polygonů. Nemění voxelový charakter, ale snižuje počet polygonů.

Je to důležitá kontrolní varianta: potřebuješ vědět, kolik výkonu stojí přechod k plynulejší geometrii.

### Marching Cubes

Pro Willage bych nastavil:

- Sampling interval: 0,25 m.
- Interpolace hran: lineární.
- Normály: gradient skalárního pole.
- Materiály: interpolované váhy.
- Výsledná geometrie: triangulovaná.
- Zachování ostrých hran: pomocí rozdělení smoothing skupin podle úhlu nebo materiálových hranic.

### Dual Contouring

Nastavil bych:

- Jeden výsledný vrchol na aktivní buňku.
- Hermite data z průsečíků a gradientů.
- QEF (Quadratic Error Function) pro umístění vrcholů.
- Omezení výsledných vrcholů na oblast buňky.
- Řízené zachování ostrých hran.

U DC je důležité správně řešit QEF. Nejde pouze o průměr průsečíků. Právě řešení QEF umožňuje zachovat rohy a hrany.

### Zásadní otázka: jak vytvořit Density?

Tady je potřeba udělat malé rozšíření datového modelu.

Tvoje buňka má nyní materiálové ID. To samo o sobě pro MC ani DC nestačí.

Potřebuješ skalární pole:

\[
D(x,y,z)
\]

Například:

- \(D<0\): pevná hmota.
- \(D>0\): vzduch.
- \(D=0\): povrch.

Doporučuji, aby Density nebyla další trvale ukládaná mapa celého ostrova.

Měla by být odvozena z:
- funkce terénu,
- geologických vrstev,
- SDF útvarů,
- lokálních výkopů,
- dalších změn.

Pro běžné voxelové oblasti můžeš vycházet z obsazenosti buněk, ale pro MC/DC je vhodnější vytvořit spojité skalární pole, případně aproximaci vzdálenosti od povrchu.

**Důležité:** Pokud do MC vložíš pouze binární hodnoty 0 a 1, nedostaneš automaticky kvalitní zaoblení. Proto bych měl parametr `surface_softness`, kterým budeš řídit šířku přechodu hustoty kolem povrchu.

Tím budeš moci testovat:

- tvrdý voxelový vzhled,
- mírně změkčený voxelový vzhled,
- organičtější povrch.

To je pro tvůj výtvarný záměr podstatnější než samotná volba meshing algoritmu.

---

# 3. Chunk architektura

Tady bych udělal jedno důležité rozhodnutí.

Tvoje logická struktura má segment 8 × 8 m, ale pro vykreslování bych zavedl ještě jednu vnitřní jednotku: **Render Chunk**.

Logický segment zůstane jednotkou organizace a ukládání změn. Render Chunk bude jednotkou generování a aktualizace geometrie.

## Doporučené rozměry

<box border radius="lg" padding={3} gap={3}>
  <grid columns={2} gap={3}>
    <grid-item>
      <title size="2xl" color="default" tabularNums>8 m</title>
      **Šířka segmentu**
      <caption>32 buněk</caption>
    </grid-item>
    <grid-item>
      <title size="2xl" color="default" tabularNums>8 m</title>
      **Výška render chunku**
      <caption>32 buněk</caption>
    </grid-item>
    <grid-item>
      <title size="2xl" color="default" tabularNums>32³</title>
      **Počet buněk**
      <caption>32 768 buněk</caption>
    </grid-item>
    <grid-item>
      <title size="2xl" color="default" tabularNums>33³</title>
      **Vzorkovací body**
      <caption>35 937 bodů</caption>
    </grid-item>
  </grid>
  <divider color="subtle"/>
  **Výsledná struktura**
  <text color="secondary" size="xs">Jeden horizontální segment 8 × 8 m je rozdělen do 16 vertikálních render chunků při maximální výšce 128 m.</text>
  <box background="surface-secondary" padding={2} radius="md" gap={1}>
    {#each Array.from({length:8},(_,i)=>i) as i}
      <box background={i===3 ? "#739B70" : i===4 ? "#8B806B" : "surface-tertiary"} theme={i===3 || i===4 ? "dark" : undefined} padding={1} radius="xs" align=center>
        <text size="xs" color={i===3 || i===4 ? "#FFFFFF" : "default"}>Render Chunk {i+1}</text>
      </box>
    {/each}
    <caption textAlign="center">Schematický výřez vertikálního sloupce chunků</caption>
  </box>
</box>

Proč 8 m?

- Zachováš existující logiku segmentů.
- Výpočetní objem jednoho render chunku je omezený.
- Jednoduše se aktualizují oblasti zasažené kopáním.
- Výšku můžeš rozdělit bez změny ukládání dat.

Pokud bude mít segment jinou velikost, render chunk může zůstat samostatně konfigurovatelný.

### Halo / Border Samples

Každý chunk musí mít přístup k okolním vzorkům.

U MC minimálně jednu sousední vrstvu vzorků za hranicí chunku. U DC musíš obdobně zajistit dostupnost sousedních buněk a jejich Hermite dat.

Při výpočtu normál nesmíš používat pouze lokální data chunku.

Jinak vzniknou:
- viditelné švy,
- rozdílné normály,
- nespojitá geometrie.

Vzorkovací souřadnice musí být globální celočíselné indexy mřížky. Nikdy nepočítej každý chunk jako nezávislou lokální mřížku.

Například:

\[
i_x = \operatorname{round}(4x)
\]

\[
i_y = \operatorname{round}(4y)
\]

\[
i_z = \operatorname{round}(4z)
\]

To je zásadní i pro determinismus.

---

# 4. Materiálový systém – 78 materiálů, nikoliv 78 shaderů

Tady bych udělal oddělení mezi identitou materiálu a jeho vizuální reprezentací.

Tvoje tabulka 78 materiálů zůstane zdrojem pravdy.

Renderer si ale vytvoří vlastní materiálový profil.

Například:

```text
MaterialDefinition
 ├── id
 ├── visual_group
 ├── texture_layer
 ├── base_color
 ├── roughness
 ├── normal_strength
 ├── blend_width
 ├── surface_style
 └── shader_flags
```

`visual_group` může být například:

- Grass
- Soil
- Clay
- Sand
- Rock
- Crystal
- Ice
- Special

Tím se vyhneš tomu, že každá geologická varianta bude vyžadovat nový shader nebo samostatný draw call.

## Doporučený shader

<AsyncImageGroup query={["hand painted stylized grass soil rock texture seamless game material","hand painted stylized stone cliff texture game asset","stylized hand painted earth dirt texture fantasy game"]} aspectRatio="5:4"/>

Použil bych:

1. Texture Array pro základní materiály.
2. Vertex Color pro barevné tónování a blend masky.
3. UV mapping pro horní plochy.
4. Triplanar mapping pro vybrané skalní stěny.
5. Jemný world-space noise pro odstranění opakování.
6. Jednoduché stylizované osvětlení.

### Jak zachovat voxelový charakter?

Nastavil bych tři nezávislé parametry:

| Parametr | Funkce |
|---|---|
| `surface_softness` | Zaoblení geometrie |
| `edge_strength` | Výraznost voxelových hran |
| `material_blend_width` | Šířka přechodů materiálů |

Tím můžeš mít například:
- téměř ostrou geometrii,
- mírně zaoblené rohy,
- výrazně malované materiály.

Nebo:
- výraznější zaoblení,
- ostřejší skalní zlomy,
- velmi jemné materiálové přechody.

Tohle je podle mě lepší než natvrdo svázat vzhled s algoritmem meshingu.

---

# 5. Konkrétní struktura projektu Godot

Navrhoval bych následující strukturu:

```text
Presentation/
│
├── Terrain/
│   ├── Core/
│   │   ├── terrain_renderer.gd
│   │   ├── terrain_chunk.gd
│   │   ├── terrain_chunk_key.gd
│   │   ├── terrain_build_request.gd
│   │   └── terrain_mesh_data.gd
│   │
│   ├── Data/
│   │   ├── terrain_data_provider.gd
│   │   ├── terrain_sampler.gd
│   │   ├── density_field.gd
│   │   └── material_field.gd
│   │
│   ├── Meshing/
│   │   ├── terrain_mesher.gd
│   │   ├── greedy_mesher.gd
│   │   ├── marching_cubes_mesher.gd
│   │   ├── dual_contouring_mesher.gd
│   │   ├── qef_solver.gd
│   │   └── normal_generator.gd
│   │
│   ├── Materials/
│   │   ├── terrain_material_library.gd
│   │   ├── terrain_material_profile.gd
│   │   └── shaders/
│   │       ├── terrain.gdshader
│   │       └── water.gdshader
│   │
│   ├── Collision/
│   │   └── terrain_collision_builder.gd
│   │
│   └── Debug/
│       ├── terrain_debug_view.gd
│       ├── meshing_benchmark.gd
│       └── terrain_test_scenes/
│
├── Water/
├── Vegetation/
├── IslandEdge/
└── Visibility/
```

### Zodpovědnosti jednotlivých tříd

| Třída | Odpovědnost |
|---|---|
| TerrainRenderer | Správa viditelných chunků |
| TerrainChunk | Stav a aktuální mesh chunku |
| TerrainDataProvider | Čtení světových dat |
| TerrainSampler | Vzorkování hustoty a materiálů |
| TerrainMesher | Společný kontrakt pro meshery |
| MarchingCubesMesher | Generování MC geometrie |
| DualContouringMesher | Generování DC geometrie |
| TerrainMeshData | Přenosová data pro vytvoření meshe |
| TerrainCollisionBuilder | Zjednodušená kolizní geometrie |
| MeshingBenchmark | Měření a porovnávání |

Doporučuji také vytvořit `TerrainRendererConfig` jako Resource, ve kterém budou konfigurovatelné parametry.

Například:

```gdscript
class_name TerrainRendererConfig
extends Resource

@export var chunk_size := 8.0
@export var voxel_size := 0.25

@export_enum(
    "Greedy",
    "MarchingCubes",
    "DualContouring"
)
var mesher_type := 1

@export var surface_softness := 0.25
@export var edge_strength := 0.5
@export var material_blend_width := 0.5

@export var generate_collision := true
@export var generate_vertex_colors := true
```

Hodnoty `surface_softness`, `edge_strength` a `material_blend_width` jsou zatím návrhové parametry, nikoliv hotové fyzikální jednotky. Jejich rozsahy bude potřeba kalibrovat.

---

# 6. Asynchronní generování geometrie

Tohle bude jedna z nejdůležitějších částí implementace.

Doporučuji rozdělit proces do čtyř fází.

<box border radius="lg" padding={3} gap={2}>
  <list connector="solid" marker="number" gap={2}>
    <list-item>
      **Request**

      `TerrainRenderer` zjistí, že chunk potřebuje vygenerovat nebo aktualizovat mesh.
    </list-item>
    <list-item>
      **Sampling + Meshing**

      Worker získá neměnný snapshot dat a vytvoří packed arrays geometrie.
    </list-item>
    <list-item>
      **Mesh Commit**

      Hlavní vlákno převezme hotová data a vytvoří `ArrayMesh`.
    </list-item>
    <list-item>
      **Apply**

      Vymění mesh na existujícím `MeshInstance3D` a případně naplánuje aktualizaci kolize.
    </list-item>
  </list>
</box>

## Důležitá pravidla pro vlákna

V Godotu 4.7 máš k dispozici `WorkerThreadPool`, který se pro tuto práci hodí. <Cite refs={["turn361804search5","turn361804search6"]}/>

Rozdělení:

| Operace | Vlákno |
|---|---|
| Načtení snapshotu dat | Podle zdroje |
| Density sampling | Worker |
| Materiálový sampling | Worker |
| Marching Cubes | Worker |
| Dual Contouring | Worker |
| Výpočet normál | Worker |
| Sestavení packed arrays | Worker |
| Vytvoření / změna mesh resource | Hlavní vlákno |
| Přidání Node do SceneTree | Hlavní vlákno |
| Výměna kolizní geometrie | Hlavní vlákno |

Godot výslovně upozorňuje na omezení práce se SceneTree a renderovacími prostředky z pracovních vláken. Proto bych na začátku nechal workers produkovat pouze obyčejná data a samotné vytvoření a aplikaci meshe prováděl na hlavním vlákně. <Cite refs={["turn361804search0","turn361804search7"]}/>

## Ukázka orchestrátoru

Zjednodušený koncepční příklad:

```gdscript
extends Node

var pending_jobs: Dictionary = {}
var completed_results: Array = []

func request_chunk_build(
    chunk_key: Vector3i,
    snapshot: RefCounted
) -> void:

    if pending_jobs.has(chunk_key):
        return

    var job = TerrainBuildJob.new()
    job.chunk_key = chunk_key
    job.snapshot = snapshot

    var task_id = WorkerThreadPool.add_task(
        _build_chunk.bind(job),
        false,
        "Terrain chunk build"
    )

    pending_jobs[chunk_key] = {
        "task_id": task_id,
        "job": job
    }


func _build_chunk(job: TerrainBuildJob) -> void:
    var result = TerrainMesherFactory.build(
        job.snapshot
    )

    job.result = result
    job.finished = true
```

Toto je záměrně pouze kostra. Produkční verze musí bezpečně synchronizovat dokončené výsledky, spravovat životní cyklus úloh a jejich identifikátory.

### Dvě věci, které bych určitě doplnil

**Generation Version**

Každý chunk má číslo verze:

```text
chunk_revision = 15
```

Pokud hráč mezitím provede další výkop, revision se zvýší.

Když se dokončí starý worker, jeho výsledek se zahodí, pokud už neodpovídá aktuální revision.

**Immutable Snapshot**

Worker nesmí číst data, která se právě mění.

Při zadání práce dostane konzistentní snapshot:

```text
TerrainBuildRequest
 ├── chunk_key
 ├── revision
 ├── generator_version
 ├── density_samples
 ├── material_samples
 ├── neighbor_samples
 └── mesher_config
```

Tím odstraníš velkou část problémů s konkurencí mezi kopáním a generováním geometrie.

---

# 7. Editace terénu a Dirty Chunk systém

Při kopání nechceš přepočítávat celý segment, natož ostrov.

Zavedl bych `DirtyRegionTracker`.

Například hráč vykopne prostor o velikosti 1 × 1 × 1 m.

<AsyncImage query="voxel terrain mining digging hole smooth stylized 3d terrain game" aspectRatio="16:9" width="100%"/>

Systém:

1. Zjistí dotčené buňky.
2. Převede je na prostorovou oblast.
3. Rozšíří oblast o vzorkovací halo.
4. Najde všechny dotčené render chunky.
5. Označí je jako Dirty.
6. Sloučí opakované požadavky.
7. Naplánuje nové meshing úlohy.

Stavy chunku:

```text
UNLOADED
   ↓
REQUESTED
   ↓
SAMPLING
   ↓
MESHING
   ↓
READY
   ↓
ACTIVE
   ↓
DIRTY
   └────→ REQUESTED
```

Přidal bych ještě `FAILED` pro chybové stavy.

### Aktualizace při rychlém kopání

Představ si, že hráč drží tlačítko a vykopává několik buněk za sebou.

Nechceš vytvořit deset meshů pro stejnou oblast.

Proto bych použil slučování změn:

- změny se zaznamenávají okamžitě,
- požadavky na mesh se slučují,
- generuje se poslední platná revision,
- staré výsledky se zahazují.

Tím oddělíš okamžitou změnu herních dat od nákladné grafické aktualizace.

## Kolize

Kolize bych negeneroval stejným tempem jako vizuální geometrii.

Doporučuji:

- vizuální mesh: aktualizovat co nejdříve,
- collision mesh: aktualizovat samostatnou úlohou,
- dekorativní detaily: bez kolize,
- drobné výkopy: případně aktualizovat kolizi až po krátké dávce změn.

U statického terénu můžeš začít s `ConcavePolygonShape3D`, ale jeho složitost musíš měřit. Pro mobilní zařízení bych kolizní mesh výrazně zjednodušil a nesnažil se kopírovat každý vizuální detail.

---

# 8. Srovnávací benchmark: MC versus DC

Tohle bych nepovažoval za vedlejší test. Udělal bych z toho samostatný nástroj projektu.

`MeshingBenchmark`

Každý algoritmus dostane úplně stejná vstupní data.

## Testovací scény

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="stylized low poly voxel rolling hill terrain game asset" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **Test A – Organický kopec**

      Hodnocení hladkosti, normál a pravidelnosti povrchu.
    </box>
  </row>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy sharp layered rock cliff game terrain" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **Test B – Skalní stěna**

      Zachování ostrých hran, vrstev a převisů.
    </box>
  </row>
  <row align=start gap={3}>
    <AsyncImage query="fantasy voxel cave underground tunnel terrain cross section game" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **Test C – Jeskyně**

      Vnitřní povrchy, stropy a uzavřené dutiny.
    </box>
  </row>
  <row align=start gap={3}>
    <AsyncImage query="voxel terrain mining hole cutout destructible environment game" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **Test D – Destrukce**

      Čas přepočtu po odstranění materiálu a kontinuita sousedních chunků.
    </box>
  </row>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy geological terrain layered rock grass cross section" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **Test E – Geologické přechody**

      Přesnost materiálových hranic a jejich výtvarné zpracování.
    </box>
  </row>
</box>

## Měřené parametry

| Kategorie | Metrika |
|---|---|
| Výkon CPU | Sampling time |
| Výkon CPU | Meshing time |
| Výkon CPU | Normals time |
| Geometrie | Vertex count |
| Geometrie | Triangle count |
| Paměť | Peak memory |
| Editace | Rebuild time |
| Kvalita | Geometrická odchylka |
| Kvalita | Zachování hran |
| Kvalita | Švy mezi chunky |
| Rendering | GPU frame time |

Nezapomeň měřit i počet draw calls, protože více materiálových povrchů může být problém stejně jako vysoký počet polygonů.

### Výsledky musí být porovnatelné

Benchmark by měl mít:

- stejný seed,
- stejnou hustotu,
- stejné materiály,
- stejnou velikost chunku,
- stejné nastavení hardwaru,
- stejný počet opakování.

Pro každý test bych měřil medián a 95. percentil, nikoliv pouze nejlepší čas.

### Cílová zařízení

Testoval bych minimálně:

1. Vývojový počítač.
2. Běžný Android telefon.
3. Slabší Android telefon.

Pro telefon bych zavedl dva samostatné rozpočty:

- CPU budget na vytvoření geometrie.
- GPU budget na její vykreslení.

Cíl 30 FPS znamená celkový frame budget přibližně 33,3 ms. Meshing ale nesmí blokovat hlavní vlákno, takže jeho čas nelze jednoduše porovnávat s celým frame budgetem.

---

# 9. Voda, okraj a dekorace jako nezávislé renderery

Tady bych zachoval původní koncepci, ale napojil ji na nový Terrain Renderer.

| Renderer | Vstup | Výstup |
|---|---|---|
| TerrainRenderer | Density + materiály | Hlavní terén |
| IslandEdgeRenderer | Okrajová geometrie | Boční stěny ostrova |
| WaterRenderer | Hladina + proudění | Vodní mesh |
| WaterfallRenderer | Emisní body | Vodopády |
| VegetationRenderer | Seed + terénní data | Vegetace |
| VisibilityRenderer | Kamera + postava | Occlusion parametry |
| AtmosphereRenderer | Poloha ostrova | Oblaka a mlha |

### Zásadní pravidlo

Žádný z těchto rendererů nesmí upravovat zdrojová data.

Renderer dostává data jako read-only vstup a vytváří vlastní grafické prostředky.

To ti umožní později například:
- vypnout vegetaci bez zásahu do světa,
- vyměnit MC za DC,
- změnit styl vody,
- přepnout na jiný shader,
- testovat 2D prezentaci.

# 10. Konkrétní vykreslování v Godotu 4.7

Pro vytvoření výsledné geometrie bych používal především `ArrayMesh`.

Proč ne `SurfaceTool`?

`SurfaceTool` je pohodlný při prototypování, ale u vlastního mesheru budeš pracovat s velkým množstvím vrcholů, indexů, normál a barev. Přímé plnění packed arrays je vhodnější pro dávkové generování geometrie.

Godot 4.7 podporuje vytvoření mesh povrchu přímo z polí prostřednictvím `ArrayMesh.add_surface_from_arrays()`. <Cite refs={["turn595281search8","turn595281search11","turn595281search10"]}/>

Příklad výsledné fáze:

```gdscript
func create_mesh(data: TerrainMeshData) -> ArrayMesh:
    var mesh := ArrayMesh.new()

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)

    arrays[Mesh.ARRAY_VERTEX] = data.vertices
    arrays[Mesh.ARRAY_NORMAL] = data.normals
    arrays[Mesh.ARRAY_COLOR] = data.colors
    arrays[Mesh.ARRAY_TEX_UV] = data.uvs
    arrays[Mesh.ARRAY_INDEX] = data.indices

    mesh.add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES,
        arrays
    )

    return mesh
```

`TerrainMeshData` bude obsahovat pouze data potřebná pro vytvoření geometrie:

```text
TerrainMeshData
 ├── vertices
 ├── normals
 ├── colors
 ├── uvs
 ├── indices
 ├── bounds
 └── material_groups
```

Materiálové skupiny bych řešil jako samostatné surfaces pouze tehdy, pokud to bude potřeba. Nedělal bych 78 surfaces podle všech materiálových ID.

Pro dekorace bych využil `MultiMeshInstance3D`. Godot ho přímo doporučuje pro efektivní vykreslování velkého množství instancí stejné geometrie. <Cite refs={["turn595281search5","turn595281search9"]}/>

---

# 11. Determinismus a přesnost

U Willage bych stanovil ještě jedno pravidlo:

**Renderer nesmí být součástí deterministického stavu světa.**

Generátor a simulace zůstávají autoritativní. Renderer pouze převádí jejich výstup na geometrii.

Doporučené rozdělení:

| Vrstva | Požadavek |
|---|---|
| World Generator | Deterministický |
| Terrain Overrides | Deterministické |
| Density Sampling | Deterministické |
| Material Sampling | Deterministické |
| Meshing | Stabilní pořadí a pravidla |
| Shader | Nemá vliv na světová data |
| Animace vody | Pouze vizuální |
| Vegetační dekorace | Deterministické umístění |

Ještě jedna technická poznámka: pro bitově deterministická světová data bych nepoužíval přímo výsledky GPU výpočtů. Výpočty na GPU a plovoucí desetinná čárka nemusí být mezi různými platformami bitově identické.

V rendereru můžeš používat float32 geometrická data, ale světové výpočty a identifikace vzorků by měly mít vlastní deterministická pravidla.

---

# 12. Implementační plán

Rozdělil bych implementaci na šest milníků. Každý musí mít ověřitelný výsledek.

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    <row align=center justify=between>
      **Milestone 1 – Terrain Sampling**
      <badge color="info">Základ</badge>
    </row>
    - Vytvoření Density Field.
    - Materiálový sampling.
    - Globální souřadnicový systém.
    - Snapshot dat.
    - Test determinismu.
    <text color="secondary" size="xs">Výstup: konzistentní vzorkovací data pro libovolný chunk.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Milestone 2 – Mesher Benchmark**
    - Greedy Block Mesher.
    - Marching Cubes.
    - Dual Contouring.
    - QEF Solver.
    - Srovnávací testovací scény.
    <text color="secondary" size="xs">Výstup: tři funkční geometrické varianty.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Milestone 3 – Chunk Renderer**
    - 8 × 8 × 8 m render chunky.
    - Halo sampling.
    - ArrayMesh.
    - Chunk cache.
    - Švy a hranice.
    <text color="secondary" size="xs">Výstup: souvislý vykreslený terén.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Milestone 4 – Editing Pipeline**
    - DirtyRegionTracker.
    - Revision management.
    - Asynchronní generování.
    - Aktualizace kolizí.
    <text color="secondary" size="xs">Výstup: funkční kopání a aktualizace geometrie.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Milestone 5 – Hybrid Art**
    - Texture Arrays.
    - Vertex blending.
    - Triplanar mapping.
    - Stylizované osvětlení.
    - Voxelové hrany a materiálové přechody.
    <text color="secondary" size="xs">Výstup: první vizuálně reprezentativní terén.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Milestone 6 – Island Presentation**
    - IslandEdgeRenderer.
    - WaterRenderer.
    - WaterfallRenderer.
    - VisibilityRenderer.
    - VegetationRenderer.
    <text color="secondary" size="xs">Výstup: kompletní prezentace ostrova.</text>
  </box>
</box>

## 13. Co považuji za nejdůležitější architektonická rozhodnutí

Shrnul bych je takto:

| Rozhodnutí | Doporučení |
|---|---|
| Zdrojová data | Zůstanou nezávislá na renderingu |
| Voxel | 0,25 m zůstává výpočetní jednotkou |
| Geometrie | Greedy / MC / DC jako zaměnitelné moduly |
| Chunk | 8 × 8 × 8 m renderovací jednotka |
| Materiály | Jedna knihovna, více vizuálních profilů |
| Rendering | ArrayMesh |
| Výpočty | WorkerThreadPool |
| Synchronizace | Immutable snapshots + revision |
| Kolize | Samostatná zjednodušená geometrie |
| Voda | Samostatný renderer |
| Výtvarný styl | Hybridní geometrie a malované materiály |

**Důležitý detail:** Godot 4.7 je již stabilní vydání; návrh proto počítá s jeho současnými API, nikoliv s experimentálními funkcemi budoucích verzí. <Cite refs={["turn595281search4","turn595281search6"]}/>

---

# 14. Moje doporučení pro první skutečný prototyp

Nezačínal bych implementací celého systému.

Vytvořil bych jednu samostatnou testovací scénu:

<AsyncImage query="stylized voxel fantasy floating island terrain grass dirt layered rock isometric game environment hand painted" aspectRatio="16:9" width="100%"/>

`TerrainLab.tscn`

V ní budou:

- jeden render chunk 8 × 8 × 8 m,
- několik procedurálně vytvořených terénních tvarů,
- tři přepínatelné meshery,
- čtyři materiály,
- možnost měnit `surface_softness`,
- možnost vykopat libovolnou buňku,
- zobrazení času generování,
- počty polygonů a vrcholů,
- vizualizace hran chunku.

A hlavně: **všechny tři meshery musí dostávat totožná data.**

Tím dostaneš skutečně objektivní srovnání, ne tři různé implementace, které náhodou vykreslují podobný kopec.

## Ještě jedna věc, kterou bych chtěl ověřit

U tvého konceptu vidím potenciální problém mezi požadavkem na voxelový vzhled a používáním Marching Cubes.

Marching Cubes může odstranit právě ty geometrické charakteristiky, které chceš zachovat. Proto bych do TerrainLab přidal i možnost řídit zaoblení nezávisle na velikosti voxelů.

Výsledkem nemusí být jeden univerzální algoritmus. Klidně můžeš v produkčním rendereru používat:

- Greedy meshing pro některé typy podzemních konstrukcí.
- Marching Cubes pro organický povrch.
- Dual Contouring pro výrazné skalní zlomy.

To není architektonická chyba. Pokud všechny tři používají stejný zdroj dat a respektují stejná pravidla hranic, jde o legitimní hybridní rendering.

**Další logický krok:** připravil bych detailní technickou specifikaci `TerrainLab` včetně datových struktur, rozhraní mesherů, benchmarků a testovacích scén. To bude dostatečně uzavřený celek, aby jej mohl implementovat vývojový agent v Godotu, aniž by musel předčasně zasahovat do generátoru Willage.

---

### 7. Uživatel

Mám pár referenčních obrázků designu které se mi líbí, 

---

### 8. Asistent (shrnutí uvažování)

Přemýšlel po dobu 12s

---

### 9. Asistent

Tohle je pro Willage velmi užitečný výběr. Z obrázků už jde poměrně dobře vyčíst, jaký vizuální směr hledáš. A hlavně: potvrzují mi, že bych se u Willage nesnažil o klasickou voxelovou grafiku.

Vidím v nich několik společných principů, ale také několik odlišných výtvarných přístupů, které bychom měli vědomě zkombinovat.

# 1. Co si z referencí beru

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="Wakfu Dofus floating island isometric hand painted game environment grass stone" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **1. Plovoucí ostrov – hlavní vizuální identita**

      - Izometrická perspektiva.
      - Výrazná silueta ostrova.
      - Sytá tráva přesahující okraje.
      - Ručně stylizované skalní vrstvy.
      - Jednotlivé kameny a kořeny jako dekorace.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy isometric game environment hand painted colorful grass stone river castle" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **2. Povrch – barevnost a prostředí**

      - Výrazné barevné plochy.
      - Malované textury.
      - Organické přechody mezi trávou, půdou a kamenem.
      - Voda jako výrazný vizuální prvek.
      - Prostředí působí živě, nikoliv geometricky sterilně.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy floating island cutaway underground cavern diorama glowing lava" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **3. Podzemí – geologická dramatičnost**

      - Výrazné skalní převisy.
      - Rozdílné geologické vrstvy.
      - Dutiny a jeskyně.
      - Světelné kontrasty.
      - Podzemí jako plnohodnotná část světa.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy isometric underground crystal cavern diorama game environment" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **4. Geologie – členitost**

      - Ostré skalní zlomy.
      - Krystaly a minerály.
      - Výškové rozdíly.
      - Terénní schodiště a průchody.
      - Dobře čitelná prostorová struktura.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="pixel art isometric fantasy underground tavern interior game environment" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **5. Interiéry – jiná úroveň stylizace**

      - Výraznější kontury.
      - Menší barevné detaily.
      - Pixel-art estetika.
      - Silná atmosféra osvětlení.

      Tohle bych zatím považoval za možný samostatný výtvarný směr interiérů.
    </box>
  </row>
</box>

# 2. Jak bych definoval výsledný výtvarný styl Willage

<badge color="success">Doporučený směr</badge>

**Stylized hand-painted 3D with voxel-based terrain geometry.**

Jinými slovy:

- Geometrie je skutečně 3D.
- Terén má prostorovou strukturu odvozenou z voxelů.
- Povrchy jsou ručně stylizované, nikoliv realistické.
- Ostré hrany a převisy se kombinují s měkkými organickými přechody.
- Vegetace, kameny a objekty mají vlastní stylizovanou geometrii.
- Kamera používá izometrickou projekci.

<AsyncImageGroup query={["Wakfu Dofus stylized floating island hand painted 3D terrain","stylized hand painted fantasy 3D terrain grass cliff layered rock","stylized fantasy underground cave glowing crystals hand painted 3D game"]} aspectRatio="5:4" layout="bento"/>

# 3. Co to znamená pro technickou architekturu

Tady je důležitá věc: tvoje rozhodnutí voxelového povrchu bych neměnil. Naopak bych upravil způsob, jakým k němu přistupujeme.

Rozdělil bych vizuální reprezentaci na tři nezávislé vrstvy:

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    <title size="lg" color="#65B978">01 – Terrain Geometry</title>
    **Procedurální geometrie**

    - Marching Cubes / Dual Contouring.
    - Geologické vrstvy.
    - Převisy a jeskyně.
    - Dynamická destrukce.
    - Skutečná geometrie terénu.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <title size="lg" color="#D5A65C">02 – Surface Appearance</title>
    **Výtvarné zpracování**

    - Hand-painted texture atlas.
    - Texture Arrays.
    - Vertex Color blending.
    - Triplanar mapping.
    - Stylizované normal maps.
    - Barevné variace materiálů.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <title size="lg" color="#64B8D0">03 – Environmental Assets</title>
    **Samostatné objekty**

    - Tráva a vegetace.
    - Balvany a krystaly.
    - Kořeny.
    - Vodopády.
    - Dekorativní skalní převisy.
    - Stavby a předměty.
  </box>
</box>

Tohle oddělení je důležité zejména proto, že při kopání nechceš regenerovat trávu, kořeny a všechny dekorace jen proto, že se změnila geometrie pod nimi.

# 4. Jedna věc, kterou bych chtěl rozhodnout před implementací

Na referencích vidím dva odlišné přístupy k samotné geometrii.

<grid columns={2} gap={3}>
  <grid-item>
    <AsyncImage query="Wakfu Dofus game floating island stylized chunky organic rounded terrain grass cliffs" aspectRatio="5:4" width="100%"/>
    **A – Organický terén**

    Měkčí, nepravidelné skalní tvary, zaoblenější přechody.
  </grid-item>
  <grid-item>
    <AsyncImage query="stylized low poly fantasy voxel island sharp faceted cliffs geological rock layers" aspectRatio="5:4" width="100%"/>
    **B – Facetovaný terén**

    Výrazné polygonové plochy, ostré zlomy, čitelné skalní bloky.
  </grid-item>
</grid>

U Willage bych osobně volil kombinaci:

- Povrch ostrova: převážně A.
- Skalní stěny: převážně B.
- Podzemní jeskyně: B s lokálními organickými prvky.
- Tráva a vegetace: samostatná geometrie.

**Moje otázka:** Chceš, aby se terén při kopání vizuálně choval spíše jako měkká hmota (plynulé deformace a zaoblené stěny), nebo jako hornina (zlomy, facetované plochy a ostré skalní hrany)?

Tohle rozhodnutí bude mít přímý dopad na výběr a konfiguraci Marching Cubes versus Dual Contouring, práci s normálami i výsledný shader.

---

### 10. Uživatel

No to asi podle druhu horniny. 

---

### 11. Asistent (shrnutí uvažování)

Přemýšlel po dobu 4s

---

### 12. Asistent

Přesně. A myslím, že tohle je pro Willage správnější přístup než vybrat jeden geometrický styl pro celý terén.

**Geometrie by měla být vlastností materiálu, nikoliv globálním nastavením rendereru.**

To navíc velmi dobře zapadá do tvého současného systému geologických vrstev a materiálové tabulky.

## 1. Materiál bude definovat způsob vykreslení

Navrhuji rozšířit materiálové definice o samostatný `VisualProfile`.

Například:

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted fantasy soft soil clay terrain cutaway game asset" aspectRatio="1:1" maxWidth="108px"/>
    <box flex="1" gap={1}>
      **Půda, jíl, sedimenty**

      <badge color="success">Organický povrch</badge>
      - Měkké přechody.
      - Zaoblené hrany.
      - Menší geometrická členitost.
      - Hladké normály.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted sandstone rock cliff layered geological strata game asset" aspectRatio="1:1" maxWidth="108px"/>
    <box flex="1" gap={1}>
      **Pískovec, vápenec**

      <badge color="info">Vrstvený povrch</badge>
      - Viditelné geologické vrstvy.
      - Lokální zlomy.
      - Středně ostré hrany.
      - Eroze a zaoblení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted angular granite rock cliff low poly game asset" aspectRatio="1:1" maxWidth="108px"/>
    <box flex="1" gap={1}>
      **Žula, rula**

      <badge color="warning">Facetovaný povrch</badge>
      - Ostré hrany.
      - Výrazné polygonové plochy.
      - Lomové struktury.
      - Menší zaoblení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized dark basalt volcanic rock cliff fractured angular game asset" aspectRatio="1:1" maxWidth="108px"/>
    <box flex="1" gap={1}>
      **Čedič, vulkanické horniny**

      <badge color="discovery">Frakturovaný povrch</badge>
      - Výrazné zlomy.
      - Sloupcové struktury.
      - Ostré lomové plochy.
      - Specifická struktura povrchu.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy ice glacier cliff translucent blue ice game asset" aspectRatio="1:1" maxWidth="108px"/>
    <box flex="1" gap={1}>
      **Led**

      <badge color="info">Speciální profil</badge>
      - Hladké plochy.
      - Lokální ostré zlomy.
      - Průhlednost a lom světla.
      - Krystalické struktury.
    </box>
  </row>
</box>

## 2. Návrh datové struktury

Nechtěl bych mít výtvarné parametry přímo v hlavní tabulce fyzikálních vlastností materiálů.

Oddělil bych fyziku od vizuální reprezentace.

```text
MaterialDefinition
 ├── PhysicalProperties
 │    ├── hardness
 │    ├── permeability
 │    ├── porosity
 │    ├── erosion_resistance
 │    └── density
 │
 └── VisualProfile
      ├── geometry
      │    ├── smoothness
      │    ├── feature_preservation
      │    ├── fracture_style
      │    └── detail_scale
      │
      ├── surface
      │    ├── texture_array_id
      │    ├── color_variation
      │    ├── roughness
      │    └── normal_strength
      │
      └── transitions
           ├── blend_distance
           ├── edge_style
           └── boundary_noise
```

Například:

| Parametr | Rozsah | Význam |
|---|---:|---|
| smoothness | 0–1 | Zaoblení geometrie |
| feature_preservation | 0–1 | Zachování ostrých hran |
| fracture_style | enum | Typ lomové struktury |
| detail_scale | 0–1 | Měřítko geometrických detailů |
| roughness | 0–1 | Drsnost povrchu |
| blend_distance | metry | Přechod mezi materiály |

Důležité: `roughness` v shaderu a geometrická drsnost nejsou totéž.

## 3. Jak to propojit s Marching Cubes a Dual Contouring

Tady bych udělal jedno důležité architektonické rozhodnutí.

Nechtěl bych, aby renderer vybíral jiný mesher pro každou buňku. To by přineslo komplikace na hranicích materiálů a chunků.

Místo toho:

<box border radius="lg" padding={3} gap={2}>
  **Material-aware Meshing Pipeline**
  <box background="rgba(59,130,246,0.10)" radius="md" padding={2} align=center>
    Density Field + Material Field
  </box>
  <box align=center>
    <icon name="arrow-down"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={2} align=center>
    Material Visual Profile Sampling
  </box>
  <box align=center>
    <icon name="arrow-down"/>
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box border radius="md" padding={2} align=center>
        **Smooth regions**

        Marching Cubes
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align=center>
        **Sharp features**

        Dual Contouring
      </box>
    </grid-item>
  </grid>
  <box align=center>
    <icon name="arrow-down"/>
  </box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={2} align=center>
    Unified Terrain Mesh
  </box>
</box>

V první verzi bych ovšem implementoval pouze jeden hlavní mesher a parametrickou kontrolu zachování hran. Výběr algoritmu podle regionu bych nechal až na benchmark.

Ještě jedna nuance: MC a DC nejsou přímo ekvivalentní přepínače hladkosti. DC umí lépe zachovat ostré geometrické rysy, zatímco MC přirozeně vytváří interpolovaný izopovrch. Výsledek bude záviset také na Density Field a gradientu.

## 4. Přechody mezi horninami

Tohle bude pro Willage velmi důležité.

Představ si, že kopeš skrz vrstvu pískovce a dostaneš se na žulové podloží.

Nechceš, aby se geometrie náhle změnila v dokonale hladkou hranici.

Potřebuješ kombinovat:

- skutečnou geologickou hranici,
- lokální nepravidelnost hranice,
- rozdílné geometrické vlastnosti materiálů,
- rozdílné povrchové textury.

<AsyncImageGroup query={["stylized hand painted fantasy geological cross section sandstone granite rock strata","stylized fantasy cave geological rock layers exposed stone strata hand painted"]} aspectRatio="5:4"/>

Materiálové přechody bych řešil interpolací vizuálních vlastností podle váhy materiálů, ale samotnou geologickou hranici bych zachoval jako samostatnou informaci. Jinak bys mohl rozmazat skutečné geologické rozhraní.

---

## 5. Moje doporučení pro Willage

Zavedl bych tři nezávislé vlastnosti:

1. **Physical Material** – jak se materiál chová ve světě.
2. **Geometric Profile** – jaký tvar a charakter má jeho geometrie.
3. **Surface Profile** – jak vypadá jeho povrch.

Tím získáš možnost například vykreslit tvrdý vápenec s výraznou erozí, měkký pískovec s ostrými lomovými hranami nebo led, který je geometricky hladký, ale obsahuje ostré krystalické struktury.

**A ještě bych otevřel jednu důležitou otázku:** Chceš, aby geometrický charakter horniny ovlivňoval také samotné kopání?

Například žula by při odkrytí vytvářela ostré lomové plochy, zatímco jíl by vytvářel zaoblenější stěny výkopu.

To by bylo zajímavé propojení geologie, destrukce a renderingu – a Willage by díky tomu působil podstatně živěji.

---

### 13. Uživatel

Sestav mi prompt pro vygenerování ilustračního obrázku který bude obsahovat všechny naše kriteria

---

### 14. Asistent (shrnutí uvažování)

Přemýšlel sekundu

---

### 15. Asistent

Připravil jsem prompt jako **konceptuální ilustraci světa Willage**, nikoliv pouze obrázek hezkého ostrova. Cílem je ukázat současně povrch, geologii, podzemí, vodu, vegetaci i charakter jednotlivých hornin.

Prompt je v angličtině, protože generátory obrázků obvykle lépe interpretují technické a výtvarné instrukce v tomto jazyce.

## Willage – Visual Direction Concept Art

<WritingBlock id="63821" variant="standard"># WILLAGE – Stylized Procedural Floating World
## Master Visual Concept Art Prompt

Create an exceptionally detailed 3D isometric fantasy game environment representing the visual identity of **Willage**, a living world built on procedurally generated floating islands.

The image should communicate a coherent game art direction combining the charm of Wakfu and Dofus, hand-painted fantasy environments, stylized geological formations, and sophisticated voxel-based terrain technology.

### 1. Overall Composition

A large, naturally shaped floating island, viewed from a fixed three-quarter isometric camera angle.

Show the island as a complete cross-section, revealing both its inhabited upper surface and its complex underground structure.

The island should feel like a miniature living world, not an artificial square platform.

Include:
- A rich, green upper landscape with rolling terrain.
- Small grass-covered plateaus and irregular elevations.
- Rivers, natural pools, streams and waterfalls.
- Small paths, stone formations, vegetation and a few fantasy structures.
- Exposed geological layers along the island's sides.
- Deep underground caves, tunnels, chambers and mineral formations.
- Floating rocks, hanging roots and occasional waterfalls disappearing into clouds beneath the island.

The composition must clearly communicate the relationship between the surface terrain and the underground geology.

### 2. Art Direction – Hybrid Hand-Painted 3D

A distinctive hybrid visual style:
- Stylized hand-painted 3D environment.
- Soft, organic shapes combined with angular low-poly geological formations.
- Rich but controlled color palette.
- Strong silhouettes and readable terrain forms.
- Painterly surface details and subtle color variation.
- Carefully designed ambient occlusion and soft directional lighting.
- Charming fantasy atmosphere without becoming childish.
- High-quality game-ready environment concept art.

Avoid photorealism, generic voxel cubes and overly simplistic low-poly graphics.

The terrain should feel sculpted and artistically designed, while retaining the visual logic of a procedural geological world.

### 3. Terrain Geometry – Material-Dependent Appearance

The geometry must visibly respond to different geological materials.

Do not use one universal surface style.

**Soft materials – soil, clay and sediment:**
- Smooth, rounded transitions.
- Organic erosion patterns.
- Soft excavation walls.
- Gentle surface deformations.

**Sedimentary rocks – sandstone and limestone:**
- Clearly visible geological strata.
- Layered formations.
- Irregular horizontal fractures.
- Eroded edges and occasional overhangs.

**Hard crystalline rocks – granite and gneiss:**
- Angular facets.
- Sharp fractures.
- Strong polygonal silhouettes.
- Irregular rock surfaces.

**Volcanic rocks – basalt:**
- Dark fractured formations.
- Angular surfaces.
- Distinctive column-like structures.
- Occasional volcanic mineral deposits.

**Ice and frozen geological formations:**
- Smooth and translucent surfaces.
- Sharp crystalline fractures.
- Subtle blue illumination.

The transitions between geological materials should feel naturally integrated rather than artificially separated.

### 4. Surface Appearance

The upper island should be visually rich and inviting.

Include:
- Saturated green grass growing over the edges of cliffs.
- Thick, slightly irregular grass-covered plateaus.
- Small patches of flowers and vegetation.
- Exposed soil beneath grass.
- Natural stone paths and rock formations.
- Trees with stylized hand-painted foliage.
- Roots partially exposed along cliff edges.

Grass should visibly overhang the geological cliff edges, creating a distinctive silhouette.

### 5. Underground World

Show a substantial underground environment integrated into the floating island.

Include:
- Large natural caverns.
- Vertical shafts and horizontal tunnels.
- Different geological strata.
- Underground pools and streams.
- Mineral veins embedded in rock.
- Glowing crystals and occasional luminous minerals.
- Stalactites and stalagmites.
- Natural rock bridges and overhangs.

The underground geometry should be more angular and dramatic than the surface terrain.

Use lighting to create distinct underground environments: dark stone, warm mineral illumination and cool cyan reflections from underground water and crystals.

The underground should feel explorable and physically connected to the surface.

### 6. Water System

Water is a fundamental part of the environment.

Show:
- Small surface streams following natural terrain slopes.
- Water collecting in geological depressions.
- Natural waterfalls flowing over island edges.
- Water disappearing into clouds below the floating island.
- Underground springs emerging from rock formations.
- Subterranean pools with turquoise reflections.

Water should have a stylized, slightly painterly appearance, with clear reflections and readable flow direction.

### 7. Island Underside

The underside of the island is an important visual feature.

Include:
- Large exposed geological rock formations.
- Distinct rock layers and irregular fractures.
- Hanging roots and occasional vegetation.
- Detached floating stones.
- Deep shadows between rock formations.
- Waterfalls and mist disappearing into clouds.

The underside should look like a naturally formed geological mass, not a regular cube or artificial platform.

### 8. Lighting and Atmosphere

Use warm, soft daylight illuminating the upper surface.

Create contrast between:
- Bright, saturated vegetation.
- Warm sandstone and brown soil.
- Dark geological cliffs.
- Cool underground water and crystals.
- Soft atmospheric clouds beneath the island.

Use stylized global illumination, ambient occlusion and painterly shadow transitions.

### 9. Technical Visual Communication

The illustration should suggest a terrain system built from 0.25-meter voxel sampling, but the voxel grid itself must NOT be visible.

The terrain must appear as continuous 3D geometry with material-dependent surface characteristics.

Show convincing natural overhangs, caves, tunnels, vertical surfaces and irregular geological boundaries.

The scene should look technically achievable in a real-time game engine such as Godot, using procedural terrain geometry, modular environmental assets and stylized materials.

### 10. Final Image Requirements

- Single coherent environment illustration.
- High-detail 3D isometric perspective.
- Entire floating island visible.
- Surface and underground clearly readable.
- Strong visual hierarchy.
- Professional fantasy game environment concept art.
- Rich hand-painted textures.
- Carefully controlled geometry and color.
- No text, labels, diagrams, UI, watermarks or borders.
- No visible voxel grid.
- No photographic realism.
- No regular Minecraft-like cube geometry.

**The final result should look like a beautiful, explorable fantasy world where geology, terrain deformation, water, vegetation and underground ecosystems are all part of one coherent living environment.**</WritingBlock>

## Co bych chtěl výsledkem ověřit

Při hodnocení vygenerovaného obrázku bych sledoval čtyři věci:

1. **Čitelnost geologie:** Je na první pohled vidět rozdíl mezi měkkou půdou, vrstveným pískovcem a tvrdou žulou?
2. **Přirozenost terénu:** Vypadá ostrov jako skutečný prostorový terén, který lze kopat a deformovat?
3. **Výtvarná konzistence:** Nepůsobí tráva, skály, voda a podzemí jako assety z různých her?
4. **Herní použitelnost:** Dokážeš si představit, že se po tomto světě pohybují postavy a hráči ho postupně přetvářejí?

Doporučuji nejprve vytvořit jeden reprezentativní obrázek celého ostrova. Ten bychom pak mohli použít jako **Visual Art Direction Reference pro celý Willage**, podle které se budou navrhovat jednotlivé materiály, shadery, vegetace a geometrie.

---

### 16. Uživatel

Zkus to vygenerovat 

---

### 17. Asistent (shrnutí uvažování)

Přemýšlel po dobu 1m 25s

---

### 18. Asistent

Výsledný koncept Willage: plovoucí ostrov s obyvatelným povrchem, vodními toky, geologickými vrstvami a propojeným podzemím.

Za mě je to dobrý směr pro další rozpracování vizuální identity hry. Zvlášť důležité je zachovat kontrast mezi barevným, živým povrchem a tmavším, geologicky členitým podzemím.

---

### 19. Uživatel

Jo jo to je dobrý. 

---

### 20. Asistent

Super. Myslím, že jsme tím získali poměrně jasný vizuální směr pro Willage.

Tenhle obrázek bychom mohli považovat za první **Visual Art Direction Reference** projektu.

Důležité bude teď převést ho z konceptu do konkrétních herních assetů a rendereru v Godotu. Začal bych rozpracováním jednoho reprezentativního výřezu ostrova: tráva, půda, několik geologických vrstev, skalní převis a voda. Na něm ověříme, jestli voxelová geometrie dokáže dosáhnout požadovaného vzhledu i při kopání.

---

### 21. Uživatel

Budu potřebovat textury a trary pro mesh ne?

---

### 22. Asistent (shrnutí uvažování)

Přemýšlel sekundu

---

### 23. Asistent

Ano. A dokonce bych řekl, že pro dosažení vzhledu z referenčních obrázků budeme potřebovat poměrně promyšlenou knihovnu **textur, materiálů a samostatných 3D assetů**.

Důležité ale je, abychom je správně rozdělili. Nechceme všechno řešit texturou ani všechno geometrií.

## 1. Co budeme potřebovat

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="hand painted stylized fantasy game seamless terrain texture atlas grass dirt soil stone" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **A. Terrain textures**

      Textury přímo pro voxelový mesh:
      - Tráva.
      - Hlína a půda.
      - Pískovec.
      - Vápenec.
      - Žula.
      - Čedič.
      - Krystalické horniny.
      - Led a sníh.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted fantasy grass clumps tufts 3D game foliage asset" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **B. Vegetační assety**

      Samostatná geometrie:
      - Trsy trávy.
      - Převislá tráva.
      - Keře.
      - Květiny.
      - Kořeny.
      - Stromy.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted fantasy rock modular cliff rock formations 3D game assets" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **C. Geometrické assety**

      Doplňková geometrie:
      - Balvany.
      - Skalní převisy.
      - Krystaly.
      - Stalaktity.
      - Stalagmity.
      - Visící kameny.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted fantasy water waterfall texture game asset" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **D. Efekty a speciální materiály**

      - Povrchová voda.
      - Vodopády.
      - Podzemní voda.
      - Průsvitné krystaly.
      - Mokré povrchy.
      - Sníh a led.
    </box>
  </row>
</box>

## 2. Jak bych to technicky řešil v Godotu

Pro voxelový terén bych doporučil následující kombinaci:

| Technologie | Použití |
|---|---|
| Texture Array | Hlavní materiály hornin |
| Vertex Colors | Přechody mezi materiály |
| Triplanar Mapping | Texturování bez závislosti na UV |
| Normal Maps | Jemné povrchové detaily |
| Roughness Maps | Rozdílné optické vlastnosti |
| MultiMeshInstance3D | Tráva, květiny, kamínky |
| Shader | Barevné variace, přechody, mokré povrchy |

**Zásadní rozhodnutí:** Texturování musí být nezávislé na generování meshe.

Když hráč odkope část žuly, mesh se přegeneruje, ale materiál se automaticky znovu přiřadí podle materiálových ID voxelů. Nemusíme ukládat textury ani UV pro každou buňku.

## 3. Jak bych navrhl první sadu textur

<grid columns={2} gap={2}>
  <grid-item>
    <AsyncImage query="hand painted seamless stylized lush green grass texture top down game material" aspectRatio="5:4" width="100%"/>
    **Grass**
    <caption>Tráva na povrchu</caption>
  </grid-item>
  <grid-item>
    <AsyncImage query="hand painted seamless stylized brown earth dirt soil texture game material" aspectRatio="5:4" width="100%"/>
    **Soil**
    <caption>Půda a sedimenty</caption>
  </grid-item>
  <grid-item>
    <AsyncImage query="hand painted stylized sandstone layered rock seamless texture game material" aspectRatio="5:4" width="100%"/>
    **Sandstone**
    <caption>Vrstvená hornina</caption>
  </grid-item>
  <grid-item>
    <AsyncImage query="hand painted stylized dark granite fractured rock seamless texture game material" aspectRatio="5:4" width="100%"/>
    **Granite**
    <caption>Tvrdá hornina</caption>
  </grid-item>
</grid>

Pro začátek bych vytvořil textury v rozlišení 512 × 512 a 1024 × 1024. Ne všechny materiály potřebují vysoké rozlišení.

## 4. Ještě jedna důležitá věc: textura není geometrie

Například převislá tráva na hraně ostrova by neměla být pouze namalovaná na textuře.

Potřebujeme kombinaci:

- Terrain mesh definuje skutečný okraj.
- Grass mesh vytváří převis.
- Vertex colors propojí trávu s okolním terénem.
- Shader přidá drobné barevné a povrchové variace.

<AsyncImage query="stylized hand painted fantasy game floating island cliff thick lush grass overhanging edge exposed layered rock roots" aspectRatio="16:9" width="100%"/>

---

## 5. Doporučený první produkční balíček

Začal bych malou knihovnou, ne stovkami assetů.

| Kategorie | Počet |
|---|---:|
| Základní terrain textures | 8 |
| Geologické textury | 8 |
| Normal/roughness mapy | podle materiálů |
| Trsy trávy | 4 |
| Keře | 3 |
| Skalní assety | 6 |
| Krystaly | 3 |
| Vodní materiály | 2 |

Tohle nám stačí k vytvoření prvního reprezentativního výřezu ostrova.

**Navrhoval bych jako další krok vytvořit jednotný Texture & Material Atlas pro Willage**, včetně výtvarných pravidel, barevné palety, měřítek textur a vazby na tvých 78 materiálových ID. Díky tomu budeme mít pevný základ pro generování dalších assetů i automatické přiřazování materiálů v Godotu.

---

### 24. Uživatel

Říká.jsi ale že každý materiál by měl.byt vykreslen trochu jinak v 3d ne jen textura. 

---

### 25. Asistent (shrnutí uvažování)

Přemýšlel po dobu 4s

---

### 26. Asistent

Ano, přesně. A máš pravdu, že v předchozím návrhu jsem příliš zdůraznil textury. Ty samy o sobě nedokážou vytvořit vizuální rozdíly, které jsme si stanovili.

U Willage potřebujeme, aby materiál ovlivňoval **skutečný 3D tvar terénu, nejen jeho povrchový vzhled**.

Rozdělil bych to na čtyři úrovně.

# 1. Čtyři vrstvy vizuální reprezentace materiálu

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="stylized clay soil smooth rounded eroded fantasy terrain 3D game asset" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **1. Geometrický charakter (macro geometry)**

      Určuje skutečný tvar terénu:
      - Zaoblenost.
      - Ostré hrany.
      - Převisy.
      - Lomové plochy.
      - Geologické vrstvení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized hand painted sandstone rock geological layers cliff closeup" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **2. Geometrické detaily (micro geometry)**

      Menší prostorové útvary:
      - Trhliny.
      - Drobné výčnělky.
      - Erozní rýhy.
      - Krystalické struktury.
      - Lomové fragmenty.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="hand painted stylized fantasy rock texture detailed painted sandstone granite" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **3. Povrchová reprezentace (surface appearance)**

      - Barevnost.
      - Textura.
      - Normal map.
      - Roughness.
      - Barevné přechody.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="stylized fantasy rocky cliff moss grass roots environmental details game art" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **4. Dekorativní vrstva (environmental details)**

      - Mech.
      - Kořeny.
      - Trsy trávy.
      - Balvany.
      - Krystaly.
    </box>
  </row>
</box>

# 2. Jak by se měly jednotlivé horniny skutečně chovat

Tady je konkrétní představa:

<box gap={3}>
  <box gap={1}>
    **Jíl – měkká geometrie**
    <AsyncImage query="stylized smooth rounded clay earth terrain cliff hand painted 3D game asset closeup" aspectRatio="16:9" width="100%"/>
    - Hladké stěny výkopu.
    - Zaoblené přechody.
    - Měkké erozní tvary.
    - Minimum ostrých lomů.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Pískovec – vrstvená geometrie**
    <AsyncImage query="stylized hand painted layered sandstone cliff geological strata angular erosion 3D game environment" aspectRatio="16:9" width="100%"/>
    - Viditelné horizontální vrstvy.
    - Místní převisy.
    - Odlamující se hrany.
    - Rozdílná eroze vrstev.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Žula – tvrdá facetovaná geometrie**
    <AsyncImage query="stylized low poly faceted granite rock cliff sharp angular fractures game asset" aspectRatio="16:9" width="100%"/>
    - Ostré polygonové plochy.
    - Výrazné zlomy.
    - Nepravidelné lomové plochy.
    - Minimum zaoblování.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **Čedič – charakteristická struktura**
    <AsyncImage query="stylized basalt column rock formations volcanic cliff fantasy game asset" aspectRatio="16:9" width="100%"/>
    - Sloupcovité útvary.
    - Pravidelnější fraktury.
    - Ostré hrany.
    - Vertikální geometrické struktury.
  </box>
</box>

# 3. Technická architektura pro Godot

Navrhuji, abychom nevytvářeli samostatný mesher pro každý materiál. To by komplikovalo napojování chunků a přechody mezi horninami.

Místo toho bych zavedl **Material-aware Geometry Pipeline**.

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **Voxel Data**

    Density + Material ID + Geological Layers
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **Material Geometry Profiles**

    Výpočet geometrických vlastností podle materiálu
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **Geometry Field Processing**

    Zaoblení, zachování hran, vrstvení a lokální struktury
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(168,85,247,0.10)" radius="md" padding={3} align=center>
    **Meshing – MC / DC comparison**

    Výběr a porovnání algoritmů pro jednotlivé typy geometrie
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align=center>
    **Unified Terrain Mesh**

    Jednotná výsledná geometrie s materiálovými atributy
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align=center>
    **Surface Shader + Detail Geometry**
  </box>
</box>

Důležitý detail: materiálové profily nesmějí libovolně deformovat původní geologii. Například zaoblování jílu musí respektovat hranici sousední žulové vrstvy.

Proto bych používal vážené materiálové profily v okolí hranic a zachovával původní geologická rozhraní jako samostatnou informaci.

# 4. Jak by mohla vypadat definice materiálu

Například:

```json
{
  "id": 12,
  "name": "Sandstone",

  "geometry_profile": {
    "meshing_mode": "feature_preserving",
    "smoothness": 0.35,
    "edge_preservation": 0.75,
    "fracture_strength": 0.55,
    "layer_expression": 0.9,
    "detail_amplitude": 0.12,
    "detail_frequency": 0.8
  },

  "surface_profile": {
    "texture_array": 2,
    "roughness": 0.85,
    "normal_strength": 0.6
  }
}
```

Hodnoty jsou zatím ilustrativní, nikoliv finální fyzikální nebo výtvarné parametry.

---

# 5. Co bych skutečně implementoval jako první

Nedělal bych hned všech 78 materiálů. Připravil bych čtyři reprezentativní materiály:

| Materiál | Geometrie | Testovaný algoritmus |
|---|---|---|
| Jíl | Hladká, zaoblená | Marching Cubes |
| Pískovec | Vrstvená | MC + DC |
| Žula | Ostrá, facetovaná | Dual Contouring |
| Čedič | Frakturovaná | DC + procedurální detaily |

Vytvořil bych jeden testovací blok 8 × 8 m, ve kterém budou všechny čtyři materiály vedle sebe a také nad sebou.

Pak bychom mohli testovat:
- Jak vypadají jejich přirozené hranice.
- Co se stane při kopání přes dvě různé horniny.
- Jak se mění geometrie při odkrytí.
- Jak vypadají materiály při izometrickém pohledu.
- Jaká je cena generování meshe na telefonu.

**Moje zásadní doporučení:** Nechme materiálovou tabulku Willage určovat nejen fyzikální vlastnosti, ale také geometrickou identitu horniny. Renderer pak bude pouze interpretovat tato data.

Tím dostaneš svět, ve kterém poznáš rozdíl mezi jílem, pískovcem a žulou nejen podle barvy, ale i podle samotného tvaru terénu. A to je podle mě jeden z nejzajímavějších vizuálních prvků, které může Willage nabídnout.

Dalším logickým krokem je vytvořit konkrétní `GeometryProfile` specifikaci pro všech 78 materiálových ID, ale nejdřív ověřit systém na těchto čtyřech horninách.

---

### 27. Uživatel

Ok koukni na to. Ve her jsou 2 druhý map, herní generovaná že seedu a pak ostrov který sklizeny z výřezu  z herních světů. Ostrov je taková základna a herní svět je pro dobrodružství a s Íránu materiálu atd. 

---

### 28. Asistent (shrnutí uvažování)

Přemýšlel po dobu 5s

---

### 29. Asistent

Aha, tohle je důležité upřesnění. Mění to trochu pohled na celou architekturu Willage. Ve skutečnosti nemáš jeden herní svět s různými oblastmi, ale **dva odlišné typy herního prostoru, které mají rozdílnou funkci a způsob práce s daty**.

A podle mě je správné je oddělit už na úrovni architektury.

# 1. Dva typy světů ve Willage

<box gap={3}>
  <box border radius="lg" padding={3} gap={2}>
    <row align=center justify=between>
      **A. Procedurální svět**
      <badge color="info">Adventure World</badge>
    </row>
    <AsyncImage query="stylized hand painted fantasy isometric vast wilderness floating islands mountains forest rivers caves game environment" aspectRatio="16:9" width="100%"/>
    **Účel:** Dobrodružství, průzkum a získávání surovin.

    - Generovaný deterministicky ze seedu.
    - Rozsáhlý prostor až 4096 × 4096 m.
    - Geologická rozmanitost.
    - Přírodní zdroje, minerály, jeskyně.
    - Vodní systémy, vegetace a biomy.
    - Primárně procedurální, změny se ukládají jako rozdíly.
    - Hráči zde objevují a těží materiály.
  </box>
  <box border radius="lg" padding={3} gap={2}>
    <row align=center justify=between>
      **B. Domovský ostrov**
      <badge color="success">Home Island</badge>
    </row>
    <AsyncImage query="stylized Wakfu Dofus hand painted fantasy floating island village miniature diorama grass stone houses waterfall" aspectRatio="16:9" width="100%"/>
    **Účel:** Základna hráčů, budování vesnice a společenský prostor.

    - Skládá se z blueprintů získaných z výřezů procedurálních světů.
    - Blueprinty lze posouvat, otáčet, zrcadlit a výškově upravovat.
    - Ostrov může kombinovat části různých světů.
    - Hráči zde staví, upravují terén a hospodaří.
    - Změny jsou trvalé a ukládají se.
    - Má větší důraz na stavění, dekorace a vizuální prezentaci.
  </box>
</box>

# 2. Co to znamená pro vykreslování

Tady bych udělal zásadní rozhodnutí:

**Oba světy by měly používat stejný Terrain Renderer, ale rozdílnou konfiguraci a pravidla prezentace.**

Nemá smysl vyvíjet dva samostatné renderery. Zbytečně bys zdvojoval práci s materiály, geometrií a optimalizací.

Navrhuji následující strukturu:

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.12)" padding={3} radius="md" align=center>
    **World Data Providers**

    Procedurální svět / Blueprint / Ostrovní změny
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(59,130,246,0.12)" padding={3} radius="md" align=center>
    **Unified Terrain Data Interface**

    Density, Material ID, Geological Layers, Water
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(168,85,247,0.12)" padding={3} radius="md" align=center>
    **Terrain Renderer**

    Geometry Pipeline + Material Profiles + Surface Shaders
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(34,197,94,0.10)" padding={3} radius="md" align=center>
    **Presentation Layer**

    Vegetace, voda, objekty, efekty, osvětlení
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box border radius="md" padding={2} align=center>
        **Adventure Presentation**

        Průzkum, příroda, zdroje
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align=center>
        **Home Island Presentation**

        Stavby, vesnice, dekorace
      </box>
    </grid-item>
  </grid>
</box>

# 3. Rozdílné vizuální priority

I při stejném rendereru bych nastavil odlišné vizuální profily.

| Oblast | Procedurální svět | Domovský ostrov |
|---|---|---|
| Geologie | Velmi důležitá | Důležitá |
| Vegetace | Přirozená, rozmanitá | Dekorativní, upravitelná |
| Voda | Přírodní hydrologie | I dekorativní vodní prvky |
| Skalní struktury | Geologicky věrné | Výrazná vizuální stylizace |
| Stavby | Vzácné / objevované | Hlavní součást |
| Dekorace | Omezené | Bohaté |
| Osvětlení | Atmosférické | Čitelnější, útulnější |

# 4. Důležitá věc: Blueprint není jen geometrie

Tady bych se zastavil.

Pokud ostrov skládáš z výřezů procedurálních světů, doporučuji zachovávat jejich původní geologickou identitu.

Blueprint by měl obsahovat nebo odkazovat na:

- Původní seed světa.
- Souřadnice výřezu.
- Verzi generátoru.
- Geologická a materiálová data.
- Výškový profil.
- Případné transformace.

Díky tomu můžeš například vytvořit ostrov, který obsahuje:

- Lesní oblast z jednoho světa.
- Vulkanickou oblast z druhého.
- Ledovcovou oblast ze třetího.

A přitom nemusíš ukládat kompletní voxelovou geometrii všech těchto oblastí. Stačí zachovat jejich deterministický zdroj a transformaci.

Samozřejmě ostrovní změny musí mít přednost před původní funkcí blueprintu.

# 5. Co bych z toho vyvodil pro další vývoj

Vidím zde tři samostatné subsystémy:

1. **World Renderer** – vykreslení rozsáhlého procedurálního světa.
2. **Island Renderer** – vykreslení složeného a editovatelného ostrova.
3. **Shared Terrain Engine** – společná geometrie, materiály a vykreslovací technologie.

Island Renderer může navíc používat bohatší dekorativní vrstvu, aniž by to zatěžovalo Adventure World.

---

## Jedna architektonická otázka, kterou bych chtěl vyřešit

Jak přesně bude fungovat vztah mezi světem a blueprintem?

Představuji si dvě možnosti:

**A – Blueprint jako zmrazený výřez**

Výřez světa se při vytvoření blueprintu zafixuje. Další změny původního světa už blueprint neovlivní.

**B – Blueprint jako živý odkaz**

Blueprint si uchovává seed a souřadnice a jeho obsah se vždy znovu dopočítává z původního světa.

Za mě je vhodnější **A s deterministickým zdrojovým záznamem**. Blueprint by měl být neměnný základ, nad kterým vzniká vlastní ostrovní stav. Je to bezpečnější pro multiplayer, verzování generátoru a dlouhodobé ukládání.

Toto rozhodnutí bude mít poměrně zásadní vliv na ukládání dat i na to, jak budeme organizovat generování a cachování meshů.

---

### 30. Uživatel

U těch výřezu jsem přemýšlel že by to byl jedno nebo dvoudruhový materiál bloku, loužil by pro budování základny ne pro tězbu. 

---

### 31. Asistent

Aha! Tak to je podstatně jiný koncept, a podle mě i zajímavější. Blueprint tedy není kus světa, který si hráč přenese na ostrov včetně jeho kompletní geologie. Je to spíš **stavební materiál a základní terénní modul pro vytvoření domovského ostrova**.

Tím se nám architektura výrazně zjednodušuje.

## 1. Blueprint jako stavební blok

Každý blueprint bude výřez procedurálního světa o rozměru 128 × 128 m, ale pro použití na domovském ostrově bude reprezentovat pouze jeden nebo dva materiály.

Například:

<grid columns={2} gap={3}>
  <grid-item>
    <AsyncImage query="stylized fantasy lush green grassy floating island terrain tile isometric game asset" aspectRatio="5:4" width="100%"/>
    **Travnatý blueprint**

    Tráva + půda
  </grid-item>
  <grid-item>
    <AsyncImage query="stylized fantasy rocky floating island plateau isometric game asset" aspectRatio="5:4" width="100%"/>
    **Skalnatý blueprint**

    Žula + půda
  </grid-item>
  <grid-item>
    <AsyncImage query="stylized fantasy sandy desert plateau floating island game environment" aspectRatio="5:4" width="100%"/>
    **Písčitý blueprint**

    Písek + pískovec
  </grid-item>
  <grid-item>
    <AsyncImage query="stylized fantasy snowy floating island rocky terrain game environment" aspectRatio="5:4" width="100%"/>
    **Ledovcový blueprint**

    Sníh + led
  </grid-item>
</grid>

Výřez tak zachová charakter terénu, ale nebude přenášet kompletní geologický systém původního světa.

## 2. Dva nezávislé materiálové systémy

Tady bych nově rozlišil:

| Vlastnost | Adventure World | Home Island |
|---|---|---|
| Materiály | Kompletní geologie | 1–2 stavební materiály |
| Horniny | Žíly, vrstvy, útvary | Zjednodušená reprezentace |
| Těžba | Ano | Ne jako hlavní účel |
| Kopání | Získávání surovin | Úprava stavebního prostoru |
| Geometrie | Geologicky podmíněná | Stavebně orientovaná |
| Blueprint | Zdroj terénu | Stavební modul |

Důležité je, že bych nepřepisoval původní materiálová ID. Blueprint může mít vlastní materiálovou reprezentaci, která odkazuje na vizuální profily společné knihovny.

## 3. Jak by to fungovalo technicky

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **Procedural World Generator**

    Kompletní terén, geologie, voda, biom
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **Blueprint Extraction**

    Výřez 128 × 128 m
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align=center>
    **Blueprint Simplification**

    Výběr 1–2 materiálů + zachování výškového profilu
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align=center>
    **Home Island Composition**

    Posuny, rotace, zrcadlení a výškové úpravy
  </box>
  <box align=center><icon name="arrow-down"/></box>
  <box background="rgba(168,85,247,0.10)" radius="md" padding={3} align=center>
    **Shared Terrain Renderer**

    Geometrie + materiály + dekorace
  </box>
</box>

## 4. Co bych zachoval z původního světa

I když blueprint obsahuje pouze jeden nebo dva materiály, nezahazoval bych:

- Výškový profil.
- Sklon terénu.
- Přirozené nerovnosti.
- Charakteristickou siluetu.
- Povrchové členění.
- Případně hydrologické vlastnosti, pokud mají být součástí stavebního modulu.

Tím dostaneš rozmanité ostrovy, aniž bys musel na domovském ostrově simulovat kompletní geologii dobrodružného světa.

## 5. Jedno důležité rozhodnutí

Vidím dvě možnosti, jak se má blueprint chovat při budování:

**A – Zachování původního reliéfu**

Hráč dostane kus terénu s původním profilem. Může ho upravovat kopáním a přidáváním materiálu, ale základní tvar zůstává.

**B – Stavební hmota**

Blueprint poskytuje materiál a základní terénní charakter, ale hráč může ostrov výrazně přetvářet, prakticky jako modelovací hmotu.

Já bych se přikláněl k variantě B, ale s původním reliéfem jako výchozím stavem.

To nám umožní vytvořit zajímavou kombinaci: hráči si přinesou různé části světů, sestaví z nich základnu a postupně si ji přetvoří.

**Další krok bych věnoval definici datového kontraktu Blueprintu**, protože právě ten určí, co se přenáší z dobrodružného světa do domovského ostrova a co už patří výhradně jeho vlastní simulaci.

---

### 32. Uživatel

Nechám to ale.asi jak to je, přenese se vše. V jiném návrhu jsem chtěl těmto blokům dávat raritu podle počtu a druhů vzácných materiálu a minerálů atd. Byl by to jen index hodnocení, neukazoval by co je v tom výřezu, jen jak vzácný výřez si uživatel udelal. 

---

### 33. Asistent

Tohle mění charakter blueprintu poměrně zásadně – a podle mě je to lepší než jeho zjednodušování na jeden nebo dva materiály.

Blueprint by tedy přenášel **kompletní obsah výřezu z procedurálního světa**, včetně geologie, minerálů a vzácných materiálů. Rarita by ale fungovala jako samostatné hodnocení jeho hodnoty, nikoliv jako informace o jeho obsahu.

## Navrhoval bych oddělit dvě věci

**1. Obsah blueprintu**

- Výškový profil a tvar terénu.
- Geologické vrstvy.
- Materiály, minerály a jejich výskyt.
- Dutiny, žíly a další geologické útvary.
- Případně vodní a další přírodní vlastnosti.

**2. Rarity Index**

Číselné hodnocení vypočítané při vytvoření blueprintu. Hráč vidí pouze výslednou raritu, nikoliv seznam nebo umístění vzácných materiálů.

Například:

<box border radius="lg" gap={3} padding={3}>
  <row align="center" justify="between">
    **Blueprint #A7F29**
    <badge color="discovery">Legendary</badge>
  </row>
  <title size="2xl" color="default" tabularNums>94.7</title>
  <text color="secondary" size="xs">Rarity Index · 0–100</text>
  <divider color="subtle"/>
  <row justify="between">
    <text color="secondary" size="sm">Původ</text>
    **Adventure World**
  </row>
  <row justify="between">
    <text color="secondary" size="sm">Rozměr</text>
    **128 × 128 m**
  </row>
  <row justify="between">
    <text color="secondary" size="sm">Geologický obsah</text>
    **Skrytý**
  </row>
  <row justify="between">
    <text color="secondary" size="sm">Hodnota</text>
    **Vzácný výřez**
  </row>
</box>

## Jak bych počítal raritu

Nedělal bych ji jako prostý součet vzácných materiálů. To by zvýhodňovalo velké množství drobných výskytů a šlo by to snadno zneužít.

Rozdělil bych ji na několik faktorů:

| Faktor | Co hodnotí |
|---|---|
| Rarity | Jak vzácné druhy materiálů se vyskytují |
| Quantity | Celkové množství vzácných materiálů |
| Diversity | Počet různých vzácných druhů |
| Concentration | Jak jsou vzácné materiály koncentrované |
| Geological uniqueness | Výjimečnost geologické kombinace |

Výsledkem by byl jeden index, například 0–100, který se převede na kategorii rarity.

Důležité je, aby výpočet probíhal nad původním blueprintem, nikoliv nad jeho aktuálně vytěženým stavem. Jinak by hráč mohl raritu měnit těžbou.

## Jedna důležitá architektonická věc

Rarity Index bych ukládal jako **metadata blueprintu**, nikoliv jako vlastnost materiálu nebo simulace.

Blueprint by tak měl například:

- `SourceWorldId`
- `SourceSeed`
- `SourceRegion`
- `GeneratorVersion`
- `RarityIndex`
- `RarityTier`
- `ContentSnapshot`

Tím získáš možnost později upravovat algoritmus hodnocení, aniž bys musel měnit samotný obsah blueprintu.

Ještě bych zvážil jednu věc: **rarita by měla být určena při vytvoření výřezu a následně neměnná**, i kdyby hráč materiály vytěžil nebo terén přetvořil. Blueprint tak reprezentuje původní přírodní hodnotu získaného území.

Tohle může být zajímavý herní mechanismus: hráči nesbírají jen kusy terénu pro stavbu, ale také vzácné geologické lokality. Dalším krokem by bylo definovat přesný výpočet Rarity Indexu a jeho ochranu proti manipulaci.

---

### 34. Uživatel

Dlambych původní a aktuální. 

---

### 35. Asistent

Ano. To je výrazně lepší řešení. Vedl bych **Original Rarity** a **Current Rarity** jako dvě samostatné hodnoty.

- **Original Rarity** – hodnota původního blueprintu při jeho získání. Neměnná, představuje historickou a sběratelskou hodnotu lokality.
- **Current Rarity** – hodnota aktuálního stavu. Přepočítává se podle toho, co v blueprintu ještě zůstalo a jaké změny v něm hráč provedl.

Například:

| Hodnota | Původní | Aktuální |
|---|---:|---:|
| Rarity Index | 94,7 | 61,2 |
| Kategorie | Legendary | Rare |
| Vzácné minerály | 5 druhů | 2 druhy |
| Geologická unikátnost | 91 | 91 |

Tady bych ale zavedl jednu důležitou věc: **ne všechny složky rarity musí reagovat na změny stejně.**

Například:
- Vytěžení minerálu sníží Current Rarity.
- Zničení vzácné geologické struktury může snížit Current Rarity.
- Postavení budovy by nemělo automaticky snižovat geologickou raritu.
- Původní geologická unikátnost zůstane zachována jako historická vlastnost.

Technicky bych měl například:

```csharp
public sealed class BlueprintRarity
{
    public RaritySnapshot Original { get; init; }
    public RaritySnapshot Current { get; set; }
}

public sealed class RaritySnapshot
{
    public float Index { get; init; }
    public RarityTier Tier { get; init; }
}
```

Ještě bych doporučil ukládat také důvod změny Current Rarity, případně jen souhrnné změnové metriky. Nemusíš kvůli tomu pokaždé analyzovat celý blueprint.

Tím získáš dvě herní hodnoty: **sběratelskou hodnotu původně objeveného místa a hodnotu jeho současného přírodního stavu.** To může být zajímavé i pro obchodování s blueprinty.

---

### 36. Uživatel

Jj tak nějak jsem nad tím přemýšlel. 

---

### 37. Asistent

Myslím, že ten koncept má dobrý potenciál. Blueprint pak není jen kus terénu, ale zároveň **sběratelský objekt s vlastní historií a proměnlivou hodnotou**.

Líbí se mi hlavně rozdělení:
- Original Rarity zachycuje, co hráč objevil a získal.
- Current Rarity zachycuje, co z původní přírodní hodnoty zachoval.

A časem se na tom dá postavit i ekonomika mezi hráči – například obchodování s nedotčenými vzácnými blueprinty oproti těm, které už byly částečně vytěženy.

Zatím bych ale nepředbíhal s ekonomikou. Nejdřív bych přesně definoval, které změny ovlivňují Current Rarity a které ne. To je důležitý základ celého systému.

---

If you want, I can:

- Navrhnout přesná pravidla pro aktualizaci Current Rarity
- Definovat datový kontrakt blueprintu včetně rarity a historie
- Rozpracovat herní mechaniku obchodování s blueprinty podle rarity
