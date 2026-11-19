# Odpověď Gemini (chat https://gemini.google.com/app/95b61d2a05f3be74, režim „Automaticky“)

> Uloženo z vykresleného textu odpovědi; matematické vzorce zjednodušeny na prostý text.

Máte odvedený výjimečně poctivý a daty podložený výzkum – většina týmů by skončila u 4GB slovníku nebo u 3D Darcyho a hru by pohřbila. Současná architektura (2,5D pásma sloupců na řídicí mřížce 0,5 m, událostní čas, priority-flood/D8 na povrchu a E63 lokální oprava podzemí) už je ve velmi dobrém stavu.

Přesto tam vidím několik míst, kde si zbytečně komplikujete život nebo kde máte skrytá rizika (hlavně determinismus u ε-sestupu, 461ms špičky na hlavním tělese a zbytečnou „fyzikální“ přesnost tam, kde hráč vnímá iluzi a událost).

Níže odpovídám na všech 5 otázek a návrhy řadím podle očekávaného přínosu (od nejvyššího).

## Návrhy seřazené podle očekávaného přínosu

### 1. Dělení režimů podle časové škály (E59) + oddělení „iluzorní hladiny“ od „přesné bilance“ (Otázky 1, 3, 5)

**Proč to má největší přínos:** V E59 jste správně narazili na 13 řádů v hydraulické vodivosti K. Když necháte vše v jednom ustáleném stavu, tělesa se po změně vlastností přepínají mezi nádrží a přelivem a přeliv pak táhne přes 118 000 pásem i tam, kde by voda prosakovala hodiny nebo dny herního času.

**Jak to pojmout:**
- Rychlý ustálený stav (ustálený průtok / prameny / vývěry): pro materiály nad prahem (rychlé cesty, pukliny, štěrk, kras/dutiny, aktivní svody).
- Události v haldě (E51): pomalé prosakování, sycení pórového prostoru a přesuny hladin v čase (t = V/ΔQ).
- Statické / prakticky nepropustné: perm <= perm_leak – vůbec nevstupují do aktivních grafů (jen jako bariéra a dno).
- Oddělit hladinu pro rendering/vizualizaci od bilance: Hráč nevidí „118 000 pásem", vidí pramen, vývěr ve stěně, vlhkost/vsak a událost. Pokud se eps u kapilárního sestupu používá jen pro šíření po „téměř vodorovných/kapilárních“ cestách, je mnohem čistší explicitní graf vodivých cest / hierarchie pánví a prahů (barrier/merge tree) než heuristická tolerance eps ve frontě, jejíž pořadí ovlivňuje výsledek.

- **Složitost:** Stavba/údržba aktivního podgrafu je výrazně menší než 312k pásem; dotazy na události O(log E) v haldě.
- **Paměť:** Nižší nebo srovnatelná (~288 MB základ, méně dočasných struktur pro neaktivní vrstvy).
- **Determinismus:** Vysoký, pokud odstraníte závislost na pořadí při eps (viz bod 2).

### 2. Deterministická lokální oprava přelivu: „přesný kbelíkový/haldový sestup bez eps-závislosti“ nebo „kmenový strom + přepočet z hrany podstromu“ (Otázky 2, 4)

**Proč to má velký přínos:** V E63 máte 90–111 ms průměr, ale 461 ms max a jen empirickou shodu kvůli eps. V multiplayeru s validací na serveru je „většinou shodné“ nebezpečné – stačí jeden hraniční výkop a klient s jiným pořadím zpracování může rozjet otisk stavu.

**Jak na to deterministicky:**
- Odstranit nejednoznačnost u eps: Buď dělat sestup po striktně seřazeném klíči (hladina / potenciál, id_pásma) (stejně jako u kbelíků A v E58, kde zachováváte kanonické pořadí), nebo eps převést na explicitní odpor / práh hrany (pokud je spád pod prahem, nepočítá se jako volný spád, ale jako odpor/kapilární člen s pevným vzorcem). Pak je výsledek matematicky nezávislý na pořadí v jakémkoli průchodu.
- Oprava přes hranici zasažené množiny (dynamic SSSP / minimax na stromě): Když zneplatníte pásma ve vykopaném sloupci a jejich podstrom S (cca 300 pásem), nejlepší novou hodnotu pro uzel v∈S neurčuje jen „nějaký nezměněný soused“, ale minimum z potenciál(u) + cena(u,v) přes všechny hrany (u,v) jdoucí z vnějšku V∖S dovnitř S (a případně nové zdroje přímo v S). Z těchto hraničních uzlů spustíte lokální Dijkstru / priority-flood jen uvnitř S a jeho bezprostředního okolí, dokud se hodnoty ustálí.
- Proč pak nevznikne „obří podstrom“ (461 ms)? Velký podstrom vzniká, když se přeruší hlavní kmen podzemního toku a velká část tělesa ztratí krmení. U takového výkopu neopravujte celé těleso najednou – viz bod 3.

- **Složitost:** O(|S| log |S| + |E_∂S|) v běžném případě; v nejhorším případě omezeno rozpočtem (bod 3).
- **Paměť:** Strom rodičů / hraniční hrany cca jednotky MB (navíc k E63 ~8–16 MB).
- **Determinismus:** Dokazatelný (bitově / číselně v rámci plovoucí čárky), pokud je kanonické řazení (hodnota, id) a pevné sčítací pořadí.

### 3. Rozdělení práce do rozpočtu snímků/tiků (time-slicing + špinavé příznaky) pro špičky typu 461 ms (Otázka 4)

**Proč to má velký přínos:** Na telefonu (30 FPS = ~33 ms na snímek) i na serveru při náporu hráčů je jednorázový 461ms výkop mnohem horší než 15 ms rozdělených do několika tiků. Protože nehrajete „tikající fyziku vody“, ale ustálený stav + události, nemusí každý výkop okamžitě dojet do posledního kouta 312 000 pásem, pokud to neovlivňuje bezprostřední událost nebo viditelný vývěr.

**Jak na to:**
- Rozpočet na tik / úlohu (např. 5–10 ms na klientovi, daný pevný počet kroků/pásem na serveru): Klíčové je, aby server i klient dělaly stejný počet kroků v deterministickém pořadí, pokud se synchronizuje stav – nebo aby server počítal událostní stav autoritativně a klient interpoloval/dopočítával lokální náhled.
- Dvourychlostní aktualizace podzemí:
  - Okamžitě (do pár ms): přímý vliv na povrch/prameny/vývěry v okolí výkopu a platnost existujících událostí (např. změna odtoku tůně ihned přepočítá t_plná = V/(Q_in − Q_ztráty) u dotčené tůně).
  - V dávkách po rozpočtu: hluboké šíření po pásmech, kde se jen upřesňuje rozložení v rozsáhlém tělese.
- Aproximace / horní mez: Pro rozsáhlé těleso (jako v grafu těles B) lze při překročení rozpočtu použít odhad hladiny / průtoku z předchozího stavu + delta a označit těleso jako dirty (k dořešení v dalším kroku), místo blokování hlavního vlákna na půl sekundy.

- **Složitost:** Amortizovaně stejná, maximální latence na jeden krok je omezená konstantním rozpočtem O(B).
- **Paměť:** Minimální (fronta rozpracovaných uzlů / stav rozpracovaného průchodu).
- **Determinismus:** Zachován, pokud je krokovač řízen pevným počtem operací v deterministickém pořadí (nikoli „kolik se stihlo za reálný wall-clock čas“ – wall-clock čas by rozbil determinismus mezi telefonem, PC a serverem!).

### 4. Komprese sloupců/pásem do „vertikálních bloků / souvislých propustných segmentů“ před samotným hledáním (Otázky 1, 3)

**Proč to má střední až velký přínos:** Máte 128×128 sloupců a ~312 000 pásem (~19 pásem na sloupec). Kapilární sestup prochází ~118 000 pásem – část z nich jsou ale dlouhé vertikální průchody propustným materiálem bez odboček nebo s monotonním spádem, případně nepropustné předěly.

**Jak na to:**
- Nemusíte opouštět reprezentaci pásmy sloupců [lo, hi) – ta je na vrstevnatý terén a tenké vrstvy (kde hrubá mřížka selhala) velmi dobrá.
- Nad pásmy ale můžete udržovat komprimovanou reprezentaci vertikálních úseků / souvislých propustných komor uvnitř každého sloupce (podobně jako run-length / interval compression): místo krokování přes každé dílčí pásmo propustného písku/hlíny, kde se nic neštěpí, přeskočíte rovnou na spodní hranu úseku nebo na místo, kde se mění sousedství/propustnost.
- Pozor na úskalí: U sestupu s eps nebo lokálními změnami výšky hladiny uvnitř sloupce musíte rozlišovat horní/dolní hranu intervalu, aby nedošlo k chybě při částečném zaplavení.

- **Složitost:** Může snížit počet navštívených uzlů při průchodu z řádu 10^5 na řád 10^4, samotná údržba intervalů ve změněném sloupci je O(P_sloupec).
- **Paměť:** Řádově jednotky až nízké desítky MB navíc.
- **Determinismus:** Vysoký, pokud komprese nemění topologii spojení ani pořadí vyhodnocování.

### 5. Kdy sáhnout po stromech (merge tree / barrier tree / union-find) místo přímého průchodu (Otázky 1, 2)

**Proč to má střední přínos (hlavně pro tůně, prameny a rozpady těles):**
- Union-find po hladinách / barrier tree je skvělý pro otázky typu: „Kdy se dvě tůně/komory sliji?“ nebo „Jaká je prahová výška přepadu mezi dvěma oblastmi?“
- Pro podzemní proudění s propustným dnem, bočními překryvy a proměnlivým dnem (auto) je ale čistý contour/merge tree sám o sobě těžší na údržbu než kombinace sloupcových pásem + lokálního grafu/souhrnů. Důvod je prostý: hladina a průsak tu neurčuje jen čistá topografie jednoho skalárního pole, ale i propustnost dna, zdroje/ponory a překryvy ve z.
- Proto nedoporučuji přepisovat celé podzemí na contour/merge tree. Má smysl ho použít cíleně (např. pro rychlé vyhodnocení přepadů/tůní nebo detekci rozpadu/slití oblastí), ne jako náhradu celého modelu.

- **Složitost:** Stavba O(N log N) (nebo s union-findem téměř lineární), dotazy na práh O(log N) s předpočtem; při častých lokálních změnách terénu může být údržba stromu dražší než lokální oprava grafu/pásem.
- **Paměť:** Desítky MB pro stromy/indexy.
- **Determinismus:** Vysoký (při pevném řazení událostí/hran).

## Přehledové srovnání a co děláte zbytečně / co chybí (Otázka 5)

| Návrh | Očekávaný přínos | Časová složitost | Paměť | Determinismus |
|---|---|---|---|---|
| 1. Časové režimy (E59) + oddělení hladiny od bilance | Velmi vysoký | Menší aktivní graf; události O(log E) | Nižší / srovnatelná | Vysoký (bez eps řazení) |
| 2. Deterministická oprava přes hranici podstromu | Vysoký | O(\|S\| log \|S\| + \|E_∂S\|) | +jednotky MB | Dokazatelný |
| 3. Deterministický rozpočet kroků (time-slicing) | Vysoký (řeší 461 ms) | Max O(B) na krok | Minimální | Zachován (při počtu kroků, ne wall-clock) |
| 4. Komprese vertikálních úseků ve sloupci | Střední–vyšší | Méně uzlů v průchodu | +jednotky až ~20 MB | Vysoký |
| 5. Cíl. merge/barrier tree (jen pro tůně/prahy) | Střední | O(N log N) stavba, O(log N) dotaz | +desítky MB | Vysoký |

**Co podle mě děláte zbytečně:**
- Honba za „fyzikální přesností“ v ustáleném stavu na 0,125 m / 118 000 pásem u každého výkopu: U hry s 10minutovým dnem, kopáním hráčů a událostmi rozhoduje čitelnost, konzistence, stabilita a odezva, ne přesnost na 9 desetinných míst u každého podzemního pásma, které hráč nevidí.
- Spoléhání na wall-clock čas / jednorázový dokončovací přepočet u velkých zásahů: Když kopne hráč v rušném místě, je lepší okamžitě aktualizovat lokální efekt (pramen, odtok, událost) a zbytek dořešit v deterministických dávkách.
- Paralelní experimentování s příliš mnoha těžkými režimy najednou: Už máte jasně ukázáno, že klíčem je lokální aktualizace + souhrny/graf + události. Další „těžké“ simulace (jako 3D Darcy nebo husté mřížky) jsou slepá ulička.

**Co vám podle mě úplně chybí:**
- Formální invarianty a deterministický replay test (klient vs. server): Nemáte jen testovat shodu s plným přepočtem na 60/100 výkopech, ale automatický fuzz test s různým pořadím souběžných výkopů (2 hráči kopou blízko sebe v různém pořadí zpracování) a kontrolou hash/otisku stavu po každém kroku.
- Explicitní oddělení „vlivu na živé události / povrch“ od „vnitřního dočištění podzemí“: Pokud výkop změní průtok do tůně nebo vývěr, potřebujete to hned. Pokud jen lehce přeskupí podzemní cestu hluboko pod povrchem, může se to dočistit v dalším kroku bez 461ms záseků.
- Geologický / herní „odhad“ pro vzdálené nebo neaktivní oblasti: Podobně jako jste na povrchu uvažovali o grafu pánví jako náhledu/LOD, i v podzemí dává smysl mít pro vzdálené/nezkoumané části „hrubší“ souhrnný stav a zpřesnit ho při zásahu nebo dotazu.

## Závěrečné doporučení

Pokud chcete zachovat současný základ (protože funguje a je změřený), nejčistší cesta vpřed je:
1. Odstranit závislost na pořadí u eps (kanonické řazení nebo pevný práh/odpor) a přejít na deterministickou lokální opravu přes hraniční hrany zasažené množiny.
2. Zavést deterministický krokovač s pevným limitem operací na tik (nikoli měřeným reálným časem!), aby zmizela 461ms špička a zachoval se otisk stavu napříč klienty a serverem.
3. Využít časové režimy z E59 (rychlé cesty vs. události vs. nepropustné dno), aby se zbytečně nepřepočítávalo to, co se v herním čase nehýbe.

Jaký je u vás aktuálně největší problém při nasazení: riziko rozchodu stavu (determinismus) mezi klientem a serverem, nebo maximální latence (461 ms špičky) na slabším zařízení / serveru?
