# Zdroje – studie trávy

Číslování odpovídá odkazům [n] v `RESERSE.md` a `README.md`. U každého zdroje je jedna věta o tom, co jsem z něj převzal.

1. https://www.youtube.com/watch?v=9dr-tRQzij4 – Acerola: *How Do Games Render Fur?* Převzal jsem princip shell texturingu (vrstvy nad sebou, hash na mřížce rozhoduje o chlupu, zúžení do kužele, `discard`).
2. https://godotshaders.com/shader/fur-grass-with-shell-texturing/ – implementace shell texturingu v Godotu 4. Odtud je index vrstvy, rozložení vrstev a test `vzdálenost > f(výška)`.
3. https://godotshaders.com/shader/multimesh-shell-texturing-fur/ – shell fur přes MultiMesh. Převzal jsem myšlenku vykreslit všechny vrstvy jedním draw callem a varování, že alpha hash v rendereru Compatibility nefunguje, proto používám `discard`.
4. https://www.reddit.com/r/godot/comments/1l8v28k/is_it_possible_to_do_shell_texturing_without/ – diskuse o počtu draw callů u shellů. Převzal jsem uložení indexu vrstvy do UV2 jediného meshe (1 materiál, 1 draw call) a doporučení 16–32 vrstev.
5. https://www.youtube.com/watch?v=Ibe1JBF5i5Y – Eric Wohllaib, GDC 2021: *Procedural Grass in Ghost of Tsushima*. Převzal jsem stéblo jako instanci s parametry (výška, šířka, náklon, ohyb), hash pro každé stéblo, generování z mřížky s náhodným posunem a LOD podle vzdálenosti.
6. https://archive.thedatadungeon.com/ghost_of_tsushima_2020/documents/gdc_2021/gdc_2021_procedural_grass_in_got.pdf – slajdy k [5]. Odtud je seznam dat pro každé stéblo (pozice, natočení, síla větru, hash, výška, šířka, náklon, ohyb).
7. https://www.gamedeveloper.com/design/using-vorticles-to-simulate-wind-in-i-ghost-of-tsushima-i- – vítr v Ghost of Tsushima. Převzal jsem stálý směr větru a poryvy jako posouvaný 2D šum.
8. https://github.com/gameidea-org/3d-grass-shader/blob/main/godot-4-grass.gdshader – tráva v Godotu 4. Odtud je uniform s pozicí hráče pro odhrnutí a vítr ze šumu posouvaného ve světových souřadnicích, maskovaný výškou na stéble.
9. https://godotshaders.com/shader/subsurface-scattering-foliage-with-trampling-and-wind/ – foliáž se šlapáním. Převzal jsem kombinaci posunu stébla do strany a dolů s útlumem podle poloměru.
10. https://penev.tech/labs/grass – interaktivní tráva (WebGL/WebGPU). Převzal jsem texturu stopy (útlum + otisk štětce), směr ohybu uložený v kanálech a pružinu „rychle nahoru, pomalu dolů“.
11. https://github.com/Nicogo1705/StrideGrassSystem – systém trávy pro engine Stride. Převzal jsem malou texturu šlapání s útlumem a otiskem každý snímek, ohyb od zdroje, návrat za pár sekund a LOD „nadbytečná stébla jako degenerované instance“.
12. https://deepwiki.com/doodlum/skyrim-community-shaders/6.2-grass-collision-system – kolize trávy ve Skyrim Community Shaders. Převzal jsem rolovací clipmapu stopy kolem kamery s časovým útlumem jako řešení pro velký svět (doporučení k integraci).
13. https://www.reddit.com/r/opengl/comments/xcjxnq/beaten_grass_trail/ – vyšlapaná stezka. Převzal jsem texturu „opotřebení“ s 2kanálovým směrem pohybu a sklopení stébel ve vertex shaderu.
14. https://cornfieldlabs.itch.io/grasspro – doplněk GrassPro pro Godot 4.7. Odtud je přehled funkcí (poryvy, stopy s návratem, kvalitativní úrovně) a zjištění, že řešení s compute shadery renderer Compatibility nepodporují.
15. https://nminhhoangit.itch.io/unity-grass-spawner – Unity Grass Spawner. Odtud je přístup bez compute shaderů (vše ve vertex shaderu) a mapa šlapání 256 px na spawner s časem návratu.
16. https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html – dokumentace Godotu k optimalizaci GPU. Převzal jsem zásady o draw callech, overdraw a fill-rate (vysvětluje, proč jsou shelly zblízka drahé).
17. https://www.shadertoy.com/view/4djSRW – Dave Hoskins: *Hash without Sine*. Odtud je funkce `hash12` ve sdíleném shaderu (citováno z paměti, stránku jsem v rámci studie neotevíral).

18. `godot-prototyp/scripts/veg_render.gd` (`_tuft`, `_flower`) a `scripts/veg.gd` (DENSITY) – interní: geometrie trsu trávy (6 trojúhelníkových stébel do kruhu, spodek tmavší), suché trávy a kvítků a hustota veg-v2 (louka 0,45 trsu na buňku); převzato pro variantu C (normalizováno na výšku 1, přidané UV pro ohyb).

Vlastní (bez vnějšího zdroje): varianta A2 „řidší koberec“ (shell s tlustšími téměř válcovými vlákny a podílem obsazených míst `fill`) a zápis času otisku do stopy.

Interní zdroje (náš prototyp, jen pro styl):
- `godot-prototyp/veg_wind.gdshader`, `terrain_toon.gdshader`, `object_toon.gdshader`, `scripts/mat.gd`, `scripts/main.gd`: pastelová paleta, toon ramp (stín 0,35, měkkost 0,12), nastavení prostředí a světla, izometrická kamera (yaw 45°, pitch −35°).
19. https://thebookofshaders.com/13/ – P. G. Vivo, J. Lowe: *The Book of Shaders*, kap. 13 Fractal Brownian Motion. Převzal jsem skládání několika oktáv šumu (fBm) se zvyšující se frekvencí a klesající amplitudou pro velké barevné fleky, suchá místa a jetel v `meadow_proc.gdshaderinc` (otevřeno 17. 11. 2026).
20. `napojeni-studie/shaders/terrain.gdshader` (`sand_detail = 2`) – interní: procedurální písek schválený Janem 14:27 (zrno `hash12(floor(q × 22))`, čeřiny, násobení barvy materiálu). Převzal jsem stejné zrno 22 na buňku a poměrové násobení barvy, aby písek a louka působily jako jedna sada.
