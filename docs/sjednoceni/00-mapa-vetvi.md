# 00 – Mapa větví a studií (stav 2026-11-20 14:10 SEČ)

Podklad pro sjednocení (Jan 2026-11-20 14:08: „Budeme teď sepisovat aktuálně finální stav… napříč větvemi vybrat nejvhodnější řešení“). Tento soubor nic nerozhoduje. Jen popisuje, co kde je, co bylo naměřeno a kde si větve odporují. Rozhodnutí se dělají v chatu s Janem a pak se zapíšou do kapitol (`01-…`).

Zdroje: `git branch -r`, `git tag`, `TODO.md` (main 0e8aa00), `blueprint-studie/PROP.md` a `DENIK.md` na jednotlivých větvích, `navrhy/`, `sdilene/`, `devlog/`. Značky [n] odkazují na seznam na konci.

Zkratky: **vých.** = výchozí stav přepínače, **zap/vyp**, **SEČ** = středoevropský čas. „Kontrola výchozí hry“ = `voda_e66` d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod, a `port_studie --check` 0 změn. Tou prošly všechny větve E78–E96.

## 1. Strom větví

```
main 0e8aa00 ─┬─ (sloučeno) E52–E77 voda, tezba-studie, e66*, e67, refaktor-uzly (obsah přes E66)
              │
 380cccf ─────┴─ e78 → e79 → e80 → e81 → e82 → e83 ─┬─ e84 (jen nástroj + rešerše)
                                                     └─ e85 (+ main 57c7dfb)
 57c7dfb ─────── e86, e87, e88 (každá zvlášť)
 8d4d809 ─────── e89, e90, e91, e92, e93 (každá zvlášť)
 0e8aa00 ─┬───── e94-metry (= e89 + převod) ── e96-blok128
          ├───── e95-async-voda (samostatně, bez e94)
          └───── zkusebni-vse (= e85 + e84 + e86 + e87 + e89–e94, BEZ e95 a e96)
```

- Nic z E78–E96 není v main. Merge-base je ve třech generacích (380cccf, 57c7dfb/8d4d809, 0e8aa00).
- `e96` nemá `e95` a `e95` nemá `e94`. Asynchronní voda a blok 128 m tedy zatím nikdy neběžely spolu.
- `zkusebni-vse` je jediné místo, kde jsou E78–E94 pohromadě. Nemá ale E95 ani E96. **Pozor na jména:** její plán i výsledky jsou v PROP zapsané jako „E95“ a snímky jsou v `shots/e95/`. Číslo E95 má přitom i asynchronní voda na `e95-async-voda`. Při sloučení je potřeba jedno přečíslovat (navrhuju zkušební větev = „Z1“).

## 2. Voda E52–E77 (v main)

| Pokus | Co řeší | Přepínače (vých.) | Klíčová čísla | Stav |
|---|---|---|---|---|
| E52–E58 | varianty podzemí (buňky, pole, pásma z funkcí, Darcy), algoritmy A/B/C | `p52_*`, `p58_var` base | E58 „pásma z funkcí“ = výchozí podzemí hry [1] | v main |
| E59–E61 | materiály podle skutečných K, n, Sy | tabulka v4 | perm = (log10 K + 9)/6 [2] | v main |
| E62–E64 | graf těles, lokální oprava přelivu, kanonický sestup | `p64_budget` 5000 | lokální = plný v testech [1] | v main |
| E66–E67 | integrace do prototypu; podzemí vytéká z okrajů (režim `pretok`) | `p67_rezim` "" (= E58), `p67_okraj` vyp | E67 je jen alternativa, výchozí zůstává E58 [3] | v main |
| E68 | orchestrátor povrch + podzemí, jedna bilance, otisk | `p68_hydro` zap, max 64 kol | smyčka tůň→pramen chyba 61 % → 0 [4] | v main |
| E69–E73 | symetrie, harmonický průměr, kapacita dolů, slučování výstupů, nálezy | `p69_remizy` zap, `p70_prumer` „pomer“, `p71_*` zap, `p72_*` zap (8 m), `p73_*` zap | bilance ≤ 1e-12 l/s; 150 → 6 výstupů [4] | v main |
| E74 | hladina podzemí jako plocha `gw` | `p74_gw`, `p74_vyzvednout`, `p74_hladina` zap | 9,4 kB místo 1,6 MB pásem; plný výpočet 1,7 → 2,3 s [4] | v main (Jan 01:49) |
| E75 | kras po tělesech | `p75_kras` **vyp** | 1. dutina 331 herních dní = 13,8 reálného dne [4] | v main, vypnuto |
| E76 | voda po přenosu výřezu, uložené prameny | `p76_prameny` zap | lokálně = plně, 0 neshod [4] | v main (Jan 03:26) |
| E77 | čas 1 herní den = 1 h | `p71_cas` 24 | eroze E51 23 → 139 min reálně [5] | v main (Jan 2026-11-19 22:19) |

Otevřené z vody (TODO main): slučovat drobné výstupy i mezi sebou; kreslit neobsazený pramen; po výkopu stavět `gw` jen pro dotčené těleso; zrychlit lokální přepočet (E79 jen o 10–35 % rychlejší než plný) [4].

## 3. Blok 2 – model světa a geologie (větve, nesloučeno)

| Větev / tag | Co řeší | Přepínače (vých.) | Klíčová čísla | Rozhodnuto / otevřené | Pomáhá / škodí jinde |
|---|---|---|---|---|---|
| `e78-prekryv` / `e78-prekryv` (77539f4) | změny hráče jako kanonický překryv buněk 0,25 m nad definicí | (nástroj, `prekryv78.gd`) | chodba 70 m 244 B proti 13–17 kB pole; 1000 buněk 1,8 kB; načtení = živý stav v 6/6 [6] | princip přijat (TODO), WVB1 zatím ukládá celé pole | základ pro E85, E88; odhalil chybu lokální vody u chodeb |
| `e79-chodby-voda` (99032fe) | lokální voda vidí dutiny | `p79_chodby` **vyp** | 0 neshod v 11 scénářích; lokálně 1,1–1,5 s proti plným 1,6–1,7 s [6] | Jan: zapnout? (otevřené) | jediná oprava pořadové závislosti z E83 |
| `e80-hranice-funkci` (88df75b) | kde končí funkce: buňka 0,5 m | – | 0,25 m z funkcí ≠ zjemnění v 7,8 % buněk; uložení „klíče + deflate“ nejlepší [6] | Jan 03:26: 0,25 m z funkcí + přepočet starých bloků; zákaz dna/okraje | E80 doporučilo opak (blok drží svou `gen_ver`) → **konflikt K4** |
| `e81-tenke-vrstvy` (fe94bd9) | tenké vrstvy mizí podle rozlišení | `p81_tenke` vyp | chybění 60 % → 7,6 % (0,5 m); svět jiný o 2,3 % [6] | Jan 03:26: v blueprintu zakázat vrstvy < 25 cm (→ E85) | p81 nafukuje vrstvy, tělesa vody horší |
| `e82-vapenec-hladina` (b8c1b69) | vápenec k hladině v ~50 % bloků | `p82_vapenec` vyp, `p82_tesneni` zap, hloubka 2 m | 495/1000 mincí; kras v E58 skoro nevzniká (2/63), v E67 19/30 ostrovů [6] | Jan 01:55 + 03:26 (mince i pro hluboký vápenec + dolomit); otevřené: jíl, E67 | zdvojnásobí závislost na pořadí vložení |
| `e83-determinismus` (ff9d2ad) | Hash(seed, změny, pořadí) | – | 12/12 bitově; pořadí vložení mění 1,9 % buněk (záměr); otisk vody = surové float64 [6] | otevřené: zaokrouhlit otisk vody? rohoví sousedé? | opravil klíč mezipaměti podzemí |
| `e84-implicitni-geologie` (070274c) | žíly, pegmatity, skarny, kras jako SDF | (nástroj) | R1 +51 ms / blok (0,5 m); útvar 176–296 B; kras přes šev funguje [6] | otevřené: SDF za příznakem, nahradit `cavity_one`? | řeší, že dnešní dutina nejde přes šev |
| `e85-blok2-rozhodnuti` (4ac8a1d) | implementace rozhodnutí 03:26 | `p85_blok2`, `p85_jemne`, `p85_okraj`, `p85_vrstvy` (0,25 m), `p85_voda` – vše vyp | jemné z funkcí 442–784 ms/blok (**65–108× pomalejší**); okraj: díry ve dně 703 → 0; tunel lokálně 12,6 s proti plným 1,6 s [6] | otevřené: co zapnout | `p79` sám nestačí, je potřeba `p85_voda` |

## 4. Blok 3 – přenos výřezu (větve, nesloučeno)

| Větev / tag | Co řeší | Přepínače | Klíčová čísla | Otevřené | Vztahy |
|---|---|---|---|---|---|
| `e86-otoceni-90` (c458886) | otočení výřezu po 90° | `p86_otoceni` vyp | otočení dat přesné (0 neshod, 5 ms); znovu generovat otočené = 19–25 % buněk jinak; švy vrstev skáčou o 1,8–2,7 m [7] | zapnout? klín vrstev u švu? zrcadlení? | počítat v souřadnicích původu (týká se i E85 jemné mřížky) |
| `e87-jadro-hory` (ff97a9f) | masiv jako funkce světa přes víc bloků | `p87_jadro_hory` vyp | sedlo na švu zmizí (šev 47,5–52,6 U); vedle nížiny stěna 5–6 m; prameny 9 → 3 [7] | zapnout? podhůří? terasy? | koliduje s `p94_hora_k` a E96 (**K6**); `veg.gd` nezná `hora_vyzdvizena` |
| `e88-kontrakt-navrh` (72e9ff3) | `TerrainSource/Transform/Placement/Instance`, WTI1, hashe, co ověřuje server | jen dokument `navrhy/navrh-terrainsource-kontrakt.md` | blok bez změn ~400–450 B; řídicí mřížka 8,7–35 kB → neukládat [8] | 11 otázek; s Willage-backend neprojednáno | souřadnice pevně 16 × 16 × 64 → po E96 neplatí (**K1**) |

## 5. Blok 4 a dál – měřítko, výkon, blok 128 m

| Větev / tag | Co řeší | Přepínače | Klíčová čísla | Rozhodnuto / otevřené | Vrstva |
|---|---|---|---|---|---|
| `e89-jednotky` (e8fff3c) | modul `jednotky.gd`, audit | `p89_meritko` vyp | 160+ ručních konstant; l → m³ dvěma způsoby (13 % náhodných hodnot jinak v posl. bitu); volání 3–4× dražší než konstanta [9] | Jan 2026-11-20 ~11:04 (t699u): 1 j = 1 m, převádět postupně, sjednotit l → m³, stromy a stavby v metrech | data |
| `e90-lod` (a68a267) | LOD a sešití švů, test 3 × 3 km | `p90_*` vyp | 2,27 M trojúhelníků, síť ≈ 260 MB; funkce `h_m` = E49 × 8 vodorovně, reliéf × 3 [10] | otevřené (6 otázek) | **prezentace** (+ funkce světa = data) |
| `e91-pruhlednost` (9f95d3b) | průhlednost / řez v izometrii | `p91_*` vyp | A dither 67/100 % viditelnosti [10] | otevřené | **prezentace** |
| `e92-meritko` (ffd6e44) | test měřítka, omezovač sklonu | `p92_svah`, `p92_max_sklon`, `p92_hladit` vyp | na 8 m bloku nepomůže, mění vodu (těleso 1 → 0); na 128 m strop 0,6 → 0 % nad 45°, ale 36 s [10] | Jan 11:48: bloky 128 m z funkce (→ E96); ostatní otevřené | data (svah) + prezentace |
| `e93-telefon` (7cbcf68) | bench APK, odhad CPU telefonu | preset „Android (bench)“ | logika v 1 vlákně; střední telefon voda 3,9–5,0 s, výkop 1,1–1,5 s; slabý 4,4–4,6× pomaleji [11] | čeká: Jan spustí APK | data (CPU) + prezentace |
| `e94-metry` / `e94-metry-2` (96f2310) | převod 30 skriptů na `jednotky.gd`, scéna v metrech | `p89_meritko` **zap na větvi**, `p94_hora_k` 1, `p94_meritko_veg` 0,5 | otisky beze změny ve 40 commitech; l → m³ sjednoceno bez změny otisků; hora max 30,5 m (strop sloupce); 162 neshod lokální vody při `hora_k` 1,5 (i na main) [12] | Jan 11:39: velikost vegetace 0,5; otevřené: sloučit, cesty, hora | data + prezentace |
| `e95-async-voda` (597342d) | voda ve vlákně po výkopu | `p95_async_voda` vyp, `p95_zpozdeni`, `p95_rezim` | blokování 652 ms → 0,15 ms; fronta = synchronní otisk po otisku; 128 m s podzemím 90–228 s do výsledku [13] | otevřené: kdy převzít, fronta / sloučení, zrychlit podzemí | data |
| `e96-blok128` (64dbbcd) | ostrov = blok 128 m z funkce | `p96_blok128` vyp, `p96_relief` 1, `p96_natazeni` 4, `p96_dlazdice` (7,4) | načtení 138–142 s, výkop 27–41 s, RSS 2,5 GB, tůně 22 % plochy, hora uříznutá na 30 m [14] | otevřené (6 otázek) | data + prezentace |
| `zkusebni-vse` / `zkusebni-vse-1` (7e2a06f) | všechny přepínače v panelu | 34 prvků, `p89_meritko` vyp | 55 dvojic bez pádu; E87 přebije `p94_hora_k`; E82 + hora 16 s [15] | – | nástroj |

Starší samostatné studie (v main, mimo hru): `voda-studie` (buněčná voda po ticích, jiný model než ostrovní voda), `lozika-studie` (gen-v3, zásobník ze serveru), `skala-studie`, `trava-studie`, `napojeni-studie` (vzhled), `tezba-studie` (T01–T03: vlastnosti a těžba hornin, `horniny_tezba_navrh.json`). Větve `e66*`, `e67-podzemi-okraje`, `tezba-studie`, `e68`–`e77`, `voda-e74-e77-slouceni` jsou celé v main. Obsah `refaktor-uzly` je v main přes synchronizaci E66 (rozdíl 3 soubory, 13 řádků).

### Prezentační vrstva (mimo kapitolu 1, Jan t710u)

Jen čte datový model. Patří sem: LOD a sešití (E90), průhlednost a řez (E91, svislý řez ze zkušební větve), shadery, stíny, draw calls a trojúhelníky (E93, E96), měřítko modelů vegetace (`p94_meritko_veg`), barvy materiálů (`mat.gd COLORS`). Výsledný pohled (2D dlaždice nebo 3D modely) zatím není rozhodnutý, takže datový model na něm nesmí záviset.

## 6. Konflikty a duplicity napříč větvemi

| # | Co | Kde | Proč to vadí |
|---|---|---|---|
| K1 | **Slovo „blok“ znamená tři věci**: blok blueprintu 8 × 8 × 32 m (16 × 16 × 64 buněk), blok vesnice 128 m (E96 ho skládá z 16 × 16 bloků 8 m) a ostrov „4 bloky, nejvýš ~16“ [16] | WVB1, E88, `veg.gd`, `block.gd` (BS 16) vs E92/E96, TODO „ostrov 4 × 4 = 512 m“ | vkládání, rotace, sousedé, recept, seed i WVB1 jsou dnes na 8 m. Po E96 nevíme, co hráč vkládá |
| K2 | **Tři jednotky s podobným jménem**: `U` = 0,5 m v geologii (E87 „40 U = 20 m“), herní jednotka `hj` = 0,25 m, scéna 1 j = 0,5 m vodorovně / 1 m svisle (před E94) | `geo_fn.U`, `jednotky.gd`, E89 | čísla v PROP se snadno čtou špatně; E94 to ve scéně opravilo jen na své větvi |
| K3 | **Výška sloupce 32 m** (BH 64 × 0,5 m) proti potřebě hory: E94 strop 30,5 m, E96 musel snížit reliéf × 3 → × 1, E90/E92 počítaly s 7–50 m | `jednotky.gd`, WVB1 `dims`, E94, E96, E90 | „skutečnou horu“ nejde udělat bez změny formátu |
| K4 | **Verze generátoru**: Jan 03:26 „nová verze přepočítá i staré bloky“ proti E80 „blok drží svou `gen_ver`“; E80 změřilo, že přepočet rozbije okolí výkopů (313/1787 buněk, 32 položení ve skále); E88 přidává, že každý přepínač terénu je nová verze | E80, E85, E88 §7 | každé zapnutí p81/p82/p85/p87/p96 by přepočítalo všechny ostrovy |
| K5 | **Lokální přepočet vody ≠ plný** (jedna chyba, hlášená pětkrát): E83 závislost na pořadí bez `p79`; E85 `p79` sám nestačí; E94 162 neshod při `hora_k` 1,5 (i main); E95 S5 110 `eff`, ve hře `fill` 43 / `to` 38; E95 blok 128 m `fill` 102 / `to` 60 | E79, E83, E85, E94, E95 | rozbíjí determinismus i shodu po načtení; výchozí test `voda_e66` to nevidí (0 neshod) |
| K6 | **Hora třemi způsoby**: E87 masiv (funkce světa, p87), `p94_hora_k` (násobí výšku šablony), E92 omezovač sklonu (horu snižuje), E96 funkce `lod90.h_m` s ořezem | E87, E94, E92, E96, zkušební panel | v panelu E87 přepíše `hora_k`; tři různé funkce světa |
| K7 | **Funkce světa ve třech nastaveních a dvě implementace bloku 128 m**: E90/E92 `h_m` × 8 / reliéf × 3 (dlaždice 14,5), E95 `blok128_voda95.gd` (jen povrch, × 8 / × 3), E96 `p96_blok128` (× 4 / × 1, dlaždice 7,4) | E90, E92, E95, E96 | čísla E95 a E96 pro 128 m nejsou o stejném terénu |
| K8 | **0,25 m mřížka**: zjemnění 0,5 m (dnes) proti vzorku z funkcí (Jan 03:26, `p85_jemne` 65–108× pomalejší, 7,8 % buněk jinak); E84 doporučuje „definice zůstává 0,5 m“; hra pořád kope po 0,5 m | E80, E84, E85 | rozhodnutí je, implementace je drahá a neodsouhlasená |
| K9 | **Výchozí podzemí E58 proti E67**: kras (E75, E82) funguje jen v E67, hra běží v E58; E77 mění chování E67 (kapacita 6× menší) | `p67_rezim`, E82, E77 | mince vápence 50/50 ve výchozí hře skoro nic nedělá |
| K10 | **Tabulky materiálů**: `materialy_voda.json` (13 základních) + `horniny_voda.json` (63 hornin, id 20–107) + `materialy_voda_navrh.json` (E59, nepřijatý) + `tezba-studie/data/horniny_tezba_navrh.json` (83, má hustotu, Mohs, vzácnost) + `mat.gd` (13 id, barvy, skóre rarity) + `poradi_hornin.json` (65 id). Kopie v `/workspace/willage-ideas/sdilene/` je **zastaralá** (2026-11-19 22:52, ještě čas × 144 a bez `_rozp75`) | `sdilene/`, `tezba-studie/`, prototyp | hustota je jen u 5 hornin ve vodní tabulce; vegetace zná jen 13 základních id |
| K11 | **Čísla zdrojů v ZDROJE.md se kříží**: [73]–[79] je v E84 rešerše geologie, v E93 Geekbench a GPU. Na `zkusebni-vse` jsou obě řady pod stejnými čísly, E96 cituje [77]–[79] bez záznamu na své větvi, E95 má [81]–[83] | `blueprint-studie/ZDROJE.md` na větvích | při sloučení přečíslovat |
| K12 | **Dvě vodní studie**: `voda-studie` (voda po buňkách a ticích) a ostrovní voda (prameny, události, pásma); jednotky převodu času: voda × 24 (E77), těžba vlastní historické × 144 | `voda-studie/`, `tezba-studie/PROP.md` | „voda jako data v buňkách“ (Jan 2026-11-17) dnes znamená něco jiného než ve hře |

## Zdroje

1. `blueprint-studie/PROP.md` (main 0e8aa00), oddíly E52–E64; `devlog/voda-algoritmy.md`.
2. `sdilene/materialy_voda.json` v4, pole `_e61`; PROP E59–E61.
3. `godot-prototyp/scripts/teren/params.gd` (main): `p67_rezim` "", `p75_kras` false; PROP E67.
4. `TODO.md` (main 0e8aa00), oddíly Voda a Rozhodnutí Jana; PROP E68–E76.
5. PROP E77 výsledky (main); `scripts/voda/cas_hry.gd`.
6. PROP oddíly E78–E85 na `zkusebni-vse` 7e2a06f (shodné s větvemi e78…e85, tipy 77539f4, 99032fe, 88df75b, fe94bd9, b8c1b69, ff9d2ad, 070274c, 4ac8a1d).
7. PROP E86, E87 (větve c458886, ff97a9f).
8. `navrhy/navrh-terrainsource-kontrakt.md` na `e88-kontrakt-navrh` 72e9ff3; `navrhy/format-bloku-wvb1.md`.
9. PROP E89 (e8fff3c), `godot-prototyp/scripts/jednotky.gd`.
10. PROP E90, E91, E92 (a68a267, 9f95d3b, ffd6e44).
11. PROP E93 (7cbcf68), `shots/e93/cpu_limit_souhrn.json`.
12. PROP E94, E94b (96f2310).
13. PROP E95 na `e95-async-voda` 597342d.
14. PROP E96 na `e96-blok128` 64dbbcd.
15. PROP „E95 zkušební větev“ na `zkusebni-vse` 7e2a06f.
16. `devlog/koncept.md`, `devlog/svet-a-meritko.md`, `teren-bloky-bunky.md` (main).
