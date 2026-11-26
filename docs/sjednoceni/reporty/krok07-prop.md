# PROP – Krok 7: klima a biomy přes mapu planety

Větev `gen-v1-krok07-klima-biomy` z `main` 5e4f1f0 (tag `gen-v1-krok06g`). Napsáno 2026-11-26 12:35 SEČ, před experimenty. Bez merge do main.
Zadání: plán 04, krok 7 (Jan 2026-11-26 11:06 / 11:15): teplotní pásma (šířka a výška), srážky včetně srážkového stínu hor, pouště, výchozí klima planety; voda se přepočítá s klimatem. Upřesnění Jan 12:26: **klima smí zesílit, oslabit nebo úplně vzít zdroje vody (prameny, vodníky, dnešní průtok řek), ale eroze zůstává jako pozůstatek minulosti** – mapa eroze se s klimatem nepřepočítává a její klíč keše se nemění. V pouštích tak zůstanou suchá údolí a koryta.

## Co už existuje (znovu použít, nenavrhovat znovu)
- Krok 2: `klima_presety.csv` + `Svet/KlimaPresety.cs` – preset (`mirne` = identita, příklady `poust`, `step`, `tundra`, `ledovec`) mění **reliéf** před generováním. Zůstává jako ruční volba; id presetu (`ParametrySveta.Klima`) teď vybírá i **výchozí klima planety** v novém `klima_v1.json`. `KlimaKVoda` z presetu C# zatím nikde nepoužívá (poznámka, beze změny).
- Reliéfní biomy (`MapaBiomu`: nížina, mokřad, pahorkatina, hornatina, sopečná) jsou **samostatná osa** (rozhodnutí 1.15). Nový klimatický biom je druhá osa, reliéfní biomy se nemění.
- Krok 6: mapa eroze planety 32 m (torus 31 360 × 15 616 m), odtok = moře, D8 příjemci, plocha povodí A, koryta A ≥ 0,25 km², vodníci v pramenech toků v kopcích (váha kopců ≥ 0,5, 10 l/s/km²), keš WGER v2 s klíčem SHA-256.
- Krok 4: prameny ze seedu (`Voda/Prameny.cs`, buňka 24 m, pravděpodobnost 0,6, výkon podle druhu).

## Návrh
Nová složka `cs/Willage.Gen/Klima` (malé soubory):
- `ParametryKlimatu` – vše laditelné, `godot-prototyp/data/v1/klima_v1.json`, výchozí klima planety podle id presetu (`mirne`, `poust`, `step`, `tundra`, `ledovec`).
- `Zemepis` – zeměpisná šířka na torusu: `u = frac((y − y_rovník)/Py)`, šířka = 90° · (1 − cos 2πu)/2 (hladká, periodická, rovník a pól jednou). *(Změněno při experimentu, viz Výsledky: lineární 180° · min(u, 1 − u).)* Rovník se posadí tak, aby start 3 × 3 ležel na `StartSirkaDeg` (výchozí 45°, mírné pásmo).
- Teplota: `T = T_pól + (T_rovník − T_pól) · cos(šířka)` − výškový gradient · (výška − hladina moře). Herní měřítko: planeta je vodorovně silně zmenšená a reliéf má jen ~60 m, proto výškový gradient je herní parametr (výchozí 0,05 °C/m, reálně 0,0065).
- Srážky: základ podle šířky (vlhký rovník, suché subtropy ~30°, vlhčí mírné pásmo ~55°, suché póly) × srážky planety (mm/rok). Vlhkost se nese **větrem po řádcích** (pasáty z východu do 30°, západní větry 30–60°, polární východní nad 60°; přepínač jednoho směru). Nad mořem se vlhkost doplňuje, nad pevninou ubývá (kontinentalita) a na návětrném svahu (stoupání vyhlazeného terénu) prší víc a vlhkost rychleji ubývá → **srážkový stín** za horami. Dva průchody kolem torusu (periodické), lehké vyhlazení napříč řádky.
- Odtok: výpar podle Turca (`ET = P / √(1 + (P/L)²)`, `L = 300 + 25T + 0,05T³`), odtok `R = P − ET`. Váha odtoku `w = R / 315,36 mm` (= 10 l/s/km², dnešní konstanta), takže v typickém mírném klimatu w ≈ 1.
- Klimatický biom (Whittaker + Köppenova mez suchosti `P_mez = 20·T + 140 mm`): moře, led (T < −8), tundra (T < 0), poušť (P < 0,5 · P_mez), step (P < P_mez), tajga (T < 5), mírný les, mírný deštný les (P ≥ 2000), savana (T ≥ 20), tropický deštný les (T ≥ 20, P ≥ 1800). Prahy v JSON.
- `HydrologieKlimatu` (nad hotovou mapou eroze, **eroze beze změny**): dnešní průtok = akumulace w · plocha po stávajících příjemcích D8. Koryto z eroze je **aktivní**, když dnešní A_k ≥ A_krit, jinak **suché koryto** (pozůstatek). Tok bez koryta (A_k ≥ A_krit mimo koryto) se jen spočítá a ukáže. Vodníci = hlavy aktivní sítě v kopcích, Q = A_k · 10 l/s/km².
- Prameny ze seedu: háček `Prameny.Klima` (null = vypnuto). Pravděpodobnost buňky × w (strop 0,95) a výkon × w (w omezené `PramenWMax`).
- Bodové dotazy `KlimaSvetaFn` (T, P, w, biom) pro funkci světa, napojené v `KonfiguraceSveta.Sestav` → `SvetKrok06.Klima`.
- Přepínač `ParametrySveta.KlimaKrok07`, **výchozí vypnuto** do Janova ano. Vypnuto = beze změny kódu cest (otisky stejné). Klíč klimatu = SHA-256 (klíč mapy eroze + kanonické parametry klimatu) – pro pozdější keš/editor; klíč eroze se nemění.

## Hypotézy
- H1: s vypnutým klimatem otisky seedu 49 beze změny: `Krok5()` krok 3 c8eeb7964d1ddd85, voda 7714d1a1d34e00ad, 18 pramenů; výchozí s erozí 9f32311e046f8b6a / 8e239a68c6d01be0, 20 pramenů; mapa 800d420bb00047de, 92 vodníků.
- H2: se zapnutým klimatem mapa eroze a krok 3 stejné (eroze je pozůstatek), mění se jen voda (prameny, vodníci).
- H3: za vyššími hřbety po větru je méně srážek (stín); pouště hlavně v subtropech (~20–35°) a ve stínu, u mírné planety pod ~15 % pevniny.
- H4: v poušti část koryt suchá; ve vlhkém pásmu aktivní síť hustší. Vodníků se může změnit počet oběma směry.
- H5: výpočet klimatu < 1 s na planetu (8 vláken).

## Měření
Testy C# (main i větev), otisky vyp/zap, podíly biomů a pouště pro seedy 49, 2, 4, 8, srovnání toků a vodníků před/po, obrázky v `godot-prototyp/shots/krok07/` (teplota, srážky se stínem, biomy, voda před/po se suchými a aktivními koryty), `git merge-tree` proti main. Negativní výsledky zapsat.

## Výsledky (2026-11-26 12:45 SEČ)

### Změny návrhu během experimentu (negativní výsledky)
- **Hladká šířka (1 − cos 2πu)/2 – zamítnuto.** Plocha se hromadí u pólu a rovníku (arkussinové rozdělení): tundra 29 % pevniny, průměrné w 0,38, 54 % koryt suchých i na „mírné“ planetě. Nahrazeno lineární šířkou 180° · min(u, 1 − u) (pásma stejně široká; teplota spojitá, na pólu jen zlom gradientu).
- **První kalibrace mírné planety (T 24 / −6 °C, 800 mm, kontinentalita 12 km) – příliš suchá.** Nyní 26 / −4 °C, 1000 mm, 20 km.
- **Skok srážek na hranicích větrných pásů** (30°, 60°: vítr se otočí) – viditelný pruh v mapě. Doplněn plynulý přechod `PrechodPasuDeg` 4° (směs obou směrů).
- **Dva průchody kolem planety nestačí** na periodické řešení (zrcadlový test 0,09). Nyní průchody do ustálení (nejvýš 12, odchylka < 1e-6).
- Koryta z eroze v moři (příznak koryta leží i na mořských uzlech) se nehodnotí; jinak by se počítala jako „suchá“.

### Otisky seedu 49
| konfigurace | mapa eroze | krok 3 | voda 14,14 | prameny 3 × 3 | vodníků |
|---|---|---|---|---|---|
| `Krok5()` | – | c8eeb7964d1ddd85 | 7714d1a1d34e00ad | 18 | – |
| výchozí s erozí, **klima vyp** | 800d420bb00047de | 9f32311e046f8b6a | 8e239a68c6d01be0 | 20 | 92 |
| výchozí s erozí, **klima zap** | 800d420bb00047de | 9f32311e046f8b6a | **904afe6c9e9c03d6** | 20 | **84** |

H1 a H2 potvrzeny: s vypnutým klimatem vše beze změny, se zapnutým se nemění mapa eroze ani geologie (klíč keše eroze d61ed38d70cfced9 stejný), mění se jen voda. Otisk klimatu `e032a25cac6e8cf9` (stejný při 1 i 8 vláknech), klíč klimatu a6271b28c59bc9fc. Start: mírný les, T 15,8 °C, P 1049 mm, w 1,12.

### Mírná planeta, 4 seedy (podíl pevniny)
| seed | poušť | step | mírný les | savana | tundra | tajga | trop. les | T °C | P mm (průměr) | w |
|---|---|---|---|---|---|---|---|---|---|---|
| 49 | 4,2 | 8,7 | 42,6 | 16,3 | 11,9 | 12,8 | 3,3 | −5,8…26,0 | 761 | 0,72 |
| 2 | 7,6 | 8,2 | 40,9 | 14,5 | 12,1 | 13,1 | 3,3 | −6,4…26,0 | 715 | 0,65 |
| 4 | 5,9 | 8,6 | 40,4 | 16,8 | 11,9 | 12,9 | 3,2 | −5,7…26,0 | 720 | 0,62 |
| 8 | 5,5 | 7,0 | 42,5 | 14,9 | 12,5 | 13,5 | 3,8 | −6,2…26,0 | 765 | 0,74 |

Led 0 %, mírný deštný les 0,2–0,3 %. Pouště v subtropickém pásu (~28°) a ve stínu za hřbety (H3 ano). Srážkový stín (P / základ pásma): návětří 1,20–1,30, závětří za hřbetem ≥ 8 m 0,59–0,66, ostatní 0,71–0,77. Klima 23–33 ms na planetu (H5 ano).

### Voda před / po (mírná planeta)
| seed | koryta z eroze | aktivní | suchá | tok mimo koryto | vodníci před → po | Q součet l/s |
|---|---|---|---|---|---|---|
| 49 | 9691 | 70,9 % | 29,1 % | 620 | 92 → 84 | 266 → 242 |
| 2 | 10454 | 66,9 % | 33,1 % | 737 | 94 → 80 | 271 → 234 |
| 4 | 10614 | 66,2 % | 33,8 % | 599 | 114 → 87 | 332 → 255 |
| 8 | 9606 | 70,6 % | 29,4 % | 656 | 103 → 98 | 300 → 278 |

Vodníci se přesouvají: do 160 m od původního zůstane jen ~1/3 (49: 32 zůstalo, 60 zaniklo, 51 nových). Z pouští a stepí mizí, přibývají v tropickém deštném lese (49: 3 → 15). Prameny ze seedu (čtverec 384 m): poušť 8 → 0, mírný les (w 2,6) 10 → 17 (46 → 151 l/s), tropický les (w 2,2) 18 → 27, tundra 0 → 0, start (w 1,1) 20 → 20 (52 → 74 l/s). H4 ano.

### Klima planety (seed 49, stejná eroze)
| planeta | poušť | step | led | tundra | w | aktivní koryta | vodníci |
|---|---|---|---|---|---|---|---|
| mírné | 4,2 | 8,7 | 0 | 11,9 | 0,72 | 70,9 % | 84 |
| step | 19,4 | 60,3 | 0 | 0 | 0,06 | 7,6 % | 3 |
| poušť | 91,5 | 8,2 | 0 | 0 | 0,00 | 0 % | 0 |
| tundra | 3,0 | 6,6 | 31,9 | 29,2 | 0,53 | 65,5 % | 45 |
| ledovec | 0 | 0 | 69,5 | 30,5 | 0,58 | 67,0 % | 54 |

Poušť: všechna koryta suchá, žádný vodník, žádný pramen – jen suchá údolí (záměr Jan 12:26). Negativní: na ledové planetě Turc dává odtok skoro = srážky (malý výpar), takže tam teče víc než ve stepi; zamrzání a tání (povrchové jevy) zatím nejsou.

### Testy
`main` 5e4f1f0: **OK 110, chyb 0**. Větev: **OK 141, chyb 0** (31 nových testů kroku 7).

### Obrázky (`godot-prototyp/shots/krok07/`)
`teplota_seed49.png`, `srazky_stin_seed49.png` (mapa + řez na 45° s terénem a srážkami), `biomy_4_seedy.png` (49, 2, 4, 8), `voda_pred_po_seed49.png` a `voda_pred_po_seed2.png` (modře aktivní, oranžově suchá koryta, fialově tok bez koryta, vodníci), `planety_klima_seed49.png` (mírné / step / poušť / ledovec).
