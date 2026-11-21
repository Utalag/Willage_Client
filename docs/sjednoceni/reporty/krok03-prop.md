# PROP – Krok 3, geologie a útvary

Větev `gen-v1-krok03-geologie` z `gen-v1-krok02-funkce-sveta` (22f4494). Napsáno 2026-11-21 23:00 SEČ, před změnou kódu. Do `main` nic nejde, krok 4 se nezačíná. Staré studijní přepínače (`p81_tenke`, `p82_vapenec`, `cavity_one` v pipeline hry) zůstanou vypnuté; hra bere dál stávající `geo_fn.gd`.

## Proč
Jan 2026-11-21 22:55 schválil krok 2 ([pt877u] ano). Krok 3 podle 04: vrstvy, mince E82, útvary SDF (E84), vnitřek sopky, oprava tabulky materiálů a přepočet propustnosti × 1/4 na buňku 0,25 m (Jan 2026-11-21 00:35).

## Zdroje k převzetí (ne psát znovu)
- Vrstvy: `geo_fn.gd` / `strata.gd` / `geo2.targets` + `ug_funkce.bands` (main, E87) — algoritmus mocností a vyklínění, ale jako čistá funkce v metrech bez mřížky sousedů a bez konstant sloupce 32 m / U = 0,5 m.
- Mince: `G2.coin82` + `lift82` z `e82-vapenec-hladina` (příznak ve hře zůstane vypnutý).
- Útvary: jádro `tools/implicit_e84.gd` z `zkusebni-vse` (SDF z hashe světové mřížky: žíla, čočka/peň, kras; skarn na kontaktu). `cavity_one` se ve funkci V1 nepoužije.
- Tenké vrstvy: logika testu `tenke_e81.gd` (definice vs. zbytky po ořezu).
- Katalogy: `poradi_hornin.json` úrovně 0–40, `minerals.gd`, `hostitele.gd`, `tridy.gd` jako data, ne jako vzorkování buněk segmentu.

## Plán
1. **Tabulka V1** (`godot-prototyp/data/materialy_v1.csv`): přepočítat `propustnost_l_s_herni` na plochu stěny 0,0625 m² (× 1/4). Pásma krajiny id 57–74 se v geologii V1 nepřiřazují (1.7.1: úrovně 41–63 nejsou vrstvy); přemapování na nejbližší vrstvu 0–40 se zapíše. Konflikt klíče `lignite` (vrstva 53 / minerál 105) se v tabulce V1 jen pojmenuje jednoznačně, starý `poradi_hornin.json` hry se nemění (`port_studie`). Staré tabulky hry se nemění, ať `voda_e66` zůstane.
2. **Vrstvy** jako funkce (`scripts/v1/geo_vrstvy.gd`), napojené na `svet_fn.bod` / `sloupec.hranice` (rozhraní 2.2 beze změny). Pásma podle 1.7.1 (37–40 / 26–36 / 13–25 / 0–12), 1–3 zástupci z mapy hornin kroku 2, vyklínění, min. 0,25 m, max. 1/4 výšky od povrchu k z = 0, vrstvy sledují tvar terénu. Druhy pipe/vein/dome/contact z katalogu nejsou vrstvy, jdou do útvarů. `k_horniny` z klimatu se uplatní jako kontrast vah (k = 1 je identita, výchozí `mirne` se nezmění).
3. **Mince E82** ve funkci V1 (zapnutá, podíl 0,5). Mince je po bloku 128 m (test: podíl bloků „ano“). Zvednutí jeskynního a hlubokého vápence a dolomitu na odhad hladiny − 2 m; jíl nad nimi vyklíní. Odhad hladiny jako v E82: vyhlazený povrch (skutečná hladina je až krok 4) — viz otevřené.
4. **Útvary SDF** (`scripts/v1/utvary.gd`): převzít E84 (žíla, čočka/peň, kras/dutina, skarn) a doplnit dóm (sůl 47) a komín (kimberlit 21) stejným postupem z hashe mřížky. Středy Z se ukotví k pásmům V1 (sloupec 128 m, ne starých 32 m). Minerály z hostitele jako vložky v útvaru, ne `cavity_one`.
5. **Sopka uvnitř:** průduch id 75 od kráteru po z = 0, kuželovité slupky, těleso vrstvy propíchne. Tabulka nemá id lávy a popela; výchozí parametry zatím `sopka_lava_id=7` (diabaz/čedič) a `sopka_popel_id=57` (zvětralé vyvřeliny) — viz otevřené.
6. Testy 1–6 z 04 + regrese kroku 1. Obrázky do `godot-prototyp/shots/krok03/`. Report `krok03.md`.

## Otevřené (nerozhoduji, jen označím)
- Má se mince po kroku 4 vázat na skutečnou hladinu podzemí, nebo zůstat u odhadu E82 (vyhlazený povrch − 2 m)?
- Má tabulka dostat samostatná id lávy a popela, nebo stačí parametry 7 a 57?
- Mají se id 57–74 z tabulky úplně odstranit, nebo jen přemapovat a v geologii nepoužívat?

## Výsledky
Doplní se po testech do tohoto souboru a do [`krok03.md`](krok03.md).
