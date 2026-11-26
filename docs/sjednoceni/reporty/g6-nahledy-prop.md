# G-6 – náhledy a izolace M1 funkce světa, M2 moře, M3 geologie (řez) (PROP)

Větev `gen-v1-g6-nahledy` (z `gen-v1-g5-okno` 05af75a). Plán 05, tabulka 3.3 a G-6. Nahrazuje zástupné prvky G-5, které patří do G-6:
vlastní náhled modulu (M1–M3), PohledRezu (řez úsečkou), Izolovat vrstvu (M1–M3). Pro M4–M6 zůstávají zástupné (G-7).

## Cíl
1. **Fasáda bez Godotu** `INahledyModulu` (`GeneratorSveta.Nahledy`) nad výstupy modulů posledního běhu (M1 `VystupFunkceSveta`, M2 `SvetFn`, M3 `GeologieCs`):
   - `Mapa(modul, vrstva, izolace, rozliseni)` → `NahledMapyDto` na oblasti funkce světa 0…SvetMaxM (dnes 4096 m – startovní svět kroků 2–5;
     M4+ mají mapu planety) s čísly (min, max, podíl moře, počet sopek …);
   - vrstvy podle tabulky 3.3: **M1** výška, biomy, horniny (dominantní), sopky, masiv; **M2** maska pevniny, moře, výška, pánve, šev torusu;
     **M3** materiál povrchu, mince E82;
   - **izolace** (jako GeoLab): M1 „jen reliéf bez moře“ (NeutralM + Σ w·reliéf, bez masivu a sopek), M2 „rozdíl výšky proti M1“,
     M3 řez „jen vrstvy“ / „jen útvary“ (+ nitro sopek);
   - `Rez(modul, od, do (Q16), krokM, rezim)` → `RezModuluDto`: M1/M2 profil povrchu (M2 i s profilem M1 a hladinou), M3 svislý řez materiálů po 0,25 m
     (jako nástroj `rez`), `Materialy()` = id, název, barva z `materialy_v1.csv` (materiál pod kurzorem);
   - barvy `Vizual/BarvyNahledu` (RGBA bez Godotu).
2. Jádro: `NahledModulu`, `RezModulu`, `Materialy` přes frontu; signály `NahledModuluHotov`, `RezModuluHotov`.
3. Okno: `NahledModulu` ukazuje vrstvy modulu (M1–M3 vlastní, M4+ planeta jako v G-5), dvěma kliky na náhled se zadá úsečka řezu;
   `PohledRezu` (skutečný uzel místo zástupného): profil (M1/M2) nebo obraz řezu (M3), materiál pod kurzorem; `KonfiguratorModulu` – „Izolovat“ pro M1–M3.
4. Jádro Willage.Gen: `GeoVrstvy.VyplnSloupecRezim` (jen vrstvy / jen útvary) – nová metoda, stávající `VyplnSloupec` beze změny.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| shoda s jádrem (dotnet) | hodnoty náhledu bitově = přímé volání `SvetFn` / `GeologieCs` ve stejných bodech (jako `PorovnejVysku`) |
| shoda s nástrojem | řez M3 v x 2048 ± 48, y 1984 = výstup `Willage.Gen.Nastroje rez` (`rez_opravy.bin`) bajt po bajtu (nový příkaz `nahled porovnej-rez`) |
| izolace | jen vrstvy ∪ jen útvary pokryjí řez: kde se „vše“ liší od „jen vrstvy“, „jen útvary“ = „vše“ |
| determinismus | dva náhledy stejné; náhled nezmění otisky |
| okno (Godot headless + Xvfb) | M1/M2/M3 vrstvy, izolace, úsečka kliknutím, řez 384 × 512 buněk, materiál pod kurzorem; textura = BarvyNahledu |
| čas | náhled 256 × 256 a řez < 1 s na boxu (měřím) |
| otisky | beze změny 9d4f2b8; čas celé planety 8,2 s se studenou keší jen zaznamenat (Jan: neladit) |

## Rizika
- M1–M3 pokrývají jen startovní svět 4096 m (dnešní funkce světa); planeta 31360 × 15616 m má jen mapu eroze (M4). Řeknu v okně i v reportu.
- Výpočet náhledu na vlákně fronty blokuje další úlohy (~stovky ms); paralelizace až když bude potřeba.

## Výsledky
Commity: 74b514a `VyplnSloupecRezim`, a2a4f8e fasáda `INahledyModulu` + `BarvyNahledu`, 68cbdb8 `TestyG6` (`--jen=G6`), 97a0950 nástroj `nahled`,
a894cab jádro, adcb6d9 okno, 64524b4 `NahledyTest`.

| Test | Výsledek |
|---|---|
| dotnet celá sada | **OK 482, chyb 0** (2 min 25 s); z toho G6 30/0 |
| shoda s nástrojem | `rez` → `nahled porovnej-rez rez_opravy.bin`: **0 rozdílných buněk, 0 rozdílných povrchů** |
| shoda s jádrem | mapy M1/M2/M3 bitově = přímé `SvetFn` / `GeologieCs` (TestyG6) |
| izolace M3 | „vše“ 131 359 nevzduchových buněk, „jen útvary“ 1 045; kde se vše liší od jen vrstev, jen útvary = vše; `VyplnSloupecRezim(Vse)` = `VyplnSloupec` bajtově |
| determinismus | 1 vlákno = 8 vláken; dva náhledy stejné |
| Godot headless | NahledyTest **17/0**, GeneratorSvetaTest (G-5) **22/0**, JadroTest **12/0**, okno jako hlavní scéna i hra `--quit-after` bez chyb |
| Godot Xvfb | NahledyTest **17/0**, 8 snímků `obrazky/g6/` |
| úsečka kliknutím | pixely 10 → 100 v řádku 64 → (320, 2048) → (3200, 2048) m, 512 vzorků po 5,625 m |
| otisky | mapa 800d420bb00047de; klima zap 86 vodníků, krok 3 9f32311e046f8b6a, voda 377a8210f82c856a, klima cb11da8d141a2a5e; vyp 92, voda 8e239a68c6d01be0; segment 059d807ab04b7f00 – **beze změny** |

Časy (box, Godot přes frontu): M1 výška 256² 220 ms, M1 horniny 256² 423 ms, M3 materiál povrchu 128² 938 ms, řez M3 384 × 512 29 ms, profil M1 1 ms;
dotnet M1 biom 256² 77 ms. Mapy se počítají po řádcích paralelně (`Parallel.For`, klon geologie na vlákno), výsledek nezávisí na počtu vláken.
Celá planeta se studenou keší **8,2 s** (z G-5) – jen zaznamenáno, neladěno (Jan).

Otisky vrstev 256² (`nahled otisky`): M1 Vyska 324c24f603b62066, Biom 7f59b7b4bf7f54dc, Horniny 2eab30ce998fb1ab, Sopky 2a6651ec87fb61b8,
Masiv 3a6ef94b03321ec8, Relief a1ae0bc30597352b; M2 Pevnina 59faba0467c220b9, More c6da7dbaf1553ca9, Vyska c83aa8fc40da998e, Panve 8a39d2abd3999ab7,
Sev 3d4d629940c1d698, RozdilM2M1 a3db1bac106051ec; M3 MaterialPovrchu 5eb5983a2c26a666, Mince 62b736b1942d6fb8.

### Negativní nálezy
1. **Výstup M3 v paměti není geologie M3**: M7 ho mutuje (`g.Svet.Eroze = e.Eroze`), první verze náhledu se proto lišila od nástroje (27/50 buněk mapy,
   1 169 buněk řezu). Oprava: náhled M3 si staví vlastní `GeologieCs` bez eroze (keš podle klíče M3). Mutaci v jádře jsem neměnil – kandidát na úklid.
2. `GeologieCs.MaterialPovrchu` vrací 0 (vzduch), když povrch leží v dolní polovině buňky (vzorek z = floor·C + 0,125 > povrch). Stávající chování jádra,
   v náhledu je vidět jako tmavé tečky; nahlášeno, neměněno.
3. M2 vrstva **Pánve je ve startovním světě 4096 m celá 0** (pánve leží jinde na planetě) – náhled je správně, ale prázdný.
4. Podíl moře v náhledu 0,594 proti cíli masky 0,374 – cíl platí pro celou planetu, výřez 4096 m ho nesplňuje (není chyba, jen pozor při čtení čísel).
5. M3 materiál povrchu 256² trvá ~1,7 s (> cíl 1 s), okno proto používá 128² (0,4–1 s).
6. M1–M3 pokrývají jen 0…4096 m; řez/náhled mimo startovní svět není (riziko z PROP potvrzeno).

### Zbývá (zástupné, G-7)
Náhledy a izolace M4–M6 (eroze, klima, voda, řez s hladinou a zvodnělou zónou 7d) – v okně zůstávají označené „zástupný“.
