extends RefCounted
## E58 varianty A / B / C nad podzemím varianty 4 (ug_funkce, režim auto). Stejné vstupy (záznam volání), stejné výkopy.
##  A: preliv přes kbelíkovou frontu (bq58) + pomocná pole místo slovníků (stejné pořadí → stejný výsledek)
##  B: graf těles: uzel = těleso se souhrny (průsak, kandidáti výstupu, dno, objem po hladině); dotaz místo BFS
##  C: stopa volání (sloupce navštívených pásem + sousedé); výkop mimo stopu = beze změny. S B: delta souhrnů.
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const BQ = preload("res://scripts/alg58/bq58.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const E := 1e-6
const SH := 4194304.0   # 2^22 pro kódování (z, index) v jednom čísle při řazení
const P64 = preload("res://scripts/alg64/pre64.gd")   # E64 K (jen s c._useK)

static func has_flag(v: String, f: String) -> bool:
	return v.split("+").has(f)

## kopie kontextu (pole se zkopírují, aby varianty a reference nesdílely stav)
static func clone(c: Dictionary) -> Dictionary:
	var o := {}
	for k in c:
		var v = c[k]
		if v is Dictionary or v is Array: o[k] = v.duplicate(true)
		elif typeof(v) >= TYPE_PACKED_BYTE_ARRAY and typeof(v) <= TYPE_PACKED_VECTOR4_ARRAY: o[k] = v.duplicate()
		else: o[k] = v
	return o

static func ex_of(c: Dictionary, excl: Array) -> Dictionary:
	var ex := {}
	for s in excl: ex[F.col_of(c, int(s))] = true
	return ex

## ---------------- A: preliv kbelíky ----------------
static func _arr(c: Dictionary) -> void:
	if c.has("_capg"): return
	var n: int = c.lo.size()
	var a := PackedInt32Array(); a.resize(n); c._capg = a
	var v := PackedFloat64Array(); v.resize(n); c._capv = v
	var d := PackedInt32Array(); d.resize(n); c._dng = d

static var PROF := {}   # E63: časy fází prelivu (jen měření)
static func preliv_A(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary, g: int, dz: float) -> Dictionary:
	if bool(c.get("_useK", false)): return P64.preliv(c, entries, q, ex, g, dz, _p1key)   # E64
	var _t0 := Time.get_ticks_usec()
	_arr(c)
	var lab: PackedInt32Array = c.lab; var capg: PackedInt32Array = c._capg; var capv: PackedFloat64Array = c._capv; var dng: PackedInt32Array = c._dng
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var cl := PackedInt32Array()
	if bool(c.get("_useE", false)) and bool(c.get("_useI", false)) and _p1key >= 0: cl = _p1_inc(c, entries, _p1key, g).duplicate()
	elif bool(c.get("_useE", false)): cl = _p1_fast(c, entries, g)
	else:
		var qu := PackedInt32Array()
		for e in entries:
			if e < 0: continue
			if capg[e] != g: cl.append(e)
			capv[e] = minf(hi[e], float(c.h[bcol[e]])); capg[e] = g; qu.append(e); lab[e] = g
		var k := 0
		while k < qu.size():
			var b := qu[k]; k += 1
			var cb := capv[b]
			for nb in F._nbrs(c, b):
				var b2: int = nb[0]; var olo: float = nb[1]; var ohi: float = nb[2]
				var below: bool = bcol[b2] == bcol[b] and hi[b2] <= lo[b] + E
				if not below and cb <= olo + E: continue
				var nc := minf(cb, hi[b2]) if below else minf(cb, ohi)
				if capg[b2] != g or nc > capv[b2] + E:
					if capg[b2] != g: cl.append(b2)
					capv[b2] = nc; capg[b2] = g; qu.append(b2); lab[b2] = g
	var _t1 := Time.get_ticks_usec()
	var pool := -1
	for b in cl:
		if pool < 0 or lo[b] < lo[pool] - E or (absf(lo[b] - lo[pool]) <= E and b < pool): pool = b
	if pool < 0:
		var r0 := F._result(c, PackedInt32Array(), 0.0, [], q, 0.0, entries, true); r0._vis = cl; return r0
	var bq = BQ.new(dz, lo[pool])
	var outs := []
	bq.push(lo[pool], pool)
	var comp := PackedInt32Array(); var best := []; var L := -INF; var n_pop := 0
	while not bq.empty():
		var it: Array = bq.pop()
		var key: float = it[0]; var id: int = it[1]
		if id < 0:
			var o: Array = outs[-id - 1]
			best = [key, n_pop, o[3], o[1], o[2]]; L = key
			break
		if dng[id] == g: continue
		dng[id] = g; comp.append(id); lab[id] = g; n_pop += 1
		L = maxf(L, hi[id])
		for o in F._outs(c, id, ex):
			outs.append([o[0], o[1], o[2], id])
			bq.push(maxf(key, float(o[0])), -outs.size())
		for nb in F._nbrs(c, id):
			if dng[int(nb[0])] != g: bq.push(maxf(key, float(nb[1])), int(nb[0]))
	var _t2 := Time.get_ticks_usec()
	var closed := best.is_empty()
	var leak := 0.0
	for b in comp: leak += F._leak(c, b, L)
	var _t3 := Time.get_ticks_usec()
	var r := F._result(c, comp, L, best, q, leak, entries, closed)
	var _t4 := Time.get_ticks_usec()
	PROF.n = int(PROF.get("n", 0)) + 1
	for kv in [["sestup", _t1 - _t0], ["pf", _t2 - _t1], ["leak", _t3 - _t2], ["result", _t4 - _t3]]: PROF[kv[0]] = float(PROF.get(kv[0], 0.0)) + kv[1] / 1000.0
	PROF.cl = cl.size(); PROF.comp = comp.size()
	cl.append_array(comp); r._vis = cl
	return r

## ---------------- E63: kapilární sestup prelivu (fáze 1) ----------------
## E: stejný algoritmus jako v preliv_A (stejné pořadí fronty), jen bez volání F._nbrs a slovníkových přístupů.
static var _p1key := -1   # index volání (nastaví _one), klíč stavu pro I
static func _p1_fast(c: Dictionary, entries: PackedInt32Array, g: int) -> PackedInt32Array:
	var lab: PackedInt32Array = c.lab; var capg: PackedInt32Array = c._capg; var capv: PackedFloat64Array = c._capv
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var body: PackedByteArray = c.body; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb; var hh: PackedFloat64Array = c.h
	var qu := PackedInt32Array(); var cl := PackedInt32Array()
	for e in entries:
		if e < 0: continue
		if capg[e] != g: cl.append(e)
		capv[e] = minf(hi[e], hh[bcol[e]]); capg[e] = g; qu.append(e); lab[e] = g
	var k := 0
	while k < qu.size():
		var b := qu[k]; k += 1
		var cb := capv[b]; var lb := lo[b]; var hb := hi[b]; var colb := bcol[b]
		for j in range(ns[b], ns[b + 1]):
			var b2 := nb[j]
			if body[b2] == 0: continue
			var lo2 := lo[b2]; var hi2 := hi[b2]
			var olo := maxf(lb, lo2); var ohi := minf(hb, hi2)
			var same := bcol[b2] == colb
			if same:
				if ohi < olo - E: continue
			elif ohi <= olo + E: continue
			var below := same and hi2 <= lb + E
			if not below and cb <= olo + E: continue
			var nc := minf(cb, hi2) if below else minf(cb, ohi)
			if capg[b2] != g or nc > capv[b2] + E:
				if capg[b2] != g: cl.append(b2)
				capv[b2] = nc; capg[b2] = g; qu.append(b2); lab[b2] = g
	return cl

## hrana u → b sestupu (stejná pravidla jako F._nbrs + preliv_A); vrací nc nebo -INF, když hrana neplatí
static func _p1_edge(cb: float, lu: float, hu: float, cu: int, lb: float, hb: float, cbb: int) -> float:
	var olo := maxf(lu, lb); var ohi := minf(hu, hb)
	var same := cbb == cu
	if same:
		if ohi < olo - E: return -INF
	elif ohi <= olo + E: return -INF
	var below := same and hb <= lu + E
	if not below and cb <= olo + E: return -INF
	return minf(cb, hb) if below else minf(cb, ohi)

## I: lokální oprava sestupu. Stav na volání: capv, dosaženo (rch), rodič (par, strom posledních zlepšení), cl.
## Po výkopech ve sloupcích D: X = pásma v D + vstupy v D; S = X + potomci X ve stromu rodičů. Mimo S se hodnoty
## nemění (cesta k nim nevede přes změněná data). S se vynuluje, osadí z dosažených sousedů mimo S a ze vstupů
## a dál běží stejný sestup (může zlepšit i pásma mimo S).
static func _p1_inc(c: Dictionary, entries: PackedInt32Array, key: int, g: int) -> PackedInt32Array:
	if not c.has("_p1st"): c._p1st = {}
	var sts: Dictionary = c._p1st
	var lab: PackedInt32Array = c.lab
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var body: PackedByteArray = c.body; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb; var hh: PackedFloat64Array = c.h
	var cs: PackedInt32Array = c.cs
	var n := lo.size()
	var st = sts.get(key)
	var capv: PackedFloat64Array; var rch: PackedByteArray; var par: PackedInt32Array
	var qu := PackedInt32Array(); var add := PackedInt32Array()
	var inS := PackedByteArray()
	var kept := PackedInt32Array()
	if st == null or st.ents != entries:
		capv = PackedFloat64Array(); capv.resize(n); rch = PackedByteArray(); rch.resize(n); rch.fill(0)
		par = PackedInt32Array(); par.resize(n); par.fill(-1)
		for e in entries:
			if e < 0: continue
			if rch[e] == 0: add.append(e)
			capv[e] = minf(hi[e], hh[bcol[e]]); rch[e] = 1; par[e] = -1; qu.append(e)
		PROF.p1_full = int(PROF.get("p1_full", 0)) + 1
	else:
		capv = st.capv; rch = st.rch; par = st.par
		var dirty: Dictionary = st.dirty
		if dirty.is_empty():
			PROF.p1_same = int(PROF.get("p1_same", 0)) + 1
			return st.cl
		var X := PackedInt32Array()
		for col in dirty:
			for b in range(cs[col], cs[col + 1]): X.append(b)
		for e in entries:
			if e >= 0 and dirty.has(bcol[e]): X.append(e)
		# potomci ve stromu rodičů (spojové seznamy dětí)
		var head := PackedInt32Array(); head.resize(n); head.fill(-1)
		var nxt := PackedInt32Array(); nxt.resize(n)
		var ocl: PackedInt32Array = st.cl
		for b in ocl:
			var pb := par[b]
			if pb >= 0: nxt[b] = head[pb]; head[pb] = b
		inS.resize(n); inS.fill(0)
		var S := PackedInt32Array()
		for b in X:
			if inS[b] == 0: inS[b] = 1; S.append(b)
		var k0 := 0
		while k0 < S.size():
			var b := S[k0]; k0 += 1
			if rch[b] == 0: continue
			var ch := head[b]
			while ch >= 0:
				if inS[ch] == 0: inS[ch] = 1; S.append(ch)
				ch = nxt[ch]
		for b in S: rch[b] = 0; par[b] = -1
		for b in ocl: if inS[b] == 0: kept.append(b)
		# vstupy v S
		for e in entries:
			if e < 0 or inS[e] == 0: continue
			if rch[e] == 0: add.append(e)
			capv[e] = minf(hi[e], hh[bcol[e]]); rch[e] = 1; par[e] = -1
		# osazení z dosažených sousedů mimo S (hrana u → b musí být v CSR u)
		for b in S:
			if body[b] == 0: continue
			var lb := lo[b]; var hb := hi[b]; var cbb := bcol[b]
			for j in range(ns[b], ns[b + 1]):
				var u := nb[j]
				if inS[u] == 1 or rch[u] == 0: continue
				var ok := false
				for j2 in range(ns[u], ns[u + 1]):
					if nb[j2] == b: ok = true; break
				if not ok: continue
				var nc := _p1_edge(capv[u], lo[u], hi[u], bcol[u], lb, hb, cbb)
				if nc == -INF: continue
				if rch[b] == 0 or nc > capv[b] + E:
					if rch[b] == 0: add.append(b)
					capv[b] = nc; rch[b] = 1; par[b] = u
		for b in S: if rch[b] == 1: qu.append(b)
		PROF.p1_rep = int(PROF.get("p1_rep", 0)) + 1; PROF.p1_S = int(PROF.get("p1_S", 0)) + S.size()
	var k := 0
	while k < qu.size():
		var b := qu[k]; k += 1
		var cb := capv[b]; var lb := lo[b]; var hb := hi[b]; var colb := bcol[b]
		for j in range(ns[b], ns[b + 1]):
			var b2 := nb[j]
			if body[b2] == 0: continue
			var nc := _p1_edge(cb, lb, hb, colb, lo[b2], hi[b2], bcol[b2])
			if nc == -INF: continue
			if rch[b2] == 0 or nc > capv[b2] + E:
				if rch[b2] == 0: add.append(b2)
				capv[b2] = nc; rch[b2] = 1; par[b2] = b; qu.append(b2)
	for b in add: lab[b] = g
	kept.append_array(add)
	sts[key] = {"capv": capv, "rch": rch, "par": par, "cl": kept, "ents": entries, "dirty": {}}
	return kept

## auto jako F._solve_auto (A volitelně), vrací i tělo nadrz (_body) a navštívená pásma prelivu (_vis) pro stopu C
static func auto_X(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary, useA: bool, dz: float) -> Dictionary:
	c.gen = int(c.gen) + 1
	var rn := F._solve_nadrz(c, entries, q, ex, int(c.gen))
	var fl := F.floor_of(c, rn.comp_ids)
	var at := float(fl.a_prop) + float(fl.a_nep)
	var f := float(fl.a_prop) / at if at > 0.0 else 1.0
	var r: Dictionary
	if f <= 1e-9:
		c.gen = int(c.gen) + 1
		r = preliv_A(c, entries, q, ex, int(c.gen), dz) if useA else F._solve_preliv(c, entries, q, ex, int(c.gen))
		r.rezim_tel = "preliv"
	else:
		var lk := minf(float(fl.seep_q), q)
		r = F._result(c, rn.comp_ids, float(rn.z_out), rn._best, q, lk, entries, rn._best.is_empty())
		r.rezim_tel = "nadrz" if f >= 1.0 - 1e-9 else "smes"
	r._body = rn.comp_ids
	r.f_prop = f
	return r

## stopa: sloupce pásem + 4 sousedé
static func footprint(c: Dictionary, lists: Array) -> PackedByteArray:
	var W: int = c.W; var H: int = c.H
	var fp := PackedByteArray(); fp.resize(W * H)
	var bcol: PackedInt32Array = c.bcol
	for l in lists:
		for b in l:
			var cc: int = bcol[b]
			if fp[cc] == 1: continue
			fp[cc] = 1
	var add := PackedInt32Array()
	for cc in W * H:
		if fp[cc] != 1: continue
		var x := cc / H; var y := cc % H
		if x > 0: add.append(cc - H)
		if x < W - 1: add.append(cc + H)
		if y > 0: add.append(cc - 1)
		if y < H - 1: add.append(cc + 1)
	for cc in add: if fp[cc] == 0: fp[cc] = 2
	return fp

## ---------------- B: graf těles ----------------
static func _barr(c: Dictionary) -> void:
	if c.has("_nid"): return
	var n: int = c.lo.size()
	var a := PackedInt32Array(); a.resize(n); a.fill(-1); c._nid = a
	for k in ["_fap", "_fan", "_fsq"]:
		var v := PackedFloat64Array(); v.resize(n); c[k] = v
	c._nodes = []

## příspěvek pásma b ke dnu (stejná pravidla jako F.floor_of)
static func _floor_b(c: Dictionary, b: int, t: Dictionary) -> Array:
	var cc: int = c.bcol[b]; var lo: float = c.lo[b]
	var under := -1
	for b2 in range(c.cs[cc], c.cs[cc + 1]):
		if b2 != b and float(c.lo[b2]) < lo - 1e-4 and float(c.hi[b2]) >= lo - 1e-4 and (under < 0 or float(c.hi[b2]) > float(c.hi[under])): under = b2
	if under >= 0 and c.body[under] == 1 and c.comp[under] == c.comp[b]: return [0.0, 0.0, 0.0]
	var m := -1 if under < 0 else int(c.mat[under])
	var perm := 1.0 if m < 0 else float(t.get(m, [0.0])[0])
	if m == 0: perm = 1.0
	var A: float = c.A
	if perm <= float(c.perm_dno): return [0.0, A, 0.0]
	return [A, 0.0, A * perm * float(c.leak_m2)]

## kandidáti výstupu pásma b (jako smyčka v F._solve_nadrz): [z, typ 0 okraj / 1 povrch, sloupec, sloupec pro excl (-1)]
static func _cands_b(c: Dictionary, b: int, nd: Dictionary) -> void:
	var cc: int = c.bcol[b]; var W: int = c.W; var H: int = c.H
	var x := cc / H; var y := cc % H
	var bl: float = c.lo[b]; var bh: float = c.hi[b]
	if x == 0 or y == 0 or x == W - 1 or y == H - 1: _cadd(nd, bl, b, 0, cc, -1, cc)
	if bh >= float(c.h[cc]) - E: _cadd(nd, bh, b, 1, cc, cc, cc)
	for d in 4:
		var qx := x; var qy := y
		match d:
			0: qx += 1
			1: qx -= 1
			2: qy += 1
			3: qy -= 1
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var c2 := qx * H + qy
		if c.wall[c2] == 1 or float(c.h[c2]) >= bh - E: continue
		_cadd(nd, maxf(bl, float(c.h[c2])), b, 1, c2, c2, cc)

static func _cadd(nd: Dictionary, z: float, b: int, ty: int, col: int, xc: int, own: int) -> void:
	var i: int = nd.cz.size()
	nd.cz.append(z); nd.cb.append(b); nd.ct.append(ty); nd.cc.append(col); nd.cx.append(xc)
	if not nd.cby.has(own): nd.cby[own] = PackedInt32Array()
	var a: PackedInt32Array = nd.cby[own]; a.append(i); nd.cby[own] = a
	nd.extra.append(i)

static func _resort(nd: Dictionary) -> void:
	var keys := PackedFloat64Array()
	var cz: PackedFloat64Array = nd.cz
	for i in cz.size():
		if cz[i] < INF: keys.append(floor(maxf(cz[i], 0.0) * 1e6) * SH + i)
	keys.sort()
	nd.sorted = keys; nd.extra = PackedInt32Array()

## nový uzel z BFS od vstupu (stejná platnost hran jako F._solve_nadrz)
static func node_build(c: Dictionary, seed: int) -> int:
	_barr(c)
	var nid: PackedInt32Array = c._nid
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var body: PackedByteArray = c.body
	var bcol: PackedInt32Array = c.bcol; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb; var lf: PackedFloat64Array = c.leakf
	var id: int = c._nodes.size()
	var nd := {"bands": PackedInt32Array(), "leak": 0.0, "zmax": -INF, "cz": PackedFloat64Array(), "cb": PackedInt32Array(), "ct": PackedInt32Array(),
		"cc": PackedInt32Array(), "cx": PackedInt32Array(), "cby": {}, "extra": PackedInt32Array(), "sorted": PackedFloat64Array(),
		"ap": 0.0, "an": 0.0, "sq": 0.0, "L": NAN, "rb": {}, "alive": true, "pre": {}}
	c._nodes.append(nd)
	var qu := PackedInt32Array([seed]); nid[seed] = id
	var k := 0; var leak := 0.0; var zmax := -INF
	var t := VS.table()
	var fap: PackedFloat64Array = c._fap; var fan: PackedFloat64Array = c._fan; var fsq: PackedFloat64Array = c._fsq
	while k < qu.size():
		var b := qu[k]; k += 1
		leak += lf[b]; zmax = maxf(zmax, hi[b])
		_cands_b(c, b, nd)
		var fb := _floor_b(c, b, t)
		fap[b] = fb[0]; fan[b] = fb[1]; fsq[b] = fb[2]
		var bl := lo[b]; var bh := hi[b]; var cc := bcol[b]
		for j in range(ns[b], ns[b + 1]):
			var b2 := nb[j]
			if nid[b2] == id or body[b2] == 0: continue
			var olo := maxf(bl, lo[b2]); var ohi := minf(bh, hi[b2])
			if (bcol[b2] == cc and ohi >= olo - E) or ohi > olo + E:
				nid[b2] = id; qu.append(b2)
	nd.bands = qu; nd.leak = leak; nd.zmax = zmax
	var ap := 0.0; var an := 0.0; var sq := 0.0
	for b in qu: ap += fap[b]; an += fan[b]; sq += fsq[b]
	nd.ap = ap; nd.an = an; nd.sq = sq
	_resort(nd)
	return id

static func node_kill(c: Dictionary, id: int) -> void:
	var nd: Dictionary = c._nodes[id]
	if not nd.alive: return
	nd.alive = false
	var nid: PackedInt32Array = c._nid
	for b in nd.bands: if nid[b] == id: nid[b] = -1

## nejnižší platný kandidát; [] = žádný; null = nejednoznačné (shoda v toleranci → přesný BFS)
static func node_best(c: Dictionary, nd: Dictionary, ex: Dictionary):
	var cz: PackedFloat64Array = nd.cz; var cx: PackedInt32Array = nd.cx
	var best := -1; var bz := INF
	var srt: PackedFloat64Array = nd.sorted
	var lim := INF
	for key in srt:
		var i := int(fposmod(key, SH))
		var z := cz[i]
		if z == INF: continue
		if key / SH > lim * 1e6 + 4.0: break
		if cx[i] >= 0 and ex.has(cx[i]): continue
		if z < bz: bz = z; best = i
		if lim == INF: lim = z + 3.0 * E
	for i in nd.extra:
		var z := cz[i]
		if z == INF or (cx[i] >= 0 and ex.has(cx[i])): continue
		if z < bz: bz = z; best = i
	if best < 0: return []
	# jednoznačnost: jiný platný kandidát do 2E
	for key in srt:
		var i := int(fposmod(key, SH))
		if key / SH > (bz + 3.0 * E) * 1e6 + 4.0: break
		if i == best or cz[i] == INF or (cx[i] >= 0 and ex.has(cx[i])): continue
		if cz[i] <= bz + 2.0 * E: return null
	for i in nd.extra:
		if i == best or cz[i] == INF or (cx[i] >= 0 and ex.has(cx[i])): continue
		if cz[i] <= bz + 2.0 * E: return null
	return [bz, -1, int(nd.cb[best]), "okraj" if int(nd.ct[best]) == 0 else "povrch", int(nd.cc[best])]

## výsledek pro jiné q z výsledku se stejnou hladinou (bez průchodu tělesem)
static func requ(c: Dictionary, rb: Dictionary, q: float, leak: float, best: Array, entries: PackedInt32Array) -> Dictionary:
	var r := rb.duplicate()
	var closed := best.is_empty()
	var net := q - leak
	var ev := []
	for e in rb.events:
		ev.append({"z": e.z, "objem_m3": e.objem_m3, "cas_s": (float(e.objem_m3) / (net * float(c.q_to_m3))) if net > 0.0 else -1.0})
	r.events = ev
	r.q_in = q; r.leak = minf(leak, q); r.never_fills = net <= 0.0; r.closed = closed
	r.out_q = maxf(net, 0.0) if not closed else 0.0
	r.out = [] if closed else [best[0], best[1], best[2], best[3], F._col_s(c, int(best[4]), String(best[3]) == "okraj")]
	return r

## dotaz jednoho volání přes graf; vrací výsledek nebo null (nejednoznačné / vstup mimo uzel → přesná cesta)
static func node_solve(c: Dictionary, call: Dictionary, ci: int, useA: bool, dz: float, stats: Dictionary):
	_barr(c)
	var ents: PackedInt32Array = call.ents
	var nid: PackedInt32Array = c._nid
	var id := nid[ents[0]]
	if id < 0: id = node_build(c, ents[0]); stats.builds += 1
	for e in ents: if nid[e] != id: return null
	var nd: Dictionary = c._nodes[id]
	var bst = node_best(c, nd, call.ex)
	if bst == null: return null
	var best: Array = bst
	var at: float = nd.ap + nd.an
	var f: float = nd.ap / at if at > 0.0 else 1.0
	var q: float = call.q
	if f <= 1e-9:
		var pc: Dictionary = nd.pre
		if pc.has(ci): return pc[ci].r
		c.gen = int(c.gen) + 1
		var r0: Dictionary = preliv_A(c, ents, q, call.ex, int(c.gen), dz) if useA else F._solve_preliv(c, ents, q, call.ex, int(c.gen))
		r0.rezim_tel = "preliv"; r0.f_prop = f
		if bool(c.get("_useK", false)): pc[ci] = P64.cache_entry(c, r0, ents, ci)   # E64
		else: pc[ci] = {"r": r0, "fp": footprint(c, [r0._vis]) if useA else PackedByteArray(), "vb": _vis_bands(c, r0) if bool(c.get("_useD", false)) else PackedByteArray(), "ents": ents}
		stats.floods += 1
		return r0
	if best.is_empty():   # uzavřené: zmax z aktuálních hi (po deltě může být zastaralé)
		var zm := -INF
		for b in nd.bands: zm = maxf(zm, float(c.hi[b]))
		nd.zmax = zm
	var L: float = best[0] if not best.is_empty() else float(nd.zmax)
	if not (nd.L == L) or nd.rb.is_empty():
		nd.rb = F._result(c, nd.bands, L, best, q, 0.0, ents, best.is_empty()); nd.L = L; stats.results += 1
	var lk := minf(float(nd.sq), q)
	var r := requ(c, nd.rb, q, lk, best, ents)
	r.rezim_tel = "nadrz" if f >= 1.0 - 1e-9 else "smes"; r.f_prop = f
	return r

## E62: pásma navštívená prelivem (1 = kapilární sestup / sousedé, 2 = těleso tůně z priority-flood)
static func _vis_bands(c: Dictionary, r: Dictionary) -> PackedByteArray:
	var vb := PackedByteArray(); vb.resize(c.lo.size())
	for b in r._vis: vb[b] = 1
	for b in r.comp_ids: vb[b] = 2
	return vb

## E62: mění výkop ve sloupci cc data, která preliv četl? (pravidla v PROP E62)
static func _pre_hit(c: Dictionary, pe: Dictionary, cc: int, b0: int, old_hi: PackedFloat64Array, old_body: PackedByteArray, old_h: float) -> bool:
	var vb: PackedByteArray = pe.vb
	var bcol: PackedInt32Array = c.bcol
	for e in pe.ents: if e >= 0 and bcol[e] == cc: return true   # 4. vstup ve sloupci
	var chg := {}
	for k in old_hi.size():
		var b := b0 + k
		if c.hi[b] != old_hi[k] or c.body[b] != old_body[k]:
			if vb[b] != 0: return true   # 1. navštívené změněné pásmo
			chg[b] = true
	if chg.is_empty() and float(c.h[cc]) == old_h: return false
	var nh := float(c.h[cc])
	var W: int = c.W; var H: int = c.H; var x := cc / H; var y := cc % H
	var cols := [cc]
	if x > 0: cols.append(cc - H)
	if x < W - 1: cols.append(cc + H)
	if y > 0: cols.append(cc - 1)
	if y < H - 1: cols.append(cc + 1)
	for col in cols:
		for b in range(c.cs[col], c.cs[col + 1]):
			if vb[b] == 0: continue
			if vb[b] == 2 and float(c.hi[b]) >= nh - E: return true   # 3. výstupy na povrch / průsak u nového povrchu
			if not chg.is_empty():
				for j in range(c.ns[b], c.ns[b + 1]):
					if chg.has(c.nb[j]): return true   # 2. soused navštíveného pásma se změnil
	return false

## B+C: delta uzlu po výkopu ve sloupci cc (staré hi pásem sloupce v old_hi). false = nutná přestavba.
static func node_delta(c: Dictionary, id: int, cc: int, old_hi: PackedFloat64Array, old_body: PackedByteArray, stats: Dictionary) -> bool:
	var nd: Dictionary = c._nodes[id]
	var nid: PackedInt32Array = c._nid
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var b0: int = c.cs[cc]; var b1: int = c.cs[cc + 1]
	# souvislost: zmizelé pásmo nebo rozpojený překryv → omezený BFS (p58_bfs_max), jestli se těleso nerozpadlo; jinak přestavba
	var budget: int = int(c.get("_bfs_max", 20000))
	var gone := PackedInt32Array()
	for b in range(b0, b1):
		if nid[b] != id: continue
		if old_body[b - b0] == 1 and c.body[b] == 0:
			var nn := []
			for j in range(c.ns[b], c.ns[b + 1]):
				var b2: int = c.nb[j]
				if b2 == b or nid[b2] != id or c.body[b2] == 0: continue
				var oh2: float = old_hi[b2 - b0] if (b2 >= b0 and b2 < b1) else hi[b2]
				if _edge_ok(lo[b], old_hi[b - b0], lo[b2], oh2, bcol[b] == bcol[b2]): nn.append(b2)
			gone.append(b)
			for t in range(1, nn.size()):
				if not _split_check(c, id, int(nn[0]), int(nn[t]), b, budget, stats, nd): return false
			continue
		if hi[b] == old_hi[b - b0]: continue
		for j in range(c.ns[b], c.ns[b + 1]):
			var b2: int = c.nb[j]
			if nid[b2] != id: continue
			var oh2: float = old_hi[b2 - b0] if (b2 >= b0 and b2 < b1) else hi[b2]
			var was := _edge_ok(lo[b], old_hi[b - b0], lo[b2], oh2, bcol[b] == bcol[b2])
			var now := _edge_ok(lo[b], hi[b], lo[b2], hi[b2], bcol[b] == bcol[b2])
			if was and not now and not _split_check(c, id, b, b2, -1, budget, stats, nd): return false
	# zmizelá pásma: ven z uzlu (průsak, dno, počet), kandidáti se níže přegenerují bez nich
	for b in gone:
		nd.leak -= float(c.leakf[b])
		nd.ap -= c._fap[b]; nd.an -= c._fan[b]; nd.sq -= c._fsq[b]
		c._fap[b] = 0.0; c._fan[b] = 0.0; c._fsq[b] = 0.0
		nid[b] = -1
		var bl: PackedInt32Array = nd.bands
		var k := bl.find(b)
		if k >= 0: bl.remove_at(k)
		nd.bands = bl
		if not nd.rb.is_empty(): nd.rb.cells = nd.bands.size(); nd.rb.events_stale = true
		stats.gone += 1
	# kandidáti: sloupec cc a 4 sousedé
	var W: int = c.W; var H: int = c.H
	var x := cc / H; var y := cc % H
	var cols := [cc]
	if x > 0: cols.append(cc - H)
	if x < W - 1: cols.append(cc + H)
	if y > 0: cols.append(cc - 1)
	if y < H - 1: cols.append(cc + 1)
	var cz: PackedFloat64Array = nd.cz
	for col in cols:
		if nd.cby.has(col):
			for i in nd.cby[col]: cz[i] = INF
			nd.cby[col] = PackedInt32Array()
		for b in range(c.cs[col], c.cs[col + 1]):
			if nid[b] == id and c.body[b] == 1: _cands_b(c, b, nd)
	if nd.extra.size() > 2000: _resort(nd)
	# dno a objem: jen pásma sloupce cc
	var t := VS.table()
	var fap: PackedFloat64Array = c._fap; var fan: PackedFloat64Array = c._fan; var fsq: PackedFloat64Array = c._fsq
	var dv := 0.0; var dl := 0.0
	for b in range(b0, b1):
		if nid[b] != id: continue
		var fb := _floor_b(c, b, t)
		nd.ap += fb[0] - fap[b]; nd.an += fb[1] - fan[b]; nd.sq += fb[2] - fsq[b]
		fap[b] = fb[0]; fan[b] = fb[1]; fsq[b] = fb[2]
		if not nd.rb.is_empty() and hi[b] != old_hi[b - b0]:
			var L: float = nd.L
			var w0 := minf(old_hi[b - b0], L) - lo[b]; var w1 := minf(hi[b], L) - lo[b]
			var pa: float = float(c.por[b]) * float(c.A)
			var d := pa * (maxf(w1, 0.0) if w1 > E else 0.0) - pa * (maxf(w0, 0.0) if w0 > E else 0.0)
			dv += d
			if int(c.mat[b]) == 0: dl += d
	if not nd.rb.is_empty() and (dv != 0.0 or dl != 0.0):
		nd.rb.volume_m3 = float(nd.rb.volume_m3) + dv; nd.rb.lake_m3 = float(nd.rb.lake_m3) + dl; nd.rb.events_stale = true
	stats.deltas += 1
	return true

## E58 C: oboustranný omezený BFS mezi a a t (bez pásma skip). Potkají se → souvislé. Jedna strana se vyčerpá →
## těleso se rozpadlo a vyčerpaná (malá) část se z uzlu odebere (delta), pokud neobsahuje vstup některého volání.
## Nerozhodnuto do budget → false (přestavba).
static func _split_check(c: Dictionary, id: int, a: int, t: int, skip: int, budget: int, stats: Dictionary, nd: Dictionary) -> bool:
	if a == t: return true
	var nid: PackedInt32Array = c._nid; var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var side := {a: 1, t: 2}
	var qs := [PackedInt32Array([a]), PackedInt32Array([t])]; var ks := [0, 0]
	var steps := 0
	while steps < budget:
		for sd in 2:
			var qu: PackedInt32Array = qs[sd]
			if ks[sd] >= qu.size():   # strana sd vyčerpána → rozpad, malá část = qu
				stats.reach += steps
				return _drop_part(c, id, qu, nd, stats)
			var b := qu[ks[sd]]; ks[sd] += 1; steps += 1
			for j in range(c.ns[b], c.ns[b + 1]):
				var b2: int = c.nb[j]
				if b2 == skip or nid[b2] != id or c.body[b2] == 0: continue
				if not _edge_ok(lo[b], hi[b], lo[b2], hi[b2], bcol[b] == bcol[b2]): continue
				var sv: int = side.get(b2, 0)
				if sv == sd + 1: continue
				if sv != 0: stats.reach += steps; return true
				side[b2] = sd + 1; qu.append(b2)
			qs[sd] = qu
	stats.reach += steps
	return false

static func _drop_part(c: Dictionary, id: int, part: PackedInt32Array, nd: Dictionary, stats: Dictionary) -> bool:
	var ents: Dictionary = c.get("_ents", {})
	for b in part: if ents.has(b): return false   # odpadla část se vstupem → přestavba
	var nid: PackedInt32Array = c._nid
	var cols := {}
	var dv := 0.0; var dl := 0.0
	for b in part:
		nd.leak -= float(c.leakf[b])
		nd.ap -= c._fap[b]; nd.an -= c._fan[b]; nd.sq -= c._fsq[b]
		c._fap[b] = 0.0; c._fan[b] = 0.0; c._fsq[b] = 0.0
		nid[b] = -1; cols[int(c.bcol[b])] = true
		if not nd.rb.is_empty():
			var w := minf(float(c.hi[b]), float(nd.L)) - float(c.lo[b])
			if w > E:
				var pa: float = float(c.por[b]) * float(c.A); dv += pa * w
				if int(c.mat[b]) == 0: dl += pa * w
	var keep := PackedInt32Array()
	for b in nd.bands: if nid[b] == id: keep.append(b)
	nd.bands = keep
	var cz: PackedFloat64Array = nd.cz
	for col in cols:   # kandidáti odpadlých pásem pryč (přegenerují se jen pásma uzlu)
		if nd.cby.has(col):
			for i in nd.cby[col]: cz[i] = INF
			nd.cby[col] = PackedInt32Array()
		for b in range(c.cs[col], c.cs[col + 1]):
			if nid[b] == id and c.body[b] == 1: _cands_b(c, b, nd)
	if not nd.rb.is_empty():
		nd.rb.volume_m3 = float(nd.rb.volume_m3) - dv; nd.rb.lake_m3 = float(nd.rb.lake_m3) - dl
		nd.rb.cells = nd.bands.size(); nd.rb.events_stale = true
	stats.splits += 1
	return true

## omezený BFS v uzlu id od a (bez pásma skip): dosáhne všech cílů do budget navštívených pásem?
static func _reach(c: Dictionary, id: int, a: int, targets: Array, skip: int, budget: int, stats: Dictionary) -> bool:
	var want := {}
	for t in targets: want[int(t)] = true
	want.erase(a)
	if want.is_empty(): return true
	var nid: PackedInt32Array = c._nid; var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var seen := {a: true}; var qu := PackedInt32Array([a]); var k := 0
	while k < qu.size() and k < budget:
		var b := qu[k]; k += 1
		for j in range(c.ns[b], c.ns[b + 1]):
			var b2: int = c.nb[j]
			if b2 == skip or seen.has(b2) or nid[b2] != id or c.body[b2] == 0: continue
			if not _edge_ok(lo[b], hi[b], lo[b2], hi[b2], bcol[b] == bcol[b2]): continue
			seen[b2] = true; qu.append(b2)
			if want.has(b2):
				want.erase(b2)
				if want.is_empty(): stats.reach += k; return true
	stats.reach += k
	return false

static func _edge_ok(lo1: float, hi1: float, lo2: float, hi2: float, same: bool) -> bool:
	var olo := maxf(lo1, lo2); var ohi := minf(hi1, hi2)
	return (same and ohi >= olo - E) or ohi > olo + E

## ---------------- řízení varianty ----------------
## calls: [{ents, q, excl (dict povrchových sloupců), ex (dict sloupců řídicí mřížky)}]
static func solve_all(c: Dictionary, calls: Array, v: String, dz: float, stats: Dictionary) -> Array:
	var useA := has_flag(v, "A"); var useB := has_flag(v, "B"); var useC := has_flag(v, "C")
	var out := []
	for ci in calls.size():
		out.append(_one(c, calls, ci, useA, useB, useC, dz, stats))
	return out

static func _one(c: Dictionary, calls: Array, ci: int, useA: bool, useB: bool, useC: bool, dz: float, stats: Dictionary) -> Dictionary:
	var call: Dictionary = calls[ci]
	_p1key = ci
	if useB:
		var r = node_solve(c, call, ci, useA, dz, stats)
		if r != null: return r
		stats.fallback += 1
	stats.exact += 1
	var r2: Dictionary
	if not useA and not useC and not useB: r2 = F.solve(c, call.ents, call.q, call.excl)
	else: r2 = auto_X(c, call.ents, call.q, ex_of(c, call.x), useA, dz)   # převod excl jako F.solve (férově)
	if useC and not useB:
		var lists := [r2._body]
		if r2.has("_vis"): lists.append(r2._vis)
		r2._fp = footprint(c, lists)
	return r2

## výkop ve sloupci povrchu s na výšku hv (buňky povrchu); prev = výsledky před výkopem → nové výsledky
static func edit(c: Dictionary, calls: Array, prev: Array, s: int, hv: float, v: String, dz: float, stats: Dictionary) -> Array:
	var useA := has_flag(v, "A"); var useB := has_flag(v, "B"); var useC := has_flag(v, "C")
	var cc := F.col_of(c, s)
	var b0: int = c.cs[cc]; var b1: int = c.cs[cc + 1]
	var old_hi := PackedFloat64Array(); var old_body := PackedByteArray()
	for b in range(b0, b1): old_hi.append(c.hi[b]); old_body.append(c.body[b])
	var old_h := float(c.h[cc])
	c._useD = has_flag(v, "D")
	var hit := F.touched(c, {}, PackedInt32Array([s]), PackedFloat64Array([hv]))
	if c.has("_p1st"):   # E63 I: sloupec cc je pro všechny uložené sestupy špinavý
		for kst in c._p1st: c._p1st[kst].dirty[cc] = true
	if not useB and not useC:   # base / A: jako tok.gd – zásah → všechna volání znovu, jinak nic
		if not hit: return prev
		var o := []
		for ci in calls.size(): o.append(_one(c, calls, ci, useA, false, false, dz, stats))
		return o
	if useC and not useB:   # stopa volání
		var o2 := []
		for ci in calls.size():
			var fp: PackedByteArray = prev[ci].get("_fp", PackedByteArray())
			if fp.is_empty() or fp[cc] != 0: o2.append(_one(c, calls, ci, useA, false, true, dz, stats))
			else: o2.append(prev[ci]); stats.skipped += 1
		return o2
	# B / B+C: uzly dotčené sloupcem cc a sousedy
	_barr(c)
	var nid: PackedInt32Array = c._nid
	var W: int = c.W; var H: int = c.H
	var x := cc / H; var y := cc % H
	var cols := [cc]
	if x > 0: cols.append(cc - H)
	if x < W - 1: cols.append(cc + H)
	if y > 0: cols.append(cc - 1)
	if y < H - 1: cols.append(cc + 1)
	var hitn := {}
	for col in cols:
		for b in range(c.cs[col], c.cs[col + 1]):
			if nid[b] >= 0: hitn[nid[b]] = true
	for id in hitn:
		var nd: Dictionary = c._nodes[id]
		if useC and node_delta(c, id, cc, old_hi, old_body, stats):
			# preliv: znovu jen při zásahu stopy (s A přesná stopa, bez A celé těleso)
			for ci in nd.pre.keys():
				var fp: PackedByteArray = nd.pre[ci].fp
				if has_flag(v, "D") and not nd.pre[ci].vb.is_empty():   # E62: závislost na pásmech místo sloupcové stopy
					if _pre_hit(c, nd.pre[ci], cc, b0, old_hi, old_body, old_h): nd.pre.erase(ci); stats.d_hit = int(stats.get("d_hit", 0)) + 1
					else: stats.skipped += 1; stats.d_keep = int(stats.get("d_keep", 0)) + 1
				elif fp.is_empty() or fp[cc] != 0: nd.pre.erase(ci)
				else: stats.skipped += 1
		else:
			node_kill(c, id); stats.rebuilds += 1
	var o3 := []
	for ci in calls.size(): o3.append(_one(c, calls, ci, useA, true, useC, dz, stats))
	return o3

## shoda dvou výsledků (fyzikální pole; počet skoků k výstupu out[1] se neporovnává)
static func same(a: Dictionary, b: Dictionary, tol: float) -> String:
	for k in ["leak", "out_q", "z_out", "volume_m3", "lake_m3"]:
		var x := float(a.get(k, 0.0)); var y := float(b.get(k, 0.0))
		if absf(x - y) > tol * maxf(1.0, absf(y)): return "%s %.12f ≠ %.12f" % [k, x, y]
	if bool(a.closed) != bool(b.closed): return "closed"
	if String(a.get("rezim_tel", "")) != String(b.get("rezim_tel", "")): return "rezim %s ≠ %s" % [a.get("rezim_tel", ""), b.get("rezim_tel", "")]
	if int(a.cells) != int(b.cells): return "cells %d ≠ %d" % [a.cells, b.cells]
	var oa: Array = a.out; var ob: Array = b.out
	if oa.size() != ob.size(): return "out"
	if not oa.is_empty():
		if int(oa[2]) != int(ob[2]) or String(oa[3]) != String(ob[3]) or int(oa[4]) != int(ob[4]): return "out %s ≠ %s" % [str(oa), str(ob)]
	if not a.get("events_stale", false) and a.events.size() != b.events.size(): return "events"
	return ""
