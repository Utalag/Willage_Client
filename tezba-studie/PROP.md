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
