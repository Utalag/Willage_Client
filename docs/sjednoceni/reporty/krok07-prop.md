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
- `Zemepis` – zeměpisná šířka na torusu: `u = frac((y − y_rovník)/Py)`, šířka = 90° · (1 − cos 2πu)/2 (hladká, periodická, rovník a pól jednou). Rovník se posadí tak, aby start 3 × 3 ležel na `StartSirkaDeg` (výchozí 45°, mírné pásmo).
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

## Výsledky
(doplní se)
