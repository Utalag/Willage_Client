# Datový model generátoru V1.0 – přehled pro diskuzi (2026-11-23)

Projekt Willage: hra s plovoucími ostrovy (Godot 4.7, GDScript; server později v C#, který musí generátor zopakovat bitově stejně). Jen datový model procedurálního generátoru terénu V1.0, bez vykreslování.

## Stav implementace (po krocích, každý schvaluje Jan zvlášť)
- Krok 1 (základy) a krok 2 (funkce světa I) jsou hotové a schválené.
- Krok 3 (geologie) je hotový a čeká na schválení.
- Kroky 4–11 jsou naplánované. Část kódu z nich existuje ve studiích a prototypu, ale ne v novém modelu.

## Hierarchie a rozměry [hotovo, krok 1]
Svět → blueprint → ostrov → blok → segment → buňka.
- Svět je deterministická funkce ze seedu na ploše max 4096 × 4096 m. Neukládá se, jen se z ní čte.
- Blok má 128 × 128 m, segment 8 m (parametr 8/16/32), buňka (voxel) 0,25 m.
- Výška sloupce je výčet 32/64/128 m (výchozí 128 m = 512 buněk), neutrální úroveň je v polovině. Rozměry musí být mocniny 2 a navzájem dělitelné.
- Jednotky jsou metry, voda je v litrech s jedním převodem na m³.
- Verze generátoru má tvar Vmajor.minor (teď V1.0) a ukládá se ke každému ostrovu.
- Determinismus je povinný: stejný seed, parametry a verze dají bitově stejný svět (float64, řazené klíče, celočíselné hashe).
- Jedna tabulka materiálů: 78 id, 1 B na buňku. U každého materiálu je mj. propustnost.
- Odloženo: jak naložit s už hranými ostrovy, když se verze generátoru změní.

## Funkce světa
Rozhraní: dotaz na bod (x, y, z) vrátí materiál, dotaz na sloupec (x, y) vrátí povrch, hranice vrstev a hladinu.

### Krok 2 [hotovo]
- Klima: základní klima světa ze seedu (mírné, poušť, step, tundra, ledovec), uvnitř světa ho mírně mění pomalá mapa. Klima je preset z tabulky, který upraví vstupní parametry generátoru (poušť je plošší a má méně vody) a určí, které biomy se vyskytují a s jakou váhou. Uplatní se před reliéfem. Tabulka patří k verzi generátoru, takže její změna znamená novou verzi. Hodnoty presetů zatím nejsou vyladěné. Reliéf a klima jsou dvě nezávislé osy.
- Mapa biomů a mapa hornin: hrubé body ze seedu a plynulá interpolace.
- Reliéf z parametrů biomu (převýšení, vlnová délka, drsnost, podíl ploch, strop sklonu). Když se převýšení pod strop nevejde, tvar se roztáhne do šířky. V přechodech biomů platí vážený průměr stropů. Drobné tvary do ~2 m smí strop překročit.
- Masiv (hora se stěnou a podhůřím) jako součást funkce.
- Sopky: počet a rozteč jsou parametry, polohy ze seedu, tvar mezi strato a štítovou, kráter, vrchol aspoň 5 m pod okrajem sloupce.

### Krok 3 [hotovo, čeká na schválení]
- Geologie: pásma vrstev z pořadí hornin, 1–3 zástupci podle mapy hornin. Vrstvy kopírují terén a vyklíňují, mocnost je min. 0,25 m a max. 1/4 výšky.
- Útvary (žíly, pně, skarny, dómy, kras, dutiny, minerály) jsou SDF z hashe světové mřížky, takže jsou spojité přes švy bloků (ověřeno 0 rozdílů).
- Vápenec a dolomit 50/50 až 2 m pod hladinou, nad tím vyklínění jílu.
- Sopka uvnitř: průduch od kráteru dolů, slupky lávy a popela.
- Otevřené: navázat vápenec na skutečnou hladinu z kroku 4? Vlastní id pro lávu a popel? Výkon (segment 2,6 s, návrhy na zrychlení zapsané).

### Krok 4 [plán]
- Hladina podzemní vody a propustnost jako funkce geologie, bez uložených buněk.
- Prameny ze seedu (druh, poloha, jmenovitý výkon), skutečný výkon omezí okolí. Artéská voda jen na ověření.

## Ostrov [plán, krok 5]
- Ostrov = seed + parametry + verze + seznam vložení v pořadí.
- Vložení (objekty Source, Transform, Placement) nese souřadnice blueprintu ve světě, otočení o 90°, zrcadlení, výškový posun, režim napojení a seed a verzi zdrojového světa. Blueprint může být i z jiného světa.
- Dotaz na vložený blok se inverzní transformací přepočte do souřadnic zdroje.
- Napojení bloků jen po stranách (rohy se neřeší). Režim Auto: rozdíl do 6 buněk se vyrovná rampou na 3 buňkách, větší rozdíl udělá útes. Dále Blend (povrch rampa 1–4 buňky, podzemní vrstvy klín 1/16 bloku) a Keep. Sousedé se při vložení nemění.

## Buňky a ukládání [plán, krok 6]
- Buňky se generují jen v zorném poli plus okraji, a jen jako slupka 2–3 buněk u vzduchu nebo pod průhlednou vodou. Hlubší se donačtou při odkrytí.
- Kopání po 0,25 m. Dno a okraj ostrova se prokopat nedají.
- Ukládá se jen rozdíl proti funkci, po segmentech (klíče + deflate, hlavička s verzí, transformací a pořadím).
- Připravené, ale vypnuté pole „původní materiál“ (+1 B na změněnou buňku) pro kontrolu na serveru.

## Voda na ostrově [plán, krok 7; jednotlivé části existují ve studiích]
- Simulace povrchu i podzemí: vsakování, boční tok podle spádu, prameny, kras.
- Eroze je samostatná vrstva posunu výšky nad funkcí, kladná (usazování) i záporná, nemění buňky. Ověří se, zda stejný offset stačí i pro krasové dutiny.
- Přepočet po výkopu běží asynchronně na sjednoceném povodí (prodleva 2 s, strop 10 s, fronta výkopů).
- Drobné výtoky pod 0,1 l/s se slučují v dosahu 8 m.
- Výchozí voda je ustálený stav po vygenerování. Ukládá se jen odchylka v krocích 1/16 l, 1 B na buňku (0–15,625 l).
- Čas: 1 herní den = 1 h.

## Další kroky [plán]
- Krok 8: povrchové jevy klimatu po vodě (písek, led, sníh, výpar, zamrzání). Prahy zatím otevřené.
- Krok 9: vegetace jako funkce seedu, materiálu, sklonu a výchozí vody, hustota na m², v tůních nic. Ukládají se jen změny (kácení, výsadba, růst).
- Krok 10: povinný test. Svět 3 × 3 bloky se rozřeže na 9 blueprintů a složí do ostrova (náhodné pořadí, otočení, zrcadlení, aspoň jeden blueprint z jiného světa). Měří se determinismus, paměť, časy a velikost rozdílu. Pak se uzavře V1.0.
- Krok 11: kontrakt se serverem. Server ukládá seed, parametry, verzi, seznam vložení a rozdíl a ověřuje to generátorem (dá se vypnout, výchozí stav zapnuto). Změny se sbírají do zásobníku; kontrola doběhne, když je zásobník plný, nebo po uplynutí intervalu, podle toho, co nastane dřív (03 §6.3). Testovací vektory zajistí stejný hash v GDScriptu i C#.

## Otázky k diskuzi
Je tenhle model (funkce světa + ukládání jen rozdílu + vkládání blueprintů s transformací) rozumný? Kde jsou rizika pro determinismus mezi GDScriptem a C#, pro velikost ukládaných dat a pro výkon funkce světa (dotaz po sloupcích ze seedu je pomalý)? A jak dobře spolu fungují eroze jako vrstva posunu a uložený rozdíl buněk?
