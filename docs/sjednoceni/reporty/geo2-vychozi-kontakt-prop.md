# PROP GEO2: sloučení `geo2-kontakt-rychle` do `geo2-vychozi` (Jan t1046u, bod 2)

*Zapsáno před sloučením 2026-11-28 12:37 (Europe/Prague). Větev `geo2-vychozi`.*

## Co se slučuje
`geo2-kontakt-rychle` (`bdc538c` PROP, `7ad4cbd` kód, `8e539b8` výsledky): přesný zkrat povrchu v hostiteli okolí kontaktního pásma. Horní hranice vrstev zásobníku je dolní mez povrchu; pokud je `z` pod ní a prefix událostí nemá pravidlo hloubky, vynechá se přesné `SvetFn.VyskaW` (výsledek bitově stejný). Předchozí měření: otisk 4 bloků × 134 M buněk shodný před / po, skarnový blok (1024, 512) K4 5,4 → 3,7 s.

## Co se ověří po sloučení
1. Sloučení bez konfliktů (větev kontakt-rychle vychází z `geo2-vychozi`, očekává se fast-forward; zachová se merge commit `--no-ff`, aby šla historie vrátit jedním revertem).
2. Celá sada testů (očekáváno 742/742), otisky GEO1 (krok 5, G-1, G-3) beze změny.
3. Bitová shoda GEO2: otisk bloku (`OtiskBloku` v `GEO2K4B`) na skarnovém bloku (1024, 512) a na jednom bloku mimo skarn se rovná otisku před sloučením (`geo2-vychozi` 82deda7).
4. V8 regrese sopky a nový test SkarnJine nejsou na této větvi (jsou na `geo2-v8-rozdily` / `geo2-skarnjine`).

## Kritéria
- Všechny 4 body splněné; jinak sloučení vrátit a vyřešit příčinu (nepushovat).
