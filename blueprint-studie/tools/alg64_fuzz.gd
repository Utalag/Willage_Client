extends SceneTree
## E64 F + M: (1) náhodné pořadí stejného vstupu (permutace sousedů v CSR a pořadí vstupů) → stejný otisk sestupu K;
## totéž pro E63 E (_p1_fast) ukazuje závislost na pořadí. (2) dva / tři hráči: výkopy u sebe v různém pořadí,
## prokládané nedokončenými kroky R; po každém dokončení otisk = čerstvý plný výpočet, na konci stejný pro všechna pořadí.
## Píše jen shots/e64/fuzz_s%d.json.
const C = preload("res://scripts/podzemi52/cache.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const U = preload("res://scripts/alg58/ug58.gd")
const U64 = preload("res://scripts/alg64/ug64.gd")
const SD = preload("res://scripts/alg64/sestup64.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PR = preload("res://scripts/bp/params.gd")

var p: Dictionary; var d: Dictionary; var Gs: Dictionary; var js; var dz := 0.0625; var cm := 1.0

func build(v: String, budget: int) -> Dictionary:
	var ug := F.from_world(C.world_of(d), d.blocks, d.n, int(p.p52_ug_n), p)
	F.set_surface(ug, Gs.W, Gs.hm, Gs.wall, cm)
	ug._bfs_max = int(p.p58_bfs_max)
	var ea := {}
	for k in js.calls:
		for e in k.e: ea[int(e)] = true
	ug._ents = ea; ug._useD = U.has_flag(v, "D")
	U64.setup(ug, v, budget)
	return ug

func calls_of(ug: Dictionary) -> Array:
	var calls := []
	for k in js.calls:
		var ents := PackedInt32Array(); for e in k.e: ents.append(int(e))
		var excl := {}; for s in k.x: excl[int(s)] = true
		calls.append({"ents": ents, "q": float(k.q), "excl": excl, "x": k.x, "ex": U.ex_of(ug, k.x), "final": bool(k.get("final", true))})
	return calls

## otisky: na volání [výsledek, stav sestupu nebo "" (líný / jiný režim)]
func parts(ug: Dictionary, res: Array) -> Array:
	var o := []
	for i in res.size():
		var sd := ""
		if ug.has("_k64") and ug._k64.has(i) and String(res[i].get("rezim_tel", "")) == "preliv":
			var st: Dictionary = ug._k64[i]
			sd = SD.digest(st) if st.dirty.is_empty() else ""
		o.append([U64.digest_res(res[i]), sd])
	return o

## shoda s čerstvým: výsledky vždy, stav sestupu tam, kde je čistý
func match(a: Array, f: Array) -> bool:
	for i in a.size():
		if a[i][0] != f[i][0]: return false
		if a[i][1] != "" and a[i][1] != f[i][1]: return false
	return true

func short(a: Array) -> String:
	var s := ""
	for x in a: s += x[0] + "/" + (x[1] if x[1] != "" else "líný") + ";"
	return s.sha256_text().substr(0, 12)

## čerstvý plný K na nové kopii se všemi dosud provedenými výkopy
func fresh(digs: Array) -> Array:
	var rk := build("K", 1 << 30); rk._useD = false
	var calls := calls_of(rk)
	for dg in digs: F.touched(rk, {}, PackedInt32Array([dg[0]]), PackedFloat64Array([dg[1]]))
	var res := []
	for i in calls.size():
		U._p1key = i
		res.append(U.auto_X(rk, calls[i].ents, calls[i].q, U.ex_of(rk, calls[i].x), true, dz))
	return parts(rk, res)

func _init() -> void:
	p = PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	js = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://shots/alg58/calls_s%d_u%d_e61.json" % [nv, nu])))
	d = C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	Gs = V.grid(d.blocks, d.T, d.n, nv, false); cm = 8.0 / nv
	var out := {"nv": nv}
	# ---------- (1) permutace pořadí ----------
	var ug := build("A+B+C+D+K", 1 << 30)
	var calls := calls_of(ug)
	var rng := RandomNumberGenerator.new(); rng.seed = 64
	var nb0: PackedInt32Array = ug.nb.duplicate()
	var dk := []; var de := []
	for t in 6:
		var nb := nb0.duplicate()
		if t > 0:
			var ns: PackedInt32Array = ug.ns
			for b in ug.lo.size():
				var a := ns[b]; var z := ns[b + 1]
				for i in range(z - 1, a, -1):
					var j := a + rng.randi() % (i - a + 1)
					var tmp := nb[i]; nb[i] = nb[j]; nb[j] = tmp
		ug.nb = nb
		var hk := ""; var he := ""
		for ci in calls.size():
			var ents: PackedInt32Array = calls[ci].ents.duplicate()
			if t > 0:
				var ea := Array(ents); ea.shuffle(); ents = PackedInt32Array(ea)
			var st := SD.new_state(ug, ents)
			var j = SD.new(); j.setup_full(ug, st, false); j.run(1 << 30)
			hk += SD.digest(st)
			# E63 E: stejný vstup, stejné pořadí jako v ug58
			ug.gen = int(ug.gen) + 1; var g: int = ug.gen
			U._arr(ug)
			var cl: PackedInt32Array = U._p1_fast(ug, ents, g)
			var cv := PackedFloat64Array(); cv.resize(ug.lo.size()); cv.fill(-INF)
			for b in cl: cv[b] = ug._capv[b]
			he += cv.to_byte_array().hex_encode().sha256_text().substr(0, 16)
		dk.append(hk.sha256_text().substr(0, 16)); de.append(he.sha256_text().substr(0, 16))
	ug.nb = nb0
	var kdist := {}; for x in dk: kdist[x] = true
	var edist := {}; for x in de: edist[x] = true
	out.perm = {"K": dk, "E": de, "K_ruznych": kdist.size(), "E_ruznych": edist.size()}
	print("permutace (6 pořadí): K %d různých otisků %s | E %d různých %s" % [kdist.size(), str(dk), edist.size(), str(de)])
	# ---------- (2) dva / tři hráči ----------
	var e0: Array = js.edits[int(p.get("p64_fuzz_edit", 14))]
	var s0 := int(e0[0]); var W: int = Gs.W
	var c0 := build("A+B+C+D+K", 1 << 30)
	var rr: int = c0.r; var Ws: int = c0.Ws
	var cc0 := F.col_of(c0, s0); var ux := cc0 / int(c0.W); var uy := cc0 % int(c0.W)
	var digs := [[s0, float(e0[1])]]
	for dd in [[1, 0], [0, 1]]:
		var s1: int = ((ux + int(dd[0])) * rr) * Ws + (uy + int(dd[1])) * rr
		digs.append([s1, float(Gs.hm[s1]) - float(p.p58_dig_m) / cm])
	print("výkopy: ", digs, " sloupce ", [cc0, F.col_of(c0, digs[1][0]), F.col_of(c0, digs[2][0])])
	var ref2 := fresh(digs.slice(0, 2)); var ref3 := fresh(digs)
	var refa := fresh([digs[0]]); var refb := fresh([digs[1]])
	var budget := int(p.p64_budget)
	# scénář: posloupnost akcí ["d", i] výkop i, ["s", n] n kroků R, ["f"] dokončit
	var scen := {
		"a,b sync": ["Kd", ["d", 0], ["d", 1]],
		"b,a sync": ["Kd", ["d", 1], ["d", 0]],
		"a,1 krok,b R": ["R", ["d", 0], ["s", 1], ["d", 1], ["f"]],
		"b,a hned R": ["R", ["d", 1], ["d", 0], ["f"]],
		"a dokončit,b R": ["R", ["d", 0], ["f"], ["d", 1], ["f"]],
		"a,b,3 kroky,c R": ["R", ["d", 0], ["d", 1], ["s", 3], ["d", 2], ["f"]],
		"c,a,1 krok,b R": ["R", ["d", 2], ["d", 0], ["s", 1], ["d", 1], ["f"]],
		"b,c,a sync": ["Kd", ["d", 1], ["d", 2], ["d", 0]],
	}
	var rows := {}
	for nm in scen:
		var sc: Array = scen[nm]
		var v := "A+B+C+D+K+I+P" + ("+R" if sc[0] == "R" else "")
		var ug2 := build(v, budget)
		var calls2 := calls_of(ug2)
		var st := {"builds": 0, "floods": 0, "results": 0, "fallback": 0, "exact": 0, "skipped": 0, "rebuilds": 0, "deltas": 0, "gone": 0, "reach": 0, "splits": 0}
		var res := U.solve_all(ug2, calls2, v, dz, st)
		var done := []; var checks := []; var nsteps := 0
		for act in sc.slice(1):
			if act[0] == "d":
				res = U64.edit(ug2, calls2, res, int(digs[act[1]][0]), float(digs[act[1]][1]), v, dz, st); done.append(act[1])
			elif act[0] == "s":
				for t in int(act[1]): U64.step(ug2, calls2, res, budget); nsteps += 1
			else:
				while U64.pending(ug2): U64.step(ug2, calls2, res, budget); nsteps += 1
			if not U64.pending(ug2):
				var h := parts(ug2, res)
				var srt := done.duplicate(); srt.sort()
				var want = null
				if srt == [0]: want = refa
				elif srt == [1]: want = refb
				elif srt == [0, 1]: want = ref2
				elif srt == [0, 1, 2]: want = ref3
				checks.append([str(done), short(h), match(h, want) if want != null else null])
		var fin: String = checks[checks.size() - 1][1]
		rows[nm] = {"checks": checks, "final": fin, "steps": nsteps}
		var nl := 0
		for x in parts(ug2, res): if x[1] == "": nl += 1
		rows[nm].lazy = nl
		print("%-18s kroků R %3d | líných stavů na konci %d | kontroly [hotové výkopy, otisk výsledků+stavů, shoda s čerstvým] %s" % [nm, nsteps, nl, str(checks)])
	out.digs = digs; out.scen = rows; out.ref = {"a": short(refa), "b": short(refb), "ab": short(ref2), "abc": short(ref3)}
	print("čerstvé: ", out.ref)
	FileAccess.open(ProjectSettings.globalize_path("res://shots/e64/fuzz_s%d.json" % nv), FileAccess.WRITE).store_string(JSON.stringify(out))
	quit()
