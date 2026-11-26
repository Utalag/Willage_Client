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
