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
- **Výpočet** (`Voda/Prusak`): propustnost cesty přes n bloků = ∏ (b_i / 255), celočíselně v Q24: `t ← (t · b + 127) / 255` pro každý blok (bez desetinných čísel, bitově shodné). Tok jedné stěnové buňky = X_min(cesta) [existující pravidlo minima] × T(cesta) × spád, kde spád = (H − max(h, z_buňky)) / (H − dno dutiny) (poměr výšek, celočíselně v mm). Stěna do vzduchu (díra) = otevřená buňka, jmenovitě 1 l/s (jako příklad „buňka 1 l/s“ v 1.8).
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
(doplní se po experimentu)
