# Studie těžby a rozkladu hornin

Samostatná studie (Jan 19. 11. 2026 13:55: „Těžbu a rozklad hornin dej do samostatné studie.“).
Není to součást běhu vody v blueprint-studii. Herní kód se tu zatím nemění.

Číslování záznamů: **T01, T02, …**. První záznam je **T01 (dříve E65 v blueprint-studii)**.

Stav: návrh T01 a T02, čeká na Jana. Zdroje jsou značky [n] v `ZDROJE.md`.

## Cíl

Navrhnout, jak se ve hře budou chovat horniny při těžbě a zpracování: jak jsou tvrdé, čím se kopou, co z nich padne, jak se suroviny poznávají a jak se z nich dělají výrobky.

## Rozsah

- vlastnosti hornin (Mohs, UCS, hustota, CAI / abraze, sypké vs soudržné)
- těžba a třídy nástrojů (ruka, kámen, bronz, železo, ocel, volitelně trhaviny)
- rozklad horniny na suroviny (výchozí podíly, přepis procent ve vrstvě blueprintu)
- Mineralogie a identifikace (neznámý minerál → znaky → obě jména)
- kvalita krystalů a zpracování (brousit, drtit, pálit, destilovat, rozložit, tavit)
- katalog materiálů a výrobků a koupitelné recepty s laděním kvality ve výrobní jednotce

## Mimo rozsah

- vodní vlastnosti a režimy průsaku (zůstávají v `../sdilene/materialy_voda.json`, `../sdilene/horniny_voda.json` a v blueprint-studii)
- generování masivu a pořadí vrstev (`../blueprint-studie/data/poradi_hornin.json`)
- počasí, vegetace, cesty

## Spuštění

```
python3 tools/horniny65.py
python3 tools/strom02.py
```

`horniny65.py` přegeneruje `data/horniny_tezba_navrh.json` a `shots/65_horniny_tezba.png`.
`strom02.py` sestaví `data/strom_rozkladu.json`, `navrhy/strom-hornin.md` a `shots/T02_strom_*.png` a zkontroluje konzistenci stromu.
Sdílené vodní tabulky nesahá. Graphviz (`dot`) v prostředí není, obrázky kreslí matplotlib.

## Soubory

| cesta | obsah |
|---|---|
| `README.md` | cíl, rozsah, otevřené otázky |
| `PROP.md` | T01 (dříve E65), T02 strom rozkladu |
| `DENIK.md` | A/B/C, záznamy T01 a T02 |
| `ZDROJE.md` | [1]–[28] T01; [29]–[38] T02 složení |
| `data/horniny_tezba_navrh.json` | návrh tabulky (sem patří; není ve `sdilene/`) |
| `tools/horniny65.py` | generátor tabulky a grafu |
| `shots/65_horniny_tezba.png` | Mohs × UCS a pevnost podle nástroje |
| `navrhy/horniny-vlastnosti-tezba.md` | návrh modelu těžby a zpracování |
| `navrhy/katalog-materialu.md` | výrobky, jednotky, laditelné parametry, recepty |
| `data/strom_rozkladu.json` | T02 strom: uzly a hrany (složení, výnosy, zpracování) |
| `tools/strom02.py` | sestavení stromu, validace, mermaid, obrázky |
| `navrhy/strom-hornin.md` | český strom po skupinách (mermaid) |
| `shots/T02_strom_*.png` | přehled a detaily složení / výnosů / zpracování |

## Rozhodnutí a hypotézy v T01

Rozhodnuto:

- 17. 11. 2026 17:53: výnos kopání je vždy 1 blok materiálu + šance na nález.
- 19. 11. 2026 13:23: každá hornina má seznam surovin; blueprint může přepsat podíly (součet 100 %, jen povolené suroviny).
- 19. 11. 2026 13:31: po identifikaci zůstanou obě jména; vlastní název může hráč smazat.

Hypotézy:

- 13:27 Mineralogie a rozklad při zpracování.
- 13:33 kvalita krystalů, broušení / drcení / destilace, chemie odděleně.
- 13:36 katalog výrobků (drcený křemen → sklo).
- 13:39 koupitelný recept dá průměr; ve výrobní jednotce lze ladit ke skrytému optimu.

## Otevřené otázky pro Jana

1. Kopání dvoukrokově (1 buňka, pak zpracování), nebo rozklad hned při kopání (hypotéza 13:27)?
2. Varianta času nástrojů A (brána tříd), B (čas podle síly), C (práce / energie), nebo hybrid A+B?
3. Měřítko času: historické × 144, nebo kratší `t_navrh_s` ke hře?
4. Mají ve hře být bronz a trhaviny jako stupně nástrojů?
5. Má kvalita výnosu (přepis podílů, kvalita krystalů) ovlivnit raritu-v2?
6. WVB1: souhlasí samostatné pole `yield_overrides`?
7. Mineralogie: třídy, body, nebo hybrid?
8. Jsou znalosti jen u postavy, nebo je může sdílet vesnice?
9. Kvalita krystalů 0–100 a cena ~ kvalita² vyhovuje, nebo jiné měřítko?
10. Mají do katalogu přibýt reaktanty jako rumělka, cín a olovo, nebo stačí později?
11. Má prach / ztráta při trhavinách a broušení být použitelný materiál, nebo jen úbytek?
12. Recepty (13:39): odemknou se natrvalo? Optimum skrýt úplně, nebo ukázat rozmezí? Sdílet ve vesnici?
13. Které výrobky jsou od začátku (vápno, malta, cihla, sklo, měď, železo) a které až později (cement, porcelán, ocel, koks)?
14. Mají mít sklářství, hrnčířství, hutnictví a zednictví vlastní dovednosti, nebo stačí Kamenictví + Chemie + Kovářství?

15. Má se typické minerální složení stát vlastní vrstvou znalostí (Mineralogie), nebo ve hře stačí výnos surovin z T01?
16. Mají olovo (galenit) a rumělka dostat vlastní ložiska, nebo zůstanou jako mezera v katalogu?
17. Má se `ruda_vzacne` rozdělit na Li / Sn / Ta?
18. Je 20 ‰ ryzího zlata ve složení buňky přijatelná abstrakce, nebo má složení zůstat u křemene a pyritu a kov jen jako kusový nález?
