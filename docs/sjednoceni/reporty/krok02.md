# Report – Krok 2: Funkce světa I (rozhraní, mapy biomů a hornin, reliéf, masiv, sopky)

Větev `gen-v1-krok02-funkce-sveta` (z `gen-v1-krok01-zaklady` c3f9b77). Plán: `04-implementace-generatoru.md`, krok 2 (větev `sjednoceni` 6e0fec6). Pravidla: 01 – 1.4, 1.7.1, 1.13, 1.14; 02 – 2.1, 2.2.

## PROP (napsáno 2026-11-21 00:45 SEČ, před experimentem)

**Cíl.** Jedna čistá funkce světa V1.0 v metrech bez mřížky sousedů: dotaz na sloupec `(x, y)` vrátí povrch, biom a zastoupení hornin, dotaz na bod `(x, y, z)` materiál. Vrstvy (krok 3) a hladina (krok 4) se doplní bez změny rozhraní. Výchozí hra se nemění: nový kód hra nevolá.

**Převzatý kód (nepsat znovu).**
- `e87-jadro-hory` ff97a9f sloučeno celé (za přepínačem `p87_jadro_hory`, výchozí vyp): funkce masivu `geo2.massif87` / `n01` (šum MASSIF87 a MASSIF87D) se volá přímo, jen v metrech a ve sloupci 128 m.
- `e96-blok128` 64dbbcd sloučeno celé (za `p96_blok128`, výchozí vyp; obsahuje `lod90.gd` E90/E95/E96): vzorec reliéfu E49/E90 (`lod90.h49`: základní šum S8_BASE, hřbet (1 − |n|)², pánev S8_LAKE) jako tvar reliéfu; `blok96.gd` jako vzor sestavení bloku 128 m z funkce (výšky ve středech buněk).
- E49 `svet/hruby_teren.gd` (main): kužel sopky s kráterem `c · (1 − r/R)^γ − kráter` zobecněný na parametry 1.14.

**Plán.**
1. `scripts/v1/svet_fn.gd` – kontext světa ze seedu a parametrů (hrubé body biomů a hornin, sopky), `vyska`, `sloupec`, `bod`.
2. Mapa biomů (varianta C, 5 biomů: nížina, mokřad, pahorkatina, hornatina, sopečná oblast) a mapa hornin: hrubé body ze seedu na 4096 m, měkké Voroného váhy (spojité).
3. Reliéf z parametrů biomu (převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu); strop sklonu se dodrží volbou efektivní amplitudy (gradient šumu změřený při startu), ne omezovačem.
4. Masiv E87 v hornatině + podhůří v pásu přechodu.
5. Sopky: počet, rozteč, velikost 20–40 m / 1–2 bloky, sklon 17°, kráter, vrchol ≤ okraj sloupce − 5 m.
6. `scripts/v1/blok_v1.gd` – výšky bloku 128 m z funkce (vzor `blok96`).
7. Testy 1–6 kroku 2 (`tools/svet_v1.gd`, grafy `tools/svet_v1_grafy.py`) + regrese kroku 1.

**Testy a kritéria (z 04, krok 2).**
| Test | Prošlo, když |
|---|---|
| 1 spojitost | výška na hranici bloků a segmentů z obou stran: rozdíl 0 m |
| 2 sklony | max ≤ strop + tolerance |
| 3 sopky | počet = parametr, rozteč ± tolerance, vrchol ≤ okraj − 5 m, kráter na vrcholu |
| 4 mapy | plynulé přechody, různé seedy → různé mapy |
| 5 determinismus | hash mřížky výšek 3 × 3 ze dvou procesů shodný |
| 6 čas | jen záznam, srovnání s E90 (4,9 s / 3 km) |
| regrese kroku 1 | `voda_e66` d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod; `port_studie --check` 0 změn; `zaklad_v1` stejný otisk ve 2 procesech |

**Odchylka předem:** `tools/rez_profil.py` kreslí řezy z buněk (`rez_data.gd`), které vzniknou až v kroku 6. Řez přes šev proto kreslí nový `svet_v1_grafy.py` přímo z funkce.

**Regrese po sloučení E87 a E96 (před kódem kroku 2):** `voda_e66` d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod (65 s); `port_studie --check` 82 souborů, 0 změn.

## Výsledky
*(doplní se po testech)*
