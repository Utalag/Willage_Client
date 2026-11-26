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
*(doplní se po implementaci)*
