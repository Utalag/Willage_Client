# Rešerše: tráva pro Willage (vysoká „srst“ + nízká, vítr, rozhrnování)

Zdroje jsou v `ZDROJE.md`, v textu jen jejich čísla [n].

## 1. Hustý koberec / srst
- **Shell texturing** [1][2]: plocha se zkopíruje N× nad sebe (vrstvy). V každé vrstvě rozhodne hash na mřížce, jestli tam chlup ještě je; chlup se směrem nahoru zužuje do kužele. Geometrie je směšně malá (24 vrstev = 48 trojúhelníků na záhon), výsledek vypadá jako srst nebo koberec. Nevýhody: zblízka a z ostrého úhlu jsou vidět mezery mezi vrstvami a cena roste s fill-rate (N překreslení každého pixelu) [16]. Doporučuje se 16–32 vrstev [4].
- **Jeden draw call**: všechny vrstvy patří do jednoho meshe a index vrstvy je v UV2 [4], případně v MultiMeshi [3]. Alpha hash v Compatibility nefunguje [3], takže se musí použít `discard` (alpha scissor).
- **Moaré** na velkou vzdálenost: když je chlup menší než pár pixelů, pravidelná mřížka „pruhuje“. Řeší se to rozmazáním nebo rozšířením podle `fwidth` (LOD v shaderu). To je moje úprava, ve studii ověřená.

## 2. Jednotlivá stébla
- **Instancovaná stébla (MultiMesh)** [5][6]: každé stéblo je instance zúženého pásku s parametry (výška, šířka, náklon, ohyb, hash). V Ghost of Tsushima generuje compute shader zhruba 1 mil. kandidátů, z nichž se vykreslí asi 83 tisíc stébel za 2,5 ms [5]. Ohyb probíhá ve vertex shaderu (Bézierova křivka [5], u nás oblouk se zachovanou délkou).
- **Compute shadery** (GoT [5], GrassPro [14], Stride [11]) dělají culling a LOD na GPU. **Renderer Compatibility (OpenGL3) compute nemá** [14], takže nám zbývá MultiMesh s instancemi spočítanými na CPU a LOD po chuncích (vypnout nebo zředit chunky daleko od kamery). Vertex-shader-only přístup popisuje [15].

## 3. Vítr
- Stálý směr a poryvy jako 2D šum posouvaný po směru větru [7][8]. Výška na stéble maskuje posun, takže kořen stojí [8][9]. Každé stéblo má navíc vlastní fázi a přidá drobné chvění (hash na stéblo [5]).
- Ve studii: dvě oktávy value noise + `smoothstep` pro poryvy, chvění se sinem s fází stébla a jemný boční kmit.

## 4. Rozhrnutí postavičkou a návrat
- **Nejjednodušší řešení** je uniform s pozicí hráče a odtlačení v poloměru [8][9]. Nemá ale paměť, takže tráva se vrátí okamžitě.
- **Textura stopy** [10][11][13][15]: malá textura nad terénem, do které se otiskuje štětec. Každý snímek se celá utlumí, takže se tráva vrací. Směr ohybu je ve dvou kanálech [10][13]. Pro velký svět se používá rolovací clipmapa kolem kamery [12].
- **Moje varianta ve studii**: místo útlumu celé textury ukládám **čas otisku** (R), směr (GB) a sílu (A). Shader sám spočítá návrat z rozdílu `sim_time − R` (držení 0,35 s, pak 1,6 s pružný návrat s malým překmitem). CPU tak každý snímek přepíše jen pixely pod postavičkou a je deterministická. Rychlý náběh a pomalý návrat odpovídá [10].

## 5. Co funguje v Godot 4 Compatibility
| Technika | Compatibility | Poznámka |
|---|---|---|
| Shell vrstvy s `discard` | ano | 1 mesh, 1 draw call [4], LOD přes `fwidth` |
| MultiMesh stébla + vertex shader | ano | culling jen po celých MultiMeshích (chunky) |
| Compute grass (GoT, GrassPro) | **ne** | [14] |
| Textura stopy jako ImageTexture z CPU | ano | malá, aktualizuje se jen otisk |
| SubViewport ping-pong stopa na GPU | ano | složitější, zatím nepotřeba |
| Alpha hash / alpha to coverage | omezeně | [3] |

## 6. Závěr pro Willage
Izometrický pohled shora z větší dálky nahrává shellům: za pár trojúhelníků dávají „srst“ a stejný shader pokryje vysokou i nízkou trávu. Stébla vypadají zblízka nejlépe, ale na celý ostrov jsou bez compute shaderů drahá. Doporučení je v `README.md`. Doplněk (12:58): po Janově zpětné vazbě „vypadá jako mech“ vznikly varianty A2 (řidší koberec) a C (trsy z prototypu jako instance [18]); z dálky jako tráva čte jen C.
