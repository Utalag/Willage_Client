extends RefCounted
## E47d testy podzemí (Jan 20:00). Jednotky: buňka objem 1, průtok 1/t (ug_cell_m3 = 1, ug_q_to_m3 = 1).
## 1) Uzavřená propustná čočka 8 × 6 × 4 se plní, pak přetéká do tůně 4 × 4 (hloubka 3) → tůň plná → přeliv.
## 2) Propustná vrstva s dutinou 3 × 3 × 3 pod ní: dutina se zaplní (podzemní jezero), pak voda teče po vrstvě k okraji ostrova.
## 3) Čočka bez výstupu: naplní se a dál nepřijímá nic.

const UG = preload("res://scripts/voda/podzemi.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const HR = preload("res://scripts/bp/horniny.gd")

static func _imperm() -> int:
	for id in VS.table():
		var e: Array = VS.table()[id]
		if e[0] == 0.0 and e[1] == 0.0 and not UG._soluble(id) and id > 4: return id
	return 1

static func _grid(W: int, H: int, NZ: int, fill_id: int) -> Array:
	var mat := PackedInt32Array(); mat.resize(W * H * NZ); mat.fill(fill_id)
	var top := PackedInt32Array(); top.resize(W * H)
	var wall := PackedByteArray(); wall.resize(W * H)
	return [mat, top, wall]

static func _p() -> Dictionary:
	return {"ponor_perm": 0.3, "ug_leak_q": 0.0, "ug_hloubka": 12, "ug_cell_m3": 1.0, "ug_q_to_m3": 1.0}

static func _set_top(g: Array, W: int, H: int, NZ: int, col: int, t: int) -> void:
	g[1][col] = t
	for z in range(t, NZ): g[0][col * NZ + z] = 0

static func run_all() -> PackedStringArray:
	var L := PackedStringArray(); var ok := true
	var imp := _imperm(); var qs := HR.id_of("quartz_sandstone"); var por := float(VS.table()[qs][1])
	L.append("# E47d testy podzemí: nepropustná %s (perm 0), propustná Křemenný pískovec perm %.2f, por %.2f" % [str(imp), VS.table()[qs][0], por])
	# 1) čočka → tůň 4 × 4
	var W := 12; var H := 12; var NZ := 24
	var g := _grid(W, H, NZ, imp)
	for x in W:
		for y in H:
			var t := 20 if x < 6 else 14
			if x >= 7 and x <= 10 and y >= 4 and y <= 7: t = 11
			_set_top(g, W, H, NZ, x * H + y, t)
	for x in range(1, 9):
		for y in range(3, 9):
			for z in range(7, 11): g[0][(x * H + y) * NZ + z] = qs
	var ctx := UG.make(W, H, NZ, g[0], g[1], g[2], _p())
	var r := UG.solve(ctx, PackedInt32Array([(1 * H + 3) * NZ + 10]), 1.0)
	var exp_v := 192.0 * por
	var t_l: float = r.events[-1].cas_s
	# tůň 4 × 4 na povrchu: tok.gd, výtok čočky = zdroj v jejím sloupci, odtok tůně 0 (ústí do ní plné těleso)
	var hm := PackedFloat64Array(); hm.resize(W * H)
	for i in W * H: hm[i] = float(g[1][i])
	var src := PackedFloat64Array(); src.resize(W * H); src[r.out[4]] = r.out_q
	var mats := PackedInt32Array(); mats.resize(W * H); mats.fill(imp)
	var st := TOK.make(hm, W, H, PackedByteArray(g[2]), mats, src, {"thr": 0.0, "cap": 0.0, "inf": 0.0, "perm_min": 0.3, "springs": true, "pit_q": 0.0}, true)
	TOK.route(st)
	var pit := {}
	for x in TOK.ponds(st, 1.0, 1.0, true, 1.0):
		if x.cells.size() == 16: pit = x
	var t_p: float = pit.udalosti[-1].cas_s if not pit.is_empty() else -1.0
	var edge := 0.0
	for e in TOK.edge_falls(st): edge += e.q
	var g1: bool = r.cells == 192 and absf(r.volume_m3 - exp_v) < 1e-6 and absf(t_l - exp_v) < 1e-6 and r.out[3] == "povrch" and r.out[0] == 10 \
		and r.out[4] / H >= 7 and r.out[4] / H <= 10 and not pit.is_empty() and absf(pit.objem_m3 - 48.0) < 0.1 and absf(t_p - 48.0) < 0.2 and absf(edge - 1.0) < 1e-6
	ok = ok and g1
	L.append("1) čočka: %d buněk, objem pórů %.2f (čekáno 192 · %.2f = %.2f), plná za %.2f t, %d událostí po vrstvách | výstup %s z=%d do sloupce (%d, %d) = dno tůně, %.2f/t | cesta po vrstvě %d buněk" % [
		r.cells, r.volume_m3, por, exp_v, t_l, r.events.size(), r.out[3], r.out[0], r.out[4] / H, r.out[4] % H, r.out_q, r.path.size()])
	L.append("   tůň 4 × 4: %s sloupců, objem %.2f (čekáno 48), plná za %.2f t po čočce → přeliv přes okraj ostrova %.2f/t | celkem do přelivu %.2f t → %s" % [
		str(pit.cells.size()) if not pit.is_empty() else "0", pit.get("objem_m3", 0.0), t_p, edge, t_l + t_p, "OK" if g1 else "CHYBA"])
	# 2) dutina ve vrstvě → podzemní jezero → okraj ostrova
	NZ = 16
	g = _grid(W, H, NZ, imp)
	for i in W * H: _set_top(g, W, H, NZ, i, 12)
	for x in range(1, 12):
		for y in range(3, 9):
			for z in range(5, 8): g[0][(x * H + y) * NZ + z] = qs
	for x in range(4, 7):
		for y in range(4, 7):
			for z in range(2, 5): g[0][(x * H + y) * NZ + z] = 0
	ctx = UG.make(W, H, NZ, g[0], g[1], g[2], _p())
	r = UG.solve(ctx, PackedInt32Array([(1 * H + 3) * NZ + 7]), 1.0)
	exp_v = 27.0 + 66.0 * por
	var g2: bool = r.lake.size() == 27 and absf(r.volume_m3 - exp_v) < 1e-6 and r.out[3] == "okraj" and r.out[0] == 5 and r.out[4] / H == 11 and absf(r.out_q - 1.0) < 1e-9
	ok = ok and g2
	L.append("2) dutina: těleso %d buněk, podzemní jezero %d buněk (dutina 27), objem do výstupu %.2f (čekáno 27 + 66 · %.2f = %.2f), plné za %.2f t | výstup %s z=%d x=%d (stěna ostrova → mlha) %.2f/t | cesta po vrstvě %d buněk → %s" % [
		r.cells, r.lake.size(), r.volume_m3, por, exp_v, r.events[-1].cas_s, r.out[3], r.out[0], r.out[4] / H, r.out_q, r.path.size(), "OK" if g2 else "CHYBA"])
	# 3) čočka bez výstupu
	g = _grid(W, H, NZ, imp)
	for i in W * H: _set_top(g, W, H, NZ, i, 12)
	for x in range(3, 7):
		for y in range(3, 7):
			for z in range(4, 6): g[0][(x * H + y) * NZ + z] = qs
	ctx = UG.make(W, H, NZ, g[0], g[1], g[2], _p())
	r = UG.solve(ctx, PackedInt32Array([(3 * H + 3) * NZ + 5]), 1.0)
	var g3: bool = r.closed and absf(r.volume_m3 - 32.0 * por) < 1e-6 and r.out_q == 0.0
	ok = ok and g3
	L.append("3) uzavřená čočka: %d buněk, objem %.2f (čekáno 32 · %.2f), plná za %.2f t, výstup žádný → pak nepřijímá, výtok %.2f → %s" % [r.cells, r.volume_m3, por, r.events[-1].cas_s, r.out_q, "OK" if g3 else "CHYBA"])
	L.append("výsledek: %s" % ("VŠE OK" if ok else "CHYBA"))
	return L
