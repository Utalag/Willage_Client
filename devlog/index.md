# Willage – osnova devlogu

Tato složka je soukromá osnova pro Jana. Není to zveřejněný web a nic odtud se neposílá ven. Později z ní může vzniknout devlog (například GitHub Pages), až to Jan schválí.

Text bere jen to, co už je v deníku a ve studiích. U každého bodu je krátce, co to je a jak je to myšleno. Podrobnosti, rozhodnutí a snímky jsou na podstránkách.

Značky v textu:

- **rozhodnuto** – Jan to schválil
- **ve zkoušce** – je to vyzkoušené, ale ještě bez rozhodnutí
- **hypotéza** – v deníku označené 💡, nápad, ne rozhodnutí

Zdroje: [`DENIK.md`](../DENIK.md), [`blueprint-studie/`](../blueprint-studie/), [`godot-prototyp/`](../godot-prototyp/), [`navrhy/format-bloku-wvb1.md`](../navrhy/format-bloku-wvb1.md), [`teren-bloky-bunky.md`](../teren-bloky-bunky.md).

---

## 1. Koncept hry

### Vesnice na Twitchi

Willage je hra, ve které streamer a diváci staví ostrovní vesnici. Hráč ostrov skládá z bloků (dlaždic), které dostane, a pak je doladí kopáním a stavěním. Materiál je omezený a zachovává se: co se vytěží, jde do inventáře a jde znovu použít.

→ [Koncept](koncept.md)

### Ostrov jako základna

Rozhodnuto je, že kopání a úpravy probíhají přímo na ostrově a doly jsou samostatná mapa. Ostrov začíná zhruba kruhově ze čtyř připravených bloků, zbytek je mlha, a rozšiřuje se vždy o jeden sousední blok. Myšlenka, že podzemí ostrova bude jen z obecných vrstev bez vzácných surovin a plná geologie zůstane výpravám, je zatím **hypotéza** (Jan 17:20: „byl to nápad“).

→ [Koncept](koncept.md)

### Vzhled: referenční obrázky

Náměty, které se Janovi líbí: plovoucí ostrov s vodopády, řez blokem s jeskyní, krystalový důl, low-poly krajina a srovnání velikosti voxelů. Jen inspirace, ne náš render.

→ [Vzhled: reference](vzhled-reference.md)

## 2. Architektura

### Generování na klientovi, server ukládá a validuje

Generátor a simulace běží na klientovi. Klient po usazení a dopočtu pošle pole bloku, server ho zkontroluje a uloží. 18. 11. 2026 Jan upřesnil, že generování je zatím primárně na klientovi i na telefonu.

→ [Architektura](architektura.md)

### Formát bloku WVB1

Návrh kontejneru `WVB1` popisuje, jak klient pošle blok: hlavička (seed, recept, zásobník, souhrn), komprimované vrstvy materiálů a vody a hash. Server přepočítá hash a souhrn a u rud kontroluje vydaný cíl. Návrh z 17. 11. 2026 čeká na schválení.

→ [Architektura](architektura.md)

### Model světa: buňky z funkcí

Svět je buněčný, ale buňky se neukládají ani nepočítají všude. Odvozují se z funkcí vrstev a z pásem a každý systém pracuje na úrovni, která mu stačí: geologie na funkcích, voda na pásmech a grafu těles, vykreslení a kopání na vzorkovaných buňkách. Stránka popisuje i srovnání s voxely a Dwarf Fortress a hranice modelu (převisy, jeskyně).

→ [Model světa](model-sveta.md)

## 3. Blueprint terénu

### Vrstvy jako spojité funkce

Buňky už nejsou zdrojem tvaru. Povrch a hranice vrstev jsou spojité funkce v metrech, buňky je jen vzorkují. Řídicí mřížka 0,5 m drží povrch a součty mocností, mezi body se interpoluje. Stejný blok proto jde navzorkovat hrubě i jemně.

→ [Blueprint terén](blueprint.md)

### Pořadí hornin a deformace podle typu

Horniny mají pořadí v tabulce (64 položek z popisu kůry, plus sopouch; výchozí podmnožina 17). Typ terénu vrstvy ohne: nížina a kopec, prohlubeň, vyzdvižená hora s jádrem, zvrásněná hora, sopka se sopouchem. Jde o směr **ve zkoušce**.

→ [Blueprint terén](blueprint.md)

### Navazování na sousedy a klíny

Okraj bere mocnost souseda přesně (Dirichlet) a do 3 m přejde v tvar blueprintu. Vrstva, kterou má jen jedna strana, vnikne klínem nebo se vyklíní. Strana bez souseda bere podmnožinu hornin z blueprintu (**rozhodnuto** 17:38). V rohu má skutečný soused přednost.

→ [Blueprint terén](blueprint.md)

### Minerály, dutiny a pevnost

Minerály jdou jen do hostitelských hornin, v přesných počtech (při jiném rozlišení se násobí (n/16)³). V bloku je nejvýš jedna dutina: nic, jeden rezervoár, nebo jedna jeskyně; blueprint s vodou i vzduchem se odmítne (**rozhodnuto** 17:38). Pevnost (nosnost, konzola) je zatím jen údaj v tabulce.

→ [Blueprint terén](blueprint.md)

### Generování masivu: varianty a proč fungovaly nebo ne

Přehled všech pokusů E45–E56 (blueprint v1, 65 hornin, klíny, hrubý svět → dlaždice → detail, větší rozlišení, mírnější svahy) se skicami, řezy a čísly. U každé varianty je, co vyšlo a co ne.

→ [Generování masivu](generovani-masivu.md)

## 4. Svět a měřítko

### Hrubý svět, dlaždice a detail

**Hypotéza**, zkoušená v E49 a E50: jednou nahrubo spočítat terén, erozi, řeky a biomy, rozřezat je na dlaždice s typem a podmnožinou hornin a podrobnou geologii dopočítat až podle potřeby, od první dlaždice dál s navázáním na sousedy. V testu 8 × 8 to švy povrchu udrželo.

→ [Svět a měřítko](svet-a-meritko.md)

### Proporční svět, sekce a LOD

**Hypotéza:** výška světa kolem 3000 m (hora ~1000 m, podzemí ~2000 m), postava ~2 m, vrstvy dál jako funkce v metrech. Počítat a ukládat jen kousky u povrchu, postavy a výkopů, zdálky jen hrubý povrch. Návrh bloku vesnice 128 × 128 m se Janovi líbil, ale ještě se nerozhodl.

→ [Svět a měřítko](svet-a-meritko.md)

### Svět výprav

Jan 18:59: tentýž princip (funkce + kousky na vyžádání) se použije pro svět výprav, dost velký pro víc hráčů najednou. Stejné funkce dají stejný terén, ukládají se jen změny. Velikost bloku v metrech je pořád otevřená.

→ [Svět a měřítko](svet-a-meritko.md)

## 5. Voda

### Prameny a koryta

Déšť je jen vizuální a vodu nedává. Vodu dávají prameny se stálým průtokem. Když je pramen uzavřený v dutině bez výtoku, neteče; po otevření teče znovu. Voda běží vygenerovaným korytem. Simulace se spouští jen při změně terénu u vody, lokálně po proudu do ustálení, a nové koryto se uloží.

→ [Voda](voda.md)

### Plnění tůní a propustnost

Tůň se neplní po ticích. Předem se spočítají objemy vrstev a časy naplnění z přítoku minus odtoku. Propustnost jámy je odtok za čas. Když je tůň plná, odtok jde podzemím a zbytek přeteče nejnižším okrajem. Když je odtok větší nebo roven přítoku, tůň se nenaplní (ponor).

→ [Voda](voda.md)

### Podzemní voda a okraj ostrova

Podzemní voda sleduje propustnou vrstvu, dutinu zaplní jako podzemní jezero a uzavřená čočka se naplní a pak přeteče (ve zkoušce E47d). Ostrov je plovoucí: voda na okraji mapy padá vodopádem do mlhy a dál se nesimuluje.

→ [Voda](voda.md)

### Algoritmy vody a podzemí: proč, data, přístupy, zvolená varianta

Proč se voda počítá jako ustálený stav a události, na jakých datech (řídicí mřížka, pásma, tabulka materiálů), všechny vyzkoušené přístupy se schématy, vzorci a grafy výkonu. Zvolená varianta podzemí A+B+C zkrátí výkop z 1,7 s na 0,9 ms při stejném výsledku (E58, **ve zkoušce**).

→ [Voda: algoritmy](voda-algoritmy.md)

## 6. Eroze a usazování

Při generování už umíme erozi, která mění jen funkci povrchu a vrstvy nechá být (E47, ve zkoušce). Mechanika za běhu hry je zatím **plán**: každý materiál dostane práh, kolik vody musí buňkou protéct, než ji odplaví, a v klidné tůni práh pro usazení. Obojí závisí na rychlosti proudění, časy se předpočítají jako události a vykopání nebo položení odpočet vynuluje.

→ [Eroze a usazování](eroze-a-usazovani.md)

## 7. Výkon a telefony

Hra má běžet i na telefonech. Generování je zatím primárně na klientovi (i na telefonu), server ukládá a validuje. Jan k tomu chce menší dosah detailu a LOD, jednodušší vzhled, vodu jen jako animaci podle časů, vykreslování Godot Compatibility a cíl 30 snímků za sekundu na středním telefonu. Měření velkého světa (E50) je z boxu v GDScriptu, ne z telefonu.

→ [Výkon a mobil](vykon-a-mobil.md)

## 8. Otevřené otázky

Zůstává několik rozhodnutí, která čekají na Jana: eroze po blocích nebo jen na hrubém světě, jádro hory přes šev, minerály a voda z hrubého světa, pravidlo krasové vyvěračky, velikost bloku vesnice, formát WVB1 a další drobnosti ze studií.

→ [Otevřené otázky](otevrene-otazky.md)
