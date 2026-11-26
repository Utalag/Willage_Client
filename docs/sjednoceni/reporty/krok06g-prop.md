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

## Výsledky (2026-11-26 12:14 SEČ)

### Testy na main (před opravou)
`main` c24967d (tag `gen-v1-krok06f`): **OK 104, chyb 0** (C# `Willage.Gen.Testy`, .NET 9, Release).

### Kořen chyby (H1 ne, H2 ano, H3 ne)
Není to chyba kreslení: binární výpis `eroze rez` má na strmém řezu W přesně 60,000 m ve všech 400 sloupcích.

`VzdalenostOdMoreJemna` vracela 0 všude, kde maska pevniny k < 0,5, i když povrch byl nad hladinou moře (`!JeMore`). Pás 5 m se proto měřil od vrstevnice k = 0,5, ne od skutečného břehu (moře = k < 0,5 a povrch < 60 m). Mezi břehem a k = 0,5 je desítky metrů pevniny:

- pozvolné (seed 49): břeh s ≈ 23 m, k = 0,5 až s ≈ 61 m (~38 m pás s vynucenou 60 m);
- strmé (od 22489,4 / 5322,3): břeh s ≈ 40 m, k = 0,5 až s ≈ 114 m (v úseku 100 m k = 0,46, proto celý řez = 60 m).

Původní spád h0 přitom není 60 m: na strmém řezu bez eroze je h0 u břehu ~58–61 m a 100 m od začátku ~80 m (pod terénem ~86 m). V 6f to vypadalo jako „původní hladina blízko 60 m“, protože D = 0 vynutilo směs na 60 m.

### Oprava
`MoreSklon.VzdalenostOdMoreJemna` bere výšku a hledá skutečné moře (`JeMore`) po 1 m. Ve vnitrozemí (hrubá vzdálenost k masce > 32 m, nebo jemně ≥ 16 m od k = 0,5) zůstává původní rychlá cesta – to stačí, protože pás přechodu je 5 m. Hrubá mřížka 64 m pro sklon kontinentu a pánve se nemění (mapa eroze beze změny). V řezu se čára podzemní vody kreslí jen na pevnině (v moři je hladina moře ve výplni, žádný fallback 60 m ve vnitrozemí).

### Otisky startu (seed 49, 14,14) – stejné jako 6f
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 |
|---|---|---|---|
| `Krok5()` (vše vypnuto) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí bez eroze | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí s erozí a vodníky | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 |

Mapa výchozího světa **800d420bb00047de** (golden beze změny), 92 vodníků, ve startu 0.

### Řez
`godot-prototyp/shots/krok06g/rez_pobrezi_100m.png` – stejné úsečky jako v 6f. Pozvolné: břeh ~23 m, v pásu 5 m napojení, dál hladina stoupá se spádem (~61–67 m). Strmé: břeh ~40 m, napojení a dál spád (~62–78 m pod terénem do 84 m), ne vodorovná 60 m.

### Další pozvolnější řezy (negativní)
Hledal jsem dva ještě mírnější břehy (nárůst výšky ~7–8 m na 96 m). Jeden je skoro vodorovný kolem 60 m a napojení není čitelnější než stávající pozvolný řez; druhý má v h0 prohlubeň (~52 m, průměr zahrnuje mořské dno). Do shots jsem je nedával.

### Testy na větvi
**OK 110, chyb 0** (nové: v moři D = 0 a 60 m, pás 5 m od skutečného břehu, za 5 m = původní spád, žádný fallback 60 m, D 20/60 m za břehem není 0, bod strmého řezu +100 m není 60 m). Před opravou tyto testy padaly (3 chyby).

### Plán 04
Jedna věta o 6g v `docs/sjednoceni/04-implementace-generatoru.md` na této větvi.

### Merge
`git merge-tree` proti `main` c24967d: bez konfliktů, main je předek (čistý fast-forward). Bez merge.
