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
