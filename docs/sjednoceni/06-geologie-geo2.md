# 06 Geologie GEO2: implementační kontrakt (chronologie, pravidla zásahu, datový model)

**Platí:** *rozhodnuto 2026-11-27 (Jan t1028u: směr a rozhodnutí 1–13 varianta A; t1029u: R1–R5, O1–O3, princip spojité geologie; t1032u, t1033u: v3 schválena jako implementační kontrakt včetně kap. 8)*.
Nahrazuje pořadí útvarů E84 („nejzápornější SDF vyhrává“) a doplňuje 1.7. Stará cesta (`GeoVrstvy`, `Utvary`) zůstává, dokud GEO2 nesplní kritéria kap. 7.1 bod 12.

Zdroj: studie Willage-ideas `studie-hybridni-geologie/` (`KONTRAKT-GEO2.md` v3, `PODKLADY.md` v2, `KOD-E84.md`, měření `mereni/`). Sem je přenesené jen schválené znění. Slova **MUSÍ / NESMÍ / SMÍ** jsou závazná.
Odkazy na soubory `PODKLADY.md`, `KOD-E84.md`, `mereni/…` míří do studie Willage-ideas, nejsou v tomto repu.

## 0. Stav schválení, princip a změny

### 0.1 Historie schválení

- **2026-11-27 11:37, Jan t1028u:** GEO2 schválen jako architektonický směr. U rozhodnutí 1–13 z v1 schválena varianta A
  (doporučení). Přehled je v kap. 7.1.
- **2026-11-27 11:54, Jan t1029u:** v2 zkontrolována, zapracování pěti připomínek R1–R5 přijato. Rozhodnutí O1, O2, O3
  a princip oddělení geometrie od voxelů (0.2, 7.2). Po zapracování těchto úprav Jan **schvaluje kontrakt jako implementační**.
  Tato v3 je právě to zapracování.
- **2026-11-27 ~12:04, Jan t1032u, t1033u:** **v3 schválena jako implementační kontrakt**, „pusť se do toho“.
  Doplněna kap. 8 (vývoj katalogu hornin), schválená současně s v3. Zapisuje se do `docs/sjednoceni/06-geologie-geo2.md`.
- **2026-11-28, Jan t1046u (pro V8, krok K7):** potvrzena tři pravidla, ve kterých GEO2 záměrně neodpovídá GEO1: `HostitelSkarn`, `PravidloZdroje`, `PoradiTeles` (7.3), a kritérium smazání staré cesty „V8: 0 otevřených buněk na ≥ 3 seedech × 11 bloků“ (7.3). Výkonový limit ×1,5 GEO1 je jen doporučení (t1047u), ne kritérium smazání.

### 0.2 Princip: spojitá geologie, voxel je jen reprezentace

GEO2 je **zdroj spojité geologické geometrie a její historie**. Voxelová mřížka je jen jedna z možných reprezentací výsledku.
Změna velikosti voxelů NESMÍ vyžadovat změny v definicích těles, v událostech ani v pravidlech GEO2.

Tři veličiny jsou **nezávislé** (výchozí hodnoty mohou být stejné, význam a použití musí zůstat oddělené):

| Veličina | Parametr | Co určuje | Co neurčuje |
|---|---|---|---|
| geometrická přesnost | (vlastnost modelu) | spojité tvary, libovolně tenká tělesa, `Bod` je vždy přesný | – |
| záruka detekce | `minTloustkaDetekce_m` (t_det) | které tětivy **intervalové** vyhodnocení zaručeně najde (2.8) | zda těleso smí existovat; výsledek `Bod`; velikost voxelu |
| rozlišení vzorkování | `vyskaDetailnihoVoxelu_m` (a krok xy rasterizace) | jak se z intervalů nebo `Bod` sestaví konkrétní mřížka (3.4) | geometrii, pravidla, t_det, toleranci kontaktu, τ |

Další samostatné parametry (také výchozí 0,125 m, význam jiný): `tolerancKontaktu_m` (e_k, 2.5), `tau_m` (τ, chyba hranic mřížky vrstev, V5).

### 0.3 Změny v2 → v3

| # | Jan 11:54 t1029u | Co se změnilo | Kapitoly |
|---|---|---|---|
| O1 | skarn jen v karbonátech (vápenec, dolomit); transformace ve svoru, amfibolitu a jinde = samostatné budoucí události, ne rozšíření skarnu | zapsáno jako rozhodnutí, příklad skarnu beze změny (už jen karbonáty) | 2.7, 7.2 |
| O2 | oddělit geometrii od voxelů; tělesa tenčí než 0,125 m jsou dovolená kdekoli, nejen na koncích žil; 0,125 m je výchozí mez záruky detekce intervalů, ne zákaz; žádná chyba validace za tenkost; jasně říct, co záruka pokrývá; bodový výpočet zůstává přesný; `okraje_se_zuzuji` není podmínka; ztráta podvoxelových detailů patří do rasterizace, ne do geologie | přepsáno 2.8 a 3.4, přejmenován parametr, odstraněna validační chyba | 0.2, 2.8, 3.4, V4 |
| O3 | čtyři samostatné parametry, všechny výchozí 0,125 m | `minTloustkaTelesa_m` → `minTloustkaDetekce_m`; přidány `tau_m` a `vyskaDetailnihoVoxelu_m` | 2.7, 2.8, 3.4 |
| 4 | GEO2 = spojitá geometrie a historie; voxel je jen reprezentace | princip 0.2 | 0.2 |

| 5 | doplněk při schválení v3: počet hornin není pevný, stabilní id, vyřazení s náhradou, pravidla přes skupiny, verze katalogu v otisku | nová kap. 8 | 8 |

Změny v1 → v2 (R1–R5) zůstávají v platnosti, viz `KONTRAKT-GEO2-v2.md` (studie Willage-ideas) kap. 0.2.

### 0.4 Změny v1 → v2 (shrnutí, platné dál)

| # | Připomínka Jana | Co se změnilo | Kapitoly |
|---|---|---|---|
| R1 | deformace a intervaly | K1–K5 **bez deformací** (validace aktivní `Deformuj` odmítne). Nová samostatná **etapa D** (D1–D4) řeší inverzi v bodě, deformace intervalů a shodu interval == bod. K6 zůstává jen rozhraní | 1.6, 1.7, 1.8, 5, V1, V9 |
| R2 | minimální tloušťka tělesa | nový parametr (tehdy `minTloustkaTelesa_m`, ve v3 přejmenován). Bezpečná detekce = závorka + vzorkování krokem ostře menším než mez záruky v mezivrstvě + půlení. Náčrt důkazu, test proti 1/64 m | 2.8, 6.2, V4 |
| R3 | `Vnikni` do prázdna | jednoznačné pravidlo pro všechny operace: **cíl je buď materiál** (rozhoduje `nahrazuje` + `zdroje`), **nebo prázdno** (rozhoduje jen `prostor`). Nikdy obojí. Upravena validace a všech 12 příkladů | 2.2, 2.3, 2.4, 2.7 |
| R4 | původ materiálu | `Vzorek` rozlišuje **aktuální materiál**, **geometrický původ** (událost, instance, vrstva, materiál původu, hostitel původu) a **poslední transformaci**. Plná historie je volitelná a jen na vyžádání | 3.1, 3.2 |
| R5 | kontaktní pásmo | jedna rozměrově správná definice `w(q) = w₀·(1 + a·N(f·q))` [m] a dosahu `R_max`. Opraveny nekonzistentní zápisy z v1 (2.2, 2.5, 6.2). Přesná definice strany kontaktu, bodu vzorku na druhé straně, `hostitel_okoli` a víc těles | 2.5 |

---

## 1. Q1 Chronologie: jeden model, tři druhy operací

### 1.1 Princip

GEO2 je **jeden chronologický model**: jeden seřazený seznam událostí a jeden vyhodnocovač. Události se liší jen druhem operace:

| Druh | Mění | Vyhodnocení | Operace |
|---|---|---|---|
| **Deformace** | souřadnicový prostor všeho staršího | inverzí souřadnic od nejmladší (**až v etapě D**, 1.8) | `Deformuj` |
| **Materiálová** | obsah prostoru | dopředu nad stavem po starších událostech | `Uloz`, `Vnikni`, `Odstran`, `Vypln` |
| **Transformace** | materiál (vlastnosti, identitu), **ne geometrii ani typ prostoru** | dopředu nad stavem po starších událostech | `Transformuj` |

Nový proces MUSÍ být nová událost jednoho z těchto druhů, ne nová větev ve vyhodnocovači.
Povrch (tvar M1 + eroze M7) je vstup, ne událost. Prostor nad finálním povrchem je `NadPovrchem` a žádná událost ho NESMÍ změnit.
`Vykopano` je překryv hry (E78), ne událost.

### 1.2 Záznam události

| Pole | Typ | Význam |
|---|---|---|
| `id` | string, unikátní, stabilní | klíč v datech a v původu |
| `stari` | int ≥ 0, unikátní | pořadí v čase, větší = mladší |
| `operace` | enum | `Uloz`, `Vnikni`, `Odstran`, `Vypln`, `Transformuj`, `Deformuj` |
| `aktivni` | bool (výchozí true) | `false` = v datech, ale kompilátor ji vynechá |
| `tvar` | objekt | prostorový popis (2.6) |
| `vyskyt` | objekt | instance: `jedna`, `mrizka` (G, p, R, sůl), `seznam` |
| `pravidla` | objekt | rozsah zásahu (kap. 2) |
| `vysledek` | objekt | materiál / tabulka `mapa` / typ vytvářeného prostoru / mineralizace |
| `sourozenci` | enum | `unie` (výchozí) / `nejmensi_sdf` (jen parita) |

### 1.3 Klíč pořadí, shodné stáří (schváleno 2A)
Klíč (`stari`, `id`). Dvě aktivní události se stejným `stari` = **chyba validace**.

### 1.4 Sourozenci (schváleno 4A)
`unie`: bod v několika instancích téže události = jeden zásah. Pro původ se vezme nejmenší `instance`. Žádné srovnávání SDF.

### 1.5 Opakované transformace (schváleno 5A)
Každá transformace se použije jednou, ve svém stáří, na stav po všech starších událostech. Další transformace vidí její výsledek
(řetězení). Mladší materiál transformace nezmění (plyne z pořadí). Omezení přes `zdroje.transformace` (2.2).

### 1.6 Vyhodnocení v bodě (K1–K5, bez deformací)

```
Bod(p):                                    // pro K1–K5 platí poloha[i] = p pro všechna i
  if p.z > zPov(p.x, p.y): return Vzorek.NadPovrchem
  s = Stav.Neurceno
  for i = 0 … N−1, jen E[i] z indexu bloku s obálkou přes p:
      (zasah, instance) = E[i].Tvar.Obsahuje(p)
      if !zasah: continue
      if !Povoluje(E[i], s, p): continue             // kap. 2.3
      s = Proved(E[i], instance, s)                   // kap. 3.1, pravidla zápisu původu
  return s.Vzorek                                     // Neurceno na konci = chyba dat (V1)
```

Aktivní událost `Deformuj` v K1–K5 MUSÍ odmítnout validace (chyba „deformace až v etapě D“). Neaktivní (`aktivni: false`)
v datech být smí. Vyhodnocovač v K1–K5 fázi poloh (inverze) **nemá**.

### 1.7 Vyhodnocení ve sloupci (K4, bez deformací)

```
Sloupec(x, y):
  behy = [ (zMin, zPov, Neurceno), (zPov, zMax, NadPovrchem) ]
  for i = 0 … N−1, jen E[i] z indexu dlaždice:
      I = E[i].IntervalySloupce(x, y)       // bezpečné intervaly tvaru (2.8), seřazené, s instancemi
      for kus in rozdel(behy, I):
          if kus ⊆ I and Povoluje(E[i], kus.stav, kus): kus.stav = Proved(E[i], …)
  sloucit sousedni behy se stejnym stavem
```

- `hloubka` = ořez intervalu. `kontakt` = interval pásma (2.5) průnikem s I.
- **Invariant (K4):** pro každé z ve sloupci platí `Sloupec.Stav(z) == Bod(x, y, z)`, kromě pásma ±ε u certifikované hranice,
  kde rozhoduje `Bod` (3.4). Záruka detekce intervalů platí jen pro tětivy délky ≥ t_det (2.8). Podlimitní části SMÍ interval
  vynechat; `Bod` je najde vždy. Test V4 to vykazuje zvlášť. Geometrie tělesa se tím nemění.
- **Příprava pro etapu D:** analytické průniky v K4 MUSÍ být napsané pro obecnou přímku (počátek + směr), svislý sloupec je
  jen zvláštní případ. Etapa D je pak použije na šikmé úseky.

### 1.8 Deformace: etapa D (samostatně, po K4 a po rozhodnutí Jana)

Jen cíl a kontrakt. Implementace až v etapě D.
- Poloha v čase i: `poloha[i] = D_k⁻¹ ∘ … ∘ D_m⁻¹ (p)` přes deformace mladší než i, od nejmladší. Událost je definovaná
  v souřadnicích svého času.
- `IDeformace` (K6, jen rozhraní): `Stari`, `Obalka`, `Inverze(ref q) → bool presne`, `UsekySloupce(primka) → seznam
  (úsek přímky ve starších souřadnicích, afinní zobrazení)` nebo `NeAfinni`.
- **D1** bod: fáze poloh v `Bod`. **D2** intervaly: sloupec se v obálce deformace rozloží na úseky. Každý úsek je přímka
  (obecně šikmá) ve starších souřadnicích a průniky z K4 se počítají na ní. U `NeAfinni` záloha: body krokem < t_det + půlení,
  hranice `Odhad`. **D3** ověření: interval == bod (V9). **D4** první skutečná deformace (zlom) jen se schválením Jana.
- Deterministická inverze: uzavřený vzorec, nebo pevný počet iterací bez testu konvergence na float.

### 1.9 Determinismus
- Jen + − × ÷ `sqrt` `floor`, celočíselné hashe (SplitMix64), žádné FMA, žádné `Sin/Exp/Pow` bez vlastní implementace.
- Úplná celočíselná pořadí událostí, instancí a běhů. Žádná iterace přes `Dictionary` / `HashSet`.
- Vzorkovací body intervalů leží na **světové mřížce** z_k = k·h (ne od začátku bloku), takže výsledek nezávisí na bloku.
- Nezávislost na počtu vláken a pořadí bloků (V7).

---

## 2. Q2 Pravidla zásahu

### 2.1 Stav bodu (vstup pravidel)
Pole z 3.1: `Material`, `Typ`, `GeoUdalost` (+ druh její operace), `GeoInstance`, `Vrstva`, `PocetTransformaci`.
Třída cíle podle `Typ`:

| Třída cíle | `Typ` | Kdo ji smí zasáhnout |
|---|---|---|
| **Neurceno** | (jen před první `Uloz`) | jen `Uloz` |
| **Materiál** | `Pevne` | `Vnikni`, `Odstran`, `Transformuj` |
| **Prázdno** | `DutinaKras`, `DutinaJina` | `Vnikni` a `Vypln`, jen s povoleným `prostor` |
| **Mimo geologii** | `NadPovrchem`, `Vykopano` | nikdo |

### 2.2 Slovník pravidel

| Pravidlo | Zápis | Kdy se uplatní |
|---|---|---|
| **nahrazuje** | `{"materialy":[…], "skupiny":[…], "krome":[…]}` nebo `"*"`. Globální `nikdy` patří sem (vypne ho `ignoruj_nikdy: true`) | **jen cíl Materiál** |
| **zdroje** | `{"vrstvy": bool / [id vrstev], "telesa": "zadna" / "starsi" / [id událostí], "transformace": bool}` | **jen cíl Materiál**. `vrstvy` = `GeoUdalost` je `Uloz`; `telesa` = `GeoUdalost` je `Vnikni` / `Vypln`; `transformace` = `PocetTransformaci > 0` |
| **prostor** | `[DutinaKras, DutinaJina]` (podmnožina) | **jen cíl Prázdno** |
| **hloubka** | `{"min_m", "max_m"}`, od finálního povrchu (schváleno 6A) | vždy (místní filtr) |
| **kontakt** | objekt (2.5), včetně `hostitel_okoli` | vždy (místní filtr) |

### 2.3 Jedno pravidlo pro cíl (připomínka 3)

```
Povoluje(E, s, p):
  if !E.Hloubka.Plati(p) or !E.Kontakt.Plati(p): return false   // místní filtry, vždy
  switch trida(s):
    Neurceno:      return E.operace == Uloz
    Material:      return E.operace ∈ {Vnikni, Odstran, Transformuj}
                          and E.Nahrazuje.Plati(s.Material) and E.Zdroje.Plati(s)
    Prazdno:       return E.operace ∈ {Vnikni, Vypln} and s.Typ ∈ E.Prostor
    MimoGeologii:  return false
```

- Bod je vždy buď materiál, nebo prázdno, nikdy obojí. Proto rozhoduje vždy **právě jeden** filtr (materiál → `nahrazuje` + `zdroje`,
  prázdno → `prostor`) a nevzniká kombinace, kterou by šlo vyložit dvojím způsobem. Platí stejně pro všechny operace.
- Pro dutinu tedy neplatí `nikdy` ani hostitelský výčet. Sopka do krasové dutiny vnikne jen proto, že má `DutinaKras` v `prostor`.
- Proč ne jiné pravidlo: varianta „prázdno musí projít i `nahrazuje` (s materiálem 0)“ by míchala materiál s prostorem a
  vyžadovala by zvláštní klíč pro 0. Navrhované pravidlo je jednodušší a odpovídá typu prostoru z K2.

### 2.4 Validace pravidel (kompilátor odmítne chybou)

| Operace | `nahrazuje` | `zdroje` | `prostor` | jiné |
|---|---|---|---|---|
| `Uloz` | zakázáno | zakázáno | zakázáno | právě jedna aktivní `Uloz` se `stari` = nejmenší, tvar pokrývá celý sloupec pod povrchem |
| `Vnikni` | výchozí `"*"` − `nikdy` | výchozí `{vrstvy: true, telesa: "zadna", transformace: true}` | výchozí `[]` (do prázdna nesmí) | – |
| `Odstran` | **povinné** | výchozí `{vrstvy: true, telesa: "zadna"}` | **zakázáno** (prázdno nejde odstranit) | povinné `hloubka.min_m`, `vysledek.prostor` ∈ {DutinaKras, DutinaJina} |
| `Vypln` | **zakázáno** | **zakázáno** | **povinné, neprázdné** | – |
| `Transformuj` | **povinné**, = klíče `mapa` | výchozí `{vrstvy: true, telesa: "zadna", transformace: false}` | **zakázáno** | každý klíč `mapa` má cíl v katalogu |
| `Deformuj` | – | – | – | v K1–K5 aktivní **zakázáno** |

Obecně: `prostor` NESMÍ obsahovat `NadPovrchem` ani `Vykopano`. Neznámý klíč, materiál, skupina nebo id události = chyba.
`zdroje.telesa` smí jmenovat jen **starší** události. `kontakt.cil` smí jmenovat jen starší události nebo vrstvy.

### 2.5 Kontaktní pásmo a `hostitel_okoli` (připomínka 5)

**Jedna definice (všechny veličiny s jednotkami):**

| Symbol | Jednotka | Zápis v datech | Význam |
|---|---|---|---|
| w₀ | m | `sirka_m` | střední šířka pásma |
| a | – (0 ≤ a < 1) | `modulace.amp_rel` | relativní rozkmit šířky |
| f | 1/m | `modulace.frekvence_1_m` | frekvence šumu šířky |
| N(·) | – (∈ [−1, 1]) | – | `VNoise` se seedem události, argument f·q (bezrozměrný) |
| d(q) | m | – | eukleidovská vzdálenost bodu q ke kontaktní ploše S (níže) |
| e_k | m | globální `tolerancKontaktu_m` | dovolená chyba výpočtu d |
| η | m | `hostitel_okoli.hloubka_vzorku_m` | jak hluboko za kontaktem se čte druhá strana |

```
w(q)   = w₀ · (1 + a · N(f·q))                 [m],  w ∈ [w₀(1−a), w₀(1+a)]
v pásmu ⇔ d̃(q) ≤ w(q)  a  strana(q) sedí  a  hostitel_okoli(q) platí
R_max  = w₀ · (1 + a) + e_k                    [m]   (největší dosah, pro kandidáty a okraj kontextu)
okraj kontextu bloku ≥ R_max + η               [m]
```

Dnešní skarn (`SkarnD`, Utvary.cs:74–86) odpovídá w₀ = 1,5 m, a = 0,5, f = 0,5 1/m, ale měří svisle.
Opravené zápisy z v1: „okruh `sirka_m + amp`“ (sčítalo metry s bezrozměrným číslem) a „šířka·(1 + amp) + mez šumu cíle“
nahrazuje jediné `R_max`.

**Cíl a kontaktní plocha.** `kontakt.cil = {"vrstvy": [...]}` a/nebo `{"udalosti": [...]}` (jen starší). Oblast cíle T =
body, jejichž stav **těsně před kontaktní událostí** má geometrický původ v cíli: `GeoUdalost` ∈ `udalosti`, nebo
`GeoUdalost` = zásobník a `Vrstva` ∈ `vrstvy`. Kontaktní plocha S = hranice T. Víc instancí a víc cílů = jedna oblast
(sjednocení), takže S je jedna plocha.

**Výpočet d̃ (musí platit |d̃ − d| ≤ e_k), schváleno 7A:**
- vrstvy: S je hranice cílových vrstev z mřížky hranic (kap. 6.3) jako výšková plocha. Každá buňka mřížky se rozdělí na
  2 trojúhelníky s pevnou úhlopříčkou. d̃ = přesná vzdálenost bod–trojúhelník, minimum přes trojúhelníky do vzdálenosti R_max.
  Chyba ≤ chyba mřížky τ (V5), proto MUSÍ platit τ ≤ e_k.
- tělesa bez šumu: přesná vzdálenost k primitivu (deska, kapsle uzavřeně; elipsoid pevným počtem iterací).
- tělesa se šumem: d̃ = vzdálenost k primitivu bez šumu. Chyba ≤ mez šumu δ_S (2.8), proto validace vyžaduje δ_S ≤ e_k.
  Jinak chyba „cíl kontaktu je příliš zašuměný“.

**Strana:** `vne` ⇔ q ∉ T, `uvnitr` ⇔ q ∈ T, `obe`. Členství q v T se čte ze stavu q (pole 3.1), ne ze znaménka funkce.

**Druhá strana (`hostitel_okoli`).** π(q) = nejbližší bod S k q (ten, který dal d̃). u = (π(q) − q)/|π(q) − q| ukazuje přes kontakt.
Bod vzorku q′ = π(q) + η·u. Když |π(q) − q| < 2⁻¹⁰ m, u = normála S v π(q) (u vrstev normála trojúhelníku, u těles
analytická). Podmínka platí ⇔ stav v q′ **těsně před kontaktní událostí** (prefixové vyhodnocení událostí < kontakt) je
`Pevne` a `Material` ∈ `hostitel_okoli.materialy` / `skupiny`.

**Víc těles a kontaktů:**
1. rozhoduje jen **nejbližší** bod S. Shoda vzdáleností: menší (pořadí cíle, instance, index trojúhelníku);
2. jiné těleso mezi q a S je vyřešené samo: q má jeho materiál, takže neprojde `nahrazuje`. Mladší těleso v době kontaktu
   neexistuje (prefix);
3. dvě různé kontaktní události se překrývají: rozhodne chronologie (druhá působí na výsledek první, jen pokud ho má v `nahrazuje`);
4. když je cíl v místě tenčí než η, q′ přeletí skrz cíl a `hostitel_okoli` čte, co je za ním (nebo prázdno). To je definované
   chování, ne chyba validace: tenký cíl je dovolený (2.8). Doporučení: η ≤ t_det, aby se zaručeně tlusté cíle nepřeskakovaly.

**Skarn jen na kontaktu karbonát–granitoid:** `nahrazuje` = karbonáty (materiál v q), `cil.vrstvy` = granitoidy, `strana` = `vne`,
`hostitel_okoli.materialy` = granitoidy (materiál v q′). Granitoid změněný starší transformací, nebo dutina na kontaktu,
pak skarn nevytvoří.

### 2.6 Tvary a obálky
`ITvar`: `Obsahuje(q)`, `Obalka(instance)` (zaručeně konzervativní), `Zavorka(primka, instance)` (2.8), `TloustkaMin(parametry)`,
`Vzdalenost(q)` (na vyžádání, `presna/odhad`), `MezSumu` δ [m]. Dnešní čočka obálku nesplňuje (4,8 % ořezaných), komín má
obálku 6× větší (`KOD-E84.md`).

### 2.7 Formát `udalosti_v2.json`, 12 příkladů

```json
{ "schema": "willage.udalosti.v2", "verze": 3,
  "konfigurace": {
    "minTloustkaDetekce_m": 0.125,
    "tolerancKontaktu_m": 0.125,
    "tau_m": 0.125,
    "vyskaDetailnihoVoxelu_m": 0.125
  },
  "nikdy": ["topsoil", "gravel_sand", "loess", "weathered_clay"],
  "udalosti": [ "…" ] }
```

Sloupec „cíl“ říká, jaký filtr se uplatní: **M** = materiál (`nahrazuje` + `zdroje`), **P** = prázdno (`prostor`).

| # | id | operace | cíl |
|---|---|---|---|
| 1 | zasobnik | Uloz | Neurceno |
| 2 | granitoid_intruze | Vnikni | M |
| 3 | skarn_kontakt | Transformuj | M |
| 4 | cocka_pegmatit | Vnikni | M |
| 5 | zila_kremen | Vnikni | M |
| 6 | solny_dom | Vnikni | M |
| 7 | komin_kimberlit | Vnikni | M |
| 8 | kras | Odstran | M |
| 9 | sopka | Vnikni | M + P |
| 10 | vyplen_jeskyne | Vypln | P |
| 11 | zlom_budouci | Deformuj | – (neaktivní) |
| 12 | metamorfoza_regionalni_budouci | Transformuj | M (neaktivní) |

```json
[
 { "id": "zasobnik", "stari": 0, "operace": "Uloz",
   "tvar": { "druh": "zasobnik", "zdroj": "VrstvySloupce", "mrizka": "adaptivni" },
   "vyskyt": { "druh": "jedna" } },

 { "id": "granitoid_intruze", "stari": 10, "operace": "Vnikni", "aktivni": false,
   "tvar": { "druh": "elipsoid", "polomery_m": [60, 40, 30], "sum": { "druh": "posun", "amp_m": 2.0, "frekvence_1_m": 0.05 } },
   "vyskyt": { "druh": "mrizka", "G": 512, "p": 0.3, "sul": 11 },
   "pravidla": { "nahrazuje": { "skupiny": ["krystal", "vapenec", "bridlice", "piskovec"] },
                 "zdroje": { "vrstvy": true, "telesa": "zadna", "transformace": true },
                 "prostor": [],
                 "hloubka": { "min_m": 30 } },
   "vysledek": { "material": "granite" } },

 { "id": "skarn_kontakt", "stari": 20, "operace": "Transformuj",
   "tvar": { "druh": "kontakt" },
   "pravidla": {
     "nahrazuje": { "materialy": ["deep_limestone", "cave_limestone", "dolomite"] },
     "zdroje": { "vrstvy": true, "telesa": "zadna", "transformace": false },
     "kontakt": { "cil": { "vrstvy": ["granite", "granodiorite", "leucogranite", "granite_massif"], "udalosti": ["granitoid_intruze"] },
                  "strana": "vne", "sirka_m": 1.5,
                  "modulace": { "amp_rel": 0.5, "frekvence_1_m": 0.5 },
                  "hostitel_okoli": { "materialy": ["granite", "granodiorite", "leucogranite", "granite_massif"], "hloubka_vzorku_m": 0.125 } } },
   "vysledek": { "mapa": { "deep_limestone": "skarn", "cave_limestone": "skarn", "dolomite": "skarn" } } },

 { "id": "cocka_pegmatit", "stari": 30, "operace": "Vnikni",
   "tvar": { "druh": "elipsoid", "z_parametru": "cocka", "obalka": "max_polomer" },
   "vyskyt": { "druh": "mrizka", "z_parametru": "cocka" },
   "pravidla": { "nahrazuje": { "skupiny": ["krystal"] },
                 "zdroje": { "vrstvy": true, "telesa": ["granitoid_intruze"], "transformace": true },
                 "prostor": [] },
   "vysledek": { "material": "pegmatite" }, "sourozenci": "unie" },

 { "id": "zila_kremen", "stari": 40, "operace": "Vnikni",
   "tvar": { "druh": "deska", "z_parametru": "zila",
             "sum": { "druh": "posun_kolmo", "amp_m": 0.3, "frekvence_1_m": 0.35 } },
   "vyskyt": { "druh": "mrizka", "z_parametru": "zila" },
   "pravidla": { "nahrazuje": { "skupiny": ["krystal"], "materialy": ["skarn", "pegmatite"] },
                 "zdroje": { "vrstvy": true, "telesa": ["granitoid_intruze", "cocka_pegmatit"], "transformace": true },
                 "prostor": [] },
   "vysledek": { "material": "quartzite", "mineralizace": { "tabulka": "mineraly_hostitele" } } },

 { "id": "solny_dom", "stari": 50, "operace": "Vnikni",
   "tvar": { "druh": "elipsoid", "z_parametru": "dome" },
   "vyskyt": { "druh": "mrizka", "z_parametru": "dome" },
   "pravidla": { "nahrazuje": { "materialy": ["rock_salt", "gypsum", "dolomite", "deep_limestone", "cave_limestone", "siltstone", "shale", "conglomerate", "quartz_sandstone"] },
                 "zdroje": { "vrstvy": true, "telesa": "zadna", "transformace": true },
                 "prostor": [] },
   "vysledek": { "material": "rock_salt" } },

 { "id": "komin_kimberlit", "stari": 60, "operace": "Vnikni",
   "tvar": { "druh": "elipsoid", "z_parametru": "pipe", "obalka": "presna" },
   "vyskyt": { "druh": "mrizka", "z_parametru": "pipe" },
   "pravidla": { "nahrazuje": "*",
                 "zdroje": { "vrstvy": true, "telesa": "starsi", "transformace": true },
                 "prostor": [] },
   "vysledek": { "material": "kimberlite" } },

 { "id": "kras", "stari": 70, "operace": "Odstran",
   "tvar": { "druh": "kapsle_retez", "z_parametru": "kras",
             "sum": { "druh": "posun_3d", "amp_m": 0.25, "frekvence_1_m": 0.5 } },
   "vyskyt": { "druh": "mrizka", "z_parametru": "kras" },
   "pravidla": { "nahrazuje": { "materialy": ["deep_limestone", "cave_limestone", "dolomite"] },
                 "zdroje": { "vrstvy": true, "telesa": "zadna", "transformace": false },
                 "hloubka": { "min_m": 2.0 } },
   "vysledek": { "prostor": "DutinaKras" } },

 { "id": "sopka", "stari": 80, "operace": "Vnikni",
   "tvar": { "druh": "sopka_nitro", "zdroj": "NitroSopky" },
   "vyskyt": { "druh": "seznam", "zdroj": "Sopky" },
   "pravidla": { "nahrazuje": "*", "ignoruj_nikdy": true,
                 "zdroje": { "vrstvy": true, "telesa": "starsi", "transformace": true },
                 "prostor": ["DutinaKras", "DutinaJina"] },
   "vysledek": { "material_z_tvaru": true } },

 { "id": "vyplen_jeskyne", "stari": 90, "operace": "Vypln",
   "tvar": { "druh": "pod_dnem", "udalost": "kras", "vyska_m": 0.4,
             "sum": { "druh": "posun_svisle", "amp_m": 0.15, "frekvence_1_m": 1.0 } },
   "pravidla": { "prostor": ["DutinaKras"] },
   "vysledek": { "material": "clay_deposit" } },

 { "id": "zlom_budouci", "stari": 100, "operace": "Deformuj", "aktivni": false,
   "tvar": { "druh": "rovina_zlomu", "bod_m": [0, 0, 0], "normala": [0.6, 0, 0.8], "posun_m": [0, 3, -2], "polomer_m": 200 },
   "vyskyt": { "druh": "mrizka", "G": 1024, "p": 0.1, "sul": 101 } },

 { "id": "metamorfoza_regionalni_budouci", "stari": 5, "operace": "Transformuj", "aktivni": false,
   "tvar": { "druh": "oblast" },
   "pravidla": { "nahrazuje": { "materialy": ["shale", "siltstone"] },
                 "zdroje": { "vrstvy": true, "telesa": "zadna", "transformace": false },
                 "hloubka": { "min_m": 400 } },
   "vysledek": { "mapa": { "shale": "phyllite", "siltstone": "mica_schist" } } }
]
```

Poznámky:
- `granitoid_intruze` je `aktivni: false`. Podle 3A zůstává granitoid ve V2.0 vrstvou a skarn má cíl `vrstvy`. Odkaz
  v `cil.udalosti` na neaktivní událost kompilátor vypustí.
- **Skarn jen v karbonátech** (O1, Jan 11:54): dnešní `utvary_hostitele.json` skarnuje i amphibolite, mica_schist,
  phyllite a crystalline_transition. Tyto horniny skarnová událost ve V2.0 nemění. Případné transformace ve svoru, amfibolitu
  nebo jiných horninách budou samostatné budoucí události, ne rozšíření pravidel skarnu.
- Lens, dome a pipe jsou dnes elipsoidy bez šumu (`Utvary.cs:43–50`). Žíla má šum posunu kolmo k desce (`P[15]`),
  kras 3D posun (`P[27]`). |N| ≤ 1, protože `VNoise` je konvexní kombinace mřížkových hodnot z [−1, 1).
- `hloubka_vzorku_m` = 0,125 m je volba příkladu (doporučení η ≤ t_det), ne podmínka validace.
- V `metamorfoza_regionalni_budouci` je `hloubka` místo pole `tvar.hloubka_m` z v1 (jedno místo pro hloubku).

### 2.8 Záruka detekce při intervalovém vyhodnocování (O2, O3)

GEO2 **MUSÍ umožnit** spojitá tělesa libovolné tloušťky, i menší než 0,125 m, a to kdekoli (nejen na zužujících se koncích žil).
Tenkost **není chyba validace**.

**Parametr záruky.** `konfigurace.minTloustkaDetekce_m` = t_det, výchozí 0,125 m. Je to **hranice záruky intervalové detekce**,
ne zákaz geometrie a ne výška voxelu. S `vyskaDetailnihoVoxelu_m` nesouvisí: změna jednoho druhý nemění (0.2).

**Co záruka pokrývá.** Pro každé těleso (instanci) a každou přímku, na které se interval počítá (v K1–K5 svislý sloupec):
**každý souvislý úsek přímky uvnitř tělesa (tětiva) o délce ≥ t_det se najde** a jeho konce jsou certifikované s chybou
≤ ε = 2⁻¹⁰ m.
Důsledek: když se do tělesa vejde koule o průměru ≥ t_det, svislá tětiva jejím středem má délku ≥ t_det a najde se.
Deska tloušťky t ≥ t_det má každou tětivu ≥ t (šikmá je delší).

**Co záruka nepokrývá.**
- Tětivy kratší než t_det **SMÍ** intervalové vyhodnocení vynechat.
- Mezery kratší než t_det mezi dvěma částmi téhož tělesa **SMÍ** zaniknout (spojí se).
- `Bod` je v obou případech **vždy přesný** a geometrii nemění. Rozdíl interval vs. bod u podlimitních tětiv vykazuje V4 zvlášť.
- Záruka nic neříká o rozestupu sloupců v xy ani o velikosti voxelu. To je rasterizace (3.4), ne geologie.

**Bezpečná detekce (pro každý tvar):**
1. **Závorka:** tvar vrátí pro přímku dvě sjednocení intervalů V (vnitřní) a O (vnější) se zaručeným V ⊆ těleso ∩ přímka ⊆ O.
   Počítají se analyticky (kvadratika / lineární), bez vyhodnocení šumu.
2. **Vzorkování jen v mezivrstvě O ∖ V:** body na světové mřížce z_k = k·h s **h = t_det / 2** (ostře < t_det) a test
   členství (přesné znaménko).
3. **Půlení** mezi sousedními vzorky s různým členstvím (a mezi okrajem V a sousedním vzorkem), pevný počet kroků
   ⌈log₂(h/ε)⌉ (pro t_det = 0,125: 6 kroků).
4. Tětivy = vnitřní vzorky + V, sloučené. Konce `Certifikovana`.

**Náčrt důkazu.** Nechť C = [a, b] je tětiva, b − a ≥ t_det. Ze závorky C ⊆ O. Když C protne V, je nalezena (V je uvnitř).
Jinak C ⊆ O ∖ V. Body mřížky mají rozestup h < t_det ≤ b − a, takže C obsahuje aspoň jeden bod z_k. Ten leží v O ∖ V,
je vzorkován a test vrátí „uvnitř“. Konce dohledá půlení mezi z_k a nejbližšími vnějšími vzorky (nebo okrajem O).
Lipschitzova konstanta se v důkazu nepoužívá. Naměřené |dSDF/dz| až 227 (`mereni/vystup4.txt`) tak záruku neohrožuje.
Mez L SMÍ sloužit jen ke zrychlení (vynechat vzorky, kde |f|/L > vzdálenost k dalšímu vzorku), a jen když je L odvozená
vzorcem, ne naměřená.

**Závorky dnešních tvarů:**

| Tvar | O (vnější) | V (vnitřní) | Proč platí |
|---|---|---|---|
| elipsoid bez šumu (čočka, dóm, komín) | přesný průnik `k0 ≤ 1` | = O | znaménko `k0(k0−1)/k1` je přesné |
| elipsoid s posunem δ = A·√3 | homotetie (1 + δ/r_min)·E | (1 − δ/r_min)·E | opěrná funkce: h_{sE} − h_E = (s−1)·h_E ≥ (s−1)·r_min |
| deska žíly, šum kolmo amp A | {\|s\| ≤ tail + A} ∩ {a² + b² ≤ (1 + A/min(r_a, r_b))²} | {\|s\| ≤ tail − A} | s je přesná vzdálenost k rovině, \|A·N\| ≤ A, mimo kruh je tail ≤ −(r − 1)·min(r_a, r_b) |
| kras, posun 3D, δ = A·√3 | kapsle s poloměrem max(r₀, r₁) + L_i·δ; elipsoid komory (1 + δ/r_min) | kapsle min(r₀, r₁) − L_i·δ (je-li > 0); komora (1 − δ/r_min) | f_i má L_i = 1 + \|r₁ − r₀\|/\|ba\| (vzorec) |
| jiný / neznámý | obálka AABB v z | ∅ | vždy správné, jen dražší |

Cena: bez šumu 0 vzorků. Žíla ≈ 2 mezivrstvy po 2A / h ≈ 20 vzorků na tětivu (A = 0,3, h = t_det/2 = 1/16 při výchozím t_det).
Kras podobně.

**Validace a hlášení (žádná chyba za tenkost).**
- Validace návrhu **NESMÍ** odmítnout tvar ani instanci proto, že je místy nebo všude tenčí než t_det.
- Příznak `okraje_se_zuzuji` **není podmínka** a v datech se nevyžaduje. Tvar SMÍ volitelně uvést informativní
  `info_min_tloustka_m` (dolní mez místní tloušťky přes rozsah parametrů). Když je vyplněná a vyjde < t_det, kompilátor
  SMÍ vypsat **varování** do zprávy (užitečné pro autora návrhu). Varování návrh neodmítne.
- Kontaktní pásmo se chová stejně: když w₀(1 − a) < t_det, podlimitní části pásma záruka nepokrývá. Není to chyba.
- Referenční test V4 používá hustotu 1/64 m. Při výchozím t_det = 0,125 m to dává aspoň 8 vzorků na zaručenou tětivu.
  Samotná hodnota t_det tím není svázaná.


## 3. Q3 Datový model

### 3.1 Vzorek (připomínka 4)

```csharp
public readonly struct Vzorek {
    // aktuální stav
    public readonly ushort Material;        // aktuální materiál (po transformacích); 0 = prázdno
    public readonly TypProstoru Typ;        // Pevne, NadPovrchem, DutinaKras, DutinaJina, Vykopano
    // geometrický původ: k čí geometrii bod patří
    public readonly ushort GeoUdalost;      // Uloz / Vnikni / Odstran / Vypln, která naposledy určila geometrii bodu
    public readonly uint   GeoInstance;     // instance (0 = bez instancí)
    public readonly short  Vrstva;          // vrstva zásobníku (u Uloz), jinak −1
    public readonly ushort MaterialPuvodu;  // materiál, který vytvořila GeoUdalost (před transformacemi; 0 u Odstran)
    public readonly ushort HostitelPuvodu;  // materiál, který GeoUdalost nahradila (0 = byla tam dutina, 0xFFFF = u Uloz žádný)
    public readonly TypProstoru TypHostitele; // Pevne, nebo typ dutiny, do které těleso vniklo
    // transformace
    public readonly ushort PosledniTransformace; // událost, 0xFFFF = žádná
    public readonly byte   PocetTransformaci;    // nasycený na 255
    public readonly byte   Priznaky;             // HraniceOdhad, (etapa D: DeformaceNekonv)
}
```

**Zápis v `Proved`:**

| Operace | Material | Typ | Geo* | MaterialPuvodu | HostitelPuvodu / TypHostitele | Transformace |
|---|---|---|---|---|---|---|
| `Uloz` | materiál vrstvy | Pevne | tato, vrstva | = Material | 0xFFFF / – | vynulovat |
| `Vnikni` | výsledek | Pevne | tato, instance | = Material | předchozí Material / předchozí Typ | vynulovat |
| `Odstran` | 0 | `vysledek.prostor` | tato, instance | 0 | předchozí Material / Pevne | vynulovat |
| `Vypln` | výsledek | Pevne | tato, instance | = Material | 0 / předchozí Typ (dutina) | vynulovat |
| `Transformuj` | `mapa[Material]` | beze změny | **beze změny** | **beze změny** | **beze změny** | Posledni = tato, Pocet + 1 |

**Příklady:**

| Bod | Material | Geo | MaterialPuvodu | HostitelPuvodu | PosledniTransformace |
|---|---|---|---|---|---|
| skarn na kontaktu | skarn | zasobnik, vrstva vápence | cave_limestone | – (vrstva) | skarn_kontakt (1×) |
| žíla v granitu | quartzite | zila_kremen #i | quartzite | granite / Pevne | – |
| žíla ve skarnu | quartzite | zila_kremen #i | quartzite | skarn / Pevne | – |
| krasová dutina | 0, DutinaKras | kras #j | 0 | cave_limestone / Pevne | – |
| láva v dutině | (materiál sopky) | sopka #k | týž | 0 / DutinaKras | – |
| jílová výplň | clay_deposit | vyplen_jeskyne | clay_deposit | 0 / DutinaKras | – |

Skarn tak geometricky zůstává součástí vrstvy vápence a jeho původní materiál je vápenec, přesně jak Jan popsal.
`zdroje` (2.2) čte druh operace `GeoUdalost` a `PocetTransformaci`.

### 3.2 Na vyžádání (volitelné, nic se neukládá)

| Dotaz | Výstup | Kdy implementovat |
|---|---|---|
| `VzdalenostKHranici(p)` | m se znaménkem k hranici geometrického původu, `presna/odhad` | K4 (je potřeba pro kontakt) |
| `Mineralizace(p)` | minerál, obsah ‰, zdroj | až s těžbou |
| `LokalniStav(p)` | zvětrání, rozpukání, alterace (zvodnění dá voda) | až bude potřeba |
| `Historie(p)` | všechny zásahy: `{udalost, instance, operace, materialPred, materialPo, typPred, typPo}` | **volitelné**, až pro inspektor nebo těžbu |

Plná historie materiálů **není povinná** a nikde se neukládá. Protože je vyhodnocení deterministické, `Historie(p)` lze kdykoli
dopsat jako stejný průchod, který zapisuje kroky (invariant: poslední stav = `Vzorek`). `PocetTransformaci > 1` říká,
kdy se vyplatí historii dopočítat. Návrh plný původ neznemožňuje, ale nevyžaduje.

### 3.3 Běh intervalu
`Beh { double Z0, Z1; Vzorek Stav; byte HraniceZ0 }`. `HraniceZ0` = `Presna` (analyticky) | `Certifikovana` (±ε) | `Odhad`
(jen etapa D, záloha). Sloupec = seřazené souvislé běhy přes [zMin, zMax], stejné sousední se slučují, poslední je `NadPovrchem`.
Tenké běhy zůstávají.

### 3.4 Rasterizace (převod spojité geometrie na mřížku, oddělená od geologie)

Rasterizace je **převod** spojitého výsledku GEO2 (intervaly, nebo `Bod`) na jednu zvolenou voxelovou mřížku.
Není součástí geologického modelu. Změna `vyskaDetailnihoVoxelu_m` nebo kroku xy **NESMÍ** změnit geometrii, události,
pravidla, t_det, e_k ani τ. Stejná geologie SMÍ být rasterizována v libovolném rozlišení.

- Výchozí detailní mřížka má výšku buňky `vyskaDetailnihoVoxelu_m` (výchozí 0,125 m). Jiné výšky (0,25 m, 0,5 m, 1 m)
  jsou stejně platné reprezentace téhož modelu.
- Sloupce se berou ve středech buněk cílového xy rozlišení. Buňka k s krokem h: zc = zMin + (k + ½)h, materiál = běh přes zc.
  Je-li |zc − hranice| ≤ ε, dopočítá se `Bod`. Platí **raster == Bod ve středech**.
- **Podvoxelové detaily** (tětiva kratší než h, nebo těleso, jehož průnik s buňkou neobsahuje střed):
  - výchozí pravidlo: **zaniknou**, pokud střed buňky leží jinde (střed vyhrává);
  - dvě různé tětivy v jedné buňce se **sloučí** do materiálu středu; sousední buňky stejného materiálu raster dál nijak nespojuje
    (to už udělaly běhy);
  - volitelně `pokryti` u vybraných událostí (zrudnění, tenké žíly, schváleno 10A): buňka dostane příznak nebo materiál,
    když podíl pokrytí ≥ f, i když střed leží jinde.
- Ztráta nebo sloučení podvoxelových detailů je vlastnost **tohoto převodu**, ne vlastnost GEO2. `Bod` a intervalový sloupec
  (až na záruku t_det, 2.8) spojitou geometrii zachovávají.

### 3.5 Kontext bloku a index těles (beze změny proti v1, schváleno 11A pro K1–K5)
Neměnný, postavený celý předem: zkompilované události, instance s obálkou přes blok + okraj (seřazené), předpočítané konstanty,
index po dlaždicích 8 × 8 m, adaptivní mřížka hranic, trojúhelníky kontaktních ploch vrstev. Okraj ≥ max(R_max + η, dosah
šumu, 1 uzel mřížky). Instance z mřížky světa, takže švy sedí. Nahrazuje `Features` pro každý sloupec, `Klon()`, `_zs`, `_zsPresne`.

### 3.6 Vlákna
Kontext a události jsou jen ke čtení. Pracovní paměť sloupce je lokální (`stackalloc`, `ArrayPool`). Žádné zámky.
Prefixové vyhodnocení pro `hostitel_okoli` je čisté (bez cache), takže je bezpečné.

---

## 4. Kritéria přijetí

| # | Co | Kritérium |
|---|---|---|
| **V1** | chronologie | Janův příklad **bez zlomu** (sedimentace → intruze → skarn → žíla) dává na ručních bodech očekávaný materiál i všechna pole 3.1. Žíla v pásmu skarnu zůstane křemen s `HostitelPuvodu = skarn`. Vypnutí mladší události nezmění body, kde zasahovala jen starší. Žádný bod pod povrchem `Neurceno`. Aktivní `Deformuj` validace odmítne |
| **V2** | pravidla | pro každý řádek 2.4 test „zakázané selže, povolené projde“. Pravidlo 2.3: dutina + `prostor` povolen → zasáhne bez ohledu na `nahrazuje`; dutina + `prostor` prázdný → nezasáhne; materiál → `prostor` se nečte |
| **V3** | kontakt | syntetické kontakty: rovina, koule, krychle s ostrými konvexními i konkávními hranami, deska tenčí než 2w₀, svislá stěna a schod vrstvy, zašuměná vrstva. Tloušťka pásma po normále ∈ [w₀(1−a) − e_k, w₀(1+a) + e_k]; žádná díra (každý bod S s karbonátem vně má pásmo); žádné ztluštění v konkávních rozích; `hostitel_okoli`: kontakt karbonát–negranitoid (nebo granitoid změněný transformací) skarn nedá; dvě tělesa v okruhu rozhodne nejbližší; spojitost přes šev bloku |
| **V4** | intervaly a t_det | proti hustému vzorku **1/64 m**: **0 vynechaných tětiv délky ≥ t_det** (v referenci), konce do ε + 1/64 m. Syntetika: desky s tloušťkou t_det·{0,5; 0,99; 1; 1,01; 2} (včetně podlimitních, které `Bod` musí najít), sklon 0–89°, téměř tečné průniky, elipsoidy s r_min = t_det/2. Fuzz ≥ 10⁵ těles. **Test závorky:** 10⁶ náhodných bodů, V ⊆ těleso ⊆ O bez výjimky. 100 skutečných segmentů. Tětivy < t_det interval SMÍ vynechat, V4 je vykáže zvlášť a ověří, že `Bod` je má. Raster v několika výškách buňky včetně `vyskaDetailnihoVoxelu_m` a 0,25 m: raster == `Bod` ve středech; změna výšky buňky NESMÍ změnit `Bod` |
| **V5** | adaptivní mřížka | chyba hranic proti přesnému `Hranice` po 0,25 m (ne vizuálně): sled vrstev 0 neshod, max \|Δz\| ≤ `tau_m` (výchozí 0,125 m) ve 100 % sloupců mimo uznanou výjimku, vykázat p99 a max. **Výjimka (Jan t1043u):** buňka 0,25 m, ve které vrstva končí (vykliňuje) uvnitř buňky, smí mít neshodu sledu i \|Δz\| > τ; musí nést příznak `HraniceOdhad` a V5 ji vykáže zvlášť (počet sloupců, neshod). Kategorie z `PODKLADY.md` + strmé svahy > 20° + rychlé změny mocnosti. Švy bloků bitově stejné |
| **V6** | výkon | odstraněná práce: vyhodnocení SDF na buňku, vzorky intervalů na tětivu, volání `Hranice`, stavby seznamů útvarů. Čas na boxu jen doplňkově. Telefon později |
| **V7** | determinismus | stejný otisk při 1 a 8 vláknech, bodem i sloupcem, v různém pořadí bloků |
| **V8** | proti staré cestě | rozdílová zpráva po kategoriích |
| **V9** | etapa D | s deformací (testovací zlom, náhodné zlomy) `Sloupec == Bod` na hustém vzorku 1/64 m: 0 neshod mimo ±ε u hranic a mimo tětivy < t_det; zlom posune vrstvy i starší tělesa a nezmění mladší |

---

## 5. Pořadí kroků (upraveno podle R1)

| Krok | Obsah | Ověření | Odhad |
|---|---|---|---|
| **K1** chronologie + pravidla | schéma, kompilátor, validátor (2.4, 2.5; 2.8 bez zákazu tenkých tvarů), dopředný `Bod` **bez deformací** (1.6), pravidlo cíle 2.3, kontakt 2.5 (zatím bodově) | V1, V2, V3 | 12–16 h |
| **K2** prostor + původ | `Vzorek` 3.1 a zápis v `Proved`, `TypProstoru`, voda čte typ. `Historie` volitelně | V1 (pole), test vody | 4–6 h |
| **K3** index + kontext | `KontextBloku`, přesné obálky (čočka, komín), bez `Klon()`, vlákna | V6, V7 | 4–6 h |
| **K4** intervaly | `Beh`, závorky a detekce 2.8 (průniky pro obecnou přímku), kontaktní pásmo v intervalech, rasterizace 3.4 | V4, V7 | 10–12 h |
| **K5** adaptivní mřížka | mřížka + kontrolní bod středu, švy, trojúhelníky kontaktu | V5, V3 znovu | 4–6 h |
| **K6** rozhraní modifikátorů | `IDeformace` (jen rozhraní a validace), bez vyhodnocení | build, V1 (odmítnutí) | 1–2 h |
| **K7** provoz | voda z běhů, náhled M3, V8, kritéria smazání staré cesty (12A) | V8 | podle praxe |
| **D1–D4** deformace | inverze v bodě, úseky sloupce, ověření interval == bod, první zlom (schválí Jan) | V9 | 8–12 h, až po K4 |

Smazání staré cesty (12A) etapu D nepotřebuje.

---

## 6. Přílohy

### 6.1 Tvary dnes → GEO2
`zila` → `deska`, `cocka` / `dome` / `pipe` → `elipsoid`, `kras` → `kapsle_retez` + komora,
skarn → `Transformuj` + `kontakt`, sopka → `sopka_nitro`, vrstvy → `zasobnik`. Řádky v `KOD-E84.md`.

### 6.2 Bezpečné intervaly
Celá definice je v 2.8. V1 uváděla „vzorkovat krokem ≤ 1/16 m nebo s mezí L“, což **neplatí jako záruka** a je nahrazené
krokem h = t_det/2 v mezivrstvě závorky. V2 ještě používala název `minTloustkaTelesa_m` a validační chybu za tenkost;
v3 je to `minTloustkaDetekce_m` bez zákazu podlimitní geometrie.

### 6.3 Mřížka hranic
Adaptivní 1 / 0,5 / 0,25 m + kontrolní bod středu. Měřeno: max 0,16 % chybných buněk (78 segmentů, `mereni/vystup3.csv`),
ale odchylka hranice při stejném sledu až 1,34 m. Bez kontrolního bodu středu by `tau_m` = 0,125 m nesplnila. Je to první měření K5.
`tau_m` je samostatný parametr (0.2), nezávislý na výšce voxelu.
**K5 (Jan 2026-11-27 t1043u):** výchozí je zaručená varianta – kontrola všech bodů 0,25 m v buňkách 1 m (V5 bez výjimek mimo vykliňování), dražší kontext je přijatelný (jde jen o generování). Rychlá varianta (střed + středy hran) zůstává volbou `MoznostiKompilace.KontrolaMrizkyPo025 = false`. Buňky s vykliňováním uvnitř 0,25 m = uznaná výjimka V5 s `HraniceOdhad`. Výchozí výstup `KontextBloku.Sloupec` = běhy (K4).

---

## 7. Rozhodnutí

### 7.1 Schválená (1–13: Jan 2026-11-27 11:37 t1028u, varianta A; R1–R5 a O1–O3: 11:54 t1029u)

Do konečného dokumentu (`docs/sjednoceni/…`) se zapíší až po Janově potvrzení úprav v3.

| # | Rozhodnutí (A) | Upřesnění |
|---|---|---|
| 1 | jeden model, tři druhy operací | – |
| 2 | shodné stáří = chyba validace | – |
| 3 | granitoid zůstane vrstvou, intruze později | příklad intruze `aktivni: false` |
| 4 | sourozenci `unie`, menší instance | – |
| 5 | transformace se řetězí | – |
| 6 | hloubka od finálního povrchu | – |
| 7 | kontakt eukleidovsky k primitivu bez šumu, šum jen v šířce | R5: jednotná definice, tolerance e_k, strana, `hostitel_okoli`, víc těles |
| 8 | slovník pravidel a bezpečné výchozí | R3: jedno pravidlo cíle, tabulka validace |
| 9 | původ: vzorek + přepočet historie | R4: vzorek rozlišuje aktuální materiál, geometrický původ a transformaci; historie volitelná |
| 10 | rasterizace středem, `pokryti` jen vybraně | v3: podvoxelové detaily zanikají / se slučují podle 3.4, odděleně od geologie |
| 11 | deformace ve sloupci po afinních úsecích + záloha | R1: přesunuto do etapy D |
| 12 | kritéria smazání staré cesty | nezávisí na etapě D |
| 13 | kritéria a pořadí kroků | R1: kap. 5, V4 podle t_det, V9 |

### 7.2 Rozhodnutí O1–O3 a princip 4 (Jan 2026-11-27 11:54 t1029u)

| # | Rozhodnutí | Znění v kontraktu |
|---|---|---|
| **O1** | Skarnová událost jen v karbonátech (vápence, dolomity). Transformace ve svoru, amfibolitu a jiných horninách = samostatné budoucí události, ne rozšíření pravidel skarnu | příklad `skarn_kontakt` (2.7) |
| **O2** | Geometrie a voxel jsou oddělené. Tělesa tenčí než 0,125 m jsou dovolená kdekoli. 0,125 m je výchozí mez záruky detekce intervalů, ne zákaz. Žádná chyba validace za tenkost. `Bod` je vždy přesný. `okraje_se_zuzuji` se nevyžaduje | 0.2, 2.8, 3.4 |
| **O3** | Čtyři samostatné parametry, všechny výchozí 0,125 m: `minTloustkaDetekce_m`, `tolerancKontaktu_m`, `tau_m`, `vyskaDetailnihoVoxelu_m`. Změna rozlišení voxelů nemění geometrii ani ostatní pravidla | 0.2, 2.7 |
| **4** | GEO2 je zdroj spojité geologické geometrie a její historie. Voxelová mřížka je jen jedna z možných reprezentací | 0.2 |


### 7.3 Rozhodnutí z V8 (Jan 2026-11-28 t1046u)

Zdroj: zpráva V8, `docs/sjednoceni/reporty/geo2-v8-prop.md` (větev `geo2-v8-rozdily`). Rozdíl proti staré cestě GEO1 je v těchto případech **záměrná změna sémantiky**, ne chyba GEO2:

| Pravidlo | Znění (GEO2 platí) | Starý GEO1 | Rozsah ve V8 (1,476 mld. buněk, 11 bloků, 1 seed) |
|---|---|---|---|
| **HostitelSkarn** | Skarn vzniká jen v hostiteli, který pravidla události skarnu připouštějí (materiál v bodě, `HostOk`). Těleso (dóm, kras), které skarn jako hostitele nepřipouští, ho nenahrazuje | vloží dóm / kras do hostitele „vrstva“ i přes skarn | 36 820 buněk (0,41 % rozdílů) |
| **PravidloZdroje** | Událost smí odebrat jen zdroje z `zdroje.telesa` (2.3). Kras (nejmladší) nesmí odebrat dóm | vítěz = nejmenší SDF, kras dóm odebere | 2 872 buněk (0,03 %) |
| **PoradiTeles** | Překryv těles rozhoduje **stáří** události (2.7, 1.3), ne nejmenší SDF (komín > čočka / dóm / žíla) | nejmenší SDF | 1 868 buněk (0,02 %) |

**Kritérium smazání staré cesty (část kap. 7.1 bod 12, krok K7):** V8 hlásí **0 otevřených buněk** (rozdíl bez vysvětlené příčiny) na pevné sadě bloků pro nejméně **3 seedy světa × 11 bloků**; každá nová příčina musí být vysvětlená a zařazená (zlepšení / dle kontraktu / tolerance). **Výkon (Jan 2026-11-28 t1047u):** limit „výchozí GEO2 ≤ ×1,5 GEO1“ je jen **doporučený cíl**, ne pevné kritérium smazání staré cesty. Měření se vykazuje (medián, rozptyl, vzdálenost od doporučení), smazání se kvůli němu nezastavuje.

Ostatní kritéria (voda a M3 na běhy, otisky GEO1 → GEO2) zůstávají nepotvrzená do dalšího rozhodnutí Jana.

Otevřené otázky k tomuto kontraktu **nezůstávají**. v3 schválena 2026-11-27 (Jan t1032u, t1033u).

---

## 8. Vývoj katalogu hornin (v3, schváleno 2026-11-27)

Katalog materiálů (`materials-catalog-v1.json`, vlastník Willage-backend) se bude měnit. GEO2 MUSÍ přežít přidání i vyřazení hornin bez přečíslování a bez změny uložených světů.

1. **Počet hornin není pevný.** Kód GEO2 NESMÍ předpokládat počet ani rozsah id (dnes 75 záznamů, `byte` id ≤ 255 je limit formátu, ne katalogu).
2. **Stabilní číselná id.** Id materiálu se po přidělení **nikdy nerecykluje ani nepřečísluje**. Klíč (`key`) je také stabilní. Nové horniny dostanou nové id.
3. **Vyřazení místo smazání.** Odebraná hornina zůstane v katalogu se stavem **vyřazená** (`idStatus: "retired"`) a **povinnou náhradou** (`replacedBy`: id aktivní horniny). Náhrada slouží:
   - starým událostem a pravidlům, která na vyřazenou horninu odkazují (kompilátor odkaz přesměruje na náhradu a vypíše varování);
   - uloženým ostrovům, výřezům a rozdílům buněk (při načtení se id vyřazené horniny čte jako náhrada).
   Řetěz náhrad se sleduje až k aktivní hornině. Cyklus je chyba katalogu.
4. **Pravidla preferují skupiny.** `nahrazuje`, `hostitel_okoli` a podobná pravidla SMÍ jmenovat materiály, ale přednost mají skupiny katalogu (`skupina`). **Nová hornina ve skupině automaticky spadne pod pravidla** bez úpravy událostí.
5. **Svět nemusí použít všechny horniny skupiny.** Pravidlo je filtr: působí jen na materiál, který v bodě skutečně je. Hornina skupiny, která ve světě nebo oblasti chybí, nic nezpůsobí a nic nevyžaduje.
6. **Verze katalogu je součástí otisku světa.** Otisk (seed + parametry + verze generátoru) nese i verzi a otisk katalogu (hash id, klíčů, skupin, stavů a náhrad). Jiný katalog = jiný svět, i když se kód nezměnil.
7. **Validace:**
   - odkaz (v událostech, `nikdy`, mapě transformace, výsledku) na **vyřazenou horninu bez náhrady** = **chyba**;
   - náhrada, která není aktivní ani nevede k aktivní, = chyba katalogu;
   - neznámý klíč nebo skupina = chyba (2.4);
   - odkaz na vyřazenou horninu s náhradou = varování a přesměrování.

Změna samotného katalogu (stav `retired`, pole `replacedBy`) je změna schématu Willage-backend. Zavede se po dohodě s Willage-backend. Do té doby GEO2 čte `idStatus` a `replacedBy`, pokud v katalogu jsou, a jinak bere všechna id jako aktivní (dnešní stavy `active` a `todo_open_range`).
