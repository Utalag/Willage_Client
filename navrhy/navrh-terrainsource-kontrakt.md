# TerrainSource a datový kontrakt terénu (návrh E88, Willage-ideas, 2026-11-20 06:55, čeká na Jana a Willage-backend)

Jen návrh. Herní kód se nemění. Navazuje na dvě položky `TODO.md` (main 57c7dfb):

- **Přenos terénu:** „Výřez terénu jako samostatný přenositelný datový objekt: `TerrainSource` (původní definice),
  `TerrainTransform` (otočení, svislý posun), `TerrainPlacement` (místo na ostrově), `TerrainInstance` (výsledek po napojení
  na sousedy). Navázat na formát bloku WVB1 a blueprint, ve spolupráci s Willage-backend.“
- **Architektura světa:** „Datový kontrakt mezi generováním světa, geologií, vodou a změnami od hráčů. Kdo vlastní která data,
  kdo je smí měnit a jak se změny šíří. Týká se i serveru, takže ve spolupráci s Willage-backend.“ Podbody: funkce vrstev jsou
  jediný zdroj pravdy o geologii. Buňky, kolize a vykreslení jsou z nich vzorkované. Voda, eroze a události jsou odvozený stav.
  Typy změn (`SurfaceChanged`, `LayerBoundaryChanged`, `MaterialChanged`, `CavityCreated`, `CavityRemoved`,
  `HydraulicConnectivityChanged`) a resolver závislostí navazují na E68.

S Willage-backend jsem nemluvil. Všechno, co se týká serveru, je návrh k projednání.

## 1. Z čeho vycházím (změřeno, ne odhad)

| Pokus | Co platí | Důsledek pro kontrakt |
|---|---|---|
| WVB1 (`navrhy/format-bloku-wvb1.md`) | Ukládá celé pole bloku (u8 na buňku, deflate, SHA-256), `gen_ver`, `placement` (mirror, rot, shift, sides), `revision` + `parent_hash`, zásobník gen-v3 + `stack_hash`. | Hlavička, revize a zásobník zůstanou. Pole buněk nahradí definice + překryv. |
| E78 `prekryv78` | Překryv = konečný materiál buňky 0,25 m jen tam, kde se liší od definice. Kanonický (rovno definici = smazat). A = seřazené klíče + deflate jen když je menší. 1 buňka 8 B, 1000 náhodných 1 792 B, chodba 124 B, chodba 70 m 244 B na 4 bloky. Celé pole 0,25 m 13,4–17,4 kB deflate. | Ukládat překryv, ne pole. Hash = f(definice, překryv), ne f(historie). |
| E80 | Funkce platí do buňky 0,5 m, jemnější je překryv hráče. Uložení klíče + deflate je nejmenší nebo do 1,6× nejmenšího (octree / intervaly / cihly horší nebo ne o moc lepší). Nová verze funkcí: položky překryvu zůstanou platné, ale okolí chodby se změní (313 z 1 787 sousedních buněk, 32 položení skončí ve skále). | Verze generátoru musí být v kontraktu a přepočet má pravidla pro konflikty. |
| E85 | 0,25 m z funkcí (`p85_jemne`) 442–784 ms na blok (65–108× proti zjemnění). Zákaz kopání z = 0 a obvodu (`p85_okraj`). Vrstvy ≥ 25 cm (`p85_vrstvy`). `p85_voda` ukládá obsazení výtoků E74 s blokem. | Server může hlídat dno a obvod z klíče překryvu. Obsazení výtoků je uložený stav, ne odvozený. |
| E76 `place76` | Voda se nepřenáší, přepočítá se. Prameny jsou uložené zdroje (`p76_prameny`), bez nich se po načtení 4 z 5 pramenů přesunou. Lokální vložení = plný výpočet (0 neshod, bilance 0). Záznam 4 bloků + 12 výkopů 524 B (JSON). | Prameny patří do instance. Vodu neukládat. |
| E83 | Blok = f(definice, seed, sousedé položení před ním). 12/12 bitově, diagonála i vzdálený blok 0. Hashe celočíselné (SplitMix64, FNV-1a, SHA-256). Otisk vody hashuje surové float64 → shoda jen na stejné platformě. Citlivost: ±1e-3 m změní 27–35 buněk z 65 536. Port: slovníky řadit, `sort_custom` úplné pořadí, žádný float32 v h a Z. | Buňky a překryv bitově. Vodu s tolerancí nebo zaokrouhleně. |
| E86 | Otočení hotových dat je přesné (0 neshod, ~5 ms). Vygenerovat znovu otočené nejde (vrstvy 2,1–3,4 m, 18,9–24,8 % buněk jinak). Co se počítá z funkcí znovu, musí se vyhodnotit v souřadnicích původu inverzní rotací. Švy vrstev přeneseného výřezu skáčou o 1,8–2,7 m. | Transform je samostatný objekt. Výpočty výřezu jdou přes inverzní transform. |
| E87 | Masiv jako funkce ve světových metrech: na švech bez sedla, pořadí 0 neshod, 0,25 m po sousedech 0 změn. Vedle nížiny stěna 5–6 m. | Čím víc je čistá funkce světa, tím méně musí kontrakt nést kontext sousedů. |
| E85 příznaky | `p85_blok2`, `p85_jemne`, `p85_okraj`, `p85_vrstvy`, `p85_voda`; dále `p86_otoceni`, `p87_jadro_hory`, `p79_chodby`. Všechny dnes výchozí vyp. | Příznaky měnící terén musí být součást verze generátoru, ne volba klienta. |

**Nové měření E88** (`blueprint-studie/shots/e88/velikosti_e88.gd`, `velikosti.json`, jeden blok bez sousedů):
řídicí mřížka bloku = `hm_f` + 20 hranic vrstev = 5 376 hodnot.

| uložení | louka | kopec | hora | písčina |
|---|---|---|---|---|
| mřížka f64 syrově / deflate | 43 008 / 32 216 B | 43 008 / 33 000 B | 43 008 / 35 493 B | 43 008 / 30 379 B |
| mřížka f32 syrově / deflate | 21 504 / 15 650 B | 21 504 / 16 057 B | 21 504 / 17 139 B | 21 504 / 14 730 B |
| mřížka pevná čárka 1/256 U (3 B) syrově / deflate | 16 128 / 8 909 B | 16 128 / 9 272 B | 16 128 / 10 391 B | 16 128 / 8 744 B |
| buňky 0,5 m (`geo`) syrově / deflate | 16 384 / 1 414 B | 16 384 / 1 657 B | 16 384 / 2 216 B | 16 384 / 1 745 B |

Závěr: řídicí mřížka je 5–25× větší než buňky po deflate. Zaokrouhlení na 1/256 U (chyba do 1 mm) podle E83 změní desítky buněk
na blok. Mřížku tedy neukládat ani neposílat. Má se počítat znovu z definice a sousedů. Buňky 0,5 m se dají poslat jako
kontrolní snímek (1,4–2,2 kB), ale jen volitelně.

## 2. Objekty

Souřadnice: blok 16 × 16 sloupců × 64 buněk po 0,5 m (8 × 8 × 32 m). Herní mřížka 32 × 32 × 128 buněk po 0,25 m
(131 072 buněk, index 17 bitů). Strany 0 −y, 1 +x, 2 +y, 3 −x (`sides.gd`).

### 2.1 `TerrainSource` – původní definice (neměnná)

Co se dá spočítat znovu, nikdy se neukládá jako data, jen jako odkaz.

| pole | typ | poznámka |
|---|---|---|
| `source_id` | u64 | vydává server |
| `origin` | u8 | 0 = vygenerováno na ostrově, 1 = výřez z průzkumného světa |
| `world_seed` | u64 | svět, ve kterém definice vznikla (ostrov nebo průzkum) |
| `origin_slot` | i32, i32 | slot v tom světě (u ostrova = cílový slot) |
| `recipe_id`, `recipe_ver` | u16, u16 | louka / kopec / hora / písčina / hora_vyzdvizena… |
| `block_seed` | u64 | |
| `gen_ver` | u16 | verze generátoru = kód + všechny příznaky měnící terén (p85, p87, …) jako profil |
| `stack`, `stack_hash` | jako WVB1 | zásobník materiálů gen-v3 od serveru |
| `origin_neighbours` | 4 × 32 B | jen u výřezu: hash instancí sousedů v původu (strana bez souseda = 0) |
| `origin_springs` | seznam | jen u výřezu: prameny v místních souřadnicích původu (E76) |

- Zdroj se ukládá jednou. Přenesený výřez neopakuje data původu, odkazuje na ně.
- U výřezu je definice f(svět průzkumu, slot, sousedé v původu). Proto zdroj nese hash sousedů původu. Kdyby se průzkumný
  svět stavěl jen z čistých funkcí světa (směr E87), `origin_neighbours` by odpadly. To je otázka 1.

### 2.2 `TerrainTransform` – otočení a svislý posun

| pole | typ | poznámka |
|---|---|---|
| `rot` | u8 | 0–3 = 0°, 90°, 180°, 270° kolem středu bloku (E86: (x, y) → (n−1−y, x), strana d → (d + rot) mod 4) |
| `dz` | i8 | posun v buňkách 0,5 m. E76 ověřeno ±4, WVB1 počítá s ±1–4 |
| `mirror` | u8 | rezerva, vždy 0. Zrcadlení se nezkoušelo |

- Data se transformují hotová (otočení ~5 ms, 0 neshod). Co se z funkcí počítá znovu (podzemí, mřížka 0,25 m, hornina hor,
  minerály), se vyhodnocuje v souřadnicích původu inverzním transformem (`bands76` s `p86`). Bez toho by bylo 0,2–0,3 % horniny
  hor jinak a minerály a dutiny úplně jinde (E86 B).
- Skládání: rot a ∘ rot b = rot (a + b) mod 4. dz se sčítá. Kontrakt ukládá jen výsledný transform, ne historii.

### 2.3 `TerrainPlacement` – místo na ostrově

| pole | typ | poznámka |
|---|---|---|
| `island_id` | u64 | |
| `slot` | i16, i16 | |
| `seq` | u32 | pořadí položení na ostrově (rozhoduje, kdo je „soused před“) |
| `neighbours_before` | 4 × 32 B | `instance_hash` sousedů na 4 hranách v okamžiku položení (0 = volná strana) |

- Pravidlo Jana (2026-11-17): sousedé se nemění, přizpůsobí se jen nový blok. E83 ověřilo, že rozhodují jen 4 hrany.
  Rohy ne (diagonála 0 buněk). Jestli mají rohy patřit do kontraktu, je otázka 6.
- Pořadí položení mění výsledek záměrně: 1,9 % buněk u švů (E83), u masivu vedle nížiny 2 000–2 700 buněk na blok (E87).
  Proto `seq` a `neighbours_before` musí být uložené. Bez nich se instance nedá zopakovat.

### 2.4 `TerrainInstance` – výsledek po napojení

| pole | typ | vlastník | poznámka |
|---|---|---|---|
| `instance_id` | u64 | server | |
| `source_id`, `transform`, `placement` | odkazy | server | |
| `gen_ver_built` | u16 | klient | verze, se kterou je spočítaná definice |
| `def_hash` | 32 B | klient | SHA-256 buněk 0,5 m definice (bez překryvu) |
| `fine_hash` | 32 B | klient | SHA-256 definice 0,25 m (když `p85_jemne`) |
| `springs` | seznam | klient při prvním postavení, pak neměnné | E76: (lx, ly, z, q, druh), místní souřadnice instance |
| `claims` | seznam | voda (E74 `p85_voda`) | obsazení výtoků |
| `overlay` | překryv 0,25 m | hráč (přes pravidla) | E78, kanonický |
| `overlay_hash` | 32 B | klient, server přepočítá | |
| `summary`, `shortfall` | jako WVB1 | klient, server kontroluje | souhrn materiálů definice + překryvu |
| `revision`, `parent_hash` | u32, 32 B | server | jako WVB1 |
| `instance_hash` | 32 B | klient, server přepočítá | viz kap. 5 |

**Neukládá se:** řídicí mřížka (`hm_f`, `bs`), buňky 0,5 i 0,25 m, podzemní pásma, stav vody (fill, eff, to, tůně),
plán událostí. Všechno je odvozené. Volitelná je jen mezipaměť na klientu.

## 3. Kdo vlastní a kdo smí měnit

| data | zdroj pravdy | kdo smí měnit | kdy |
|---|---|---|---|
| funkce vrstev, povrch, masiv, region | generátor (`geo_fn`, `geo2`, `pipeline`) dané `gen_ver` | nikdo za běhu | jen nová verze generátoru |
| definice instance (buňky z funkcí) | generátor z Source + Transform + sousedů před | nikdo | při položení a při nové verzi |
| minerály, dutiny generátoru | generátor (RNG v metrech původu) | nikdo | jako definice |
| prameny | voda při prvním postavení, pak uložené | nikdo (jen nová verze) | E76 |
| obsazení výtoků E74 | voda | voda | uloží se s blokem (`p85_voda`) |
| překryv 0,25 m | hráč | hráč přes pravidla (`p85_okraj`) | kopání, pokládání |
| voda (povrch, podzemí, tůně, bilance) | odvozená z buněk + pramenů | nikdo neukládá | přepočet E68 |
| události (plnění tůní, příchod vody, eroze E51) | plán z ustáleného vodního stavu | plánovač | po každé změně vody (E76 `events`) |
| `seq`, `neighbours_before`, `revision` | server | server | položení, uložení |

Odvozený stav (voda, události) nikdy nemění definici ani překryv. Výjimka by byla eroze E51, která mění povrch. Ta musí jít
jako změna typu `SurfaceChanged` do překryvu se zdrojem „eroze“, ne do definice. Otázka 7.

## 4. Typy změn a resolver (mapování na E68)

Dnes systémy volají jeden druhého přímo: `ostrov_voda.edit` → `UGO.dig` → `hydro68.update`, `edit79`, `place76`.
Návrh: každá operace vydá událost, každý systém má tabulku, na co reaguje. Pořadí zůstane jako v E68: terén a geologie →
povrch ↔ podzemí do ustálení → bilance → události.

| událost | kdo ji vydá | data | reakce dnes (kód) | okno přepočtu |
|---|---|---|---|---|
| `SurfaceChanged` | kopání a pokládání (překryv), eroze | sloupce, nová výška | `ostrov_voda.edit` → `UGO.dig` → `hydro68.update(ch, margin)` | změněné sloupce + `tok_margin` 6 |
| `CavityCreated` / `CavityRemoved` | překryv (podpis dutiny sloupce se změnil) | sloupce | E79 `edit79`: přestavba pásem dotčených sloupců, `_add_drains`, `hydro68.update` (`p79_chodby`) | změněné sloupce + odtoky a vývěry |
| `MaterialChanged` | překryv bez změny dutiny a výšky | buňky | dnes nic. E85 zaručí, že změna 0,25 m nemění materiál buňky 0,5 m. Změna 0,5 m (jiná propustnost) nemá lokální cestu | návrh: sloupce, jako `CavityCreated` |
| `LayerBoundaryChanged` | jen generátor (nová verze, položení bloku) | blok | plné postavení podzemí bloku | celý blok + prstenec |
| `BlockPlaced` (nový) | položení instance | slot, transform | `place76`: sloupce bloku + prstenec švu 1 sloupec, podzemí z funkcí v souřadnicích původu, `_claim_update` | blok + 1 sloupec |
| `GeneratorVersionChanged` (nový) | server / klient při načtení | ostrov | dnes nic | celý ostrov v pořadí `seq` (kap. 7) |
| `HydraulicConnectivityChanged` | voda (výstup přepočtu) | tělesa, odtoky, prameny se změnou | E76 `prenos76.dirty` + `events` | výřez + prstenec `e51_s_len` + 1 + změněná voda + celé dotčené tůně (377–384 z 1 280 sloupců) |

- Pravidlo zpětné vazby: voda nikdy nevydá změnu terénu ve stejném kroku. Eroze se plánuje jako událost do budoucna.
  Tím zůstane smyčka E68 konečná.
- Měřeno: lokální = plný přepočet je dnes splněné jen s `p79_chodby` + `p85_voda` (E85). Bez nich výchozí lokální voda závisí
  na pořadí (E83). Resolver tedy předpokládá zapnuté oba příznaky.
- Cena: drobné změny 46–206 ms lokálně proti ~2 s plně. Chodba s `p85_blok2` je lokálně pomalejší než plně (12,6 s proti
  1,6 s, E85). Resolver by měl mít práh: velká změna → rovnou plný přepočet. Hranici neznám, otázka 8.

## 5. Hashe

| hash | přes co | přesnost |
|---|---|---|
| `def_hash` | buňky 0,5 m definice (u8, pořadí `(x*16+y)*64+z`) | bitově. E83 2 běhy, 2 procesy |
| `fine_hash` | buňky 0,25 m definice | bitově |
| `overlay_hash` | kanonické bajty překryvu (seřazené klíče, nekomprimované) | bitově. Nezávisí na kompresi ani na pořadí operací na různých buňkách |
| `instance_hash` | SHA-256(`source_id`, `transform`, `slot`, `seq`, `neighbours_before`, `gen_ver_built`, `def_hash`, `fine_hash`, `springs`, `claims`, `overlay_hash`) | bitově |
| `water_print` | voda (fill, eff, to, extra, src2, výstupy) | **ne bitově mezi platformami**. Návrh: zaokrouhlit (fill 1/4096 buňky jako WVB1 u16, průtoky 1e-6 l/s) a porovnávat s tolerancí. Do `instance_hash` nepatří |

- Bitová shoda buněk mezi platformami platí jen tehdy, když port počítá h a Z stejně (f64, `a + (b − a)·t`, žádný float32,
  bez FMA). Šum FastNoiseLite je float32, na ARM může FMA změnit poslední bity. Dopad jsem změřil jen nepřímo: posun 1e-6 m
  změní nejvýš 1 buňku mimo přesné remízy (E83). Telefon ani .NET nemám změřené.
- Dnešní `hydro68.otisk` formátuje `%.12f` a hashuje surové bity. Pro server nevhodné.

## 6. Binární rozvržení (návrh WTI1 – instance terénu)

Little-endian, SHA-256, deflate (raw) jako WVB1. Velikosti jsou z měření (E78, E76, E88), hlavička je spočítaná z polí.

```
WTI1 hlavička                              273 B
  magic "WTI1", format_ver u8, flags u8
  instance_id u64, source_id u64, gen_ver_built u16, sim_ver u16
  transform: rot u8, dz i8, mirror u8
  placement: island_id u64, slot i16 i16, seq u32, neighbours_before 4 × 32 B
  revision u32, parent_hash 32 B
  def_hash 32 B, fine_hash 32 B (0 když chybí)
summary  u16 n + n × (u16 mat, u32 count)        ~ 6 B na materiál
shortfall u16 n + n × (u16 mat, u32 count)
springs  u8 n + n × (u8 lx, u8 ly, u16 z_q8, u32 q_mls, u8 druh)  9 B na pramen
claims   u16 n + n × (u32 výtok, u32 cíl)          8 B na obsazení (tvar zatím návrh)
overlay  u8 kódování (0 syrově, 1 deflate) + u32 délka + data
         data = u32 počet + n × (varint delta klíče, u8 materiál)   (E78 A)
instance_hash 32 B
```

| obsah (na 4 bloky, E78) | překryv |
|---|---|
| 1 buňka | 8 B syrově (deflate 40 B → nekomprimovat) |
| 100 buněk | 304 / 255 B |
| 1 000 náhodných | 2 779 / 1 792 B |
| chodba 15 m + šachta | 4 421 / 124 B |
| chodba 70 m přes 4 bloky | 18 831 / 244 B |
| nepravidelná jeskyně (E80) | 663 B deflate |

- Blok bez změn hráče: hlavička 273 B + `instance_hash` 32 B + souhrn (~12 materiálů × 6 B) + prameny ≈ 400–450 B. Pro srovnání: WVB1 pole 0,5 m je 1,4–2,2 kB deflate,
  0,25 m 13,4–17,4 kB na 4 bloky. Řídicí mřížka by byla 8,7–35 kB.
- Volitelná sekce `cells_snapshot` (flags bit): buňky 0,5 m po deflate (1,4–2,2 kB). Slouží pro server, který generátor nemá,
  a pro ladění. Otázka 4.
- `TerrainSource` je samostatný záznam (~75 B + zásobník + u výřezu 4 × 32 B a prameny původu), jednou na zdroj.

## 7. Verze (Jan rozhodl: nová verze generátoru přepočítá i staré bloky, překryv musí přežít)

Postup při `GeneratorVersionChanged`:

1. Bloky ostrova se postaví znovu v pořadí `seq`, každý jen se sousedy, kteří mají menší `seq` (pravidlo sousedů platí i po
   přepočtu). Výřezy ze svých `TerrainSource` v souřadnicích původu, pak transform.
2. Na novou definici se položí překryv beze změny klíčů. Klíče jsou v souřadnicích instance (po transformu), takže přežijí.
3. Kanonizace: položky rovné nové definici se smažou.
4. Konflikty se nahlásí, ne opraví potichu. E80 změřilo, že se mění okolí výkopu (313 z 1 787 sousedních buněk) a že položené
   buňky mohou skončit uvnitř skály (32). Návrh: položka „vzduch“ zůstane vždy (hráč vykopal), položka „materiál“ zůstane taky.
   Rozdíl uvidí hráč jako jinou skálu kolem chodby.
5. Voda se plně přepočítá. Prameny: buď zůstanou uložené (mohou skončit ve vzduchu nebo pod skálou), nebo se najdou znovu
   (posunou se jako bez `p76`, 4 z 5). Otázka 3.
6. Nové `def_hash`, `instance_hash`, `revision + 1`, `parent_hash` = stará instance.

Odhad ceny pro ostrov 16 bloků (z měření na blok, ne změřené celé): generování 0,2–0,4 s + 0,25 m z funkcí 0,44–0,78 s
na blok ≈ 10–19 s, plus plný přepočet vody ~2–3 s (4 bloky; 16 bloků neměřeno).

`gen_ver` zahrnuje i příznaky. Zapnutí `p87_jadro_hory` nebo `p85_vrstvy` je tedy nová verze a spustí přepočet.

## 8. Co server ověřuje

Server generátor nemá (WVB1, dohoda 18:35). Ověřuje tedy strukturu, pravidla a zachování materiálu, ne geometrii.

1. Hlavička: verze, délky, `overlay_hash` a `instance_hash` přepočítá sám.
2. `source_id` vydal on. `stack_hash` = vydaný zásobník.
3. Transform: `rot` 0–3, `dz` v mezích, `mirror` 0.
4. Placement: slot volný a sousedí s ostrovem, `seq` = další v pořadí, `neighbours_before` = aktuální `instance_hash` sousedů
   v jeho databázi.
5. Překryv: klíče < 131 072, seřazené, bez duplicit, materiály povolené. Zákaz dna a obvodu (`p85_okraj`) se dá ověřit z klíče
   (z = 0) a ze slotu (strana bez souseda), bez generátoru.
6. Souhrn: další revize = předchozí souhrn − vykopané + položené (WVB1 bod 4). K tomu musí server znát materiál, který byl
   v buňce před změnou. Návrh: na drátě položka překryvu nese i původní materiál definice (+1 B). Server pak počítá přesně,
   ale musí věřit první revizi. Otázka 4.
7. Voda: jen horní meze (WVB1). Žádné hashe vody.
8. Revize: `parent_hash` = poslední uložená, jinak konflikt (optimistická zámka).

## 9. Rizika a negativa

- Definice se nedá ověřit bez portu generátoru. Klient může poslat jiné buňky. Server vidí jen souhrn a hashe.
- Přenesený výřez nese klíny vrstev ze sousedů původu. Na švech ostrova skáčou vrstvy o 1,8–2,7 m (E86). Kontrakt to neřeší.
- Masiv vedle nížiny dělá stěnu 5–6 m (E87). Pokud se to opraví ve funkci, je to nová `gen_ver` a přepočet všech ostrovů.
- Překryv 0,25 m nemá historii. Vykopat → zasypat a zasypat → vykopat dávají různý výsledek záměrně (E78). Pro audit
  podvodů by server potřeboval log operací, ne jen konečný stav.
- `p85_jemne` je 65–108× pomalejší. Přepočet celého ostrova při nové verzi trvá podle odhadu desítky sekund.
- Bitová shoda mezi x86 a ARM / .NET není změřená, jen audit.
- `veg.gd` nezná typ `hora_vyzdvizena` (chyba `DENSITY`, nález E87). Blok se postaví bez vegetace. Vegetace v kontraktu není.

## 10. Otázky pro Jana

1. Průzkumný svět: stavět ho jen z čistých funkcí světa (jako masiv E87), aby `TerrainSource` výřezu byl jen (svět, slot)?
   Nebo nést hash sousedů původu?
2. Má `TerrainInstance` ukládat řídicí mřížku (8,7–35 kB), nebo jen hashe a vše počítat znovu (návrh)?
3. Při nové verzi generátoru: prameny ponechat uložené, nebo najít znovu?
4. Má klient posílat serveru snímek buněk 0,5 m (1,4–2,2 kB), aby server znal definici? A položky překryvu s původním
   materiálem pro přesný souhrn?
5. Otisk vody: zaokrouhlit (1/4096 buňky, 1e-6 l/s) a porovnávat s tolerancí, nebo vodu serveru neposílat vůbec?
6. Rohoví sousedé v `neighbours_before`: jen 4 hrany (dnes), nebo i rohy?
7. Eroze E51 mění povrch: zapisovat ji do překryvu jako hráčské změny (se zdrojem „eroze“)?
8. Práh, kdy resolver místo lokálního přepočtu udělá plný (chodby s `p85_blok2` jsou lokálně pomalejší)?
9. Zrcadlení výřezu: rezervovat a nepovolit, nebo zahodit z WVB1?
10. Švy vrstev přeneseného výřezu (1,8–2,7 m): klín v pásu u švu při položení (mění instanci, ne zdroj)?
11. Má být `gen_ver` jedno číslo pro celý klient, nebo profil příznaků, ze kterého server pozná, co se změnilo?
