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
**Postaveno:** viz Cíl 1–5 (vše hotovo). Zástupné uzly `ZastupnyPanel` pro 7d, M8, M9, U-1, U-2, nápovědu; signál `KatalogZmenen` zástupný.

| Měření | Výsledek |
|---|---|
| `dotnet run Willage.Gen.Testy` | **OK 397, chyb 0** (4 min 8 s) |
| Godot 4.7.2 mono headless `--editor --build-solutions` | build .NET projektu OK |
| `dotnet build WillagePrototyp.csproj` | OK, 0 chyb |
| headless `JadroTest.tscn` | **OK 12, chyb 0**; `Generuj` na hl. vlákně zahřáté 0,014 ms, studené 3,4 ms (JIT + start vlákna); během generace 2,0 s proběhlo 291 snímků, nejdelší 24,3 ms; otisky = CLI; mapa 980×488 /4 → 245×122; zrušení po M5 → `PraceZrusena`; chyba → `PraceSelhala` |
| hlavní scéna hry s autoloadem (`--quit-after 120`) | OK, líná inicializace nic nepočítá |
| `klima otisky` | mapa 800d420bb00047de; zap: 86 vodníků, krok 3 9f32311e046f8b6a, voda 377a8210f82c856a, klima cb11da8d141a2a5e; vyp: 92, 8e239a68c6d01be0; segment 059d807ab04b7f00 (test) – **beze změny vůči 9d4f2b8** |

**Negativní / nečekané:**
- První běh testů 386/3: headless import Godotu vytvořil `*.csv.import`/`*.translation` v `data/` a změnil manifest → manifest je ignoruje, `.gitignore` (c0ac920).
- První `Generuj` 3,2–3,4 ms (JIT) – limit < 1 ms platí jen pro zahřáté volání, studené se hlásí.
- G-3 větev byla napoprvé pushnuta bez změny seed → long v `PlanetaV1`/`SouborPlanety` (nekompilovala) – opraveno commitem 1389f1c na gen-v1-g3-api.
- Fasáda není vláknově bezpečná – řešeno jedinou frontou; CTS se záměrně nedisposuje (souběh se zrušením).

## G-3 review (Willage-backend) – zapracováno
| Bod | Commit | Co |
|---|---|---|
| 1 WPLN jen autorský formát, hash kanonického obsahu | 40e1ed7 | `SouborPlanety.Otisk` = SHA-256 kanonického textu; `PlanetaInfoDto.OtiskPlanety`; zástupný `PlanetaJson.Export` (`willage-planeta-export-v1`) |
| 2 bez reference na Geology.Core, Q16 = 2D bod | 774726e | README + doc `SouradniceQ16`; MapaDto = hrubá mřížka 32 m, ne buňky |
| 3 seed long, 32bit na jednom místě | 1369bb5 | `SeedSveta.Hash32` (dolních 32 bitů = dosavadní chování oáz) |
| 4 SloupecDto 2 B/buňku | d273e41 | materiál + varianta jako Dev ShellCellPayload; `StredBunky`/`MinRohBunky` |
| 5 MaterialId byte, kolize 57 | cd92826 | `byte`, kolize SopkaPopelId 57 s Dev 57–74 zdokumentována, nepřečíslováno |
| 6 Q16 na hranici | 836623f | `UpravaRegionu` v Q16 (long); PovrchM/KrokM zdokumentovány v metrech |
| 7 verzování | 2fc28a3 | `KompatibilitaPlanety` (Plna/Prepocet/Nepodporovana), formát 1..Verze; pin `materials-catalog-v1.json` (schemaVersion + SHA) v manifestu |
| 8 zrcadla jen pro čtení + golden vektory | 774726e | README |
| testy | 0ff686e | otisk stabilní/se mění, export, seed 2⁴⁰+5, V0.9 a formát 2 odmítnuty, pin katalogu |

Otisky se žádným bodem nezměnily.
