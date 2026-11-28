# PROP GEO2 V8: porovnání GEO1 × GEO2 na ≥ 3 seedech × 11 bloků (Jan t1057u)

*Zapsáno před experimentem 2026-11-28 14:57 (Europe/Prague). Větev `geo2-v8-seedy` = `geo2-vychozi` (včetně sloučeného kontaktu rychle) + `geo2-skarnjine` (nástroj V8, oprava sopky zPovKuz, příčina `SkarnHostitelOkoli`). Měření běží na Janově Windows PC (nezatížený stroj); hardware se liší od boxu.*

## Kritérium
Jan t1046u / kontrakt 7.3: smazání staré cesty GEO1 vyžaduje **0 otevřených buněk** (rozdíl bez vysvětlené příčiny) na pevné sadě **11 bloků** pro nejméně **3 seedy světa**. Každá nová příčina musí být vysvětlená a zařazená (zlepšení / dle kontraktu / tolerance).

Na seedu 49 (box, 1,476 mld. buněk) bylo po zařazení `SkarnHostitelOkoli` 0 otevřených. Toto měření ověří totéž na dalších seedech a zároveň pořídí čistší časy GEO1 / GEO2 (PC bez cizí zátěže).

## Seedy a bloky
Výchozí seed světa je **49** (`ParametrySveta.Seed`). Další dva: **7** a **100** (žádný speciální význam, jen jiné než 49). Celkem 3 × 11 bloků.

Stejná sada jako V8 (`TestyGeo2V8.Kategorie`):
- 5 náhodných: (1024, 512), (3000, 2000), (0, 0), (2048, 1024), (512, 3072)
- 2 švy mince: (1856, 1024) u x = 1920, (1984, 2560) u x = 2048
- 2 hornatina / strmé: (1664, 1728), (3904, 1344)
- svah a okraj první sopky světa — souřadnice se **počítají ze seedu** (stejný vzorec jako dřív: `Floor(X + 0,4 R − 64)` a `Floor(X + R − 96)`), protože sopka se se seedem posune. V CSV a logu budou skutečné (x, y).

Blok 128 m, sloupce po 0,25 m, z po 0,25 m (512 buněk na sloupec).

## Postup
1. Na boxu: větev, rozšíření `--jen=GEO2V8 --seedy=49,7,100` (čas GEO1 a GEO2 zvlášť na blok, CSV po seedu). Čas GEO1 = stěnový čas paralelního `VyplnSloupec`; čas GEO2 sloupce = maximum času vlákna jen na `Sloupec` (bez klasifikace V8); kontext = `KontextBlokuE84.Sestav`. CSV: `rozdily-seed-{seed}.csv` a `casy.csv`.
2. Na Janově PC (Windows 11): clone veřejného `https://github.com/Utalag/Willage_Client` do `C:\dev\Willage_Client` **bez tokenu**, checkout `geo2-v8-seedy`, `dotnet build` Release, `--jen=GEO2` (kontrola, že testy na Windows projdou), potom V8 na 3 seedech. Výstup do `docs/sjednoceni/reporty/geo2-v8-seedy-data/`.
3. Výsledky zkopírovat na box (`CopyToBox`), zapsat sem včetně negativních, commit a push z boxu. Nic do main. Na Janově PC se nemění nic mimo `C:\dev\Willage_Client`.

## Co se zapíše
- Po seedu a kategorii: počet buněk, různých, verdikty (zlepšení / dle kontraktu / tolerance / **otevřené**), příčiny.
- Seznam otevřených buněk (souřadnice), pokud nějaké budou.
- Čas na blok: kontext GEO2, sloupce GEO1, sloupce GEO2 (stěnový čas,  paralelně; PC je nezatížený, ale čísla nelze přímo srovnávat s boxem — jiné CPU).
- Nové příčiny, pokud se objeví, a zda jsou vysvětlené.

## Kritérium úspěchu
- 0 otevřených buněk na všech 3 seedech × 11 blocích, nebo každá nová otevřená buňka má vysvětlení (a čeká na zařazení / rozhodnutí Jana).
- `--jen=GEO2` na Windows projde.
- Token se na PC nepoužije a neuloží.

---

# VÝSLEDKY (zapsáno 2026-11-28, Europe/Prague)

Data: `geo2-v8-seedy-data/` [1]–[9]. Měřeno na Janově PC „Utalag“ (Windows, **24 vláken**, bez cizí zátěže; **jiný hardware než box**, časy se s časy z boxu nesrovnávají). Větev `geo2-v8-seedy` (základ 39d80d7), clone veřejného repa bez tokenu. `--jen=GEO2`: **OK 228, chyb 0** [6].

## 1. Otevřené buňky a rozdíly na seed
Pevná sada 11 bloků × 128 m × 0,25 m = 1 476 395 008 buněk na seed.

| seed | různých buněk | rozdíl | zlepšení | dle kontraktu | tolerance | **otevřené** |
|---|---|---|---|---|---|---|
| 49 | 8 966 595 | 0,607 % | 2 689 | 8 800 150 | 163 756 | **0** |
| 7 | 8 033 760 | 0,544 % | 26 578 | 7 707 387 | 299 795 | **0** |
| 100 | 7 342 184 | 0,497 % | 5 456 | 7 151 153 | 185 575 | **0** |

Seed 49 se shoduje s dřívějším měřením na boxu (0,607 %, 2 689 zlepšení) [1][7]. **Kritérium Jan t1046u / kontrakt 7.3 (0 otevřených na ≥ 3 seedech × 11 blocích) je splněno.**

## 2. Příčiny rozdílů (podíl z různých buněk)
| příčina (verdikt) | seed 49 | seed 7 | seed 100 |
|---|---|---|---|
| SkarnJenKarbonaty (dle kontraktu) | 97,68 % | 94,30 % | 94,05 % |
| SkarnHraniceOdhad (tolerance) | 1,67 % | 2,24 % | 2,06 % |
| HostitelSkarn (dle kontraktu) | 0,41 % | 1,54 % | 3,26 % |
| SkarnVPasmuTolerance (tolerance) | 0,15 % | 1,49 % | 0,46 % |
| SkarnDiraGeo1 (zlepšení) | 0,017 % | 0,30 % | 0,055 % |
| PravidloZdroje (dle kontraktu) | 0,032 % | 0,065 % | 0,053 % |
| CockaObalka (zlepšení) | 0,013 % | 0,030 % | 0,020 % |
| PoradiTeles (dle kontraktu) | 0,021 % | 0,030 % | 0,029 % |
| SkarnHostitelOkoli (dle kontraktu) | 2 buňky | 578 buněk | 18 buněk |

Nová příčina se na seedech 7 a 100 neobjevila, všech 9 příčin je z kontraktu / V8 už vysvětleno. Hlavní kategorie: skarn jen v karbonátech (GEO1 ho dávalo i do nekarbonátů, v GEO1 porušení O1 93 % / 73 % / 71 % skarnových buněk, v GEO2 0 %).

## 3. Časy na Janově PC (GEO1 × GEO2 sloupce)
GEO1 = stěnový čas paralelního `VyplnSloupec`; GEO2 = **maximum času vlákna** jen na `Sloupec` (bez klasifikace V8); kontext GEO2 (`KontextBlokuE84.Sestav`) 0,9–1,8 s navíc a není v GEO2 sloupcích. Všech 33 řádků: `casy-vsechny-seedy.csv` [8].

| seed | GEO1 součet / medián | GEO2 součet / medián | poměr GEO2/GEO1 min – medián – max | bloků nad ×1,5 |
|---|---|---|---|---|
| 49 | 31,2 s / 2,82 s | 25,1 s / 1,59 s | 0,42 – 0,65 – 1,79 | 1 (blok 1984, 2560, 5,65 s) |
| 7 | 37,9 s / 3,54 s | 91,2 s / 3,40 s | 0,36 – 1,29 – 6,66 | 5 |
| 100 | 28,3 s / 2,49 s | 33,2 s / 1,81 s | 0,35 – 0,76 – 4,06 | 2 |
| vše | GEO1 2,17–3,84 s na blok | GEO2 1,06–23,57 s na blok | 0,35 – 0,76 – 6,66 | 8 z 33 |

- GEO1 je stabilní (2,2–3,8 s). V **typickém** bloku je GEO2 rychlejší: 19 z 33 bloků je GEO2 ≤ GEO1, 25 z 33 do doporučeného ×1,5 (t1047u; jen doporučení).
- **Doporučení ×1,5 se však nesplňuje v 8 z 33 blocích** a v nejhorších případech je GEO2 až 6,7× pomalejší.
- Bloky nad 4 s (GEO2): seed 49 (1984, 2560) 5,65 s; seed 7 (3000, 2000) 8,22, (2048, 1024) 17,83, (1856, 1024) 18,27, (1664, 1728) 23,57, (3904, 1344) 9,80; seed 100 (3904, 1344) 11,72, (2280, 1909) 4,57.
- Poznámka k metrice: „max vlákno“ je citlivé na jedno těžké vlákno; celkový CPU čas jsme neměřili.

## 4. Anomálie: pomalé horské bloky seedu 7 — verdikt
Otázka: jde o skutečné zpomalení (geologie seedu), nebo šum?

Důkazy:
1. **Přeměření samotného bloku** (1664, 1728) seed 7, dva běhy po sobě na nezatíženém PC [9]: GEO2 **14,87 s** a **18,68 s** (GEO1 3,34 / 3,59 s); původně 23,57 s. Rozdílů 51 412 stejně ve všech třech během, otevřených 0.
2. Týž blok (1664, 1728) v seedu 49: 3,12 s (3,25 s v prvním běhu [5]); v seedu 100: 1,10 s. Blok je tedy pomalý jen se seedem 7.
3. Seed 49 jsme měřili dvakrát (běh 1 [5], běh 2 [1]): pomalý blok (1984, 2560) vyšel **6,27 s** a **5,65 s**, ostatní bloky 1,0–3,4 s v obou během. Pomalost je reprodukovatelná na stejném (seed, blok).
4. Seed 100: čtyři bloky z přerušeného běhu a z opakování se liší o 10–45 % (např. (2048, 1024) 3,64 vs 2,51 s), řád se ale drží.

**Verdikt: zpomalení je skutečné a závisí na seedu a bloku (geologie), ne na šumu měření.** Šum je asi ±10–30 % (14,9 / 18,7 / 23,6 s na témže bloku), ale ne řádový. Seed 7 byl navíc měřen krátce po restartu PC, což mohlo část času přidat, ale přeměření v klidu zůstalo 4–5× nad GEO1. Příčina uvnitř GEO2 není určena (profil z dřívějška: `VrstvySloupce.Hranice`, ~32 µs a 21 kB na volání, 2,4–3,4× na sloupec v horských blocích). Nevíme, zda jde o pár patologických sloupců, nebo o celý blok; to by ukázalo měření času na sloupec.

Dopad na smazání GEO1: podmínka správnosti je splněna (0 otevřených). Výkonové kritérium ×1,5 je jen doporučení, ale zjištěné špičky (až ~19 s na blok) jsou pro načítání bloků za běhu hry (generace po blocích na požádání) praktický problém a je potřeba je před smazáním GEO1 vyřešit nebo vědomě přijmout (rozhoduje Jan).

## 5. Negativní výsledky
- **Pád na prázdné cestě `--csv` (Windows).** První běh (seedy 49,7,100) spadl na `System.ArgumentException: The path is empty` v `TestyGeo2V8.Spust`; log [5], `hotovo.txt` [3] (výstup -532462766 = neošetřená .NET výjimka). Opraveno `Path.GetFullPath` (commit 39d80d7); generátoru se to netýká, šlo jen o testovací nástroj. Měření ale kvůli tomu bylo nutné opakovat.
- **Běh ztracený restartem PC.** Společný běh pro seedy 7 a 100 byl přerušen restartem PC: log [2] (`v8-seedy.log`) má kompletní seedy 49 a 7 a u seedu 100 jen 4 bloky z 11. Seed 100 se spustil znovu samostatně (`v8-seedy-seed100.log` [4], `hotovo-seed100.txt`, exit 0) a je kompletní. Čísla seedu 100 v tomto PROP jsou z opakování [4].
- `casy.csv` [8] zůstal po posledním běhu jen se seedem 100 (zápis po seedu přepisuje); kompletní časy proto vznikly z logů do `casy-vsechny-seedy.csv`. Chyba nástroje: zapisovat časy po seedu do samostatného souboru.
- `CopyToBox` z PC nešel (cesta mimo povolený kořen), data se přenesla přes výstup příkazu. Surové logy přeměření [9] zůstaly na PC; do repa je krátké shrnutí.
- Kontext (`KontextBlokuE84.Sestav`) a klasifikace V8 nejsou v čase „GEO2 sloupce“; srovnání s GEO1 je tedy mírně příznivé pro GEO2 (o 0,9–1,8 s kontextu navíc).

## 6. Zdroje a data
Soubory v `geo2-v8-seedy-data/`, citované v textu:
- [1] `v8-seedy.log` — seedy 49 a 7 kompletní, seed 100 přerušen restartem po 4 blocích
- [2] `rozdily-seed-49.csv`, `rozdily-seed-7.csv`, `rozdily-seed-100.csv` — kategorie × zdroj × příčina × verdikt × počet buněk
- [3] `hotovo.txt`, `hotovo-seed100.txt` — exit kódy a časy konců
- [4] `v8-seedy-seed100.log` — seed 100, opakování, kompletní
- [5] `v8-seedy-seed49-prvni-beh.log` — první běh, pád na prázdné `--csv` (seed 49 kompletní před pádem)
- [6] `geo2-testy.log` — `--jen=GEO2`, OK 228, chyb 0
- [7] `docs/sjednoceni/reporty/geo2-v8-prop.md` — dřívější V8 na boxu (seed 49)
- [8] `casy.csv` (po posledním běhu jen seed 100) a `casy-vsechny-seedy.csv` (33 řádků z logů)
- [9] `remeras/README.md` — přeměření bloku (1664, 1728) seed 7 (dva běhy)

## 7. Další kroky
1. Jan rozhodne, zda výkonové špičky GEO2 (až ~19 s na blok seedu 7) jsou před smazáním GEO1 překážka; ×1,5 je jen doporučení.
2. Změřit čas na sloupec v blocích (1664, 1728) seed 7 a (3904, 1344) seed 100: jsou pomalé jen některé sloupce? Cíl: `VrstvySloupce.Hranice` (opakovaná volání) – bitově shodné zrychlení U1/U2 (odloženo).
3. Zbývající podmínky smazání GEO1: přesun vody a M3 na uložené běhy, nahrazení otisků GEO1 otisky GEO2, ostatní z 8 kritérií V8.
4. Opravit zápis `casy.csv` po seedu; měřit i celkový CPU čas vedle „max vlákno“.
5. Nic nejde do main bez Janova schválení; sloučení přes Willage-backend.
