# PROP – Krok 6g: oprava hladiny podzemní vody u břehu

Větev `gen-v1-krok06g-oprava-hladiny` z `main` (c24967d, tag `gen-v1-krok06f`). Napsáno 2026-11-26 12:05 SEČ, před opravou. Bez merge do main.
Zadání: Jan 11:55 (t947u / t948u) – v řezu `shots/krok06f/rez_pobrezi_100m.png` (strmé pobřeží, seed 49, od x 22489,4 y 5322,3) je hladina vodorovně 60 m přes celých 100 m, i 60 m ve vnitrozemí pod terénem ~80 m. Upřesnění: kde terén nemá vlastní hladinu ze spádu, čára mořské hladiny skončí 5 m za břehem (nekreslit ji dál); kde terénní voda je, napojí se. Žádný fallback na 60 m.

## Cíl a metoda
- Zjistit, jestli je to chyba kreslení (skript kreslí konstantu, špatné pole, ořez), nebo výpočtu (vzdálenost k moři, obrácený přechod, původní spád sám padá na 60).
- Vytisknout podél obou úseček z C# knihovny: povrch, masku pevniny k, `JeMore`, hrubou i jemnou vzdálenost, surovou hladinu s přechodem (h1) a bez něj (h0).
- Oprava v C# na této větvi, regresní test, testy na main i na větvi, nový řez `shots/krok06g/rez_pobrezi_100m.png` (stejné úsečky; případně dva další pozvolnější břehy), legenda česky. Otisky startu seed 49. Bez merge.

## Hypotézy
- H1 (kreslení): skript kreslí vodorovnou 60 m místo pole W. Binární výpisy `eroze rez` to vyvrátí nebo potvrdí.
- H2 (vzdálenost): `VzdalenostOdMoreJemna` vrací 0 všude, kde `Pevnina` (k) < 0,5, i když povrch je nad hladinou moře (`!JeMore`). Pás 5 m se proto měří od vrstevnice k = 0,5, ne od skutečného břehu (moře = k < 0,5 a povrch < 60 m). Mezi břehem a k = 0,5 je desítky metrů pevniny s vynucenou hladinou 60 m. Na strmém řezu k v úseku 100 m nedosáhne 0,5 → celý řez = 60 m.
- H3 (původní spád): h0 je samo ~60 m, přechod nic nekazí.
- H4 po opravě: v moři hladina = 60 m; v pásu 5 m od skutečného břehu (`JeMore`) plynulé napojení na h0; dál h1 = h0. Kde h0 (terénní voda) je, čára se napojí. Kde není, čára 60 m v řezu skončí 5 m za břehem (nekreslit fallback 60 m). Mapa eroze a otisky startu 3 × 3 beze změny (start je stovky metrů od moře).

## Měření
Testy C# na `main` c24967d i na větvi. Řezy, otisky startu, `git merge-tree` s aktuálním main. Negativní výsledky zapsat.
