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
(2026-11-26 13:25 SEČ)

### Sloučení do main dfcb9ff
Merge `gen-v1-prusak-pobrezi` (obsahuje i koeficient) do větve z main. Konflikty jen v `DENIK.md` a `cs/Willage.Gen.Testy/Program.cs`: ponechány obě strany (deník v časovém pořadí: koeficient 12:36, krok 7 12:45, pobřeží 13:08, krok 7b 13:20; testy `TestyKrok07` i `TestyPrusak` / `TestyPrusakPobrezi`). Ostatní soubory (DataSveta, KonfiguraceSveta, ErozeNastroj, nástroje) se sloučily samy: zůstalo klima i průsak. Přepínače výchozí vypnuto.

### Šířky pásu krasu (30 dnů; `shots/prusak-kras/sirky_pasu.md`)
S puklinami jsou cave_limestone, deep_limestone, dolomite a limestone_outcrop stejné jako písek: **1,59 / 2,65 / 3,60 m** při spádu 10 / 50 / 200 ‰ (7 d 1,69 m, 90 d 3,40 m). Bez puklin zůstávají 0,00 / 0,01 / 0,02 m. Sádrovec a sůl 0 (bez puklin, H4 potvrzena). H1 potvrzena. H5: porozita 350 ‰ je záměr, aby pás seděl na 1,5–3,5 m (puklinová 1–5 % by při stejném K dojela na strop 16 m).

### Podíl pobřeží (sken 64 m po ose x, spád 50 ‰)
| seed | břehů | před, pás 1–3 m | po, pás 1–3 m | před, &lt; 0,01 m | po, &lt; 0,01 m | kras dominantní po (šířka 2,65 m) |
|---|---|---|---|---|---|---|
| 49 | 2316 | 297 (13 %) | 1463 (63 %) | 1441 (62 %) | 419 (18 %) | 1241 (54 %): jeskyň. 568, hlub. 428, dolomit 245 |
| 1 | 2508 | 286 (11 %) | 1568 (63 %) | 1535 (61 %) | 423 (17 %) | 1362 (54 %) |
| 2 | 1736 | 211 (12 %) | 1072 (62 %) | 1064 (61 %) | 307 (18 %) | 927 (53 %) |
| 3 | 1902 | 256 (13 %) | 1212 (64 %) | 1153 (61 %) | 327 (17 %) | 1016 (53 %) |

H2 potvrzena: **asi polovina břehů změnila šířku** (seed 49: 1166 z 2316, 50 %; z pásu &lt; 0,01 m nebo 0,01–1 m do 1–3 m). limestone_outcrop se na břehu skoro nevyskytuje (není v první osmičce). Část ornice (topsoil) přestala být dominantní, protože v okně 2 m je pod ní vápenec s větším dosahem (seed 49: ornice 512 → 370).

### Řezy
`godot-prototyp/shots/prusak-kras/rezy_kras_pobrezi.png` – tři řezy 100 m, seed 49, celek a detail 20 m u břehu: dolomit (od x 8244 y 992), jeskynní vápenec (od x 20050 y 1760), vápenec + ornice (od x 30500,5 y 4704, směr −x). Oranžová = konstanta 5 m, fialová = pás z koeficientu bez puklin (~0,01 m, čára hned klesá na spád terénu), modrá = s puklinami (~2,65 m). `podil_pobrezi.png` – sloupcový graf podílu břehů.

### Otisky (klima výchozí zapnuto, přepínače průsaku vypnuto) = main dfcb9ff
`klima otisky` keš k49:
| konfigurace | mapa | krok 3 | voda 14,14 | prameny 3×3 | vodníci |
|---|---|---|---|---|---|
| klima vyp (`Krok06()`) | 800d420bb00047de | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 | 92 |
| **klima zap (výchozí)** | 800d420bb00047de | 9f32311e046f8b6a | **377a8210f82c856a** | **21** | **86** |
H3 potvrzena. Stejné i s `--pobrezi` (start 3×3 je daleko od moře). `Krok5()` / `Krok06()` hlídají testy kroku 7 (beze změny). Otisk klimatu cb11da8d141a2a5e, start: mírný les, T 10,1 °C, P 943 mm, w 1,35.

### Testy
`main` dfcb9ff: **OK 156, chyb 0**. Větev: **OK 228, chyb 0**. Negativní při psaní testů (opraveno, ne v kódu knihovny): (1) monotónnost koeficientu proti K matrice padala, protože kras má nízké K matrice a koeficient 178 – porovnává se efektivní K. (2) dutina v dolomitu bez puklin není bitově 0 (matrice dá jednotky µl za hodinu), jen ~10⁹× menší tok než s puklinami.

### Merge
`git merge-tree` proti `main` dfcb9ff: bez konfliktů, main je předek. Bez merge do main.
