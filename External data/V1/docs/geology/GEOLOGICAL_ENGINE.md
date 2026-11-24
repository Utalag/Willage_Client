# Willage Geological Engine v0 – technická dokumentace implementace

Tento dokument popisuje **skutečný kód** v repozitáři (stav v0, algorithmVersion 1, schemaVersion 1).

Aktualizace vizualizace A (24. 11. 2026): viz `VISUALIZATION_A_RESULTS.md` – přesný průřez ve 3D/2D, nezávislé rozlišení, snapshotové filtry vrstev, ověření požadavků. Matematika procesů a výsledky golden vectors jsou nezměněné. Návrh v1: `ARCHITECTURE_V1_PROPOSAL.md`; fáze 3–7 nejsou implementované. Periodické/neomezené zlomy jsou samostatně evidovány v `TECHNICAL_ISSUES.md`.

## 0. Konvence
- Osy: **Y nahoru** (gravitace −Y), **X a Z vodorovně**, jednotky **metry**. Platí v jádru i v rendereru (Three.js je také Y-up, žádný převod).
- Index události 0 = nejstarší. Pořadí pole `events` **je** chronologie; `time` (Ma) je jen informativní a přepočítává se z pořadí (`retime`, `src/geology/timeline/timeline.ts`).
- Výchozí objem 64 × 64 × 64 m (volitelně 128 m), rozlišení 2 / 1 / 0,5 / 0,25 m (0,25 m = cílové rozlišení hry).

## 13.1 Architektura „backendu“ a výpočetního jádra

**Celý engine běží na klientovi (v prohlížeči).** Neexistuje žádný serverový backend. Výpočetní „backend“ je čistá TypeScript vrstva bez závislosti na Reactu a Three.js, která běží:
- ve **Web Workeru** (`src/workers/geology.worker.ts`): vzorkování voxelové mřížky (`sampleGrid`) a přímé vyhodnocení 2D průřezu (`sampleSection`);
- v **hlavním vlákně**: inspektor bodu (jeden bod), diagnostické metriky transformací (9³ bodů na deformaci), in-app testy (`runSuite`), generování meshe (`buildCulledMesh`, pouze v 3D pohledu), export golden vectors.
Pokud Worker nelze vytvořit, `GeologyClient` (`src/workers/client.ts`) provede stejný kód synchronně.

| Modul | Soubor | Odpovědnost |
|---|---|---|
| Hash | `src/core/deterministic/hash.ts` | `hashInt3` (32bit integer hash, Math.imul), `deriveSeed`, `hashString` (FNV-1a) |
| Šum | `src/core/deterministic/noise.ts` | `valueNoise2` (quintic), `fbm2` s periodou |
| Souřadnice | `src/core/coordinates/world.ts` | `WorldConfig`, `gridDims`, `cellCenter`, `wrapCoord` |
| Materiály | `src/core/materials/materials.ts` | databáze materiálů se stabilními ID |
| Typy událostí/operací | `src/geology/events/types.ts` | JSON definice událostí, rozhraní `MaterialOperation`, `DeformationOperation`, `TransformationOperation` |
| Sedimentace | `src/geology/events/material/sedimentation.ts` | `SedimentationOperation` |
| Vrásnění | `src/geology/events/deformation/folding.ts` | `FoldingOperation` |
| Zlom | `src/geology/events/deformation/fault.ts` | `FaultOperation` |
| Transformace | `src/geology/events/transformation/transformation.ts` | pouze rozhraní + testovací pomocník |
| Registr | `src/geology/operations/compile.ts` | `compileEvent` (JSON → operace), `contextFor` |
| Časová osa | `src/geology/timeline/timeline.ts` | výběr (`upToIndex`, `isolateId`), `compileTimeline`, validace závislostí, `createEvent` |
| Serializace | `src/geology/timeline/serialization.ts` | verzovaný JSON (`schemaVersion`) |
| Evaluator | `src/geology/evaluator/evaluator.ts` | `GeologicalFieldEvaluator.evaluate(x,y,z,out,history)` |
| Vzorkování | `src/voxel/sampling/sampleGrid.ts` | `sampleGrid`, `sampleSection` |
| Mesh | `src/voxel/mesh/culledMesher.ts` | `buildCulledMesh` |
| Renderer | `src/visualization/**` | `Viewport3D` (R3F), `CrossSection2D` (canvas), palety |
| Diagnostika | `src/diagnostics/**` | `measureTransforms`, `runSuite`, `buildGoldenVectors` |
| UI | `src/ui/**` | časová osa, parametry, inspektor, diagnostika, `GeoLab` |

### Tok dat
```text
UI (React state: events[], world, res, query)
  │ postMessage (strukturovaná kopie JSON)
  ▼
Worker: compileTimeline → ops[] → GeologicalFieldEvaluator → sampleGrid/sampleSection → material/source/layer
  │ transfer ArrayBuffer (bez kopie)
  ▼
Hlavní vlákno: buildCulledMesh(material, visibility LUT, palette, cut) → Float32Array/Uint32Array
  ▼
Viewport3D: THREE.BufferGeometry (1 mesh) ── nebo ── CrossSection2D: ImageData z sampleSection
```
Změna parametrů/časové osy/3D rozlišení → nové objemové vzorkování pouze v 3D (debounce 250 ms). 2D změna modelu vzorkuje jen průřez. Průřez se počítá samostatně (200 ms), jeho posun a vlastní rozlišení nezmění grid ani mesh. Kamera pouze vykresluje na vyžádání; viditelnost/barvení/buňky mění odvozený mesh/raster, nikdy geologické vzorkování. GPU vizuálně odřízne povrch bez capu, přesnou plochu řezu nese raster z evaluatoru. Renderer neobsahuje geologická pravidla.

## 13.2 Matematické algoritmy
Podrobné rovnice viz `ALGORITHMS.md`. Shrnutí:

**SedimentationOperation** (`sedimentation.ts`, `interfaces`, `classify`) – výšky rozhraní jsou analytické funkce vodorovných (x, z):
- \(h_0 = y_{start} + R\,N_{h,0}(x,z)\)
- \(w_i = t_i S \max(0.05,(1+V N_{l,i}(x,z))L(x,z))\), \(S=(y_{end}-y_{start})/\sum t\)
- \(h_i = \max(h_{i-1},\ h_0+\sum_{j\le i} w_j + R\,N_{h,i}(x,z))\)
- \(L(x,z)=1+\sum f_m e^{-r_m^2/\rho_m^2}\)

Parametry: `yStart, yEnd` [m], `layers[{materialId, thickness}]` (relativní mocnosti), `thicknessVariation` V ∈ [0, 0.9], `thicknessFrequency` [1/m], `roughness` R [m], `roughnessFrequency` [1/m], `local[]`, `mode`. Omezení: vrstvy jsou výškové pole (nemohou se převrátit samy o sobě), mocnost se může vyklínit na 0 (pinch-out) díky `max`.

**FoldingOperation** (`folding.ts`) – svislé střižné vrásnění:
- \(F(x,z)=A\,W(x,z)\sin(k_x x+k_z z+\varphi+I\pi N(x,z))\), \(g(y)=e^{\gamma(y-y_{ref})}\)
- forward \(y'=y+F(x,z)g(y)\); pro γ = 0 inverze **analyticky** \(y=y'-F\); pro γ ≠ 0 **Newton** (tolerance 1e-9 m, max 40 iterací, záložní bisekce).
- omezení: \(|A|\,|k| \le 1.2\) (amplituda se ořízne, varování), \(|A\gamma| e^{|\gamma|\,span}\le 0.8\) (γ se půlí), takže \(\det J = 1+F\gamma g > 0\).

**FaultOperation** (`fault.ts`) – rovinný zlom, tuhý posun nadloží:
- \(s=(\cos\theta,0,\sin\theta)\), \(u=(\sin\theta\cos\delta,-\sin\delta,-\cos\theta\cos\delta)\), \(n=(\sin\theta\sin\delta,\cos\delta,-\cos\theta\sin\delta)\)
- strana \(d(p)=n\cdot(p-p_0)\); kladná strana (nadloží) se posouvá o \(\Delta=D_{dip}u+D_{strike}s\)
- inverze po částech: \(p=p'-\Delta\) pro \(d(p')>0\), jinak \(p=p'\). Je přesná, protože \(n\cdot\Delta=0\).
- drcená zóna: \(|d(p')|<w/2\) → materiál 7 (brekcie) + příznak `FLAG_DAMAGE`.

## 13.3 Souřadnicový systém
- Spojité souřadnice v metrech, nezávislé na voxelech. Buňka (i, j, k) pokrývá \([i\,r,(i+1)r)\) a vzorkuje se ve středu \((i+0.5)r\) (`cellCenter`). Index pole: `i + nx·(j + ny·k)`, j = výška.
- Zpětná rekonstrukce (`GeologicalFieldEvaluator.walk`): \(p_N \to p_{N-1}\to\dots\to p_0\). Pro i = N−1 … 0: deformace → `inverse`; materiálová událost → `classify` na aktuálních (tehdejších) souřadnicích. Historie se zapisuje do `Float64Array(3·(N+1))`: stage i = poloha **před** událostí i, stage N = současnost; nenavštívené stage = NaN.
- Pravidla materiálových událostí:
  - bod v intervalu vrstvy → materiál vrstvy (`onlap`: jen pokud starší historie dává prázdno);
  - bod nad vrstvou, režim `erode` → vzduch (vše starší nad erozní plochou je odstraněno = diskordance);
  - bod pod bází → rozhoduje starší historie; je-li tam prázdno (např. synklinála pod erozní plochou), vyplní ho nejnižší vrstva. Skutečná spodní hranice mladší sedimentace = min(erozní plocha, paleopovrch).
- Numerická chyba: Newton s tolerancí 1e-9 m; reziduum a příznak `FLAG_NOT_CONVERGED` jsou vráceny s každým vzorkem (`maxResidual`).
- Ověření invertibility: `measureTransforms` počítá \(|F(F^{-1}(p))-p|\), \(\det J\) a \(|J-I|\) na mřížce 9³ pro každou deformaci; test 2 a 3.

## 13.4 Determinismus
- Žádný `Math.random`, žádný hash přes `Math.sin`. Šum je value noise nad celočíselnými rohy mřížky s `hashInt3` (murmur-like mix, 32bit `Math.imul`), quintic interpolace `6t⁵−15t⁴+10t³`.
- Každá událost má vlastní `seed` (výchozí = FNV-1a z ID); dílčí seedy (vrstvy, rozhraní, nepravidelnost vrás) přes `deriveSeed(seed, salt)`.
- Všechny funkce jsou čisté → pořadí vyhodnocování bodů nemá vliv (ověřeno testem 1: dopředné vs. obrácené pořadí). Cache (`SedimentationOperation.interfaces` pro poslední sloupec) je memoizace čisté funkce.
- Přesnost: float64. Integer hash je bitově shodný na všech platformách. `Math.sin/exp/cos` nejsou v ECMAScriptu specifikovány bitově přesně → **ověřujeme jen opakovatelnost na jednom stroji**, nikoli bitovou shodu mezi platformami/prohlížeči. Bitová shoda se řeší až v portu do C# (fixed-point nebo vlastní deterministické sin/exp).

## 13.5 Voxelizace
- `sampleGrid`: bodové vzorkování ve středech buněk, osa Y nejvnitřnější smyčka (zásah cache sloupce). Výstup `Uint8Array material` + `Uint8Array source` (index události, 255 = žádná) + `Int32Array layer` (dočasný index vrstvy, −1 = žádná). Materiál buňky = materiál ve středu (bez anti-aliasingu/majority).
- `sampleSection`: přímé vyhodnocení roviny bez mřížky; UI volí 2 / 1 / 0,5 / 0,25 m. Vrací pxPerM, material/source/layer. Jednotné `sectionCoordinates` určuje pixelové středy, 2D/3D picking a polohu roviny. X: u=Z, v od horního Y; Z: u=X, v od horního Y; Y: u=X, v roste po Z.
- `buildCulledMesh`: dvouprůchodový mesher (spočítat → alokovat TypedArrays → naplnit), stěna se generuje jen mezi viditelnou a neviditelnou buňkou; výsledkem je **jeden** `BufferGeometry`. Volba „voxelové buňky“ zmenší stěny o 8 %. Nový pohled A nepoužívá voxelový cut/cap; klipuje povrch v rendereru a přidává nezávisle vyhodnocenou přesnou rovinu. Mesher nadále zachovává původní volitelné cutAxis/cutPos API.
- `GeoSample.bodyId` a inspektor vracejí `null`, protože v0 nemá stabilní identitu těles. Filtr source:layer je pouze snapshotový údaj, resetuje se po změně historie; není exportovaný stable ID. JSON a golden vectors se nemění.

## 13.6 Testování
Spuštění: v aplikaci tlačítko **Testy** / Diagnostika → „Spustit automatické testy“ (`runSuite`), nebo `bunx vitest run src/geology` (stejná sada + jednotkové testy operací, `src/geology/__tests__/engine.test.ts`). Skutečný výsledek při psaní dokumentace: **21/21 prošlo**.

| Test | Ověřuje | Očekáváno | Skutečně naměřeno | Limity |
|---|---|---|---|---|
| 1 Determinismus | hash mřížky E (2 m) 2× + 2000 bodů v obou pořadích | shoda | ba54723a = ba54723a, pořadí bez vlivu | jen jeden stroj |
| 2 Inverze | max \|F(F⁻¹p)−p\| všech scénářů + numerická vrása γ=0.02 | < 1e-6 m | 8.62e-10 m | mřížka 9³ |
| 3 Jacobian | min det J (vč. extrémních parametrů) + obrácení pořadí vrstev ve 400 sloupcích scénáře C | det > 0, 0 obrácení | min det 0.8641, 0 | det jen ve vzorkových bodech |
| 4 Periodicita | Sample(x,y,z) = Sample(x+64, y, z−128) na torusu, šum i F vrásy | 0 rozdílů | 0/1500, Δ šumu 0, Δ F 5.4e-15 | zlomy nejsou periodické |
| 5 Chronologie | zlom = posun starší struktury, záměna pořadí mění výsledek, pokryv E | 0 chyb, >0 rozdílů | 0/1484, 2000 buněk, 300/300 | – |
| 6 Spojitost | max skok rozhraní mezi sousedními 1m sloupci | C < 3 m, svislý zlom > 5 m | viz in-app (C ≈ 1.6 m) | ukloněný zlom tvoří zlom rozhraní, ne skok |
| 7 Rozlišení | buňka = funkce ve středu; objemové podíly 2 m vs 1 m | 0; < 2 % | 0; < 2 % | geometrie voxelů se liší (záměrně) |

Jednotkové testy operací: monotonie rozhraní, 5 vrstev, nerovnost rozhraní; přesná analytická inverze vrásy; konvergence Newtona; ořez amplitudy a det J > 0; posun jen kladné strany zlomu, přesná inverze, skluz v rovině, brekcie v drcené zóně; vzduch/podloží; historie p0…pN; hák transformací; round-trip JSON; reprodukovatelnost golden vectors.

## 13.7 Výkon (skutečně naměřeno)
Měřeno 24. 11. 2026 v sandboxu (Node 22 / vitest, 16 vláken CPU, jednovláknový výpočet), `sampleGrid` + `buildCulledMesh`, všechny materiály viditelné:

| Scénář | Rozlišení | Vzorků | Vyhodnocení | Mesh | Stěn | Mřížka | Mesh data |
|---|---|---|---|---|---|---|---|
| A (1 událost) | 2 m | 32 768 | 30 ms | 53 ms* | 5 038 | 0,07 MB | 0,85 MB |
| A | 1 m | 262 144 | 62 ms | 104 ms* | 20 252 | 0,52 MB | 3,40 MB |
| A | 0,5 m | 2 097 152 | 347 ms | 350 ms | 81 152 | 4,19 MB | 13,6 MB |
| B (2) | 1 m | 262 144 | 86 ms | 40 ms | 20 270 | 0,52 MB | 3,41 MB |
| C (3, nepravidelná vrása) | 1 m | 262 144 | 262 ms | 55 ms | 23 698 | 0,52 MB | 3,98 MB |
| D (3) | 1 m | 262 144 | 114 ms | 43 ms | 20 242 | 0,52 MB | 3,40 MB |
| E (5) | 1 m | 262 144 | 115 ms | 44 ms | 25 946 | 0,52 MB | 4,36 MB |
| E | 0,5 m | 2 097 152 | 652 ms | 308 ms | 105 116 | 4,19 MB | 17,7 MB |

\* první běh zahrnuje JIT zahřátí. V headless Chromiu (scénář E, 1 m, Worker): vyhodnocení 89 ms, průřez 40 ms, mesh 108 ms, vykreslení do 2. snímku 210 ms (softwarové GPU).
Vliv rozlišení: čas ~ lineární s počtem vzorků (×8 při půlení kroku). Vliv událostí: hlavní náklad je šum (fbm); nepravidelnost vrásy (2 oktávy fbm na vzorek) je nejdražší. **Nezměřeno:** 0,25 m (16,8 M vzorků pro 64 m, 134 M pro 128 m – v prohlížeči nepraktické bez chunkingu), reálné GPU, mobilní zařízení, paměťová špička prohlížeče.

## 13.8 Přenos do C# a Godotu
- Přímo přenositelné: celé `src/core`, `src/geology`, `src/voxel` (bez DOM/React/Three). `Math.imul` → `unchecked(uint * uint)`; `>>>` → `uint >>`; `Float64Array` → `double[]`/`Span<double>`; `Uint8Array` → `byte[]`.
- Závislé na JS: Web Worker/`postMessage` (→ Godot `WorkerThreadPool` / Task), `performance.now`, Three.js/React (→ Godot `ArrayMesh`, `SurfaceTool`).
- Zachovat datové struktury: JSON časové osy (`TimelineDocument`, schemaVersion 1), ID materiálů, rozhraní operací (`Forward/Inverse/IsInvertible/Validate/EvaluateJacobian`), layout pole `i + nx(j + ny k)`, sample record bez alokace.
- Kompatibilita: porovnat s **golden vectors** (tlačítko „Golden vectors A–E“, `buildGoldenVectors`): body jsou kvantovány na 1/1024 m, obsahují materiál, ID zdrojové události, příznaky a historii p0…pN. Shoda materiálu se očekává mimo body ležící < ~1e-9 m od rozhraní; pro bitovou shodu použít fixed-point (např. Q32.32) a deterministické aproximace sin/exp.
- Budoucí Willage: server v C# vyhodnocuje chunky (např. 32³ při 0,25 m) na vyžádání, `CompiledTimeline` sdílená, cache rozhraní per sloupec; klient dostává jen voxelová data.

## 13.9 Známá omezení a další vývoj
Neimplementováno (jen rozhraní `TransformationOperation` / dokumentace): intruze, sopky, metamorfóza, mineralizace, eroze povrchu (kromě rovinné erozní báze sedimentace), hydrogeologie, plná toroidní periodicita (zlomy nejsou periodické; vrásy mají přichycený vlnový vektor; rozsah vrásy používá min-image vzdálenost).
Doporučené pořadí: 1) plná periodicita zlomů (periodické kopie roviny / omezený rozsah zlomu s útlumem), 2) eroze povrchu (výšková funkce eroze jako MaterialEvent s mode erode), 3) intruze (implicitní tělesa SDF jako MaterialEvent přepisující starší), 4) kontaktní metamorfóza (TransformationEvent podle vzdálenosti od intruze v čase vzniku), 5) mineralizace, 6) sopky, 7) hydrogeologie (vlastnosti materiálů → propustnost).

### Seznam matematických zjednodušení (v0)
1. Vrásnění je **čistě svislý střih**: body se posouvají jen po Y, sloupce (x, z) zůstávají na místě. Proto ve 3D **nemůže** vzniknout překrytí vrstev ani obrácení pořadí (det J = 1 + Fγg > 0, ověřeno testem 3 ve 400 sloupcích ve 3D, ne jen v průřezu). Daň: žádné překocené/ležaté vrásy, žádné horizontální zkrácení, mocnost vrstvy měřená kolmo na vrstvu se na ramenech ztenčuje (o faktor cos sklonu).
2. Sklon ramen je omezen \(A|k|\le1.2\) (~50°); nepravidelnost fázovým šumem tento odhad mírně zvyšuje a hlídá se jen numericky.
3. Zlom je nekonečná rovina s konstantním posunem (bez útlumu posunu, bez tažení vrstev, bez rotace bloků). Drcená zóna je pouze pásmo |d| < w/2.
4. Jacobian vrásy používá centrální diference (h = 1e-4 m) pro ∂F/∂x, ∂F/∂z; Jacobian zlomu je identita mimo rovinu, na rovině nedefinovaný.
5. Sedimentace je výškové pole rozhraní; erozní báze je rovina + šum (ne skutečný paleopovrch), prohlubně pod ní se vyplňují nejnižší vrstvou.
6. Materiál buňky = bodový vzorek ve středu (žádné průměrování), proto se geometrie voxelů mezi rozlišeními liší.
7. Value noise (ne gradient noise); periodicita šumu přichycuje frekvenci na celé násobky periody.
8. Float64 s nespecifikovanou přesností transcendentních funkcí – bitová shoda mezi platformami není zaručena.
