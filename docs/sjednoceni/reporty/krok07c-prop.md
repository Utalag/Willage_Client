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
