# PROP – Puklinová propustnost krasu (vápenec, dolomit) a sloučení průsaku do main

Větev `gen-v1-prusak-merge` z `main` dfcb9ff (tagy `gen-v1-krok07` / `gen-v1-krok07b`, klima výchozí zapnuto). Napsáno 2026-11-26 13:15 SEČ, před experimentem. Bez merge do main.
Zadání: Jan 13:05 (t968u) – doporučení z kroku pobřeží: vápence a dolomit (kras) dostanou **puklinovou** propustnost, aby se při průsaku chovaly zhruba jako písek (pobřežní pás ~1,5–3,5 m podle spádu, koeficient ~178). Data v `prusak_v1.json` / parametrech vody, celočíselně, za stávajícími přepínači (vypnuto = svět beze změny). Zároveň připravit práci na průsaku ke sloučení: přenést `gen-v1-prusak-koeficient` + `gen-v1-prusak-pobrezi` + tuto změnu do větve z aktuálního mainu (klima 7/7b). Známé textové konflikty v `DENIK.md` a `cs/Willage.Gen.Testy/Program.cs` – ponechat obě strany.

## Co už existuje (reuse)
- Koeficient 0–255 a útlum Q24 (`PrusakKoeficient`, `PrusakUtlum`); dosah v čase `PrusakDosah`; šířka pobřežního pásu `PobrezniPas` z K, porozity a koeficientu za horizont 30 dnů, s tlakem. Přepínače `PrusakKoeficient` a `PrusakPobrezi` výchozí vypnuto.
- Katalog: vápenec a dolomit mají K matrice 3e-8 m/s (třída koeficientu ~20), proto pás 0,01 m. Přitom jsou v `KatalogMaterialu.RozpustneKlice` (kras: `cave_limestone`, `deep_limestone`, `dolomite`, `limestone_outcrop`; sádrovec a sůl taky, ale nejsou uhličitany).
- `Propustnost.X` (generátor pramenů a profilů) se z puklin **nesmí** měnit – otisky při vypnutých přepínačích zůstanou.

## Návrh
- **Data** (`prusak_v1.json`, pole `pukliny`): pro krasové uhličitany (`cave_limestone`, `deep_limestone`, `dolomite`, `limestone_outcrop`) efektivní K = 1e-4 m/s (jako písek), koeficient 178, porozita 0,35 (stejné τ₀ jako u písku → stejný dosah 1,59 / 2,65 / 3,60 m podle spádu 10 / 50 / 200 ‰). Sádrovec a sůl se zatím nechávají bez puklin (nejsou uhličitany); zapsat jako otevřený bod.
- **Výpočet:** `PrusakKoeficient` po tabulce z K použije přepis `pukliny.koef`. `PobrezniPas` a model dutiny berou efektivní K a porozitu z `pukliny`, jinak z katalogu. Celočíselně jako dosud (Q24, mm, ms). `Propustnost` (generátor) se nemění.
- **Přepínače:** žádný nový. Pukliny se uplatní jen při zapnutém `PrusakPobrezi` (pás) nebo `PrusakKoeficient` (dutina). Vypnuto = konstanta 5 m, otisky jako na main dfcb9ff.
- **Sloučení:** větev z main dfcb9ff, merge `gen-v1-prusak-pobrezi` (obsahuje i koeficient). Konflikty: v deníku oba záznamy (7/7b i průsak) v časovém pořadí; v `Program.cs` testů `TestyKrok07` i `TestyPrusak` / `TestyPrusakPobrezi`. Ostatní (DataSveta, KonfiguraceSveta, ErozeNastroj, nástroje) sloučit tak, že zůstanou klima i průsak.

## Hypotézy
- H1: s puklinami je dosah vápence a dolomitu stejný jako u písku (1,59 / 2,65 / 3,60 m při 10 / 50 / 200 ‰, horizont 30 dnů, strop 16 m). Bez puklin zůstane 0,01 m.
- H2: podíl břehů s pásem 1–3,5 m vzroste (dříve ~13 % jen písek; vápence byly ~0,01 m a tvořily velkou část břehu – cave_limestone, deep_limestone, dolomite).
- H3: příznaky vypnuty, klima výchozí zapnuto: otisky = main dfcb9ff (voda 14,14 **377a8210f82c856a**, prameny 3×3 **21**, vodníků **86**; krok 3 9f32311e046f8b6a; mapa 800d420bb00047de). `Krok5()` a `Krok06()` beze změny (7714d1a1d34e00ad / 8e239a68c6d01be0, 18 / 20 pramenů).
- H4 (možný negativní): sádrovec a sůl zůstanou těsné (pás 0). Pokud Jan bude chtít i je, stačí doplnit do `pukliny`.
- H5 (možný negativní): porozita 0,35 je „písková“, ne puklinová (ta bývá 0,01–0,05 a čelo by při stejném K uteklo až na strop). Je to záměr, aby pás seděl na 1,5–3,5 m.

## Měření
Šířky pásu krasových břehů před/po; podíl pobřeží se změněnou šířkou (seed 49 a další); řezy vápencovými břehy (`shots/prusak-kras/`, česky, před/po); otisky s klimatem zapnutým a předvolbami Krok5/Krok06, příznaky vypnuto; testy na main dfcb9ff a na větvi; `git merge-tree`.

## Výsledky
(doplní se po experimentu)
