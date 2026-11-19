extends RefCounted
## E67 (Jan 15:54–16:00): podzemní voda jako přetoky ve 3D nad pásmy ug_funkce (režim p67_rezim = "pretok").
## Voda od vstupu teče nejdřív DOLŮ (pásmo tělesa, které se dotýká zespodu ve stejném sloupci), jinak do stran do sousedních
## pásem s nižším dnem, rozdělená vahou perm × výška překryvu (jako D∞ na povrchu). Výstup ve výšce dna pásma (odkrytá stěna
## ostrova – p67_okraj, nižší povrch souseda) vezme celý průtok pásma. Stojatá voda („vana“) jen v uzavřené misce bez nižšího
## výstupu: priority-flood ze dna pasti (klíč max(hladina, spodek překryvu), výstupy F._outs) stoupá do prvního výstupu nebo
## do prahu, za kterým je pásmo s nižším dnem mimo past → past plná po práh, přebytek (průtok − průsak) teče dál od prahu.
## Pasti, které se při stoupání potkají, se spojí (fill-spill-merge). Ustálený stav, žádná simulace po krocích; časy plnění
## pastí = objem / čistý průtok. Pořadí: halda (hodnota, id) → výsledek nezávisí na pořadí sousedů ani vstupů.
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const HP = preload("res://scripts/alg64/heap64.gd")
const E := 1e-6

static func _perm(c: Dictionary, b: int, t: Dictionary) -> float:
	var m: int = c.mat[b]
	if m == 0: return 1.0
	return maxf(float(t.get(m, [0.0])[0]), 0.01)

## pásmo tělesa přímo pod b ve stejném sloupci (dotýká se dna b), nejvyšší; -1 = žádné
static func _below(c: Dictionary, b: int) -> int:
	var cc: int = c.bcol[b]; var lo: float = c.lo[b]; var best := -1
	for b2 in range(c.cs[cc], c.cs[cc + 1]):
		if b2 == b or c.body[b2] == 0: continue
		if float(c.lo[b2]) < lo - E and float(c.hi[b2]) >= lo - E and (best < 0 or float(c.hi[b2]) > float(c.hi[best])): best = b2
	return best

static func solve(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var t := VS.table()
	var NB: int = c.lo.size()
	var trace := q <= 0.0
	var qe := q if not trace else 1.0
	var qb := {}                 # pásmo → průtok čekající na rozdělení
	var down := HP.new()         # sestup: nejvyšší dno první
	var ents := []
	for e in entries:
		if e >= 0: ents.append(e)
	for e in ents:
		qb[e] = float(qb.get(e, 0.0)) + qe / ents.size(); down.push(float(c.lo[e]), e)
	var wet := {}                # mokrá pásma sestupu (film u dna)
	var pit_of := {}             # pásmo → index pasti
	var pits := []               # {bands, level, q_in, leak, over, typ: "prah"|"vystup"|"nenaplni", tgt, out, merged}
	var outs := {}               # "typ|sloupec" → [z, typ, sloupec, q, pásmo]
	var guard := 0
	var gmax := 40 * NB + 1000
	while down.size() > 0 and guard < gmax:
		guard += 1
		var b := down.pop()
		var f := float(qb.get(b, 0.0))
		if f <= 1e-12: qb[b] = 0.0; continue
		qb[b] = 0.0
		if pit_of.has(b):
			_pit_add(c, pits, _root(pits, int(pit_of[b])), f, qb, down, outs)
			continue
		wet[b] = true
		var lo: float = c.lo[b]
		# 1) výstup ve výšce dna (stěna ostrova / nižší povrch souseda) – nejnižší, při shodě nejmenší sloupec
		var bo := []
		for o in F._outs(c, b, ex):
			if float(o[0]) <= lo + E and (bo.is_empty() or float(o[0]) < float(bo[0]) - E or (absf(float(o[0]) - float(bo[0])) <= E and int(o[2]) < int(bo[2]))): bo = o
		if not bo.is_empty():
			_out_add(outs, bo, f, b); continue
		# 2) dolů
		var bl := _below(c, b)
		if bl >= 0:
			qb[bl] = float(qb.get(bl, 0.0)) + f; down.push(float(c.lo[bl]), bl); continue
		# 3) do stran do pásem s nižším dnem, váha perm × výška překryvu
		var cand := []; var ws := 0.0
		for nb in F._nbrs(c, b):
			var b2: int = nb[0]
			if int(c.bcol[b2]) == int(c.bcol[b]) or float(c.lo[b2]) >= lo - E: continue
			var w := _perm(c, b2, t) * maxf(float(nb[2]) - float(nb[1]), 0.01)
			cand.append([b2, w]); ws += w
		if ws > 0.0:
			cand.sort_custom(func(a, b3): return a[0] < b3[0])
			for e in cand:
				var b2: int = e[0]
				qb[b2] = float(qb.get(b2, 0.0)) + f * float(e[1]) / ws; down.push(float(c.lo[b2]), b2)
			continue
		# 4) dno pasti
		_pit_fill(c, pits, pit_of, b, f, qb, down, outs, ex)
	return _result(c, entries, q, trace, wet, pits, outs, t0, guard >= gmax)

## kam steče voda z pásma s (bez průtoku): koncová pásma sestupu (dno pasti / pásmo s výstupem ve výšce dna)
static func _probe(c: Dictionary, s: int, ex: Dictionary) -> Array:
	var seen := {s: true}; var st := [s]; var term := []
	while not st.is_empty() and seen.size() < 200000:
		var b: int = st.pop_back()
		var lo: float = c.lo[b]
		var fl := false
		for o in F._outs(c, b, ex):
			if float(o[0]) <= lo + E: fl = true; break
		if fl: term.append(-1 - b); continue
		var bl := _below(c, b)
		if bl >= 0:
			if not seen.has(bl): seen[bl] = true; st.append(bl)
			continue
		var any := false
		for nb in F._nbrs(c, b):
			var b2: int = nb[0]
			if int(c.bcol[b2]) == int(c.bcol[b]) or float(c.lo[b2]) >= lo - E: continue
			any = true
			if not seen.has(b2): seen[b2] = true; st.append(b2)
		if not any: term.append(b)
	return term

static func _root(pits: Array, i: int) -> int:
	while int(pits[i].merged) >= 0: i = int(pits[i].merged)
	return i

static func _out_add(outs: Dictionary, o: Array, f: float, b: int) -> void:
	var k := "%s|%d" % [String(o[1]), int(o[2])]
	if not outs.has(k): outs[k] = [float(o[0]), String(o[1]), int(o[2]), 0.0, b]
	outs[k][3] = float(outs[k][3]) + f

## další průtok do už vyřešené pasti: přebytek nad průsakem jde za práh / do výstupu
static func _pit_add(c: Dictionary, pits: Array, i: int, f: float, qb: Dictionary, down, outs: Dictionary) -> void:
	var p: Dictionary = pits[i]
	var old := maxf(float(p.q_in) - float(p.leak), 0.0)
	p.q_in = float(p.q_in) + f
	var dlt := maxf(float(p.q_in) - float(p.leak), 0.0) - old
	if dlt <= 1e-12: return
	if p.typ == "nenaplni": p.typ = String(p.get("typ_full", "uzavrena"))
	if not p.out.is_empty(): _out_add(outs, p.out, dlt, -1)
	elif int(p.tgt) >= 0:
		var g: int = p.tgt
		qb[g] = float(qb.get(g, 0.0)) + dlt; down.push(float(c.lo[g]), g)

## priority-flood ze dna pasti b (jako F._solve_preliv), práh = pásmo s nižším dnem, dosažené shora
static func _pit_fill(c: Dictionary, pits: Array, pit_of: Dictionary, b: int, f: float, qb: Dictionary, down, outs: Dictionary, ex: Dictionary) -> void:
	var NB: int = c.lo.size()
	var cur := pits.size()
	var p := {"bands": PackedInt32Array(), "level": float(c.lo[b]), "q_in": f, "leak": 0.0, "typ": "", "tgt": -1, "out": [], "merged": -1, "floor": float(c.lo[b])}
	pits.append(p)
	var h := HP.new()
	var od := []                 # výstupy jako položky haldy (id NB + i)
	var inp := {}
	h.push(-float(c.lo[b]), b)
	var L := float(c.lo[b])
	while h.size() > 0:
		var key := -h.top_v()
		var id := h.pop()
		if id >= NB:
			p.out = od[id - NB]; L = maxf(L, key); p.typ = "vystup"; break
		if inp.has(id): continue
		if pit_of.has(id):
			var j := _root(pits, int(pit_of[id]))
			if j != cur:
				if key >= float(pits[j].level) - E:   # spojení s dřívější pastí: její pásma do této, hladina stoupá dál
					var pj: Dictionary = pits[j]
					pj.merged = cur
					p.q_in = float(p.q_in) + float(pj.q_in) - maxf(float(pj.q_in) - float(pj.leak), 0.0)
					for b2 in pj.bands:
						inp[b2] = true; pit_of[b2] = cur; p.bands.append(b2)
						for o in F._outs(c, b2, ex):
							od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
						for nb in F._nbrs(c, b2):
							if not inp.has(int(nb[0])): h.push(-maxf(key, float(nb[1])), int(nb[0]))
					continue
				# práh do pasti s vyšší hladinou: přeteče do ní – ledaže ta přetéká zpět sem (vzájemný přeliv → spojit)
				var back := false
				if int(pits[j].tgt) >= 0:
					for tb in _probe(c, int(pits[j].tgt), ex):
						if inp.has(tb) or tb == b: back = true
				if back:
					var pj2: Dictionary = pits[j]
					pj2.merged = cur
					p.q_in = float(p.q_in) + float(pj2.q_in) - maxf(float(pj2.q_in) - float(pj2.leak), 0.0)
					for b2 in pj2.bands:
						inp[b2] = true; pit_of[b2] = cur; p.bands.append(b2)
						for o in F._outs(c, b2, ex):
							od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
						for nb in F._nbrs(c, b2):
							if not inp.has(int(nb[0])): h.push(-maxf(key, float(nb[1])), int(nb[0]))
					L = maxf(L, float(pj2.level))
					continue
				p.tgt = id; p.typ = "prah"; L = maxf(L, key); break
		if id != b and float(c.lo[id]) < key - E:   # dno pod hladinou a pásmo do pasti nepatří → práh, přeliv dál
			var ret := true                         # ...ledaže by voda z něj stekla jen zpět do této pasti (pak k ní patří)
			for tb in _probe(c, id, ex):
				if not (inp.has(tb) or tb == b): ret = false; break
			if not ret:
				p.tgt = id; p.typ = "prah"; L = maxf(L, key); break
		inp[id] = true; pit_of[id] = cur; p.bands.append(id)
		L = maxf(L, key)
		for o in F._outs(c, id, ex):
			od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
		for nb in F._nbrs(c, id):
			if not inp.has(int(nb[0])): h.push(-maxf(key, float(nb[1])), int(nb[0]))
	if p.typ == "": p.typ = "uzavrena"
	p.level = L
	var lk := 0.0
	for b2 in p.bands: lk += F._leak(c, b2, L)
	p.leak = lk
	var over := maxf(float(p.q_in) - lk, 0.0)
	if over <= 0.0: p.typ_full = p.typ; p.typ = "nenaplni"; return
	if not p.out.is_empty(): _out_add(outs, p.out, over, -1)
	elif int(p.tgt) >= 0:
		var g: int = p.tgt
		qb[g] = float(qb.get(g, 0.0)) + over; down.push(float(c.lo[g]), g)

static func _result(c: Dictionary, entries: PackedInt32Array, q: float, trace: bool, wet: Dictionary, pits: Array, outs: Dictionary, t0: int, cut: bool) -> Dictionary:
	var comp := PackedInt32Array(); var vol := 0.0; var lake := 0.0; var leak := 0.0; var zmin := INF
	var pl := []
	var qs := 1.0 if not trace else 0.0
	for i in pits.size():
		var p: Dictionary = pits[i]
		if int(p.merged) >= 0: continue
		var v := 0.0
		for b in p.bands:
			var top := minf(float(c.hi[b]), float(p.level)); var w := top - float(c.lo[b])
			comp.append(b); zmin = minf(zmin, float(c.lo[b]))
			if w > E:
				var pa: float = float(c.por[b]) * float(c.A)
				v += pa * w
				if int(c.mat[b]) == 0: lake += pa * w
				var cc: int = c.bcol[b]; c.wt[cc] = maxf(c.wt[cc], top)
		vol += v; leak += float(p.leak) * qs
		var net := float(p.q_in) - float(p.leak)
		pl.append({"hladina": float(p.level), "dno": float(p.floor), "pasem": p.bands.size(), "objem_m3": v, "typ": String(p.typ),
			"q_in": float(p.q_in) * qs, "cas_s": (v / (net * float(c.q_to_m3))) if net > 0.0 and not trace else -1.0, "bands": p.bands})
	var ol := []
	for k in outs: ol.append(outs[k])
	ol.sort_custom(func(a, b): return float(a[3]) > float(b[3]) or (float(a[3]) == float(b[3]) and int(a[2]) < int(b[2])))
	var oq := 0.0
	for o in ol: oq += float(o[3]) * qs
	var out := []
	var o67 := []
	for o in ol:
		var cs := F._col_s(c, int(o[2]), String(o[1]) == "okraj")
		o67.append([float(o[0]), String(o[1]), cs, float(o[3]) * qs, int(o[4])])
	if not ol.is_empty(): out = [float(ol[0][0]), 0, int(ol[0][4]), String(ol[0][1]), o67[0][2]]
	var wl := PackedInt32Array()
	for b in wet: wl.append(b)
	wl.sort()
	# stopa: sloupce navštívených pásem (mokrá + pasti); výkop zasáhne výsledek jen ve stopě nebo u ní (ug58.edit)
	var fp := PackedByteArray(); fp.resize(int(c.W) * int(c.H))
	for b in wl: fp[int(c.bcol[b])] = 1
	for b in comp: fp[int(c.bcol[b])] = 1
	var mem := F.Members.new(); mem.ctx = c; mem.id = c.comp[entries[0]] if not entries.is_empty() and entries[0] >= 0 else -1
	var zo := float(ol[0][0]) if not ol.is_empty() else (float(pl[0].hladina) if not pl.is_empty() else 0.0)
	var closed := ol.is_empty()
	var nf := (q - leak) <= 0.0
	return {"cells": comp.size() + wl.size(), "q_in": q, "leak": minf(leak, q), "zmin": zmin, "z_out": zo, "out": out, "events": [],
		"volume_m3": vol, "never_fills": nf, "out_q": oq if not closed else 0.0, "closed": closed, "lake_m3": lake, "members": mem,
		"path": wl, "lake": PackedInt32Array(), "comp_ids": comp, "rezim_tel": "pretok", "pits67": pl, "outs67": o67, "wet67": wl,
		"ms67": (Time.get_ticks_usec() - t0) / 1000.0, "cut67": cut, "_fp67": fp}
