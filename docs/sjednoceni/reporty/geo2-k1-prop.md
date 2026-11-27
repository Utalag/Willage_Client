# GEO2 K1 PROP: chronologie událostí + pravidla zásahu + validace

Větev `geo2-k1-chronologie` (z `origin/main` b4bc92d). Kontrakt: `docs/sjednoceni/06-geologie-geo2.md` (větev `geo2-kontrakt-docs`),
schválený Janem 2026-11-27 (t1028u–t1033u, „Tak se asi do toho pust.“). Zapsáno před prací 2026-11-27 ~12:15 SEČ.

## Cíl (K1, část a)
Nový nemonolitický modul `cs/Willage.Gen/Geo2/`. Stará cesta (`GeoVrstvy`, `Utvary`) se nemění ani nemaže a nic ho zatím nevolá.
1. **Model události** (kontrakt 1.2): `id`, `stari`, `operace` (`Uloz`, `Vnikni`, `Odstran`, `Vypln`, `Transformuj`, `Deformuj`), `aktivni`,
   `tvar` (druh + surová data), `vyskyt`, `pravidla`, `vysledek`, `sourozenci`.
2. **Čtení `udalosti_v2.json`** (2.7) z textu JSON, bez nových balíčků (`System.Text.Json`).
3. **Katalog pro GEO2** (kap. 8): id, klíč, skupina, stav (`active` / `todo_open_range` / `retired`), náhrada `replacedBy`, otisk katalogu.
   Nad stejným `materials-catalog-v1.json` jako `KatalogMaterialu` (ten zůstává beze změny).
4. **Kompilátor a validátor** (1.3, 2.4, kap. 8): třídění podle (stáří, id), vynechání neaktivních, chyba při shodném stáří,
   tabulka povolených a zakázaných pravidel podle operace, neznámé klíče, materiály a skupiny, odkazy jen na starší události,
   aktivní `Deformuj` = chyba (K1–K5), vyřazená hornina bez náhrady = chyba, s náhradou = varování a přesměrování. Bez chyby za tenkost (O2).
5. **Pravidlo cíle** (2.3): materiál → `nahrazuje` + `zdroje`, prázdno → jen `prostor`, `NadPovrchem` / `Vykopano` nikdo, `Neurceno` jen `Uloz`. `hloubka` vždy.
6. **Dopředný vyhodnocovač bodu** (1.6) bez deformací nad rozhraním `ITvar` / `ITvarZasobniku` (tvary dodá továrna). Stav nese minimum pro pravidla:
   materiál, typ prostoru, geometrický původ (událost, instance, vrstva), počet a poslední transformace. Plný `Vzorek` (3.1) je K2.
7. Testy (`--jen=GEO2`) na syntetických tvarech (poloprostor, koule, deska), lokálně, bez GitHub Actions.

## Mimo K1a (zůstává)
- **K1b:** kontaktní pásmo 2.5 (vzdálenost, strana, `hostitel_okoli`, prefixové vyhodnocení) a adaptéry dnešních tvarů E84 (deska, elipsoid, kras, sopka, zásobník `VrstvySloupce`).
  Do té doby kompilátor událost s `kontakt` přijme jen tehdy, když továrna dodá implementaci kontaktu. Jinak hlásí chybu „kontakt až v K1b“.
- K2 a další: plný `Vzorek`, typ prostoru pro vodu, kontext bloku, intervaly, mřížka, rozhraní deformací.

## Hypotézy / kritéria
| Test | Očekávání |
|---|---|
| V1 (bez zlomu, syntetika) | sedimentace → intruze → transformace → žíla: očekávaný materiál a původ; žíla mladší než transformace zůstane; vypnutí mladší události nezmění body staré |
| V2 | každý řádek 2.4: zakázané selže validací s kódem chyby, povolené projde; pravidlo 2.3 pro dutinu i materiál |
| pořadí | shodné stáří = chyba; pořadí v datech nezáleží (zamíchané pole = stejný výsledek) |
| katalog (kap. 8) | vyřazená bez náhrady = chyba, s náhradou = přesměrování + varování, cyklus náhrad = chyba; skupina zahrne i nově přidanou horninu; otisk katalogu se změní se stavem / náhradou |
| příklad 2.7 | 12 událostí ze `06-geologie-geo2.md` se zkompiluje bez chyby (kontakt přes zkušební továrnu) |
| regrese | celý `Willage.Gen.Testy` beze změny počtu chyb (0), otisky staré cesty beze změny (nový kód se nevolá) |

## Rizika
- Kontrakt předbíhá katalog: `retired` / `replacedBy` v katalogu Willage-backend zatím nejsou. Čtou se, jen pokud tam jsou.
- Zkušební tvary nejsou geologické tvary; ověřují pravidla, ne geometrii (ta je K1b, K4).

## Výsledky
*(doplní se po měření)*
