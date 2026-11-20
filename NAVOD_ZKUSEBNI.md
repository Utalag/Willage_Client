# Zkušební větev `zkusebni-vse` – návod pro Jana

Na větvi jsou všechny změny z Bloků 2–4 (E78–E87, E89–E94). Všechny přepínače jsou ve výchozím stavu **vypnuté**, takže
hra je stejná jako na `main`. Zapínáš je v panelu přímo ve hře. Do `main` se nic neslučuje.

## 1. Stáhnout větev

V GitHub Desktopu: *Current branch → zkusebni-vse* (případně nejdřív *Fetch origin*).

Nebo v terminálu:

```
git fetch origin
git switch zkusebni-vse        # první přepnutí: git switch -c zkusebni-vse origin/zkusebni-vse
```

Konkrétní stav: tag `zkusebni-vse-1`.

## 2. Otevřít v Godotu

1. Godot 4.7 → *Import* → složka `godot-prototyp` (soubor `project.godot`).
2. Spustit hru klávesou **F5** (hlavní scéna `main.tscn`).
3. První spuštění chvíli trvá, Godot importuje soubory.

## 3. Panel přepínačů

- Panel je **vlevo nahoře** pod nápovědou: *„▾ Přepínače (zkušební E95)“*.
- Kliknutím na nadpis se panel **sbalí / rozbalí**.
- **Najeď myší na řádek** a za chvilku se ukáže bublina: co přepínač dělá, z jakého pokusu je, kolik stojí a co mění.
- Skupiny: **Voda**, **Geologie**, **Výřez**, **Měřítko a zobrazení**.
- Číselné parametry (posuvník / počítadlo) se ukážou pod svým přepínačem, až ho zapneš.
- Dole je tlačítko **Vše vypnout** (návrat na výchozí hru) a řádek se stavem (čas přestavby, otisk vody).

### Co se stane po přepnutí

- **Terén a voda** (E79, E81, E82, E85, E87, E92, E94, Metry): ostrov se **přegeneruje** (asi 4–7 s, hra na chvíli stojí).
  Kamera i panel zůstanou, **vykopané buňky a stavby se ztratí**.
- **E85 nekopat dno a okraj** a **E86 otočení výřezu** platí hned, bez přegenerování.
- **E90 LOD krajina** se postaví pod ostrovem (asi 1–1,5 s). Je to jiná funkce světa než ostrov, jen ukázka pásem LOD.
- **E91 průhlednost** a **Svislý řez** fungují hned za běhu (shadery). První zapnutí může na chvíli zaseknout obraz
  (Godot překládá shadery).

### Svislý řez

1. V panelu dole ve skupině *Měřítko a zobrazení* vyber **Svislý řez → osa X** nebo **osa Z**.
2. Posuvníkem **poloha řezu** projížděj ostrovem. Posun je plynulý, nic se nepřegenerovává.
3. Uvidíš vrstvy hornin, podzemní vodu (modře) a jeskyně. Řezaná plocha má barvu materiálu buňky.
4. Ostrov můžeš otáčet (Q/E). Odřízne se vždycky ta část, která je blíž ke kameře.

## Poznámky

- Přepínače se nepamatují mezi spuštěními hry. Po novém spuštění je všechno zase vypnuté.
- Kombinace, které dělají potíže, jsou popsané v `blueprint-studie/PROP.md` (E95) a v `DENIK.md`.
- Snímky panelu a řezu jsou v `blueprint-studie/shots/e95/`.
