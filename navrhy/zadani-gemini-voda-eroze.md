# Zadání pro Gemini: proudění vody a eroze ve voxelové hře Willage

## Kontext hry
Willage je hra (Godot, GDScript, později C#), která má běžet i na telefonech. Terén generuje klient, server data ukládá a validuje. Hráč má létající ostrov složený z bloků a terén může kopat i stavět. Buňka (voxel) má 0,5 m, blok má třeba 64×64×256 buněk. Svět 8×8 bloků (256×256×128 m) se teď generuje 8,6 min na 1 jádře v GDScriptu.

## Jak je uložený terén
- Geologické vrstvy jsou spojité funkce. Každý blok má řídicí mřížku 16×16 bodů (rozteč 0,5 m) s výškou povrchu a s výškou spodní hranice každé vrstvy (2D matice na vrstvu, desetinná čísla). Mezi body se interpoluje bilineárně, i přes hranice bloků.
- Buňky se z funkcí jen vzorkují: 1 bajt = ID materiálu (pole n×n×4n). Minerály a dutiny (jedna jeskyně nebo nádrž na blok) se dopíší do buněk.
- Nový blok navazuje vrstvami na sousedy. Vrstva, která chybí na jedné straně, vyklíní.

## Data materiálů (sdílená tabulka)
12 povrchových materiálů (vzduch, tráva, hlína, písek, jíl, vápenec, žula, čedič, měď, železo, sníh) a 63 hornin podzemí. Každý materiál má:
- perm: propustnost (0–1, kolik propustí za čas)
- por: pórovitost (kolik vody se vejde do buňky)
- res: odpor povrchu; ret: zadržení vody
- load, cantilever: pevnost (kolik buněk nad sebou unese, jak daleko může přečnívat)
- ero_v: rychlost proudu (m/s), od které materiál eroduje
- ero_vol: kolik m³ vody musí přes buňku protéct, než ji odnese
- sed_v: rychlost, pod kterou se materiál usazuje
Příklad tráva: perm 0,25, por 0,4, ero_v 1,2, ero_vol 4000, sed_v 0,03. Horniny zatím nemají hodnoty eroze a prahy nejsou kalibrované (odhad podle Hjulströmovy křivky).

## Pravidla vody (rozhodnutí autora)
- Déšť je jen vizuální. Voda teče jen z pramenů (speciální buňky se stálým průtokem). Pramen uzavřený v dutině neteče.
- Přes okraj ostrova voda přepadá vodopádem do mlhy a dál se nesimuluje.
- Nic se nemění, nic se nepočítá. Po zásahu hráče se přepočte jen okolí po proudu, dokud se tok neustálí, a uloží se nové koryto.
- Tůně se plní po výškových hladinách jako předpočítané události, bez ticků: čas hladiny = objem / (přítok − odtok do podloží). Po naplnění jde část vody podzemím a zbytek přetéká nejnižším okrajem. Když je odtok ≥ přítok, vzniká ponor.
- Šíření: šířka proudu v celých buňkách = přítok / propustnost. Příklad: přítok 4 na písku (0,5) teče 8 buňkami, na materiálu 0,25 se rozšíří na 16, pokud jsou volné. Částečně zaplněná buňka se neřeší.
- Eroze: buňka má odpočet (kumulovaný objem vody při rychlosti ≥ ero_v). Rychlá voda materiál odplavuje, v klidné vodě se usazuje. Vykopání nebo položení buňky odpočet vynuluje. Události jsou v jedné prioritní frontě.
- Zpětná vazba: hlubší koryto pobere víc vody na buňku, proud se zúží a zrychlí a eroduje víc, dokud nenarazí na tvrdší materiál.
- Podzemí: voda teče po propustné vrstvě, plní dutiny (podzemní jezera) a uzavřené čočky, pak přetéká nejnižším výstupem (pramen ve svahu, stěna ostrova). Smí běžet na hrubší mřížce (32 na blok).

## Co už víme z měření
- Současné podzemí ve slovnících GDScriptu bere 3,4 GB (9,7 mil. buněk). Na hrubé mřížce je to 0,7 GB.
- Eroze: fronta s 1 mil. událostí stojí 2,6 µs na operaci. Přepočet po události je ale 230 ms na mapě 128², protože prochází celou mřížku (opravuje se na lokální).
- Rozpracované varianty podzemí: obyčejná pole, voda jako funkce nad maticemi vrstev plněná od nejnižšího z, Darcy přes konečné objemy (harmonický průměr K na stěnách, řídká matice, řešič CG).
- Povrch: maticový výpočet celé mapy najednou (mělká voda, gradient hladiny jako vektor rychlosti, případně uložený jako funkce na řídicí mřížce).

## Otázky pro tebe
1. Jaký algoritmus pro povrchový tok a erozi je nejlepší pro tato pravidla, aby běžel na telefonu (C#, případně compute shader)? Celá mapa maticově najednou, nebo lokálně?
2. Jak skloubit maticový výpočet se zásadou „bez ticků, předpočítané události“?
3. Jak nejlépe modelovat podzemí nad vrstvami jako funkcemi (2D matice na vrstvu) místo 3D buněk?
4. Jak kalibrovat ero_v, ero_vol a sed_v, aby eroze ve hře probíhala v rozumném čase (dny až týdny hry) a vypadala přirozeně?
5. Co v návrhu chybí nebo co povede k problémům (stabilita, determinismus kvůli validaci na serveru, švy mezi bloky)?
Navrhni konkrétní datové struktury a pseudokód.
