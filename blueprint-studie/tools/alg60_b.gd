extends SceneTree
## E60 povrch B: je graf pánví přesný? Srovnání B s priority-flood bez ε (vlastní kopie, ε = 0) a s tok.gd (ε = 1e-3).
const C = preload("res://scripts/podzemi52/cache.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const B = preload("res://scripts/alg58/povrch58.gd")
const RK = preload("res://scripts/svet8/reky.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PR = preload("res://scripts/bp/params.gd")

func _pf(hm: PackedFloat64Array, W: int, wall: PackedByteArray, eps: float) -> PackedFloat64Array:
	var n := W * W; var fill := hm.duplicate(); var done := PackedByteArray(); done.resize(n)
	var heap := []
	for i in n:
		var x := i / W; var y := i % W
		if wall[i] == 0 and (x == 0 or y == 0 or x == W - 1 or y == W - 1): RK._push(heap, fill[i], i); done[i] = 1
	while not heap.is_empty():
		var e := RK._pop(heap); var i: int = e[1]
		var x := i / W; var y := i % W
		for d in 8:
			var qx: int = x + TOK.DX[d]; var qy: int = y + TOK.DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= W: continue
			var j := qx * W + qy
			if done[j] == 1 or wall[j] == 1: continue
			done[j] = 1; fill[j] = maxf(hm[j], fill[i] + eps); RK._push(heap, fill[j], j)
	return fill

## E60: B + ε dopočet. tok.gd fill je pevný bod F_j = max(hm_j, min_soused F + ε) s okrajem F = hm (první vytažený soused
## má nejmenší fill). Z fill bez ε (B) se k němu dojde zvedáním zdola (operátor je monotónní) jen v buňkách, kde podmínka neplatí.
func _cand(F: PackedFloat64Array, hm: PackedFloat64Array, wall: PackedByteArray, W: int, j: int, eps: float) -> float:
	var x := j / W; var y := j % W; var mn := INF
	for d in 8:
		var qx: int = x + TOK.DX[d]; var qy: int = y + TOK.DY[d]
		if qx < 0 or qy < 0 or qx >= W or qy >= W: continue
		var i := qx * W + qy
		if wall[i] == 1: continue
		mn = minf(mn, F[i])
	return maxf(hm[j], mn + eps) if mn < INF else F[j]

func _eps_fix(hm: PackedFloat64Array, W: int, wall: PackedByteArray, f0: PackedFloat64Array, eps: float) -> Dictionary:
	var F := f0.duplicate(); var heap := []; var pops := 0; var raised := 0
	for j in W * W:
		var x := j / W; var y := j % W
		if wall[j] == 1 or x == 0 or y == 0 or x == W - 1 or y == W - 1: continue
		var c := _cand(F, hm, wall, W, j, eps)
		if c > F[j]: RK._push(heap, c, j)
	while not heap.is_empty():
		var e := RK._pop(heap); var j: int = e[1]; pops += 1
		if float(e[0]) <= F[j]: continue
		var c := _cand(F, hm, wall, W, j, eps)
		if c <= F[j]: continue
		F[j] = c; raised += 1
		var x := j / W; var y := j % W
		for d in 8:
			var qx: int = x + TOK.DX[d]; var qy: int = y + TOK.DY[d]
			if qx <= 0 or qy <= 0 or qx >= W - 1 or qy >= W - 1: continue
			var i := qx * W + qy
			if wall[i] == 1: continue
			var ci := _cand(F, hm, wall, W, i, eps)
			if ci > F[i]: RK._push(heap, ci, i)
	return {"fill": F, "pops": pops, "raised": raised}

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var nv := int(p.s64_voda_n)
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var Gs := V.grid(d.blocks, d.T, d.n, nv, false); var W: int = Gs.W
	d.clear()
	var hm: PackedFloat64Array = Gs.hm
	var t := Time.get_ticks_usec(); var rb := B.basin_fill(hm, W, W, Gs.wall); var b_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec(); var f0 := _pf(hm, W, Gs.wall, 0.0); var pf0_ms := (Time.get_ticks_usec() - t) / 1000.0
	var fe := _pf(hm, W, Gs.wall, TOK.EPS)
	var fb: PackedFloat64Array = rb.fill
	t = Time.get_ticks_usec(); var fx := _eps_fix(hm, W, Gs.wall, fb, TOK.EPS); var fix_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec(); var fe2 := _pf(hm, W, Gs.wall, TOK.EPS); var pfe_ms := (Time.get_ticks_usec() - t) / 1000.0
	var dfix := 0; var dfixmax := 0.0
	for i in W * W:
		if fx.fill[i] != fe2[i]: dfix += 1; dfixmax = maxf(dfixmax, absf(fx.fill[i] - fe2[i]))
	var diffB0 := 0; var dmaxB0 := 0.0; var lake0 := 0; var lakeB := 0; var lakeE := 0; var epsOnly := 0; var raisedE := 0; var dmaxE := 0.0
	for i in W * W:
		if Gs.wall[i] == 1: continue
		if fb[i] != f0[i]: diffB0 += 1; dmaxB0 = maxf(dmaxB0, absf(fb[i] - f0[i]))
		if f0[i] > hm[i] + 0.01: lake0 += 1
		if fb[i] > hm[i] + 0.01: lakeB += 1
		if fe[i] > hm[i] + 0.01:
			lakeE += 1
			if not (f0[i] > hm[i] + 0.01): epsOnly += 1
		if fe[i] > hm[i]: raisedE += 1
		dmaxE = maxf(dmaxE, fe[i] - f0[i])
	var out := {"W": W, "B_ms": b_ms, "pf0_ms": pf0_ms, "B_vs_pf0_diff_cells": diffB0, "B_vs_pf0_dmax": dmaxB0, "lake_pf0": lake0, "lake_B": lakeB,
		"lake_eps": lakeE, "lake_eps_only": epsOnly, "raised_eps": raisedE, "eps_minus_pf0_max": dmaxE,
		"Beps_ms": b_ms + fix_ms, "eps_fix_ms": fix_ms, "pf_eps_ms": pfe_ms, "Beps_vs_tokfill_diff_cells": dfix, "Beps_vs_tokfill_dmax": dfixmax, "eps_fix_raised": fx.raised, "eps_fix_pops": fx.pops}
	FileAccess.open(ProjectSettings.globalize_path("res://shots/alg60/b_s%d.json" % nv), FileAccess.WRITE).store_string(JSON.stringify(out))
	print(out)
	quit()
