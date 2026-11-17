# Rešerše: jak vznikají ložiska, sloje a žíly (pro realističnost ore-v0)

Krátce, jen co ovlivňuje tvar a hostitele v ore-v0. Zdroje jen jako značky, seznam v `ZDROJE.md`.

## Žíly (vein) – měď
- Žíla je deskovité těleso, které vyplní puklinu minerály vysráženými z horkých roztoků [1]. Pukliny mají převládající směr (podle napětí v hornině), takže skutečné žíly jsou spíš **ploché desky s jedním hlavním směrem** než klikatá trubka.
- Měď je nejčastěji v porfyrových ložiscích u žulových (granitoidních) intruzí, jako síť tenkých žilek a rozptýlené rudy [2], a ve skarnech na styku žuly s vápencem [3]. Hostitel žula + vápenec z návrhu tedy sedí.
- Pro hru: náhodná procházka s 90° kroky dává „trubkovou mříž“ (viz `37_lozika_hora.png`). Realističtější by byla žíla 1–2 buňky silná v jedné rovině (deska) s jedním hlavním směrem na blok, nebo síť tenkých žilek (stockwork) v okolí jednoho bodu [1][2].

## Čočky (pocket) – železo
- Čočka je těleso uprostřed silné a k okrajům tenké [5]. BFS s p = 0,55 do všech 6 směrů dává kulatý shluk; plošší čočka by vznikla s menší svislou pravděpodobností (např. vodorovně 0,6, svisle 0,35).
- Železo se v přírodě těží hlavně z páskovaných železných rud (BIF), což jsou mocné **vrstvy** [4], a z magnetitových skarnů na kontaktu intruze s vápencem [3]. Hostitel žula + čedič je herně v pořádku, vápenec jako záložní hostitel (L4) má oporu ve skarnech.

## Sloje (layer) – jíl
- Jíl vzniká zvětráváním hornin a zůstává v půdě, nebo ho voda odnese a usadí ve vrstvách v klidné vodě (jezera, varvy) [6]. Plochá vrstva v hlíně a písku v hloubce půdy tedy sedí. Svislá pravděpodobnost 0,1 dává sloj 1–2 buňky silnou.
- V prototypu je jíl i základní materiál podloží (pod hlínou). Ložiskový jíl a jíl z půdy jsou v datech stejné ID, což komplikuje kontrolu souhrnu (viz README, otázky).

## Jeskyně (cave-v0, gen-v3)
- Nejběžnější jeskyně jsou krasové: voda s kyselinou uhličitou rozpouští vápenec podél vrstev, zlomů a puklin [7]. Jeskyně tedy patří hlavně do vápence a mají tvar podle vrstvy → tvar `chamber` (vodorovně víc než svisle) v pásmu vápence.
- Části jeskyně pod místní hladinou podzemní vody jsou zatopené [7] → voda v jeskyni sahá jen do hladiny, nad ní je suchý vzduch.
- Rozpor pro hru: vápenec, ve kterém jeskyně vznikají, je v reálu propustný (proto se rozpouští). Ve hře je jednodušší brát ho jako nepropustný, jinak voda z jeskyně prosákne (viz `shots/gen3_sim.txt`).

## Voda v zemi (gen-v3)
- Hladina podzemní vody je horní okraj nasycené zóny, kde jsou všechny póry plné vody; nad ní je nenasycená zóna [8] → gen-v3 plní propustnou oblast odspodu do hladiny.
- V jemné zemině vzlíná voda nad hladinu (kapilární lem) a nad nepropustnou vrstvou může být zavěšená hladina [8] → „mokrá hlína nad jílem“ je věrohodná, studie ji zatím nedělá.
