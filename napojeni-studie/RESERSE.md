# Rešerše – napojování terénu (louka, písek, voda)

Zdroje jsou v `ZDROJE.md`, v textu jen značky [n].

## 1. Kde se rozhoduje o přechodu: na hraně buňky, nebo v rohu

**Klasická mřížka (přechod na hranách buňky).** Každá buňka nese materiál a dlaždici vybírá podle sousedů. Sada 15 dlaždic kreslí hranici středem dlaždice, takže není jasné, čemu buňka patří; sada „blob“ 47 dlaždic drží hranici u okraje buňky, ale potřebuje 8 sousedů a hodně kresby [4][8]. Z 256 kombinací 8 sousedů zbude 47 díky pravidlu, že diagonála se počítá jen u dvou stejných ortogonálních sousedů [9]. Při více materiálech se obvykle zavádí priorita: „vyšší“ materiál přesahuje do nižšího [10]. Vnější a vnitřní rohy se těžko dělají stejně zaoblené [4].

**Duální mřížka (Oskar Stålberg, Bad North, Townscaper).** Zobrazovací dlaždice se posunou o půl buňky, takže každý roh dlaždice leží ve středu datové buňky. Dlaždice se vybere podle materiálů svých 4 rohů, tedy marching squares: 2⁴ = 16 kombinací, se symetrií jen 6 tvarů [1][3][4][11]. Hranice materiálu pak leží na hraně datové buňky (zarovnaná s logikou) a vnější i vnitřní rohy jsou stejně kulaté [4][5]. Datová mřížka zůstává autoritativní pro hratelnost, hledání cest a kolize; duální je jen pro „plošné“ podkladové zobrazení, objekty patří na hlavní mřížku [2][6][7]. Změna jedné buňky přepočítá 4 dlaždice kolem [6]. Cena: zobrazovací vrstva je o 1 větší a posunutá [7].

Pro Willage to platí i pro výšku: když jsou rohy dlaždice ve středech buněk, výška se mezi nimi dá interpolovat → svah místo schodu (pláž, břeh), zatímco data zůstanou celé vrstvy.

## 2. Prolínání materiálů (splat)

Splat mapa ukládá váhy materiálů do kanálů textury v daném rozlišení na metr [12]. Výškové prolínání (height blend) ukáže materiál, který je „výš“ ve své výškové textuře, s parametrem šířky přechodu: malá = ostrá hranice, velká = lineární prolnutí [12][13]. Ve studii používám splat 16 texelů na buňku a ostrou toon hranici s obrysem; výškové prolínání s výškovými texturami materiálů (Gemini) je připravené jako další krok.

## 3. Břeh, pěna, vlny

Pěna se obvykle odvozuje z hloubky vody nad terénem; hloubkový buffer ale měří po paprsku kamery a u ortografické izometrie a malých vodních ploch dává nerovnoměrný pás [14][15]. Spolehlivější je předpočítané vzdálenostní pole k břehu: pevný pás pěny + linie, které postupují k břehu podle `fract(vzdálenost·f − čas·v + šum)` a šumem se trhají [15][16][17]. Ve studii se pole počítá z výškové mapy (chamfer, 2 průchody) a stejné pole slouží i pro mokrý písek.

## 4. Pláž a mokrý písek

Profil pláže: suchý písek vzadu → plochá berma → mírně skloněný mokrý předbřeh, kam dobíhají vlny → dno [18]. Mokrý písek je tmavší a sytější, protože voda v pórech sníží rozptyl a světlo se víc pohltí [19][20]. Ve studii: ztmavení do 0,9 buňky od vody a do 0,35 m nad hladinou.

## 5. Tráva u okraje

Hustota trávy se násobí maskou ze vzdálenosti k okraji (šířka + plynulý náběh) [21]. Ve studii: v pásu 1,2 buňky od okraje louky klesá hustota trsů až na 15 %, trsy jsou nižší a přibývá suchých; kvítky jen uvnitř louky.

## 6. Švy mezi bloky

U voxelových chunků stejného rozlišení švy nevzniknou, když obě strany používají stejné vzorky na hranici: N buněk = N+1 vzorků, chunk čte jeden vzorek za kladnou hranici a počítá stejnou aritmetikou [22][23]. Přechodové buňky (Transvoxel) jsou potřeba jen mezi různými LOD [22]. Pro Willage: mesher prototypu už čte okraj sousedů (obal 18 × 18) [24]. U duální mřížky patří dlaždice bloku, jejíž levý horní roh je v bloku, a čte 1 řadu buněk od východního a jižního souseda. Výšky stran se dorovnávají už v datech (block_gen: auto / blend1–4 / keep) [24], vizuální přechod materiálu na hranici bloku pak dělá samotná dlaždice.
