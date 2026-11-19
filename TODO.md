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
