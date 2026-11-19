# Model světa: buňky z funkcí

Zpět na [osnovu](index.md).

Stav: popis toho, jak je svět postavený dnes, sepsaný 19. 11. 2026. Inspirací byl rozbor, který Jan nechal udělat v ChatGPT nad tímto devlogem. Čísla jsou jen z našich měření. Body označené **hypotéza** zatím nikdo nerozhodl.

## Shrnutí

Willage je buněčný svět. Buňka je základní prostorová jednotka: má materiál, dá se vykopat, položit a vidět. Počítat všechno po buňkách je ale moc drahé (E50: svět 512 × 512 × 256 = 67 milionů buněk, generování 515 s na jednom vlákně). Proto se buňky neukládají ani nepočítají všude. Odvozují se z funkcí a z kompaktních struktur a každý systém pracuje na té úrovni, která mu stačí.

Není to tedy „funkce místo buněk“. Funkce popisují, z čeho se buňky složí.

## Čtyři úrovně

| Úroveň | Co obsahuje | Zdroj pravdy? |
|---|---|---|
| Definice | povrch `hm_f`, hranice vrstev `bs[k]`, blueprint, seed, minerály a dutiny | ano |
| Pásma | intervaly `[lo, hi)` po sloupcích s materiálem a pórovitostí, propojená do těles | ano (kompaktní zápis souvislých buněk) |
| Vzorkované buňky | mřížka v potřebném rozlišení pro vykreslení, kolize a kopání | ne, dají se kdykoli znovu spočítat |
| Odvozený stav | voda na povrchu i v podzemí, průtoky, události s absolutním herním časem, eroze | ne, přepočítá se po změně |

Tři úspory, které se doplňují:

- buňku jde zrekonstruovat z definice podle polohy, nemusí být uložená;
- souvislé pásmo nahradí všechny buňky uvnitř;
- z ustáleného stavu vody se spočítají časy událostí, takže se nesimuluje každý tik.

Rozdíl je vidět na podzemní vodě (svět svet64): buňky ve slovníku 4002 MB a 155 s, pole 575 MB a 36 s, funkce nad vrstvami 288 MB a 0,6–1,7 s. Podrobnosti jsou na stránce [Algoritmy vody](voda-algoritmy.md).

## Který systém pracuje s čím

| Systém | Pracovní reprezentace |
|---|---|
| Generování geologie | funkce a blueprint |
| Složení materiálu | pásma |
| Vykreslení | vzorkované buňky, mesh |
| Kolize | buňky vzorkované jen kolem hráče |
| Kopání | změna buněk na místě a přepočet dotčených pásem |
| Povrchová voda | řídicí mřížka, priority-flood a D8 |
| Podzemní voda | pásma a graf těles |
| Eroze a usazování | události a změna povrchu |

## Srovnání s jinými přístupy

- **Klasický voxelový engine** ukládá a počítá každou buňku. Je pružný (jeskyně, převisy, oblouky), ale drahý na paměť a výpočet.
- **Dwarf Fortress** (hlavní inspirace) má hrubé generování světa (výška, teplota, srážky, odvodnění, biomy, řeky, geologie) a pak hraje na explicitních dlaždicích po úrovních Z. Odtud máme hrubý svět a dlaždice. Liší se to tím, že my stav buněk co nejvíc odvozujeme z funkcí a pásem.
- **Vrstvené výškové pole** (layered heightfield) popisuje vrstvy výškami hranic. Je to přesně princip `bs[k]`, včetně mocnosti vrstvy jako rozdílu dvou hranic.
- **Implicitní terén** popisuje prostor funkcí `F(x, y, z)`. Hodí se na tvary, které vrstvy neumí.
- **Řídké objemy** (octree, DAG, komprimované intervaly) ukládají jen použité části prostoru. Naše pásma jsou jednoduchá varianta.

Přehled těchto přístupů je v článku [A Review of Digital Terrain Modeling](https://doi.org/10.1111/cgf.13657) (Galin a kol., Eurographics 2019).

## Kde jsou hranice modelu

Funkce `bs[k](x, y)` dává pro každé místo jednu výšku. Sama proto neumí převis, skalní oblouk ani nepravidelnou jeskyni. Dutiny dnes pokrývají pásma (víc intervalů ve sloupci), ale složitější tvary ze hry, například nepravidelný výkop nebo síť chodeb, se jimi popisují hůř.

**Hypotéza:** tam, kde změna přestane jít popsat funkcemi a pásmy, vznikne lokální oblast s plnými buňkami, a jen tam. Celý ostrov kvůli jedné jeskyni do voxelů převádět nechceme.

## Změny od hráče

**Hypotéza:** definice zůstává nedotčená a změny se ukládají zvlášť jako překryv:

```text
definice → vzorkování buněk → překryv změn → skutečný stav buňky
```

U průzkumného světa to znamená generovat deterministicky ze stejných funkcí a ukládat jen změny. U osobního ostrova to navazuje na formát bloku WVB1, který dnes ukládá celé pole bloku. Jak se k sobě oba způsoby mají, je otevřené.

## Dva světy a přenos terénu

Průzkumný svět (velký, po chunkách) a osobní ostrov (začíná na 4 blocích, nejvýš asi 16) sdílí stejnou geologii a vodu. Hráč přenese výřez s celou geologickou definicí, otočí ho, posune ho do výšky a připojí ho. Existující bloky se nemění, přizpůsobí se jen nový. Voda se nepřenáší hotová, po vložení se přepočítá v novém okolí. Otevřené body jsou v [`TODO.md`](../TODO.md).

## Zdroje

- [Svět a měřítko](svet-a-meritko.md) (E49, E50)
- [Algoritmy vody](voda-algoritmy.md) (E52, E55, E58)
- [Blueprint terén](blueprint.md)
- [`TODO.md`](../TODO.md)
