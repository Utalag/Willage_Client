# Sjednocení Willage – osnova

Začátek: Jan 2026-11-20 14:08 SEČ (t709u): „Máme teď hodně větví a variant výpočtů… Budeme tedy teď sepisovat aktuálně finální stav. Vezmeme to od začátku a napříč větvemi zkusíme vybrat nejvhodnější řešení. Můžeme otevřít i starší otázky a přehodnotit i některé už rozhodnuté.“

Upřesnění od Jana:
- **t710u:** jde o **datový model světa**. Vzhled je jen základní, materiály se rozliší barvou. Jestli bude pohled 2D (dlaždice), nebo 3D (modely), není rozhodnuté, takže datový model na tom nesmí záviset. Vykreslování, LOD, průhlednost a shadery tvoří prezentační vrstvu.
- **t712u:** rozhodnutí padají v chatu s Janem a teprve potom se zapíšou sem. Kapitoly jsou kostry, pole **Platí:** se vyplňuje až po rozhodnutí.

## Jak se s tím pracuje

1. Ke každému bodu kapitoly je současný stav, varianty z větví s čísly, doporučení a otázka.
2. Body se s Janem procházejí po jednom v pořadí níže.
3. Po rozhodnutí se do pole **Platí:** zapíše pravidlo s datem a citací Jana. Nahradí-li to starší rozhodnutí, uvede se i ono.
4. Teprve podle vyplněných kapitol se slučují větve. Každé sloučení má vlastní PROP a kontrolu výchozí hry, nebo novou referenci, pokud se výchozí hra mění záměrně.
5. Na větvi `sjednoceni` jsou jen dokumenty. Do main až s Janovým ano.

## Soubory

| Soubor | Obsah | Stav |
|---|---|---|
| [`00-mapa-vetvi.md`](00-mapa-vetvi.md) | všechny větve a studie, přepínače, čísla, rozhodnutí, konflikty K1–K12, prezentační vrstva | hotový podklad |
| [`materialy.csv`](materialy.csv) | návrh jedné tabulky materiálů (78 id, přibližné hodnoty, `~` = odhad) | návrh k 1.6 |
| [`01-principy-a-vstupy.md`](01-principy-a-vstupy.md) | kapitola 1: pojmy, jednotky, výška sloupce, funkce světa, determinismus a verze, materiály, geologie, voda, přepočet vody, kontrakt, datový rozpočet, objektová vrstva, profil ostrova | rozhodnuto (přepočet verze 1.5 odložen, 1.11 přeskočeno) |
| [`02-model-sveta-a-generovani.md`](02-model-sveta-a-generovani.md) | kapitola 2: pořadí kroků generátoru, rozhraní funkce světa, slupka, segment a rozdíl, výchozí voda, vegetace, test 3 × 3 | rozhodnuto |
| [`03-otevrene-body.md`](03-otevrene-body.md) | zbývající otevřené body po kapitolách 1–2, podle původních kapitol 3–8 (voda, kopání, přenos výřezu, kontrakt WTI1 společně s Willage-backend, prezentace, plán slučování) | kostra, čeká na Jana |

## Pořadí bodů kapitoly 1 k projití s Janem

1. **1.1 Pojmy:** ostrov, blok, segment, buňka; hierarchie ukládání ostrov → blok → segment → buňka, ostrov jako jednotka ukládání, svět (1.4) se s ostrovem nesmí zaměňovat – *rozhodnuto 2026-11-20 (t713u, t714u), doplněno (t741u–t743u)*.
2. **1.3 Výška sloupce:** výčet 32 / 64 / 128 m, výchozí 128 m, neutrální úroveň v polovině – *rozhodnuto 2026-11-20 (t716u, t717u)*.
3. **1.4 Zdroj pravdy o terénu:** herní svět ze spojité funkce bez vlastních bloků, blueprint řezáním, segmenty ukládají buňky; výchozí velikost 3 × 3 bloky, maximum 4096 × 4096 m (parametr), ostrov se rozšiřuje vkládáním; ostrov procedurální = seed + parametry + verze + seznam vložení (nese i seed a verzi zdrojového světa), ukládá se jen rozdíl proti funkci – *rozhodnuto 2026-11-20 (t718u, t719u), doplněno (t744u–t749u, t761u–t762u, t801u–t803u)*.
4. **1.2 Jednotky a jemná mřížka:** procedurální svět; generuje se jen zorné pole + okraj a slupka 2–3 buněk u vzduchu (0,25 m z funkce), hlubší buňky až při odkrytí, podzemní voda jako funkce – *rozhodnuto 2026-11-20 (t799u, t800u)*.
5. **1.5 Verze generátoru:** determinismus povinný, změny a vložení nesou verzi (t801u–t803u); přepočet při nové verzi *odložen 2026-11-20 (t726u)*.
6. **1.9 Přepočet vody:** lokální = plný, výřez na povodí + asynchronně na pozadí, prodleva 2 s / strop 10 s; testovací scénář „dva hráči“ (postupné odtékání po zastavení přítoku) – *rozhodnuto 2026-11-20 (t734u, t735u), doplněno (t776u–t778u)*.
7. **1.8 Voda jako data:** obsah buňky v m³, povrch priority-flood + D8, výchozí podzemí E67, čas 1 den = 1 h; vsakování: propustnost X v l/s herního času při spádu 1, skutečný tok = X × spád včetně výšky vody, min dvou materiálů; artéská voda; pramen (jmenovitý výkon omezený okolím, jednoduchý / tlakový model); eroze E51 (práh `ero_v`, odnos průtok × (v/práh)^k, výchozí k = 1,5) – *rozhodnuto 2026-11-20 (t732u), doplněno (t765u–t785u)*.
8. **1.11 Datový rozpočet:** *přeskočeno 2026-11-20 (t738u)*.
9. **1.6 Materiály:** jedna tabulka, jedno id – *rozhodnuto 2026-11-20 (t727u)*, návrh `materialy.csv`.
10. **1.7 Geologie:** útvary jako funkce světa přes švy, vrstvy podle terénu, vyklínění; skladba vrstev, mapa složení na maximální ploše (hrubé body ze seedu, interpolace), 1–3 zástupci v pásmu, min. 1 buňka, švy 1/16 bloku – *rozhodnuto 2026-11-20 (t732u), doplněno (t750u–t763u)*.
11. **1.12 Objektová vrstva:** terén a rostliny po segmentu (otáčejí se s blokem), stavby a cesty seznam na ostrově, smějí přes hranici bloku – *rozhodnuto 2026-11-20 (t739u, t740u), změněno (t741u–t743u)*.
12. **1.10 Kontrakt:** WVB1 základ, data po segmentech, voda v litrech (1 B), server ukládá seed, parametry, verzi, seznam vložení a rozdíl proti funkci, namátkově kontroluje generátorem (vypínatelné) – *rozhodnuto 2026-11-20 (t736u, t737u), změněno (t801u–t803u)*.
13. **1.13 Profil a členitost terénu:** parametry členitosti (rozhodnuto); bok ostrova jen prezentace: bloky s texturou 5 m pod nejnižší okrajovou buňkou, v té výšce oblaka, voda padá do oblak – *rozhodnuto 2026-11-20 (t805u–t807u)*.
14. **1.14 Sopka:** neaktivní, události ji probudí a uspí; tvar mezi strato a štítovou (sklon 17°); větší 40 m / 2 bloky, nižší 20 m / 1 blok; vrchol aspoň 5 m pod okrajem sloupce; počet a rozteč jako parametry světa (2, 3 bloky); průduch id 75 a kuželovité vrstvy lávy a popela, těleso se propíchne běžnými vrstvami jako skalní jádro (rozhodnuto).

## Pořadí bodů kapitoly 2

1. **2.1 Pořadí kroků generátoru:** funkce světa (reliéf a sopky) → geologie a útvary (sopka vrstvy propíchne) → výchozí voda jako funkce → vegetace ze seedu; buňky až ve slupce; minerály a dutiny jako útvary funkce.
2. **2.2 Rozhraní funkce světa:** dotaz na bod a sloupec v metrech, objekty E88 (Source / Transform / Placement / Instance), inverzní transformace vložení, řídicí mřížka se neukládá.
3. **2.3 Slupka a líné generování:** obnažené buňky (vzduch, dno průhledné vody), okraj zorného pole jako parametr, donačtení při odkrytí.
4. **2.4 Segment a rozdíl:** výchozí 8 m, formát E78 / WTI1, 16 / 32 m jen jako parametry k měření.
5. **2.5 Výchozí voda:** zůstává funkcí, počítá se ve slupce nebo na povodí, ukládají se prameny a odchylky.
6. **2.6 Vegetace:** funkce seedu (hustota na m²), ve slupce, na disk jen změny.
7. **2.7 Testovací pipeline 3 × 3:** svět → 9 blueprintů → ostrov; měření slupky, rozdílu, vody a determinismu. Stavět až po rozhodnutí 2.1–2.6.

## Pořadí otevřených bodů (kapitoly 3–8, jen to, co 1–2 nerozhodly)

1. **6.1** Co server ověřuje a zda posílat snímek buněk (E88 č. 4) — společně s Willage-backend.
2. **6.3** Serverová kontrola a mazání ověřených dat.
3. **6.2** Tvar verze generátoru `gen_ver` (E88 č. 11).
4. **4.1** Zapisovat erozi E51 do překryvu (E88 č. 7).
5. **5.1** Rohoví sousedé v kontraktu (E88 č. 6).
6. **5.2** Výchozí režim napojení švů (Auto / Blend / Keep).
7. **3.2** Slučovat drobné výstupy v dosahu 8 m i mezi sebou?
8. **7.1** Pohled 2D (dlaždice), nebo 3D (modely)?
9. **7.2** LOD prezentační vrstvy.
10. **7.3** Průhlednost a řez v izometrii (E91).

Odložené (teď se neptám): přepočet při nové verzi generátoru (1.5) včetně E88 č. 3; datový rozpočet 1.11. Úkoly implementace jsou na konci `03-otevrene-body.md`, nejsou to rozhodnutí.

## Legenda

- **rozhodnuto (datum)** = Jan rozhodl, s citací. ⚠ = novější měření to zpochybňuje.
- **K1–K12** = konflikty z `00-mapa-vetvi.md` §6.
- **Blueprint** = otisk oblasti herního světa o velikosti jednoho bloku (128 m). Vložený blueprint je blok ostrova.
- **[n]** = zdroj ze seznamu na konci kapitoly (soubor a commit).
- Časy jsou v SEČ (Europe/Prague). Měření jsou z boxu (Linux x86_64), telefon zatím není změřený.
