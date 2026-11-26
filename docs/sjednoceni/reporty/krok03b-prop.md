# PROP – Krok 3b, hostitelské horniny útvarů (A1) a šum mocnosti podle horniny (A10)

**PŘERUŠENO 26. 11. 07:59, přechod na C#**; v 8:04 Jan schválil doporučení a ukotvení středu dómu se dokončilo v GDScriptu (viz Rozhodnutí). Větev `gen-v1-krok03b-hostitele-sum` z `gen-v1-krok03-geologie` (d571153). Napsáno 2026-11-26 ráno SEČ, před změnou kódu. Do `main` ani do větve kroku 3 se nemerguje. Sopku (naklopení vrstev, A11) neřeším – patří Willage-backendu.

## Proč
Jan 2026-11-26 schválil ([pt897u], [pt898u]) dvě úpravy generování vrstev jako doplněk kroku 3: **A1** útvary jen ve vhodné hornině (dnes `host_ok` vrací `true`, takže žíla nebo čočka může vzniknout i v písku či ornici) a **A10** vlastní nepravidelnost mocnosti pro každou horninu (dnes mají všechny jednu oktávu na měřítku 180 m). Vápenec u hladiny (A12) zůstává u odhadu `vyska_tvar − 2 m`. GDScript je teď ověřovací prototyp; ověřené věci se později přepíšou do C#, proto kód krátký, členěný a přenositelný (data v tabulkách, čisté funkce, žádné konstanty podle případu).

## Stav před změnou (zjištěno ve zdrojích)
- `utvary.gd::host_ok`: `skarn/cocka/zila/dome/pipe → true`, `kras → id ∈ {44,49,5} a hloubka ≥ 2 m`. Seznamy hostitelů v kódu natvrdo (`KARST`, `GRANITOID`).
- Katalog: `data/teren/poradi_hornin.json` (klíče, id, `kind`, `hosts_minerals`) a `data/teren/mineraly_hostitele.json` (minerál → hostitelé; čte `scripts/teren/hostitele.gd`). Hostitele **útvarů** (žíla, dóm, komín, skarn) katalog nemá, jen hostitele minerálů. V žíle se přitom s p = 0,08 objeví minerál 8 (měď) nebo 9 (železo) bez ohledu na horninu.
- `geo_vrstvy.gd::_zastupci`: mocnost zástupce `t = lerp(thick0, thick1, _n01("V1_THICK", idx, x, y))`, `_n01` = jedna oktáva hodnotového šumu na buňce 180 m. Podíl pásma = váha / součet vah, mocnost = výška pásma × podíl, clamp [0,25 m; H/4], pod 0,125 m vyklíní; z jsou kumulativní součty mocností (vrstvy se nemohou křížit).

## Plán
1. **A1 – tabulka hostitelů útvarů** `godot-prototyp/data/v1/utvary_hostitele.json`: typ útvaru → klíče hostitelských hornin z `poradi_hornin.json` (+ `min_hloubka_m`) a seznam `nikdy` (ornice, štěrk/písek, spraš, zvětralý jíl). `nikdy` vyhrává nad čímkoli. Nový malý skript `scripts/v1/hostitele_utvaru.gd` (načtení, převod klíč → id, `je_hostitel(typ, id, hloubka)`); `utvary.gd::host_ok` se na něj jen odkáže. Skarn a minerál v žíle se také ověřují (minerál přes `mineraly_hostitele.json` / `hostitele.gd`; není-li hostitelem, zůstane pegmatit).
2. **A10 – tabulka šumu mocnosti** `godot-prototyp/data/v1/sum_hornin_v1.csv`: pro každou horninu měřítko (m), amplituda (0–1 rozsahu `thick0…thick1`), počet oktáv, persistence. Nový skript `scripts/v1/sum_hornin.gd` (fBm z hashe světa; oktáva 0 = původní pole, takže řádek 180 m / 1,0 / 1 oktáva je bitově původní chování). `_zastupci` bere šum odtud; šum přítomnosti (`V1_PRES`) se nemění. Mocnost zůstává součtem mocností, E81 clamp a vyklínění i E82 mince beze změny.
3. **Přepínače** `a1_hostitele`, `a10_sum_hornin` (výchozí zapnuto ve V1 funkci; hra je nevolá). Vypnuté obě = bitově původní krok 3 (kontrola proti d571153) a zároveň „před“ pro obrázky.
4. **Testy** (`tools/geo_v1b.gd`, celý blok 128 m z funkce světa): (a) žádný útvar v nehostiteli a nikdy v ornici/písku/spraši/jílu (nezávislé čtení tabulky v testu; s vypnutým A1 musí test selhat – ověření, že kousá); (b) parametry šumu odpovídají tabulce pro každou horninu + měřená amplituda/četnost podél řezu; (c) žádné křížení vrstev, definice ≥ 0,25 m, součet = H; (d) determinismus dvou procesů a shoda s d571153 při vypnutých přepínačích; (e) původní testy kroku 3 (`geo_v1.gd`).
5. **Obrázky** před/po: svislé řezy mocnostmi, vodorovný řez útvarů (maska hostitel/nehostitel), křivky šumu podle horniny. Do `godot-prototyp/shots/krok03b/`.
6. Report `krok03b.md`, záznam do DENIK.md (blok B).

## Hypotézy a kritéria
- H1: po zapnutí A1 je počet buněk útvaru v nehostiteli 0 (dnes > 0). Očekávám úbytek komínů a dómů uvnitř vrstev, ve kterých je dnes Z-střed mimo hostitele (dóm leží v pásmu krystalinika, ne sedimentů) – zaznamenám objem před/po, i když to bude „záporný“ výsledek.
- H2: každá hornina má měřitelně jinou drsnost/amplitudu; hrubé horniny (slepenec, štěrk) víc zlomů v řezu než jemné (jílovec, břidlice).
- H3: čas `hranice` stoupne úměrně počtu oktáv (max 3×). Zaznamenám.
- Nulový výsledek A1 (žádná změna) nebo neprokazatelná změna A10 se zapíše stejně jako úspěch.

## Mimo rozsah
Naklopení vrstev sopkou (A11), skutečná hladina podzemní vody u mince (zůstává odhad), šum přítomnosti (`V1_PRES`) po horninách, přesun geologie do C#.

## Výsledky
**PŘERUŠENO 26. 11. (07:59 SEČ), přechod na C#.** Jan změnil plán: prototypy se odteď píší celé v C#. GDScriptová implementace A1 a A10 se nedokončuje (zůstává jako ověřená reference chování, bez reportu `krok03b.md`, bez schválení kroku, bez merge). Co je hotové a změřené:

### A1 – hostitelé útvarů (kód + data + test)
- Tabulka `data/v1/utvary_hostitele.json` (klíče hornin z `poradi_hornin.json`; `nikdy` = ornice, štěrk/písek, spraš, zvětralý jíl; kras min. hloubka 2 m), skript `scripts/v1/hostitele_utvaru.gd`, `utvary.gd::host_ok` na něj odkazuje; skarn a minerál 8/9 v žíle se také ověřují (katalog `mineraly_hostitele.json` přes `teren/hostitele.gd`).
- Test `tools/geo_v1b.gd --rezim=hostitele` (nezávislé čtení tabulky), celé bloky 128 m, krok 2 m / 0,5 m, bloky 14–16 × 14–16 (9 bloků): **po: 0 buněk útvaru v nehostiteli, 0 v půdě/písku, 0 pod min. hloubkou, 0 minerálů mimo hostitele. Před (původní kód): 91 300 + 105 401 + 85 059 buněk v nehostiteli (řady 14/15/16), minerály mimo hostitele 229 + 213 + 237, v ornici jen 1 buňka dómu.** Test tedy nad původním kódem selže (kousá).
- **Záporný / překvapivý výsledek:** v výchozím světě se útvary do ornice/písku skoro nedostávaly (1 buňka). Skutečná chyba byla jinde: skarn vznikal u každého kontaktu granitoidu s čímkoli a dóm uprostřed krystalinika. Objem útvarů po A1 (3 bloky řady 14 / 15 / 16, před → po): skarn 91 284 → 22 607 / 94 489 → 9 525 / 94 080 → 26 669; dóm 35 679 → 13 654 / 36 546 → 16 349 / 27 242 → 10 227; komín 3 040 → 3 183 (+5 %), žíla 4 217 → 4 541 (+8 %, už je nepřepisuje skarn), kras beze změny (1 598 / 1 152 / 1 791).
- Dóm: střed Z leží v 0,55–0,75 výšky, tj. většinou v pásmu krystalinika (0,32–0,67), kde sůl není hostitel. Proto dóm ztratil ~60 % objemu. Návrh do C#: ukotvit střed dómu do pásma sedimentů, ne měnit tabulku.

### A10 – šum mocnosti podle horniny (kód + data + test)
- Tabulka `data/v1/sum_hornin_v1.csv` (37 hornin: měřítko, amplituda, oktávy, persistence, profil), skript `scripts/v1/sum_hornin.gd` (fBm, oktáva 0 = původní pole; chybějící řádek = původní 180 m / 1,0 / 1 okt.). Šum přítomnosti `V1_PRES` beze změny. E81 clamp, vyklínění, E82 mince beze změny.
- Test `--rezim=sum`: **PROŠLO**. 37 řádků, 0 bez řádku; parametry v kódu = tabulka; rozsah pole v mezích 0,5 ± amplituda/2; slepenec std 0,125 a 12,3 průchodů/km vs. jílová břidlice 0,063 a 1,7 průchodů/km; 3 oktávy dávají 2× větší drobný detail (druhá diference na 20 m 0,0263 vs 0,0133); původní řádek je bitově původní pole (0 odlišností z 2 000); přepínač vypnut = všude původní parametry; změna tabulky mění hranice (512/512 vzorků).
- Test `--rezim=vrstvy` (4 bloky × 16 384 sloupců po 1 m, 65 536 sloupců, před i po): **0 křížení, 0 mezer, 0 definic < 0,25 m, součet = výška tvaru u všech sloupců**; min. mocnost 0,370 m. Definice nad H/4 (po sloučení tenkých, existující odchylka od E81): před 4 653 z 686 654 vrstev, po 602 z 718 297. E82 mince: vápenec na cíli `vyska_tvar − 2 m` ve 15 584 / 16 384 sloupců před, 16 384 / 16 384 po; závislost na hladině podzemí žádná (`mince82` a `_mince_zvedni` čtou jen x, y, seed a `vyska_tvar`).
- Pozn. k amplitudě: fBm je normalizovaný na [0, 1], takže efektivní rozptyl 3 oktáv je menší než u jedné; „amplituda“ je maximální rozkmit, ne směrodatná odchylka (naměřené std v `shots/krok03b/sum.json`).

### Determinismus
- Otisk bloku 14,14 (xy 2 m, z 1 m, 524 288 buněk): **obě přepínače vypnuté = `72d639d2db974623` = shodně s d571153** (původní kód). a1 zap, a10 vyp `0da762462839bf45`; a1 vyp, a10 zap `5462d544ce64c7f6`; oba zap `c7f3b073c6fce3b8`. Blok 15,15: `5fd263467dd194b4` (oba zap). Dva procesy se stejným otiskem nebyly spuštěny samostatně (kód přerušen); funkce jsou čisté hashe seedu.
- Cena: otisk bloku 128 m (`vypln_sloupec`) 12,3 s před / 12,8 s po (+4 %); čas `hranice` zvlášť neměřen.

### Obrázky (`godot-prototyp/shots/krok03b/`)
`a10_rez_pred_po.png`, `a10_krivky_horniny.png`, `a1_rez_a1_pred_po.png`, `a1_rez_a1b_pred_po.png` (+ `a1_rezy_stat.json`: v řezu blokem 14,14 před 1 756 z 2 833 buněk útvarů v nehostiteli, po 0 z 1 261; v řezu 14,15 před 1 745 z 2 086, po 0 z 394).

### Co přenést do C#
Tabulky `utvary_hostitele.json` a `sum_hornin_v1.csv` jako data beze změny; logika `je_hostitel` / `mineral_ok` (nikdy vyhrává, min. hloubka, hosts `*`); fBm z hash-hodnotového šumu (oktava 0 shodná s původním polem, lakunarita 2, váhy persistence^o, normalizace Σw, `0,5 + (n − 0,5)·amplituda`); testy z `tools/geo_v1b/` jako referenční vektory (otisky výše, `sum.json`, počty buněk útvarů).

### Otevřené otázky pro Jana
Zodpovězeno 2026-11-26 8:04 SEČ ([pt907u] souhlas s doporučeními). Viz následující oddíl.

## Rozhodnutí Jana 2026-11-26 8:04 SEČ
Jan souhlasil s doporučeními ([pt907u]). Přepis do C# jen tam, kde bude potřeba, postupně nebo při finalizaci ([pt906u]).

1. **Zvětralý jíl (4) a spraš (54) zůstanou v seznamu `nikdy`.** Tabulka `utvary_hostitele.json` beze změny.
2. **Skarn zůstane jen v karbonátech a vápnitých metamorfitech** (hlubinný a jeskynní vápenec, dolomit, amfibolit, svor, fylit, přechodová zóna). Menší objem je v pořádku. Tabulka beze změny.
3. **Střed dómu (sůl 47) se ukotví do pásma sedimentů.** Implementováno v GDScriptu (`utvary.gd`, parametr `dom_pasmo_sedimenty`, výchozí zapnuto): střed Z = 15–85 % výšky pásma sedimentů, podíly pásem stejné jako `geo_vrstvy.PASMA` / `pasmo_*`. Vypnutý parametr = původní vzorec 0,55–0,75 výšky (pro srovnání). Výsledky níže.
4. **Tabulka `sum_hornin_v1.csv` je schválená jako výchozí hodnoty**, doladí se podle vzhledu.
5. **Šum přítomnosti `V1_PRES` se zatím nemění.**

### Dóm v sedimentech – výsledky
Doplněno 2026-11-26 8:12 SEČ. Stejné 9 bloků 128 m (14–16 × 14–16), krok 2 m / 0,5 m jako A1.

Objem dómu (buňky, A1 zapnuté):

| řada bloků | před A1, starý střed | po A1, starý střed | po A1, střed v sedimentech | v pásmu / mimo pásmo |
|---|---|---|---|---|
| 14 | 35 679 | 13 654 | **30 640** | 28 783 / 1 857 |
| 15 | 36 546 | 16 349 | **33 270** | 31 780 / 1 490 |
| 16 | 27 242 | 10 227 | **25 215** | 24 692 / 523 |
| **součet** | **99 467** | **40 230** (40 %) | **89 125** (90 % původního, 2,2× proti starému středu) | 85 255 / 3 870 (4,3 %) |

Po ukotvení: **0 buněk dómu v nehostiteli** (i 0 v půdě, 0 pod min. hloubkou). „Mimo pásmo“ (4,3 %) jsou konce elipsoidu, které po šumu mocnosti pořád leží v hostitelské sedimentární vrstvě (skutečné hranice pásma nejsou přesně 0,67–0,92). Dóm tedy leží v hostiteli; ztráta objemu proti stavu bez A1 je teď ~10 % (ořez okrajů), ne ~60 %.

Řez: `godot-prototyp/shots/krok03b/a1_rez_dom_pred_po.png` (y = 1917 m, střed 2069, 1917; v řezu 1 588 → 2 768 buněk útvarů) a `a1_rez_dom2_pred_po.png` (y = 1943 m).

### Testy po ukotvení dómu (2026-11-26 8:12 SEČ)
- **A1** (`geo_v1b --rezim=hostitele`, 9 bloků): PROŠLO, kousá nad původním kódem. Po (nový střed): 0 porušení hostitele / nikdy / hloubky / minerálu. Objem viz tabulka výše.
- **A10** (`--rezim=sum`): PROŠLO, čísla stejná jako před úpravou dómu (šum vrstev se nemění).
- **Vrstvy** (`--rezim=vrstvy`, 65 536 sloupců): PROŠLO, 0 křížení, 0 mezer, 0 definic < 0,25 m, součet = výška tvaru, mince na cíli 16 384 / 16 384 (čísla vrstev stejná jako před úpravou dómu – dóm není vrstva).
- **Původní testy kroku 3** (`tools/geo_v1.gd --rezim=vse`, výchozí a1+a10+dóm v sedimentech): **0 chyb**. Řez šev 0 neshod; sopka průduch id 75 k z = 0, 3 402 buněk, těleso v 5 m id 75; tenké: definice < 0,25 m **0**, definice < 0,5 m 366, po ořezu < 0,25 m 5, < 0,5 m 8; útvary přes šev 0 neshod (28 útvarů na řezu); mince 521/1024 = 0,5088 (3σ ok). Čas: segment 8 m / 0,25 m / 128 m **3 051 ms** (krok 3: 2 614 ms); srovnání E84 606 ms vs 89 ms; `hranice` 774 ms (krok 3: 531 ms).
- **Determinismus dvou procesů** (`geo_v1.gd --rezim=det`, mřížka 3 × 3, 2 m / 1 m, 4 718 592 buněk): oba **`bbdc0afa877d6c2e`** (128 s / 127 s). Otisk je jiný než d571153 (`59e4569309aa8500`) i než krok 3b před ukotvením dómu – očekávané (A1+A10+nový střed). Při vypnutých přepínačích a `dom_pasmo_sedimenty=false` zůstává shoda s d571153 (`72d639d2db974623` na bloku 14,14) z předešlého běhu.

Do `main` ani do větve kroku 3 se nemerguje.
