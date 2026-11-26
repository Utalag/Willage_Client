# PROP – Koeficient průsaku (těsnost materiálu), zapínatelný

Větev `gen-v1-prusak-koeficient` z `main` 5e4f1f0 (tag `gen-v1-krok06g`). Napsáno 2026-11-26 12:25 SEČ, před experimentem. Bez merge do main.
Zadání: Jan 12:19 (t955u) – „zařadit jako zapínatelný parametr a uvidíme v simulacích“; upřesnění 12:21: **koeficient se ukládá jako celé číslo bajt 0–255** (255 = plně propustné, 0 = těsné), výpočet deterministicky celočíselně, ať jsou výsledky bitově shodné na všech zařízeních.

## Co už existuje (reuse)
- C# `Materialy/Propustnost.cs`: X = K × 0,0625 m² × 1000 l/s při spádu 1 pro každý materiál (K z `materials-catalog-v1.json`, pole `permeabilityMs`), rozhraní = minimum, těleso = K ≥ prah nebo rozpustná hornina. `VykonPramene` sčítá X sousedů pramene. Žádná závislost na tloušťce vrstvy.
- GDScript (blueprint-studie, `p72_prusak`, `p71_prusak`, `p73_prusak_tok`, `p76_prameny`, E74–E77): „průsak“ = únik protékané vody dnem pasti do polopropustného okolí (l/s na stěnu · perm), limit dosahu 8 m (`p72_dosah_m`). To je jiná veličina (únik z nádrže), tento krok ji nemění.
- Data: `godot-prototyp/data/v1/voda_v1.json` → `ParametryVody` (record). Katalog materiálů je zrcadlo z Willage_Dev (jen čtení), proto koeficienty nepatří do něj.

## Návrh
- **Data**: `godot-prototyp/data/v1/prusak_v1.json`: třídy podle K (K ≥ 1e-3 → 255, ≥ 1e-4 → 178, …, < 1e-11 → 0) a přepisy podle klíče materiálu. Hodnoty jsou celé 0–255. Vzduch = 255, materiál bez K = 0.
- **Přepínač**: `ParametryVody.PrusakKoeficient` (výchozí `false`, v `voda_v1.json` také `false`). Když je vypnuto, tabulka se nevytvoří a nic se nepočítá; generátor světa (hladina, prameny) koeficient nečte, otisky seedu 49 se tedy nesmí změnit ani při zapnutí. Koeficient ovlivňuje jen dynamický průsak do uzavřených prostor (podvodní stavby, vykopané dutiny).
- **Výpočet** (`Voda/Prusak`): propustnost cesty přes n bloků = ∏ (b_i / 255), celočíselně v Q24: `t ← t · b / 255 (zaokrouhleno dolů)` pro každý blok (bez desetinných čísel, bitově shodné). Tok jedné stěnové buňky = X_min(cesta) [existující pravidlo minima] × T(cesta) × spád, kde spád = (H − max(h, z_buňky)) / (H − dno dutiny) (poměr výšek, celočíselně v mm). Stěna do vzduchu (díra) = otevřená buňka, jmenovitě 1 l/s (jako příklad „buňka 1 l/s“ v 1.8).
- Objem v pikolitrech v `Int128`, krok 10 s herního času, žádný double v časové smyčce kromě jednorázového převodu X [l/s] → µl/s (zaokrouhlení).

## Hypotézy
- H1: bez koeficientu (stávající pravidlo) tloušťka stěny nehraje roli: 1 blok písku = 10 bloků písku. S koeficientem 178/255 = 0,698 klesne tok ~0,698^n (1 → 0,70; 5 → 0,17; 10 → 0,027).
- H2: hrubý štěrk (255) se chová stejně zapnuto i vypnuto; žula a jíl jsou těsné v obou režimech (X je už ~1e-11 l/s), takže koeficient mění hlavně střední materiály (písek, spraš, zvětralé horniny).
- H3: fingerprints seedu 49 (krok 3, voda 14,14, prameny 3 × 3, mapa) jsou stejné s vypnutým i zapnutým příznakem (generátor koeficient nečte).
- H4 (možný negativní nález): násobení po blocích je exponenciální útlum, kdežto fyzikální Darcy v sérii je spíš 1/(Σ 1/c). Pro tenké stěny to dá podobné číslo, pro silné útlum výrazně rychlejší. Je to záměrná hra, ne fyzika; zapsat do výsledků.
- H5 (možný problém): u velmi těsných stěn zaokrouhlení Q24 nuluje tok. Měřit, kolik bloků písku už vychází T = 0.

## Měření
1. Dutina 2 × 2 m, výška 6 m (dno 56 m, strop 62 m), voda venku H = 60 m, stěna ze všech stran ze zadaného materiálu a tloušťky: žula 1 blok, jíl (clay_deposit) 10 bloků, písek (gravel_sand) 1/5/10 bloků, spraš 1/5, zvětralá žula 5, štěrk (subalpine_scree) 1, žula + 1 buňka díra. Režim stávající (vypnuto) vs. koeficient (zapnuto). Hlásit: čas do 50 % a 90 % rovnovážné výšky, výšku hladiny po 1 h / 1 dni / 7 dnech / 30 dnech, konečnou výšku.
2. Fingerprints seedu 49 s příznakem vypnuto / zapnuto.
3. Testy C# na main 5e4f1f0 a na větvi; `git merge-tree` proti main.
4. Obrázky `godot-prototyp/shots/prusak/` (česky): útlum podle tloušťky a materiálu; křivky plnění dutiny.

## Výsledky
(2026-11-26 12:35 SEČ)

### Implementace
Data `godot-prototyp/data/v1/prusak_v1.json` (bajty 0–255), `Materialy/PrusakKoeficient.cs` (tabulka, odmítne mimo 0–255), `Voda/Prusak/{PrusakUtlum,StenaDutiny,PrusakDutina}.cs`, příznak `ParametryVody.PrusakKoeficient` (výchozí false, i v `voda_v1.json`), `PodzemniVodaFn.Prusak` (null při vypnutí) a `Dutina(...)`. Nástroj `Willage.Gen.Nastroje prusak <složka>`, volba `--prusak` pro otisky. Obrázky + tabulka: `godot-prototyp/shots/prusak/`.

Koeficienty: štěrk (subalpine_scree) 255, písek (gravel_sand) 178 (0,698), zvětralá žula 77, spraš 38, jíl (clay_deposit, weathered_clay) 13 (0,05), žula, ortorula a materiály bez K 0.

### Tabulka (dutina 2 × 2 × 6 m, dno 56 m, venku 60 m, 30 dnů, krok 10 s)
| scénář | režim | T cesty | přítok na začátku (l/h) | do 50 % | do 90 % | hladina 1 h | 1 den | 7 dnů | 30 dnů (m) |
|---|---|---|---|---|---|---|---|---|---|
| žula 1 blok | stávající | – | 0 | nedosaženo | nedosaženo | 56,00 | 56,00 | 56,00 | 56,00 |
| žula 1 blok | koeficient | 0 | 0 | nedosaženo | nedosaženo | 56,00 | 56,00 | 56,00 | 56,00 |
| jíl 10 bloků | stávající / koef. | – / 0 | 0 | nedosaženo | nedosaženo | 56,00 | 56,00 | 56,00 | 56,00 |
| písek 1 blok | stávající | – | 7200 | 1,3 h | 3,5 h | 57,64 | 60,00 | 60,00 | 60,00 |
| písek 1 blok | koeficient | 0,698 | 5026 | 1,8 h | 5,0 h | 57,19 | 60,00 | 60,00 | 60,00 |
| písek 5 bloků | stávající | – | 7200 | 1,3 h | 3,5 h | 57,64 | 60,00 | 60,00 | 60,00 |
| písek 5 bloků | koeficient | 0,166 | 1193 | 7,7 h | 21,2 h | 56,30 | 59,72 | 60,00 | 60,00 |
| písek 10 bloků | stávající | – | 7200 | 1,3 h | 3,5 h | 57,64 | 60,00 | 60,00 | 60,00 |
| písek 10 bloků | koeficient | 0,0275 | 198 | 1,9 dne | 5,3 dne | 56,05 | 57,13 | 59,83 | 60,00 |
| spraš 1 blok | stávající | – | 6,9 | nedosaženo | nedosaženo | 56,00 | 56,04 | 56,29 | 57,18 |
| spraš 1 blok | koeficient | 0,149 | 1,0 | nedosaženo | nedosaženo | 56,00 | 56,01 | 56,04 | 56,18 |
| spraš 5 bloků | koeficient | 0,0001 | 0 | nedosaženo | nedosaženo | 56,00 | 56,00 | 56,00 | 56,00 |
| zvětralá žula 5 bl. | stávající | – | 71 | 5,3 dne | 14,7 dne | 56,02 | 56,42 | 58,45 | 59,98 |
| zvětralá žula 5 bl. | koeficient | 0,0025 | 0,18 | nedosaženo | nedosaženo | 56,00 | 56,00 | 56,01 | 56,03 |
| štěrk 1 blok | oba | 1,0 | 720 000 | 0,8 min | 2,0 min | 60,00 | 60,00 | 60,00 | 60,00 |
| žula 1 blok + 1 díra | oba | 0 | 3488 | 3,1 h | 10,2 h | 56,80 | 59,98 | 60,00 | 60,00 |
| písek 10 bl. + 1 díra | stávající | – | 10 666 | 54 min | 2,6 h | 58,17 | 60,00 | 60,00 | 60,00 |
| písek 10 bl. + 1 díra | koeficient | 0,0275 | 3685 | 2,9 h | 9,5 h | 56,85 | 59,99 | 60,00 | 60,00 |
(úplná tabulka `shots/prusak/tabulka.md`)

### Hypotézy
- **H1 potvrzena.** Stávající pravidlo: 1, 5 i 10 bloků písku dávají totéž (7200 l/h). S koeficientem 5026 / 1193 / 198 l/h, tj. přesně poměr T; písek 10 bloků se plní 1,9 dne místo 1,3 h (≈ 35× pomaleji).
- **H2 potvrzena.** Štěrk 255 beze změny. Žula a jíl jsou těsné v obou režimech (X ≈ 1e-11 l/s na buňku, po kvantování na µl/s = 0; za 30 dnů hladina beze změny). Koeficient mění hlavně střední materiály (písek, spraš, zvětralé horniny).
- **H3 potvrzena.** Otisky seedu 49 s příznakem vypnuto i zapnuto stejné, viz níže.
- **H4 (částečně negativní):** exponenciální útlum se od sériového Darcyho (1/Σ 1/c) liší. Písek 5 bloků: 0,166 (násobení) vs 0,140 (série); 10 bloků: 0,027 vs 0,070. Pro tlusté vrstvy je tedy násobení „přísnější“ než fyzika, jak Jan chtěl („silná vrstva jemného písku je těsná“); jde o herní pravidlo, ne o Darcyho zákon.
- **H5 potvrzena a opravena.** Se zaokrouhlením na nejbližší (+127) uvízl koeficient ≥ 128 na 1 LSB Q24 (nikdy 0, zbytkový tok ~6e-8). Proto se zaokrouhluje dolů: písek dosáhne T = 0 po 43 blocích, spraš po ~10 blocích (T < 1e-8). Zlatá čísla písek 1/5/10 bloků: 11711154 / 2780473 / 460804 (Q24; ověřeno nezávisle v Pythonu celými čísly).

### Další nálezy (negativní / omezení)
- Koeficient se v generátoru světa (hladina, prameny, profil) **nepoužívá**: ten ho nepotřebuje a tak zůstaly otisky. Použije se až u kopání a staveb (uzavřené prostory), kde bude potřeba lokální přepočet vody.
- Tok stěnové buňky = X_min × T × spád: X (K z katalogu) už je fyzikální strop, koeficient je další útlum. Materiál s vysokým koeficientem, ale nízkým K (např. hill_sand K 1e-4 → 178) tak není propustnější, než dovolí K.
- Model je jednoduchý: odvzdušněná dutina, stěna vždy rovná cesta bloků, bez tlaku a bez šíření podél stěny. Díra do 1 buňky dominuje (žula + díra se plní 3 h jako písek bez útlumu).
- Rychlost plnění závisí na `OtevrenaLs` = 1 l/s (jmenovitý tok otevřené buňky) a na kroku 0,25 m; jiné hodnoty změní časy, ne pořadí.

### Otisky seed 49 (mapa eroze 32 m, `eroze otisky`)
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 | příznak vypnuto = zapnuto |
|---|---|---|---|---|
| vše vypnuto (krok 5) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 | ano |
| eroze | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 | ano |
| eroze + vodníci | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 | ano |
Mapa 800d420bb00047de (golden). Totéž jako po 6g.

### Testy
`main` 5e4f1f0: **OK 110, chyb 0**. Větev: **OK 135, chyb 0** (nových 25: tabulka 0–255, odmítnutí mimo rozsah, monotónnost, útlum Q24 a zlatá čísla, přepínač, shoda otisku bloku vody, tloušťka bez vlivu při vypnutí, pořadí při zapnutí, štěrk shodný, žula/jíl těsné, díra, deterministické opakování, hladina monotónní a ≤ 60 m).

### Obrázky
`godot-prototyp/shots/prusak/utlum_podle_tloustky.png`, `plneni_dutiny.png` (skript `graf.py`).

### Návrh dalšího kroku
Napojit `PrusakDutina` na skutečné vykopané prostory po lokálním přepočtu vody (E74–E77) a doplnit těsnost podle skutečných stěn (ne jen rovné cesty). Rozhodnutí o zapnutí ve výchozím světě čeká na Jana.
