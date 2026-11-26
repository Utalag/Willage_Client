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

## Výsledky (2026-11-26 11:45 SEČ)

Změna proti PROP: **ochrana startu pro vodu.** Hladina svázaná s mořem měnila start (bez eroze: voda 14,14 7714d1a1… → d97ff173…, prameny 3 × 3: 18 → 2), protože moře leží jen 155–680 m od startu 3 × 3 (seed 49: 192 m; min. přes 10 seedů 155 m). Proto se vzdálenost k moři pro vodu v okolí startu zvětšuje (plná ochrana do 600 m od středu startu, plný účinek od 1400 m, parametry `StartVodaOchranaM`, `StartVodaPrechodM`). Start je tak beze změny, hladina u pobřeží mimo start = 60 m.
Zvlnění švu: `SevZvlneniM` (400), `SevZvlneniLambdaMinM` (600), `SevZvlneniLambdaMaxM` (3000) v `more_v1.json` jsou ladící parametry a součást klíče keše; test: změna 400 → 900, změna vlnových délek i 0 dává jiný otisk i klíč (Jan 11:22).

### Měření – výchozí svět (35 % ± 5 p. b., zvlnění 400 m), mapa 32 m, 8 vláken
| seed | středů | pevniny ≥ 50 km² (km²) | ostrovy v průlivech | ostrovů celkem (≥ 1 km²; největší km²) | moře cíl → skut. | řeky max / > 5 km | jezer > 1 km² | čas | paměť |
|---|---|---|---|---|---|---|---|---|---|
| 49 | 3 | 2: 217, 78 | 4 | 12 (3; 10,8) | 37,4 → 36,6 % | 13,1 km / 11 | 5 | 5,6 s | 180 MB |
| 1 | 4 | 2: 174, 151 | 1 | 8 (1; 1,0) | 33,8 → 32,9 % | 12,0 / 7 | 5 | 5,5 s | 179 MB |
| 2 | 2 | 2: 164, 155 | 2 | 7 (0; 0,7) | 35,1 → 34,4 % | 12,3 / 12 | 5 | 5,5 s | 221 MB |
| 3 | 2 | 2: 165, 133 | 3 | 6 (1; 2,5) | 39,1 → 38,4 % | 9,4 / 9 | 4 | 5,1 s | 185 MB |
| 4 | 3 | 3: 139, 104, 91 | 2 | 7 (1; 1,0) | 32,0 → 31,3 % | 12,7 / 11 | 4 | 5,0 s | 176 MB |
| 5 | 3 | 2: 262, 77 | 2 | 7 (1; 3,5) | 30,5 → 29,8 % | 10,7 / 10 | 4 | 5,6 s | 184 MB |
| 6 | 3 | 3: 124, 93, 93 | 2 | 14 (1; 1,2) | 36,4 → 35,7 % | 17,6 / 11 | 4 | 5,1 s | 185 MB |
| 7 | 3 | 3: 127, 101, 85 | 0 | 12 (1; 1,5) | 36,1 → 35,4 % | 11,6 / 12 | 4 | 5,0 s | 185 MB |
| 8 | 3 | 2: 205, 99 | 5 | 9 (2; 2,1) | 37,4 → 36,7 % | 11,7 / 11 | 4 | 5,1 s | 185 MB |
| 9 | 4 | 1: 342 | 1 | 10 (0; 0,6) | 30,6 → 29,8 % | 9,7 / 11 | 4 | 5,2 s | 219 MB |

- **H1 ano:** samostatné pevniny 9 ze 10 seedů ≥ 2 (v 6d: 3 ze 10), 2–3 pevniny; ostrovů v průlivech 0–5 (celkem 22 vs. 5), největší ostrov 10,8 km² (seed 49, spojení s pobřežním ostrovem).
- Moře −0,6 až −0,9 p. b. pod cílem (bez kompenzace, Jan 10:54), všech 10 seedů v pásmu 30–40 %.
- Determinismus: 1 vlákno = 8 vláken (otisk 800d420bb00047de, seed 49), čas 5,0–5,6 s (H3 ano).

### Hladina podzemní vody u moře
Řezy 100 m (kolmo na pobřeží, 40 m moře + 60 m pevnina, seed 49, `shots/krok06e/rez_pobrezi_100m.png`): v moři a v pásu 100 m od pobřeží je hladina přesně 60 m (v moři = hladina moře, na pevnině pod povrchem), přechod do vnitrozemí je plynulý přes 600 m. Testy: 10 seedů, v moři přesně 60 m, start 3 × 3 beze změny, spojitost (krok 1 m < 3 m), bez moře beze změny.
**Důsledek (negativní/otázka):** na pevnině 60–100 m od pobřeží je hladina vodorovně 60 m, takže u strmých břehů je hluboko pod povrchem (strmý řez: povrch až 84 m, hladina 60 m) a u pozvolných (povrch 60–72 m) blízko povrchu – u pozvolného pobřeží se hladina může dostat k povrchu (vývěry, zóna `Vyver`); počet vývěrů u pobřeží jsem neměřil.

### Nové výchozí otisky startu (seed 49, 14,14)
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 |
|---|---|---|---|
| `Krok5()` (vše vypnuto) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí bez eroze (moře, sklon, pánve, hladina u moře) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí s erozí a vodníky | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 |

Mapa výchozího světa **800d420bb00047de** (golden v `TestyKrok06d`), 92 vodníků, ve startu 0. Otisk krok 3 s erozí se mění proti 6d (0f66c994…), protože jiný podíl moře změnil odtok a tím erozi i ve startu.

### Obrázky
`godot-prototyp/shots/krok06e/`: `planeta_4_seedy.png` (49, 2, 4, 8), `toky_seed2.png`, `toky_vse_zapnuto_seed49.png`, `sev_v_mori.png`, `rez_pobrezi_100m.png` (pozvolné a strmé pobřeží).

### Testy
100/100 (nové: výchozí hodnoty, hladina u moře, start, spojitost, ladící zvlnění švu).

### Doplněno
Rozhodnutí 6–6e, TODO (náplavy, delty, mořské usazeniny) a nové pořadí klima/biomy → předherní editor světa jsou v `docs/sjednoceni/04-implementace-generatoru.md` na samostatné větvi `docs-plan04-krok06e` z `main` (4097472); na větvi 6e byl soubor starší než main, proto by se tam merge nečistil.
