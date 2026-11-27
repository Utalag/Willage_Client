# PROP GEO2 K6: rozhraní modifikátorů (IDeformace), bez vyhodnocení

*Zapsáno před prací 2026-11-27 ~17:15 (Jan t1042u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 1.8, R1, krok K6 v kap. 5,
V1 (aktivní `Deformuj` validace odmítne). Větev `geo2-k6-modifikatory` z `geo2-k5-mrizka`. Etapa D se NEDĚLÁ.*

## Návrh
1. `Geo2/IDeformace.cs` – jen typy, žádná implementace v produkčním kódu:
   - `ObalkaOsova` (min/max x, y, z) – obálka deformace;
   - `AfinniZobrazeni` (3×3 + posun, `Pouzij`) – zobrazení úseku do starších souřadnic;
   - `UsekDeformace(T0, T1, Primka Starsi, AfinniZobrazeni Zobrazeni)` – úsek parametru přímky a jeho přímka ve starších souřadnicích;
   - `IDeformace`: `Stari`, `Obalka`, `bool Inverze(ref double x, ref double y, ref double z)` (vrací „přesně“),
     `bool UsekySloupce(in Primka p, List<UsekDeformace> useky)` (false = `NeAfinni`, záloha etapy D).
2. Validace beze změny: aktivní `Deformuj` = `DEFORMACE_AZ_D`, neaktivní v datech smí být a vyhodnocení neovlivní.
3. Kompilátor ani sloupec rozhraní nevolají (napojení = etapa D, D1/D2).

## Kritéria
| Test | Očekávání |
|---|---|
| build | rozhraní se přeloží, nic ho v produkci nevolá |
| V1 odmítnutí | aktivní `Deformuj` → `DEFORMACE_AZ_D`; neaktivní projde a `Bod` / běhy jsou stejné jako bez ní |
| tvar rozhraní | testovací posun (jen v testech) splní: `UsekySloupce` dá jeden úsek, jeho přímka = afinní obraz sloupce, `Inverze` = zobrazení bodu |
| regrese | celá sada 0 chyb, otisky GEO1 beze změny |

## Rizika
- podoba rozhraní se může v etapě D upřesnit (jen rozhraní, bez uživatelů → levná změna).

## Výsledky *(2026-11-27 ~17:25)*
Commity: `4d018f8` rozhraní `IDeformace` (+ `ObalkaOsova`, `AfinniZobrazeni`, `UsekDeformace`), `abf1b02` testy (`--jen=GEO2K6`).

| Test | Výsledek |
|---|---|
| build | OK; produkce rozhraní nevolá |
| V1 odmítnutí | aktivní `Deformuj` → `DEFORMACE_AZ_D`; neaktivní projde, 2000 bodů + 100 sloupců běhů stejných jako bez ní |
| tvar rozhraní | testovací posun: 1 úsek, bod úseku ve starších souřadnicích = inverze (1e-12), zobrazení = inverze, mimo obálku identita |
| regrese | celá sada **742 / 742 OK**, otisky GEO1 beze změny |

Výkon: beze změny (žádný kód na cestě vyhodnocení). Rozhodnutí pro Jana: žádné nové; podoba rozhraní se upřesní v etapě D.
