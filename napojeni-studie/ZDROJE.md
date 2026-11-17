# Zdroje – studie napojování terénu

Číslování odpovídá značkám [n] v `RESERSE.md`, `README.md` a v deníku. Čerpáno 2026-11-17.

| # | Zdroj | Co jsem převzal |
|---|---|---|
| 1 | BorisTheBrave: *Quarter-Tile Autotiling* (2023) – https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/ | Popis duální mřížky: dlaždice posunuté o půl buňky, výběr dlaždice podle terénů v rozích = marching squares. |
| 2 | Oskar Stålberg, vlákno na X (Thread Reader) – https://threadreaderapp.com/thread/1448248658865049605 | Duální mřížka je hlavně pro „plošné“ podkladové sady (terén); objekty a hratelnost zůstávají na hlavní mřížce; obě reprezentace držet v kódu. |
| 3 | Oskar Stålberg: *The Story of Townscaper*, Konsoll 2021 – https://www.youtube.com/watch?v=5xrRTOikBBg | Původ techniky (Bad North, Townscaper), stavění z rohů místo z buněk. |
| 4 | jess::codes: *Draw fewer tiles – by using a Dual-Grid system!* – https://www.youtube.com/watch?v=jEWFSv3ivTg | Srovnání sad 15 / 47 / 16 dlaždic, nejednoznačnost klasické sady, 2⁴ = 16 konfigurací rohů, stejně zaoblené vnitřní i vnější rohy. |
| 5 | jess-hammer/dual-grid-tilemap-system-godot – https://github.com/jess-hammer/dual-grid-tilemap-system-godot | Implementace v Godotu: datová vrstva + zobrazovací vrstva, 16 pevných pravidel. |
| 6 | Nick Chalvatzakis: *Dual grid system for auto-tiling* – https://nickchalvatzakis.com/blog/dual-grid-system-for-auto-tiling | Datová mřížka je autoritativní (logika, hledání cest), vizuální jen zobrazuje; při změně buňky stačí přepočítat 4 okolní dlaždice. |
| 7 | Nerulio: *Dual Grid Tileset — 16 Tiles Instead of 47* – https://nerulio.com/en/game/dual-grid-tileset/ | Náklady: zobrazovací vrstva je posunutá a o 1 větší než data; kolize zůstávají na datové mřížce; neplést s 16 sadou podle hran. |
| 8 | cr31: *Blob Tileset* – https://cr31.co.uk/stagecast/wang/blob.html | Blob = 47 dlaždic jako podmnožina Wang dlaždic se 2 hranami a 2 rohy, bitové váhy sousedů. |
| 9 | Stormcloak Games: *Blob layouts and tilesets* (2022) – https://stormcloak.games/2022/02/09/blob-layouts-and-tilesets | Pravidlo: diagonála se počítá jen když jsou oba sousední ortogonální sousedé stejní (256 → 47). |
| 10 | bunyip/autotile (Go) – https://pkg.go.dev/github.com/matjam/bunyip/grid/autotile | Přehled typů pravidel Edge16 / Blob47 / Corner16 (= duální mřížka) / Wang; u Wang „vyšší barva vyhrává a přesahuje nižší“ → priorita materiálů v přístupu 1. |
| 11 | John Wigg: *SphereScaper* – https://john-wigg.dev/SphereScaper/ | Marching squares na dlaždicích: 16 případů, se symetrií 6 modelů. |
| 12 | InnoGames: *Terrain Shader in Unity* – https://blog.innogames.com/terrain-shader-in-unity/ | Splat mapa (váhy materiálů v kanálech), rozlišení v px na metr, výškové prolínání s „hloubkou“. |
| 13 | URP Rendering in Practice, Case 20.5 *Height Blend* – https://gametech.byte888.com/urp/en/case/20-5.html | Vzorec výškového prolínání a parametr šířky přechodu (malý = ostrý, velký = lineární). |
| 14 | Cyanilux: *Shoreline Shader Breakdown* – https://www.cyanilux.com/tutorials/shoreline-shader-breakdown/ | Pěna z hloubky pod hladinou; svislá (světová) hloubka místo hloubky po paprsku kamery. |
| 15 | URP Rendering in Practice, Case 19.7 *Shore Foam* – https://gametech.byte888.com/urp/en/case/19-7.html | Pevný pás pěny + linie postupující k břehu `fract(shore·f − t·v + šum)`; omezení hloubkového bufferu → vzdálenostní pole. |
| 16 | J. Panuelos: *Toon Shaders: Animated Water Foam* (2020) – https://jpanuelos.com/2020/10/18/GhibliWater.html | Předpočítaná vzdálenost k břehu a sinusové vlnky z ní (toon/Ghibli styl). |
| 17 | Chromosphere: *Yuki 7* case study – https://chromosphere-la.com/case-study/yuki7study6/ | Pěna kolem břehů z distance fields, procedurální pásy. |
| 18 | Texas A&M OCNG 251: *Parts of a beach* – https://odsl.tamu.edu/courses/ocng251/wk09/obj03-beach-parts.html | Profil pláže: suchá zadní pláž → berma → mokrý předbřeh (swash) → dno; jemný písek = mírnější svah. |
| 19 | Hong Kong Observatory: *Why does wet sand look darker than dry sand?* – https://www.hko.gov.hk/en/education/earth-science/optical-phenomena/00362-why-does-wet-sand-look-darker-than-dry-sand.html | Proč je mokrý písek tmavší (méně rozptylu, víc pohlcení) → ztmavení a mírné zesycení. |
| 20 | J. Lekner, M. C. Dorf: *Why some things are darker when wet*, Applied Optics 27 (1988) – https://doi.org/10.1364/ao.27.001278 | Fyzikální model ztmavení (film vody, odraz zpět do zrn). |
| 21 | GrassCore – dokumentace – https://redicionstudio.com/GrassCore/GrassCore_Documentation.pdf | Řídnutí trávy u okraje: šířka + plynulý náběh (EdgeFalloff) násobí hustotu. |
| 22 | E. Lengyel: *Voxel-Based Terrain for Real-Time Virtual Simulations* / Transvoxel – https://transvoxel.org/ | Stejné vzorky na hranici chunků → bez švů; přechodové buňky jen při rozdílném LOD. |
| 23 | jeromem.dev: *Seamless Chunked Voxel Terrain* – https://jeromem.dev/Notes/Seamless+Chunked+Voxel+Terrain | N buněk = N+1 vzorků, číst o 1 vzorek za kladnou hranici, stejná aritmetika na obou stranách → švy sedí. |
| 24 | Interní: `godot-prototyp/scripts/block_gen.gd`, `mesher.gd`, `terrain_toon.gdshader` | Dorovnání stran (auto / blend1–4 / keep, 3 buňky, max 6), obal sousedů 18 × 18, toon ramp a obrysy z CUSTOM0 (jen čteno a zkopírováno). |
| 25 | Interní: `trava-studie/` (varianta C, schválená 13:05) | Trsy a kvítky veg-v2 jako MultiMesh, shader `grass_tuft` a vítr (zkopírováno). |
| 26 | Interní: `tileset-trava-pisek/` | Dřívější 2D sada tráva/písek v režimu Match Corners (také rohová logika). |
| 27 | Interní: `godot-prototyp/assets/tex/01.png` (tráva), `03.png` (písek) – textury Gemini v2 | Zkopírováno do `assets/tex/`; detail jako poměr k průměrné barvě textury (stejně jako `terrain_toon.gdshader`). |
