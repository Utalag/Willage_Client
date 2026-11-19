extends SceneTree
## E58 podzemí: jedna varianta (p58_var) v jednom procesu. Vstup shots/alg58/calls_s%d_u%d.json (tools/alg58_rec.gd).
## Měří plné řešení všech volání, výkopy (p58_edits), shodu s čerstvým plným řešením po každém výkopu, paměť.
const C = preload("res://scripts/podzemi52/cache.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const U = preload("res://scripts/alg58/ug58.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const M = preload("res://scripts/svet64/mereni.gd")
const PR = preload("res://scripts/bp/params.gd")

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var v := String(p.p58_var); var dz := float(p.p58_dz); var tol := float(p.p58_tol)
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	var js = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://shots/alg58/calls_s%d_u%d%s.json" % [nv, nu, String(p.get("p58_tag", ""))])))
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var T: int = d.T; var n: int = d.n
	var Gs := V.grid(d.blocks, T, n, nv, false); var W: int = Gs.W; var cm := 8.0 / nv
	var t_b := Time.get_ticks_usec()
	var ug := F.from_world(C.world_of(d), d.blocks, n, nu, p)
	F.set_surface(ug, W, Gs.hm, Gs.wall, cm)
	var build_ms := M.ms(t_b)
	d.clear()
	var calls := []
	for k in js.calls:
		var ents := PackedInt32Array(); for e in k.e: ents.append(int(e))
		var excl := {}; for s in k.x: excl[int(s)] = true
		calls.append({"ents": ents, "q": float(k.q), "excl": excl, "x": k.x, "ex": U.ex_of(ug, k.x), "final": bool(k.get("final", true))})
	ug._bfs_max = int(p.get("p58_bfs_max", 20000))
	var ents_all := {}
	for k in js.calls:
		for e in k.e: ents_all[int(e)] = true
	ug._ents = ents_all
	ug._useD = U.has_flag(v, "D")   # E62
	ug._useE = U.has_flag(v, "E"); ug._useI = U.has_flag(v, "I")   # E63
	var R := U.clone(ug)
	var m0 := M.mem()
	var st := {"builds": 0, "floods": 0, "results": 0, "fallback": 0, "exact": 0, "skipped": 0, "rebuilds": 0, "deltas": 0, "gone": 0, "reach": 0, "splits": 0}
	var t0 := Time.get_ticks_usec()
	var res := U.solve_all(ug, calls, v, dz, st)
	var full_ms := M.ms(t0)
	var ref := []
	for k in calls: ref.append(F.solve(R, k.ents, k.q, k.excl))
	var bad := []
	for i in calls.size():
		var why := U.same(res[i], ref[i], tol)
		if why != "": bad.append("plné #%d: %s" % [i, why])
	var tot0 := _tot(res, calls)
	var ems := []; var ehit := 0
	for ed in js.edits:
		var s := int(ed[0]); var hv := float(ed[1])
		var t1 := Time.get_ticks_usec()
		res = U.edit(ug, calls, res, s, hv, v, dz, st)
		ems.append(M.ms(t1))
		if F.touched(R, {}, PackedInt32Array([s]), PackedFloat64Array([hv])): ehit += 1
		ref = []
		for k in calls: ref.append(F.solve(R, k.ents, k.q, k.excl))
		for i in calls.size():
			var why := U.same(res[i], ref[i], tol)
			if why != "": bad.append("výkop %d #%d: %s" % [ems.size(), i, why])
			if why.begins_with("cells") and bool(p.get("p58_debug", false)) and ug.has("_nid"):
				var nd: Dictionary = ug._nodes[ug._nid[calls[i].ents[0]]]
				var A := {}; for b in nd.bands: A[b] = true
				var Bs := {}; for b in ref[i].comp_ids: Bs[b] = true
				for b in A: if not Bs.has(b): print("navíc v uzlu ", b, " col ", ug.bcol[b], " lo ", ug.lo[b], " hi ", ug.hi[b], " body ", ug.body[b])
				for b in Bs: if not A.has(b): print("chybí v uzlu ", b, " col ", ug.bcol[b], " lo ", ug.lo[b], " hi ", ug.hi[b], " body ", ug.body[b], " nid ", ug._nid[b], " edit col ", F.col_of(ug, s))
				quit(); return
	var tot1 := _tot(res, calls); var tr := _tot(ref, calls)
	var m1 := M.mem()
	var extra := 0
	if ug.has("_nid"):
		extra += ug.lo.size() * (4 + 24)
		for nd in ug._nodes: extra += nd.cz.size() * (8 + 4 * 4) + nd.sorted.size() * 8 + nd.bands.size() * 4
	if ug.has("_capg"): extra += ug.lo.size() * 16
	for r in res: if r.has("_fp"): extra += r._fp.size()
	if ug.has("_p1st"):   # E63 I
		for kst in ug._p1st:
			var s1: Dictionary = ug._p1st[kst]
			extra += s1.capv.size() * 8 + s1.rch.size() + s1.par.size() * 4 + s1.cl.size() * 4
	var em := 0.0; var ex := 0.0
	for x in ems: em += x; ex = maxf(ex, x)
	em /= maxf(ems.size(), 1)
	var out := {"var": v, "nv": nv, "nu": nu, "build_ms": build_ms, "full_ms": full_ms, "edit_ms": ems, "edit_avg": em, "edit_max": ex, "edits_hit_ref": ehit,
		"mismatch": bad.size(), "mismatch_list": bad.slice(0, 20), "stats": st, "extra_mb": extra / 1048576.0, "peak_mb": m1.peak_mb, "rss_before_mb": m0.rss_mb,
		"tot0": tot0, "tot1": tot1, "tot_ref": tr, "world": js.get("world", {}), "calls": calls.size(), "n_bands": ug.lo.size()}
	var fn := "ug_%s_s%d_u%d%s.json" % [v.replace("+", "p"), nv, nu, String(p.get("p58_tag", ""))]
	FileAccess.open(ProjectSettings.globalize_path("res://shots/alg58/" + fn), FileAccess.WRITE).store_string(JSON.stringify(out))
	print("%s s%d u%d: plné %.0f ms | výkop průměr %.1f ms, max %.1f ms (%d výkopů, zásah %d) | neshod %d | navíc %.1f MB, peak %.0f MB | průsak %.3f výtok %.3f l/s (ref %.3f / %.3f) | %s %s" % [
		v, nv, nu, full_ms, em, ex, ems.size(), ehit, bad.size(), extra / 1048576.0, m1.peak_mb, tot1.leak, tot1.out, tr.leak, tr.out, str(st), str(bad.slice(0, 3))])
	if ug.has("_p1st"):   # E63 I: velikost uložených stavů sestupu
		var by := 0
		for kst in ug._p1st:
			var stt: Dictionary = ug._p1st[kst]
			by += stt.capv.size() * 8 + stt.rch.size() + stt.par.size() * 4 + stt.cl.size() * 4
		U.PROF.p1_mb = by / 1048576.0; U.PROF.bands = ug.lo.size()
	if not U.PROF.is_empty(): print("E63 profil prelivu: ", U.PROF)
	quit()

func _tot(res: Array, calls: Array) -> Dictionary:
	var l := 0.0; var o := 0.0
	for i in calls.size():
		if float(calls[i].q) > 0.0: l += float(res[i].leak); o += float(res[i].out_q)
	var lf := 0.0; var of := 0.0   # E60: jen poslední kolo (tělesa světa), dřív se sčítala všechna kola
	for i in calls.size():
		if float(calls[i].q) > 0.0 and calls[i].final: lf += float(res[i].leak); of += float(res[i].out_q) if not res[i].closed else 0.0
	return {"leak_all_calls": l, "out_all_calls": o, "leak": lf, "out": of}
