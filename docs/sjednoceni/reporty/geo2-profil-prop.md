# PROP GEO2: profil času na blocích, kde je výchozí GEO2 nad doporučením ×1,5 GEO1 (Jan t1046u bod 3, t1047u)

*Zapsáno před profilováním 2026-11-28 12:41 (Europe/Prague). Větev `geo2-profil` z `geo2-vychozi` (včetně sloučeného kontaktu rychle) + nástroj měření z `geo2-vykon-mereni`. **Jen profilování, nic se neimplementuje.***

## Cíl
Najít, kde se na blocích s největším poměrem k GEO1 tráví čas, a navrhnout **jen levné a jisté bitově stejné** úspory s odhadem zisku. Limit ×1,5 GEO1 je **doporučení** (Jan t1047u), ne kritérium smazání: kde už není co levně zrychlit, uvede se jen vzdálenost od doporučení.

## Bloky a postup
Bloky: hornatina (1664, 1728) a (3904, 1344), svah sopky (1673, 1705), okraj sopky (1710, 1705), šev mince (1984, 2560). Z měření bodu 3 (8 vláken, medián, GEO2 / GEO1): ×2,69, ×2,99, ×2,22, ×1,65, ×1,98 (po kontaktu rychle ×3,04, ×2,81, ×2,22, ×1,81, ×1,89).
Nástroj `dotnet-trace` (vzorkování CPU, všechna vlákna), výchozí GEO2 cesta (kontext + `Sloupec` z běhů), sloupce po 0,25 m, 8 vláken, 2 průchody bloku v jednom procesu (první zahřeje JIT; do profilu jde celý běh, zahřívací průchod se uvádí v celkovém čase). Převod na speedscope a součet inkluzivních / vlastních časů podle metod.
Srovnání s GEO1 stejného bloku (stejný nástroj) kvůli tomu, co je společné (`VrstvySloupce.Hranice` apod.).

## Co chci zjistit
1. Rozpad času: kontext (mřížka hranic, indexy těles) × `Sloupec` (segmentace, sondy, bisekce, raster) × společné GEO1 části (`VrstvySloupce.Hranice`, šum).
2. Který tvar událostí dominuje na strmých blocích (zásobník vrstev, těleso, sopka, kras, kontaktní pásmo).
3. Zda je dominantní práce odstranitelná bez změny výsledku (cache, předpočet, zkrat s dokázanou ekvivalencí).

## Kritéria
- Každá navržená úspora: příčina z profilu (% času), proč je bitově stejná (důkaz / kontrola), odhad zisku (min / max, z podílu času), riziko, pracnost.
- Nic se neimplementuje ani nemění; měřicí nástroj `--jen=GEO2PROFIL` je jediná nová kódová změna.
