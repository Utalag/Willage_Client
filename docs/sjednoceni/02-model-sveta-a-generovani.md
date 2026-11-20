# 02 – Model světa a generování bloku 128 m (kostra k rozhodnutí)

Stav: **kostra**, 2026-11-20 20:45 SEČ. Každý bod obsahuje současný stav z větví a studií, varianty s naměřenými čísly, doporučení a otázku pro Jana. Pole **Platí:** je prázdné. Vyplní se až po Janově rozhodnutí v chatu (Jan t712u). Do té doby nic z tohoto souboru neplatí jako pravidlo.

Navazuje na kapitolu 1 (`01-principy-a-vstupy.md`), která je rozhodnutá (až na přepočet při nové verzi generátoru, 1.5, a přeskočený datový rozpočet, 1.11). Tady se řeší, **v jakém pořadí a po jakých jednotkách se z rozhodnutého modelu svět a ostrov skutečně generují**. Vykreslování, LOD, průhlednost, shadery a slučování sítí patří do prezentační vrstvy (kapitola 7) a z dat jen čtou.

Značení: K1–K12 = konflikty z `00-mapa-vetvi.md`. [n] = zdroj ze seznamu na konci. Časy jsou v SEČ. Měření jsou z boxu (Linux x86_64), telefon je jen odhad z E93.

---

## 2.1 Pořadí kroků generátoru

**Téma.** V jakém pořadí vzniká blok 128 m: funkce světa, reliéf, geologie a útvary, sopky, výchozí voda, vegetace. Co zůstává funkcí a co se vzorkuje do buněk.

**Současný stav**
- Dnešní pipeline (`pipeline.gd`, režim `geo` = v2) běží po **segmentech 8 m** (v kódu „blok“) a má toto pořadí [1]:
  1. povrch ze **šablony** (recept louka / kopec / hora / písčina) a volitelná eroze,
  2. dorovnání okrajů na sousedy; chybí-li soused, regionální základ (`surf_ref`), nebo `base_hm` z hrubého světa (E49) [1][2],
  3. vrstvy: vlastní tvar + regionální základ, mocnosti se napojují klíny na sousedy,
  4. hranice = součet mocností, kontext `geo_fn.world_fn` + `block_info`,
  5. **celý sloupec** se vzorkuje do buněk 0,5 m (`geo_fn.sample`),
  6. minerály, pak dutiny (`cavity_one`, dnes nejvýš jedna na segment — to 1.7 ruší),
  7. voda: vsakování gen-v3 (`G.infiltrate`),
  8. validátor gen-v3.
- Vegetace v pipeline není. Generuje se až z hotového segmentu po všech transformacích (`veg.generate`, seed účel „VEG“) [3].
- E96 zapíná `p96_blok128`: ostrov je 16 × 16 segmentů 8 m = 128 × 128 m. Povrch bere z funkce `lod90.h_m` přes `base_hm`, bez šablon. Typ segmentu (jen geologie) se volí z průměru a rozpětí výšky. Vrstvy, minerály, dutiny a voda jdou stávající pipeline [2].
- **Časy E96** (box, 256 segmentů): generování 58–61 s (**224 ms / segment**, lineární). Pole povrchu / kostky / duální povrch / vegetace 7,3 / 8,4 / 2,8 / 9,6 s. Plná voda 49–53 s. Načtení celkem **138–142 s**. Výkop 27–41 s. RSS 2,5 GB. Historicky E49 ~0,25 s na segment, sedí s 224 ms [2].
- Funkce světa existuje ve víc podobách (K6, K7): `lod90.h_m` (E90 × 8 / reliéf × 3; E96 × 4 / × 1), masiv E87, `p94_hora_k`, omezovač E92. E49 `hruby_teren` má navíc **jednu sopku** (kužel s kráterem ve středu dlaždice); test E90 ji vypíná [2][4][5].
- Kapitola 1 už rozhodla: terén dává jedna funkce světa (1.4), slupka 2–3 buněk s 0,25 m z funkce (1.2), útvary jsou funkce světa přes švy (1.7), sopka je součást funkce a vrstvy propíchne (1.14), podzemní voda je funkce (1.2, 1.8), ukládá se jen rozdíl proti funkci (1.4, 1.10). Dnešní pipeline tohle ještě nedělá: vzorkuje celý sloupec a celý ostrov dopředu.

**Varianty pořadí**

| | A: dnešní pipeline (šablona → švy → vzorek celého sloupce → voda → vegetace) | B: nejdřív celá funkce světa, vzorek až ve slupce (návrh podle 1.2–1.4, 1.7, 1.14) |
|---|---|---|
| povrch | šablona + dorovnání, v E96 `h_m` přes `base_hm` | funkce reliéfu (1.13) včetně sopek (1.14) |
| geologie | po segmentu, klíny na sousedy, dutina max. 1 na segment | funkce vrstev a útvarů; sopka je propíchne |
| voda a vegetace | až po vyplnění buněk celého sloupce | výchozí stav je funkce; materializace viz 2.5 a 2.6 |
| kdy vznikají buňky | vždy celý segment (64 buněk výšky při sloupci 32 m) | jen slupka 2–3 buněk v zorném poli a při odkrytí |
| čas (změřeno jen A) | 224 ms / segment 8 m, 58–61 s na blok 128 m [2] | nyní neměřeno; odhad z E90: výšky a slupka 3 km mapy ≈ 5,8 MB, stavba 4,9 s (jen výška, bez geologie a vody) [4] |

**Doporučení.** Varianta B, v tomto pořadí (všechno nejdřív jako funkce, vzorek až nakonec):

1. **Reliéf** funkce světa v metrech, včetně profilu (1.13) a sopek (1.14). Šablony povrchu a `p94_hora_k` / E92 se nepoužívají (1.4).
2. **Geologie a útvary** (1.7, 1.7.1) jako funkce téhož světa. Sopka vrstvy **propíchne** (průduch a kuželovité slupky lávy a popela, 1.14), neohýbá je.
3. **Výchozí voda** jako funkce: hladina podzemí, prameny ze seedu (1.8). Buňky vody se ještě nevytvářejí (viz 2.5).
4. **Vegetace** ze seedu jako pravidlo nad povrchem a vodou (1.12, viz 2.6).
5. **Vzorek** jen ve slupce (1.2) a **uložení jen rozdílu** proti funkci (1.4).

Minerály, žíly, kras i dutiny jsou útvary funkce světa (1.7), ne krok „po vyplnění buněk“. Validátor gen-v3 a zásobník ze serveru zůstávají kontrolou, ne zdrojem tvaru.

**Otázka pro Jana.** Souhlasíš s pořadím: reliéf a sopky ve funkci světa → geologie a útvary (sopka vrstvy propíchne) → výchozí voda jako funkce → vegetace ze seedu, a buňky se vzorkují až ve slupce? Mají minerály a dutiny zůstat součástí funkce světa (jako útvary v 1.7), nebo se mají počítat až při vzorkování slupky?

**Platí:** *rozhodnuto (2026-11-20 20:44–20:49, Jan t811u–t814u)*

- **Biomy (varianta C, kombinace):** hrubá **mapa biomů** (např. hornatina, pahorkatina, nížina, mokřad, sopečná oblast) určí oblasti světa a pro každou výběr hornin. Uvnitř oblasti **mapa hornin** rozloží konkrétní zastoupení. Výška, voda a vegetace berou biom i horninu. Biom je zároveň zdrojem parametrů členitosti (1.13) a výskytu sopek (1.14).
- **Mapa hornin** udává jen to, **kde a v jakém množství** se která hornina vyskytuje. Tvar reliéfu sama neurčuje.
- **Pořadí kroků generátoru** (vše nejdřív jako funkce, vzorek až nakonec):
  1. mapa biomů a mapa hornin (hrubé body ze seedu na maximální ploše světa, 1.7.1),
  2. reliéf a sopky ve funkci světa (parametry členitosti z biomu),
  3. geologie a útvary podle mapy hornin (sopka vrstvy propíchne, 1.14),
  4. výchozí voda jako funkce (hladina podzemí, prameny ze seedu),
  5. vegetace ze seedu jako pravidlo nad povrchem a vodou,
  6. vzorek jen ve slupce (1.2) a uložení jen rozdílu proti funkci (1.4).
- Validátor gen-v3 zůstává kontrolou, ne zdrojem tvaru.
- **Minerály, žíly, kras a dutiny** jsou útvary **ve funkci světa** (1.7), ne krok při vzorkování slupky. Dutina tak vypadá stejně, ať se k ní hráč prokope odkudkoli (Jan t815u, 20:50).


---

## 2.2 Rozhraní funkce světa a transformace vložení

**Téma.** Jak se funkce světa ptáme (bod, sloupec) a jak se do dotazu promítne vložení blueprintu (zrcadlení, otočení, posun výšky, prolnutí švů). Navazuje na návrh TerrainSource (E88).

**Současný stav**
- `geo_fn` umí dotaz v metrech: `surface_m`, `boundary_m`, `column` (povrch + hranice vrstev), `material` v bodě (X, Y, Z), `sample` do buněk. Kontext `world_fn` ale potřebuje **řídicí mřížku sousedních segmentů** (`hm_f`, `bs`). Chybí-li soused, okraj se zrcadlí. Rozteč řídicí mřížky je U = 0,5 m, šířka segmentu 8 m, výška sloupce 32 m jsou v kódu konstanty [6]. Proto E90 `geo_fn` na mapě 3 km nepoužilo [4].
- Výška světa je zvlášť v `lod90.h_m(x, y)`: vzorec E49 v metrech, nezávislý na rozlišení. Geologii, vodu ani sopku (v testu vypnutou) nezná [4].
- E88 (jen dokument, s Willage-backend neprojednáno) navrhuje čtyři objekty [7]:
  - **TerrainSource** — neměnná definice: seed světa, slot původu, recept, `block_seed`, `gen_ver`, zásobník, u výřezu hashe sousedů původu a prameny,
  - **TerrainTransform** — `rot` 0–3, `dz` v buňkách 0,5 m, `mirror` rezervované (vždy 0; zrcadlení se v E86 nezkoušelo),
  - **TerrainPlacement** — ostrov, slot, pořadí `seq`, `neighbours_before` na 4 hranách,
  - **TerrainInstance** — výsledek po napojení: hashe definice, prameny, obsazení výtoků, překryv.
- E88 měření (jeden segment 8 m bez sousedů): řídicí mřížka po deflate 8,7–35 kB, buňky 0,5 m 1,4–2,2 kB (mřížka 5–25× větší) → mřížku neukládat. Segment bez změn hráče v návrhu WTI1 ≈ 400–450 B [7].
- E86: otočení **hotových dat** je přesné (0 neshod, ~5 ms). Vygenerovat výřez znovu v otočené poloze nejde (vrstvy o 2,1–3,4 m, 18,9–24,8 % buněk jinak). Co se z funkcí počítá znovu, musí jít **inverzní transformací do souřadnic původu**. Švy vrstev přeneseného výřezu skáčou o 1,8–2,7 m (už u rot 0, klíny ze sousedů původu) [8].
- E87: masiv jako funkce přes švy, pořadí vložení 0 neshod uvnitř masivu; vedle nížiny stěna 5–6 m a pořadí změní 2 000–2 700 buněk [9].
- Kapitola 1 už rozhodla tvar vložení (1.4): seznam v pořadí nese souřadnice, zrcadlení, otočení, výškový posun, režim napojení (Auto / Blend / Keep) a **seed i verzi zdrojového světa**. Sousedé se nemění. Ukládá se jen rozdíl proti funkci (1.10). Souřadnice 16 × 16 × 64 v E88 po 1.1 a 1.3 neplatí (K1, K3).

**Varianty rozhraní**

| | A: `geo_fn` dnes (kontext segmentu a sousedů) | B: `h_m` (jen výška, E90/E96) | C: jedno dotazové API + objekty E88 (Source / Transform / Placement / Instance) |
|---|---|---|---|
| dotaz na bod / sloupec | ano, ale potřebuje mřížku sousedů | jen výška | cíl: bod → materiál, sloupec → povrch + vrstvy + hladina |
| vložení | buňky se otočí až po vzorku | není | dotaz v souřadnicích původu inverzní transformací (E86) |
| uložení | dnes celé buňky segmentu | nic (jen funkce) | jen Source + Transform + Placement + rozdíl (1.4, 1.10) |
| stav | v kódu | v kódu, bez geologie | jen návrh [7] |

**Doporučení.** Varianta C. Jedno API funkce světa: dotaz na bod `(x, y, z)` vrátí materiál a dotaz na sloupec `(x, y)` vrátí povrch, hranice vrstev a hladinu podzemí, bez nutnosti mít předem mřížku sousedů. Vložení je Transform + Placement: výpočty jdou inverzní transformací do souřadnic zdrojového světa (E86). Řídicí mřížku neukládat (E88). Zrcadlení je v 1.4 povolené, i když v E86 chybí měření — do kontraktu ho dát a změřit v 2.7. Z jedenácti otázek E88 kapitoly 1 už zodpověděly podstatu 1, 2, 5, 9 a 10 (čistá funkce, bez mřížky, voda se jako celek neukládá, zrcadlení platí, švy se napojují režimem Auto / Blend / Keep). Otevřené zůstávají hlavně 3, 4, 6, 7, 8 a 11 (prameny při nové verzi, snímek buněk pro server, rohy, eroze v překryvu, práh plného přepočtu, tvar `gen_ver`) — ty patří do kapitol 3, 5 a 6, ne sem.

**Otázka pro Jana.** Má být rozhraní funkce světa jeden dotaz na bod a na sloupec v metrech (s inverzní transformací vložení), a objekty E88 (Source, Transform, Placement, Instance) základem uložení, aniž bychom ukládali řídicí mřížku?

**Platí:** *rozhodnuto (2026-11-20 20:52–20:53, Jan t816u, t817u)*

- **Jedno rozhraní funkce světa** v metrech, jediné místo, kde se zbytek hry ptá, co kde je (generátor slupky, voda, kontrola na serveru):
  - dotaz na **bod** `(x, y, z)` vrátí materiál,
  - dotaz na **sloupec** `(x, y)` vrátí povrch, hranice vrstev a hladinu podzemí.
- Funkce nepotřebuje předem mřížku sousedů. **Řídicí mřížka se neukládá** (E88).
- Vložený blok se počítá **inverzní transformací** (zrcadlení, otočení, posun) do souřadnic zdrojového světa (E86). Otočený nebo zrcadlený blok tak dá na stejný dotaz stejnou odpověď jako originál ve světě.
- Ukládá se jen popis vložení podle E88 (Source, Transform, Placement). Zrcadlení se změří v 2.7.
- Zbylé otázky E88 (3, 4, 6, 7, 8, 11) patří do kapitol 3, 5 a 6.


---

## 2.3 Slupka a líné generování

**Téma.** Jak poznat obnažené buňky, jaký je okraj zorného pole a kdy se donačtou hlubší buňky (kopání, voda).

**Současný stav**
- Rozhodnuto v 1.2: izometrický omezený výhled; generuje a vykresluje se jen **zorné pole plus okraj**; jen to, co je **obnažené vzduchem** (u průhledné vody i dno); slupka **2–3 buněk** (parametr) s mřížkou **0,25 m z funkce**; hlubší buňky až při odkrytí; podzemní voda zůstává funkcí.
- Hra to tak dnes nedělá. Segment 8 m se vyplní **celý sloupec** najednou (`FN.sample`, výška 64 buněk = 32 m) [1][6]. E96 proto generuje všech 256 segmentů při načtení (58–61 s) [2].
- E90 (prezentace, ale slupku změřilo): „povrchová slupka = vrchní buňka + 2 pod ní“ (3 × u8 na sloupec). Mapa 3 072 m, 832 512 sloupců, výšky a slupka ≈ 5,8 MB, stavba 4,9 s. Krok hráče o 16 m: 15 kousků + 35 sousedů, 296 ms. Odhad 1 m všude: ≈ 57 s, ≈ 2,6 GB sítě (síť je prezentace) [4]. TODO to formulovalo stejně: „vzorkuje se jen povrchová slupka (viditelné buňky + 1–2 vrstvy pod nimi), zbytek až při interakci“ [10].
- E85: vzorek 0,25 m z funkcí na **celý** segment 8 m je 442–784 ms (65–108× proti zjemnění 6,0–8,1 ms) a liší se v 7,8 % buněk [11]. V 1.2 se proto varianta „0,25 m všude“ zrušila ve prospěch slupky.
- E96 návrh optimalizace načtení: nejdřív 3 × 3 segmenty u startu (~2 s), zbytek ve vlákně [2]. To je líné načítání segmentů, ne slupka uvnitř sloupce.
- Jak přesně určit „obnažené vzduchem“ a šířku okraje zorného pole v datech dnes není. E90 úroveň volilo podle **hráče**, ne podle kamery [4].

**Varianty**

| | A: celý sloupec při vložení segmentu (dnes) | B: slupka 2–3 buněk v zorném poli + okraj, zbytek při odkrytí (1.2) |
|---|---|---|
| kdy vznikají buňky 0,25 m | celý segment (E85 442–784 ms / 8 m) [11] | jen obnažený povrch a dno průhledné vody |
| hloubka | celý sloupec (32 m dnes, 128 m podle 1.3) | parametr 2–3 buněk |
| odkrytí | už je vygenerované | kopání nebo obnažení vodou donačte buňky z funkce |
| čas | 58–61 s na blok 128 m [2] | neměřeno na ostrově; E90 slupka 3 km bez geologie 4,9 s [4] |

**Doporučení.** Varianta B, jak je v 1.2. Obnažená buňka = má alespoň jednoho souseda vzduch, nebo leží na dně otevřené průhledné vody. Okraj zorného pole je parametr (pár polí kvůli pohybu). Generátor slupky volá stejné API jako 2.2. Při kopání nebo poklesu vody se z funkce donačtou nově obnažené buňky a jednou uložený rozdíl se nepřepočítává. Šířku okraje a přesný počet buněk slupky změřit v 2.7, nehádat.

**Otázka pro Jana.** Platí, že obnažená buňka je ta, která sousedí se vzduchem nebo tvoří dno průhledné vody, a že okraj zorného pole je jen parametr (pár polí), aniž bychom slupku předem vzorkovali do hloubky celého sloupce?

**Platí:** *rozhodnuto (2026-11-20 20:57–20:59, Jan t818u, t819u)*

- **Obnažená buňka** sousedí se vzduchem, nebo tvoří dno otevřené průhledné vody.
- **Viditelnou oblast určuje prezentace** podle zoomu a velikosti dlaždice (tilesetu). Datový model pevnou šířku zobrazení nezná, dostane jen obdélník světa, který je vidět.
- Generátor k oblasti přidá **okraj** (parametr v metrech nebo buňkách, ne v dlaždicích) a vzorkuje **slupku 2–3 buněk** (1.2).
- Při kopání nebo poklesu vody se nově obnažené buňky **donačtou z funkce**. Jednou uložený rozdíl se znovu nepočítá.
- **Rozlišení 0,5 m je pro data a výpočty** (poměry, objemy, voda), ne pro zobrazení. Prezentace může kreslit jinak (2D dlaždice i 3D).
- Šířku okraje a počty buněk slupky změřit v 2.7, nehádat.
- **Poznámka pro kapitolu 7 (Jan t820u–t822u, 21:03–21:08):** viditelný voxel je **0,25 m** (postava 1,75 m = 7 voxelů). **128 / 256 / 512 px** je rozlišení textury dlaždice podle kvality a monitoru (Full HD, 2K, 27"), ne velikost dlaždice na obrazovce. Kolik terénu je vidět, určuje zoom. Datový model to neomezuje. Obrázek: `obrazky/voxel-meritko.png`.
- **Výchozí zoom (Jan t823u, t824u, 21:08–21:35):** v axonometrii kolem **64 dlaždic (voxelů 0,25 m) vodorovně**, tedy asi 16 m na šířku obrazovky (~30 px na voxel u Full HD, ~40 px u 2K).


---

## 2.4 Segment jako jednotka práce a ukládání rozdílu

**Téma.** Segment je jednotka výpočtu a ukládání rozdílu proti funkci (1.1, 1.4). Jaký má být formát rozdílu a jestli nechat 8 m, nebo zkusit 16 / 32 m.

**Současný stav**
- Segment je podle 1.1 parametr, výchozí **8 m** (16 × 16 buněk 0,5 m). Kandidáti 16 a 32 m se měli doladit v 1.11, ten je přeskočený.
- Dnes je segment i jednotka vložení, receptu, seedu, rotace a formátu WVB1 (K1, v kódu „blok“) [1][12]. E96 složilo blok 128 m z 256 takových segmentů [2].
- **Překryv E78** je kanonický rozdíl proti definici: buňka 0,25 m → materiál, položka rovná definici se maže. Uložení „seřazené klíče + deflate“. Čísla: 1 buňka 8 B (deflate 40 B → nekomprimovat), 1 000 náhodných 1 792 B, chodba 15 m + šachta 124 B, chodba 70 m přes 4 segmenty 244 B, nepravidelná jeskyně 663 B. Celé pole 0,25 m je 13,4–17,4 kB deflate na 4 segmenty [7][13].
- E88 / WTI1: segment 8 m bez změn hráče ≈ 400–450 B (hlavička, hashe, prameny). WVB1 pole 0,5 m je 1,4–2,2 kB deflate [7].
- E96 k velikosti 16 / 32 m nic neměřilo pro data. Navrhlo slučovat **sítě** vegetace a terénu po 32 m — to je prezentace (kapitola 7) [2]. E90 kousky okolí hráče měly 16 m [4].
- Po 1.4 a 1.10 se neukládají vygenerované, ale nezměněné buňky. Prázdný segment je tedy jen odkaz na funkci (Source + Transform + Placement), ne pole buněk.

**Varianty velikosti segmentu**

| | 8 m (výchozí, 1.1) | 16 m | 32 m |
|---|---|---|---|
| segmentů v bloku 128 m | 256 | 64 | 16 |
| čas generování dnes (celý sloupec) | 224 ms / segment, 58–61 s na blok [2] | neměřeno | neměřeno |
| rozdíl E78 | čísla výše jsou z této velikosti [13] | neměřeno | neměřeno |
| práce ve slupce | jemná jednotka načítání | méně jednotek, větší okraj při pohybu | ještě hrubší |

**Doporučení.** Nechat výchozí **8 m** jako jednotku práce i rozdílu, protože jediné změřené velikosti překryvu i pipeline k ní patří. 16 a 32 m zůstanou parametry podle 1.1 a změří se v 2.7 (čas slupky, velikost rozdílu, voda). Formát rozdílu vzít z E78 (kanonický překryv 0,25 m, klíče + deflate) a z hlavičky WTI1 (verze, transformace, pořadí, hashe). Voda a vegetace v rozdílu jen tam, kde se liší od funkce (2.5, 2.6). Slučování sítí po 32 m nechat kapitole 7.

**Otázka pro Jana.** Necháme segment 8 m jako výchozí jednotku práce a rozdílu (formát E78 / WTI1) a 16 / 32 m jen jako parametry k měření? Nebo chceš výchozí velikost změnit už teď, bez nového měření?

**Platí:** *rozhodnuto (2026-11-20 21:08–21:35, Jan t823u, t824u)*

- **Segment 8 m** je výchozí jednotka práce i uložení rozdílu. Při výchozím zoomu (~16 m na šířku) jsou vidět asi 2 segmenty, s okrajem generátor drží zhruba 3×3 až 4×4 segmentů.
- **16 a 32 m** zůstávají parametry (1.1) a změří se v 2.7.
- **Formát rozdílu** z E78 (kanonický překryv 0,25 m, klíče + deflate), **hlavička** z WTI1 (verze, transformace, pořadí, hashe).
- Voda a vegetace v rozdílu jen tam, kde se liší od funkce (2.5, 2.6). Slučování sítí po 32 m patří do kapitoly 7.


---

## 2.5 Výchozí stav vody z funkce a její materializace

**Téma.** Kdy se z funkce vody (1.2, 1.8) stanou uložené metry krychlové v buňkách a co zůstane jen funkcí.

**Současný stav**
- Dnes je voda **odvozený stav**: po načtení se přepočítá, neukládá se. Zdrojem jsou prameny (`p76_prameny` je ukládá, bez nich se po načtení 4 z 5 pramenů přesunou), materiály a geometrie [7][14].
- Pipeline na konci nalije objem a vsákne ho gen-v3 (`infiltrate`) [1][15]. Herní ostrov pak staví vodu E68 (povrch priority-flood + D8, podzemí, bilance, události) [14].
- Prameny hledá `prameny.find` ze seedu / pravidel na už hotové výšce a materiálu: druhy sníh, kontakt, kras; na okraji ostrova se nenasazují. Ucpaný pramen neteče, po otevření teče znovu [16]. To odpovídá 1.8, až na to, že 1.8 přidává přenos vykopaného pramene jako předmětu.
- Časy: ostrov START (2 × 2 segmenty 8 m) plná voda 2,6 s. Blok 128 m v E96 **49–53 s** (prameny 0,3 / pásma 15 / povrch + podzemí 33 s), tůně **22 % plochy**, 10 pramenů [2]. E95 na 128 m s podzemím **90–228 s** do výsledku (jiná mřížka než E96, K7) [17].
- 1.2 a 1.8: podzemní voda je funkce (propustnost a hladina), materializuje se až obnažením vzduchem. Povrch je priority-flood + D8. Ukládá se v m³ na buňku, ale jen tam, kde se liší od výchozí funkce (1.4). Déšť je událost, ne trvalý stav.

**Varianty materializace**

| | A: plný výpočet vody při vložení / načtení (dnes) | B: podzemí zůstane funkcí, povrch se spočítá na ostrově při vložení | C: voda je výchozí funkce; spočítá se až když ji slupka nebo přepočet (1.9) potřebuje, ukládá se jen rozdíl |
|---|---|---|---|
| čas vložení bloku 128 m | 49–53 s až 1,5–3,8 min [2][17] | podzemí odpadá, povrch v E95 na 128 m 10–34 ms [17]; tůně a koryta celého ostrova neměřeny samostatně | neměřeno |
| determinismus | ano, když doběhne celý výpočet | ano pro povrch | ano, algoritmus musí jít spustit z funkce znovu (1.5, 1.9: lokální = plný, okno = povodí) |
| uložení | dnes nic, po načtení znova celé | prameny + stav povrchu | prameny (jako teď E76) a voda jen tam, kde se liší od výchozího výpočtu |

**Doporučení.** Varianta C. Výchozí voda je čistá funkce terénu, pramenů a parametrů (stejný algoritmus jako 1.8 / 1.9). Podzemní hladina a propustnost se neukládají. Prameny jsou nasazené ze seedu a ukládají se, protože je hráč může ucpat, vykopat a přenést (1.8). Povrchová voda (koryta, tůně) se dopočítá, až ji potřebuje slupka nebo přepočet, a to na celém povodí (1.9), ne na celém ostrově zbytečně. Uloží se jen odchylka od výchozího výpočtu. Plný výpočet při každém načtení (49–53 s a víc) tím odpadá.

**Otázka pro Jana.** Má výchozí voda zůstat funkcí a spočítat se až ve slupce nebo při přepočtu na povodí, s uložením jen pramenů a odchylek? Nebo se má povrchová voda (tůně a koryta) spočítat jednou pro celý ostrov už při vložení bloku?

**Platí:** *vyplývá z rozhodnutí 1.2, 1.4, 1.8, 1.9 (Jan t825u, 21:38)*

- Podzemní hladina a propustnost jsou **čistá funkce**, neukládají se (1.2).
- **Prameny** se nasazují ze seedu a ukládají se, protože je hráč může ucpat, vykopat a přenést (1.8).
- **Povrchová voda** (koryta, tůně) se dopočítá, až ji potřebuje slupka nebo přepočet, **na celém povodí asynchronně** (1.9). První zobrazení nového území může trvat déle. **První načtení nebo uložení bloku smí chvíli trvat, zobrazí se progressbar** (Jan t826u, 21:39).
- **Po vygenerování světa se voda ukáže rovnou v konečném (ustáleném) stavu**, nic nedotéká. Dotékání a přelévání nastává až při vložení blueprintu do ostrova nebo při kopání (Jan t828u, 21:48).
- Ukládá se **jen odchylka** od výchozího výpočtu (1.4). Plný výpočet bloku při každém načtení odpadá.


---

## 2.6 Vegetace ze seedu a změny proti ní

**Téma.** Základní porost jako opakovatelná funkce seedu a co se z něj ukládá jako rozdíl (1.12).

**Současný stav**
- `veg.generate` staví porost **až z hotového segmentu po zrcadlení a otočení**. Seed je seed segmentu, účel „VEG“, souřadnice se před hashem převádějí zpět do zdroje (`_to_src`). Záznam: `{druh, lx, ly, lz, posun, natočení, měřítko}`. Druh smí jen na materiál z `SURFACES`. Hustota je pravděpodobnost **na sloupec** podle receptu (louka, kopec, hora, písčina). Stromy jen na sudé mřížce zdroje [3].
- 1.12 rozhodlo: rostliny jsou oddělená vrstva, ukládají se **po segmentech**, otáčejí a zrcadlí se s blokem, ukládají se **jen změny** vůči seedu (vykácení, výsadba, stav růstu). Stavby a cesty jsou seznam na ostrově, do tohoto bodu nepatří.
- ⚠ Hustota na sloupec se mění s velikostí buňky, má být na m² (E94) [18]. ⚠ Recept `hora_vyzdvizena` v `veg.gd` chybí, segment je bez vegetace (E87) [9]. E96: rostliny v tůních a korytech se nevysadí; 8 640 rostlin na bloku 128 m [2].
- Vegetace není ve WVB1 ani v E88 [7][12].

**Varianty**

| | A: seznam rostlin v segmentu ze seedu (dnes se ukládá / staví celý) | B: vegetace je funkce seedu + povrchu + vody; ukládá se jen rozdíl (1.12) |
|---|---|---|
| závislost na buňce | hustota na sloupec [3] | hustota na m² ve zdrojových souřadnicích [18] |
| voda | E96 později rostliny v tůních smaže [2] | pravidlo „ne v tůni / na vhodném materiálu“ už při vyhodnocení |
| uložení | celý seznam, ve formátu chybí | jen vykácení, výsadba, stav růstu |

**Doporučení.** Varianta B, v souladu s 1.12. Základní porost je deterministická funkce (seed bloku, souřadnice původu, materiál a sklon povrchu, výchozí voda). Hustota na m², ne na sloupec. Vyhodnocuje se ve slupce, stejně jako terén. Uloží se jen rozdíl. Recepty typů krajiny (včetně masivu / sopky) musí mít pravidlo hustoty, ať se neopakuje výpadek `hora_vyzdvizena`.

**Otázka pro Jana.** Platí, že základní vegetace se z funkce seedu vyhodnotí až ve slupce (hustota na m², ne v tůni) a na disk půjdou jen změny (vykácení, výsadba, růst)?

**Platí:** *rozhodnuto (2026-11-20 21:39–21:42, Jan t827u)*

- Vegetace je **samostatná programová vrstva nad terénem** (1.12). Dá se nezávisle upravovat i **vypnout**, terén na ní nezávisí.
- Základní porost je **funkce** seedu, souřadnic původu, materiálu, sklonu povrchu a výchozí vody. Vyhodnocuje se **jen ve slupce**.
- Hustota se počítá **na m²**, ne na sloupec. V tůních se nevysazuje.
- **Každý biom má pravidlo hustoty**, aby se neopakovala holá vyzdvižená hora (`hora_vyzdvizena`).
- Ukládají se **jen změny** proti funkci (vykácení, výsadba, růst).


---

## 2.7 Testovací pipeline 3 × 3

**Téma.** Jak ověřit model: svět 3 × 3 bloky (384 × 384 m) → 9 blueprintů → ostrov s náhodným pořadím, otočením a zrcadlením (rozhodnuto v 1.4). Co měřit.

**Současný stav**
- Test z 1.4 **není postavený**. Dají se spouštět jen části.
- E49 / `svet8`: hrubý svět 8 × 8 dlaždic najednou (výška, biomy, řeka, jedna sopka), pak řezy do blueprintů s `base_hm`. To je svět studie, ne ostrov 3 × 3 bloky po 128 m [5].
- E90: mapa 24 × 24 dlaždic po 128 m = 3 072 m, **jen funkce výšky** (bez geologie, vody, vložení). Stavba slupky 4,9 s, RSS 125 → 270 MB, z toho síť ≈ 260 MB [4].
- E96: **jeden** blok 128 m z funkce, 16 × 16 segmentů 8 m v pořadí po řádcích, bez náhodného otočení a zrcadlení. Načtení 138–142 s, voda 49–53 s, výkop 27–41 s, RSS 2,5 GB, tůně 22 % plochy. Telefon odhad E93: načtení 3,7–4,5 min [2].
- Dva běhy a dva procesy: E83 / E86 / E87 hlásí bitovou shodu buněk (12/12, 14/14). Otisk vody je surový float64, shoda jen na stejné platformě [7][8][9].
- 1.4 dovoluje spustit test celé, nebo zvlášť: jen svět, nebo jen ostrov z hotových blueprintů.

**Varianty rozsahu měření**

| | A: jen funkce světa 3 × 3 (jako E90, menší mapa) | B: svět 3 × 3 → 9 blueprintů → jeden ostrov (1.4), slupka + voda + rozdíl | C: B na celém maximu 32 × 32 (4 096 m) |
|---|---|---|---|
| co ověří | spojitost funkce, čas reliéfu | vložení, transformace, švy, slupka, determinismus | maximum světa (1.4) |
| stav | E90 je 3 km, ne 384 m [4] | není postavené | není; E90 3 km je jen výška |

**Doporučení.** Varianta B jako povinný test modelu, ve třech spustitelných režimech z 1.4 (svět, ostrov z hotových blueprintů, obojí). Měřit a zapisovat do PROP:

- čas funkce světa 3 × 3, čas řezu 9 blueprintů, čas vložení ostrova (náhodné pořadí, rotace, zrcadlení, aspoň jeden blueprint s cizím seedem),
- čas a počet buněk slupky (2–3 buňky, 0,25 m) v zorném poli + okraj, čas donačtení při odkrytí,
- velikost uloženého rozdílu (prázdný ostrov vs. po výkopech),
- výchozí voda: čas na povodí, počet pramenů, podíl tůní (srovnání s 22 % v E96),
- determinismus: dva běhy, dva procesy, shoda buněk a zaokrouhlené vody,
- paměť RSS bez scény (scéna a draw calls patří do kapitoly 7),
- srovnání segmentu 8 / 16 / 32 m, pokud v 2.4 zůstanou kandidáty.

Dokud 2.1–2.6 nebudou rozhodnuté, test nestavět.

**Otázka pro Jana.** Stačí jako povinný test svět 3 × 3 bloky, řez na 9 blueprintů a složení ostrova (včetně zrcadlení a jednoho blueprintu z jiného světa), s měřením slupky, rozdílu, vody a determinismu? Maximum 4 096 m necháme až později?

**Platí:** *rozhodnuto (2026-11-20 21:48–21:50, Jan t828u, t829u)*

- Povinný test: **svět 3 × 3 bloky → řez na 9 blueprintů → ostrov** (náhodné pořadí, otočení, zrcadlení, aspoň jeden blueprint z jiného světa). Spouští se celý, jen svět, nebo jen ostrov (1.4).
- Měří se a zapisuje do PROP vše z výčtu výše (svět, řez, vložení, slupka, donačtení, rozdíl, voda, determinismus, paměť, segment 8/16/32 m).
- Ověří se i, že **vygenerovaný svět má vodu hned v ustáleném stavu** a voda se pohne až po vložení nebo kopání (2.5).
- **Maximální svět 4096 m** slouží jen pro první fáze a rozvržení (mapa biomů a hornin). Celý se nestaví ani negeneruje.
- Test se staví až po dokončení celého dokumentu.


---

## Zdroje

1. `godot-prototyp/scripts/teren/pipeline.gd` (`e96-blok128` 64dbbcd), kroky `steps_v2`.
2. PROP E96 (`e96-blok128` 64dbbcd), výsledky 2026-11-20 13:01.
3. `godot-prototyp/scripts/teren/zaklad/veg.gd` (`e96-blok128` 64dbbcd; stejné jádro v main).
4. PROP E90 a `godot-prototyp/scripts/teren/lod90.gd` (`e90-lod` a68a267).
5. `godot-prototyp/scripts/teren/svet/hruby_teren.gd` (E49, `e96-blok128` 64dbbcd).
6. `godot-prototyp/scripts/teren/geo_fn.gd` (`e96-blok128` 64dbbcd): `world_fn`, `column`, `material`, `sample`.
7. `navrhy/navrh-terrainsource-kontrakt.md` (`e88-kontrakt-navrh` 72e9ff3).
8. PROP E86 a `godot-prototyp/scripts/teren/otoceni86.gd` (`e86-otoceni-90` c458886).
9. PROP E87 (`e87-jadro-hory` ff97a9f).
10. `TODO.md`, položka „Plán vzorkování a LOD“ (`e96-blok128` 64dbbcd; stejný text na main).
11. PROP E85 (`e85-blok2-rozhodnuti` 4ac8a1d).
12. `navrhy/format-bloku-wvb1.md` (main 57c7dfb).
13. `godot-prototyp/scripts/teren/prekryv78.gd` a PROP E78 (`e78-prekryv` 77539f4; čísla převzatá i v E88 [7]).
14. `docs/sjednoceni/01-principy-a-vstupy.md` body 1.2, 1.4, 1.8, 1.9, 1.10, 1.12; PROP E68–E76 (main).
15. `godot-prototyp/scripts/teren/zaklad/gen_v3.gd`, `infiltrate` (`e96-blok128` 64dbbcd).
16. `godot-prototyp/scripts/voda/prameny.gd` (`e96-blok128` 64dbbcd).
17. PROP E95 (`e95-async-voda` 597342d).
18. PROP E94 / E94b (`e94-metry` 96f2310).
