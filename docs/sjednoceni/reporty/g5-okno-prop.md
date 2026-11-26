# G-5 – okno 1 Generátor světa: kostra + konfigurátory generované ze schématu (PROP)

Větev `gen-v1-g5-okno` (z `gen-v1-g4-jadro` 199d06e). Plán 05, kap. 5 a tabulka G-5. Jan 17:39: na čekající věci zástupné prvky.

## Cíl
1. **Popis konfigurátoru bez Godotu** (`cs/Willage.Gen.Api/Konfigurator/`): z `ParametrDto` (schéma G-2) určí druh editoru
   (celé / desetinné s posuvníkem, když je rozsah; přepínač; volba; text; JSON pro pole a tabulky), skupiny v pořadí schématu,
   převod hodnoty editoru ↔ JSON pro `Nastav` (invariantní kultura, celá čísla bez desetinné části), jen čtení → zamčený editor.
   Mapa modul → vrstvy náhledu (dočasná, G-6/G-7 přinesou vlastní náhledy). Testovatelné v `Willage.Gen.Testy`.
2. **Okno** `godot-prototyp/nastroje/GeneratorSveta.tscn` – samostatná hlavní scéna (`godot --path godot-prototyp res://nastroje/GeneratorSveta.tscn`),
   kořen `GeneratorSvetaOkno` jen propojuje uzly (žádný monolit). Uzly viditelné v editoru (`[GlobalClass]`, `scripts/cs/GeneratorSveta/`):
   - `HorniLista` – seed, gen_ver, otisk planety, Přepočítat vše, Zrušit, Potvrdit planetu, Uložit / Načíst WPLN;
   - `SeznamModulu` – M0–M7 + zástupné M6d, M8, M9 se stavem (spočteno / z paměti / čeká / zástupný), výběr;
   - `KonfiguratorModulu` – vrstva modulu (jako funkční vrstvy GeoLabu): skupiny, `EditorParametru` na každý parametr
     generovaný z popisu 1, akce Přepočítat modul + závislé, Výchozí hodnoty modulu, Izolovat vrstvu (zástupné → G-6/G-7), Uložit sadu (zástupné);
     u zástupných modulů jen `ZastupnyPanel`;
   - nápověda parametru: tlačítko „?“ s textem „zástupný: nápověda – texty nejsou ve v1“ (Jan 16:50: texty ve v1 nejsou);
   - `NahledModulu` – výběr vrstvy + `NahledVrstvy` (G-4); `PohledRezu` zástupný (G-6); `Diagnostika` (souhrn planety, čas, přepočtené moduly);
   - `RetezPrepoctu` – M0 → … → M9 se stavem a časy, průběžně ze signálu `ModulHotov`.
3. Jádro: `Vychozi()`, `InfoPlanety()`, signál `PrepocetHotov(prepocitane)` pro diagnostiku; vše dál přes frontu.
4. Headless test `nastroje/testy/GeneratorSvetaTest.tscn` (instancuje okno) + snímky okna (Godot s rendererem pod Xvfb, pokud půjde).

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| popis konfigurátoru (dotnet) | 202 parametrů → editor pro každý; 160 desetinných, 14 celých, 20 přepínačů, 2 volby, 6 JSON; převod hodnoty tam a zpět = původní JSON; skupiny v pořadí schématu |
| okno headless | seznam 11 modulů; výběr M4 → 20 editorů v 5 skupinách; změna parametru M5 přes editor → neplatné M5, M6, M7 (ne M0–M4); přepočet → M0–M4 z paměti, M5+ spočteno |
| čas | celá planeta ve okně (studená keš eroze z disku) ≈ 2 s na boxu; plán uvádí ~5–6 s s erozí bez keše |
| potvrzení | po Potvrdit editory zamčené, Nastav odmítnut |
| otisky | beze změny 9d4f2b8 |

## Rizika
- Headless Godot nemá renderer → snímky okna přes Xvfb + OpenGL (llvmpipe); když nepůjde, nakreslím rozvržení zvlášť a řeknu to.
- 202 editorů v jednom okně – staví se jen editory vybraného modulu (max 47).

## Výsledky
*(doplní se po implementaci)*
