# PROP GEO2 K5: adaptivní mřížka hranic (6.3) místo pevné 0,5 m

*Zapsáno před prací 2026-11-27 ~16:50 (Jan t1042u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 2.5 (plocha vrstev, τ ≤ e_k), 6.3, V5,
krok K5 v kap. 5. Větev `geo2-k5-mrizka` z `geo2-k4-intervaly`. Kritérium: GEO2 lepší než GEO1, výkon ne výrazně pod K3/K4.*

## Návrh
1. **Kořeny 1 m na světové mřížce, dělení 0,5 → 0,25 m (quadtree).** Uzly mřížky (sloučené cílové intervaly zásobníku) na mřížce 1/8 m,
   počítají se jen ty, které dělení potřebuje.
2. **Přijetí buňky:** rohy mají stejný počet cílových intervalů a v kontrolních bodech – střed (na úhlopříčce 00–11 trojúhelníků) a středy
   4 hran – mají přesné intervaly stejný počet a |interpolace − přesně| ≤ τ (`tau_m`, výchozí 0,125). Jinak dělit. Buňka 0,25 m, která
   nevyhoví, zůstane s příznakem odhadu (`BodPlochy.Odhad` → `HraniceOdhad` u kontaktu).
3. **Švy:** rozhodnutí kořene závisí jen na uzlech světové mřížky → stejné v každém bloku (bitově).
4. **Volba v datech:** `tvar.mrizka` zásobníku `adaptivni` (výchozí, příklad kontraktu) / `pevna` (0,5 m); `MoznostiKompilace.KrokMrizkyHranicM`
   = vynucená pevná mřížka (testy K1b/K3, srovnání). Neznámá hodnota = chyba `MRIZKA_NEZNAMA`.
5. **Sdílený kód:** trojúhelníky, vzdálenost, rozsah z a intervaly uzlu jsou jeden kód (`HledaniPlochy`) pro pevnou i adaptivní mřížku;
   pevná dává stejný výsledek jako dosud.
6. Okraj kontextu: + velikost největší buňky (1 m) místo kroku 0,5 m.

## Kritéria
| Test | Očekávání |
|---|---|
| V5 | proti přesnému `Hranice` po 0,25 m (sloupce na mřížce 0,25 m i mimo ni): sled cílových vrstev 0 neshod mimo buňky s odhadem, max \|Δz\| ≤ τ ve sloupcích na mřížce; vykázat p99 a max, zvlášť strmé svahy > 20° a rychlé změny mocnosti; počet buněk s odhadem |
| srovnání | chyba hranic pevné 0,5 m × adaptivní (p99, max) – adaptivní musí být lepší |
| švy | listy kořene spočtené ve dvou různých blocích (kontext) bitově stejné; V7 otisk bloku 1 / N vláken |
| kontakt | V4 bloku E84 s adaptivní mřížkou: 0 vynechaných tětiv ≥ t_det; skarn × pevná mřížka po kategoriích |
| výkon | kontext (uzly) a blok K4 s adaptivní × pevnou 0,5 m |
| regrese | celá sada 0 chyb, otisky GEO1 beze změny |

## Rizika
- kontrolní body jen ve středu a středech hran: mezi nimi může chyba τ překročit (měří V5 na mřížce 0,25 m i mimo);
- víc uzlů v členitých místech → dražší kontext (měří se).

## Výsledky *(2026-11-27 ~17:10)*
Commity: `72a957b` HledaniPlochy + pevná mřížka beze změny, `cc89f15` PlochaVrstevAdaptivni, `074d72b` volba v datech + okraj,
`c21021a` testy. Celá sada **735 / 735 OK**, otisky GEO1 beze změny (krok 5, G-1, G-3).

| Test | Výsledek |
|---|---|
| listy (7 bloků 64 m, skarn: granitoidy) | 1 m 84,5 %, 0,5 m 3,2 %, 0,25 m 12,2 %; listů s odhadem 2730 |
| V5 na mřížce 0,25 m (458 752 sloupců) | **neshod sledu 0, p99 0,004, max 0,123 m, > τ 0** (mimo listy s odhadem) |
| V5 mimo mřížku (náhodné polohy) | neshod 0, p99 0,004, max 0,139 m, **> τ 4 sloupce** |
| V5 svahy > 20° (111 791 sl.) / rychlá mocnost (635) | max 0,118 / 0,000 m, > τ 0 |
| listy s odhadem (≈ 0,4 % sloupců) | vrstva vykliňuje uvnitř buňky 0,25 m: neshod sledu 768 z 1807 sloupců (příznak `HraniceOdhad` jde do kontaktu) |
| pevná 0,5 m pro srovnání | neshod sledu 1444, max 6,6 m, > τ 855 sloupců → **adaptivní je výrazně lepší** |
| švy | 1024 kořenů v překryvu dvou kontextů, 0 rozdílů |
| skarn proti referenci 0,125 m (11 527 buněk) | jinak: adaptivní 9, pevná 0,5 m 25 |
| V4 E84 s adaptivní mřížkou | 0 tětiv ≥ t_det vynecháno |

**Negativní výsledek:** jen kontrolní body (střed + středy hran) V5 nesplnily – 4 sloupce na mřížce 0,25 m nad τ (max 0,142 m).
Proto přibyla úplná kontrola všech bodů 0,25 m v buňkách 1 m (`KontrolaMrizkyPo025`, výchozí zapnuto): 0 sloupců nad τ.

**Výkon** (uzly = volání `Hranice` v kontextu): adaptivní 630 427 × pevná 141 148 (7 bloků); kontext 5,1 s × 1,4 s.
Blok 128 m (kontext + blok K4): (1024, 512) pevná 3,37 s, adaptivní 3,88 s, rychlá (bez úplné kontroly) 2,92 s;
(3000, 2000) 1,21 / 2,58 / 1,34 s. Samotný blok K4 stejný (0,14 × 0,15 s na 64 m); dražší je jen kontext. Rychlá varianta dala
v měřených blocích stejné buňky jako úplná. Čas je zatížen cizími procesy na boxu (grep, ~2 jádra).

**Rozhodnutí pro Jana (kontrakt neměním):**
1. Úplná kontrola 0,25 m = V5 zaručeně, ale kontext ~2–4× dražší. Rychlá varianta = cena jako pevná mřížka, V5 jen statisticky
   (4 / 458 752 sloupců nad τ, max 0,142 m). Výchozí zůstává zaručená varianta; přepnutí na rychlou by změkčilo V5.
2. Listy s odhadem (vykliňování uvnitř 0,25 m): uznat jako výjimku V5 s příznakem `HraniceOdhad`, nebo přidat úroveň 0,125 m (cena).
3. Mimo mřížku 0,25 m 4 sloupce nad τ (max 0,139 m) – kontrakt měří po 0,25 m, takže V5 splněno; uvádím pro úplnost.

## Rozhodnutí Jana (2026-11-27 17:37, t1043u)
1. Výchozí zůstává **zaručená** varianta (úplná kontrola 0,25 m); dražší kontext je přijatelný, jde jen o generování.
2. Buňky 0,25 m s vykliňováním vrstvy uvnitř buňky (`HraniceOdhad`) jsou **uznaná výjimka V5** – zapsáno do kontraktu
   (`06-geologie-geo2.md` V5 a 6.3, větev `geo2-kontrakt-docs`; `KONTRAKT-GEO2.md`). V5 je tím splněno: mimo výjimku 0 neshod sledu,
   0 sloupců nad τ na mřížce 0,25 m; výjimka se vykazuje zvlášť (1807 sloupců, 768 neshod v 7 blocích).
3. Běhy jako výchozí `KontextBloku.Sloupec` – provedeno na `geo2-vychozi` (`geo2-vychozi-prop.md`).
