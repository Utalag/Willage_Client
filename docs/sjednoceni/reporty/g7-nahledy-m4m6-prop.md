# G-7 – náhledy a izolace M4 eroze, M5 klima (tabulka pásem), M6 voda a průsak (řez s hladinou) (PROP)

Větev `gen-v1-g7-nahledy-m4m6` (z `gen-v1-g6-nahledy` 86bec57). Plán 05, tabulka 3.3 a G-7. Nahrazuje zástupné prvky G-6 pro M4–M6
(náhled planety z G-5, „Izolovat vrstvu (zástupné)“, řez „s hladinou … (G-7, 7d)“).
**7d (zvodnělá zóna šířením průsaku + strop hladiny u pobřeží 60 m) je dál odložené (Jan)**: v náhledu i v řezu zůstává jasně označená
zástupná vrstva bez logiky. Mutaci M7 → M3 a vzduch v `MaterialPovrchu` (nálezy G-6) neopravuji – jen dál vedu v seznamu.

## Cíl
1. Fasáda `INahledyModulu` rozšířená o M4–M6 (bez Godotu), každá skupina ve vlastní třídě (žádný monolit):
   - **M4 eroze** (mapa planety 32 m, torus 31 360 × 15 616 m): výška planety po erozi, **posun eroze** H0 − H (izolace „mapa posunu eroze“),
     toky (log₁₀ plochy povodí), jezera, koryta; body = vodníci kroku 6 (bez klimatu); řez = profil před / po erozi.
   - **M5 klima**: teplota, srážky, odtok w, biom klimatu, koryta aktivní / suchá (hydrologie klimatu); body = oázy a vodníci s klimatem;
     izolace „jen klima (bez vlivu na vodu)“ = biom klimatu bez překryvu oáz; **tabulka pásem** (pásma ze `Zemepis` + změřené T, P, podíl biomů
     po pásmech); řez = profil povrchu s řadami teplota, srážky, w.
   - **M6 voda**: hloubka hladiny pod povrchem (surová hladina 7c, NaN = bez hladiny), absolutní hladina, dobití 7c, zóna vývěru, pobřežní pás
     (hladina = hladina moře), **7d zvodnělá zóna – zástupná** (NaN, příznak `zastupny`); body = prameny ze seedu a vodníci; izolace
     „jen hladina“ (bez bodů) / „jen prameny“ (body na šedém povrchu); **řez s hladinou** = materiály po 0,25 m (erodovaná geologie jako nástroj
     `eroze rez`) + povrch + surová hladina + hladina moře + prameny do 150 m od úsečky.
   - Oblast: M4/M5 celá planeta (uzly mapy, nejbližší uzel), M6 výchozí start 3 × 3 bloky (1792…2176 m, kde reporty počítají prameny).
2. Jádro Godot: stejné metody `NahledModulu` / `RezModulu`, navíc `TabulkaPasem`.
3. Okno: `NahledModulu` M4–M6 vlastní vrstvy + nový uzel `BodyNahledu` (překryv bodů), `TabulkaPasem` (Tree, jen M5),
   `PohledRezu` M4–M6 (profil, řady, hladina, prameny), zástupný štítek 7d; `KonfiguratorModulu` izolace M4 / M5 (zap/vyp), M6 (cyklus).
4. Willage.Gen (jádro světa) beze změny.

## Hypotézy / měření
| Test | Očekávání |
|---|---|
| M4 shoda | hodnoty mapy = pole `MapaEroze` v uzlech bitově; otisk mapy `800d420bb00047de`; vodníků bez klimatu 92 |
| M5 shoda s nástrojem / reporty 7–7b | podíly biomů pevniny, w průměr, T min/max, koryta aktivní / suchá = výpis `klima mapa` (report 7b: mírný les 91,0 %, tajga 5,4 %, step 3,6 %, w 0,83, aktivní koryta 73–79 %); oázy 0 na mírné planetě |
| M6 shoda s nástrojem / report 7c | dobití pevniny bez / částečně / plně = `klima mapa` (7c: 0,3 / 16,9 / 82,8 %); prameny start 3 × 3 = 21; řez M6 = `eroze rez` (materiály bajt po bajtu, povrch, hladina) |
| izolace | M4 posun = H0 − H; M5 biom bez oáz liší se jen v uzlech oáz; M6 jen hladina = hodnoty hladiny bez bodů, jen prameny = body beze změny |
| 7d | vrstva i řez zástupné (NaN, `zastupny` = 1), žádná logika 7d |
| determinismus | 1 = 8 vláken; dva náhledy stejné; otisky beze změny |
| okno (headless + Xvfb) | M4–M6 vrstvy, body, izolace, tabulka pásem, řez s hladinou, materiál pod kurzorem; snímky |
| čas | náhled < 1 s (M6 hladina měřím – drahá funkce, případně menší rozlišení) |
| otisky | beze změny; čas celé planety 8,2 s jen zaznamenat |

## Rizika
- Hladina 7c (`RegionalniHladina.Surova`) je drahá (≈ 113 uzlů na vzorek); M6 náhled proto na menší oblasti / rozlišení.
- Nástroj `eroze rez` staví svět s planetárním `SvetMaxM`, okno s výchozím – shoda jen ve startovním světě (ověřím).
- M6 řez z erodované geologie (výstup M7) – to je správně pro vodu, ale je to stejný objekt, který mutace M7 → M3 mění (nález G-6).

## Výsledky
*(doplní se po implementaci)*
