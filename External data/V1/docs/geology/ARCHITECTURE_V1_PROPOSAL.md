# Geological Engine v1 – návrh k posouzení

**Stav: schválený architektonický návrh; fáze 3–7 nejsou implementované.** K realizaci byla schválena pouze fáze 2 (vizualizace A). Současný engine, `algorithmVersion = 1` a `SCHEMA_VERSION = 1` se nemění. Návrh neimplementuje nové geologické procesy. Y je nahoru, X/Z vodorovně, jednotkou je metr.

## 1. Dopad na skutečný v0

| Oblast | Současný kód | Dopad návrhu |
|---|---|---|
| Historie | `GeoEvent[]`, index 0 nejstarší; `compileTimeline` vytvoří operace | Zachovat jako referenční implementaci; v1 přidá identitu modelu, rozsah a vazby mimo v0 |
| Bodové vyhodnocení | `GeologicalFieldEvaluator.evaluate`, zpětné inverze deformací, klasifikace materiálu | Zachovat matematiku i pořadí; budoucí adaptér doplní stabilní provenance |
| Sedimentace / vrásnění / zlom | Samostatné přenositelné operace | Obalit adaptéry, nepřepisovat algoritmy kvůli hierarchii ani vizualizaci |
| Kompilace | Výběr událostí, vytvoření operací a validace při každém požadavku | Později immutable snapshot, cache a konzervativní závislosti |
| Prostor | v0 obaluje současný bod do periodického `WorldConfig` | Globální souřadnice v1 musí mít vlastní světovou periodu; 64/128 m výřez nesmí určovat periodu světa |
| Voxelová data | `sampleGrid` vzorkuje celý objem, materiál a zdroj v `Uint8Array` | Zachovat; index zdroje není trvalé ID tělesa a nestačí pro rozsáhlou historii |
| Mesh | `buildCulledMesh` již vytváří **jen viditelné stěny**, jeden sloučený mesh | Není pravda, že renderer kreslí všechny vnitřní voxely; náklad je stále úplné vzorkování a dva průchody objemem |
| Průřez | `sampleSection` volá přímo evaluator, nezávisle na voxelové mřížce | Použít pro variantu A ve 2D i 3D; dnes UI pevně zadává 4 px/m |
| UI | Kamera nepřevzorkovává; barvy, skrytí materiálu a 3D řez mění jen mesh | Zachovat oddělení, zastavit nepotřebné vzorkování v neaktivním pohledu |

Tento dokument neudává nové naměřené časy. Dosavadní měření a limity jsou v `GEOLOGICAL_ENGINE.md`; odhad složitosti není benchmark.

## 2. Architektonický diagram

```text
Immutable world document: události + materiály + vztahy těles
   Global model ──► Regional models ──► Local models
          rodičovské výsledky / závislosti / globální souřadnice
                            │
                   Geological compiler
       validace → kanonické pořadí → operace → bounds → index
                            │
                  CompiledWorld snapshot
                            │
                 Geological query evaluator
       query point / section / region; historie + stable provenance
                   ┌────────┴─────────┐
            voxel sampler       geometry/section extraction
                   │                  │
             chunk output      surfaces / curves / fields
                   └────────┬─────────┘
                     renderer (Three.js)
```

Chunk je pouze žádost o oblast a výstupní data. Nevlastní historii, seed ani lokální geologické pravdy. Renderer nepřidává geologická pravidla.

## 3. Hierarchie a čas

- **Global Geological Model:** světová historie a dlouhovlnné struktury, vlastní prostorové měřítko a seznam událostí.
- **Regional Geological Model:** explicitní globální oblast, vlastní historie a reference na rodičovský model; zpřesňuje jeho výsledek, nezačíná prázdným podložím.
- **Local Geological Model:** stejný kontrakt pro malou oblast, vstupem je globální + regionální výsledek. Oblast není svázána s hranicemi chunků.

Hierarchie určuje vlastnictví a závislosti, **nenahrazuje geologickou chronologii**. Nestačí prostě zřetězit tři samostatně vyhodnocená pole a vybrat lokální materiál: tím by se ztratily inverze pozdějších deformací působících na starší regionální/globální tělesa.

Kompilátor nejprve sestaví jediný deterministický chronologický rozvrh relevantní historie. Každá událost má explicitní **stabilní uloženou** `sequence` ve světovém dokumentu; kompilace ji nikdy neodvozuje ani nepřečísluje. Změna chronologie je explicitní editace uložené historie. Pole jednotlivých modelů jsou chronologická, `timeMa` zůstává informativní. Závislosti musí ukazovat na starší události; duplicity sequence a cykly se odmítnou, nikoliv tiše přeuspořádají. Rodičovská struktura, na níž lokální událost závisí, musí existovat v jejím čase. Konfliktní překryv regionů musí mít explicitní pořadí nebo validací skončit chybou.

Oblast regionální/lokální deformace vyžaduje matematicky platný forward/inverse na přechodu. Stávající nekonečný zlom se nesmí pouze oříznout AABB: vznikla by jiná, neověřená deformace. Ve v1 nejprve zůstane operací s neomezeným vlivem, dokud nebude zvlášť navržena a otestována skutečně omezená varianta.

## 4. Navržené datové kontrakty

Následující TypeScript je **specifikace budoucího API**, nikoliv nový importovatelný modul. Všechny serializovatelné definice jsou nezávislé na Reactu, Three.js, DOM a voxelovém rozlišení.

```ts
type StableId = string;
type Point3 = { x: number; y: number; z: number };
type Bounds3 = { min: Point3; max: Point3 };
type Support = { kind: "bounded"; bounds: Bounds3 } | { kind: "unbounded" };
type ModelLevel = "global" | "regional" | "local";

interface GeologicalModel {
  id: StableId;
  level: ModelLevel;
  parentModelId: StableId | null;
  support: Support;                   // globální souřadnice
  characteristicScaleM: number;      // nikoliv rozlišení voxelů
  eventIds: StableId[];              // chronologické reference
}

interface GeologicalEvent {
  id: StableId;
  modelId: StableId;
  sequence: number;
  timeMa: number;
  seed: number;
  algorithmVersion: number;
  enabled: boolean;
  dependsOn: StableId[];
  definition: GeoEvent;              // v0 adaptér pro existující procesy
  inputBodyIds: StableId[];
  outputBodyIds: StableId[];
}

interface GeologicalBody {
  id: StableId;
  modelId: StableId;
  kind: "stratum" | "fault-zone" | "solid" | "vein";
  geometryIds: StableId[];
  materialIds: number[];
  contributions: {
    eventId: StableId;
    role: "created" | "deformed" | "transformed" | "truncated";
  }[];
}

interface GeologicalGeometry {
  id: StableId;
  frame: { kind: "event-stage"; eventId: StableId } | { kind: "present" };
  support: Support;
  definition:
    | { kind: "parametric-surface"; algorithmId: string; parameters: unknown }
    | { kind: "swept-curve"; algorithmId: string; parameters: unknown }
    | { kind: "closed-solid"; algorithmId: string; parameters: unknown }
    | { kind: "implicit-field"; algorithmId: string; parameters: unknown;
        distanceSemantics: "sdf" | "level-set" };
  algorithmVersion: number;
}

interface GeologicalMaterial {
  id: number;                        // zachovat stabilní ID v0 / materialy.csv
  name: string;
  properties: Record<string, number>;
}

interface GeologicalTransformation {
  id: StableId;
  eventId: StableId;
  inputMaterialIds: number[];
  outputMaterialIds: number[];
  geometryIds: StableId[];
  algorithmId: string;
  algorithmVersion: number;
  parameters: unknown;
}
```

`unknown` je místo pro budoucí registrované, verzované a validované parametrické kontrakty, nikoliv povolení přijímat libovolný JSON. Intruze, sopky, žíly a transformace zůstávají návrhem; žádný takový algoritmus není tímto zaveden.

Vztah event–body je mnoho ku mnoha: sedimentace může vytvořit několik strat, vrásnění a zlom přispět k jejich pozdějšímu stavu. ID vrstvy není ID materiálu; dvě vrstvy mohou mít stejný materiál. **Ve v0 je bodyId vždy null:** stabilní identita není dostupná a nesmí se odvozovat z indexu zdroje ani pořadí vrstev. Index vrstvy je pouze dočasný údaj pro inspekci a vizuální filtr konkrétního snapshotu. Stabilní identity těles a vrstev se zavedou až v novém kontraktu.

Zdroj vytvoření, pozdější vlivy a zdroj změny materiálu jsou oddělené. Například brekcie nesmí falešně změnit identitu původní sedimentační události na „nové sedimentární těleso“.

## 5. Vhodnost geometrických reprezentací

| Reprezentace | Vhodné použití | Omezení |
|---|---|---|
| Parametrická plocha | Rozhraní sedimentace, forward deformovaná vrása | Nestačí sama o sobě pro rozhodnutí vlastnictví materiálu po mladší sedimentaci a erozním překrytí |
| 3D křivka s průřezem | Budoucí žíly, kanálové struktury | Křivka bez objemové definice není materiálové těleso; samoprůniky a návaznosti potřebují pravidla |
| Uzavřené těleso | Budoucí intruze a sopečná tělesa | Nutná robustní definice vnitřku a hranice; síť rendereru není zdroj pravdy |
| Implicitní pole / SDF | Klasifikace, kombinace těles, budoucí lokální extrakce | Po obecné deformaci SDF zpravidla není skutečná vzdálenost; zachovat jako level set nebo dodat ověřenou metriku |

Kombinace je vhodná. Procedurální definice je autoritativní; polygonové meshe jsou jen odvozený výstup pro konkrétní pohled a toleranci. V0 má výšky sedimentárních rozhraní a forward/inverse deformace, ale neposkytuje úplné současné oříznuté hranice těles.

## 6. Kompilace, reprodukovatelnost a invalidace

1. Validovat světový dokument, verze, ID, reference, chronologii a podporované procesy.
2. Vytvořit kanonický seznam operací s explicitním mapováním stabilních ID na indexy. Zachovat původní události beze změny.
3. Adaptovat existující `compileEvent` a `contextFor`; zkompilovat čisté procesy se světovým kontextem, nikoliv kontextem chunku.
4. Spočítat konzervativní support a dependency graph; není-li mez prokazatelná, označit vliv jako neomezený.
5. Sestavit spatial index a immutable snapshot. Evaluátory mají vlastní scratch buffer/cache, nesdílejí měnitelný stav mezi souběžnými dotazy.
6. Cache klíč zahrnuje kanonický dokument, všechny algoritmické verze, světovou periodu a kontext. Barvy, kamera a výstupní rozlišení nejsou klíčem geologické kompilace.

První kompilátor provádí pouze bezeztrátové optimalizace: opětovné použití nezměněných operací a konzervativní vyřazení prokazatelně nerelevantních kandidátů. Žádné slučování materiálů, voxelová aproximace historie ani zjednodušení hranic. Kanonické pořadí zůstává stejné i po spatial query.

Po změně události se invaliduje její operace, odvozené geometrie a tranzitivně závislé výsledky, včetně mladších překrytí/deformací. Změna pořadí invaliduje dotčený chronologický suffix; změna periody či podporované verze může invalidovat celý model. Rozsah invalidace je sjednocení starého a nového supportu, rozšířené o prokázané deformační vlivy. Bez důkazu se zvolí úplná invalidace. Nový snapshot se zveřejní atomicky; staré asynchronní výsledky s jiným snapshot ID UI zahodí.

## 7. Spatial index a tok bodového dotazu

Navrhuje se BVH nad konečnými globálními AABB událostí a těles plus samostatný seznam neomezených operací. BVH je reprodukovatelně sestavené se stabilním tie-break ID. Chunky nejsou součástí indexu historie. Torus vyžaduje rozdělení bounds překračujících šev nebo periodické kopie s deduplikací stable ID; neomezené rovinné zlomy v0 zůstávají přiznaným omezením periodicity.

**Důležitá podmínka:** dotaz pouze na současný bod nestačí. Mladší deformace může jeho historickou polohu přesunout do oblasti starší události, která současný bod neobsahuje.

Bezpečný postup:
1. Přijmout bod v globálních metrech a snapshot ID; světové obalení provést pouze podle světového kontraktu.
2. Procházet chronologii od nejmladšího. Kandidáty pro konkrétní stage hledat v příslušných souřadnicích, doplnit neomezené operace a dependency closure.
3. Aplikovat skutečné inverze; po změně historické polohy znovu ověřit starší support. Alternativou jsou prokázané konzervativní současné bounds celého vlivu.
4. Klasifikovat materiál ve správném čase, zachovat onlap/erode a pending transformace v0.
5. Vrátit materiál, layer/body identitu, creation event, ovlivňující události a případně historii. Neznámá body identita se vrací jako `null`, neodhadne se podle barvy.

První v1 adaptér může dál procházet úplný chronologický seznam. Index pro něj zrychluje vyhledání a inspekci těles; vyřazování operací se zapíná až po ekvivalenčních testech. Bezpečnost má přednost před deklarovaným zrychlením.

## 8. Navržené API

```ts
compileWorld(document, previousSnapshot?): CompiledWorld
validateWorld(document): ValidationReport
evaluatePoint(snapshot, globalPoint, out, history?): GeologicalSample
evaluateSection(snapshot, plane, resolutionM, out): SectionSamples
sampleRegion(snapshot, globalBounds, resolutionM, out): RegionSamples
queryBodies(snapshot, globalBounds): StableId[]
extractGeometry(snapshot, globalBounds, toleranceM, selection): GeometryOutput
invalidate(previousSnapshot, documentChanges): RecompilePlan
```

`CompiledWorld` nese snapshot ID, verzované vstupy, dependency graph, index a read-only definice operací. `GeologicalSample` zachovává materiál, příznaky, reziduum a vrací stable provenance; historie zůstává opt-in. `RegionSamples` obsahují globální origin, rozlišení, rozměry a explicitní mapu lokálního source indexu na stable ID. `GeometryOutput` nese souřadnice, stable ID struktur a deklarovanou toleranci, nikdy nepřepisuje autoritativní materiálové pole.

Adaptér v0 deleguje bodové dotazy a průřezy na současný evaluator/sampler. Vstup `out` i scratch state vlastní jeden dotazující evaluator. Budoucí C# zachová kontrakty a pořadí, ne JS objekty workeru nebo rendereru.

## 9. Vyhodnocení vizualizací A/B

### A – povrchové stěny a přímo vyhodnocené průřezy (doporučeno nyní)

Využije se existující culled mesh. Nově se výsledky `sampleSection` vykreslí také jako samostatná rovina ve 3D na přesné hodnotě X, Y nebo Z, s nezávislým rozlišením 2 / 1 / 0,5 / 0,25 m. Posun řezu nesmí spouštět `sampleGrid`.

Objem lze vizuálně odříznout, aby rovinu nezakrýval. Stávající voxelový cap je kvantovaný na buňky; v novém režimu se nesmí prezentovat jako přesný průřez. Povrchová geometrie se ořízne pro aktuální pohled a přesnou rovinu nese samostatný evaluatorový výsledek, bez dvou překrývajících se capů. 3D i 2D převádějí pixel na stejný střed vzorku v globálních souřadnicích a inspektor znovu vyhodnotí tento bod.

Změna kamery, barev nebo viditelnosti překreslí již existující data. Posun/rozlišení průřezu vzorkuje jen rovinu. V čistém 2D pohledu se nesestavuje 3D mesh ani nová objemová mřížka; poslední platná 3D data se mohou uchovat pro návrat. Objemový výpočet při návratu do 3D je nutný jen pro změněný model/world/resolution.

Materiály a **sedimentární vrstvy** mají oddělené filtry (dvě vrstvy stejného materiálu nejsou totéž). Skrytí zdrojové události/tělesa je vizuální filtr dat, nikoliv její vypnutí v historii. Stávající „enabled“ znamená skutečné odebrání procesu a nové geologické vyhodnocení; UI tyto dvě akce musí odlišit. Body v0 nejsou plnohodnotně definované, takže se ukáže dostupná identita zdrojové vrstvy a události, ne vymyšlené těleso.

Hranice vrstev lze vyznačit z přechodů material/source/layer ID na řezu. Drcená zóna a zlom mají odlišnou identitu; analytická stopa zlomu na řezu musí být případně odvozena v čisté extrakční vrstvě a transformována všemi mladšími operacemi. Nebude-li to nyní implementováno, samotná brekcie se neoznačí za přesnou plochu zlomu.

**Náročnost:** menší až střední; rozšíření dat průřezu/identity vrstev, rendereru, UI a testů. Matematické procesy není nutné přepisovat. **Limity:** stále úplné vzorkování pro voxelový 3D povrch, aliasing bodových průřezů, bez plných geometrických těles či vnitřních ploch všech strat. Nulová damageWidth může znamenat, že samotný zlom není barevně vidět.

### B – procedurální geometrické objekty (preferováno později)

Lze přímo parametrizovat rozhraní sedimentace a posunout je forward operacemi. Pro obecný výsledek v0 je ale nutné také:
- rozdělit plochu na zlomu, aby trojúhelníky nepřemosťovaly skok;
- oříznout starší vrstvy podle mladší sedimentace, onlap/erode a vyplnění paleoprohlubní;
- aplikovat všechny mladší deformace na každou historickou hranici;
- určit pravé hranice a identity těles, ne jen kreslit původní rozhraní;
- ověřit vlastnictví materiálu na obou stranách vůči evaluatoru.

Intruze, sopky a žíly nemají ve v0 implementované matematické procesy, proto jejich geometrické zobrazení není nyní možné poctivě dodat. B nevyžaduje zahodit současný evaluator, ale vyžaduje novou robustní extrakci, trimování a provenance. To překračuje malou úpravu rendereru.

**Rozhodnutí k potvrzení:** nejprve A; B jako pozdější hybridní výstup v1, ne dekorativní náhrada geologie. Neuvádět A jako vyřešení objemového vzorkování pro 0,25 m ve velkém světě.

## 10. Migrační plán

1. **Nyní – posouzení návrhu:** žádná změna runtime, JSON ani algoritmů.
2. **Vizualizace A:** přímý 3D průřez, společné osy/picking pro 2D a 3D, samostatné rozlišení, viditelnost vrstev/zdrojů, hranice; testy proti evaluatoru a ověření počtu požadavků.
3. **v1 kontrakty a v0 adaptér:** nový explicitně verzovaný formát a migrační funkce; staré schemaVersion 1 nadále čitelné. Golden vectors A–E musejí zůstat ekvivalentní.
4. **Hierarchie bez cullingu:** modely ve světových souřadnicích a kanonická chronologie; porovnání s úplným evaluátorem.
5. **Kompilace a invalidace:** immutable snapshots, opětovné použití operací a testy inkrementální vs úplné kompilace.
6. **Index a sampling oblastí:** konzervativní bounds, historické kandidáty, chunk origin; srovnání chunků s přímými dotazy včetně švů.
7. **Hybrid B:** jedna podporovaná procedurální reprezentace po druhé, geometrické řezy a oboustranná materiálová validace. Žádné nové geologické procesy bez zvláštního zadání.

Fáze 3–7 jsou budoucí práce, nikoliv součást okamžité realizace vizualizace A.

## 11. Ověření a technická rizika

| Riziko | Ochrana / ověření |
|---|---|
| Hierarchie změní chronologii | Jedno explicitní pořadí; test mladší globální deformace nad starší lokální sedimentací |
| Index vynechá historicky relevantní událost | Konzervativní bounds, unbounded fallback; indexed vs full evaluator na stejných bodech |
| Lokální omezení zlomů poruší inverzi | Nezavádět clipping jako deformaci; samostatný matematický návrh a inverse/Jacobian testy |
| Invalidace vynechá vliv mladšího procesu | Dependency closure a porovnání inkrementálního snapshotu s úplnou kompilací |
| Barva zamění materiál za těleso | Stable ID vrstvy/tělesa/provenance, test dvou strat stejného materiálu |
| Uint8 zdroj přeteče při velké historii | Explicitní indexové mapy a širší typ v novém kontraktu, ne tiché přetečení |
| Roviny řezu se liší v 2D a 3D | Jedna souřadnicová funkce a test X/Y/Z se vzorky z evaluatoru |
| Kamera či skrytí spouští geologii | Ověřit worker request counts pro kameru, barvy, viditelnost a posun řezu |
| B kreslí neexistující vrstvy / spojuje zlom | Trimování podle evaluatoru, test materiálu na obou stranách hranice |
| Torus/chunk mění šum a původ | Světový seed a perioda nezávislé na chunku; kontrola sousedních regionů a švů |
| Paměť / 0,25 m objem | A neřeší úplné vzorkování; později region sampling/chunking, skutečný benchmark před tvrzením |
| Bitová shoda JS/C# | Zachovat deklarovaný limit same-machine; golden vectors, deterministická matematika až při portu |

Kritéria pro realizaci A: zachování existujících testů a golden vectors; průřezy všech os odpovídají evaluatoru; resolution řezu nezávisí na 3D mřížce; inspektor ukazuje skutečný bod i zdroj; posun řezu nepřevzorkuje objem; ovládání a viditelnost se ověří v desktopovém i mobilním rozměru. Zvuk a herní fyzika nejsou součástí tohoto geologického nástroje.