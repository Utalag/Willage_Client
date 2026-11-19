# PROP – tezba-studie

Samostatná studie těžby a rozkladu hornin (Jan 13:55). Číslování záznamů je **T01, T02, …**.
První záznam je přesunutý návrh z blueprint-studie E65.

## T01 (dříve E65) vlastnosti a těžba hornin, katalog výrobků (návrh 2026-11-19 13:43; přesun 13:55; Jan 13:23 rozhodnutí, 13:27–13:39 hypotézy)


- **Plán:** jen rešerše a návrh, žádný herní kód, žádný commit (souběžně doběhlo E64).
  Existující tabulky `materialy_voda.json` a `horniny_voda.json` se nepřepisují.
  Nejdřív zapsat, co už je (pořadí hornin, load/cantilever, rarita, výnos 17:53, WVB1),
  pak typické reálné hodnoty a návrh těžby / zpracování.
- **Rozhodnutí Jana v tomto návrhu:**
  - 17:53: kopání dá vždy 1 blok materiálu + šance na nález. Platí dál pro krok kopání.
  - 13:23: každá hornina má seznam získatelných surovin. Blueprint vrstvy může přepsat
    procenta. Součet 1000 ‰, jen suroviny povolené u té horniny.
  - 13:31: po identifikaci zůstanou obě jména (vlastní i skutečné). Vlastní může hráč sám smazat.
- **Hypotézy (ne rozhodnutí):**
  - 13:27: zpracování rozloží horninu v poměrech bloku; Mineralogie poznává suroviny;
    neznámé stejně padají („neznámý minerál“ se znaky).
  - 13:33: krystaly mají kvalitu; broušení, drcení, destilace a rozklad; chemie / alchymie
    je jiná dovednost než Mineralogie.
  - 13:36: katalog běžných výrobků (sklo z drceného křemene, vápno, malta, kovy, …).
  - 13:39: popisy v katalogu jsou základ koupitelných receptů. Koupený recept dá jen
    průměrnou kvalitu. Ve výrobní jednotce lze recept ladit (poměry, teplota, čas, přísady,
    čistota vstupů) ke skrytému optimu a výrazně lepší kvalitě.
- **Postup:** rešerše existujících souborů a reálných hodnot (Mohs, UCS, hustota, CAI, jakost
  rud, řád času kopání) [1]–[12]. Návrh jedné tabulky a trojí varianty času nástrojů.
  Výnosy s výchozími podíly podle typického použití. Kusový výnos u drahokamů zvlášť
  (diamant v kimberlitu není objemové %, typicky 0,02–10 ct/t [9]).
- **Doporučený model (hypotéza, kromě bodů výše):**
  - Dvoukrokově: kopání zachová 17:53 a WVB1 (1 buňka do inventáře); zpracování rozloží
    buňku podle podílů (výchozí nebo přepis vrstvy).
  - Čas i výnos úměrné objemu (0,5 m = 0,125 m³; při 0,125 m vše × 1/64).
  - Třídy tvrdosti: ruka / kámen / bronz / železo / ocel. Trhaviny jen zrychlení a víc suti.
  - Hybrid času A+B: slabší nástroj o 1–2 stupně kopat nemůže, jinak čas podle síly.
  - Zvlášť historický čas po × 144 a kratší `t_navrh_s` ke hře (žula historicky ~63 s na
    buňku 0,5 m, návrh 12 s).
  - Přepis podílů jako volitelné pole WVB1 (nový bit flags), ne do `params` zásobníku.
  - Rarita-v2 se nemění; bonus z kvality výnosu je otevřená otázka.
- **Výsledek / soubory:**
  - `data/horniny_tezba_navrh.json` — 83 položek (horniny, aliasy, minerály), suroviny,
    třídy, časy, výchozí podíly, schéma přepisu, znalosti, řetězce, recepty.
  - `navrhy/horniny-vlastnosti-tezba.md` — návrh modelu.
  - `navrhy/katalog-materialu.md` — výrobky, jednotky, laditelné parametry, náčrt funkce kvality.
  - `shots/65_horniny_tezba.png` — Mohs × UCS a pevnost podle min. nástroje.
  - ZDROJE [1]–[28] (v této studii; v blueprint-studii zůstaly zástupné [45]–[72]).
- **Negativa:**
  - UCS a CAI mají široké rozsahy. Typická hodnota zařadila gabro k oceli (228 MPa) a žulu
    k železu (154 MPa), i když se často těží podobně. Práh jde posunout.
  - Horské pojmenované horniny dědí žulu / rulu / kvarcit. „Hlubinný vápenec / křída“ má
    hodnoty vápence, ne křídy.
  - Podíly surovin u běžných hornin jsou herní, opřené o použití, ne o laboratoř.
  - Jakost rudných buněk je abstrakce ložiska, ne průměr porfyru 0,44 % Cu [8].
  - Pole ani recepty jsem ve hře nezkoušel.
- **Otevřené pro Jana:** dvoukrok vs rozklad hned při kopání; varianta času A/B/C/hybrid;
  historický čas vs `t_navrh_s`; bronz a trhaviny; vliv kvality na raritu-v2; pole WVB1;
  Mineralogie třídy / body / hybrid; recepty (13:39) natrvalo, skryté optimum, sdílení ve vesnici.

## T02 strom hornin, obsah a další rozklad surovin (plán 2026-11-19 14:20; Jan 14:19 „Vytvoř strom hornin, co obsahují, a jak se dají dále suroviny rozložit.“)

- **Cíl:** jeden přehledný strom: hornina → co obsahuje (minerály a výchozí suroviny z T01) → jak se suroviny dál rozkládají a zpracovávají → výrobky a prvky. Navazuje na T01, herní kód se nemění, bez commitu.
- **Data:** všechny horniny z `data/horniny_tezba_navrh.json` (bez aliasů a vzduchu). Skupiny: vyvřeliny, přeměněné, usazené, rudy, zeminy. Výchozí podíly surovin z T01 (součet 1000 ‰). Základní vždy známý výnos se označí (kámen, štěrk, písek, jíl, hlína, sůl, uhlí… — bez Mineralogie). Složení minerálů je typické, reálné, jen orientační.
- **Další rozklad:** navázat na `navrhy/katalog-materialu.md` (drcení, broušení, pálení, tavení, destilace, loužení, hašení, slévání). U každého kroku dovednost z T01 (Mineralogie, Kamenictví, Chemie / alchymie, Hutnictví, Sklářství, …).
- **Výstupy:**
  - `data/strom_rozkladu.json` — uzly a hrany (operace, vstupy, výstupy, podíly, dovednost)
  - `navrhy/strom-hornin.md` — česky, u každé skupiny čitelný mermaid
  - `shots/T02_strom_*.png` — jeden přehled skupin a 2–4 detaily na skupinu, čitelné na telefonu
  - `tools/strom02.py` — sestaví data i obrázky a zkontroluje konzistenci (základní výnos u každé horniny, součet 1000 ‰, existující vstupy hran, cykly jen označené)
- **Kreslení:** Graphviz (`dot`) v prostředí není; použiju matplotlib + networkx a vrstvené rozložení (zleva / shora dolů).
- **Zdroje:** složení hornin doplním do `ZDROJE.md` od [29] výše. Zpracování beru z T01 [13]–[28], pokud nebude potřeba nové.

- **Výsledek (2026-11-19 14:35):** datový strom a kontroly prošly. Graphviz (`dot`) v prostředí není, obrázky jsou z matplotlib (vrstvy shora dolů, české popisky Liberation Sans).
  - 74 hornin (bez aliasů a vzduchu): vyvřeliny 21, přeměněné 19, usazené 13, rudy 10, zeminy 11.
  - 34 minerálů, 22 surovin T01, 28 výrobků, 12 prvků, 3 vnější vstupy (dřevo, dřevěné uhlí, soda), 2 mezery (galenit, rumělka).
  - 175 uzlů, 550 hran, 46 procesů, 20 unikátních operací.
  - Každá hornina má základní výnos; výnosy i typické složení sčítají 1000 ‰. Cyklus je jen vápenný (malta → kalcit / písek), označený `cyklus`.
  - Soubory: `data/strom_rozkladu.json`, `navrhy/strom-hornin.md`, `tools/strom02.py`, 24 obrázků `shots/T02_strom_*.png`.
  - Nové zdroje složení [29]–[38]. Zpracování bere T01 [13]–[28].
- **Úprava rozložení (2026-11-19 14:37, recenze Jana):** detaily (např. kovy) byly nečitelný chumel. Graphviz (`dot`) nejde nainstalovat. Rozložení je teď v matplotlib zleva doprava: jeden pruh na vstupní surovinu / rodinu, vrstvy podle nejdelší cesty, řazení barycentrem, výška pruhu podle počtu uzlů ve sloupci. Huby (struska, dřevěné uhlí, koks jako palivo, soda, na snímku mědi i cín) nejsou samostatné uzly, jen popisek hrany („+ dřevěné uhlí“). Rudy jsou rozdělené po kovech (měď+bronz, železo+ocel, cín, zlato, vzácné, uhlí, drahokamy); přeměněné a usazené mají zvlášť stavbu a oheň. Všechny snímky zkontrolované vizuálně. Počet křížení hran (pravý průnik úseček, bez sdíleného vrcholu): 0 na každém snímku, `krizeni_celkem=0`.
- **Negativa / mezery:** typické složení je střed rozsahů, ne zákon. 20 ‰ zlata ve složení buňky je herní abstrakce (reálně g/t, [37]). `ruda_vzacne` míchá Li, Sn a Ta. Chybí ložiska olova a rumělky. Kaolin není oddělený od jílu. Soda a dřevěné uhlí jsou vnější vstupy. Výtěžky tavení jsou herní, ne stechiometrie. Hnědé uhlí nemá větev na koks. Pigmenty z malachitu / hematitu jsou v datech, na obrázku kovů nejsou hlavní větví.
- **Otevřené pro Jana:** složení jako vrstva znalostí, nebo stačí výnosy; olovo a rumělka jako ložiska; rozdělení `ruda_vzacne`; abstrakce zlata 20 ‰ vs kusový nález.

## T03 základní stroje, stavby a zařízení na zpracování (plán 2026-11-19 14:50; Jan 14:49 „Přidej i seznam základních strojů, staveb a zařízení na jejich zpracování“)

- **Cíl:** přehled základních výrobních jednotek, které provádějí operace ze stromu T02. Každá operace / hrana ve `data/strom_rozkladu.json` musí mít aspoň jedno zařízení. Herní kód se nemění.
- **U každé položky:** český název; typ (stroj / stavba / zařízení / nástroj); které operace ze stromu provádí; přijímané vstupy a výstupy; hrubý reálný popis (jak to funguje, zdroj energie: ruka / voda / zvíře / oheň / dřevěné uhlí); technický věk (primitivní → středověk → raně průmyslové); z čeho se to staví (materiály z katalogu, uzavření smyčky); která dovednost to obsluhuje; které parametry receptu jde ladit (teplota, čas, poměry).
- **Příklady k pokrytí:** drtič / stoupa, mlýn, brusná dílna, vápenka, cihelna / milíř, sklářská pec, kelímek, dmýchací pec / výheň, hamr, kovárna, ryžovací splav, loužicí kádě, destilační přístroj / alembik, solivar, pražírna. Doplním jednotky z katalogu (hasicí jáma, mísírna, sádrová pec, hrnčířská pec, koksovna, cementářská pec) a pokrytí hran, které nejsou „ pec“ (těžba, složení, karbonatace).
- **Výstupy:**
  - `data/zarizeni.json` — seznam jednotek (operace, procesy, vstupy, výstupy, věk, energie, materiály, dovednost, ladění)
  - `navrhy/zarizeni.md` — česky, podle věku, s odkazy na operace stromu
  - `shots/T03_zarizeni.png` — jeden snímek čitelný na telefonu: zařízení podle věku a co vyrábějí
  - `tools/zarizeni03.py` — sestaví data i obrázek a zkontroluje, že každá operace i každá hrana stromu má aspoň jedno zařízení a že odkazy (procesy, suroviny, dovednosti) existují
- **Zdroje:** zpracování z T01 [13]–[28], kde stačí; nové zdroje jednotek doplním do `ZDROJE.md` od [39] výše.
- **Mimo rozsah:** vysoká pec (ve stromu je dýmačka, ne blast furnace), moderní elektrické pece, herní kód a vyvážení času / kapacity.

- **Výsledek (2026-11-19 14:55):** seznam jednotek, kontroly a snímek jsou hotové. Graphviz se nepoužívá, plakát je z matplotlib.
  - 25 zařízení (10 primitivních, 13 středověkých, 2 raně průmyslové). Typy: 1 nástroj, 3 stroje, 12 staveb, 9 zařízení.
  - Všech 20 operací a všech 550 hran stromu T02 má aspoň jedno zařízení; všech 46 procesů je přiřazených. Hamr kuje lupu z dýmačky, ve stromu T02 nemá vlastní operaci (`mimo_strom`).
  - Soubory: `data/zarizeni.json`, `navrhy/zarizeni.md`, `tools/zarizeni03.py`, `shots/T03_zarizeni.png`.
  - Nové zdroje jednotek [39]–[53]. Zpracování dál bere T01 [13]–[28] a T02 [36]–[38].
- **Negativa / mezery:** kapacita, obsluha a herní čas jednotek nejsou. Solivar sdílí operaci `destilovat` v širším smyslu čištění. Výtěžky tavení zůstávají herní. Hnědé uhlí pořád nemá větev na koks. Rumělka a galenit jsou dál mezery.
- **Otevřené pro Jana:** doplnit kování lupy do stromu; dýmačka s koksem vs pozdější vysoká pec; oddělit odpar soli od destilace; které jednotky jsou ve vesnici od začátku.
