extends RefCounted
## E64 řízení variant K / I / R / V nad E58–E63 (ug58). Příznaky ve variantě: "A+B+C+D+K+I+R+V".
##  K: kanonický sestup (sestup64), I: lokální oprava přes hranici S, R: kroky po rozpočtu operací, V: řetězce ve sloupci,
##  P: výsledek priority-flood z paměti, když se pool nezměnil a výkop nesáhl na data, která flood četl.
## Výchozí chování ug58 se nemění: háček v ug58.preliv_A se zapne jen přes c._useK.
const U = preload("res://scripts/alg58/ug58.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const SD = preload("res://scripts/alg64/sestup64.gd")
const P64 = preload("res://scripts/alg64/pre64.gd")
const E := 1e-6

static func setup(c: Dictionary, v: String, budget: int) -> void:
	c._useK = U.has_flag(v, "K")
	c._useI64 = U.has_flag(v, "I") and c._useK
	c._useR64 = U.has_flag(v, "R") and c._useK
	c._useV64 = U.has_flag(v, "V") and c._useK
	c._useP64 = U.has_flag(v, "P") and c._useI64   # P: priority-flood z paměti, když výkop nesáhl na data, která četl
	c._r_budget = budget
	if c._useK: c._useE = false; c._useI = false   # ug58 E/I se s K nepoužijí
	if c._useV64: chain_all(c)

## V: vnitřní článek řetězce = pásmo tělesa bez bočních sousedů, nejvýš 1 nad a 1 pod ve sloupci
static func _chain_b(c: Dictionary, b: int) -> int:
	if c.body[b] == 0: return 0
	var lo: float = c.lo[b]; var hi: float = c.hi[b]; var col: int = c.bcol[b]
	var up := 0; var dn := 0
	var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb
	for j in range(ns[b], ns[b + 1]):
		var b2 := nb[j]
		if c.body[b2] == 0: continue
		if c.bcol[b2] != col:
			if minf(hi, c.hi[b2]) > maxf(lo, c.lo[b2]) + E: return 0
		elif c.hi[b2] <= lo + E: dn += 1
		else: up += 1
	return 1 if up <= 1 and dn <= 1 else 0

static func chain_all(c: Dictionary) -> void:
	var n: int = c.lo.size()
	var a := PackedByteArray(); a.resize(n)
	for b in n: a[b] = _chain_b(c, b)
	c._chain64 = a

static func chain_cols(c: Dictionary, cc: int) -> void:
	var a: PackedByteArray = c._chain64
	var H: int = c.H; var W: int = c.W; var x := cc / H; var y := cc % H
	var cols := [cc]
	if x > 0: cols.append(cc - H)
	if x < W - 1: cols.append(cc + H)
	if y > 0: cols.append(cc - 1)
	if y < H - 1: cols.append(cc + 1)
	for col in cols:
		for b in range(c.cs[col], c.cs[col + 1]): a[b] = _chain_b(c, b)

## výkop (krok 0): označí změněná pásma jako špinavá pro všechny stavy sestupu, pustí ug58.edit s rozpočtem
static func edit(c: Dictionary, calls: Array, prev: Array, s: int, hv: float, v: String, dz: float, stats: Dictionary) -> Array:
	var cc := F.col_of(c, s)
	var b0: int = c.cs[cc]; var b1: int = c.cs[cc + 1]
	var oh := PackedFloat64Array(); var ob := PackedByteArray(); var old_h := float(c.h[cc])
	for b in range(b0, b1): oh.append(c.hi[b]); ob.append(c.body[b])
	c._edit_no = int(c.get("_edit_no", 0)) + 1
	if bool(c.get("_useR64", false)):
		c._r_prev = prev; c._r_left = int(c._r_budget)
	# X = pásma, jejichž data se změnila (hi, body), + všechna pásma sloupce, když se změnil povrch h a sloupec má vstup
	# (semínko vstupu = min(hi, h)). Jiná pásma sloupce mají stejné hrany → do X nepatří (důkaz v PROP E64).
	var X := []
	var nh := hv * float(c.get("cm_s", c.side))   # stejně jako F.touched
	if nh < old_h:
		var ents: Dictionary = c.get("_ents", {})
		for b in range(b0, b1):
			var h2 := minf(float(c.hi[b]), nh)
			var bd := 0 if h2 <= float(c.lo[b]) + E else int(c.body[b])
			if h2 != float(c.hi[b]) or bd != int(c.body[b]) or ents.has(b): X.append(b)
	if c.has("_k64"):
		for k in c._k64:
			var st: Dictionary = c._k64[k]
			for b in X: st.dirty[b] = true; st.pfd[b] = true
			if nh < old_h: st.pfc[cc] = true
	c._x64 = X.size()
	var res := U.edit(c, calls, prev, s, hv, v, dz, stats)
	if bool(c.get("_useV64", false)): chain_cols(c, cc)   # jen výkon: na správnost příznak vliv nemá
	if bool(c.get("_useR64", false)):
		c._r_res = res
		if pending(c) and c._r_left > 0: step(c, calls, res, int(c._r_left), true)
		c.erase("_r_prev")
	return res

static func pending(c: Dictionary) -> bool:
	return c.has("_jobs") and not c._jobs.is_empty()

## další krok: rozpracované úlohy (pořadí podle klíče volání) dostanou dohromady nejvýš budget operací
static func step(c: Dictionary, calls: Array, res: Array, budget: int, in_edit := false) -> bool:
	if not pending(c): return false
	var left := budget
	var keys: Array = c._jobs.keys(); keys.sort()
	for key in keys:
		if left <= 0: break
		var j = c._jobs[key]
		j.absorb_dirty()
		left -= j.run(left)
		if j.phase >= 5:
			c._jobs.erase(key)
			var r: Dictionary = j.result
			if j.ph != null:
				r.rezim_tel = j.ph.get("rezim_tel", "preliv"); r.f_prop = j.ph.get("f_prop", 0.0)
			_publish(c, calls, res, key, j, r)
	if in_edit: c._r_left = left
	return pending(c)

static func _publish(c: Dictionary, calls: Array, res: Array, key: int, j, r: Dictionary) -> void:
	var ents: PackedInt32Array = calls[key].ents
	if c.has("_nid"):
		var id: int = c._nid[ents[0]]
		if id >= 0:
			var nd: Dictionary = c._nodes[id]
			var pe = nd.pre.get(key)
			if pe != null and is_same(pe.r, j.ph):
				nd.pre[key] = P64.cache_entry(c, r, ents, key)
	if key < res.size() and (j.ph == null or is_same(res[key], j.ph)): res[key] = r

## otisk výsledku (fyzikální pole bez počítadel) + stavu sestupu
static func digest_res(r: Dictionary) -> String:
	var o: Array = r.get("out", [])
	var parts := [r.get("leak", 0.0), r.get("out_q", 0.0), r.get("z_out", 0.0), r.get("volume_m3", 0.0), r.get("lake_m3", 0.0), r.get("closed", false), r.get("rezim_tel", ""), r.get("cells", 0)]
	if not o.is_empty(): parts.append_array([o[2], o[3], o[4]])
	for e in r.get("events", []): parts.append_array([e.z, e.objem_m3, e.cas_s])
	var s := ""
	for x in parts: s += (var_to_str(x) if typeof(x) == TYPE_FLOAT else str(x)) + "|"
	return s.sha256_text().substr(0, 16)
