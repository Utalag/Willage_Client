extends SceneTree
## E60 povrch: profil fází tok.update (C+A) a optimalizovaná kopie tok60.update; shoda bit po bitu s tok.update.
const C = preload("res://scripts/podzemi52/cache.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const P = preload("res://scripts/alg60/tok60p.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const M = preload("res://scripts/svet64/mereni.gd")
const PR = preload("res://scripts/bp/params.gd")

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var nv := int(p.s64_voda_n); var sdz := float(p.get("p58_sdz", 1.0)); var mode := String(p.get("p60_mode", "prof"))
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
	TOK.FLOOD_DZ = sdz
	var s0 := TOK.make(Gs.hm.duplicate(), W, W, Gs.wall, mats, src.duplicate(), L, true); TOK.route(s0)
	var s1 := TOK.make(Gs.hm.duplicate(), W, W, Gs.wall, mats, src.duplicate(), L, true); TOK.route(s1)
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.p58_seed)
	var cand := PackedInt32Array()
	for i in W * W:
		if Gs.wall[i] == 0 and not TOK._border(s0, i) and s0.eff[i] > 0.0: cand.append(i)
	var edits := []
	for k in int(p.p58_edits):
		var i := cand[rng.randi() % cand.size()]
		edits.append([i, float(s0.hm[i]) - float(p.p58_dig_m) / cm])
	var ph := {}; var e0 := []; var e1 := []; var bad := 0; var info := []
	var impl = P if mode == "prof" else load("res://scripts/alg60/tok60.gd")
	if mode != "prof": impl.M0 = int(p.get("p60_m0", 0)); impl.FAST_FLOOD = bool(p.get("p60_ff", true))
	for ed in edits:
		var ch := PackedInt32Array([int(ed[0])]); var hv := PackedFloat64Array([float(ed[1])])
		var t := Time.get_ticks_usec(); var r0 := TOK.update(s0, ch, hv, s0.src, int(q.tok_margin)); e0.append(M.ms(t))
		t = Time.get_ticks_usec(); var r1: Dictionary = impl.update_prof(s1, ch, hv, s1.src, int(q.tok_margin)) if mode == "prof" else impl.update(s1, ch, hv, s1.src, int(q.tok_margin)); e1.append(M.ms(t))
		info.append([r0.window, r0.touched, r0.expanded])
		if not r1.dry:
			var pr: Dictionary = impl.PR
			var ks := ["t0", "okno0", "flood", "d8_okno", "po_proudu", "odtoky", "tune"]
			for k in range(1, ks.size()):
				ph[ks[k]] = float(ph.get(ks[k], 0.0)) + (float(pr[ks[k]]) - float(pr[ks[k - 1]])) / 1000.0
		for key in ["fill", "eff", "to", "ain", "pw", "extra", "src2", "sink"]:
			if s0[key] != s1[key]: bad += 1; if bad < 12: print("neshoda ", key)
		var k0: Array = s0._pd.keys(); k0.sort(); var k1: Array = s1._pd.keys(); k1.sort()
		if k0 != k1: bad += 1; print("neshoda tůně (klíče)")
		else:
			for kp in k0:
				var a: Dictionary = s0._pd[kp]; var b: Dictionary = s1._pd[kp]
				if str(a) != str(b): bad += 1; print("neshoda tůně ", kp); break
		if str(s0.get("under", [])) != str(s1.get("under", [])): bad += 1; print("neshoda under")
	for k in ph: ph[k] = ph[k] / edits.size()
	if mode != "prof": ph["z toho tůně+filtr"] = float(impl.PR.get("pc", 0.0)) / edits.size(); ph["mokrých tůní"] = impl.PR.get("np", 0); ph["tůní"] = s1._pd.size()
	# obě varianty proti plnému route po všech výkopech (pravda bez okna)
	var sr := TOK.make(Gs.hm.duplicate(), W, W, Gs.wall, mats, src.duplicate(), L, true)
	for ed in edits: sr.hm[int(ed[0])] = float(ed[1])
	TOK.route(sr)
	var cmp := {}
	for nm in ["ref", "new"]:
		var ss: Dictionary = s0 if nm == "ref" else s1
		var fd := 0.0; var ed2 := 0.0; var nf := 0; var ne := 0
		for i in W * W:
			var a := absf(ss.fill[i] - sr.fill[i]); var b := absf(ss.eff[i] - sr.eff[i])
			fd = maxf(fd, a); ed2 = maxf(ed2, b)
			if a > 1e-9: nf += 1
			if b > 1e-9: ne += 1
		cmp[nm] = {"fill_max": fd, "eff_max_lps": ed2, "fill_cells": nf, "eff_cells": ne}
	var dnew := 0.0; var dn := 0
	for i in W * W:
		var a := absf(s0.fill[i] - s1.fill[i]); dnew = maxf(dnew, a)
		if a > 1e-9 or absf(s0.eff[i] - s1.eff[i]) > 1e-9: dn += 1
	cmp["ref_vs_new"] = {"fill_max": dnew, "cells": dn}
	print("proti plnému route: ", cmp)
	var a0 := 0.0; var a1 := 0.0; var m0 := 0.0; var m1 := 0.0
	for x in e0: a0 += x; m0 = maxf(m0, x)
	for x in e1: a1 += x; m1 = maxf(m1, x)
	a0 /= edits.size(); a1 /= edits.size()
	var out := {"m0": int(p.get("p60_m0", 0)), "ff": bool(p.get("p60_ff", true)), "nv": nv, "W": W, "mode": mode, "ref_avg": a0, "ref_max": m0, "new_avg": a1, "new_max": m1, "phases": ph, "mismatch": bad, "vs_full": cmp, "info": info, "ref_all": e0, "new_all": e1}
	FileAccess.open(ProjectSettings.globalize_path("res://shots/alg60/tok_%s_s%d_m%d%s.json" % [mode, nv, int(p.get("p60_m0", 0)), "_ff" if bool(p.get("p60_ff", true)) else ""]), FileAccess.WRITE).store_string(JSON.stringify(out))
	print("m0 %d ff %s | %d² %s: tok.update %.1f ms (max %.1f) | kopie %.1f ms (max %.1f) | neshod %d | fáze %s | okno/dotčeno/zvětšení %s" % [int(p.get("p60_m0", 0)), str(p.get("p60_ff", true)), W, mode, a0, m0, a1, m1, bad, str(ph), str(info.slice(0, 6))])
	quit()
