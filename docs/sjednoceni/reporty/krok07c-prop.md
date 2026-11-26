# PROP – Krok 7c: hladina podzemní vody podle klimatu, oprava propadu u břehu

Větev `gen-v1-krok07c-hladina-klima` z main `e2d55d2` (tag `gen-v1-prusak`, prusak sloučen, přepínače vypnuté). Z větve `gen-v1-rez-poust` převzat nástroj řezu (cherry-pick `395f0ae`). Napsáno 2026-11-26 13:30 SEČ, před experimenty. Bez merge do main.
Zadání Jana 13:24 (+ upřesnění 13:24 a 13:26):

1. **Klima snižuje hladinu v suchu.** Hladina podzemní vody **neexistuje všude**. Existuje jen tam, kde je dobíjená: odtok klimatu `w` nad laditelným prahem, pobřežní pás u moře, aktivní koryta (řeky), oázy a vodníci. Střední stav mezi tím: čím menší dobíjení, tím hlouběji pod povrchem (desítky metrů). V suché poušti bez dobíjení **není žádná hladina** (stav „bez hladiny“, ne jen hluboko); řez tam čáru nekreslí. Spojitě a deterministicky, parametry v `klima_v1.json`. Jen se zapnutým klimatem; bez klimatu staré chování a staré otisky.
2. **Oprava propadu ~6 m** těsně za břehem. Regionální hladina u moře „vidí“ mořské dno (vážený průměr povrchu v poloměru 48 m zahrnuje uzly pod hladinou moře) a stáhne pevninskou hladinu pod hladinu moře i pod sklonovou hladinu. Pevninská hladina nesmí být stažena uzly mořského dna. Regresní test.
3. **Řezy:** zvodnělá (nasycená) zóna šrafou přes barvy materiálů (buňky pod hladinou, kam voda dosáhne = propustné těleso; těsnění zůstává bez šrafy), v české legendě (Jan 13:26).

## Návrh

### Oprava 2 (`RegionalniHladina`)
- Uzly světové mřížky (8 m) v **moři** (`JeMore`: povrch < hladina moře a maska k < 0,5) se do váženého průměru G nezapočítají (`ParametryVody.HladinaBezMorskychUzlu`, výchozí zapnuto, `false` = starý výpočet). Když nezbude žádný pevninský uzel (bod uprostřed moře nebo úzký poloostrov), použijí se všechny uzly jako dosud.
- V pásu přechodu u břehu (smoothstep z 60 m) se pevninská hladina nesmí dostat pod hladinu moře: `l = max(l, hladina moře)` jen v pásu; za pásem platí sklonová hladina bez ořezu.

### Změna 1 (`NapajeniVody`, nový `Klima/NapajeniVody.cs`)
Pole dobití **e ∈ [0, 1]** na mřížce mapy klimatu (32 m, torus, bilineárně jako klima) s hodnotou „bez hladiny“ tam, kde e = 0:
- e_w = smoothstep(`HladinaWPrah`, `HladinaWPlna`, w), takže pod prahem `w < HladinaWPrah` je e_w = 0.
- Zdroje (e = 1 uvnitř plného poloměru, k nule v dosahu, smoothstep): pobřeží (uzly moře, `HladinaBrehPlneM` / `HladinaBrehDoM`), aktivní koryta (`Aktivni`, `BezKoryta`; `HladinaKorytoPlneM` / `HladinaKorytoDoM`), vodníci a oázy (`HladinaZdrojPlneM` / `HladinaZdrojDoM`).
- e = max(e_w, e_zdrojů).
- Hladina: `L = L_sklon − HladinaSuchoM · (1 − e)`, `e = 0` ⇒ `NaN` (bez hladiny). Pobřežní přechod u moře a hladina v moři = hladina moře jsou nad tím a zůstávají (v moři `Surova` = hladina moře i při e = 0).
- Zapíná jen klima (`SvetKrok06.Klima != null`). Bez klimatu `Napajeni = null` ⇒ výpočet beze změny.

### Navazující kód
`NaN` = bez hladiny. Prameny (zóna vývěru: `prevys < 0` musí odfiltrovat i `NaN`), `ProfilSloupce` (bez hladiny ⇒ žádná nasycená, zavěšená ani sevřená voda), `Vykon` (strop pramene bez hladiny = nula), `Blok`, nástroj řezu (CSV `NaN`, čára se nekreslí), otisky.
Prameny ze seedu už jsou násobené `w` (`KlimaW`). Nová hladina je přísnější: vývěr potřebuje hladinu u povrchu, tedy jen tam, kde e ≈ 1.

## Hypotézy
- H1: bez klimatu (`Krok06()`, `Krok5()`, `--bez-klimatu`) beze změny otisků, **kromě** oprava 2 u pobřeží (kontrola: s `HladinaBezMorskychUzlu = false` shodné staré otisky; s opravou se změní jen voda v pobřežním pásu).
- H2: oprava 2: v 5 m pásu za břehem na řezu desert a mírné planety klesne hloubka hladiny z ~6 m na ≲ 1,5 m; hladina nikde na pevnině pod 60 m u břehu.
- H3: pouštní planeta (w = 0): hladina neexistuje mimo pobřežní pás, oázy a okolí vodníků; počet seedových pramenů 0 jako dosud.
- H4: mírná planeta: `w` ≈ 0,7–0,8, ostrov bez hladiny maximálně lokálně (srážkový stín); start 3×3 beze změny počtu pramenů (≈ 21 / 3×3 ověřit), počet vodníků 86 beze změny.
- H5: determinismus: stejná mapa klimatu ⇒ stejné pole e ⇒ stejné otisky při 1 a 8 vláknech.

## Měření
Testy C# (main `e2d55d2`, větev), `klima otisky` vyp/zap před a po, řezy: poušť 200 m / 1 km a strmé mírné pobřeží (krok06g) do `godot-prototyp/shots/krok07c/`, hloubky hladiny podél řezů, počty pramenů / vodníků / oáz, `git merge-tree` proti main. Negativní výsledky zapsat.

## Výsledky (2026-11-26 14:05 SEČ)

### Oprava 2: negativní výsledek a konečné řešení
- **Varianta z návrhu (mořské uzly z průměru vynechat) nestačí a na strmém pobřeží škodí.** Průměr jen z pevninských uzlů je jednostranný: na svahu leží těžiště pevninské půlky okna výš než bod. Na strmém řezu kroku 6g hladina za břehem skočila **nad** povrch (až +4,4 m, tedy falešná zóna vývěru hned u břehu), na pouštním pobřeží klesla jen z 6,3 na 2,1 m.
- **Konečné řešení:** uzel v moři vstupuje do průměru **hladinou moře** (60 m, tlaková výška moře), ne hloubkou dna (`HladinaBezMorskychUzlu`, výchozí zapnuto). Navíc **podlaha**: kde je v okně hladiny podíl mořských uzlů ≥ `HladinaPodlahaPodil` (0,05), není pevninská hladina pod hladinou moře; dál se podlaha plynule snižuje o `HladinaPodlahaM` (10 m) a mizí. Podlaha je nutná, protože hladina u pobřeží se ještě snižuje o hrubou erozi (5,3 m u pouštního břehu, krok 6b), což ji táhlo pod hladinu moře i bez mořského dna.
- Řez pouštní, do 25 m za břehem: největší hloubka hladiny **6,34 m → 2,05 m**, minimum hladiny 53,68 → **59,16 m** (0,8 m pod hladinou moře ≈ 25 m za břehem, kde podlaha už neplatí a hladina se napojuje na sklonovou). Řez strmý mírný: nejhlubší hladina ve 25 m od břehu 3,07 m → 2,98 m, minimum hladiny 59,08 → **60,14 m** (nikde pod mořem).
- Sklon hladiny podél řezu spojitý (max skok na 0,25 m 0,27–0,34 m).

### Změna 1: dobití hladiny (`NapajeniVody`)
Výchozí hodnoty `klima_v1.json`: `HladinaWPrah` 0,05 (pod tím bez hladiny), `HladinaWPlna` 0,3 (od tohoto w plně dobitá; první zkouška 0,5 snižovala hladinu na 32 % pevniny mírné planety, proto 0,3), `HladinaSuchoM` 30 m, pobřeží plné 100 m / do 400 m, koryta 48 / 160 m, oázy a vodníci 96 / 250 m. Pole dobití e ∈ [0, 1] na mřížce 32 m, bilineárně; e = 0 ⇒ hladina neexistuje (NaN), jinak sklonová hladina − 30 m·(1 − e).
- Pevnina bez hladiny / částečně (hlouběji) / plně dobitá (seed 49, `klima mapa`): **poušť 71,9 % / 21,1 % / 6,9 %**, step 43,4 / 40,8 / 15,9 %, **mírná 0,3 / 16,9 / 82,8 %**.
- Poušť, řez 1 km: hladina existuje do s ≈ 776 m (u břehu na hladině moře, dál klesá: s=285 3,6 m, 400 m 8,0 m, 520 m 12,8 m, 600 m 21,6 m, 700 m 29,5 m, 750 m 31,3 m), od **s = 776 m dál (224 m do konce řezu) hladina není**.
- Prameny: poušť (w = 0) 0 seedových pramenů jako v 7b; mírná planeta start 3 × 3 **21 = 21** (7b = 7c), oblast (22400, 5200) 512 m: 23 = 23. Vodníci 86 beze změny (hladinu nepoužívají).
- Otisky seedu 49 s novým výchozím: krok 3 `9f32311e046f8b6a`, mapa `800d420bb00047de`, klima mírná `cb11da8d141a2a5e`, voda 14,14 `377a8210f82c856a`, 21 pramenů 3×3, 86 vodníků; bez klimatu `8e239a68c6d01be0`, 20 pramenů, 92 vodníků: **všechny beze změny** (blok 14,14 neleží u moře; u pobřeží se voda mění opravou 2, viz H1).
- Testy: main `e2d55d2` **228 / 0 chyb**, větev **254 / 0 chyb** (26 nových).

### Hypotézy
- H1: bez klimatu otisky beze změny. Splněno pro start a blok 14,14; **pobřežní bloky** se opravou 2 mění (vypnutí `HladinaBezMorskychUzlu: false` + `--stare-dno` je vrátí). Celoplanetární otisk bez klimatu neměřen.
- H2: splněno s výhradou (podlaha: 0,8 m pod mořem 25 m za břehem na poušti).
- H3: splněno (hladina jen v pobřežním pásu do ~700 m, u oáz, vodníků, aktivních koryt).
- H4: splněno (21 = 21 pramenů, 86 vodníků).
- H5: splněno (test determinismu pole dobití; klima nezávisí na vláknech jako dosud).

### Zjištění a otevřené
- Hranice „hladina → bez hladiny“ je skok (hloubka ~31 m → NaN) tam, kde e dosáhne 0. Spojitější by byl „vyschlý“ pás, ale NaN je požadovaný stav.
- Bez dobití nemají ani oázy z hrubé mapy dobití mimo kruh 96–250 m; oáza uzel 32 m, bilineární plné dobití jen blízko středu.
- Pokles hladiny o hrubou erozi (6b) je stále pod hladinou moře v pásu 25–100 m za břehem, kde podlaha ustupuje.
- Řezy: `godot-prototyp/shots/krok07c/` (poušť 200 m, 1 km, strmé mírné pobřeží 100 m), šrafa = zvodnělé buňky (propustné těleso podle modelu, tj. K ≥ práh nebo rozpustná hornina vč. vápence, dolomitu a soli; těsnění bez šrafy), červený pruh nahoře = bez hladiny.
