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
**Postaveno:** Cíl 1–4. Okno `nastroje/GeneratorSveta.tscn` (vlastní hlavní scéna), uzly v `godot-prototyp/scripts/cs/GeneratorSveta/` (namespace `WillagePrototyp.OknoGeneratoru`):
`GeneratorSvetaOkno` (jen propojuje), `HorniLista`, `SeznamModulu` (ItemList), `KonfiguratorModulu` + `EditorParametru`, `NahledModulu`, `Diagnostika`, `RetezPrepoctu`, `StavyModulu`.
Logika konfigurátoru bez Godotu: `cs/Willage.Gen.Api/Konfigurator/PopisKonfiguratoru.cs`. Fasáda: nově `IModuly.VychoziModulu(modul)`. Jádro: `Vychozi`, `VychoziModulu`, `InfoPlanety`, DTO keš (`PosledniModuly`, `ParametryDto`, `PosledniInfo`).
Signál `PrepocetHotov` z PROP nebyl potřeba – diagnostika čte `PosledniVysledek` po `PlanetaHotova`.

**Zástupné (označené „zástupný“):** Izolovat vrstvu (→ G-6/G-7), Uložit sadu (sady parametrů; dnes celá planeta ve WPLN), nápověda „?“ u každého parametru (texty nejsou ve v1),
editor tabulek a polí (6 parametrů – ve v1 JSON v řádku), vlastní náhled modulu (dnes vrstvy hotové planety), PohledRezu (G-6), U-1, U-2, moduly M6d/M8/M9 (jen panel).

| Měření | Výsledek |
|---|---|
| `dotnet run Willage.Gen.Testy` | **OK 452, chyb 0** (G-5 část 55/0) |
| Godot headless `GeneratorSvetaTest.tscn` | **OK 22, chyb 0** |
| tentýž test pod Xvfb (OpenGL 4.5, Mesa llvmpipe) se snímky | OK 22, chyb 0; snímky 1600×960 v `docs/sjednoceni/obrazky/g5/` |
| `JadroTest.tscn` (G-4) | OK 12, chyb 0 |
| okno jako hlavní scéna (`--quit-after`), hra s autoloadem | bez chyb (po opravě níže) |
| editory | 202 editorů ve 35 skupinách (desetinné 160, celé 14, přepínače 20, volby 2, JSON 6), 172 s posuvníkem, 8 zamčených (jen čtení); hodnota každého editoru = hodnota sady; nezměněná hodnota → Nastav nezneplatní nic (194/194) |
| M4 | 20 editorů v 5 skupinách, náhled eroze |
| změna `VyskovyGradientCNaM` 0,05 → 0,06 přes editor | neplatné M5, M6, M6d, M7, M8, M9; Čeká jen M5, M6, M7; **přepočet ~0,4 s: M0–M4 z paměti, M5–M7 spočteno**; klima jiné, mapa stejná |
| Výchozí hodnoty modulu | editor zpět 0,05, otisky zpět cb11da8d141a2a5e / 86 |
| Potvrdit planetu | uloží WPLN, editory zamčené, Nastav odmítnut |
| čas celé planety v okně | **~2,0 s s keší eroze WGER na disku; 8,2 s se studenou keší** (plán odhadoval 5–6 s) |
| `klima otisky` | mapa 800d420bb00047de; zap 86 / 9f32311e046f8b6a / 377a8210f82c856a / cb11da8d141a2a5e; vyp 92 / 8e239a68c6d01be0 – **beze změny** |

**Negativní / nečekané:**
- Studená planeta 8,2 s (eroze bez keše) – nad odhadem plánu 5–6 s; s keší 2 s. Neladil jsem (mimo G-5).
- `SpinBox` bez kroku ukazoval 16 desetin („0000000136“ místo 315.36) a `Range` ukládá min + n·krok (315.36000000000001) → krok podle zápisu hodnoty (aspoň 3 desetiny)
  a zaokrouhlení na desetiny kroku před převodem do JSON; test „hodnota editoru = sada“ to hlídá.
- Výchozí hodnoty modulu z keše DTO v okně nic neudělaly (keš měla starou hodnotu) → nová metoda fasády `VychoziModulu` počítá na vlákně fronty z aktuální sady;
  jádro po přijatém `Nastav` obnoví DTO parametrů modulu.
- Zavření okna během generace: zrušené úlohy se doručovaly po uvolnění uzlu jádra → `ObjectDisposedException` (chyba už z G-4) → doručení po `_ExitTree` se zahodí.
- Test čekal na `PlanetaInfo` po Uložit a chytil dřívější info (souběh ve frontě) → čeká na soubor.
- Headless Godot nemá renderer – snímky jdou jen pod Xvfb (`xvfb-run … --rendering-driver opengl3`).
