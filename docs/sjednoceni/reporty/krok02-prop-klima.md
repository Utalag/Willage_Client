# PROP – Krok 2, klima (presety a pomalá mapa)

Větev `gen-v1-krok02-funkce-sveta` (HEAD 69155e0). Napsáno 2026-11-21 22:20 SEČ, před změnou kódu. Do `main` nic nejde, krok 3 se nezačíná.

## Proč
Jan 2026-11-21 22:09–22:19 rozhodl, že svět má podnebí (klima) jako samostatnou osu vedle reliéfu. Tabulka presetů upraví vstupní parametry generátoru a nese, které reliéfní biomy se v daném podnebí vyskytnou a s jakou vahou (Jan: „jo a navíc by to taky mohlo nést jaké biomy se vyskytnou v daném podnebí“). Povrchové jevy (písek, led, sníh, výpar, zamrzání) přijdou až v samostatném kroku po vodě; tady se jen zapíší do dokumentace a v kroku 2 se načte preset.

## Rozhodnutí (platí)
1. Každý svět má **základní klima**. Uvnitř světa ho **pomalá mapa** mírně mísením posouvá k sousedním podnebím (kombinace).
2. Reliéf a klima jsou **nezávislé osy**. Stávající biomy (nížina, mokřad, pahorkatina, hornatina, sopečná oblast) zůstávají typy reliéfu.
3. Klima je **tabulka presetů** (soubor dat). Preset násobí / posouvá vstupní parametry (převýšení, podíly reliéfních biomů, horniny, množství vody, …) a nese váhy, které reliéfní biomy se v něm vyskytnou.
4. Preset se uplatní **před generováním reliéfu** (začátek kroku 2). Povrchové jevy až později, po vodě.

## Volba výchozího klimatu
Parametr `klima` má výchozí hodnotu **`mirne`**. Preset `mirne` je identita (násobitele 1, posuny 0, podíly biomů stejné jako dosavadní výchozí svět), takže výchozí svět zůstane bitově shodný (otisk `04c1d51d4f0cc3d4`). Základní klima ze seedu se použije jen při `klima=ze_seedu`. Pojmenovaný preset (`poust`, `step`, `tundra`, `ledovec`) svět vynutí rovnoměrně a deterministicky změní. Pomalá mapa se při vynuceném pojmenovaném klimatu neuplatní (háček existuje, svět je stejnorodý).

## Plán
1. Zapsat rozhodnutí do `01` (nové 1.15), `04` (načtení presetu v kroku 2, nový pozdější krok po vodě na povrchové jevy) a `03` (konkrétní hodnoty presetů zůstávají otevřené). Větev `sjednoceni`.
2. `godot-prototyp/data/klima_presety.csv` + `scripts/v1/klima.gd`: načtení, výběr, uplatnění na parametry.
3. Napojení v `svet_fn.gd` na začátku `_init`, před mapou biomů a reliéfem. Háček pomalé mapy (`klima_vahy(x, y)`).
4. Příkladové presety poušť / step / tundra / ledovec označit jako **příklad, nehodnocené hodnoty**.
5. Testy kroku 2 s výchozím `mirne` (švy, sklony, determinismus = `04c1d51d4f0cc3d4`, čas, `voda_e66`, `port_studie`, `zaklad_v1`). Navíc: vynucený nevýchozí preset změní svět deterministicky (dva procesy). Obrázek stejný seed: mírné / poušť / ledovec.

## Výsledky
Doplní se po testech do tohoto souboru a do [`krok02.md`](krok02.md).
