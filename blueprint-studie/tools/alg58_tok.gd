extends SceneTree
## E58 povrch: route (halda) vs A (kbelíky) vs B (graf pánví), výkopy: plný route vs update (C, E51b) vs update + A.
## Svět svet64 z cache při s64_voda_n (16/32/64 → 128² / 256² / 512²). → shots/alg58/tok_s%d.json
const C = preload("res://scripts/podzemi52/cache.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const B = preload("res://scripts/alg58/povrch58.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const M = preload("res://scripts/svet64/mereni.gd")
const PR = preload("res://scripts/bp/params.gd")

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var nv := int(p.s64_voda_n); var sdz := float(p.get("p58_sdz", 1.0))
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var T: int = d.T; var n: int = d.n
	var q := V.scaled(p, nv); var cm := 8.0 / nv
	var Gs := V.grid(d.blocks, T, n, nv, false); var W: int = Gs.W
	d.clear()
	var springs := PRM.find(Gs.hm, W, W, Gs.wall, Gs.mat_d, q)
	var src := PRM.src(springs, Gs.hm, W * W)
	var dd := int(round(float(q.strz_target_m) / float(q.voda_cell_m)))
	var mats := PackedInt32Array(); mats.resize(W * W)
	for i in W * W:
		if Gs.wall[i] == 0: mats[i] = Gs.mat_d.call(i, dd * 16 / nv)
	var L := TOK.losses(q, true)
	var mk := func() -> Dictionary: return TOK.make(Gs.hm.duplicate(), W, W, Gs.wall, mats, src.duplicate(), L, true)
	var out := {"nv": nv, "W": W, "sdz": sdz}
	# plný route: 2 × střídavě, bere se menší čas
	var tb := INF; var ta := INF
	var s0: Dictionary; var s1: Dictionary
	for rep in 2:
		TOK.FLOOD_DZ = 0.0; s0 = mk.call(); var t := Time.get_ticks_usec(); TOK.route(s0); tb = minf(tb, M.ms(t))
		TOK.FLOOD_DZ = sdz; s1 = mk.call(); t = Time.get_ticks_usec(); TOK.route(s1); ta = minf(ta, M.ms(t))
	TOK.FLOOD_DZ = 0.0
	out.route_ms = tb; out.route_A_ms = ta
	# samotný flood (bez D8 a průtoku)
	var ins := PackedByteArray(); ins.resize(W * W); ins.fill(1)
	var seeds := PackedInt32Array()
	for i in W * W:
		if Gs.wall[i] == 0 and TOK._border(s0, i): seeds.append(i)
	var sf: Dictionary = mk.call()
	for i in W * W: sf.fill[i] = sf.hm[i]
	var t2 := Time.get_ticks_usec(); TOK._flood(sf, ins, seeds); out.flood_ms = M.ms(t2)
	for i in W * W: sf.fill[i] = sf.hm[i]
	TOK.FLOOD_DZ = sdz; t2 = Time.get_ticks_usec(); TOK._flood(sf, ins, seeds); out.flood_A_ms = M.ms(t2); TOK.FLOOD_DZ = 0.0
	out.same_A = s0.fill == s1.fill and s0.eff == s1.eff and s0.to == s1.to
	# B: graf pánví
	var rb := B.basin_fill(Gs.hm, W, W, Gs.wall)
	out.B_ms = rb.ms; out.B_parts = rb.ms_parts; out.B_basins = rb.basins; out.B_edges = rb.edges
	var fb: PackedFloat64Array = rb.fill; var f0: PackedFloat64Array = s0.fill
	var nland := 0; var lake0 := 0; var lakeB := 0; var both := 0; var dmax := 0.0; var big := 0
	for i in W * W:
		if Gs.wall[i] == 1: continue
		nland += 1
		var a: bool = f0[i] > float(Gs.hm[i]) + 0.01; var b: bool = fb[i] > float(Gs.hm[i]) + 0.01
		if a: lake0 += 1
		if b: lakeB += 1
		if a and b: both += 1
		var dl := absf(f0[i] - fb[i]); dmax = maxf(dmax, dl)
		if dl > 0.5: big += 1
	out.B_cmp = {"land": nland, "lake_route": lake0, "lake_B": lakeB, "lake_both": both, "fill_dmax_cells": dmax, "fill_diff_gt_half_cell": big}
	# výkopy u vody: plný route (bez C) vs update (C) vs update + A
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.p58_seed)
	var cand := PackedInt32Array()
	for i in W * W:
		if Gs.wall[i] == 0 and not TOK._border(s0, i) and s0.eff[i] > 0.0: cand.append(i)
	var edits := []
	for k in int(p.p58_edits):
		var i := cand[rng.randi() % cand.size()]
		edits.append([i, float(s0.hm[i]) - float(p.p58_dig_m) / cm])
	var e0 := []; var e1 := []; var ef := []
	for ed in edits:
		var ch := PackedInt32Array([int(ed[0])]); var hv := PackedFloat64Array([float(ed[1])])
		TOK.FLOOD_DZ = 0.0
		var t := Time.get_ticks_usec(); TOK.update(s0, ch, hv, s0.src, int(q.tok_margin)); e0.append(M.ms(t))
		TOK.FLOOD_DZ = sdz
		t = Time.get_ticks_usec(); TOK.update(s1, ch, hv, s1.src, int(q.tok_margin)); e1.append(M.ms(t))
		TOK.FLOOD_DZ = 0.0
	# plný route po všech výkopech (cena přepočtu bez C) a shoda update s plným výpočtem
	var sr: Dictionary = mk.call()
	for ed in edits: sr.hm[int(ed[0])] = float(ed[1])
	var t3 := Time.get_ticks_usec(); TOK.route(sr); out.route_after_ms = M.ms(t3)
	var effd := 0.0; var filld := 0.0
	for i in W * W:
		effd = maxf(effd, absf(sr.eff[i] - s0.eff[i])); filld = maxf(filld, absf(sr.fill[i] - s0.fill[i]))
	out.C_vs_full = {"eff_max_lps": effd, "fill_max": filld}
	out.same_A_after_edits = s0.fill == s1.fill and s0.eff == s1.eff
	out.edit_C = _st(e0); out.edit_CA = _st(e1)
	out.peak_mb = M.mem().peak_mb
	FileAccess.open(ProjectSettings.globalize_path("res://shots/alg58/tok_s%d.json" % nv), FileAccess.WRITE).store_string(JSON.stringify(out))
	print("povrch %d²: route %.0f ms (A %.0f), flood %.0f ms (A %.0f), shoda A %s | B graf pánví %.0f ms (%d pánví, %d hran), jezera route %d / B %d / obojí %d, fill Δmax %.2f b., >0,5 b. %d | výkop update C %.1f ms (max %.1f), C+A %.1f (max %.1f), plný route %.0f ms; C vs plný: eff Δ %.6f, fill Δ %.4f; shoda A po výkopech %s | peak %.0f MB" % [
		W, tb, ta, out.flood_ms, out.flood_A_ms, str(out.same_A), rb.ms, rb.basins, rb.edges, lake0, lakeB, both, dmax, big,
		out.edit_C.avg, out.edit_C.max, out.edit_CA.avg, out.edit_CA.max, out.route_after_ms, effd, filld, str(out.same_A_after_edits), out.peak_mb])
	quit()

func _st(a: Array) -> Dictionary:
	var s := 0.0; var m := 0.0
	for x in a: s += x; m = maxf(m, x)
	return {"avg": s / maxf(a.size(), 1), "max": m, "all": a}
