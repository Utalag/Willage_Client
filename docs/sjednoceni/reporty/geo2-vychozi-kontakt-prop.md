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

## Výsledky (2026-11-28 12:44, Europe/Prague)
- Sloučeno `--no-ff` (merge commit `64e7f4f`), bez konfliktů (`geo2-kontakt-rychle` vycházela z `geo2-vychozi`). Vrácení = `git revert -m 1 64e7f4f`.
- **Celá sada 742 / 742 OK**, otisky GEO1 (krok 5, G-1, G-3) beze změny.
- **Bitová shoda GEO2** po sloučení: otisk celého bloku (134 217 728 buněk, po sloupcích) shodný s hodnotami zaznamenanými před úpravou (`geo2-kontakt-rychle-prop.md`) ve 4 blocích, K3 == K4 v každém: (1024, 512) `CB5E93702313A0E2`, (3000, 2000) `F9696D1DFD21AC63`, (0, 0) `0F956A8A505FB87F`, (3904, 1344) `395D525F269149CE`.
- Výkon po sloučení: viz `geo2-vykon-prop.md` (měření B, GEO2 + kontakt rychle): skarnový blok (1024, 512) celkem 7,44 → 5,45 s (×2,36 → ×1,43 GEO1).
- Push: token `WILLAGE_CLIENT_GH_TOKEN` v tomto běhu není nastaven, větev zůstává lokálně (předchozí remote stav `geo2-vychozi` 82deda7).
