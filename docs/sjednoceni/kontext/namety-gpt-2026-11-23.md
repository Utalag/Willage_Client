# Náměty z konzultací s GPT (2026-11-23)

**Stav: seznam námětů, ne rozhodnutí.** Rozhodnutí platí jen v kapitolách 01–04 a dostanou se tam až po souhlasu Jana. Tento soubor kapitoly 01–04 ani kód nemění.

Zdroj jsou dva rozhovory s ChatGPT, které Jan vedl 2026-11-23 nad kontextovými přehledy z této složky. Celé texty i s Janovými otázkami jsou v [`gpt/`](gpt/): [1] datový model, [2] vykreslování. Odkaz „[1] zpr. 45“ znamená zprávu č. 45 v souboru `gpt/konverzace1.md`.

GPT neměl úplný kontext projektu (Jan, 2026-11-23). Proto byl každý námět ověřen proti:
- kapitolám 01–04 (větev `sjednoceni`),
- reportům kroků 1–3,
- `DENIK.md` (blok B, slepé cesty) a `TODO.md`,
- kódu větve `gen-v1-krok03-geologie` (`scripts/v1/`),
- Janovým rozhodnutím: buňka 0,25 m, pevný zoom 64 dlaždic bez LOD, determinismus, hierarchie ostrov → blok → segment → buňka, vodopád na okraji ostrova.

## Legenda

| Skupina | Význam |
|---|---|
| **A** | nové a stojí za zvážení |
| **B** | už máme nebo je v plánu (uvedeno kde) |
| **C** | je v rozporu s rozhodnutím Jana, nebo GPT něco nepochopil (uvedeno proč) |
| **D** | zajímavé, ale ne teď |

Náročnost: **malá** (hodiny, úprava pravidla nebo testu), **střední** (den až dva, nový modul nebo nástroj), **velká** (víc dní, mění algoritmus).

Počty: **A 15**, **B 20**, **C 9**, **D 11**.

## Janovy vlastní podněty z rozhovorů

Tyto body neřekl GPT, napsal je Jan. Nejsou zatím v 01–04. Uvádím je zvlášť, protože ukazují jeho záměr (ani to ale nejsou rozhodnutí):
- **Každá vrstva má být jinak nepravidelná** ([1] zpr. 78).
- **Sopka zvedá vrstvy až do svislé polohy**, střed je sopouch od nuly ([1] zpr. 82).
- **Čočky, kras a jeskyně se generují i do zemin. To by možná stálo za změnu výpočtu** ([1] zpr. 86). Kód to potvrzuje: `utvary.gd` → `host_ok` vrací pro čočku, žílu, dóm a komín vždy `true`. Kras je omezený na vápence/dolomit (id 44, 49, 5) a hloubku ≥ 2 m. Viz A1.
- **Geometrický charakter podle druhu horniny**, ne jen textura ([2] zpr. 10, 24). Viz A9.
- **Pramen jako kohoutek:** materiál je kohoutek, bez odběru není produkce, pramen má max. tlak a objem ([1] zpr. 59–67). To už kryje 1.8 (B9).
- **Hydrologická mapa jako ustálený stav** a rozmístění pramenů podle ní ([1] zpr. 69–71). Kryje 2.5 a krok 4 (B8, B10).
- **Výřez přenese všechno.** Úvahu o 1–2 materiálech bloku Jan sám zavrhl ([2] zpr. 30–32).
- **Rarita výřezu původní a aktuální** ([2] zpr. 32–36). Viz A14.
- **Dva typy map:** svět výprav ze seedu a domovský ostrov z výřezů ([2] zpr. 27). Je to už v TODO (podnět 2026-11-19), viz B19.

---

## A – nové a stojí za zvážení

### A1 Pravidla hostitelské horniny pro útvary
- **Co:** u každého útvaru určit, ve kterých horninách smí vzniknout:
  - čočka a žíla jen ve skalních horninách (případně podle tabulky hostitel → výplň),
  - zeminy (písek, štěrk, jíl, ornice) nehostí žíly ani rudní čočky,
  - minerály v žíle jako shluky podél žíly, ne rovnoměrně.
- **Proč:** `host_ok` dnes pustí čočky a žíly i do zemin. Jan to sám zmínil jako chybu ([1] zpr. 86). GPT navrhuje žílu jako „puklinu + mineralizaci“ ([1] zpr. 87, 89). Data k tomu už existují: `scripts/teren/hostitele.gd` (plán kroku 3 ho uvádí jako katalog k převzetí), ale kód `scripts/v1/` ho zatím nepoužívá.
- **Krok:** 3 (geologie, útvary). **Náročnost:** malá (pravidlo), střední (shluky minerálů v žíle).

### A2 Číselný kontrakt determinismu GDScript ↔ C#
- **Co:**
  - výstupy funkce světa (výška, hranice vrstev, SDF útvarů) před porovnáním a uložením kvantovat na pevnou jednotku, např. 1/4096 m, s jedním pravidlem zaokrouhlení,
  - sepsat rizikové operace: `sin`, `cos`, `pow`, `exp`, `log`, FMA, převod float → int a pořadí slovníků,
  - testovací vektory i s mezivýsledky (ne jen konečný hash).
- **Proč:** dnes je definováno jen „float64, řazené klíče, celočíselné hashe“. Kód kroků 2–3 přitom používá:
  - `FastNoiseLite.get_noise_2d` (v Godotu počítá ve float32),
  - `pow` / `exp` / `log` (`_smin`, `_kuzel`, kontrast hornin),
  - `sin` / `cos` (rozmístění sopek).
  
  Port do C# na serveru (krok 11) se na tom může rozejít v posledních bitech, a to i když jsou obě strany „float64“ ([1] zpr. 3 §2, zpr. 45 audit A). Nejrizikovější je FastNoiseLite: C# verze musí dát stejný float32 výsledek, nebo šum potřebuje vlastní implementaci.
- **Krok:** 1 (pravidla) a 11 (server). **Náročnost:** střední.

### A3 Šum funkce světa jako vlastní deterministická implementace
- **Co:** místo vestavěného `FastNoiseLite` mít vlastní šum (gradient / value noise) nad celočíselným hashem, stejný v GDScriptu i C#.
- **Proč:** jde o konkrétní důsledek A2. Vestavěný šum je černá skříňka enginu: změna verze Godotu nebo jiná knihovna v C# může změnit svět bez změny `gen_ver` ([1] zpr. 3 §2.1).
- **Krok:** 1 / 2. **Náročnost:** střední. Může se zpomalit GDScript, takže nejdřív změřit.

### A4 Plná identita zdroje: hash parametrů a verze tabulek
- **Co:** ke zdroji (`TerrainSource`, E88) a k ostrovu ukládat kromě seedu a `gen_ver` i:
  - hash parametrů světa,
  - verzi tabulky materiálů,
  - verzi souřadnicového systému,
  - profil determinismu.
- **Proč:** 1.4 / 2.2 říká, že vložení nese „seed i verzi zdrojového světa“. Svět je ale funkce seedu, *parametrů* a verze (1.5). U výřezu z jiného světa (jiné klima, jiný sloupec) chybí parametry, takže se zdroj nedá jednoznačně přepočítat ([1] zpr. 3 §7.1, zpr. 45 audit C).
- **Krok:** 1, 5, 11. **Náročnost:** malá.

### A5 Doménová sůl hashů jako pravidlo
- **Co:** zapsat do pravidel kroku 1, že každý subsystém hashuje s vlastním účelem (doménou) a že se domény nesmí sdílet.
- **Proč:**
  - v kódu to už z velké části je: `H.mix(seed, účel, vrstva)` a `_u(ucel, i, j, k)`,
  - výjimkou je `svet.sd ^ 84` (šum okraje útvarů v `utvary.gd`), kde je doména jen XOR konstantou,
  - pravidlo ale není v dokumentu, takže nový kód ho může porušit ([1] zpr. 3 §2.3).
- **Krok:** 1. **Náročnost:** malá.

### A6 Překryv: rozlišit „vzduch“ od „beze změny“
- **Co:** v překryvu (E78) mít jasnou sémantiku Inherit / Air / Override. Hodnota „bez změny“ nesmí splynout s materiálem 0 = vzduch.
- **Proč:** po vykopání musí být vzduch skutečný zápis, ne absence záznamu. U deflate formátu s výchozí nulou se to dá snadno zaměnit ([1] zpr. 3 §6.1, zpr. 16 §7). Před krokem 6 ověřit, jak to řeší E78 / WTI1.
- **Krok:** 6. **Náročnost:** malá.

### A7 Test ekvivalence pro zrychlení geologie řídicí mřížkou 0,5 m
- **Co:** u návrhu „hranice na mřížce 0,5 m + interpolace“ porovnat materiál každé buňky s plným výpočtem. Výsledek: 0 rozdílů, nebo seznam rozdílů.
- **Proč:**
  - Jan u zrychlení požaduje, aby se výsledek nezměnil (04, krok 3, 2026-11-21 23:52),
  - interpolace hranic mění materiál buněk blízko hranice,
  - jinak by to byla nová verze generátoru ([1] zpr. 3 §3).
- **Krok:** 3. **Náročnost:** malá.

### A8 Hranice vrstev jednou na sloupec, dávkově
- **Co:** při vyplnění segmentu počítat `hranice(x, y)` jednou na sloupec a všechny buňky Z brát z toho výsledku. Útvary počítat jen v buňkách, kde SDF obálka útvaru zasahuje.
- **Proč:**
  - `hranice` 32 × 32 trvá 531 ms ze segmentu 2614 ms,
  - `vypln_sloupec` už hranice počítá jednou, ale `bod()` je volá znovu,
  - GPT doporučuje dávkové API „sloupec → pole materiálů“ ([1] zpr. 3 §3.4, zpr. 16 §4).
  
  Částečně je to B: cache po segmentu je v návrhu zrychlení kroku 3. Novinkou je pravidlo, že hra smí volat jen dávkové API, ne `bod()` ve smyčce.
- **Krok:** 3 / 6. **Náročnost:** střední.

### A9 Vizuální profil materiálu oddělený od fyzikální tabulky
- **Co:** k 78 materiálům mít druhou tabulku pro prezentaci:
  - geometrický charakter (zaoblení, hranatost, lámavost, šum povrchu),
  - barvu a texturu,
  - styl přechodu s okolím.
  
  Fyzikální tabulka (propustnost, pevnost, těžba) zůstane beze změny.
- **Proč:** Jan chce geometrii „podle druhu horniny“ ([2] zpr. 10, 24). GPT navrhuje čtyři vrstvy vizuální reprezentace a jeden shader s parametry, ne 78 shaderů ([2] zpr. 6 §4, zpr. 12, 26). Sedí to na Surface Nets (DENIK A, skála C) s parametrem hladkosti podle materiálu.
- **Krok:** 12 (prezentace). **Náročnost:** střední.

### A10 Každá vrstva s vlastní nepravidelností
- **Co:**
  - mocnost každé vrstvy z vlastního šumu (vlastní frekvence, amplituda a oktávy podle druhu horniny),
  - hranice jako kumulativní součet mocností,
  - doménové zvlnění (warping) a prostorové vyklínění.
- **Proč:**
  - Jan to chce ([1] zpr. 78),
  - GPT upozorňuje: deformovat mocnosti, ne hranice, jinak se vrstvy kříží ([1] zpr. 77, 79),
  - dnešní `geo_vrstvy` už sčítá mocnosti; ověřit, zda šum mocnosti je u každé vrstvy jiný.
- **Krok:** 3. **Náročnost:** střední.

### A11 Sopka jako deformace souřadnic
- **Co:** místo „vrstvy končí na tělese sopky“ počítat vrstvy kolem sopky v deformovaných souřadnicích. Materiál(P) = Geologie(P′), kde P′ vznikne:
  - zvednutím okolí,
  - naklopením vrstev u průduchu,
  - průduchem jako jádrem.
  
  K tomu pořadí útvarů podle relativního stáří (`formation_order`).
- **Proč:** Jan popisuje vrstvy zvednuté až do svislé polohy ([1] zpr. 82). Dnešní kód je u tělesa sopky jen ořízne (report kroku 3, test 1). GPT rozebírá varianty s pro a proti ([1] zpr. 83, 85).
- **Krok:** 3. **Náročnost:** velká. Mohla by být i v D; záleží, jak moc to Jan chce už ve V1.0.

### A12 Riziko závislosti geologie na pořadí (vápenec × hladina)
- **Co:** hlídat, aby geologie nezávisela na skutečné hladině vody nebo na sousedních vloženích. Například vápenec nebo kras navázaný na hladinu by mohl změnit materiál podle pořadí vkládání.
- **Proč:**
  - mince E82 je dnes po bloku 128 m a hladina přijde až v kroku 4,
  - GPT to vede jako riziko R1 ([1] zpr. 45 audit B, zpr. 79),
  - patří k otevřené otázce mince v kroku 3/4.
- **Krok:** 3 / 4. **Náročnost:** malá (rozhodnutí a test).

### A13 Diagnostický nástroj geologie v Godotu (TerrainLab)
- **Co:** scéna, ve které jde:
  - vypnout nebo zapnout jednotlivé složky (klima, reliéf, masiv, sopka, vrstvy, útvary),
  - ukázat řez X / Y / Z, hodnotu SDF a materiál pod kurzorem,
  - zobrazit příspěvky složek (`EvaluateDetailed`).
- **Proč:**
  - Jan chtěl vidět funkce jako plochy ve 3D, v Godotu ([1] zpr. 4, 7),
  - dnes jsou jen statické řezy PNG z `geo_v1.gd`,
  - GPT navrhuje rozložení a režimy ([1] zpr. 9, 11, 13).
- **Krok:** nástroje ke krokům 2–3. **Náročnost:** střední.

### A14 Index rarity výřezu, který neprozradí obsah
- **Co:** výřez nese dvě rarity: původní (ze zdroje) a aktuální (po těžbě a úpravách). Hráč vidí jen index, ne seznam materiálů uvnitř. Rarita se počítá ze souhrnu zásobníku nebo materiálů.
- **Proč:**
  - Jan ([2] zpr. 32–36),
  - směr „původní i aktuální“ už je v `teren-bloky-bunky.md` (Jan 17. 11., „možná“) a rarita-v2 existuje ve studiích,
  - v 01–04 to ale není, a GPT přidává myšlenku, že index nemá prozradit obsah ([2] zpr. 33).
- **Krok:** 5 / 11 nebo herní design. **Náročnost:** střední.

### A15 Okraj ostrova jako samostatný renderer
- **Co:** okraj ostrova kreslit zvlášť:
  - pásy hornin podle geologie,
  - převis trávy přes hranu,
  - visící kameny jako MultiMesh,
  - vodopád jako emitor.
- **Proč:**
  - 1.13.1 dnes říká jen „bloky s vlastní texturou 5 m pod okrajem a oblaka“,
  - Jan si uložil referenci okraje, která se mu líbí (`reference/okraj-ostrova-2026-11-22.jpg`),
  - GPT doporučuje výjimku z univerzálního meshe právě pro okraj ([2] zpr. 3 §3, zpr. 6 §9).
- **Krok:** 12. **Náročnost:** střední.

---

## B – už máme nebo je v plánu

| # | Námět GPT | Kde to máme |
|---|---|---|
| B1 | Oddělené vrstvy dat: zásah hráče / eroze / voda / vegetace ([1] zpr. 3 §9, zpr. 45 audit B) | 03 §4.1, kroky 6–9, 2.6 vegetace |
| B2 | Deterministická cache nezávislá na pořadí dotazů, LRU ([1] zpr. 3 §3.2) | návrh zrychlení kroku 3 (cache povrchu a mapy hornin po segmentu) |
| B3 | Otočení jen po 90°, celočíselné ([1] zpr. 3 §4.1) | E86, krok 5 |
| B4 | Inverzní transformace do souřadnic zdroje ([1] zpr. 3 §4, zpr. 51 A) | 2.2 (rozhodnuto 2026-11-20), E86 |
| B5 | Výřez nese seed a verzi zdrojového světa ([1] zpr. 3 §4.3) | 1.4, 2.2, E88 (doplnění parametrů viz A4) |
| B6 | Eroze jako výškový posun, geologie zůstává absolutní ([1] zpr. 3 §5, zpr. 39) | Jan 2026-11-21 00:24, 04 krok 7 (ověřit pod zemí) |
| B7 | Voda v buňce jako malé celé číslo ([1] zpr. 3 §6.2) | 1/16 l, plná buňka 250, 251–255 rezerva (Jan 2026-11-21 00:39) |
| B8 | Výchozí ustálený stav vody + jen odchylky ([1] zpr. 58, 72) | 2.5, Jan 2026-11-20 (voda bez animace náběhu) |
| B9 | Pramen jako kohoutek s max. tlakem a výkonem ([1] zpr. 60–68) | 1.8: jmenovitý výkon omezený okolím, tlakový model pod přepínačem |
| B10 | Rozmístění pramenů podle hydrogeologie (kontakt, kras) ([1] zpr. 70) | krok 4, prameny E74–E77 |
| B11 | Materializovat jen slupku u povrchu ([1] zpr. 49, 56; [2] zpr. 3 §8) | 2.3 slupka 2–3 buňky, krok 6 |
| B12 | Plný výpočet vody jako referenční „orákulum“ ([1] zpr. 45 audit F) | krok 7, test lokální = plný (E67, E76) |
| B13 | Hierarchické hashe a kontrola integrity ([1] zpr. 3 §7.3, zpr. 45 audit E) | E88, 03 §6.3 (zásobník, kontrola po naplnění nebo intervalu) |
| B14 | Duchové buňky na okraji, špinavé chunky, přestavba ve vlákně ([2] zpr. 6 §6, §7) | DENIK A: chunky 8³, přestavba ±2 buňky, 29 ms; E95 |
| B15 | Hladký povrch z voxelů ([2] zpr. 3 §1) | DENIK A, skála C: Surface Nets (Jan zvolil), jen u povrchu |
| B16 | Vodopád na okraji jako emitor, bez další simulace ([2] zpr. 3 §4) | rozhodnutí Jana (voda na okraji padá do mlhy) |
| B17 | Průhlednost: dither místo skutečné průhlednosti, řez v podzemí ([2] zpr. 3 §5) | 03 §7.3, E91 (vlastní přepínače, výchozí vypnuto) |
| B18 | Dekorace a vegetace jako MultiMesh, oddělené od terénu ([2] zpr. 6 §9) | 1.12, 2.6, slučování sítí po 32 m |
| B19 | Dva typy světů: svět výprav a domovský ostrov ([2] zpr. 29) | TODO.md (podnět 2026-11-19), DENIK (svět výprav, Jan 18:59) |
| B20 | Jedno rozhraní zdroje terénu (`ITerrainSource`) pro generátor, vodu i server ([2] zpr. 3 §7, zpr. 6 §2.1) | 2.2 rozhodnuto: jedno API bod / sloupec, E88 `TerrainSource` |

---

## C – rozpor s rozhodnutím Jana, nebo nepochopení

| # | Námět GPT | Proč neplatí |
|---|---|---|
| C1 | Hierarchické LOD a hrubší geometrie v dálce ([1] zpr. 3 §3.1, zpr. 49; [2] zpr. 6 §3) | Jan: jediné rozlišení 0,25 m, pevný zoom 64 dlaždic, bez LOD (03 §7.2). Materializace podle aktivity se částečně kryje se slupkou (B11). |
| C2 | Ukládat změny jako seznam operací nad funkcí (`SubtractSphere` …) místo rozdílu buněk ([1] zpr. 74) | Rozhodnutý je překryv buněk E78 (1.4, 1.10, 2.4). GPT sám přiznává problém s 50 000 operacemi a nutnost checkpointů. Hromadné operace jako jeden zápis viz D10. |
| C3 | „Rozpor A × B v 1.4“ (segment ukládá vzorky 0,5 m a kontroluje se namátkou) ([1] zpr. 28) | Text 1.4 to hned v dalším bodě ruší („Tím se mění předchozí bod“). Je to jen neuklizený text, ne rozpor modelu (viz Úklid). |
| C4 | „Kontrakt se serverem (krok 11) je zcela otevřený“ ([1] zpr. 39, 45 audit E) | Podstatné je rozhodnuté: ukládá se jen rozdíl, zásobník a kontrola po naplnění nebo intervalu (03 §6.1, §6.3). Otevřené jsou jen detaily E88. |
| C5 | Voda na hrubší mřížce než terén ([1] zpr. 56) | Voda je po buňkách 0,25 m (1.8, B7). Hrubší mřížka by rozbila lokální = plný (B12). |
| C6 | Měkký přechod materiálů v meshi (blend hranice, „surface_softness“ na hranách materiálů) ([2] zpr. 12 §4) | DENIK B: měkká hranice 0,20–0,25 zamítnuta, rozmazává toon obrys. Charakter povrchu podle horniny (A9) ano, rozmazání hranice materiálů ne. |
| C7 | Výřez zjednodušit na 1–2 materiály / „zmrazený výřez“ ([2] zpr. 31) | Jan: „přenese se vše“ ([2] zpr. 32). Vložení je procedurální přes inverzní transformaci (2.2), ne kopie hotových dat. |
| C8 | Render chunky 16³ / 32³ ([2] zpr. 6 §3) | DENIK B: 16³ při kopání 167 ms proti 29 ms u 8³. Platí chunky 8³ (B14). |
| C9 | Více specializovaných reprezentací (heightmap + voxely + SDF) jako rovnocenné zdroje pravdy ([1] zpr. 53 E) | Zdroj pravdy je jedna funkce světa + rozdíl (1.4, 2.2). Ostatní jsou jen odvozené cache. GPT sám u varianty E varuje před synchronizací. |

---

## D – zajímavé, ale ne teď

| # | Námět | Proč později | Krok / oblast | Náročnost |
|---|---|---|---|---|
| D1 | Adaptivní uložení překryvu podle hustoty změn: řídký seznam / bitmapa / husté pole ([1] zpr. 3 §6.1, zpr. 56) | nejdřív změřit skutečná data z kroku 6 | 6 | střední |
| D2 | Oddělit vodu v pórech, volnou vodu a povrchovou vodu ([1] zpr. 72 §3) | dnešní model 1.8 stačí pro V1.0 | 7 | velká |
| D3 | 3D deformace stropů krasu a jeskyní ([1] zpr. 9 §3) | útvary SDF teď prošly testy | 3 (později) | střední |
| D4 | Zlomy a vrásy jako deformace souřadnic ([1] zpr. 77, 83) | souvisí s A11, rozsah mimo V1.0 | 3 (V1.x) | velká |
| D5 | Prostorová pole podílu horniny S_i(x, y, z) místo vrstev ([1] zpr. 79) | mění celý model geologie | 3 (V2) | velká |
| D6 | Srovnávací test Marching Cubes × Dual Contouring × Surface Nets ([2] zpr. 6 §8) | Jan v [2] zvolil „srovnat“, ale skála už má Surface Nets (B15). Až při prezentaci. | 12 | střední |
| D7 | Síť podle materiálu (jiná metoda pro skálu a zeminu) ([2] zpr. 12 §3) | navazuje na A9 a D6 | 12 | velká |
| D8 | Kolize ze zjednodušené sítě nebo přímo z buněk ([2] zpr. 6 §7) | až po výkonu sítí na telefonu | 12 | střední |
| D9 | Ekonomika rarity a obchod s výřezy ([2] zpr. 33) | herní design, ne generátor | herní design | střední |
| D10 | Rozpočet výkonu na operaci (ms na kopnutí, segment, vodu) ([1] zpr. 45 audit D) | Jan přeskočil 1.11 (cíl telefonu a fps); znovu se neptat, jen měřit | 1.11 / 6 | malá |
| D11 | Společný renderer pro svět výprav i ostrov s profily prezentace ([2] zpr. 29) | až bude svět výprav | 12 | střední |

---

## Úklid dokumentace (opraveno 2026-11-23 po souhlasu Jana)

Jan 2026-11-23 13:03 schválil opravu zastaralých zmínek o namátkové kontrole. Opraveno podle 03 §6.1 a §6.3 v:
- 01 §1.4 (ř. ~166),
- 01 §1.10 (odrážky „Přenos dat“, „Změněno“, „Zamítnuté varianty“),
- 03 §6 „Už vyřešeno“,
- 04 krok 11,
- `kontext/datovy-model.md` krok 11.

Oprava k původnímu zápisu: 01 §1.4 na tomto místě už měla buňku 0,25 m. Zastaralá tam byla jen věta o ukládání hotových dat segmentu a o namátkové kontrole.

## Zdroje

- [1] ChatGPT, „Technické hodnocení modelu“, Jan 2026-11-23, 89 zpráv. https://chatgpt.com/share/6b042446-2f50-83eb-9146-5c39ce7e1ff9 – kopie [`gpt/konverzace1.md`](gpt/konverzace1.md)
- [2] ChatGPT, „Architektura vykreslování terénu“, Jan 2026-11-23, 37 zpráv. https://chatgpt.com/share/6b04246b-4a10-83eb-816c-45acdc7b9fe8 – kopie [`gpt/konverzace2.md`](gpt/konverzace2.md)
- Ověřeno proti:
  - `docs/sjednoceni/01`–`04` (větev `sjednoceni`, 5959226),
  - `reporty/krok01`–`krok03`,
  - `DENIK.md`, `TODO.md`, `teren-bloky-bunky.md`,
  - kódu `gen-v1-krok03-geologie`: `scripts/v1/svet_fn.gd`, `geo_vrstvy.gd`, `utvary.gd`, `stable_hash.gd`.
