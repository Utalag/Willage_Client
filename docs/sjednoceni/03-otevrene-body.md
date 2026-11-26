# 03 – Otevřené body po kapitolách 1 a 2 (kostra k rozhodnutí)

Stav: **kostra**, 2026-11-20 21:55 SEČ. Kapitoly 1 a 2 jsou rozhodnuté (`01-principy-a-vstupy.md`, `02-model-sveta-a-generovani.md`, tip `7c6bb1f`). Tento soubor bere původně plánované kapitoly 3–8 z osnovy a nechává **jen body, které 1 a 2 ještě nerozhodly**. Pole **Platí:** je prázdné, vyplní se až po Janově rozhodnutí v chatu (t712u).

Pořadí bodů níže je podle důležitosti (nejdřív datový kontrakt a zbylá data, pak voda, prezentace, sloučení). V každé kapitole je nejdřív seznam **Už vyřešeno v kap. 1–2**, potom jen otevřené body. Úkoly, které už pravidlo mají a zbývá je napsat do kódu, jsou na konci v **Úkoly implementace (ne rozhodnutí)**.

Odložené z kapitoly 1, teď se znovu neptám: **přepočet při nové verzi generátoru** (1.5, t726u) a s ním otázka E88 č. 3 (prameny po nové verzi nechat, nebo najít znovu) [1][2]. Datový rozpočet výkonu (1.11) Jan přeskočil (t738u).

Značení: [n] = zdroj na konci. K1–K12 = konflikty z `00-mapa-vetvi.md`. Časy v SEČ, měření z boxu.

---

## Pořadí otevřených bodů

1. **6.1** Co server ověřuje a zda posílat snímek buněk (E88 č. 4) — společně s Willage-backend.
2. **6.3** Serverová kontrola a mazání ověřených dat (Jan, hovor 20. 11. 2026).
3. **6.2** Tvar verze generátoru `gen_ver` (E88 č. 11).
4. **4.1** Zapisovat erozi E51 do překryvu (E88 č. 7).
5. **5.1** Rohoví sousedé v kontraktu (E88 č. 6).
6. **5.2** Výchozí režim napojení švů (Auto / Blend / Keep) u přeneseného výřezu.
7. **3.2** Slučovat drobné výstupy v dosahu 8 m i mezi sebou?
8. **7.1** Pohled 2D (dlaždice), nebo 3D (modely)?
9. **7.2** LOD prezentační vrstvy.
10. **7.3** Průhlednost a řez v izometrii (E91).
11. **Klima** Konkrétní hodnoty klimatických presetů (násobitele, posuny, podíly reliéfních biomů, voda) mimo výchozí identitu mírného klimatu.

---

## 3. Voda (bývalá kapitola 3)

Původní plán: jeden algoritmus podzemí, oprava lokálního přepočtu, vlákno.

**Už vyřešeno v kap. 1–2**

- Práh pro plný přepočet vody (dřívější bod 3.1, E88 č. 8) je vyřešený v 1.9: voda se počítá asynchronně v pozadí s debouncem, lokální přepočet dává stejný výsledek jako plný a počítá se sjednocené povodí. Bod zrušen (Jan, hovor 20. 11. 2026).
- Výchozí podzemí E67 (`pretok`) → 1.8.
- Lokální přepočet = plný výpočet; okno je celé zasažené povodí; běží asynchronně na pozadí; prodleva 2 s, strop 10 s; fronta dalších výkopů; scénář „dva hráči“ → 1.9.
- Výchozí voda je funkce, po vygenerování světa v ustáleném stavu; prameny se ukládají; na ostrově se počítá na povodí; ukládá se jen odchylka → 1.2, 1.8, 2.5.
- Vsakování: tok = X × spád včetně výšky vody, mezi materiály minimum, čas 1 den = 1 h → 1.8.1.
- Eroze E51: práh `ero_v`, odnos průtok × (v/práh)^k, výchozí k = 1,5 → 1.8.2.
- Artéská voda jako funkce, materializace až po obnažení („jen pokud to model zvládne“) → 1.8.1.
- Otisk vody a uložení: voda v buňce je celé číslo litrů (1 B), ne surový float64 → 1.10 (E88 č. 5).
- Neobsazený pramen zvedá hladinu tělesa, obsazování je zapnuté, pramen se kreslí, dokud ho hráč nevykope, nenapojí nebo nezachytí → 1.8 (2026-11-20 01:49).

Oprava K5 (lokální ≠ plný v pěti větvích) a zrychlení podzemí jsou implementace rozhodnutého 1.9, ne nové rozhodnutí.

### 3.2 Slučování drobných výstupů mezi sebou

**Téma.** E72 slučuje drobné výstupy pod prahem k silnému výstupu do 8 m. Otevřené zůstalo, jestli se mají slučovat i **mezi sebou**, když silný v dosahu není [4][8].

**Současný stav**
- *rozhodnuto v E72:* práh `p67_prune_min` 0,1 l/s, dosah `p72_dosah_m` 8 m, `p72_prusak` zapnutý. Ostrov E67: 150 → 6 výstupů, součet 4,10 l/s beze změny. Po limitu 8 m je výstupů 6 → 18, protože 12 drobných po 0,02 l/s leží v řadě na okraji dál než 8 m od silného [8].
- 1.8.1 bere 8 m jako vzdálenost slučování drobných výtoků / pramenů, ne jako dosah průsaku. Slučování **mezi sebou** (do největšího ze skupiny) Jan ještě nerozhodl [4].

**Varianty**

| | A: jen k silnému v dosahu 8 m (dnes) | B: i mezi sebou do největšího ze skupiny, když silný není blízko |
|---|---|---|
| okraj ostrova (12 × 0,02 l/s) [8] | 12 samostatných výstupů | jedna skupina, součet stejný |

**Doporučení.** Varianta B: drobné výstupy v dosahu 8 m se sloučí do největšího ze skupiny i bez silného souseda. Součet průtoku zůstane, kreslení bude čistší. Dosah 8 m a práh 0,1 l/s se nemění.

**Otázka pro Jana.** Slučovat drobné výstupy v dosahu 8 m i mezi sebou do největšího ze skupiny, když silný výstup není blízko?

**Platí:** (Jan, hovor 20. 11. 2026) Práh je 0,1 l/s; jde o výchozí hodnotu volitelného parametru, který se dá ve hře měnit. Výtoky pod tímto prahem se slučují s jiným výtokem v dosahu 8 m, a to i mezi sebou, když poblíž není silný výstup.

---

## 4. Kopání a překryv (bývalá kapitola 4)

Původní plán: kopání a překryv 0,25 m, zákaz dna a okraje, ukládání.

**Už vyřešeno v kap. 1–2**

- Jemná mřížka 0,25 m z funkce jen ve slupce 2–3 buněk, hlubší buňky při odkrytí → 1.2, 2.3.
- Zákaz prokopání dna a okraje ostrova (`p85_okraj`) → 1.13.1, 1.10.
- Bok ostrova jen prezentace (5 m pod nejnižší okrajovou buňkou, oblaka, voda padá do oblak) → 1.13.1.
- Ukládá se jen rozdíl proti funkci, formát překryvu E78 (kanonické klíče + deflate), hlavička WTI1, segment 8 m → 1.4, 1.10, 2.4.
- Obnažená buňka sousedí se vzduchem nebo tvoří dno průhledné vody; donačtení z funkce, jednou uložený rozdíl se nepřepočítává → 2.3.

Hra dnes pořád kope po 0,5 m a vyplňuje celý sloupec — to je úkol implementace, ne rozhodnutí.

### 4.1 Eroze E51 do překryvu

**Téma.** Eroze mění povrch. Má se zapisovat do překryvu jako změna proti funkci, nebo do definice? (E88 otázka 7) [2].

**Současný stav**
- Překryv E78 nese konečný materiál buňky 0,25 m, kde se liší od definice. Zdroj pravdy o kopání je hráč. Voda a události definici ani překryv nemění, **výjimkou by byla eroze E51** [2][9].
- 1.8.2: eroze bere materiál nad prahem `ero_v`, odnos průtok × (v/práh)^1,5, čas jako události. Kras E75 se rozpouští podle průtoku.
- 1.4 a 2.4: ukládá se jen rozdíl proti funkci. Kdyby eroze měnila definici, ostrov by přestal být zopakovatelný ze seedu a seznamu vložení.
- Návrh E88: eroze jde jako událost `SurfaceChanged` do překryvu se zdrojem „eroze“, ne do definice. Voda v tom samém kroku změnu terénu nevydá, eroze se plánuje do budoucna (smyčka E68 zůstane konečná) [2].

**Varianty**

| | A: eroze mění definici / buňky napřímo (hrozí dnes) | B: eroze se zapíše do překryvu se zdrojem „eroze“ (návrh E88) |
|---|---|---|
| opakovatelnost ostrova | ne, funkce už nesedí | ano, rozdíl proti funkci |
| shoda s 1.4 / 2.4 | rozbíjí to | sedí |

**Doporučení.** ~~Varianta B. Eroze E51 (a rozpouštění krasu E75, které bere horninu) se zapisuje do stejného překryvu jako kopání, se zdrojem „eroze“.~~ ⚠ překonáno: eroze i kras během hry jdou vrstvou offsetu, ne překryvem buněk (viz Platí).

**Otázka pro Jana.** ~~Má se eroze E51 (a úbytek horniny krasem) zapisovat do překryvu jako změna proti funkci, se zdrojem „eroze“, a ne do definice terénu?~~ ⚠ překonáno, viz Platí.

**Platí:** (Jan, hovor 20. 11. 2026) Eroze se **neukládá** jako změněné buňky. Původní generátor terénu zůstává nedotčený a eroze je samostatná vrstva offsetu (posunu výšky), která se přičítá k výšce z původní funkce. Vzniká tak v podstatě druhá funkce s upraveným vstupem. Výpočet vody běží na výsledném terénu s offsetem. Výhody: minimální objem dat, erozi lze kdykoli vypnout nebo předělat bez zásahu do generátoru a voda se v prohlubních chová správně.
- **Doplněno (Jan 2026-11-21 00:24):** posun eroze **smí být kladný**. Terén může i růst (usazování, náplavy, delty), nejen ubývat.
- **Doplněno (Jan 2026-11-21 00:24):** kras během hry se ukládá **stejnou cestou offsetu**, ne jako změna materiálu na vzduch v překryvu buněk. Jan: „Zkusíme jít cestou offsetu.“ V kroku 7 se ověří, jestli offset stačí i pro podzemní dutiny.

---

## 5. Přenos výřezu (bývalá kapitola 5)

Původní plán: otočení, švy vrstev, prameny.

**Už vyřešeno v kap. 1–2**

- Vložení nese zrcadlení, otočení, výškový posun, režim napojení (Auto / Blend / Keep), seed a verzi zdrojového světa; sousedé se nemění → 1.4.
- Výpočty jdou inverzní transformací do souřadnic původu; zrcadlení je povolené a změří se v testu 2.7 → 2.2, E86 [10].
- Švy na ostrově: vrstvy se zaklíní nebo napojí na úseku 1/16 bloku (8 m při bloku 128 m) → 1.7.1 (E88 č. 10).
- Prameny výřezu se přenášejí uložené (`p76_prameny`); hráč je může ucpat, vykopat a položit jinde → 1.8, 2.5, E76 [11].
- Řídicí mřížka se neukládá; čistá funkce světa, bez hashe sousedů původu jako zdroje tvaru → 2.2 (E88 č. 1, 2, 9).

Otočení hotových dat je změřené (0 neshod, ~5 ms). Skok vrstev 1,8–2,7 m u přeneseného výřezu se řeší režimem napojení z 1.7.1, ne novým principem [10]. Zbývá vybrat **výchozí režim** a jestli do kontraktu patří i rohy.

### 5.1 Rohoví sousedé v kontraktu

**Téma.** `neighbours_before` dnes nese jen 4 hrany. Mají do kontraktu patřit i rohy? (E88 otázka 6) [2].

**Současný stav**
- Pravidlo z 2026-11-17: sousedé se nemění, přizpůsobí se jen nový blok. E83: blok závisí jen na sousedech položených před ním na **4 hranách**. Diagonála (roh) a vzdálený blok mění **0 buněk**. 12/12 bitově, dva procesy stejně [12].
- Pořadí vložení mění výsledek záměrně (~1,9 % buněk u švů; u masivu vedle nížiny 2 000–2 700 buněk) — proto se `seq` a `neighbours_before` ukládají [2][12][13].

**Varianty**

| | A: jen 4 hrany (dnes, E83) | B: 4 hrany + 4 rohy |
|---|---|---|
| vliv na buňky | roh mění 0 buněk [12] | kontrakt větší, výsledek stejný |
| opakovatelnost | stačí 4 hrany + `seq` | stejná |

**Doporučení.** Varianta A: v kontraktu zůstanou jen 4 hrany. Rohy do `neighbours_before` nedávat, E83 ukázalo, že výsledek nemění.

**Otázka pro Jana.** Stačí v uloženém vložení jen 4 hranoví sousedé (jak je to dnes a jak změřilo E83), nebo mají do kontraktu patřit i rohy?

**Platí:** (Jan, hovor 20. 11. 2026) **Zavrženo.** Rohoví sousedé se neřeší. Bloky se napojují vždy jen po stranách (v osách), nikdy diagonálně přes roh.

---

### 5.2 Výchozí režim napojení švů

**Téma.** 1.4 zavádí režimy Auto / Blend / Keep, 1.7.1 určuje klín na 1/16 bloku. Není rozhodnuté, který režim je výchozí, když hráč vloží otočený nebo cizí blueprint (šev vrstev v E86 skáče o 1,8–2,7 m) [10].

**Současný stav**
- Přenesený výřez nese klíny ze sousedů **původu**, ne z nových sousedů na ostrově. Bloky vygenerované na místě mají šev vrstev 0 U. U výřezu (i rot 0) je skok 1,8–2,7 m proti kroku uvnitř 0,7–1,15 m [10].
- 1.7.1: pořadí vrstev na švu ostrova se nemusí shodovat; vrstvy se zaklíní nebo napojí na úseku 1/16 bloku.
- Keep by skok nechal být. Blend by ho vzal klínem z 1.7.1. Auto je v prototypu definované (`block_gen.gd`: rozdíl ≤ 6 buněk dorovná rampou na 3 buňkách, větší nechá jako útes, po sloupcích).

**Varianty**

| | Keep | Blend (klín 1/16 bloku, 1.7.1) | Auto |
|---|---|---|---|
| šev výřezu 1,8–2,7 m [10] | ostane skok | zaklíní se na 8 m | podle pravidla (návrh: Blend, když by skok přesáhl 1 buňku, jinak Keep) |

**Doporučení.** ~~Výchozí **Blend**: klín nebo napojení na 1/16 bloku podle 1.7.1. Keep jen když ho hráč u daného vložení výslovně zvolí. Auto zatím nezavádět, dokud ho nebude potřeba jako zkratku.~~ ⚠ překonáno: výchozí je Auto; Blend má dvě nezávislá nastavení (povrch 1–4 buňky, vrstvy klín 1/16 bloku), viz Platí (2026-11-21 00:24).

**Otázka pro Jana.** Má být výchozí napojení švu při vložení blueprintu Blend (klín na 1/16 bloku podle 1.7.1) a Keep jen na výslovnou volbu?

**Platí:** (Jan, hovor 20. 11. 2026) Výchozí režim je **Auto**. Auto se rozhoduje podle rozdílu výšek v každém sloupci zvlášť: rozdíl do 6 buněk vyhladí rampou na 3 buňkách, větší rozdíl nechá jako útes. Blend a Keep zůstávají jako volitelné alternativy. Počty 6 a 3 buněk pocházejí z prototypu s buňkou 0,5 m (3 m a 1,5 m). Po sjednocení buňky na 0,25 m se zachovávají vzdálenosti v metrech (Jan 2026-11-21 00:35): rozdíl do 3 m (12 buněk) vyhladí rampou na 1,5 m (6 buněk), větší rozdíl zůstane útesem.
- **Doplněno (Jan 2026-11-21 00:24):** Blend má **dvě nezávislá nastavení**. Napojení povrchu je rampa na 1–4 buňkách. Napojení podzemních vrstev je klín, výchozí 1/16 bloku (1.7.1).

---

## 6. Kontrakt se serverem (bývalá kapitola 6)

Původní plán: kontrakt WTI1, společně s Willage-backend.

**Už vyřešeno v kap. 1–2**

- Klient generuje a simuluje, server ukládá, načítá a validuje → 1.10.
- Server ukládá a posílá seed, parametry, verzi generátoru, seznam vložení a rozdíl proti funkci (ne hotová pole segmentů). WVB1 je balík změn segmentu. Kontrola generátorem jde vypnout → 1.10 (t801u–t803u); kdy kontrola běží (zásobník, ne namátkově) → 6.3.
- Voda v buňce: krok 1/16 l, hodnota 0–250 = 0–15,625 l, 1 B, 251–255 rezerva (Jan 2026-11-21 00:39; záloha 2 B). Determinismus povinný, změny i vložení nesou verzi → 1.5, 1.10 (sjednoceno s buňkou 0,25 m, Jan 2026-11-21 00:19).
- Objekty Source / Transform / Placement, bez řídicí mřížky, zrcadlení platí → 2.2.
- Výška sloupce a velikost segmentu jsou parametry (32/64/128 m a 8/16/32 m), ne natvrdo 16 × 16 × 64 → 1.1, 1.3, 1.10.

Návrh E88 s Willage-backend **ještě nebyl projednán** [2]. Body 6.1 a 6.2 jsou návrh k tomu jednání, ne konečné pravidlo bez backendu. Spolu s nimi se k backendu vezme už rozhodnutý základ z 1.10 a 2.2. Otázka E88 č. 3 zůstává odložená s 1.5.

### 6.1 Co server ověřuje a snímek buněk

**Téma.** Má klient posílat serveru snímek buněk 0,5 m (tehdejší datová buňka; po 2026-11-21 00:19 je buňka 0,25 m, viz 1.1) a v položce překryvu i původní materiál definice, aby server spočítal souhrn přesně? (E88 otázka 4) [2].

**Současný stav**
- 1.10: při zapnuté kontrole server občas znovu vygeneruje segment ze seedu + změn a porovná hash. Při vypnuté kontrole jen ukládá a kontroluje **bilanci materiálu**.
- E88: bez portu generátoru server nevidí geometrii, jen souhrn a hashe. Návrh volitelné sekce `cells_snapshot` (buňky 0,5 m po deflate, 1,4–2,2 kB na segment 8 m, měřeno při buňce 0,5 m) a +1 B původního materiálu v položce překryvu [2].
- Překryv E78 jinak nese jen nový materiál. Souhrn „co ubylo / přibylo“ server z rozdílu bez původního materiálu nebo bez generátoru přesně nesloží [2][9].

**Varianty**

| | A: jen hash a bilance; snímek ne (generátor jen při zapnuté kontrole) | B: A + původní materiál v položce překryvu (+1 B) | C: B + povinný snímek buněk 0,5 m (1,4–2,2 kB, měřeno při buňce 0,5 m) |
|---|---|---|---|
| server bez generátoru | hrubá bilance | přesný souhrn změn | přesný souhrn i náhled buněk |
| velikost | jako E78 [9] | +1 B na položku | +1,4–2,2 kB vždy [2] |

**Doporučení.** Varianta B jako základ pro jednání s Willage-backend: položka překryvu nese i původní materiál definice, aby šla bilance spočítat bez generátoru. Snímek buněk 0,5 m nechat **volitelný** (ladění a servery bez portu generátoru), ne povinný na každém uložení. Namátková kontrola z 1.10 se nemění. Po 2026-11-21 00:19 by volitelný snímek nesl buňky 0,25 m; číslo 1,4–2,2 kB je měření při 0,5 m.

**Otázka pro Jana.** Má položka překryvu nést i původní materiál definice (kvůli bilanci na serveru) a snímek buněk zůstat jen volitelný? (V otázce stálo „snímek buněk 0,5 m“; po 2026-11-21 00:19 je datová buňka 0,25 m.) Tento bod se má projednat s Willage-backend.

**Platí:** (Jan 2026-11-21 00:10, po vyjádření Willage-backend) Ostrov = seed + parametry + verze generátoru (`Vmajor.minor`) + seznam vložení + rozdíl proti funkci. Položka překryvu nese i původní materiál buňky (+1 B) a umí i odchylku vody. Snímek buněk je jen volitelný (ladění) a nikdy není zdroj pravdy. Formát balíku změn je verzovaný a nesmí se plést se starým WVB1 jako celým polem buněk (WVB1 v2 nebo WTI1, hlavička podle 1.1 a 1.3). Kontrola generátorem jde vypnout. Kontrola se provádí vždy proti pinované verzi ostrova, nikdy proti novějšímu generátoru.

---

### 6.2 Tvar verze generátoru

**Téma.** Je `gen_ver` jedno číslo pro celý klient, nebo profil příznaků, ze kterého server pozná, co se změnilo? (E88 otázka 11) [2].

**Současný stav**
- 1.5: uložené změny i každé vložení nesou verzi generátoru. Jak přepočítat svět při nové verzi, je odložené. Determinismus je povinný.
- E88: každý přepínač terénu (`p85`, `p87`, …) je nová verze. `gen_ver` je v návrhu u16. Bez profilu server nepozná, jestli šlo o opravu švu, nebo o jinou funkci hor [2].
- K4: dřívější rozhodnutí „nová verze přepočítá i staré bloky“ (03:26) proti E80 (přepočet rozbije okolí výkopů: 313 z 1 787 buněk, 32 položení ve skále) je právě to, co 1.5 odložilo [12][14]. Tvar pole `gen_ver` tím ale není zodpovězený.

**Varianty**

| | A: jedno číslo u16 (návrh E88) | B: číslo + uložený profil příznaků / parametrů, které verze mění |
|---|---|---|
| místo v hlavičce | 2 B | číslo + krátký odkaz / seznam |
| server pozná, co se změnilo | ne, jen „je jiná“ | ano |
| přepočet (až se 1.5 otevře) | vše, nebo nic | lze cílit jen dotčené části |

**Doporučení.** Varianta B: v datech zůstane jedno číslo `gen_ver`, ale každá verze má dokumentovaný profil (které parametry a pravidla mění). Server i klient podle čísla profil najdou. Samotný přepočet starých ostrovů se teď neotevírá (1.5).

**Otázka pro Jana.** Má `gen_ver` zůstat jedno číslo, ke kterému patří dokumentovaný profil změn (aby server poznal, co je jiné), aniž bychom teď rozhodovali o přepočtu starých ostrovů?

**Platí:** (Jan, hovor 20. 11. 2026) Verze generátoru se zapisuje ve tvaru `Vmajor.minor`: velké V, číslo před tečkou je hlavní verze (zásadní, nekompatibilní změna), číslo za tečkou je minoritní verze (drobná změna) a přičítá se postupně. Číslo zůstává jednoduché na uložení a porovnání. Význam změny (nekompatibilní, nebo drobná) se nese v metadatech verze nebo v poznámce ke commitu. Přepočet starých ostrovů zůstává odložený (1.5).

---

### 6.3 Serverová kontrola a mazání ověřených dat

**Téma.** Jak dlouho server drží původní hodnoty změněných buněk a co s nimi udělá po kontrole (navrhl Jan v hovoru 20. 11. 2026).

**Návrh Jana**
- Server je jediný zdroj pravdy.
- Klient ke každé změněné buňce pošle i její původní hodnotu: 1 B materiálu na změněnou buňku (navazuje na 6.1, varianta B).
- Server dělá namátkovou kontrolu v nastaveném časovém intervalu (parametr).
- Buňky, které kontrolou projdou, se po ověření smažou nebo vynulují. Shoda je výchozí stav a jejich data už nejsou potřeba.
- Buňky, kde kontrola najde rozpor, se nemažou. Data zůstanou, protože se rozpor musí dořešit a server k nim má referenci pro pozdější spor.
- Tím se ušetří místo a zůstává mechanismus pro odhalení podvodu.

**Otázka pro Jana.** Platí tento postup jako pravidlo kontraktu? Projedná se spolu s 6.1 s Willage-backend.

**Platí:** (Jan 2026-11-21 00:10, po vyjádření Willage-backend; doplněno 2026-11-21 00:24) Kontrola není namátková. Změny se sbírají do **zásobníku**; kontrola doběhne, když je zásobník plný, nebo po uplynutí časového intervalu, podle toho, co nastane dřív. Obě meze jsou parametry. Zvláštní kontrola rud při každém zápisu není. (Nahrazuje dřívější formulaci „interval nebo počet změn“.) Po úspěšné kontrole se smaže **jen pole původního materiálu**; položka změny (nová hodnota a voda) zůstává, jinak by se vracel výkop. Pole se po ověření vynechá, nenuluje (0 = vzduch). Při přijetí změny se pohyb materiálu zapíše do účetní knihy hráče a ostrova, protože po smazání původních hodnot zůstane jen čistý rozdíl vůči funkci. Záznamy s rozporem se nemažou a zůstávají jako reference pro spor. K úspěšné kontrole se uloží krátký otisk (čas, gen_ver, segment, hash, počet buněk). Kontrola nepřegenerovává celý segment při kopání. Kontrola je ve výchozím stavu zapnutá (Jan 2026-11-21 00:18). Když se vypne, server věří inventáři od klienta.

---

## 7. Prezentační vrstva (bývalá kapitola 7)

Původní plán: co čte z dat, LOD, průhlednost, řez, 2D/3D.

**Už vyřešeno v kap. 1–2**

- Datový model je v metrech a na 2D/3D nezávisí; ~~buňka 0,5 m = 1 dlaždice~~ **buňka 0,25 m = 1 dlaždice** jako jediný most k zobrazení → 1.1 (t710u, t715u; sjednoceno Jan 2026-11-21 00:19).
- Viditelnou oblast dává prezentace podle zoomu; generátor dostane obdélník + okraj a vzorkuje slupku → 2.3.
- Viditelný voxel je 0,25 m (postava 1,75 m = 7 voxelů), stejně jako datová buňka. 128 / 256 / 512 px je rozlišení textury dlaždice, ne velikost na obrazovce → 2.3 (t820u–t822u).
- Výchozí zoom v axonometrii kolem 64 dlaždic (voxelů 0,25 m) vodorovně, asi 16 m na šířku obrazovky → 2.3, 2.4 (t823u, t824u).
- Bok ostrova: bloky s vlastní texturou 5 m pod nejnižší okrajovou buňkou, v té výšce oblaka → 1.13.1.
- Měřítko vegetace 0,5; slučování sítí po 32 m patří sem, ne do dat → 1.12, 2.4.
- Omezovač sklonu E92 a `p94_hora_k` se ruší; členitost je v parametrech funkce světa → 1.4, 1.13.
- Jednotka scény 1 m → 1.2 / E89 [15].

Cílový telefon a fps Jan v 1.11 přeskočil; znovu se neptám. Bench APK z E93 pořád čeká, až ho Jan spustí, to není bod tohoto dokumentu [16].

### 7.1 Pohled 2D, nebo 3D

**Téma.** Jestli bude pohled 2D (dlaždice), nebo 3D (modely), Jan v t710u nechal otevřené. Datový model na tom nesmí záviset, ale prezentace to rozhodnout musí.

**Současný stav**
- Prototyp i rozhodnutí o zoomu a voxels počítají s **izometrií / axonometrií** a dlaždicemi (1.2, 2.3). Pravidlo „buňka 0,25 m = 1 dlaždice“ (do 2026-11-21 00:19 znělo 0,5 m) je most k 2D tilesetu 16/32/64 px [17].
- E90/E91/E96 kreslí 3D sítě (krychle, slupka, LOD) v téže axonometrii — to je nástrojová prezentace, ne rozhodnutí o hře [6][18][19].
- Materiály se zatím rozliší barvou (t710u).

**Varianty**

| | A: 2D izometrické dlaždice | B: 3D modely v axonometrii | C: data stejná, výchozí je A, B jako pozdější režim |
|---|---|---|---|
| sedí k 2.3 (voxel, zoom, textury) | ano | jde, jiný renderer | ano |
| práce teď | navazuje na tileset | větší | A teď, B až po datech |

**Doporučení.** Varianta C: výchozí pohled zůstane izometrické 2D dlaždice (zoom a textury z 2.3), datový model se nemění. 3D modely ve stejné axonometrii jdou přidat později jako druhý režim, který čte stejná data.

**Otázka pro Jana.** Má výchozí pohled zůstat izometrické 2D dlaždice, s možností později přidat 3D modely nad stejným datovým modelem? Nebo chceš rovnou 3D?

**Platí:**

---

### 7.2 LOD prezentační vrstvy

**Téma.** Jak se z dat staví hrubší zobrazení v dálce (E90). Není to datový model: slupka a obdélník pohledu už jsou v 2.3.

**Současný stav**
- E90: úroveň podle **hráče**, ne kamery. Kousky 16 m: ≤ 1 kousek 0,25 m, ≤ 3 kousky 0,5 m, jinak 1 m; daleko sloupce 8 m. Mapa 3 072 m, 2,27 M trojúhelníků, stavba 4,9 s, síť ≈ 260 MB. Bez sešití 6 982 děr (1 388 m², max 5 m), se sešitím stěn dolů **0 děr**. Krok hráče 16 m: 296 ms [18]. Čísla E90 jsou měření prezentačního LOD, ne datový model.
- 2.3 už říká, že viditelnou oblast bere prezentace z **zoomu a kamery**, datový model pevnou šířku nezná. ~~Viditelný voxel je 0,25 m, data 0,5 m~~ ⚠ překonáno rozhodnutím 2026-11-21 00:19: datová buňka i viditelný voxel jsou 0,25 m, výchozí záběr ~16 m (pevný zoom 64 dlaždic).
- Měřítko reliéfu × 8 / × 3 z testu E90 není otázka prezentace; členitost zadávají parametry světa (1.13).

**Varianty (jen to, co zbývá)**

| | A: LOD podle hráče, pásma E90 (16 / 48 m, daleko 8 m) | B: LOD podle kamery / zoomu, blízko 0,25 m, dál 0,5 m, zdálky hrubší; sešití stěn ponechat (historie, před rozhodnutím bez LOD) |
|---|---|---|
| soulad s 2.3 | slabší (2.3 už bere kameru) | sedí |
| sešití | v E90 nutné, jinak díry [18] | stejné, 0 děr |

**Doporučení.** ~~Varianta B. Úroveň se volí podle kamery a zoomu, ne podle postavy. Zblízka 0,25 m (viditelný voxel), dál 0,5 m (data), zdálky hrubší síť.~~ ⚠ překonáno rozhodnutím o 7.2 (bez LOD) a sjednocením buňky 2026-11-21 00:19 (data i pohled 0,25 m). Sešití stěn dolů k sousedovi nechat (v E90 zrušilo díry). Slučování stěn nebo výšková síť je optimalizace, ne pravidlo dat.

**Otázka pro Jana.** ~~Má se LOD řídit kamerou a zoomem (zblízka voxel 0,25 m, dál 0,5 m, zdálky hrubší) a sešití stěn z E90 zůstat?~~ ⚠ překonáno: jediné rozlišení 0,25 m, bez LOD (viz Platí).

**Platí:** (Jan, hovor 20. 11. 2026) Zatím se nechává jediné rozlišení 0,25 m na buňku, bez úrovní LOD a bez zoomu: celý pohled je v jednom rozlišení. Datová buňka je stejná 0,25 m (1.1, Jan 2026-11-21 00:19).

---

### 7.3 Průhlednost a řez v izometrii

**Téma.** Jak v izometrii vidět podzemí, když ho zakrývá svah nebo stavba (E91) [19].

**Současný stav**
- E91 (příznaky vypnuté): režim A dither ve válci, B řez, C přestavba sítí. Varianta A měla 67/100 % viditelnosti. Skutečný poloměr řezu v testu byl 1,5 m při nastavení kolem 3 m. Otevřené bylo: A na povrchu + B v podzemí, poloměr, výška řezu, víko barvou nebo skutečný řez, vegetace a vodopády nad řezem [19].
- 1.2 / 2.3: kreslí se jen obnažené vzduchem, u průhledné vody i dno. To řeší vodu, ne svah, který v izometrii zakrývá chodbu.

**Varianty**

| | A: jen dither / průhlednost na povrchu | B: jen řez (díra do terénu) | C: dither nebo průhlednost na povrchu + skutečný řez v podzemí (návrh E91) |
|---|---|---|---|
| chodba ve svahu | svah zůstane, prosvítá | svah zmizí v okruhu | nahoře kontext, dole řez |
| vegetace / vodopády | zůstanou | musí se oříznout nebo skrýt | oříznout spolu s řezem |

**Doporučení.** Varianta C: na povrchu průhlednost nebo dither, v podzemí skutečný řez. Poloměr a výška jsou parametry (výchozí řádově metry u postavy, doladí se v prezentaci). Vegetace a vodopády v řezu se oříznou nebo skryjí stejně jako terén, ať v díře netrčí.

**Otázka pro Jana.** Má být v izometrii na povrchu průhlednost (dither) a v podzemí skutečný řez kolem postavy, s vegetací a vodopády oříznutými v tom samém okruhu?

**Platí:** (Jan, hovor 20. 11. 2026) Ponechává se stávající nastavení z prototypu: průhlednost jako válec od postavy ke kameře s jemnou mřížkou vyřezávajících pixelů a řez, který prořízne terén a ukáže podzemní prostory. Obojí má vlastní přepínač, výchozí stav je vypnuto, takže se ve výchozí hře neprojevuje. Do nového řešení se implementuje v tomto stavu, úpravy později podle potřeby.

---

## 8. Plán slučování (bývalá kapitola 8)

Původní plán: pořadí slučování větví a zapnutí přepínačů.

**Už vyřešeno v kap. 1–2 (přepínače, které už nemají být otázkou)**

Z rozhodnutí vyplývá výchozí chování; při stavbě modelu se přepínače nahradí pravidlem, ne novým ptaním:

- `p67_rezim = pretok` (E67) → 1.8; K9 se tím zavírá.
- `p85_okraj` zap → 1.13.1; `p85_jemne` všude ne (jen slupka) → 1.2; zákaz vrstev < 25 cm se ruší (minimum 1 buňka = 0,25 m, Jan 2026-11-21) → 1.7.1.
- `p79_chodby` + `p85_voda` jsou nutné k tomu, aby lokální přepočet viděl dutiny a výtoky (1.9, K5) [3][12].
- Otočení a zrcadlení přes inverzní transformaci (`p86`) → 2.2; jádro hory ve funkci světa (`p87`) → 1.4, 1.7; blok 128 m z funkce (`p96`) → 1.1, 1.4.
- Jedna funkce světa, bez `p94_hora_k` a omezovače E92 → 1.4 (K6, K7).
- Kras E75 během hry patří k 1.8 (`p75_kras` je dnes vypnutý — zapne se při implementaci) a ukládá se cestou offsetu (4.1, ověřit v kroku 7).
- Do main jen s Janovým ano; každé sloučení má PROP a kontrolu výchozí hry, nebo novou referenci, když se výchozí hra mění záměrně.

E95 (vlákno vody) a E96 (blok 128 m) spolu nikdy neběžely [14]. Zkušební větev `zkusebni-vse` nemá E95 ani E96 a její „E95“ je jiný pokus než `e95-async-voda` (při sloučení přečíslovat na Z1) [14].

## Rozhodnuto při kroku 2 (funkce světa, Jan 2026-11-21)

Tyto body vznikly až z testů kroku 2 (otázky v reportu `krok02.md`) a z pozdější poznámky k rozdrobeným biomům; v původní kostře 03 nebyly. Jsou uzavřené. Pravidla jsou v 1.13, 1.14 a 2.1.

1. **Hory pod stropem sklonu** — *rozhodnuto (Jan 2026-11-21).* Roztáhnout do šířky (prodloužit vlnovou délku), ať mají plnou výšku (hornatina ~24 m, masiv ~12 m). Nezplošťovat. → 1.13.
2. **Strop v přechodu biomů** — *rozhodnuto (Jan 2026-11-21).* Platí vážený průměr stropů podle vah mísení, ne strop strmějšího biomu. → 1.13.
3. **Drobný detail masivu (skály)** — *rozhodnuto (Jan 2026-11-21).* Tvarům do výšky parametru (výchozí ~2 m) povolit strmější sklon. Strop platí pro celkový tvar hory. → 1.13.
4. **Poloha výchozího světa 3 × 3** — *rozhodnuto (Jan 2026-11-21).* Nechat ho uprostřed maxima, sopku přiblížit těsně vně výřezu. → 1.14.
Větší oblasti biomů (hrubší měřítko a slučování drobných ostrovů) byly jen **srovnány** za přepínačem `biom_velke_oblasti` (výchozí vyp). Jan 2026-11-21 21:21: současné biomy jsou asi v pořádku; **není to rozhodnutí**.

Pravidla klimatu (samostatná osa, preset, základní klima, pomalá mapa, uplatnění před reliéfem, povrchové jevy až po vodě) jsou rozhodnutá → 1.15. **Otevřené zůstávají konkrétní hodnoty presetů** (násobitele, posuny, podíly reliéfních biomů, množství vody) mimo výchozí identitu mírného klimatu (`mirne`). Příkladové presety poušť / step / tundra / ledovec v kódu jsou jen náčrt, nehodnocené hodnoty.


---

## Úkoly implementace (ne rozhodnutí)

Tohle se s Janem nerozhoduje znovu. Pravidlo už je v kapitolách 1 a 2, v kódu ještě není. Dělat až po dokončení dokumentu, každý zásah s PROP a kontrolou výchozí hry (nebo novou referencí, když se výchozí hra mění záměrně).

1. **Násobitel `p71_cas` / `cas_hry.FAKTOR` (= 24) ve svislé kapacitě zrušit.** Tok má být čistě K × A v l/s herního času (1.8.1).
2. **Spád ve svislé kapacitě (`ug67._caprem`) není natvrdo 1.** Započítat výšku vody nad buňkou (1.8.1).
3. **Spojení dvou materiálů = minimum** obou hodnot, ne výchozí „pomer“ ani volitelný harmonický průměr z E70 (1.8.1). Boční tok počítat jako X × skutečný spád hladiny.
4. **`e51_k` změnit z 0 na 1,5** (1.8.2).
5. **`materialy.csv`:** odstranit nebo přemapovat pásma krajiny id 57–74 (1.7.1) a vyřešit konflikty id z 1.6 (stejné id, jiný materiál; `lignite` 53 i 105; 13 herních tříd proti 78 id).
6. **Opravit K5:** výsledek lokálního přepočtu musí být stejný jako plný; okno je povodí (1.9). Výchozí test `voda_e66` to dnes nevidí (0 neshod). Zahrnout `p79_chodby` a `p85_voda`.
7. **Pomalý lokální běh podzemí v režimu přelivu / přetoku** (E62: úprava 3,4 → 2,7 s, cíl milisekundy nesplněn) řešit v rámci bodu 6, výchozí model je E67 (1.8) [5].
8. **Kopání po 0,25 m ve slupce** a generování jen slupky 2–3 buněk, ne celého sloupce (1.2, 2.3). Dnes se kope a vzorkuje po 0,5 m / celý sloupec.
9. **Výchozí podzemí přepnout na E67** a kras E75 zapnout v souladu s 1.8 (`p75_kras` je dnes vypnutý).
10. Ostatní vyplývající z 1–2 (bez nového rozhodnutí): inverzní transformace vložení, jedna funkce světa včetně jádra hory a sopky, vegetace na m² podle biomu, postupný převod na `jednotky.gd`, ověřit artéskou vodu „pokud to model zvládne“, podhůří u stěny masivu 5–6 m (E87) jako součást funkce světa. Povinný test 2.7 až po dokumentu. Měření determinismu na telefonu a v .NET ještě není.

---

## Zdroje

1. `docs/sjednoceni/01-principy-a-vstupy.md` a `docs/sjednoceni/02-model-sveta-a-generovani.md` (`sjednoceni` 7c6bb1f), pole **Platí:**.
2. `navrhy/navrh-terrainsource-kontrakt.md` (`e88-kontrakt-navrh` 72e9ff3), otázky 3, 4, 6, 7, 8, 11.
3. PROP E85 (`e85-blok2-rozhodnuti` 4ac8a1d), lokální chodba 12,6 s proti plným 1,6 s.
4. `docs/sjednoceni/00-mapa-vetvi.md` a `TODO.md` (main / `sjednoceni`): otevřené z vody, E79 časy.
5. PROP E62 (`main` 57c7dfb), režim přelivu: výkop 3,4 → 2,7 s.
6. PROP E96 (`e96-blok128` 64dbbcd).
7. PROP E95 (`e95-async-voda` 597342d).
8. PROP E72 a `TODO.md` (main): slučování výstupů, 150 → 6, po limitu 8 m 6 → 18.
9. `godot-prototyp/scripts/teren/prekryv78.gd` a PROP E78 (`e78-prekryv` 77539f4).
10. PROP E86 (`e86-otoceni-90` c458886).
11. PROP E76 (main / `e76-voda-po-prenosu`).
12. PROP E83 (`e83-determinismus` ff9d2ad).
13. PROP E87 (`e87-jadro-hory` ff97a9f).
14. `docs/sjednoceni/00-mapa-vetvi.md`, konflikty K4–K7 a strom větví.
15. PROP E89 (`e89-jednotky` e8fff3c), `godot-prototyp/scripts/jednotky.gd`.
16. PROP E93 (`e93-telefon` 7cbcf68).
17. `docs/sjednoceni/01-principy-a-vstupy.md` bod 1.1 (t714u, t715u).
18. PROP E90 a `godot-prototyp/scripts/teren/lod90.gd` (`e90-lod` a68a267).
19. PROP E91 (`e91-pruhlednost` 9f95d3b).
