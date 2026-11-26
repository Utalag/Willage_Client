# G-4 PROP – Godot jádro `WillageJadro`

Větev `gen-v1-g4-jadro` (z `gen-v1-g3-api`), plán 05 krok G-4, Jan 17:39 (postupně, zástupné části, bez čekání na schválení mezi kroky).

## Cíl
1. **Fronta práce bez Godotu** (`cs/Willage.Gen.Api/Fronta/FrontaPrace`): jedno vlákno na pozadí, úlohy v pořadí, zrušení (`CancellationToken`),
   výsledek / chyba / průběh se doručí přes předaný dispečer (v Godotu `CallDeferred` na hlavní vlákno). Testovatelné v `Willage.Gen.Testy`.
2. **Průběh a zrušení v pipeline**: `PipelineSveta.Spust(…, poModulu, zruseni)` – volitelné parametry, výchozí chování beze změny;
   zrušení se kontroluje mezi moduly. Fasáda: `ISluzbaSveta.Generuj(IProgress<ModulDto>?, CancellationToken)`.
3. **Barvy vrstev bez Godotu** (`Willage.Gen.Api/Vizual/BarvyVrstev`): MapaDto → RGBA8 (výška, eroze, teplota, srážky, biom) – logika převodu mimo uzly.
4. **Godot jádro** `godot-prototyp/scripts/cs/Jadro/` (C#, žádný monolit):
   - `WillageJadro` (autoload Node, `[GlobalClass]`): drží `GeneratorSveta` (líně, hra se nezdrží), frontu, příkazy `Generuj`, `Nastav`, `Uloz`, `Nacti`, `Potvrd`, `Zrus`;
     signály `ModulHotov`, `PlanetaHotova`, `PraceSelhala`, `PraceZrusena`, `KatalogZmenen` (zástupně: hlídání souborů přijde s oknem 2).
   - `Adaptery/`: `TexturaMapy` (MapaDto → `Image`/`ImageTexture`), `SitRezu` (RezDto → `ArrayMesh` profil), `MultiMeshSloupce` (SloupecDto → `MultiMesh` kostek 0,25 m).
   - Uzly viditelné v editoru: `NahledVrstvy` (`TextureRect`, exportovaná vrstva, po `PlanetaHotova` si vyžádá mapu), `StavJadra` (`Label`, stav fronty a modulů).
   - Zástupné uzly: `ZastupnyPanel` (`Label` s textem „zástupný: …“) pro 7d, M8, M9, U-1, U-2, nápovědu.
5. Testovací scéna `nastroje/testy/JadroTest.tscn` (C# `JadroTest`), headless: generace přes jádro, hlavní vlákno neblokované, zrušení, otisky = CLI, textura.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| fronta (dotnet) | pořadí úloh, výjimka → chyba, zrušení před i během, průběh na dispečeru, Dispose ukončí vlákno |
| pipeline průběh | callback po každém modulu (11 se zástupnými), zrušení mezi moduly → OperationCanceledException, výsledky beze změny |
| headless Godot | volání `Generuj` na hlavním vlákně < 1 ms, snímky běží během generace, otisky = 800d420bb00047de / cb11da8d141a2a5e / 86 / 377a8210f82c856a, zrušení → signál PraceZrusena |
| build | `dotnet build` WillagePrototyp i Godot .NET headless (Godot 4.7.2 mono je na boxu v /workspace/tools) |
| všechny testy | 375 + nové, 0 chyb, otisky 9d4f2b8 |

## Rizika
- Headless Godot poprvé importuje zdroje projektu (pomalé) – import se nepočítá do měření.
- `CallDeferred` z vlákna na pozadí je v Godotu 4 bezpečné (fronta zpráv), ale signály se musí vysílat jen na hlavním vlákně – dispečer to hlídá.
- Autoload v project.godot se načte i ve hře – proto líná inicializace (nic se nepočítá, dokud o to někdo nepožádá).

## Výsledky
*(doplní se po implementaci)*
