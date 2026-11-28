# PROP GEO2: přeměření výkonu GEO1 / K3 / výchozí GEO2 (Jan t1044u, bod 3)

*Zapsáno před experimentem 2026-11-28 ~03:10. Větev `geo2-vykon-mereni` z `geo2-vychozi`. Kontrakt V6: čas na boxu je jen doplňkový (primární je odstraněná práce);
měří se na boxu, NE na počítači Jana (vyžadovalo by schvalování).*

## Zátěž boxu (zjištěno před měřením, 2026-11-28 03:09)
Cizí procesy `grep` PID **295547** a **297041** (`grep -o … jc_AI%20developer.html`) běží od 2026-11-27 ~ 21:00, každý ~ 100 % jednoho jádra (RSS 4,9 GB a 0,6 GB). Nejsou moje,
**nezabíjím je**, jen zaznamenávám. Box má 8 jader, takže 8 vláken měřených cest sdílí ~ 6 volných jader; load average před měřením bývá 4–8.
Nástroj zaznamenává před každým blokem `loadavg` a CPU cizích procesů a po měření uvádí rozptyl.

## Co se měří
Pro každý blok 128 m (stejných 11 bloků jako V8: 5 náhodných, 2 šev mince, 2 hornatina / strmé, svah a okraj sopky), sloupce po 0,25 m, z po 0,25 m, 512 buněk na sloupec:

| Cesta | Definice |
|---|---|
| **GEO1** | `GeoVrstvy.VyplnSloupec` (stará cesta), `Klon()` na vlákno |
| **K3** | kontext bloku s pevnou mřížkou hranic 0,5 m, `Sloupec` po bodech (`SloupecPoBodech`, tj. stav kódu po K3: bod po buňce) |
| **GEO2 výchozí** | kontext se zaručenou adaptivní mřížkou, `Sloupec` z běhů (výchozí od `geo2-vychozi`) |
| **GEO2 + kontakt rychle** | totéž s úpravou z bodu 2 (`geo2-kontakt-rychle`), jen jako samostatný binární běh (dočasný merge, nepushuje se) |

Čas = kontext (sestavení, u GEO1 žádný) + sloupce, zvlášť i celkem. Každá cesta v každém bloku **R = 5 opakování** (+ 1 zahřívací vyřazené), cesty se střídají (rotace pořadí),
aby posun zátěže nezvýhodnil jednu z nich. Uvádí se **medián, min, max a relativní rozptyl** ((max − min) / medián) a poměr mediánů proti GEO1 a proti K3.
Navíc 1 vlákno na 2 blocích (sloupce po 0,5 m, R = 3), aby se oddělil vliv cizí zátěže.

## Kritéria / co z toho plyne
- Výchozí GEO2 ne výrazně pomalejší než K3 (Jan t1042u). Cílový práh z V8 návrhu: ≤ ×1,5 GEO1.
- Rozptyl < 15 % → čísla jsou vypovídající; vyšší rozptyl se uvede a výsledek označí jako orientační.
- Kontrola správnosti: kontrolní součet výstupu každé cesty se v opakováních shoduje (determinismus).

## Rizika
- Cizí `grep` (2 jádra) zkresluje čas; střídání cest a medián z 5 opakování to zmírní, ne odstraní.
- Paměťová zátěž (cizí 4,9 GB RSS) – box má 15 GB, měřený proces potřebuje < 1 GB (sloupce se nekladou do paměti, jen kontrolní součet).


## Výsledky (2026-11-28, zápis 04:10 Europe/Prague)

Celá sada testů na větvi po měření: **742/742**, otisky GEO1 (krok 5, G-1, G-3) beze změny. Měřeno jen na boxu, ne na Janově PC. Nástroj `--jen=GEO2VYKON` (střídání cest, 1 zahřívací vyřazené, medián / min / max / rel. rozptyl, kontrolní součet). Surová data a logy: `docs/sjednoceni/reporty/geo2-vykon-data/`.
Cizí `grep` PID **295547** a **297041** běžely celou dobu, každý ~99 % jádra (součet ~198–199 % CPU). **Nezabity.** Load average 5,26–10,44 (při 8vláknovém běhu typicky 7–10). Box 8 jader, měřená cesta tedy sdílí zhruba 6 volných.

Časy běhů: výchozí 8 vláken 03:08–03:46; GEO2 + kontakt rychle (dočasný merge `geo2-kontakt-rychle` do detached worktree, nepushuje se) 03:46–04:03; 1 vlákno (jen výchozí GEO2, krok 0,5 m, R = 3) 04:03–04:07.

**Determinismus:** kontrolní součet každé cesty stejný ve všech opakováních (33 + 33 + 3 + 3 assercí, 0 chyb).

Čas v sekundách, medián z R = 5 (resp. 3 u 1 vlákna). Relativní rozptyl = (max − min) / medián. Práh z návrhu V8: výchozí GEO2 ≤ ×1,5 GEO1. Čas je podle kontraktu V6 jen doplňkový.

### A. Výchozí GEO2, 8 vláken, sloupce po 0,25 m

| Blok | Kategorie | GEO1 | K3 | GEO2 výchozí (kontext + sloupce) | K3/GEO1 | GEO2/GEO1 | GEO2/K3 | ×1,5 |
|---|---|---:|---:|---|---:|---:|---:|---|
| (1024, 512) | náhodné / skarn | 3,15 [3,07–3,71] 20 % | 5,93 [5,47–6,51] 18 % | 7,44 = 1,86+5,50 [6,75–8,09] 18 % | 1,88 | 2,36 | 1,25 | nad |
| (3000, 2000) | náhodné | 3,88 [3,64–4,08] 12 % | 6,46 [5,65–64,73] 915 % † | 4,61 = 1,63+2,98 [4,32–4,93] 13 % | 1,67 | 1,19 | 0,71 | ok |
| (0, 0) | náhodné | 3,98 [3,26–4,13] 22 % | 4,39 [4,22–18,06] 315 % † | 5,15 = 1,98+3,19 [4,94–5,79] 17 % | 1,10 | 1,30 | 1,17 | ok |
| (2048, 1024) | náhodné | 3,54 [3,18–3,85] 19 % | 4,07 [3,99–4,61] 15 % | 4,98 = 1,91+3,05 [4,23–5,09] 17 % | 1,15 | 1,41 | 1,22 | ok |
| (512, 3072) | náhodné | 3,14 [3,06–3,65] 19 % | 4,35 [4,06–4,45] 9 % | 4,64 = 1,86+2,70 [4,27–4,77] 11 % | 1,39 | 1,48 | 1,07 | ok |
| (1856, 1024) | šev mince x = 1920 | 3,49 [3,27–3,68] 12 % | 4,79 [4,27–6,09] 38 % | 4,69 = 1,75+2,85 [4,36–4,95] 12 % | 1,37 | 1,34 | 0,98 | ok |
| (1984, 2560) | šev mince x = 2048 | 3,99 [3,75–4,19] 11 % | 6,33 [6,10–47,14] 649 % † | 7,92 = 1,74+6,18 [7,72–8,50] 10 % | 1,58 | 1,98 | 1,25 | nad |
| (1664, 1728) | hornatina / strmé | 3,39 [2,69–3,42] 22 % | 12,06 [11,45–12,84] 11 % | 9,14 = 1,81+7,24 [8,58–10,11] 17 % | 3,55 | 2,69 | 0,76 | nad |
| (3904, 1344) | hornatina / strmé | 3,52 [3,33–3,76] 12 % | 5,93 [5,79–6,37] 10 % | 10,53 = 1,61+8,90 [10,20–11,23] 10 % | 1,68 | 2,99 | 1,77 | nad |
| (1673, 1705) | svah sopky | 2,97 [2,78–3,16] 13 % | 10,92 [10,20–11,45] 11 % | 6,57 = 1,73+4,61 [6,00–101,53] 1453 % † | 3,68 | 2,22 | 0,60 | nad |
| (1710, 1705) | okraj sopky | 3,75 [3,29–4,02] 19 % | 9,65 [9,09–10,02] 10 % | 6,19 = 2,03+4,16 [5,80–15,17] 152 % † | 2,58 | 1,65 | 0,64 | nad |

† špička v jednom z 5 opakování (pravděpodobně GC / plánovač při 8 vláknech + 2 cizích jádrech). Medián špičku odřezává; bez ní by rozptyl byl v desítkách procent jako u ostatních. 1vláknové běhy špičky neměly.

**Splnění prahu ×1,5 GEO1:** 5 z 11 bloků (náhodné kromě skarnového, šev 1856,1024). **Nad prahem 6 z 11:** skarn (1024, 512) ×2,36; šev 1984,2560 ×1,98; hornatina ×2,69 a ×2,99; svah sopky ×2,22; okraj sopky ×1,65.

**Výchozí GEO2 proti K3:** na 8 z 11 bloků ≤ ×1,25; na hornatině (1664, 1728) a na sopce rychlejší než K3 (×0,60–0,76), protože K3 tam je pomalé (10–12 s). Výjimka (3904, 1344): ×1,77 (sloupce 8,90 s proti K3 5,50 s).

### B. GEO2 + kontakt rychle, 8 vláken, sloupce po 0,25 m

Stejný protokol, binárka z dočasného merge (nepushováno). Load na začátku 9,14 (vyšší než u výchozího běhu, který začínal na 6,04) — poměry vůči GEO1 mezi běhy A a B proto srovnávat opatrně; férovější je absolutní čas GEO2 a čas sloupců.

| Blok | GEO1 | K3 | GEO2+kontakt (k+s) | GEO2/GEO1 | GEO2/K3 | ×1,5 | GEO2 výchozí → kontakt (zrychlení) |
|---|---:|---:|---|---:|---:|---|---|
| (1024, 512) skarn | 3,80 [2,94–3,92] 26 % | 5,44 [5,43–6,10] 12 % | 5,45 = 1,78+3,68 [4,95–5,87] 17 % | 1,43 | 1,00 | ok | 7,44 → 5,45 (×1,37); sloupce 5,50 → 3,68 |
| (3000, 2000) | 3,78 | 5,69 | 4,42 = 1,58+2,84 | 1,17 | 0,78 | ok | 4,61 → 4,42 (šum) |
| (0, 0) | 3,22 | 5,21 | 4,63 = 1,86+2,77 | 1,44 | 0,89 | ok | 5,15 → 4,63 |
| (2048, 1024) | 2,95 | 3,93 | 4,12 = 1,52+2,60 | 1,40 | 1,05 | ok | 4,98 → 4,12 |
| (512, 3072) | 3,01 | 5,57 | 4,73 = 1,78+2,79 | 1,57 | 0,85 | nad | 4,64 → 4,73 (šum; poměr přeskočil práh kvůli rychlejšímu GEO1, ne pomalejšímu GEO2) |
| (1856, 1024) | 2,96 | 3,85 | 4,05 = 1,49+2,58 | 1,37 | 1,05 | ok | 4,69 → 4,05 |
| (1984, 2560) | 3,82 | 6,62 | 7,22 = 1,74+5,35 | 1,89 | 1,09 | nad | 7,92 → 7,22 |
| (1664, 1728) | 2,72 | 10,98 | 8,28 = 1,79+6,42 | 3,04 | 0,75 | nad | 9,14 → 8,28; poměr horší kvůli rychlejšímu GEO1 (3,39 → 2,72) |
| (3904, 1344) | 3,32 | 5,43 | 9,33 = 1,61+7,72 | 2,81 | 1,72 | nad | 10,53 → 9,33 |
| (1673, 1705) | 2,69 | 11,04 | 5,97 = 1,58+4,34 | 2,22 | 0,54 | nad | 6,57 → 5,97 |
| (1710, 1705) | 3,07 | 9,64 | 5,55 = 1,60+3,85 | 1,81 | 0,58 | nad | 6,19 → 5,55 |

**Hlavní výsledek bodu 2 potvrzen novým protokolem:** skarnový blok (1024, 512) zlevnil sloupce 5,50 → 3,68 s, celek 7,44 → 5,45 s, poměr k GEO1 ×2,36 → ×1,43 (práh splní), k K3 ×1,25 → ×1,00. Kontext téměř stejný (1,86 → 1,78 s) — zkrat je ve vyhodnocení pásma, ne v mřížce. Ostatní bloky bez systematického zrychlení sloupců (očekáváno: zkrat cílí na kontaktní pásmo).

Po kontaktu práh ×1,5 GEO1: 5 z 11 (skarn nově ok; (512, 3072) nově těsně nad — to je šum mezi běhy, ne regress). Hornatina a sopka zůstávají nad prahem; vůči K3 jsou ale často rychlejší.

### C. 1 vlákno, sloupce po 0,5 m, R = 3 (jen výchozí GEO2)

Rozptyl 1–4 % — čísla jsou vypovídající, cizí zátěž tady skoro nevidět.

| Blok | GEO1 | K3 (k+s) | GEO2 výchozí (k+s) | K3/GEO1 | GEO2/GEO1 | GEO2/K3 |
|---|---:|---|---|---:|---:|---:|
| (1024, 512) | 3,81 [3,73–3,87] 4 % | 7,81 = 1,74+6,08 [7,76–7,83] 1 % | 14,67 = 7,56+7,12 [14,55–14,84] 2 % | 2,05 | 3,85 | 1,88 |
| (1664, 1728) | 3,42 [3,39–3,43] 1 % | 16,25 = 1,79+14,44 [16,22–16,39] 1 % | 16,48 = 7,70+8,78 [16,32–16,80] 3 % | 4,75 | 4,82 | 1,01 |

Kontext adaptivní mřížky je při 1 vlákně 7,56–7,70 s proti ~1,6–2,0 s při 8 vláknech (kontext se paralelizuje). Poměry vůči GEO1 jsou horší než u 8 vláken i proto, že krok 0,5 m zmenší práci ve sloupcích a kontext pak tvoří větší podíl. Na strmém bloku je výchozí GEO2 prakticky stejně rychlé jako K3 (×1,01); na skarnovém je pomalejší (×1,88) — souhlasí s 8vláknovým výsledkem před zlevněním kontaktu.

### Negativa a šum
- Práh ×1,5 GEO1 výchozí GEO2 **na všech blocích nesplňuje** (6 z 11 nad, nejhůř hornatina ×2,7–3,0). Po zlevnění kontaktu skarnový blok práh splní, hornatina a sopka ne.
- Kritérium smazání GEO1 z V8 („výkon ≤ ×1,5 GEO1“) tedy výchozí GEO2 samo o sobě zatím nesplňuje.
- Několik 8vláknových opakování mělo extrémní špičky (K3 až 64,7 s při mediánu 6,5 s; GEO2 až 101,5 s při mediánu 6,6 s). Medián je použitelný, min/max a rozptyl u těchto řádků vypovídající nejsou. Při 1 vlákně špičky nebyly.
- Dva po sobě jdoucí 8vláknové běhy (výchozí vs. kontakt) mají jiný load (6 → 9) a tím i jiný čas GEO1; poměr GEO2/GEO1 mezi běhy A a B proto není čistý A/B test, jen orientační. Absolutní čas GEO2 na skarnu je robustnější důkaz zrychlení.
- Cizí `grep` (2 jádra, jeden s RSS ~5 GB) zkresluje 8vláknová čísla; 1vláknová jsou čistší, ale měří jiný krok (0,5 m) a neměří cestu s kontaktem.

### Závěr pro rozhodnutí
- Výchozí GEO2 je na rovině/náhodných blocích blízko prahu nebo pod ním (×1,19–1,48) a srovnatelné s K3 (×0,71–1,25). Na skarnu bez zkratů pásma nad prahem (×2,36, ×1,25 K3); po `geo2-kontakt-rychle` ×1,43 a ×1,00 K3.
- Na hornatině a sopce je GEO2 pomalejší než GEO1 (×1,65–2,99), ale často rychlejší než K3 (K3 tam trvá 10–12 s). Výjimka (3904, 1344): GEO2 je pomalejší i proti K3 (×1,77).
- Sloučení zlevnění kontaktu do výchozí větve má smysl (skarn, bitově stejný výsledek z bodu 2). Práh ×1,5 GEO1 na všech blocích tím ale nespadne. Jestli práh zůstane podmínkou smazání GEO1, je potřeba ještě zlevnit hornatinu / (3904, 1344), nebo práh upravit (např. ≤ ×1,5 GEO1 na náhodných + ≤ K3 na strmých).

**Poznámka (Jan t1047u, 2026-11-28):** limit ×1,5 GEO1 je jen **doporučení**, ne pevné kritérium smazání staré cesty. Čísla výše se berou jako vzdálenost od doporučení; profil a návrhy úspor viz `geo2-profil-prop.md` (větev `geo2-profil`).
