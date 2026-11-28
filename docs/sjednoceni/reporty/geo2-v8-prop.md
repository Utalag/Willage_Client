# PROP GEO2 V8: zpráva rozdílů GEO2 × GEO1 po kategoriích + kritéria smazání staré cesty

*Zapsáno před experimentem 2026-11-28 ~02:20 (Jan t1044u, bod 1). Větev `geo2-v8-rozdily` z `geo2-vychozi`. Kontrakt `06-geologie-geo2.md`
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

## Výsledky *(2026-11-28 ~02:35)*
Commity: `a09a5cc` nástroj, `9ad69f6` příčina SkarnHraniceOdhad, `035c575` **oprava K4 nalezená V8** (sopka), kvalita skarnu, výsledky.
Data: `docs/sjednoceni/reporty/geo2-v8-data/rozdily.csv` (kategorie × zdroj GEO1 × zdroj GEO2 × příčina × verdikt × buněk).
Měření: 11 bloků 128 m (1,476 mld. buněk, sloupce 0,25 m, z po 0,25 m), `--jen=GEO2V8`; výstup bitově stejný při 1 a 8 vláknech (md5 shodný).

### Negativní výsledek a nalezená chyba GEO2 (K4)
První běh ukázal v blocích se sopkou **50 052 „otevřených“ buněk** (weathered_volcanic → diabase, `Sopka → Sopka`). Příčina: `TvarSopky.Sloupec`
neměla zlom v `zPovKuz`; mezi `zPovKuz` a `zPovKuz + 0,05` je `k = −1` (popel), takže proužek 0,05 m (< t_det) se vynechal a **raster z běhů ≠ `Bod`**
(V4 to nechytil, kontroluje tětivy ≥ t_det a E84 bloky bez sopky). Oprava = jeden zlom (`035c575`). Regresní test (29 277 buněk u povrchu kuželu):
před opravou 1 171 rozdílů, po opravě 0. Po opravě sopky: svah sopky 0,023 % různých, okraj 0,26 % (vše skarn/tělesa, ne sopka).

### Podíl různých buněk po kategoriích (po opravě)
| Kategorie | buněk | různých | podíl | zlepšení | dle kontraktu | tolerance | otevřené |
|---|---|---|---|---|---|---|---|
| náhodné (5 bloků) | 671 088 640 | 3 227 433 | 0,481 % | 984 | 3 154 395 | 72 054 | 0 |
| šev mince x = 1920 | 134 217 728 | 1 561 179 | 1,163 % | 21 | 1 535 818 | 25 340 | 0 |
| šev mince x = 2048 | 134 217 728 | 2 257 781 | 1,682 % | 505 | 2 248 040 | 9 236 | 0 |
| hornatina / strmé svahy (2) | 268 435 456 | 1 534 441 | 0,572 % | 1 178 | 1 489 274 | 43 987 | 2 |
| svah sopky | 134 217 728 | 30 795 | 0,023 % | 0 | 30 702 | 93 | 0 |
| okraj sopky | 134 217 728 | 354 966 | 0,265 % | 0 | 341 922 | 13 044 | 0 |
| **celkem** | 1 476 395 008 | **8 966 595** | **0,607 %** | 2 688 | 8 800 151 | 163 754 | **2** |

(šev mince: bloky centrované na švy x = 1920 a 2048; sopka = první sopka světa, blok na svahu 0,4 R a na okraji.)

### Kde a proč se liší (příčiny, podíl z různých buněk)
| Příčina | Verdikt | buněk | z různých | Vysvětlení |
|---|---|---|---|---|
| `SkarnJenKarbonaty` | dle kontraktu (O1, Jan t1029u) | 8 758 591 | 97,68 % | GEO1 dělá skarn i ve svoru (5,27 M) a amfibolitu (3,56 M); GEO2 jen v karbonátech |
| `SkarnHraniceOdhad` | tolerance (uznaná výjimka V5, Jan t1043u) | 150 047 | 1,67 % | vykliňování vrstvy uvnitř buňky 0,25 m, vzdálenost k hranici je odhad (`HraniceOdhad`) |
| `HostitelSkarn` | dle kontraktu (host = materiál v bodě) | 36 820 | 0,41 % | GEO1 vloží dóm / kras do hostitele „vrstva“; GEO2 ponechá skarn, který těleso za hostitele nepřipouští (ověřeno `HostOk`) |
| `SkarnVPasmuTolerance` | tolerance | 13 707 | 0,15 % | obě varianty leží v kontraktním pásmu [0,625; 2,375] m, rozhodl jiný šum modulace |
| `PravidloZdroje` | dle kontraktu (2.3, `zdroje.telesa`) | 2 872 | 0,03 % | kras (nejmladší) nesmí odebrat dóm, GEO1 ano (nejmenší SDF) |
| `PoradiTeles` | dle kontraktu (stáří, 2.7) | 1 868 | 0,02 % | překryv těles rozhoduje stáří, ne nejmenší SDF (komín > čočka / dóm / žíla) |
| `SkarnDiraGeo1` | **zlepšení (měřeno)** | 1 496 | 0,017 % | v karbonátu uvnitř jistého pásma (D < 0,625 m) GEO1 skarn nemá, GEO2 ano |
| `CockaObalka` | **zlepšení (měřeno)** | 1 192 | 0,013 % | oprava obálky čočky (GEO1 ořezává) |
| `SkarnJine` | **otevřené** | 2 | 0,00002 % | GEO1 skarn, GEO2 karbonát, bez odhadu hranice – neprošetřeno (2 buňky, blok (3904, 1344)) |

Nezávislé měření kvality skarnu proti kontraktu (sloupce se skarnem v aspoň jednom systému; pásmo po normále [0,625; 2,375] m, O1):

| | skarn (buněk) | v nekarbonátu (porušení O1) | tlustší než pásmo | díry v pásmu karbonátu | s odhadem |
|---|---|---|---|---|---|
| GEO1 | 9 549 367 | 8 898 790 (93,2 %) | 0 | 1 496 (0,167 % karbonátu v pásmu) | 5 372 |
| GEO2 | 712 382 | 0 | 0 | 2 (0,0002 %) | 15 895 |

**Poctivě:** (1) 97,7 % rozdílů je jediné rozhodnutí O1 (skarn jen v karbonátech), nikoli objektivní měření; „lépe“ je podle kontraktu, ne podle geologické
pravdy. (2) Pásmo skarnu v karbonátech GEO1 netloustne nad kontraktní horní mez (tlustší 0), svislá vzdálenost tu tedy kontrakt neporušuje; GEO2 nemá
výhodu v tloušťce, má ji v dírách (1 496 → 2) a v O1. (3) Měřené „zlepšení“ je malé (2 688 buněk, 0,00018 % všech); většina změn je změna sémantiky podle kontraktu.

### Přechody materiálu (prvních 8, GEO1 → GEO2)
skarn → mica_schist 5 267 632; skarn → amphibolite 3 556 532; skarn → pegmatite 57 908; rock_salt → skarn 26 433; skarn → kimberlite 16 794;
cave_limestone → skarn 13 843; map_ceiling (dutina) → skarn 10 387; dolomite → skarn 9 492.

### Návrh kritérií smazání staré cesty GEO1 (K7, 12A) – k potvrzení Janem
**Co se maže a co ne.** GEO2 dnes stojí na částech GEO1: `VrstvySloupce` (zásobník, hranice), `NitroSopky`, `Utvary.Sdf` / `TvorbaUtvaru.Make` (parametry a SDF těles),
`HostiteleUtvaru` (data). Smazat lze jen **cestu vyhodnocení**: `GeoVrstvy.Bod` / `VyplnSloupec` / `VyplnSloupecRezim`, `Utvary.MatFeats` / `SkarnD` / `FeatMat`,
`TvorbaUtvaru.Features` (výběr vítěze podle nejmenší SDF), `KesGeologie` / `ParalelniSloupce` (keš a `Klon()` na vlákno). Ostatní zůstává (nebo se přesune pod GEO2).
Uživatelé staré cesty dnes: voda (`Prameny`, `PodzemniVodaFn`, `RegionalniHladina`, `Doplnovani`), `M3Geologie`, `M7VystupPlanety`, náhledy API (`NahledyModuluApi`),
nástroje (`Willage.Gen.Nastroje`), otisky G-1 / G-3 / krok 5.

| # | Kritérium | Stav |
|---|---|---|
| 1 | V1–V8 splněna (V9 / etapa D se nevyžaduje) | V1–V7 ano (K1–K6), V8 tato zpráva |
| 2 | **V8: otevřených buněk = 0** na pevné sadě bloků (CSV v repu) pro nejméně 3 seedy světa × 11 bloků; každá nová příčina vysvětlená | teď 2 buňky z 1,48 mld. (1 seed) → prošetřit `SkarnJine`, přidat seedy |
| 3 | Všechny „dle kontraktu“ přechody (top 10 podle počtu) Jan podepsal; O1 je podepsané | O1 ano, ostatní k potvrzení |
| 4 | Výkon GEO2 (výchozí, kontext + sloupce) ne horší než ×1,5 GEO1 na blocích z V6, medián z ≥ 5 opakování na nezatíženém boxu | bod 3 zadání (měření) |
| 5 | Voda, M3, M7, API a nástroje čtou z GEO2 (běhy), žádný produkční kód nevolá `GeoVrstvy.Bod` / `VyplnSloupec` | ne (K7) |
| 6 | Zlaté otisky GEO1 (G-1, G-3, krok 5) nahrazeny otisky GEO2 s Janovým schválením; starý otisk archivován jako hash v dokumentu | ne |
| 7 | Souběžný provoz za přepínačem `GeologieV2` po dobu určenou Janem (návrh: jedno plné vygenerování světa a jedna herní relace bez hlášené geologické chyby) | ne |
| 8 | Smazání jedním commitem na vlastní větvi, testy a zbývající otisky bez změny, návrat = `git revert` | – |

### Rozhodnutí Jana t1046u (2026-11-28 12:30 Europe/Prague)
- **Schváleno:** pravidla `HostitelSkarn`, `PravidloZdroje`, `PoradiTeles` jako „dle kontraktu“ (zapsáno do `06-geologie-geo2.md` 7.3 na větvi `geo2-kontrakt-docs`, commit `f988b94`).
- **Schváleno:** kritérium 2 – 0 otevřených buněk na ≥ 3 seedech × 11 bloků. Kritérium 4 (výkonový práh ×1,5 GEO1) **Jan teprve rozhodne** (po profilování, viz `geo2-vykon-prop.md`).
- **Zadáno hned:** prošetřit 2 buňky `SkarnJine` (blok 3904, 1344) – viz `geo2-skarnjine-prop.md` (větev `geo2-skarnjine`).
- Kritérium 3 v tabulce výše: O1 + tři pravidla = podepsáno; zbývá případný nový přechod z dalších seedů.

### Rozhodnutí pro Jana (původní návrh, stav viz výše)
1. Potvrdit seznam „dle kontraktu“ změn (kromě O1): `HostitelSkarn`, `PravidloZdroje`, `PoradiTeles`.
2. Potvrdit kritérium 2 (0 otevřených, ≥ 3 seedy) a výkonový práh ×1,5 (kritérium 4).
3. Zda se mají 2 buňky `SkarnJine` prošetřit hned, nebo až při měření více seedů.
