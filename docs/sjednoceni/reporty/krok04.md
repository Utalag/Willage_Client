# Krok 4 – podzemní voda a prameny jako funkce světa (C#), report

Větev `gen-v1-krok04-podzemni-voda` z 94cefbe. PROP s plným znění výsledků: [krok04-prop.md](krok04-prop.md). Do `main` se nemerguje, čeká na Jana.

**Co vzniklo:** první C# kód generátoru. Čistá knihovna `cs/Willage.Gen` (bez Godotu), Godot .NET fasáda `godot-prototyp/scripts/cs/` a most do GDScript geologie kroků 1–3 (geologie se nepřepisovala, [pt906u]). Kontrakty Willage-backendu zrcadlené jen pro čtení (konstanty, HashInt3 + golden vectors, katalog materiálů z Willage_Dev main).

**Výsledky:** jednotkové testy 29/29, běh na funkci světa 0 chyb; hladina nikde nad povrchem, švy 0 neshod; 8 pramenů na 3 × 3, výkon v mezích; artéská voda ano (618 sloupců, 420 z nich v sopce); otisk `f19006126c4b12a7` ve 3 procesech; C# část ~0,1 s na blok, zbytek (99,6 %) je čtení geologie z GDScriptu.

**Záporné:** bez zesílení údolí (β = 0) 0 pramenů; kontaktní pramen ani sníh nevznikly; většina artéských případů je ve vnitřku sopky.

## Otázky pro Jana
1. Hladina jako funkce reliéfu (d₀ 1,5 m, zesílení údolí β = 1) místo řešiče E67 – stačí pro výchozí svět? Řešič E67 by zůstal pro ostrov v kroku 7.
2. Hustota pramenů: 8 na 3 × 3 bloky (60 % buněk 32 m s vývěrem). Dřív E96 ~10 na blok. Víc?
3. Slupky popela uvnitř sopky jsou sevřené vrstvy a dávají artéskou vodu (420 z 618). Nechat, nebo vnitřek sopky brát jako nepropustný?
4. Sůl a sádrovec se počítají jako propustné těleso (pravidlo krasu z E67). Nechat?
5. Artéská voda: tlaková výška = nejvyšší výchoz stejné horniny do 192 m. Všechny artéské případy by po prokopání tryskaly. Není to moc často (198 sloupců mimo sopku na bloku)?
6. Port geologie do C#: most je 99,6 % času (7,3 ms na sloupec). Přepsat při kroku 5/6, nebo až při finalizaci?
7. Pozorování z řezů: vrstvy kroku 3 mají skok na švech bloků (mince E82 po blocích 128 m), viz `rez_y1960.png` – souvisí s otevřenou otázkou E86.
