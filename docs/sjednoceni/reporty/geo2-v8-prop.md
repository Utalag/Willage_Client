# PROP GEO2 V8: zpráva rozdílů GEO2 × GEO1 po kategoriích + kritéria smazání staré cesty

*Zapsáno před experimentem 2026-11-28 ~02:40 (Jan t1044u, bod 1). Větev `geo2-v8-rozdily` z `geo2-vychozi`. Kontrakt `06-geologie-geo2.md`
V8 (rozdílová zpráva po kategoriích), K7, rozhodnutí 12A. **Kritérium je „GEO2 lepší než GEO1“, ne přesná shoda.***

## Cíl
1. Buňku po buňce porovnat GEO1 (`GeoVrstvy.VyplnSloupec`) a GEO2 (výchozí `KontextBloku.Sloupec`, běhy + raster) na blocích 128 m, sloupce 0,25 m,
   z po 0,25 m, v kategoriích z `PODKLADY.md` 2.7 (náhodné, šev mince E82, svah sopky, okraj sopky, hornatina / strmé svahy).
2. Každý rozdíl zařadit podle **zdroje** v GEO1 a v GEO2 (vzduch, sopka, vrstva, skarn, čočka, žíla, dóm, komín, kras) a podle **příčiny**.
3. U každé příčiny určit **verdikt** nezávislým měřením (ne podle toho, kdo má pravdu „podle sebe“):

| Verdikt | Význam |
|---|---|
| **zlepšení** | GEO2 splňuje kontrakt a GEO1 ho porušuje (měřeno): oprava obálky čočky; skarn jen v karbonátech (O1) a tloušťka pásma eukleidovsky v [w₀(1−a)−e_k, w₀(1+a)+e_k] (3. rozhodnutí 7); žíla v skarnu zůstane křemen, o překryvu rozhoduje stáří (2.7) |
| **dle kontraktu (změna)** | záměrná změna sémantiky bez objektivního „lépe“ (pořadí těles podle stáří místo nejmenší SDF, hostitel z materiálu v bodě, typ prostoru dutiny) |
| **tolerance** | rozdíl v rámci τ / ε od hranice vrstvy nebo povrchu (buňka se středem do 0,125 m od hranice) |
| **otevřené / chyba** | nevysvětleno žádnou z předchozích příčin: nutno prošetřit; počítá se jako chyba GEO2, dokud není vysvětleno |

4. Z měření odvodit **návrh kritérií smazání GEO1** (K7, 12A).

## Postup
- Nástroj v testovacím projektu (`TestyGeo2V8*.cs`, dělený na zdroj GEO1 / zdroj GEO2 / příčiny / zpráva), spouštěn `--jen=GEO2V8`.
- Vlákna: `Klon()` GEO1 na vlákno (jako K3), GEO2 jedním kontextem. Počítadla po vlákně, sloučení na konci (determinismus výsledku).
- Skarn: vzdálenost D k nejbližšímu bodu plochy granitoidu z kontaktní plochy GEO2 (stejná, kterou V3 ověřuje vůči jemné referenci).
- Výsledek: tabulky (kategorie × podíl různých buněk, přechody materiálů, příčiny × verdikt), uloženo i do CSV v `docs/sjednoceni/reporty/geo2-v8-data/`.

## Kritéria úspěchu měření
- Podíl „otevřených“ buněk vykázaný čísly (cíl: blízko 0; nenulový se rozebere po příčinách a poctivě uvede).
- Součet kategorií = všechny různé buňky (kontrolní součet).
- Měření reprodukovatelné (stejný výstup při 1 a 8 vláknech).

## Rizika
- Příčiny se mohou překrývat (buňka u hranice vrstvy i u skarnu): zařazuji první platnou v pevném pořadí (v PROP výsledcích uvedeno).
- Verdikt „zlepšení“ je jen tak silný, jak měření D / obálky; u pořadí těles je to „dle kontraktu“, ne „lépe“.
