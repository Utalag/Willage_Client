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
