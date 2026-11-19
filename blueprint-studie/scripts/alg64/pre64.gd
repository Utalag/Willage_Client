extends RefCounted
## E64: preliv jako úloha po krocích. Fáze: sestup (sestup64, K / K+I / +V) → priority-flood z pool (stejně jako
## ug58.preliv_A: BQ, _outs, _nbrs) → průsak → souhrn. run(budget) = nejvýš budget operací (pásmo / položka fronty).
## Bez R se úloha doběhne hned (sync). S R (ug64) se výsledek zveřejní až po dokončení; do té doby platí starý.
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const BQ = preload("res://scripts/alg58/bq58.gd")
const SD = preload("res://scripts/alg64/sestup64.gd")

var c: Dictionary
var key := 0
var entries: PackedInt32Array
var q := 0.0
var ex: Dictionary
var g := 0
var dz := 0.0625
var use_i := false
var use_v := false
var use_p := false
var st: Dictionary
var ds = null
var phase := 0   # 0 sestup, 1 start PF, 2 PF, 3 průsak, 4 souhrn, 5 hotovo
var bq = null
var outs := []
var comp := PackedInt32Array()
var done := {}
var best := []
var L := -INF
var n_pop := 0
var kk := 0
var leak := 0.0
var result = null
var ph = null       # zástupný (starý) výsledek, který se zveřejnil místo rozpracovaného
var ops_total := 0
var steps := 0

static func make(c_: Dictionary, entries_: PackedInt32Array, q_: float, ex_: Dictionary, g_: int, dz_: float, key_: int) -> RefCounted:
	var j = load("res://scripts/alg64/pre64.gd").new()
	j.c = c_; j.entries = entries_; j.q = q_; j.ex = ex_; j.g = g_; j.dz = dz_; j.key = key_
	j.use_i = bool(c_.get("_useI64", false)); j.use_v = bool(c_.get("_useV64", false)); j.use_p = bool(c_.get("_useP64", false))
	j._start_descent()
	return j

func _start_descent() -> void:
	if not c.has("_k64"): c._k64 = {}
	var sts: Dictionary = c._k64
	var s0 = sts.get(key)
	ds = SD.new()
	if not use_i or s0 == null or s0.ents != entries:
		st = SD.new_state(c, entries); sts[key] = st
		ds.setup_full(c, st, use_v)
	else:
		st = s0
		var cols: Array = st.dirty.keys(); st.dirty = {}
		if cols.is_empty(): ds.c = c; ds.st = st; ds.phase = 5
		else: ds.setup_repair(c, st, cols, use_v)
	phase = 0

## nová špinavá pásma během rozpracované úlohy
func absorb_dirty() -> bool:
	if st.dirty.is_empty(): return false
	var cols: Array = st.dirty.keys(); st.dirty = {}
	if not use_i:   # bez I: plný sestup znovu
		st = SD.new_state(c, entries); c._k64[key] = st
		ds = SD.new(); ds.setup_full(c, st, use_v)
	elif ds.phase < 5: ds.inject(cols)
	else:
		ds = SD.new(); ds.setup_repair(c, st, cols, use_v)
	phase = 0; result = null
	return true

func run(budget: int) -> int:
	_ops = 0
	var ops := 0
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi
	while phase < 5 and ops < budget:
		var _t0 := Time.get_ticks_usec(); var _ph := phase
		_run_phase(budget, lo, hi)
		ops = _ops
		if c.has("_k64c"):   # jen měření
			var nm: String = ["t_sestup", "t_pf", "t_pf", "t_leak", "t_result"][_ph]
			c._k64c[nm] = int(c._k64c.get(nm, 0)) + (Time.get_ticks_usec() - _t0)
	ops_total += ops; steps += 1
	return ops

var _ops := 0
func _run_phase(budget: int, lo: PackedFloat64Array, hi: PackedFloat64Array) -> void:
	var ops := _ops
	if true:
		if phase == 0:
			ops += ds.run(budget - ops)
			if ds.phase >= 5: phase = 1
		elif phase == 1:
			var pool: int = st.pool
			if use_p and st.has("pf") and int(st.pf.pool) == pool and pool >= 0 and not _pf_hit():
				result = st.pf.r.duplicate(); var vis0: PackedInt32Array = st.cl.duplicate(); vis0.append_array(result.comp_ids); result._vis = vis0
				st.pfd = {}; st.pfc = {}; phase = 5; ops += 1
				_mark_comp(result.comp_ids)
				if c.has("_k64c"): c._k64c.pf_cache = int(c._k64c.get("pf_cache", 0)) + 1
				_ops = ops; return
			comp = PackedInt32Array(); done = {}; best = []; L = -INF; n_pop = 0; outs = []; leak = 0.0; kk = 0
			if pool < 0:
				result = F._result(c, PackedInt32Array(), 0.0, [], q, 0.0, entries, true); result._vis = st.cl.duplicate()
				_mark_comp(PackedInt32Array())
				phase = 5; _ops = ops; return
			bq = BQ.new(dz, lo[pool]); bq.push(lo[pool], pool)
			phase = 2; ops += 1
		elif phase == 2:   # priority-flood jako ug58.preliv_A
			while not bq.empty() and ops < budget:
				var it: Array = bq.pop(); ops += 1
				var kv: float = it[0]; var id: int = it[1]
				if id < 0:
					var o: Array = outs[-id - 1]
					best = [kv, n_pop, o[3], o[1], o[2]]; L = kv
					phase = 3; break
				if done.has(id): continue
				done[id] = true; comp.append(id); c.lab[id] = g; n_pop += 1
				L = maxf(L, hi[id])
				for o in F._outs(c, id, ex):
					outs.append([o[0], o[1], o[2], id])
					bq.push(maxf(kv, float(o[0])), -outs.size())
				for nb in F._nbrs(c, id):
					if not done.has(int(nb[0])): bq.push(maxf(kv, float(nb[1])), int(nb[0]))
			if phase == 2 and bq.empty(): phase = 3
		elif phase == 3:
			while kk < comp.size() and ops < budget:
				leak += F._leak(c, comp[kk], L); kk += 1; ops += 1
			if kk >= comp.size(): phase = 4
		elif phase == 4:
			var closed := best.is_empty()
			result = F._result(c, comp, L, best, q, leak, entries, closed)
			var vis: PackedInt32Array = st.cl.duplicate(); vis.append_array(comp); result._vis = vis
			ops += comp.size(); phase = 5
			_mark_comp(comp)
			if use_p: _pf_store()
	_ops = ops

## vb: stará tůň → 1/0 podle dosažení, nová tůň → 2 (jako ug58._vis_bands, ale bez průchodu všemi pásmy)
func _mark_comp(nc: PackedInt32Array) -> void:
	var vb: PackedByteArray = st.vb; var capv: PackedFloat64Array = st.capv
	for b in st.comp: vb[b] = 1 if capv[b] > -INF else 0
	for b in nc: vb[b] = 2
	st.comp = nc

## záznam pro cache uzlu B (ug58.node_solve): vb ze stavu místo průchodu _vis (fp se s D nepoužije)
static func cache_entry(c: Dictionary, r: Dictionary, ents: PackedInt32Array, key: int) -> Dictionary:
	var st = c._k64.get(key) if c.has("_k64") else null
	if st == null or not bool(c.get("_useD", false)):
		return {"r": r, "fp": load("res://scripts/alg58/ug58.gd").footprint(c, [r._vis]), "vb": PackedByteArray(), "ents": ents}
	return {"r": r, "fp": PackedByteArray(), "vb": st.vb, "ents": ents}

## P: co priority-flood četl: sloupce pásem tůně + 4 sousedé (_outs čte h, _leak sousední pásma), sloupec výstupu,
## sousedé pásem tůně v CSR (klíče položek fronty, které se nevybraly)
func _pf_store() -> void:
	var W: int = c.W; var H: int = c.H
	var cols := PackedByteArray(); cols.resize(W * H)
	var nbr := {}
	var bcol: PackedInt32Array = c.bcol; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb
	for b in comp:
		var cc: int = bcol[b]; var x := cc / H; var y := cc % H
		cols[cc] = 1
		if x > 0: cols[cc - H] = 1
		if x < W - 1: cols[cc + H] = 1
		if y > 0: cols[cc - 1] = 1
		if y < H - 1: cols[cc + 1] = 1
		for j in range(ns[b], ns[b + 1]): nbr[nb[j]] = true
	if not best.is_empty(): cols[int(best[4])] = 1
	var r0: Dictionary = result.duplicate(); r0.erase("_vis")
	st.pf = {"pool": st.pool, "r": r0, "cols": cols, "nbr": nbr}
	st.pfd = {}; st.pfc = {}

func _pf_hit() -> bool:
	var cols: PackedByteArray = st.pf.cols; var nbr: Dictionary = st.pf.nbr; var bcol: PackedInt32Array = c.bcol
	for cc in st.pfc: if cols[cc] != 0: return true
	for b in st.pfd:
		if cols[bcol[b]] != 0 or nbr.has(b): return true
	return false

## synchronní preliv (háček z ug58.preliv_A při _useK); s R a existujícím starým výsledkem po krocích přes ug64
static func preliv(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary, g: int, dz: float, key: int) -> Dictionary:
	if bool(c.get("_useR64", false)) and c.has("_r_prev") and key < c._r_prev.size():
		if not c.has("_jobs"): c._jobs = {}
		var j = c._jobs.get(key)
		if j == null:
			j = make(c, entries, q, ex, g, dz, key); c._jobs[key] = j
		else:
			j.absorb_dirty()
		var left := int(c.get("_r_left", 0))
		c._r_left = left - j.run(left)
		if j.phase >= 5:
			c._jobs.erase(key)
			return j.result
		var old: Dictionary = c._r_prev[key]
		j.ph = old.duplicate(); j.ph._pending = true
		return j.ph
	var j2 = make(c, entries, q, ex, g, dz, key)
	j2.run(1 << 30)
	return j2.result
