# G-7 – náhledy a izolace M4 eroze, M5 klima (tabulka pásem), M6 voda a průsak (řez s hladinou) (PROP)

Větev `gen-v1-g7-nahledy-m4m6` (z `gen-v1-g6-nahledy` 86bec57). Plán 05, tabulka 3.3 a G-7. Nahrazuje zástupné prvky G-6 pro M4–M6
(náhled planety z G-5, „Izolovat vrstvu (zástupné)“, řez „s hladinou … (G-7, 7d)“).
**7d (zvodnělá zóna šířením průsaku + strop hladiny u pobřeží 60 m) je dál odložené (Jan)**: v náhledu i v řezu zůstává jasně označená
zástupná vrstva bez logiky. Mutaci M7 → M3 a vzduch v `MaterialPovrchu` (nálezy G-6) neopravuji – jen dál vedu v seznamu.

## Cíl
1. Fasáda `INahledyModulu` rozšířená o M4–M6 (bez Godotu), každá skupina ve vlastní třídě (žádný monolit):
   - **M4 eroze** (mapa planety 32 m, torus 31 360 × 15 616 m): výška planety po erozi, **posun eroze** H0 − H (izolace „mapa posunu eroze“),
     toky (log₁₀ plochy povodí), jezera, koryta; body = vodníci kroku 6 (bez klimatu); řez = profil před / po erozi.
   - **M5 klima**: teplota, srážky, odtok w, biom klimatu, koryta aktivní / suchá (hydrologie klimatu); body = oázy a vodníci s klimatem;
     izolace „jen klima (bez vlivu na vodu)“ = biom klimatu bez překryvu oáz; **tabulka pásem** (pásma ze `Zemepis` + změřené T, P, podíl biomů
     po pásmech); řez = profil povrchu s řadami teplota, srážky, w.
   - **M6 voda**: hloubka hladiny pod povrchem (surová hladina 7c, NaN = bez hladiny), absolutní hladina, dobití 7c, zóna vývěru, pobřežní pás
     (hladina = hladina moře), **7d zvodnělá zóna – zástupná** (NaN, příznak `zastupny`); body = prameny ze seedu a vodníci; izolace
     „jen hladina“ (bez bodů) / „jen prameny“ (body na šedém povrchu); **řez s hladinou** = materiály po 0,25 m (erodovaná geologie jako nástroj
     `eroze rez`) + povrch + surová hladina + hladina moře + prameny do 150 m od úsečky.
   - Oblast: M4/M5 celá planeta (uzly mapy, nejbližší uzel), M6 výchozí start 3 × 3 bloky (1792…2176 m, kde reporty počítají prameny).
2. Jádro Godot: stejné metody `NahledModulu` / `RezModulu`, navíc `TabulkaPasem`.
3. Okno: `NahledModulu` M4–M6 vlastní vrstvy + nový uzel `BodyNahledu` (překryv bodů), `TabulkaPasem` (Tree, jen M5),
   `PohledRezu` M4–M6 (profil, řady, hladina, prameny), zástupný štítek 7d; `KonfiguratorModulu` izolace M4 / M5 (zap/vyp), M6 (cyklus).
4. Willage.Gen (jádro světa) beze změny.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| M4 shoda | hodnoty mapy = pole `MapaEroze` v uzlech bitově; otisk mapy `800d420bb00047de`; vodníků bez klimatu 92 |
| M5 shoda s nástrojem / reporty 7–7b | podíly biomů pevniny, w průměr, T min/max, koryta aktivní / suchá = výpis `klima mapa` (report 7b: mírný les 91,0 %, tajga 5,4 %, step 3,6 %, w 0,83, aktivní koryta 73–79 %); oázy 0 na mírné planetě |
| M6 shoda s nástrojem / report 7c | dobití pevniny bez / částečně / plně = `klima mapa` (7c: 0,3 / 16,9 / 82,8 %); prameny start 3 × 3 = 21; řez M6 = `eroze rez` (materiály bajt po bajtu, povrch, hladina) |
| izolace | M4 posun = H0 − H; M5 biom bez oáz liší se jen v uzlech oáz; M6 jen hladina = hodnoty hladiny bez bodů, jen prameny = body beze změny |
| 7d | vrstva i řez zástupné (NaN, `zastupny` = 1), žádná logika 7d |
| determinismus | 1 = 8 vláken; dva náhledy stejné; otisky beze změny |
| okno (headless + Xvfb) | M4–M6 vrstvy, body, izolace, tabulka pásem, řez s hladinou, materiál pod kurzorem; snímky |
| čas | náhled < 1 s (M6 hladina měřím – drahá funkce, případně menší rozlišení) |
| otisky | beze změny; čas celé planety 8,2 s jen zaznamenat |

## Rizika
- Hladina 7c (`RegionalniHladina.Surova`) je drahá (≈ 113 uzlů na vzorek); M6 náhled proto na menší oblasti / rozlišení.
- Nástroj `eroze rez` staví svět s planetárním `SvetMaxM`, okno s výchozím – shoda jen ve startovním světě (ověřím).
- M6 řez z erodované geologie (výstup M7) – to je správně pro vodu, ale je to stejný objekt, který mutace M7 → M3 mění (nález G-6).

## Výsledky
**Shrnutí:** fasáda + okno ukazují M4–M6 vlastními vrstvami, body, izolací a řezem; čísla = nástroje / reporty 6–7c; 7d zůstává zástupné;
Willage.Gen beze změny; otisky beze změny.

| Ověření | Výsledek |
|---|---|
| dotnet celá sada | **OK 524, chyb 0** (2 min 30 s); z toho G7 **42/0** (G6 upraven: vlastní náhled M1–M3 → M1–M6, řez M7 = ArgumentException) |
| `klima otisky` | zap: 86 vodníků, krok 3 `9f32311e046f8b6a`, voda `377a8210f82c856a`, klima `cb11da8d141a2a5e`; vyp: 92 vodníků, voda `8e239a68c6d01be0`; mapa `800d420bb00047de`; segment `059d807ab04b7f00` (testy krok 5 / G-1) – **beze změny** |
| `nahled porovnej-rez-vody` (M6 řez proti `eroze rez`) | start (2000,1984)+96 m i pobřeží (868,1984)+128 m: **0 rozdílných buněk materiálu, 0 povrchů, 0 hladin**; řady M4/M5 proti CSV 0/384 a 0/512; shoda platí i přes planetární `SvetMaxM` nástroje |
| Godot headless | NahledyM4M6Test **21/0**, NahledyTest (G-6) **17/0**, GeneratorSvetaTest (G-5) **22/0** (M4 teď vlastní náhled), JadroTest **12/0**, okno jako hlavní scéna i hra `--quit-after` bez chyb |
| Godot Xvfb (OpenGL 4.5, llvmpipe) | NahledyM4M6Test **21/0**, 8 snímků `obrazky/g7/` |

**Čísla (mírná planeta seed 49, = `klima mapa` / reporty):**
- M4: podíl moře 0,366, eroze průměr 0,741 m, max 20 m (= MaxEroseM), koryt 9 691 uzlů, „jezer“ 46 375 uzlů, vodníků bez klimatu 92; mapa 256 × 127 po 122,5 m.
- M5: mírný les 91,0 %, tajga 5,4 %, step 3,6 %, deštný 0,1 %; w 0,83; T 2,9…18,0 °C; koryta aktivní 75,9 %, suchá 22,9 %; vodníků 86, oáz 0.
- M6: dobití pevniny bez / částečně / plně 0,3 / 16,9 / 82,8 %; prameny start 3 × 3 = 21; řez start 12 pramenů do 150 m, pobřeží 30.
- Pouštní planeta (TestyG7): 71 oáz, `BiomBezOaz` se liší jen v uzlech oáz; bez hladiny 71,9 %.

**Tabulka pásem (M5):**

| Pásmo | Podíl | Pevnina | T °C | P mm | w | Hlavní biom |
|---|---|---|---|---|---|---|
| subtropy | 0,15 | 52,7 % | 16,1 | 607 | 0,32 | mírný les 78 % |
| mírné | 0,6 | 60,7 % | 10,4 | 744 | 0,88 | mírný les 98 % |
| chladné | 0,25 | 76,5 % | 6,0 | 677 | 0,96 | mírný les 82 % |

**Časy:** mapy M4/M5 20–45 ms, řezy M4/M5 1–6 ms; M6 mapa 128² start 0,7–1,0 s, řez start 0,33–0,58 s;
M6 pobřeží: mapa 256 m po 2 m 2,4–2,8 s, řez 128 m 2,0–3,4 s (negativní, viz níže). Studená celá planeta 8,2 s – jen zaznamenáno, neladěno.

**Negativní nálezy / odchylky:**
1. **Souběh v katalogu materiálů:** paralelní `PodzemniVodaFn` padala (`KatalogMaterialu.NeznamaId` – `Najdi` pod zámkem, `PobrezniPas.Remove` bez něj).
   Řešení jen ve fasádě: vlastní `Geologie.Klon()` + `KatalogMaterialu` na vlákno; jádro neopraveno (kandidát na samostatný krok).
2. `Prameny.VOblasti` je jednovláknové (start 3 × 3 ≈ 1,4 s); fasáda počítá po buňkách paralelně se stejným řazením → ≈ 0,65 s, výsledek shodný.
3. **Pobřeží je pomalé** (2–3,4 s řez, 2,4–2,8 s mapa) – drahá hladina 7c u moře; neladil jsem.
4. Mapa M4 má 127 řádků, ne 128 (15 616 / 122,5 zaokrouhleno dolů); test upraven.
5. Na mírné planetě je 0 oáz → izolace M5 „jen klima“ je tam totožná s biomem klimatu (rozdíl ověřen jen na pouštní planetě).
6. Příznak „jezero“ v M4 zabírá 46 375 uzlů – zřejmě zahrnuje i moře; vrstvu nechávám jako příznak MapaEroze, nevykládám.
7. Posun eroze vypadal skoro bíle (průměr 0,74 m, max 20 m) → odmocninová škála; hladina v moři vypadala jako vývěr → moře / voda nad povrchem tmavě modrá (< −0,25 m), vývěr tyrkys (−0,25…0).
8. Úsečka mimo oblast M6 se kreslila mimo mapu → `clip_contents` + `NastavOblast` pro pohled u pobřeží.

**Dál v seznamu (neopraveno, dle zadání):** mutace M7 → M3 (erodovaná geologie), `MaterialPovrchu` vrací vzduch.
**Zástupné:** 7d zvodnělá zóna (šíření průsaku) + strop hladiny 60 m u pobřeží (Jan odložil) – vrstva `ZvodnelaZona7d` = NaN + šrafy, řez se štítkem;
uložení sady, U-1 regionální úpravy, U-2 částečný přepočet, editace v tabulce pásem, vlastní náhled M7–M9.

**Snímky** (`docs/sjednoceni/obrazky/g7/`): 01 M4 izolace posun eroze, 02 M4 toky + vodníci, 03 M5 biomy + tabulka pásem, 04 M5 koryta,
05 M6 hladina + prameny, 06 M6 jen prameny, 07 M6 řez přes pobřeží s hladinou, 08 M6 7d zástupná.
