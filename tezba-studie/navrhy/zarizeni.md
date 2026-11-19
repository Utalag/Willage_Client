# Základní stroje, stavby a zařízení na zpracování

Stav: **návrh** (T03, Jan 19. 11. 2026 14:49). Čeká na Jana. Herní kód se nemění.

Navazuje na strom operací v [strom-hornin.md](strom-hornin.md) (T02) a na výrobní jednotky zmíněné v [katalog-materialu.md](katalog-materialu.md) (T01). Zdroje jsou značky [n] podle `ZDROJE.md` této studie.

Účel: ke každé operaci stromu přiřadit aspoň jednu reálnou jednotku — nástroj, stroj, stavbu nebo zařízení — a uzavřít smyčku katalogu (jednotka se staví z materiálů, které tyhle jednotky samy vyrábějí). Koupitelný recept (hypotéza 13:39) se ladí právě tady: teplota, čas, poměry.

## Pokrytí stromu

Ve stromu je **20 operací** a **550 hran**; pokrytých hran je **550**. Zařízení je **25** (z toho 1 mimo strom: hamr).

| operace | hrany | zařízení |
|---|---:|---|
| `slozeni` (typické minerální složení (orientační, ne herní výnos)) | 260 | `stul_mineralogie` |
| `tezba` (výchozí výnos po zpracování buňky (T01, ‰ objemu)) | 181 | `nastroj_tezba` |
| `odpovida` (minerál se po uvolnění stává touto surovinou) | 27 | `stul_mineralogie` |
| `drtit` (drcení) | 10 | `stoupa`, `mlyn` |
| `brousit` (broušení / leštění) | 3 | `brusna_dilna` |
| `palit` (pálení / kalcinace) | 8 | `vapenka`, `pec_sadra`, `milir`, `pec_cement` |
| `prazit` (pražení (sulfidy, rumělka)) | 2 | `prazirna` |
| `hasit` (hašení vápna) | 1 | `hasici_jama` |
| `michat` (míchání malty / směsi) | 2 | `dilna_zednicka` |
| `tavit` (tavení kovu) | 29 | `pec_hrncirska`, `kelimek`, `dymacka` |
| `tavit_sklo` (tavení skla) | 3 | `pec_sklarska` |
| `palit_keramiku` (výpal keramiky / porcelánu) | 4 | `pec_hrncirska` |
| `palit_cihly` (výpal cihel) | 2 | `cihelna` |
| `destilovat` (destilace) | 1 | `alembik`, `solivar` |
| `louzit` (loužení) | 6 | `louzici_kade` |
| `koksovat` (koksování uhlí) | 2 | `koksovna` |
| `ryzovat` (ryžování / ryzí kov) | 1 | `splav` |
| `slevat` (slévání slitin) | 2 | `kelimek` |
| `cementovat` (nauhličení / kalení oceli) | 4 | `kovarna` |
| `karbonatace` (karbonatace (vápno zpět na kalcit) — záměrný cyklus) | 2 | `stavba_vapenna` |

## Podle věku

### Primitivní

Pravěk až starověk: ruka, oheň, jednoduchá jáma nebo pec z hlíny a kamene.

#### Těžební nářadí

- **Typ:** nástroj. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka.
- **Dovednost:** bez zvláštní dovednosti (běžná práce / třída nástroje T01).
- **Operace stromu:** `tezba`.
- **Procesy:** —.
- **Vstupy:** libovolná hornina.
- **Výstupy:** stavební kámen / kvádr, štěrk / drcený kámen, písek, jíl, hlína, černé uhlí, sůl, jalovina.
- **Staví se z:** dřevo (vnější vstup), stavební kámen / kvádr, měď (kov), bronz, železo (kov), ocel.
- **Ladění receptu:** cas, volba_nastroje.
- **Jak:** Rýč, špičák, kladivo a později kovový krumpáč, kterými se buňka horniny uvolní. Výchozí výnosy (operace tezba) vznikají tady, ne v peci: základ je vždy známý (kámen, štěrk, písek, jíl…), ruda a drahokamy potřebují Mineralogii k určení, ale z buňky padnou. Třída nástroje z T01 (ruka → kámen → bronz → železo → ocel) určuje, co vůbec jde kopat a jak dlouho. Energie je ruční práce; trhaviny v T01 jsou volitelná zkratka, ne nutná brána. [10][11][12]

#### Zkušební stůl

- **Typ:** zařízení. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka.
- **Dovednost:** Mineralogie (rozpoznání minerálů a rud).
- **Operace stromu:** `slozeni`, `odpovida`.
- **Procesy:** `med_na_prvek`, `zelezo_na_prvek`, `cin_na_prvek`, `koks_uhlik`, `kremen_kremik`, `vapno_vápnik`.
- **Vstupy:** libovolná hornina, libovolný minerál, libovolný výrobek, libovolná surovina.
- **Výstupy:** libovolný minerál, libovolná surovina, libovolný prvek.
- **Staví se z:** dřevo (vnější vstup), stavební kámen / kvádr, sklo, keramika, měď (kov).
- **Ladění receptu:** cas, typ_zkousky.
- **Jak:** Lupa, vryp, střep, eventualmente slabá kyselina a srovnávací vzorky. Tady se čte typické minerální složení horniny (operace slozeni) a přiřazuje se, který minerál po uvolnění odpovídá které surovině nebo který kov je který prvek (odpovida). Nic se tu netaví; je to poznání, ne pec. Bez tohoto kroku hráč vidí jen základní výnosy z T01. [7][36]

#### Drtič / stoupa

- **Typ:** stroj. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka, voda, zvíře.
- **Dovednost:** Kamenictví (drcení, broušení, kvádry).
- **Operace stromu:** `drtit`.
- **Procesy:** `drtit_blok`, `drtit_blok_kremen`, `struska_sterk`.
- **Vstupy:** stavební kámen / kvádr, struska.
- **Výstupy:** štěrk / drcený kámen, prach / jemná suť (část nepoužitelná), křemenný písek.
- **Staví se z:** stavební kámen / kvádr, dřevo (vnější vstup), železo (kov).
- **Ladění receptu:** cas, velikost_zrna, pomer_vsazky.
- **Jak:** Těžké pěchy, později vodní stoupa: kámen nebo železné baňky padají na kvádr nebo strusku a drtí je na štěrk, prach a z křemenných hornin i sklářský písek. Agricola popisuje stoupy u rudních úpraven už v 16. století; ruční palice je starší. Jemnější mletí nechává mlýn. Poměr frakcí a doba drcení se ladí; příliš jemný prach je na stavbu horší, na pigment naopak potřeba. [39][52]

#### Vápenka

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** oheň, dřevěné uhlí.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `palit`.
- **Procesy:** `palit_vapno`, `palit_kalcit`, `palit_dolomit`.
- **Vstupy:** vápno / vápencová surovina, kalcit, dolomit.
- **Výstupy:** pálené vápno.
- **Staví se z:** stavební kámen / kvádr, cihla, malta, jíl.
- **Ladění receptu:** teplota, cas, palivo, velikost_kusu.
- **Jak:** Šachtová nebo polní pec, ve které se vápenec nebo dolomit pálí na pálené vápno (CaCO₃ → CaO + CO₂). Historicky stačí žár zhruba 800–950 °C, tedy méně než na sklo. Palivo je dřevo, dřevěné uhlí nebo později uhlí — síra z uhlí ale vápno špiní. Nedopal nechá uhličitan, přepal zhorší hašení. Pec sama se staví z kamene a cihel spojených maltou, kterou tahle pec umožňuje. [13][14][41]

#### Hasicí jáma

- **Typ:** zařízení. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka.
- **Dovednost:** Zednictví (hašení, malta, cihly).
- **Operace stromu:** `hasit`.
- **Procesy:** `hasit_vapno`.
- **Vstupy:** pálené vápno.
- **Výstupy:** hašené vápno.
- **Staví se z:** stavební kámen / kvádr, cihla, dřevo (vnější vstup), písek.
- **Ladění receptu:** pomer_vody, cas, teplota.
- **Jak:** Jáma nebo kád, kde se pálené vápno hasí vodou na hašené vápno (CaO + H₂O → Ca(OH)₂). Reakce je silně exotermní — malá jáma z kamene a cihel to musí vydržet. Málo vody spálí kaši, moc vody ji zředí. Čas zrání (i dny až týdny u vápenné kaše) ladí plasticitu malty. Energie je jen lidská práce a teplo reakce, ne přidaný oheň. [13][14]

#### Zednická dílna / mísírna

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka.
- **Dovednost:** Zednictví (hašení, malta, cihly).
- **Operace stromu:** `michat`.
- **Procesy:** `michat_maltu`.
- **Vstupy:** hašené vápno, písek.
- **Výstupy:** malta.
- **Staví se z:** dřevo (vnější vstup), stavební kámen / kvádr, cihla, železo (kov).
- **Ladění receptu:** pomer_vapno_pisek, pomer_vody, cas.
- **Jak:** Koryto, později míchačka, kde se hašené vápno spojuje s pískem na maltu. Klasický poměr je zhruba jeden díl vápna na dva až tři díly písku; přesné optimum je ve hře skryté (hypotéza receptů 13:39). Špinavý nebo příliš jemný písek maltu zhorší. Práce je ruční. Malta odsud jde na stavbu, kde tvrdne karbonatací. [13][14]

#### Vápenná zeď a omítka

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** bez přidané energie (vzduch).
- **Dovednost:** Zednictví (hašení, malta, cihly).
- **Operace stromu:** `karbonatace`.
- **Procesy:** `karbonatace_malt`.
- **Vstupy:** malta.
- **Výstupy:** kalcit, písek.
- **Staví se z:** malta, cihla, stavební kámen / kvádr, pálené vápno.
- **Ladění receptu:** cas, vlhkost, tloustka.
- **Jak:** Hotová zeď, klenba nebo omítka z vápenné malty. Není to pec: malta na vzduchu přijímá CO₂ a vrací se na kalcit (vápenný cyklus, jediný schválený cyklus ve stromu T02). Tvrdnutí trvá týdny až roky, vlhko pomáhá, příliš rychlé vyschnutí škodí. Písek v maltě zůstává, kalcit se teoreticky dá z trosek znovu pálit ve vápence — uzavřená smyčka. [13][14]

#### Cihelna

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** oheň.
- **Dovednost:** Zednictví (hašení, malta, cihly).
- **Operace stromu:** `palit_cihly`.
- **Procesy:** `palit_cihly`.
- **Vstupy:** jíl, písek.
- **Výstupy:** cihla.
- **Staví se z:** jíl, hlína, stavební kámen / kvádr, cihla, malta.
- **Ladění receptu:** teplota, cas, pomer_jil_pisek, cas_suseni.
- **Jak:** Formování jílu s trochou písku, sušení a výpal v polní peci nebo později v kroužcové peci. Cihly samy pak staví další pece, vápenky i tuto cihelnu — další smyčka katalogu. Teplota a rovnoměrnost žáru rozhodují o pevnosti a barvě; nedopal je měkký, přepal slinuje a křiví. Palivo je dřevo, později uhlí. Sušení před výpalem je stejně důležité jako sám žár. [27]

#### Milíř

- **Typ:** zařízení. **Věk:** primitivní (až středověk).
- **Energie:** oheň.
- **Dovednost:** Uhlířství (dřevěné uhlí) — vstup zvenku, ne z horniny.
- **Operace stromu:** `palit`.
- **Procesy:** `uhli_drevene`.
- **Vstupy:** dřevo (vnější vstup).
- **Výstupy:** dřevěné uhlí, saze / čerň.
- **Staví se z:** dřevo (vnější vstup), hlína, prach / jemná suť (část nepoužitelná), jíl.
- **Ladění receptu:** cas, tesnost, druh_dreva.
- **Jak:** Hromada dřeva zasypaná hlínou a prachem, s řízeným přístupem vzduchu. Dřevo se suchou destilací mění na dřevěné uhlí, vedlejším produktem jsou saze. Uhlí je palivo i redukční činidlo dýmačky a kelímku — bez milíře stojí hutnictví. Příliš vzduchu spálí vsázku na popel, málo vzduchu nechá syrové dřevo. Pozdější retorta je čistší, ale milíř je základní jednotka. [21]

#### Hrnčířská pec

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** oheň, dřevěné uhlí.
- **Dovednost:** Hrnčířství / keramika.
- **Operace stromu:** `palit_keramiku`, `tavit`.
- **Procesy:** `palit_keramiku`, `porcelan`, `glazura`.
- **Vstupy:** jíl, křemenný písek, draselný živec, pálené vápno, měděná ruda.
- **Výstupy:** keramika, porcelán, glazura.
- **Staví se z:** jíl, hlína, cihla, stavební kámen / kvádr, malta.
- **Ladění receptu:** teplota, cas, pomer_vsazky, atmosfera.
- **Jak:** Komorová nebo jámová pec na výpal nádob, kachlů a později porcelánu (jíl / kaolin, křemen, živec). Ve stejné dílně se taví i glazura (křemen, tavidlo, barvicí oxid třeba z mědi). Teplota, atmosféra (oxidační / redukční) a poměry vsázky ladí barvu, slinutí a praskliny. Porcelán je pozdější výrobek; kaolin ve stromu ještě není oddělený od jílu. [16][27][49]

#### Dmýchací pec / výheň (dýmačka)

- **Typ:** stavba. **Věk:** primitivní (až raně průmyslové).
- **Energie:** ruka, voda, dřevěné uhlí, oheň.
- **Dovednost:** Hutnictví (tavení kovů, koksování, slévání).
- **Operace stromu:** `tavit`.
- **Procesy:** `tavit_zelezo`, `tavit_zelezo_koks`, `tavit_fe_ti`.
- **Vstupy:** železná ruda, titanomagnetit (Fe-Ti), dřevěné uhlí, koks.
- **Výstupy:** železo (kov), struska, titanový koncentrát.
- **Staví se z:** jíl, hlína, stavební kámen / kvádr, cihla, železo (kov).
- **Ladění receptu:** teplota, cas, pomer_ruda_palivo, intenzita_dmechu.
- **Jak:** Nízká šachtová pec (dýmačka): železná ruda a dřevěné uhlí, vzduch měchy (ruka nebo vodní kolo). Nevzniká tekuté surové železo jako ve vysoké peci, ale lupa kovu a struska, kterou je potřeba dokovat na hamru. Pozdější cesta dává koks místo uhlí (raně průmyslové), pořád ale ne blast furnace. Titanomagnetit nechá část titanu v koncentrátu. Ladí se dmych, poměr vsázky a čas. [20][21][36][52]

#### Ryžovací splav

- **Typ:** zařízení. **Věk:** primitivní (až raně průmyslové).
- **Energie:** voda, ruka.
- **Dovednost:** Hutnictví (tavení kovů, koksování, slévání).
- **Operace stromu:** `ryzovat`.
- **Procesy:** `ryzovat_zlato`.
- **Vstupy:** zlatá ruda.
- **Výstupy:** zlato (prvek).
- **Staví se z:** dřevo (vnější vstup), stavební kámen / kvádr, železo (kov).
- **Ladění receptu:** prutok_vody, cas, sklon, velikost_zrna.
- **Jak:** Dřevěný žlab s příčkami, případně jen pánvička: proud vody oddělí těžké ryzí zlato od písku. Energie je voda a ruka, žádný oheň. Podíl kovu ve stromu je herní abstrakce; ve skutečnosti se zlato počítá v g/t. Ladí se sklon, průtok a zrnitost vsázky — moc vody odnese i zlato, málo vody nevyplaví jalovinu. Navazující loužení je jiná, pozdější cesta. [37][44]

### Středověk

Voda, měchy, vodní kolo, hamr, sklářská pec, alembik, kovárna.

#### Mlýn

- **Typ:** stroj. **Věk:** středověk (až raně průmyslové).
- **Energie:** ruka, voda, zvíře.
- **Dovednost:** Kamenictví (drcení, broušení, kvádry).
- **Operace stromu:** `drtit`.
- **Procesy:** `drtit_kremen_min`, `pigment_okr`, `pigment_malachit`.
- **Vstupy:** křemen, hematit, malachit.
- **Výstupy:** křemenný písek, okr (pigment), malachitový pigment.
- **Staví se z:** stavební kámen / kvádr, dřevo (vnější vstup), železo (kov), cihla, malta.
- **Ladění receptu:** cas, jemnost, pomer_vsazky.
- **Jak:** Mlýnské kameny, běhoun a ležák, poháněné vodou, zvířetem nebo rukou. Mele křemen na sklářský písek a železité nebo měděné minerály na pigment (okru, malachit). Stejný mlýn později mele i slínek na cement. Jemnost mletí rozhoduje o tavení skla i o krytí barvy; přemletí je ztráta času a prachu. Stoupa drtí hrubě, mlýn mele. [24][36][40][53]

#### Brusná dílna

- **Typ:** stavba. **Věk:** středověk (až raně průmyslové).
- **Energie:** ruka, voda.
- **Dovednost:** Kamenictví (drcení, broušení, kvádry).
- **Operace stromu:** `brousit`.
- **Procesy:** `brousit_drahokamy`, `brousit_diamant`, `brousit_granat`.
- **Vstupy:** drahokamy, diamanty, granáty.
- **Výstupy:** broušený kámen, broušený diamant, broušený granát.
- **Staví se z:** dřevo (vnější vstup), stavební kámen / kvádr, železo (kov), broušený granát.
- **Ladění receptu:** cas, zrnitost_brusu, tlak.
- **Jak:** Kotouče, pískovcové a později kovové disky se zrnem (sám granát slouží jako brusivo — smyčka katalogu). Brousí a leští drahokamy, diamant a granát; část hmoty padne jako odpad. Ruční práce, u větších kamenů vodní kolo. Čas, tlak a posloupnost zrnitosti ladí lesk a riziko praskliny. [51]

#### Sádrová pec

- **Typ:** zařízení. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `palit`.
- **Procesy:** `palit_sadru`.
- **Vstupy:** sádrovec.
- **Výstupy:** sádra.
- **Staví se z:** cihla, stavební kámen / kvádr, železo (kov), malta.
- **Ladění receptu:** teplota, cas.
- **Jak:** Nízkoteplotní pec nebo kotel, ve kterém sádrovec ztratí část krystalové vody a stane se sádrou. Teplota je podstatně nižší než u vápna (řádově 150–180 °C). Přepal („mrtvá sádra“) už s vodou dobře netuhne, nedopal nechá surový kámen. Palivo stačí dřevo, není potřeba dřevěné uhlí. [15]

#### Sklářská pec

- **Typ:** stavba. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň, dřevěné uhlí.
- **Dovednost:** Sklářství.
- **Operace stromu:** `tavit_sklo`.
- **Procesy:** `tavit_sklo`.
- **Vstupy:** křemenný písek, soda / potaš (tavidlo), pálené vápno.
- **Výstupy:** sklo.
- **Staví se z:** cihla, stavební kámen / kvádr, jíl, malta, železo (kov).
- **Ladění receptu:** teplota, cas, pomer_vsazky, cas_chlazeni.
- **Jak:** Pánvová pec na sodnovápenaté sklo: křemenný písek, soda nebo potaž z popela a vápno jako stabilizátor. Čistý křemen taje až kolem 1700 °C, tavidlo teplotu sníží. K peci patří chladicí pec — rychlé chlazení sklo roztrhne. Poměry vsázky, čistota písku a křivka chlazení jsou hlavní ladění kvality (čirost, bubliny, praskliny). [16][17]

#### Kelímek a slévárna

- **Typ:** zařízení. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň, dřevěné uhlí.
- **Dovednost:** Hutnictví (tavení kovů, koksování, slévání).
- **Operace stromu:** `tavit`, `slevat`.
- **Procesy:** `tavit_med`, `tavit_cin`, `slevat_bronz`, `olovo_chybi_ruda`.
- **Vstupy:** měděná ruda, vzácné kovy (Li, Sn, Ta), dřevěné uhlí, měď (kov), cín (kov), galenit (v tabulce hornin chybí).
- **Výstupy:** měď (kov), cín (kov), bronz, olovo (kov), struska, lithný koncentrát.
- **Staví se z:** keramika, jíl, stavební kámen / kvádr, cihla, železo (kov).
- **Ladění receptu:** teplota, cas, pomer_paliva, pomer_slitiny.
- **Jak:** Žáruvzdorný kelímek v malé peci nebo výhni: tavení mědi (zhruba 1100–1200 °C) a cínu s dřevěným uhlím jako palivem i redukcí, pak slévání bronzu (typicky okolo 5–10 % cínu). Sem patří i olovo, až bude ve hře galenit (teď mezera). Železo se tu netaví — na to je dýmačka. Ladí se teplota, čas, podíl uhlí a poměr slitiny; výtěžek kovu ve stromu je herní, ne stechiometrie. [18][19][48]

#### Hamr

- **Typ:** stroj. **Věk:** středověk (až raně průmyslové).
- **Energie:** voda, ruka.
- **Dovednost:** Kovářství (ocel, kalení).
- **Operace stromu:** — (není ve stromu T02).
- **Procesy:** —.
- **Vstupy:** železo (kov).
- **Výstupy:** železo (kov).
- **Staví se z:** dřevo (vnější vstup), železo (kov), stavební kámen / kvádr, cihla, malta.
- **Ladění receptu:** cas, teplota, intenzita_uderu.
- **Jak:** Těžké vodní kladivo (hamr) nebo ruční perlík, kterým se z lupy dýmačky vykove struska a spojí zrna železa do tyče nebo prutu. Bez tohoto kroku není „železo (kov)“ ze stromu ještě použitelný výrobek. Hamr stojí u toku, pohání ho vodní kolo; výheň vedle drží žár. Ve stromu T02 není samostatná operace kování — proto je hamr v seznamu, ale validační skript ho nepočítá jako pokrytí žádné hrany. [20][42][52]
- **Mimo strom:** Kování lupy z dýmačky na použitelnou tyč; ve stromu T02 není samostatná operace, navazuje na tavit železa.

#### Kovárna

- **Typ:** stavba. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň, dřevěné uhlí, ruka.
- **Dovednost:** Kovářství (ocel, kalení).
- **Operace stromu:** `cementovat`.
- **Procesy:** `cementovat_ocel`, `cementovat_ocel_drevo`.
- **Vstupy:** železo (kov), koks, dřevěné uhlí.
- **Výstupy:** ocel.
- **Staví se z:** stavební kámen / kvádr, cihla, malta, železo (kov), dřevo (vnější vstup).
- **Ladění receptu:** teplota, cas, zdroj_uhliku, kaleni.
- **Jak:** Výheň, kovadliny a cementační skříň: železo se dlouho žíhá v uhlíkaté sypké vsázce (dřevěné uhlí nebo koks) a povrch se nauhličí na ocel (cementace). Navazuje kalení a popouštění. Čas se měří ve dnech, ne v minutách; teplota a zdroj uhlíku ladí hloubku cementace a riziko zkřehnutí. Bez dýmačky a hamru nemá kovárna co zpracovat. [28][50]

#### Loužicí kádě

- **Typ:** zařízení. **Věk:** středověk (až raně průmyslové).
- **Energie:** ruka, oheň.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `louzit`.
- **Procesy:** `louzit_med`, `louzit_zlato`, `louzit_lithium`, `titan_na_prvek`.
- **Vstupy:** měděná ruda, zlatá ruda, lithný koncentrát, titanový koncentrát.
- **Výstupy:** měď (kov), zlato (prvek), lithium (prvek), tantal (prvek), titan (prvek), železo (prvek).
- **Staví se z:** dřevo (vnější vstup), keramika, sklo, měď (kov), cihla.
- **Ladění receptu:** cas, teplota, koncentrace, pomer_louzidla.
- **Jak:** Kádě a koryta, ve kterých se kov louží do roztoku a pak sráží: oxidická měď, zlato (pozdější cesta vedle ryžování), lithium a tantal z pegmatitového koncentrátu i titan z titanomagnetitu. Středověká alchymie to zkouší v malém; průmyslové loužení je raně průmyslové. Luhidlo, čas, teplota a koncentrace jsou laditelné; špatný poměr nechá kov v jalovině nebo sežere kád. [18][37][38][45]

#### Destilační přístroj / alembik

- **Typ:** zařízení. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `destilovat`.
- **Procesy:** —.
- **Vstupy:** rumělka (v tabulce hornin chybí), sůl.
- **Výstupy:** rtuť, rtuť (prvek), čištěná sůl.
- **Staví se z:** měď (kov), keramika, sklo, jíl.
- **Ladění receptu:** teplota, cas.
- **Jak:** Alembik: kotlík, helma a chladič. Slouží k destilaci par — u rumělky po pražení ke kondenzaci rtuti, obecně k čištění kapalin. Operace destilovat ve stromu je u soli použitá v širším smyslu (čištění); vlastní sůl vaří solivar, alembik ho jen zastřešuje jako laboratorní obdobu odparu. Staví se z keramiky, později z mědi a skla. Teplota a čas ladí, co přejde do jímky. [25][43]

#### Solivar

- **Typ:** stavba. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `destilovat`.
- **Procesy:** `cistit_sul`.
- **Vstupy:** sůl.
- **Výstupy:** čištěná sůl.
- **Staví se z:** cihla, železo (kov), dřevo (vnější vstup), malta, stavební kámen / kvádr.
- **Ladění receptu:** teplota, cas, krystalizace.
- **Jak:** Varna solanky: kamenná sůl se rozpustí, nečistoty se usadí a voda se odpaří v pánvích nad ohněm (nebo na slunci v teplejším kraji). Ve stromu je to operace destilovat v širším smyslu čištění, ne pravá destilace par. Teplota, čas odparu a řízená krystalizace ladí čistotu. Palivo je dřevo; pánve jsou železné, dům z cihel a dřeva. [26][47]

#### Pražírna

- **Typ:** stavba. **Věk:** středověk (až raně průmyslové).
- **Energie:** oheň.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `prazit`.
- **Procesy:** `rtut_chybi_rumelka`.
- **Vstupy:** rumělka (v tabulce hornin chybí).
- **Výstupy:** rtuť, rtuť (prvek).
- **Staví se z:** cihla, stavební kámen / kvádr, malta, keramika.
- **Ladění receptu:** teplota, cas, pristup_vzduchu.
- **Jak:** Pec na pražení rud za přístupu vzduchu. Ve stromu je konkrétně pražení rumělky (HgS) a jímání par rtuti — v tabulce hornin rumělka zatím chybí, jde o mezeru z T01. Historicky se stejně praží i sulfidy před tavením. Teplota, čas a vzduch rozhodují, jestli síra odejde a kov se neuteče. Jímání par patří k alembiku; obě jednotky se doplňují. [25][46]

### Raně průmyslové

Koks, mechanický drtič, cementářská pec, průmyslové loužení. Ne vysoká pec.

#### Cementářská pec

- **Typ:** stavba. **Věk:** raně průmyslové.
- **Energie:** oheň, dřevěné uhlí.
- **Dovednost:** Chemie / alchymie (pálení, pražení, destilace, loužení).
- **Operace stromu:** `palit`.
- **Procesy:** `palit_cement`.
- **Vstupy:** vápno / vápencová surovina, jíl.
- **Výstupy:** cement.
- **Staví se z:** cihla, stavební kámen / kvádr, železo (kov), malta, ocel.
- **Ladění receptu:** teplota, cas, pomer_vapno_jil, jemnost_mleti.
- **Jak:** Výpal směsi vápence a jílu na slínek a následné mletí (mlýn). Portlandský cement je podstatně mladší než vápenná malta a chce vyšší žár než vápenka. Ve stromu je to pozdější výrobek; poměry vsázky a teplota jsou hrubé, ne moderní rotační pec se všemi přísadami. Palivo je uhlí nebo koks. [22]

#### Koksovna

- **Typ:** stavba. **Věk:** raně průmyslové.
- **Energie:** oheň.
- **Dovednost:** Hutnictví (tavení kovů, koksování, slévání).
- **Operace stromu:** `koksovat`.
- **Procesy:** `koksovat`.
- **Vstupy:** černé uhlí.
- **Výstupy:** koks, saze / čerň.
- **Staví se z:** cihla, stavební kámen / kvádr, železo (kov), malta, ocel.
- **Ladění receptu:** teplota, cas, tesnost.
- **Jak:** Retorta nebo komora, ve které se černé uhlí zahřívá bez vzduchu na koks a saze. Analogie milíře, ale surovina je uhlí, ne dřevo, a jednotka je raně průmyslová. Koks pak živí pozdější cestu dýmačky a cementaci oceli. Hnědé uhlí ve stromu větev na koks nemá. Tesnost a čas ladí pevnost koksu; vzduch vsázku spálí. [21]

## Smyčka katalogu

Vápenka, cihelna a zednická dílna dávají cihlu, maltu a kámen, z nichž se staví další pece. Milíř dává dřevěné uhlí pro kelímek i dýmačku. Dýmačka a hamr dají železo na nástroje, hamr i kování pěchů stoupy. Brusná dílna používá broušený granát jako brusivo. To je záměr: jednotka není zvenku, patří do stejného stromu materiálů.

## Mezery a otevřené otázky

- Hamr ve stromu T02 nemá vlastní operaci (kování lupy). Má se doplnit, nebo stačí jako navazující krok dýmačky?
- Má dýmačka s koksem zůstat dýmačkou, nebo později přejít na vysokou pec (teď mimo rozsah)?
- Solivar používá operaci `destilovat` v širším smyslu čištění; oddělit odpar od pravé destilace?
- Které jednotky jsou ve vesnici od začátku (stoupa, milíř, vápenka, cihelna) a které až s receptem / věkem?
- Kapacita, počet obsluhy a herní čas jednotek nejsou v tomto záznamu (jen laditelné parametry receptu).

