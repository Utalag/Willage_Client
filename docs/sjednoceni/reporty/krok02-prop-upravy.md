# PROP – Krok 2, úpravy po rozhodnutích Jana (2026-11-21)

Větev `gen-v1-krok02-funkce-sveta` (HEAD 8e21cb0). Napsáno 2026-11-21 21:15 SEČ, před změnou kódu. Do `main` nic nejde, krok 3 se nezačíná.

## Proč
Po testech kroku 2 Jan rozhodl čtyři body ke stropu sklonu, tvaru hor a poloze sopky (2026-11-21). K měřítku biomů nejdřív chtěl větší oblasti (21:10), v 21:21 upřesnil, že současné jsou asi v pořádku — varianta se proto jen srovná za vypnutým přepínačem. Výchozí hra se nemění: nový kód hra nevolá.

## Rozhodnutí (platí)
1. **Hory pod stropem sklonu se roztáhnou do šířky**, aby si zachovaly plnou výšku (hornatina ~24 m, masiv ~12 m). Nezplošťovat amplitudu. Strop sklonu každého biomu platí dál.
2. **V přechodu mezi biomy** platí **vážený průměr stropů** podle vah mísení, ne strop strmějšího biomu.
3. **Drobné tvary** (skály, detail masivu E87) do výšky parametru `detail_max_m` (výchozí 2 m) **smí strop překročit**. Strop platí pro celkový tvar hory. Detail masivu se obnoví (nesmí zmizet ořezem).
4. **Výchozí svět 3 × 3 zůstane uprostřed** maxima (bloky 14–16). Sopka se přiblíží, ať je vidět z výchozího světa (střed těsně vně 3 × 3). Determinismus (stejný seed + parametry → stejný svět) zůstává.
5. **Biomy — jen srovnání (Jan 2026-11-21 21:21).** Nejdřív (21:10) chtěl větší oblasti, večer upřesnil, že současné jsou asi v pořádku. Varianta větších oblastí se dokončí za přepínačem `biom_velke_oblasti` (**výchozí vyp**). Hlavní testy běží s výchozím měřítkem. Do dokumentace se to jako rozhodnutí nezapisuje, jen jako srovnaná možnost.

## Plán
1. `svet_fn.gd`: když se převýšení pod strop nevejde, snížit frekvenci šumu (prodloužit vlnovou délku) a nechat plnou amplitudu; totéž u masivu (ne u detailu).
2. `strop_tan`: vážený průměr `Σ w_i · tan(strop_i)`; v kuželu sopky dál strop sopky.
3. Parametr `detail_max_m` (2 m). Amplituda detailu masivu = min(zadaná, `detail_max_m`), bez ořezu stropem. `vyska_tvar` = výška bez detailu (pro test celkového tvaru).
4. Parametr vzdálenosti sopky od okraje výchozího 3 × 3 (výchozí 100 m vně čtverce). První sopka na obvodu tohoto rámu, úhel ze seedu; další dál podle rozteče. `start_blok` beze změny.
5. Přepínač `biom_velke_oblasti` (výchozí vyp). Při zapnutí: typ stanice z hrubé mřížky `biom_meritko_m` (768 m) a ostrovy pod `biom_min_plocha_m2` (90 000 m² ≈ 300 × 300 m) se sloučí do typově nejčastějšího souseda. Výchozí mapa typů zůstává po stanicích 256 m.
6. Testy: švy 0 m; sklon celkového tvaru pod váženým stropem (překročení detailem jen zaznamenat: maximum a kolik); sopky včetně vzdálenosti od středu 3 × 3; determinismus ve 2 procesech; čas; regrese kroku 1 (`voda_e66` 0 neshod, `port_studie` 0 změn, otisk `zaklad_v1` cc9e412759114af1). Hlavní testy s výchozími biomy. Srovnání výchozí vs. větší oblasti (seed 49 a 50): mapy vedle sebe, počet úlomků a medián/typická velikost. Obrázky do `godot-prototyp/shots/krok02/`. Rozhodnutí 1–4 zapsat do `01`, `04` a označit v `03` (větev `sjednoceni`); větší biomy tam jen jako srovnaná možnost, ne jako rozhodnutí.

## Výchozí stav biomů (současné měřítko, seed 49 / 50, mřížka 8 m)
Převažující biom seed 49: podíl ploch 0,30 / 0,08 / 0,36 / 0,20 / 0,06. Souvislé oblasti (4-sousedé): seed 49 **118 úlomků**, medián plochy 58 048 m² (√ ≈ **241 m**); seed 50 **112 úlomků**, medián 60 768 m² (√ ≈ **247 m**). Varianta větších oblastí se proti tomuto měří, ale výchozí zůstává tento stav (Jan 21:21).

## Poznámka k šířce přechodu
Po zapnutí váženého stropu a plné výšky hor (včetně masivu) byl původní přechod 192 m v pásu mokřad/hornatina moc prudký (celkový tvar na světě až 6,7° nad stropem). Výchozí `biom_prechod_m` je proto **320 m**, ať skok výšky zůstane pod stropem. Přiřazení typů a velikost oblastí se tím nemění, jen jsou okraje měkčí. Není to nové rozhodnutí Jana, jen nutné doladění k bodům 1 a 2.

## Výsledky (2026-11-21 21:46 SEČ)
Všechna kritéria kroku 2 po úpravách prošla, regrese kroku 1 je beze změny. Podrobnosti jsou v [`krok02.md`](krok02.md), oddíl „Úpravy po rozhodnutích Jana“.

- Převýšení: hornatina 24 m (vlna 680 m), masiv 12 m, detail 0,75 m. Výchozí 3 × 3 uprostřed, nejbližší sopka 102 m od okraje / 362 m od středu.
- Švy 0 m. Celkový tvar na celém světě pod váženým stropem (rezerva 3,60°, 0 vzorků nad). Povrch s detailem taky zůstal pod stropem (rezerva 1,64°); překročení je povolené, v měření nenastalo.
- Determinismus `04c1d51d4f0cc3d4` ve dvou procesech. `voda_e66` d7aedf3a6d9d10e8 → 63d7b89a91385a79, 0 neshod; `port_studie` 0 změn; `zaklad_v1` cc9e412759114af1.
- Výchozí biomy seed 49/50: 100 a 99 úlomků, medián √ 211 m a 203 m. Varianta `biom_velke_oblasti` (srovnání): 19 a 26 úlomků, medián √ 697 m a 405 m.
- `biom_prechod_m` 192 → 320 m, jinak by tvar v přechodu mokřad/hornatina lezl až 6,7° přes vážený strop.
