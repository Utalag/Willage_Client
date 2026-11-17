# Zdroje – studie skály

Číslování odpovídá odkazům [n] v README a v komentářích. U zdrojů označených „(z boxu 403)“ stránka existuje, ale ze serveru studie ji nešlo otevřít, takže jsem obsah z ní tentokrát neověřoval.

1. S. F. F. Gibson: Constrained Elastic SurfaceNets: Generating Smooth Models from Binary Segmented Data (MERL TR99-24, MICCAI 1998) – https://www.merl.com/publications/TR99-24 – princip Surface Nets: jeden vrchol v každé krychli mřížky, kde se mění znaménko, a plochy přes hrany se změnou znaménka (přístup C, `scripts/nets_mesher.gd`).
2. M. Lysenko: Smooth Voxel Terrain (Part 2), 0fps.net, 2012 – https://0fps.net/2012/07/12/smooth-voxel-terrain-part-2/ – praktická podoba naive Surface Nets: vrchol jako průměr průsečíků hran, quad z vrcholů 4 krychlí kolem hrany (přístup C).
3. M. Lysenko: Ambient occlusion for Minecraft-like worlds, 0fps.net, 2013 – https://0fps.net/2013/07/03/ambient-occlusion-for-minecraft-like-worlds/ – AO ve vrcholech kostek a volba úhlopříčky podle AO (přístup A, převzatý mesher prototypu `scripts/cube_mesher.gd`).
4. S. Worley: A Cellular Texture Basis Function, SIGGRAPH 1996 – https://dl.acm.org/doi/10.1145/237170.237267 (z boxu 403) – buněčný šum; praskliny = místa, kde F2 − F1 je malé (`rock.gdshader`).
5. M. Teschner a kol.: Optimized Spatial Hashing for Collision Detection of Deformable Objects, VMV 2003 – https://matthias-research.github.io/pages/publications/tetraederCollision.pdf – prvočísla 73856093, 19349663, 83492791 pro hash celočíselné polohy (deterministický šum vrcholů v B a C, výběr variant v D).
6. D. Hoskins: Hash without Sine, Shadertoy – https://www.shadertoy.com/view/4djSRW (z boxu 403) – hash `fract(p * 0.1031)…` pro value noise v shaderu (`h31` v `rock.gdshader`).
7. I. Quilez: Voronoi – basic, Shadertoy – https://www.shadertoy.com/view/MslGD8 (z boxu 403) – sinusový hash 3D bodů pro Worleyho buňky (`h33` v `rock.gdshader`).
8. B. Golus: Normal Mapping for a Triplanar Shader, 2017 – https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a (z boxu 403) – triplanární mapování a ostřejší váhy podle normály (`pow(abs(n), 4)`) (`rock.gdshader`).
9. J. Peck (Auburn): FastNoiseLite – https://github.com/Auburn/FastNoiseLite – knihovna šumu, kterou má Godot vestavěnou (tvar vzorku v `chunk.gd`, šum hustoty v C).
10. Godot Engine – Spatial shaders (dokumentace) – https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html – vestavěné proměnné (`MODEL_MATRIX`, `VIEW_MATRIX`, `light()`), `dFdx`/`dFdy` pro ploché fazety.
11. Blender Python API – bmesh.ops – https://docs.blender.org/api/current/bmesh.ops.html – `bisect_plane`, `holes_fill`, `triangulate`, `recalc_face_normals` pro odštípnuté kameny (`blender/kameny.py`, přístup D).
12. J. Motomura: GuiltyGearXrd's Art Style: The X Factor Between 2D and 3D, GDC 2015 – https://www.gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The – obrys metodou inverted hull (posunutý obal kreslený zevnitř) (`outline.gdshader`).
13. JohnBrx: Adding 3D Terrain to my 2D Game [DEVLOG], YouTube – https://www.youtube.com/watch?v=ez68sFkO6Qo – video od Jana; z něj police/terasy v prototypu. Tady z něj vycházejí vodorovné římsy v hustotě (C) a pruhy vrstev v shaderu.
14. W. E. Lorensen, H. E. Cline: Marching Cubes, SIGGRAPH 1987 – https://dl.acm.org/doi/10.1145/37402.37422 (z boxu 403) – alternativa k Surface Nets, jen pro srovnání v README, v kódu se nepoužívá.

Vlastní věci bez zdroje: tvar vzorku, zaoblení vrcholů mřížky k těžišti plných buněk (B), zostření interpolace smoothstepem a útlum šumu podle „hmotnosti“ okolí (C), hybrid podle souvislých komponent (D) a paleta a toon světlo převzaté z prototypu Willage.

## Doplněno 17. 11. odpoledne (optimalizace C na celý blok)
15. Godot Engine – C# / .NET (dokumentace) – https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html – co je potřeba pro C# v Godotu (sestavení Godot .NET a .NET SDK); podklad pro odhad integrace horké smyčky v C#.
16. Godot Engine – About godot-cpp (GDExtension v C++) – https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html – druhá cesta k nativní rychlosti (GDExtension), zatím jen jako možnost.
17. J. Peck (Auburn): FastNoiseLite.cs – https://github.com/Auburn/FastNoiseLite/blob/master/CSharp/FastNoiseLite.cs – C# verze stejného šumu (licence MIT), zkopírovaná do `csharp_bench/`; dává stejné hodnoty jako šum vestavěný v Godotu (benchmark vytvoří přesně stejný počet trojúhelníků).
18. Godot Engine – FastNoiseLite (třída) – https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html – mapování typů (TYPE_SIMPLEX_SMOOTH = OpenSimplex2S, FBM, oktávy), aby C# benchmark počítal stejný šum jako Godot.
