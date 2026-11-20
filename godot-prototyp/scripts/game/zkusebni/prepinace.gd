extends RefCounted
## E95 (zkušební větev zkusebni-vse): seznam přepínačů Bloků 2–4 pro panel na obrazovce. Každý záznam:
##   k        klíč příznaku / parametru
##   g        skupina v panelu
##   t        "b" zaškrtávátko, "f" posuvník (desetinné), "i" počítadlo (celé), "o" výběr z možností
##   cil      kam se zapíše a co se po změně stane:
##            "teren"  → ostrov_teren.over + přegenerování ostrova (znovu načtení scény, kopání a stavby se ztratí)
##            "zive"   → ostrov_teren.over i T.p hned, bez přegenerování (pravidlo se použije při dalším kopání / přenosu)
##            "meritko", "lod", "pruhl", "rez" → za běhu (uzel ostrova, LOD krajina, shadery)
##   rodic    číselný parametr se zobrazí pod svým přepínačem (a projeví se, jen když je přepínač zapnutý)
##   tip      bublina (česky): co dělá, z jakého pokusu, cena, vedlejší účinky
## p89_meritko a p94_meritko_veg jsou v SurfaceParams (načtou se při startu scény → znovu načtení scény).
## Výchozí hodnoty bere panel z ostrov_teren.params() (tedy totéž co výchozí hra), u E89–E91 a řezu z jejich modulů.

const SKUPINY := ["Voda", "Geologie", "Výřez", "Měřítko a zobrazení"]

const SEZNAM := [
	# ------------------------------------------------------------------ voda
	{"k": "p79_chodby", "g": "Voda", "t": "b", "cil": "teren", "n": "E79 chodby ve vodě",
		"tip": "E79: po vykopání chodby nebo šachty se podzemí postaví znovu a lokální přepočet vody vidí i dutiny se vstupem z povrchu (dnes je nevidí).\nCena: přestavba ostrova ~{teren} s; každé kopání dutiny pak +1–2 s (lokální přepočet je jen o 10–35 % rychlejší než plný).\nVedlejší účinky: projeví se až při kopání; start ostrova se nemění. Spolu s E85 voda dává lokálně = plně."},
	{"k": "p85_voda", "g": "Voda", "t": "b", "cil": "teren", "n": "E85 obsazené výtoky v bloku",
		"tip": "E85: obsazení výtoků podzemní vody (E74) se ukládá do bloku, takže plný výpočet, lokální přepočet i načtení dají stejnou vodu.\nCena: přestavba ~{teren} s.\nVedlejší účinky: mění vodu po kopání; doporučeno zapnout spolu s E79 (bez něj lokální voda s E74 nesedí)."},
	# ------------------------------------------------------------------ geologie
	{"k": "p81_tenke", "g": "Geologie", "t": "b", "cil": "teren", "n": "E81 tenké vrstvy",
		"tip": "E81: vrstva tenčí než buňka nezmizí – dostane aspoň jednu buňku (konzervativní vzorkování). Chybějících tenkých vrstev 60 % → 7,6 %.\nCena: přestavba ~{teren} s.\nVedlejší účinky: mění 2,3 % buněk a otisk vody (víc podzemních těles), tenká vrstva je nafouknutá na 0,5 m."},
	{"k": "p81_min_m", "g": "Geologie", "t": "f", "min": 0.01, "max": 0.25, "krok": 0.01, "rodic": "p81_tenke", "cil": "teren", "n": "práh tenké vrstvy (m)",
		"tip": "E81: vrstva tenčí než tento práh se nekreslí vůbec, silnější dostane aspoň jednu buňku. Výchozí 0,05 m.\nCena: přestavba ~{teren} s (jen se zapnutým E81)."},
	{"k": "p82_vapenec", "g": "Geologie", "t": "b", "cil": "teren", "n": "E82 vápenec k hladině",
		"tip": "E82 (Jan 01:55): zhruba v polovině bloků (mince ze seedu bloku) se vršek jeskynního vápence zvedne na povrch − 2 m a nepropustné vrstvy nad ním se vyklíní.\nCena: přestavba ~{teren} s, generování +5 %.\nVedlejší účinky: mění geologii i vodu (prameny, kras), záleží na pořadí vložení bloků."},
	{"k": "p82_podil", "g": "Geologie", "t": "f", "min": 0.0, "max": 1.0, "krok": 0.05, "rodic": "p82_vapenec", "cil": "teren", "n": "podíl bloků s vápencem",
		"tip": "E82: jaký podíl bloků dostane vápenec k hladině (0,5 = polovina, podle seedu bloku).\nCena: přestavba ~{teren} s."},
	{"k": "p82_pod_m", "g": "Geologie", "t": "f", "min": 0.5, "max": 6.0, "krok": 0.5, "rodic": "p82_vapenec", "cil": "teren", "n": "vápenec pod povrchem (m)",
		"tip": "E82: jak hluboko pod vyhlazeným povrchem leží vršek vápence (výchozí 2 m – nad ním zůstane propustný kryt pro vsak).\nCena: přestavba ~{teren} s."},
	{"k": "p82_tesneni", "g": "Geologie", "t": "b", "rodic": "p82_vapenec", "cil": "teren", "n": "vyklínit těsnění nad vápencem",
		"tip": "E82: nepropustné vrstvy (jílovec, jíl) nad vápencem se v bloku „ano“ vyklíní, aby voda z krytu došla do vápence.\nCena: přestavba ~{teren} s. Mění prameny."},
	{"k": "p85_vrstvy", "g": "Geologie", "t": "b", "cil": "teren", "n": "E85 vrstvy ≥ 25 cm",
		"tip": "E85 (Jan 03:26): v blueprintu zmizí vrstvy tenčí než 25 cm (místo dostane vrstva nad ní).\nCena: přestavba ~{teren} s.\nVedlejší účinky: jinak 0,65 % buněk, mění vodu."},
	{"k": "p85_min_m", "g": "Geologie", "t": "f", "min": 0.05, "max": 1.0, "krok": 0.05, "rodic": "p85_vrstvy", "cil": "teren", "n": "nejmenší mocnost (m)",
		"tip": "E85: vrstva tenčí než tato mocnost zmizí (výchozí 0,25 m).\nCena: přestavba ~{teren} s."},
	{"k": "p85_jemne", "g": "Geologie", "t": "b", "cil": "teren", "n": "E85 mřížka 0,25 m z funkcí",
		"tip": "E85 (Jan 03:26): jemná mřížka 0,25 m pro kopání se počítá přímo z funkcí geologie, ne zjemněním buněk 0,5 m.\nCena: přestavba ~{teren} s; 65–108× pomalejší definice bloku (0,4–0,8 s na blok místo 6–8 ms).\nVedlejší účinky: jinak 7,8 % jemných buněk; výřez E76 zůstává zjemněním."},
	{"k": "p85_okraj", "g": "Geologie", "t": "b", "cil": "zive", "n": "E85 nekopat dno a okraj",
		"tip": "E85 (Jan 03:26): dno ostrova (vrstva 0) a obvodové sloupce ostrova nejdou prokopat, vnitřní švy bloků ano.\nCena: žádná, platí hned bez přegenerování (při dalším kopání, klávesa M)."},
	{"k": "p85_blok2", "g": "Geologie", "t": "b", "cil": "teren", "n": "E85 vše z Bloku 2 najednou",
		"tip": "E85: zapne naráz E85 jemné, okraj, vrstvy i voda (jednotlivé přepínače pak nic nemění).\nCena: přestavba ~{teren} s (nejpomalejší kvůli jemné mřížce).\nVedlejší účinky: mění vodu i buňky; u chodeb je lokální přepočet pomalejší než plný."},
	{"k": "p87_jadro_hory", "g": "Geologie", "t": "b", "cil": "teren", "n": "E87 jádro hory přes bloky",
		"tip": "E87: vyzdvižená hora je jedna funkce masivu ve světových metrech – šev mezi horami nespadne do sedla a jádro se u okraje bloku neutne.\nCena: přestavba ~{teren} s.\nVedlejší účinky: týká se jen bloků „hora vyzdvižená“ (v panelu se proto startovní hora vygeneruje jako vyzdvižená); masiv vedle louky dá stěnu 5–6 m, jiná voda."},
	{"k": "p87_amp", "g": "Geologie", "t": "f", "min": 4.0, "max": 30.0, "krok": 1.0, "rodic": "p87_jadro_hory", "cil": "teren", "n": "výška masivu (buňky)",
		"tip": "E87: amplituda masivu nad základem v buňkách 0,5 m (výchozí 18).\nCena: přestavba ~{teren} s."},
	# ------------------------------------------------------------------ výřez
	{"k": "p86_otoceni", "g": "Výřez", "t": "b", "cil": "zive", "n": "E86 otočení výřezu po 90°",
		"tip": "E86: podzemí otočeného výřezu bere šum hornin v souřadnicích původu (inverzní rotace), takže pásma podzemí sedí 256/256.\nCena: žádná, bez přegenerování.\nVedlejší účinky: projeví se jen při přenosu výřezu s otočením (E76/E86); startovní ostrov se nemění. Ve hře zatím není akce přenosu výřezu."},
	# ------------------------------------------------------------------ měřítko a zobrazení
	{"k": "p89_meritko", "g": "Měřítko a zobrazení", "t": "b", "cil": "teren", "n": "Metry (E94)",
		"tip": "E89 + E94 (Jan 11:04): scéna v metrech – 1 jednotka = 1 m, buňka 0,5 × 0,5 × 0,5 m (dnes 1 × 1 × 0,5, tedy vodorovně natažená 2×). Stromy, stavby, kamera, tráva a mlha jsou v metrech.\nCena: znovu načtení scény ~{teren} s (data ostrova a voda se nemění, otisky vody stejné).\nVedlejší účinky: ostrov vypadá menší a hora strmější; stromy 3,5–4 m zakryjí louku. Na větvi e94-metry je výchozí zap, tady vyp."},
	{"k": "p94_meritko_veg", "g": "Měřítko a zobrazení", "t": "f", "min": 0.25, "max": 1.5, "krok": 0.05, "rodic": "p89_meritko", "cil": "teren", "n": "E94b měřítko vegetace",
		"tip": "E94b (Jan 11:39): měřítko velikosti vegetace ve scéně v metrech (× skutečné výšky; 0,5 → listnáč 1,75 m, jehličnan 2 m, keř 0,5 m). Hustota se nemění. Jan ji bude ladit.\nCena: znovu načtení scény ~{teren} s (data ostrova a voda beze změny).\nVedlejší účinky: jen vzhled; platí jen se zapnutými Metry (E94)."},
	{"k": "p94_hora_k", "g": "Měřítko a zobrazení", "t": "f", "min": 1.0, "max": 2.5, "krok": 0.1, "cil": "teren", "n": "E94 výška hory ×",
		"tip": "E94: převýšení hory nad její patou (1 = beze změny). Startovní hora je v bloku 8 m jen ~9 m nad loukou; 1,5 dá vrchol ~10,5 m (strop sloupce 61 buněk = 30,5 m).\nCena: přegenerování ostrova ~{teren} s.\nVedlejší účinky: mění terén hory i vodu; s vyšší horou má lokální přepočet vody neshody (stará chyba vody, i na main)."},
	{"k": "p92_svah", "g": "Měřítko a zobrazení", "t": "b", "cil": "teren", "n": "E92 omezovač sklonu",
		"tip": "E92: omezí sklon povrchu šablony bloku na strop (výchozí 1,0 = 45°).\nCena: přestavba ~{teren} s.\nVedlejší účinky: mění vodu (podzemní těleso a vývěr mohou zmizet, vodopády 8 → 1–5), hora se sníží 9,5 → 6 m."},
	{"k": "p92_max_sklon", "g": "Měřítko a zobrazení", "t": "f", "min": 0.3, "max": 1.5, "krok": 0.05, "rodic": "p92_svah", "cil": "teren", "n": "strop sklonu (m/m)",
		"tip": "E92: největší sklon v m/m (1,0 = 45°, 0,6 = 31°).\nCena: přestavba ~{teren} s."},
	{"k": "p92_hladit", "g": "Měřítko a zobrazení", "t": "i", "min": 0, "max": 6, "rodic": "p92_svah", "cil": "teren", "n": "průchody vyhlazení",
		"tip": "E92: kolik průchodů vyhlazení 3 × 3 proběhne před omezovačem (0 = žádné).\nCena: přestavba ~{teren} s."},
	{"k": "p90_lod", "g": "Měřítko a zobrazení", "t": "b", "cil": "lod", "n": "E90 LOD krajina okolo",
		"tip": "E90: pod ostrovem se postaví krajina z funkce světa E49 po kouscích 16 m: u středu 0,25 m, dál 0,5 m, pak 1 m a v dálce hrubá data. Barvy ukazují úrovně (červená 0,25 / žlutá 0,5 / modrá 1 m / šedá daleko).\nCena: stavba ~{lod} s, ostrov se nepřegeneruje.\nVedlejší účinky: je to jiná funkce než geologie ostrova (jen náhled pásem LOD); svět 512 × 512 m místo testu 3 × 3 km."},
	{"k": "p90_okoli", "g": "Měřítko a zobrazení", "t": "i", "min": 0, "max": 1, "rodic": "p90_lod", "cil": "lod", "n": "okolí dlaždic s detailem",
		"tip": "E90: kolik dlaždic 128 m kolem středu má detail (0 = jen dlaždice středu, 1 = 3 × 3 dlaždice).\nCena: přestavba LOD (1 → několik s)."},
	{"k": "p90_slupka", "g": "Měřítko a zobrazení", "t": "i", "min": 1, "max": 6, "rodic": "p90_lod", "cil": "lod", "n": "slupka (buněk pod povrchem)",
		"tip": "E90: kolik buněk pod povrchem se vzorkuje do paměti (viditelná slupka). Vzhled se nemění, mění se jen paměť.\nCena: přestavba LOD."},
	{"k": "p90_daleko_m", "g": "Měřítko a zobrazení", "t": "f", "min": 2.0, "max": 16.0, "krok": 1.0, "rodic": "p90_lod", "cil": "lod", "n": "dálka – velikost sloupce (m)",
		"tip": "E90: rozlišení hrubých dat mimo detail (výchozí 8 m; menší = hladší dálka, víc trojúhelníků).\nCena: přestavba LOD."},
	{"k": "p90_barvy", "g": "Měřítko a zobrazení", "t": "b", "rodic": "p90_lod", "cil": "lod", "n": "barvit úrovně LOD",
		"tip": "E90: obarví kousky podle úrovně (červená 0,25 m, žlutá 0,5 m, modrá 1 m, šedá dálka). Vypnuto = barvy materiálu."},
	{"k": "p91_pruhlednost", "g": "Měřítko a zobrazení", "t": "b", "cil": "pruhl", "n": "E91 průhlednost překážek",
		"tip": "E91: co je mezi kamerou a bodem uprostřed obrazovky (místo postavy), se zahodí – válec s ditherem (A) a/nebo řez nad výškou bodu (B). Odhalený vnitřek je tmavé víko.\nCena: za běhu, ~{pruhl} s na první překlad shaderů, pak ~0,5 ms; snímek +3 až +14 %.\nVedlejší účinky: shadery na disku se nemění (kopie za běhu)."},
	{"k": "p91_mode", "g": "Měřítko a zobrazení", "t": "o", "moznosti": ["A válec", "B řez nad bodem", "A + B"], "hodnoty": [1, 2, 3], "rodic": "p91_pruhlednost", "cil": "pruhl", "n": "režim",
		"tip": "E91: A = válec kolem paprsku bod → kamera (dither), B = zahodí vše nad bodem + strop v kruhu, A + B obojí."},
	{"k": "p91_r", "g": "Měřítko a zobrazení", "t": "f", "min": 1.0, "max": 10.0, "krok": 0.25, "rodic": "p91_pruhlednost", "cil": "pruhl", "n": "poloměr válce",
		"tip": "E91: poloměr válce A v jednotkách scény (výchozí 3). Za běhu, bez přestavby."},
	{"k": "p91_cut_r", "g": "Měřítko a zobrazení", "t": "f", "min": 2.0, "max": 60.0, "krok": 1.0, "rodic": "p91_pruhlednost", "cil": "pruhl", "n": "poloměr řezu B",
		"tip": "E91: poloměr kruhu řezu B kolem bodu (výchozí 10; velké číslo = všude). Za běhu."},
	{"k": "p91_ceil", "g": "Měřítko a zobrazení", "t": "f", "min": 0.25, "max": 6.0, "krok": 0.25, "rodic": "p91_pruhlednost", "cil": "pruhl", "n": "výška řezu B nad bodem",
		"tip": "E91: řez B zahodí vše výš než bod + tato výška (výchozí 1,25). Za běhu."},
	{"k": "zk_rez", "g": "Měřítko a zobrazení", "t": "o", "moznosti": ["vypnuto", "osa X", "osa Z"], "hodnoty": [0, 1, 2], "cil": "rez", "n": "Svislý řez",
		"tip": "Svislý řez (Jan 11:25, E95): svislá rovina přes celý ostrov; vše na straně ke kameře se zahodí (terén, voda, stromy, stavby) a v řezu jsou vidět vrstvy, podzemní voda a jeskyně.\nŘez je obarvený materiálem buňky (data bloků 0,5 m), díry bez dat tmavé.\nCena: za běhu, posun bez přegenerování (~{rez} s jen při prvním zapnutí – překlad shaderů).\nVedlejší účinky: kombinuje se s E91; po změně kopáním se data řezu obnoví do 1 s."},
	{"k": "zk_rez_pos", "g": "Měřítko a zobrazení", "t": "f", "min": 0.0, "max": 1.0, "krok": 0.002, "rodic": "zk_rez", "cil": "rez", "n": "poloha řezu",
		"tip": "Svislý řez: poloha roviny přes celý ostrov (0 = jeden okraj, 1 = druhý). Plynule, bez přegenerování."},
]

## výchozí hodnoty mimo ostrov_teren.params()
const VYCHOZI_JINE := {"p89_meritko": false, "p94_meritko_veg": 0.5, "p90_lod": false, "p90_okoli": 1, "p90_slupka": 3, "p90_daleko_m": 8.0, "p90_barvy": true,
	"p91_pruhlednost": false, "p91_mode": 1, "p91_r": 3.0, "p91_cut_r": 10.0, "p91_ceil": 1.25, "zk_rez": 0, "zk_rez_pos": 0.5}

static func zaznam(k: String) -> Dictionary:
	for e in SEZNAM:
		if e.k == k: return e
	return {}
