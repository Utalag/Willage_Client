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
| [`01-principy-a-vstupy.md`](01-principy-a-vstupy.md) | kapitola 1: pojmy, jednotky, výška sloupce, funkce světa, determinismus a verze, materiály, geologie, voda, přepočet vody, kontrakt, datový rozpočet, objektová vrstva, profil ostrova | kostra, čeká na Jana |
| `02-…` (plán) | model světa a generování bloku 128 m (pipeline, segmenty, pořadí vložení, recept) | po kapitole 1 |
| `03-…` (plán) | voda: jeden algoritmus podzemí, oprava lokálního přepočtu, vlákno | po 1.8–1.9 |
| `04-…` (plán) | kopání a překryv 0,25 m, zákaz dna a okraje, ukládání | po 1.2 |
| `05-…` (plán) | přenos výřezu: otočení, švy vrstev, prameny | po 1.4–1.5 |
| `06-…` (plán) | kontrakt se serverem (WTI1), společně s Willage-backend | po 1.10 |
| `07-…` (plán) | prezentační vrstva: co čte z dat, LOD, průhlednost, řez, 2D/3D | po rozhodnutí o pohledu |
| `08-…` (plán) | plán slučování větví a pořadí zapnutí přepínačů | na konec |

## Pořadí bodů kapitoly 1 k projití s Janem

1. **1.1 Pojmy:** ostrov, blok, segment, buňka; hierarchie ukládání ostrov → blok → segment → buňka, ostrov jako jednotka ukládání, svět (1.4) se s ostrovem nesmí zaměňovat – *rozhodnuto 2026-11-20 (t713u, t714u), doplněno (t741u–t743u)*.
2. **1.3 Výška sloupce:** výčet 32 / 64 / 128 m, výchozí 128 m, neutrální úroveň v polovině – *rozhodnuto 2026-11-20 (t716u, t717u)*.
3. **1.4 Zdroj pravdy o terénu:** herní svět ze spojité funkce bez vlastních bloků, blueprint řezáním, segmenty ukládají buňky; výchozí velikost 3 × 3 bloky, maximum 4096 × 4096 m (parametr), ostrov se rozšiřuje vkládáním – *rozhodnuto 2026-11-20 (t718u, t719u), doplněno (t744u–t749u, t761u–t762u)*.
4. **1.2 Jednotky a jemná mřížka:** definice 0,5 m a 0,25 m jen u kopání (přehodnocení 03:26).
5. **1.5 Verze generátoru:** *odloženo 2026-11-20 (t726u)*, dokud nebude jeden funkční generátor.
6. **1.9 Přepočet vody:** lokální = plný, výřez na povodí + asynchronně na pozadí, prodleva 2 s / strop 10 s; testovací scénář „dva hráči“ (postupné odtékání po zastavení přítoku) – *rozhodnuto 2026-11-20 (t734u, t735u), doplněno (t776u–t778u)*.
7. **1.8 Voda jako data:** obsah buňky v m³, povrch priority-flood + D8, výchozí podzemí E67, čas 1 den = 1 h; vsakování: propustnost X v l/s herního času při spádu 1, skutečný tok = X × spád včetně výšky vody, min dvou materiálů; artéská voda; pramen (jmenovitý výkon omezený okolím, jednoduchý / tlakový model); eroze E51 (práh `ero_v`, odnos průtok × (v/práh)^k, výchozí k = 1,5) – *rozhodnuto 2026-11-20 (t732u), doplněno (t765u–t785u)*.
8. **1.11 Datový rozpočet:** *přeskočeno 2026-11-20 (t738u)*.
9. **1.6 Materiály:** jedna tabulka, jedno id – *rozhodnuto 2026-11-20 (t727u)*, návrh `materialy.csv`.
10. **1.7 Geologie:** útvary jako funkce světa přes švy, vrstvy podle terénu, vyklínění; skladba vrstev, mapa složení na maximální ploše (hrubé body ze seedu, interpolace), 1–3 zástupci v pásmu, min. 1 buňka, švy 1/16 bloku – *rozhodnuto 2026-11-20 (t732u), doplněno (t750u–t763u)*.
11. **1.12 Objektová vrstva:** terén a rostliny po segmentu (otáčejí se s blokem), stavby a cesty seznam na ostrově, smějí přes hranici bloku – *rozhodnuto 2026-11-20 (t739u, t740u), změněno (t741u–t743u)*.
12. **1.10 Kontrakt:** WVB1 základ, data po segmentech, voda v litrech (1 B), server ukládá hotová data a namátkově kontroluje generátorem – *rozhodnuto 2026-11-20 (t736u, t737u)*.
13. **1.13 Profil a členitost terénu:** parametry členitosti (rozhodnuto); obrys, bok a spodek ostrova otevřené.
14. **1.14 Sopka:** neaktivní, události ji probudí a uspí; tvar mezi strato a štítovou (sklon 17°); větší 40 m / 2 bloky, nižší 20 m / 1 blok; vrchol aspoň 5 m pod okrajem sloupce; počet a rozteč jako parametry světa (2, 3 bloky); průduch id 75 a kuželovité vrstvy lávy a popela, těleso se propíchne běžnými vrstvami jako skalní jádro (rozhodnuto).

## Legenda

- **rozhodnuto (datum)** = Jan rozhodl, s citací. ⚠ = novější měření to zpochybňuje.
- **K1–K12** = konflikty z `00-mapa-vetvi.md` §6.
- **Blueprint** = otisk oblasti herního světa o velikosti jednoho bloku (128 m). Vložený blueprint je blok ostrova.
- **[n]** = zdroj ze seznamu na konci kapitoly (soubor a commit).
- Časy jsou v SEČ (Europe/Prague). Měření jsou z boxu (Linux x86_64), telefon zatím není změřený.
