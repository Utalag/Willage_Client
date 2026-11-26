# Report – Krok 2: Funkce světa I (rozhraní, mapy biomů a hornin, reliéf, masiv, sopky)

Větev `gen-v1-krok02-funkce-sveta` (z `gen-v1-krok01-zaklady` c3f9b77). Plán: `04-implementace-generatoru.md`, krok 2 (větev `sjednoceni` 6e0fec6). Pravidla: 01 – 1.4, 1.7.1, 1.13, 1.14; 02 – 2.1, 2.2.

## PROP (napsáno 2026-11-21 00:30 SEČ, před experimentem)

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

## Výsledky (2026-11-21 00:50 SEČ)

Všechna kritéria kroku 2 prošla a regrese kroku 1 je beze změny. Nový kód hra nevolá, takže se výchozí hra nemění a nová reference `voda_e66` nevznikla. Testy běžely lokálně na boxu (Godot 4.7.2 headless, Python 3), bez CI.

### Co vzniklo a odkud je kód
| Změna | Soubor | Odkud |
|---|---|---|
| masiv jako funkce světa (šum MASSIF87 / MASSIF87D, `geo2.n01`) | sloučeno celé, přepínač `p87_jadro_hory` zůstává vyp | `e87-jadro-hory` ff97a9f (commit 9d7a0d0) |
| `lod90.gd` (vzorec E49/E90 `h49`, `h_m`), `blok96.gd` (blok 128 m z funkce) | sloučeno celé, přepínač `p96_blok128` zůstává vyp | `e96-blok128` 64dbbcd (obsahuje i `lod90` z E90/E92/E95 beze změny), commit fcd5f3a |
| funkce světa V1.0: `vyska`, `sloupec`, `bod`, `vahy`, `horniny`, `strop_tan` | `godot-prototyp/scripts/v1/svet_fn.gd` | nové; tvar reliéfu podle `lod90.h49` (šum + hřbet (1 − abs n)²), masiv přes `geo2.n01`, kužel s kráterem podle `svet/hruby_teren.gd` (E49) |
| výšky bloku 128 m a segmentu z funkce | `godot-prototyp/scripts/v1/blok_v1.gd` | podle `blok96.heights` (výška ve středech buněk, bez šablon) |
| testy a grafy | `godot-prototyp/tools/svet_v1.gd`, `tools/svet_v1_grafy.py` | nové |

**Výchozí parametry světa** (všechny jsou vstupní data, `svet_fn.vychozi()`): seed 49; mapa biomů po 256 m s přechodem 192 m; podíl ploch nížina / mokřad / pahorkatina / hornatina / sopečná oblast 0,35 / 0,10 / 0,30 / 0,20 / 0,05. Členitost podle biomu (posun nad neutrální úrovní 64 m, převýšení, vlnová délka, drsnost, strop sklonu): nížina 0 / 3 m / 160 m / 0,40 / 12°, mokřad −1,5 / 1,2 / 120 / 0,35 / 6°, pahorkatina 5 / 10 / 140 / 0,45 / 25°, hornatina 8 / 24 m (hřbet) / 360 / 0,35 / 40°, sopečná 2 / 3 / 150 / 0,40 / 10°. Mapa hornin po 192 m, 3 zástupci. Masiv: zdvih 8 m + amp 12 m (freq 0,008 /m) + detail 0,75 m (0,05 /m), podhůří 4 m. Sopky: 2, rozteč 384 m ± 10 %, výška 20–40 m, sklon 17°, γ 1,5, strop svahu sopky 35°.

### Testy
| Test | Výsledek | Kritérium | Stav |
|---|---|---|---|
| 1 spojitost | 12 švů bloků výchozího světa 3 × 3 (každý blok se ptá sám, rohy po 0,25 m): max rozdíl **0 m**; 480 švů segmentů 8 m prostředního bloku: **0 m**; segment proti bloku 0 m; šev přes sopku 1: 0 m. Největší krok přes šev 0,088 m = stejně jako uvnitř bloku u švu (0,088 m) | 0 skoků | prošlo |
| 2 sklony, výchozí svět (0,25 m) | p50 6,8°, p95 15,8°, max 22,4°; nejmenší rezerva pod lokálním stropem 17,6° | max ≤ strop + 1° | prošlo |
| 2 sklony, okno sopky 1 (0,5 m) | p50 5,8°, p95 19,8°, max 31,1°; rezerva 8,9° | | prošlo |
| 2 sklony, okno masivu (0,5 m) | p50 6,8°, p95 17,8°, max 25,8°; rezerva 14,2° | | prošlo |
| 2 sklony, celý svět 4096 m (mřížka 4 m, diference ±0,25 m, 1 048 576 bodů) | p50 4,2°, p95 14,2°, max 32,1°; nad lokálním stropem 0 bodů, nejtěsněji −0,72° (pahorkatina 24,7° při stropu 25°). Max podle převažujícího biomu: nížina 20,7°, mokřad 18,5°, pahorkatina 24,7°, hornatina 32,1°, sopečná 31,3° | | prošlo |
| 3 sopky | počet 2 = parametr; rozteč 413 m (384 ± 10 % = 346–422 m); sopka 1: H 31,2 m, Ø úpatí 229 m, vrchol 100,85 m (27,2 m pod okrajem sloupce, strop 123 m), kráter 4,57 m hluboký, nejvyšší bod na okraji kráteru (r 12,3 m, rc 12,2 m); sopka 2: H 32,3 m, Ø 237 m, vrchol 101,49 m, kráter 4,67 m | všechna kritéria | prošlo |
| 4 mapy | 4096 m po 8 m pro seedy 49 a 50 a výřez 3 × 3 po 1 m. Plynulost na 8 příčkách přes celý svět po 1 m: změna váhy biomu max 0,0092 / m, koncentrace horniny max 0,0075 / m (mez 0,05). Jiný seed: jiný převažující biom na 74,2 % plochy, jiná převažující hornina na 89,7 %. Podíl biomů na mapě 0,30 / 0,08 / 0,36 / 0,20 / 0,06 (parametr 0,35 / 0,10 / 0,30 / 0,20 / 0,05) | plynulé, různé seedy různé | prošlo |
| 5 determinismus | SHA-256 výšek výchozího světa 3 × 3 po 0,25 m (2 359 296 buněk, float64) ve dvou procesech: `ad397d6f6aa7a688…` oba | shoda | prošlo |
| 6 čas | dotaz na výšku 12,9 µs, sloupec 53 µs, bod 39 µs; blok 128 m: 1 m 0,21 s, 0,5 m 0,86 s, 0,25 m 3,5 s; blok se sopkou 0,5 m 0,72 s; výchozí svět 3 × 3 po 0,25 m 30–31 s; mapa 3 km po 4 m 5,9 s (E90: 4,9 s / 3 km, ale jiná úloha: slupka po LOD); vytvoření světa 89 ms | jen záznam | zaznamenáno |
| regrese: `voda_e66` 12 výkopů | d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod, 62 s | beze změny | prošlo |
| regrese: `port_studie --check` | 82 souborů, 0 změn | 0 změn | prošlo |
| regrese: `zaklad_v1` ve 2 procesech | otisk cc9e412759114af1 oba, 0 chyb | shoda s krokem 1 | prošlo |

### Negativní nálezy a odchylky
- **Odhad gradientu šumu podhodnotil sklon (opraveno).** První běh měřil gradient diferencí 0,02 / f. Na celém světě pak 3 body pahorkatiny překročily strop až o 3,1° (28,1° při stropu 25°). Diference byla delší než vlnová délka nejjemnější oktávy, takže gradient vyšel až 1,4× menší. Po zkrácení na 0,001 / f prošlo 0 bodů. Je to ale pořád odhad maxima z 8 000 vzorků, ne matematická mez. Rezerva 20 % stropu se na celém světě vyčerpala až na 0,72°.
- **Strop sklonu ořízne převýšení.** Hornatina chtěla 24 m a dostala 12,7 m, pahorkatina místo 10 m 8,1 m. U masivu E87 bylo zadáno 12 m a vyšlo 6,9 m. Detail E87 má zadáno 0,75 m a vychází jen **0,025 m**, protože jeho šum s domain warpem je velmi strmý (2,1 / m), takže detail masivu prakticky zmizel. S hodnotami E87 (freq 0,03, dfreq 0,25) by zbylo 0,5 m masivu, proto jsou výchozí hodnoty V1 0,008 a 0,05.
- **Strop v přechodu biomů.** V pásu přechodu platí strop strmějšího z přítomných biomů. Nížina má proto max 20,7° při vlastním stropu 12° (u hranice s hornatinou). Je to moje volba, potřebuje potvrzení.
- **Sklon na buňkách 0,25 m** (výška zaokrouhlená na 0,25 m, sklon přes 2 m) má ve výchozím světě max 24,3°. Je to jen informace, kritérium se měří na spojité funkci.
- **`tools/rez_profil.py` nepoužit.** Kreslí z buněk (`rez_data.gd`), ty vzniknou až v kroku 6. Řez přes šev a řezy sopkou a masivem kreslí `svet_v1_grafy.py` přímo z funkce.
- **Biomy E49 (`svet/biomy.gd`) nepoužity.** Jde o pokryv (jezero, řeka, les…) z výšky a srážek, ne o biomy varianty C (2.1). Biom tu je vstup reliéfu, ne výsledek.
- **Sopka si bere bod mapy biomů své buňky** (sopečná oblast). Biom je zdrojem výskytu sopek (2.1), ale polohu sopek určují počet a rozteč (1.14). Výška se navíc zkrátí tak, aby vrchol zůstal ≥ 5 m pod okrajem. S výchozími hodnotami se nezkrátila (H podle seedu 31,2 a 32,3 m).
- **`bod(x, y, z)`** v kroku 2 vrací pod povrchem převažující horninu z mapy hornin. Vrstvy ho nahradí v kroku 3, rozhraní zůstane stejné.
- Rozteč sopek je vzdálenost k nejbližší sopce. Okraj světa pro sopky je 320 m, aby se celé vešly do maxima 4096 m.

### Obrázky (`godot-prototyp/shots/krok02/`)
- `mapy_4096_seed49.png`, `mapy_4096_seed50.png`: mapa biomů (mísení podle vah), mapa hornin (směs barev zástupců), stínovaná výška se sopkami a výřezem 3 × 3.
- `vychozi_svet_3x3.png`: biomy, horniny, reliéf 0,25 m výchozího světa (bloky 14–16), švy čárkovaně; `vychozi_svet_vrstevnice.png`: vrstevnice po 1 m.
- `test1_sev_profil.png`: řez přes šev bloků, každý blok ze svého dotazu.
- `test2_sklony_histogram.png`: histogramy sklonů (výchozí svět, sopka, masiv, celý svět).
- `test3_sopky.png`: reliéf sopky 1 s úpatím a kráterem, řezy oběma sopkami.
- `masiv_rez.png`: masiv E87 s vahou masivu (podhůří) a řez.
- `test6_cas.png`: časy dotazů a výšek bloku.
- Data: `svet_v1.json`, `sklony_svet.json`, `det_beh1.json`, `det_beh2.json`, `zaklad_v1_beh1.json`, `zaklad_v1_beh2.json`, `voda_e66.json` + `.log`, `port_check.txt`. Binární mřížky pro grafy jsou mimo git (`/tmp/k2/data`, znovu je vytvoří `svet_v1.gd`).

### Otázky pro Jana
1–4 rozhodnuté 2026-11-21 (viz následující oddíl). Měřítko biomů Jan večer (21:21) nechal jako srovnání, ne jako rozhodnutí.

## Úpravy po rozhodnutích Jana (2026-11-21)

PROP před změnou: [`krok02-prop-upravy.md`](krok02-prop-upravy.md). Napsáno 2026-11-21 21:15 SEČ, výsledky 21:46 SEČ. Hlavní testy běžely s výchozími biomy (přepínač `biom_velke_oblasti` vypnutý). Do `main` nic nejde, krok 3 se nezačíná.

### Co platí
1. Hory se pod stropem **roztáhnou do šířky** a nechají si plnou výšku. Hornatina má zadaných 24 m (efektivní vlnová délka 360 → 680 m), pahorkatina 10 m (140 → 172 m), masiv 12 m (freq 0,008 → 0,00524 /m). Nížina, mokřad a sopečný reliéf se vešly bez změny vlny. Podhůří si nechalo 4 m (vlna 48 → 192 m).
2. V přechodu platí **vážený průměr** stropů podle vah mísení. V kuželu sopky dál strop sopky (35°).
3. Parametr `detail_max_m` (výchozí 2 m). Detail masivu je znovu **0,75 m** (předtím ořezem 0,025 m) a smí strop překročit. Strop se kontroluje na celkovém tvaru (`vyska_tvar`).
4. Výchozí 3 × 3 zůstává uprostřed (bloky 14–16, počátek 1792 m). První sopka leží těsně vně výřezu (parametr `sopka_od_okraje_startu_m` = 100 m; naměřeno 102 m od okraje, 362 m od středu 3 × 3). Druhá dál podle rozteče (725 m od středu).
5. Větší biomy jsou jen **srovnání** za přepínačem `biom_velke_oblasti` (výchozí vyp, měřítko 768 m, minimum 90 000 m²). Jan 21:21: současné biomy jsou asi v pořádku; do 01/02 se to jako rozhodnutí nezapisuje.

**Doladění k bodům 1 a 2:** po zapnutí váženého stropu a plné výšky hor byl původní přechod 192 m v pásu mokřad/hornatina moc prudký (tvar na světě až 6,7° nad stropem). Výchozí `biom_prechod_m` je proto **320 m**. Typ stanic a velikost oblastí se nemění, jen jsou okraje měkčí.

### Testy (výchozí biomy)
| Test | Výsledek | Stav |
|---|---|---|
| 1 spojitost | 12 švů bloků, 480 švů segmentů, segment proti bloku, šev přes sopku 1: max rozdíl **0 m** | prošlo |
| 2 sklony, celkový tvar | výchozí svět 0,25 m: p50 4,2°, p95 13,2°, max 25,3°, rezervy pod váženým stropem 6,54° (0 vzorků nad); okno sopky 0,5 m: max 25,5°, rezerva 7,0°; okno masivu: max 20,6°, rezerva 13,7°. Celý svět 4096 m (mřížka 4 m, 1 048 576 bodů): p50 3,8°, p95 11,2°, max 28,6°, rezerva 3,60°, **0 vzorků nad stropem**. Max podle převažujícího biomu (tvar): nížina 21,5°, mokřad 13,4°, pahorkatina 20,7°, hornatina 28,6°, sopečná 27,9° | prošlo |
| 2 sklony, povrch s detailem | výchozí svět: p50 4,2°, p95 13,8°, max 29,9°, rezerva 2,09° (0 vzorků nad); sopka max 25,5°; masiv max 26,6° (tvar tam 20,6° — detail přidá až ~6°). Celý svět: p50 3,8°, p95 11,2°, max 32,5°, rezerva 1,64°, 0 vzorků nad. Detail smí strop překročit; v těchto měřeních zůstal pod ním | zaznamenáno |
| 3 sopky | počet 2; rozteč 391 m (384 ± 10 % = 346–422 m); sopka 1: H 31,2 m, Ø úpatí 229 m, vrchol 97,76 m (30,0 m pod okrajem sloupce), kráter 3,20 m, nejvyšší bod na okraji kráteru (r 12,22 m, rc 12,24 m), 362 m od středu 3 × 3 / 102 m od okraje; sopka 2: H 32,3 m, Ø 237 m, vrchol 101,20 m, kráter 3,82 m, 725 m od středu | prošlo |
| 4 mapy | plynulost: Δváha biomu 0,0061 / m, Δhornina 0,0064 / m (mez 0,05). Jiný seed: jiný převažující biom na 71,5 % plochy, jiná hornina na 87,8 %. Podíl biomů 0,31 / 0,06 / 0,39 / 0,19 / 0,05 (parametr 0,35 / 0,10 / 0,30 / 0,20 / 0,05) | prošlo |
| 5 determinismus | SHA-256 výšek 3 × 3 po 0,25 m (2 359 296 buněk) ve dvou procesech: `04c1d51d4f0cc3d4…` oba (jiný než před úpravami, to se čekalo) | prošlo |
| 6 čas | dotaz na výšku 13,6 µs, sloupec 62 µs, bod 49 µs; blok 128 m: 1 m 0,22 s, 0,5 m 0,88 s, 0,25 m 3,6 s; blok se sopkou 0,5 m 0,64 s; výchozí 3 × 3 po 0,25 m 30 s; mapa 3 km po 4 m 6,0 s; vytvoření světa 108 ms | zaznamenáno |
| regrese: `voda_e66` 12 výkopů | d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod | prošlo |
| regrese: `port_studie --check` | 82 souborů, 0 změn | prošlo |
| regrese: `zaklad_v1` ve 2 procesech | otisk cc9e412759114af1 oba, 0 chyb | prošlo |

Kvantovaný sklon ve výchozím světě (výška na 0,25 m, sklon přes 2 m): max 29,2°.

### Srovnání větších biomů (`biom_velke_oblasti` zap, není rozhodnutí)
Souvislé oblasti převažujícího biomu, mřížka 8 m, 4-sousedé. Výchozí stav po rozšíření přechodu na 320 m (stejné přiřazení typů ke stanicím jako dřív, jen měkčí okraj):

| Seed | Varianta | Úlomků | Medián plochy | Typická velikost (√ mediánu) | Průměr √ |
|---|---|---|---|---|---|
| 49 | výchozí | 100 | 44 512 m² | **211 m** | 410 m |
| 50 | výchozí | 99 | 41 216 m² | **203 m** | 412 m |
| 49 | větší oblasti | 19 | 485 568 m² | **697 m** | 940 m |
| 50 | větší oblasti | 26 | 164 160 m² | **405 m** | 803 m |

Před jakoukoli změnou přechodu (původní krok 2, přechod 192 m) bylo seed 49: 118 úlomků, medián √ 241 m; seed 50: 112 úlomků, medián √ 247 m. Obrázek vedle sebe: `biomy_4096_srovnani.png`.

### Obrázky (`godot-prototyp/shots/krok02/`)
Stejné jako v původním kroku 2, přegenerované po úpravách, plus `biomy_4096_srovnani.png` (výchozí mapa biomů vlevo, větší oblasti vpravo, seedy 49 a 50, výřez 3 × 3 vyznačený).

## Klima (presety, 2026-11-21 22:09–22:19)

PROP před změnou: [`krok02-prop-klima.md`](krok02-prop-klima.md). Napsáno 2026-11-21 22:20 SEČ, výsledky 22:35 SEČ. Do `main` nic nejde, krok 3 se nezačíná. Rozhodnutí jsou v `01` 1.15, `04` (načtení presetu v kroku 2, nový krok 8 po vodě na povrchové jevy) a `03` (konkrétní hodnoty presetů zůstávají otevřené); větev `sjednoceni`, commit `d5f8717`.

### Jak se volí výchozí klima
Parametr `klima` má výchozí hodnotu **`mirne`**. Preset `mirne` je identita (násobitele 1, posuny 0, podíly reliéfních biomů 0,35 / 0,10 / 0,30 / 0,20 / 0,05). Výchozí svět proto zůstane bitově stejný. Základní klima ze seedu (`V1_KLIMA_ZAKLAD`) se použije jen při **`klima=ze_seedu`**; u seedu 49 by to teď padlo na `ledovec` (náhoda pořadí v tabulce, hodnoty příkladů se ještě mohou změnit). Pojmenovaný preset (`poust`, `step`, `tundra`, `ledovec`) svět vynutí rovnoměrně. Pomalá mapa je háček `klima_vahy(x, y)`: při vynuceném / výchozím pojmenovaném klimatu vrací váhu 1 na základu, při `ze_seedu` mísí sousedy. **Do výšky ani podílů biomů se mapa v tomto kroku nemísí** — reliéf bere jen základní preset (až budou hodnoty doladěné, půjde míchání zapojit). `k_voda` a `k_horniny` se jen uloží pro pozdější kroky.

Příkladové presety poušť / step / tundra / ledovec jsou v `godot-prototyp/data/klima_presety.csv` označené `priklad=1` (náčrt, nehodnocené hodnoty).

### Testy
| Test | Výsledek | Stav |
|---|---|---|
| 1 spojitost | švy bloků, segmentů, segment proti bloku, šev přes sopku: max **0 m** | prošlo (beze změny) |
| 2 sklony, celkový tvar | výchozí svět: p50 4,2°, p95 13,2°, max 25,3°, rezerva 6,54°; svět 4096 m: p50 3,8°, p95 11,2°, max 28,6°, rezerva 3,60°, 0 vzorků nad stropem | prošlo (beze změny) |
| 2 sklony, povrch s detailem | výchozí svět max 29,9°, rezerva 2,09°; svět max 32,5°, rezerva 1,64°, 0 vzorků nad | zaznamenáno (beze změny) |
| 3 sopky | 2; rozteč 391 m; H 31,2 / 32,3 m; první 102 m vně 3 × 3 / 362 m od středu | prošlo (beze změny) |
| 4 mapy | Δváha 0,0061 / m, jiný seed 71,5 % | prošlo (beze změny) |
| 5 determinismus (výchozí `mirne`) | SHA-256 výšek 3 × 3 po 0,25 m (2 359 296 buněk) ve dvou procesech: **`04c1d51d4f0cc3d4`** oba, výšky 67,5–94,0 m | prošlo (bitově shodné s předchozím krokem 2) |
| 5b determinismus (`klima=poust`) | dva procesy: **`6e2a92c42cfc2b50`** oba, výšky 65,3–86,0 m, jiné než `mirne` | prošlo |
| 6 čas | výška 12,8 µs, sloupec 60 µs, bod 47 µs; blok 0,25 m 3,6 s; mapa 3 km po 4 m 5,8 s; vytvoření světa 109 ms | zaznamenáno |
| 7 klima v `vse` | výchozí id `mirne`; háček vah jednotný; poušť na výřezu 3 × 3 po 1 m otisk `aee96e5907bbf4b5` ≠ `mirne` `fd6239c8340bf338`, dva výskyty shoda | prošlo |
| 7 srovnání presetů (seed 49, 1 m) | `mirne` `fd6239c8340bf338` (67,5–94,0 m); `poust` `aee96e5907bbf4b5` (65,3–86,0 m); `ledovec` `c134c6f77bbab811` (72,7–122,5 m) | prošlo |
| regrese: `voda_e66` 12 výkopů | d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod | prošlo |
| regrese: `port_studie --check` | 82 souborů, 0 změn | prošlo |
| regrese: `zaklad_v1` ve 2 procesech | otisk cc9e412759114af1 oba, 0 chyb | prošlo |

### Obrázek
`godot-prototyp/shots/krok02/klima_srovnani_seed49.png` — stejný seed 49, tři sloupce mírné / poušť / ledovec, nahoře mapa reliéfních biomů, dole stínovaný reliéf, výřez 3 × 3 vyznačený. Poušť je plošší a sušší (víc nížiny, málo mokřadů a hor), ledovec má převahu hornatiny a vyšší reliéf. Na mapě 4096 m u ledovce sahá povrch až k měkkému stropu sloupce (123 m) — očekávané u nehodnocených hodnot (posun +4 m a převýšení ×1,3).

### Odchylky
- Základní klima se ze seedu **nevolí ve výchozím běhu**, právě aby zůstal otisk `04c1d51d4f0cc3d4`. Chce-li Jan seedové klima jako výchozí, stačí změnit výchozí `klima` na `ze_seedu` (výchozí svět se tím změní).
- Pomalá mapa je zatím jen háček, ne zásah do reliéfu.
- Příkladové presety nejsou laděné; konkrétní čísla zůstávají otevřená (03).
- Časy dotazu se proti minulému běhu liší v řádu mikrosekund (šum měření).

## Další krok
Krok 3 (geologie a útvary) se nezačíná, čeká na schválení. Do `main` nic nejde.
