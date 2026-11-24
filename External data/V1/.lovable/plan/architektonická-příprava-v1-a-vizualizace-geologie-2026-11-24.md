# Architektonická příprava v1 a vizualizace geologie

## Vyhodnocení současného stavu
- 3D již vykresluje pouze viditelné voxelové **stěny** v jednom meshi, nikoliv všechny vnitřní buňky. Stále však vzorkuje celý objem.
- 2D průřez používá skutečný `GeologicalFieldEvaluator`, ale má pevné rozlišení 0,25 m; současný 3D řez je odvozený z objemové mřížky.
- Varianta B není jen změna zobrazení: chybí ořezané současné hranice těles po zlomech a mladší sedimentaci. Přímé kreslení původních ploch by mohlo zobrazovat neexistující geologii.

**Doporučení: nyní realizovat variantu A, variantu B připravit jako pozdější hybridní výstup.**

## Architektonický návrh v1
Podrobný návrh je v `docs/geology/ARCHITECTURE_V1_PROPOSAL.md`; obsahuje diagram, datové kontrakty, API, tok bodového vyhodnocení, index, migraci a rizika.

- Oddělit globální, regionální a lokální modely s vlastní historií a měřítkem; chunk bude pouze výstupní oblastí.
- Oddělit události, tělesa, geometrii, materiály a transformace; vztah událost–těleso je mnoho ku mnoha.
- Zachovat jedinou explicitní chronologii a skutečné inverze napříč úrovněmi; lokální model nezačíná prázdným podložím.
- Původní historii zachovat, odvozenou kompilaci verzovat a konzervativně invalidovat.
- Navrhnout BVH v globálních souřadnicích se zvláštním seznamem neomezených operací; hledat kandidáty i v historických souřadnicích, ne pouze u současného bodu.
- Existující procesy převzít adaptéry bez změny matematiky. Hierarchii, nové formáty a index zatím **neimplementovat**.

## Realizace po schválení – varianta A
1. **Přesný průřez ve 3D i 2D:** sdílené nastavení X/Y/Z a poloha; samostatné rozlišení 2 / 1 / 0,5 / 0,25 m. 3D rovina zobrazí přímo vzorky evaluatoru, ne kvantovaný voxelový cap.
2. **Odhalení vnitřku:** zachovat povrchový mesh a možnost odříznout zakrývající část; vyhnout se zdvojení ploch a nesprávnému označení hrubého capu za přesný řez.
3. **Inspektor:** klik na povrch zachová voxelovou inspekci; klik na průřez ve 2D i 3D vyhodnotí stejný skutečný střed vzorku a jeho původ.
4. **Viditelnost a hranice:** zachovat barvy materiálů, přidat rozlišení zdrojových sedimentárních vrstev a jejich hranic; vizuální skrytí zdrojů oddělit od vypnutí události v geologické historii. Neslibovat plnohodnotná tělesa či přesné analytické plochy zlomů, které v0 zatím nemá.
5. **Výpočty jen pro potřebný pohled:** v 2D nevytvářet nový objem ani mesh; posun průřezu vzorkuje jen rovinu. Kamera, paleta a viditelnost nezmění geologické vzorkování. Uchovat platná data pro návrat do 3D.
6. **Ověření a dokumentace:** testy os/pickingu, vrstvy stejného materiálu, skutečné shody s evaluátorem a nezávislosti rozlišení; existující geologické testy; ověření worker požadavků a ovládání ve 3D/2D na desktopu i menším displeji. Dokumentovat skutečná omezení a měřit místo odhadovaných slibů.

## Technické hranice změny
- Three.js zůstane pouze renderer. `src/core`, `src/geology`, `src/voxel`, `src/diagnostics` zůstanou bez Reactu, Three.js a DOM.
- Žádné nové procesy, žádný server, žádné přepisování algoritmů sedimentace, vrásnění a zlomů.
- Data průřezů mohou získat odvozenou identitu vrstvy pro filtry; nejde o změnu uloženého JSON. `SCHEMA_VERSION` a `algorithmVersion` zůstanou beze změny, pokud se jejich skutečný kontrakt nebo algoritmus nemění.
- A neodstraní úplné objemové vzorkování potřebné pro současný 3D voxelový povrch. Chunking, nové v1 JSON a obecná geometrická extrakce B patří do dalších samostatných etap.

## Výsledek
Návrh v1 bez zásadního přepisu jádra a ověřená vizualizace A s nezávisle detailním, posuvným průřezem a zachovaným geologickým původem bodů.