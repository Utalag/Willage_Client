# Terén: bloky a buňky (plánování s Janem, 17. 11. 2026)

Stav: plánování, rozhodnutí Jana. Předáno Willage-backendovi 17. 11. 2026 (spolupráce na úpravě Willage_Dev).

## Rozhodnuto
- Terén není placka: má výšky a vrstvy materiálů (např. tráva → hlína → kámen), síla vrstev se liší.
- Kopání a úpravy terénu probíhají **přímo na ostrově**; doly = přepnutí do **samostatné mapy**.
- Ostrov si hráč **sestavuje z bloků (dlaždic)**, které dostane; pak je doladí kopáním/úpravou.
- **Blok = 3D pole buněk** s různě namíchanými materiály.
- Blok vzniká z **typu (recept: hora, louka, kopec…) + seedu** → bloky mohou, ale nemusí být stejné.
- **Katalog bloků**: běžné (náhodný seed), pevné (daný seed, všichni stejný), unikátní (pojmenovaný seed, existuje jednou, např. odměna z eventu).
- **Materiál je omezený a zachovává se**: co se vytěží, jde do inventáře a lze znovu použít (kandidát na zápis přes ledger).
- Server ukládá typ + seed + seznam změn, ne celý objem.

## Později
- Kombinování typů (hybridní recepty s váhami) a prolínání okrajů sousedních bloků.
- Rotace pohledu o 90°.

## Otevřené otázky
- Velikost bloku v buňkách (šířka × hloubka × výška) a počet bloků na ostrov; vztah k současnému poli 16×16 v backendu.
- Klient: 2D izometrie, nebo 3D s izometrickou kamerou v Godotu (3D vychází lépe pro výšky, kopání a rotaci; 2D pro malovaný vzhled a lehký web).
- Jak navazují výšky na hranách bloků při umístění.

## Doplněno 17. 11. 2026 (Jan)
- Buňky jsou krychle (hexy zamítnuty).
- **Blok = 16 × 16 × 64 buněk** (16 384 buněk na blok).
- Výchozí povrch kolem středu výšky; konkrétní hladinu určí typ bloku (louka níž, hora výš).
- Ostrov na začátku zhruba kruhový: 4 připravené bloky, zbytek je mlha (prázdná místa pro vkládání nových bloků).
- Rozšiřování zatím libovolným směrem; odemyká se vždy jen jeden blok sousedící s ostrovem (ne celý prstenec).
- Napojení nového bloku podle rozdílu výšek na hraně: malý rozdíl = plynulé dorovnání okraje nového bloku, velký = útes/skalní stěna. Mění se jen buňky nového bloku, sousedé nikdy. Práh může záviset na typu bloku.
- Při vkládání: posun celé výšky bloku o 1–4 buňky nahoru/dolů; pak pro každou ze 4 stran přepínač Automaticky / Dorovnat (síla 1–4 buňky) / Ponechat. Pořadí: posun, pak strany.
- Posun výšky NEstojí materiál: při posunu nahoru se dole odeberou spodní řady, při posunu dolů se dole dogenerují ze seedu (výška bloku zůstává 64).
- Dorovnání stran také NEstojí materiál: posun i dorovnání jsou bonus při vkládání pro přizpůsobení ostrova; materiál se počítá až při kopání a stavění.
- Při vkládání jde blok otočit po 90° kolem svislé osy (0/90/180/270) a zrcadlit (vodorovně). Pořadí: zrcadlení, rotace, posun výšky, dorovnání stran.
- Blok interně drží souhrn materiálů (počet buněk podle materiálu); každý materiál má v katalogu skóre; rarita bloku se odvozuje i z obsažených materiálů. Blok ukazuje původní raritu (pevná z vygenerovaného stavu) i aktuální raritu (přepočítaná podle současného obsahu po těžbě a stavění).

## Později: fyzika materiálů (Jan, 17. 11. 2026)
- Každý materiál má nosnost = kolik buněk nad sebou unese, než se propadne (např. písek 1, pískovec 3, skála neomezeně, močál 0 = propadne se hned).
- Hráč bude muset podpírat doly a výkopy (podpěry jako stavba).
- Do datového modelu materiálu stačí teď jen připravit vlastnost „nosnost“; simulace propadů přijde později.
- Mlha = zvláštní materiál: nehratelný a nestavitelný (nelze kopat ani stavět); vyplňuje prázdná místa kolem ostrova a mizí jen vložením nového bloku.
- Buňka má poloviční výšku: 1 × 1 × 0,5 (Jan 17. 11.). Zatím zůstává 64 buněk na výšku (blok fyzicky poloviční); škálování později.

- Vzhled terénu: kostky (Jan 17. 11.). Vyhlazení Surface Nets bylo vyzkoušeno (godot-3d-test/smooth/), zatím se nepoužije.

- Bloky reprezentují jen materiály terénu. Květiny, stromy, keře a další rostliny jsou samostatná vrstva objektů na povrchu; každá rostlina smí jen na vhodný materiál (Jan 17. 11.).
- Základní vegetace se generuje se seedem bloku; každý druh vegetace má vlastní skóre; další sázení provádí uživatel sám (Jan 17. 11.).
- Zatímní směr (Jan 17. 11., „možná“): rarita bloku rozdělena na samostatné skupiny, rarita materiálů a rarita vegetace (každá původní i aktuální); případná celková rarita později.
- Cesty (Jan 17. 11.): žádné automatické vytváření; uživatel zvolí stavby k propojení a případně průchozí body, hra najde trasu po terénu (malý schod projde, útes/voda/mlha ne). Cesta je vrstva nad terénem jako vegetace. Otevřené: cena materiálu za cestu.
- Vizuální směr (Jan 17. 11.): kawaii styl ve 3D (pastelové barvy, toon shading, zaoblené tvary, obrysy, případně nepravidelné „tužkové“ čáry); pixel art není podmínka. Předlohy staveb z Janových obrázků jen jako inspirace, modely vlastní. Tráva jako animovaná vegetace (MultiMesh + shader).
