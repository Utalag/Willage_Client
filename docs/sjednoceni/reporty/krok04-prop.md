# PROP – Krok 4, podzemní voda a prameny jako funkce světa (C#)

Větev `gen-v1-krok04-podzemni-voda` z `gen-v1-krok03b-hostitele-sum` (94cefbe). Napsáno 2026-11-26 8:25 SEČ, před změnou kódu. Do `main` se nemerguje, schválí Jan.

## Proč
Krok 4 v `04-implementace-generatoru.md`: hladina podzemí a propustnost jako **funkce geologie bez uložených buněk** (1.2, 2.5), prameny ze seedu s jmenovitým výkonem a skutečným výkonem omezeným okolím (jednoduchý model výchozí, tlakový pod přepínačem, 1.8), artéská voda jen ověřit (1.8.1). Od 26. 11. se prototypy píší v C# ([pt905u]); starý GDScript se přepisuje jen tam, kde je to potřeba ([pt906u]).

## Rozhodnutí o kódu
- **Geologie kroků 1–3 zůstává v GDScriptu (most, ne port).** Krok 4 potřebuje jen povrch a materiál buněk sloupce. To dává `svet_fn.gd` (`vyska`) a `geo_vrstvy.gd::vypln_sloupec` (512 buněk 0,25 m). Port celé funkce světa (svet_fn + geo_vrstvy + útvary + šum + klima, ~1 500 řádků) by byl přepis bez kolize, proti [pt906u]. C# je volá v procesu Godot .NET přes `GodotObject.Call` (adaptér `GeologieGd`). Jádro C# zná jen rozhraní `IGeologie`, takže pozdější port geologie do C# se dotkne jen adaptéru.
- **Jádro Willage-backendu:** zrcadlím (kopie, jen čtení) jen to, co krok 4 potřebuje: `GeologyGridConstants` (0,25 / 8 / 128 m) a `GeologyHash.HashInt3` s golden vectors z Willage_Dev main (PR #14 sloučen, 29bffc0). Na Willage_Dev se neodkazuju jako na projekt (soukromé repo, jiný build), do Willage_Dev nic nezapisuju.
- **Materiály:** propustnost K (m/s), pórovitost a skupina z katalogu Willage-backendu `materials-catalog-v1.json` (Willage_Dev PR #15, 50b61e5, nesloučeno), kopie jen pro čtení v `godot-prototyp/data/v1/`. Nová ID nepřiděluju. Propustnost buňky X = K × 0,0625 m² × 1000 l/m³ (l/s herního času při spádu 1, 1.8.1); rozhraní = minimum obou.
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
