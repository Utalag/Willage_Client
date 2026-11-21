# PROP – Krok 2, úpravy po rozhodnutích Jana (2026-11-21)

Větev `gen-v1-krok02-funkce-sveta` (HEAD 8e21cb0). Napsáno 2026-11-21 21:15 SEČ, před změnou kódu. Do `main` nic nejde, krok 3 se nezačíná.

## Proč
Po testech kroku 2 Jan rozhodl čtyři body ke stropu sklonu, tvaru hor a poloze sopky (2026-11-21) a večer (21:10 SEČ) ještě pátý k měřítku biomů. Výchozí hra se nemění: nový kód hra nevolá.

## Rozhodnutí (platí)
1. **Hory pod stropem sklonu se roztáhnou do šířky**, aby si zachovaly plnou výšku (hornatina ~24 m, masiv ~12 m). Nezplošťovat amplitudu. Strop sklonu každého biomu platí dál.
2. **V přechodu mezi biomy** platí **vážený průměr stropů** podle vah mísení, ne strop strmějšího biomu.
3. **Drobné tvary** (skály, detail masivu E87) do výšky parametru `detail_max_m` (výchozí 2 m) **smí strop překročit**. Strop platí pro celkový tvar hory. Detail masivu se obnoví (nesmí zmizet ořezem).
4. **Výchozí svět 3 × 3 zůstane uprostřed** maxima (bloky 14–16). Sopka se přiblíží, ať je vidět z výchozího světa (střed těsně vně 3 × 3). Determinismus (stejný seed + parametry → stejný svět) zůstává.
5. **Biomy jsou moc rozdrobené.** Zvětšit oblasti: měřítko mapy biomů je parametr (cíl typické oblasti v řádu stovek metrů) a ostrovy pod minimální plochou (parametr) se sloučí do souseda. Spojitost švů a determinismus zůstávají.

## Plán
1. `svet_fn.gd`: když se převýšení pod strop nevejde, snížit frekvenci šumu (prodloužit vlnovou délku) a nechat plnou amplitudu; totéž u masivu (ne u detailu).
2. `strop_tan`: vážený průměr `Σ w_i · tan(strop_i)`; v kuželu sopky dál strop sopky.
3. Parametr `detail_max_m` (2 m). Amplituda detailu masivu = min(zadaná, `detail_max_m`), bez ořezu stropem. `vyska_tvar` = výška bez detailu (pro test celkového tvaru).
4. Parametr vzdálenosti sopky od okraje výchozího 3 × 3 (výchozí 100 m vně čtverce). První sopka na obvodu tohoto rámu, úhel ze seedu; další dál podle rozteče. `start_blok` beze změny.
5. Parametry `biom_meritko_m` (výchozí 768 m) a `biom_min_plocha_m2` (výchozí 90 000 m² ≈ 300 × 300 m). Typ stanice mapy biomů se bere z hrubé mřížky o rozteči měřítka (stanice zůstanou po 256 m, kvůli nepravidelnému okraji). Komponenty pod prahem se sloučí do typově nejčastějšího souseda (při shodě nižší id typů). Sopka si dál vezme stanici až po sloučení.
6. Testy: švy 0 m; sklon celkového tvaru pod váženým stropem (překročení detailem jen zaznamenat: maximum a kolik); sopky včetně vzdálenosti od středu 3 × 3; determinismus ve 2 procesech; čas; regrese kroku 1 (`voda_e66` 0 neshod, `port_studie` 0 změn, otisk `zaklad_v1` cc9e412759114af1). Mapy 4096 m seed 49 a 50 před/po změně biomů, počet úlomků a medián/typická velikost oblasti. Obrázky do `godot-prototyp/shots/krok02/`. Rozhodnutí zapsat do `01`, `04` a označit v `03` (větev `sjednoceni`).

## Výchozí stav biomů (před změnou, seed 49 / 50, mřížka 8 m)
Převažující biom: podíl ploch 0,30 / 0,08 / 0,36 / 0,20 / 0,06 a  (seed 50 se liší). Souvislé oblasti (4-sousedé): seed 49 **118 úlomků**, medián plochy 58 048 m² (√ ≈ **241 m**); seed 50 **112 úlomků**, medián 60 768 m² (√ ≈ **247 m**). To je ten rozdrobený stav, proti kterému jdeme.

## Výsledky
Doplní se po testech do tohoto souboru a do [`krok02.md`](krok02.md).
