# Technické hodnocení modelu

Zdroj: https://chatgpt.com/share/6b042446-2f50-83eb-9146-5c39ce7e1ff9

Počet zachycených zpráv: 89

---

### 1. Uživatel

Projekt Willage: hra s plovoucími ostrovy (Godot 4.7, GDScript; server později v C#, který musí generátor zopakovat bitově stejně). Chci probrat jen datový model procedurálního generátoru terénu V1.0, bez vykreslování.

STAV IMPLEMENTACE (stavíme po krocích, každý schvaluju zvlášť)
- Krok 1 (základy) a krok 2 (funkce světa I) jsou hotové a schválené.
- Krok 3 (geologie) je hotový a čeká na schválení.
- Kroky 4–11 jsou naplánované. Část kódu z nich existuje ve studiích a prototypu, ale ne v novém modelu.

HIERARCHIE A ROZMĚRY [hotovo, krok 1]
Svět → blueprint → ostrov → blok → segment → buňka.
- Svět je deterministická funkce ze seedu na ploše max 4096 × 4096 m. Neukládá se, jen se z ní čte.
- Blok má 128 × 128 m, segment 8 m (parametr 8/16/32), buňka (voxel) 0,25 m.
- Výška sloupce je výčet 32/64/128 m (výchozí 128 m = 512 buněk), neutrální úroveň je v polovině. Rozměry musí být mocniny 2 a navzájem dělitelné.
- Jednotky jsou metry, voda je v litrech s jedním převodem na m³.
- Verze generátoru má tvar Vmajor.minor (teď V1.0) a ukládá se ke každému ostrovu.
- Determinismus je povinný: stejný seed, parametry a verze dají bitově stejný svět (float64, řazené klíče, celočíselné hashe).
- Jedna tabulka materiálů: 78 id, 1 B na buňku. U každého materiálu je mj. propustnost.
- Odloženo: jak naložit s už hranými ostrovy, když se verze generátoru změní.

FUNKCE SVĚTA
Rozhraní: dotaz na bod (x, y, z) vrátí materiál, dotaz na sloupec (x, y) vrátí povrch, hranice vrstev a hladinu.
- Krok 2 [hotovo]:
  - Klima: základní klima světa ze seedu (mírné, poušť, step, tundra, ledovec), uvnitř světa ho mírně mění pomalá mapa. Klima je preset z tabulky, který upraví vstupní parametry generátoru (poušť je plošší a má méně vody) a určí, které biomy se vyskytují a s jakou váhou. Uplatní se před reliéfem. Tabulka patří k verzi generátoru, takže její změna znamená novou verzi. Hodnoty presetů zatím nejsou vyladěné. Reliéf a klima jsou dvě nezávislé osy.
  - Mapa biomů a mapa hornin: hrubé body ze seedu a plynulá interpolace.
  - Reliéf z parametrů biomu (převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu). Když se převýšení pod strop nevejde, tvar se roztáhne do šířky. V přechodech biomů platí vážený průměr stropů. Drobné tvary do ~2 m smí strop překročit.
  - Masiv (hora se stěnou a podhůřím) jako součást funkce.
  - Sopky: počet a rozteč jsou parametry, polohy ze seedu, tvar mezi strato a štítovou, kráter, vrchol aspoň 5 m pod okrajem sloupce.
- Krok 3 [hotovo, čeká na schválení]:
  - Geologie: pásma vrstev z pořadí hornin, 1–3 zástupci podle mapy hornin. Vrstvy kopírují terén a vyklíňují, mocnost je min. 0,25 m a max. 1/4 výšky.
  - Útvary (žíly, pně, skarny, dómy, kras, dutiny, minerály) jsou SDF z hashe světové mřížky, takže jsou spojité přes švy bloků (ověřeno 0 rozdílů).
  - Vápenec a dolomit 50/50 až 2 m pod hladinou, nad tím vyklínění jílu.
  - Sopka uvnitř: průduch od kráteru dolů, slupky lávy a popela.
  - Otevřené: navázat vápenec na skutečnou hladinu z kroku 4? Vlastní id pro lávu a popel? Výkon (segment 2,6 s, návrhy na zrychlení zapsané).
- Krok 4 [plán]: hladina podzemní vody a propustnost jako funkce geologie, bez uložených buněk. Prameny ze seedu (druh, poloha, jmenovitý výkon), skutečný výkon omezí okolí. Artéská voda jen na ověření.

OSTROV [plán, krok 5]
- Ostrov = seed + parametry + verze + seznam vložení v pořadí.
- Vložení (objekty Source, Transform, Placement) nese souřadnice blueprintu ve světě, otočení o 90°, zrcadlení, výškový posun, režim napojení a seed a verzi zdrojového světa. Blueprint může být i z jiného světa.
- Dotaz na vložený blok se inverzní transformací přepočte do souřadnic zdroje.
- Napojení bloků jen po stranách (rohy se neřeší). Režim Auto: rozdíl do 6 buněk se vyrovná rampou na 3 buňkách, větší rozdíl udělá útes. Dále Blend (povrch rampa 1–4 buňky, podzemní vrstvy klín 1/16 bloku) a Keep. Sousedé se při vložení nemění.

BUŇKY A UKLÁDÁNÍ [plán, krok 6]
- Buňky se generují jen v zorném poli plus okraji, a jen jako slupka 2–3 buněk u vzduchu nebo pod průhlednou vodou. Hlubší se donačtou při odkrytí.
- Kopání po 0,25 m. Dno a okraj ostrova se prokopat nedají.
- Ukládá se jen rozdíl proti funkci, po segmentech (klíče + deflate, hlavička s verzí, transformací a pořadím).
- Připravené, ale vypnuté pole „původní materiál“ (+1 B na změněnou buňku) pro kontrolu na serveru.

VODA NA OSTROVĚ [plán, krok 7; jednotlivé části existují ve studiích]
- Simulace povrchu i podzemí: vsakování, boční tok podle spádu, prameny, kras.
- Eroze je samostatná vrstva posunu výšky nad funkcí, kladná (usazování) i záporná, nemění buňky. Ověří se, zda stejný offset stačí i pro krasové dutiny.
- Přepočet po výkopu běží asynchronně na sjednoceném povodí (prodleva 2 s, strop 10 s, fronta výkopů).
- Drobné výtoky pod 0,1 l/s se slučují v dosahu 8 m.
- Výchozí voda je ustálený stav po vygenerování. Ukládá se jen odchylka v krocích 1/16 l, 1 B na buňku (0–15,625 l).
- Čas: 1 herní den = 1 h.

DALŠÍ KROKY [plán]
- Krok 8: povrchové jevy klimatu po vodě (písek, led, sníh, výpar, zamrzání). Prahy zatím otevřené.
- Krok 9: vegetace jako funkce seedu, materiálu, sklonu a výchozí vody, hustota na m², v tůních nic. Ukládají se jen změny (kácení, výsadba, růst).
- Krok 10: povinný test. Svět 3 × 3 bloky se rozřeže na 9 blueprintů a složí do ostrova (náhodné pořadí, otočení, zrcadlení, aspoň jeden blueprint z jiného světa). Měří se determinismus, paměť, časy a velikost rozdílu. Pak se uzavře V1.0.
- Krok 11: kontrakt se serverem. Server ukládá seed, parametry, verzi, seznam vložení a rozdíl a namátkově to ověřuje generátorem (dá se vypnout). Ověřené změny se ukládají do zásobníku. Testovací vektory zajistí stejný hash v GDScriptu i C#.

CO CHCI PROBRAT
Je tenhle model (funkce světa + ukládání jen rozdílu + vkládání blueprintů s transformací) rozumný? Kde vidíš rizika pro determinismus mezi GDScriptem a C#, pro velikost ukládaných dat a pro výkon funkce světa (dotaz po sloupcích ze seedu je pomalý)? A jak dobře spolu fungují eroze jako vrstva posunu a uložený rozdíl buněk?

---

### 2. Asistent (shrnutí uvažování)

Přemýšlel po dobu 1m 6s

---

### 3. Asistent

# Willage – technické hodnocení datového modelu generátoru V1.0

Můj závěr: **základní architektura je správně navržená a má dobrý potenciál pro dlouhodobý vývoj. Neměnil bych její základní principy. Upravil bych ale několik důležitých částí datového modelu ještě před uzavřením V1.0.**

Největší přednost návrhu je oddělení tří věcí:

1. **Procedurální svět** – matematická funkce, která dokáže rekonstruovat terén ze seedu.
2. **Ostrov** – složenina blueprintů, transformací a vlastních parametrů.
3. **Perzistentní změny** – pouze to, co hráči změnili oproti výchozímu stavu.

To je velmi dobrý základ pro hru, kde:
- svět může být rozsáhlý, ale nemusí být celý uložený;
- hráči mohou vytvářet ostrovy z různých částí různých světů;
- server nemusí ukládat kompletní geometrii;
- klient může generovat terén lokálně;
- server může generování nezávisle ověřovat.

Vidím však pět oblastí, které bych považoval za zásadní:

| Oblast | Hodnocení | Riziko |
|---|---|---|
| Funkce světa ze seedu | Velmi dobrý základ | Výkon opakovaných dotazů |
| Blueprinty a transformace | Správný koncept | Švy a přesnost transformací |
| Ukládání rozdílů | Velmi dobrý koncept | Změny verzí a precedence |
| Determinismus GDScript/C# | Vyžaduje zpřesnění | Bitová neshoda |
| Eroze jako samostatná vrstva | Správný směr | Interakce s geologií a editací |

Prošel bych to postupně.

---

# 1. Funkce světa + ukládání rozdílů

Tohle bych rozhodně zachoval.

V podstatě navrhuješ systém, ve kterém není terén primárně datová struktura, ale **rekonstruovatelný stav**.

Zjednodušeně:

\[
World = F(seed, parameters, version, x,y,z)
\]

A ostrov:

\[
Island = Composition(Worlds, Placements, Deltas)
\]

Výsledný materiál buňky potom:

\[
M(x,y,z) =
\begin{cases}
D(x,y,z), & \text{existuje uložená změna}\\
G(x,y,z), & \text{jinak}
\end{cases}
\]

Kde:
- \(G\) je procedurální generátor,
- \(D\) je uložená změna,
- \(M\) je výsledný materiál.

Tento přístup má jednu zásadní výhodu: **velikost uložených dat závisí na rozsahu hráčských zásahů, nikoliv na velikosti ostrova.**

To je pro Willage velmi výhodné.

## Co bych ale změnil

Nedělal bych z rozdílu jednu univerzální vrstvu.

Doporučuji oddělit minimálně tři typy změn:

<box border radius="lg" gap={3} padding={3}>
  <box gap={1}>
    **A. Terrain Override**

    <badge color="success">Základní vrstva</badge>
    - Vykopané buňky.
    - Nahrazené materiály.
    - Uměle vytvořené bloky.
    - Změna materiálu na konkrétních souřadnicích.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **B. Terrain Deformation**

    <badge color="success">Samostatná vrstva</badge>
    - Eroze.
    - Usazování sedimentů.
    - Posuny povrchu.
    - Případně další přirozené deformace.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **C. Dynamic State**

    <badge color="success">Samostatná vrstva</badge>
    - Odchylka množství vody.
    - Vegetační změny.
    - Sníh a led.
    - Další dynamické jevy.
  </box>
</box>

Proč?

Protože tyto změny mají odlišnou sémantiku, granularitu a životní cyklus.

Například:
- vykopání buňky je trvalý zásah hráče;
- eroze může postupně měnit hodnotu;
- množství vody se může měnit každou simulaci;
- vegetace může růst a zanikat.

Kdybys všechno ukládal jako změnu materiálu buňky, postupně by se ti systém začal komplikovat.

**Důležité:** každá vrstva musí mít definované pořadí aplikace. Nestačí pouze vědět, že nějaká změna existuje.

---

# 2. Determinismus mezi GDScriptem a C#

Tady vidím největší technické riziko celého návrhu.

Máš uvedeno:

- float64;
- celočíselné hashe;
- řazené klíče;
- stejný seed a verzi;
- bitově stejný výsledek.

To je dobrý začátek, ale samotný float64 bitovou shodu nezaručuje.

## 2.1 Problém není jen přesnost floatu

GDScript a C# mohou při zdánlivě totožném výpočtu vytvořit odlišné výsledky.

Rizikové jsou zejména:

| Operace | Potenciální problém |
|---|---|
| sin, cos, pow, exp | Rozdílné implementace matematických funkcí |
| sqrt | Rozdílné zaokrouhlování |
| Interpolace | Rozdílné pořadí operací |
| FMA | Sloučení násobení a sčítání |
| Převody float → int | Odlišná pravidla zaokrouhlování |
| Hashování | Přetečení a signed/unsigned |
| Dictionary | Pořadí iterace |
| Random | Rozdílné generátory a stav RNG |

Například:

\[
a + b \cdot c
\]

nemusí být bitově stejné jako:

\[
FMA(b,c,a)
\]

Přestože matematicky jde o stejnou operaci.

U procedurálního generátoru je to problém, protože malá odchylka může změnit:
- výšku terénu;
- klasifikaci materiálu;
- polohu hranice vrstvy;
- rozhodnutí, zda vznikne dutina;
- výsledek interpolace.

## 2.2 Doporučuji hybridní determinismus

Nemusíš nutně odstranit všechny floaty. Doporučuji ale rozdělit výpočty do dvou kategorií.

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    <badge color="success">Deterministické jádro</badge>
    **Integer / Fixed-point**

    Použít pro:
    - souřadnice a transformace;
    - seed a hash;
    - výběr materiálů;
    - rozhodování o vzniku útvarů;
    - hranice voxelů;
    - výsledné výšky a mocnosti vrstev;
    - ukládání a porovnávání.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <badge color="info">Numerické výpočty</badge>
    **Float64**

    Použít pro:
    - mezivýpočty noise;
    - hladké funkce reliéfu;
    - SDF;
    - fyzikální modely;
    - interpolace, pokud jejich výsledek následně prochází přesně definovanou kvantizací.
  </box>
</box>

Například výslednou výšku neukládat jako libovolný float, ale kvantizovat ji na pevnou jednotku.

Možná reprezentace:

- 1 jednotka = 1/4096 m;
- 1 voxel = 1024 jednotek;
- všechny výsledné výšky jsou integer.

Tím získáš velmi jemné rozlišení a zároveň přesné hranice voxelů.

Ještě důležitější je definovat jednotné zaokrouhlování. Například round-half-away-from-zero nebo vlastní celočíselnou implementaci.

## 2.3 Hashovací systém

Doporučuji nepoužívat jeden společný RNG, který generuje hodnoty postupně.

Místo toho použít **counter-based deterministický hash**.

Například:

```text
Hash(
    WorldSeed,
    DomainId,
    FeatureType,
    GridX,
    GridY,
    FeatureIndex
)
```

Z jednoho seedu tak můžeš nezávisle získat:
- polohu sopky;
- velikost žíly;
- typ horniny;
- polohu pramene;
- lokální variaci biomu.

Výhoda je zásadní.

Přidání nového typu geologického útvaru nerozbije generování ostatních útvarů, protože jejich náhodné hodnoty nejsou závislé na pořadí volání RNG.

Doporučuji také zavést oddělené `DomainId` pro každou generativní subsystémovou oblast.

## 2.4 Testování shody

Zaveď společný soubor testovacích vektorů:

```text
GeneratorVersion
WorldSeed
ParametersHash
Coordinate
ExpectedMaterial
ExpectedHeight
ExpectedLayerBoundaries
ExpectedColumnHash
```

GDScript i C# musí pro stejné vstupy vrátit stejné výsledky.

Neověřoval bych pouze výsledný hash celého ostrova. Testoval bych také jednotlivé mezivýsledky.

**Moje doporučení:** determinismus definovat jako samostatný kontrakt generátoru, ne jako vedlejší vlastnost implementace.

---

# 3. Výkon funkce světa – největší praktický problém

Tady bych byl poměrně přísný.

Matematicky čistý generátor, který dokáže vypočítat libovolný bod světa, je skvělý. Ale pokud každý dotaz na sloupec musí znovu počítat klima, biom, reliéf, masiv, sopku, geologii a útvary, nebude to škálovat.

Zvlášť pokud:
- hráč kope;
- voda požaduje opakované dotazy;
- klient generuje několik segmentů;
- mobilní zařízení musí držet FPS;
- server současně provádí kontrolní regeneraci.

**Neřešil bych to optimalizací jednotlivých matematických funkcí jako první. Změnil bych způsob, jakým generátor pracuje s daty.**

## 3.1 Funkce světa by měla mít více úrovní

Navrhuji následující architekturu:

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **World Definition**

    <text color="secondary" size="xs">Seed · Parametry · Verze · Klima</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Coarse Spatial Fields**

    <text color="secondary" size="xs">Mapa biomů · Horniny · Klima · Základní reliéf</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Column Evaluation**

    <text color="secondary" size="xs">Výška · Geologické hranice · Podzemní voda</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align="center">
    **Spatial Feature Evaluation**

    <text color="secondary" size="xs">Žíly · Pně · Dutiny · Sopky · Minerály</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align="center">
    **Material Query**

    <text color="secondary" size="xs">Výsledný materiál na souřadnici X, Y, Z</text>
  </box>
</box>

Klíčová změna: jednotlivé úrovně nemusí pokaždé počítat své vstupy znovu.

## 3.2 Přidej deterministickou cache

Doporučuji tři typy cache.

| Cache | Obsah | Granularita |
|---|---|---|
| World Field Cache | Klima, biom, horniny | Hrubá světová mřížka |
| Column Cache | Výška a hranice vrstev | Sloupec XY |
| Feature Cache | Lokální geologické útvary | Prostorová oblast |

Cache není součástí uloženého světa. Je to pouze dočasný výpočetní výsledek.

Například:

```text
ColumnCacheKey:
    WorldSeed
    GeneratorVersion
    ParametersHash
    X
    Y
```

Výsledkem může být:

```text
ColumnData:
    SurfaceHeight
    BiomeId
    RockMapId
    LayerBoundaries[]
    GroundwaterLevel
```

Tento výsledek následně využívají další funkce.

### Důležitá věc: cache musí být nezávislá na pořadí dotazů

Pokud nejprve vygeneruješ sloupec A a potom B, musíš dostat stejný výsledek jako při opačném pořadí.

Cache nikdy nesmí ovlivňovat výsledek generátoru. Smí pouze eliminovat opakované výpočty.

## 3.3 Segment jako výpočetní jednotka

Máš blok 128 × 128 m a segment 8 m.

To je dobré rozdělení.

Zavedl bych ale jasné rozlišení:

- **Sloupec** = logická jednotka funkce světa.
- **Segment** = jednotka dávkového výpočtu a cache.
- **Buňka** = jednotka materiálového dotazu a editace.
- **Blok** = organizační a kompoziční jednotka.

Segment 8 × 8 m obsahuje při rozlišení 0,25 m:

\[
32 \times 32 = 1024
\]

sloupců.

Místo 1024 samostatných volání celého generátoru bych měl možnost požádat o:

```text
EvaluateSegment(segment_x, segment_y)
```

Generátor tak může:
1. načíst potřebné hrubé mapy;
2. vypočítat 1024 sloupců;
3. vyhodnotit relevantní geologické útvary;
4. vytvořit kompaktní ColumnData;
5. ponechat výsledek v cache.

To je výrazně vhodnější pro dávkové zpracování a pozdější paralelizaci.

### Pozor na jednu věc

Geologické útvary nesmí být omezené hranicemi segmentu.

Segment je pouze výpočetní jednotka. Geologický útvar musí být definovaný v globálních souřadnicích světa. To už máš správně vyřešené pomocí SDF a hashované světové mřížky.

## 3.4 Jak bych řešil pomalé dotazy na sloupce

Rozhodně bych nezaváděl trvalé uložení všech sloupců.

Místo toho:

- hrubé mapy vypočítat nebo načítat po prostorových dlaždicích;
- sloupce počítat dávkově;
- výsledky držet v omezené LRU cache;
- segmenty generovat asynchronně;
- po zahození cache kdykoliv rekonstruovat stejný výsledek.

Tím zachováš původní filozofii procedurálního světa.

---

# 4. Blueprinty a transformace

Tento koncept považuji za jeden z nejsilnějších prvků návrhu.

Umožňuje ti oddělit generování světa od konstrukce konkrétního ostrova.

Například:

<AsyncImage query="fantasy floating island modular terrain blocks seamless mountainous landscape aerial view game environment" aspectRatio="16:9" width="100%"/>

Ostrov nemusí být vygenerovaný z jednoho seedu. Může obsahovat:
- část světa A;
- část světa B;
- ručně upravený blueprint;
- opakovaně použitý blueprint;
- různé transformace jednotlivých částí.

To je architektonicky velmi dobré.

## 4.1 Doporučuji přesně definovat souřadnicový systém

Zavedl bych tři souřadnicové prostory:

| Prostor | Účel |
|---|---|
| World Space | Souřadnice původního procedurálního světa |
| Blueprint Space | Lokální souřadnice blueprintu |
| Island Space | Výsledné souřadnice ostrova |

Transformace:

\[
P_{island} = T_{placement}(P_{blueprint})
\]

A při dotazu:

\[
P_{blueprint} = T^{-1}_{placement}(P_{island})
\]

Následně:

\[
P_{world} = T^{-1}_{source}(P_{blueprint})
\]

Všechny transformace musí mít přesně definované pořadí.

### Moje doporučení

Pro V1.0 používej pouze celočíselné souřadnice v jednotkách 0,25 m.

Tedy:

```text
1 world unit = 1 voxel = 0.25 m

X, Y, Z = integer
```

Otočení o 90° a zrcadlení potom můžeš řešit čistě celočíselnými operacemi.

Například:

```text
Rotation 0:
    (x, y)

Rotation 90:
    (-y, x)

Rotation 180:
    (-x, -y)

Rotation 270:
    (y, -x)
```

U zrcadlení je potřeba jednoznačně definovat osu a pořadí aplikace vůči rotaci.

Tím se vyhneš problémům s floating-point transformacemi.

## 4.2 Napojování blueprintů

Zde vidím jeden potenciální problém.

Tvůj systém říká:

- Auto: rozdíl do 6 buněk vyrovnat rampou na 3 buňkách;
- větší rozdíl vytvoří útes;
- Blend: povrchová rampa a podzemní klín;
- Keep: zachovat původní stav.

To je dobré, ale musíš rozhodnout, kdo je vlastníkem výsledného přechodu.

Doporučuji zavést koncept **Boundary Evaluation**.

Například:

```text
Boundary:
    PlacementA
    PlacementB
    Side
    Mode
    BoundaryWidth
    HeightDifference
    MaterialPolicy
    GeologicalPolicy
```

Výsledek napojení se bude počítat z obou sousedních blueprintů.

Důležité je, aby:
- přechod nebyl závislý na pořadí generování segmentů;
- sousední segmenty počítaly stejnou hranici;
- změna pořadí načítání neměnila výsledek;
- bylo jasné, jak se rozhoduje při více sousedních vloženích.

**Zásadní upozornění:** pořadí vložení je součástí identity ostrova, ale nemělo by automaticky znamenat, že poslední vložený blueprint přepíše předchozí.

Pořadí má vliv jen tam, kde to výslovně definuje kompoziční pravidlo.

## 4.3 Blueprint z jiného světa

Tady je potřeba zachovat identitu původního zdroje.

Nestačí uložit pouze seed.

Doporučuji:

```text
Source:
    SourceWorldSeed
    SourceGeneratorVersion
    SourceParametersHash
    SourceCoordinateSystemVersion
```

`SourceParametersHash` je důležitý, protože stejný seed nemusí znamenat stejný svět při jiných parametrech.

Při pozdější změně generátoru musí být možné poznat, podle čeho byl blueprint vytvořen.

---

# 5. Eroze jako vrstva posunu versus uložený rozdíl buněk

Toto je podle mě nejzajímavější architektonická otázka celého návrhu.

Tvůj nápad, že eroze nemění buňky, ale ukládá samostatnou vrstvu výškového posunu, je velmi dobrý.

A především: **erozi bych opravdu nedával do stejného systému jako hráčské změny buněk.**

## 5.1 Jak bych to modeloval

Výchozí terén:

\[
H_0(x,y)
\]

Erozní deformace:

\[
E(x,y)
\]

Výsledný povrch:

\[
H(x,y)=H_0(x,y)+E(x,y)
\]

Kladné E znamená usazování, záporné E znamená erozi.

Doporučuji, aby E nebylo ukládáno jako float64, ale jako kvantizovaná celočíselná hodnota.

Například:

```text
ErosionDelta:
    X
    Y
    HeightOffset
```

Případně kompaktní pole hodnot na segment.

Výhodou je, že můžeš mít:

- procedurální výchozí terén;
- erozní deformaci;
- hráčské vykopání;
- umístění nových materiálů;

aniž by se tyto systémy vzájemně ničily.

## 5.2 Pozor na geologii

Zde je největší problém.

Představ si:

- původní povrch: 100 m;
- vrstva vápence: 90–95 m;
- eroze odstraní 3 m.

Nový povrch je 97 m.

Co se stane s geologickými vrstvami?

Máš dvě možnosti.

**Varianta A – posun pouze povrchu**

Geologické vrstvy zůstávají na původních absolutních souřadnicích.

Výsledek: terén může odhalit nové vrstvy, ale musíš řešit, jak geometricky interpretovat odstraněný materiál.

**Varianta B – deformace celého geologického sloupce**

Posuneš nejen povrch, ale také příslušné hranice vrstev.

Výsledek: geologická struktura zůstává relativně zachovaná, ale eroze se chová spíše jako deformace celého sloupce než jako skutečné odebírání materiálu.

Pro Willage bych doporučil třetí, přesnější variantu:

**C – erozní změna povrchu + zachování geologických struktur v absolutních souřadnicích.**

Tedy:
- eroze mění povrch;
- geologické vrstvy zůstávají definované ve světových souřadnicích;
- dotaz na materiál respektuje nový povrch;
- materiál nad novým povrchem se stává vzduchem;
- nově odkryté vrstvy se projeví přirozeně.

Tím zachováš význam geologie.

U krasových dutin je potřeba samostatně rozhodnout, zda se jejich strop může erozí odkrýt. Podle mě ano.

## 5.3 Jak spolu budou fungovat eroze a hráčské kopání

Tady doporučuji jednoznačné pořadí:

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **1. Base Terrain**

    Původní procedurální terén a geologie.
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **2. Natural Deformation**

    Eroze a usazování.
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **3. Player Overrides**

    Vykopané, nahrazené a nově umístěné buňky.
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3}>
    **4. Effective Terrain**

    Výsledný stav pro další systémy.
  </box>
</box>

Toto pořadí znamená, že hráčské zásahy mají přednost před přirozeným generováním.

Příklad:

1. Eroze odebere 2 m terénu.
2. Hráč do místa umístí kamennou zeď.
3. Eroze se později aktualizuje.
4. Zeď zůstává, protože jde o explicitní hráčský override.

To je žádoucí chování.

### Jeden problém, který bych vyřešil předem

Co se stane, když eroze odebere materiál z buňky, kterou hráč předtím upravil?

Doporučuji rozlišovat:
- `Inherit` – použít výsledek generátoru;
- `Air` – explicitně odstranit buňku;
- `MaterialOverride` – explicitně nastavit materiál.

To je důležité, protože prázdná buňka nesmí být zaměnitelná s buňkou, pro kterou neexistuje uložený rozdíl.

Samotné pole `MaterialId` na to nestačí, pokud je vzduch reprezentovaný nulou a zároveň je nula použita pro nepřítomnost změny.

---

# 6. Velikost ukládaných dat

Tady máš dobré předpoklady.

Základní rozměry:

- segment 8 × 8 m;
- voxel 0,25 m;
- 32 × 32 sloupců;
- výchozí výška 128 m;
- 512 buněk na sloupec.

Jeden segment obsahuje:

\[
32 \times 32 \times 512 = 524\,288
\]

buněk.

Při jednom bajtu na buňku:

<box border radius="lg" padding={3} gap={2}>
  **Paměť plného segmentu**
  <title size="2xl" color="default" tabularNums>512 KiB</title>
  <text color="secondary" size="xs">Pouze materiálové ID, bez dalších datových struktur.</text>
  <divider color="subtle"/>
  **Jeden blok 128 × 128 m**

  16 × 16 segmentů = 256 segmentů.

  <title size="xl" tabularNums>128 MiB</title>
  <text color="secondary" size="xs">Plně materializovaný blok při výšce 128 m.</text>
</box>

To je důvod, proč je správně, že nechceš ukládat kompletní materiálová pole.

## 6.1 Doporučená struktura uložených změn

Pro každou změněnou buňku:

```text
SegmentDelta:
    SegmentCoordinate
    ChangedCellCount
    CellChanges[]
```

Změna:

```text
CellChange:
    LocalCellIndex
    Operation
    MaterialId
```

Operace:
- Air;
- MaterialOverride;
- případně ResetToGenerated.

Doporučuji ukládat změny seřazené podle `LocalCellIndex`.

Výhody:
- kompaktní delta encoding;
- snadné porovnání;
- rychlé hledání;
- deterministické hashování;
- snadná komprese.

Pro větší počet změn bych použil několik reprezentací podle hustoty:

| Hustota změn | Reprezentace |
|---|---|
| Velmi nízká | Sparse seznam změn |
| Střední | Bitset + seznam materiálů |
| Vysoká | Husté pole + komprese |

Není důvod používat vždy stejnou reprezentaci.

## 6.2 Voda

Tady vidím potenciálně problémovou část.

Máš 1 bajt na buňku a rozsah 0–15,625 l.

To je rozumné pro kompaktní uložení, ale je nutné si uvědomit, že jedna buňka má objem:

\[
0{,}25^3 = 0{,}015625\,m^3
\]

To odpovídá 15,625 litru.

Takže tvoje reprezentace dokáže uložit maximálně jeden objem buňky vody na buňku.

To může být záměr, ale musíš rozlišit:
- obsah vody v pórech;
- volnou vodu v buňce;
- vodu proudící přes buňku;
- případnou vodu nad povrchem.

Pro podzemní vodu může být tento limit dostatečný, pro povrchovou vodu budeš pravděpodobně potřebovat samostatný model.

Také bych oddělil výchozí ustálený stav od hráčských změn. Výchozí voda by měla být rekonstruovatelná ze seedu a parametrů; uložená odchylka by měla být jednoznačně vztažená k tomuto základu.

---

# 7. Další rizika, která bych nepodcenil

Ještě několik věcí, které nejsou přímo vidět v současném modelu, ale mohou později způsobit zásadní problémy.

## 7.1 Verze generátoru nestačí sama o sobě

Máš `V1.0`, což je správně.

Doporučuji ale vedle verze generátoru uchovávat také:

```text
GeneratorIdentity:
    GeneratorVersion
    ParametersHash
    MaterialTableVersion
    CoordinateSystemVersion
    DeterminismProfile
```

Důvod:

Změna tabulky materiálů může změnit výsledek, i když se nezmění samotný algoritmus.

Stejně tak změna pravidel zaokrouhlování nebo souřadnicového systému.

Verze V1.0 musí jednoznačně identifikovat celý kontrakt generování, ne jen zdrojový kód.

## 7.2 Material ID

78 materiálů v jednom bajtu je bez problému.

Doporučuji ale rozlišit:
- identitu materiálu;
- vlastnosti materiálu;
- jeho vizuální reprezentaci;
- jeho fyzikální vlastnosti.

Generátor by měl pracovat s ID a vlastnostmi definovanými v konkrétní verzi tabulky.

Změna vizuálního vzhledu kamene nesmí způsobit změnu hashů terénu.

Změna propustnosti materiálu naopak může ovlivnit vodní simulaci, ale nemusí nutně znamenat změnu základního terénu.

To jsou dvě odlišné věci.

## 7.3 Kontrola integrity uložených změn

Doporučuji zavést hashování na několika úrovních:

```text
WorldHash
    └── BlueprintHash
          └── PlacementHash
                └── SegmentDeltaHash
```

Tím může server kontrolovat pouze relevantní část ostrova.

Nemusí při každém ověření rekonstruovat celý ostrov.

Hash by měl zahrnovat také identitu zdrojového blueprintu a pořadí kompozice.

---

# 8. Co bych zachoval a co bych změnil

Toto je moje výsledné doporučení pro V1.0.

| Část modelu | Rozhodnutí |
|---|---|
| Svět jako funkce seedu | Zachovat |
| Klima a biom jako nezávislé osy | Zachovat |
| Geologie jako pásma + SDF | Zachovat |
| Blueprinty z různých světů | Zachovat |
| Transformace o 90° | Zachovat, definovat celočíselně |
| Ukládání pouze rozdílů | Zachovat |
| Eroze jako samostatná vrstva | Zachovat |
| Materiálové override | Zachovat |
| Float64 jako jediná garance determinismu | Změnit |
| Jeden univerzální delta systém | Rozdělit |
| Výpočet každého sloupce od začátku | Nahradit víceúrovňovou cache |
| Segment jako hranice geologie | Nepoužívat |
| Jediný hash celého ostrova | Doplnit hierarchické hashe |

# 9. Navrhovaná výsledná architektura datového modelu

Takhle bych si představoval cílovou strukturu V1.0.

<box border radius="lg" padding={3} gap={3}>
  <box gap={1} align="center">
    <title size="lg">World Definition</title>
    <text color="secondary" size="xs">Seed · Parameters · Generator Identity</text>
  </box>
  <divider color="subtle"/>
  <box gap={1} align="center">
    **Procedural World Function**
    <text color="secondary" size="xs">Climate · Biomes · Relief · Geology · Groundwater</text>
    <badge color="info">Deterministic</badge>
  </box>
  <divider color="subtle"/>
  <box gap={1} align="center">
    **Island Composition**
    <text color="secondary" size="xs">Source · Transform · Placement · Boundary Rules</text>
  </box>
  <divider color="subtle"/>
  **Island State**
  <grid columns={2} gap={2}>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} gap={1}>
        **Terrain Delta**
        <text color="secondary" size="xs">Buňkové změny</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} gap={1}>
        **Deformation**
        <text color="secondary" size="xs">Eroze, sedimenty</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} gap={1}>
        **Water State**
        <text color="secondary" size="xs">Odchylky vody</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} gap={1}>
        **Environmental State**
        <text color="secondary" size="xs">Vegetace, sníh, led</text>
      </box>
    </grid-item>
  </grid>
  <divider color="subtle"/>
  <box gap={1} align="center">
    **Effective Terrain Query**
    <text color="secondary" size="xs">World → Placement → Deformation → Override → Material</text>
  </box>
  <divider color="subtle"/>
  <box gap={1} align="center">
    **Persistence & Validation**
    <text color="secondary" size="xs">Segment Deltas · Hashes · Server Verification</text>
  </box>
</box>

Poznámka: jde o logické vrstvy datového modelu. Nemusí to být samostatné projekty ani samostatné runtime služby.

---

# 10. Co bych udělal před schválením kroku 3

Krok 3 bych zatím formálně neschvaloval, ale nepovažuji ho za špatně navržený. Jeho základní principy jsou správné.

Nejdříve bych uzavřel následujících pět rozhodnutí:

<box border radius="lg" padding={3} gap={3}>
  **Rozhodnutí potřebná pro uzavření datového modelu**

  {@body const items = ["Definovat deterministický numerický kontrakt GDScript ↔ C# včetně kvantizace a hashování.","Definovat identitu generátoru a verzování materiálových tabulek.","Definovat pořadí aplikace procedurálního terénu, eroze a hráčských změn.","Definovat souřadnicové transformace a pravidla vlastnictví hranic blueprintů.","Definovat strukturu ColumnData a víceúrovňovou cache bez závislosti na pořadí dotazů."]}
  {@body const [checked,setChecked] = DIL.useState([])}
  <row align="center" justify="between">
    <text color="secondary" size="xs" tabularNums>{checked.length} / {items.length} vyřešeno</text>
    <button size="sm" variant="ghost" color="secondary" onClick={()=>setChecked([])}>Reset</button>
  </row>
  <box background="surface-tertiary" radius="full" height="6px" clip>
    <box background="surface-inverted" height="6px" radius="full" width={`${checked.length/items.length*100}%`}/>
  </box>
  {#each items as item,i}
    <checkbox key={i} checked={checked.includes(i)} onChange={v=>setChecked(old=>v?[...old,i]:old.filter(x=>x!==i))}>{item}</checkbox>
  {/each}
</box>

## Moje konečné hodnocení

<badge color="success">Architekturu doporučuji zachovat</badge>

Největší síla návrhu je, že odděluješ **definici světa od jeho aktuálního stavu**. To je správný základ pro serverově ověřitelný, procedurálně generovaný multiplayerový svět.

Největší riziko není samotná geologie ani velikost dat. Je to determinismus a opakovaná cena výpočtu.

Proto bych jako další technický krok navrhoval následující:

**Definovat přesný datový kontrakt `WorldColumnData` a `WorldGenerator`, tedy co musí generátor vypočítat, co může cachovat a co musí být identické mezi GDScriptem a C#.**

Tím získáme stabilní rozhraní pro kroky 2–4 a současně připravíme základ pro ostrov, vodu i serverovou validaci. Zatím bych nepřecházel k implementaci dalších kroků, dokud tento kontrakt nebude schválen.

---

### 4. Uživatel

V datovém modelu generuju funkcionálně geologické vrstvy. Potřebuji tuto funkci vykreslit jako 3d graf/plochu abych mohl kontrolovat jak to vypadá. 

---

### 5. Asistent (shrnutí uvažování)

Přemýšlel pár sekund

---

### 6. Asistent

Pro Willage bych doporučil vytvořit **samostatný 3D diagnostický nástroj pro geologii**, který nebude součástí herního vykreslování terénu.

Cílem je zobrazit výsledek funkce generátoru jako skutečný 3D prostorový model, abys mohl kontrolovat:
- průběh jednotlivých geologických vrstev;
- jejich mocnost a vyklínění;
- návaznost vrstev na povrch terénu;
- žíly, pně, dómy a dutiny;
- spojitost přes hranice bloků a segmentů;
- případné průniky nebo překrývání vrstev.

<AsyncImageGroup query={["3D geological stratigraphic model cutaway colored layers terrain scientific visualization","3D geological cross section subsurface strata colored layers visualization","3D geological model ore veins underground strata scientific visualization"]} aspectRatio="5:4" layout="bento"/>

Vidím dvě možnosti realizace:

**A. Samostatný interaktivní 3D prohlížeč**

Zadáš seed a parametry generátoru, nástroj zavolá funkce geologie a vykreslí vrstvy jako barevné 3D plochy. Můžeš otáčet modelem, přibližovat, skrývat vrstvy a dělat řezy.

**B. Diagnostický modul přímo v Godot 4.7**

Využije stejné funkce generátoru jako hra, ale místo herního terénu vytvoří diagnostickou Mesh geometrii. Výhodou je, že testuješ přímo produkční implementaci.

**Doporučuji B**, protože potřebuješ ověřovat skutečné výsledky generátoru, nikoliv jeho druhou implementaci.

Jedna otázka: Chceš tento 3D prohlížeč vytvořit přímo v Godotu, nebo chceš nejdříve samostatnou interaktivní 3D vizualizaci pro kontrolu matematických funkcí geologie?

---

### 7. Uživatel

Klidně v Godot , protože pak potřebuji i vykreslit jeskyně, hory atd ale pořád jako plochy funkcí

---

### 8. Asistent (shrnutí uvažování)

Přemýšlel po dobu 25s

---

### 9. Asistent

Pak bych pro Willage zvolil jednu společnou architekturu: **funkcionální 3D terén s procedurálně generovanými povrchy (Implicit Surface / SDF) a diagnostickým vykreslovačem v Godotu.**

To je důležitější rozhodnutí, než se na první pohled zdá. Nechceš totiž vykreslovat pouze geologické vrstvy. Chceš stejným principem zobrazovat:

- vnější povrch ostrova a reliéf;
- jednotlivé geologické vrstvy;
- skalní stěny a převisy;
- jeskyně a krasové dutiny;
- žíly a jiné geologické útvary;
- průduchy sopek;
- podzemní prostory.

A přitom nechceš, aby se základním zdrojem pravdy stala voxelová geometrie.

To znamená, že bych oddělil **matematickou definici povrchu od jeho triangulace a vykreslení**.

# 1. Základní architektura

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Functional Terrain Model**

    <text color="secondary" size="xs">Seed · Parametry · Geologie · Reliéf · Útvary</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Surface Field Evaluation**

    <text color="secondary" size="xs">Výška, SDF, materiál, hranice vrstev</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Surface Extraction**

    <text color="secondary" size="xs">Marching Cubes / Dual Contouring</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box background="rgba(34,197,94,0.10)" radius="md" padding={2} align="center">
        **Game Renderer**
        <text color="secondary" size="xs">Finální terén</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(34,197,94,0.10)" radius="md" padding={2} align="center">
        **Diagnostic Renderer**
        <text color="secondary" size="xs">Geologické řezy a plochy</text>
      </box>
    </grid-item>
  </grid>
</box>

Výhoda: obě vykreslovací cesty používají stejná matematická data. Diagnostický nástroj tedy nebude mít vlastní napodobeninu geologie.

# 2. Jak reprezentovat jednotlivé útvary

Nedoporučuji používat jednu univerzální matematickou funkci pro všechno. Potřebuješ několik typů funkčních povrchů.

| Typ | Matematická reprezentace | Příklad |
|---|---|---|
| Povrch terénu | Výšková funkce H(x,y) | Hory, údolí |
| Geologické vrstvy | Hranice Bₖ(x,y) | Sedimenty, horniny |
| Žíly | 3D SDF | Rudné žíly |
| Jeskyně | 3D SDF | Krasové dutiny |
| Skalní masivy | Kombinace výškové funkce a SDF | Převisy, stěny |
| Sopky | Kombinace výškové funkce a SDF | Kráter, průduch |

Důležitá vlastnost: H(x,y) nedokáže sama reprezentovat převis ani jeskyni. Pro tyto případy potřebuješ plnohodnotnou 3D implicitní reprezentaci.

## 3. Jak bych matematicky skládal geologii a jeskyně

Tady bych zavedl jeden společný princip: **každý povrch je definován rovnicí, nikoliv uloženou geometrií.**

Například:

### A. Vnější povrch ostrova

\[
F_{terrain}(x,y,z)=z-H(x,y)
\]

Kde H je tvoje existující funkce reliéfu.

### B. Geologické vrstvy

Každá hranice vrstvy je samostatná funkce:

\[
B_k(x,y)
\]

Například:

\[
F_k(x,y,z)=z-B_k(x,y)
\]

Dvě sousední hranice určují mocnost geologické vrstvy:

\[
T_k(x,y)=B_{k+1}(x,y)-B_k(x,y)
\]

Pokud se vrstva vyklíní, její mocnost postupně klesne k nule.

### C. Jeskyně a dutiny

Jeskyni bych reprezentoval pomocí 3D SDF:

\[
D(x,y,z)
\]

Prostor uvnitř dutiny bude mít zápornou hodnotu, vně kladnou.

Základní princip odečtení dutiny od horniny:

\[
F_{result}=\max(F_{terrain},-D)
\]

Tím vznikne prostor, kde je původní hornina odstraněna.

### D. Žíly a pně

Stejně jako jeskyně mohou být definovány 3D SDF, ale místo odečtení horniny se použijí jako materiálová oblast uvnitř horniny.

Například:

```text
MaterialAt(x, y, z):

    if CaveSDF(x, y, z) < 0:
        return AIR

    if OreVeinSDF(x, y, z) < 0:
        return ORE

    return GeologicalLayerMaterial(x, y, z)
```

Toto je zjednodušený příklad precedence, nikoliv kompletní pravidlo pro všechny materiály.

**Důležitá věc:** geologické vrstvy a jeskyně nemusí mít samostatnou geometrii uloženou v paměti. Jsou to funkce, které se vyhodnocují v požadovaném prostoru.

---

# 4. Jak to vykreslovat v Godotu

Pro samotnou triangulaci bych začal algoritmem Marching Cubes.

<AsyncImageGroup query={["Marching cubes algorithm 3D implicit surface visualization grid isosurface","Marching cubes geological terrain mesh cave cutaway visualization","Dual contouring 3D voxel implicit surface sharp features comparison"]} aspectRatio="5:4"/>

Porovnal bych dva algoritmy:

| Vlastnost | Marching Cubes | Dual Contouring |
|---|---|---|
| Hladké povrchy | Výborné | Dobré |
| Jeskyně | Výborné | Výborné |
| Ostré skalní hrany | Méně přesné | Lepší |
| Složitost implementace | Nižší | Vyšší |
| Vhodnost pro první prototyp | <badge color="success">Doporučuji</badge> | Později |

Pro V1 bych použil Marching Cubes a nekomplikoval první implementaci.

Samotný postup:

1. Vymezíš 3D oblast, například jeden segment 8 × 8 m.
2. Vytvoříš výpočetní mřížku.
3. Na každém bodě vyhodnotíš příslušnou funkci.
4. Najdeš průsečíky nulové hladiny.
5. Vytvoříš trojúhelníky.
6. Vypočítáš normály z gradientu funkce.
7. Výsledek předáš Godot `ArrayMesh`.

Výpočet funkčních hodnot a triangulaci můžeš provádět mimo hlavní renderovací vlákno. Vytvoření a připojení výsledného `Mesh` pak provedeš bezpečně na hlavním vlákně.

## 5. Diagnostický režim – co potřebuješ vidět

Nechtěl bych vytvořit pouze 3D model. Vytvořil bych malý geologický inspektor.

<AsyncImageGroup query={["3D geological strata model colored layers transparent cutaway scientific visualization","3D geological model section plane interactive cross section visualization","3D underground cave system geological visualization cutaway terrain"]} aspectRatio="5:4"/>

Jeho funkce:

- Zobrazit pouze vnější povrch.
- Zobrazit všechny geologické vrstvy.
- Skrýt nebo izolovat konkrétní horninu.
- Zobrazit jeskyně a dutiny.
- Zobrazit žíly a pně.
- Průhlednost jednotlivých vrstev.
- Řez libovolnou rovinou X, Y nebo Z.
- Zobrazit drátěný model triangulace.
- Zobrazit normály povrchů.
- Zobrazit hodnotu SDF v místě kurzoru.
- Zobrazit skutečnou mocnost vrstev.

Zvlášť důležitý je řez. Při pohledu na celý ostrov totiž neodhalíš chyby v geologických hranicích.

# 6. Důležitá architektonická věc: neplést funkci a výpočetní mřížku

Tohle bych chtěl zdůraznit vzhledem k tvému datovému modelu.

Máš rozlišení voxelů 0,25 m. To ale neznamená, že musíš všechny funkce počítat v tomto rozlišení.

Například diagnostický prohlížeč může mít tři režimy:

| Režim | Vzorkování | Použití |
|---|---:|---|
| Preview | 1 m | Rychlá kontrola tvarů |
| Normal | 0,5 m | Kontrola geologie |
| Detail | 0,25 m | Kontrola detailů a dutin |

Výpočetní mřížka je pouze vzorkovací pomůcka pro vytvoření vykreslovací geometrie. Není zdrojem pravdy.

Navíc doporučuji u segmentů používat přesah vzorkovací oblasti (ghost cells), aby nevznikaly mezery mezi sousedními mesh segmenty.

# 7. Jak bych rozdělil implementaci

Nezačínal bych rovnou jeskyněmi. Postupoval bych takto:

<list connector="solid" marker="number" gap={2}>
  <list-item>
    **Funkční povrchy**

    Implementovat rozhraní pro vyhodnocení výškových funkcí a geologických hranic.
  </list-item>
  <list-item>
    **3D Surface Extractor**

    Marching Cubes, normály, triangulace a rozdělení na segmenty.
  </list-item>
  <list-item>
    **Geologický renderer**

    Barevné vrstvy, mocnosti, vyklínění a řezy.
  </list-item>
  <list-item>
    **SDF útvary**

    Žíly, pně, dutiny, kras a jeskyně.
  </list-item>
  <list-item>
    **Terrain Inspector**

    Interaktivní diagnostický nástroj s přepínáním vrstev a měřením.
  </list-item>
  <list-item>
    **Napojení na generátor Willage**

    Použít skutečné funkce z V1.0, nikoliv jejich kopie.
  </list-item>
</list>

## 8. Jedna věc, kterou bych rozhodl už teď

Rozlišoval bych dva typy výsledné geometrie:

- **Boundary Surface:** geometrie hranice mezi dvěma materiály, například vápenec a jílovec.
- **Solid Surface:** hranice mezi pevnou hmotou a prázdným prostorem, například vnější povrch ostrova nebo stěna jeskyně.

Obojí může používat Marching Cubes, ale musí mít odlišná pravidla pro materiály, normály a vykreslování.

To je důležité, protože nechceš, aby vykreslování geologických rozhraní omylem vytvořilo v terénu skutečné díry.

---

**Moje doporučení pro Willage:** funkcionální model ponechat jako jediný zdroj pravdy a vytvořit nad ním univerzální 3D Surface Extractor. Ten později využiješ jak pro diagnostiku, tak pro skutečné vykreslování hry.

Ještě bych dohodl jednu zásadní věc: výsledná triangulace je pouze odvozená geometrie. Neměla by být součástí deterministického datového kontraktu serveru. Server ověřuje funkční hodnoty a materiály, klient si z nich vytvoří mesh.

Dalším krokem bych definoval konkrétní rozhraní `ISurfaceField`, `IGeologyField` a `ISurfaceExtractor` v GDScriptu, včetně toho, jak budou spolupracovat při vykreslování vrstev, jeskyní a vnějšího povrchu.

---

### 10. Uživatel

Ok inspirují se tím. Aktualne je to takto: - Klima: základní klima světa ze seedu (mírné, poušť, step, tundra, ledovec), uvnitř světa ho mírně mění pomalá mapa. Klima je preset z tabulky, který upraví vstupní parametry generátoru (poušť je plošší a má méně vody) a určí, které biomy se vyskytují a s jakou váhou. Uplatní se před reliéfem. Tabulka patří k verzi generátoru, takže její změna znamená novou verzi. Hodnoty presetů zatím nejsou vyladěné. Reliéf a klima jsou dvě nezávislé osy.
- Mapa biomů a mapa hornin: hrubé body ze seedu a plynulá interpolace.
- Reliéf z parametrů biomu (převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu). Když se převýšení pod strop nevejde, tvar se roztáhne do šířky. V přechodech biomů platí vážený průměr stropů. Drobné tvary do ~2 m smí strop překročit.
- Masiv (hora se stěnou a podhůřím) jako součást funkce.
- Sopky: počet a rozteč jsou parametry, polohy ze seedu, tvar mezi strato a štítovou, kráter, vrchol aspoň 5 m pod okrajem sloupce.

---

### 11. Asistent

Teď už je jasnější, jak generátor skutečně funguje. A podle mě je důležité zachovat jeho současnou filozofii: **terén vzniká kombinací několika nezávislých funkčních polí, nikoliv jednou velkou funkcí reliéfu.**

Nechtěl bych současný model překopávat kvůli 3D vykreslování. Spíš bych nad něj přidal vrstvu, která jednotlivé funkce umí vyhodnotit a převést na plochy.

Vidím současnou architekturu takto:

# 1. Rozdělení generátoru na funkční pole

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" padding={3} radius="md" align="center">
    **World Seed + Parameters**
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box border radius="md" padding={2} align="center">
        **Climate Field**
        <text color="secondary" size="xs">Klima světa a lokální změny</text>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align="center">
        **Biome Field**
        <text color="secondary" size="xs">Biomy a jejich váhy</text>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align="center">
        **Rock Field**
        <text color="secondary" size="xs">Mapa hornin</text>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} align="center">
        **Relief Parameters**
        <text color="secondary" size="xs">Převýšení, drsnost, sklon</text>
      </box>
    </grid-item>
  </grid>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(34,197,94,0.10)" padding={3} radius="md" align="center">
    **Terrain Surface Function**

    <text color="secondary" size="xs">Reliéf + masivy + sopky</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(34,197,94,0.10)" padding={3} radius="md" align="center">
    **Height Field H(x,y)**
    <text color="secondary" size="xs">Výsledná výška povrchu</text>
  </box>
</box>

Důležité je, že klima, biom a horniny zůstávají samostatnými datovými poli.

Například poušť nemusí znamenat pouštní reliéf. Pouze upravuje parametry, ze kterých reliéf vzniká.

To je správné oddělení.

# 2. Co bych přidal pro diagnostiku

Každá funkce by měla umět vrátit nejen výslednou hodnotu, ale také svůj příspěvek.

Například u reliéfu:

```text
TerrainEvaluation:
    BaseRelief
    BiomeContribution
    MountainMassifContribution
    VolcanoContribution
    FinalHeight
    Slope
```

Neznamená to, že všechny příspěvky musí být prostý součet. Jde o diagnostické hodnoty jednotlivých operací.

V Godotu bych pak mohl přepínat:

- pouze základní reliéf;
- reliéf včetně biomů;
- reliéf včetně masivů;
- reliéf včetně sopek;
- výsledný povrch.

To ti umožní odhalit, která část generátoru vytváří nežádoucí tvar.

# 3. Jak bych jednotlivé funkce zobrazoval

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="3D procedural terrain heightmap smooth mountainous landscape scientific visualization" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Reliéf H(x,y)**

      Barevná výšková plocha. Možnost zobrazit vrstevnice, sklon a převýšení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D terrain biome regions colored procedural landscape biome map visualization" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Biomy a klima**

      Barevné regiony, plynulé přechody a váhy jednotlivých biomů.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D geological layered terrain cross section colored strata visualization" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Geologie**

      3D plochy hranic vrstev, průběh mocností a vyklínění.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D stratovolcano caldera crater terrain procedural landscape model" aspectRatio="1:1" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **Masivy a sopky**

      Samostatné plochy příspěvků a výsledný složený reliéf.
    </box>
  </row>
</box>

# 4. Jedna důležitá otázka k současnému modelu

U tvého reliéfu je zajímavé pravidlo:

> Když se převýšení pod strop nevejde, tvar se roztáhne do šířky.

To bych chtěl v diagnostickém nástroji zobrazovat zvlášť.

Potřebujeme totiž rozlišovat:
- původní požadovaný tvar;
- tvar upravený kvůli limitu převýšení;
- výsledný tvar po kombinaci s masivy a sopkami.

Jinak bude obtížné zjistit, jestli je výsledná hora skutečně taková, jakou generátor zamýšlel.

# 5. Co navrhuji jako další krok

Než začneme řešit konkrétní Godot třídy, potřebujeme si vyjasnit jednu vlastnost současného generátoru.

**Jak přesně skládáš jednotlivé reliéfní funkce?**

{@body const [model,setModel] = DIL.useState("add")}
{@body const [massif,setMassif] = DIL.useState("integrated")}
<box border radius="lg" padding={3} gap={3}>
  **1. Jak vzniká výsledná výška terénu?**
  <radio-group direction="col" value={model} onChange={setModel}>
    <radio value="add">Sčítáním příspěvků funkcí (základní reliéf + masivy + sopky).</radio>
    <radio value="blend">Plynulým kombinováním funkcí (blending).</radio>
    <radio value="hybrid">Kombinací obou přístupů podle typu útvaru.</radio>
    <radio value="other">Jiným způsobem.</radio>
  </radio-group>
  <divider color="subtle"/>
  **2. Jak je v současnosti reprezentovaný masiv?**
  <radio-group direction="col" value={massif} onChange={setMassif}>
    <radio value="integrated">Je součástí základní funkce reliéfu.</radio>
    <radio value="separate">Má vlastní funkci, která upravuje základní reliéf.</radio>
    <radio value="sdf">Je samostatný 3D útvar (SDF).</radio>
    <radio value="planned">Zatím není implementovaný.</radio>
  </radio-group>
  <button block onClick={()=>GenUI.issueNewTurn("Upřesnění současného generátoru Willage: skládání reliéfu: "+model+"; reprezentace masivu: "+massif+". Navrhni další datový model a diagnostické vykreslování.")}>Potvrdit</button>
</box>

Podle toho můžeme navrhnout diagnostické vykreslování tak, aby odpovídalo skutečné matematice generátoru, a nevyžadovalo její přepis.

---

### 12. Uživatel

Upřesnění současného generátoru Willage: skládání reliéfu: add; reprezentace masivu: separate. Navrhni další datový model a diagnostické vykreslování.

---

### 13. Asistent

Na základě upřesnění bych pro Willage navrhl model, ve kterém je **základní reliéf, masivy a sopky samostatně vyhodnocované funkce, jejichž výsledné příspěvky se skládají aditivně**.

To je dobré rozhodnutí i z hlediska budoucího rozšiřování: každou část můžeš samostatně testovat, vizualizovat a ladit, aniž bys musel měnit ostatní části generátoru.

Navrhuji následující datový model pro generátor V1.0.

# 1. Architektura výpočtu reliéfu

<box border radius="lg" padding={3} gap={3}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Climate Field**

    <text color="secondary" size="xs">Globální klima + lokální klimatická odchylka</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" />
  </box>
  <grid columns={2} gap={2}>
    <grid-item>
      <box background="rgba(16,185,129,0.10)" radius="md" padding={3} align="center">
        **Biome Field**

        <text color="secondary" size="xs">Biome ID + váhy přechodů</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(16,185,129,0.10)" radius="md" padding={3} align="center">
        **Rock Field**

        <text color="secondary" size="xs">Rock ID + váhy hornin</text>
      </box>
    </grid-item>
  </grid>
  <box align="center">
    <icon name="arrow-down" color="secondary" />
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Relief Parameters**

    <text color="secondary" size="xs">Výškové parametry odvozené z biomů a klimatu</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" />
  </box>
  <box border={{size:1,color:"#16A34A"}} radius="md" padding={3} gap={2}>
    **Terrain Components**
    <grid columns={3} gap={2}>
      <grid-item background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        **Base Relief**
        <text size="xs" color="secondary">H₀(x,y)</text>
      </grid-item>
      <grid-item background="rgba(59,130,246,0.10)" radius="md" padding={2}>
        **Massif**
        <text size="xs" color="secondary">Hₘ(x,y)</text>
      </grid-item>
      <grid-item background="rgba(217,119,6,0.10)" radius="md" padding={2}>
        **Volcano**
        <text size="xs" color="secondary">Hᵥ(x,y)</text>
      </grid-item>
    </grid>
    <box align="center">
      <icon name="arrow-down" color="secondary" />
    </box>
    <box background="rgba(16,185,129,0.12)" radius="md" padding={3} align="center">
      **Additive Composition**

      <math value="H(x,y)=H_0(x,y)+H_m(x,y)+H_v(x,y)"/>
    </box>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" />
  </box>
  <box background="rgba(148,163,184,0.12)" radius="md" padding={3} align="center">
    **Final Height Field**

    <text size="xs" color="secondary">Výsledná výška terénu a odvozené vlastnosti</text>
  </box>
</box>

Důležitá vlastnost: každá komponenta musí vracet svůj výsledek nezávisle. Nesmí si sama upravovat výsledek jiné komponenty.

## 2. Datový model

Doporučuji rozdělit data do čtyř skupin.

### A. World Fields

Základní prostorová data světa.

| Datový objekt | Obsah |
|---|---|
| `ClimateSample` | Climate ID, lokální klimatická odchylka |
| `BiomeSample` | Biome ID a váhy zastoupení |
| `RockSample` | Rock ID a váhy zastoupení |
| `ReliefParameters` | Parametry výsledného reliéfu |

`BiomeSample` a `RockSample` by měly podporovat více současných hodnot. Přechod mezi dvěma biomy tedy není skoková změna ID, ale vážená kombinace.

Například:

```text
BiomeSample
    Count: 2
    BiomeA: Mountain
    WeightA: 0.65
    BiomeB: Forest
    WeightB: 0.35
```

### B. Relief Parameters

Toto je důležitá část modelu. Doporučuji ji držet jako samostatný datový objekt, který je výsledkem vyhodnocení klimatu a biomů.

```text
ReliefParameters
    Elevation
    Wavelength
    Roughness
    FlatAreaRatio
    MaxSlope
    SmallFeatureAmplitude
```

Význam:

- `Elevation` – požadované převýšení.
- `Wavelength` – prostorová velikost základních tvarů.
- `Roughness` – členitost povrchu.
- `FlatAreaRatio` – podíl relativně rovných ploch.
- `MaxSlope` – limit sklonu pro hlavní reliéf.
- `SmallFeatureAmplitude` – maximální amplituda drobných tvarů, které mohou limit sklonu překročit.

Je vhodné oddělit parametry před úpravou limitem a po úpravě limitem. Diagnostika pak ukáže, zda generátor skutečně dosáhl požadovaného převýšení.

### C. Terrain Components

Zde jsou tři samostatné komponenty.

**1. BaseRelief**

Základní reliéf odvozený z biomů.

```text
BaseReliefDefinition
    Seed
    Parameters
    NoiseProfile
    HeightOffset
    ElevationScale
```

Výstup:

```text
BaseReliefSample
    RawHeight
    Slope
    Curvature
    AppliedHeight
```

**2. MountainMassif**

Samostatná funkce masivu.

```text
MassifDefinition
    Center
    Radius
    Orientation
    Height
    WallWidth
    FoothillWidth
    WallProfile
    FoothillProfile
```

Výstup:

```text
MassifSample
    Distance
    WallContribution
    FoothillContribution
    TotalContribution
```

Tím zachováš možnost samostatně testovat masiv, jeho stěnu i podhůří.

**3. Volcano**

Sopka je také samostatná komponenta.

```text
VolcanoDefinition
    Center
    Radius
    Height
    ShapeType
    CraterRadius
    CraterDepth
    ProfileParameters
```

`ShapeType` může rozlišovat stratovulkán a štítovou sopku.

Výstup:

```text
VolcanoSample
    Distance
    ConeContribution
    CraterContribution
    FinalContribution
```

U kráteru bych doporučil záporný příspěvek vůči kuželovému profilu, nikoliv samostatnou úpravu výsledné výšky.

### D. Terrain Evaluation

Toto je nejdůležitější diagnostický datový objekt.

Doporučuji, aby generátor uměl vrátit nejen konečnou výšku, ale také všechny mezivýsledky.

```text
TerrainEvaluation
    Position
    Climate
    Biomes
    Rocks
    ReliefParameters

    BaseRelief
    MassifContributions[]
    VolcanoContributions[]

    FinalHeight
    FinalSlope
    FinalCurvature
```

`MassifContributions` a `VolcanoContributions` jsou pole, protože v jednom místě může působit více masivů nebo sopek.

Tento objekt nemusíš vytvářet při každém herním dotazu. Měl by existovat diagnostický režim `EvaluateDetailed()`, zatímco běžný herní režim bude používat optimalizované `EvaluateHeight()`.

---

# 3. Důležitá pravidla pro aditivní skládání

Samotné sčítání je jednoduché, ale potřebuješ definovat několik pravidel.

### Pravidlo 1: Každá komponenta vrací příspěvek

Například:

| Komponenta | Výška |
|---|---:|
| Base Relief | 12 m |
| Massif | +18 m |
| Volcano | +25 m |
| **Final Height** | **55 m** |

Záporné příspěvky jsou povolené, například kráter.

### Pravidlo 2: Příspěvky musí mít definovanou oblast vlivu

Masiv ani sopka nesmí ovlivňovat celý svět, pokud to není záměr.

Každá komponenta proto potřebuje:

- `InfluenceRadius`
- `BoundingRegion`
- `FalloffProfile`

To umožní rychle vyřadit komponenty, které jsou mimo oblast dotazu.

### Pravidlo 3: Výškový strop musí mít jasné pořadí

Doporučuji:

1. Vypočítat základní reliéf.
2. Uplatnit jeho lokální omezení sklonu.
3. Přičíst masivy.
4. Přičíst sopky.
5. Vyhodnotit finální výšku a sklon.

Tím se vyhneš situaci, kdy limit základního biomového reliéfu nechtěně ořízne masiv nebo sopku.

### Pravidlo 4: Hranice sloupce se kontroluje až na výsledku

U sopky zachovej tvé pravidlo, že vrchol musí být minimálně 5 m pod horním okrajem sloupce.

Doporučuji ale zavést i obecnou kontrolu rozsahu výsledného reliéfu. Masiv může být vyšší než základní biom a nesmí způsobit neplatnou geometrii.

---

# 4. Diagnostické vykreslování v Godot 4.7

Pro diagnostiku bych vytvořil samostatnou scénu `TerrainLab.tscn`.

Není to herní renderer. Je to nástroj, který zobrazuje skutečné výsledky generátoru.

<AsyncImageGroup query={["procedural terrain heightfield 3D wireframe visualization scientific terrain analysis","3D terrain procedural noise biome heatmap visualization","procedural mountain terrain heightmap 3D scientific visualization"]} aspectRatio="5:4" layout="bento"/>

## Rozložení TerrainLab

<box border radius="lg" padding={3} gap={3}>
  <row align="center" justify="between">
    **TerrainLab – návrh rozhraní**
    <badge color="success">Diagnostic</badge>
  </row>
  <grid columns={2} gap={2}>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2}>
        <text weight="semibold" size="sm">Viewport</text>
        <AsyncImage query="3D procedural terrain height field shaded wireframe editor viewport" aspectRatio="5:4"/>
        <text color="secondary" size="xs">3D plocha, rotace, zoom, výběr bodu</text>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        <text weight="semibold" size="sm">Component Preview</text>
        <AsyncImage query="3d isolated procedural mountain terrain mesh on plain background" aspectRatio="5:4"/>
        <text color="secondary" size="xs">Samostatné komponenty a jejich příspěvky</text>
      </box>
    </grid-item>
  </grid>
  <divider color="subtle"/>
  **Zobrazované vrstvy**
  <row justify="between">
    <text size="sm">Base Relief</text>
    <badge>ON</badge>
  </row>
  <row justify="between">
    <text size="sm">Mountain Massifs</text>
    <badge>ON</badge>
  </row>
  <row justify="between">
    <text size="sm">Volcanoes</text>
    <badge>ON</badge>
  </row>
  <row justify="between">
    <text size="sm">Final Terrain</text>
    <badge>ON</badge>
  </row>
  <divider color="subtle"/>
  **Inspector**
  <text color="secondary" size="xs">Vybraný bod X/Y → výška, sklon, biome weights, příspěvky komponent.</text>
</box>

## 5. Režimy vykreslování

Rozdělil bych je na tři skupiny.

### A. Component View – jednotlivé funkce

<grid columns={2} gap={3}>
  <grid-item>
    <AsyncImage query="3D procedural rolling terrain height field isolated green shaded surface" aspectRatio="5:4"/>
    **Base Relief**
    <text size="xs" color="secondary">Pouze základní reliéf.</text>
  </grid-item>
  <grid-item>
    <AsyncImage query="isolated 3D mountain massif with steep cliff and foothills terrain model" aspectRatio="5:4"/>
    **Massif**
    <text size="xs" color="secondary">Masiv, stěna a podhůří.</text>
  </grid-item>
  <grid-item>
    <AsyncImage query="isolated 3D stratovolcano crater terrain model" aspectRatio="5:4"/>
    **Volcano**
    <text size="xs" color="secondary">Kužel, kráter a výška.</text>
  </grid-item>
  <grid-item>
    <AsyncImage query="3D procedural terrain mountains shaded elevation mesh" aspectRatio="5:4"/>
    **Final Terrain**
    <text size="xs" color="secondary">Výsledné složení všech příspěvků.</text>
  </grid-item>
</grid>

### B. Analysis View – analytické vrstvy

| Režim | Co kontroluje |
|---|---|
| Height Map | Výškové rozložení |
| Slope Map | Sklon terénu |
| Curvature Map | Konvexní a konkávní tvary |
| Biome Map | Rozložení biomů |
| Biome Weights | Plynulost přechodů |
| Climate Map | Klimatické regiony |
| Component Contribution | Výškový příspěvek každé komponenty |
| Influence Map | Oblasti vlivu masivů a sopek |

Zvlášť důležitá je `Component Contribution`. Měla by umět zobrazit například masiv jako samostatnou barevnou výškovou plochu. Díky tomu poznáš, jestli masiv opravdu přidává zamýšlený tvar, nebo pouze deformuje okolní reliéf.

### C. Inspection View – detailní kontrola bodu

Po kliknutí do plochy zobrazit například:

```text
Position:
    X: 125.00 m
    Y: 248.00 m

Climate:
    Temperate

Biomes:
    Mountain: 0.72
    Forest:   0.28

Base Relief:
    Height:  12.40 m
    Slope:   18.20°

Massifs:
    Massif #02: +14.20 m

Volcanoes:
    Volcano #01: +0.00 m

Final:
    Height: 26.60 m
    Slope:  32.10°
```

Takový inspektor je velmi užitečný při ladění hranic biomů a překryvů komponent.

---

# 6. Technická implementace v Godot 4.7

Doporučená struktura souborů:

```text
TerrainGenerator/
│
├── Core/
│   ├── TerrainGenerator.gd
│   ├── TerrainEvaluation.gd
│   └── TerrainParameters.gd
│
├── Fields/
│   ├── ClimateField.gd
│   ├── BiomeField.gd
│   └── RockField.gd
│
├── Relief/
│   ├── ReliefParameterResolver.gd
│   ├── BaseRelief.gd
│   ├── MountainMassif.gd
│   └── Volcano.gd
│
├── Diagnostics/
│   ├── TerrainLab.tscn
│   ├── TerrainLab.gd
│   ├── TerrainMeshBuilder.gd
│   ├── TerrainMaterialBuilder.gd
│   ├── TerrainInspector.gd
│   └── TerrainDebugSettings.gd
│
└── Tests/
    ├── TerrainDeterminismTests.gd
    ├── TerrainBoundaryTests.gd
    └── TerrainComponentTests.gd
```

### Vykreslovací pipeline

Pro diagnostický 3D povrch bych použil:

- `ArrayMesh` pro tvorbu geometrie.
- `SurfaceTool` pouze pro prototypování; později přímé plnění `ArrayMesh`.
- `MeshInstance3D` pro zobrazení jednotlivých komponent.
- `ShaderMaterial` pro výškové barvy, sklony a diagnostické heatmapy.
- `Camera3D` + `DirectionalLight3D` pro standardní 3D inspekci.

Vzorkovací krok:

| Režim | Rozestup vzorků | Použití |
|---|---:|---|
| Preview | 2 m | Rychlé zobrazení celého regionu |
| Normal | 1 m | Běžné ladění |
| Detail | 0,5 m | Kontrola drobných tvarů |
| Voxel | 0,25 m | Kontrola proti hernímu rozlišení |

Vzorkování je pouze pro tvorbu diagnostické geometrie. Nesmí změnit samotnou funkci terénu.

**Důležité:** komponenty vykresluj jako samostatné mesh objekty, ale výsledný terén počítej vždy ze stejné společné evaluation funkce. Jinak by se ti diagnostika mohla rozcházet s herním výsledkem.

---

# 7. Co bych doplnil před implementací

Jsou zde tři věci, které bych chtěl mít vyřešené před definitivním uzavřením datového modelu:

1. **Pořadí a překryv masivů:** pokud se překrývají dva masivy, jejich výšky se prostě sečtou? Nebo se má jejich společný prostor nějak omezit?
2. **Pořadí a překryv sopek:** mohou být sopky součástí masivu, nebo se jejich příspěvky vždy přičítají nezávisle?
3. **Výšková normalizace:** je `Elevation` biomu požadované převýšení základního reliéfu, nebo maximální výška výsledného terénu včetně masivů a sopek?

Moje doporučení pro V1.0 je zachovat čisté sčítání všech komponent a nepřidávat zatím automatické ořezávání jejich překryvů. Ořezávání by mohlo komplikovat determinismus i ladění.

**Navrhuji jako další krok uzavřít pravidla překryvů a výškových limitů.** Potom můžeme definitivně specifikovat datové struktury a rozhraní `EvaluateHeight()` / `EvaluateDetailed()` pro GDScript, aby šly později beze změny konceptu přenést do C#.

---

### 14. Uživatel

Zde je zatím plán v aktuálním stavu: # Datový model generátoru V1.0 – přehled pro diskuzi (2026-11-23)

Projekt Willage: hra s plovoucími ostrovy (Godot 4.7, GDScript; server později v C#, který musí generátor zopakovat bitově stejně). Jen datový model procedurálního generátoru terénu V1.0, bez vykreslování.

## Stav implementace (po krocích, každý schvaluje Jan zvlášť)
- Krok 1 (základy) a krok 2 (funkce světa I) jsou hotové a schválené.
- Krok 3 (geologie) je hotový a čeká na schválení.
- Kroky 4–11 jsou naplánované. Část kódu z nich existuje ve studiích a prototypu, ale ne v novém modelu.

## Hierarchie a rozměry [hotovo, krok 1]
Svět → blueprint → ostrov → blok → segment → buňka.
- Svět je deterministická funkce ze seedu na ploše max 4096 × 4096 m. Neukládá se, jen se z ní čte.
- Blok má 128 × 128 m, segment 8 m (parametr 8/16/32), buňka (voxel) 0,25 m.
- Výška sloupce je výčet 32/64/128 m (výchozí 128 m = 512 buněk), neutrální úroveň je v polovině. Rozměry musí být mocniny 2 a navzájem dělitelné.
- Jednotky jsou metry, voda je v litrech s jedním převodem na m³.
- Verze generátoru má tvar Vmajor.minor (teď V1.0) a ukládá se ke každému ostrovu.
- Determinismus je povinný: stejný seed, parametry a verze dají bitově stejný svět (float64, řazené klíče, celočíselné hashe).
- Jedna tabulka materiálů: 78 id, 1 B na buňku. U každého materiálu je mj. propustnost.
- Odloženo: jak naložit s už hranými ostrovy, když se verze generátoru změní.

## Funkce světa
Rozhraní: dotaz na bod (x, y, z) vrátí materiál, dotaz na sloupec (x, y) vrátí povrch, hranice vrstev a hladinu.

### Krok 2 [hotovo]
- Klima: základní klima světa ze seedu (mírné, poušť, step, tundra, ledovec), uvnitř světa ho mírně mění pomalá mapa. Klima je preset z tabulky, který upraví vstupní parametry generátoru (poušť je plošší a má méně vody) a určí, které biomy se vyskytují a s jakou váhou. Uplatní se před reliéfem. Tabulka patří k verzi generátoru, takže její změna znamená novou verzi. Hodnoty presetů zatím nejsou vyladěné. Reliéf a klima jsou dvě nezávislé osy.
- Mapa biomů a mapa hornin: hrubé body ze seedu a plynulá interpolace.
- Reliéf z parametrů biomu (převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu). Když se převýšení pod strop nevejde, tvar se roztáhne do šířky. V přechodech biomů platí vážený průměr stropů. Drobné tvary do ~2 m smí strop překročit.
- Masiv (hora se stěnou a podhůřím) jako součást funkce.
- Sopky: počet a rozteč jsou parametry, polohy ze seedu, tvar mezi strato a štítovou, kráter, vrchol aspoň 5 m pod okrajem sloupce.

### Krok 3 [hotovo, čeká na schválení]
- Geologie: pásma vrstev z pořadí hornin, 1–3 zástupci podle mapy hornin. Vrstvy kopírují terén a vyklíňují, mocnost je min. 0,25 m a max. 1/4 výšky.
- Útvary (žíly, pně, skarny, dómy, kras, dutiny, minerály) jsou SDF z hashe světové mřížky, takže jsou spojité přes švy bloků (ověřeno 0 rozdílů).
- Vápenec a dolomit 50/50 až 2 m pod hladinou, nad tím vyklínění jílu.
- Sopka uvnitř: průduch od kráteru dolů, slupky lávy a popela.
- Otevřené: navázat vápenec na skutečnou hladinu z kroku 4? Vlastní id pro lávu a popel? Výkon (segment 2,6 s, návrhy na zrychlení zapsané).

### Krok 4 [plán]
- Hladina podzemní vody a propustnost jako funkce geologie, bez uložených buněk.
- Prameny ze seedu (druh, poloha, jmenovitý výkon), skutečný výkon omezí okolí. Artéská voda jen na ověření.

## Ostrov [plán, krok 5]
- Ostrov = seed + parametry + verze + seznam vložení v pořadí.
- Vložení (objekty Source, Transform, Placement) nese souřadnice blueprintu ve světě, otočení o 90°, zrcadlení, výškový posun, režim napojení a seed a verzi zdrojového světa. Blueprint může být i z jiného světa.
- Dotaz na vložený blok se inverzní transformací přepočte do souřadnic zdroje.
- Napojení bloků jen po stranách (rohy se neřeší). Režim Auto: rozdíl do 6 buněk se vyrovná rampou na 3 buňkách, větší rozdíl udělá útes. Dále Blend (povrch rampa 1–4 buňky, podzemní vrstvy klín 1/16 bloku) a Keep. Sousedé se při vložení nemění.

## Buňky a ukládání [plán, krok 6]
- Buňky se generují jen v zorném poli plus okraji, a jen jako slupka 2–3 buněk u vzduchu nebo pod průhlednou vodou. Hlubší se donačtou při odkrytí.
- Kopání po 0,25 m. Dno a okraj ostrova se prokopat nedají.
- Ukládá se jen rozdíl proti funkci, po segmentech (klíče + deflate, hlavička s verzí, transformací a pořadím).
- Připravené, ale vypnuté pole „původní materiál“ (+1 B na změněnou buňku) pro kontrolu na serveru.

## Voda na ostrově [plán, krok 7; jednotlivé části existují ve studiích]
- Simulace povrchu i podzemí: vsakování, boční tok podle spádu, prameny, kras.
- Eroze je samostatná vrstva posunu výšky nad funkcí, kladná (usazování) i záporná, nemění buňky. Ověří se, zda stejný offset stačí i pro krasové dutiny.
- Přepočet po výkopu běží asynchronně na sjednoceném povodí (prodleva 2 s, strop 10 s, fronta výkopů).
- Drobné výtoky pod 0,1 l/s se slučují v dosahu 8 m.
- Výchozí voda je ustálený stav po vygenerování. Ukládá se jen odchylka v krocích 1/16 l, 1 B na buňku (0–15,625 l).
- Čas: 1 herní den = 1 h.

## Další kroky [plán]
- Krok 8: povrchové jevy klimatu po vodě (písek, led, sníh, výpar, zamrzání). Prahy zatím otevřené.
- Krok 9: vegetace jako funkce seedu, materiálu, sklonu a výchozí vody, hustota na m², v tůních nic. Ukládají se jen změny (kácení, výsadba, růst).
- Krok 10: povinný test. Svět 3 × 3 bloky se rozřeže na 9 blueprintů a složí do ostrova (náhodné pořadí, otočení, zrcadlení, aspoň jeden blueprint z jiného světa). Měří se determinismus, paměť, časy a velikost rozdílu. Pak se uzavře V1.0.
- Krok 11: kontrakt se serverem. Server ukládá seed, parametry, verzi, seznam vložení a rozdíl a namátkově to ověřuje generátorem (dá se vypnout). Ověřené změny se ukládají do zásobníku. Testovací vektory zajistí stejný hash v GDScriptu i C#.

## Otázky k diskuzi
Je tenhle model (funkce světa + ukládání jen rozdílu + vkládání blueprintů s transformací) rozumný? Kde jsou rizika pro determinismus mezi GDScriptem a C#, pro velikost ukládaných dat a pro výkon funkce světa (dotaz po sloupcích ze seedu je pomalý)? A jak dobře spolu fungují eroze jako vrstva posunu a uložený rozdíl buněk?

---

### 15. Asistent (shrnutí uvažování)

Přemýšlel po dobu 5s

---

### 16. Asistent

Tento přehled budu považovat za aktuální pracovní specifikaci generátoru Willage V1.0. Je důležité, že už rozlišuješ hotové a schválené části od těch, které jsou pouze naplánované. Nebudu tedy považovat existující prototypy kroků 4–11 za součást nového datového modelu.

Celkově považuji zvolený princip za správný. **Funkční svět jako zdroj pravdy, blueprinty jako transformované výřezy světa a ukládání pouze odchylek** je vhodná architektura pro rozsáhlý procedurální svět. Má ale několik míst, která bych před uzavřením V1.0 zpřesnil.

# 1. Celkové hodnocení architektury

<badge color="success">Zachovat</badge> Základní koncepci bych neměnil.

| Oblast | Hodnocení | Hlavní riziko |
|---|---|---|
| Funkční svět ze seedu | Velmi dobrý základ | Výpočetní náročnost |
| Hierarchie bloků a segmentů | Dobrá | Hranice a vlastnictví buněk |
| Geologie pomocí SDF | Dobrá | Výkon a deterministická numerika |
| Blueprinty s transformací | Velmi dobrý princip | Identita zdrojového světa |
| Ukládání rozdílů | Velmi dobrý princip | Správné pořadí vrstev |
| Generování buněk na vyžádání | Vhodné | Opakované výpočty |
| Eroze jako samostatná vrstva | Správný směr | Interakce s geologií a editacemi |
| Determinismus GDScript/C# | Nedostatečně specifikovaný | Bitová shoda |

Největší architektonické riziko podle mě není samotná procedurální funkce. Je to **pořadí, ve kterém se skládají jednotlivé vrstvy výsledného terénu a ukládají změny**.

Proto bych před implementací dalších kroků zavedl následující společný model.

# 2. Doporučený model výsledného terénu

Dnes máš několik různých zdrojů dat:

- Funkční svět.
- Vložené blueprinty.
- Geologické útvary.
- Erozi a usazování.
- Změny provedené hráčem.
- Dynamický stav vody a dalších systémů.

Nedoporučuji je sloučit do jednoho pole buněk. Každá vrstva má jiný životní cyklus, jiný způsob výpočtu a jiné požadavky na ukládání.

Navrhuji tuto logickou hierarchii:

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **1. World Definition**

    <text color="secondary" size="xs">Seed, parametry, verze generátoru, tabulky</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **2. Procedural World Function**

    <text color="secondary" size="xs">Klima, biomy, reliéf, masivy, sopky, geologie</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **3. Island Composition**

    <text color="secondary" size="xs">Blueprinty, Source, Transform, Placement, napojení</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box border={{size:1,color:"#16A34A"}} radius="md" padding={3} gap={2}>
    **4. Island State**
    <grid columns={2} gap={2}>
      <grid-item background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        **Terrain Override**
        <text color="secondary" size="xs">Kopání, změna materiálu</text>
      </grid-item>
      <grid-item background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        **Terrain Deformation**
        <text color="secondary" size="xs">Eroze, usazování</text>
      </grid-item>
      <grid-item background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        **Water State**
        <text color="secondary" size="xs">Odchylky vody</text>
      </grid-item>
      <grid-item background="rgba(16,185,129,0.10)" radius="md" padding={2}>
        **Environmental State**
        <text color="secondary" size="xs">Sníh, led, vegetace</text>
      </grid-item>
    </grid>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(16,185,129,0.12)" radius="md" padding={3} align="center">
    **5. Effective Terrain Query**

    <text color="secondary" size="xs">Výsledný materiál, povrch, hranice vrstev a stav vody</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="rgba(148,163,184,0.12)" radius="md" padding={3} align="center">
    **6. Persistence & Validation**

    <text color="secondary" size="xs">Ukládání rozdílů, komprese, serverová kontrola</text>
  </box>
</box>

Toto pořadí je zatím logické, ne definitivní výpočetní kontrakt. Zejména pořadí eroze a hráčských změn musíš ještě přesně rozhodnout.

## 3. Determinismus mezi GDScript a C#

Tady bych byl nejpřísnější.

Tvoje současná specifikace říká:

> float64, řazené klíče, celočíselné hashe.

To je dobrý začátek, ale nestačí to pro garantovanou bitovou shodu.

### Proč float64 nestačí

GDScript a C# mohou při stejném matematickém výrazu dospět k rozdílnému výsledku. Rizikové jsou především:

- `sin`, `cos`, `pow`, `sqrt`.
- Odlišné pořadí operací.
- Fused multiply-add.
- Převody mezi integer a floating-point.
- Zaokrouhlování na hranicích buněk.
- Interpolace a normalizace.
- Pořadí iterace kolekcí.

Rozdíl může být extrémně malý, ale pokud ovlivní hranici materiálu nebo výběr útvaru, může se rozšířit dál.

### Doporučené řešení: Hybrid Determinism

| Oblast | Reprezentace |
|---|---|
| Světové souřadnice | Integer |
| Souřadnice buněk | Integer |
| Otočení a zrcadlení | Integer transformace |
| Seed a hash | Integer |
| Výběr materiálu | Integer |
| Výběr útvarů | Integer |
| Mezivýpočty funkcí | Float64 |
| Výška a geometrické hranice | Kvantizovaný integer |
| Ukládání | Integer |

Jako výchozí kvantizaci výšky bych zvolil:

\[
Q=4096\ \text{jednotek/m}
\]

Tedy:

\[
1Q=\frac{1}{4096}\text{ m}
\]

Jeden voxel o velikosti 0,25 m pak obsahuje přesně 1024 kvantizačních jednotek.

To je dostatečně jemné pro geologické i výškové výpočty.

**Důležitější než samotná přesnost je ale definice pravidel kvantizace.** Musí být přesně určeno, kdy se kvantizuje, jak se zaokrouhluje a jak se zachází se zápornými hodnotami.

Dále bych zavedl:

- `DeterminismProfile`
- `CoordinateSystemVersion`
- `MaterialTableVersion`
- `ParametersHash`

Tyto hodnoty bych zahrnul do identity vygenerovaného světa.

# 4. Výkon: dotaz na sloupec ze seedu

Tohle je pravděpodobně největší praktický problém při generování.

Představ si, že potřebuješ vytvořit jeden segment:

- 8 × 8 m.
- 0,25 m buňky.
- 32 × 32 sloupců.
- 512 výškových buněk.

To znamená 1024 sloupců a až 524 288 buněk.

Pokud budeš při každém dotazu na materiál znovu počítat klima, biom, reliéf, geologii a SDF útvary, bude to velmi drahé.

### Doporučuji tři úrovně cache

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    **L1 – World Field Cache**
    <badge color="success">Dlouhá životnost</badge>
    <text color="secondary" size="sm">Klima, biomové váhy, mapa hornin a základní parametry reliéfu.</text>
    <text color="secondary" size="xs">Cache po prostorových dlaždicích.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **L2 – Column Cache**
    <badge color="success">Vysoká priorita</badge>
    <text color="secondary" size="sm">Výška povrchu, hranice geologických vrstev, podzemní voda.</text>
    <text color="secondary" size="xs">Cache po sloupcích nebo skupinách sloupců.</text>
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    **L3 – Feature Cache**
    <badge color="success">Podle potřeby</badge>
    <text color="secondary" size="sm">SDF žil, pňů, krasu, dutin, masivů a sopek.</text>
    <text color="secondary" size="xs">Cache podle prostorové oblasti a identifikátoru útvaru.</text>
  </box>
</box>

Zásadní pravidlo: cache nesmí být zdrojem pravdy. Musí být pouze memoizací výsledků funkce.

To znamená, že:

- Výsledek nesmí záviset na pořadí dotazů.
- Vymazání cache nesmí změnit svět.
- Výpočet segmentu musí být možný bez předchozího výpočtu sousedního segmentu.
- Cache nesmí používat náhodné pořadí jako vstup do výpočtu.

### Ještě jedno důležité doporučení

Nedělal bych pouze `EvaluateColumn(x, y)`.

Přidal bych také:

```text
EvaluateRegion(bounds, resolution)
EvaluateSegment(segment_id)
EvaluateColumn(x, y)
EvaluatePoint(x, y, z)
```

Vnitřní implementace by měla podporovat dávkové vyhodnocení.

Pro generátor je totiž výhodnější spočítat celou oblast najednou než opakovaně vyhodnocovat jednotlivé sloupce.

# 5. Blueprinty a transformace

Tvoje řešení je dobré, ale doplnil bych identitu zdroje.

Blueprint z jiného světa nemůže být identifikován jen seedem. Potřebuje také identitu všech pravidel, podle kterých vznikl.

Doporučená struktura:

```text
Source
    WorldSeed
    GeneratorVersion
    ParametersHash
    MaterialTableVersion
    CoordinateSystemVersion
    DeterminismProfile

Transform
    Rotation90
    MirrorX
    MirrorY
    HeightOffset

Placement
    WorldPosition
    ConnectionMode
    PlacementOrder
```

### Proč je to důležité?

Představ si, že hráč vloží blueprint vytvořený v generátoru V1.0 do ostrova V1.1.

Pokud se změnila tabulka biomů nebo geologických vrstev, nestačí znát původní seed. Musíš přesně vědět, podle jakých pravidel zdrojový blueprint vznikl.

Tím se zároveň otevírá cesta k budoucí podpoře starších blueprintů bez nutnosti okamžitě řešit migraci všech ostrovů.

### Transformace

Doporučuji provádět všechny prostorové transformace v celočíselných voxelových souřadnicích.

Rotace o 90° a zrcadlení jsou přesné operace. Nepotřebuješ `sin` ani `cos`.

Ještě bych výslovně definoval pořadí:

1. Zrcadlení.
2. Rotace.
3. Přičtení pozice.
4. Výškový posun.

A toto pořadí už nikdy neměnit bez změny `CoordinateSystemVersion`.

# 6. Eroze jako vrstva posunu

Tohle je podle mě jedno z nejlepších rozhodnutí v současném návrhu.

Eroze by neměla měnit původní funkci světa ani přepisovat geologické vrstvy.

Základní princip:

\[
H_{\text{effective}}(x,y)
=
H_{\text{base}}(x,y)+E(x,y)
\]

Kde:

- \(H_{\text{base}}\) je původní výška.
- \(E\) je uložená deformace způsobená erozí a usazováním.

Ale je potřeba rozlišit dva případy.

### A. Eroze a odkrytí vrstev

<AsyncImage query="geological terrain erosion exposed sedimentary rock strata cross section natural cliff" aspectRatio="16:9" width="100%"/>

Při erozi se povrch sníží a objeví se původní geologická vrstva.

To funguje velmi dobře s tvým funkčním modelem geologie.

### B. Usazování materiálu

<AsyncImage query="river sediment deposition layered sediment terrain cross section geological illustration" aspectRatio="16:9" width="100%"/>

Tady už samotný výškový offset nemusí stačit.

Pokud voda usadí písek nebo sediment, musíš vědět, jaký materiál novou vrstvu tvoří. Jinak bude mít terén správnou výšku, ale špatný materiál.

Proto bych rozlišil:

```text
TerrainDeformation
    HeightOffset
```

a případně v budoucnu:

```text
SedimentLayer
    MaterialId
    Thickness
    Source
```

Pro V1.0 bych sedimentovou vrstvu zatím nedělal, pokud ti stačí modelovat usazování jako změnu povrchového offsetu. Ale nenechal bych datový model předpokládat, že všechny kladné deformace jsou automaticky původní hornina.

### Co s jeskyněmi?

Dvourozměrný offset \(E(x,y)\) mění pouze povrchovou hranici. Nezmění geometrii všech podzemních dutin.

To může být v pořádku, pokud eroze pouze odkrývá existující dutiny. Pokud by měla měnit i stropy jeskyní, budeš potřebovat další 3D deformační reprezentaci.

To bych pro V1.0 nechal jako samostatnou otázku.

# 7. Ukládání rozdílů buněk

Tady bych zachoval tvůj návrh, ale zavedl bych tři explicitní stavy.

| Stav | Význam |
|---|---|
| Inherit | Použít původní funkci |
| Air | Buňka je explicitně prázdná |
| MaterialOverride | Použít jiný materiál |

To je zásadní. Prázdná buňka nesmí být zaměnitelná s buňkou, pro kterou není uložen žádný rozdíl.

Doporučená logika:

```text
GetEffectiveMaterial(position):

    delta = GetTerrainOverride(position)

    if delta == Air:
        return Air

    if delta == MaterialOverride:
        return delta.MaterialId

    return GetProceduralMaterial(position)
```

Eroze by se vyhodnocovala v samostatné vrstvě a nesměla by být omylem interpretována jako hráčský override.

## Pozor na velikost dat

Pro jeden segment 8 × 8 m máš:

- 32 × 32 sloupců.
- 512 buněk výšky.
- 524 288 buněk celkem.
- 512 KiB plného materiálového pole.

Při ukládání pouze změn je to velmi výhodné, ale nedoporučuji se předem zavázat k jediné kompresní reprezentaci.

Navrhl bych tři varianty podle hustoty změn:

| Hustota změn | Reprezentace |
|---|---|
| Nízká | Sparse seznam změněných buněk |
| Střední | Bitset + pole materiálů |
| Vysoká | Dense pole + komprese |

Volba reprezentace může být interní optimalizace. Logický obsah dat musí zůstat stejný.

### Jedna drobná matematická kontrola vody

Objem jedné buňky při velikosti 0,25 m je:

\[
0{,}25^3=0{,}015625\ m^3=15{,}625\ l
\]

Při kroku 1/16 litru odpovídá maximální objem hodnotě 250.

To se do jednoho bajtu vejde, ale pouze hodnoty 0–250 reprezentují validní rozsah. Hodnoty 251–255 bych rezervoval, nebo bych definoval jiné chování.

Zároveň bych v budoucím modelu oddělil vodu povrchovou, volnou podzemní a vodu vázanou v pórech. Nemusí mít stejnou kapacitu ani stejná pravidla aktualizace.

# 8. Co bych před uzavřením V1.0 ještě doplnil

Nevidím důvod měnit základní návrh. Vidím ale šest rozhodnutí, která bych chtěl mít explicitně v dokumentaci.

| Priorita | Rozhodnutí | Proč |
|---|---|---|
| Kritická | Determinism Profile | GDScript/C# bitová shoda |
| Kritická | Pořadí vrstev | Správné skládání terénu |
| Vysoká | Identita zdrojového světa | Blueprinty z jiných světů |
| Vysoká | Hranice segmentů | Žádné mezery ani rozdíly |
| Vysoká | Reprezentace deformace | Eroze vs. hráčské změny |
| Střední | Adaptivní ukládání rozdílů | Velikost persistence |

---

# 9. Doporučené pořadí další práce

Vzhledem k tomu, že chceš jednotlivé kroky samostatně schvalovat, nedoporučuji teď přeskakovat k implementaci cache, vody nebo ukládání.

Navrhuji nejdříve uzavřít samotný kontrakt funkce světa.

<list connector="solid" marker="number" gap={2}>
  <list-item>
    **Dokončit schválení kroku 3 – Geologie**

    Rozhodnout vápenec, dolomit a materiálová ID lávy a popela.
  </list-item>
  <list-item>
    **Krok 4 – Podzemní voda**

    Definovat vztah mezi geologií, propustností a hladinou.
  </list-item>
  <list-item>
    **Datový kontrakt generátoru**

    Přesně definovat vstupy, výstupy, kvantizaci, pořadí výpočtu a determinismus.
  </list-item>
  <list-item>
    **Krok 5 – Ostrov a blueprinty**

    Uzavřít transformace, identitu zdroje a napojování.
  </list-item>
  <list-item>
    **Krok 6 – Ukládání**

    Definovat override, deformaci a persistence.
  </list-item>
  <list-item>
    **Krok 7 – Voda a eroze**

    Teprve zde řešit dynamický stav a přepočty.
  </list-item>
</list>

**Můj hlavní závěr:** architektura je dostatečně dobrá na to, aby se na ní dalo stavět. Největší přínos teď nebude v přidávání dalších funkcí, ale v přesném definování kontraktu mezi jednotlivými vrstvami. Tím zabráníš tomu, aby se později GDScriptová implementace a serverová C# implementace postupně rozešly.

Jako nejbližší konkrétní krok bych navrhl uzavřít **datový kontrakt `World Function → Island Composition → Effective Terrain`**, ještě před přechodem na vodu.

---

### 17. Uživatel

Dám ti další kontext, jsou to ale materiály které byli vytvořený před textem který jsi před chvílí dostal, takže můžou být zastaralé nebo v rozporu s aktuálním návrhem. Přečteš dokumenty zde v repu ? https://github.com/Utalag/Willage_Client/tree/sjednoceni/docs%2Fsjednoceni

---

### 18. Asistent

The output of this plugin was redacted.

---

### 19. Asistent

The output of this plugin was redacted.

---

### 20. Asistent

The output of this plugin was redacted.

---

### 21. Asistent (shrnutí uvažování)

Přemýšlel po dobu 16s

---

### 22. Asistent

Ano. Dokážu projít dokumentaci v repozitáři, porovnat ji s aktuálním návrhem V1.0 a označit zastaralé nebo rozporné části.

Zkusil jsem otevřít přímo:

[Willage_Client – docs/sjednoceni, větev sjednoceni](https://github.com/Utalag/Willage_Client/tree/sjednoceni/docs%2Fsjednoceni)

Narazil jsem ale na problém: GitHub mi vrací `404 Not Found` a webový přístup k této stránce je omezený. Zatím tedy nemám obsah dokumentů k dispozici. Může jít o soukromý repozitář nebo omezení přístupu propojeného GitHub účtu.

**Nejjednodušší řešení:** nahraj sem ZIP složky `docs/sjednoceni`, případně jednotlivé dokumenty.

Až je budu mít, zpracuji je takto:

1. **Inventář dokumentů** – co který dokument popisuje.
2. **Porovnání s aktuálním modelem** – co stále platí.
3. **Zastaralé návrhy** – co už neodpovídá současnému stavu.
4. **Konflikty** – konkrétní rozpory mezi dokumenty a aktuální specifikací.
5. **Chybějící rozhodnutí** – témata, která ještě nejsou uzavřená.

Nebudu automaticky přebírat starší návrhy do nové architektury. Aktuální specifikace z 23. 11. 2026 zůstane výchozím bodem a starší dokumenty použijeme jako historický a technický kontext.

---

### 23. Uživatel

# 00 – Mapa větví a studií (stav 2026-11-20 14:10 SEČ)

Podklad pro sjednocení (Jan 2026-11-20 14:08: „Budeme teď sepisovat aktuálně finální stav… napříč větvemi vybrat nejvhodnější řešení“). Tento soubor nic nerozhoduje. Jen popisuje, co kde je, co bylo naměřeno a kde si větve odporují. Rozhodnutí se dělají v chatu s Janem a pak se zapíšou do kapitol (`01-…`).

Zdroje: `git branch -r`, `git tag`, `TODO.md` (main 0e8aa00), `blueprint-studie/PROP.md` a `DENIK.md` na jednotlivých větvích, `navrhy/`, `sdilene/`, `devlog/`. Značky [n] odkazují na seznam na konci.

Zkratky: **vých.** = výchozí stav přepínače, **zap/vyp**, **SEČ** = středoevropský čas. „Kontrola výchozí hry“ = `voda_e66` d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod, a `port_studie --check` 0 změn. Tou prošly všechny větve E78–E96.

## 1. Strom větví

```
main 0e8aa00 ─┬─ (sloučeno) E52–E77 voda, tezba-studie, e66*, e67, refaktor-uzly (obsah přes E66)
              │
 380cccf ─────┴─ e78 → e79 → e80 → e81 → e82 → e83 ─┬─ e84 (jen nástroj + rešerše)
                                                     └─ e85 (+ main 57c7dfb)
 57c7dfb ─────── e86, e87, e88 (každá zvlášť)
 8d4d809 ─────── e89, e90, e91, e92, e93 (každá zvlášť)
 0e8aa00 ─┬───── e94-metry (= e89 + převod) ── e96-blok128
          ├───── e95-async-voda (samostatně, bez e94)
          └───── zkusebni-vse (= e85 + e84 + e86 + e87 + e89–e94, BEZ e95 a e96)
```

- Nic z E78–E96 není v main. Merge-base je ve třech generacích (380cccf, 57c7dfb/8d4d809, 0e8aa00).
- `e96` nemá `e95` a `e95` nemá `e94`. Asynchronní voda a blok 128 m tedy zatím nikdy neběžely spolu.
- `zkusebni-vse` je jediné místo, kde jsou E78–E94 pohromadě. Nemá ale E95 ani E96. **Pozor na jména:** její plán i výsledky jsou v PROP zapsané jako „E95“ a snímky jsou v `shots/e95/`. Číslo E95 má přitom i asynchronní voda na `e95-async-voda`. Při sloučení je potřeba jedno přečíslovat (navrhuju zkušební větev = „Z1“).

## 2. Voda E52–E77 (v main)

| Pokus | Co řeší | Přepínače (vých.) | Klíčová čísla | Stav |
|---|---|---|---|---|
| E52–E58 | varianty podzemí (buňky, pole, pásma z funkcí, Darcy), algoritmy A/B/C | `p52_*`, `p58_var` base | E58 „pásma z funkcí“ = výchozí podzemí hry [1] | v main |
| E59–E61 | materiály podle skutečných K, n, Sy | tabulka v4 | perm = (log10 K + 9)/6 [2] | v main |
| E62–E64 | graf těles, lokální oprava přelivu, kanonický sestup | `p64_budget` 5000 | lokální = plný v testech [1] | v main |
| E66–E67 | integrace do prototypu; podzemí vytéká z okrajů (režim `pretok`) | `p67_rezim` "" (= E58), `p67_okraj` vyp | E67 je jen alternativa, výchozí zůstává E58 [3] | v main |
| E68 | orchestrátor povrch + podzemí, jedna bilance, otisk | `p68_hydro` zap, max 64 kol | smyčka tůň→pramen chyba 61 % → 0 [4] | v main |
| E69–E73 | symetrie, harmonický průměr, kapacita dolů, slučování výstupů, nálezy | `p69_remizy` zap, `p70_prumer` „pomer“, `p71_*` zap, `p72_*` zap (8 m), `p73_*` zap | bilance ≤ 1e-12 l/s; 150 → 6 výstupů [4] | v main |
| E74 | hladina podzemí jako plocha `gw` | `p74_gw`, `p74_vyzvednout`, `p74_hladina` zap | 9,4 kB místo 1,6 MB pásem; plný výpočet 1,7 → 2,3 s [4] | v main (Jan 01:49) |
| E75 | kras po tělesech | `p75_kras` **vyp** | 1. dutina 331 herních dní = 13,8 reálného dne [4] | v main, vypnuto |
| E76 | voda po přenosu výřezu, uložené prameny | `p76_prameny` zap | lokálně = plně, 0 neshod [4] | v main (Jan 03:26) |
| E77 | čas 1 herní den = 1 h | `p71_cas` 24 | eroze E51 23 → 139 min reálně [5] | v main (Jan 2026-11-19 22:19) |

Otevřené z vody (TODO main): slučovat drobné výstupy i mezi sebou; kreslit neobsazený pramen; po výkopu stavět `gw` jen pro dotčené těleso; zrychlit lokální přepočet (E79 jen o 10–35 % rychlejší než plný) [4].

## 3. Blok 2 – model světa a geologie (větve, nesloučeno)

| Větev / tag | Co řeší | Přepínače (vých.) | Klíčová čísla | Rozhodnuto / otevřené | Pomáhá / škodí jinde |
|---|---|---|---|---|---|
| `e78-prekryv` / `e78-prekryv` (77539f4) | změny hráče jako kanonický překryv buněk 0,25 m nad definicí | (nástroj, `prekryv78.gd`) | chodba 70 m 244 B proti 13–17 kB pole; 1000 buněk 1,8 kB; načtení = živý stav v 6/6 [6] | princip přijat (TODO), WVB1 zatím ukládá celé pole | základ pro E85, E88; odhalil chybu lokální vody u chodeb |
| `e79-chodby-voda` (99032fe) | lokální voda vidí dutiny | `p79_chodby` **vyp** | 0 neshod v 11 scénářích; lokálně 1,1–1,5 s proti plným 1,6–1,7 s [6] | Jan: zapnout? (otevřené) | jediná oprava pořadové závislosti z E83 |
| `e80-hranice-funkci` (88df75b) | kde končí funkce: buňka 0,5 m | – | 0,25 m z funkcí ≠ zjemnění v 7,8 % buněk; uložení „klíče + deflate“ nejlepší [6] | Jan 03:26: 0,25 m z funkcí + přepočet starých bloků; zákaz dna/okraje | E80 doporučilo opak (blok drží svou `gen_ver`) → **konflikt K4** |
| `e81-tenke-vrstvy` (fe94bd9) | tenké vrstvy mizí podle rozlišení | `p81_tenke` vyp | chybění 60 % → 7,6 % (0,5 m); svět jiný o 2,3 % [6] | Jan 03:26: v blueprintu zakázat vrstvy < 25 cm (→ E85) | p81 nafukuje vrstvy, tělesa vody horší |
| `e82-vapenec-hladina` (b8c1b69) | vápenec k hladině v ~50 % bloků | `p82_vapenec` vyp, `p82_tesneni` zap, hloubka 2 m | 495/1000 mincí; kras v E58 skoro nevzniká (2/63), v E67 19/30 ostrovů [6] | Jan 01:55 + 03:26 (mince i pro hluboký vápenec + dolomit); otevřené: jíl, E67 | zdvojnásobí závislost na pořadí vložení |
| `e83-determinismus` (ff9d2ad) | Hash(seed, změny, pořadí) | – | 12/12 bitově; pořadí vložení mění 1,9 % buněk (záměr); otisk vody = surové float64 [6] | otevřené: zaokrouhlit otisk vody? rohoví sousedé? | opravil klíč mezipaměti podzemí |
| `e84-implicitni-geologie` (070274c) | žíly, pegmatity, skarny, kras jako SDF | (nástroj) | R1 +51 ms / blok (0,5 m); útvar 176–296 B; kras přes šev funguje [6] | otevřené: SDF za příznakem, nahradit `cavity_one`? | řeší, že dnešní dutina nejde přes šev |
| `e85-blok2-rozhodnuti` (4ac8a1d) | implementace rozhodnutí 03:26 | `p85_blok2`, `p85_jemne`, `p85_okraj`, `p85_vrstvy` (0,25 m), `p85_voda` – vše vyp | jemné z funkcí 442–784 ms/blok (**65–108× pomalejší**); okraj: díry ve dně 703 → 0; tunel lokálně 12,6 s proti plným 1,6 s [6] | otevřené: co zapnout | `p79` sám nestačí, je potřeba `p85_voda` |

## 4. Blok 3 – přenos výřezu (větve, nesloučeno)

| Větev / tag | Co řeší | Přepínače | Klíčová čísla | Otevřené | Vztahy |
|---|---|---|---|---|---|
| `e86-otoceni-90` (c458886) | otočení výřezu po 90° | `p86_otoceni` vyp | otočení dat přesné (0 neshod, 5 ms); znovu generovat otočené = 19–25 % buněk jinak; švy vrstev skáčou o 1,8–2,7 m [7] | zapnout? klín vrstev u švu? zrcadlení? | počítat v souřadnicích původu (týká se i E85 jemné mřížky) |
| `e87-jadro-hory` (ff97a9f) | masiv jako funkce světa přes víc bloků | `p87_jadro_hory` vyp | sedlo na švu zmizí (šev 47,5–52,6 U); vedle nížiny stěna 5–6 m; prameny 9 → 3 [7] | zapnout? podhůří? terasy? | koliduje s `p94_hora_k` a E96 (**K6**); `veg.gd` nezná `hora_vyzdvizena` |
| `e88-kontrakt-navrh` (72e9ff3) | `TerrainSource/Transform/Placement/Instance`, WTI1, hashe, co ověřuje server | jen dokument `navrhy/navrh-terrainsource-kontrakt.md` | blok bez změn ~400–450 B; řídicí mřížka 8,7–35 kB → neukládat [8] | 11 otázek; s Willage-backend neprojednáno | souřadnice pevně 16 × 16 × 64 → po E96 neplatí (**K1**) |

## 5. Blok 4 a dál – měřítko, výkon, blok 128 m

| Větev / tag | Co řeší | Přepínače | Klíčová čísla | Rozhodnuto / otevřené | Vrstva |
|---|---|---|---|---|---|
| `e89-jednotky` (e8fff3c) | modul `jednotky.gd`, audit | `p89_meritko` vyp | 160+ ručních konstant; l → m³ dvěma způsoby (13 % náhodných hodnot jinak v posl. bitu); volání 3–4× dražší než konstanta [9] | Jan 2026-11-20 ~11:04 (t699u): 1 j = 1 m, převádět postupně, sjednotit l → m³, stromy a stavby v metrech | data |
| `e90-lod` (a68a267) | LOD a sešití švů, test 3 × 3 km | `p90_*` vyp | 2,27 M trojúhelníků, síť ≈ 260 MB; funkce `h_m` = E49 × 8 vodorovně, reliéf × 3 [10] | otevřené (6 otázek) | **prezentace** (+ funkce světa = data) |
| `e91-pruhlednost` (9f95d3b) | průhlednost / řez v izometrii | `p91_*` vyp | A dither 67/100 % viditelnosti [10] | otevřené | **prezentace** |
| `e92-meritko` (ffd6e44) | test měřítka, omezovač sklonu | `p92_svah`, `p92_max_sklon`, `p92_hladit` vyp | na 8 m bloku nepomůže, mění vodu (těleso 1 → 0); na 128 m strop 0,6 → 0 % nad 45°, ale 36 s [10] | Jan 11:48: bloky 128 m z funkce (→ E96); ostatní otevřené | data (svah) + prezentace |
| `e93-telefon` (7cbcf68) | bench APK, odhad CPU telefonu | preset „Android (bench)“ | logika v 1 vlákně; střední telefon voda 3,9–5,0 s, výkop 1,1–1,5 s; slabý 4,4–4,6× pomaleji [11] | čeká: Jan spustí APK | data (CPU) + prezentace |
| `e94-metry` / `e94-metry-2` (96f2310) | převod 30 skriptů na `jednotky.gd`, scéna v metrech | `p89_meritko` **zap na větvi**, `p94_hora_k` 1, `p94_meritko_veg` 0,5 | otisky beze změny ve 40 commitech; l → m³ sjednoceno bez změny otisků; hora max 30,5 m (strop sloupce); 162 neshod lokální vody při `hora_k` 1,5 (i na main) [12] | Jan 11:39: velikost vegetace 0,5; otevřené: sloučit, cesty, hora | data + prezentace |
| `e95-async-voda` (597342d) | voda ve vlákně po výkopu | `p95_async_voda` vyp, `p95_zpozdeni`, `p95_rezim` | blokování 652 ms → 0,15 ms; fronta = synchronní otisk po otisku; 128 m s podzemím 90–228 s do výsledku [13] | otevřené: kdy převzít, fronta / sloučení, zrychlit podzemí | data |
| `e96-blok128` (64dbbcd) | ostrov = blok 128 m z funkce | `p96_blok128` vyp, `p96_relief` 1, `p96_natazeni` 4, `p96_dlazdice` (7,4) | načtení 138–142 s, výkop 27–41 s, RSS 2,5 GB, tůně 22 % plochy, hora uříznutá na 30 m [14] | otevřené (6 otázek) | data + prezentace |
| `zkusebni-vse` / `zkusebni-vse-1` (7e2a06f) | všechny přepínače v panelu | 34 prvků, `p89_meritko` vyp | 55 dvojic bez pádu; E87 přebije `p94_hora_k`; E82 + hora 16 s [15] | – | nástroj |

Starší samostatné studie (v main, mimo hru): `voda-studie` (buněčná voda po ticích, jiný model než ostrovní voda), `lozika-studie` (gen-v3, zásobník ze serveru), `skala-studie`, `trava-studie`, `napojeni-studie` (vzhled), `tezba-studie` (T01–T03: vlastnosti a těžba hornin, `horniny_tezba_navrh.json`). Větve `e66*`, `e67-podzemi-okraje`, `tezba-studie`, `e68`–`e77`, `voda-e74-e77-slouceni` jsou celé v main. Obsah `refaktor-uzly` je v main přes synchronizaci E66 (rozdíl 3 soubory, 13 řádků).

### Prezentační vrstva (mimo kapitolu 1, Jan t710u)

Jen čte datový model. Patří sem: LOD a sešití (E90), průhlednost a řez (E91, svislý řez ze zkušební větve), shadery, stíny, draw calls a trojúhelníky (E93, E96), měřítko modelů vegetace (`p94_meritko_veg`), barvy materiálů (`mat.gd COLORS`). Výsledný pohled (2D dlaždice nebo 3D modely) zatím není rozhodnutý, takže datový model na něm nesmí záviset.

## 6. Konflikty a duplicity napříč větvemi

| # | Co | Kde | Proč to vadí |
|---|---|---|---|
| K1 | **Slovo „blok“ znamená tři věci**: blok blueprintu 8 × 8 × 32 m (16 × 16 × 64 buněk), blok vesnice 128 m (E96 ho skládá z 16 × 16 bloků 8 m) a ostrov „4 bloky, nejvýš ~16“ [16] | WVB1, E88, `veg.gd`, `block.gd` (BS 16) vs E92/E96, TODO „ostrov 4 × 4 = 512 m“ | vkládání, rotace, sousedé, recept, seed i WVB1 jsou dnes na 8 m. Po E96 nevíme, co hráč vkládá |
| K2 | **Tři jednotky s podobným jménem**: `U` = 0,5 m v geologii (E87 „40 U = 20 m“), herní jednotka `hj` = 0,25 m, scéna 1 j = 0,5 m vodorovně / 1 m svisle (před E94) | `geo_fn.U`, `jednotky.gd`, E89 | čísla v PROP se snadno čtou špatně; E94 to ve scéně opravilo jen na své větvi |
| K3 | **Výška sloupce 32 m** (BH 64 × 0,5 m) proti potřebě hory: E94 strop 30,5 m, E96 musel snížit reliéf × 3 → × 1, E90/E92 počítaly s 7–50 m | `jednotky.gd`, WVB1 `dims`, E94, E96, E90 | „skutečnou horu“ nejde udělat bez změny formátu |
| K4 | **Verze generátoru**: Jan 03:26 „nová verze přepočítá i staré bloky“ proti E80 „blok drží svou `gen_ver`“; E80 změřilo, že přepočet rozbije okolí výkopů (313/1787 buněk, 32 položení ve skále); E88 přidává, že každý přepínač terénu je nová verze | E80, E85, E88 §7 | každé zapnutí p81/p82/p85/p87/p96 by přepočítalo všechny ostrovy |
| K5 | **Lokální přepočet vody ≠ plný** (jedna chyba, hlášená pětkrát): E83 závislost na pořadí bez `p79`; E85 `p79` sám nestačí; E94 162 neshod při `hora_k` 1,5 (i main); E95 S5 110 `eff`, ve hře `fill` 43 / `to` 38; E95 blok 128 m `fill` 102 / `to` 60 | E79, E83, E85, E94, E95 | rozbíjí determinismus i shodu po načtení; výchozí test `voda_e66` to nevidí (0 neshod) |
| K6 | **Hora třemi způsoby**: E87 masiv (funkce světa, p87), `p94_hora_k` (násobí výšku šablony), E92 omezovač sklonu (horu snižuje), E96 funkce `lod90.h_m` s ořezem | E87, E94, E92, E96, zkušební panel | v panelu E87 přepíše `hora_k`; tři různé funkce světa |
| K7 | **Funkce světa ve třech nastaveních a dvě implementace bloku 128 m**: E90/E92 `h_m` × 8 / reliéf × 3 (dlaždice 14,5), E95 `blok128_voda95.gd` (jen povrch, × 8 / × 3), E96 `p96_blok128` (× 4 / × 1, dlaždice 7,4) | E90, E92, E95, E96 | čísla E95 a E96 pro 128 m nejsou o stejném terénu |
| K8 | **0,25 m mřížka**: zjemnění 0,5 m (dnes) proti vzorku z funkcí (Jan 03:26, `p85_jemne` 65–108× pomalejší, 7,8 % buněk jinak); E84 doporučuje „definice zůstává 0,5 m“; hra pořád kope po 0,5 m | E80, E84, E85 | rozhodnutí je, implementace je drahá a neodsouhlasená |
| K9 | **Výchozí podzemí E58 proti E67**: kras (E75, E82) funguje jen v E67, hra běží v E58; E77 mění chování E67 (kapacita 6× menší) | `p67_rezim`, E82, E77 | mince vápence 50/50 ve výchozí hře skoro nic nedělá |
| K10 | **Tabulky materiálů**: `materialy_voda.json` (13 základních) + `horniny_voda.json` (63 hornin, id 20–107) + `materialy_voda_navrh.json` (E59, nepřijatý) + `tezba-studie/data/horniny_tezba_navrh.json` (83, má hustotu, Mohs, vzácnost) + `mat.gd` (13 id, barvy, skóre rarity) + `poradi_hornin.json` (65 id). Kopie v `/workspace/willage-ideas/sdilene/` je **zastaralá** (2026-11-19 22:52, ještě čas × 144 a bez `_rozp75`) | `sdilene/`, `tezba-studie/`, prototyp | hustota je jen u 5 hornin ve vodní tabulce; vegetace zná jen 13 základních id |
| K11 | **Čísla zdrojů v ZDROJE.md se kříží**: [73]–[79] je v E84 rešerše geologie, v E93 Geekbench a GPU. Na `zkusebni-vse` jsou obě řady pod stejnými čísly, E96 cituje [77]–[79] bez záznamu na své větvi, E95 má [81]–[83] | `blueprint-studie/ZDROJE.md` na větvích | při sloučení přečíslovat |
| K12 | **Dvě vodní studie**: `voda-studie` (voda po buňkách a ticích) a ostrovní voda (prameny, události, pásma); jednotky převodu času: voda × 24 (E77), těžba vlastní historické × 144 | `voda-studie/`, `tezba-studie/PROP.md` | „voda jako data v buňkách“ (Jan 2026-11-17) dnes znamená něco jiného než ve hře |

## Zdroje

1. `blueprint-studie/PROP.md` (main 0e8aa00), oddíly E52–E64; `devlog/voda-algoritmy.md`.
2. `sdilene/materialy_voda.json` v4, pole `_e61`; PROP E59–E61.
3. `godot-prototyp/scripts/teren/params.gd` (main): `p67_rezim` "", `p75_kras` false; PROP E67.
4. `TODO.md` (main 0e8aa00), oddíly Voda a Rozhodnutí Jana; PROP E68–E76.
5. PROP E77 výsledky (main); `scripts/voda/cas_hry.gd`.
6. PROP oddíly E78–E85 na `zkusebni-vse` 7e2a06f (shodné s větvemi e78…e85, tipy 77539f4, 99032fe, 88df75b, fe94bd9, b8c1b69, ff9d2ad, 070274c, 4ac8a1d).
7. PROP E86, E87 (větve c458886, ff97a9f).
8. `navrhy/navrh-terrainsource-kontrakt.md` na `e88-kontrakt-navrh` 72e9ff3; `navrhy/format-bloku-wvb1.md`.
9. PROP E89 (e8fff3c), `godot-prototyp/scripts/jednotky.gd`.
10. PROP E90, E91, E92 (a68a267, 9f95d3b, ffd6e44).
11. PROP E93 (7cbcf68), `shots/e93/cpu_limit_souhrn.json`.
12. PROP E94, E94b (96f2310).
13. PROP E95 na `e95-async-voda` 597342d.
14. PROP E96 na `e96-blok128` 64dbbcd.
15. PROP „E95 zkušební větev“ na `zkusebni-vse` 7e2a06f.
16. `devlog/koncept.md`, `devlog/svet-a-meritko.md`, `teren-bloky-bunky.md` (main).

---

### 24. Asistent (shrnutí uvažování)

Přemýšlel po dobu 4s

---

### 25. Asistent

Ano. Tento dokument je velmi užitečný, protože obsahuje něco, co v aktuálním přehledu V1.0 zatím chybí: **historii technických rozhodnutí, skutečná měření a především důkazy, kde jednotlivé části generátoru selhávaly při kombinaci**.

Budu ho evidovat jako historický podklad z 20. 11. 2026, nikoliv jako aktuální specifikaci. Aktuální plán z 23. 11. má přednost.

Už při prvním porovnání se ukazuje několik zásadních věcí.

# 1. Co z dokumentu je stále použitelné

| Oblast | Historický výsledek | Vztah k aktuálnímu V1.0 |
|---|---|---|
| Překryv změn hráče E78 | Velmi úsporné ukládání změněných buněk | Potvrzuje správnost ukládání rozdílů |
| Lokální voda E79 | V některých scénářích rychlejší než plný výpočet | Použitelný základ, ale zatím neprokázaná správnost |
| SDF geologie E84 | Útvary spojité přes švy bloků | Potvrzuje současný návrh geologie |
| Determinismus E83 | 12/12 bitově shodných testů | Dobrý výsledek, ale ne úplný důkaz |
| Transformace E86 | Přesné otočení uložených dat | Potvrzuje celočíselné transformace |
| Masiv E87 | Funkce masivu přes více bloků | Historický základ pro samostatnou komponentu masivu |
| Jednotky E89/E94 | Sjednocení na metry bez změny otisků | Odpovídá aktuálnímu modelu |
| Asynchronní voda E95 | Blokování 652 ms → 0,15 ms | Velký potenciál, ale dosud neintegrovaný s E96 |

Za obzvlášť důležité považuji E78, E84, E86 a E89/E94. To jsou výsledky, na kterých se dá stavět, nikoliv pouze teoretické návrhy.

# 2. Největší rozpory s aktuálním modelem

Z dokumentu bych vytáhl šest problémů, které mají přímý dopad na současnou architekturu.

## K1 – Význam bloku a jeho rozměry

<badge color="danger">Kritický rozpor</badge>

Historické studie pracovaly s několika významy bloku:

- 8 × 8 m – původní blueprint.
- 128 × 128 m – větší blok vesnice.
- Ostrov složený z několika bloků.

Aktuální návrh už definuje:

- Blok 128 × 128 m.
- Segment 8 × 8 m.
- Buňka 0,25 m.

To je podstatná změna. Starý `WVB1` a kontrakt E88 nemohou být bez úprav považovány za aktuální formát.

**Doporučení:** v novém modelu bych nepoužíval samotné slovo `Block` bez kvalifikace. Rozlišil bych například:

```text
WorldBlock       128 × 128 m
Segment            8 × 8 m
Cell               0,25 × 0,25 m
Blueprint         výřez světa
Island            složený herní objekt
```

Blueprint navíc nemusí být rozměrově totožný s blokem.

## K3 – Výška sloupce a skutečné hory

<badge color="danger">Kritický rozpor</badge>

Historické testy ukázaly, že při výšce 32 m byla hora omezena na přibližně 30,5 m. E96 pak narazilo na velmi vysoké náklady:

- načtení 138–142 sekund,
- výkop 27–41 sekund,
- RSS 2,5 GB.

Aktuální návrh už nabízí výšku 32/64/128 m.

To řeší prostorový limit, ale automaticky to neřeší výkonnost. Naopak větší sloupec může výrazně zvýšit množství generovaných buněk.

**Doporučení:** oddělit výšku funkčního světa od skutečného množství materializovaných buněk. Výška sloupce 128 m nesmí znamenat, že se musí při každém dotazu vytvořit všech 512 buněk.

To je v souladu s tvým plánem generování pouze viditelné slupky.

## K4 – Verze generátoru

<badge color="warning">Nutné rozhodnutí</badge>

Historie ukazuje konflikt:

- Jedna varianta přepočítá staré bloky podle nové verze.
- Druhá zachová původní `gen_ver`.
- Přepočet po změně funkce může poškodit okolí výkopů.

V aktuálním modelu má ostrov vlastní verzi generátoru a blueprint může pocházet z jiného světa.

Tady bych doporučil velmi důležité rozlišení:

**Verze generátoru není totéž jako verze zdrojového blueprintu.**

Každé vložení musí zachovat identitu původního zdroje. Nová verze generátoru nesmí automaticky změnit již existující zdrojová data.

To také znamená, že bude potřeba samostatná politika kompatibility verzí.

## K5 – Lokální přepočet vody

<badge color="danger">Kritický technický problém</badge>

Toto je podle mě nejvýznamnější negativní výsledek celého dokumentu.

Lokální přepočet vody opakovaně vykazoval rozdíly proti plnému výpočtu:

- E83 – závislost na pořadí.
- E85 – samotné zapnutí E79 nestačilo.
- E94 – 162 neshod při určitém nastavení masivu.
- E95 – rozdíly mezi `eff`, `fill` a `to`.

To znamená, že lokální výpočet zatím není bezpečná optimalizace.

**Moje doporučení:** plný výpočet musí zůstat referenční implementací. Lokální přepočet se smí stát výchozím až tehdy, když prokáže shodu s plným výpočtem na testovacích scénářích, včetně různých pořadí editací a načítání.

Jinak by se ti mohlo stát, že stejný ostrov bude mít jinou vodu podle toho, které segmenty hráč navštívil.

## K6 – Hora třemi způsoby

<badge color="warning">Aktuální návrh musí sjednotit</badge>

Historicky existovaly tři přístupy:

1. Masiv jako samostatná funkce světa.
2. Násobení výšky existující šablony.
3. Omezování sklonu, které horu mění.

Aktuálně už jsi upřesnil, že skládání reliéfu je aditivní a masiv je samostatná komponenta.

Tím se výběr architektury výrazně zjednodušuje.

Pro V1.0 bych zachoval:

\[
H=H_{\text{base}}+H_{\text{massif}}+H_{\text{volcano}}
\]

Historické násobení šablony a ořezávání výsledné hory bych nepovažoval za další souběžné implementace. Jsou to experimenty, jejichž výsledky lze využít při ladění parametrů.

## K8 – Rozlišení 0,25 m versus 0,5 m

<badge color="warning">Velmi důležité</badge>

Dokument uvádí:

- Historická geologie pracovala s 0,5m mřížkou.
- Přechod na 0,25 m z funkce byl až 65–108× pomalejší.
- Přitom 7,8 % buněk se mezi oběma přístupy lišilo.
- E84 doporučovalo zachovat 0,5m definici.

Aktuální návrh už definuje voxel 0,25 m.

To ale neznamená, že všechny funkce musí pracovat v rozlišení 0,25 m.

Doporučil bych rozlišit:

| Vrstva | Rozlišení |
|---|---|
| Souřadnicový systém světa | 0,25 m |
| Geologické funkce | Podle konkrétní funkce |
| SDF útvary | Spojitá funkce |
| Výsledný materiál buněk | 0,25 m |
| Ukládání změn | 0,25 m |

Tím můžeš zachovat jemné herní rozlišení, aniž bys nutil každou procedurální funkci vyhodnocovat všechno v nejvyšší přesnosti.

---

# 3. Důležitá historická měření výkonu

Tady bych nechtěl ztratit žádné výsledky. Jsou důležité pro rozhodování o architektuře.

| Studie | Výsledek | Co z toho plyne |
|---|---:|---|
| E78 – překryv | 70m chodba: 244 B | Sparse změny mají velký potenciál |
| E84 – SDF | +51 ms/blok | Geologické útvary mají měřitelnou cenu |
| E85 – jemné funkce | 442–784 ms/blok | Nutnost cache a dávkového výpočtu |
| E90 – LOD | 2,27 mil. trojúhelníků, cca 260 MB | Prezentační vrstva musí být oddělena |
| E93 – telefon | Voda 3,9–5 s | Mobilní výkon je kritické omezení |
| E95 – async voda | 652 ms → 0,15 ms blokování | Asynchronní architektura má smysl |
| E96 – blok 128 m | 138–142 s načtení, 2,5 GB RSS | Současná implementace není pro produkci použitelná |

Zvlášť E96 bych nepřehlížel. Větší prostorový model je správný koncepčně, ale současná implementace zatím není výkonnostně přijatelná.

# 4. Co bych převzal do současné specifikace

Rozdělil bych historické poznatky na tři kategorie.

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    <badge color="success">Převzít jako základ</badge>
    **Potvrzené principy**
    - E78 – ukládání změn jako překryv.
    - E84 – SDF pro 3D geologické útvary.
    - E86 – přesné transformace o 90°.
    - E89/E94 – sjednocení jednotek na metry.
    - E87 – masiv jako prostorová funkce.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <badge color="warning">Převzít po úpravě</badge>
    **Řešení vyžadující nové ověření**
    - E79 – lokální voda.
    - E82 – vápenec a dolomit podle hladiny.
    - E83 – deterministické otisky.
    - E85 – jemné vyhodnocování funkcí.
    - E95 – asynchronní voda.
  </box>
  <divider color="subtle"/>
  <box gap={1}>
    <badge color="danger">Nepřebírat jako současný návrh</badge>
    **Zastaralé nebo konfliktní implementace**
    - WVB1 s pevnými rozměry 8 × 8 m.
    - Staré jednotky `U` a `hj`.
    - Násobení hory šablonou.
    - Staré implementace bloku 128 m.
    - Předpoklad, že lokální voda je již deterministicky ekvivalentní plné.
  </box>
</box>

# 5. Nová rizika, která bych přidal do aktuálního seznamu

Z tohoto dokumentu vyplývají ještě čtyři rizika, která v aktuálním plánu nejsou dostatečně viditelná.

**R1 – Závislost geologie na pořadí vložení.**

Vápenec a dolomit navázané na podzemní vodu mohou způsobit, že stejný blueprint bude mít jinou geologii podle toho, zda se nejdříve vloží sousední blok.

To je v přímém rozporu s požadavkem, aby sousedé nebyli při vložení měněni. Musíme proto rozhodnout, zda je geologie vlastností zdrojového světa, nebo výsledkem kompozice ostrova.

**R2 – Identita souřadnicového systému.**

Historické mřížky 0,5 m a 0,25 m se nesmí zaměňovat. Transformace, SDF i hranice segmentů musí používat jednoznačné celočíselné souřadnice.

**R3 – Výchozí voda a deterministická reprodukce.**

Historické otisky vody používaly surové float64. To je slabé místo serverového ověřování. Voda bude potřebovat vlastní přesně definovanou kvantizaci a pravidla zaokrouhlení.

**R4 – Kombinované výkonnostní testy.**

E95 a E96 spolu nikdy neběžely. Proto nevíme, jak se bude chovat blok 128 m při současném asynchronním přepočtu vody.

Výsledky jednotlivých větví nelze jednoduše sčítat a považovat za výsledek společné architektury.

---

# 6. Co z toho plyne pro další postup

Zatím bych nic neimplementoval ani nepřepisoval. Dokument nám pomohl určit, co je skutečně ověřené a co jen vypadá jako hotové.

Navrhuji následující pořadí:

1. Zpracovat další dokumenty `01-…` a porovnat jejich rozhodnutí s tímto přehledem.
2. Vytvořit jednotný seznam rozhodnutí: schváleno, zamítnuto, otevřeno, historické.
3. Teprve potom aktualizovat aktuální datový model V1.0.

**Jedna věc je už teď jasná:** E96, E95 a E85 by měly být považovány za důležité výkonnostní a architektonické studie, ne za hotové stavební kameny. Jejich kombinace musí projít novým testem.

Pošli další dokument, ideálně `01-…`. Budu průběžně udržovat jednotný přehled rozporů a rozhodnutí, abychom nemuseli na konci celé sjednocení dělat znovu.

---

### 26. Uživatel

# 01 – Základní principy a vstupní data (kostra k rozhodnutí)

Stav: **kostra**, 2026-11-20 14:20 SEČ. Každý bod obsahuje současný stav, varianty z větví s naměřenými čísly, doporučení a otázku pro Jana. Pole **Platí:** je zatím prázdné. Vyplní se až po Janově rozhodnutí v chatu (Jan t712u). Do té doby nic z tohoto souboru neplatí jako pravidlo.

Rozsah (Jan t710u): jen **datový model světa**. Vykreslování, LOD, průhlednost, shadery, draw calls a velikost modelů jsou prezentační vrstva, která data jen čte (viz `00-mapa-vetvi.md` §5). Datový model nesmí záviset na tom, jestli bude pohled 2D, nebo 3D.

Značení: „rozhodnuto (datum)“ = Jan už rozhodl. ⚠ = novější měření to zpochybňuje. K1–K12 = konflikty z mapy větví. Body jsou seřazené podle tématu. Pořadí, ve kterém je navrhuju s Janem procházet (nejdřív to, na čem závisí nejvíc ostatních), je v `README.md`.

---

## 1.1 Pojmy: ostrov, blok, segment, buňka

**Současný stav (před rozhodnutím).** „Blok“ měl tři významy (K1). Dnešní „blok“ v kódu (ve studiích „blok blueprintu“) má 8 × 8 × 32 m (16 × 16 × 64 buněk), podle nových pojmů je to **segment**. Je jednotkou vkládání, receptu, seedu, rotace, sousedů i formátu WVB1 [1][2]. „Blok vesnice 128 m“ byl Janova preference z 2026-11-19 19:56 [3] a od 2026-11-20 11:48 je rozhodnuto „generovat celý blok 128 m“ [4]. E96 ho ale složilo z 16 × 16 bloků po 8 m [5]. Ostrov má podle konceptu začínat na 4 blocích a mít nejvýš ~16 [1]. TODO uvádí „4 × 4 bloky = 512 × 512 m“ [3].

**Varianty**

| | A: blok = 8 m (stav kódu) | B: blok = 128 m, uvnitř segmenty 8 m (E96) | C: blok = 128 m, uvnitř segmenty 16/32 m (návrh E96 §3) |
|---|---|---|---|
| co hráč vkládá | blok 8 m | blok 128 m (výřez) | blok 128 m |
| ostrov 4 → 16 bloků | 16 × 16 → 32 × 32 m | 256 × 256 → 512 × 512 m | jako B |
| WVB1 / E88 | platí beze změny | nutná nová verze (dims) | nová verze |
| čísla | ostrov START 4 s načtení [6] | 138–142 s načtení, 2,5 GB [5] | neměřeno |

**Doporučení (před rozhodnutím).** Zavést tři slova: **blok** (128 m, jednotka vkládání a vlastnictví), **segment** (vnitřní dělení bloku pro výpočet a ukládání, dnes 8 m) a **ostrov** (sada bloků). „Dlaždice“ nechat pro svět výprav. Pravidla vkládání (rotace, sousedé, recept) přesunout ze segmentu 8 m na blok 128 m. Velikost segmentu řešit v 1.11 podle výkonu, ne jako princip.

**Otázka pro Jana.** Je blok 128 m jednotka, kterou hráč vkládá a otáčí, a ostrov se skládá z 4 až 16 takových bloků? Nebo je 128 m celý ostrov?

**Platí:** *rozhodnuto (2026-11-20 14:34–14:39, Jan t713u, t714u); doplněno (2026-11-20, Jan t741u–t743u); doplněno (Jan 2026-11-21 00:19, buňka 0,25 m)*

| Pojem | Co to je | Velikost (výchozí) |
|---|---|---|
| **Ostrov** | jednotka ukládání: proměnný počet bloků, roste dynamicky po jednom bloku, nese i data přes hranice bloků | – |
| **Blok** | jeden stavební dílek, ze kterého se ostrov skládá. Hráč ho vkládá, zrcadlí a otáčí | 128 × 128 m (512 × 512 buněk) |
| **Segment** | vnitřní část bloku. Jednotka výpočtu, ukládání a načítání. Segmenty vykreslují buňky | parametr, výchozí 8 m (32 × 32 buněk). 16 a 32 m jsou kandidáti, doladí se v bodě o výkonu (1.11) |
| **Buňka (voxel)** | nese materiál a vodu | 0,25 m |

- **Pravidlo:** velikost bloku, segmentu i buňky jsou parametry a v buňkách musí být mocninou 2. Blok se musí beze zbytku dělit na segmenty a segment na buňky. Blok 100 m tedy nejde, 64, 128 nebo 256 m ano.
- **Proč:** indexy jdou bitovými posuny, přehledy a LOD se půlí až na jednu buňku, quadtree slouží pro načítání a slučované vykreslování, a velikosti sedí na 2D tilesety 16/32/64 px (Jan t714u).
- **Důsledek:** dnešní „blok“ 8 m v kódu (`BS` 16, WVB1 `dims`, `veg.gd`, E88) je od teď segment. Vkládání, zrcadlení, rotace, recept a sousedé patří bloku. „Dlaždice“ zůstává pro svět výprav.
- **Data a zobrazení (Jan t715u, 2026-11-20):** datový model je v metrech a o pixelech nic neví. ~~Se zobrazením ho spojuje jen pravidlo **buňka 0,5 m = 1 dlaždice (tile)**. Segment 8 m = 16 × 16 dlaždic, blok 128 m = 256 × 256. Zobrazení převádí jedním faktorem (např. 1 m = 64 px, tedy dlaždice 32 px).~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19.
- **rozhodnuto (Jan 2026-11-21 00:19):** datová buňka (materiál, voda, kopání, simulace vody, rozdíl / překryv) je sjednocená na **0,25 m**, stejně jako viditelný voxel a dlaždice. Pravidlo zobrazení je **buňka 0,25 m = 1 dlaždice (tile)**. Segment 8 m = 32 × 32 dlaždic, blok 128 m = 512 × 512, sloupec 128 m = 512 buněk. Plná buňka vody je 0,25³ m³ = **15,625 l**. Důvod: výřez okna je malý (pevný zoom 64 dlaždic), delší jsou jen vstupní výpočty. Zobrazení převádí jedním faktorem (např. 1 m = 64 px, tedy dlaždice 16 px). Výměna tilesetu ani přechod mezi 2D a 3D data nemění.
- **Hierarchie ukládání (Jan t741u–t743u):** ostrov → blok → segment → buňka. Ostrov je také jednotka ukládání: roste dynamicky po jednom bloku a nese data, která jdou přes hranice bloků.
- **Poznámka – ostrov a svět:** tyto dva pojmy se nesmějí zaměňovat. **Svět** (1.4) zůstává vygenerovaný zdroj blueprintů. **Ostrov** je to, co hráč skládá z bloků a kde se ukládají i data přesahující hranici bloku.

---

## 1.2 Jednotky a mřížky

**Současný stav**
- *rozhodnuto (2026-11-19 20:12):* herní jednotka a kopací buňka 0,25 m, postava 1,75 m = 7 jednotek. Hierarchie: 1 m hrubý svět, 0,5 m řídicí mřížka geologie (vnitřní mřížka funkce, ne datová buňka), 0,25 m kopání, terén sám rozlišení nemá [3].
- *rozhodnuto (2026-11-19 20:40):* kopání zůstává po 0,25 m [3].
- *rozhodnuto (2026-11-20 ~11:04, t699u):* 1 jednotka scény = 1 m, převod na `jednotky.gd` postupně, jeden tvar l → m³, stavby a stromy v metrech [7]. Hotovo na `e94-metry` (otisky beze změny ve 40 commitech, l → m³ bez změny otisků) [8].
- *rozhodnuto (2026-11-20 03:26):* mřížku 0,25 m počítat z funkcí [3]. ⚠ E85: 65–108× pomalejší (442–784 ms na segment 8 m) a jiných 7,8 % buněk [9]. ~~E84 doporučuje nechat definici 0,5 m [9].~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19: datová buňka je 0,25 m (1.1). Měření E85 platí (vzorek 0,25 m na celý segment).
- Hra dnes pořád kope po 0,5 m (stav kódu, úkol implementace). Mřížka 0,25 m je zatím jen v `prekryv78` [9].
- K2: `U` = 0,5 m v geologii (řídicí mřížka funkce, ne datová buňka), `hj` = 0,25 m [8].

**Varianty jemné mřížky 0,25 m**

⚠ překonáno rozhodnutím 2026-11-21 00:19: datová buňka je 0,25 m (1.1). Tabulka a časy zůstávají jako měření z doby, kdy definice byla 0,5 m.

| | A: zjemnění buněk 0,5 m (dnes) | B: vzorek funkcí 0,25 m (Jan 03:26, `p85_jemne`) | C: definice 0,5 m, 0,25 m jen překryv hráče (E80, E84) |
|---|---|---|---|
| čas na segment 8 m | 6–8 ms | 442–784 ms | 6–8 ms |
| odhad na blok 128 m (× 256) | ~2 s | ~1,9–3,3 min | ~2 s |
| věrnost funkci | 7,8 % buněk jinak | přesná | jako A, rozdíl jen u výkopu |
| závislost na otočení | ne | musí se počítat v souřadnicích původu (E86) | ne |

**Doporučení.** ~~Jednotky: **metr** pro fyziku a vodu, **buňka 0,5 m** jako definice terénu, **0,25 m** jen pro kopání a překryv. Jedno jméno pro každou jednotku (`m`, `b05`, `b025`) a zrušit `U` v textech. Pro jemnou mřížku varianta C: zachová rozhodnutí o kopání 0,25 m a nestojí minuty na blok. Variantu B vrátit, jen až bude generátor v rychlejším jazyce.~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19: datová buňka je 0,25 m (1.1). Metr zůstává jednotkou fyziky. `U` / řídicí mřížka 0,5 m je vnitřní mřížka geologické funkce, ne datová buňka.

**Otázka pro Jana.** ~~Necháme definici terénu po 0,5 m a jemných 0,25 m jen tam, kde hráč kope? Tím se mění tvoje rozhodnutí z 03:26 „0,25 m z funkcí“.~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19: buňka 0,25 m platí pro definici i kopání.

**Platí:** *rozhodnuto (2026-11-20 20:09–20:14, Jan t799u, t800u)*; mění rozhodnutí 2026-11-20 03:26 „0,25 m z funkcí všude“

- **Procedurální svět:** terén se negeneruje celý dopředu, generuje se z funkce světa podle potřeby.
- Pohled je izometrický, výhled je omezený. Generuje a vykresluje se jen **zorné pole plus pár polí okraje** kvůli plynulému pohybu a dokreslování.
- Vykresluje se jen to, co je **obnažené vzduchem**. U otevřené průhledné vody se vykreslí i dno.
- Generuje se jen **slupka 2–3 buněk** pod povrchem (hloubka je parametr). V ní se buňka **0,25 m počítá přímo z funkce světa** (varianta B), protože jde jen o tenkou vrstvu, ne o celý blok. Sjednocení datové buňky na 0,25 m (2026-11-21 00:19, 1.1) toto pravidlo nemění: pořád se vzorkuje jen slupka, ne celý sloupec.
- Hlubší buňky se **donačtou až při odkrytí** (kopání, voda). Uložená data obsahují jen to, co už bylo vygenerované nebo změněné.
- **Podzemní voda** se počítá jako funkce (propustnost a hladina z funkce světa) bez uložených buněk. Kde se vzduchem obnaží, vykreslí se.


---

## 1.3 Výška sloupce

**Současný stav.** V dnešním kódu má sloupec 64 buněk × 0,5 m = 32 m a pevně je zapsaný v WVB1 (`dims` 16, 16, 64) [2], v E88 [10] i v `jednotky.gd` (BH 64) [8]. Povrch může mít nejvýš 61 buněk = 30,5 m [8]. E96 kvůli tomu snížilo reliéf funkce z × 3 (7–50 m) na × 1 (16–30 m) a vrchol hory je uříznutý [5]. Charakter krajiny (kompaktní / vyvážená / velkolepá) Jan nerozhodl (Blok 5) [3].

**Varianty**

| | 32 m (dnes v kódu) | 64 m | 128 m |
|---|---|---|---|
| buněk 0,5 m ve sloupci (tehdejší buňka) | 64 | 128 | 256 |
| buněk 0,25 m ve sloupci (výpočet) | 128 | 256 | 512 |
| hora nad loukou | ~10 m (E94) | ~40 m | ~100 m |
| paměť buněk bloku 128 m (u8, 0,5 m, výpočet) | 4 MB | 8 MB | 16 MB |
| paměť buněk bloku 128 m (u8, 0,25 m, výpočet = × 8) | 32 MB | 64 MB | 128 MB |
| index buňky 0,25 m na segment 8 m | 17 bitů | 18 bitů | 19 bitů |

Paměť je výpočet, ne měření. Při buňce 0,5 m: 256 × 256 × výška × 1 B. Při buňce 0,25 m osminásobek (512 × 512 × výška). Skutečná paměť E96 byla 2,5 GB RSS, hlavně kvůli scéně, a měřila se při buňce 0,5 m [5].

**Doporučení.** 64 m. Vejde se hora z E90/E96 bez ořezu. Ukládá se jen definice a překryv (1.11), takže výška stojí hlavně při generování. 128 m až po rozhodnutí o charakteru krajiny.

**Otázka pro Jana.** Zvětšíme sloupec na 64 m? Nebo nejdřív rozhodneme charakter krajiny?

**Platí:** *rozhodnuto (2026-11-20, Jan t716u, t717u)*

- **Výška sloupce** je celá výška bloku od dna ostrova po nejvyšší bod: podloží, vrstvy, jeskyně, podzemní voda i hory.
- Je to **parametr jako výčet mocnin 2: 32 / 64 / 128 m**, výchozí **128 m** (512 buněk po 0,25 m).
- **Neutrální úroveň terénu je v polovině výšky.** Při 128 m je pod ní 64 m pro podloží a kopání a nad ní 64 m pro hory.
- **Proč:** vejde se i největší hora a hezky se vykreslí (Jan t717u).
- **Důsledek – velikost dat (odhad, ne měření):** buňka u8 (materiál). Vzduch nad terénem se neukládá, takže pevné buňky jsou zhruba po neutrální úroveň a do výšky hor.

  Čísla níž jsou výpočet při buňce 0,25 m (osminásobek dřívějších hodnot počítaných při 0,5 m). Není to měření.

  | výška | buněk ve sloupci (0,25 m) | segment 8 m (32 × 32) plný sloupec | segment, jen pod neutrální úrovní | blok 128 m (256 segmentů), jen pod neutrální úrovní |
  |---|---|---|---|---|
  | 32 m | 128 | 128 kB | 64 kB | 16 MB |
  | 64 m | 256 | 256 kB | 128 kB | 32 MB |
  | 128 m | 512 | 512 kB | 256 kB | 64 MB |

  Jsou to nekomprimované buňky v paměti při generování. Na disk a na server jde jen definice + překryv (1.10), který na výšce skoro nezávisí. Voda jen v buňkách, kde je. Index buňky v segmentu 8 m (32 × 32 × 512) má při sloupci 128 m 19 bitů (při sloupci 32 m 17 bitů).
- **Důsledek – co změnit při stavbě modelu:** 32 m (64 buněk po 0,5 m) je dnes natvrdo ve WVB1 (`dims` 16, 16, 64), v E88 / WTI1 (souřadnice 16 × 16 × 64, index 17 bitů) a v `jednotky.gd` (`BH` 64). Musí to být parametr podle tohoto výčtu, při buňce 0,25 m a sloupci 128 m tedy 512 buněk.

---

## 1.4 Zdroj pravdy o terénu: funkce světa, šablony a hora

**Současný stav**
- Terén jsou funkce ve světových metrech (`geo_fn`: povrch, hranice vrstev na řídicí mřížce 0,5 m — to je vnitřní mřížka funkce, ne datová buňka, viz 1.1 — materiál bodu). Buňky jsou z nich vzorky [9]. Princip „funkce jsou jediný zdroj pravdy, buňky, voda a vykreslení jsou odvozené“ je v TODO jako návrh (ChatGPT 2026-11-19) [3].
- Povrch dnes dávají **šablony povrchu** (recepty louka, kopec, hora, písčina; ve studiích „šablony blueprintu“) na segment 8 m (v kódu „blok“). Okraje se dorovnávají na sousedy, sousedé se nikdy nemění (*rozhodnuto 2026-11-17*) [1].
- *rozhodnuto (2026-11-20 11:48):* blok 128 m z funkce světa místo šablon [4].
- K6/K7: hora a funkce světa existují ve více verzích.

**Varianty povrchu**

| | A: šablony na segment 8 m + dorovnání (dnes) | B: funkce světa `h_m` (E90/E96) | C: B + masiv jako funkce (E87) |
|---|---|---|---|
| švy | 0 skok; hora má na každém švu sedlo (20 m) [11] | 0 skok, bez sedel | 0 skok, pořadí vložení 0 neshod [11] |
| závislost na pořadí vložení | 1,9 % buněk (záměr) [9] | jen geologie | 0 u masivu |
| svahy | 26 % bodů nad 45° (kvantování) [12] | p50 9°, p95 28° (× 4 / × 1) [5] | hladší, bez teras [11] |
| negativa | hora malá (9 m) | tůně 22 % plochy [5] | stěna 5–6 m vedle nížiny [11] |
| parametry | – | E90 × 8 / × 3; E96 × 4 / × 1 | U, nezávislé na E90 |

**Doporučení.** Jedna funkce světa pro povrch i masiv (B + C sloučit do jedné funkce v metrech s jedním nastavením). Šablony povrchu nechat jako **recept**, který funkci jen moduluje (typ bloku řídí geologii a jemný tvar, jako cesta `base_hm` v E49). `p94_hora_k` a omezovač sklonu E92 zrušit: řeší totéž hůř a mění vodu. Svět výprav a ostrov musí brát stejnou funkci.

**Otázka pro Jana.** Má povrch bloku dávat jedna funkce světa a recept (louka, hora…) jen upravovat geologii a detail? Nebo chceš šablony zachovat jako hlavní tvar?

**Platí:** *rozhodnuto (2026-11-20 15:09–15:12, Jan t718u, t719u); doplněno (2026-11-20, Jan t744u–t748u, t749u, t761u–t762u)*

Jde o dvě oddělené věci:

1. **Herní svět**
   - Generuje se jako celek z funkce světa.
   - Tvar terénu dává jen funkce: žádné šablony povrchu a žádné ruční zvedání hor. `p94_hora_k` a omezovač sklonu E92 se ruší. Hory dělá svět, i masiv E87 má být součástí funkce světa.
2. **Blueprint**
   - Blueprint je **otisk jedné oblasti herního světa o velikosti jednoho bloku** (128 m).
   - Vesnický ostrov se skládá z blueprintů: vložení, zrcadlení, otočení, posun výšky a napojení na sousedy (dříve rozhodnuto: sousedé se nemění, přizpůsobuje se nový blok).
3. **Testovací pipeline** (jeden krok navíc v generování světa)
   - Vygenerovat svět 3 × 3 bloky (384 × 384 m), rozřezat ho na 9 blueprintů a ty náhodně poskládat do ostrova (náhodné pořadí, otočení a zrcadlení).
   - Lze spustit celé (test světa i Willage zároveň), nebo zvlášť: jen svět, nebo jen ostrov z hotových blueprintů, podle fáze testování.

Pojmy: **blueprint** = otisk světa o velikosti bloku. To, čemu se ve studiích říkalo „šablona blueprintu“ (louka, kopec…), je dnes **šablona povrchu / recept** a pro tvar terénu se už nepoužívá. Vložený blueprint na ostrově je **blok**.

- **Doplněno (Jan t744u–t749u, t761u–t762u):**
  - Herní svět je **velká mapa ze spojité funkce**. Vlastní bloky nemá; na blueprinty se dělí řezáním.
  - Segmenty uvnitř blueprintu vzorkují svou část funkce do buněk 0,25 m a ukládají výsledná data, ne funkci. Při vložení se buňky jen otočí nebo zrcadlí. Od té chvíle se data segmentu mění kopáním a vodou. Funkce zůstává zdrojem pro regeneraci a pro namátkovou kontrolu na serveru (1.10).
  - **Procedurální ostrov (Jan t801u–t803u, 2026-11-20 20:17–20:21):** svět je ze seedu, parametrů a verze generátoru plně opakovatelný. Ostrov zůstává procedurální, má jen jeden vstup navíc: **seznam vložení v pořadí**. Každé vložení nese souřadnice blueprintu ve světě, zrcadlení, otočení, výškový posun a režim napojení boků (Auto/Blend/Keep). Funkce bloku je funkce světa přepočtená do nové polohy, prolnutí švů je funkce sousedů (ti se při vložení nemění, proto stačí pořadí).
  - Vložení nese i **seed a verzi generátoru svého světa**, aby šel vložit i blueprint z jiného světa (připravenost do budoucna).
  - **Ukládá se jen rozdíl proti funkci:** změněné buňky terénu, vrstvy nad terénem (stavby, cesty, změny rostlin) a voda tam, kde se liší od výchozí funkce. Nezměněné buňky se neukládají, ani když už byly vygenerované (viz 1.2). Tím se mění předchozí bod „segmenty ukládají výsledná data“.
- Svět má maximální velikost **4096 × 4096 m** (32 × 32 bloky po 128 m, mocnina 2, parametr). Začíná na výchozí velikosti **3 × 3 bloky** (nastavitelný parametr, Jan t749u) a při potřebě se dogenerovává, ale jen do tohoto maxima (Jan t761u–t762u). Nové části uvnitř maxima navazují plynule.
  - **Rozlišení rozšiřování:** rozšiřovat svět znamená nové blueprinty z funkce. Rozšiřovat ostrov znamená, že hráč vloží další blueprint jako blok. Ten blueprint může pocházet z jiného místa světa a být otočený, takže sousedé na ostrově se napojují dorovnáním okrajů, ne funkcí.

---

## 1.5 Determinismus, seed, pořadí a verze generátoru

**Současný stav**
- Blok = f(definice, seed, sousedé položení před ním). 12/12 bitově, 2 procesy stejně [9].
- *rozhodnuto (2026-11-17):* sousedé se nemění, pořadí vložení výsledek mění záměrně (1,9 % buněk u švů, s E82 dvakrát víc) [3][9].
- Hash = f(definice, překryv), ne f(historie). Na stejné buňce rozhoduje pořadí (vykopat → zasypat ≠ zasypat → vykopat) [9].
- Otisk vody hashuje surové float64. Shoda je jen na stejné platformě, telefon a .NET nejsou změřené [9][10].
- *rozhodnuto (2026-11-20 03:26):* nová verze generátoru přepočítá i staré bloky [3]. ⚠ K4: E80 změřilo, že se změní okolí výkopů (313 z 1 787 buněk) a 32 položených buněk skončí ve skále [9]. Podle E88 je každý přepínač terénu nová verze [10].

**Varianty verze generátoru**

| | A: přepočítat vše (Jan 03:26) | B: blok drží svou verzi (E80) | C: přepočítat jen bloky bez změn hráče |
|---|---|---|---|
| konzistence světa | jedna verze | víc verzí vedle sebe | skoro jedna |
| zásah do hráčových výkopů | ano (měřeno) | ne | ne |
| cena | ostrov 16 segmentů 8 m ~10–19 s; 128 m neměřeno [10] | 0 | malá |
| kód | jen nejnovější generátor | všechny verze navždy | nejnovější + staré pro dotčené |

**Doporučení.** Pro buňky a překryv bitový determinismus: f64, žádný float32, řazené slovníky, celočíselné hashe [9]. Vodu hashovat po zaokrouhlení (1/4096 buňky, 1e-6 l/s) [10]. U verze generátoru varianta C. Výjimkou budou opravy chyb, kde se přepočítá vše a konflikty se hráči ohlásí.

**Otázka pro Jana.** Při nové verzi generátoru přepočítat jen bloky, do kterých hráč nezasáhl, a ostatní nechat na staré verzi?

**Platí:** **Odloženo (2026-11-20, Jan t726u):** neřešit, dokud nemáme jeden funkční generátor.

- **Doplněno (2026-11-20 20:17–20:21, Jan t801u–t803u):** protože se ukládá jen rozdíl proti funkci, je **determinismus povinný**. Stejný seed, parametry a verze generátoru musí dát bitově stejný svět na všech zařízeních a na serveru. Uložené změny i každé vložení blueprintu proto nesou verzi generátoru. Jak přepočítat svět při nové verzi, zůstává odložené.

---

## 1.6 Materiály a sdílená tabulka

**Současný stav (K10)**
- `sdilene/materialy_voda.json` v4 obsahuje 13 základních materiálů a `horniny_voda.json` 63 hornin (id 20–107). Mají propustnost `perm` = (log10 K + 9)/6, pórovitost, zadržení, odpor, pevnost (`load`, `cantilever`), erozi (`ero_v`, `sed_v`), režim a čas průsaku pro čas × 24 [13].
- Rozpustnost a hustota jsou jen u 5 hornin (E75) [13].
- `tezba-studie/data/horniny_tezba_navrh.json` (T01, návrh) má 83 položek s hustotou, Mohsem, UCS, vzácností a výtěžkem [14].
- `mat.gd` ve hře má 13 id, barvy a skóre rarity. `poradi_hornin.json` má 65 id [15].
- `materialy_voda_navrh.json` (E59) je nepřijatý návrh, nahradila ho v4 [13].
- Kopie `/workspace/willage-ideas/sdilene/` je zastaralá: ještě čas × 144 a bez rozpustnosti.
- Vegetace zná jen základní id (`SURFACES` v `veg.gd`) [16].

**Varianty**

| | A: dnešní stav (více souborů) | B: jedna tabulka materiálů, pole po skupinách (voda, těžba, pevnost, vzhled) | C: B + generovaná z jednoho zdroje pro GDScript i C# |
|---|-

---

### 27. Asistent (shrnutí uvažování)

Přemýšlel po dobu 4s

---

### 28. Asistent

Ano. Beru tyto dokumenty jako **historické podklady ke sjednocení**, nikoliv jako automaticky platnou specifikaci. Budu rozlišovat tři úrovně:

1. **Aktuální rozhodnutí** – co už jsi výslovně schválil v chatu.
2. **Výsledky studií** – naměřené hodnoty a ověřené technické varianty.
3. **Návrhy a otevřené otázky** – nic z toho nepovažovat za závazné, dokud to neschválíš.

Zatím z dodaných částí dokumentů vyplývá několik důležitých věcí, které mají přímý dopad na naši současnou práci na vykreslování terénu.

## Co považuji za aktuální základ

| Oblast | Aktuální stav |
|---|---|
| Svět | Spojitá procedurální funkce ze seedu, parametrů a verze |
| Maximální rozměr světa | 4096 × 4096 m |
| Výchozí svět | 3 × 3 bloky |
| Blok | 128 × 128 m, stavební dílek ostrova |
| Segment | Výchozí 8 × 8 m, výpočetní a ukládací jednotka |
| Buňka / voxel | 0,25 × 0,25 m |
| Výška sloupce | Výchozí 128 m |
| Geologická řídicí mřížka | 0,5 m, nezávislá na datové buňce |
| Blueprint | Otisk oblasti světa o velikosti jednoho bloku |
| Ostrov | Sestava blueprintů s vlastním pořadím vložení a změnami |
| Ukládání | Rozdíly proti procedurální funkci |

## Co to znamená pro vykreslování

Zásadně se tím potvrzuje, že musíme oddělit tři věci:

- **Procedural World Model** – definuje, co se na daných souřadnicích nachází.
- **Voxel Data Model** – reprezentuje vzorkované buňky a jejich aktuální změny.
- **Rendering Model** – z voxelových dat vytváří výslednou geometrii.

To je důležité i vzhledem k dříve zvolenému směru:

- Povrch: voxel.
- Geometrie: compare.
- Výtvarný styl: hybrid.

Renderer nesmí být svázaný s tím, jakým algoritmem vznikla funkce světa. Musí umět vykreslit jak původní procedurální terén, tak jeho změny po kopání, vodní erozi, vložení blueprintu nebo vzniku jeskyně.

## Zatím vidím jeden zásadní rozpor v dokumentaci

V kapitole 1.4 jsou vedle sebe dvě odlišné představy:

**Varianta A – uložený otisk:**
Segmenty vzorkují funkci světa do buněk. Při vložení blueprintu se buňky otočí nebo zrcadlí a dále se pracuje s nimi.

**Varianta B – procedurální vložení:**
Ostrov si uchovává seznam vložení a funkce bloku se vyhodnocuje v nové poloze. Ukládají se pouze rozdíly proti této funkci.

Tyto varianty nejsou ekvivalentní. Liší se zejména v tom, jak se řeší transformace, švy, determinismus a regenerace dat. Dokument obsahuje formulace obou přístupů, takže bych je zatím neslučoval do jednoho závěru.

Další důležitý bod je výkon: E85 naměřilo 65–108× vyšší čas při vzorkování celého segmentu v rozlišení 0,25 m. To je relevantní pro návrh načítání a generování meshů, ale neznamená to, že máme měnit schválenou velikost buňky.

---

**Pro další práci budu tyto materiály používat jako kontext a budu upozorňovat na rozpory s novějším návrhem.** Nebudu automaticky přebírat staré přepínače ani výsledky studií jako součást finální architektury.

Pošli prosím zbytek kapitoly 01 a případně další kapitoly. Zatím bych nedělal finální technický návrh rendereru – nejprve potřebujeme uzavřít, jak přesně funguje hranice mezi procedurální funkcí,

---

### 29. Uživatel

# 02 – Model světa a generování bloku 128 m (kostra k rozhodnutí)

Stav: **kostra**, 2026-11-20 20:45 SEČ. Každý bod obsahuje současný stav z větví a studií, varianty s naměřenými čísly, doporučení a otázku pro Jana. Pole **Platí:** je prázdné. Vyplní se až po Janově rozhodnutí v chatu (Jan t712u). Do té doby nic z tohoto souboru neplatí jako pravidlo.

Navazuje na kapitolu 1 (`01-principy-a-vstupy.md`), která je rozhodnutá (až na přepočet při nové verzi generátoru, 1.5, a přeskočený datový rozpočet, 1.11). Tady se řeší, **v jakém pořadí a po jakých jednotkách se z rozhodnutého modelu svět a ostrov skutečně generují**. Vykreslování, LOD, průhlednost, shadery a slučování sítí patří do prezentační vrstvy (kapitola 7) a z dat jen čtou.

Značení: K1–K12 = konflikty z `00-mapa-vetvi.md`. [n] = zdroj ze seznamu na konci. Časy jsou v SEČ. Měření jsou z boxu (Linux x86_64), telefon je jen odhad z E93.

---

## 2.1 Pořadí kroků generátoru

**Téma.** V jakém pořadí vzniká blok 128 m: funkce světa, reliéf, geologie a útvary, sopky, výchozí voda, vegetace. Co zůstává funkcí a co se vzorkuje do buněk.

**Současný stav**
- Dnešní pipeline (`pipeline.gd`, režim `geo` = v2) běží po **segmentech 8 m** (v kódu „blok“) a má toto pořadí [1]:
  1. povrch ze **šablony** (recept louka / kopec / hora / písčina) a volitelná eroze,
  2. dorovnání okrajů na sousedy; chybí-li soused, regionální základ (`surf_ref`), nebo `base_hm` z hrubého světa (E49) [1][2],
  3. vrstvy: vlastní tvar + regionální základ, mocnosti se napojují klíny na sousedy,
  4. hranice = součet mocností, kontext `geo_fn.world_fn` + `block_info`,
  5. **celý sloupec** se vzorkuje do buněk 0,5 m (`geo_fn.sample`) — dnešní kód, před sjednocením buňky na 0,25 m,
  6. minerály, pak dutiny (`cavity_one`, dnes nejvýš jedna na segment — to 1.7 ruší),
  7. voda: vsakování gen-v3 (`G.infiltrate`),
  8. validátor gen-v3.
- Vegetace v pipeline není. Generuje se až z hotového segmentu po všech transformacích (`veg.generate`, seed účel „VEG“) [3].
- E96 zapíná `p96_blok128`: ostrov je 16 × 16 segmentů 8 m = 128 × 128 m. Povrch bere z funkce `lod90.h_m` přes `base_hm`, bez šablon. Typ segmentu (jen geologie) se volí z průměru a rozpětí výšky. Vrstvy, minerály, dutiny a voda jdou stávající pipeline [2].
- **Časy E96** (box, 256 segmentů): generování 58–61 s (**224 ms / segment**, lineární). Pole povrchu / kostky / duální povrch / vegetace 7,3 / 8,4 / 2,8 / 9,6 s. Plná voda 49–53 s. Načtení celkem **138–142 s**. Výkop 27–41 s. RSS 2,5 GB. Historicky E49 ~0,25 s na segment, sedí s 224 ms [2].
- Funkce světa existuje ve víc podobách (K6, K7): `lod90.h_m` (E90 × 8 / reliéf × 3; E96 × 4 / × 1), masiv E87, `p94_hora_k`, omezovač E92. E49 `hruby_teren` má navíc **jednu sopku** (kužel s kráterem ve středu dlaždice); test E90 ji vypíná [2][4][5].
- Kapitola 1 už rozhodla: terén dává jedna funkce světa (1.4), slupka 2–3 buněk s 0,25 m z funkce (1.2), útvary jsou funkce světa přes švy (1.7), sopka je součást funkce a vrstvy propíchne (1.14), podzemní voda je funkce (1.2, 1.8), ukládá se jen rozdíl proti funkci (1.4, 1.10). Dnešní pipeline tohle ještě nedělá: vzorkuje celý sloupec a celý ostrov dopředu.

**Varianty pořadí**

| | A: dnešní pipeline (šablona → švy → vzorek celého sloupce → voda → vegetace) | B: nejdřív celá funkce světa, vzorek až ve slupce (návrh podle 1.2–1.4, 1.7, 1.14) |
|---|---|---|
| povrch | šablona + dorovnání, v E96 `h_m` přes `base_hm` | funkce reliéfu (1.13) včetně sopek (1.14) |
| geologie | po segmentu, klíny na sousedy, dutina max. 1 na segment | funkce vrstev a útvarů; sopka je propíchne |
| voda a vegetace | až po vyplnění buněk celého sloupce | výchozí stav je funkce; materializace viz 2.5 a 2.6 |
| kdy vznikají buňky | vždy celý segment (64 buněk výšky při sloupci 32 m) | jen slupka 2–3 buněk v zorném poli a při odkrytí |
| čas (změřeno jen A) | 224 ms / segment 8 m, 58–61 s na blok 128 m [2] | nyní neměřeno; odhad z E90: výšky a slupka 3 km mapy ≈ 5,8 MB, stavba 4,9 s (jen výška, bez geologie a vody) [4] |

**Doporučení.** Varianta B, v tomto pořadí (všechno nejdřív jako funkce, vzorek až nakonec):

1. **Reliéf** funkce světa v metrech, včetně profilu (1.13) a sopek (1.14). Šablony povrchu a `p94_hora_k` / E92 se nepoužívají (1.4).
2. **Geologie a útvary** (1.7, 1.7.1) jako funkce téhož světa. Sopka vrstvy **propíchne** (průduch a kuželovité slupky lávy a popela, 1.14), neohýbá je.
3. **Výchozí voda** jako funkce: hladina podzemí, prameny ze seedu (1.8). Buňky vody se ještě nevytvářejí (viz 2.5).
4. **Vegetace** ze seedu jako pravidlo nad povrchem a vodou (1.12, viz 2.6).
5. **Vzorek** jen ve slupce (1.2) a **uložení jen rozdílu** proti funkci (1.4).

Minerály, žíly, kras i dutiny jsou útvary funkce světa (1.7), ne krok „po vyplnění buněk“. Validátor gen-v3 a zásobník ze serveru zůstávají kontrolou, ne zdrojem tvaru.

**Otázka pro Jana.** Souhlasíš s pořadím: reliéf a sopky ve funkci světa → geologie a útvary (sopka vrstvy propíchne) → výchozí voda jako funkce → vegetace ze seedu, a buňky se vzorkují až ve slupce? Mají minerály a dutiny zůstat součástí funkce světa (jako útvary v 1.7), nebo se mají počítat až při vzorkování slupky?

**Platí:** *rozhodnuto (2026-11-20 20:44–20:49, Jan t811u–t814u)*

- **Biomy (varianta C, kombinace):** hrubá **mapa biomů** (např. hornatina, pahorkatina, nížina, mokřad, sopečná oblast) určí oblasti světa a pro každou výběr hornin. Uvnitř oblasti **mapa hornin** rozloží konkrétní zastoupení. Výška, voda a vegetace berou biom i horninu. Biom je zároveň zdrojem parametrů členitosti (1.13) a výskytu sopek (1.14).
- **Mapa hornin** udává jen to, **kde a v jakém množství** se která hornina vyskytuje. Tvar reliéfu sama neurčuje.
- **Pořadí kroků generátoru** (vše nejdřív jako funkce, vzorek až nakonec):
  1. mapa biomů a mapa hornin (hrubé body ze seedu na maximální ploše světa, 1.7.1),
  2. reliéf a sopky ve funkci světa (parametry členitosti z biomu),
  3. geologie a útvary podle mapy hornin (sopka vrstvy propíchne, 1.14),
  4. výchozí voda jako funkce (hladina podzemí, prameny ze seedu),
  5. vegetace ze seedu jako pravidlo nad povrchem a vodou,
  6. vzorek jen ve slupce (1.2) a uložení jen rozdílu proti funkci (1.4).
- Validátor gen-v3 zůstává kontrolou, ne zdrojem tvaru.
- **Minerály, žíly, kras a dutiny** jsou útvary **ve funkci světa** (1.7), ne krok při vzorkování slupky. Dutina tak vypadá stejně, ať se k ní hráč prokope odkudkoli (Jan t815u, 20:50).


---

## 2.2 Rozhraní funkce světa a transformace vložení

**Téma.** Jak se funkce světa ptáme (bod, sloupec) a jak se do dotazu promítne vložení blueprintu (zrcadlení, otočení, posun výšky, prolnutí švů). Navazuje na návrh TerrainSource (E88).

**Současný stav**
- `geo_fn` umí dotaz v metrech: `surface_m`, `boundary_m`, `column` (povrch + hranice vrstev), `material` v bodě (X, Y, Z), `sample` do buněk. Kontext `world_fn` ale potřebuje **řídicí mřížku sousedních segmentů** (`hm_f`, `bs`). Chybí-li soused, okraj se zrcadlí. Rozteč řídicí mřížky je U = 0,5 m (vnitřní mřížka funkce, ne datová buňka, viz 1.1), šířka segmentu 8 m, výška sloupce 32 m jsou v kódu konstanty [6]. Proto E90 `geo_fn` na mapě 3 km nepoužilo [4].
- Výška světa je zvlášť v `lod90.h_m(x, y)`: vzorec E49 v metrech, nezávislý na rozlišení. Geologii, vodu ani sopku (v testu vypnutou) nezná [4].
- E88 (jen dokument, s Willage-backend neprojednáno) navrhuje čtyři objekty [7]:
  - **TerrainSource** — neměnná definice: seed světa, slot původu, recept, `block_seed`, `gen_ver`, zásobník, u výřezu hashe sousedů původu a prameny,
  - **TerrainTransform** — `rot` 0–3, `dz` v buňkách 0,5 m (tehdejší datová buňka; po 2026-11-21 je buňka 0,25 m, viz 1.1), `mirror` rezervované (vždy 0; zrcadlení se v E86 nezkoušelo),
  - **TerrainPlacement** — ostrov, slot, pořadí `seq`, `neighbours_before` na 4 hranách,
  - **TerrainInstance** — výsledek po napojení: hashe definice, prameny, obsazení výtoků, překryv.
- E88 měření (jeden segment 8 m bez sousedů, měřeno při buňce 0,5 m): řídicí mřížka po deflate 8,7–35 kB, buňky 0,5 m 1,4–2,2 kB (mřížka 5–25× větší) → mřížku neukládat. Segment bez změn hráče v návrhu WTI1 ≈ 400–450 B [7].
- E86: otočení **hotových dat** je přesné (0 neshod, ~5 ms). Vygenerovat výřez znovu v otočené poloze nejde (vrstvy o 2,1–3,4 m, 18,9–24,8 % buněk jinak). Co se z funkcí počítá znovu, musí jít **inverzní transformací do souřadnic původu**. Švy vrstev přeneseného výřezu skáčou o 1,8–2,7 m (už u rot 0, klíny ze sousedů původu) [8].
- E87: masiv jako funkce přes švy, pořadí vložení 0 neshod uvnitř masivu; vedle nížiny stěna 5–6 m a pořadí změní 2 000–2 700 buněk [9].
- Kapitola 1 už rozhodla tvar vložení (1.4): seznam v pořadí nese souřadnice, zrcadlení, otočení, výškový posun, režim napojení (Auto / Blend / Keep) a **seed i verzi zdrojového světa**. Sousedé se nemění. Ukládá se jen rozdíl proti funkci (1.10). Souřadnice 16 × 16 × 64 v E88 po 1.1 a 1.3 neplatí (K1, K3).

**Varianty rozhraní**

| | A: `geo_fn` dnes (kontext segmentu a sousedů) | B: `h_m` (jen výška, E90/E96) | C: jedno dotazové API + objekty E88 (Source / Transform / Placement / Instance) |
|---|---|---|---|
| dotaz na bod / sloupec | ano, ale potřebuje mřížku sousedů | jen výška | cíl: bod → materiál, sloupec → povrch + vrstvy + hladina |
| vložení | buňky se otočí až po vzorku | není | dotaz v souřadnicích původu inverzní transformací (E86) |
| uložení | dnes celé buňky segmentu | nic (jen funkce) | jen Source + Transform + Placement + rozdíl (1.4, 1.10) |
| stav | v kódu | v kódu, bez geologie | jen návrh [7] |

**Doporučení.** Varianta C. Jedno API funkce světa: dotaz na bod `(x, y, z)` vrátí materiál a dotaz na sloupec `(x, y)` vrátí povrch, hranice vrstev a hladinu podzemí, bez nutnosti mít předem mřížku sousedů. Vložení je Transform + Placement: výpočty jdou inverzní transformací do souřadnic zdrojového světa (E86). Řídicí mřížku neukládat (E88). Zrcadlení je v 1.4 povolené, i když v E86 chybí měření — do kontraktu ho dát a změřit v 2.7. Z jedenácti otázek E88 kapitoly 1 už zodpověděly podstatu 1, 2, 5, 9 a 10 (čistá funkce, bez mřížky, voda se jako celek neukládá, zrcadlení platí, švy se napojují režimem Auto / Blend / Keep). Otevřené zůstávají hlavně 3, 4, 6, 7, 8 a 11 (prameny při nové verzi, snímek buněk pro server, rohy, eroze v překryvu, práh plného přepočtu, tvar `gen_ver`) — ty patří do kapitol 3, 5 a 6, ne sem.

**Otázka pro Jana.** Má být rozhraní funkce světa jeden dotaz na bod a na sloupec v metrech (s inverzní transformací vložení), a objekty E88 (Source, Transform, Placement, Instance) základem uložení, aniž bychom ukládali řídicí mřížku?

**Platí:** *rozhodnuto (2026-11-20 20:52–20:53, Jan t816u, t817u)*

- **Jedno rozhraní funkce světa** v metrech, jediné místo, kde se zbytek hry ptá, co kde je (generátor slupky, voda, kontrola na serveru):
  - dotaz na **bod** `(x, y, z)` vrátí materiál,
  - dotaz na **sloupec** `(x, y)` vrátí povrch, hranice vrstev a hladinu podzemí.
- Funkce nepotřebuje předem mřížku sousedů. **Řídicí mřížka se neukládá** (E88).
- Vložený blok se počítá **inverzní transformací** (zrcadlení, otočení, posun) do souřadnic zdrojového světa (E86). Otočený nebo zrcadlený blok tak dá na stejný dotaz stejnou odpověď jako originál ve světě.
- Ukládá se jen popis vložení podle E88 (Source, Transform, Placement). Zrcadlení se změří v 2.7.
- Zbylé otázky E88 (3, 4, 6, 7, 8, 11) patří do kapitol 3, 5 a 6.


---

## 2.3 Slupka a líné generování

**Téma.** Jak poznat obnažené buňky, jaký je okraj zorného pole a kdy se donačtou hlubší buňky (kopání, voda).

**Současný stav**
- Rozhodnuto v 1.2: izometrický omezený výhled; generuje a vykresluje se jen **zorné pole plus okraj**; jen to, co je **obnažené vzduchem** (u průhledné vody i dno); slupka **2–3 buněk** (parametr) s mřížkou **0,25 m z funkce**; hlubší buňky až při odkrytí; podzemní voda zůstává funkcí.
- Hra to tak dnes nedělá. Segment 8 m se vyplní **celý sloupec** najednou (`FN.sample`, výška 64 buněk = 32 m) [1][6]. E96 proto generuje všech 256 segmentů při načtení (58–61 s) [2].
- E90 (prezentace, ale slupku změřilo): „povrchová slupka = vrchní buňka + 2 pod ní“ (3 × u8 na sloupec). Mapa 3 072 m, 832 512 sloupců, výšky a slupka ≈ 5,8 MB, stavba 4,9 s. Krok hráče o 16 m: 15 kousků + 35 sousedů, 296 ms. Odhad 1 m všude: ≈ 57 s, ≈ 2,6 GB sítě (síť je prezentace) [4]. TODO to formulovalo stejně: „vzorkuje se jen povrchová slupka (viditelné buňky + 1–2 vrstvy pod nimi), zbytek až při interakci“ [10].
- E85: vzorek 0,25 m z funkcí na **celý** segment 8 m je 442–784 ms (65–108× proti zjemnění 6,0–8,1 ms) a liší se v 7,8 % buněk [11]. V 1.2 se proto varianta „0,25 m všude“ (myšleno vzorek celého sloupce) zrušila ve prospěch slupky. Sjednocení datové buňky na 0,25 m (2026-11-21 00:19, 1.1) tohle nemění: pořád se vzorkuje jen slupka, ne celý sloupec.
- E96 návrh optimalizace načtení: nejdřív 3 × 3 segmenty u startu (~2 s), zbytek ve vlákně [2]. To je líné načítání segmentů, ne slupka uvnitř sloupce.
- Jak přesně určit „obnažené vzduchem“ a šířku okraje zorného pole v datech dnes není. E90 úroveň volilo podle **hráče**, ne podle kamery [4].

**Varianty**

| | A: celý sloupec při vložení segmentu (dnes) | B: slupka 2–3 buněk v zorném poli + okraj, zbytek při odkrytí (1.2) |
|---|---|---|
| kdy vznikají buňky 0,25 m | celý segment (E85 442–784 ms / 8 m) [11] | jen obnažený povrch a dno průhledné vody |
| hloubka | celý sloupec (32 m dnes, 128 m podle 1.3) | parametr 2–3 buněk |
| odkrytí | už je vygenerované | kopání nebo obnažení vodou donačte buňky z funkce |
| čas | 58–61 s na blok 128 m [2] | neměřeno na ostrově; E90 slupka 3 km bez geologie 4,9 s [4] |

**Doporučení.** Varianta B, jak je v 1.2. Obnažená buňka = má alespoň jednoho souseda vzduch, nebo leží na dně otevřené průhledné vody. Okraj zorného pole je parametr (pár polí kvůli pohybu). Generátor slupky volá stejné API jako 2.2. Při kopání nebo poklesu vody se z funkce donačtou nově obnažené buňky a jednou uložený rozdíl se nepřepočítává. Šířku okraje a přesný počet buněk slupky změřit v 2.7, nehádat.

**Otázka pro Jana.** Platí, že obnažená buňka je ta, která sousedí se vzduchem nebo tvoří dno průhledné vody, a že okraj zorného pole je jen parametr (pár polí), aniž bychom slupku předem vzorkovali do hloubky celého sloupce?

**Platí:** *rozhodnuto (2026-11-20 20:57–20:59, Jan t818u, t819u)*

- **Obnažená buňka** sousedí se vzduchem, nebo tvoří dno otevřené průhledné vody.
- **Viditelnou oblast určuje prezentace** podle zoomu a velikosti dlaždice (tilesetu). Datový model pevnou šířku zobrazení nezná, dostane jen obdélník světa, který je vidět.
- Generátor k oblasti přidá **okraj** (parametr v metrech nebo buňkách, ne v dlaždicích) a vzorkuje **slupku 2–3 buněk** (1.2).
- Při kopání nebo poklesu vody se nově obnažené buňky **donačtou z funkce**. Jednou uložený rozdíl se znovu nepočítá.
- ~~**Rozlišení 0,5 m je pro data a výpočty** (poměry, objemy, voda), ne pro zobrazení.~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19 (1.1): **datová buňka i viditelný voxel jsou 0,25 m**. Data, výpočty (poměry, objemy, voda, kopání, překryv) i dlaždice používají tutéž buňku 0,25 m. Prezentace může kreslit 2D dlaždice i 3D, ale rozlišení dat je stejné.
- Šířku okraje a počty buněk slupky změřit v 2.7, nehádat.
- **Poznámka pro kapitolu 7 (Jan t820u–t822u, 21:03–21:08):** viditelný voxel je **0,25 m** (postava 1,75 m = 7 voxelů). **128 / 256 / 512 px** je rozlišení textury dlaždice podle kvality a monitoru (Full HD, 2K, 27"), ne velikost dlaždice na obrazovce. Kolik terénu je vidět, určuje zoom. Datový model to neomezuje. Obrázek: `obrazky/voxel-meritko.png`.
- **Výchozí zoom (Jan t823u, t824u, 21:08–21:35):** v axonometrii kolem **64 dlaždic (voxelů 0,25 m) vodorovně**, tedy asi 16 m na šířku obrazovky (~30 px na voxel u Full HD, ~40 px u 2K).
- **Pevný zoom (Jan, hovor 20. 11. 2026):** zoom je pevný na 64 dlaždicích (voxelech 0,25 m) napříč. Je to v podstatě jediná úroveň detailu (LOD), v souladu s rozhodnutím 7.2 (`03-otevrene-body.md`): jedno rozlišení 0,25 m, bez úrovní LOD a bez zoomu.


---

## 2.4 Segment jako jednotka práce a ukládání rozdílu

**Téma.** Segment je jednotka výpočtu a ukládání rozdílu proti funkci (1.1, 1.4). Jaký má být formát rozdílu a jestli nechat 8 m, nebo zkusit 16 / 32 m.

**Současný stav**
- Segment je podle 1.1 parametr, výchozí **8 m** (32 × 32 buněk 0,25 m; dříve 16 × 16 buněk 0,5 m). Kandidáti 16 a 32 m se měli doladit v 1.11, ten je přeskočený.
- Dnes je segment i jednotka vložení, receptu, seedu, rotace a formátu WVB1 (K1, v kódu „blok“) [1][12]. E96 složilo blok 128 m z 256 takových segmentů [2].
- **Překryv E78** je kanonický rozdíl proti definici: buňka 0,25 m → materiál, položka rovná definici se maže. Uložení „seřazené klíče + deflate“. Čísla: 1 buňka 8 B (deflate 40 B → nekomprimovat), 1 000 náhodných 1 792 B, chodba 15 m + šachta 124 B, chodba 70 m přes 4 segmenty 244 B, nepravidelná jeskyně 663 B. Celé pole 0,25 m je 13,4–17,4 kB deflate na 4 segmenty [7][13].
- E88 / WTI1: segment 8 m bez změn hráče ≈ 400–450 B (hlavička, hashe, prameny). WVB1 pole 0,5 m je 1,4–2,2 kB deflate, měřeno při buňce 0,5 m [7].
- E96 k velikosti 16 / 32 m nic neměřilo pro data. Navrhlo slučovat **sítě** vegetace a terénu po 32 m — to je prezentace (kapitola 7) [2]. E90 kousky okolí hráče měly 16 m [4].
- Po 1.4 a 1.10 se neukládají vygenerované, ale nezměněné buňky. Prázdný segment je tedy jen odkaz na funkci (Source + Transform + Placement), ne pole buněk.

**Varianty velikosti segmentu**

| | 8 m (výchozí, 1.1) | 16 m | 32 m |
|---|---|---|---|
| segmentů v bloku 128 m | 256 | 64 | 16 |
| čas generování dnes (celý sloupec) | 224 ms / segment, 58–61 s na blok [2] | neměřeno | neměřeno |
| rozdíl E78 | čísla výše jsou z této velikosti [13] | neměřeno | neměřeno |
| práce ve slupce | jemná jednotka načítání | méně jednotek, větší okraj při pohybu | ještě hrubší |

**Doporučení.** Nechat výchozí **8 m** jako jednotku práce i rozdílu, protože jediné změřené velikosti překryvu i pipeline k ní patří. 16 a 32 m zůstanou parametry podle 1.1 a změří se v 2.7 (čas slupky, velikost rozdílu, voda). Formát rozdílu vzít z E78 (kanonický překryv 0,25 m, klíče + deflate) a z hlavičky WTI1 (verze, transformace, pořadí, hashe). Voda a vegetace v rozdílu jen tam, kde se liší od funkce (2.5, 2.6). Slučování sítí po 32 m nechat kapitole 7.

**Otázka pro Jana.** Necháme segment 8 m jako výchozí jednotku práce a rozdílu (formát E78 / WTI1) a 16 / 32 m jen jako parametry k měření? Nebo chceš výchozí velikost změnit už teď, bez nového měření?

**Platí:** *rozhodnuto (2026-11-20 21:08–21:35, Jan t823u, t824u)*

- **Segment 8 m** je výchozí jednotka práce i uložení rozdílu. Při výchozím zoomu (~16 m na šířku) jsou vidět asi 2 segmenty, s okrajem generátor drží zhruba 3×3 až 4×4 segmentů.
- **16 a 32 m** zůstávají parametry (1.1) a změří se v 2.7.
- **Formát rozdílu** z E78 (kanonický překryv 0,25 m, klíče + deflate), **hlavička** z WTI1 (verze, transformace, pořadí, hashe).
- Voda a vegetace v rozdílu jen tam, kde se liší od funkce (2.5, 2.6). Slučování sítí po 32 m patří do kapitoly 7.


---

## 2.5 Výchozí stav vody z funkce a její materializace

**Téma.** Kdy se z funkce vody (1.2, 1.8) stanou uložené metry krychlové v buňkách a co zůstane jen funkcí.

**Současný stav**
- Dnes je voda **odvozený stav**: po načtení se přepočítá, neukládá se. Zdrojem jsou prameny (`p76_prameny` je ukládá, bez nich se po načtení 4 z 5 pramenů přesunou), materiály a geometrie [7][14].
- Pipeline na konci nalije objem a vsákne ho gen-v3 (`infiltrate`) [1][15]. Herní ostrov pak staví vodu E68 (povrch priority-flood + D8, podzemí, bilance, události) [14].
- Prameny hledá `prameny.find` ze seedu / pravidel na už hotové výšce a materiálu: druhy sníh, kontakt, kras; na okraji ostrova se nenasazují. Ucpaný pramen neteče, po otevření teče znovu [16]. To odpovídá 1.8, až na to, že 1.8 přidává přenos vykopaného pramene jako předmětu.
- Časy: ostrov START (2 × 2 segmenty 8 m

---

### 30. Asistent (shrnutí uvažování)

Přemýšlel pár sekund

---

### 31. Asistent

Mám kapitolu **02 – Model světa a generování bloku 128 m**. Navazuje na rozhodnutí z kapitoly 01 a zatím obsahuje schválené body 2.1–2.4. Bod 2.5 je v zaslaném textu nedokončený.

Navr

---

### 32. Uživatel

# 03 – Otevřené body po kapitolách 1 a 2 (kostra k rozhodnutí)

Stav: **kostra**, 2026-11-20 21:55 SEČ. Kapitoly 1 a 2 jsou rozhodnuté (`01-principy-a-vstupy.md`, `02-model-sveta-a-generovani.md`, tip `7c6bb1f`). Tento soubor bere původně plánované kapitoly 3–8 z osnovy a nechává **jen body, které 1 a 2 ještě nerozhodly**. Pole **Platí:** je prázdné, vyplní se až po Janově rozhodnutí v chatu (t712u).

Pořadí bodů níže je podle důležitosti (nejdřív datový kontrakt a zbylá data, pak voda, prezentace, sloučení). V každé kapitole je nejdřív seznam **Už vyřešeno v kap. 1–2**, potom jen otevřené body. Úkoly, které už pravidlo mají a zbývá je napsat do kódu, jsou na konci v **Úkoly implementace (ne rozhodnutí)**.

Odložené z kapitoly 1, teď se znovu neptám: **přepočet při nové verzi generátoru** (1.5, t726u) a s ním otázka E88 č. 3 (prameny po nové verzi nechat, nebo najít znovu) [1][2]. Datový rozpočet výkonu (1.11) Jan přeskočil (t738u).

Značení: [n] = zdroj na konci. K1–K12 = konflikty z `00-mapa-vetvi.md`. Časy v SEČ, měření z boxu.

---

## Pořadí otevřených bodů

1. **6.1** Co server ověřuje a zda posílat snímek buněk (E88 č. 4) — společně s Willage-backend.
2. **6.3** Serverová kontrola a mazání ověřených dat (Jan, hovor 20. 11. 2026).
3. **6.2** Tvar verze generátoru `gen_ver` (E88 č. 11).
4. **4.1** Zapisovat erozi E51 do překryvu (E88 č. 7).
5. **5.1** Rohoví sousedé v kontraktu (E88 č. 6).
6. **5.2** Výchozí režim napojení švů (Auto / Blend / Keep) u přeneseného výřezu.
7. **3.2** Slučovat drobné výstupy v dosahu 8 m i mezi sebou?
8. **7.1** Pohled 2D (dlaždice), nebo 3D (modely)?
9. **7.2** LOD prezentační vrstvy.
10. **7.3** Průhlednost a řez v izometrii (E91).
11. **Klima** Konkrétní hodnoty klimatických presetů (násobitele, posuny, podíly reliéfních biomů, voda) mimo výchozí identitu mírného klimatu.

---

## 3. Voda (bývalá kapitola 3)

Původní plán: jeden algoritmus podzemí, oprava lokálního přepočtu, vlákno.

**Už vyřešeno v kap. 1–2**

- Práh pro plný přepočet vody (dřívější bod 3.1, E88 č. 8) je vyřešený v 1.9: voda se počítá asynchronně v pozadí s debouncem, lokální přepočet dává stejný výsledek jako plný a počítá se sjednocené povodí. Bod zrušen (Jan, hovor 20. 11. 2026).
- Výchozí podzemí E67 (`pretok`) → 1.8.
- Lokální přepočet = plný výpočet; okno je celé zasažené povodí; běží asynchronně na pozadí; prodleva 2 s, strop 10 s; fronta dalších výkopů; scénář „dva hráči“ → 1.9.
- Výchozí voda je funkce, po vygenerování světa v ustáleném stavu; prameny se ukládají; na ostrově se počítá na povodí; ukládá se jen odchylka → 1.2, 1.8, 2.5.
- Vsakování: tok = X × spád včetně výšky vody, mezi materiály minimum, čas 1 den = 1 h → 1.8.1.
- Eroze E51: práh `ero_v`, odnos průtok × (v/práh)^k, výchozí k = 1,5 → 1.8.2.
- Artéská voda jako funkce, materializace až po obnažení („jen pokud to model zvládne“) → 1.8.1.
- Otisk vody a uložení: voda v buňce je celé číslo litrů (1 B), ne surový float64 → 1.10 (E88 č. 5).
- Neobsazený pramen zvedá hladinu tělesa, obsazování je zapnuté, pramen se kreslí, dokud ho hráč nevykope, nenapojí nebo nezachytí → 1.8 (2026-11-20 01:49).

Oprava K5 (lokální ≠ plný v pěti větvích) a zrychlení podzemí jsou implementace rozhodnutého 1.9, ne nové rozhodnutí.

### 3.2 Slučování drobných výstupů mezi sebou

**Téma.** E72 slučuje drobné výstupy pod prahem k silnému výstupu do 8 m. Otevřené zůstalo, jestli se mají slučovat i **mezi sebou**, když silný v dosahu není [4][8].

**Současný stav**
- *rozhodnuto v E72:* práh `p67_prune_min` 0,1 l/s, dosah `p72_dosah_m` 8 m, `p72_prusak` zapnutý. Ostrov E67: 150 → 6 výstupů, součet 4,10 l/s beze změny. Po limitu 8 m je výstupů 6 → 18, protože 12 drobných po 0,02 l/s leží v řadě na okraji dál než 8 m od silného [8].
- 1.8.1 bere 8 m jako vzdálenost slučování drobných výtoků / pramenů, ne jako dosah průsaku. Slučování **mezi sebou** (do největšího ze skupiny) Jan ještě nerozhodl [4].

**Varianty**

| | A: jen k silnému v dosahu 8 m (dnes) | B: i mezi sebou do největšího ze skupiny, když silný není blízko |
|---|---|---|
| okraj ostrova (12 × 0,02 l/s) [8] | 12 samostatných výstupů | jedna skupina, součet stejný |

**Doporučení.** Varianta B: drobné výstupy v dosahu 8 m se sloučí do největšího ze skupiny i bez silného souseda. Součet průtoku zůstane, kreslení bude čistší. Dosah 8 m a práh 0,1 l/s se nemění.

**Otázka pro Jana.** Slučovat drobné výstupy v dosahu 8 m i mezi sebou do největšího ze skupiny, když silný výstup není blízko?

**Platí:** (Jan, hovor 20. 11. 2026) Práh je 0,1 l/s; jde o výchozí hodnotu volitelného parametru, který se dá ve hře měnit. Výtoky pod tímto prahem se slučují s jiným výtokem v dosahu 8 m, a to i mezi sebou, když poblíž není silný výstup.

---

## 4. Kopání a překryv (bývalá kapitola 4)

Původní plán: kopání a překryv 0,25 m, zákaz dna a okraje, ukládání.

**Už vyřešeno v kap. 1–2**

- Jemná mřížka 0,25 m z funkce jen ve slupce 2–3 buněk, hlubší buňky při odkrytí → 1.2, 2.3.
- Zákaz prokopání dna a okraje ostrova (`p85_okraj`) → 1.13.1, 1.10.
- Bok ostrova jen prezentace (5 m pod nejnižší okrajovou buňkou, oblaka, voda padá do oblak) → 1.13.1.
- Ukládá se jen rozdíl proti funkci, formát překryvu E78 (kanonické klíče + deflate), hlavička WTI1, segment 8 m → 1.4, 1.10, 2.4.
- Obnažená buňka sousedí se vzduchem nebo tvoří dno průhledné vody; donačtení z funkce, jednou uložený rozdíl se nepřepočítává → 2.3.

Hra dnes pořád kope po 0,5 m a vyplňuje celý sloupec — to je úkol implementace, ne rozhodnutí.

### 4.1 Eroze E51 do překryvu

**Téma.** Eroze mění povrch. Má se zapisovat do překryvu jako změna proti funkci, nebo do definice? (E88 otázka 7) [2].

**Současný stav**
- Překryv E78 nese konečný materiál buňky 0,25 m, kde se liší od definice. Zdroj pravdy o kopání je hráč. Voda a události definici ani překryv nemění, **výjimkou by byla eroze E51** [2][9].
- 1.8.2: eroze bere materiál nad prahem `ero_v`, odnos průtok × (v/práh)^1,5, čas jako události. Kras E75 se rozpouští podle průtoku.
- 1.4 a 2.4: ukládá se jen rozdíl proti funkci. Kdyby eroze měnila definici, ostrov by přestal být zopakovatelný ze seedu a seznamu vložení.
- Návrh E88: eroze jde jako událost `SurfaceChanged` do překryvu se zdrojem „eroze“, ne do definice. Voda v tom samém kroku změnu terénu nevydá, eroze se plánuje do budoucna (smyčka E68 zůstane konečná) [2].

**Varianty**

| | A: eroze mění definici / buňky napřímo (hrozí dnes) | B: eroze se zapíše do překryvu se zdrojem „eroze“ (návrh E88) |
|---|---|---|
| opakovatelnost ostrova | ne, funkce už nesedí | ano, rozdíl proti funkci |
| shoda s 1.4 / 2.4 | rozbíjí to | sedí |

**Doporučení.** ~~Varianta B. Eroze E51 (a rozpouštění krasu E75, které bere horninu) se zapisuje do stejného překryvu jako kopání, se zdrojem „eroze“.~~ ⚠ překonáno: eroze i kras během hry jdou vrstvou offsetu, ne překryvem buněk (viz Platí).

**Otázka pro Jana.** ~~Má se eroze E51 (a úbytek horniny krasem) zapisovat do překryvu jako změna proti funkci, se zdrojem „eroze“, a ne do definice terénu?~~ ⚠ překonáno, viz Platí.

**Platí:** (Jan, hovor 20. 11. 2026) Eroze se **neukládá** jako změněné buňky. Původní generátor terénu zůstává nedotčený a eroze je samostatná vrstva offsetu (posunu výšky), která se přičítá k výšce z původní funkce. Vzniká tak v podstatě druhá funkce s upraveným vstupem. Výpočet vody běží na výsledném terénu s offsetem. Výhody: minimální objem dat, erozi lze kdykoli vypnout nebo předělat bez zásahu do generátoru a voda se v prohlubních chová správně.
- **Doplněno (Jan 2026-11-21 00:24):** posun eroze **smí být kladný**. Terén může i růst (usazování, náplavy, delty), nejen ubývat.
- **Doplněno (Jan 2026-11-21 00:24):** kras během hry se ukládá **stejnou cestou offsetu**, ne jako změna materiálu na vzduch v překryvu buněk. Jan: „Zkusíme jít cestou offsetu.“ V kroku 7 se ověří, jestli offset stačí i pro podzemní dutiny.

---

## 5. Přenos výřezu (bývalá kapitola 5)

Původní plán: otočení, švy vrstev, prameny.

**Už vyřešeno v kap. 1–2**

- Vložení nese zrcadlení, otočení, výškový posun, režim napojení (Auto / Blend / Keep), seed a verzi zdrojového světa; sousedé se nemění → 1.4.
- Výpočty jdou inverzní transformací do souřadnic původu; zrcadlení je povolené a změří se v testu 2.7 → 2.2, E86 [10].
- Švy na ostrově: vrstvy se zaklíní nebo napojí na úseku 1/16 bloku (8 m při bloku 128 m) → 1.7.1 (E88 č. 10).
- Prameny výřezu se přenášejí uložené (`p76_prameny`); hráč je může ucpat, vykopat a položit jinde → 1.8, 2.5, E76 [11].
- Řídicí mřížka se neukládá; čistá funkce světa, bez hashe sousedů původu jako zdroje tvaru → 2.2 (E88 č. 1, 2, 9).

Otočení hotových dat je změřené (0 neshod, ~5 ms). Skok vrstev 1,8–2,7 m u přeneseného výřezu se řeší režimem napojení z 1.7.1, ne novým principem [10]. Zbývá vybrat **výchozí režim** a jestli do kontraktu patří i rohy.

### 5.1 Rohoví sousedé v kontraktu

**Téma.** `neighbours_before` dnes nese jen 4 hrany. Mají do kontraktu patřit i rohy? (E88 otázka 6) [2].

**Současný stav**
- Pravidlo z 2026-11-17: sousedé se nemění, přizpůsobí se jen nový blok. E83: blok závisí jen na sousedech položených před ním na **4 hranách**. Diagonála (roh) a vzdálený blok mění **0 buněk**. 12/12 bitově, dva procesy stejně [12].
- Pořadí vložení mění výsledek záměrně (~1,9 % buněk u švů; u masivu vedle nížiny 2 000–2 700 buněk) — proto se `seq` a `neighbours_before` ukládají [2][12][13].

**Varianty**

| | A: jen 4 hrany (dnes, E83) | B: 4 hrany + 4 rohy |
|---|---|---|
| vliv na buňky | roh mění 0 buněk [12] | kontrakt větší, výsledek stejný |
| opakovatelnost | stačí 4 hrany + `seq` | stejná |

**Doporučení.** Varianta A: v kontraktu zůstanou jen 4 hrany. Rohy do `neighbours_before` nedávat, E83 ukázalo, že výsledek nemění.

**Otázka pro Jana.** Stačí v uloženém vložení jen 4 hranoví sousedé (jak je to dnes a jak změřilo E83), nebo mají do kontraktu patřit i rohy?

**Platí:** (Jan, hovor 20. 11. 2026) **Zavrženo.** Rohoví sousedé se neřeší. Bloky se napojují vždy jen po stranách (v osách), nikdy diagonálně přes roh.

---

### 5.2 Výchozí režim napojení švů

**Téma.** 1.4 zavádí režimy Auto / Blend / Keep, 1.7.1 určuje klín na 1/16 bloku. Není rozhodnuté, který režim je výchozí, když hráč vloží otočený nebo cizí blueprint (šev vrstev v E86 skáče o 1,8–2,7 m) [10].

**Současný stav**
- Přenesený výřez nese klíny ze sousedů **původu**, ne z nových sousedů na ostrově. Bloky vygenerované na místě mají šev vrstev 0 U. U výřezu (i rot 0) je skok 1,8–2,7 m proti kroku uvnitř 0,7–1,15 m [10].
- 1.7.1: pořadí vrstev na švu ostrova se nemusí shodovat; vrstvy se zaklíní nebo napojí na úseku 1/16 bloku.
- Keep by skok nechal být. Blend by ho vzal klínem z 1.7.1. Auto je v prototypu definované (`block_gen.gd`: rozdíl ≤ 6 buněk dorovná rampou na 3 buňkách, větší nechá jako útes, po sloupcích).

**Varianty**

| | Keep | Blend (klín 1/16 bloku, 1.7.1) | Auto |
|---|---|---|---|
| šev výřezu 1,8–2,7 m [10] | ostane skok | zaklíní se na 8 m | podle pravidla (návrh: Blend, když by skok přesáhl 1 buňku, jinak Keep) |

**Doporučení.** ~~Výchozí **Blend**: klín nebo napojení na 1/16 bloku podle 1.7.1. Keep jen když ho hráč u daného vložení výslovně zvolí. Auto zatím nezavádět, dokud ho nebude potřeba jako zkratku.~~ ⚠ překonáno: výchozí je Auto; Blend má dvě nezávislá nastavení (povrch 1–4 buňky, vrstvy klín 1/16 bloku), viz Platí (2026-11-21 00:24).

**Otázka pro Jana.** Má být výchozí napojení švu při vložení blueprintu Blend (klín na 1/16 bloku podle 1.7.1) a Keep jen na výslovnou volbu?

**Platí:** (Jan, hovor 20. 11. 2026) Výchozí režim je **Auto**. Auto se rozhoduje podle rozdílu výšek v každém sloupci zvlášť: rozdíl do 6 buněk vyhladí rampou na 3 buňkách, větší rozdíl nechá jako útes. Blend a Keep zůstávají jako volitelné alternativy. Počty 6 a 3 buněk pocházejí z prototypu s buňkou 0,5 m (3 m a 1,5 m). Po sjednocení buňky na 0,25 m se zachovávají vzdálenosti v metrech (Jan 2026-11-21 00:35): rozdíl do 3 m (12 buněk) vyhladí rampou na 1,5 m (6 buněk), větší rozdíl zůstane útesem.
- **Doplněno (Jan 2026-11-21 00:24):** Blend má **dvě nezávislá nastavení**. Napojení povrchu je rampa na 1–4 buňkách. Napojení podzemních vrstev je klín, výchozí 1/16 bloku (1.7.1).

---

## 6. Kontrakt se serverem (bývalá kapitola 6)

Původní plán: kontrakt WTI1, společně s Willage-backend.

**Už vyřešeno v kap. 1–2**

- Klient generuje a simuluje, server ukládá, načítá a validuje → 1.10.
- Server ukládá a posílá seed, parametry, verzi generátoru, seznam vložení a rozdíl proti funkci (ne hotová pole segmentů). WVB1 je balík změn segmentu. Namátková kontrola generátorem jde vypnout → 1.10 (t801u–t803u).
- Voda v buňce: krok 1/16 l, hodnota 0–250 = 0–15,625 l, 1 B, 251–255 rezerva (Jan 2026-11-21 00:39; záloha 2 B). Determinismus povinný, změny i vložení nesou verzi → 1.5, 1.10 (sjednoceno s buňkou 0,25 m, Jan 2026-11-21 00:19).
- Objekty Source / Transform / Placement, bez řídicí mřížky, zrcadlení platí → 2.2.
- Výška sloupce a velikost segmentu jsou parametry (32/64/128 m a 8/16/32 m), ne natvrdo 16 × 16 × 64 → 1.1, 1.3, 1.10.

Návrh E88 s Willage-backend **ještě nebyl projednán** [2]. Body 6.1 a 6.2 jsou návrh k tomu jednání, ne konečné pravidlo bez backendu. Spolu s nimi se k backendu vezme už rozhodnutý základ z 1.10 a 2.2. Otázka E88 č. 3 zůstává odložená s 1.5.

### 6.1 Co server ověřuje a snímek buněk

**Téma.** Má klient posílat serveru snímek buněk 0,5 m (tehdejší datová buňka; po 2026-11-21 00:19 je buňka 0,25 m, viz 1.1) a v položce překryvu i původní materiál definice, aby server spočítal souhrn přesně? (E88 otázka 4) [2].

**Současný stav**
- 1.10: při zapnuté kontrole server občas znovu vygeneruje segment ze seedu + změn a porovná hash. Při vypnuté kontrole jen ukládá a kontroluje **bilanci materiálu**.
- E88: bez portu generátoru server nevidí geometrii, jen souhrn a hashe. Návrh volitelné sekce `cells_snapshot` (buňky 0,5 m po deflate, 1,4–2,2 kB na segment 8 m, měřeno při buňce 0,5 m) a +1 B původního materiálu v položce překryvu [2].
- Překryv E78 jinak nese jen nový materiál. Souhrn „co ubylo / přibylo“ server z rozdílu bez původního materiálu nebo bez generátoru přesně nesloží [2][9].

**Varianty**

| | A: jen hash a bilance; snímek ne (generátor jen při zapnuté kontrole) | B: A + původní materiál v položce překryvu (+1 B) | C: B + povinný snímek buněk 0,5 m (1,4–2,2 kB, měřeno při buňce 0,5 m) |
|---|---|---|---|
| server bez generátoru | hrubá bilance | přesný souhrn změn | přesný souhrn i náhled buněk |
| velikost | jako E78 [9] | +1 B na položku | +1,4–2,2 kB vždy [2] |

**Doporučení.** Varianta B jako základ pro jednání s Willage-backend: položka překryvu nese i původní materiál definice, aby šla bilance spočítat bez generátoru. Snímek buněk 0,5 m nechat **volitelný** (ladění a servery bez portu generátoru), ne povinný na každém uložení. Namátková kontrola z 1.10 se nemění. Po 2026-11-21 00:19 by volitelný snímek nesl buňky 0,25 m; číslo 1,4–2,2 kB je měření při 0,5 m.

**Otázka pro Jana.** Má položka překryvu nést i původní materiál definice (kvůli bilanci na serveru) a snímek buněk zůstat jen volitelný? (V otázce stálo „snímek buněk 0,5 m“; po 2026-11-21 00:19 je datová buňka 0,25 m.) Tento bod se má projednat s Willage-backend.

**Platí:** (Jan 2026-11-21 00:10, po vyjádření Willage-backend) Ostrov = seed + parametry + verze generátoru (`Vmajor.minor`) + seznam vložení + rozdíl proti funkci. Položka překryvu nese i původní materiál buňky (+1 B) a umí i odchylku vody. Snímek buněk je jen volitelný (ladění) a nikdy není zdroj pravdy. Formát balíku změn je verzovaný a nesmí se plést se starým WVB1 jako celým polem buněk (WVB1 v2 nebo WTI1, hlavička podle 1.1 a 1.3). Kontrola generátorem jde vypnout. Kontrola se provádí vždy proti pinované verzi ostrova, nikdy proti novějšímu generátoru.

---

### 6.2 Tvar verze generátoru

**Téma.** Je `gen_ver` jedno číslo pro celý klient, nebo profil příznaků, ze kterého server pozná, co se změnilo? (E88 otázka 11) [2].

**Současný stav**
- 1.5: uložené změny i každé vložení nesou verzi generátoru. Jak přepočítat svět při nové verzi, je odložené. Determinismus je povinný.
- E88: každý přepínač terénu (`p85`, `p87`, …) je nová verze. `gen_ver` je v návrhu u16. Bez profilu server nepozná, jestli šlo o opravu švu, nebo o jinou funkci hor [2].
- K4: dřívější rozhodnutí „nová verze přepočítá i staré bloky“ (03:26) proti E80 (přepočet rozbije okolí výkopů: 313 z 1 787 buněk, 32 položení ve skále) je právě to, co 1.5 odložilo [12][14]. Tvar pole `gen_ver` tím ale není zodpovězený.

**Varianty**

| | A: jedno číslo u16 (návrh E88) | B: číslo + uložený profil příznaků / parametrů, které verze mění |
|---|---|---|
| místo v hlavičce | 2 B | číslo + krátký odkaz / seznam |
| server pozná, co se změnilo | ne, jen „je jiná“ | ano |
| přepočet (až se 1.5 otevře) | vše, nebo nic | lze cílit jen dotčené části |

**Doporučení.** Varianta B: v datech zůstane jedno číslo `gen_ver`, ale každá verze má dokumentovaný profil (které parametry a pravidla mění). Server i klient podle čísla profil najdou. Samotný přepočet starých ostrovů se teď neotevírá (1.5).

**Otázka pro Jana.** Má `gen_ver` zůstat jedno číslo, ke kterému patří dokumentovaný profil změn (aby server poznal, co je jiné), aniž bychom teď rozhodovali o přepočtu starých ostrovů?

**Platí:** (Jan, hovor 20. 11. 2026) Verze generátoru se zapisuje ve tvaru `Vmajor.minor`: velké V, číslo před tečkou je hlavní verze (zásadní, nekompatibilní změna), číslo za tečkou je minoritní verze (drobná změna) a přičítá se postupně. Číslo zůstává jednoduché na uložení a porovnání. Význam změny (nekompatibilní, nebo drobná) se nese v metadatech verze nebo v poznámce ke commitu. Přepočet starých ostrovů zůstává odložený (1.5).

---

### 6.3 Serverová kontrola a mazání ověřených dat

**Téma.** Jak dlouho server drží původní hodnoty změněných buněk a co s nimi udělá po kontrole (navrhl Jan v hovoru 20. 11. 2026).

**Návrh Jana**
- Server je jediný zdroj pravdy.
- Klient ke každé změněné buňce pošle i její původní hodnotu: 1 B materiálu na změněnou buňku (navazuje na 6.1, varianta B).
- Server dělá namátkovou kontrolu v nastaveném časovém intervalu (parametr).
- Buňky, které kontrolou projdou, se po ověření smažou nebo vynulují. Shoda je výchozí stav a jejich data už nejsou potřeba.
- Buňky, kde kontrola najde rozpor, se nemažou. Data zůstanou, protože se rozpor musí dořešit a server k nim má referenci pro pozdější spor.
- Tím se ušetří místo a zůstává mechanismus pro odhalení podvodu.

**Otázka pro Jana.** Platí tento postup jako pravidlo kontraktu? Projedná se spolu s 6.1 s Willage-backend.

**Platí:** (Jan 2026-11-21 00:10, po vyjádření Willage-backend; doplněno 2026-11-21 00:24) Kontrola není namátková. Změny se sbírají do **zásobníku**; kontrola doběhne, když je zásobník plný, nebo po uplynutí časového intervalu, podle toho, co nastane dřív. Obě meze jsou parametry. Zvláštní kontrola rud při každém zápisu není. (Nahrazuje dřívější formulaci „interval nebo počet změn“.) Po úspěšné kontrole se smaže **jen pole původního materiálu**; položka změny (nová hodnota a voda) zůstává, jinak by se vracel výkop. Pole se po ověření vynechá, nenuluje (0 = vzduch). Při přijetí změny se pohyb materiálu zapíše do účetní knihy hráče a ostrova, protože po smazání původních hodnot zůstane jen čistý rozdíl vůči funkci. Záznamy s rozporem se nemažou a zůstávají jako reference pro spor. K úspěšné kontrole se uloží krátký otisk (čas, gen_ver, segment, hash, počet buněk). Kontrola nepřegenerovává celý segment při kopání. Kontrola je ve výchozím stavu zapnutá (Jan 2026-11-21 00:18). Když se vypne, server věří inventáři od klienta.

---

## 7. Prezentační vrstva (bývalá kapitola 7)

Původní plán: co čte z dat, LOD, průhlednost, řez, 2D/3D.

**Už vyřešeno v kap. 1–2**

- Datový model je v metrech a na 2D/3D nezávisí; ~~buňka 0,5 m = 1 dlaždice~~ **buňka 0,25 m = 1 dlaždice** jako jediný most k zobrazení → 1.1 (t710u, t715u; sjednoceno Jan 2026-11-21 00:19).
- Viditelnou oblast dává p

---

### 33. Asistent

Mám i dokument **02 – Model světa a generování bloku 128 m** a **03 – Otevřené body po kapitolách 1 a 2**. Beru je jako historické podklady k aktuálnímu modelu V1.0, nikoli jako automaticky platnou specifikaci.

Důležitá věc: dokument 03 obsahuje několik rozhodnutí, která už jsou v aktuálním modelu z 23. 11. zapracovaná, ale také některé formulace, které

---

### 34. Uživatel

# 04 – Implementace generátoru V1.0

Stav: **návrh k odsouhlasení**, 2026-11-20 23:50 SEČ. Podklad pro stavbu nové verze generátoru podle kapitol 1–3. Žádné rozhodnutí se tu nemění ani nepřidává. Kde dokument narazí na rozpor nebo chybějící rozhodnutí, odkáže na přílohu A.

**Verze.** Nový generátor dostane `gen_ver` = **V1.0** (tvar `Vmajor.minor` podle 6.2). Je to první verze, která staví na sjednoceném modelu, a s dnešními bloky není kompatibilní (jiná velikost bloku, výška sloupce, ukládání jen rozdílu). Proto hlavní číslo 1. Kroky 1–9 běží pod označením V1.0-vývoj. Číslo V1.0 se uzavře až po povinném testu 2.7 (krok 10).

**Zásady pořadí**
- Od základů nahoru. Každý krok staví jen na předchozích a nic hotového se v pozdějším kroku nepřepisuje.
- Datový model je nezávislý na zobrazení. Prezentace přijde až v posledním kroku a z dat jen čte.
- Kód se nepíše znovu, kde už existuje. U každého kroku je uvedeno, odkud se bere (větev a soubor).
- Testy jsou jen lokální (Godot 4.7.2 headless na boxu, `/workspace/tools/Godot_v4.7.2-stable_linux.x86_64`, Python skripty). Žádné CI ani GitHub Actions.
- Výchozí hra se kontroluje otiskem `voda_e66` (d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod) a `port_studie --check` (0 změn). Kde krok výchozí hru mění záměrně (od kroku 2 dál, nový generátor), vznikne nová reference a stará se zapíše do reportu.

**Stavy:** *hotovo v kódu* = existuje a odpovídá rozhodnutí; *částečně* = kód je, ale jinak nebo jen na studijní větvi; *jen rozhodnuto* = pravidlo je v dokumentu, kód není; *otevřené* = chybí rozhodnutí.

---

## Přehled kroků

| Krok | Obsah | Stav | Závisí na | Schválení |
|---|---|---|---|---|
| 1 | Základy: jednotky, rozměry, verze, tabulka materiálů, determinismus | částečně | – | Jan po kroku |
| 2 | Funkce světa I: API, mapa biomů a hornin, reliéf, masiv, sopky, klima (presety) | částečně | 1 | Jan po kroku |
| 3 | Funkce světa II: geologie a útvary | částečně | 2 | Jan po kroku |
| 4 | Funkce světa III: podzemní voda a prameny jako funkce | částečně | 3 | Jan po kroku |
| 5 | Vložení blueprintu a ostrov | částečně | 2–4 | Jan po kroku |
| 6 | Buňky: slupka, kopání, rozdíl a ukládání | částečně | 5 | Jan po kroku |
| 7 | Voda na ostrově: simulace, eroze, přepočet | částečně | 6 | Jan po kroku |
| 8 | Povrchové jevy klimatu (písek, led, sníh, výpar, zamrzání) | jen rozhodnuto | 7 | Jan po kroku |
| 9 | Vegetace jako funkce a vrstva změn | částečně | 7–8 | Jan po kroku |
| 10 | Povinný test 3 × 3 a uzavření V1.0 | jen rozhodnuto | 1–9 | Jan: ano do main |
| 11 | Kontrakt se serverem | otevřené (6.1 zápis, 6.3 backend) | 6, 10 | Jan + Willage-backend |
| 12 | Prezentace | jen rozhodnuto (7.1 odloženo) | 10 | Jan po kroku |

---

## Krok 1 – Základy: jednotky, rozměry, verze, materiály, determinismus

**Obsah**
- Jednotky v metrech a jeden převod l → m³: převzít modul `scripts/jednotky.gd` a `scripts/voda/litry.gd` z větve `e94-metry` (E89 + E94, otisky beze změny).
- Nový modul rozměrů modelu V1.0 (vedle dnešních konstant, které hra zatím potřebuje): blok 128 m, segment 8 m (parametr 8 / 16 / 32), buňka 0,25 m, výška sloupce jako výčet 32 / 64 / 128 m (výchozí 128 m = 512 buněk), neutrální úroveň v polovině, maximální svět 4096 m, výchozí svět 3 × 3 bloky. Kontrola pravidla mocnin 2 a dělitelnosti (1.1, 1.3, 1.4).
- `gen_ver` ve tvaru `Vmajor.minor`: čtení, porovnání, uložení (6.2). Výchozí hodnota V1.0.
- Jedna tabulka materiálů: `materialy.csv` (78 id) jako jediný zdroj, načítání podle id, kontrola (unikátní id 0–255, rozsahy, propustnost podle vzorce (log10 K + 9) / 6) (1.6). Konflikty starých seznamů se jen vypíšou, opraví se v kroku 3, kde se tabulka poprvé použije pro geologii.
- Pravidla determinismu na jednom místě: float64, řazené klíče, celočíselné hashe (`stable_hash.gd`, main) (1.5).

**Odkud kód:** `e94-metry` 96f2310 (jednotky, litry, převod scény na metry), `main` 0e8aa00 (`stable_hash.gd`), `docs/sjednoceni/materialy.csv`.

**Proč tady:** všechny další kroky používají jednotky, rozměry, id materiálů a verzi. Kdyby se měnily později, přepisovalo by se všechno nad nimi.

**Stav:** částečně. Jednotky a litry hotové na `e94-metry` (mimo main). Rozměry V1.0, verze a načítání tabulky jen rozhodnuto. Výška sloupce je dnes natvrdo 32 m (`BH` 64).

**Testy**
1. *Výchozí hra beze změny* (`tools/voda_e66.gd`, `tools/port_studie.py --check`): otisk d7aedf3a6d9d10e8 → 63d7b89a91385a79 a 0 neshod; port 0 změn. Prošlo = obojí shodné.
2. *Jednotky* (`tools/jednotky_e89.gd`, `tools/litry_e94.gd` z `e94-metry`): tam a zpět pro hustoty 16–128, l → m³ bez rozdílu bitů. Prošlo = 0 chyb, 0 rozdílných bitů.
3. *Rozměry V1.0* (nový `tools/zaklad_v1.gd`): všechny kombinace výšky 32/64/128 a segmentu 8/16/32 projdou kontrolou, neplatné (např. blok 100 m) se odmítnou; index buňky tam a zpět na celém segmentu při sloupci 128 m. Prošlo = 0 chyb, neplatné kombinace odmítnuté.
4. *Verze* (`zaklad_v1.gd`): čtení a porovnání `V1.0 < V1.1 < V2.0`, chybný zápis odmítnut. Prošlo = všechny případy správně.
5. *Tabulka materiálů* (`tools/materialy_v1.py`): unikátní id, rozsahy, vzorec propustnosti, porovnání se `sdilene/materialy_voda.json` v4. Graf propustnosti podle materiálu (PNG). Prošlo = 0 chyb tabulky; nalezené konflikty se jen vypíšou do reportu.
6. *Determinismus*: dva procesy Godotu dají stejný hash rozměrů, verze a tabulky. Prošlo = shoda.

**Velikost:** malý (1–2 h práce agenta).

---

## Krok 2 – Funkce světa I: rozhraní, mapy, reliéf, masiv, sopky a klima

**Obsah**
- Jedno rozhraní funkce světa v metrech: dotaz na bod `(x, y, z)` → materiál, dotaz na sloupec `(x, y)` → povrch, hranice vrstev, hladina (2.2). V kroku 2 vrací povrch a biom, vrstvy a hladinu doplní kroky 3 a 4 bez změny rozhraní.
- Mapa biomů (varianta C) a mapa hornin: hrubé body ze seedu na maximální ploše 4096 m, plynulá interpolace (2.1, 1.7.1).
- Reliéf z parametrů členitosti podle biomu: převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu (1.13). Žádné šablony povrchu, `p94_hora_k` ani omezovač E92 (1.4). Když se převýšení pod strop nevejde, tvar se roztáhne do šířky a výška zůstane. V přechodu biomů platí vážený průměr stropů. Drobné tvary do 2 m (parametr) smí strop překročit (Jan 2026-11-21).
- Masiv E87 a podhůří u jeho stěny jako součást funkce (1.4, úkol 10 v kap. 3).
- Sopky: počet a rozteč jako parametry světa, polohy ze seedu, tvar mezi strato a štítovou (sklon ~17°), velikost mezi 20 m / 1 blok a 40 m / 2 bloky, kráter, vrchol aspoň 5 m pod okrajem sloupce (1.14). Výchozí svět 3 × 3 zůstává uprostřed maxima, alespoň jedna sopka těsně vně výřezu (Jan 2026-11-21).
- Klima: načtení tabulky presetů, uplatnění základního klimatu (a háček pomalé mapy) **před** generováním reliéfu (1.15). Povrchové jevy klimatu do tohoto kroku nepatří (krok 8, po vodě).

**Odkud kód:** `lod90.gd` (`h_m`, E90/E96, větve `e95-async-voda` a `e96-blok128`), masiv `geo2.gd` + `geo_fn.gd` z `e87-jadro-hory` ff97a9f, sopka a biomy z `teren/svet/hruby_teren.gd` (E49, main), `blok96.gd` (E96) jako vzor sestavení bloku 128 m z funkce.

**Proč tady:** povrch a biom jsou vstup pro geologii (vrstvy podle terénu), vodu i vegetaci. Musí být hotové a pevné dřív než cokoli, co z nich čte.

**Stav:** částečně. Výšková funkce existuje (E90/E96), masiv jako funkce (E87, jen na větvi), sopka jen jako kužel E49. Mapa biomů a hornin podle 2.1 jen rozhodnuto.

**Testy**
1. *Spojitost*: výška na hranici bloků a segmentů bez skoku (rozdíl 0 m). Obrázek řezu přes šev (`tools/rez_profil.py`). Prošlo = 0 skoků.
2. *Sklony*: histogram sklonů (p50, p95, max) proti stropu sklonu (graf PNG). Prošlo = max sklonu **celkového tvaru** (bez drobného detailu) ≤ vážený strop přechodu + tolerance. Překročení detailem se zaznamená, není to chyba.
3. *Sopky*: počet = parametr, rozteč ± tolerance, vrchol ≤ okraj sloupce − 5 m, kráter na vrcholu, alespoň jedna sopka těsně u výchozího 3 × 3. Mapa výšek s vyznačenými sopkami (PNG). Prošlo = všechna kritéria.
4. *Mapy biomů a hornin*: obrázek map na 4096 m a výřez 3 × 3 (`blueprint-studie/tools/gif_svet8.py` jako vzor). Prošlo = plynulé přechody, různé seedy dají různé mapy. Varianta větších oblastí biomů je jen srovnání za přepínačem (výchozí vyp), ne rozhodnutí.
5. *Determinismus*: hash mřížky výšek 3 × 3 ze dvou procesů. Prošlo = shoda.
6. *Čas*: dotaz na sloupec a výšky bloku 128 m (graf). Kritérium jen záznam, cíl je srovnání s E90 (4,9 s / 3 km).
7. *Klima*: výchozí preset `mirne` (identita) zachová otisk výšek výchozího světa. Vynucený jiný preset svět deterministicky změní (shoda ve dvou procesech). Obrázek stejný seed: mírné / poušť / ledovec.

**Velikost:** střední až velký.

---

## Krok 3 – Funkce světa II: geologie a útvary

**Obsah**
- Pásma vrstev z úrovní 0–40 (`poradi_hornin.json`), 1–3 zástupci podle mapy hornin, vrstvy podle tvaru terénu, vyklínění, mocnost min. 1 buňka (0,25 m, Jan 2026-11-21 00:34) a max. 1/4 výšky (1.7, 1.7.1).
- Mince E82 (jeskynní a hluboký vápenec a dolomit 50/50 až 2 m pod hladinu) a vyklínění jílu nad ní (1.8).
- Útvary jako funkce celého světa přes švy (SDF z hashe světové mřížky, E84): žíly, pně, skarny, dómy, kras, dutiny, minerály. `cavity_one` se ruší (1.7, 2.1).
- Sopka uvnitř: průduch id 75 od kráteru po z = 0, kuželovité slupky lávy a popela, těleso vrstvy propíchne (1.14).
- Oprava konfliktů id v tabulce materiálů a přemapování pásem krajiny id 57–74 (úkol 5 v kap. 3).

**Odkud kód:** `geo_fn.gd`, `strata.gd`, `geo2.gd` (main, E87), nástroj `tools/implicit_e84.gd` (SDF, `zkusebni-vse`), `tools/vapenec_e82.gd` a změny E82 (`e82-vapenec-hladina`), `tools/tenke_e81.gd`, `minerals.gd`, `hostitele.gd`, `tridy.gd` (main).

**Proč tady:** geologie potřebuje povrch z kroku 2 a sama je vstupem pro podzemní vodu (propustnost, hladina) v kroku 4. Mapování materiálů se opraví tady, protože tu se tabulka poprvé opravdu používá.

**Stav:** částečně. Vrstvy a klíny jsou v pipeline, ale po segmentech a s mřížkou sousedů. SDF útvary jen jako studijní nástroj E84. Mince E82 na větvi. Průduch a slupky sopky jen rozhodnuto.

**Testy**
1. *Řezy*: svislé řezy přes šev bloků, přes masiv a přes sopku (`tools/rez_gif.py`, `rez_profil.py`, `rez_data.gd`). Prošlo = vrstvy přes šev spojité, u sopky končí na tělese, průduch dosahuje z = 0.
2. *Tenké vrstvy*: počet vrstev tenčích než 0,5 m po ořezu povrchem (`tenke_e81.gd`). Prošlo = 0 v definici; zbytky po ořezu se jen vypíšou.
3. *Útvary přes šev*: stejný útvar z obou stran švu, stejná dutina při dotazu z různých bloků (`implicit_e84.gd`). Prošlo = 0 rozdílů.
4. *Mince vápence*: podíl bloků „ano“ (`vapenec_e82.gd`). Prošlo = 50 % ± statistická odchylka na 3 × 3 a víc seedech.
5. *Čas*: ms na segment (graf proti E84 ~89 ms). Kritérium jen záznam.
6. *Determinismus*: hash materiálů na mřížce 3 × 3 ze dvou procesů. Prošlo = shoda.

**Velikost:** velký.

**Návrhy na zlepšení** (Jan 2026-11-21 23:52, po měření kroku 3: segment 8 m / 0,25 m / 128 m 2614 ms, srovnatelný s E84 521 ms proti 89 ms, samotné `hranice` 531 ms)
- Hranice vrstev počítat na řídící mřížce geologie 0,5 m a mezi body interpolovat; dnes se zbytečně počítají po 0,25 m. Odhad zrychlení ~4×, výsledek se nemá měnit.
- Výšku terénu a mapu hornin spočítat jednou na segment a držet v mezipaměti, místo výpočtu pro každý sloupec znovu ze seedu.
- Později nejtěžší výpočty šumu přesunout do C# nebo GDExtension (typicky 10–50×), větší zásah.
- Ověřit na samostatné větvi, schválí Jan.

---

## Krok 4 – Funkce světa III: podzemní voda a prameny

**Obsah**
- Hladina podzemí a propustnost jako funkce geologie, bez uložených buněk (1.2, 2.5). Výchozí model podzemí E67 (1.8).
- Prameny ze seedu: druhy, poloha, jmenovitý výkon; skutečný výkon omezený okolím; jednoduchý model výchozí, tlakový pod přepínačem (1.8).
- Artéská voda jako funkce sevřené vrstvy, jen ověřit, „pokud to model zvládne“ (1.8.1).

**Odkud kód:** `voda/podzemi/gw74.gd`, `ug67.gd`, `ug_funkce.gd`, `voda/prameny.gd` (main), převod litrů z kroku 1.

**Proč tady:** voda potřebuje geologii z kroku 3 a sama ještě nepotřebuje buňky. Je to poslední část funkce světa, takže krok 5 může vkládat blueprinty s kompletní funkcí.

**Stav:** částečně. `gw74`, `ug67` a `prameny.gd` jsou v main, ale pracují nad buňkami segmentu 8 m, ne nad funkcí světa. Jmenovitý výkon, tlakový model a artéská voda jen rozhodnuto.

**Testy**
1. *Hladina jako funkce*: mapa hladiny podzemí na 3 × 3 (PNG) a řez s hladinou (`rez_profil.py`). Prošlo = hladina spojitá přes švy, nikde nad povrchem mimo prameny a jezera.
2. *Prameny*: počet, druhy, žádný na okraji ostrova, výkon ≤ jmenovitý a ≤ propustnost okolí (tabulka). Prošlo = všechna pravidla.
3. *Artéská voda*: aspoň jeden případ sevřené vrstvy, tlaková výška = výška doplňování. Neprošlo = zapíše se jako „model nezvládne“, ne chyba.
4. *Determinismus*: hash hladiny a seznamu pramenů ze dvou procesů. Prošlo = shoda.

**Velikost:** střední.

---

## Krok 5 – Vložení blueprintu a ostrov

**Obsah**
- Objekty Source, Transform, Placement (E88): ostrov = seed + parametry + verze + seznam vložení v pořadí. Vložení nese souřadnice blueprintu ve světě, zrcadlení, otočení, výškový posun, režim napojení, seed a verzi zdrojového světa (1.4, 2.2).
- Inverzní transformace: dotaz na vložený blok se přepočte do souřadnic zdroje (2.2, E86).
- Napojení jen po stranách, rohy se neřeší (5.1). Výchozí režim Auto (rozdíl ≤ 6 buněk rampa na 3 buňkách, větší útes, po sloupcích), volitelně Blend a Keep (5.2). Blend má dvě nezávislá nastavení: povrch rampa 1–4 buňky a podzemní vrstvy klín (výchozí 1/16 bloku, 1.7.1).
- Sousedé se při vložení nemění.

**Odkud kód:** `teren/otoceni86.gd` a `tools/otoceni_e86.gd` (`e86-otoceni-90`), režimy napojení z `block_gen.gd` (`BLEND_MAX` 6, main) a `island.gd` (výběr režimu stran), `teren/sides.gd`, návrh objektů `navrhy/navrh-terrainsource-kontrakt.md` (`e88-kontrakt-navrh`).

**Proč tady:** vložení pracuje nad hotovou funkcí světa (kroky 2–4) a ještě nepotřebuje buňky. Krok 6 pak vzorkuje už vložený, napojený blok.

**Stav:** částečně. Otočení hotových dat změřené (0 neshod), dotaz inverzní transformací jen v nástroji E86. Režimy Auto / Blend / Keep jsou v prototypu jen pro povrch. Zrcadlení neměřeno. Objekty E88 jen návrh.

**Testy**
1. *Inverzní transformace*: otočený a zrcadlený blok dá na stejný dotaz stejnou odpověď jako originál (`otoceni_e86.gd`, rozšířit o zrcadlení). Prošlo = 0 neshod pro rot 0–3 × zrcadlení.
2. *Režimy švu*: řez přes šev pro Auto, Blend (povrch i vrstvy) a Keep (obrázek, `rez_profil.py`). Prošlo = Auto: rozdíl ≤ 6 buněk dorovnán na 3 buňkách, větší zůstane; Blend povrchu: rampa na zvoleném počtu 1–4 buněk; Blend vrstev: klín na zvolené délce (výchozí 1/16 bloku); Keep: beze změny; sousedé beze změny (0 buněk).
3. *Pořadí vložení*: blok závisí jen na sousedech na 4 stranách položených před ním (`determinismus_e83.gd`). Prošlo = roh a vzdálený blok mění 0 buněk, dva procesy shodně.
4. *Cizí svět*: vložení blueprintu s jiným seedem a verzí. Prošlo = načte se a napojí bez chyby.

**Velikost:** střední.

---

## Krok 6 – Buňky: slupka, kopání, rozdíl a ukládání

**Obsah**
- Generuje se jen zorné pole + okraj (parametr) a slupka 2–3 buněk u vzduchu a pod průhlednou vodou, buňka 0,25 m přímo z funkce (1.2, 2.3).
- Obnažená buňka sousedí se vzduchem nebo je dnem průhledné vody. Hlubší buňky se donačtou při odkrytí (2.3).
- Kopání po 0,25 m (úkol 8 v kap. 3). Zákaz prokopání dna a okraje (`p85_okraj`, 1.13.1).
- Ukládá se jen rozdíl proti funkci po segmentech 8 m: překryv E78 (klíče + deflate), hlavička WTI1 s `gen_ver`, transformací a pořadím (2.4). Ostrov se uloží a načte jako seed + parametry + verze + seznam vložení + rozdíl (1.4, 1.10).
- Pole „původní materiál“ (+1 B) se v překryvu jen připraví za přepínačem, vypnuté, dokud nebude zapsané 6.1.

**Odkud kód:** `teren/prekryv78.gd` a `tools/prekryv_e78.gd` (`e78-prekryv` / `zkusebni-vse`), slupka z E90 (`lod90.gd`, výpočet „vrchní buňka + 2 pod ní“), `p85_okraj` (`e85-blok2-rozhodnuti`, `tools/okraj_hra_e85.gd`), formát WVB1 (`navrhy/format-bloku-wvb1.md`), hlavička WTI1 (E88).

**Proč tady:** buňky vznikají až z hotového vloženého bloku (krok 5). Simulace vody (krok 7), povrchové jevy klimatu (krok 8) a vegetace (krok 9) potřebují buňky a uložený rozdíl.

**Stav:** částečně. Překryv E78 hotový na studijní větvi. Slupka jen pro výšku (E90). Hra kope po 0,5 m a vzorkuje celý sloupec. Zákaz dna a okraje hotový na větvi E85.

**Testy**
1. *Slupka*: počet buněk a čas slupky v zorném poli + okraj (graf podle velikosti okraje). Prošlo = žádná neobnažená buňka mimo slupku, každá obnažená ve slupce.
2. *Donačtení*: po výkopu se nové buňky shodují s funkcí. Prošlo = 0 rozdílů.
3. *Rozdíl*: velikosti překryvu (prázdný ostrov, 1 buňka, chodba 70 m, jeskyně) proti E78 (`prekryv_e78.gd`, graf). Prošlo = prázdný ostrov = jen hlavičky; chodba 70 m řádově ~244 B.
4. *Uložit a načíst*: ostrov po výkopech se uloží, načte a dá bitově stejné buňky. Prošlo = shoda hashů.
5. *Dno a okraj*: počet děr ve dně a okraji po náhodném kopání (`okraj_hra_e85.gd`). Prošlo = 0.
6. *Paměť*: RSS bez scény na bloku 128 m (graf proti E96 345 MB). Kritérium jen záznam.

**Velikost:** velký.

---

## Krok 7 – Voda na ostrově: simulace, eroze, přepočet

**Obsah**
- Výchozí podzemí E67 a kras E75 zapnutý (úkol 9 v kap. 3).
- Pravidla vsakování 1.8.1: zrušit násobitel `p71_cas` × 24, spád včetně výšky vody, spojení materiálů = minimum, boční tok X × spád (úkoly 1–3).
- Eroze: `e51_k` = 1,5 (úkol 4) a eroze jako samostatná vrstva posunu výšky nad funkcí, ne změněné buňky (4.1). Posun smí být kladný (usazování, náplavy, delty) i záporný. Voda počítá na terénu s posunem.
- Kras během hry se ukládá stejnou cestou offsetu, ne jako vzduch v překryvu buněk. **V tomto kroku se ověří**, jestli offset stačí i pro podzemní dutiny (Jan 2026-11-21 00:24: „Zkusíme jít cestou offsetu“).
- Přepočet: lokální = plný na sjednoceném povodí (oprava K5 včetně `p79_chodby` a `p85_voda`), asynchronně na pozadí, prodleva 2 s, strop 10 s, fronta výkopů (1.9, úkoly 6–7).
- Slučování výtoků pod prahem 0,1 l/s (laditelný parametr) v dosahu 8 m, i mezi sebou (3.2).
- Výchozí voda v ustáleném stavu po vygenerování, uloží se jen odchylka v krocích 1/16 l, hodnota 0–250 = 0–15,625 l (1 B) (2.5, 1.10).

**Odkud kód:** `voda/hydro68.gd`, `ostrov_voda.gd`, `ug67.gd`, `kras75.gd`, `prameny.gd`, `eroze/mech.gd` (main), `voda/async95.gd` a `tools/async_e95.gd` (`e95-async-voda`), `tools/chodby_e79.gd` (`e79-chodby-voda`), slučování E72 (`p72_*`, main).

**Proč tady:** simulace potřebuje buňky a rozdíl z kroku 6. Eroze jako posun výšky potřebuje hotovou vodu. Povrchové jevy klimatu (krok 8) a vegetace (krok 9) potřebují znát tůně a koryta.

**Stav:** částečně. E67, kras, E68 a E72 jsou v main (E67 a kras vypnuté). Asynchronní voda jen na `e95-async-voda`, nikdy neběžela s blokem 128 m. K5 neopravené. Eroze dnes mění buňky (`mech.gd`), vrstva posunu jen rozhodnuto.

**Testy**
1. *Lokální = plný* (`voda_e66.gd` s chodbami a vyšší horou, scénáře E94 a E95). Prošlo = 0 neshod (dnes 162 a 43/38).
2. *Bilance*: součet přítoků a odtoků. Prošlo = ≤ 1e-12 l/s.
3. *Asynchronní běh*: blokování hlavního vlákna a čas do výsledku (graf, `async_e95.gd`). Prošlo = blokování < 1 ms; výsledek po frontě shodný s plným výpočtem.
4. *Scénář „dva hráči“*: časová řada průtoku v korytě po ucpání pramene (graf). Prošlo = voda nezmizí naráz, odtéká postupně, tůně zůstanou.
5. *Výtoky*: počet výstupů před a po slučování (E72: 150 → 6 → 18). Prošlo = součet průtoku beze změny, drobné výtoky v dosahu 8 m sloučené.
6. *Eroze*: vypnutí vrstvy posunu vrátí terén bitově na funkci; řez koryta po erozi i po usazení (obrázek). Prošlo = shoda po vypnutí; kladný posun zvedne povrch, záporný ho sníží.
7. *Kras offsetem*: dutina vzniklá během hry se uloží ve vrstvě posunu, ne jako vzduch v překryvu. Prošlo = po vypnutí offsetu je materiál funkce zpět; ověření, zda offset stačí i pod povrchem, se zapíše do reportu (zkusit cestu offsetu).
8. *Us

---

### 35. Asistent

Dokument 04 mám. Je to důležitý posun: na rozdíl od předchozích dokumentů už neřeší jen vlastnosti modelu, ale převádí rozhodnutí kapitol 1–3 do konkrétního implementačního plánu, včetně zdrojových souborů, testů a pořadí prací.

**Zatím ho ale nepovažuji za schválený implementační kontrakt.** Budu ho porovnávat s aktuálním stavem V1.0 z 23. 11. 2026.

### První zjištění – důležité rozpory a rizika

| Oblast | Co uvádí dokument 04 | Stav vůči aktuálnímu modelu |
|---|---|---|
| Krok 1 – determinismus | Float64, řazené klíče, celočíselné hashe | Nedostatečné. Samotný Float64 nezaručuje bitovou shodu GDScript/C#. |
| Krok 2 – reliéf | Biom určuje členitost, masiv a sopky | Odpovídá aktuálnímu modelu. Musí zůstat `add` a `separate`. |
| Krok 3 – geologie | Vrstevní hranice počítat na mřížce 0,5 m | Zajímavá optimalizace, ale zatím neprokázaná ekvivalence výsledků. |
| Krok 3 – mocnost vrstev | Minimum 0,25 m, maximum 1/4 výšky | Odpovídá rozhodnutému modelu. |
| Krok 4 – podzemní voda | Převést E67/GW74 na funkci světa | Správný směr. Je nutné zachovat oddělení funkce od materializovaných buněk. |
| Krok 5 – blueprint | Source / Transform / Placement | Odpovídá aktuálnímu kontraktu. |
| Krok 6 – slupka | Slupka 2–3 buňky, segment 8 m | Odpovídá. Pozor na to, že 0,25 m platí pro celý datový model, ne jen vykreslení. |
| Krok 7 – voda | Offset eroze a krasu | Odpovídá rozhodnutí, ale musí se prokázat, zda výškový offset stačí i pro změny podzemních dutin. |
| Krok 10 – test | 3 × 3 bloky, následné složení blueprintů | Odpovídá aktuálnímu povinnému integračnímu testu. |

### Tři problémy, které bych řešil před implementací

**1. Determinismus musí být samostatná technická vrstva.**

V dokumentu je determinismus zatím popsaný příliš stručně. Doplnil bych:

- celočíselné souřadnice a transformace,
- pevně definovaný hash a `DomainId` pro jednotlivé subsystémy,
- přesné pravidlo zaokrouhlování a kvantizace,
- zákaz závislosti na pořadí iterace `Dictionary`,
- společné testovací vektory pro Godot/GDScript a C#,
- kontrolní hashe mezivýsledků, nejen finálního světa.

**2. Optimalizace geologie na 0,5m mřížce nesmí změnit význam funkce.**

Výpočet hranic vrstev na 0,5 m může být dobrý kompromis. Musí se ale rozlišovat:
- přesnost souřadnic,
- rozlišení interního výpočtu,
- rozlišení výsledných datových buněk.

Datová buňka zůstává 0,25 m. Pokud interpolace hranic změní materiál některých buněk, není to pouhá optimalizace bez změny výsledku.

**3. Krok 7 má příliš mnoho kritických změn najednou.**

Současně se má opravit lokální přepočet vody, zavést asynchronní běh, změnit erozi na offset, zapnout kras a ověřit podzemní dutiny. Doporučuji je implementovat a testovat odděleně, aby bylo možné přesně určit původ případné chyby.

---

### Předběžný závěr

Dokument 04 je použitelný jako základ implementačního plánu. Neměnil bych pořadí kroků 1–10, ale před samotnou realizací bych zpřesnil determinismus, hranice geologických vrstev a rozdělení vodní simulace.

Důležité je také zachovat jednu zásadu: **funkce světa je zdroj pravdy, buňky jsou její materializovaná reprezentace a prezentace je až další nezávislá vrstva.**

Další užitečný krok bude dokončit registr rozdílů mezi dokumenty 00–04 a aktuálním modelem V1.0, aby se z historických prototypů omylem nestala nová pravidla.

---

### 36. Uživatel

# Sjednocení Willage – osnova

Začátek: Jan 2026-11-20 14:08 SEČ (t709u): „Máme teď hodně větví a variant výpočtů… Budeme tedy teď sepisovat aktuálně finální stav. Vezmeme to od začátku a napříč větvemi zkusíme vybrat nejvhodnější řešení. Můžeme otevřít i starší otázky a přehodnotit i některé už rozhodnuté.“

Upřesnění od Jana:
- **t710u:** jde o **datový model světa**. Vzhled je jen základní, materiály se rozliší barvou. Jestli bude pohled 2D (dlaždice), nebo 3D (modely), není rozhodnuté, takže datový model na tom nesmí záviset. Vykreslování, LOD, průhlednost a shadery tvoří prezentační vrstvu.
- **t712u:** rozhodnutí padají v chatu s Janem a teprve potom se zapíšou sem. Kapitoly jsou kostry, pole **Platí:** se vyplňuje až po rozhodnutí.

## Jak se s tím pracuje

1. Ke každému bodu kapitoly je současný stav, varianty z větví s čísly, doporučení a otázka.
2. Body se s Janem procházejí po jednom v pořadí níže.
3. Po rozhodnutí se do pole **Platí:** zapíše pravidlo s datem a citací Jana. Nahradí-li to starší rozhodnutí, uvede se i ono.
4. Teprve podle vyplněných kapitol se slučují větve. Každé sloučení má vlastní PROP a kontrolu výchozí hry, nebo novou referenci, pokud se výchozí hra mění záměrně.
5. Na větvi `sjednoceni` jsou jen dokumenty. Do main až s Janovým ano.

## Soubory

| Soubor | Obsah | Stav |
|---|---|---|
| [`00-mapa-vetvi.md`](00-mapa-vetvi.md) | všechny větve a studie, přepínače, čísla, rozhodnutí, konflikty K1–K12, prezentační vrstva | hotový podklad |
| [`materialy.csv`](materialy.csv) | návrh jedné tabulky materiálů (78 id, přibližné hodnoty, `~` = odhad) | návrh k 1.6 |
| [`01-principy-a-vstupy.md`](01-principy-a-vstupy.md) | kapitola 1: pojmy, jednotky, výška sloupce, funkce světa, determinismus a verze, materiály, geologie, voda, přepočet vody, kontrakt, datový rozpočet, objektová vrstva, profil ostrova | rozhodnuto (přepočet verze 1.5 odložen, 1.11 přeskočeno) |
| [`02-model-sveta-a-generovani.md`](02-model-sveta-a-generovani.md) | kapitola 2: pořadí kroků generátoru, rozhraní funkce světa, slupka, segment a rozdíl, výchozí voda, vegetace, test 3 × 3 | rozhodnuto |
| [`03-otevrene-body.md`](03-otevrene-body.md) | zbývající otevřené body po kapitolách 1–2, podle původních kapitol 3–8 (voda, kopání, přenos výřezu, kontrakt WTI1 společně s Willage-backend, prezentace, plán slučování) | kostra, čeká na Jana |

## Pořadí bodů kapitoly 1 k projití s Janem

1. **1.1 Pojmy:** ostrov, blok, segment, buňka; hierarchie ukládání ostrov → blok → segment → buňka, ostrov jako jednotka ukládání, svět (1.4) se s ostrovem nesmí zaměňovat; datová buňka 0,25 m = 1 dlaždice – *rozhodnuto 2026-11-20 (t713u, t714u), doplněno (t741u–t743u), buňka sjednocena 2026-11-21 00:19*.
2. **1.3 Výška sloupce:** výčet 32 / 64 / 128 m, výchozí 128 m (512 buněk po 0,25 m), neutrální úroveň v polovině – *rozhodnuto 2026-11-20 (t716u, t717u), přepočteno 2026-11-21 00:19*.
3. **1.4 Zdroj pravdy o terénu:** herní svět ze spojité funkce bez vlastních bloků, blueprint řezáním, segmenty ukládají buňky; výchozí velikost 3 × 3 bloky, maximum 4096 × 4096 m (parametr), ostrov se rozšiřuje vkládáním; ostrov procedurální = seed + parametry + verze + seznam vložení (nese i seed a verzi zdrojového světa), ukládá se jen rozdíl proti funkci – *rozhodnuto 2026-11-20 (t718u, t719u), doplněno (t744u–t749u, t761u–t762u, t801u–t803u)*.
4. **1.2 Jednotky a jemná mřížka:** procedurální svět; generuje se jen zorné pole + okraj a slupka 2–3 buněk u vzduchu (0,25 m z funkce), hlubší buňky až při odkrytí, podzemní voda jako funkce – *rozhodnuto 2026-11-20 (t799u, t800u)*.
5. **1.5 Verze generátoru:** determinismus povinný, změny a vložení nesou verzi (t801u–t803u); přepočet při nové verzi *odložen 2026-11-20 (t726u)*.
6. **1.9 Přepočet vody:** lokální = plný, výřez na povodí + asynchronně na pozadí, prodleva 2 s / strop 10 s; testovací scénář „dva hráči“ (postupné odtékání po zastavení přítoku) – *rozhodnuto 2026-11-20 (t734u, t735u), doplněno (t776u–t778u)*.
7. **1.8 Voda jako data:** obsah buňky v m³, povrch priority-flood + D8, výchozí podzemí E67, čas 1 den = 1 h; vsakování: propustnost X v l/s herního času při spádu 1, skutečný tok = X × spád včetně výšky vody, min dvou materiálů; artéská voda; pramen (jmenovitý výkon omezený okolím, jednoduchý / tlakový model); eroze E51 (práh `ero_v`, odnos průtok × (v/práh)^k, výchozí k = 1,5) – *rozhodnuto 2026-11-20 (t732u), doplněno (t765u–t785u)*.
8. **1.11 Datový rozpočet:** *přeskočeno 2026-11-20 (t738u)*.
9. **1.6 Materiály:** jedna tabulka, jedno id – *rozhodnuto 2026-11-20 (t727u)*, návrh `materialy.csv`.
10. **1.7 Geologie:** útvary jako funkce světa přes švy, vrstvy podle terénu, vyklínění; skladba vrstev, mapa složení na maximální ploše (hrubé body ze seedu, interpolace), 1–3 zástupci v pásmu, min. 1 buňka (0,25 m, Jan 2026-11-21), švy 1/16 bloku – *rozhodnuto 2026-11-20 (t732u), doplněno (t750u–t763u)*.
11. **1.12 Objektová vrstva:** terén a rostliny po segmentu (otáčejí se s blokem), stavby a cesty seznam na ostrově, smějí přes hranici bloku – *rozhodnuto 2026-11-20 (t739u, t740u), změněno (t741u–t743u)*.
12. **1.10 Kontrakt:** WVB1 základ, data po segmentech, voda v krocích 1/16 l, 0–250 = 0–15,625 l (1 B), server ukládá seed, parametry, verzi, seznam vložení a rozdíl proti funkci, namátkově kontroluje generátorem (vypínatelné) – *rozhodnuto 2026-11-20 (t736u, t737u), změněno (t801u–t803u), rozsah vody 2026-11-21 00:19*.
13. **1.13 Profil a členitost terénu:** parametry členitosti (rozhodnuto); bok ostrova jen prezentace: bloky s texturou 5 m pod nejnižší okrajovou buňkou, v té výšce oblaka, voda padá do oblak – *rozhodnuto 2026-11-20 (t805u–t807u)*.
14. **1.14 Sopka:** neaktivní, události ji probudí a uspí; tvar mezi strato a štítovou (sklon 17°); větší 40 m / 2 bloky, nižší 20 m / 1 blok; vrchol aspoň 5 m pod okrajem sloupce; počet a rozteč jako parametry světa (2, 3 bloky); průduch id 75 a kuželovité vrstvy lávy a popela, těleso se propíchne běžnými vrstvami jako skalní jádro (rozhodnuto).

## Pořadí bodů kapitoly 2

1. **2.1 Pořadí kroků generátoru:** funkce světa (reliéf a sopky) → geologie a útvary (sopka vrstvy propíchne) → výchozí voda jako funkce → vegetace ze seedu; buňky až ve slupce; minerály a dutiny jako útvary funkce.
2. **2.2 Rozhraní funkce světa:** dotaz na bod a sloupec v metrech, objekty E88 (Source / Transform / Placement / Instance), inverzní transformace vložení, řídicí mřížka se neukládá.
3. **2.3 Slupka a líné generování:** obnažené buňky (vzduch, dno průhledné vody), okraj zorného pole jako parametr, donačtení při odkrytí.
4. **2.4 Segment a rozdíl:** výchozí 8 m, formát E78 / WTI1, 16 / 32 m jen jako parametry k měření.
5. **2.5 Výchozí voda:** zůstává funkcí, počítá se ve slupce nebo na povodí, ukládají se prameny a odchylky.
6. **2.6 Vegetace:** funkce seedu (hustota na m²), ve slupce, na disk jen změny.
7. **2.7 Testovací pipeline 3 × 3:** svět → 9 blueprintů → ostrov; měření slupky, rozdílu, vody a determinismu. Stavět až po rozhodnutí 2.1–2.6.

## Pořadí otevřených bodů (kapitoly 3–8, jen to, co 1–2 nerozhodly)

1. **6.1** Co server ověřuje a zda posílat snímek buněk (E88 č. 4) — společně s Willage-backend.
2. **6.3** Serverová kontrola a mazání ověřených dat.
3. **6.2** Tvar verze generátoru `gen_ver` (E88 č. 11).
4. **4.1** Zapisovat erozi E51 do překryvu (E88 č. 7).
5. **5.1** Rohoví sousedé v kontraktu (E88 č. 6).
6. **5.2** Výchozí režim napojení švů (Auto / Blend / Keep).
7. **3.2** Slučovat drobné výstupy v dosahu 8 m i mezi sebou?
8. **7.1** Pohled 2D (dlaždice), nebo 3D (modely)?
9. **7.2** LOD prezentační vrstvy.
10. **7.3** Průhlednost a řez v izometrii (E91).

Odložené (teď se neptám): přepočet při nové verzi generátoru (1.5) včetně E88 č. 3; datový rozpočet 1.11. Úkoly implementace jsou na konci `03-otevrene-body.md`, nejsou to rozhodnutí.

## Legenda

- **rozhodnuto (datum)** = Jan rozhodl, s citací. ⚠ = novější měření to zpochybňuje.
- **K1–K12** = konflikty z `00-mapa-vetvi.md` §6.
- **Blueprint** = otisk oblasti herního světa o velikosti jednoho bloku (128 m). Vložený blueprint je blok ostrova.
- **[n]** = zdroj ze seznamu na konci kapitoly (soubor a commit).
- Časy jsou v SEČ (Europe/Prague). Měření jsou z boxu (Linux x86_64), telefon zatím není změřený.

---

### 37. Asistent

Tento dokument je zásadní, protože vysvětluje **metodiku sjednocování Willage a původ jednotlivých rozhodnutí**. Díky němu lze lépe rozlišit, co Jan skutečně schválil, co je pouze návrh implementace a co zůstalo otevřené.

Po jeho porovnání s dokumenty 00–04 bych zavedl následující pravidla pro další práci.

## 1. Jakou autoritu mají jednotlivé dokumenty

| Dokument | Role v projektu | Autorita |
|---|---|---|
| 00 – Mapa větví | Historie experimentů, měření a konfliktů | Historický podklad |
| Sjednocení – osnova | Metodika rozhodování a evidence | Procesní pravidla |
| 01 – Principy a vstupy | Schválený datový model | Normativní specifikace |
| 02 – Model světa | Schválená architektura generování | Normativní specifikace |
| 03 – Otevřené body | Rozhodnutí a zbývající úkoly | Smíšená – podle stavu bodu |
| 04 – Implementace V1.0 | Návrh realizace | Implementační návrh, nikoli automaticky schválený |

**Při rozporu má přednost poslední výslovné rozhodnutí Jana, nikoli novější dokument nebo existující implementace.**

To je důležité zejména proto, že dokument 04 obsahuje odkazy na konkrétní větve a commity. Ty jsou zdrojem existujícího kódu, ne automaticky schválenou podobou nového generátoru.

## 2. Co osnova potvrzuje v aktuálním modelu

<badge color="success">Potvrzeno</badge>

- Datový model je nezávislý na 2D/3D prezentaci.
- Svět je spojitá procedurální funkce.
- Blueprint je otisk oblasti světa o velikosti 128 × 128 m.
- Segment má výchozí velikost 8 × 8 m.
- Buňka má velikost 0,25 m.
- Ostrov je seed, parametry, verze, seznam vložení a rozdílová data.
- Generátor používá inverzní transformaci pro vložené blueprinty.
- Geologické útvary jsou funkcí světa, nikoli výsledkem náhodného generování při kopání.
- Výchozí voda a podzemní voda jsou odvozené z funkce světa.
- Buňky se materializují pouze v potřebném rozsahu a slupce.
- Přepočet vody musí zachovat ekvivalenci lokálního a referenčního výpočtu.

## 3. Co je potřeba aktualizovat v registru rozhodnutí

Několik bodů z dokumentu 03 už má konkrétní rozhodnutí. Neměly by proto zůstávat vedené jako otevřené.

| Bod | Aktuální stav | Doplnění do registru |
|---|---|---|
| 3.2 Slučování výtoků | Rozhodnuto | I drobné výtoky lze slučovat mezi sebou v dosahu 8 m. |
| 4.1 Eroze | Rozhodnuto | Samostatný výškový offset, kladný i záporný. |
| 5.1 Rohoví sousedé | Rozhodnuto | Napojení pouze po stranách. |
| 5.2 Napojení švů | Rozhodnuto | Auto jako výchozí, Blend a Keep volitelné. |
| 6.1 Serverový kontrakt | Rozhodnuto | Rozdíl proti funkci, auditní původní materiál do kontroly. |
| 6.3 Serverová kontrola | Rozhodnuto | Dávková kontrola podle zaplnění zásobníku nebo časového intervalu, nikoli namátková. |

Zvlášť bych opravil formulaci v dokumentu 01, která stále uvádí namátkovou kontrolu generátorem. Pozdější rozhodnutí 6.3 ji nahradilo.

## 4. Rozdíly mezi osnovou a aktuálním V1.0

Tady jsou čtyři místa, která bych nepřehlédl.

**A. Determinismus**

Osnova říká, že determinismus je povinný, ale sama o sobě neurčuje dostatečně přesný technický profil. Dokument 04 ho redukuje na Float64, řazené klíče a celočíselné hashe. To nestačí pro garantovanou bitovou shodu GDScript/C#.

Je potřeba doplnit samostatný deterministický kontrakt.

**B. Reliéf a masiv**

Novější rozhodnutí upřesňuje skládání reliéfu:

\[
H = H_\text{base}+H_\text{massif}+H_\text{volcano}
\]

Masiv je samostatná komponenta (`separate`), nikoliv dodatečné škálování základního reliéfu.

**C. Geologie**

Dokument 04 navrhuje výpočet hranic vrstev na 0,5m řídicí mřížce. To zatím není schválená optimalizace. Musí projít testem, že interpolace nezmění výslednou materiálovou klasifikaci buněk.

**D. Serverový kontrakt**

Dokument 04 označuje krok 11 jako otevřený. To je částečně zastaralé: základní pravidla už jsou rozhodnutá. Otevřená zůstává především konkrétní implementace zápisu, validace a koordinace s Willage-backend.

---

## 5. Doporučený stav dokumentů

| Dokument | Doporučená akce |
|---|---|
| 00 | Zachovat jako historický podklad |
| Osnova | Zachovat jako metodiku, doplnit odkazy na pozdější rozhodnutí |
| 01 | Zachovat, následně sjednotit s V1.0 |
| 02 | Zachovat jako schválenou architekturu |
| 03 | Aktualizovat stav rozhodnutých bodů a otevřených úkolů |
| 04 | Zachovat jako návrh implementace, opravit zastaralé formulace |

## 6. Důležitý závěr pro další postup

Osnova potvrzuje, že jsme neměli začít implementací podle toho, co už existovalo v `main`. Správný postup je nejprve definovat výsledný model, potom z existujících větví vybrat použitelné části a nakonec je integrovat.

Proto bych nyní ještě neslučoval větve. Nejprve bych vytvořil **jeden konsolidovaný registr V1.0**, který bude obsahovat:

1. Schválená pravidla a jejich původ.
2. Nahrazená historická rozhodnutí.
3. Implementační úkoly.
4. Otevřená technická ověření.
5. Odložené otázky.
6. Testovací kritéria pro uzavření V1.0.

Tím získáme jedno místo, podle kterého se bude implementovat, aniž by agent musel interpretovat několik dokumentů a rozhodovat, který z nich má přednost.

**Navrhuji pokračovat dokumentem 05, pokud následuje.** Po jeho zpracování už můžeme sestavit konsolidovaný registr bez předčasného uzavírání dosud nedodaných částí specifikace.

---

### 38. Uživatel

Můžeš mi zhodnotit to, co jsem ti poslal?

---

### 39. Asistent

Ano. A když se na to podívám jako na celek, nejen jako na technickou specifikaci generátoru, ale také jako na způsob, jakým řídíš vývoj Willage, moje hodnocení je poměrně pozitivní.

**Považuji to za velmi dobrý základ pro vývoj procedurálního světa.** Největší přínos ale není v konkrétních algoritmech. Je v tom, že ses pokusil oddělit rozhodnutí o datovém modelu od experimentování s implementací. To je u projektu, který má tolik historických větví a prototypů, zásadní.

Vidím ovšem několik míst, která bych nepodceňoval. Některá jsou architektonická, jiná mohou způsobit problémy až při přechodu z Godotu do C#.

# 1. Hodnocení celého přístupu

<box border radius="lg" gap={3} padding={3}>
  <title size="2xl" color="success">8,5 / 10</title>
  **Velmi dobrá architektonická koncepce, před implementací vyžaduje několik zpřesnění.**
  <divider color="subtle"/>
  {#each [{n:"Koncepce datového modelu",v:9.5},{n:"Oddělení dat a prezentace",v:10},{n:"Procedurální generování",v:9},{n:"Práce s historickým kódem",v:9},{n:"Determinismus a kompatibilita",v:6.5},{n:"Výkonnostní plán",v:7.5},{n:"Persistence a serverový kontrakt",v:8}] as item}
    <box gap={1}>
      <row align="center" justify="between">
        **{item.n}**
        <text tabularNums weight="semibold">{item.v}/10</text>
      </row>
      <box background="surface-tertiary" height="7px" radius="full" clip>
        <box height="7px" radius="full" width={`${item.v*10}%`} background={item.v>=9?"#16A34A":item.v>=8?"#3985D6":"#D69B35"}/>
      </box>
    </box>
  {/each}
  <caption color="secondary">Moje expertní hodnocení koncepce podle dodaných dokumentů, nikoli audit skutečného zdrojového kódu.</caption>
</box>

## Co považuji za nejpovedenější

### A. Svět jako funkce, nikoliv jako uložená geometrie

Tohle je podle mě nejdůležitější rozhodnutí celého projektu.

Místo toho, aby sis ukládal celý svět jako obrovskou strukturu buněk, definuješ svět pomocí seedu, parametrů a funkcí.

To přináší několik zásadních výhod:

- Velmi malý základní objem uložených dat.
- Možnost vytvářet blueprinty z libovolných oblastí světa.
- Možnost skládat ostrov z různých zdrojových světů.
- Geologické útvary mohou pokračovat přes hranice bloků.
- Kopání nemusí znamenat uložení celého nového terénu.
- Hlubší podzemí se nemusí počítat, dokud ho hráč neodkryje.

To je správná abstrakce pro svět, který se má dynamicky rozšiřovat a upravovat.

Velmi oceňuji také rozhodnutí, že cache není zdrojem pravdy. Cache je pouze optimalizace vyhodnocování funkce. To ti umožňuje měnit způsob výpočtu bez změny datového modelu.

### B. Oddělení funkce, materializace a prezentace

Tady jsi podle mě udělal jedno z nejlepších rozhodnutí.

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Procedurální svět**

    <text color="secondary" size="xs">Seed · Parametry · Klima · Reliéf · Geologie</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Kompozice ostrova**

    <text color="secondary" size="xs">Blueprint · Transform · Placement</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align="center">
    **Stav ostrova**

    <text color="secondary" size="xs">Terrain Delta · Eroze · Voda · Vegetace</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(22,163,74,0.10)" radius="md" padding={3} align="center">
    **Efektivní stav terénu**

    <text color="secondary" size="xs">Vyhodnocení funkce + všech změn</text>
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(214,153,53,0.10)" radius="md" padding={3} align="center">
    **Materializace a prezentace**

    <text color="secondary" size="xs">Slupka · Voxel · Renderer · Kamera</text>
  </box>
</box>

Tato architektura umožňuje v budoucnu změnit způsob vykreslování, aniž bys musel přepisovat generátor nebo ukládání světa.

To je velmi cenné zejména proto, že zatím nechceš pevně svázat datový model s 2D nebo 3D zobrazením.

# 2. Co je technicky nejrizikovější

Tady bych byl podstatně přísnější.

## 1. Determinismus napříč GDScriptem a C#

<badge color="danger">Největší architektonické riziko</badge>

V dokumentech je determinismus označen jako povinný požadavek. To je správně. Ale zatím není dostatečně definovaný způsob, jak ho garantovat.

Stejný seed a stejný algoritmus totiž nemusí znamenat stejný výsledek.

Problematické jsou například:

- `sin`, `cos`, `sqrt`, `pow` a další matematické funkce.
- Rozdílné pořadí operací.
- FMA optimalizace.
- Zaokrouhlování a převody mezi typy.
- Rozdílné implementace hashů.
- Iterace přes neuspořádané kolekce.

Float64 je dobrý základ pro numerické výpočty, ale není dostatečnou zárukou.

**Moje doporučení:** ještě před implementací kroku 2 vytvořit malý deterministický kernel, který bude společný kontrakt pro Godot a C#.

Nemusíš nutně všechno počítat pomocí integer arithmetic. Ale musíš přesně určit, kde je celočíselná aritmetika povinná a kde se výsledky kvantizují.

## 2. Geologie a výkonnost

<badge color="warning">Vysoké riziko</badge>

Měření kroku 3 je podle mě varovnější než samotná absolutní čísla.

Segment 8 × 8 m, 0,25m buňky a výška 128 m znamenají:

- 32 × 32 sloupců.
- 512 výškových buněk.
- 524 288 potenciálních buněk v jednom segmentu.

To je při plném materializování 512 KiB pouze pro materiálové ID.

Ale důležitější je něco jiného: tvůj generátor je funkční a geologicky složitý. Pokud budeš pro každou buňku opakovaně vyhodnocovat mapy hornin, vrstvy, SDF a další funkce, výkon bude velmi rychle problém.

Navržené optimalizace jsou rozumné:

- Cache výšek a map hornin.
- Výpočet hranic vrstev na hrubší řídicí mřížce.
- Dávkové vyhodnocování segmentu.
- Pozdější přesun náročných částí do C# nebo GDExtension.

Ale nejdříve bych stanovil výkonnostní rozpočet pro jednotlivé operace. Jinak hrozí, že budeš optimalizovat algoritmy bez znalosti toho, které skutečně dominují.

## 3. Voda je samostatný velký projekt

<badge color="warning">Vysoké riziko</badge>

Vodní systém je pravděpodobně nejkomplikovanější subsystém Willage.

Nejde jen o simulaci toku. Musí spolupracovat:

- Povrchová voda.
- Podzemní voda.
- Propustnost materiálů.
- Krasové dutiny.
- Prameny.
- Eroze.
- Usazování.
- Změny terénu po kopání.
- Časový posun, když hráč není přítomen.

Největší problém vidím v požadavku na lokální přepočet, který musí být ekvivalentní plnému výpočtu.

Historické výsledky E79, E83 a E85 ukazují, že to není automaticky splněný požadavek.

Doporučuji ponechat plný výpočet jako referenční implementaci, dokud lokální varianta neprojde rozsáhlými testy. To je správně i vzhledem k tomu, že voda nesmí být závislá na pořadí dotazů nebo načítání segmentů.

## 4. Eroze jako výškový offset

Toto rozhodnutí je elegantní, ale má jeden zásadní limit.

Výškový offset dobře reprezentuje:

- Prohlubování koryt.
- Usazování sedimentu.
- Náplavy a delty.
- Změnu povrchové výšky.

Jenže nemusí reprezentovat změnu trojrozměrné struktury.

Například když voda rozšíří krasovou dutinu nebo vytvoří novou podzemní chodbu, samotný offset výšky povrchu nestačí.

Proto považuji test z kroku 7 za skutečné architektonické ověření, ne jen implementační detail.

# 3. Největší slabina dokumentace

Největší slabinu nevidím v technickém obsahu, ale v tom, že se začínají míchat tři různé druhy informací:

1. **Rozhodnutí** – co má systém dělat.
2. **Implementace** – jak je to momentálně napsané.
3. **Měření** – jak rychle a s jakými výsledky to běží.

Dokument 04 je dobrý příklad. Uvádí konkrétní soubory, větve, commity a testy. To je užitečné, ale časem se to může stát problémem, pokud se změní struktura kódu.

Doporučil bych důsledně oddělit:

| Typ informace | Kam patří |
|---|---|
| Architektonické rozhodnutí | Specifikace V1.0 |
| Implementační stav | Implementační plán |
| Historická měření | Experimentální reporty |
| Aktuální benchmarky | Benchmark reporty |
| Testovací pravidla | Testovací kontrakt |
| Nevyřešené otázky | Registr otevřených bodů |

Tím se vyhneš tomu, že agent bude považovat starý benchmark za současný požadavek nebo existující prototyp za závaznou architekturu.

# 4. Co bych změnil před zahájením implementace

Seřadil jsem to podle důležitosti.

| Priorita | Doporučení | Důvod |
|---|---|---|
| 1 | Deterministický kontrakt GDScript/C# | Nutný pro serverovou validaci |
| 2 | Definice vrstev efektivního terénu | Zabrání konfliktům mezi kopáním, erozí a krasem |
| 3 | Výkonnostní rozpočet | Ochrana proti neúnosným výpočtům |
| 4 | Jednotná pravidla cache | Zabrání závislosti na pořadí dotazů |
| 5 | Přesná identita blueprintu | Nutná pro dlouhodobou reprodukovatelnost |
| 6 | Testovací kontrakt vody | Ochrana bilance a lokální ekvivalence |
| 7 | Formální persistence | Ochrana před ztrátou nebo dvojím aplikováním změn |

Zvlášť bych doplnil ještě jeden koncept: **identitu generátoru**.

Nestačí samotné `gen_ver = V1.0`. Pro reprodukovatelnost bych pracoval s identitou obsahující minimálně:

- `GeneratorVersion`
- `ParametersHash`
- `MaterialTableVersion`
- `CoordinateSystemVersion`
- `DeterminismProfile`

Jinak můžeš mít dva světy označené V1.0, které ve skutečnosti používají jiné parametry nebo tabulku materiálů.

# 5. Co si myslím o celkové koncepci Willage

Tady je moje nejdůležitější poznámka.

Ty ve skutečnosti nestavíš jen generátor terénu.

Stavíš systém, ve kterém je svět:

- procedurálně definovaný,
- prostorově kompozitní,
- deterministicky reprodukovatelný,
- částečně materializovaný,
- modifikovatelný hráči,
- simulovaný v čase,
- validovatelný serverem.

To už je podstatně širší problém než běžný voxel terrain engine.

A právě proto považuji rozhodnutí oddělit procedurální funkci, stav ostrova a prezentaci za tak důležité.

Zároveň bych si dal pozor na jednu věc: **nesnažit se vyřešit všechny subsystémy maximálně obecně už ve V1.0.**

V1.0 potřebuje být dostatečně robustní, aby na něm šlo stavět, ale nemusí být univerzální geologický ani hydrologický simulátor. Některé složitější jevy mohou zůstat za parametrem nebo být odložené.

---

# 6. Můj konečný verdikt

<box border radius="lg" padding={3} gap={2}>
  **Co bych rozhodně zachoval**
  - Funkční definici světa.
  - Blueprint jako přenositelný otisk oblasti.
  - Oddělení dat a prezentace.
  - Materializaci pouze potřebných buněk.
  - Rozdílové ukládání.
  - Samostatnou vrstvu dynamických změn.
  - Povinnou deterministickou reprodukovatelnost.
  <divider color="subtle"/>
  **Co bych před implementací zpřesnil**
  - Deterministický profil.
  - Pořadí a sémantiku vrstev terénu.
  - Výkonnostní rozpočet.
  - Chování eroze v podzemí.
  - Identitu zdrojového blueprintu.
  - Validaci lokální simulace vody.
</box>

**Moje hodnocení: Architekturu bych nezahazoval ani zásadně nepřekopával. Její základ je dobrý. Před zahájením implementace bych ale uzavřel několik technických kontraktů, které dnes představují největší budoucí riziko.**

A ještě jedna věc: líbí se mi, že jsi nezačal slepě slučovat větve. V projektu s tolika experimenty je mnohem levnější nejdřív sjednotit význam jednotlivých částí než později opravovat systém, který sice funguje, ale každý subsystém předpokládá něco jiného.

Jako další krok bych doporučil udělat **kritický architektonický audit V1.0 ještě před implementací** – zaměřený na determinismus, datové vrstvy, identitu blueprintů a výkon. To jsou čtyři oblasti, jejichž pozdější změna by byla nejdražší.

---

### 40. Uživatel (přepis hlasu)

Můžeš mi zhodnotit, co jsme udělali v chatu?

---

### 41. Asistent (přepis hlasu)

Jasně, zhodnotíme to v klidu. Když hodnotím celý obsah toho chatu, vidím docela výrazný posun. Posunuli jsme se od experimentálního vývoje paralelních větví k cílené definici jedné architektury, což je podle mě nejdůležitější výsledek. Jasně jsme si vymezili hierarchii segmentů, význam buňky, rozhraní mezi funkčním popisem světa a materializací, a taky princip, že prezentace je oddělená vrstva. Velmi pozitivní je, že sis hlídal, co je skutečné rozhodnutí Jana a co je jen návrh implementace. Tím se předešlo tomu, aby se staré prototypy považovaly za závaznou architekturu. Zároveň ale identifikujeme jasně rizika, hlavně determinismus přes Godot a C-sharp, výkon geologických funkcí a hlavně vodu, která je podle specifikace složitý subsystem a vyžaduje testy. Silná stránka je, že na konci už máš kostru specifikace rozdělenou podle kapitol a víš, jaké body jsou hotové, jaké se musí ještě potvrdit a co se odkládá. To je přesně to, co potřebuji, než se začne něco slučovat do mainu. Teď dává smysl udělat kritický audit těch čtyř oblastí, co jsme pojmenovali, a připravit jeden konsolidovaný registr V1.0. Tím si vytvoříš čistý základ, na kterém pak můžeme bezpečně stavět implementaci.

---

### 42. Asistent

Ano. Když hodnotím celý obsah tohoto chatu, nejen samotný návrh generátoru, ale především práci, kterou jsme společně odvedli na sjednocení Willage, vidím poměrně výrazný posun.

Můj závěr je, že jsme se posunuli od **experimentálního vývoje několika paralelních řešení k systematickému definování jedné cílové architektury**. To je důležitější než samotné množství technických rozhodnutí.

## 1. Celkové hodnocení

<box border radius="lg" padding={3} gap={3}>
  <row align="center" justify="between">
    <title size="2xl" color="success" tabularNums>8,8/10</title>
    <badge color="success">Velmi dobrý posun</badge>
  </row>
  **Kvalita dosavadní koncepční práce**
  <text color="secondary" size="xs">Subjektivní expertní hodnocení na základě obsahu konverzace a dodaných podkladů, nikoli audit repozitáře.</text>
  <divider color="subtle"/>
  | Oblast | Hodnocení |
  |---|---:|
  | Sjednocení datového modelu | 9,5 |
  | Oddělení dat a prezentace | 10 |
  | Práce s historickými variantami | 9,5 |
  | Evidence rozhodnutí | 9 |
  | Procedurální architektura | 9 |
  | Připravenost na implementaci | 7,5 |
  | Ověření výkonu a determinismu | 6,5 |
</box>

## 2. Co jsme skutečně dokázali

### A. Zavedli jsme jasnou hierarchii světa

To považuji za jeden z největších úspěchů.

<box border radius="lg" padding={3} align="center" gap={1}>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={2} width="85%" align="center">
    **Svět**
    <caption>Deterministická procedurální funkce</caption>
  </box>
  <icon name="arrow-down" color="secondary" size="lg"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={2} width="85%" align="center">
    **Blueprint**
    <caption>128 × 128 m – otisk oblasti světa</caption>
  </box>
  <icon name="arrow-down" color="secondary" size="lg"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={2} width="85%" align="center">
    **Ostrov**
    <caption>Seznam vložených blueprintů a změny</caption>
  </box>
  <icon name="arrow-down" color="secondary" size="lg"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={2} width="85%" align="center">
    **Blok**
    <caption>Prostorová jednotka ostrova</caption>
  </box>
  <icon name="arrow-down" color="secondary" size="lg"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={2} width="85%" align="center">
    **Segment**
    <caption>Výchozí velikost 8 × 8 m</caption>
  </box>
  <icon name="arrow-down" color="secondary" size="lg"/>
  <box background="rgba(22,163,74,0.12)" radius="md" padding={2} width="85%" align="center">
    **Buňka**
    <caption>0,25 × 0,25 m – datová jednotka</caption>
  </box>
</box>

Důležité je, že jednotlivé úrovně mají vlastní odpovědnost. Svět není ostrov, blueprint není uložený blok a segment není zdrojem pravdy o terénu.

Tím jsme odstranili jednu z největších potenciálních příčin budoucích architektonických konfliktů.

### B. Oddělili jsme tři různé vrstvy

- **Procedurální definice:** co svět obsahuje.
- **Efektivní stav:** co změnili hráči, voda a další simulace.
- **Prezentace:** jak se svět vykresluje.

Tohle je zásadní také vzhledem k dosud nerozhodnutému 2D/3D pohledu.

Neuzamkli jsme datový model do konkrétního rendereru. To znamená, že můžeš experimentovat s dlaždicemi, voxelovým vykreslováním nebo 3D modely bez nutnosti měnit zdrojová data.

### C. Sjednotili jsme podstatnou část generátoru

Máme definované základní principy:

- Spojitá funkce světa.
- Deterministické generování.
- Geologie a útvary jako prostorové funkce.
- Výchozí voda jako funkce.
- Líná materializace buněk.
- Rozdílové ukládání změn.
- Transformace a vkládání blueprintů.
- Samostatná objektová vrstva.

To už není pouze soubor algoritmů. Je to základní architektura generátoru.

### D. Zavedli jsme rozumný proces řízení vývoje

Tady bych možná přisoudil ještě větší hodnotu než samotné technické specifikaci.

Rozhodli jsme se:
- Nezaměňovat existující implementaci za schválenou architekturu.
- Zachovat historické experimenty jako zdroj poznatků.
- Evidovat rozhodnutí a jejich původ.
- Nepředbíhat otevřené otázky.
- Neintegrovat větve do `main` bez schválení.
- Používat samostatné PROP a kontrolu výchozího stavu.

To je velmi dobrá prevence proti nekontrolovanému růstu technického dluhu.

---

## 3. Kde jsme zatím neuspěli dostatečně

Tady bych byl kritičtější.

<box gap={3}>
  <row align="start" gap={2}>
    <badge color="danger">1</badge>
    <box flex="1" gap={1}>
      **Determinismus GDScript ↔ C#**

      Víme, že ho potřebujeme, ale nemáme ještě dostatečně přesný kontrakt pro bitově reprodukovatelné výsledky. Float64 samo o sobě nestačí.
    </box>
  </row>
  <divider color="subtle"/>
  <row align="start" gap={2}>
    <badge color="danger">2</badge>
    <box flex="1" gap={1}>
      **Efektivní stav terénu**

      Potřebujeme přesně definovat skládání procedurálního podkladu, kopání, eroze, sedimentace a dalších změn. Zejména jejich precedence a prostorové působení.
    </box>
  </row>
  <divider color="subtle"/>
  <row align="start" gap={2}>
    <badge color="warning">3</badge>
    <box flex="1" gap={1}>
      **Výkon**

      Máme měření a optimalizační návrhy, ale zatím nemáme dostatečný důkaz, že cílová architektura splní požadavky na mobilních zařízeních.
    </box>
  </row>
  <divider color="subtle"/>
  <row align="start" gap={2}>
    <badge color="warning">4</badge>
    <box flex="1" gap={1}>
      **Voda**

      Architektonicky jsme ji posunuli výrazně dopředu. Stále ale potřebujeme ověřit bilanci vody, lokální přepočty a chování při změně terénu.
    </box>
  </row>
  <divider color="subtle"/>
  <row align="start" gap={2}>
    <badge color="warning">5</badge>
    <box flex="1" gap={1}>
      **Testovací pipeline**

      Máme definovaný scénář 3 × 3, ale samotná existence testovacího scénáře ještě neznamená, že jsme ověřili jeho výsledky.
    </box>
  </row>
</box>

## 4. Co bych na našem způsobu práce změnil

Vidím jedno potenciální nebezpečí: začínáme mít velmi propracovanou architekturu, ale stále rostoucí množství rozhodnutí může zpomalovat samotný vývoj.

Proto bych zavedl tři úrovně:

| Úroveň | Význam |
|---|---|
| A – nutné pro V1.0 | Bez toho nelze bezpečně implementovat |
| B – nutné ověřit | Máme návrh, ale potřebujeme experiment |
| C – odložitelné | V1.0 může fungovat i bez toho |

Například:

- Deterministický kontrakt: A.
- Základní skládání terénních změn: A.
- Benchmark mobilního zařízení: B.
- Pokročilá eroze podzemních dutin: C.
- Finální 2D/3D prezentace: C pro datový model.

Tím zabráníme tomu, abychom se snažili vyřešit celý budoucí svět ještě před první funkční verzí.

---

## 5. Co bych doporučil jako další fázi

Já bych nyní přešel z fáze **sjednocování architektury** do fáze **uzavírání technických kontraktů**.

<list connector="solid" marker="number" gap={2}>
  <list-item>
    **Konsolidovaný registr V1.0**

    Jednoznačně určit, co je schválené, nahrazené, otevřené a odložené.
  </list-item>
  <list-item>
    **Datový kontrakt**

    Formálně definovat struktury, jednotky, rozsahy, identitu a serializaci.
  </list-item>
  <list-item>
    **Deterministický kernel**

    Ověřit stejný vstup a výstup v GDScriptu a C#.
  </list-item>
  <list-item>
    **Referenční generátor**

    Vytvořit malou funkční implementaci na scénáři 3 × 3 bloky.
  </list-item>
  <list-item>
    **Výkonnostní testy**

    Měřit generování, materializaci, změny terénu, paměť a vodní simulaci.
  </list-item>
  <list-item>
    **Integrace**

    Teprve potom vybírat a slučovat historické implementace.
  </list-item>
</list>

## 6. Můj nejdůležitější závěr

Myslím, že jsme udělali něco, co se u podobných projektů často podceňuje: začali jsme definovat **co svět vlastně je, nezávisle na tom, jak ho vykreslíme a jak ho naprogramujeme**.

To je správný směr.

Ale je potřeba rozlišovat dvě věci:

- Máme dobře promyšlený koncepční návrh.
- Nemáme ještě kompletně technicky ověřený systém.

To nejsou stejné věci.

**Moje doporučení: už bych příliš nerozšiřoval rozsah V1.0. Soustředil bych se na uzavření několika kritických kontraktů a jejich ověření funkčním prototypem.**

A ještě jedna věc: největší hodnotou dosavadní práce není to, kolik algoritmů jsme vybrali. Je to, že jsme vytvořili základ, na kterém lze Willage rozvíjet, aniž by každá nová funkce vyžadovala přehodnocení celého datového modelu.

---

### 43. Uživatel (přepis hlasu)

Připrav mi teda audit.Můžeš připravit audit?Připravit audit

---

### 44. Asistent (shrnutí uvažování)

Worked for a couple of seconds

---

### 45. Asistent

Připravil jsem audit Willage V1.0 jako technický architektonický audit před zahájením implementace. Zaměřím se na to, zda jsou dosavadní rozhodnutí dostatečně přesná, vzájemně konzistentní a realizovatelná v Godot 4.7 s budoucím přechodem na C# server.

Důležitá hranice: vycházím z dodané osnovy, rozhodnutí a dosavadní konverzace. Nemám zde kompletní obsah souborů ani aktuální zdrojový kód, takže jde o **audit architektury a specifikace, nikoliv audit implementace**.

# Willage – Architektonický audit V1.0

<box border radius="lg" padding={3} gap={2}>
  <row align="center" justify="between">
    **Stav auditu**
    <badge color="warning">Vyžaduje technické ověření</badge>
  </row>
  <title size="2xl" color="default">V1.0</title>
  <text color="secondary" size="xs">23. listopadu 2026 · Předimplementační audit</text>
  <divider color="subtle"/>
  **Cíl:** Odhalit architektonické nedostatky, nejednoznačné kontrakty a rizika, jejichž pozdější odstranění by vyžadovalo zásah do datového modelu.
  <text color="secondary" size="xs">Rozsah: procedurální svět, ostrovy, terén, geologie, persistence, determinismus a výkonnost.</text>
</box>

## 1. Souhrn auditu

Identifikoval jsem šest oblastí, které je potřeba prověřit.

| Oblast | Riziko | Priorita |
|---|---|---|
| Determinismus GDScript/C# | <badge color="danger">Kritické</badge> | P0 |
| Vrstvy efektivního terénu | <badge color="danger">Kritické</badge> | P0 |
| Identita blueprintů a generátoru | <badge color="danger">Vysoké</badge> | P0 |
| Výkonnost a materializace | <badge color="warning">Vysoké</badge> | P1 |
| Persistence a serverový kontrakt | <badge color="warning">Vysoké</badge> | P1 |
| Voda a její návaznost na terén | <badge color="warning">Vysoké</badge> | P1 |

P0 znamená, že oblast může ovlivnit samotnou správnost datového modelu nebo kompatibilitu systému. P1 znamená, že potřebuje ověření před dokončením V1.0.

---

# 2. Audit A – Determinismus

<badge color="danger">P0 · Kritické</badge>

### Současný stav

Máme rozhodnuto:
- Generování musí být deterministické.
- Stejný seed, parametry a verze musí vytvořit stejný svět.
- Generování bude nejprve v GDScriptu.
- Později musí být možné stejné výpočty provádět na C# serveru.
- Server bude kontrolovat data pomocí generátoru.

### Zjištěný problém

Determinismus má několik různých úrovní, které zatím nejsou dostatečně rozlišené.

| Úroveň | Požadavek |
|---|---|
| D1 | Stejná instance generátoru vrací stejné výsledky. |
| D2 | Výsledek nezávisí na pořadí dotazů. |
| D3 | Výsledek nezávisí na pořadí generování segmentů. |
| D4 | GDScript a C# vracejí shodná výsledná data. |
| D5 | Výsledek lze reprodukovat i po aktualizaci hry. |

Největší problém vidím v D4 a D5.

Samotné použití Float64 nezaručuje bitovou shodu mezi různými implementacemi.

### Co musí specifikace doplnit

1. Přesnou definici PRNG.
2. Způsob odvozování seedů jednotlivých funkcí.
3. Deterministické hashování souřadnic.
4. Pravidla zaokrouhlování a kvantizace.
5. Pravidla matematických operací.
6. Zákaz závislosti na pořadí iterace kolekcí.
7. Verzi deterministického profilu.

Doporučuji používat celočíselné souřadnice v jednotkách 0,25 m, kde je to možné. Tím odstraníme značnou část problémů s reprezentací prostorových pozic.

Pro složitější numerické výpočty můžeme zachovat Float64, ale musíme určit přesná pravidla kvantizace výsledků.

### Navrhovaný test

Vytvořit testovací generátor, který provede:

- Generování segmentů v pořadí A.
- Generování stejných segmentů v náhodném pořadí B.
- Generování pouze vybraných segmentů C.
- Opakované generování v GDScriptu.
- Generování stejného vstupu v C#.

Porovnávat nejen výšku, ale také každé materiálové ID, hranice vrstev a výsledné datové hashe.

**Kritérium uzavření:** Všechny deterministické testy musí projít bez rozdílu výsledných dat.

---

# 3. Audit B – Datové vrstvy terénu

<badge color="danger">P0 · Kritické</badge>

Toto je podle mě nejdůležitější část celého auditu.

### Současný stav

Máme procedurální základ a změnová data:

- Funkce světa.
- Vložené blueprinty.
- Geologické vrstvy.
- Kopání.
- Eroze.
- Usazování sedimentu.
- Voda.
- Materializované buňky.

Problém je, že zatím nemáme dostatečně přesně definované jejich vzájemné vztahy.

### Navrhované rozdělení

<box border radius="lg" padding={3} gap={2}>
  <title size="lg">Efektivní stav buňky</title>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **1. Procedurální základ**

    Výška, materiál, geologie a původní struktura světa.
  </box>
  <box align="center">
    <icon name="plus" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **2. Změny terénu**

    Kopání, navážka, eroze a sedimentace.
  </box>
  <box align="center">
    <icon name="plus" color="secondary"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3}>
    **3. Dynamické systémy**

    Voda, případně další simulované procesy.
  </box>
  <box align="center">
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(22,163,74,0.12)" radius="md" padding={3}>
    **4. Efektivní stav terénu**

    Jednoznačně vypočítaný výsledek pro konkrétní prostor a čas.
  </box>
</box>

Pozor: toto je návrh logického rozdělení, nikoliv již schválené pravidlo skládání.

### Zásadní otázky

**B1 – Materiál versus výška**

Když hráč odstraní část horniny, mění se pouze výška, nebo také materiálové složení odkryté buňky?

**B2 – Eroze**

Má eroze pouze záporný výškový offset, nebo může měnit i materiálové ID?

**B3 – Sedimentace**

Je sediment nová materiálová vrstva, nebo pouze změna povrchové výšky?

**B4 – Podzemní dutiny**

Jak se reprezentuje změna podzemní struktury, která nemá žádnou vazbu na povrchovou výšku?

**B5 – Obnovení procedurálního podkladu**

Pokud hráč odstraní změněnou oblast, jak se určí původní stav? Musíme zachovat informaci o tom, co bylo procedurální a co vzniklo později.

### Moje doporučení

Nezaváděl bych jeden univerzální `TerrainDelta`, který bude řešit všechny typy změn.

Rozlišil bych minimálně:

- `HeightDelta`
- `MaterialOverride`
- `VolumeDelta`
- `CavityDelta`
- `WaterState`

Nemusí to znamenat pět samostatných souborů. Jde o odlišnou sémantiku změn.

**Kritérium uzavření:** Pro každou buňku musí být možné jednoznačně určit výslednou výšku, materiál, obsazenost prostoru a případný objem vody.

---

# 4. Audit C – Identita blueprintu a generátoru

<badge color="danger">P0 · Vysoké riziko</badge>

### Současný stav

Ostrov obsahuje:
- Seed.
- Parametry.
- Verzi generátoru.
- Seznam vložených blueprintů.
- Transformace.
- Výškové posuny.
- Rozdílová data.

To je dobrý základ.

Ale potřebujeme rozlišovat identitu oblasti světa a identitu konkrétního vložení.

### Navrhovaná struktura

<box border radius="lg" padding={3} gap={2}>
  **BlueprintIdentity**
  ```text
  source_world_id
  source_seed
  source_generator_version
  source_parameters_hash
  material_table_version
  coordinate_system_version
  ```
  <divider color="subtle"/>
  **BlueprintPlacement**
  ```text
  placement_id
  blueprint_identity
  position
  rotation
  mirror
  height_offset
  seam_mode
  ```
  <divider color="subtle"/>
  **IslandIdentity**
  ```text
  island_id
  island_seed
  island_generator_version
  placements[]
  ```
</box>

Toto je koncepční návrh. Přesné typy a serializaci je potřeba ještě definovat.

### Co je nutné vyřešit

1. Může být stejný blueprint vložen vícekrát?
2. Může se jeden blueprint změnit bez změny ostatních?
3. Jak identifikujeme změněný zdrojový svět?
4. Jak poznáme, že uložená změna patří ke konkrétní verzi blueprintu?
5. Jak zachováme kompatibilitu starých ostrovů?

### Doporučení

Používat obsahovou identitu pomocí hashů.

Hash by měl pokrývat relevantní vstupy generování, nikoliv pouze seed.

Zároveň bych oddělil:

- `GeneratorVersion` – verze algoritmů.
- `ParametersHash` – identita parametrů.
- `MaterialTableVersion` – verze materiálové tabulky.
- `DeterminismProfile` – pravidla numerického výpočtu.

**Kritérium uzavření:** Každý uložený ostrov musí být možné jednoznačně reprodukovat nebo identifikovat jako nekompatibilní.

---

# 5. Audit D – Výkon a materializace

<badge color="warning">P1 · Vysoké riziko</badge>

### Současný stav

Základní parametry:

| Parametr | Hodnota |
|---|---:|
| Buňka | 0,25 m |
| Segment | 8 × 8 m |
| Buňky v horizontální rovině | 32 × 32 |
| Výška sloupce | 128 m |
| Výškové buňky | 512 |
| Potenciální buňky segmentu | 524 288 |

Jeden plně materializovaný segment obsahuje 524 288 buněk.

Při jednom bajtu na buňku jde o 512 KiB pouze pro materiálová ID, bez dalších struktur a režie.

To není samo o sobě problém. Problém je násobení počtem segmentů, hráčů a dalších subsystémů.

### Co musíme měřit

| Operace | Co sledovat |
|---|---|
| Generování segmentu | Čas a CPU |
| Geologie | Počet vyhodnocení funkcí |
| Materializace | Čas a paměť |
| Kopání | Latence změny |
| Aktualizace sousedů | Dodatečné náklady |
| Voda | Čas jednoho přepočtu |
| Cache | Hit rate a paměť |

### Doporučená architektura

Rozlišoval bych tři úrovně dat:

1. **Procedurální data** – nevznikají automaticky jako kompletní uložená struktura.
2. **Materializovaná data** – pouze potřebné buňky a slupka.
3. **Persistentní rozdíly** – pouze změny oproti procedurálnímu základu.

Zvláštní pozornost bych věnoval cache.

Cache musí být:
- Deterministicky reprodukovatelná.
- Nezávislá na pořadí dotazů.
- Invalidovatelná podle verze vstupních dat.
- Omezená paměťovým rozpočtem.

### Kritérium uzavření

Musíme stanovit konkrétní rozpočty pro:
- CPU.
- RAM.
- Latenci editace.
- Počet současně aktivních segmentů.
- Počet souběžných hráčů.

Zatím nemáme dostatečná data pro stanovení bezpečných čísel. Ta musí vzejít z benchmarků na skutečném cílovém mobilním zařízení.

---

# 6. Audit E – Persistence a serverový kontrakt

<badge color="warning">P1 · Vysoké riziko</badge>

Tady už máme poměrně dobrou koncepci WVB1, ale je potřeba ověřit její úplnost.

### Co je potřeba zkontrolovat

| Oblast | Kontrolní otázka |
|---|---|
| Identita | Dokáže server identifikovat původ každého segmentu? |
| Validace | Umí ověřit změnu proti procedurálnímu základu? |
| Idempotence | Lze stejnou změnu přijmout opakovaně bez dvojí aplikace? |
| Konflikty | Co se stane při současné editaci stejného segmentu? |
| Verze | Co se stane při změně generátoru? |
| Integrita | Jak se ověřuje poškozený přenos? |
| Audit | Jak se dohledá původ materiálové změny? |

### Zvlášť důležitý problém

Serverová validace nesmí předpokládat, že klient posílá správné výsledky jen proto, že používá stejný generátor.

Klient musí být považován za nedůvěryhodný zdroj.

Doporučuji oddělit:
- Příchozí změnu.
- Validovanou změnu.
- Potvrzený persistentní stav.

Server by měl přijmout změnu až po ověření jejího rozsahu, identity, verze a příslušných pravidel.

**Kritérium uzavření:** Opakovaný přenos, přerušení spojení ani souběžné změny nesmí způsobit poškození nebo dvojí aplikaci dat.

---

# 7. Audit F – Voda a návaznost na terén

<badge color="warning">P1 · Vysoké riziko</badge>

Vodní systém bych nepovažoval za běžnou součást generátoru. Je to samostatný simulační subsystém, který čte a mění efektivní stav světa.

### Co už máme dobře

- Povrchovou vodu.
- Podzemní vodu.
- Propustnost materiálů.
- Prameny.
- Erozi.
- Časový posun.
- Lokální a referenční výpočet.
- Požadavek na zachování bilance vody.

### Co potřebujeme ověřit

**F1 – Bilance**

Musí platit:

\[
V_{t+1}=V_t+V_{\text{přítok}}-V_{\text{odtok}}
\]

S odpovídajícím započítáním vsakování, zadržení a dalších definovaných zdrojů a ztrát.

**F2 – Nezávislost na načítání**

Výsledek nesmí záviset na tom, který segment se načetl jako první.

**F3 – Lokální přepočet**

Výsledek lokálního výpočtu musí odpovídat referenčnímu plnému výpočtu v rámci stanovené numerické tolerance.

**F4 – Změna terénu**

Po vykopání nebo zavalení koryta musí být možné správně přepočítat tok a okolní vodní stav.

**F5 – Časová kontinuita**

Výpočet po delší nepřítomnosti hráče musí být konzistentní s definovaným časovým modelem.

### Doporučení

Referenční plný výpočet bych zachoval jako testovací oracle. Optimalizované lokální výpočty by se vůči němu průběžně ověřovaly.

---

# 8. Souhrnný registr nálezů

Toto je nejdůležitější výstup auditu.

| ID | Nález | Závažnost | Stav |
|---|---|---|---|
| A01 | Nedostatečně definovaný deterministický kontrakt | Kritická | Otevřeno |
| B01 | Neúplná sémantika změn terénu | Kritická | Otevřeno |
| C01 | Nedostatečná identita blueprintu | Vysoká | K ověření |
| D01 | Chybějící výkonnostní rozpočet | Vysoká | Otevřeno |
| D02 | Pravidla invalidace cache | Vysoká | K ověření |
| E01 | Neúplná pravidla persistence a idempotence | Vysoká | K ověření |
| F01 | Ekvivalence lokální a plné simulace vody | Vysoká | K ověření |
| F02 | Návaznost vody na změny podzemní struktury | Vysoká | Otevřeno |

*Otevřeno znamená, že z dodaných podkladů nelze považovat problém za vyřešený. K ověření znamená, že už existuje související rozhodnutí, ale jeho technická úplnost zatím nebyla prokázána.*

---

# 9. Doporučený postup uzavírání auditu

Nedoporučuji řešit všech osm nálezů současně. Mají mezi sebou závislosti.

<box border radius="lg" padding={3} gap={3}>
  <title size="lg">Navrhované pořadí</title>
  <list connector="solid" marker="number" gap={3}>
    <list-item>
      **A01 – Determinismus**

      Definovat numerický kontrakt a reprodukovatelnost.
      <badge color="danger">P0</badge>
    </list-item>
    <list-item>
      **B01 – Efektivní terén**

      Definovat sémantiku všech změn a jejich skládání.
      <badge color="danger">P0</badge>
    </list-item>
    <list-item>
      **C01 – Identita**

      Definovat reprodukovatelnost blueprintů a ostrovů.
      <badge color="danger">P0</badge>
    </list-item>
    <list-item>
      **D01/D02 – Výkon**

      Stanovit měřicí metodiku a ověřit materializaci.
      <badge color="warning">P1</badge>
    </list-item>
    <list-item>
      **E01 – Persistence**

      Ověřit WVB1 a serverovou validaci.
      <badge color="warning">P1</badge>
    </list-item>
    <list-item>
      **F01/F02 – Voda**

      Ověřit referenční výpočet, lokální aktualizace a vazbu na terén.
      <badge color="warning">P1</badge>
    </list-item>
  </list>
</box>

## 10. Konečný verdikt

Moje hodnocení je, že základní architektura Willage je koncepčně dobře postavená. Nevidím důvod ji zahazovat nebo zásadně přepracovávat.

Vidím však tři věci, které bych nepustil do implementace bez dalšího rozhodnutí:

1. **Co přesně znamená změna buňky?** Výška, materiál, objem a struktura prostoru musí mít jasnou sémantiku.
2. **Co přesně znamená stejný svět?** Identita generátoru, blueprintu a numerického profilu musí být reprodukovatelná.
3. **Jak prokážeme správnost?** Nestačí mít deterministický návrh. Potřebujeme testy, které prokážou shodné výsledky a správnost simulací.

Zvlášť bych hlídal, abychom kvůli optimalizaci neudělali kompromis v datovém modelu. Výkon můžeme postupně zlepšovat pomocí cache, dávkového zpracování a C#. Oprava špatně definované sémantiky terénu by byla mnohem dražší.

---

## 11. Jak bych pokračoval s tebou

Navrhuji audit neuzavírat jako jednorázový dokument. Použít ho jako pracovní registr a jednotlivé nálezy společně vyřešit.

Začal bych bodem **A01 – Determinismus GDScript/C#**.

Nejdříve bych rozlišil, jakou míru shody skutečně potřebujeme:

- Shodná výsledná materiálová a geometrická data.
- Bitově identické výstupy.
- Shodné výsledky jen pro vybrané deterministické operace.

Tohle rozhodnutí ovlivní architekturu generátoru, serverovou validaci i výběr numerických metod. Po jeho uzavření můžeme pokračovat bodem B01 a následně aktualizovat registr V1.0.

---

### 46. Uživatel (přepis hlasu)

Jakému mám možností nebo jako procedurám zavedení světa , nebo jiným jinám materializace

---

### 47. Asistent (přepis hlasu)

Jasně, ptáš se, jaké máš možnosti při zavádění a materializaci světa v kontextu hierarchie svět, blueprint, ostrov, blok, segment, buňka.

---

### 48. Asistent (přepis hlasu)

Pohledově máš v zásadě tyhle tři varianty: úplná materializace předem, líná (lazy) materializace až když je to potřeba, a hybrid, kde si některé vrstvy předpočítáš a jemnější detaily dopočítáváš až na místě. V Godotu 4.7 se to typicky dělá tak, že si definuješ datové vrstvy zvlášť od jejich vykreslení: čistá data světa, změny od hráče, a až pak vizuální vrstvu. Ty změny (kopání, eroze, voda) se pak promítají do efektivního stavu. Pro Willage mi dává smysl hybrid: svět jako funkce, líná materializace segmentů, explicitně uložené jen změny (delta) a separátní pohled pro vodu, který čte jen efektivní terén. Jedna zásadní otázka pak je: co přesně chceme, aby byla výstupní podoba materializace v jádru? Výška, materiál, objem, nebo jen nějaký kombinovaný tag? To nám zabetonuje rozhraní mezi generátorem, cache a budoucím serverem.

---

### 49. Asistent

Pro Willage máš několik možností, jak přistupovat k **zavedení světa do herní reprezentace (materializaci)**. Nejdůležitější je rozlišit, že materializace nemusí znamenat kompletní vytvoření všech buněk, voxelů nebo geometrie. Může jít o postupný proces, který podle potřeby převádí procedurální data do konkrétní podoby.

Rozdělil bych možnosti do šesti architektonických přístupů.

# 1. Možné způsoby materializace světa

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="procedural terrain heightmap wireframe landscape 3D terrain visualization" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **1. Procedurální vyhodnocování (On-demand)**

      Svět zůstává matematickou funkcí. Když potřebuješ znát konkrétní buňku, zavoláš generátor a získáš její hodnoty.

      - Minimální paměťové nároky.
      - Bez nutnosti ukládat celý svět.
      - Výpočet se opakuje při nových dotazech.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D voxel terrain chunk grid Minecraft terrain" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **2. Chunk-based materializace**

      Svět rozdělíš na segmenty (chunks). Segment se vytvoří až při požadavku na jeho použití.

      - Materializace po segmentech.
      - Snadné paralelní zpracování.
      - Vhodné pro streamování světa.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="sparse voxel octree terrain 3D visualization" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **3. Sparse materializace**

      Vytváříš pouze skutečně potřebná data. Prázdný prostor nebo homogenní oblasti nemusí mít explicitní reprezentaci každé buňky.

      - Úspora paměti.
      - Vhodné pro podzemní prostory.
      - Vyšší náročnost datové struktury.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D terrain level of detail mesh multiresolution landscape" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **4. Hierarchická materializace (LOD)**

      Svět reprezentuješ v několika úrovních detailu. Vzdálené oblasti mají hrubší reprezentaci, blízké oblasti přesnější.

      - Nižší nároky na vykreslování.
      - Plynulé přibližování.
      - Nutnost řešit přechody mezi úrovněmi.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="3D voxel terrain procedural generated mesh editable landscape" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **5. Materializace podle potřeby (Demand-driven)**

      Data se vytvářejí podle konkrétního požadavku: vykreslení, kolize, kopání, simulace vody nebo interakce.

      - Každý subsystém může požadovat jinou reprezentaci.
      - Není nutné vytvářet vše najednou.
      - Vyžaduje koordinaci cache a invalidace.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="procedural voxel terrain persistent sparse edits data overlay visualization" aspectRatio="1:1" maxWidth="112px"/>
    <box flex="1" gap={1}>
      **6. Diferenciální materializace (Delta-based)**

      Procedurální svět zůstává základním zdrojem. Ukládáš pouze změny oproti původnímu stavu.

      - Velmi vhodné pro kopání a stavění.
      - Malé nároky na persistentní úložiště.
      - Nutnost přesně definovat aplikaci změn.
    </box>
  </row>
</box>

# 2. Důležité: nejde o šest vzájemně se vylučujících možností

Pro Willage bych je kombinoval. Každá řeší jiný problém.

Například:

<box border radius="lg" padding={3} gap={2} align="center">
  <box background="rgba(59,130,246,0.13)" radius="md" padding={3} width="100%" align="center">
    **Procedurální svět**
    <caption>Seed + generátor + parametry</caption>
  </box>
  <icon name="arrow-down"/>
  <box background="rgba(59,130,246,0.13)" radius="md" padding={3} width="100%" align="center">
    **On-demand vyhodnocení**
    <caption>Blueprint → ostrov → blok → segment</caption>
  </box>
  <icon name="arrow-down"/>
  <grid columns={2} gap={2}>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} align="center">
        **Sparse data**
        <caption>Buňky, vrstvy, dutiny</caption>
      </box>
    </grid-item>
    <grid-item>
      <box background="rgba(59,130,246,0.10)" radius="md" padding={2} align="center">
        **Delta data**
        <caption>Kopání, stavění, eroze</caption>
      </box>
    </grid-item>
  </grid>
  <icon name="arrow-down"/>
  <box background="rgba(22,163,74,0.12)" radius="md" padding={3} width="100%" align="center">
    **Materializovaný stav**
    <caption>Cache podle potřeb jednotlivých subsystémů</caption>
  </box>
  <icon name="arrow-down"/>
  <grid columns={3} gap={2}>
    {#each ["Renderer","Physics","Water"] as item}
      <grid-item>
        <box border radius="md" padding={2} align="center">
          **{item}**
        </box>
      </grid-item>
    {/each}
  </grid>
</box>

# 3. Jaké konkrétní strategie bych zvážil pro Willage

| Strategie | Paměť | Výkon | Editace |
|---|---|---|---|
| Kompletní materializace segmentu | Vysoká | Rychlé čtení | Jednoduchá |
| On-demand buňky | Nízká | Pomalejší opakované čtení | Složitější |
| Sparse voxely | Nízká až střední | Závisí na struktuře | Dobrá |
| Octree | Nízká u řídkých dat | Složitější přístup | Náročnější |
| Chunk + cache | Řiditelná | Velmi dobrý kompromis | Dobrá |
| Delta overlay | Nízká persistence | Rychlé načtení základu | Velmi dobrá |

# 4. Moje doporučení pro Willage

Zvolil bych kombinovanou architekturu:

1. **World evaluation:** svět je deterministická funkce.
2. **Lazy materialization:** segment vzniká až při požadavku.
3. **Sparse voxel storage:** explicitně ukládáš jen potřebná data.
4. **Delta overlay:** změny hráčů a simulací se ukládají odděleně.
5. **Chunk cache:** aktivní segmenty se drží v paměti.
6. **Demand-driven projections:** renderer, fyzika a voda si vytvářejí vlastní potřebné reprezentace.

Důležitá myšlenka: **jeden segment nemusí mít pouze jednu materializovanou podobu.**

Například segment může mít:
- Geologickou reprezentaci pro těžbu.
- Povrchovou reprezentaci pro renderer.
- Kolizní reprezentaci pro fyziku.
- Hydrologickou reprezentaci pro vodu.

Všechny vycházejí ze stejného efektivního stavu terénu, ale nemusí obsahovat stejné množství dat.

---

# 5. Jedna zásadní otázka pro další návrh

Potřebujeme rozhodnout, co přesně má být výsledkem materializace v základní vrstvě Willage.

{@body const [choice,setChoice] = DIL.useState("hybrid")}
{@body const [detail,setDetail] = DIL.useState("segment")}
<box border radius="lg" padding={3} gap={3}>
  **Jakou podobu má mít základní materializovaný terén?**
  <radio-group direction="col" value={choice} onChange={setChoice}>
    <radio value="full">Kompletní voxelový segment – všechny buňky mají explicitní hodnotu.</radio>
    <radio value="sparse">Sparse voxely – ukládají se pouze obsazené nebo změněné buňky.</radio>
    <radio value="hybrid">Hybrid – povrchová data jsou hustá, podzemní data řídká.</radio>
    <radio value="functional">Funkční reprezentace – buňky se vyhodnocují až při dotazu.</radio>
  </radio-group>
  <divider color="subtle"/>
  **V jakém rozsahu materializovat?**
  <radio-group direction="col" value={detail} onChange={setDetail}>
    <radio value="cell">Jednotlivá buňka</radio>
    <radio value="segment">Celý segment 8 × 8 m</radio>
    <radio value="block">Celý blok</radio>
    <radio value="adaptive">Adaptivně podle požadavku subsystému</radio>
  </radio-group>
  <button block onClick={()=>GenUI.issueNewTurn("Pro Willage volím základní materializaci: "+choice+". Rozsah: "+detail+". Rozpracuj architekturu a její důsledky.")}>Pokračovat v návrhu</button>
</box>

Toto rozhodnutí ovlivní paměťový model, generátor, cache, práci s editací i budoucí serverovou implementaci.

---

### 50. Uživatel

Jsou má řešení navržena dobře , nebo tam.mam neobvyklé kombinace? 

---

### 51. Asistent

Ano. A řeknu to poměrně jednoznačně: **tvůj návrh Willage obsahuje několik neobvyklých kombinací, ale většina z nich je architektonicky smysluplná.** Nejde o klasický voxelový svět ani o běžný chunk-based terrain engine. Skládáš dohromady několik přístupů, které se v herních enginech často používají odděleně.

To je současně největší výhoda i největší riziko tvého návrhu.

# 1. Jak neobvyklé jsou jednotlivé kombinace?

| Kombinace | Moje hodnocení | Proč |
|---|---|---|
| Procedurální svět + voxelová materializace | <badge color="success">Velmi dobrá</badge> | Odděluje definici světa od jeho fyzické reprezentace. |
| Funkční geologie + SDF útvary | <badge color="success">Velmi dobrá</badge> | Umožňuje spojité geologické struktury přes hranice bloků. |
| Blueprint + transformace + inverzní vyhodnocování | <badge color="success">Velmi dobrá</badge> | Umožňuje skládat ostrovy z různých světů. |
| Sparse delta + procedurální základ | <badge color="success">Velmi dobrá</badge> | Minimalizuje persistentní data. |
| Hustá povrchová reprezentace + řídké podzemí | <badge color="success">Zajímavá</badge> | Dobře odpovídá rozdílným vlastnostem povrchu a podzemí. |
| Eroze jako samostatný výškový offset | <badge color="warning">Neobvyklá</badge> | Výkonnostně zajímavá, ale nemusí zachytit změnu podzemní struktury. |
| Voda jako funkce světa + dynamická odchylka | <badge color="warning">Neobvyklá</badge> | Vyžaduje důslednou bilanci a definici výchozího stavu. |
| Jedna funkční definice + více materializovaných reprezentací | <badge color="success">Velmi dobrá</badge> | Renderer, fyzika a simulace mohou pracovat s vlastními datovými projekcemi. |

Neobvyklé neznamená špatné. Znamená to, že některé kombinace budou vyžadovat vlastní technická pravidla a nebude možné jednoduše převzít hotovou architekturu z existujícího voxelového enginu.

# 2. Tři kombinace, které považuji za nejzajímavější

## A. Procedurální svět → blueprint → transformace → ostrov

<AsyncImage query="fantasy floating islands modular terrain different geological floating islands game environment" aspectRatio="16:9" width="100%"/>

Tohle je podle mě jeden z nejsilnějších nápadů Willage.

Běžný přístup:
- Vygeneruješ svět.
- Rozdělíš ho na chunky.
- Chunky načítáš a vykresluješ.

Tvůj přístup:
- Vygeneruješ funkční svět.
- Z něj vytvoříš blueprint.
- Blueprint můžeš otočit, zrcadlit a výškově posunout.
- Můžeš ho vložit do jiného světa.
- Výsledný ostrov nemusí mít jeden společný původní seed.

To je podstatný rozdíl.

**Riziko:** Inverzní transformace musí být jednoznačná. Musíš přesně definovat souřadnicové systémy, hranice blueprintů a pořadí rotace a zrcadlení.

Pokud to zvládneš, získáš velmi flexibilní systém skládání světů.

## B. Funkční geologie → SDF → voxelová materializace

<AsyncImage query="3D geological cross section mineral veins ore deposits underground strata cave visualization" aspectRatio="16:9" width="100%"/>

Tohle je technicky zajímavější než běžné ukládání materiálu v jednotlivých voxelech.

Geologie není definovaná jako hotová voxelová mapa. Je definovaná jako prostorová funkce, která určuje materiál v konkrétním bodě.

SDF útvary pak mohou vytvářet:
- Žíly.
- Rudní pně.
- Skarny.
- Dutiny.
- Krasové struktury.

Výsledkem je spojitá geologie, kterou můžeš vzorkovat podle potřeby.

**Riziko:** Výkon. SDF útvary mohou být při každém vyhodnocení drahé. Proto potřebuješ prostorové indexování útvarů a cache jejich výsledků.

Zásadní je také to, aby optimalizace nezměnila výsledné materiálové ID na hranicích vzorkování.

## C. Výchozí voda → dynamická simulace → odchylka

<AsyncImage query="fantasy floating island waterfalls underground springs streams ponds terrain cutaway visualization" aspectRatio="16:9" width="100%"/>

Tady máš velmi zajímavý koncept.

Místo toho, abys celou vodu vždy počítal od nuly, máš:
- Výchozí ustálený vodní stav.
- Procedurální zdroje vody.
- Hydrologickou simulaci.
- Ukládané odchylky od výchozího stavu.

To může výrazně snížit nároky na ukládání.

Ale je zde zásadní problém: **odchylka v objemu vody sama o sobě nemusí popisovat její dynamický stav.**

Je nutné rozlišit:
- Vodu uloženou v buňce.
- Proudící vodu.
- Vodu v pórech horniny.
- Povrchovou hladinu.
- Vodu zadrženou v podzemních strukturách.

Jinak můžeš mít správný celkový objem, ale nesprávné chování simulace.

# 3. Kde vidím největší architektonické nebezpečí?

Ne v jednotlivých algoritmech, ale v jejich kombinaci.

Například:

<box border radius="lg" padding={3} gap={2}>
  **Příklad: Hráč vykopá krasovou dutinu**
  <list connector="solid" marker="number" gap={2}>
    <list-item>Procedurální geologie určí vápenec.</list-item>
    <list-item>Hráč odstraní materiál.</list-item>
    <list-item>Vznikne změna terénu.</list-item>
    <list-item>Voda musí reagovat na novou dutinu.</list-item>
    <list-item>Eroze může změnit výšku povrchu.</list-item>
    <list-item>Renderer, fyzika a hydrologie musí dostat aktuální stav.</list-item>
    <list-item>Server musí změny uložit a ověřit.</list-item>
  </list>
  <divider color="subtle"/>
  **Riziko:** Pokud každý subsystém interpretuje změny trochu jinak, vzniknou rozdílné verze reality.
</box>

Proto bych jako nejdůležitější architektonický princip zavedl:

**Jeden autoritativní efektivní stav terénu, více specializovaných reprezentací.**

To znamená, že renderer, fyzika a voda mohou mít vlastní cache a datové struktury, ale nesmí si samostatně definovat, co je skutečný stav terénu.

# 4. Srovnání s běžnými přístupy

| Vlastnost | Běžný voxel engine | Willage |
|---|---|---|
| Základ světa | Voxelová data | Procedurální funkce |
| Geologie | Materiál v buňce | Funkční geologie + SDF |
| Načítání | Chunk | Segment podle požadavku |
| Změny | Přímá změna voxelů | Delta vůči základu |
| Skládání světa | Chunky jednoho světa | Blueprinty z různých světů |
| Voda | Často oddělená simulace | Výchozí funkce + dynamické odchylky |
| Server | Replikace změn | Reprodukovatelný generátor + validace |

Willage je tedy spíše kombinací **procedurálního world engine, voxelového datového modelu a simulačního systému** než klasickou voxelovou hrou.

# 5. Moje konečné hodnocení

<box border radius="lg" padding={3} gap={2}>
  <title size="2xl" color="success">9/10</title>
  **Originalita a koncepční propojení**
  <divider color="subtle"/>
  <title size="2xl">7/10</title>
  **Technická ověřitelnost současného návrhu**
  <divider color="subtle"/>
  <title size="2xl" color="success">8,5/10</title>
  **Potenciál architektury**
</box>

Moje hodnocení je, že architektura není zbytečně komplikovaná jen proto, že kombinuje více přístupů. Většina kombinací má konkrétní důvod vycházející z požadavků Willage.

Ale upozornil bych na jednu věc: snažíš se vytvořit univerzální procedurální model světa, který současně podporuje editaci, geologii, vodu, skládání ostrovů a budoucí serverovou validaci.

To už je poměrně ambiciózní systém.

**Doporučil bych ještě jeden konkrétní krok:** udělat architektonickou analýzu závislostí mezi subsystémy. Tedy zjistit, které části jsou skutečně nezávislé, které sdílejí data a které se mohou navzájem dostat do konfliktu. Právě tam se podle mě skrývá největší potenciální problém celé architektury.

---

### 52. Uživatel

A jak by to šlo jinak ? 

---

### 53. Asistent

Šlo by to postavit několika jinými způsoby. A některé by byly výrazně jednodušší než současný Willage. Otázkou ale je, kolik vlastností bys musel obětovat.

Vidím celkem **pět alternativních architektur**. Porovnám je s tvým současným návrhem podle toho, co Willage potřebuje: plovoucí ostrovy, těžbu, geologii, vodu, skládání oblastí z různých světů a provoz na mobilních zařízeních.

# 1. Pět alternativních architektur

## Varianta A – Klasický voxelový svět

<AsyncImage query="Minecraft voxel terrain underground mining voxel world cross section" aspectRatio="16:9" width="100%"/>

Všechno je reprezentováno explicitními voxely.

Každý voxel obsahuje například:
- ID materiálu.
- Typ obsahu.
- Případně vodu.
- Další stavové informace.

Svět se rozdělí na chunky, které se načítají a ukládají.

**Výhody**
- Jednoduchá editace a těžba.
- Jednoduchá serverová synchronizace.
- Přímočará materializace.
- Existuje mnoho ověřených technik.

**Nevýhody**
- Velká paměťová náročnost.
- Procedurální generování musí vytvořit velké množství dat.
- Geologické útvary musíš převést do voxelové mapy.
- Skládání různých světů je komplikovanější.

Hodí se, pokud chceš především klasickou voxelovou hru.

## Varianta B – Čistě funkční svět

<AsyncImage query="procedural mathematical terrain function 3D landscape wireframe heightfield" aspectRatio="16:9" width="100%"/>

Žádné trvalé voxelové pole.

Svět je sada matematických funkcí:

```text
GetHeight(x, y)
GetMaterial(x, y, z)
GetWater(x, y, z)
GetDensity(x, y, z)
```

Všechno se vyhodnocuje při dotazu.

**Výhody**
- Minimální paměťové nároky.
- Velmi dobrá reprodukovatelnost.
- Snadné generování rozsáhlého světa.
- Přirozená podpora různých souřadnicových systémů.

**Nevýhody**
- Editace vyžaduje další vrstvu změn.
- Opakované dotazy mohou být drahé.
- Složité simulace nejsou přirozenou součástí statické funkce.

Hodí se pro rozsáhlé procedurální světy s malým množstvím editací.

## Varianta C – SDF / volumetrický svět

<AsyncImage query="signed distance field volumetric terrain caves smooth 3D terrain cutaway" aspectRatio="16:9" width="100%"/>

Základní reprezentací není materiálová buňka, ale skalární pole hustoty nebo vzdálenosti od povrchu.

Například:

\[
D(x,y,z)<0 \Rightarrow \text{pevný materiál}
\]

\[
D(x,y,z)>0 \Rightarrow \text{vzduch}
\]

Materiál může být další funkcí.

**Výhody**
- Přirozené jeskyně, dutiny a nepravidelné útvary.
- Plynulé kopání a deformace.
- Dobrá kombinace s procedurální geologií.
- Přirozené vytváření nepravidelných tvarů.

**Nevýhody**
- Náročnější extrakce geometrie.
- Složitější přesná reprezentace tenkých vrstev.
- Obtížnější ukládání změn.
- Vyšší nároky na mobilní hardware.

Hodí se pro hry, kde jsou důležité plynulé deformace a prostorové útvary.

## Varianta D – Heightmap + vrstvené podzemí

<AsyncImage query="3D terrain heightmap underground geological strata cross section game terrain" aspectRatio="16:9" width="100%"/>

Povrch je reprezentován výškovou funkcí nebo heightmapou.

Podzemí je samostatná struktura vrstev.

Například:

```text
Surface:
    Height(x, y)

Underground:
    Layer(x, y, depth)
    Material(x, y, depth)
    Features(x, y, z)
```

**Výhody**
- Velmi efektivní povrch.
- Jednoduchá hydrologie.
- Výrazně nižší paměťové nároky.
- Dobré pro mobilní zařízení.

**Nevýhody**
- Problematické převisy a jeskyně.
- Obtížnější víceúrovňové podzemí.
- Omezení při kopání tunelů a složitých dutin.

Hodí se pro strategické a survival hry s převážně povrchovou interakcí.

## Varianta E – Hybridní prostorový model

<AsyncImage query="3D voxel terrain hybrid smooth voxel block terrain underground cave geological layers" aspectRatio="16:9" width="100%"/>

Toto je nejbližší alternativní architektura tvému návrhu.

Rozdíl je v tom, že bych nesjednocoval všechny subsystémy do jedné univerzální funkční reprezentace.

Místo toho bych použil několik specializovaných datových modelů:

| Subsystém | Reprezentace |
|---|---|
| Povrch | Heightfield |
| Geologie | Funkce + SDF |
| Podzemí | Sparse voxely |
| Hráčské změny | Delta overlay |
| Voda | Hydrologická síť + objemová data |
| Vegetace | Procedurální objekty |
| Prezentace | Samostatná mesh/voxel vrstva |

**Výhody**
- Každý subsystém používá vhodnou datovou strukturu.
- Dobrá optimalizace.
- Zachovává flexibilitu procedurálního světa.

**Nevýhody**
- Nejsložitější integrace.
- Potřebuješ jasná pravidla vlastnictví dat.
- Přechody mezi reprezentacemi mohou být problematické.

---

# 2. Přímé porovnání

| Vlastnost | A: Voxely | B: Funkce | C: SDF | D: Heightmap | E: Hybrid |
|---|---:|---:|---:|---:|---:|
| Paměť | Nízká až vysoká* | Výborná | Dobrá | Výborná | Dobrá |
| Těžba | Výborná | Složitější | Výborná | Omezená | Výborná |
| Geologie | Dobrá | Výborná | Výborná | Omezená | Výborná |
| Jeskyně | Výborná | Složitější | Výborná | Slabá | Výborná |
| Voda | Dobrá | Složitější | Složitější | Výborná | Výborná |
| Mobilní výkon | Záleží na implementaci | Dobrý | Náročnější | Výborný | Dobrý |
| Skládání světů | Dobré | Výborné | Dobré | Dobré | Výborné |

*Paměť voxelů výrazně závisí na hustotě, kompresi a způsobu materializace.

# 3. Co bych změnil na současném Willage

Já bych nezvolil ani jednu variantu v čisté podobě. Zkusil bych následující architekturu:

<box border radius="lg" padding={3} gap={2}>
  <title size="lg">Willage – alternativní architektura</title>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={3} align="center">
    **World Definition**

    Seed, klima, biom, reliéf, geologie
  </box>
  <icon name="arrow-down"/>
  <grid columns={2} gap={2}>
    <grid-item>
      <box border radius="md" padding={2} gap={1}>
        **Surface Model**
        <caption>Heightfield + lokální deformace</caption>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} gap={1}>
        **Volume Model**
        <caption>SDF + sparse voxely</caption>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} gap={1}>
        **Hydrology**
        <caption>Toky + podzemní voda</caption>
      </box>
    </grid-item>
    <grid-item>
      <box border radius="md" padding={2} gap={1}>
        **Object Model**
        <caption>Vegetace a další objekty</caption>
      </box>
    </grid-item>
  </grid>
  <icon name="arrow-down"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={3} align="center">
    **Effective World State**

    Jednotný kontrakt pro aktuální stav světa
  </box>
  <icon name="arrow-down"/>
  <grid columns={3} gap={2}>
    {#each ["Renderer","Physics","Persistence"] as item}
      <grid-item>
        <box border radius="md" padding={2} align="center">
          **{item}**
        </box>
      </grid-item>
    {/each}
  </grid>
</box>

Tím bys získal jednu důležitou věc: **nemusíš nutit vodu, geologii, vykreslování a těžbu používat stejnou interní datovou strukturu.**

Musí ale sdílet jednoznačný kontrakt efektivního stavu a pravidla aktualizace.

# 4. Co bych osobně vybral pro Willage

<badge color="success">Moje doporučení</badge>

Vybral bych variantu E, ale s jednou zásadní změnou oproti současnému návrhu:

**Oddělil bych výpočetní model od modelu materializace.**

To znamená:

- Procedurální funkce definují svět.
- Specializované subsystémy počítají geologii, vodu a terén.
- Materializace vytváří pouze potřebné datové reprezentace.
- Delta ukládá změny.
- Efektivní stav sjednocuje výsledky.

Tím odstraníš tlak na to, aby jedna datová struktura musela řešit všechny problémy.

---

## 5. Co je ale potřeba rozhodnout

Vidím jednu zásadní otázku, která může změnit celý návrh:

**Chceš, aby Willage byl primárně voxelový svět, nebo procedurální simulační svět, který se pouze vykresluje pomocí voxelů?**

To jsou dvě odlišné filozofie.

{@body const [architecture,setArchitecture] = DIL.useState("simulation")}
<box border radius="lg" padding={3} gap={3}>
  <radio-group direction="col" value={architecture} onChange={setArchitecture}>
    <radio value="voxel">
      **Voxelový svět**

      Buňky jsou skutečným základem světa. Funkce slouží hlavně k jejich počátečnímu vytvoření.
    </radio>
    <radio value="simulation">
      **Procedurální simulační svět**

      Svět existuje jako soustava funkcí a simulací. Voxely jsou jen jedna z jeho materializovaných podob.
    </radio>
    <radio value="hybrid">
      **Rovnocenný hybrid**

      Procedurální funkce a explicitní prostorová data jsou dvě rovnocenné části základního modelu.
    </radio>
  </radio-group>
  <button block onClick={()=>GenUI.issueNewTurn("Pro Willage preferuji filozofii: "+architecture+". Porovnej její důsledky s dosavadním návrhem a navrhni výslednou architekturu.")}>Vyhodnotit architekturu</button>
</box>

Tohle bych vyřešil dříve než další optimalizace. Určuje to totiž, co bude v budoucnu zdrojem pravdy o světě a co bude pouze jeho odvozenou reprezentací.

---

### 54. Uživatel

Hlavním cílem byla malá dstova náročnost a výkonnostní náročnost. Moje varianta mi přišla celkem datové a vykonostně efektivní. Ale je pravdou že mě jiné možnosti nenapadlo jak to řešit. Cílem bylo aby se vygeneroval uvěřitelný kus země kde se bude moct dát kopat, hra bude mix mezi budovatelskou, RPG, simulátorem, crafting. Nejsem zastáncem jednoho  konkrétního směru. 

---

### 55. Asistent (shrnutí uvažování)

Přemýšlel po dobu 15s

---

### 56. Asistent

Teď už lépe chápu, co se snažíš vytvořit. A po tomto upřesnění bych trochu změnil své předchozí hodnocení.

Myslím, že ses vydal správným směrem. Jen bych se přestal snažit rozhodnout, jestli Willage je voxelová hra, procedurální hra, nebo simulátor. **Tohle není rozhodnutí, které by mělo určovat architekturu. Architektura má vycházet z toho, co musí svět umět a kolik prostředků na to může spotřebovat.**

Tvým cílem není vytvořit další Minecraft. Chceš vytvořit uvěřitelný kus země, který hráči mohou skutečně měnit, prozkoumávat, těžit, zastavovat a využívat v rámci ekonomiky, craftingu a simulace.

To je trochu jiný technický problém.

# 1. Co vlastně potřebuje Willage

Zkusil bych definovat požadavky bez vazby na konkrétní technologii.

<box border radius="lg" padding={3} gap={3}>
  **Funkční požadavky na svět**
  <row align=start gap={2}>
    <AsyncImage query="realistic stylized floating island landscape hills forest river" aspectRatio="1:1" maxWidth="88px"/>
    <box flex="1" gap={1}>
      **Přirozený terén**

      Kopce, údolí, svahy, útesy, vodní plochy a geologicky uvěřitelná skladba.
    </box>
  </row>
  <row align=start gap={2}>
    <AsyncImage query="fantasy game mining underground cave ore veins cross section" aspectRatio="1:1" maxWidth="88px"/>
    <box flex="1" gap={1}>
      **Plně editovatelný prostor**

      Kopání, těžba rud, tunely, jeskyně, dutiny, odkrývání vrstev a stavění.
    </box>
  </row>
  <row align=start gap={2}>
    <AsyncImage query="stylized village buildings farming fields roads river game environment" aspectRatio="1:1" maxWidth="88px"/>
    <box flex="1" gap={1}>
      **Budovatelská vrstva**

      Stavby, infrastruktura, využívání materiálů a změny krajiny.
    </box>
  </row>
  <row align=start gap={2}>
    <AsyncImage query="fantasy underground flowing water spring waterfall cave environment" aspectRatio="1:1" maxWidth="88px"/>
    <box flex="1" gap={1}>
      **Simulace prostředí**

      Voda, vsakování, eroze, sedimentace, počasí a vegetace.
    </box>
  </row>
  <row align=start gap={2}>
    <AsyncImage query="fantasy crafting workshop blacksmith mining ore game" aspectRatio="1:1" maxWidth="88px"/>
    <box flex="1" gap={1}>
      **Herní ekonomika a crafting**

      Materiály musí mít skutečné vlastnosti a praktické využití.
    </box>
  </row>
</box>

Z toho vyplývá důležitá věc: svět nemusí být všude stejně detailní.

Hráč může vidět celý ostrov, ale jen malá část bude právě aktivně těžena, zastavována nebo simulována.

To je podle mě největší příležitost k úspoře výkonu.

# 2. Proč se mi tvůj původní návrh vlastně líbí

Tvoje architektura má několik velmi dobrých rozhodnutí, která bych zachoval.

| Tvoje řešení | Proč je výhodné |
|---|---|
| Svět jako funkce | Nemusíš ukládat celý vygenerovaný svět. |
| Blueprinty | Nemusíš znovu generovat stejné oblasti. |
| Inverzní transformace | Můžeš používat části různých světů. |
| Segmenty 8 m | Malá jednotka materializace a ukládání změn. |
| Buňky 0,25 m | Rozumná prostorová granularita pro těžbu. |
| SDF geologické útvary | Nemusíš ukládat kompletní voxelové modely rudných žil. |
| Delta persistence | Neukládáš nezměněnou část světa. |
| Funkční výchozí voda | Nemusíš persistentně uchovávat celý původní vodní systém. |

Všimni si, že většina těchto rozhodnutí má společný princip:

**Neukládat něco, co lze levně a deterministicky znovu vypočítat.**

To je velmi dobrý základ.

# 3. Kde bych hledal ještě větší úspory

Tady bych se na tvůj návrh podíval trochu jinak. Nehledal bych jednu nejlepší reprezentaci terénu. Hledal bych **nejlevnější reprezentaci pro každou činnost, kterou hra potřebuje provádět**.

Například:

| Činnost | Doporučená reprezentace |
|---|---|
| Generování reliéfu | Matematická funkce |
| Geologické vrstvy | Funkce sloupce + SDF útvary |
| Běžný povrch | Heightfield nebo odvozená geometrie |
| Oblast připravená k těžbě | Materializované voxely |
| Hluboké nedotčené podzemí | Funkční geologický model |
| Vykopané tunely | Sparse voxel data |
| Voda | Samostatná hydrologická reprezentace |
| Změny hráče | Sparse delta |

Tohle není kompromis. Je to způsob, jak se vyhnout zbytečným výpočtům a ukládání.

## 4. Největší potenciální problém tvého současného modelu: počet buněk

Podívejme se na tvoje rozměry.

<box border radius="lg" padding={3} gap={2}>
  **Jeden segment 8 × 8 × 128 m**
  <grid columns={3} gap={2}>
    <grid-item>
      <title size="xl" tabularNums>32</title>
      <caption>Buněk X</caption>
    </grid-item>
    <grid-item>
      <title size="xl" tabularNums>32</title>
      <caption>Buněk Y</caption>
    </grid-item>
    <grid-item>
      <title size="xl" tabularNums>512</title>
      <caption>Buněk Z</caption>
    </grid-item>
  </grid>
  <divider color="subtle"/>
  <title size="2xl" tabularNums>524 288</title>
  **Potenciálních voxelů v jednom segmentu**
  <text color="secondary" size="xs">Při 1 bajtu na materiálové ID:</text>
  <title size="xl" tabularNums>512 KiB</title>
  <text color="secondary" size="xs">Bez dalších datových struktur, cache a režie.</text>
</box>

A teď celý blok 128 × 128 m:

- 16 × 16 segmentů.
- 256 segmentů.
- 134 217 728 potenciálních buněk.
- 128 MiB pouze pro materiálová ID.

To je důvod, proč považuji tvé rozhodnutí materializovat pouze slupku za velmi důležité.

**Nedoporučoval bych nikdy automaticky materializovat celý objem bloku.**

Místo toho bych rozlišoval tři stavy:

1. Nevyhodnocený prostor – existuje pouze jako funkce.
2. Vyhodnocený prostor – výsledek je v dočasné cache.
3. Materializovaný prostor – má explicitní data kvůli editaci, simulaci nebo vykreslování.

Tím získáš kontrolu nad tím, kolik paměti skutečně spotřebuješ.

# 5. Alternativa, kterou bych u Willage skutečně zvážil

Nazval bych ji **adaptivní materializace podle aktivity**.

Ne podle vzdálenosti od kamery, ale podle toho, co se v dané oblasti děje.

<AsyncImage query="stylized 3D terrain floating island cutaway showing surface soil underground caves mining tunnels geological layers" aspectRatio="16:9" width="100%"/>

Příklad jednoho ostrova:

| Oblast | Stav | Zpracování |
|---|---|---|
| Vzdálený povrch | Neaktivní | Funkce + hrubá geometrie |
| Viditelný povrch | Aktivní vizuálně | Jemná geometrie |
| Oblast vesnice | Aktivní | Materializace potřebných buněk |
| Těžební oblast | Aktivní interakce | Přesné voxely |
| Hluboké podzemí | Neaktivní | Funkční geologie |
| Vykopaná jeskyně | Trvalá změna | Sparse data + delta |
| Aktivní vodní tok | Simulovaný | Hydrologická cache |

Výhoda je, že celý svět nemusí být ve stejném stavu detailu.

A ještě důležitější: oblast může přecházet mezi stavy podle potřeby, aniž by se změnila její logická identita.

## 6. Co bych naopak nedělal

Některé populární techniky bych pro Willage nepoužil jako univerzální řešení.

- **Kompletní voxelizace:** zbytečně velká paměťová náročnost.
- **SDF pro celý svět:** drahé vyhodnocování a komplikovaná persistence.
- **Čistá heightmapa:** omezuje tunely, převisy a víceúrovňové podzemí.
- **Octree všude:** přidává režii a složitost i tam, kde je prostor pravidelný.
- **Jedna společná mřížka pro všechny simulace:** nutí vodu, geologii i renderer používat stejnou granularitu.

Poslední bod považuji za zvlášť důležitý. Voda například nemusí být počítána v každém voxelovém kroku 0,25 m. Může se počítat na hrubší síti a detailněji pouze tam, kde je to herně potřeba.

# 7. Jak bych výslednou architekturu upravil

<box border radius="lg" padding={3} gap={2}>
  <title size="lg">Doporučený model Willage</title>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={3} align="center">
    **Procedurální svět**

    Seed, klima, biom, reliéf, geologie
  </box>
  <icon name="arrow-down"/>
  <box background="rgba(59,130,246,0.12)" radius="md" padding={3} align="center">
    **Funkční prostorový model**

    Výška, materiál, vrstvy, útvary, výchozí voda
  </box>
  <icon name="arrow-down"/>
  <box border radius="md" padding={3} gap={2}>
    **Adaptivní materializace**
    <grid columns={2} gap={2}>
      <grid-item>
        <box background="rgba(59,130,246,0.09)" radius="md" padding={2}>
          **Surface**

          <caption>Geometrie povrchu</caption>
        </box>
      </grid-item>
      <grid-item>
        <box background="rgba(59,130,246,0.09)" radius="md" padding={2}>
          **Volume**

          <caption>Voxely a dutiny</caption>
        </box>
      </grid-item>
      <grid-item>
        <box background="rgba(59,130,246,0.09)" radius="md" padding={2}>
          **Hydrology**

          <caption>Voda a její stav</caption>
        </box>
      </grid-item>
      <grid-item>
        <box background="rgba(59,130,246,0.09)" radius="md" padding={2}>
          **Objects**

          <caption>Vegetace a objekty</caption>
        </box>
      </grid-item>
    </grid>
  </box>
  <icon name="arrow-down"/>
  <box background="rgba(22,163,74,0.12)" radius="md" padding={3} align="center">
    **Efektivní stav světa**

    Autoritativní stav + persistentní změny
  </box>
</box>

Důležitá podmínka: jednotlivé reprezentace nesmí být samostatnými zdroji pravdy. Musí být odvozené z jednoho konzistentního stavu a mít jasně definovanou invalidaci.

---

# 8. Můj závěr

Po tvém vysvětlení bych původní architekturu nezavrhoval. Naopak.

Myslím, že jsi intuitivně dospěl k velmi dobrému řešení pro kombinaci procedurálního světa a editovatelného terénu.

Co bych změnil:

- Zachoval bych funkční svět.
- Zachoval bych blueprinty.
- Zachoval bych 0,25m voxelovou granularitu pro přesnou editaci.
- Zachoval bych delta persistence.
- Zachoval bych funkční geologii.
- Změnil bych přístup k materializaci tak, aby byla adaptivní a nezávislá na konkrétní reprezentaci.

**Největší optimalizaci podle mě nezískáš tím, že budeš mít menší voxel. Získáš ji tím, že nebudeš počítat a držet v paměti data, která právě nikdo nepotřebuje.**

A navrhuji jako další krok udělat konkrétní výkonnostní model Willage: spočítat paměť a výpočetní náklady pro jednotlivé varianty materializace na jednom bloku 128 × 128 m, včetně povrchu, podzemí, vody a editace. To nám umožní rozhodovat podle čísel, ne podle dojmu.

---

### 57. Uživatel

Proč jsem chtěl výpočet vodních toků a i pod zemí. Chtěl jsem to jako funkci. A to kuli tomu že když se hráč prokope k vodě tak se může začít nějak chovat, nebo když ji prokope cestu k propustné vrstvě tak se tam začne ztrácet/rozlévat. A taky při skládání ostrova se může rozlít nebo začít vsakovat do již usazených bloků. 

---

### 58. Asistent

Tohle je důležité upřesnění. A mění to, jak bych se díval na vodní simulaci v architektuře Willage.

Ty totiž nechceš simulovat vodu jen proto, aby na povrchu hezky tekly potůčky. Chceš, aby **voda byla přirozenou vlastností materiálu a prostoru, která reaguje na změny geometrie a geologie**.

Jinými slovy: hráč nemá vodu pouze pozorovat. Má možnost odhalit, přesměrovat, vypustit nebo změnit její tok.

## Proč dává funkční model vody smysl

Vidím u tebe čtyři hlavní situace:

<box gap={3}>
  <row align=start gap={3}>
    <AsyncImage query="fantasy game terrain underground water aquifer cave tunnel water spring cross section" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **1. Proražení k podzemní vodě**

      Hráč kope do země a prorazí zvodnělou vrstvu nebo podzemní dutinu. Voda začne vytékat do výkopu, zaplavovat ho nebo hledat cestu ven.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="geological cross section water leaking through porous soil layers underground" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **2. Proražení propustné vrstvy**

      Hráč otevře cestu zadržované vodě do propustné horniny. Voda začne prosakovat, rozlévat se nebo postupně měnit svou podzemní cestu.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="water flowing over terrain between floating island rock blocks waterfall fantasy environment" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **3. Skládání ostrova z bloků**

      Nově připojený blok změní geometrii terénu a hydraulické podmínky. Voda se může rozlít do sousedního bloku, začít vsakovat nebo změnit směr odtoku.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="underground cave spring water emerging from rock wall into pool" aspectRatio="5:4" maxWidth="116px"/>
    <box flex="1" gap={1}>
      **4. Změna podzemního systému**

      Výkop, dutina nebo propojení dvou vrstev může změnit tlakové a průtokové poměry. Na jiném místě se může objevit nový pramen nebo zaniknout původní.
    </box>
  </row>
</box>

## Co z toho plyne pro architekturu

Tady bych opravil jednu věc z mého předchozího doporučení: **voda by neměla být pouze lokální simulací nad již materializovanými voxely.**

Potřebuješ funkční hydrologický model, který dokáže odpovědět na otázku:

> Jak se bude voda chovat v tomto místě, pokud se změní terén, materiál nebo propojení podzemních prostor?

To ale neznamená, že musíš permanentně simulovat každou buňku.

Navrhoval bych tři oddělené vrstvy:

<box border radius="lg" gap={3} padding={3}>
  **1. Hydrologický potenciál – funkce**

  Popisuje přirozené podmínky:
  - zdroje vody a jejich vydatnost,
  - hladiny a tlakové poměry,
  - propustnost a pórovitost hornin,
  - přirozené podzemní cesty,
  - terén a gravitační potenciál.

  <badge color="success">Procedurální, deterministický základ</badge>
  <divider color="subtle"/>
  **2. Hydrologická topologie – odvozená síť**

  Popisuje propojení:
  - povodí a povrchové toky,
  - zvodnělé vrstvy,
  - propustné a nepropustné oblasti,
  - podzemní propojení a vývěry,
  - otevřené dutiny a nově vzniklé cesty.

  <badge color="info">Vypočítává se a cachuje</badge>
  <divider color="subtle"/>
  **3. Dynamický stav vody – simulace**

  Obsahuje skutečné změny:
  - objem vody,
  - aktuální průtok,
  - zaplavení,
  - vsakování,
  - změny hladin,
  - odchylky způsobené hráčskými zásahy.

  <badge color="warning">Ukládají se změny a důležité stavy</badge>
</box>

## Jak by to fungovalo při hráčské akci

Představ si konkrétní příklad:

1. V hornině existuje podzemní voda, jejíž základní rozložení určuje procedurální funkce.
2. Hráč vykope tunel a propojí ho se zvodnělou oblastí.
3. Systém zjistí nové propojení.
4. Přepočítá dotčenou hydrologickou oblast.
5. Voda začne proudit do tunelu podle rozdílu potenciálu, propustnosti a odporu.
6. Pokud tunel ústí do další propustné vrstvy, část vody se začne vsakovat.
7. Pokud je výtok větší než schopnost vrstvy vodu přijímat, voda se začne hromadit nebo odtékat dál.

Při připojení nového ostrovního bloku by se postupovalo podobně: zjistí se změněná topologie a přepočítá se oblast, kterou nové spojení ovlivnilo.

## Co bych změnil na původním návrhu

Původní záměr zachovat, ale přesněji definovat jednotlivé výpočty.

| Oblast | Doporučený princip |
|---|---|
| Výchozí voda | Funkční hydrologický model |
| Podzemní voda | Vrstvy a propojené zvodnělé oblasti |
| Propustnost | Vlastnost materiálu |
| Povrchový tok | Síť odtoku s lokální dynamikou |
| Podzemní tok | Potenciál + hydraulická vodivost |
| Výkop | Změna topologie a lokální přepočet |
| Připojení bloku | Aktualizace hranic a propojení |
| Ukládání | Dynamické odchylky od výchozího stavu |

Jedna důležitá technická poznámka: samotná propustnost materiálu nestačí. Pro realistické chování budeš potřebovat také pórovitost, nasycení, hydraulický potenciál, retenční schopnost a případně tlak. Voda v propustné vrstvě totiž nemusí automaticky téct dolů – může téct i do stran nebo vzhůru, pokud tomu odpovídá tlakový gradient.

## Můj závěr

Teď už chápu, proč jsi chtěl vodu jako funkci. Nejde jen o efekt počasí nebo dekoraci. Voda je součástí interaktivního modelu země.

A právě proto bych ji neomezoval na hrubší samostatnou mřížku bez vazby na geologii. Může mít vlastní výpočetní rozlišení, ale musí respektovat skutečné materiálové a prostorové podmínky.

**Zásadní princip pro Willage bych formuloval takto:**

*Svět definuje výchozí hydrologické podmínky. Geometrie a materiály určují možné cesty vody. Hráčské zásahy mění jejich propojení. Simulace počítá následky těchto změn.*

Dalším krokem by bylo navrhnout konkrétní hydrologický model, který pokryje povrchovou vodu, podzemní zvodně, propustnost, tlak a změny topologie, aniž by vyžadoval permanentní simulaci celého ostrova.

---

### 59. Uživatel

Zdroje vody jsem definoval jako speciální voxely které generují vodu. 

---

### 60. Asistent

To je dobré řešení. V tom případě bych zdroje vody vůbec neodděloval jako samostatný generátor hydrologického systému. **Speciální voxel je lokální zdroj vody, který je součástí samotného materiálového modelu světa.**

To má několik výhod:

- Zdroj existuje na konkrétních souřadnicích.
- Jeho okolní geologie určuje, jak se voda šíří.
- Hráč ho může odhalit kopáním.
- Může ho propojit s jinými vrstvami nebo dutinami.
- Připojení dalšího bloku může změnit jeho odtokové podmínky.
- Zdroj nemusí být materializovaný, dokud není potřeba.

### Jak bych zdrojový voxel definoval

Například:

| Vlastnost | Význam |
|---|---|
| `material_id` | Identifikace zdrojového voxelu |
| `source_type` | Pramen, tlaková voda, podzemní rezervoár |
| `generation_rate` | Produkce vody za čas |
| `pressure` | Výchozí tlak, pokud je relevantní |
| `capacity` | Případný limit zásoby |
| `active_condition` | Podmínky, za kterých zdroj produkuje vodu |

Ne všechny vlastnosti musí být uložené přímo ve voxelu. Část může být definovaná v materiálové tabulce a část jako parametry konkrétní instance.

### Důležitý rozdíl: zdroj versus zásoba vody

Rozlišoval bych dvě věci:

- **Zdrojový voxel:** průběžně dodává vodu.
- **Vodní voxel / zásoba:** obsahuje určité množství vody, které může odtéct, prosáknout nebo se vypařit.

To je zásadní například při vykopání studny. Hráč může narazit na zdroj s průběžným přítokem, ale také pouze na konečnou zásobu vody.

<AsyncImage query="geological underground aquifer water spring source cross section porous rock layers educational illustration" aspectRatio="16:9" width="100%"/>

### Jedna věc, kterou bych ještě vyřešil

Pokud zdrojový voxel produkuje například 2 litry za sekundu, musí být jasné, co se stane, když nemá kam vodu odvádět.

Může:
1. Zvyšovat tlak.
2. Zvyšovat množství zadržené vody.
3. Dosáhnout kapacity a zastavit produkci.
4. Vytvořit nový výtok, pokud překročí určitou hranici.

Tohle rozhodnutí ovlivní celý model podzemní vody.

**Můj návrh:** zachoval bych zdrojové voxely jako základní mechanismus vzniku vody a nad nimi vybudoval hydraulický model, který řeší její pohyb. Tím zůstane generování vody jednoduché a její chování může být poměrně komplexní.

Zajímalo by mě ještě, jestli jsi zdrojové voxely zamýšlel jako nekonečné generátory, nebo jako výstup z nějaké omezené podzemní zásoby. To je důležitý rozdíl pro návrh simulace.

---

### 61. Uživatel

Dosáhne kapacity , zvýší tlak a pokud i tak nikam neunikne zastaví další produkci. 

---

### 62. Asistent

Tohle je podle mě správná mechanika. Vytváříš tím **tlakový vodní zdroj s omezenou akumulační kapacitou**, nikoliv nekonečný generátor vody, který ji bez ohledu na okolí neustále přidává do světa.

Pro Willage bych jeho chování definoval jako stavový proces:

## Chování zdrojového voxelu

<box border radius="lg" padding={3} gap={2}>
  <box background="rgba(34,197,94,0.09)" radius="md" padding={3} align=center>
    **1. Volná produkce**

    Zdroj produkuje vodu stanovenou rychlostí.
    <text color="success" weight="medium" size="sm">Voda má kam odtékat.</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.09)" radius="md" padding={3} align=center>
    **2. Hromadění vody**

    Okolí nedokáže přijmout celý přítok. Voda se akumuluje a zvyšuje tlak.
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(245,158,11,0.09)" radius="md" padding={3} align=center>
    **3. Maximální kapacita**

    Zdroj dosáhne maximální zásoby a tlaku.
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(239,68,68,0.09)" radius="md" padding={3} align=center>
    **4. Pozastavení produkce**

    Pokud voda nemůže uniknout, další produkce se zastaví.
  </box>
  <caption color="secondary">Po uvolnění odtoku se tlak sníží a produkce může znovu pokračovat.</caption>
</box>

## Doporučený matematický model

Pro jeden zdroj:

\[
\frac{dV}{dt}=Q_{in}-Q_{out}
\]

Kde:

- \(V\) = aktuální objem vody,
- \(Q_{in}\) = produkce zdroje,
- \(Q_{out}\) = odtok do okolí.

Tlak může být funkcí zaplnění rezervoáru:

\[
P=f\left(\frac{V}{V_{max}}\right)
\]

Produkce se zastaví při současném splnění podmínek:

\[
V=V_{max}\quad \land \quad Q_{out}=0
\]

V praxi bych přidal malou toleranci a hysterezi, aby zdroj při hraničních podmínkách nepřepínal mezi aktivním a neaktivním stavem každým simulačním krokem.

## Co je na tom architektonicky zajímavé

Tímto přístupem můžeš mít jeden univerzální mechanismus pro různé situace:

- Pramen v hornině.
- Tlakovou podzemní vodu.
- Vodní rezervoár.
- Průsak z jedné geologické vrstvy do druhé.
- Výtok po proražení hráčem.

Rozdíly mohou být pouze v parametrech zdrojového voxelu a okolních materiálů.

**Důležitá věc pro další návrh:** tlak by neměl být jen vizuální parametr. Měl by ovlivňovat schopnost vody překonávat odpor okolních materiálů. Pak může voda například prorazit do sousední propustné vrstvy, i když by se tam při běžném gravitačním vsakování nedostala.

Doporučil bych teď definovat společný hydraulický model pro zdroje, volnou vodu a nasycené póry. Tím se vyhneme tomu, že každá z těchto situací bude mít vlastní, vzájemně neslučitelnou simulaci.

---

### 63. Uživatel

Není odběr=není produkce. 

---

### 64. Asistent

Přesně. Takže zdroj není generátor, který vyrábí vodu nezávisle na okolí. Je to **zdroj s produkcí řízenou skutečným odběrem**.

To znamená:

- Pokud voda volně odtéká, zdroj ji doplňuje.
- Pokud okolí vodu nepřijímá, produkce klesá.
- Pokud není žádný odběr, produkce je nulová.
- Pokud se voda hromadí, roste tlak.
- Po dosažení maximální kapacity se produkce zastaví.
- Jakmile se obnoví odběr, produkce může pokračovat.

Matematicky bych to vyjádřil:

\[
Q_{production} = \min(Q_{demand}, Q_{max})
\]

Přičemž produkce musí respektovat dostupnou kapacitu a tlakové podmínky.

**Tohle je podstatný rozdíl oproti klasickému nekonečnému zdroji vody.** Zdroj reaguje na hydraulický systém, nikoliv pouze na čas.

Pro Willage bych tuto vlastnost zapsal jako základní invariant: *Zdroj vody nevytváří vodu bez hydraulického odběru.*

Dalším krokem je definovat, jak se počítá odběr při proudění do propustné vrstvy, volného prostoru a sousedního vodního voxelu.

---

### 65. Uživatel

Je to jak kohoutek od vodovodu , a materiál je ten kohoutek. Poušti víc nebo míň. 

---

### 66. Asistent

Teď je to jasné. A moje předchozí interpretace byla zbytečně komplikovaná.

**Zdrojový voxel je v podstatě vodovodní kohoutek. Materiál určuje, jak moc je otevřený.**

Nemusíme tedy modelovat přirozenou produkci vody podle poptávky jako samostatný proces. Stačí hydraulický model, ve kterém zdroj umožňuje průtok podle podmínek okolí.

### Navržený princip

\[
Q = K \cdot \Delta P
\]

Kde:

- \(Q\) – aktuální průtok,
- \(K\) – vodivost zdrojového materiálu (otevření kohoutku),
- \(\Delta P\) – rozdíl hydraulického potenciálu.

Průtok se samozřejmě omezí maximální vydatností zdroje.

### Co to znamená v praxi

| Situace | Chování |
|---|---|
| Volný výtok | Voda proudí podle vodivosti zdroje. |
| Úzká cesta | Průtok omezí odpor cesty. |
| Propustná vrstva | Voda se postupně vsakuje. |
| Nepropustné okolí | Voda se hromadí a roste tlak. |
| Uzavřený prostor | Průtok se zastaví. |
| Otevření nové cesty | Voda začne znovu proudit. |

Důležité je, že materiál zdrojového voxelu určuje jeho vodivost, zatímco okolní materiály určují odpor další cesty.

**Tím získáváme jeden společný hydraulický princip pro povrchovou i podzemní vodu.**

Navrhoval bych nyní definovat materiálové parametry vody tak, aby zdroj, propustná hornina i nepropustná bariéra používaly stejný výpočetní model, ale každý měl jinou hydraulickou funkci.

---

### 67. Uživatel

Zdroj má tedy maximální tlak a objem vody který zvládne  vyprodukovat. 

---

### 68. Asistent

Ano. Tím už máme poměrně přesně definovaný model zdrojového voxelu. Má tři základní parametry:

1. **Maximální tlak (`max_pressure`)** – nejvyšší tlak, který zdroj dokáže vytvořit.
2. **Maximální průtok (`max_flow_rate`)** – maximální objem vody, který dokáže dodat za jednotku času.
3. **Kapacita (`max_capacity`)** – maximální množství vody, které může zdroj zadržet při omezeném nebo nulovém odběru.

Aktuální průtok pak závisí na hydraulických podmínkách a vodivosti zdroje.

### Příklad

<box border radius="lg" padding={3} gap={2}>
  **Zdroj vody – příklad parametrů**
  | Parametr | Hodnota |
  |---|---:|
  | Maximální tlak | 300 kPa |
  | Maximální průtok | 5 l/s |
  | Maximální kapacita | 200 l |
  <divider color="subtle"/>
  **Možné provozní stavy**
  - Volný výtok: až 5 l/s.
  - Částečně omezený výtok: například 2 l/s.
  - Uzavřená cesta: tlak roste, voda se hromadí.
  - Dosažení kapacity: další průtok se zastaví.
</box>

Ještě bych rozlišil jednu fyzikální věc: maximální tlak a maximální kapacita jsou nezávislé limity. Tlak určuje schopnost vody překonávat odpor, kapacita určuje, kolik vody může být zadrženo.

**Pro další návrh je důležité určit, zda zdroj po uvolnění kapacity okamžitě obnoví průtok, nebo zda se jeho průtok plynule mění podle aktuálního tlaku a odběru.** To rozhodne o stabilitě simulace.

---

### 69. Uživatel

Jako může se vygenerovat i hydrologická mapa a na základě ní se můžou rozmisťovat vodní zdroje. 

---

### 70. Asistent

Ano. A to je podle mě velmi dobré propojení procedurálního generování světa s hydrologickou simulací.

Dokonce bych tento postup preferoval před náhodným rozmísťováním zdrojových voxelů. **Hydrologická mapa by určovala, kde je vznik vodního zdroje geograficky pravděpodobný. Samotný zdroj by pak byl reprezentován speciálním voxelem s vlastními hydraulickými parametry.**

## Navrhovaný postup generování

<box border radius="lg" padding={3} gap={3}>
  <box gap={1}>
    **1. Generování terénu a geologie**

    <AsyncImage query="procedural terrain geological elevation map mountain valley terrain topographic visualization" aspectRatio="16:9" width="100%"/>
    Výška terénu, sklon, horniny, propustnost, nepropustné vrstvy a podzemní struktury.
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box gap={1}>
    **2. Výpočet hydrologické mapy**

    <AsyncImage query="hydrology watershed flow accumulation drainage basin map GIS visualization" aspectRatio="16:9" width="100%"/>
    Výpočet povodí, odtokových cest, akumulace vody, infiltrace a potenciálních podzemních cest.
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box gap={1}>
    **3. Určení vhodných míst pro zdroje**

    <AsyncImage query="groundwater springs aquifer recharge geological cross section diagram" aspectRatio="16:9" width="100%"/>
    Například kontakt propustné a nepropustné vrstvy, údolí, podzemní akumulační oblasti nebo krasové systémy.
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box gap={1}>
    **4. Umístění zdrojových voxelů**

    <AsyncImage query="fantasy underground natural spring flowing from rock wall cave water source" aspectRatio="16:9" width="100%"/>
    Každý zdroj dostane parametry tlaku, kapacity a maximálního průtoku. Okolní materiály ovlivní skutečné proudění.
  </box>
</box>

## Jakou hydrologickou mapu bych vytvořil

Nedělal bych jednu univerzální mapu. Vytvořil bych několik odvozených polí:

| Mapa / pole | Účel |
|---|---|
| Flow Direction | Směr povrchového odtoku |
| Flow Accumulation | Množství vody přitékající z okolí |
| Watershed | Rozdělení území na povodí |
| Infiltration Potential | Potenciál vsakování |
| Groundwater Potential | Potenciál výskytu podzemní vody |
| Aquifer Connectivity | Propojení zvodnělých oblastí |
| Spring Potential | Vhodnost místa pro pramen |

Tyto mapy nemusí mít rozlišení 0,25 m. Pro prvotní generování bych experimentoval s rozlišením 1–2 m a následně zpřesňoval pouze oblasti, kde se mají umístit zdroje nebo kde je potřeba detailní simulace.

## Důležitá věc: hydrologická mapa není samotná simulace

Tady bych zachoval jasné rozdělení:

- **Generátor světa:** vypočítá pravděpodobné hydrologické podmínky.
- **Generátor zdrojů:** umístí speciální zdrojové voxely.
- **Hydrologická simulace:** vypočítá skutečné chování vody.
- **Hráčské zásahy:** mění geometrii a propojení, čímž vyvolávají nové výpočty.

Výhodou je, že při prvním vytvoření ostrova nemusíš simulovat veškerou vodu do detailu. Můžeš vygenerovat její výchozí rozložení a teprve při interakci hráče spustit přesnější výpočet.

## Ještě jeden zajímavý důsledek

Hydrologická mapa může ovlivňovat i samotnou herní ekonomiku a gameplay:

- Kde hráč najde studnu.
- Kde se vyplatí stavět vodní mlýn.
- Kde bude možné zavlažovat.
- Kde hrozí zatopení dolu.
- Kde lze najít podzemní pramen.
- Kde se vyplatí těžit propustné nebo nepropustné horniny.

**Doporučil bych jako další krok navrhnout generátor hydrologické mapy pro blok 128 × 128 m**, který bude pracovat s geologií Willage V1.0 a bude umět určit jak povrchové toky, tak potenciální podzemní zvodně a místa pro zdrojové voxely.

---

### 71. Uživatel

Hydrologická mapa by tedy i mohla poskytovat ustálený stav vodních toků a změny by se pak dopočítávali. 

---

### 72. Asistent

Přesně. A tím se podle mě dostáváme k velmi zajímavé architektuře: **hydrologická mapa nebude pouze podkladem pro rozmístění zdrojů, ale bude představovat výchozí ustálený hydrologický stav ostrova.**

Dynamická simulace pak nebude muset počítat celý vodní systém od nuly. Bude počítat pouze změny oproti tomuto stavu.

## 1. Hydrologická mapa jako výchozí stav

Při generování ostrova se vypočítá:

- přirozené povrchové toky,
- výchozí hladiny vody,
- podzemní zvodně,
- nasycení propustných vrstev,
- přirozené prameny a vývěry,
- směry odtoku a vsakování,
- zdrojové voxely a jejich parametry.

Výsledkem bude referenční hydrologický stav.

<AsyncImage query="detailed geological hydrology cross section surface river groundwater aquifer springs infiltration illustration" aspectRatio="16:9" width="100%"/>

## 2. Hráč mění svět → počítají se odchylky

Příklad: hráč vykope tunel do zvodnělé vrstvy.

<box border radius="lg" padding={3} gap={2}>
  <row align=center justify=between>
    **Výchozí stav**
    <badge color="success">Ustálený</badge>
  </row>
  Voda proudí přirozenými cestami a podzemní hladina je stabilní.
  <divider color="subtle"/>
  <row align=center justify=between>
    **Zásah hráče**
    <badge color="warning">Změna topologie</badge>
  </row>
  Výkop propojí zvodeň s novou dutinou.
  <divider color="subtle"/>
  <row align=center justify=between>
    **Nový výpočet**
    <badge color="info">Lokální simulace</badge>
  </row>
  Přepočítá se dotčená hydrologická oblast. Voda začne proudit do tunelu a mění se tlak i hladina.
  <divider color="subtle"/>
  <row align=center justify=between>
    **Nový stav**
    <badge color="success">Ustálení</badge>
  </row>
  Po odeznění změn vznikne nový ustálený stav.
</box>

## 3. Rozdělení dat

Navrhl bych tři samostatné datové vrstvy:

| Vrstva | Obsah | Persistence |
|---|---|---|
| Hydrologický základ | Výchozí ustálený stav | Odvoditelný z generátoru |
| Hydrologické změny | Odchylky způsobené zásahy | Ukládat |
| Aktivní simulace | Aktuální průtoky, tlak, přechodové jevy | Cache / průběžné ukládání podle potřeby |

Důležité je, aby se hydrologický základ nikdy nepřepisoval hráčskými změnami. Je to referenční stav, ke kterému lze simulaci vztáhnout.

## 4. Jedna důležitá technická nuance

Ustálený stav není totéž co nulový průtok.

Řeka může mít ustálený stav, přestože jí neustále protéká voda. Stejně tak podzemní zvodeň může mít stabilní hladinu, zatímco voda přitéká a odtéká.

Proto bych u každé oblasti rozlišoval:

- objem vody,
- hydraulický potenciál,
- průtok,
- přítok a odtok,
- nasycení materiálu.

A ještě jedna věc: změna jednoho výkopu nemusí ovlivnit jen sousední segment. Může ovlivnit celé propojené povodí nebo zvodeň. Proto by se přepočet měl řídit **hydrologickou konektivitou**, ne pouze geometrickou vzdáleností.

## 5. Jak bych to koncepčně pojmenoval

<box border radius="lg" padding={3} gap={2}>
  <title size="lg">Hydrological Baseline + Delta Simulation</title>
  <text color="secondary" size="sm">Výchozí hydrologický stav a simulace odchylek</text>
  <box background="surface-secondary" radius="md" padding={3} align=center>
    **Procedural Hydrology**

    Výchozí ustálený stav
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="surface-secondary" radius="md" padding={3} align=center>
    **Hydrological Delta**

    Změny terénu, materiálu a propojení
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary"/>
  </box>
  <box background="surface-secondary" radius="md" padding={3} align=center>
    **Dynamic Simulation**

    Přechodové jevy a nové rovnovážné podmínky
  </box>
</box>

**Můj názor:** Tohle je pro Willage vhodnější než permanentní simulace celého vodního systému. Zachováš komplexní interakce vody s geologií, ale většinu času můžeš pracovat s předpočítaným stavem.

Jako další krok bych definoval datovou strukturu hydrologického baseline a pravidla, podle kterých se z výkopu nebo připojení nového bloku určí rozsah nutného přepočtu.

---

### 73. Uživatel

Hele je rozumné místo zápisu konkrétních změn jako voxely, editovat procedurální funkci ? 

---

### 74. Asistent

Ano. A dokonce si myslím, že je to jedna z nejzajímavějších alternativ pro Willage. Jen bych rozlišoval, **co přesně znamená editovat procedurální funkci**.

Místo toho, abys při každém kopnutí ukládal změnu jednotlivých voxelů, můžeš ukládat změnu parametrů nebo samotné definice světa. Výsledná geometrie se potom znovu vypočítá.

## 1. Dva přístupy

<box border radius="lg" padding={3} gap={3}>
  **A. Voxelová delta**

  <AsyncImage query="voxel terrain digging block game terrain cross section grid" aspectRatio="16:9" width="100%"/>
  Původní procedurální funkce zůstává nezměněná. Ukládáš seznam změněných buněk.

  ```text
  Cell(12, 8, 24) = Air
  Cell(12, 8, 25) = Air
  Cell(13, 8, 24) = Air
  ```

  Výhody:
  - Jednoznačná změna.
  - Jednoduchá persistence.
  - Přesná editace jednotlivých buněk.

  Nevýhody:
  - Velké množství záznamů při rozsáhlých úpravách.
  - Nutnost slučovat změny a původní procedurální stav.
  <divider color="subtle"/>
  **B. Editace procedurální funkce**

  <AsyncImage query="signed distance field terrain sculpting volumetric terrain boolean subtraction visualization" aspectRatio="16:9" width="100%"/>
  Místo ukládání jednotlivých buněk ukládáš operaci nad funkcí.

  ```text
  SubtractSphere(
      center = (12, 8, 24),
      radius = 1.5
  )
  ```

  Výsledný terén vznikne vyhodnocením původní funkce a následných operací.

  Výhody:
  - Kompaktní zápis rozsáhlých změn.
  - Přirozená podpora kopání a tvarování.
  - Možnost znovu vytvořit geometrii v libovolném místě.

  Nevýhody:
  - Složitější pořadí operací.
  - Náročnější vyhodnocování.
  - Nutnost řešit překrývání, materiály a návaznost operací.
</box>

## 2. Co bych zvolil pro Willage

Nevolil bych výhradně jednu variantu. Použil bych **procedurální základ + seznam geometrických operací + lokální materializaci**.

Například:

\[
F_{effective}=F_{base}\oplus O_1\oplus O_2\oplus \ldots O_n
\]

Kde:

- \(F_{base}\) je původní procedurální funkce.
- \(O_i\) jsou editace hráčů, eroze, dutiny a další změny.
- \(F_{effective}\) je výsledná funkce světa.

Operace mohou být například:

| Operace | Význam |
|---|---|
| Subtract | Vykopání materiálu |
| Add | Přidání materiálu |
| ReplaceMaterial | Změna materiálu |
| Deform | Změna geometrie |
| CreateCavity | Vytvoření dutiny |
| ModifyPorosity | Změna propustnosti |

Výsledná funkce se vyhodnocuje jen v potřebném rozsahu. Mesh a voxelová reprezentace jsou potom odvozené cache.

## 3. Zajímavější je, že to může sjednotit i vodu

Stejný princip můžeš použít pro hydrologii.

Původní hydrologická funkce definuje ustálený stav. Výkop není pouze změna voxelů, ale geometrická operace, která změní hydraulickou konektivitu.

Například:

```text
Base:
  Aquifer A
  Impermeable layer
  Aquifer B

Operation:
  SubtractTunnel(...)

Recalculate:
  Aquifer A <-> Tunnel
  New water flow
```

To je elegantnější než udržovat nezávislé seznamy voxelových změn a ručně synchronizovat geometrii s vodou.

## 4. Na co si dát pozor

Největší problém není samotné ukládání operací, ale jejich dlouhodobé vyhodnocování.

Představ si ostrov s 50 000 výkopy a úpravami. Pokud musíš při každém dotazu projít všechny operace, výkon bude špatný.

Proto bych zavedl:

- prostorový index operací,
- rozdělení operací podle segmentů,
- cache výsledné funkce,
- periodické vytvoření checkpointu,
- možnost sloučit starší operace do nové procedurální reprezentace.

A hlavně: operace musí mít deterministické pořadí a identitu.

## 5. Moje doporučení

| Oblast | Doporučená reprezentace |
|---|---|
| Původní svět | Procedurální funkce |
| Geologie | Funkce + SDF útvary |
| Hráčské kopání | Geometrické operace |
| Změny materiálu | Lokální operace / voxelová delta |
| Voda | Hydrologická funkce + dynamické odchylky |
| Rendering | Materializovaná geometrie / mesh |
| Persistence | Operace + checkpointy |

**Důležitá výhrada:** ne každou změnu lze rozumně reprezentovat geometrickou operací. Například vytěžení rudy, její odebrání z inventáře, změna vlastnosti materiálu nebo voda, která skutečně protekla a odpařila se, potřebují vlastní stav.

---

### Ještě jedna architektonická možnost

Zvážil bych, jestli by pro Willage nebylo nejlepší mít místo jedné procedurální funkce **kompozitní světovou funkci**, která skládá geometrii, materiály, geologii a hydrologii z několika nezávislých funkcí a operací.

Tím bys nemusel mít voxelová data jako hlavní zdroj pravdy, ale zároveň bys nebyl závislý na jedné obrovské a stále složitější funkci.

Tohle bych před implementací porovnal na jednom scénáři: vykopání tunelu o délce 20 metrů, změna geologie a následné zaplavení. Rozdíl v RAM, CPU, velikosti uložených dat a náročnosti přepočtu by ukázal, zda se vyplatí přejít od voxelových delt k operačnímu modelu.

---

### 75. Uživatel

Přemýšlím jak efektivně vygenerovat geologické vrstvy. Napadl mě použít perlín + fraktální šum terén a pan aplikovat offsety s šumem až na dno. 

---

### 76. Asistent (shrnutí uvažování)

Přemýšlel po dobu 12s

---

### 77. Asistent

Tohle je rozumný směr. Dokonce bych ho považoval za jednu z efektivnějších možností, jak generovat geologické vrstvy bez toho, abys musel vytvářet a ukládat každou voxelovou buňku zvlášť.

Pokud správně chápu záměr, chceš vytvořit geologický profil, který bude kopírovat povrch terénu, ale jednotlivé vrstvy budou mít vlastní zvlnění a nepravidelnosti až směrem ke dnu ostrova.

Zásadní je podle mě oddělit dvě věci:

- **Geologická stratifikace:** základní pořadí a mocnost vrstev.
- **Geologická deformace:** zvlnění, uklínění, lokální změny mocnosti a poruchy.

Nemusíš kvůli tomu generovat plný 3D objem.

## 1. Jak bych to matematicky postavil

Nejdříve vytvoř základní povrch:

\[
H(x,y)=H_{base}+N_{terrain}(x,y)
\]

Potom definuj hloubku pod povrchem:

\[
d(x,y,z)=H(x,y)-z
\]

Geologické vrstvy bych definoval pomocí hranic v této hloubce.

Například:

\[
D_0=0
\]

\[
D_1=4m,\quad D_2=11m,\quad D_3=23m
\]

To jsou základní mocnosti vrstev. Jenže místo rovných hranic přidáš deformaci:

\[
D_i(x,y)=D_i+W_i(x,y)
\]

Kde \(W_i\) je kombinace šumů.

Materiál buňky potom určíš podle toho, mezi kterými dvěma hranicemi se nachází.

<AsyncImage query="geological stratified rock layers cross section wavy sedimentary strata geological illustration" aspectRatio="16:9" width="100%"/>

## 2. Nepoužíval bych ale nezávislý šum pro každou vrstvu

Tohle je důležité.

Kdybys každou hranici deformoval samostatným Perlin noise, mohlo by se stát, že:

- vrstvy budou náhodně procházet jedna druhou,
- jejich mocnost bude extrémně kolísat,
- vzniknou nepřirozené ostré změny,
- sousední vrstvy se budou chovat jako nezávislé barevné pásy.

Místo toho bych použil hierarchii deformací:

<box border radius="lg" padding={3} gap={2}>
  **A. Společná geologická deformace**

  <AsyncImage query="geological folded sedimentary strata cross section broad folds" aspectRatio="16:9" width="100%"/>
  Velké zvlnění, které ovlivňuje několik vrstev současně.

  **B. Lokální deformace jednotlivých vrstev**

  <AsyncImage query="wavy sedimentary rock layers irregular strata cross section" aspectRatio="16:9" width="100%"/>
  Menší odchylky mocnosti a tvaru konkrétní vrstvy.

  **C. Lokální geologické útvary**

  <AsyncImage query="geological cross section mineral veins intrusions faults sedimentary layers" aspectRatio="16:9" width="100%"/>
  Žíly, pně, průniky hornin, zlomy a další útvary. Ty bych nadále řešil samostatnými SDF funkcemi.
</box>

Například:

\[
W_i(x,y)=W_{shared}(x,y)+a_iN_i(x,y)
\]

Tím zachováš kontinuitu vrstev, ale každá může mít vlastní charakter.

## 3. Ještě lepší varianta: deformovat mocnost, ne hranice

Osobně bych dal přednost tomuto řešení.

Místo přímého posouvání hranic vypočítáš lokální mocnost každé vrstvy:

\[
T_i(x,y)=\max(T_{min},T_{base,i}+N_i(x,y))
\]

A jednotlivé hranice získáš postupným sčítáním:

\[
D_i(x,y)=\sum_{k=0}^{i-1}T_k(x,y)
\]

Tím automaticky zajistíš, že se vrstvy nebudou vzájemně křížit.

Společný geologický šum může ovlivňovat jejich průběh a lokální šum jejich mocnost.

Ještě bych přidal *domain warping* – deformaci vstupních souřadnic šumu. Díky tomu vrstvy nebudou vypadat jako pravidelné vlny.

## 4. Jak bych to přizpůsobil Willage

Vzhledem k tvému modelu bych zvolil následující výpočet:

| Operace | Rozlišení | Výsledek |
|---|---:|---|
| Terénní funkce | 0,5 m nebo hrubší | Výška povrchu |
| Geologická stratifikace | 0,5 m | Hranice vrstev |
| Deformace vrstev | 0,5 m nebo hrubší | Nepravidelnost |
| SDF geologické útvary | Podle potřeby | Žíly, pně, dutiny |
| Materiálové vyhodnocení | 0,25 m | Výsledný voxel |

Výhoda je, že pro jeden sloupec vypočítáš několik hranic vrstev a následně pouze určuješ materiál buněk. Nemusíš vyhodnocovat 3D Perlin noise pro každou buňku.

## 5. Jedna věc, kterou bych nepodcenil

Pokud budou všechny vrstvy kopírovat povrch terénu, získáš geologii podobnou sedimentárním vrstvám. To je dobré pro základní generování, ale není to univerzální geologie.

Například:

- sedimentární vrstvy mohou kopírovat starší povrchové reliéfy,
- hlubší vrstvy mohou být výrazně deformované,
- masivní horniny mohou tvořit rozsáhlá tělesa,
- zlomy mohou vrstvy posouvat,
- magmatické intruze mohou protínat několik vrstev.

Proto bych zachoval tvůj původní koncept SDF útvarů. Stratifikace vytvoří základní geologii a SDF do ní přidá geologické struktury.

<AsyncImageGroup query={["geological cross section sedimentary strata folded layers","geological cross section fault displacement rock strata","geological cross section igneous intrusion cutting sedimentary layers"]} aspectRatio="5:4" layout="carousel"/>

## Moje doporučení

Pro Willage bych začal modelem:

**Terénní funkce → stratifikace → společná deformace → lokální změny mocnosti → SDF útvary → materiálové vyhodnocení.**

Je to výpočetně úsporné, deterministické a dobře slučitelné s tvým systémem blueprintů a procedurálního světa.

Než bych to uzavřel, ověřil bych jednu věc: jak má vypadat geologie v řezu celým ostrovem 128 × 128 × 128 m. Na tom lze porovnat tři varianty – vrstvy kopírující současný terén, vrstvy kopírující původní geologický reliéf a kombinaci obou. Ta poslední mi připadá nejslibnější.

---

### 78. Uživatel

Chci aby každá vrstva byla jiná nepravidelná 

---

### 79. Asistent

Pak bych opustil představu, že všechny vrstvy sdílejí jednu společnou deformaci. Každá geologická vrstva by měla mít vlastní prostorový průběh, vlastní nepravidelnost a vlastní mocnost.

To, co popisuješ, je spíš **procedurální generování nepravidelných geologických rozhraní**.

## Jak bych to navrhl

Každá hranice vrstvy bude samostatná funkce:

\[
D_i(x,y)=D_{base,i}+N_i(x,y)
\]

Kde:
- \(D_{base,i}\) určuje základní hloubku,
- \(N_i\) je vlastní fraktální šum konkrétní vrstvy,
- každá vrstva má vlastní seed, amplitudu a frekvenci šumu.

Ale ještě bych přidal proměnlivou mocnost vrstvy:

\[
T_i(x,y)=T_{base,i}+M_i(x,y)
\]

Tím získáš dvě nezávislé vlastnosti: nepravidelný průběh vrstvy a její lokální tloušťku.

## Jaký výsledek tím získáš

<AsyncImageGroup query={["realistic geological cross section irregular sedimentary rock strata different thickness wavy layers","geological cross section irregular discontinuous sedimentary layers erosion unconformity","complex geological cross section folded irregular rock layers natural geology"]} aspectRatio="5:4" layout="carousel"/>

Jednotlivé vrstvy mohou:
- lokálně zesilovat a zeslabovat,
- zvlnit se nezávisle na sousedních vrstvách,
- postupně vyklínit,
- přecházet do jiného materiálu,
- mít vlastní měřítko nepravidelnosti.

## Pozor na jednu matematickou vlastnost

Pokud budeš generovat každou hranici nezávisle, mohou se hranice protnout. Výsledkem by byla záporná mocnost vrstvy.

Proto bych doporučil jiný postup:

\[
D_0(x,y)=0
\]

\[
D_{i+1}(x,y)=D_i(x,y)+T_i(x,y)
\]

A každá mocnost \(T_i\) bude samostatná kladná funkce.

Tím získáš nezávislý charakter každé vrstvy, ale nikdy se ti nepřekříží jejich hranice.

**Ještě zajímavější možnost:** přidat pravděpodobnostní vyklínění. Některá vrstva může postupně zmizet a její sousední vrstvy se spojí. To vytvoří mnohem přirozenější geologii než pouhé zvlněné pásy.

Pro Willage bych jako další krok otestoval generátor třeba na řezu 128 × 128 × 128 m, kde bude každá vrstva mít vlastní fraktální šum, mocnost i pravděpodobnost vyklínění.

---

### 80. Uživatel

Aktuálně to mám takto. # Jak generujeme geologické vrstvy (V1.0, krok 3)

Zdroj: větev `gen-v1-krok03-geologie` (d571153), soubory `scripts/v1/geo_vrstvy.gd`, `scripts/v1/utvary.gd`, `scripts/v1/svet_fn.gd`. Stav: krok 3 hotový, čeká na schválení Jana. Všechno je čistá funkce světových souřadnic v metrech (x, y, z), bez mřížky sousedů, takže výsledek přes švy bloků sedí a je deterministický (stejný seed → stejné bity).

## Pořadí výpočtu v bodě `bod(x, y, z)`

1. Povrch `z_pov = vyska_w(x, y, detaily=true)`. Když `z > z_pov`, je to vzduch (0).
2. Sopka: když bod leží v tělese sopky, vrátí průduch nebo slupku (viz kapitola 6).
3. Vrstvy: `hranice(x, y)` dá seznam vrstev zdola nahoru, z něj materiál ve výšce z.
4. Útvary (žíla, čočka, dóm, komín, kras, skarn): když je bod uvnitř útvaru, materiál útvaru přepíše vrstvu.

## 1. Mapa hornin (krok 2, vstup pro vrstvy)

Svět je pokrytý mřížkou středů hornin s roztečí `hS = 192 m`. Střed buňky (i, j) je posunutý náhodně v rozsahu 15–85 % buňky:

$$x_{ij} = (i + 0{,}15 + 0{,}7\,u)\,h_S,\quad y_{ij} = (j + 0{,}15 + 0{,}7\,u')\,h_S$$

Každý střed má pro každý biom koncentrace hornin `c_m = u_m² / Σ u²` (u je hash ze seedu).

V bodě se vezme okolí 5 × 5 středů, d_min je vzdálenost k nejbližšímu a přechod `hB = 160 m`:

$$q_n = \max\!\left(0,\ 1 - \frac{d_n - d_{min}}{h_B}\right),\qquad w_n = q_n^2$$

$$\text{konc}(id) = \sum_n \sum_t w_t^{biom}\,\frac{w_n}{\sum w}\,c_{n,t,id}$$

Výsledek je seznam `[id, podíl]` seřazený sestupně.

## 2. Pásma (1.7.1)

Výška sloupce `H = max(vyska_tvar(x, y), 0,25)`. `vyska_tvar` je tvar terénu bez drobného detailu, takže vrstvy sledují reliéf. Sloupec od z = 0 po H se dělí na 4 pásma podle úrovní katalogu `poradi_hornin.json` (0–40):

| Pásmo | Úrovně | Podíl výšky |
|---|---|---|
| spodek | 0–12 | 0,32 |
| krystalinikum | 13–25 | 0,35 |
| sedimenty | 26–36 | 0,25 |
| svrchní | 37–40 | 0,08 |

$$H_{pasmo} = H \cdot \frac{podil}{\sum podil}$$

Vrstvou jsou jen druhy `layer`, `soil` a `seam`. Druhy pipe, vein, dome a contact jdou do útvarů.

## 3. Zástupci pásma (1–3 horniny)

Pro každou horninu pásma se spočítá váha.

Přítomnost a mocnost ze seedu, jde o pomalé pole s buňkou 180 m a bilineární interpolací se smoothstepem:

$$pres = \text{smoothstep}(1 - f - 0{,}12,\ 1 - f + 0{,}12,\ n_{pres}(x,y))$$
$$t = \text{lerp}(t_0, t_1, n_{thick}(x,y))$$
$$v_{id} = \max(t \cdot pres, 0)$$

kde `f` je četnost (`freq`) a `[t0, t1]` je rozsah mocnosti z katalogu.

K tomu se přičte mapa hornin z kroku 2: `v_id += 2 · konc(id)`.

Kontrast z klimatického presetu je `v' = v^k`. Výchozí klima `mirne` má k = 1, takže se nic nemění.

Pak se váhy normalizují, vezmou se nejvýš 3 nejsilnější (`zastupcu = 3`), zahodí se ty s podílem pod 0,06 (vyklínění) a zbytek se znovu normalizuje na součet 1. Když nezbude nic, vezme se první aktivní vrstva pásma.

## 4. Mocnosti vrstev

$$th = H_{pasmo} \cdot podil_{zastupce}$$

- Když `th < 0,125 m` (polovina minima), vrstva v tomto místě vyklíní.
- Jinak se ořízne: `th = clamp(th, 0,25 m, H/4)`.

Dorovnání na výšku sloupce:
- Když je součet menší než H, rozdíl dostane spodní vrstva.
- Když je větší, ubírá se odshora, ale žádná vrstva nejde pod 0,25 m.

Pak se tenké vrstvy (pod 0,25 m) sloučí se silnějším sousedem. Definice tak má vždy aspoň jednu buňku.

## 5. Mince E82 (vápenec k hladině)

Mince se hází po světovém bloku 128 m:

$$ano \iff \frac{\text{hash}(seed,\ bx \cdot 7919 + by)\ \&\ \text{0xFFFF}}{65536} < 0{,}5$$

Když padne „ano“:
- cíl je `z_cil = vyska_tvar − 2 m` (odhad hladiny podle E82, skutečná hladina přijde až v kroku 4);
- nejvyšší vrstva vápence nebo dolomitu (id 5, 44, 49) se zvětší až k `z_cil`, a mocnost na to se bere z vrstev nad ní (bez zbytků pod 0,25 m), takže součet zůstane H;
- jíl (4, 12, 51) a nepropustné vrstvy (propustnost 0) nad vápencem vyklíní a jejich mocnost dostane nejbližší propustná vrstva nad nimi, jinak vápenec;
- znovu se sloučí tenké vrstvy.

Test: 521 z 1024 bloků „ano“ = 0,509, tedy v toleranci.

## 6. Z mocností souřadnice a ořez povrchem

Vrstvy se skládají od z = 0: `z0 = Σ předchozích`, `z1 = z0 + th`. Nahoře se ořízne skutečným povrchem (s detailem): `z1' = min(z1, z_pov)`. Vrstva, která tím zmizí, se vynechá. Zbytky po ořezu můžou být tenčí než 0,25 m: test našel 8 takových (0,246–0,250 m).

## 7. Vnitřek sopky (1.14)

Profil kužele (H výška, R poloměr, rc poloměr kráteru, d hloubka kráteru, γ tvar):

$$kuz(r) = \begin{cases} H\left(\frac{R - r}{R - r_c}\right)^{\gamma} & r_c \le r < R \\ H - d\,(1 - (r/r_c)^2) & r < r_c \end{cases}$$

Povrch kužele je `z_k = h_okoli + kuz(r)`.

- Průduch (id 75): `r < max(2 m, 0,35 · rc)` a `z ≤ h_okoli + H − d`, takže vede až do z = 0.
- Slupky: `k = floor((z_k − z) / 5 m)`. Sudé k je láva (zatím id 7, diabaz), liché popel (zatím id 57).
- Vrstvy pod tělesem sopky nepokračují.

## 8. Útvary jako SDF (E84)

Každý druh má vlastní světovou mřížku (rozteč G, četnost p, dosah R):

| Druh | G | p | R | Materiál |
|---|---|---|---|---|
| žíla | 10 m | 0,7 | 7 m | pegmatit 38, občas minerál 8/9 (8 %) |
| čočka/peň | 12 m | 0,6 | 4,5 m | pegmatit 38 |
| kras | 14 m | 0,8 | 22 m | vzduch (dutina) |
| dóm | 16 m | 0,35 | 8 m | sůl 47 |
| komín | 20 m | 0,25 | 10 m | kimberlit 21 |

V buňce (gi, gj) útvar existuje, když `u(hash(seed, druh, gi·7919 + gj)) < p`. Střed je `(gi + u1)·G, (gj + u2)·G`. Hloubka středu je podíl `vyska_tvar` ve středu, například u žíly `cz = clamp(zs · (0,35 + 0,30·u), 4, zs − 2)`. Bod se dívá jen do buněk, jejichž obálka ho může zasáhnout, takže výsledek je stejný z obou stran švu.

Vzdálenostní funkce (záporná = uvnitř):
- **Žíla** je deska s normálou n a tloušťkou t0 (0,15–0,40 m), tvar elipsy a × b, okraj zvlněný 3D šumem: `|s + 0,35·noise| − tail`, kde `s = q·n`.
- **Čočka, dóm, komín** jsou elipsoid s poloosami (ra, rb, rc), přibližná SDF: `k0(k0 − 1)/k1`, kde `k0 = |q/r|` a `k1 = |q/r²|`. Komín je úzký svislý elipsoid od z = 0.
- **Kras** je řetěz 6 uzlů (krok 3 m, náhodně se stáčí), mezi nimi kapsle s poloměrem 0,5–1,1 m plus jedna komora (elipsoid 2,2 × 1,8 × 1,2 m). Prostor je deformovaný šumem o amplitudě 0,25 m. Kras se vyhloubí jen ve vápenci nebo dolomitu (5, 44, 49) a aspoň 2 m pod povrchem.
- **Skarn** (42) je pás ±1,5 m (zvlněný šumem) kolem rozhraní granitoidu (6, 36, 37) s jinou horninou, a to jen na straně mimo granitoid.

Pořadí: skarn, pak útvary. Vyhraje nejzápornější SDF (bod nejhlouběji uvnitř).

## 9. Ověřeno testy (krok 3)

- 0 neshod na švu bloků i segmentů (vrstvy i útvary).
- 0 vrstev pod 0,25 m v definici.
- Determinismus: hash `59e4569309aa8500` ze dvou procesů (4,7 mil. buněk).
- Čas: segment 8 m při 0,25 m a výšce 128 m trvá 2614 ms. To je pomalé (E84 mělo 89 ms při 0,5 m / 32 m), zrychlení přijde později.

## Otevřené (rozhoduje Jan)

1. Má mince po kroku 4 brát skutečnou hladinu místo `vyska_tvar − 2 m`?
2. Má láva a popel dostat vlastní id místo 7 a 57?
3. Mají se pásma krajiny 57–74 z tabulky smazat, nebo jen nepoužívat?

---

### 81. Asistent

Teď když vidím skutečnou implementaci, můžu tvůj nápad posoudit mnohem přesněji. A musím trochu upravit své předchozí doporučení.

**Ty už totiž máš poměrně pokročilý funkční geologický generátor. Nemyslím si, že potřebuješ přecházet na úplně jiný model. Spíš bych změnil způsob, jakým vzniká samotná stratifikace.**

Současný model má jednu zásadní vlastnost: geologické vrstvy jsou sice nepravidelné v materiálovém zastoupení a mocnosti, ale jejich hranice jsou odvozené ze společné struktury výšky sloupce. Výsledkem jsou převážně horizontální pásma kopírující reliéf.

Ty chceš něco jiného: aby každá vrstva měla vlastní geologický charakter a prostorový průběh.

## 1. Co máš dnes a kde je omezení

Současný postup:

1. Rozdělíš výšku sloupce na čtyři pásma.
2. V každém pásmu vybereš 1–3 horniny.
3. Jejich podíly určí mocnost.
4. Mocnosti se skládají od dna směrem nahoru.
5. Celá struktura sleduje současný reliéf.

To je výpočetně poměrně efektivní, protože většina práce probíhá v 2D.

Ale výsledná geologie má omezenou variabilitu.

Například:

<AsyncImage query="geological cross section horizontal sedimentary rock strata clean layered diagram" aspectRatio="16:9" width="100%"/>

Jednotlivé vrstvy mohou mít různou mocnost, ale pořád jde v zásadě o soustavu vrstev, které sledují společnou výškovou strukturu.

Problém není v Perlin noise. Problém je v tom, kde a jak ho aplikuješ.

## 2. Co bych změnil: každá vrstva vlastní 2D pole

Navrhuji zachovat tvůj současný princip výpočtu mocností, ale přidat každé vrstvě vlastní prostorovou deformaci.

Každá vrstva by měla například:

| Parametr | Význam |
|---|---|
| `base_thickness` | Základní mocnost |
| `thickness_noise` | Nepravidelnost mocnosti |
| `thickness_frequency` | Měřítko nepravidelnosti |
| `thickness_amplitude` | Intenzita změn |
| `fold_noise` | Zvlnění celé vrstvy |
| `fold_amplitude` | Hloubka zvlnění |
| `warp_strength` | Deformace souřadnic |
| `pinch_probability` | Pravděpodobnost vyklínění |

Tohle jsou parametry generátoru, ne nutně data, která musíš ukládat pro každý sloupec.

### Příklad výsledku

<AsyncImageGroup query={["irregular sedimentary geological strata cross section complex wavy layers","geological cross section alternating thick thin discontinuous rock layers","folded sedimentary rock strata geological cross section natural irregular"]} aspectRatio="5:4" layout="carousel"/>

Každá vrstva může mít:
- vlastní vlnovou délku;
- vlastní amplitudu;
- lokálně proměnlivou mocnost;
- vlastní směr deformace;
- vlastní oblasti vyklínění.

Důležité je, že sousední vrstvy už nemusí mít stejný průběh.

## 3. Jak bych upravil matematiku

Tady bych nepoužil úplně nezávislé hranice vrstev. Zachoval bych jejich pořadí pomocí kumulativní mocnosti.

Nejdříve základní mocnost:

\[
T_i(x,y)=T_{base,i}+A_iN_i(x,y)
\]

Kde \(N_i\) je vlastní fraktální pole konkrétní vrstvy.

Potom deformace jejího rozhraní:

\[
B_i(x,y)=B_{i-1}(x,y)+T_i(x,y)
\]

Tím získáš vrstvy s vlastní nepravidelností a současně zajistíš, že se jejich hranice nebudou vzájemně křížit.

Pro přirozenější tvary bych přidal domain warping:

\[
N_i'(x,y)=N_i(x+W_x(x,y),y+W_y(x,y))
\]

To rozbije pravidelnost samotného šumu.

**Pozor:** Pokud chceš skutečně geologicky nezávislé vrstvy, samotné skládání mocností nestačí. Vytváří totiž stále uspořádanou stratigrafii. Zlomy, vrásnění, eroze starších vrstev a intruze musí být samostatné operace. To už částečně řešíš pomocí SDF.

## 4. Ještě zajímavější varianta: vrstvy jako prostorová pole

Tady bych se na chvíli zastavil, protože existuje ještě jiná možnost.

Místo výpočtu hranic vrstev můžeš každé hornině přiřadit prostorovou funkci:

\[
S_i(x,y,z)
\]

Ta určuje, jak moc daný materiál v daném místě odpovídá své geologické oblasti.

Výsledný materiál vybereš podle nejsilnějšího pole, případně podle vážených přechodů.

<AsyncImage query="geological 3d volumetric cross section irregular geological formations colored rock strata" aspectRatio="16:9" width="100%"/>

Výhody:
- vrstvy mohou být skutečně prostorově nezávislé;
- snadno vytvoříš čočky, přechody a nepravidelná tělesa;
- lépe se kombinují s podzemní geologií.

Nevýhody:
- musíš vyhodnocovat více funkcí;
- je složitější zachovat geologické pořadí;
- materiálové přechody a priority jsou náročnější;
- výkon může být výrazně horší.

Pro Willage bych to zatím nedělal jako hlavní model. Tvoje současná stratifikace je úspornější.

## 5. Co mě ale zaujalo nejvíc: současných 2614 ms

<badge color="warning">Výkonový problém</badge>

Segment 8 × 8 × 128 m, tedy 32 × 32 × 512 = 524 288 buněk, generuješ za 2,614 sekundy.

To je pro mobilní hru příliš pomalé, pokud by se takové generování mělo provádět při běžném načítání.

Neznamená to ale, že samotná geologická funkce je pomalá. Čas může být z velké části způsoben opakovaným vyhodnocováním:

- `hranice(x,y)` pro každou buňku;
- mapy hornin;
- bilineární interpolace;
- hashů a šumových funkcí;
- SDF útvarů;
- hledání kandidátních útvarů.

Přitom všechny buňky stejného sloupce sdílejí stejné hranice vrstev.

To znamená, že bych jako první optimalizoval:

**A. Sloupcové vyhodnocení**

Pro každou dvojici `(x,y)` jednou vypočítat:
- výšku povrchu;
- mapu hornin;
- mocnosti;
- hranice vrstev;
- kandidátní útvary.

A následně vyhodnocovat 512 výškových buněk.

**B. Oddělení vrstev od útvarů**

SDF útvary nemusíš vyhodnocovat stejně často jako základní stratifikaci. Mohou mít vlastní prostorový index a vlastní cache.

**C. Batch vyhodnocování**

Místo 524 tisíc nezávislých volání `bod()` používat dávkové vyhodnocení sloupce nebo segmentu.

Tohle bych udělal ještě před přidáním dalších vrstev šumu.

---

## 6. Moje doporučení pro další verzi geologie

| Část | Současný model | Doporučení |
|---|---|---|
| Mapa hornin | 192m mřížka | Zachovat |
| Pásma | 4 výšková pásma | Zatím zachovat jako geologický základ |
| Zástupci | 1–3 horniny | Zachovat |
| Mocnost | Podíl pásma | Doplnit vlastní prostorové pole |
| Nepravidelnost | Převážně 2D pomalá pole | Vlastní fraktální pole každé vrstvy |
| Vyklínění | Prahové podle podílu | Doplnit prostorové vyklínění |
| SDF útvary | Samostatně | Zachovat |
| Výpočet | Opakované bodové vyhodnocení | Sloupcové batch vyhodnocení |

**Nezahazoval bych současný generátor.** Jeho základní koncepce je dobrá. Přidal bych novou variantu stratifikace a porovnal ji se současnou na stejném seedu.

Ještě bych ale chtěl vyjasnit jednu zásadní věc, protože od ní se odvíjí správná matematika:

**Chceš, aby jednotlivé vrstvy byly nepravidelné hlavně ve vodorovném směru, tedy aby se jejich hranice různě vlnily a měnily mocnost, nebo chceš, aby se mohly také rozpadat na samostatná tělesa, čočky a izolované kapsy horniny?**

To jsou dva poměrně odlišné geologické modely. První je vhodný pro stratifikaci, druhý už pro prostorová materiálová pole.

---

### 82. Uživatel

Mám tam zahrnutou i sopku která jde až od nuly a tam se vrstvy zvedá ji do svislé polohy, středem je sopouch. Sopka z pohledu vrstev vypadá tak jako by je všechny připíchla a částečně vytlačila napovrch. 

---

### 83. Asistent

Tohle je důležitý detail. Pak už současný model není jen jednoduchá horizontální stratigrafie. Sopka u tebe funguje jako **lokální geologická deformace celé stratigrafie** – přesněji jako intruze, která vrstvy nadzvedla, vyklonila a částečně vytlačila k povrchu.

Geometricky si to představuji takto:

<AsyncImageGroup query={["volcanic geological cross section strata uplifted around central volcanic conduit diagram","volcanic intrusion cross section domed folded sedimentary layers central pipe geology illustration"]} aspectRatio="5:4" layout="carousel"/>

- **Mimo sopku:** vrstvy mají svůj původní průběh a vlastní nepravidelnost.
- **Při přiblížení k sopce:** vrstvy se postupně deformují, zvedají a jejich sklon se mění.
- **V tělese sopky:** vrstvy jsou vykloněné až téměř svislé, případně přerušené.
- **Uprostřed:** sopouch protíná vrstvy od spodní části až ke kráteru.
- **Na povrchu:** část vrstev může být odkrytá nebo překrytá sopečným materiálem.

### Co to znamená pro generátor vrstev

Doporučil bych oddělit dvě věci:

1. **Původní stratigrafii** – určuje, jaké horniny existují, jejich mocnost a nepravidelnost.
2. **Geologickou deformaci** – mění jejich prostorovou polohu a orientaci.

Sopka by tedy neměla být jen kužel, který přepíše materiál uvnitř svého SDF. Měla by mít vlastní deformační pole, které ovlivňuje i okolní vrstvy.

Například pro bod v okolí sopky můžeme definovat radiální vzdálenost \(r\), deformační intenzitu \(D(r)\) a vertikální posun:

\[
z'=z-\Delta z(x,y,z)
\]

Současně bychom potřebovali horizontální deformaci nebo transformaci lokálních souřadnic, aby se vrstvy nejen zvedaly, ale také nakláněly. Samotný vertikální offset by vytvořil kopec, nikoliv skutečně vykloněné vrstvy.

**Důležitá architektonická věc:** Nejdříve bych vyhodnotil původní vrstvu v deformovaných souřadnicích a až potom aplikoval sopouch a sopečné těleso. Tím zůstane zachována kontinuita vrstev a sopka nebude muset ručně přepisovat každou horninu.

Tím se dostáváme k zajímavější otázce: **Chceš, aby se sopka chovala jako skutečná intruze, která deformuje vrstvy v celém svém okolí, nebo má deformace končit na hranici jejího tělesa?** První varianta bude geologicky přesvědčivější a umožní i odkryté svislé vrstvy na svazích sopky.

---

### 84. Uživatel

Pro a proti u jednotlivých variant ? 

---

### 85. Asistent

Rozdíl je poměrně zásadní. Nejde jen o vizuální efekt, ale o to, jak budeš muset reprezentovat geologii a jak složité bude její generování.

Porovnal bych tři varianty, protože existuje ještě zajímavý kompromis mezi oběma krajními řešeními.

## 1. Deformace pouze uvnitř tělesa sopky

<AsyncImage query="geological cross section volcano cone with horizontal undisturbed sedimentary layers outside cone and steeply uplifted layers inside volcanic body" aspectRatio="16:9" width="100%"/>

Sopka deformuje vrstvy pouze ve svém tělese. Na hranici sopky se jejich průběh vrátí k původnímu stavu.

**Výhody**
- Nejjednodušší implementace.
- Nízké výpočetní náklady.
- Snadné zachování determinismu.
- Malý zásah do současného generátoru.
- Jednodušší řešení švů mezi bloky.

**Nevýhody**
- Může vzniknout nepřirozený přechod mezi deformovanými a původními vrstvami.
- Vrstvy mohou působit jako nasunuté na kužel, nikoliv jako geologicky deformované.
- Chybí okolní zlomy, vyklenutí a odkryté vrstvy.
- Při kopání v okolí sopky nebude geologie působit příliš přesvědčivě.

**Vhodné pro:** stylizovanou hru, kde je sopka především zajímavý terénní objekt.

## 2. Deformace celého okolí sopky

<AsyncImage query="geological cross section volcanic intrusion doming folding sedimentary strata around central volcanic conduit geological illustration" aspectRatio="16:9" width="100%"/>

Sopka působí jako intruze. Vrstvy se zvedají už v určité vzdálenosti od ní, postupně mění sklon a v blízkosti sopouchu mohou přecházet do téměř svislé polohy.

**Výhody**
- Geologicky nejpřesvědčivější varianta.
- Vrstvy mají plynulou kontinuitu.
- Při kopání se odhalují zajímavé struktury.
- Umožňuje vznik kontaktů různých hornin, žil a dalších útvarů.
- Sopka se stává skutečnou součástí geologické historie ostrova.

**Nevýhody**
- Výrazně složitější výpočetní geometrie.
- Musíš řešit deformaci ve 3D, ne pouze měnit výšku vrstev.
- Vzniká větší riziko samoprotínání a nepřirozeného zhušťování vrstev.
- Obtížnější generování při kombinaci více sopek.
- Náročnější ladění parametrů a kontrola výsledků.

**Vhodné pro:** svět, kde geologie představuje důležitou součást průzkumu, těžby a gameplaye.

## 3. Hybridní varianta – regionální deformace + lokální intruze

<AsyncImage query="geological cross section volcanic laccolith intrusion uplifted folded strata central volcanic pipe surrounding sedimentary layers textbook diagram" aspectRatio="16:9" width="100%"/>

Tuhle variantu bych považoval za nejlepší kompromis.

Rozdělil bych sopku na tři geometrické oblasti:

<box border radius="lg" gap={3} padding={3}>
  <row align=start gap={3}>
    <AsyncImage query="geological cross section gently domed sedimentary strata around magma intrusion" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **A. Vnější oblast – vyklenutí**

      Vrstvy se postupně zvedají a mírně naklánějí. Deformace je slabá, ale zasahuje dostatečně daleko, aby nebyl vidět ostrý přechod.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="geological cross section steeply tilted folded rock strata volcanic intrusion" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **B. Vnitřní oblast – vyklonění**

      Vrstvy se výrazně naklánějí, mohou být přerušované a vytlačované vzhůru. Tady vzniká charakteristický geologický vzhled sopky.
    </box>
  </row>
  <divider color="subtle"/>
  <row align=start gap={3}>
    <AsyncImage query="geological cross section central volcanic conduit pipe magma intrusion" aspectRatio="1:1" maxWidth="104px"/>
    <box flex="1" gap={1}>
      **C. Jádro – sopouch**

      Samostatné těleso, které protíná vrstvy. Může obsahovat magmatickou výplň, brekcii nebo prázdný průduch podle fáze sopky.
    </box>
  </row>
</box>

**Výhody**
- Velmi dobrý poměr vizuální kvality a výpočetní náročnosti.
- Můžeš používat stejné principy i pro jiné geologické jevy.
- Parametry lze nastavovat podle typu sopky.
- Zachováš současnou procedurální koncepci vrstev.
- Nemusíš deformovat celý svět, pouze oblast ovlivněnou sopkou.

**Nevýhody**
- Musíš definovat přechody mezi oblastmi.
- Potřebuješ pořadí operací a pravidla pro překryv více deformací.
- Je nutné ošetřit zachování mocnosti vrstev a jejich topologii.

---

## Srovnání

| Kritérium | 1. Lokální | 2. Celoplošná | 3. Hybridní |
|---|---:|---:|---:|
| Výpočetní náročnost | Nízká | Vysoká | Střední |
| Implementační složitost | Nízká | Vysoká | Střední |
| Geologická věrohodnost | Nízká | Vysoká | Vysoká |
| Kontinuita vrstev | Omezená | Výborná | Výborná |
| Vhodnost pro těžbu | Střední | Výborná | Výborná |
| Rozšiřitelnost | Omezená | Výborná | Výborná |

## Moje doporučení pro Willage

Zvolil bych variantu 3, ale s jednou důležitou architektonickou zásadou:

**Nedeformoval bych jednotlivé vrstvy samostatnými offsety. Deformoval bych prostorovou souřadnicovou soustavu, ve které se geologické vrstvy vyhodnocují.**

Například:

\[
P'=F(P,\text{vulkanické deformace})
\]

A potom:

\[
Material(P)=Geology(P')
\]

To má několik výhod:
- Všechny vrstvy reagují na stejnou geologickou událost.
- Jejich vzájemné vztahy zůstávají zachované.
- Můžeš kombinovat více deformací.
- Sopka se stane jedním typem geologické transformace, nikoliv speciálním případem generátoru materiálů.

Pozor ale na jednu věc: pouhá transformace souřadnic může vytvořit nepřirozenou kompresi nebo roztažení vrstev. Pro geologicky věrohodný výsledek bude potřeba kontrolovat také lokální deformaci a případně zachování minimální mocnosti.

**Ještě bych před implementací rozhodl jednu věc:** Chceš, aby se tímto způsobem deformovaly pouze sopky, nebo chceš stejný mechanismus později použít také pro tektonické vrásnění, zlomy, magmatické intruze a další geologické události?

To totiž rozhoduje, jestli má vzniknout samostatný `VolcanoDeformer`, nebo obecnější systém `GeologicalDeformation`, do kterého sopka dodá pouze své parametry.

---

### 86. Uživatel

Do zemin generuje (čočky) krás a jeskyně. To by možná stálo za změnu výpočtu. 

---

### 87. Asistent

Ano. A myslím, že právě tady se vyplatí změnit architekturu výpočtu. Ne nutně celý generátor geologie, ale způsob, jakým se skládají jeho jednotlivé prostorové struktury.

V současnosti máš několik různých mechanismů:

- **Vrstvy:** určují základní geologickou skladbu.
- **Sopka:** přepisuje materiál v tělese a sopouchu.
- **Žíly, čočky, dómy a komíny:** používají SDF a přepisují základní vrstvy.
- **Kras:** vytváří dutiny pouze ve vápenci a dolomitu.
- **Skarn:** vzniká v okolí kontaktu granitoidu s jinou horninou.

To je funkční, ale začíná se projevovat jeden architektonický problém: každý typ geologického útvaru si řeší vlastní prostorovou logiku.

## Navrhoval bych přejít na geologický model složený z operací

Místo toho, aby `bod(x,y,z)` postupně zkoušel jednotlivé výjimky, by vyhodnocoval několik vrstev geologického modelu.

<box border radius="lg" padding={3} gap={3}>
  <title size="lg">Navrhovaná architektura</title>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **1. Základní geologie**

    <text color="secondary" size="sm">Stratigrafie, horniny, mocnosti, nepravidelnost vrstev</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **2. Geologické deformace**

    <text color="secondary" size="sm">Vrásnění, sopky, zlomy, intruze, vyklenutí</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **3. Geologická tělesa**

    <text color="secondary" size="sm">Žíly, čočky, komíny, dómy, skarny</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(59,130,246,0.10)" radius="md" padding={3} align=center>
    **4. Dutiny a porušení hornin**

    <text color="secondary" size="sm">Kras, jeskyně, pukliny, eroze</text>
  </box>
  <box align=center>
    <icon name="arrow-down" color="secondary" size="lg"/>
  </box>
  <box background="rgba(34,197,94,0.10)" radius="md" padding={3} align=center>
    **5. Výsledný materiál bodu**

    <text color="secondary" size="sm">Materiál ID, vzduch, voda, případně vlastnosti horniny</text>
  </box>
</box>

Důležité je, že tyto fáze nemusí znamenat pět samostatných výpočtů pro každou buňku. Mohou používat předpočítaná lokální pole a prostorové indexy.

## Zajímavá změna: oddělit geometrii od materiálu

Například dnes máš kras definovaný tak, že:
- vytvoří se řetěz uzlů;
- vytvoří se kapsle a komora;
- ověří se, jestli se nachází ve vápenci;
- pokud ano, výsledek je vzduch.

To je poměrně dobrý základ. Rozšířil bych ho tak, aby kras nebyl pouze přepis materiálu, ale samostatná geometrická struktura.

Podobně by fungovaly:

| Struktura | Geometrie | Materiálový účinek |
|---|---|---|
| Sopka | Deformační pole + těleso | Přemístění a nahrazení hornin |
| Žíla | Deska / SDF | Minerální výplň |
| Čočka | Elipsoid / SDF | Lokální hornina |
| Skarn | Kontaktní pásmo | Metamorfovaná hornina |
| Kras | Síť dutin | Odstranění horniny |
| Jeskyně | Propojené dutiny | Vzduch, případně voda |
| Zlom | Plocha / pásmo | Posun, rozdrcení nebo přerušení vrstev |

Tím získáš možnost kombinovat útvary. Například krasová jeskyně může procházet několika vápencovými vrstvami, ale nesmí automaticky pokračovat do žuly.

## Jedna důležitá věc: pořadí operací

Není správné všechny operace pouze seřadit a nechat poslední vyhrát.

Představ si:
- sopka deformuje vrstvy;
- žíla protíná deformované vrstvy;
- kras vytvoří dutinu ve vápenci;
- pozdější magmatická intruze část krasu vyplní.

Tady záleží na geologické posloupnosti událostí. Proto bych do budoucna u útvarů zavedl také `formation_order` nebo jinou informaci o relativním stáří.

To ti umožní rozhodovat, zda je jedna struktura starší nebo mladší než druhá.

## Co bych změnil jako první

Nezačínal bych přepisem všeho. Udělal bych tři kroky:

1. **Zachovat současnou stratigrafii**, ale připravit ji na prostorové deformace.
2. **Oddělit geometrické operace od materiálových pravidel.** SDF útvary by nejprve určovaly prostorový rozsah a až následně by se rozhodovalo, co v daném místě způsobí.
3. **Přepsat sopku jako první deformační událost** a ověřit, že správně funguje kontinuita vrstev, než se začne měnit kras a další útvary.

Tím získáš obecný mechanismus, který budeš moci rozšiřovat bez toho, aby `svet_fn.gd` postupně narůstal o další speciální případy.

**Ještě bych si pohlídal jednu věc:** ne každá geologická struktura musí být geometrickou deformací. Kras je odebrání materiálu, žíla je vložení tělesa a zlom může být posun dvou částí geologického modelu. Architektura by měla rozlišovat tyto operace, ne je násilně sjednocovat pod jeden typ SDF.

---

### 88. Uživatel

A co žíly? 

---

### 89. Asistent

Žíly jsou podle mě jeden z nejzajímavějších důvodů, proč přejít na obecnější geologický model. A zároveň bych je neřešil stejně jako čočky nebo sopky.

**Žíla není jen objekt určitého materiálu. Je to geologické těleso, které vzniklo vyplněním pukliny nebo trhliny v již existující hornině.**

To má důsledky pro její geometrii, generování i vztah k okolním horninám.

## 1. Jak bych modeloval žíly

<AsyncImageGroup query={["quartz mineral vein cutting through dark host rock geological specimen","complex branching hydrothermal quartz veins rock cross section","pegmatite vein irregular mineral intrusion geological outcrop"]} aspectRatio="5:4" layout="carousel"/>

Rozlišil bych tři základní typy:

- **Puklinová žíla:** tenká deska, která protíná okolní horniny. Může být téměř rovná, zvlněná nebo rozvětvená.
- **Hydrotermální žilná síť:** více propojených a rozvětvených žil, často s různým minerálním složením.
- **Mohutná žíla / pegmatit:** nepravidelné, lokálně rozšířené těleso, které může přecházet do čoček.

Tvoje současná implementace desky s normálou, elipsou a zvlněným okrajem je dobrý základ pro první typ.

## 2. Co bych změnil oproti současnému SDF

Dnes máš žílu jako samostatný útvar s parametry:

- mřížka 10 m;
- pravděpodobnost 0,7;
- dosah 7 m;
- tloušťka 0,15–0,40 m;
- pegmatit ID 38;
- občas minerál ID 8/9.

Problém není samotné SDF. Problém je, že jednotlivé žíly vznikají jako nezávislé objekty. Geologicky zajímavější by bylo generovat nejprve **systém puklin** a teprve do něj umisťovat minerální výplně.

<AsyncImage query="geological mineral vein network branching fracture system schematic cross section" aspectRatio="16:9" width="100%"/>

Navržený postup:

1. Vygenerovat puklinovou strukturu.
2. Určit její orientaci, délku, rozvětvení a šířku.
3. Rozhodnout, které pukliny jsou mineralizované.
4. Určit složení výplně.
5. Vložit žíly do již existující geologie.

Tím vznikne například jedna hlavní křemenná žíla s několika vedlejšími větvemi, nikoliv náhodná směs izolovaných elipsoidů.

## 3. Žíla musí respektovat geologické prostředí

Tady bych zavedl pravidla pro vznik jednotlivých typů žil.

| Hostitelská hornina | Možné žilné výplně |
|---|---|
| Žula | Křemen, pegmatit, živce |
| Metamorfity | Křemen, kalcit, rudní minerály |
| Vápenec | Kalcit, křemen, rudní mineralizace |
| Vulkanické horniny | Křemen, kalcit, hydrotermální minerály |

Neznamená to, že musíš mít pevně danou tabulku pro každou kombinaci. Můžeš použít pravděpodobnostní pravidla podle geologického prostředí.

Například:

\[
P(\text{mineralizace}) =
f(\text{hostitelská hornina},\text{geologická událost})
\]

A důležitá věc: vzácné minerály bych negeneroval jako náhodné jednotlivé buňky. Měly by tvořit lokální koncentrace uvnitř žíly, případně malé krystaly nebo shluky.

## 4. Vztah k ostatním geologickým operacím

Tady bych zavedl relativní geologické stáří.

Příklad:

<box border radius="lg" padding={3} gap={2}>
  <title size="lg">Příklad geologické posloupnosti</title>
  <list connector="solid" marker="number" gap={2}>
    <list-item>
      **Vznik původních hornin**

      Vytvoří se stratigrafie a její nepravidelnosti.
    </list-item>
    <list-item>
      **Tektonické porušení**

      Vzniknou pukliny a zlomy.
    </list-item>
    <list-item>
      **Mineralizace**

      Některé pukliny se vyplní křemenem, pegmatitem nebo rudami.
    </list-item>
    <list-item>
      **Krasovění**

      Vzniknou dutiny, které mohou protínat starší horniny i žíly.
    </list-item>
    <list-item>
      **Pozdější intruze**

      Novější magmatická událost může starší žíly přerušit nebo překrýt.
    </list-item>
  </list>
</box>

Tohle je důležité i pro těžbu. Hráč může najít žílu, která končí na zlomu, pokračuje na druhé straně s posunem nebo je přerušená jinou horninou.

## 5. Moje doporučení pro architekturu Willage

Žíly bych oddělil na dvě úrovně:

**FractureSystem**
- definuje pukliny;
- jejich prostorovou geometrii;
- propojení a větvení;
- orientaci;
- případně stáří.

**Mineralization**
- rozhoduje, které pukliny jsou mineralizované;
- definuje druh výplně;
- koncentraci vzácných minerálů;
- lokální změny mocnosti.

Výsledkem je, že jedna puklina nemusí být vždy mineralizovaná a jedna mineralizovaná puklina nemusí mít po celé délce stejné složení.

---

### Jedna věc, kterou bych rozhodl před návrhem algoritmu

Chceš, aby hráč při kopání nacházel spíše:

**A.** Jednotlivé izolované žíly – náhodné mineralizované útvary, které se dají těžit.

**B.** Souvislé žilné systémy – hlavní žíla s větvemi, změnami mocnosti a lokálními koncentracemi rud.

**C.** Kombinaci obojího – běžné samostatné žíly a vzácné rozsáhlé mineralizované systémy.

Já bych volil C. Umožní ti to mít běžné nálezy i skutečně zajímavá ložiska, jejichž nalezení bude pro hráče významným objevem.

---

If you want, I can:

- Explore vein modeling techniques
- Discuss integration of veins with volcanic deform
- Explain geologic age ordering for veins
