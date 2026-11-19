extends RefCounted
## E47b: strže podle průtoku (stream power [23]), ponory a vodopády na mřížce celého světa W × H (index gx · H + gy, jednotky U).
## Vstup: hm (povrch), wall (1 = mimo svět / chybějící blok), mat_at(gi) → MaterialId 2 m pod povrchem.
## Výstup: hm změněná na místě + {chan, sink, falls, depth, acc, ...}. Jednoduchá varianta ponoru: voda zmizí (zvodeň se nemodeluje).

const RK = preload("res://scripts/svet8/reky.gd")   # binární halda (_push/_pop)
const TOK = preload("res://scripts/voda/tok.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const Mat = preload("res://scripts/kopie/mat.gd")
const KARST := ["cave_limestone", "deep_limestone", "dolomite", "limestone_outcrop", "gypsum", "rock_salt"]
const SOFT := ["loess", "gravel_sand", "weathered_clay", "hill_sand", "subalpine_scree", "topsoil", "conglomerate"]

static var _ER := {}
## erodovatelnost podle zóny tabulky pořadí (měkké sedimenty a půda víc)
static func erod(m: int) -> float:
	if _ER.is_empty():
		for e in HR.raw().rocks:
			var z: String = e.zone
			var k: float = {"sedimenty": 1.0, "hory": 0.7, "krystalinikum": 0.5, "plast": 0.4, "telesa": 0.4, "povrch": 1.3}.get(z, 1.0)
			if e.key in SOFT: k = 1.3
			_ER[int(e.id)] = k
		_ER[Mat.GRASS] = 1.3; _ER[Mat.DIRT] = 1.3; _ER[Mat.SAND] = 1.3; _ER[Mat.CLAY] = 1.2; _ER[Mat.SNOW] = 0.3
	return float(_ER.get(m, 0.5))

static var _K := {}
static func soluble(m: int) -> bool:
	if _K.is_empty():
		for k in KARST: _K[HR.id_of(k)] = true
	return _K.has(m)

static func permeable(m: int, p: Dictionary) -> bool:
	var e: Array = VS.table().get(m, [0.0, 0.0, 0.0, 0.0])
	return float(e[0]) >= float(p.ponor_perm)

const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

## priority-flood [20] od okraje světa (zdi se přeskočí), pořadí zpracování = od nejnižšího
static func _fill(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray) -> Array:
	var fill := hm.duplicate()
	var done := PackedByteArray(); done.resize(W * H)
	var heap := []
	for i in W * H:
		if wall[i] == 1: done[i] = 1; continue
		var x := i / H; var y := i % H
		var edge := x == 0 or y == 0 or x == W - 1 or y == H - 1
		if not edge:
			for d in 4:
				var j: int = (x + DX[d]) * H + y + DY[d]
				if wall[j] == 1: edge = true
		if edge: RK._push(heap, fill[i], i); done[i] = 1
	var order := PackedInt32Array()
	while not heap.is_empty():
		var e := RK._pop(heap); var i: int = e[1]
		order.append(i)
		var x := i / H; var y := i % H
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if done[j] == 1: continue
			done[j] = 1; fill[j] = maxf(fill[j], fill[i] + 1e-3); RK._push(heap, fill[j], j)
	return [fill, order]

## src: prázdné = E47b (každý sloupec přispívá 1, práh strz_thr); jinak E47c průtok z pramenů v l/s (práh strz_thr_q).
static func run(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray, mat_at: Callable, p: Dictionary, src := PackedFloat64Array(), ug := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var cm := float(p.get("voda_cell_m", 0.5))   # E50: výška buňky mřížky v m (0,5 = řídicí mřížka; 0,125 = buňky 64 na blok)
	var springs := not src.is_empty()
	var mats := PackedInt32Array(); mats.resize(W * H)
	for i in W * H:
		if wall[i] == 0: mats[i] = mat_at.call(i)
	if not springs:
		src.resize(W * H)
		for i in W * H: src[i] = 1.0 if wall[i] == 0 else 0.0
	var st := TOK.make(hm.duplicate(), W, H, wall, mats, src, TOK.losses(p, springs), bool(p.get("ostrov_okraj", false)) and springs)
	if not ug.is_empty(): st.ug = ug   # E47d podzemí po vrstvě
	TOK.route(st)
	var fill: PackedFloat64Array = st.fill; var order: PackedInt32Array = st.order; var to: PackedInt32Array = st.to
	var slope := PackedFloat64Array(); slope.resize(W * H)
	for i in order:
		var x := i / H; var y := i % H
		slope[i] = maxf((hm[i] - (hm[to[i]] if to[i] >= 0 else hm[i])) / (1.4142 if to[i] >= 0 and (to[i] / H != x and to[i] % H != y) else 1.0), 0.0)
	var acc: PackedFloat64Array = st.ain; var eff: PackedFloat64Array = st.eff; var sink: PackedByteArray = st.sink
	var thr: float = st.L.thr
	var lost := 0.0; var n_karst := 0
	for i in W * H:
		lost += src[i]
		if sink[i] == 2: n_karst += 1
	for f in TOK.edge_falls(st): lost -= f.q
	for u in st.under: lost -= u.q   # podzemím z tůní k vyvěračce ve stěně – neztrácí se
	if not st.edge_out:
		for i in order:
			if to[i] < 0: lost -= eff[i]
	# zahloubení: E = K · k_mat · A^m · S^n jen v korytech (A po ponorech ≥ práh), K z mediánu = cíl
	var m := float(p.strz_m); var n := float(p.strz_n)
	var raw := PackedFloat64Array(); raw.resize(W * H)
	var vals := []
	for i in W * H:
		if wall[i] == 0 and (eff[i] >= thr or sink[i] > 0) and slope[i] >= float(p.strz_min_s):
			raw[i] = erod(mats[i]) * pow(maxf(eff[i], acc[i] if sink[i] > 0 else 0.0), m) * pow(slope[i], n); vals.append(raw[i])
	vals.sort()
	var target := float(p.strz_target_m) / cm
	var med := maxf(float(vals[vals.size() / 2]) if not vals.is_empty() else 1.0, 1e-9)
	var K := target / med
	var gam := float(p.strz_gamma)   # kontrast: hloubka = cíl · (E / medián)^γ  (γ 1 = čistý stream power, γ < 1 tlumí rozptyl sklonu)
	var depth := PackedFloat64Array(); depth.resize(W * H)
	var chan := PackedByteArray(); chan.resize(W * H)
	for i in W * H:
		if raw[i] > 0.0:
			chan[i] = 1; depth[i] = maxf(depth[i], minf(target * pow(raw[i] / med, gam), float(p.strz_max_k) * target))
	for i in W * H:   # břehy
		if chan[i] == 0: continue
		var x := i / H; var y := i % H
		for d in 4:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if wall[j] == 0 and chan[j] == 0: depth[j] = maxf(depth[j], float(p.strz_bank) * depth[i])
	for i in W * H:
		hm[i] = maxf(hm[i] - depth[i], 2.0)
	if bool(p.strz_mono):   # spádový profil: koryto po proudu nikdy výš (jinak proměnná hloubka nechá v korytě uzavřené jámy)
		for k in range(order.size() - 1, -1, -1):
			var i := order[k]; var j := to[i]
			if chan[i] == 1 and j >= 0 and chan[j] == 1 and hm[j] > hm[i] - 0.01:
				var nd := hm[j] - (hm[i] - 0.01)
				hm[j] -= nd; depth[j] += nd
	# vodopády: spád po proudu ≥ vodopad_m; tůň pod ním
	var falls := []
	var fdrop := float(p.vodopad_m) / cm
	# E52: spád se měří na vodorovné vzdálenosti vodopad_dx_m po proudu (0,5 m = 1 buňka řídicí mřížky = staré pravidlo);
	# souvislý spád přes víc buněk se slije do jednoho vodopádu (horní buňka). vodopad_dx_m ≤ 0 = staré pravidlo na buňku.
	var dxm := float(p.get("vodopad_dx_m", 0.5))
	var fstep := PackedInt32Array(); fstep.resize(W * H)
	var ffoot := PackedInt32Array(); ffoot.resize(W * H); ffoot.fill(-1)
	for i in W * H:
		if chan[i] == 0 or to[i] < 0: continue
		var j := to[i]; var nst := 1
		if dxm > 0.0:
			var dist := 0.0; j = i; nst = 0
			while to[j] >= 0 and dist < dxm - 1e-6:
				var t2 := to[j]
				dist += cm * (1.4142 if (t2 / H != j / H and t2 % H != j % H) else 1.0)
				j = t2; nst += 1
		if hm[i] - hm[j] >= fdrop: ffoot[i] = j; fstep[i] = nst
	for i in W * H:
		if ffoot[i] < 0: continue
		var x := i / H; var y := i % H; var sup := false
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var u := qx * H + qy
			if to[u] == i and ffoot[u] >= 0 and fstep[u] > 1: sup = true; break
		if sup: continue
		var j := ffoot[i]
		falls.append({"top": i, "foot": j, "drop_m": (hm[i] - hm[j]) * cm, "acc": eff[i], "z_top": hm[i], "z_foot": hm[j]})
	var plunge := 0.0
	for f in falls:
		var j: int = f.foot
		var pd := minf(float(p.tun_k) * (f.z_top - f.z_foot), float(p.tun_max_m) / cm)
		hm[j] = maxf(hm[j] - pd, 2.0); plunge = maxf(plunge, pd)
		var x := j / H; var y := j % H
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var q := qx * H + qy
			if wall[q] == 0 and q != f.top: hm[q] = maxf(hm[q] - 0.4 * pd, 2.0)
		f.z_foot = hm[j]
	return {"chan": chan, "sink": sink, "falls": falls, "depth": depth, "acc": acc, "eff": eff, "to": to, "mats": mats,
		"lost": lost, "n_karst": n_karst, "edge": TOK.edge_falls(st), "st": st, "K": K, "plunge_max": plunge, "ms": (Time.get_ticks_usec() - t0) / 1000.0}
