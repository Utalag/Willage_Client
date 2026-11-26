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

## Výsledky (26. 11. 2026)

Základ: main 3466e11 (G-1 sloučeno, tag gen-v1-g1); kód cs/ a data jsou shodné s otestovaným gen-v1-g1-moduly, větev přenesena rebase.

**Postaveno**
- `cs/Willage.Gen/Schema/`: `ParametrSchematu` + `TypParametru`, `MetadataParametru` (skupiny, výslovné rozsahy, volby, jen čtení; jednotka a rozsah jinak odvozené z názvu), `SchemaParametru` (reflexe ParametrySveta / ParametryEroze / ParametryKlimatu / ParametryVody + tabulka prusak_v1.json, JSON), `SadaParametru` (výchozí z dat nebo z kódu, Nastav, Sestav → ParametrySveta + NastaveniModulu, JSON s částečnými hodnotami), `BiomJson`.
- Nástroj `Willage.Gen.Nastroje schema [soubor] [--kontrola]`; export `docs/sjednoceni/reporty/g2/schema_parametru_v1.json` (mimo data, manifest se nemění).
- Moře nastavitelné přes ParametrySveta/sadu (`ParametryMore.UplatniNaVychozi`); M4 bere pole M2 ze vstupu. Hladina* (dobití 7c) patří M6.
- PNG: `docs/sjednoceni/obrazky/g2/01-schema-parametru.png` (`kresli_g2.py`).

**Schéma:** 202 parametrů – M0 10, M1 42, M2 38, M3 16, M4 20, M5 29, M6 47, M7 0. Typy: Desetinne 160, Logicky 20, Cele 14, Tabulka 4 (Biomy, HorninyBiomu, Planety, průsak), Pole 2, Volba 2 (Klima z klima_presety.csv, InterpolaceE). Jen čtení 8. Rozsah z kódu 8, odhad 166. Nápověda: prázdný slot u všech.

**Testy:** 338/0 (G-1 307 + G-2 31), běh 2 min 10 s. G-1 test „PodilMore v ParametrySveta nic nemění“ záměrně změněn na „mění M2–M7“.

**Otisky (nezávisle `klima otisky`) = 9d4f2b8:** mapa 800d420bb00047de; klima zap: 86 vodníků, krok 3 9f32311e046f8b6a, voda 14,14 377a8210f82c856a, klima cb11da8d141a2a5e; klima vyp: 92 vodníků, voda 14,14 8e239a68c6d01be0. Segment Puvodni() 059d807ab04b7f00 (test).

**Zvláštnosti a negativní nálezy**
- `ParametryKlimatu.Planety`: výchozí v C# ≠ klima_v1.json (např. mírné SrazkyMmRok 1000 v C#, 800 v souboru) – jediný rozdíl soubor × C# (121 hodnot ze souborů). Sada „jen z kódu“ proto mění klíče M5–M7.
- Hladina moře dvakrát: ParametrySveta.HladinaMoreM (M2) a ParametryKlimatu.HladinaMoreM (M5) – nejsou svázané.
- PlanetaXM/YM v ParametrySveta (M2) i ParametryEroze (M4); svět planety bere eroze → pole ve světě jen čtení. Stejně SvetMaxM, BlokM, SloupecM.
- Podil, KlimaKVoda, KlimaKHorniny vždy přepíše preset klimatu → jen čtení.
- ParametryVody.Seed (49) je samostatný seed, nesvázaný se seedem světa.
- `UplatniNaVychozi`: pole moře nastavené přesně na výchozí hodnotu C# dostane hodnotu ze souboru (dnes soubor = C#, takže neviditelné).
- Reliéf M1 erozní mapa planety stále nepoužívá (zvláštnost G-1 zachována).
- Biom nešel deserializovat (názvy parametrů konstruktoru ≠ pole) → `BiomJson`, ParametrySveta beze změny.
- Rozsahy jsou až na 8 odhad z názvu a výchozí hodnoty – k ladění Janem; schéma rozsah nevynucuje.
