extends RefCounted
## Výchozí parametry studie (vše přepsatelné z příkazové řádky: --klic=hodnota, pole čárkami, např. --band=3 --drape=0,0.1,0.3,0.5,0.6).
## Výšky v buňkách (buňka 0,5 m).

static func defaults() -> Dictionary:
	return {
		"world_seed": 2026,
		# geologie: v2 = tabulka pořadí hornin (data/poradi_hornin.json) se zdvihem pod horami, v1 = 5 vrstev gen-v3 (studie 45)
		"geo": "v2",
		"surface_shift": 9.0,    # v2: šablony povrchu o 9 buněk výš, nížina = 40 jako v tabulce
		"zone_tops": [12.5, 25.5, 39.5],
		"zone_amp": [1.2, 1.8, 1.0],
		# zdvih podle typu: [plášť ×u, krystalinikum ×u, λ ztenčení sedimentů, prohnutí plášť, kryst., sed. ×(záporné u)]
		# profily deformace vrstev (Janova skica 16:34): mirne [a spodní, a horní]; hora [plášť ×u, krystalinikum úbočí ×u,
		# u začátku jádra, u plného jádra, buněk jádra pod povrchem, λ ztenčení sedimentů] = hora_vyzdvizena; hora_zvrasnena [a spodní, a horní, mocnina útlumu s hloubkou]; sopka [R, γ, sbíhání spodní, horní, buněk pod povrchem]
		"profiles": {"mirne": [0.1, 0.85], "hora_vyzdvizena": [0.3, 0.6, 2.0, 9.0, 0.0, 2.5], "hora_zvrasnena": [0.2, 1.0, 1.5], "sopka": [11.0, 0.8, 0.35, 1.0, 1.5]},
		"uplift_blur": 2,
		"snowline": 52,
		"treeline": 50,
		"rocks_on": [],
		"rocks_off": [],
		"taper_m": 3.0,         # v2: délka náběhu od okraje (m): okraj = soused, dál vlastní tvar; i délka klínu
		"layer_pool": ["siltstone", "conglomerate", "gypsum"],   # v2: vrstvy, které smí blueprint zapnout (rocks_on)
		"body_freq_scale": 0.0,  # náhodná tělesa podle freq × tohle (0 = jen ukázková níže)
		"demo_pipes": [[40.0, 24.0]],
		"demo_domes": [[16.0, 23.0]],
		# regionální deska (Janova skica 1): vršky vrstev čedič, žula, vápenec, jíl, písek
		"region_base": [7.0, 15.0, 22.0, 24.5, 27.0],
		"region_amp": [2.0, 2.5, 3.0, 2.0, 1.5],
		"region_freq": 0.035,
		"region_warp": 12.0,
		# vlastní charakter blueprintu: vrstvy se zvednou pod kopcem (drape × převýšení nad surf_ref) + malý šum
		"surf_ref": 40.0,
		"drape": [0.0, 0.15, 0.45, 0.6, 0.7],
		"strata_noise": 0.6,
		"soil": 2,
		# navázání
		"band": 4,              # pás dorovnání povrchu od strany se sousedem (buňky), 0 = bez dorovnání
		"strata_band": 0,       # 0 = korekce vrstev přes celý blok, n > 0 jen v pásu n od sousedů
		"free_face": "neumann", # strany bez souseda: neumann (pokračuj) nebo zero (vlastní cíl)
		"continue": true,       # false = jen regionální základ + vlastní charakter (srovnání)
		"iters": 600,
		"omega": 1.8,
		# volitelná hydraulická eroze povrchu (před dorovnáním okrajů)
		"erosion": false,
		"droplets": 3000,
		# běh po snímcích
		"budget_ms": 6.0,
	}

## parametry studie 45 (v1: 5 vrstev gen-v3, povrch prototypu kolem 31)
static func v1(p: Dictionary) -> Dictionary:
	var q := p.duplicate(true)
	q.geo = "v1"; q.surface_shift = 0.0; q.surf_ref = 31.0
	return q

static func apply_args(p: Dictionary, args: PackedStringArray) -> Dictionary:
	for a in args:
		if not a.begins_with("--") or not a.contains("="):
			continue
		var kv := a.substr(2).split("=", true, 1)
		var k := kv[0]
		if not p.has(k):
			continue
		var v = p[k]
		if v is bool: p[k] = kv[1] in ["1", "true", "ano"]
		elif v is int: p[k] = int(kv[1])
		elif v is float: p[k] = float(kv[1])
		elif v is Array and (k.begins_with("rocks_") or k == "layer_pool"): p[k] = Array(kv[1].split(","))
		elif v is Array: p[k] = Array(kv[1].split(",")).map(func(s): return float(s))
		else: p[k] = kv[1]
	return p
