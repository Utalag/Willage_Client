# PROP – Krok 6d: úpravy kontinentů (ostrovy v průlivech, přesný podíl moře, zvlněný šev, klíč keše, vše zapnuto výchozí)

Větev `gen-v1-krok06d-upravy` z `gen-v1-krok06c-kontinenty` (4a98656). Napsáno 2026-11-26 10:53 SEČ, před kódem. Bez merge do main.
Zadání: Jan 10:51 (t934u), předběžné schválení 6 doporučení z 6c.

## Cíl a metoda
1. **Šíje** zůstávají jako přirozená varianta (beze změny kódu).
2. **Ostrovy v průlivech:** po prvním prahu se ze seedu vyberou kandidáti v moři (maska pod prahem, dál od švu než poloměr + rezerva, dál od startu a od sebe). Ostrov = hladká kupka v masce `max(m, prah0 + A·(1 − (d/R)²))` na zkřivených souřadnicích + šum členitosti. Parametry `OstrovuPocet`, `OstrovPolomerM`, `OstrovVyska` v `more_v1.json` (v klíči). Měřit plochy ostrovů.
3. **Přesný podíl moře:** skutečné moře = maska pod 0,5 **a** povrch pod hladinou 60 m. Kalibrace: na mřížce prahu (128 m) spočítat skutečné moře s výškou světa (bez sklonu, ten moře nemění) a iterativně posouvat kvantil prahu o rozdíl (cíl − skutečnost), max. 8 iterací, cíl ±0,2 p. b. (měřeno na mapě 32 m).
4. **Zvlněný okraj švu:** šířka tvrdého pásu = 512 m + `SevZvlneniM`·u(p), u ∈ [0, 1] z periodického šumu (λ 1–4 km). Pás prolnutí 512 m zůstává celý v moři; pobřeží u švu už není rovné.
5. **Klíč keše:** `more_v1.json` do hashů datových souborů jen při zapnutém moři.
6. **`VseKrok06` výchozí zapnuto:** výchozí `ParametrySveta` = moře + sklon + pánve; `KonfiguraceSveta.Sestav` přidá erozi a vodníky. Výchozí hodnoty v C# = hodnoty v `more_v1.json`. Testy ekvivalence s GDScriptem a historické otisky kroků 3–5 dostanou explicitně `VseKrok06 = false` (porovnávají starou konfiguraci); nové goldeny výchozího startu se zapíší do testu.

## Hypotézy
- H1: |moře cíl − skutečnost| ≤ 0,2 p. b. pro 10 seedů.
- H2: ostrovy 2–6 km² v průlivech, počet podle parametru.
- H3: start beze změny proti 6c (moře nezasahuje start), šev celý v moři, determinismus 1 = 8 vláken, 2 procesy.
- H4: čas mapy 32 m < 7 s.

## Měření
10 seedů: moře cíl/skutečnost, kontinenty, ostrovy (plochy), řeky, čas, paměť, determinismus; otisky výchozího startu. Obrázky `godot-prototyp/shots/krok06d/`.

## Změna zadání během kroku
Jan 10:54: **bod 3 (kompenzace prahu moře) vynechán** – odchylka ~0,8 p. b. se vejde do tolerance ±5 %. Kalibrace prahu (bisekce na mřížce 64 m s výškou světa) byla rozpracovaná a byla odstraněna, práh zůstává kvantil histogramu masky. Navíc: svislý řez přechodem moře–pevnina 100 m.

## Výsledky (2026-11-26 11:08 SEČ)

### Ostrovy v průlivech
Kandidát ze seedu musí ležet v moři prvního prahu celý **i s pásem 250 m** (16 směrů), dál od švu než R + zvlnění + přechod + 300 m, od startu > R + 2 km a od sebe. Kupka na nezkřivených souřadnicích: `max(m, práh0 + 0,3·(1 − (d/R)²) + C·F)`, R = 700 m × (0,6–1,4).
**Negativní:** první pokus (kupka na zkřivených souřadnicích, bez kontroly okolí) ostrovy přilepil ke kontinentům nebo přemostil průliv (seed 2: 2 → 1 pevnina). S pásem 600 m se nevešel ani jeden ostrov – průlivy jsou při 70 % pevniny úzké (~1 km). S pásem 250 m: 0–2 ostrovy v průlivech na seed (z max. 5), celkem 6 na 10 seedů.

### Zvlněný okraj pásu švu
Tvrdý pás = 512 m + `SevZvlneniM`·u, u = ½ + ½·tanh(½·F), F periodický šum λ 600–3000 m. Pás prolnutí 512 m zůstává celý v moři (test 4 seedy), směrodatná odchylka polohy prvního pobřeží od švu > 100 m (test).
**Negativní / kompromis:** 400 m zvlnění (λ 1–4 km) bylo na obrázku pořád skoro rovné; 900 m (výchozí) je zřetelně zvlněné, ale širší moře u švu bere podíl moře průlivům → víc šíjí: samostatné pevniny seed 49/2/6/7 = 1/2/3/3 při 400 m, 1/2/1/2 při 900 m.

### Měření – výchozí svět (VseKrok06: moře, sklon, 4 pánve, eroze, vodníci), mapa 32 m, 8 vláken
| seed | středů | pevniny ≥ 50 km² (km²) | ostrovy v průlivech | ostrovů celkem (≥ 1 km², největší) | moře cíl → skut. | řeky max / > 5 km / > 10 km | jezer > 1 km² | čas | paměť |
|---|---|---|---|---|---|---|---|---|---|
| 49 | 3 | 1: 334 | 2 | 7 (0; 0,4) | 32,4 → 31,7 % | 11,4 km / 11 / 4 | 5 | 5,3 s | 179 MB |
| 1 | 4 | 1: 345 | 0 | 4 (2; 5,7) | 28,8 → 28,2 % | 13,6 / 10 / 1 | 4 | 5,5 s | 177 MB |
| 2 | 2 | 2: 176, 164 | 1 | 6 (2; 2,0) | 30,1 → 29,7 % | 15,1 / 14 / 2 | 5 | 5,5 s | 218 MB |
| 3 | 2 | 2: 178, 145 | 1 | 6 (1; 1,5) | 34,1 → 33,5 % | 11,9 / 11 / 3 | 4 | 6,2 s | 219 MB |
| 4 | 3 | 1: 359 | 0 | 4 (0; 0,4) | 27,0 → 26,6 % | 14,6 / 14 / 3 | 4 | 5,5 s | 215 MB |
| 5 | 3 | 1: 367 | 0 | 1 (0; 0,1) | 25,5 → 25,1 % | 11,1 / 15 / 3 | 5 | 5,6 s | 156 MB |
| 6 | 3 | 1: 336 | 0 | 10 (1; 1,5) | 31,4 → 30,7 % | 12,3 / 12 / 1 | 4 | 5,6 s | 219 MB |
| 7 | 3 | 2: 229, 108 | 0 | 8 (1; 2,3) | 31,1 → 30,5 % | 13,0 / 16 / 2 | 4 | 5,3 s | 195 MB |
| 8 | 3 | 1: 330 | 1 | 8 (1; 2,5) | 32,4 → 31,8 % | 12,0 / 11 / 2 | 4 | 5,2 s | 219 MB |
| 9 | 4 | 1: 367 | 0 | 8 (0; 0,2) | 25,6 → 25,0 % | 9,9 / 17 / 0 | 5 | 5,4 s | 214 MB |

- Moře −0,4 až −0,7 p. b. pod cílem (bez kompenzace, Jan 10:54). Jezera z pánví 1,6–3,1 km², hloubka 10–16 m.
- Determinismus: 1 vlákno = 8 vláken = 2. proces (otisk 08e6ca036c3e2322, seed 49).
- H1 vynecháno, H2 ne (ostrovy 0,4–2,5 km², jen 0–2 v průlivech), H3 ano, H4 ano (5,2–6,2 s).

### Nové výchozí otisky startu (seed 49, 14,14)
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 |
|---|---|---|---|
| `ParametrySveta.Krok5()` (vše vypnuto) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí `new ParametrySveta()` bez eroze (moře, sklon, pánve) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí + eroze + vodníci (`KonfiguraceSveta.Sestav`) | 0f66c994ddb2c77b | a48305922c8c47a8 | 20 |

Mapa výchozího světa 08e6ca036c3e2322 (golden v `TestyKrok06d`), 105 vodníků, ve startu 0. Sestavení 6,0 s, z keše ~1 s.
Testy ekvivalence s GDScriptem používají `ParametrySveta.Puvodni()` (nově `VseKrok06 = false`), historické testy kroku 6/6b/6c `ParametrySveta.Krok5()`. Výchozí hodnoty v C# = `more_v1.json` (test) → Godot adaptér (`VodaV1` s `new ParametrySveta`) dostane stejný svět i bez JSON (moře, pánve; bez eroze).

### Klíč keše
Bez moře: klíč = klíč kroku 6 (jen klima a horniny), `more_v1.json` se nezapočítává (test).

### Svislý řez pobřeží (Jan 10:54)
Nástroj `eroze rez <keš> x0 y0 ux uy délka out.bin` (výchozí svět s erozí, planetární svet_max_m), buňka 0,25 m, materiály, povrch, surová hladina podzemní vody. Dva řezy po 100 m kolmo na pobřeží (40 m moře + 60 m pevnina), seed 49: pozvolné (od 9443,8 / 5486,1 m) a strmé (od 19032,9 / 11959,6 m). Obrázek `shots/krok06d/rez_pobrezi_100m.png`.
Pozorování (otázky): hladina podzemní vody o moři neví – ve strmém řezu je pod mořem nad hladinou moře (62 m), v pozvolném pod dnem; dno moře tvoří stejné vrstvy jako pevnina (ornice/štěrk, žádné mořské sedimenty); u pobřeží může být solný peň (rock_salt) kousek pod povrchem.

### Obrázky
`godot-prototyp/shots/krok06d/planeta_4_seedy.png` (49, 2, 3, 7), `toky_seed2.png`, `toky_vse_zapnuto_seed49.png`, `sev_v_mori.png`, `rez_pobrezi_100m.png`.

### Testy
89/89.

### Otázky pro Jana
1. Zvlnění švu 900 m (zřetelné, víc šíjí) nebo 400 m (méně zvlněné, víc samostatných kontinentů)?
2. Ostrovy v průlivech jsou malé a málo časté (úzké průlivy). Povolit je i blíž ke kontinentům / větší, nebo dát moři víc místa (např. podíl moře 35 %)?
3. Hladina podzemní vody u moře: svázat s hladinou moře 60 m (moře jako okrajová podmínka)? Samostatný krok?
4. Mořské dno: náplavy/sedimenty pod mořem spojit s TODO náplavy a delty?
5. Doplnit rozhodnutí 6b–6d do `docs/sjednoceni/04-implementace-generatoru.md` (větev sjednoceni)?
