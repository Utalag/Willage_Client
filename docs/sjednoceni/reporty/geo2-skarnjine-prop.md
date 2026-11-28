# PROP GEO2: prošetření 2 otevřených buněk `SkarnJine` (blok 3904, 1344; Jan t1046u, bod 1)

*Zapsáno před experimentem 2026-11-28 12:30 (Europe/Prague). Větev `geo2-skarnjine` z `geo2-v8-rozdily`.*

## Výchozí stav (z V8)
Z 1,476 mld. porovnaných buněk (11 bloků, 1 seed) zůstávají 2 buňky v blok (3904, 1344) [hornatina / strmé] s příčinou `SkarnJine`, verdikt **otevřené**: GEO1 = skarn (zdroj Skarn), GEO2 = vrstva (karbonát), bez příznaku odhadu hranice.
V nezávislém měření kvality skarnu to odpovídá 2 „dírám v pásmu karbonátu“ GEO2 (0,0002 %). Kritérium smazání vyžaduje 0 otevřených, takže 2 buňky blokují.

## Hypotézy (od nejpravděpodobnější)
1. **Hranice pásma** (D ≈ 0,625 m = dolní mez kontraktního pásma): rozdíl dvou implementací vzdálenosti k jistému pásmu skarnu (GEO1 `Utvary.SkarnD` × GEO2 `KontaktniPasmo`), mimo tolerančních větví klasifikátoru (D přesně na hranici, nebo těsně pod ní).
2. **Povrch / sopka / dutina** poblíž buňky: GEO2 vrací vrstvu, protože prefix událostí (kras, těleso) mění stav a skarn se nevyhodnotí.
3. **Skutečná chyba GEO2**: skarn v pásmu, ale `KontaktniPasmo.Plati` vrátí false (strana, `hostitel_okoli`, e_k).

## Postup
1. Do V8 doplnit (jen nástroj) výpis souřadnic otevřených buněk (`V8Blok.Otevrene`).
2. Spustit V8 na bloku (3904, 1344), vypsat 2 buňky; ladicí výpis `GEO2V8L` (D, odhad, pasmo.Plati, běhy sloupce).
3. Určit příčinu: pokud chyba GEO2 → oprava + regresní test; pokud jde o legitimní tolerance / rozdíl dvou správných definic → zařadit jako novou příčinu s verdiktem a vysvětlením (Jan potvrdí, pokud mění sémantiku).
4. Ověřit celou sadu (`744/744` + nový test), otisky GEO1 beze změny, V8 na bloku znovu (0 otevřených).

## Kritéria
- Otevřených buněk v bloku (3904, 1344) = 0 po opravě nebo zařazení s vysvětlením.
- Žádný jiný blok se nezhorší (V8 na ostatních se neřeší hned; opravená logika nesmí změnit výsledek GEO2 mimo ověřené buňky bez vysvětlení: otisk GEO2 bloku před × po).
