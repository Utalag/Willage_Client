# PROP GEO2: profil času na blocích, kde je výchozí GEO2 nad doporučením ×1,5 GEO1 (Jan t1046u bod 3, t1047u)

*Zapsáno před profilováním 2026-11-28 12:41 (Europe/Prague). Větev `geo2-profil` z `geo2-vychozi` (včetně sloučeného kontaktu rychle) + nástroj měření z `geo2-vykon-mereni`. **Jen profilování, nic se neimplementuje.***

## Cíl
Najít, kde se na blocích s největším poměrem k GEO1 tráví čas, a navrhnout **jen levné a jisté bitově stejné** úspory s odhadem zisku. Limit ×1,5 GEO1 je **doporučení** (Jan t1047u), ne kritérium smazání: kde už není co levně zrychlit, uvede se jen vzdálenost od doporučení.

## Bloky a postup
Bloky: hornatina (1664, 1728) a (3904, 1344), svah sopky (1673, 1705), okraj sopky (1710, 1705), šev mince (1984, 2560). Z měření bodu 3 (8 vláken, medián, GEO2 / GEO1): ×2,69, ×2,99, ×2,22, ×1,65, ×1,98 (po kontaktu rychle ×3,04, ×2,81, ×2,22, ×1,81, ×1,89).
Nástroj `dotnet-trace` (vzorkování CPU, všechna vlákna), výchozí GEO2 cesta (kontext + `Sloupec` z běhů), sloupce po 0,25 m, 8 vláken, 2 průchody bloku v jednom procesu (první zahřeje JIT; do profilu jde celý běh, zahřívací průchod se uvádí v celkovém čase). Převod na speedscope a součet inkluzivních / vlastních časů podle metod.
Srovnání s GEO1 stejného bloku (stejný nástroj) kvůli tomu, co je společné (`VrstvySloupce.Hranice` apod.).

## Co chci zjistit
1. Rozpad času: kontext (mřížka hranic, indexy těles) × `Sloupec` (segmentace, sondy, bisekce, raster) × společné GEO1 části (`VrstvySloupce.Hranice`, šum).
2. Který tvar událostí dominuje na strmých blocích (zásobník vrstev, těleso, sopka, kras, kontaktní pásmo).
3. Zda je dominantní práce odstranitelná bez změny výsledku (cache, předpočet, zkrat s dokázanou ekvivalencí).

## Kritéria
- Každá navržená úspora: příčina z profilu (% času), proč je bitově stejná (důkaz / kontrola), odhad zisku (min / max, z podílu času), riziko, pracnost.
- Nic se neimplementuje ani nemění; měřicí nástroj `--jen=GEO2PROFIL` je jediná nová kódová změna.

## Výsledky (2026-11-28 13:01, Europe/Prague)

Nástroj: `--jen=GEO2PROFIL --blok=ox,oy --cesta=geo1|geo2|hranice|hranice8 [--opak=N]`; `dotnet-trace collect --format speedscope` (vzorkování, 8 vláken) a souhrny v `geo2-profil-data/pf-*.txt` (inkluzivní a vlastní časy). Produkční kód **beze změny** (`git diff geo2-vychozi -- cs/Willage.Gen` prázdný).
Cizí `grep` PID 295547 / 297041 běžely dál (~198 % CPU, nezabity).

### 1. Kde se čas tráví (podíl času ve `Willage.Gen`, vzorkování)

| Blok (kategorie) | GEO2 / GEO1 po sloučení kontaktu (medián, měření B) | `VrstvySloupce.Hranice` | z toho `Zastupci` | z toho `Dictionary.Resize` + `List.set_Capacity` (alokace) | `Behy` (K4 sloupec) | kontext (mřížka, `CiloveIntervaly`) | kontaktní pásmo `Plati` | volání `Hranice` na sloupec (K4, bodové sloupce) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| hornatina (1664, 1728) | ×3,04 (8,28 s / 2,72 s) | 79,7 % | 63,9 % | 70,8 % | 69,2 % | 27,1 % | 19,6 % | 2,42 |
| hornatina (3904, 1344) | ×2,81 (9,33 s / 3,32 s) | 90,3 % | 71,7 % | 81,1 % | 70,4 % | 26,8 % | 32,3 % | 3,40 |
| svah sopky (1673, 1705) | ×2,22 (5,97 s / 2,69 s) | 74,7 % | 60,3 % | 66,7 % | 61,3 % | 34,4 % | 0 | 1,00 |
| okraj sopky (1710, 1705) | ×1,81 (5,55 s / 3,07 s) | 77,8 % | 63,1 % | 69,6 % | 59,4 % | 35,9 % | 0 | 1,00 |
| šev mince (1984, 2560) | ×1,89 (7,22 s / 3,82 s) | 91,1 % | 72,9 % | 80,2 % | 67,6 % | 29,3 % | 28,3 % | 3,07 |
| *srovnání GEO1 stejných bloků* | – | 51–54 % | 41–44 % | 67–77 % (`Features`/`Make` také alokují) | – | – | – | 1,00 |

(podíly vzorkování se překrývají: kontext i `Behy` volají `Hranice`; vzorkování je zkreslené k místům alokace, proto dole ověření stopkami.)

**Ověření stopkami (blok (3904, 1344), 8 vláken, 2 průchody, bez trace):** v `HraniceSloupce` (cache miss bodových sloupců) 28–30 jádro-sekund na průchod, **916 233 volání** = 3,5 na sloupec (262 144 sloupců), tj. **~32 µs na volání**; průchod má celkem ~67 jádro-sekund (kontext 2,1 s + sloupce 7,7 s × ~7 vláken) → Hranice v bodových sloupcích ≈ **44 %** času průchodu, další velká část Hranice je v uzlech mřížky kontextu (`CiloveIntervaly`, ~27 % času).
**Mikroměření** jednoho `GeoVrstvy.Hranice(x, y)` (1 vlákno, po zahřátí): 48–69 µs, **21 kB alokace na volání** (z toho `Vahy` + `VyskaTvar` + `VyskaW` ≈ 10 µs a 0,1 kB); v 8 vláknech 83–170 µs jádro-času na volání, bez zámkové kontence (sdílená instance ≈ `Klon()` na vlákno). GC pauzy jsou malé (0,15 s u GEO1, 0,3–0,8 s u GEO2 na průchod), cena je v samotné alokaci (GEO1 19,8 GB na blok, GEO2 27,5 GB = ~105 kB na sloupec, z toho ~74 kB `Hranice`).

**Hlavní závěr:** výchozí GEO2 je pomalejší než GEO1 hlavně proto, že (a) na strmých blocích a švu volá `Hranice` 2,4–3,5× na sloupec (vlastní sloupec + `q′` v kontaktním pásmu + sousední sloupce bodů), GEO1 1×, (b) kontext (mřížka) stojí 1,5–2,0 s navíc na blok, na sopce je to 30 % času. `Hranice` je sdílený kód GEO1, takže obě cesty platí stejnou cenu za volání. Sopka a skarn mají 1,0–1,1 volání na sloupec, tam rozhoduje kontext a K4 režie.

### 2. Návrhy úspor (jen bitově stejné, levné a jisté; nic neimplementováno)

| # | Úspora | Důkaz bitové shody | Odhad zisku | Pracnost, riziko |
|---|---|---|---|---|
| **U1** | **Bez alokací v `VrstvySloupce.Zastupci` a `Hranice`**: pro pásmo `ip` jsou `band`, `posl` (poslední výskyt id) i pořadí klíčů konstantní, spočítat jednou v konstruktoru; `vahy` jako pole podle indexu; vynechat `Keys.ToList()` ×2, LINQ `Select/ToList`, `Podily()` alokující pole na volání | zlaté otisky GEO1 (krok 5, G-1, G-3), celá sada 742 testů, V8 (0 změn), otisk bloků K4B (4 bloky × 134 M buněk) – všechny musí zůstat beze změny | `Zastupci` je 60–73 % času v profilu a 55–66 % jsou alokace; **odhad −25 až −45 % času GEO2** (absolutně), GEO1 podobně (−20 až −35 %). **Poměr ke GEO1 se změní málo** (obě cesty zrychlí; GEO2 volá víc, takže mírně vyhraje: odhad ×2,8 → ×2,5 na hornatině). Odhad z profilu (zkresleného), skutečný zisk ověří prototyp | 2–4 h; nízké riziko (čistá funkce, bez změny pořadí); mění sdílený soubor GEO1 (`VrstvySloupce.cs`), takže potřeba souhlas Jana (malá změna GEO1 už byla schválena t1039u) |
| **U2** | **Větší paměť sloupců** `ZasobnikVrstvySloupce.N` 4 → 32 (1 konstanta) | součet otisků stejný (zkoušeno) | **změřeno** (zkouška, vráceno, necommitnuto): (3904, 1344) sloupce 8,15–8,47 → 7,05–7,15 s (−14 %); (1664, 1728) v šumu (−3 až −8 %); `q′` sloupce se skoro neopakují | 5 min; paměť +28 sloupců na vlákno; zisk jen na blocích s kontaktním pásmem |
| **U3** | (střední) **Hranice sloupce `q′` bez přesného povrchu**: pro hostitele okolí stačí vrstva v hloubce `q′z`; `VyskaW` je ~10–17 µs z 50–70 µs volání. Potřeba nepřivřený seznam vrstev s dolní mezí povrchu a bezpečné použití jen pro `z` hluboko pod povrchem | stejný princip jako v bodu 2 (kontakt rychle); důkaz: `z ≤ dolní mez povrchu` ⇒ klip povrchem se neuplatní | ~15–25 % ceny volání u `q′` volání (~40 % všech volání) ⇒ ~5–8 % času GEO2 | 3–5 h, střední riziko (okraj u povrchu) – **nedoporučuji teď** |
| – | Nelze bitově: méně uzlů mřížky (kontext 1,5–2,0 s), řidší sondy `q′`, hrubší `eta` | – | – | mění výsledek, rozhodnutí Jana |

### 3. Jak daleko jsme od doporučení ×1,5 GEO1 (po sloučení kontaktu, medián z 5, 8 vláken)

| Blok | GEO1 | GEO2 | doporučení ×1,5 | potřebné zrychlení GEO2 | po U1 + U2 (odhad GEO2 / GEO1) |
|---|---:|---:|---:|---:|---|
| hornatina (1664, 1728) | 2,72 s | 8,28 s (×3,04) | 4,08 s | −51 % | ×2,2–2,6 (nedosáhne) |
| hornatina (3904, 1344) | 3,32 s | 9,33 s (×2,81) | 4,98 s | −47 % | ×2,0–2,4 (nedosáhne) |
| svah sopky (1673, 1705) | 2,69 s | 5,97 s (×2,22) | 4,04 s | −32 % | ×1,6–1,9 (blízko) |
| okraj sopky (1710, 1705) | 3,07 s | 5,55 s (×1,81) | 4,61 s | −17 % | ×1,3–1,6 (dosažitelné) |
| šev mince (1984, 2560) | 3,82 s | 7,22 s (×1,89) | 5,73 s | −21 % | ×1,4–1,7 (blízko) |

Odhad „po U1 + U2“ počítá s tím, že zrychlí i GEO1 (sdílená `Hranice`); je to odhad z podílů v profilu, ne měření. **Kde už není co levně zrychlit:** strmé bloky s 3,4 voláními `Hranice` na sloupec; zbývající rozdíl je dán počtem volání (kontaktní pásmo `q′`, sousední sloupce) a mřížkou kontextu, tedy sémantikou GEO2 a Janovým rozhodnutím o zaručené mřížce, ne optimalizací kódu. Limit je jen doporučení (Jan t1047u), nezastavuje smazání GEO1.

### Negativní / poznámky
- Vzorkovací profil přeceňuje podíl míst alokace: před závěrem jsem ho ověřil stopkami (Hranice ~44 % bodových sloupců + ~27 % kontext vs. 75–91 % v profilu).
- Zkouška U2 byla provedena jako zahozený experiment (soubor vrácen `git checkout`, žádný commit); mimo něj žádná změna produkčního kódu.
- Mezi dvěma 8vláknovými měřeními bodu 3 se GEO1 čas měnil o 10–20 % (load 6 → 10); poměry ×1,5 proto platí s tolerancí ±0,2.
