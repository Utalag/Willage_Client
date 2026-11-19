extends RefCounted
## E52: demo testy E47d (čočka → tůň 4 × 4, dutina = podzemní jezero, uzavřená čočka) pro každou variantu podzemí.
## Buňka 1 m, objem 1, průtok 1/t. Buňkové varianty musí dát přesně čísla E47d. Funkce (pásma ze sloupců) má hladinu
## v metrech a výstup ve stěně na spodku vrstvy (spojitě): objem do výstupu u dutiny je jen dutina (27), ne + 1 vrstva buněk.

const S = preload("res://scripts/podzemi52/ug_slovnik.gd")
const P = preload("res://scripts/podzemi52/ug_pole.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const TP = preload("res://scripts/voda/tests_podzemi.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const HR = preload("res://scripts/bp/horniny.gd")

static func _p(rezim: String) -> Dictionary:
	return {"ponor_perm": 0.3, "ug_leak_q": 0.0, "ug_hloubka": 12, "ug_cell_m3": 1.0, "ug_q_to_m3": 1.0, "p52_rezim": rezim}

static func _scen(k: int, imp: int, qs: int) -> Dictionary:
	var W := 12; var H := 12; var NZ := 24 if k == 1 else 16
	var g := TP._grid(W, H, NZ, imp)
	var e := 0
	if k == 1:
		for x in W:
			for y in H:
				var t := 20 if x < 6 else 14
				if x >= 7 and x <= 10 and y >= 4 and y <= 7: t = 11
				TP._set_top(g, W, H, NZ, x * H + y, t)
		for x in range(1, 9):
			for y in range(3, 9):
				for z in range(7, 11): g[0][(x * H + y) * NZ + z] = qs
		e = (1 * H + 3) * NZ + 10
	elif k == 2:
		for i in W * H: TP._set_top(g, W, H, NZ, i, 12)
		for x in range(1, 12):
			for y in range(3, 9):
				for z in range(5, 8): g[0][(x * H + y) * NZ + z] = qs
		for x in range(4, 7):
			for y in range(4, 7):
				for z in range(2, 5): g[0][(x * H + y) * NZ + z] = 0
		e = (1 * H + 3) * NZ + 7
	else:
		for i in W * H: TP._set_top(g, W, H, NZ, i, 12)
		for x in range(3, 7):
			for y in range(3, 7):
				for z in range(4, 6): g[0][(x * H + y) * NZ + z] = qs
		e = (3 * H + 3) * NZ + 5
	return {"W": W, "H": H, "NZ": NZ, "g": g, "e": e}

static func run_all() -> PackedStringArray:
	var L := PackedStringArray(); var all_ok := true
	var imp := TP._imperm(); var qs := HR.id_of("quartz_sandstone"); var por := float(VS.table()[qs][1])
	L.append("# E52 demo testy E47d × varianty podzemí (%s), propustná Křemenný pískovec por %.2f" % [Time.get_datetime_string_from_system(), por])
	for vname in ["slovnik", "pole", "funkce nadrz", "funkce preliv", "funkce auto"]:
		var parts := PackedStringArray(); var ok := true
		for k in [1, 2, 3]:
			var sc := _scen(k, imp, qs)
			var W: int = sc.W; var H: int = sc.H; var NZ: int = sc.NZ; var g: Array = sc.g; var e: int = sc.e
			var ctx: Dictionary; var ent: int
			if vname == "slovnik": ctx = S.make(W, H, NZ, g[0], g[1], g[2], _p("nadrz")); ent = e
			elif vname == "pole": ctx = P.make(W, H, NZ, g[0], g[1], g[2], _p("nadrz")); ent = e
			else:
				ctx = F.from_cells(W, H, NZ, g[0], g[1], g[2], _p(vname.split(" ")[1]))
				ent = F.band_at(ctx, e / NZ, float(e % NZ) + 0.5)
			var r: Dictionary = ctx.impl.solve(ctx, PackedInt32Array([ent]), 1.0)
			var fn: bool = String(vname).begins_with("funkce")
			var t_last: float = r.events[-1].cas_s if not r.events.is_empty() else -1.0
			var good := false; var txt := ""
			if k == 1:
				var exp_v := 192.0 * por
				var zx: float = 11.0 if fn else 10.0
				good = absf(r.volume_m3 - exp_v) < 1e-6 and absf(t_last - exp_v) < 1e-6 and not r.out.is_empty() and r.out[3] == "povrch" \
					and absf(float(r.out[0]) - zx) < 1e-6 and int(r.out[4]) / H >= 7 and int(r.out[4]) / H <= 10 and absf(r.out_q - 1.0) < 1e-9
				txt = "1) čočka %.2f (čekáno %.2f), plná za %.2f t, výstup %s z %s do (%d, %d)" % [r.volume_m3, exp_v, t_last,
					str(r.out[3]) if not r.out.is_empty() else "—", str(r.out[0]) if not r.out.is_empty() else "—", int(r.out[4]) / H if not r.out.is_empty() else -1, int(r.out[4]) % H if not r.out.is_empty() else -1]
			elif k == 2:
				var exp_v := 27.0 if fn else 27.0 + 66.0 * por
				var lake: float = float(r.lake_m3) if fn else float(r.lake.size())
				good = absf(lake - 27.0) < 1e-6 and absf(r.volume_m3 - exp_v) < 1e-6 and not r.out.is_empty() and r.out[3] == "okraj" \
					and absf(float(r.out[0]) - 5.0) < 1e-6 and int(r.out[4]) / H == 11 and absf(r.out_q - 1.0) < 1e-9
				txt = "2) dutina: jezero %.0f (27), objem do výstupu %.2f (čekáno %.2f), výstup %s z %s x %d" % [lake, r.volume_m3, exp_v,
					str(r.out[3]) if not r.out.is_empty() else "—", str(r.out[0]) if not r.out.is_empty() else "—", int(r.out[4]) / H if not r.out.is_empty() else -1]
			else:
				good = r.closed and absf(r.volume_m3 - 32.0 * por) < 1e-6 and r.out_q == 0.0
				txt = "3) uzavřená čočka %.2f (čekáno %.2f), výstup žádný, výtok %.2f" % [r.volume_m3, 32.0 * por, r.out_q]
			ok = ok and good
			parts.append(txt + (" OK" if good else " CHYBA"))
		all_ok = all_ok and ok
		L.append("%s: %s | %s" % [vname, " | ".join(parts), "OK" if ok else "CHYBA"])
	L.append("výsledek: %s" % ("VŠE OK" if all_ok else "CHYBA"))
	return L

## E55: režim podle dna. Deska pískovce z 4..6 přes celou šířku (výstup okrajem x = 11), pod ní dno: nepropustné (imp),
## slabě propustné (tráva perm 0,25 > práh 0,05) nebo půl na půl (x < 6 nepropustné). Bilance přítok = průsak + výtok.
static func run_e55() -> PackedStringArray:
	var L := PackedStringArray(); var all_ok := true
	var imp := TP._imperm(); var qs := HR.id_of("quartz_sandstone"); var weak := 1; var leak_full := 0.0
	for case in ["nepropustne", "propustne", "pul"]:
		var W := 12; var H := 12; var NZ := 16
		var g := TP._grid(W, H, NZ, imp)
		for i in W * H: TP._set_top(g, W, H, NZ, i, 12)
		for x in W:
			for y in range(3, 9):
				var fm := imp
				if case == "propustne" or (case == "pul" and x >= 6): fm = weak
				for z in range(0, 4): g[0][(x * H + y) * NZ + z] = fm
				for z in range(4, 6): g[0][(x * H + y) * NZ + z] = qs
		var p := _p("auto"); p.ug_leak_q = 0.002; p.p55_perm_dno = 0.05
		var ctx := F.from_cells(W, H, NZ, g[0], g[1], g[2], p)
		var e := (1 * H + 5) * NZ + 5
		var ent := F.band_at(ctx, e / NZ, float(e % NZ) + 0.5)
		var r: Dictionary = ctx.impl.solve(ctx, PackedInt32Array([ent]), 1.0)
		var bal: float = float(r.q_in) - float(r.leak) - float(r.out_q) - (float(r.q_in) - float(r.leak) if r.closed else 0.0)
		var f: float = r.dno.f_prop
		var exp_mode: String = {"nepropustne": "preliv", "propustne": "nadrz", "pul": "smes"}[case]
		var good: bool = String(r.rezim_tel) == exp_mode and absf(bal) < 1e-9
		if case == "pul": good = good and absf(f - 0.5) < 1e-9 and absf(float(r.leak) - 0.5 * leak_full) < 1e-9
		if case == "propustne": leak_full = float(r.leak)
		if case == "propustne": good = good and float(r.leak) > 0.0
		all_ok = all_ok and good
		L.append("E55 dno %s: režim %s (čekáno %s), podíl propustného dna %.2f, průsak %.3f, výtok %.3f (%s), bilance %.9f → %s" % [case, r.rezim_tel, exp_mode, f, r.leak, r.out_q,
			str(r.out[3]) if not r.out.is_empty() else "—", bal, "OK" if good else "CHYBA"])
	L.append("výsledek E55: %s" % ("VŠE OK" if all_ok else "CHYBA"))
	return L
