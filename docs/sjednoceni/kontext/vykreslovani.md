# Vykreslování dat generátoru – kontext pro diskuzi (2026-11-23)

Projekt Willage: hra s plovoucími ostrovy (Godot 4.7, GDScript, později server v C#). Datový model viz `datovy-model.md`.

## Shrnutí dat
- Svět je deterministická funkce ze seedu (max 4096 × 4096 m), neukládá se. Ostrov je seznam vložených blueprintů (bloky 128 m) s otočením, zrcadlením a výškovým posunem; výchozí ostrov 3 × 3 bloky.
- Buňky (voxely) 0,25 m, segmenty 8 m, výška sloupce 128 m. Generuje se jen slupka 2–3 buněk u vzduchu nebo průhledné vody v zorném poli; hlubší buňky se donačtou při kopání. Ukládá se jen rozdíl proti funkci.
- Voda (povrch i podzemí) se simuluje, eroze je vrstva posunu výšky. Pak povrchové jevy klimatu (písek, led, sníh) a vegetace jako funkce.

## Vykreslování
- Vykreslení data jen čte, nesmí je měnit.
- Izometrický pohled, pevný zoom 64 buněk (16 m) na šířku obrazovky, jedno rozlišení bez LOD. Cílem je i telefon.
- Dnes je v prototypu mesher, který staví 3D povrch z voxelů. Zda bude finální prezentace 2D nebo 3D, je zatím odložené.
- Okraj ostrova: bok jako jednoduché bloky s texturou do 5 m pod nejnižší okrajovou buňkou, pod ním oblaka. Voda na okraji padá jako vodopád do oblak a dál se nesimuluje.
- Předměty mezi kamerou a postavou (a podzemí nad postavou) se zprůhlední nebo odříznou. Prototyp válce od postavy ke kameře s ditherem a řez jsou za přepínačem.
- Styl: ručně malovaný stylizovaný izometrický look (Wakfu/Dofus), sytá tráva přetažená přes hranu, balvanité skalní vrstvy pod okrajem, visící kameny a kořeny pod ostrovem. Reference: `/workspace/willage-ideas/reference/` (okraj-ostrova, meshy-okraj, meshy-bloky).

## Otázky k diskuzi
Jak vykreslit voxely 0,25 m měkce a malovaně, ne kostičkovaně (marching cubes, dual contouring, bloky s texturou, shadery, triplanární texturování)? Jak dělat přechody materiálů, okraj s převislou trávou, vodu, vodopády a zprůhlednění, a jak to utáhnout na telefonu?
