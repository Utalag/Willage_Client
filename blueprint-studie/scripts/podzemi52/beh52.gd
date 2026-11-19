extends RefCounted
## E52 běh jedné varianty podzemí nad světem svet64 z cache (vlastní proces → vlastní peak paměti).
## Povrchová voda vždy na s64_voda_n (64/blok) jako E50; podzemí podle p52_var:
##   slovnik | pole: buňky po p52_ug_n na blok (≠ povrch → obal ug_mrizka), funkce: pásma na řídicí mřížce (+ dutiny z buněk p52_ug_n),
##   povrch: jen povrch (počet vodopádů, vodopad_dx_m). Měří: sestavení, řešení, celý běh, lokální změnu (výkop 1 m nad tělesem).

const C = preload("res://scripts/podzemi52/cache.gd")
const S = preload("res://scripts/podzemi52/ug_slovnik.gd")
const P = preload("res://scripts/podzemi52/ug_pole.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const MR = preload("res://scripts/podzemi52/ug_mrizka.gd")
const D3 = preload("res://scripts/podzemi52/ug_darcy3d.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const M = preload("res://scripts/svet64/mereni.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const TOK = preload("res://scripts/voda/tok.gd")

static func name_of(p: Dictionary) -> String:
	var v := String(p.p52_var); var nv := int(p.s64_voda_n)
	if v == "povrch": return "povrch_s%d_dx%s" % [nv, str(float(p.vodopad_dx_m))]
	if v == "funkce" and String(p.p52_rezim) == "auto": return "funkce_auto_s%d_dut%d_pd%s" % [nv, int(p.p52_ug_n), str(float(p.p55_perm_dno))]
	if v == "funkce": return "funkce_%s_s%d_dut%d%s" % [String(p.p52_rezim), nv, int(p.p52_ug_n), ("_k%s" % str(float(p.p52_darcy_k))) if String(p.p52_rezim) == "darcy" else ""]
	if v == "darcy3d": return "darcy3d_s%d_u%d_k%s" % [nv, int(p.p52_ug_n), str(float(p.p52_k0))]
	if v == "pole": return "pole_s%d_u%d_%s" % [nv, int(p.p52_ug_n), ("lim%s" % str(float(p.p52_hloubka_m))) if float(p.p52_hloubka_m) > 0.0 else "bez"]
	return "%s_s%d_u%d" % [v, nv, int(p.p52_ug_n)]

static func run_one(p: Dictionary) -> String:
	var mem0 := M.mem()
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	if d.is_empty(): return "chybí cache %s (./run.sh podzemi52 ji vytvoří)" % p.p52_cache
	var T: int = d.T; var n: int = d.n; var fine: Dictionary = d.blocks
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	var q := V.scaled(p, nv)
	var cm := 8.0 / nv
	var Gs := V.grid(fine, T, n, nv, false)
	var W: int = Gs.W
	var springs := PRM.find(Gs.hm, W, W, Gs.wall, Gs.mat_d, q)
	var src := PRM.src(springs, Gs.hm, W * W)
	var dd := int(round(float(q.strz_target_m) / float(q.voda_cell_m)))
	var mat_d: Callable = Gs.mat_d
	var mat_at := func(gi: int) -> int: return mat_d.call(gi, dd * 16 / nv)
	var mem_load := M.mem()
	var nm := name_of(p)
	var out := {"name": nm, "var": String(p.p52_var), "nv": nv, "nu": nu, "rezim": String(p.p52_rezim), "lim_m": float(p.p52_hloubka_m),
		"rss_load_mb": mem_load.rss_mb, "rss0_mb": mem0.rss_mb}
	var v := String(p.p52_var)
	if v == "povrch":
		var t0 := Time.get_ticks_usec()
		var h1: PackedFloat64Array = Gs.hm.duplicate()
		var r1 := SZ.run(h1, W, W, Gs.wall, mat_at, q, src)
		out.run_ms = M.ms(t0)
		var s1 := V.summary(r1, cm)
		out.falls = r1.falls.size(); out.falls_m = r1.falls.map(func(f): return float(f.drop_m))
		out.edge_q = s1.edge_q; out.wet = s1.wet; out.peak_mb = M.mem().peak_mb
		_save(out, nm)
		return "%s: vodopádů %d (spády %s m), okraj %.2f l/s, %.1f s" % [nm, out.falls, str(out.falls_m.map(func(x): return snappedf(x, 0.01))), s1.edge_q, out.run_ms / 1000.0]
	# --- podzemí
	var t_b := Time.get_ticks_usec()
	var ug: Dictionary
	var cm_u := 8.0 / nu
	if v == "funkce":
		var world = C.world_of(d)
		ug = F.from_world(world, fine, n, nu, p)
		ug.darcy_k = float(p.get("p52_darcy_k", 1e-4)); ug.darcy_dz = float(p.get("p52_darcy_dz", 0.5)); ug.darcy_it = int(p.p52_darcy_it)
		F.set_surface(ug, W, Gs.hm, Gs.wall, cm)
		cm_u = 0.0
	else:
		var Gu := V.grid(fine, T, n, nu, true)
		var qu := V.scaled(p, nu)
		var inner: Dictionary = (P if v == "pole" else (D3 if v == "darcy3d" else S)).make(Gu.W, Gu.W, Gu.NZ, Gu.mat3, Gu.top, Gu.wall, qu)
		ug = inner if nu == nv else MR.make(inner, W, Gs.hm, Gs.wall, nv / nu)
		Gu.clear()
	out.build_ms = M.ms(t_b)
	var mem_build := M.mem()
	var t_r := Time.get_ticks_usec()
	var h2: PackedFloat64Array = Gs.hm.duplicate()
	var r := SZ.run(h2, W, W, Gs.wall, mat_at, q, src, ug)
	out.run_ms = M.ms(t_r)
	out.solve_ms = float(ug.stats.solve_ms); out.solves = int(ug.stats.solves)
	if ug.stats.has("cg_it"): out.cg = {"ms": float(ug.stats.cg_ms), "it": ug.stats.cg_it, "unknowns": int(ug.stats.unknowns)}
	out.ug_ms = float(out.build_ms) + float(out.solve_ms)
	var mem_run := M.mem()
	var s2 := V.summary(r, cm)
	var st: Dictionary = r.st
	var bodies := []
	var qin := 0.0; var leak := 0.0; var oq := 0.0
	for b in st.get("ug_bodies", []):
		var zo: float = float(b.z_out) if cm_u == 0.0 else (float(b.z_out) + 0.5) * cm_u
		bodies.append({"cells": int(b.cells), "q_in": float(b.q_in), "leak": float(b.leak), "out_q": float(b.out_q), "closed": bool(b.closed),
			"typ": String(b.out[3]) if not b.out.is_empty() else "—", "z_m": zo, "vol_m3": float(b.volume_m3), "plni": not bool(b.never_fills),
			"darcy": b.get("darcy", {}), "darcy3d": b.get("darcy3d", {}), "rezim_tel": String(b.get("rezim_tel", "")),
			"dno": b.get("dno", {}), "out_col": int(b.out[4]) if not b.out.is_empty() else -1})
		qin += float(b.q_in); leak += float(b.leak); oq += float(b.out_q)
	out.bodies = bodies; out.q_in = qin; out.leak = leak; out.out_q = oq
	if v == "funkce" and String(p.p52_rezim) == "auto":   # E55: mapa pro snímek (řídicí mřížka + povrch)
		out.ctrl = {"W": int(ug.W), "H": int(ug.H), "side": float(ug.side), "h": Array(ug.h)}
		out.surf = {"W": W, "cm": cm}
	out.under_q = s2.under_q; out.under_n = s2.under_n; out.edge_q = s2.edge_q; out.lost = s2.lost; out.lost_deep = float(st.get("lost_deep", 0.0))
	out.springs_q = 0.0
	for sp in springs: out.springs_q += float(sp.q)
	out.falls = r.falls.size()
	out.rss_build_mb = mem_build.rss_mb; out.rss_run_mb = mem_run.rss_mb
	# --- lokální změna: výkop 1 m v suchém sloupci nad tělesem, nejblíž výtoku největší tůně s odtokem do podzemí
	var L: Dictionary = st.L
	var wetp := TOK.ponds(st, float(L.cell_m2), float(L.u_m), false).filter(func(x): return not x["suchá"] and x.outlet >= 0 and x.drain_lps > 0.0)
	wetp.sort_custom(func(a, b): return float(a.podzemi_lps) > float(b.podzemi_lps))
	var col := -1
	if not wetp.is_empty():
		var o: int = wetp[0].outlet
		for rad in range(1, 80):
			for dx in range(-rad, rad + 1):
				for dy in [-rad, rad]:
					for sw in 2:
						var x: int = o / W + (dx if sw == 0 else dy); var y: int = o % W + (dy if sw == 0 else dx)
						if col >= 0 or x < 0 or y < 0 or x >= W or y >= W: continue
						var c := x * W + y
						if Gs.wall[c] == 0 and st.pw[c] == 0 and st.eff[c] < float(L.thr) and ug.impl.entry(ug, c) >= 0: col = c
			if col >= 0: break
	out.local_col = [col / W, col % W] if col >= 0 else []
	if col >= 0:
		var ch := PackedInt32Array([col]); var hv := PackedFloat64Array([st.hm[col] - 1.0 / cm])
		var s0 := float(ug.stats.solve_ms); var n0 := int(ug.stats.solves)
		var t1 := Time.get_ticks_usec()
		var up := TOK.update(st, ch, hv, st.src, int(q.tok_margin))
		out.local_update_ms = M.ms(t1)
		t1 = Time.get_ticks_usec()
		TOK._apply_drains(st)   # suchý výkop: update nic nepočítá, podzemí se přepočte při dalším odtoku tůní
		out.local_drains_ms = M.ms(t1)
		out.local_ug_ms = float(ug.stats.solve_ms) - s0; out.local_solves = int(ug.stats.solves) - n0
	out.peak_mb = M.mem().peak_mb
	if v == "funkce":
		out.wt = Array(ug.wt); out.hc = Array(ug.h); out.Wc = int(ug.W); out.cav_cells = int(ug.stats.get("cav_cells", 0))
		out.n_bands = ug.lo.size()
		var thick := PackedFloat32Array(); thick.resize(ug.W * ug.H)
		for b in ug.lo.size():
			if ug.body[b] == 1: thick[ug.bcol[b]] += ug.hi[b] - ug.lo[b]
		out.perm_thick = Array(thick)
		# řez řádkem řídicí mřížky přes výtok největší tůně
		var row: int = (wetp[0].outlet / W) / int(ug.r) if not wetp.is_empty() else ug.W / 2
		var sec := []
		for y in ug.H:
			var cc: int = row * ug.H + y
			var bl := []
			for b in range(ug.cs[cc], ug.cs[cc + 1]): bl.append([ug.lo[b], ug.hi[b], int(ug.mat[b]), int(ug.body[b])])
			sec.append({"h": ug.h[cc], "wt": ug.wt[cc], "b": bl})
		out.sec_row = row; out.sec = sec
	_save(out, nm)
	return "%s: sestavení %.0f ms, řešení %.0f ms (%d×), běh %.1f s, peak %.0f MB (po načtení %.0f) | přítok %.2f, průsak %.2f, výtok %.2f l/s (%d), okraj %.2f, těles %d | lokální změna %s: update %.0f ms + odtoky %.0f ms, z toho podzemí %.0f ms (%d řešení)" % [
		nm, out.build_ms, out.solve_ms, out.solves, out.run_ms / 1000.0, out.peak_mb, mem_load.rss_mb, qin, leak, oq, s2.under_n, s2.edge_q, bodies.size(),
		str(out.local_col), float(out.get("local_update_ms", -1.0)), float(out.get("local_drains_ms", -1.0)), float(out.get("local_ug_ms", -1.0)), int(out.get("local_solves", 0))]

static func _save(out: Dictionary, nm: String) -> void:
	var dir := ProjectSettings.globalize_path("res://shots/podzemi52")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir + "/" + nm + ".json", FileAccess.WRITE).store_string(JSON.stringify(out))
