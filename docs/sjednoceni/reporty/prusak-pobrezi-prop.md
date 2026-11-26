# PROP – Šířka pobřežního pásu podzemní vody z koeficientu průsaku

Větev `gen-v1-prusak-pobrezi` z `gen-v1-prusak-koeficient` (0c23f5f). Napsáno 2026-11-26 12:45 SEČ, před experimentem. Bez merge do main.
Zadání: Jan 12:35 (t959u): funkce z koeficientu průsaku (útlum / dosah z materiálového sloupce) a napojit ji na pobřeží místo konstantní `HladinaPrechodM = 5 m`. Šířka pásu mořské hladiny do vnitrozemí závisí na materiálech u břehu (štěrk široký, písek užší, jíl/žula skoro nic), pak smoothstep do spádové hladiny jako dosud; kde terén nemá vlastní vodu, čára končí na okraji pásu. Za přepínačem (výchozí vypnuto = konstanta 5 m a otisky seed 49 beze změny), ladící parametry v JSON. Upřesnění Jan 12:36: **šířka pásu = jak daleko vnikne mořská voda do vnitrozemí za časový horizont (výchozí 30 dnů); dál se nic nepočítá; horizont je ladící parametr.**

## Co už existuje (reuse)
- `RegionalniHladina.Surova`: u moře `hladina = hm + (l − hm) · smoothstep(d / HladinaPrechodM)`, d = vzdálenost od skutečného břehu (`MoreSklon.VzdalenostOdMoreJemna`, 6g; hledá `JeMore` po 1 m do 16 m).
- Koeficient průsaku 0–255 (`PrusakKoeficient`, `PrusakUtlum`, Q24; větev gen-v1-prusak-koeficient), K a porozita z katalogu (`Material.KMs`, `Porovitost`).

## Návrh
- **Funkce dosahu** `Voda/Prusak/PrusakDosah`: jak daleko dojde čelo mořské vody za horizont H v homogenní vrstvě materiálu m. Blok délky ℓ = 0,25 m (buňka). Doba přes čistý blok (Darcy) τ₀ = ℓ · n / (K · i) (n porozita z katalogu, i spád `PobrezSpad`). Čelo prochází blokem k s propustností T_k = ∏ b/255 (Q24, celočíselně, dolů), proto τ_k = τ₀ / T_k. Dosah = největší počet bloků, jehož součet τ_k ≤ H, plus zlomek posledního bloku (lineárně, celočíselně v mm). Materiál s koeficientem 255 postupuje stálou rychlostí, materiál s menším koeficientem zpomaluje geometricky (tlustá vrstva = těsná). K = 0 nebo koeficient 0 = dosah 0.
- **Materiálový sloupec** `PobrezniPas.Sirka`: u skutečného břehu (nejbližší bod `JeMore`) se vezmou pevné buňky od povrchu o `PobrezOknoM` dolů; platí materiál s největším dosahem (voda proniká nejpropustnější vrstvou). Vrstva se předpokládá pokračující do vnitrozemí. Strop `PobrezMaxM` (musí být ≤ ~30 m kvůli oknu hledání břehu).
- **Napojení**: `RegionalniHladina.Surova`: když `PrusakPobrezi` zapnuto, šířka pásu W = `PobrezniPas.Sirka` z břehu nejbližšího k bodu místo konstanty; dál `smoothstep(d / W)`; d ≥ W beze změny (hladina = původní spád, kde terén vlastní vodu nemá, čára končí na okraji pásu); v moři d = 0 → hladina moře. W = 0 (žula, jíl) = pás nulový.
- **Přepínač a JSON** (`voda_v1.json`): `prusakPobrezi: false`, `pobrezHorizontDni: 30`, `pobrezSpad`, `pobrezPorovitost` (náhradní, když katalog nemá), `pobrezMaxM`, `pobrezOknoM`. Vypnuto: kód cesta `HladinaPrechodM` beze změny (i hledání břehu s oknem 16 m).
- Šířky se cacheují po 1 m bodu břehu.

## Hypotézy
- H1: štěrk (K 1e-2) dosáhne stropu, písek (K 1e-4) několik metrů, spraš a jíl necelý metr až nic, žula 0.
- H2: bez koeficientu (jen Darcy) by písek v 30 dnech dosáhl desítek metrů; koeficient jej kvůli geometrickému zpomalování stlačí na jednotky metrů.
- H3: příznak vypnut: otisky seed 49 (krok 3, voda 14,14, prameny 3 × 3, mapa) a další seedy beze změny. Zapnuto: otisk kroku 3 a mapa beze změny (voda nemění terén), otisk vody a prameny se mohou lišit jen poblíž moře; start 3 × 3 je daleko od moře → beze změny.
- H4 (možný problém): šířka závisí na materiálu u konkrétního bodu břehu a mezi sousedními body se skokově mění → v hladině podél břehu skoky. Změřit.
- H5 (možný problém): pás větší než 16 m vyžaduje větší okno hledání břehu (cena).

## Měření
Šířky pásu pro materiály a horizonty 7/30/90 dnů; řezy: strmé a pozvolné z 6g, hledat štěrkový / písčitý břeh; otisky a prameny seed 49 a další seedy zapnuto/vypnuto; testy; `git merge-tree`.

## Výsledky
(doplní se po experimentu)
