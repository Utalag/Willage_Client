# Řez suché pouště navazující na moře

Pouštní planeta, seed 49, klima krok 7b zapnuto. Buňka 0,25 m.

- Úsečka: začátek **(13848, 14368) m**, směr **+x (1, 0)**.
- Břeh: **s ≈ 84,62 m**, bod **(13932,62, 14368,00) m**.
- Obrázky: `rez_poust_200m.png`, `rez_poust_1000m.png` (stejná úsečka, přehled 1 km).
- Data: `rez_200.csv`, `rez_1000.csv`. Binární sloupec z `dotnet run -c Release -- eroze rez <kes> 13848 14368 1 0 <L> <bin> --seed 49 --planeta poust`, vykreslení `godot-prototyp/tools/rez_poust.py`.

Subtropické pásmo, na pevnině biom poušť, T ≈ 29,4–30,1 °C, srážky ≈ 126 mm/rok (na konci 1 km ≈ 158 mm), w = 0. Pramen ani oáza na řezu nejsou (nejbližší oáza ≈ 475 m stranou od začátku). Suché koryto jen na 1 km, s = 504–536 m. Aktivní tok žádný.
