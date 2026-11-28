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

### E1. Diagnostika po sloupcích (box, 8 vláken, krok 0,5 m = 256 × 256 sloupců; relativní poměry)
Nástroj `--jen=GEO2POMALY --seed= --blok=x,y,0.5 --csv=` (`TestyGeo2Pomaly`), čítače `Plati/Nejblizsi/Pred/Hranice` za ThreadStatic. Surová data po sloupcích: `/workspace/pomaly-out/*.csv` (na boxu, 4 MB na blok; do repa nejdou), souhrn v `geo2-pomaly-blok-data/souhrn-e1.csv`.

| seed, blok | součet času sloupců | volání `GeoVrstvy.Hranice` | z toho Pred (q′ kontaktu) | čas uvnitř Hranice | sloupců s chůzí kontaktu |
|---|---|---|---|---|---|
| 7, (1664,1728) **pomalý** | 45,1 s | 1 447 026 | 1 120 336 | 40,4 s (90 %) | 38 637 z 65 536 (59 %) |
| 100, (3904,1344) **pomalý** | 28,2 s | 806 924 | 602 393 | 23,3 s (83 %) | 20 982 (32 %) |
| 7, (3904,1344) | 21,1 s | 652 373 | 476 017 | 17,1 s (81 %) | 16 428 (25 %) |
| 49, (3904,1344) | 11,1 s | 227 986 | 132 179 | 6,7 s (60 %) | 5 059 (8 %) |
| 49, (1664,1728) | 10,6 s | 159 865 | 76 616 | 4,5 s (42 %) | 2 724 (4 %) |
| 7, (512,3072) rychlý | 5,2 s | 65 536 | 0 | 2,0 s (38 %) | 0 |
| 100, (1664,1728) rychlý | 5,7 s | 65 536 | 0 | 2,0 s (35 %) | 0 |

- **Čas ≈ počet volání `Hranice` × ~28 µs** (sedm bloků: 26–30 µs/volání). Počet bodových vyhodnocení `Bod` je naopak podobný (2,6–5,7 M), takže pomalost není v počtu vzorků/běhů.
- **Sloupce s chůzí skarnového kontaktu** (v dosahu R_max od plochy skarnu) stojí ~1,0–1,2 ms a ~0,8 MB alokací, ostatní 0,04–0,1 ms a ~20 kB. Medián času sloupce 0,795 ms (seed 7 pomalý) × 0,04 ms (rychlý).
- Seed 7 blok (1664,1728): kontakt zasahuje 59 % plochy bloku, seed 49 4 %, seed 100 0 %. Geologie seedu 7 (skarn kolem zvedaného karbonátu) tam skarnovou plochu má všude pod horou.

### E2. Mikro-měření a profil `GeoVrstvy.Hranice` (1 vlákno)
`--jen=GEO2HRBENCH`: 29,4 µs/volání, 22,5 kB/volání (seed 7), 29,9 µs a 22,6 kB (seed 100); z toho `VyskaW` ≈ 4 µs, `VyskaTvar` ≈ 4 µs, zbytek `VrstvySloupce.Hranice` ≈ 21 µs. `dotnet-trace` (sampling): `VrstvySloupce.Hranice` 68 %, z toho `Zastupci` ~50 % (vkládání do `Dictionary<int,…>` a růst `List`/`Dictionary` – alokace), `FNV-1a(string)` přes `Encoding.UTF8.GetBytes` na každé volání šumu (`HashSveta.U` ~330× na volání).

### E3. Příčina (shrnutí)
Kontaktní pásmo skarnu s `HostitelOkoli` volá v každém bodě v pásmu `Pred(q′)` = stav bodu v **jiném sloupci** q′ = π(q) + η·u. To je jedno volání `GeoVrstvy.Hranice` (celý zásobník vrstev sloupce, ~29 µs a 22 kB) na každé `Plati`; paměť na 4 sloupce se pokaždé míjí (q′ je pokaždé jiné) a navíc vytlačí vlastní sloupec (FIFO), takže se vlastní sloupec přepočítává (1,23 volání na `Pred`). Bloky a seedy, kde skarnová plocha zasahuje velkou část bloku (seed 7, (1664,1728): 59 %), tak mají 22 volání `Hranice` na sloupec místo 1 → 20–25× dražší sloupec.

Otisky výstupu GEO2 před jakoukoli změnou (krok 0,5 m; `OTISK` = FNV-1a přes bajty vzorků, XOR přes sloupce): seed 7 (1664,1728) `EA7EE5D22E5DBA98`; seed 100 (3904,1344) `2F18B4AE92E6F18C`; seed 49 (1664,1728) `3C1D6022947DBDA1`.
