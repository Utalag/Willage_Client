# E84 implicitní útvary nad vrstvami – měření (2026-11-20 04:33)

Spuštění (dva procesy, výstupy `proces1.json`, `proces2.json`, `vystup1.txt`, `vystup2.txt`):

    cd godot-prototyp
    Godot_v4.7.2 --headless --path . -s tools/implicit_e84.gd -- --out=../blueprint-studie/shots/e84/proces1.json

Ostrov START (4 bloky: louka, hora, kopec, louka), Linux x86_64, GDScript, jedno vlákno. Časy = průměr na blok.

## Útvary v ostrově
13 útvarů z hashe světové mřížky: 6 žil, 1 čočka pegmatitu, 6 krasových kanálů (řetěz 5 kapslí + komora).
Skarn kolem granitoidu je v každém bloku (těleso `contact`). Na blok zasahuje 6–11 útvarů.

## Čas na blok (ms)
| | 0,5 m (16×16×64) | 0,25 m (32×32×128) |
|---|---|---|
| geo_fn dnes (vrstvy + skarn svisle) | 38 | 346 |
| R0 dutina `cavity_one` (navíc) | 38 | 297 |
| R1 SDF bod po bodu, vše | 89 | 654 |
| R1 jen skarn po normále | 66 | 429 |
| R1 jen žíly, čočky, kras | 73 | 547 |
| R2 stavba intervalů | 355 | 1477 |
| R2 buňky z intervalů | 61 | 435 |

Vyřazení podle meze (bez šumu, Lipschitz) zrychlilo R1 z 158 na 89 ms a z 1156 na 716 ms. Hashe buněk se nezměnily.

## Paměť
- Útvar: 176 B (čočka), 192 B (žíla), 296 B (kras: 6 uzlů). Parametry ve float64 + seed + obálka.
- Blok: 6–11 útvarů = 1,1–2,9 kB, ale nic se neukládá: útvary jdou znovu z hashe.
- Intervaly R2: 86–200 na blok při sloupcích 0,5 m, 349–806 při 0,25 m (2 čísla + id útvaru).
- Pro srovnání: plné buňky 16 384 B (0,5 m) a 131 072 B (0,25 m) na blok.

## Švy (4 švy × 16 384 bodů přímo na švu, krok 0,125 m)
- Útvar z obou bloků: 0 rozdílů (v útvaru 85–954 bodů).
- Materiál geo_fn: 256 rozdílů na šev. To je kryt půdy podle typu bloku (louka proti hoře / kopci), už dnes. Útvary to nemění.
- Dutina R0: 60 buněk na blok, roste jen uvnitř bloku a přes šev nikdy nepokračuje.
- Kras R1 přes šev pokračuje (1–7 párů buněk). Stěna na švu 0–2 buňky, to je jen vzorkování.

## Determinismus
- 2× v procesu stejně, 2 procesy stejně (všechno kromě časů).
- float32 (parametry i body zaokrouhlené): 0 změněných buněk při 0,5 m i 0,25 m. 0 bodů s |d| < 1e-6 m z 2 805–38 614.
- Útvary používají jen + − × ÷ sqrt floor a celočíselný hash.
- Výjimka: výška uzlů krasu bere `G2.zone_tops` (FastNoiseLite).
- `Vector3` v Godotu je float32 (ověřeno). geo_fn ho dnes používá v rovinách žil.

## Překryv E78
- Definice je 0,5 m zjemněná. 0,25 m z funkcí se od ní liší v 7 637–14 929 buňkách už bez útvarů (známé z E80).
- Útvary přidají jen 384–533 buněk (0,3–0,4 %). Uložit je by stálo 1,5–2,3 kB (runs), deflate 0,8–1,3 kB.
- Chodba 0,25 m přes kanál: buňky, které už jsou dutina, jsou no-op (2 a 4 z 32). Překryv má jen skutečné změny (30 a 28).

## Pásma vody (sloupce 0,5 m, `ug_funkce.bands`)
- Pásem 4 362–5 196 na blok. Se skarnem a krasem jich je o 113–311 víc (+2,6 až +6,4 %). Z toho 212–475 jsou skarnová pásma.
- Objem krasu:

| blok | intervaly (přesně) | buňky 0,5 m | buňky 0,25 m |
|---|---|---|---|
| (0,1) | 23,39 m³ (voda 14,95) | 24,0 | 23,78 |
| (1,0) | 4,73 | 4,88 | 4,95 |
| (1,1) | 2,41 | 2,88 | 2,47 |
| (0,0) | 0,44 | 0,38 | 0,34 |

- Pásma dnes tělesa nevidí. Bez vyříznutí skarnu vycházel kras 2× větší než v buňkách. Skarn je nerozpustný a buňky ho tak berou.

## Stejná dutina při 0,5 a 0,25 m (průnik / sjednocení buněk 0,25 m)
- R0: 56–75 %, objem stejný z definice.
- R1: 50–68 %. Kanály mají poloměr 0,5–1,1 m, takže vzorek 0,5 m tenké části ztratí.
- Pravda R1 nezávisí na rozlišení (intervaly). Buňky jsou jen vzorek.
