# PROP – G-2: schéma parametrů modulů M0–M7

Větev `gen-v1-g2-schema` (z `gen-v1-g1-moduly` 8538de0; G-1 schválil Jan 17:24 a merge předal Willage-backendu, main je zatím `9d4f2b8`). Podle [`05-plan-generator-editory.md`](../05-plan-generator-editory.md), fáze 1, krok G-2. Napsáno 2026-11-26 17:35 SEČ, před implementací.

## Cíl
Jedno schéma všech laditelných parametrů generátoru, ze kterého G-5 vygeneruje konfigurátory modulů:
- položka = id, modul (vlastník), zdroj (třída nebo soubor), název v kódu, skupina, typ, výchozí hodnota, rozsah, krok, jednotka, volby, datový soubor, krátký popis a **prázdné pole `napoveda`** (texty nápověd ve v1 nejsou, Jan 16:50);
- schéma se **sestaví z kódu reflexí** (názvy, typy a výchozí hodnoty z `ParametrySveta`, `ParametryEroze`, `ParametryKlimatu`, `ParametryVody`) a doplní ručně psanými metadaty (skupina, jednotka, rozsah); testy hlídají, že metadata a kód sedí;
- **sada hodnot** (`SadaParametru`): hodnoty podle schématu → `ParametrySveta` + `NastaveniModulu` pro pipeline; JSON tam a zpět;
- export schématu do JSON (`willage.gen` nástroj `schema`) jako podklad pro G-5.

## Oprava: moře přes ParametrySveta
Dnes `ErozePlanety.NactiMore` vždy přepíše všech 36 polí moře hodnotami z `more_v1.json`, takže nastavit je v `ParametrySveta` nejde (nález G-1). Návrh: soubor přepíše pole **jen tam, kde má `p` ještě výchozí hodnotu C#** (výchozí C# = `more_v1.json`, hlídá test 6d). Výchozí svět i všechny dnešní cesty tak dají stejné otisky; ručně nastavené pole zůstane. Omezení: pole ručně nastavené přesně na výchozí C# hodnotu, když se soubor liší, dostane hodnotu ze souboru. Přesná cesta bez tohoto omezení je `SadaParametru` (pořadí výchozí C# < soubor < sada).

## Další drobnosti z nálezů G-1
- Parametry dobití hladiny 7c (`Hladina*` v `ParametryKlimatu`) patří modulu **M6** (klíč M6, ne M5); M6 a M7 berou aktuální parametry klimatu z nastavení, ne z uloženého výstupu M5 (aby změna `Hladina*` nepřepočítala M5 a přesto se projevila).
- Pole, která preset klimatu kroku 2 vždy přepíše (`Podil`, `KlimaKVoda`, `KlimaKHorniny`), se ve schématu označí jako odvozená (jen čtení).

## Testy a kritéria
| Test | Prošlo, když |
|---|---|
| celá sada | 307/307 jako G-1 + nové, 0 chyb; otisky `9d4f2b8` beze změny (golden mapa `800d420bb00047de`, segmenty, nástroj `klima otisky`) |
| úplnost | každý parametr z kódu (pole / vlastnost) je ve schématu právě jednou, v právě jednom modulu; metadata nemají nic navíc |
| výchozí hodnoty | výchozí hodnota schématu = dnešní hodnota (C#, a kde je soubor, hodnota ze souboru); rozdíly C# × soubor vypsat |
| rozsahy | výchozí hodnota leží v rozsahu, min < max, jednotka a skupina vyplněné, `napoveda` existuje (prázdná) |
| JSON | schéma i sada hodnot tam a zpět beze ztráty; výchozí sada → stejné klíče modulů jako pipeline bez sady |
| moře | `PodilMore` v `ParametrySveta` i v sadě změní klíče M2–M7 a podíl moře; výchozí beze změny |
| `Hladina*` | změna `HladinaSuchoM` přepočítá jen M6 a M7, výsledné dobití = přímý výpočet |

Výsledky (i negativní) se doplní níže.

## Výsledky
*(doplní se po implementaci)*
