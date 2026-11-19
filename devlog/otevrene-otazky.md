# Otevřené otázky

Zpět na [osnovu](index.md).

Otázky čekající na Jana, jak jsou zapsané v deníku a v `PROP.md`. Nic z toho tu nerozhodujeme.

## Terén a svět

- Erozi při generování dělat po blocích s připnutým okrajem (nezávislé na pořadí), nebo jen jednou na hrubém světě?
- Jádro vyzdvižené hory navazovat přes šev jako další funkci, nebo typ hory určovat jen pro celý masiv?
- Má hrubý svět určovat i počty minerálů a vodu dlaždice? Teď jsou minerály podle typu a voda podle srážek.
- Velikost bloku vesnice v metrech. Návrh 128 × 128 m se Janovi 18:58 líbil, ale ještě se nerozhodl.
- Délka klínu (teď 3 m) – Jan 17:38 ji nechal být, doladění je možné.
- Podmnožina hornin podle regionu / vesnice, nebo po bloku?
- Obnovit kopii sdílené tabulky v prototypu (`tools/sync_shared_table.sh`)? Pole pevnosti v kopii chybí.

## Voda a eroze za běhu

- Má mít krasová vyvěračka vlastní pravidlo? V E47b vyšla 0.
- Promítat úpravy terénu do 3D buněk podzemí? Zatím se změna terénu do podzemí nepromítá.
- Síla eroze při generování (800 kapek / cap 1 dává strže do 3 m na horách): víc, nebo míň?
- Runtime odplavování a usazování podle prahů a rychlosti proudění je zatím jen plán, studie není.

## Klient, server a data

- Schválit návrh formátu `WVB1`?
- Shoda výpočtu v C# a GDScriptu (float64, stejné pořadí operací) se zatím neověřovala.
- Rarita gen-v3: držet podíl tříd, nebo spíš bonusu ze zásobníku na serveru? Pásmo „vzácná“ je u nových prahů úzké.
- Starší otázky z blueprint v1: co přesně dělat při nedostatku hostitele, jak má vypadat šev povrchu, seed regionální desky, odebrání bloku, aritmetika na serveru.

## Vzhled

- Textura skryté stěny podzemí (hlína / skála) a síla ztmavení s hloubkou.
- 2D tileset: ověřit na telefonu plné kostky ve variantě `_klasik` a rohy Janových listů.

## Zdroje

- [`DENIK.md`](../DENIK.md) – „Další krok“ u položek A/2, A/3, A/6
- [`blueprint-studie/PROP.md`](../blueprint-studie/PROP.md) – otevřené otázky v1, v2, v2.1, v3
- [`navrhy/format-bloku-wvb1.md`](../navrhy/format-bloku-wvb1.md)
