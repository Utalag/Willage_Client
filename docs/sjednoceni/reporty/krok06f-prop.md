# PROP – Krok 6f: hladina podzemní vody jen v pásu 5 m od břehu

Větev `gen-v1-krok06f-hladina-breh` z `main` (3096136, tag `gen-v1-krok06e`). Napsáno 2026-11-26 11:36 SEČ, před kódem. Bez merge do main.
Zadání: Jan 11:33 (t945u), úprava 11:34: přechod jen v pásu **5 m** od břehu (ne 10 m).

## Cíl a metoda
- `HladinaPrechodM` výchozí **5 m** (parametr ve `voda_v1.json` i v C#, již vstupuje do výpočtu hladiny). V moři a do 5 m od břehu hladina = 60 m; dál platí původní hladina ze spádu (reliéf, krok 4). Napojení `smoothstep` přes těch 5 m (beze změny vzorce, jen šířka).
- Start 3 × 3 je v 6e 155–680 m od moře (seed 49: 192 m). Při 5 m by vazba start neměla ovlivnit → **odstranit výjimku** `StartVodaOchranaM` / `StartVodaPrechodM` a `VzdalenostProVodu`. Pokud by otisky startu bez eroze přesto nesedly, výjimku vrátím a zdůvodním.
- Testy C# na `main` (před změnou) i na větvi. Nový řez `shots/krok06f/rez_pobrezi_100m.png`, otisky startu, prameny 3 × 3, golden mapy (mapa eroze se nemění – hladina mapu neovlivňuje).
- Jedna věta do plánu 04 na této větvi. Mořské usazeniny zůstávají v TODO.

## Hypotézy
- H1: start 3 × 3 beze změny proti 6e (krok 3 c8eeb7964d1ddd85, voda 7714d1a1d34e00ad, 18 pramenů) i bez výjimky.
- H2: v řezu je hladina 60 m jen v moři a ~5 m od břehu, pak plynule na původní spád (ve vnitrozemí 50–100 m od břehu už původní hladina).
- H3: golden mapy eroze 800d420bb00047de beze změny.

## Výsledky (2026-11-26 11:42 SEČ)

### Testy na main (před změnou)
`main` 3096136: **OK 100, chyb 0** (C# `Willage.Gen.Testy`, .NET 9, Release).

### Změna metody
- `HladinaPrechodM` = **5 m** (`voda_v1.json` i výchozí v `ParametryVody`). Vzorec beze změny (smoothstep přes šířku pásu).
- **Výjimka startu odstraněna** (`StartVodaOchranaM`, `StartVodaPrechodM`, `VzdalenostProVodu`). Start 3 × 3 je 155–680 m od moře (seed 49: 192 m) ≫ 5 m, otisky bez eroze beze změny (H1 ano).
- Hrubá vzdálenost k moři (mřížka 64 m, pro sklon) **nestačí na pás 5 m**. Pro hladinu se u pobřeží (hrubá D ≤ 32 m) vzdálenost dopočítá z masky pevniny po 1 m (`MoreSklon.VzdalenostOdMoreJemna`). Sklon kontinentu a pánve dál používají mřížku 64 m → mapa eroze se nemění.
- `HladinaPrechodM` je parametr ve `voda_v1.json` a mění výpočet hladiny. Do klíče keše **mapy eroze** nevstupuje, protože mapu nemění (voda je čistá funkce).

### Otisky startu (seed 49, 14,14) – stejné jako 6e
| konfigurace | krok 3 | voda 14,14 | prameny 3 × 3 |
|---|---|---|---|
| `Krok5()` (vše vypnuto) | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí bez eroze | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 |
| výchozí s erozí a vodníky | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 |

Mapa výchozího světa **800d420bb00047de** (golden beze změny, H3 ano), 92 vodníků, ve startu 0.

### Řez
`godot-prototyp/shots/krok06f/rez_pobrezi_100m.png` – stejné úsečky jako v 6e (porovnání). Pozvolné pobřeží: hladina 60 m v moři a ~5 m za břehem, pak plynule na původní spád (~63–67 m). Strmé: za břehem je původní hladina sama blízko 60 m na prvních desítkách metrů, proto není 5 m přechod vizuálně ostrý; dál sleduje reliéf (H2 ano).

### Testy na větvi
**OK 104, chyb 0** (nové: výchozí 5 m, start bez výjimky = bez vazby, za 5 m = původní spád, v moři 60 m).

### Plán 04
Jedna věta o 6f v `docs/sjednoceni/04-implementace-generatoru.md` na této větvi.
