extends SceneTree
## KOPIE z blueprint-studie/tools/alg64_ug.gd (E66, tools/port_studie.py): změněné jen cesty.
## E64 podzemí: varianta (p58_var, např. A+B+C+D+K+I+R) nad záznamem E61 (shots/alg58/calls_s%d_u16_e61.json).
## Po každém výkopu (a u R po dokončení všech kroků) porovná s čerstvým plným výpočtem K (tol 0 + otisk) a volitelně
## (p64_oldref) se starým F.solve (tol p58_tol). Píše jen do shots/e64/.
const C = preload("res://scripts/voda/podzemi/cache.gd")
const F = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const U = preload("res://scripts/voda/podzemi/ug58.gd")
const U64 = preload("res://scripts/voda/podzemi/ug64.gd")
const SD = preload("res://scripts/voda/podzemi/sestup64.gd")
const V = preload("res://scripts/teren/svet64/voda64.gd")
const M = preload("res://scripts/teren/svet64/mereni.gd")
const PR = preload("res://scripts/teren/params.gd")

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var v := String(p.p58_var); var dz := float(p.p58_dz); var tol := float(p.p58_tol)
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n); var budget := int(p.p64_budget)
	var oldref := bool(p.p64_oldref)
	var js = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../blueprint-studie/shots/alg58/calls_s%d_u%d_e61.json" % [nv, nu])))
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var Gs := V.grid(d.blocks, d.T, d.n, nv, false)
	var ug := F.from_world(C.world_of(d), d.blocks, d.n, nu, p)
	F.set_surface(ug, Gs.W, Gs.hm, Gs.wall, 8.0 / nv)
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
	ug._useD = U.has_flag(v, "D")
	var Rold := U.clone(ug) if oldref else {}
	var Rk := U.clone(ug)   # čerstvý plný K (bez I, bez R)
	U64.setup(Rk, "K", 1 << 30); Rk._useD = false
	U64.setup(ug, v, budget)
	var cnt := {"S": 0, "seeds": 0, "pops": 0, "stale": 0, "chain": 0, "scan": 0, "inject": 0}
	var prof := {"sestup": 0.0, "pf": 0.0, "leak": 0.0, "result": 0.0}   # ms za všechny výkopy
	ug._k64c = cnt
	var m0 := M.mem()
	var st := {"builds": 0, "floods": 0, "results": 0, "fallback": 0, "exact": 0, "skipped": 0, "rebuilds": 0, "deltas": 0, "gone": 0, "reach": 0, "splits": 0}
	var t0 := Time.get_ticks_usec()
	var res := U.solve_all(ug, calls, v, dz, st)
	var full_ms := M.ms(t0)
	var full_pops := int(cnt.pops)
	var bad := []; var bad_old := []; var hk := {"ok": 0, "lazy": 0}
	var chk := func(tag: String) -> void:
		Rk.erase("_k64")
		for i in calls.size():
			U._p1key = i
			var rf := U.auto_X(Rk, calls[i].ents, calls[i].q, U.ex_of(Rk, calls[i].x), true, dz)
			var pre := String(res[i].get("rezim_tel", "")) == "preliv"
			var why := U.same(res[i], rf, 0.0 if pre else tol)
			if why == "" and pre and U64.digest_res(res[i]) != U64.digest_res(rf): why = "otisk výsledku"
			if pre and why == "" and ug._k64.has(i) and Rk._k64.has(i):
				var s1: Dictionary = ug._k64[i]
				if s1.dirty.is_empty():
					if SD.digest(s1) != SD.digest(Rk._k64[i]): why = "otisk sestupu %s ≠ %s" % [SD.digest(s1), SD.digest(Rk._k64[i])]
					else: hk.ok += 1
				else: hk.lazy += 1
			if why != "": bad.append("%s #%d: %s" % [tag, i, why])
			if oldref:
				var ro := F.solve(Rold, calls[i].ents, calls[i].q, calls[i].excl)
				var w2 := U.same(res[i], ro, tol)
				if w2 != "": bad_old.append("%s #%d: %s" % [tag, i, w2])
	chk.call("plné")
	for kk in cnt: cnt[kk] = 0
	var pe := []   # profil po výkopech
	var ems := []; var steps := []; var smax := []; var vis := []; var Ss := []
	var useR := bool(ug._useR64)
	var ei := 0
	for ed in js.edits:
		ei += 1
		var s := int(ed[0]); var hv := float(ed[1])
		var t1 := Time.get_ticks_usec()
		res = U64.edit(ug, calls, res, s, hv, v, dz, st)
		var sm := [M.ms(t1)]
		while useR and U64.pending(ug):
			var t2 := Time.get_ticks_usec()
			U64.step(ug, calls, res, budget)
			sm.append(M.ms(t2))
		var tot := 0.0; var mx := 0.0
		for x in sm: tot += x; mx = maxf(mx, x)
		ems.append(tot); steps.append(sm.size()); smax.append(mx)
		vis.append(int(cnt.pops) + int(cnt.chain)); Ss.append(int(cnt.S))
		var pr1 := {"X": int(ug.get("_x64", 0))}
		for kk in cnt:
			if String(kk).begins_with("t_"): pr1[String(kk).substr(2)] = cnt[kk] / 1000.0; prof[String(kk).substr(2)] = float(prof.get(String(kk).substr(2), 0.0)) + cnt[kk] / 1000.0
		pe.append(pr1)
		for kk in cnt: cnt[kk] = 0
		F.touched(Rk, {}, PackedInt32Array([s]), PackedFloat64Array([hv]))
		if oldref: F.touched(Rold, {}, PackedInt32Array([s]), PackedFloat64Array([hv]))
		chk.call("výkop %d" % ei)
	var m1 := M.mem()
	var kb := 0
	for k in ug._k64: kb += SD.state_bytes(ug._k64[k])
	if ug.has("_chain64"): kb += ug._chain64.size()
	var a := ems.duplicate(); a.sort()
	var avg := 0.0
	for x in ems: avg += x
	avg /= maxf(ems.size(), 1)
	var p95: float = a[int(ceil(0.95 * a.size())) - 1] if not a.is_empty() else 0.0
	var worst := ems.find(a[a.size() - 1]) + 1
	var out := {"var": v, "nv": nv, "budget": budget, "full_ms": full_ms, "full_pops": full_pops, "edit_ms": ems, "edit_avg": avg, "edit_p95": p95, "edit_max": a[a.size() - 1], "worst_edit": worst,
		"steps": steps, "step_max_ms": smax, "visited": vis, "S": Ss, "mismatch": bad.size(), "mismatch_list": bad.slice(0, 20), "mismatch_old": bad_old.size() if oldref else -1,
		"mismatch_old_list": bad_old.slice(0, 20), "hash_ok": hk.ok, "lazy": hk.lazy, "prof": prof, "prof_edit": pe, "state_mb": kb / 1048576.0, "peak_mb": m1.peak_mb, "rss_mb": m1.rss_mb, "rss0_mb": m0.rss_mb, "stats": st, "n_bands": ug.lo.size()}
	var fn := "ug_%s_s%d%s.json" % [v.replace("+", "p"), nv, String(p.p64_tag)]
	FileAccess.open(ProjectSettings.globalize_path("res://shots/66_parita/" + fn), FileAccess.WRITE).store_string(JSON.stringify(out))
	var vs := 0.0; for x in vis: vs += x
	var sm2 := 0.0; for x in smax: sm2 = maxf(sm2, x)
	var stm := 0; for x in steps: stm = maxi(stm, x)
	print("%s s%d b%d: plné %.0f ms (%d výběrů) | výkop průměr %.1f p95 %.1f max %.1f ms (výkop %d) | krok max %.1f ms, kroků max %d | navštíveno průměr %.0f | neshod K %d (otisk sestupu OK %d, líných %d) | neshod se starým %s | stav %.1f MB, peak %.0f MB" % [
		v, nv, budget, full_ms, full_pops, avg, p95, a[a.size() - 1], worst, sm2, stm, vs / maxf(vis.size(), 1), bad.size(), hk.ok, hk.lazy, str(out.mismatch_old), out.state_mb, m1.peak_mb])
	print("profil výkopů (ms celkem): ", prof, " S průměr ", Ss.reduce(func(x, y): return x + y, 0) / maxf(Ss.size(), 1))
	var wi: int = worst - 1
	print("nejhorší výkop %d: %.1f ms, S %d, %s" % [worst, ems[wi], Ss[wi], str(pe[wi])])
	if not bad.is_empty(): print(bad.slice(0, 5))
	if not bad_old.is_empty(): print("staré: ", bad_old.slice(0, 5))
	quit()
