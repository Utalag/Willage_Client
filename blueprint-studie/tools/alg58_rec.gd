extends SceneTree
## E58 krok 1: běh povrchu + podzemí (funkce, auto) jako E55, záznam volání podzemí a výběr výkopů → shots/alg58/calls_s%d_u%d.json
const C = preload("res://scripts/podzemi52/cache.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const REC = preload("res://scripts/alg58/rec58.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const PR = preload("res://scripts/bp/params.gd")

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var T: int = d.T; var n: int = d.n; var fine: Dictionary = d.blocks
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	var q := V.scaled(p, nv); var cm := 8.0 / nv
	var Gs := V.grid(fine, T, n, nv, false); var W: int = Gs.W
	var springs := PRM.find(Gs.hm, W, W, Gs.wall, Gs.mat_d, q)
	var src := PRM.src(springs, Gs.hm, W * W)
	var dd := int(round(float(q.strz_target_m) / float(q.voda_cell_m)))
	var mat_d: Callable = Gs.mat_d
	var mat_at := func(gi: int) -> int: return mat_d.call(gi, dd * 16 / nv)
	var ug := F.from_world(C.world_of(d), fine, n, nu, p)
	F.set_surface(ug, W, Gs.hm, Gs.wall, cm)
	ug.impl = REC; ug._rec = []
	var r := SZ.run(Gs.hm.duplicate(), W, W, Gs.wall, mat_at, q, src, ug)
	var st: Dictionary = r.st
	var seen := {}; var calls := []
	for k in ug._rec:
		var key := "%s|%.9f|%s" % [str(k.e), float(k.q), str(k.x)]
		if seen.has(key): continue
		seen[key] = true; calls.append(k)
	# výkopy: polovina u vstupů těles (± p58_near sloupců řídicí mřížky), polovina náhodně nad tělesy; suché sloupce
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.p58_seed)
	var K := int(p.p58_edits); var rr: int = ug.r
	var ent_cols := []
	for k in calls:
		for e in k.e: ent_cols.append(int(ug.bcol[e]))
	var edits := []; var used := {}
	var tries := 0
	while edits.size() < K and tries < 200000:
		tries += 1
		var s := -1
		if edits.size() % 2 == 0 and not ent_cols.is_empty():
			var cc: int = ent_cols[rng.randi() % ent_cols.size()]; var R := int(p.p58_near)
			var ux: int = cc / int(ug.W) + rng.randi_range(-R, R); var uy: int = cc % int(ug.W) + rng.randi_range(-R, R)
			if ux < 0 or uy < 0 or ux >= int(ug.W) or uy >= int(ug.W): continue
			s = (ux * rr + rng.randi() % rr) * W + uy * rr + rng.randi() % rr
		else: s = rng.randi() % (W * W)
		if used.has(s) or Gs.wall[s] == 1 or st.pw[s] == 1 or st.eff[s] >= float(st.L.thr) or F.entry(ug, s) < 0: continue
		var cc2 := F.col_of(ug, s)
		if used.has(-cc2 - 1): continue
		used[s] = true; used[-cc2 - 1] = true
		edits.append([s, float(Gs.hm[s]) - float(p.p58_dig_m) / cm])
	var out := {"nv": nv, "nu": nu, "W": W, "calls": calls, "edits": edits, "n_bands": ug.lo.size(), "n_comp": int(ug.n_comp), "run_ms": float(r.get("ms", 0.0))}
	var path := ProjectSettings.globalize_path("res://shots/alg58/calls_s%d_u%d%s.json" % [nv, nu, String(p.get("p58_tag", ""))])
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out))
	print("volání %d (unikátních), výkopů %d, pásem %d, těles %d → %s" % [ug._rec.size(), edits.size(), ug.lo.size(), int(ug.n_comp), path])
	quit()
