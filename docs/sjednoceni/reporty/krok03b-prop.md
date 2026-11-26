# PROP – Krok 3b, hostitelské horniny útvarů (A1) a šum mocnosti podle horniny (A10)

Větev `gen-v1-krok03b-hostitele-sum` z `gen-v1-krok03-geologie` (d571153). Napsáno 2026-11-26 ráno SEČ, před změnou kódu. Do `main` ani do větve kroku 3 se nemerguje. Sopku (naklopení vrstev, A11) neřeším – patří Willage-backendu.

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
(doplním po experimentu)
