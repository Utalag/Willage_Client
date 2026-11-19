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
		# E47 eroze po vrstvách a voda (scripts/voda): kapky na blok, pravidla jako erosion.gd, nános, déšť voda_sim
		"ero_droplets": 800, "ero_inertia": 0.05, "ero_cap": 1.0, "ero_erode": 0.1, "ero_deposit_rate": 0.1, "ero_steps": 30,
		"ero_deposit": "gravel_sand",
		# E47b strže (stream power), ponory, vodopády (scripts/voda/strze.gd)
		"strz_thr": 8.0, "strz_target_m": 2.0, "strz_max_k": 2.0, "strz_gamma": 0.5, "strz_mono": false, "strz_m": 0.5, "strz_n": 1.0, "strz_bank": 0.35,
		"ponor_perm": 0.3, "ponor_cap": 40.0, "ponor_inf": 0.5, "strz_min_s": 0.02,
		# E47c voda jen z pramenů (l/s), okraj ostrova = odtok, lokální přepočet koryta (scripts/voda/prameny.gd, tok.gd)
		"voda_zdroj": "prameny", "ostrov_okraj": true, "strz_thr_q": 0.3, "ponor_cap_q": 3.0, "ponor_inf_q": 0.02,
		"pram_q_snih": 4.0, "pram_q_kontakt": 1.5, "pram_q_kras": 5.0, "pram_peak_q": 0.97, "pram_slope": 0.5, "pram_dist": 8.0, "pram_max": 10, "pram_max_druh": 4,
		# Jan 19:48: odtok prohlubně do podzemí = Σ perm · pit_drain_q (l/s na sloupec); tok_margin = okraj okna lokálního přepočtu
		"tok_margin": 6, "pit_drain_q": 0.01,
		# E47d podzemí po propustné vrstvě (scripts/voda/podzemi.gd): zapnuto, hloubka hledání vstupu (buňky), průsak do slabě propustného okolí (l/s na stěnu · perm)
		"podzemi_vrstva": true, "ug_hloubka": 12, "ug_leak_q": 0.0005, "ponor_rate": 0.2, "vodopad_m": 1.5, "tun_k": 0.5, "tun_max_m": 1.0,
		# E49 malý svět (scripts/svet8): dlaždic na stranu, bodů hrubé mřížky na dlaždici, terén, počasí, eroze, řeky, typy
		"s8_tiles": 8, "s8_px": 8, "s8_base_amp": 4.0, "s8_mtn_amp": 20.0, "s8_mtn_bias": 0.0, "s8_lake_amp": 6.0, "s8_volcano": 1,
		"s8_rain_base": 0.12, "s8_rain_oro": 0.25, "s8_rain_use": 0.6, "s8_rain_recharge": 0.02,
		"s8_droplets": 2.0, "s8_ero_cap": 1.0, "s8_ero_erode": 0.1, "s8_ero_dep": 0.1, "s8_frames": 8,
		"s8_river": 18.0, "s8_force_mtn": "", "s8_massif": true, "s8_lake": 0.3, "s8_lake_frac": 0.15, "s8_mtn_mean": 47.0, "s8_mtn_max": 53.0, "s8_hill_relief": 6.0, "s8_slope": 0.6,
		"s8_first": [3, 4],
		"s56_on": false, "s56_max_slope": 1.0, "s56_pasy": 200, "s56_hladit": 1, "s56_hladit_w": 0.5, "s56_paty": 0.2, "s56_hreben": 2.0,
		# E50 svět 8 × 8 v jemných buňkách (scripts/svet64): buněk na stranu bloku (výška 4n), vodní mřížka na blok (dělitel s64_n),
		# podzemí ve 3D, kolik bloků (0 = všechny), determinismus na prvních N blocích, srovnání s E49, uložit data pro GIF a izo
		"s64_n": 64, "s64_voda_n": 64, "s64_podzemi": true, "s64_bloky": 0, "s64_det_bloky": 3, "s64_e49": true, "s64_data": true, "s64_out": "bench_svet64",
		# E50 dutiny: E49 dlaždice dutiny nemají; jedna dutina (vzduch = jeskyně / voda = rezervoár) o s64_dutina_n základních buňkách v typech
		"s64_dutina": "vzduch", "s64_dutina_n": 40, "s64_dutina_typy": "kopec,svah,hora_vyzdvizena,hora_zvrasnena",
		"voda_cell_m": 0.5,
		# E52 podzemí: varianty (scripts/podzemi52). cache světa svet64, varianta (slovnik | pole | hruba | funkce | darcy), podzemí na hrubší
		# mřížce (s64_ug_n buněk na blok, Jan 21:14 výchozí 32; povrch dál s64_voda_n), pole: těleso jen do p52_hloubka_m pod povrchem,
		# funkce: režim nadrz (jedna nádrž = jako slovník) | preliv (plnění a přelévání od vstupu), vodopád: spád na vodorovné vzdálenosti
		"p52_cache": "res://.cache52/svet64.bin", "p52_var": "slovnik", "s64_ug_n": 32, "s64_ug_alg": "pole", "p52_ug_n": 64, "p52_hloubka_m": 6.0,
		"p52_rezim": "nadrz", "p52_darcy_it": 40000, "p52_darcy_k": 0.0001, "p52_darcy_dz": 0.5, "p52_k0": 0.001, "p55_perm_dno": 0.05, "p67_okraj": false, "p67_rezim": "", "p67_kras": true, "p67_film_m": 0.5, "p67_prune": true, "p67_prune_min": 0.1, "p68_hydro": true, "p73_vyver": false, "p73_pritok": false, "p73_zrychleni": false, "p73_prusak_tok": false, "p68_kola": 64, "p68_tol": 0.000000001, "p72_slucovat": true, "p72_prusak": true, "p69_remizy": true, "p70_prumer": "pomer", "p71_kapacita": true, "p71_prusak": true, "p71_cas": 144.0, "p58_var": "base", "p58_dz": 0.0625, "p58_edits": 20, "p58_seed": 58, "p58_dig_m": 1.0, "p58_tol": 1e-9, "p58_near": 6, "p58_bfs_max": 20000, "p58_tag": "", "p58_sdz": 1.0, "p58_surf_var": "base", "p64_budget": 5000, "p64_oldref": false, "p64_tag": "", "p60_mode": "prof", "p60_m0": 0, "p60_ff": true, "p52_k_dut": 1.0, "p52_cg_it": 5000, "p52_cg_tol": 1e-6, "p52_out": "podzemi52", "vodopad_dx_m": 0.5,
		# E51 eroze a usazování událostmi (scripts/eroze51): Manning n, šířka koryta k_b · √Q (m), min. sklon, sklon přes okraj,
		# exponent rychlosti v odpočtu (0 = čistě objem), koncentrace plavenin c0 (m³/m³), materiál nánosu, okraj okna přepočtu
		"e51_n": 0.035, "e51_kb": 3.0, "e51_s_min": 0.005, "e51_s_edge": 0.5, "e51_k": 0.0, "e51_c0": 0.0002, "e51_nanos": "clay",
		"e51_margin": 4, "e51_s_len": 4, "e51_dni": 60.0, "e51_perf_n": 128, "e51_perf_ev": 300, "e51_halda": 1000000, "e51b_ev": 100,
		# E53 plošný tok maticemi: mapa p53_n² (perf z E51), propustnost l/s na buňku podle materiálu, mělká voda dt/tření
		"p53_n": 64, "p53_alpha": 0.5, "p53_vcell": 125.0, "p53_k_dirt": 2.0, "p53_k_sand": 2.0, "p53_k_clay": 1.0, "p53_k_rock": 1.0,
		"p53_max": 3000, "p53_sw_dt": 0.05, "p53_sw_cf": 2.0, "p53_sw_max": 4000, "p53_margin": 12, "p53_epoch": 3, "p53_jen": "",
		"voda_rain": 0.02, "voda_rain_ticks": 60, "voda_ticks": 400, "voda_depth": 6, "voda_infil": 0.10,
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
