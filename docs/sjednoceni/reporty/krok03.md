# Report – Krok 3: Funkce světa II (geologie a útvary)

Větev `gen-v1-krok03-geologie` z `gen-v1-krok02-funkce-sveta` (22f4494). Plán: `04-implementace-generatoru.md`, krok 3. Pravidla: 01 – 1.7, 1.7.1, 1.8, 1.14; 02 – 2.2 (rozhraní `sloupec` / `bod` beze změny). Jan schválil krok 2 2026-11-21 22:55 SEČ.

## PROP (napsáno 2026-11-21 23:00 SEČ, před experimentem)

**Cíl.** Doplnit funkci světa o vrstvy, minci E82, útvary jako světovou funkci přes švy (SDF z hashe mřížky, E84) a vnitřek sopky. Buňka 0,25 m. Přepočítat `propustnost_l_s_herni` v tabulce V1 × 1/4 (Jan 2026-11-21 00:35). Výchozí hra se nemění: nový kód hra nevolá, studijní přepínače `p81_tenke`, `p82_vapenec` a `cavity_one` v pipeline hry zůstanou vypnuté.

**Převzatý kód (nepsat znovu).**
- Vrstvy: `geo_fn.gd` / `strata.gd` / `geo2.targets` (main, E87) — algoritmus mocností a vyklínění jako čistá funkce v metrech, bez mřížky sousedů a bez sloupce 32 m.
- Mince: `G2.coin82` + `lift82` z `e82-vapenec-hladina` (ve hře příznak vypnutý).
- Útvary: jádro `tools/implicit_e84.gd` z `zkusebni-vse` (žíla, čočka/peň, kras, skarn). `cavity_one` se ve V1 nepoužije.
- Tenké vrstvy: logika testu `tenke_e81.gd` (definice vs. zbytky po ořezu).
- Katalogy: `poradi_hornin.json` úrovně 0–40; `minerals.gd`, `hostitele.gd`, `tridy.gd` jako data.

**Plán.** Tabulka V1 (propustnost × 1/4, přemapování krajiny 57–74); vrstvy 0–40 v `geo_vrstvy.gd` (pásma 1.7.1, 1–3 zástupci, vyklínění, min. 0,25 m, max. 1/4 výšky sloupce, tvar podle `vyska_tvar`); mince E82 ve V1 zapnutá; útvary SDF v `utvary.gd` včetně dómu a komínu; vnitřek sopky (průduch 75, slupky); testy 1–6 + regrese kroku 1.

**Testy a kritéria (z 04, krok 3).**
| Test | Prošlo, když |
|---|---|
| 1 řezy | vrstvy spojité přes šev, končí na tělese sopky, průduch dosáhne z = 0 |
| 2 tenké vrstvy | v definici 0 vrstev &lt; 0,25 m; zbytky po ořezu povrchem se vypíší (uvádí se i práh 0,5 m) |
| 3 útvary přes šev | 0 rozdílů; stejná dutina z různých bloků |
| 4 mince E82 | podíl bloků „ano“ 50 % ± statistická odchylka, 3 × 3 i více seedů |
| 5 čas | záznam ms na segment, srovnání s E84 ~ 89 ms |
| 6 determinismus | hash materiálů na mřížce 3 × 3 ze dvou procesů shodný |
| regrese | `voda_e66` 0 neshod, `port_studie --check` 0 změn; `zaklad_v1` – novou referenci zapsat, pokud se otisk změní přepočtem propustnosti |

## Výsledky (2026-11-21 23:25 SEČ)

Kritéria 1–4 a 6 prošla. Čas (test 5) je zaznamenán a je výrazně nad E84 — viz odchylky. Regrese kroku 1 je beze změny. Nový kód hra nevolá, výchozí hra se nemění. Testy běžely lokálně na boxu (Godot 4.7.2 headless, Python 3), bez CI.

### Co vzniklo a odkud je kód
| Změna | Soubor | Odkud |
|---|---|---|
| propustnost × 1/4 na stěnu 0,0625 m² | `godot-prototyp/data/materialy_v1.csv`, `docs/sjednoceni/materialy.csv`, `prepocet_propustnost_l_s.py` | rozhodnutí Jana 2026-11-21 00:35, vzorec 1.8.1 |
| přemapování krajiny 57–74 | `godot-prototyp/data/krajina_remap_v1.csv` | úkol 5 kapitoly 3 / 1.7.1; řádky v tabulce zůstávají |
| vrstvy, mince E82, vnitřek sopky | `scripts/v1/geo_vrstvy.gd` | E87 `geo_fn`/`strata`/`geo2.targets`; E82 `coin82`/`lift82`; 1.14 sopka |
| útvary SDF (žíla, čočka, kras, skarn, dóm, komín) | `scripts/v1/utvary.gd` | E84 `implicit_e84.gd`; dóm (sůl 47) a komín (kimberlit 21) stejným postupem |
| napojení na rozhraní 2.2 | `scripts/v1/svet_fn.gd` (`sloupec.hranice`, `bod`) | krok 2, beze změny podpisů |
| testy a grafy | `tools/geo_v1.gd`, `tools/geo_v1_grafy.py` | kritéria z 04; tenké vrstvy podle E81 |

`k_horniny` z klimatického presetu se uplatní jako kontrast vah hornin `w' = normalize(w^k)`. Výchozí `mirne` má k = 1, takže je identita a výšky i geologie výchozího světa se tím nemění.

### Testy
| Test | Výsledek | Kritérium | Stav |
|---|---|---|---|
| 1 řez šev | 0 neshod sousedů ± 0,25 m na svislém řezu západ–východ středem výchozího 3 × 3; vrstvy sledují tvar a jsou spojité | 0 neshod (mince je po bloku 128 m, případný skok na švu mince by se jen zaznamenal) | prošlo |
| 1 řez masiv | váha masivu 0,562 ve (2008, 1944) m; vrstvy sledují hřbet | řez přes masiv | prošlo |
| 1 řez sopka | průduch id 75 v z = 0,1 i v z = 5 m (3402 buněk průduchu na řezu 0,5 m); vrstvy končí na tělese; slupky lávy/popela v kuželu | průduch k z = 0, vrstvy nepokračují pod tělesem | prošlo |
| 2 tenké vrstvy | 2304 vzorků, 22 395 vrstev. Definice &lt; 0,25 m: **0**. Definice &lt; 0,5 m: 233 (minimum je teď 0,25 m, jen záznam). Po ořezu povrchem &lt; 0,25 m: **8** (štěrk 3 a písek 2, mocnost 0,246–0,250 m, definice 0,25 m). Po ořezu &lt; 0,5 m: 29. | 0 v definici pod 0,25 m; zbytky po ořezu vypsat | prošlo |
| 3 útvary přes šev | 0 neshod na švu bloku i segmentu (stejný světový bod z obou „stran“); 84 útvarů/dutin na řezu švu | 0 rozdílů | prošlo |
| 4 mince E82 | 3 × 3: 5/9 = 0,556. 16 seedů × 8 × 8 bloků: 521/1024 = **0,5088** (oček. 0,5, σ = 0,0156, 3σ = 0,0469) | 50 % ± stat. odchylka | prošlo |
| 5 čas | segment 8 m, 0,25 m / 128 m: **2614 ms** (524 288 buněk, `vypln_sloupec`). Srovnání E84 (0,5 m / 32 m): **521 ms** vs 89 ms. Samotné `hranice` 32 × 32: **531 ms**. Init světa 110 ms. | záznam, srovnání s E84 ~ 89 ms | zaznamenáno (nad E84, viz odchylky) |
| 6 determinismus | SHA-256 materiálů výchozího 3 × 3, krok 2 m v XY a 1 m v Z (4 718 592 buněk) ve dvou procesech: **`59e4569309aa8500`** oba (113 s / 113 s) | shoda dvou procesů | prošlo |
| regrese: `voda_e66` 12 výkopů | d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod | beze změny | prošlo |
| regrese: `port_studie --check` | 82 souborů, 0 změn | 0 změn | prošlo |
| regrese: `zaklad_v1` ve 2 procesech | otisk **cc9e412759114af1** oba, 0 chyb, 0 odchylek perm. Otisk zahrnuje K a hustotu, ne `propustnost_l_s_herni`, proto se po přepočtu × 1/4 nezměnil. Nová reference tedy není potřeba; přepočet je v tabulce V1 i v `docs/sjednoceni/materialy.csv`. | stejný otisk, pokud se hash nemění | prošlo |

Zbytky po ořezu &lt; 0,25 m (8): id 3 (štěrk) nebo 2 (písek), definice 0,25 m, ořezaná mocnost 0,2466–0,2500 m, v okolí (2052–2076, 1860–1900) m. Jde o svrchní vrstvu seříznutou detailem povrchu pod `vyska_tvar`.

### Obrázky
| Soubor | Obsah |
|---|---|
| `godot-prototyp/shots/krok03/rez_sev.png` | svislý řez přes šev bloků, západ–východ, výchozí 3 × 3 |
| `godot-prototyp/shots/krok03/rez_masiv.png` | svislý řez přes masiv |
| `godot-prototyp/shots/krok03/rez_sopka.png` | svislý řez sopkou: průduch k z = 0, slupky, vrstvy končí na tělese |
| `godot-prototyp/shots/krok03/utvary_rez_20m.png` | vodorovný řez 20 m pod povrchem, výřez 3 × 3, krok 2 m |
| `godot-prototyp/shots/krok03/mince_mapa.png` | mince E82 po blocích 128 m (24 × 24), výchozí 3 × 3 orámovaný |
| `godot-prototyp/shots/krok03/cas_segment.png` | čas na segment vs. E84 89 ms |

Data k obrázkům: `shots/krok03/geo_v1.json`, `det_beh1.json`, `det_beh2.json`; binární mřížky mimo git (`/tmp/k3/data`, znovu je vytvoří `geo_v1.gd`).

### Tabulka materiálů
`propustnost_l_s_herni` je K × 0,0625 m² × 1000. Příklady: tráva 6,25×10⁻⁴, ornice 2,31×10⁻⁴, štěrk 6,25×10⁻³, jíl 6,25×10⁻⁹, vápenec 1,87×10⁻⁶, žula 6,25×10⁻¹¹. K a `propustnost_0_1` se nemění. Konflikt lignit 53 / minerál 105 už v tabulce V1 jsou dva řádky; `poradi_hornin.json` hry se neměnil.

Pásma krajiny 57–74 se jako vrstvy V1 nepřiřazují. Přemapování je v `krajina_remap_v1.csv` (např. 57→7, 58→51, 59→52, většina horských pásem → 6). Řádky v CSV zůstávají; odstranit je je otevřené.

Dočasné id sopky (parametry, dokud Jan nerozhodne): `sopka_lava_id=7` (diabaz), `sopka_popel_id=57` (zvětralé vyvřeliny), slupka 5 m, poloměr průduchu `max(2 m, 0,35 × r_kráteru)`.

### Odchylky
- **Čas vs. E84.** Srovnatelný segment (8 m, 0,5 m, výška 32 m) trval 521 ms proti tehdejším 89 ms (asi 5,9×). Už samotné `hranice` na segmentu 8 m při kroku 0,25 m jsou 531 ms (mapa hornin + šum přítomnosti v GDScriptu). Plný sloupec V1 (0,25 m, 128 m, útvary) je 2614 ms. Měření používá `vypln_sloupec` (hranice a seznam útvarů jednou na sloupec). Zrychlení je možné později, v tomto kroku se jen zaznamenává.
- **Vodorovný řez útvarů** je po 2 m, ne po 1 m — 384² dotazů `hranice` by report zdrželo. Řezy svislé jsou po 0,5 m.
- **Mince** se v tomto kroku váže na odhad E82 ( `vyska_tvar` − 2 m), ne na skutečnou hladinu (krok 4). Viz otevřené.
- **k_horniny** je v kroku 3 jen kontrast vah zástupců, a jen když k ≠ 1.

### Otevřené otázky pro Jana (nerozhodnuto)
1. Má se mince po kroku 4 vázat na skutečnou hladinu podzemí, nebo zůstat u odhadu E82 (vyhlazený povrch − 2 m)?
2. Má tabulka dostat samostatná id lávy a popela, nebo stačí parametry 7 a 57?
3. Mají se id 57–74 z tabulky úplně odstranit, nebo jen přemapovat a v geologii nepoužívat (stav teď)?

Krok 4 se nezačíná. Do `main` se nemerguje.
