# PROP – Krok 5 (nové pořadí), port geologie do C# s opravami z kroku 4

Větev `gen-v1-krok04b-geologie-cs` z `gen-v1-krok04-podzemni-voda` (511d0a3). Napsáno 2026-11-26 9:15 SEČ, před změnou kódu. Do `main` se nemerguje. Krok 4 schválil Jan 8:48 ([pt913u]), nové pořadí kroků 9:06 ([pt914u], [pt916u]).

## Proč
Most do GDScriptu je 99,6 % času kroku 4 (7,3 ms na sloupec). Jan rozhodl port hned (rozhodnutí 6 ke kroku 4) a tři opravy: nitro sopky nepropustné (3), vyhladit skoky vrstev na švech od mince E82 (7), hustota pramenů jako parametr (2, způsob a hodnoty rozhodne Jan).

## Plán
1. **Port kroků 1–3 do `cs/Willage.Gen`** (bez Godotu), data beze změny (`poradi_hornin.json`, `materialy_v1.csv`, `klima_presety.csv`, `v1/utvary_hostitele.json`, `v1/sum_hornin_v1.csv`, `teren/mineraly_hostitele.json`). Moduly: Godot matematika a FastNoiseLite (`Sum/`), parametry a klima, mapa biomů, reliéf, masiv, sopky, mapa hornin, funkce světa (`Svet/`), katalog hornin, šum mocnosti, hostitelé, vrstvy, mince, vnitřek sopky, útvary, `GeologieCs : IGeologie` (`Geologie/`). Jen výchozí cesta; volby, které výchozí svět nepoužívá (`biom_velke_oblasti`, `klima=ze_seedu`), hodí výjimku a jsou zapsané jako nepřenesené.
2. **FastNoiseLite:** oficiální C# port Auburn/FastNoiseLite ve verzi, kterou má Godot 4.x (1.1.0, f7af54b, MIT) + obal s chováním Godotu (parametry jako `float`, souřadnice `float`, doménová deformace v samostatném objektu, výchozí hodnoty Godotu). `Vector2` sopek v `float` jako v Godotu.
3. **Ekvivalence s GDScriptem před opravami** (opravy vypnuté): (a) povrch a materiál v náhodných bodech; (b) sloupce bloku 14,14 po 2 m × 0,25 m; (c) otisk kroku 3 `bbdc0afa877d6c2e` (3 × 3, 2 m / 1 m, 4 718 592 buněk) přepočtený v C#; (d) otisk vody kroku 4 `f19006126c4b12a7` s C# geologií. Kde bitová shoda nejde, změřit počet a velikost rozdílů a zapsat.
4. **Opravy za přepínači (výchozí zapnuto):**
   - `sopka_nepropustna`: buňky vnitřku sopky (průduch, láva, popel) jsou pro vodu těsnění (rozhraní `IGeologie.NitroSopkyDo`).
   - `p82_prechod_m` (výchozí 32 m, 0 = vypnuto = původní mince po blocích): mince E82 jako spojité pole c ∈ [0, 1] – uvnitř bloku hodnota mince, v pásu kolem švu hladký přechod (smoothstep, bilineárně mezi středy bloků). Zvednutí vápence a vyklínění jílu se násobí c.
   - Hustota pramenů: parametry `bunkaPramenuM` a `pravdepodobnostBunky` (už existují), výchozí 32 m a 0,6 beze změny; test, že je hustota řídí.
5. **Testy:** jednotkové, ekvivalence (bod 3), determinismus ve 2 procesech, řez švem před a po opravě mince (obrázek), skok vrstev na švu (statistika před/po), artéské případy před/po nepropustné sopce, čas bloku C# proti GDScriptu (krok 3: segment 8 m a otisk 3 × 3; krok 4: blok s profily).
6. Report, DENIK, push. Most `GeologieGd` zůstane jen jako reference pro porovnání.

## Hypotézy
- H1: povrch a buňky budou bitově shodné (stejný FastNoiseLite, IEEE double/float, glibc libm). Riziko: pořadí sčítání, `float` u Vector2, cache `_zs` útvarů (klíč po 0,25 m – závislost na pořadí dotazů), rozdíl v parsování čísel.
- H2: C# bude ≥ 20× rychlejší než GDScript (segment 8 m 3,05 s v GDScriptu).
- H3: spojitá mince odstraní skok na švu bez změny podílu 50/50.

## Mimo rozsah
Eroze světa (krok 6), změna výchozí hustoty pramenů, četnost artéské vody (odloženo).

## Výsledky (2026-11-26 9:27 SEČ)

### Struktura (`cs/Willage.Gen`, bez Godotu)
- `Sum/`: `FastNoiseLite.cs` (MIT, 1.1.0 f7af54b, beze změny), `GodotSum.cs` (chování Godotu), `StableHash.cs`, `Gd.cs` (smoothstep, round… jako `math_funcs.h`).
- `Data/`: `DataSveta.cs` (cesty k `godot-prototyp/data`), `Csv.cs`.
- `Svet/`: `ParametrySveta`, `KlimaPresety`, `HashSveta`, `Sumy`, `MapaBiomu`, `Relief`, `Masiv`, `Sopky`, `MapaHornin`, `SvetFn`.
- `Geologie/`: `KatalogHornin`, `SumHornin`, `HostiteleUtvaru`, `Hranice`, `MinceE82`, `VrstvySloupce`, `NitroSopky`, `VNoise`, `Utvar`, `TvorbaUtvaru`, `Utvary`, `GeoVrstvy`, `GeologieCs : IGeologie`.
- Voda: přepínač `SopkaNepropustna` v `ParametryVody`; `ProfilSloupce`, `Prameny`, `Doplnovani`, `VykonPramene` berou masku nitra sopky.
- `cs/Willage.Gen.Nastroje` (příkazy `vyska det3 voda sevy rez sopka prameny cas`), `cs/Willage.Gen.Testy` (44/44). Godot: `VodaV1.nastav` používá `GeologieCs`, `nastav_gd` most. Nástroje GDScript: `tools/geo_cs_cas.gd`, `tools/geo_cs_godot.gd`; obrázek `tools/geo_cs_rez.py`.

### Ekvivalence (opravy vypnuté, `ParametrySveta.Puvodni()`, `SopkaNepropustna=false`) – H1 potvrzena
| Co | GDScript | C# |
|---|---|---|
| 3 600 bodů: povrch, tvar, biom, horniny; sopky, amplitudy | výpis `float64` | 0 rozdílů (bitově) |
| Otisk kroku 3 (3 × 3, 2 m / 1 m) | `bbdc0afa877d6c2e` | `bbdc0afa877d6c2e` |
| Segmenty 8 m po 0,25 m (1792,1792 / 1856,1920 / 2000,1800 / 2104,2104) | `99b4ca3f…` `0dc5e424…` `4391f413…` `059d807a…` | stejné |
| Voda bloku 14,14 (2 m, profily) | `f19006126c4b12a7` (krok 4, most) | `f19006126c4b12a7` |
| Hladina v Godotu: `nastav` proti `nastav_gd` | 25 bodů | 25/25 shodných |

### Časy (box, jedno vlákno, Release)
| Úloha | GDScript | C# | Poměr |
|---|---|---|---|
| Krok 3, 3 × 3 po 2 m / 1 m | 128 s (krok 3b) | 2,5–2,8 s | ≈ 49× |
| Segment 8 m po 0,25 m (4 místa) | 3,1 / 8,1 / 7,4 / 8,0 s | 0,30 / 0,33 / 0,19 / 0,08 s | 10–100× (první s JIT) |
| Blok 128 m po 0,25 m (134 M buněk) | odhad ~30 min | 18,5 s | – |
| Krok 4, blok 14,14 s profily | ~30 s (most) | 0,9–1,1 s (+0,2 s init) | ≈ 30× |

### Opravy (výchozí zapnuto)
- **Mince E82 spojitá** (`P82PrechodM` 32 m): šev x = 2048 (různé mince), 64 párů sloupců 0,25 m přes šev: různých buněk průměr 30,8 → 2,6 (max 69 → 24), skok stropu vápence 8,2 m → 0,24 m (max 84 → 0,5). Kontrola uvnitř bloku 3,8 buněk. Švy se stejnou mincí beze změny (rozdíly ±0,03 jen u rohů). `krok05/sevy_mince.csv`, obrázek `krok05/rez_sev_mince.png`. H3 potvrzena.
- **Nitro sopky nepropustné** (`SopkaNepropustna`): sopka 13,13 sevřených vrstev 29 044 (28 639 artéských) → 0, volná zvodeň 913 → 343 sloupců; sopka 10,13: 32 554 → 26. Výchoz v nitru sopky se nebere jako oblast doplňování.
- **Hustota pramenů** (jen parametry, výchozí 32 m / 0,6 beze změny), svět 3 × 3: 32/0,6 → 8; 32/1,0 → 17; 24/0,6 → 18; 16/0,6 → 20; 16/1,0 → 27 pramenů (rozestup 8 m).
- Determinismus dvou procesů s opravami: krok 3 `c8eeb7964d1ddd85`, voda 14,14 `add94931c6922f9c` (oba běhy shodné).

### Otevřené otázky pro Jana
1. Výchozí hustota pramenů: čtverec a pravděpodobnost (tabulka výše).
2. Šířka přechodu mince 32 m: stačí, nebo širší (64 m) kvůli pozvolnějšímu sklonu vrstev?
3. Cache výšky středu útvaru `_zs` (klíč 0,25 m) je převzatá kvůli bitové shodě; teoreticky závisí na pořadí dotazů (3 × 3: 0 kolizí). Navrhuji ji později nahradit přesným klíčem (změní otisk jen při kolizi).
4. Krok 3 na 0,25 m: 18,5 s na blok na jednom vlákně. Paralelizace po sloupcích (instance na vlákno) až podle potřeby?

## Rozhodnutí Jana 2026-11-26 9:32 ([pt922u]) a zapracování (9:36 SEČ)
1. **Hustota pramenů:** výchozí čtverec **24 m**, pravděpodobnost 0,6 (`voda_v1.json` i `ParametryVody`). Svět 3 × 3: **18 pramenů** (122 /km², 16 vývěrů, 2 krasové) místo 8.
2. **Přechod mince E82:** zůstává 32 m.
3. **Keš výšky středu útvaru: přesný klíč** (`TvorbaUtvaru`, `ParametrySveta.UtvaryKlicGd = false`; GDScript klíč round(4·c) jen v `Puvodni()` pro porovnání). Výška okolí sopky se počítá jednou při stavbě světa, keš podle klíče nemá. Masiv si šumy z keše geo2 drží přímo, dotaz už do keše nesahá. **Otisky se nezměnily**, protože ve světě nejsou kolize: krok 3 bez oprav `bbdc0afa877d6c2e` (klíč GDScript i přesný), s opravami `c8eeb7964d1ddd85` (oba klíče), segment 2104,2104 `059d807ab04b7f00` (přesný klíč = GDScript). Test: opačné pořadí dotazů dá stejné bajty.
4. **Paralelní výpočet 0,25 m** (`ParalelniSloupce`, instance `GeologieCs.Klon()` na vlákno, sdílená `SvetFn`, sloupec na pevném místě): blok 14,14 po 0,25 m (134 217 728 buněk), otisk **`ce6d906313af513f`** na 1, 2, 4 a 8 vláknech:

| Vláken | 1 | 2 | 4 | 8 |
|---|---|---|---|---|
| Čas bloku 128 m | 18,9 s | 9,3 s | 4,7 s | 2,6–3,7 s |

Bez oprav (`Puvodni()`): 1 vlákno = 8 vláken = `ddc93f9662db4fb8` (19,2 s / 3,4 s).

**Otisky po změnách** (2 procesy, oba shodné): krok 3 `c8eeb7964d1ddd85` (beze změny), voda 14,14 **`7714d1a1d34e00ad`** (dříve `add94931c6922f9c`, změna jen hustotou pramenů 24 m; 2 prameny v bloku), blok 0,25 m `ce6d906313af513f`.
**Testy:** C# 49/49; Godot .NET build 0 chyb; `tools/geo_cs_godot.gd` hladina C# = most 25/25, prameny bloku 13,13: 2.
