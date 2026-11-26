# PROP – Krok 4, podzemní voda a prameny jako funkce světa (C#)

Větev `gen-v1-krok04-podzemni-voda` z `gen-v1-krok03b-hostitele-sum` (94cefbe). Napsáno 2026-11-26 8:25 SEČ, před změnou kódu. Do `main` se nemerguje, schválí Jan.

## Proč
Krok 4 v `04-implementace-generatoru.md`: hladina podzemí a propustnost jako **funkce geologie bez uložených buněk** (1.2, 2.5), prameny ze seedu s jmenovitým výkonem a skutečným výkonem omezeným okolím (jednoduchý model výchozí, tlakový pod přepínačem, 1.8), artéská voda jen ověřit (1.8.1). Od 26. 11. se prototypy píší v C# ([pt905u]); starý GDScript se přepisuje jen tam, kde je to potřeba ([pt906u]).

## Rozhodnutí o kódu
- **Geologie kroků 1–3 zůstává v GDScriptu (most, ne port).** Krok 4 potřebuje jen povrch a materiál buněk sloupce. To dává `svet_fn.gd` (`vyska`) a `geo_vrstvy.gd::vypln_sloupec` (512 buněk 0,25 m). Port celé funkce světa (svet_fn + geo_vrstvy + útvary + šum + klima, ~1 500 řádků) by byl přepis bez kolize, proti [pt906u]. C# je volá v procesu Godot .NET přes `GodotObject.Call` (adaptér `GeologieGd`). Jádro C# zná jen rozhraní `IGeologie`, takže pozdější port geologie do C# se dotkne jen adaptéru.
- **Jádro Willage-backendu:** zrcadlím (kopie, jen čtení) jen to, co krok 4 potřebuje: `GeologyGridConstants` (0,25 / 8 / 128 m) a `GeologyHash.HashInt3` s golden vectors z Willage_Dev main (PR #14 sloučen, 29bffc0). Na Willage_Dev se neodkazuju jako na projekt (soukromé repo, jiný build), do Willage_Dev nic nezapisuju.
- **Materiály:** propustnost K (m/s), pórovitost a skupina z katalogu Willage-backendu `materials-catalog-v1.json` (Willage_Dev main 3476488, PR #15 sloučen 26. 11.; obsah ověřen shodný s 50b61e5), kopie jen pro čtení v `godot-prototyp/data/v1/`. Nová ID nepřiděluju. Propustnost buňky X = K × 0,0625 m² × 1000 l/m³ (l/s herního času při spádu 1, 1.8.1); rozhraní = minimum obou.
- **Struktura:** čistá knihovna `cs/Willage.Gen` (net9.0, bez Godotu) + tenká Godot C# fasáda v `godot-prototyp/scripts/cs/` + konzolové testy `cs/Willage.Gen.Testy` (syntetická geologie) + běh na skutečném světě přes Godot headless (`tools/voda_v1.gd` spustí C# běžce). Krátké soubory, jedna odpovědnost.

## Model (návrh, hypotéza)
1. **Propustné těleso** = buňka s K ≥ 6,3·10⁻⁸ m/s (`ponor_perm` 0,3 z E67) nebo rozpustná hornina (vápenec, dolomit, `kras67`). Ostatní je těsnění.
2. **Regionální hladina** (E74 jako funkce, ne řešič): tlumená kopie reliéfu. G(x, y) = vážený průměr výšky povrchu v uzlech světové mřížky 8 m do poloměru R = 48 m, váha (1 − d²/R²)². Hladina L = min(G − d₀, povrch), d₀ = 1,5 m. Je spojitá a nezávisí na bloku (uzly jsou světové), takže švy sedí z definice. Kde G − d₀ > povrch, je **zóna vývěru** (mokřad, pramen, jezero kroku 7).
3. **Sloupec:** nasycené jsou propustné buňky od L dolů po první těsnění (volná hladina). **Zavěšená voda:** nad těsněním, které leží nad L, film 0,5 m (`film67`). **Sevřená vrstva:** propustné pásmo pod L mezi dvěma těsněními.
4. **Artéská voda:** tlaková výška sevřené vrstvy = nejvyšší povrch v okolí 192 m (mřížka 8 m), kde stejná hornina vychází na povrch (oblast doplňování). Artéská, když výška > strop vrstvy; samovolně tekoucí, když > povrch. Neukládá se.
5. **Prameny ze seedu:** světová buňka 32 m, kandidáti na mřížce 2 m v zóně vývěru; druh `kras` (rozpustná hornina u povrchu), `kontakt` (propustné nad těsněním do 2 m, sklon ≥ 0,5), `snih` (věčný sníh, id 10), jinak `vyver`. Nejlepší kandidát buňky (druh, sklon, hash), existence s pravděpodobností z hashe, rozestup ≥ 8 m řeší priorita z hashe jen mezi sousedními buňkami (lokální, švy sedí). Jmenovitý výkon = základ druhu (E47c: kras 5, sníh 4, kontakt 1,5 l/s, vývěr 1 l/s) × 0,5–1,5 z hashe.
6. **Skutečný výkon:** jednoduchý model Σ stěn X(soused) × 1, vzduch/voda = otevřená stěna; výkon = min(jmenovitý, kapacita). Tlakový model (přepínač `tlakovy`): nevydaný výkon zvedá tlakovou výšku Ht do stropu (výška doplňování − z), spád = 1 + Ht / 0,25 m, výkon = min(jmenovitý, kapacita × spád).
7. Okraj ostrova neexistuje před krokem 5: funkce dá prameny světa, filtr „ne na okraji ostrova“ (2 m) se testuje jako funkce pro vložení.

## Testy (04 krok 4, celé bloky 128 m z funkce světa)
1. **Hladina:** mapa hladiny 3 × 3 bloky (PNG, hloubka pod povrchem), svislé řezy s hladinou. Prošlo = L ≤ povrch všude, spojitost přes švy (bloky počítané zvlášť dají na švu stejné hodnoty, skok přes šev ≤ skok uvnitř).
2. **Prameny:** počet, druhy, žádný v 2 m od okraje ostrova po filtru, výkon ≤ jmenovitý a ≤ kapacita okolí; příklady z 1.8 (granit + jedna buňka 1 l/s → 1 l/s; odkopáno → jmenovitý; ucpáno → ~0).
3. **Artéská voda:** aspoň jeden případ sevřené vrstvy, tlaková výška = výška doplňování (nezávislý přepočet). Neprošlo = „model nezvládne“, ne chyba.
4. **Determinismus:** otisk (SHA-256, hodnoty v Q16) hladiny, profilů a seznamu pramenů ze dvou procesů.
5. Jednotkové testy C# (golden vectors hashe, propustnost z katalogu, výkon pramene, profil sloupce na syntetické geologii).
6. Kontrola E82: u sloupců s mincí „ano“ porovnat odhad `vyska_tvar − 2 m` se skutečnou L (A12, jen záznam).
7. Čas: C# část vs. most do GDScriptu vs. dřívější E74/E96 (blok 128 m 49–53 s).

## Hypotézy a kritéria
- H1: hladina jako funkce reliéfu stačí na test 1 bez řešiče E67; rozdíl proti E67 (výtok z okrajů vrstev, pasti) zapíšu jako omezení.
- H2: most do GDScriptu je úzké hrdlo (~3 ms na sloupec), C# část je proti němu zanedbatelná.
- H3: artéská voda vznikne jen tam, kde stejná hornina vychází na povrch do 192 m; ve výchozím světě může být vzácná. Nulový výsledek se zapíše.

## Mimo rozsah
Řešič E67 v C#, povrchová voda a jezera (krok 7), okraj ostrova a vložení (krok 5), ukládání pramenů (krok 6), port geologie do C#.

## Změna po prvním běhu (zapsáno 8:31 SEČ)
První běh na skutečném světě (β = 0, čistě tlumená kopie reliéfu): **0 % zóny vývěru, 0 pramenů na 3 × 3** (startovní svět je mírný, povrch 67–94 m; G − povrch nepřekročí d₀ = 1,5 m). Záporný výsledek uložen v `shots/krok04/beh1_beta0.json`. Doplněno zesílení údolí β: L = min(G − d₀ + β·(G − povrch), povrch), výchozí β = 1 (`voda_v1.json`). Spojitost se nemění (povrch i G jsou spojité).

## Výsledky (2026-11-26 8:36 SEČ)
Všechny testy: **jednotkové C# 29/29, běh na funkci světa 0 chyb** (`tools/voda_v1.gd --rezim=vse`, 67 s). Svět seed 49, bloky 14–16 × 14–16.

### 1. Hladina jako funkce
- Mapa 3 × 3 bloky po 2 m (192 × 192): **L nad povrchem 0×**, zóna vývěru 3,3 % plochy, hloubka hladiny průměr 1,53 m, max 10,5 m (u sopky).
- Švy: bloky počítané v oddělených instancích (jiné pořadí plnění paměti), šev x i y po 1 m: **0 neshod**. Skok přes šev na 2 m 0,192 / 0,236 m, uvnitř bloku max 0,192 / 0,246 m (šev není vidět).
- Profil sloupců bloku 14,14 (4 096 sloupců): hladina v těsnění 381 sloupců (9,3 %, bez volné vody), zavěšená voda 271 sloupců (6,6 %).
- Obrázky: `shots/krok04/mapa_hladiny_3x3.png`, `rez_y1856.png`, `rez_y1960.png`.

### 2. Prameny
- 3 × 3: **8 pramenů** (6 vývěr, 2 kras; kontakt 0, sníh 0). Výkon > jmenovitý nebo > kapacita: 0. Blíž než 8 m: 0. V 2 m od okraje oblasti 3 × 3: 0 (filtr pro vložení `Prameny.MimoOkraj`). Prameny celé oblasti jsou shodné ze dvou instancí.
- Ve výchozím světě jsou všechny otevřené (vzduch nad buňkou) → výkon = jmenovitý 0,79–4,33 l/s.
- Zasypání okolní horninou (5 pramenů): jednoduchý model písek 6 × 0,00625 = 0,0375 l/s, ornice 0,0014 l/s; tlakový model vydá plný jmenovitý výkon s Ht 5–17 m, u ornice narazí na strop 20 m a vydá 0,112 l/s.
- Příklady z 1.8 v jednotkových testech: žula + jedna buňka 1 l/s → 1 l/s; odkopáno → 10 l/s; ucpáno → ~0; tlakový strop 0,5 m → 3 l/s.
- Záporné: kontaktní pramen nevznikl ani jeden (sklon ≥ 0,5 v zóně vývěru na mírném startu chybí); sníh ve startovním světě není.

### 3. Artéská voda – model ji zvládne
- Blok 14,14: 4 705 sevřených vrstev, **618 artéských** (tlaková výška > strop vrstvy), všech 618 by po prokopání tryskalo (výška > povrch). 12/12 vzorků nezávisle ověřeno (výchoz ve zvláštní instanci geologie: stejná hornina, stejná výška).
- Ale: 420 z 618 jsou slupky popela (57) mezi lávou ve vnitřku sopky. Mimo sopku 198: ornice 46, písek 56, jeskynní vápenec 53, spraš 43. Pískovec 52: 1 557 sevřených, 0 artéských (nevychází do 192 m). 4 087 sevřených vrstev nemá v dosahu výchoz.

### 4. Determinismus
Otisk bloku 14,14 (hladina + profily + prameny, Q16): **`f19006126c4b12a7`** ve třech procesech (det ×2, vse). S β = 0 byl `b017a12c4686fd61`.

### Kontrola E82 (A12)
551 sloupců s mincí (mřížka 12 m): L − (vyska_tvar − 2 m) medián +0,75 m, p10 −0,73, p90 +1,58; v 83 % je skutečná L nad odhadem, tj. strop vápence leží ≥ 2 m pod hladinou. Odhad mince tedy sedí; geologie na hladině dál nezávisí.

### Čas (blok 128 m, samostatný proces)
| úloha | celkem | GDScript (most) | C# |
|---|---|---|---|
| hladina 1 m (16 384 bodů) | 352 ms | 204 ms (povrch 11 µs) | 147 ms |
| profily 2 m (4 096 sloupců) | 29,9 s | 29,8 s (`vypln_sloupec` 7,3 ms) | 110 ms |
GDScriptový protějšek kroku 4 neexistuje; dřívější voda na bloku 128 m (E96, plná simulace) 49–53 s. **Hypotéza H2 potvrzena:** 99,6 % času je čtení geologie z GDScriptu, C# část je ~0,1 s.

### Omezení
Hladina není řešič E67 (pasti, výtok z okrajů vrstev, bilance); je to funkce reliéfu. Torus se zatím nebalí (světové metry bez periody). Totožnost vrstvy pro doplňování = ID horniny.
