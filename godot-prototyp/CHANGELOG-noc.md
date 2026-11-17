# Noční změny 17. 11. 2026 (cca 3:36–4:00 SEČ)

Checkpointy (bez `.godot`): `../godot-prototyp-checkpointy/cp0-v2.2-0336.tgz` (před nocí), `cp1-opravy-*`, `cp2-vegetace-kawaii-*`, `cp3-cesty-*`, `cp4-final-*`,
2. kolo: `cp5-kolo2-*`; 3. kolo: `cp6-pred-kolem3-*`, `cp7-kolo3-*`.
Generátor terénu, schéma `mix` i `vectors/vectors.json` beze změny (proto-v2.2, ověřeno re-exportem a `cmp`).

## 1. Opravy
- Pruhy mlhy na stěnách ostrova: 18 tenkých vrstev místo 7 (plynulý přechod).
- Žluté rámečky platných míst jen při vkládání (na startu nepřekáží).
- Popisky stran schované pod pravým panelem: kamera se při zobrazeném UI posune (h/v offset).
- Přesvícený domek z Blenderu: ztlumené albedo, drsnost 1, bez odlesků.

## 2. Vegetace (veg-v1)
- Samostatná vrstva nad buňkami, deterministická ze seedu bloku (účel `VEG`), invariantní vůči zrcadlení/rotaci.
- 8 druhů se skóre a povolenými povrchy; tráva/květiny jako MultiMesh s větrem, stromy/keř/kaktus z Blenderu (`blender/vegetace.py`).
- Panel: souhrn vegetace + rarita vegetace (zatímní, samostatně od materiálů).
- `vectors/veg_vectors.json` (nový soubor) pro backend. Přesný algoritmus v README.

## 3. Kawaii vzhled
- `terrain_toon.gdshader`: toon ramp, pastel, obrysy hran srázů z dat v meshi (CUSTOM0 + UV). T přepíná.
- Srovnání `shots/14_kawaii_pred_po.png`.

## 4. Cesty
- `scripts/roads.gd`: A* (krok ≤ 1 buňka, ne přes útesy, mlhu, mezery, stavby), průjezdní body, vrstva dlaždic, vegetace pod cestou zmizí.
- Režim C v UI, demo se 3 domky (`shots/15_cesty.png`), selftest pickingu sloupce a test nedosažitelného vrcholu hory.

## 5. Textury materiálů (Gemini v2)
- Kontrola švů (`tools/textury_kontrola.py`): originály mají viditelné švy (hlína, čedič, rudy). Opraveno levným prolnutím okrajů
  (`tools/textury_pripravit.py` → `assets/tex/01..10.png`), poměr šev/vnitřek z 1,5–3,6 na 0,6–1,2.
- Texture2DArray v toon shaderu jen jako detail (barva zůstává z materiálu), X přepíná, výchozí vypnuto. `shots/16_textury.png`, `16b_textury_detail.png`.

# 2. kolo (cca 4:00–4:15 SEČ)

## Cesty na terasy (rampy a schody)
- Krok A* až 4 buňky; cena: rovina 1, Δ1 1,5, Δ2–4 1 + 2,5·Δ (penalizace schodů). Útes > 4 buňky neprůchozí (selftest `SELFTEST cesty útes`).
- Vrstva cesty je jeden mesh: dlaždice, rampa (klín) pro Δ1 místo „schodu“, schody Δ2–4 (stupeň 0,25 m, sloupky). Terén se nemění.
- Demo: cesta od domku na terasu hory (hm 31 -> 49, 6 schodišť). `shots/15_cesty.png`, `shots/17_schody_detail.png`.

## Kawaii objekty
- `scripts/toon.gd` + `object_toon.gdshader` + `outline.gdshader`: stejný toon ramp a obrys (inverted hull) pro stromy, keře, kaktusy, domky a cesty;
  tráva a květiny toon bez obrysu. T přepíná vše. `shots/18_kawaii_objekty.png`.

## Vegetace (veg-v2)
- Písčina: kaktus 0,08 -> 0,11, suchá tráva 0,30 -> 0,42; skóre kaktusu 8 -> 5 (jinak by písčina byla „vzácná“ vždy).
- Jen vykreslení: kaktus 1,7×, suchá tráva 1,5× a tmavší. Popisky v galerii 13 nad středem bloku. `vectors/veg_vectors.json` = veg-v2.

## Zaoblené hrany (B)
- Stínovací trik v toon shaderu (lem horní plochy světlejší, okraj boční stěny tmavší), přepínatelné. `shots/19_hrany.png`.

## Hero
- `shots/20_hero.png` (+ `20b_hero_hrany.png`): ostrov doplněný o písčinu a louku s domkem a cestou, bez UI.

# 3. kolo (cca 4:12–4:30 SEČ)

## Opravy kola 2
- Schody 3–4 buňky se roztáhnou na 2 sloupce, když má trasa rovný nájezd; A* (stav se směrem příchodu) rovný nájezd preferuje (přirážka 2 za zatočení u velkého schodu). V demu 2 roztažené.
- Údolní sloupec: sloučení do plošiny + jedny schody, nic se nepřekrývá (v demu 1 sloučené údolí).
- Dlažba místo dlaždic se švy: malta + 2 × 2 kameny s variací (záměrný „cobble“ vzhled); schody/rampy mají obrys, dlažba ne.
- Panel vpravo ukazuje blok pod cestou/kliknutím/stavbou (dřív zůstával starý).

## Kopání (M)
- Kopat/položit vrchní buňku, inventář ostrova, aktuální rarita se mění (původní ne), vegetace na sloupci zmizí, zákazy (mlha, dno, strop, stavby, cesty).
- Delta bloku + `vectors/delta_sample.json` (návrh formátu delta-v0). `shots/21_kopani.png`.

## Stavby z lišty
- Záložka „Stavby“: Domek, Studna, Větrný mlýn, Políčko (Blender `blender/stavby.py`), průhledný zelený/červený náhled, R otočit, Esc zrušit.
- Cesty se napojí na dveře libovolné stavby (v demu 3 nové cesty). `shots/22_stavby.png`.

## Známé problémy
- Schody bez rovného nájezdu (zatáčka přímo pod schody) mají dál běh 1 buňku (u Δ4 strmé).
- ~~Obrysy objektů u ostrých low-poly tvarů nepravidelné~~ → opraveno v kole 4.
- Kopání jen vrchní buňky sloupce (výběr materiálu 1–9 doplněn v kole 4). Dno (lz 0) a strop nejsou v demu vyzkoušené, jen v kódu.
- ~~Náhled stavby po R na posledním místě~~ → opraveno v kole 4.
- Při pohledu z výchozí kamery (yaw 45°) jsou schody na západních stěnách schované; demo pro 15/17/20 používá yaw 315°.
- Hustoty a prahy rarity vegetace jsou zatímní.
- U textur je při velkém oddálení detail jemný až neznatelný; rudy v textuře se opakují po 4 m.

# 4. kolo (cca 4:28–4:50 SEČ)

## Hratelný build
- Oficiální export šablony Godot 4.7.2 (GitHub release `4.7.2-stable`, `Godot_v4.7.2-stable_export_templates.tpz`).
- `export_presets.cfg`: „Windows Desktop“ (x86_64) a „Linux“, PCK vložené do spustitelného souboru.
- `../build/willage-prototyp-windows.zip` a `../build/willage-prototyp-linux.zip`, uvnitř `WillagePrototyp/` + `HRAJ.txt` (ovládání česky).
- Modely `.glb` a textury `.png` se načítají přes `FileAccess.get_file_as_bytes("res://…")` (dřív `globalize_path`, v exportu nefunguje); mají `.import` s `importer="keep"`, aby se do PCK dostaly beze změny.
- Výstupy dema (screenshoty, delta) jdou v exportu do `user://` (`_out_dir`), v projektu dál do `res://`.
- Linuxový build ověřen pod xvfb s `-- --demo`: bez chyb skriptů, všechny SELFTESTy OK, modely i textury načtené, 26 screenshotů. Windows build tady spustit nejde (jen ověřeno, že je PE `MZ` a obsahuje assety).

## Video
- `-- --video`: scénář s plynulými přesuny kamery (smootherstep, 30 fps) – start, vložení bloku s rotací/zrcadlením/výškou, terasy, vítr ve vegetaci, cesty se schody, stavba mlýna s náhledem, kopání a položení vápence.
- Natočeno `--write-movie --fixed-fps 30` (1280 × 720 přes dočasný `override.cfg`), ffmpeg → `../build/demo.mp4` (H.264) + `../build/demo-vitr-cesty.gif`.

## Drobnosti
- Náhled stavby po R se přepočítá na aktuálním místě pod myší.
- Režim kopání: klávesy 1–9 vyberou materiál z inventáře (číslované v panelu, vybraný podtržený).
- Obrysy objektů: vyhlazené normály (průměr podle polohy vrcholu) uložené v CUSTOM0, `outline.gdshader` je používá → obrys bez děr na ostrých hranách.

## Oprava po review videa (4:53–5:10 SEČ): černé stěny
- Příznak: ve videu 0:24–0:28 (otočení kamery ke schodům, yaw 225°) stěny terénu téměř černé. Týkalo se i hry (Q/E) a buildů, viz původní `shots/17_schody_detail.png`.
- Příčina: `light()` v `terrain_toon.gdshader` a `object_toon.gdshader` násobil světlo `step(0.0, ndl + 0.2)` – plochy odvrácené od slunce (ndl < −0,2, tj. stěny −z a −x při slunci (−55°, 25°)) dostaly jen ambient 0,42 × tmavá barva hlíny. Z výchozích pohledů (yaw 45/315) byly skoro schované, při otočení se objevily najednou.
- Oprava: odvrácené plochy dostanou stínovou úroveň, plynule tmavší podle ndl (`shadow_level * mix(0.55, 1.0, smoothstep(-1, 0, ndl))`), nikdy jen ambient. Mesh, stíny ani obrys s tím nesouvisely.

## Experiment rozlišení bloku (17. 11., 11:50 SEČ)
- Nový režim `-- --res-test` (viz README „Experiment: rozlišení bloku“): stejný blok vykreslený v referenční mřížce 16 × 16 × 64 a v nastavitelné mřížce (`--res-xy`, `--res-z`, `--cell-xy`, `--cell-z`), výchozí 32 × 32 × 64 s buňkou 0,5 × 0,5 × 0,5.
- Hra se nemění: nové soubory `res_gen.gd`, `res_mesher.gd`, `res_test.gd`, `tools/res_combine.py`, v `main.gd` jen přepínač. Záloha před změnou: `../godot-prototyp-checkpointy/cp11-pred-32x32-1148.tgz`.
- Snímky: `shots/23_rozliseni_16_vs_32_{hora7777,kopec2302}_*.png`, navíc `23_rozliseni_16_vs_32x128_c0.5x0.25_hora7777_*.png`.
- Časy (llvmpipe, GDScript, 1 blok): 16 × 16 × 64 generování 20 ms, mesh 51–57 ms, 6–7 tis. trojúhelníků; 32 × 32 × 64 generování 77–83 ms, mesh 148–159 ms, 14–16 tis. trojúhelníků; 32 × 32 × 128 generování 156 ms, mesh 327 ms, 29 tis. trojúhelníků.
- Pozorování: v jemné mřížce se strmé přechody mezi terasami rozpadnou na drobné travnaté schůdky (víc sloupců padne do svahu profilu a detailní šum je ±1 buňka). Pro hladší útesy by šlo zostřit přechody profilu nebo dát strmým místům kámen.
