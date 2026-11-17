# Rešerše – voda a propustnost materiálů (Willage)

Zadání Jana (2026-11-17 15:47): „Budeme muset materiálu přidat propustnost. Písek vodu neudrží ale trochu zpomalí. Tráva hodně zpomalí. Jíl zadrží, pevná skála zadrží, porézní skála mírný průsak. Tím se vytvoří i toky a rybníky.“
Doplněno 15:47: voda musí být skutečná data v buňkách (ne jen obraz) – průchodnost, kopání u vody. 15:51: každá buňka má svůj objem, voda přetéká a odtéká, zdroje vody jako entity bloku (shora, ze svahu, skrytá kapsa).

## 1 Jak to dělají hry
- **Dwarf Fortress** drží v každé buňce hloubku vody 1–7, voda padá a rozlévá se, hloubka mění průchodnost [1]. Tlak řeší zvlášť: voda ze zdroje stoupá až do jeho výšky, proto prokopnutí do vodonosné vrstvy vytopí chodbu [2].
- **Minecraft** rozlišuje zdrojový blok a tekoucí vodu, šíří ji po tikách k nejbližšímu sestupu [3]. Objem se nezachovává (nekonečný zdroj) – pro Willage nevhodné, Jan chce měřitelný objem.
- **Hmotový buněčný automat** (W-Shadow, Jgallant): buňka nese množství vody 0–1, kroky dolů → do stran → přebytek nahoru, počítá se z kopie stavu, aby výsledek nezávisel na pořadí, a buňky pod prahem se přeskakují [4][14].
- **Noita** počítá jen „špinavé“ oblasti v chuncích a nečinné chunky uspí; vlákna po šachovnici [13].
- **Virtual pipes** (výšková mapa sloupců s průtokem a setrvačností) dává hladké potoky a je rychlé na GPU [15], ale neumí vodu v zemi a dutiny pod povrchem.

## 2 Fyzika, zjednodušená na buňky
- Proudění v zemi je podle Darcyho úměrné propustnosti a rozdílu tlakové výšky [5]. Studie bere místo tlakové výšky nasycení buňky (voda / pórovitost).
- Propustnost a pórovitost jsou dvě různé veličiny: jíl pojme hodně vody, ale skoro nic nepropustí; písek pojme méně a propouští hodně; čerstvá žula ani jedno; vápenec málo a pomalu [6][7].
- Povrchový odtok zpomaluje drsnost povrchu – tráva je mnohem „drsnější“ než písek nebo holá zem [8].
- Vsakování má strop; co ho převýší, teče po povrchu [9].
- Rybník nad jílovou čočkou v písku je zavěšená hladina [10]. Pramen na svahu vzniká tam, kde vodonosná vrstva vyjde na povrch [11]; uzavřená vrstva pod tlakem vyteče po provrtání sama [12].

## 3 Co z toho studie použila
- Hmotový automat [4][14] na datových buňkách 1 × 1 × 0,5: `w` v každé buňce (vzduch pojme 1, materiál svou pórovitost), pevné pořadí kroků, do stran z kopie stavu → deterministické, server může počítat tiky.
- Materiál = 3 čísla: propustnost, pórovitost, odpor povrchu [6][7][8], vsak s horní mezí `infil` [9].
- Přetlak jako „přebytek o buňku výš“ [4][2] místo řešení tlaku.
- Zdroje jako entity bloku: `top_flow` [3], `hillside_spring` [11], `underground_pocket` [12][2].
- Průchodnost podle hloubky vody a nasycení povrchu (bláto) [1].

## 4 Co studie zatím neumí
- Skutečný tlak ve spojených nádobách (voda nevyteče U-trubicí výš, než je přetlak o 1 buňku za tik) [2].
- Setrvačnost toku (potoky jsou „líné“, tečou po rozdílu hladin) [15].
- Kapilarita (nenasycená zem nad dutinou pomalu odkapává).
