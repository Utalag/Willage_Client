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
1. Na boxu: větev, rozšíření `--jen=GEO2V8 --seedy=49,7,100` (čas GEO1 a GEO2 zvlášť na blok, CSV po seedu).
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
