# Kronika a předhistorie ostrova (koncept, nízká priorita)

Stav: nápad pro vedlejší větev, ne hlavní vývoj. Zadání: Jan 13. 11. 2026 (přes Willage-backend).
Inspirace: Dwarf Fortress (generovaný svět s historií, režim Legends). Licence se netýká, přebíráme jen princip.

## Shrnutí pro Jana
Doporučuju udělat obě varianty, ale v pořadí: nejdřív **B – Kronika z akcí diváků** (vzniká sama z událostí, které už backend zná, a na Twitchi dává smysl, protože diváci se v ní vidí), potom volitelně **A – krátká předhistorie** (jednorázově při vzniku ostrova, jen jako „koření“). Obě sdílí jeden datový základ: záznam v kronice + volitelná vazba na buňku mapy.

## Varianta A – předhistorie při vzniku ostrova
- Při vytvoření ostrova se ze seedu deterministicky vygeneruje 3–6 událostí „před příchodem osadníků“ (např. ztroskotání lodi, starý maják, bitva, zmizelý kmen, sopka).
- Každá událost může zanechat **stopu na mapě**: ruinu nebo dekor ve vrstvě dekor (kamenný kruh, vrak, hrob), případně skrytý vchod do Z-patra pod povrchem (vazba na nápad dolů/dungeonů).
- Stopy jsou objevitelné: hráč najde ruinu → odemkne se zápis legendy v kronice → případně malá odměna přes ledger.
- Generátor = tabulky šablon (typ události, podmínka terénu, stopa, text) + seed ostrova. Žádné LLM, aby to bylo opakovatelné a testovatelné.

## Varianta B – kronika psaná akcemi diváků (doporučeno)
- Kronika je append-only seznam zápisů ze skutečných událostí za živého streamu: první návštěva diváka, postavená stavba, splněný komunitní cíl, loot event, raid, sabotáž (infamy), rekord, výročí ostrova.
- Ne každá akce je zápis. Pravidla „hodné zápisu“: první výskyt, milník (100. stavba), vzácnost, komunitní cíl, nebo velký dopad. Jinak by kronika byla spam.
- Zápisy se seskupují do **kapitol = streamů** (session z B04): „Kapitola 12 – Noc velkého mostu“. Název kapitoly ze šablony podle nejvýznamnější události.
- Divák vidí ve kronice svoje jméno (Twitch display name) – motivace vracet se. Prestiž/infamie může přidat titul do zápisu („Zlotřilý X podpálil mlýn“).
- Volitelně: místo na mapě dostane jméno podle události („Pahorek Kapitánky“) – pojmenování buňky/oblasti.

## Vazba na World/Islands (B06/B07)
- Ostrov = pole 16×16 buněk, vrstvy terén / dekor / stavby, Z-patra.
- Stopy předhistorie se umisťují jako běžné objekty ve vrstvě **dekor** (příp. stavby u ruin), takže nepotřebují novou vrstvu.
- Zápis kroniky má jen volitelnou **referenci na místo**: IslandId + souřadnice buňky + Z-patro. Kronika sama mapu nemění; změny mapy dělají stávající příkazy světa a kronika je jen zaznamenává.
- Mazání/přestavba buňky zápis nemaže (historie zůstává, i když ruina zmizí).

## Návrh dat (pro převod do backendu, k posouzení Willage-backend)
- `ChronicleEntry`: Id, IslandId, SessionId?, OccurredAt, Kind (číselník – kandidát na Intellenum), Importance, ActorViewerIds[], Location? (CellX, CellY, Z), TemplateKey + parametry (text se skládá až při zobrazení → lokalizace).
- `ChronicleChapter`: SessionId, IslandId, Title, souhrn.
- `IslandLore` (varianta A): IslandId, Seed, seznam vygenerovaných událostí + odkazy na umístěné stopy, příznak „objeveno“.
- Zdroj: doménové události, které už existují (návštěva, stavba, ledger, session/tick, EventSub). Kronika je jejich **odběratel** (projekce), ne nový zdroj pravdy.

## Pravidla a rizika
- Twitch: v kronice jen display name a veřejné akce; při smazání účtu diváka jméno anonymizovat. Žádné zprávy z chatu doslova bez souhlasu.
- Moderace: texty jen ze šablon, žádný volný text od diváků → nic urážlivého v kronice.
- Rozsah: držet malé. MVP = varianta B s 5–8 typy zápisů a kapitolami podle streamu.

## Otázky pro Jana
1. Začít variantou B (kronika diváků), A až později? (doporučení: ano)
2. Má být kronika veřejně čitelná i mimo hru (web stránka ostrova), nebo jen ve hře?
3. Smí zápisy přinášet odměny (prestiž, loot), nebo jsou čistě pamětní?
4. Má mít kronika i ostrov streamera (stream-only ostrov), divácký ostrov, nebo oba? (doporučení: hlavně stream ostrov, divácký jen osobní deník)
