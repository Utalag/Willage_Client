# TODO (Willage studie)

Seznam nápadů a úkolů, které čekají na Janovo rozhodnutí nebo na zařazení. Hotové položky se odškrtnou a odkáží na commit nebo tag.

## Voda

- [ ] **E68 – sjednocení výpočtu povrchu a podzemí (hydrologický orchestrátor).** Podnět: konverzace s ChatGPT 2026-11-19 ([sdílený chat](https://chatgpt.com/share/6aff2aa3-865c-83ed-a19c-63720302f8cf)).
  - Jeden společný krok pro povrch, podzemí, tůně, prameny a události: sdílená vodní bilance, jedno pořadí výpočtů a jedno místní přepočítání po změně terénu.
  - Algoritmy zůstávají: povrch priority-flood + D8, podzemí pásma a tělesa (E58 A+B+C, E67).
  - Pořadí: terén a geologie → povrch a podzemí → vodní bilance → události → místní invalidace.
  - Ohlídat smyčku rybník → průsak → pramen → rybník: předávání vody oběma směry s limitem počtu kol, zachování hmoty, deterministický výsledek (hash).
  - Postup: nejdřív krátký návrh (PROP), pak větev s měřením.
- [ ] **Harmonický průměr propustností** sousedních materiálů pro dělení vody do stran v E67 (teď prostý poměr propustností), aby jíl brzdil i sousední písek.
- [ ] **Test symetrie a referenční test** (zdroj 1 l/s nad sloupcem, vrstvy 1,0 / 0,8 / 0,6 / 0,4 / 0,2 l/s, nepropustné podloží): symetrický terén musí dát symetrický výsledek a voda se nesmí ztratit.

## Architektura světa

Podnět: druhá odpověď ChatGPT 2026-11-19 (Jan ji poslal do chatu). Jde o návrhy k posouzení, ne o rozhodnutí.

- [ ] **Datový kontrakt mezi generováním světa, geologií, vodou a změnami od hráčů.** Kdo vlastní která data, kdo je smí měnit a jak se změny šíří. Týká se i serveru, takže ve spolupráci s Willage-backend.
  - Funkce vrstev zůstávají jediným zdrojem pravdy o geologii. Buňky, kolize a vykreslování jsou z nich jen vzorkované. Stav vody, eroze a událostí je odvozený stav, který nemusí znovu vyhodnocovat geologické funkce.
  - Místo přímých volání mezi systémy typy změn (`SurfaceChanged`, `LayerBoundaryChanged`, `MaterialChanged`, `CavityCreated`, `CavityRemoved`, `HydraulicConnectivityChanged`) a resolver závislostí: každý systém deklaruje, na které změny reaguje. Navazuje na E68.
- [ ] **Determinismus celého světa, nejen jednoho bloku.** Ujasnit `Hash(seed, změny, pořadí)`: u kterých operací pořadí nesmí hrát roli a u kterých ano (vykopat a zasypat). Otázka pro Jana: nový blok se dnes přizpůsobuje už položeným sousedům, takže pořadí vkládání bloků výsledek ovlivňuje. Má to tak zůstat, nebo má být navazování symetrické?
- [ ] **Jádro vyzdvižené hory přes více bloků:** geologická kontinuita masivu přes švy.
- [ ] **Tenké vrstvy a převzorkování mezi rozlišeními:** vrstva tenčí než buňka nesmí zmizet nebo se objevovat podle rozlišení.
- [ ] **Výkon na telefonu:** hierarchie rozlišení (region, blok, sekce 16³ nebo 32³, jemné buňky jen u hráče), všechny úrovně ze stejných funkcí. Změřit generování bloku na slabém zařízení.
