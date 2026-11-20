# Zdroje – blueprint-studie

| # | odkaz | co jsem převzal |
|---|---|---|
| 1 | https://en.wikipedia.org/wiki/Laplace%27s_equation | harmonická funkce = nejhladší plocha mezi pevnými okraji (princip maxima: uvnitř nepřekročí okrajové hodnoty) → korekce hranic vrstev a okraje povrchu bez překmitů |
| 2 | https://en.wikipedia.org/wiki/Successive_over-relaxation | Gauss–Seidel s převrelaxací (ω ≈ 1,8), pevné pořadí průchodu → deterministické a rychlé na mřížce 16 × 16 |
| 3 | https://en.wikipedia.org/wiki/Dirichlet_boundary_condition | Dirichlet = pevná hodnota na okraji (strana se sousedem), Neumann = nulový spád (strana bez souseda) |
| 4 | https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html | FastNoiseLite: fBm a domain warp (`domain_warp_enabled`, amplituda, frekvence) pro vlnění regionálních vrstev |
| 5 | https://github.com/SebLague/Hydraulic-Erosion | eroze kapkami: setrvačnost, kapacita sedimentu podle spádu, rychlosti a vody, odpar → `erosion.gd` |
| 6 | https://inria.hal.science/inria-00402079 | Mei, Decaudin, Hu 2007: rychlá hydraulická eroze na mřížce (pipe model) – alternativa, kdyby kapky byly málo |
| 7 | https://en.wikipedia.org/wiki/Principle_of_lateral_continuity | Stenův princip boční souvislosti: vrstva pokračuje do stran, dokud se neztenčí nebo ji nepřeruší překážka → geologický důvod „protáhnout vrstvy sousedů“ |
| 8 | https://dwarffortresswiki.org/index.php/DF2014:Stone | DF: vrstevní horniny (layer stones) a minerály vázané na konkrétní hostitelské horniny → tabulka minerál → hostitelé |
| 9 | https://en.wikipedia.org/wiki/Ore_genesis | rudy vznikají v určitých prostředích a horninách (hydrotermální žíly, sedimentární ložiska) → hostitelé v `data/mineraly_hostitele.json` |
| 10 | `inspirace/gemini-kura-64.md` (Janův zdroj, vygenerovalo Gemini) | pořadí 64 hornin kůry 0–63 (plášť, krystalinikum, sedimenty, povrch, hory, vzduch). Je to **pořadí možných hornin**, na místě je jen jejich podmnožina → `data/poradi_hornin.json` |
| 11 | `inspirace/skica-tvary-vrstev.jpg` (Janova skica, 2026-11-18 16:34) | tři profily vrstev: mírné kopce a nížiny (vrstvy vlní s povrchem), sopka (vrstvy se strmě zvedají a sbíhají ke kráteru, uprostřed sopouch), hora (antiklinála, hlubší vrstvy se klenou méně) → profily `mirne`, `sopka`, `hora` v `geo2.gd` |
| 12 | `inspirace/moje-predstava-rez.png` (Janova představa řezu, 2026-11-18 16:38) | hora = jádro z hlubokých hornin prorazí hlínu a sedimenty, na úpatí jen zbytky, sníh nahoře; přes kopec se vrstvy ohnou; pod jezerem se prohnou |
| 13 | https://en.wikipedia.org/wiki/Anticline | antiklinála: vrstvy klenuté nahoru, nejstarší horniny v jádře → profil hory |
| 14 | https://en.wikipedia.org/wiki/Salt_dome a https://en.wikipedia.org/wiki/Kimberlite | solný dóm (diapir, hřibovitý tvar prorážející sedimenty) a kimberlitový komín (svislá mrkev z pláště, hostitel diamantů) → speciální tělesa |
| 15 | https://en.wikipedia.org/wiki/Pegmatite a https://en.wikipedia.org/wiki/Skarn | pegmatitové žíly (drahokamy, Li/Sn/Ta) a skarn na kontaktu granitoidu s karbonátem (Cu, Fe, granáty) → hostitelé v `mineraly_hostitele.json` |
| 16 | https://link.springer.com/article/10.1007/BF02775087 a PDF https://cg.minesparis.psl.eu/bibliotheque/public/LAJAUNIE_Publication_02422.pdf | Lajaunie, Courrioux, Manuel 1997: foliační pole a 3D kartografie interpolací potenciálu (ko-kriging bodů na rozhraní a sklonů) → izoplochy jedné série se nekříží |
| 17 | https://doi.org/10.1016/j.pepi.2008.06.013 (Calcagno, Chilès, Courrioux, Guillen 2008, *PEPI*) | GeoModeller: potenciálové pole + geologická pravidla, stratigrafický sloup, relace mezi sériemi |
| 18 | https://gmd.copernicus.org/articles/12/1/2019/gmd-12-1-2019.html a PDF https://gmd.copernicus.org/articles/12/1/2019/gmd-12-1-2019.pdf | de la Varga, Schaaf, Wellmann 2019: GemPy, otevřený ko-kriging, série, nesouhlasnosti a zlomy jako samostatná pole |
| 19 | https://www.gempy.org/theory a https://github.com/gempy-project/gempy | dokumentace a kód GemPy (Lajaunie 1997, Calcagno 2008) |
| 20 | https://support.intrepid-geophysics.com/support/solutions/articles/43000054680-what-is-the-distinction-between-the-erode-and-onlap-relation-in-the-stratigraphic-map- | GeoModeller: *erode* = mladší plocha řeže starší, *onlap* = zastaví se o ni; sloup platí shora dolů |
| 21 | https://loop3d.org/LoopStructural/getting_started/about.html | LoopStructural: implicitní plochy (DSI na tetraedrech, konečné diference, RBF), fold frame pro vrásy |
| 22 | https://link.springer.com/article/10.1007/s11004-014-9540-3 a https://www.ring-team.org/research-publications/ring-meeting-papers?id=2411&view=pub | Hillier et al. 2014: geologické plochy zobecněnou interpolací RBF (SURFE); body, gradienty, nerovnosti nad/pod |
| 23 | https://loop3d.org/LoopStructural/_auto_examples/1_basic/plot_2_surface_modelling.html | LoopStructural: jedno skalární pole pro více souhlasných horizontů, mocnost posune izohodnotu |
| 24 | https://doi.org/10.1016/j.epsl.2016.09.040 (Laurent, Ailleres, Grose, Caumon, Jessell, Armit 2016, *EPSL*) | implicitní model vrás a přetištěných deformací; obyčejná implicitní interpolace vrásu vyhladí, proto fold frame |
| 25 | https://badlands.readthedocs.io/en/latest/proc.html a https://github.com/badlands-model/badlands | Badlands: vývoj krajiny na geologickém čase (stream power, sedimentace, zdvih, hladina moře) |
| 26 | https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0195557 | Salles et al. 2018: pyBadlands, transport sedimentu a stratigrafie pánví |
| 27 | https://esurf.copernicus.org/articles/5/21/2017/ | Hobley et al. 2017: Landlab, modulární 2D modely zemského povrchu |
| 28 | https://landlab.csdms.io/ | dokumentace Landlab včetně StreamPowerEroder (E = K A^m S^n) |
| 29 | https://csdms.colorado.edu/wiki/Model:GOLEM | GOLEM (Tucker a Slingerland 1994): model vývoje krajiny (výška, půda, tok, tektonika); v zadání „Goblin“ |
| 30 | https://fastscape.org/ | FastScape: rychlé komponenty vývoje krajiny (směrování toku, řez, zdvih) |
| 31 | https://www.cs.purdue.edu/homes/bbenes/papers/Cordonier16CGF.pdf (Cordonnier et al. 2016; DOI 10.1111/cgf.12820 je za paywallovou bránou) | velký terén z mapy tektonického zdvihu a fluviální eroze, stream-power rovnice na říčním grafu |
| 32 | https://www.cs.purdue.edu/cgvlab/www/resources/papers/Cordonnier-IEEE_Transactions_on_Visualization_and_Computer_Graphics-2018-Sculpting_Mountains_Interactive_Terrain_Modeling_Based_on_Subsur.pdf (DOI 10.1109/tvcg.2017.2689022) | *Sculpting Mountains*: vrstevnatá kůra, vrásnění, objemový zdvih, eroze podle kompetence horniny |
| 33 | https://www.cs.purdue.edu/cgvlab/www/resources/papers/Galin-Computer_Graphics_Forum-2019-A_Review_of_Digital_Terrain_Modeling.pdf (Galin, Guérin, Peytavie, et al. 2019; DOI 10.1111/cgf.13657 je za bránou) | přehled modelů terénu: výšková pole, vrstvené funkce mocností, objemové a implicitní reprezentace |
| 34 | https://perso.liris.cnrs.fr/egalin/Articles/2009-arches.pdf (Peytavie, Galin, Grosjean, Merillou 2009) | *Arches*: zásobník materiálů ve sloupci + implicitní povrch konvolucí; vzduch mezi skálami = jeskyně, oblouk, převis |
| 35 | https://minecraft.wiki/w/Noise_router | Minecraft 1.18: strom hustotních funkcí (final_density, zvodně, žíly toggle/ridged/gap) |
| 36 | https://minecraft.wiki/w/World_generation | Minecraft: zvodně s místní hladinou a bariérou, šumové jeskyně, žíly v hostitelském plnivu |
| 37 | https://dwarffortresswiki.org/Stone_layers | Dwarf Fortress: pořadí vrstev (půda, sedimenty / výlevné, metamorfity, hlubinné vyvřeliny), rudy podle hostitele a biomu |
| 38 | https://wiki.vintagestory.at/Terrain_Generation/en | Vintage Story: geologická provincie, skupiny sediment / metamorfity / vyvřeliny, pak rudy do hostitelů |
| 39 | https://wiki.vintagestory.at/Rock/en | Vintage Story: mocnosti podle provincie, čedič může ležet nahoře, halit dómy, mramor žíly |
| 40 | https://terraria.wiki.gg/wiki/World_generation | Terraria: průchody (hlína/kámen, díry, „shinies“); není stratigrafie, jen hloubkové pásy a přemalování |
| 41 | https://www.nomanssky.com/2015/02/no-mans-sky-at-gdc/ | Hello Games, GDC 2015: procedurální planety, oznámení přednášky *Building a Galaxy* |
| 42 | https://www.youtube.com/watch?v=sCRzxEEcO2Y | Ingram / Hello Games: *Continuous World Generation in No Man's Sky* — voxely, hustota, marching cubes (bez stratigrafie) |
| 43 | https://santosgrueiro.com/papers/2014/2014-Santam-Proc.pdf (Santamaría-Ibirika et al. 2014, *The Visual Computer*) | procedurální objemový terén jako zásobníky vrstev, žíly a jeskyně z parametrů |
| 44 | https://people.cs.uct.ac.za/~Jgain/wp-content/papercite-data/pdf/paris2019.pdf (Paris, Galin, Peytavie, Guérin, Gain 2019; DOI 10.1145/3342765 je za bránou ACM) | *Terrain Amplification with Implicit 3D Features*: strom implicitních primitiv, vrstvy, zlomy, vrásy, odolnost, římsy |
| 16 | `inspirace/skica-klin.jpg` (Janova skica klínu, 2026-11-18 16:49) | levý blok 1,2,4,5,6,7, pravý 1,3,5,6,7: vrstvy 2 a 4 pokračují přes šev a v pravém bloku se vyklíní, 3 naroste od švu, 1, 5, 6, 7 navazují → navázání v mocnostech (`strata.gd continue_thick`) |
| 17 | https://en.wikipedia.org/wiki/Pinch_out (a https://en.wikipedia.org/wiki/Stratigraphic_trap) | vyklínění vrstvy (pinch-out): mocnost klesá k nule, vrstva končí klínem → mocnost jako funkce s nulou na okraji |
| 18 | https://en.wikipedia.org/wiki/Bilinear_interpolation | buňky jako vzorky: funkce mezi řídicími body (rozteč 0,5 m) bilineárně, i přes šev bloků → stejný tvar při jemnějším rozlišení |
| 19 | https://en.wikipedia.org/wiki/Aquifer a https://en.wikipedia.org/wiki/Karst | rezervoár = voda uzavřená nepropustnou horninou (dno a stěny); jeskyně přednostně v karbonátech (kras) pod pevným stropem |
| 20 | https://arxiv.org/abs/1511.04463 (Barnes, Lehman, Mulla 2014, *Priority-Flood*) | vyplnění bezodtokých míst haldou od okraje (E49 `svet8/reky.gd`): jezera = vyplněno, směr toku po vyplněném povrchu |
| 21 | https://en.wikipedia.org/wiki/Biome#Whittaker_(1962,_1970,_1975)_biome-types | Whittakerovo rozdělení biomů podle teploty a srážek (E49 `svet8/biomy.gd`, zjednodušeno + řeky a jezera) |
| 22 | https://en.wikipedia.org/wiki/Orographic_lift | návětrné srážky a srážkový stín za horami (E49 `svet8/pocasi.gd`: vlhkost ubývá s výstupem terénu) |
| 23 | https://en.wikipedia.org/wiki/Stream_power_law | zahloubení koryta E = K · A^m · S^n (E47b `voda/strze.gd`: A = průtok, K kalibrované na medián 2 m, k_mat podle horniny) |
| 24 | https://en.wikipedia.org/wiki/Plunge_pool | tůň pod vodopádem vymletá dopadající vodou (E47b: prohloubení min(0,5 · spád, 1 m) pod vodopádem) |
| 25 | https://en.wikipedia.org/wiki/Ponor a https://en.wikipedia.org/wiki/Losing_stream | ponor = otvor, kudy povrchová voda odchází do podzemí (kras); ztrácející se tok v propustném dně (E47b/c ponory, odtok tůně) |
| 26 | https://en.wikipedia.org/wiki/Spring_(hydrology) a https://en.wikipedia.org/wiki/Spring_horizon | pramen = výstup podzemní vody; kontaktní prameny na styku propustné nad nepropustnou (E47c `voda/prameny.gd` druh „kontakt“) |
| 27 | https://en.wikipedia.org/wiki/Aquifer (oddíl *Confined versus unconfined*), https://en.wikipedia.org/wiki/Porosity, https://en.wikipedia.org/wiki/Subterranean_river | podzemní voda v propustné vrstvě sevřené nepropustnou; objem pórů = pórovitost × objem; podzemní tok a jezera (E47d `voda/podzemi.gd`) |
| 28 | https://zenithsal.cloudmillgames.com/posts/godot-code-bench/, https://github.com/dicarne/godot-benchmark-gdscript-csharp | GDScript vs C# v Godotu: čisté smyčky C# 30–58 ×, Godot Dictionary podobně (E50 odhad pro telefon) |
| 29 | https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html, https://www.cpu-monkey.com/en/cpu-qualcomm_snapdragon_7_gen_3 | C# export na Android experimentální (od 4.2, .NET 9); Snapdragon 7 Gen 3 GB6 1 jádro ≈ 1 130 (E50) |
| 30 | https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html | WorkerThreadPool pro paralelní vzorkování bloků (E50 návrh) |
| 31 | https://en.wikipedia.org/wiki/Manning_formula | Manningova rovnice v = (1/n) R^(2/3) S^(1/2); E51 `eroze51/hydro.gd` pro široké koryto (R ≈ h), n 0,035 |
| 32 | https://en.wikipedia.org/wiki/Hjulstr%C3%B6m_curve | Hjulströmův diagram: rychlost proudu rozhoduje mezi erozí, transportem a usazováním; jíl je soudržný (vysoký práh eroze), písek se odnese nejsnáz (E51 `ero_v`, `sed_v`) |
| 33 | https://en.wikipedia.org/wiki/Darcy%27s_law, https://en.wikipedia.org/wiki/Finite_volume_method, https://en.wikipedia.org/wiki/Conjugate_gradient_method | Darcyho zákon Q = K·S/L·ΔP; konečné objemy (ΣQ = 0 v buňce, harmonický průměr K na stěně); sdružené gradienty pro řídkou SPD soustavu (E52 varianta 5, 2D relaxace i 3D CG) |
| 34 | https://hal.inria.fr/inria-00402079/document (Mei, Decaudin, Hu 2007: Fast Hydraulic Erosion Simulation and Visualization on GPU), https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf (Stam 2003) | „virtuální trubky“: výška vody + toky po hranách, explicitní krok přes celé pole, na GPU; Stamovy stabilní tekutiny (E53 mělká voda `plosne53/mvoda.gd`) |
| 35 | https://web.mit.edu/cesium/Public/terrain.pdf (Musgrave, Kolb, Mace 1989: The Synthesis and Rendering of Eroded Fractal Terrains), https://old.cescg.org/CESCG-2011/papers/TUBudapest-Jako-Balazs.pdf (Jákó 2011: thermal erosion, talus angle) | Tepelná eroze: kde rozdíl sousedů přesáhne mezní úhel (talus), část přebytku se přesune dolů, hmota se zachová; E56 `svah56/svah.gd` omezovač sklonu |
| 36 | https://doi.org/10.1145/363269.363610 (Dial 1969: Algorithm 360, kbelíková fronta pro nejkratší cesty), https://doi.org/10.1016/j.cageo.2013.04.024 (Barnes, Lehman, Mulla 2014: Priority-Flood) | Kbelíková fronta: klíče po kbelících, vložení O(1); priority-flood s frontou pro rovné úseky; E58 A `alg58/bq58.gd`, `tok.gd` `FLOOD_DZ` |
| 37 | https://doi.org/10.5194/esurf-8-431-2020 (Barnes, Callaghan, Wickert 2020: hierarchie prohlubní / Fill-Spill-Merge) | Pánve a přelivy jako graf (hierarchie prohlubní); E58 B povrch `alg58/povrch58.gd` (zjednodušeně, bez ε spádu) a graf těles podzemí `alg58/ug58.gd` |
| 38 | https://fc79.gw-project.org/english/chapter-2/ (Freeze & Cherry 1979: Groundwater, kap. 2, tab. 2.2 a 2.4) | Rozsahy hydraulické vodivosti K (m/s) a pórovitosti pro zeminy a horniny; E59 `tools/materialy59.py` |
| 39 | https://doi.org/10.3133/wsp1662D (Johnson 1967: Specific yield, USGS WSP 1662-D, tab. 29) | Specifická vydatnost Sy (jíl 0,02, prach 0,08, jemný písek 0,21, střední 0,26, štěrk 0,22–0,25); zadržení = n − Sy; E59 |
| 40 | https://doi.org/10.13031/2013.33720 (Rawls, Brakensiek, Saxton 1982: Estimation of soil water properties) | Nasycená vodivost půd (písek ~5,8e-5, hlína ~3,7e-6, jílovitá půda ~1,7e-7 m/s); E59 drn a hlína |
| 41 | https://en.wikipedia.org/wiki/Stokes%27_law | Usazovací rychlost malých částic (Stokes): jíl a prach se usazují jen ve skoro stojaté vodě; E59 sed_v |
| 42 | `gemini/podzemi-konzultace/odpoved.md` (Gemini, chat 2026-11-19, režim „Automaticky“) | Rešerše řešení podzemí E64: pevné pořadí místo ε, oprava přes všechny hrany do S, kroky po rozpočtu (ne podle času), test více hráčů, svislá komprese (na našich datech jen 1,45 % pásem) |
| 43 | https://doi.org/10.1016/0020-0190(77)90002-3 (Knuth 1977: A generalization of Dijkstra's algorithm, IPL 6(1)) | Dijkstra pro monotónní „superior“ funkce hran; E64 K důkaz (f(x) ≤ x, neklesající) |
| 44 | https://doi.org/10.1006/jagm.1996.0046 (Ramalingam, Reps 1996: An incremental algorithm for a generalization of the shortest-path problem, J. Algorithms 21) | Inkrementální přepočet po změně hran (zneplatnit podstrom, osadit z hranice); E64 I a prořezání |

| 45 | — | Přesunuto do tezba-studie/ZDROJE.md jako [1] (T01, dříve E65). |
| 46 | — | Přesunuto do tezba-studie/ZDROJE.md jako [2] (T01, dříve E65). |
| 47 | — | Přesunuto do tezba-studie/ZDROJE.md jako [3] (T01, dříve E65). |
| 48 | — | Přesunuto do tezba-studie/ZDROJE.md jako [4] (T01, dříve E65). |
| 49 | — | Přesunuto do tezba-studie/ZDROJE.md jako [5] (T01, dříve E65). |
| 50 | — | Přesunuto do tezba-studie/ZDROJE.md jako [6] (T01, dříve E65). |
| 51 | — | Přesunuto do tezba-studie/ZDROJE.md jako [7] (T01, dříve E65). |
| 52 | — | Přesunuto do tezba-studie/ZDROJE.md jako [8] (T01, dříve E65). |
| 53 | — | Přesunuto do tezba-studie/ZDROJE.md jako [9] (T01, dříve E65). |
| 54 | — | Přesunuto do tezba-studie/ZDROJE.md jako [10] (T01, dříve E65). |
| 55 | — | Přesunuto do tezba-studie/ZDROJE.md jako [11] (T01, dříve E65). |
| 56 | — | Přesunuto do tezba-studie/ZDROJE.md jako [12] (T01, dříve E65). |
| 57 | — | Přesunuto do tezba-studie/ZDROJE.md jako [13] (T01, dříve E65). |
| 58 | — | Přesunuto do tezba-studie/ZDROJE.md jako [14] (T01, dříve E65). |
| 59 | — | Přesunuto do tezba-studie/ZDROJE.md jako [15] (T01, dříve E65). |
| 60 | — | Přesunuto do tezba-studie/ZDROJE.md jako [16] (T01, dříve E65). |
| 61 | — | Přesunuto do tezba-studie/ZDROJE.md jako [17] (T01, dříve E65). |
| 62 | — | Přesunuto do tezba-studie/ZDROJE.md jako [18] (T01, dříve E65). |
| 63 | — | Přesunuto do tezba-studie/ZDROJE.md jako [19] (T01, dříve E65). |
| 64 | — | Přesunuto do tezba-studie/ZDROJE.md jako [20] (T01, dříve E65). |
| 65 | — | Přesunuto do tezba-studie/ZDROJE.md jako [21] (T01, dříve E65). |
| 66 | — | Přesunuto do tezba-studie/ZDROJE.md jako [22] (T01, dříve E65). |
| 67 | — | Přesunuto do tezba-studie/ZDROJE.md jako [23] (T01, dříve E65). |
| 68 | — | Přesunuto do tezba-studie/ZDROJE.md jako [24] (T01, dříve E65). |
| 69 | — | Přesunuto do tezba-studie/ZDROJE.md jako [25] (T01, dříve E65). |
| 70 | — | Přesunuto do tezba-studie/ZDROJE.md jako [26] (T01, dříve E65). |
| 71 | — | Přesunuto do tezba-studie/ZDROJE.md jako [27] (T01, dříve E65). |
| 72 | — | Přesunuto do tezba-studie/ZDROJE.md jako [28] (T01, dříve E65). |
| 81 | https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html | Godot 4.7: Thread-safe APIs – scéna není vláknově bezpečná, u polí a slovníků GDScriptu změna velikosti z více vláken potřebuje mutex (E95). |
| 82 | https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html | Godot: Using multiple threads – Thread, Mutex, Semaphore, wait_to_finish (E95). |
| 83 | https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html | Godot: WorkerThreadPool – pool pro krátké úlohy; E95 volí vlastní Thread (dlouhé úlohy za sebou). |
