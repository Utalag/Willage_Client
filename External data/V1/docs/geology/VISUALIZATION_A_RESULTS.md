# Fáze 2 – vizualizace A: implementace a výsledky

Ověřeno 24. 11. 2026. Fáze 3–7 v1 zůstávají návrhem; nebyl implementován nový světový dokument, hierarchie, index ani nový geologický proces.

## Dodaná funkcionalita

- 3D vykresluje culled povrchový mesh a samostatný průřez **přímo ze současného evaluatoru**. GPU odstraní zakrývající povrch na přesné poloze řezu, nevytvoří kvantovaný voxelový cap.
- Společná osa X/Y/Z a poloha pro 3D/2D, samostatné rozlišení řezu 2 / 1 / 0,5 / 0,25 m. Kamera je přizpůsobena poměru stran a vykresluje na vyžádání.
- Jedna konvence rasteru a společný pixelový picking. 3D/2D inspektor vyhodnotí skutečný střed zvoleného pixelu; povrchový picking zůstává voxelový.
- Materiály, zdrojové sedimentační události a jednotlivé zdrojové vrstvy lze vizuálně skrýt bez změny geologické historie. Filtr source/layer je dočasný pro konkrétní snapshot a po změně historie se resetuje; nejde o stabilní identitu.
- Volitelné hranice vrstev jsou **hranice vzorkovaného rastru**, včetně rozlišení vrstev stejného materiálu podle source/layer.
- `GeoSample.bodyId` a inspektor vracejí `null`. Žádné ID těles není odvozeno z indexů. Uložený JSON a golden vectors jsou nezměněné.
- V 2D se nově nepočítá objem ani mesh. Platný grid je uchován pro návrat do 3D. Posun roviny či změna jejího rozlišení vyhodnocuje pouze řez; barvy, hranice, viditelnost a kamera neodesílají žádný sampling požadavek.

## Testy – skutečný výsledek

```text
bunx vitest run src/geology/__tests__/engine.test.ts \
  src/geology/__tests__/visualizationA.test.ts \
  src/ui/useGeologySamples.test.tsx src/test/app-routing.test.tsx

4 soubory, 35/35 testů prošlo
21 původních geologických + 8 nových numerických/identitních
+ 5 testů oddělení požadavků + 1 existující test routování
```

Nové numerické testy ověřují:
- všechny vzorky řezů X/Y/Z při 2 m a poloze 23,375 m vůči nezávisle sestaveným souřadnicím a skutečnému evaluatoru: materiál, zdroj, vrstva a null bodyId;
- přesné souřadnice pixelových středů i krajních pixelů a vodorovné roviny;
- rozměry průřezů 32/64/128/256 pro krok 2/1/0,5/0,25 m nezávisle na 2m gridu;
- skrývání jedné zdrojové vrstvy, aniž se skryje jiná stejného materiálu;
- neměnnost vstupní historie;
- **před změnou zaznamenaný golden checksum 881396785 = po změně 881396785** (`hashString(JSON.stringify(buildGoldenVectors(16)))`, scénáře A–E). Shoda platí na tomto stroji, nikoliv slib bitové shody jiných platforem.

Testy samplerového hooku ověřují počty grid/section volání při posunu řezu, změně rozlišení, editaci modelu v 2D, návratu do 3D, nezměněném rerenderu a opožděném výsledku starého řezu.

## Prohlížeč – end-to-end

Skutečný Web Worker, Chromium/SwiftShader, scénář E, žádná demo/mock data:

| Krok | Grid požadavky | Section požadavky |
|---|---:|---:|
| První 3D otevření | 1 | 1 |
| Posun Z řezu 32 → 23,375 m | 1 | 2 |
| Rozlišení řezu 0,25 → 0,5 m | 1 | 3 |
| Rotace kamery, barvení událostí, hranice, skrytí vrstvy | 1 | 3 |
| 2D a přepínání X/Y/Z, návrat do 3D | 1 | 6 |

Kliknutím ve 3D a následně na tentýž pixel ve 2D bylo potvrzeno:

```text
p = (24.750, 21.750, 23.375) m
materialId = 3 (Vápenec)
sourceEventId = sedimentation-1
layerIndex = 3
bodyId = null
flags = 0
historie p0…p5 shodná v obou pohledech
```

Na X/Y/Z řezech v 2D bylo potvrzeno, že souřadnice příslušné osy zůstává přesně 23,375 m. Na mobilním rozměru byl ověřen také 3D řez X/Y/Z a 2D picking s čitelným inspektorem; žádný horizontální overflow (scrollWidth = viewport = 390 px).

Bundlovaný ověřovací harness dovednosti **3d-game** zachytil a byly vizuálně zkontrolovány rozměry 1280×1800, 770×1214 a 390×844. Model není prázdný ani mimo rám; barvy, řezy a inspektor jsou viditelné. **0 page errors, 0 failed/4xx/5xx requests**. Automatická kontrola sestavení: poslední stav `build OK`.

Zbývají neblokující upstream varování `THREE.Clock` v R3F a `THREE_CJS_DEPRECATED` v testovacím běhu; SwiftShader při screenshotu hlásí GPU ReadPixels stall. Žádné z nich není důkaz výkonu na skutečné GPU. Balíčky nebyly kvůli varování měněny.

## Odchylky a omezení

- **Bez odchylky od schváleného rozsahu:** matematika sedimentace, vrásnění a zlomů se nezměnila; algorithmVersion a SCHEMA_VERSION zůstávají 1. Runtime sample record pouze přidal explicitní null bodyId a sampling přenáší dočasný layer index; nejde o nový světový JSON.
- Pro zdrojové vrstvy není stabilní ID, jen snapshotový index; žádná stabilní identita těles není vymyšlena. U deformací je zachováno skutečné enabled vypnutí procesu; geometrický filtr samostatného zlomového tělesa zatím není dostupný.
- Hranice jsou rasterové a bodové vzorkování může vynechat velmi tenkou vrstvu nebo damage zónu. Brekcie není deklarována jako přesná analytická plocha zlomu. Analytické plochy všech zlomů/těles a varianta B nejsou implementované.
- Pro 3D voxelový povrch je stále nutné úplné vzorkování. Jemné/velké objemy bez chunkingu mohou být náročné; 0,25 m na 128 m nebylo měřeno. Přidaný `Int32Array layer` zvyšuje sampling data z 2 na 6 bajtů/vzorek (bez dalších dat meshe a rastru).
- Existující source `Uint8Array` a sentinel 255 zůstávají limitem velké historie; širší stabilní kontrakty patří až do v1.
- Geologická periodicita/neomezené zlomy se neřeší ořezáním bounds. Samostatný problém: GEO-PERIODIC-FAULT v `TECHNICAL_ISSUES.md`.
- Skutečná GPU, mobilní hardware a dotykový pocit nebyly v sandboxu ověřeny. Pro kontrolu otevřít náhled na vlastním zařízení, přepnout X/Y/Z, posouvat řez, otáčet model a kliknout do průřezu. Screenshoty a automatizované myší ovládání dokazují vykreslení a datový tok, nikoliv plynulost či reálné dotykové ovládání.

## Opakovatelnost kontroly v náhledu

V development režimu lze v konzoli číst `window.__geologyRequests()` (grid/section počty) a `window.__geologyView()` (aktuální osa, poloha, rozměry a inspekce). Nejde o produkční API ani možnost měnit matematiku. Architektonické rozhodnutí je uvedeno v root `AGENTS.md`.