# PROP – Krok 6e: doladění (podíl moře 35 %, hladina podzemní vody u moře, plán 04)

Větev `gen-v1-krok06e-doladeni` z `gen-v1-krok06d-upravy` (121cfc5). Napsáno 2026-11-26 11:18 SEČ, před kódem. Bez merge do main.
Zadání: Jan 11:15 (t943u), schválení 5 doporučení ke 6d.

## Cíl a metoda
1. `SevZvlneniM` zpět na 400 m (JSON i výchozí hodnota v C#).
2. `PodilMore` 0,35 (± 5 p. b. ze seedu). Změřit ostrovy v průlivech a oddělené kontinenty pro 10 seedů (v 6d: ostrovy 0–2, samostatné pevniny 1–2).
3. **Hladina podzemní vody = hladina moře 60 m u pobřeží a v moři.** `RegionalniHladina.Surova` se smíchá s hladinou moře: `w = k_moře(x, y)` z `MoreSklon` (0 = pevnina, 1 = moře); hladina = `(1 − w)·H_vnitrozemí + w·60 m`, kde `w = 1 − smoothstep(0, ŠířkaPřechodu, D)` a D = vzdálenost od moře (už existující mřížka 64 m, bilineárně); v moři D = 0 → 60 m. Šířka přechodu parametr `HladinaPrechodM` (výchozí 600 m, ladit řezem: hladina musí plynule navázat). Parametr ve `voda_v1.json`/`ParametryVody` a v klíči. Bez moře beze změny (start 3 × 3 neovlivněn, vzdálenost k moři ≫ 600 m).
4. **Mořské usazeniny** jen do TODO (spolu s náplavy a deltami) v DENIKu a plánu 04.
5. **Plán 04:** doplnit rozhodnutí 6–6e do `docs/sjednoceni/04-implementace-generatoru.md` přímo na této větvi (soubor se na `sjednoceni` po 8c7fc4d nezměnil → merge čistý, ověřit `git merge-tree`). Doplnit další pořadí: klima a biomy (teplotní pásma, srážky vč. srážkového stínu, pouště, výchozí klima planety) přes mapu s novým výpočtem vody a eroze, pak předherní editor světa (úpravy s regiony přes více bloků, přepočet závislých kroků, uložení planety, dál jen herní změny).

## Hypotézy
- H1: při 35 % moře ≥ 2 samostatné pevniny ve většině seedů, ostrovů v průlivech víc než v 6d.
- H2: hladina podzemní vody v řezu u moře ≈ 60 m, plynulý přechod; start beze změny (otisky bez eroze stejné, s erozí se mohou změnit jen pokud je start blíž moři než přechod – nemá být).
- H3: čas mapy < 7 s, determinismus.

## Měření
10 seedů: moře cíl/skutečnost, pevniny, ostrovy, řeky, čas; nové otisky startu; řez pobřeží (pozvolné + strmé); `git merge-tree` s aktuálním main.
