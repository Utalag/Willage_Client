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

## Výsledky (2026-11-28 12:40, Europe/Prague)

**Příčina (změřeno, obě buňky):** není to chyba GEO2 vůči kontraktu. Podmínku kontaktu 2.5 `d̃ ≤ w ∧ strana ∧ hostitel_okoli(q′)` splňují strana (vně granitu) i šířka (D = 0,412 a 0,341 m, w = 1,436 a 1,729 m, bez odhadu), selhává jen **`hostitel_okoli` v q′ = π + η·u** (R5, η = 0,125 m).

| | buňka 1 | buňka 2 |
|---|---|---|
| souřadnice | (3942,625; 1378,875; 37,125) | (3944,125; 1382,125; 37,375) |
| GEO1 / GEO2 | skarn / cave_limestone | skarn / cave_limestone |
| sloupec buňky (GEO1 vrstvy) | orthogneiss [24,06; 30,36], **granite [30,36; 36,67]**, cave_limestone [36,67; 41,92] | granite [30,62; 36,995], cave_limestone [36,995; 42,13] |
| nejbližší bod plochy π | (3942,500; 1378,981; 36,747), D = 0,412 m | (3944,003; 1382,213; 37,069), D = 0,341 m |
| q′ (xy) | (3942,462; 1379,014) | (3943,958; 1382,245) |
| sloupec v q′ | **granite [24,13; 30,45], orthogneiss [30,45; 36,77]**, cave_limestone | stejný jev |
| materiál v q′ | orthogneiss → filtr `granite…` neprojde | orthogneiss |

Mapa hornin má v těchto místech boční hranici: v sloupci buňky je ve vrstvě pod vápencem granit, o 0,16 m vedle je na stejné hloubce ortorula (pořadí granit / ortorula se prohodí). Plocha cíle (vrh granitu) tam končí; nejbližší bod π leží na jejím okraji a směr `u = (π − q)/D` míří šikmo přes okraj, takže q′ po 0,125 m skončí už v ortorule. GEO1 měří jen svislou vzdálenost ve vlastním sloupci (0,457 m nad granitem) a skarn dá.

**Verdikt:** záměrné chování kontraktu (R5) na okraji plochy cíle, ne chyba implementace. Zařazeno jako nová příčina `SkarnHostitelOkoli` (verdikt „dle kontraktu“). Oprava kódu GEO2 **nebyla provedena**, protože by změnila definici q′ v kontraktu (to je rozhodnutí Jana, viz níže).

**Změny:** klasifikátor V8 (`V8Pricina.cs`: příčina `SkarnHostitelOkoli`, funkce `HostitelOkoliSelhal` – silný test: strana a šířka platí a `KontaktniPasmo.Plati` přesto vrací false), nástroj V8 vypisuje souřadnice otevřených buněk, ladicí výpis `GEO2V8L` rozšířen o rozbor hostitele q′ a zásobníků. **Produkční kód GEO2 beze změny.**

**Regresní test** `TestyGeo2V8.RegreseSkarnJine` (v režimu `GEO2`, `GEO2V8R` i v celé sadě): obě buňky GEO1 skarn / GEO2 karbonát, D < 0,625 m bez odhadu, pásmo neplatí; raster == Bod; vzorek bloku (3904, 1344) po 2 m (2,10 mil. buněk, 23 880 různých) má **0 otevřených** buněk.

**V8 blok (3904, 1344) znovu:** 134 217 728 buněk, různých 1 530 174 (1,1401 %), zlepšení 1 178, dle kontraktu 1 485 155 (z toho `SkarnHostitelOkoli` 2), tolerance 43 841, **otevřené 0**.
Nezávislé měření kvality skarnu stále hlásí 2 „díry v pásmu karbonátu“ GEO2 (0,0015 % karbonátu v pásmu 136 069), protože nepočítá `hostitel_okoli`; jsou to tytéž 2 buňky.

## Rozhodnutí pro Jana
Kontrakt 2.5 / R5 to dovoluje (tento okraj je dán definicí q′ po 0,125 m směrem k π). Chceš to nechat (2 buňky z 1,48 mld.; skarn tam chybí do 0,4 m od granitu na okraji plochy), nebo změnit definici q′ tak, aby `u` byla normála plochy v π (pak by q′ zůstalo v hostiteli a „díry“ by zmizely, změna kontraktu a nová měření V3/V8)? Doporučení: nechat, dokud jiné seedy neukážou víc takových buněk.
