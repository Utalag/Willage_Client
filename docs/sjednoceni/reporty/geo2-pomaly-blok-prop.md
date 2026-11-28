# PROP GEO2: proč je blok (1664, 1728) na seedu 7 pomalý (Jan t1070u)

*Zapsáno před experimentem 2026-11-28 (Europe/Prague). Větev `geo2-pomaly-blok` z `geo2-v8-seedy` (03b0dd4). Měří se primárně na boxu (8 jader, relativní poměry stačí), absolutní časy případně na Janově PC.*

## Pozorování (z `geo2-v8-seedy-prop.md`, Janův PC, 24 vláken)
- seed 7, blok (1664, 1728): GEO2 sloupce 14,9 / 18,7 / 23,6 s (3 běhy) proti GEO1 ≈ 3,5 s; tentýž blok v seedu 49 = 3,1 s, v seedu 100 = 1,1 s.
- seed 100, blok (3904, 1344): 11,7 s (GEO1 2,9 s). Seed 7 (3904, 1344): 9,8 s. Seed 49 (3904, 1344): 3,5 s.
- Metrika „GEO2 sloupce“ = maximum přes vlákna součtu času `KontextBloku.Sloupec` (bez klasifikace V8); tedy buď je těžké všechno, nebo jedno vlákno dostalo drahé sloupce.
- Jiné bloky: 1–2 s. Zpomalení je tedy reprodukovatelné na (seed, blok), není to šum.

## Hypotézy
- **H1** Několik patologických sloupců (jeden nebo pár vláken dostane drahé sloupce) × celý blok je drahý.
- **H2** Cena sloupce roste s počtem nejistých oblastí / počtem volání `Bod` (`SloupecGeo2.VolaniBod`), protože `Nejisty` vzorkuje po h = t_det/2 a půlí hranice na ε = 2⁻¹⁰ m.
- **H3** Rekurze `Useky(c, i, …)` pro každý kontakt (prefix událostí < i se počítá znovu pro každý kontakt) zvyšuje cenu násobně u sloupců, kde kontakt (skarn) něco dělá.
- **H4** Něco jiného: `VrstvySloupce.Hranice` (alokace ~21 kB/volání, dřívější profil), geometrie kontaktní plochy, GC.

## Postup
1. Přečíst kód (`SloupecGeo2`, `KontextBloku`, kontakt, tvary E84) a určit horké cesty.
2. Diagnostika za příznakem (`--jen=GEO2POMALY --seed= --blok=`): na sloupec čas `Sloupec`, `VolaniBod`, počet běhů, počet událostí a nejistých úseků; alokované bajty vlákna (`GC.GetAllocatedBytesForCurrentThread`), počet volání `Hranice`. Výstup: rozdělení nákladů (jaký podíl času má top 1 % / 10 % sloupců), korelace s vlastnostmi sloupce.
3. Porovnat: pomalý blok (seed 7) × stejný blok seed 49/100 × rychlý blok seedu 7 (např. (512, 3072)) × (3904, 1344) seed 100.
4. Případně `dotnet-trace`/`dotnet-counters` na boxu.
5. Navrhnout opravu; pokud je malá a bitově shodná, implementovat a ověřit otisky/bitovou shodu proti současnému GEO2 výstupu na stejných blocích.

## Kritérium úspěchu
Příčina doložená čísly (podíl času na konkrétním rysu a sloupcích). Případná oprava: bitově shodný výstup a měřitelné zrychlení; každý experiment včetně negativního zapsán níže.

## Výsledky
*(doplní se)*
