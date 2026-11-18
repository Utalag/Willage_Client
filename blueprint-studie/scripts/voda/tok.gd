extends RefCounted
## E47c tok: uložené koryto na mřížce světa (index gx · H + gy, výšky v U). Voda jen z pramenů (src, l/s) nebo v režimu E47b z plochy (src = 1).
## Stav st = {hm, wall, W, H, mats, src, fill, to, ain (přítok), eff (odtok po ztrátách), sink, L, edge_out}.
##  route(st)          plný výpočet (priority-flood [20] + D8 + ztráty v ponorech)
##  update(st, ch, hv) změna terénu: suché okolí → nic; jinak lokální okno + jen po proudu, dokud se průtok mění (ustálení)
##  ponds(st)          tůně: po vrstvách U plocha, objem a čas naplnění z přítoku (události, žádné tiky)
## Plovoucí ostrov (edge_out): každý sloupec na okraji mapy vodu hned vypouští přes okraj (vodopád do mlhy), dál se nesimuluje.

const RK = preload("res://scripts/svet8/reky.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]
const EPS := 1e-3

static var _SOL := {}
static func _soluble(m: int) -> bool:
	if _SOL.is_empty():
		var HR = load("res://scripts/bp/horniny.gd")
		for k in ["cave_limestone", "deep_limestone", "dolomite", "limestone_outcrop", "gypsum", "rock_salt"]: _SOL[HR.id_of(k)] = true
	return _SOL.has(m)

## ztráty L = {thr, cap (kras naráz), inf (propustná · perm na sloupec), perm_min}
static func losses(p: Dictionary, springs: bool) -> Dictionary:
	if springs: return {"thr": float(p.strz_thr_q), "cap": float(p.ponor_cap_q), "inf": float(p.ponor_inf_q), "perm_min": float(p.ponor_perm), "springs": true, "pit_q": float(p.pit_drain_q), "cell_m2": pow(float(p.get("voda_cell_m", 0.5)), 2.0), "u_m": float(p.get("voda_cell_m", 0.5))}
	return {"thr": float(p.strz_thr), "cap": float(p.ponor_cap), "inf": float(p.ponor_inf), "perm_min": float(p.ponor_perm), "springs": false, "pit_q": 0.0}

static func make(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray, mats: PackedInt32Array, src: PackedFloat64Array, L: Dictionary, edge_out: bool) -> Dictionary:
	var n := W * H
	var st := {"hm": hm, "wall": wall, "W": W, "H": H, "mats": mats, "src": src, "L": L, "edge_out": edge_out}
	for k in ["fill", "ain", "eff", "extra", "src2"]:
		var a := PackedFloat64Array(); a.resize(n); st[k] = a
	var t := PackedInt32Array(); t.resize(n); t.fill(-1); st.to = t
	var s := PackedByteArray(); s.resize(n); st.sink = s
	return st

static func _border(st: Dictionary, i: int) -> bool:
	var x: int = i / st.H; var y: int = i % st.H
	return x == 0 or y == 0 or x == st.W - 1 or y == st.H - 1

## priority-flood na množině cells (null = celý svět); seeds = buňky s pevnou výškou fill (okraj mapy nebo okraj okna)
static func _flood(st: Dictionary, inside: PackedByteArray, seeds: PackedInt32Array) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var fill: PackedFloat64Array = st.fill; var hm: PackedFloat64Array = st.hm; var wall: PackedByteArray = st.wall
	var done := PackedByteArray(); done.resize(W * H)
	var heap := []
	for i in seeds: RK._push(heap, fill[i], i); done[i] = 1
	var order := PackedInt32Array()
	while not heap.is_empty():
		var e := RK._pop(heap); var i: int = e[1]
		order.append(i)
		var x := i / H; var y := i % H
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if done[j] == 1 or wall[j] == 1 or inside[j] == 0: continue
			done[j] = 1; fill[j] = maxf(hm[j], fill[i] + EPS); RK._push(heap, fill[j], j)
	return order

static func _to(st: Dictionary, i: int) -> void:
	var W: int = st.W; var H: int = st.H; var fill: PackedFloat64Array = st.fill
	st.to[i] = -1
	if st.edge_out and _border(st, i): return
	var x := i / H; var y := i % H; var best := 0.0
	for d in 8:
		var qx: int = x + DX[d]; var qy: int = y + DY[d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var j := qx * H + qy
		if st.wall[j] == 1: continue
		var s := (fill[i] - fill[j]) / (1.4142 if d >= 4 else 1.0)
		if s > best: best = s; st.to[i] = j

## přítok + ztráty jedné buňky (sousedé musí mít eff hotové)
static func _cell(st: Dictionary, i: int) -> float:
	var W: int = st.W; var H: int = st.H
	var a: float = st.src[i] + st.src2[i]   # src2 = výtok z podzemí (E47d)
	var x := i / H; var y := i % H
	for d in 8:
		var qx: int = x + DX[d]; var qy: int = y + DY[d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var j := qx * H + qy
		if st.to[j] == i: a += st.eff[j]
	st.ain[i] = a
	var L: Dictionary = st.L; var e := a; var sk := 0
	var in_pit: bool = st.fill[i] > st.hm[i] + 0.01
	if st.extra[i] > 0.0:   # odtok tůně do propustné vrstvy (Jan 19:48), uplatní se na přelivové buňce tůně
		var l0 := minf(a, st.extra[i])
		st.ain[i] = a; st.sink[i] = 3 if l0 >= a else 0
		var o0: float = st.eff[i]; st.eff[i] = a - l0
		return absf(st.eff[i] - o0)
	if a >= L.thr and not in_pit and not (L.springs and st.src[i] > 0.0):   # na buňce pramene a v tůni (má vlastní odtok) se neztrácí po buňkách
		var m: int = st.mats[i]; var l := 0.0
		if _soluble(m): l = minf(a, L.cap)
		else:
			var pm := float(VS.table().get(m, [0.0])[0])
			if pm >= L.perm_min: l = minf(a, L.inf * pm)
		e = a - l
		if e < L.thr and l > 0.0:
			sk = 2 if _soluble(m) else 1; e = 0.0
	st.sink[i] = sk
	var old: float = st.eff[i]
	st.eff[i] = e
	return absf(e - old)

static func route(st: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n: int = st.W * st.H
	var inside := PackedByteArray(); inside.resize(n); inside.fill(1)
	var seeds := PackedInt32Array()
	for i in n:
		st.fill[i] = st.hm[i]; st.eff[i] = 0.0
		if st.wall[i] == 0 and _border(st, i): seeds.append(i)
	var order := _flood(st, inside, seeds)
	for i in order: _to(st, i)
	for k in range(order.size() - 1, -1, -1): _cell(st, order[k])
	st.order = order
	for it in 4:   # povrch ↔ podzemí, dokud se odtoky tůní a výtoky z podzemí mění
		if _apply_drains(st).size() == 0: break
		for k in range(order.size() - 1, -1, -1): _cell(st, order[k])
	pond_mask(st)
	return {"ms": (Time.get_ticks_usec() - t0) / 1000.0, "cells": order.size()}

static func wet(st: Dictionary, i: int) -> bool:
	return st.ain[i] > 0.0 or st.eff[i] > 0.0

## lokální přepočet po změně terénu ve sloupcích ch na výšky hv (a stavu pramenů v src_new)
static func update(st: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array, src_new: PackedFloat64Array, margin: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var W: int = st.W; var H: int = st.H; var n := W * H
	var touched := {}
	var region := ch.duplicate()
	for i in n:
		if src_new[i] != st.src[i]: region.append(i)
	for k in ch.size(): st.hm[ch[k]] = hv[k]
	st.src = src_new
	if st.has("ug_cache") and st.get("ug") != null:   # změna nad podzemním tělesem → těleso spočítat znovu
		var NZ: int = st.ug.NZ
		for key in st.ug_cache.keys():
			var mem: Dictionary = st.ug_cache[key].get("members", {})
			for c in ch:
				if mem.has(c * NZ + int(st.ug.top[c]) - 1) or mem.has(c * NZ + int(st.ug.top[c]) - 2):
					st.ug_cache.clear(); break
			if st.ug_cache.is_empty(): break
	# suché okolí (± 1 sloupec) → nic se nesimuluje
	var near_water := region.size() > ch.size()   # pramen se otevřel / uzavřel → vždy přepočet
	for i in region:
		var x := i / H; var y := i % H
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx := x + dx; var qy := y + dy
				if qx >= 0 and qy >= 0 and qx < W and qy < H and (wet(st, qx * H + qy) or st.pw[qx * H + qy] == 1): near_water = true
	if not near_water:
		# jen fill změněných buněk (aby příští porovnání sedělo), tok beze změny
		for i in ch: st.fill[i] = maxf(st.fill[i], st.hm[i])
		return {"touched": 0, "window": 0, "expanded": 0, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": true}
	var x0 := W; var x1 := 0; var y0 := H; var y1 := 0
	for i in region:
		x0 = mini(x0, i / H); x1 = maxi(x1, i / H); y0 = mini(y0, i % H); y1 = maxi(y1, i % H)
	var m := margin; var expanded := 0
	var inside := PackedByteArray(); var ring := PackedInt32Array(); var order := PackedInt32Array()
	var old_to: PackedInt32Array = st.to.duplicate(); var old_fill: PackedFloat64Array = st.fill.duplicate()
	while true:
		inside = PackedByteArray(); inside.resize(n); ring = PackedInt32Array()
		var ax := maxi(x0 - m, 0); var bx := mini(x1 + m, W - 1); var ay := maxi(y0 - m, 0); var by := mini(y1 + m, H - 1)
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				if st.wall[i] == 1: continue
				inside[i] = 1
				var edge := (x == ax and ax > 0) or (x == bx and bx < W - 1) or (y == ay and ay > 0) or (y == by and by < H - 1)
				if _border(st, i):
					st.fill[i] = st.hm[i]; ring.append(i)
				elif edge:
					st.fill[i] = old_fill[i]; ring.append(i)
		for i in ring: inside[i] = 0
		for i in n:
			if inside[i] == 1: st.fill[i] = st.hm[i]
		order = _flood(st, inside, ring)
		# okraj okna musí dál mít odtok dolů (soused s nižší fill); jinak by se změnila fill i za oknem → zvětšit okno
		var leak := false
		for r in ring:
			if _border(st, r): continue
			var x := r / H; var y := r % H; var sup := false
			for d in 8:
				var qx: int = x + DX[d]; var qy: int = y + DY[d]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if st.wall[j] == 0 and st.fill[j] < st.fill[r] - 1e-9: sup = true; break
			if not sup: leak = true; break
		if not leak or (ax == 0 and ay == 0 and bx == W - 1 and by == H - 1): break
		for i in n: if inside[i] == 1: st.fill[i] = old_fill[i]
		m *= 2; expanded += 1
	for i in order: _to(st, i)
	# přepočet průtoku v okně (od nejvyšších), pak jen po proudu, dokud se mění
	var heap := []
	for k in range(order.size() - 1, -1, -1):
		var i := order[k]
		_cell(st, i); touched[i] = true
		for j in [old_to[i], st.to[i]]:
			if j >= 0 and not touched.has(j) and inside[j] == 0 and not ring.has(j): RK._push(heap, -st.fill[j], j)
	var queued := {}
	while not heap.is_empty():
		var e := RK._pop(heap); var i: int = e[1]
		if queued.has(i): continue
		queued[i] = true; touched[i] = true
		var dlt := _cell(st, i)
		if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); RK._push(heap, -st.fill[st.to[i]], st.to[i])
	# odtoky tůní: změněné přelivy přepočítat po proudu
	for it in 4:
		var chg := _apply_drains(st)
		if chg.is_empty(): break
		for i in chg: RK._push(heap, -st.fill[i], i)
		queued = {}
		while not heap.is_empty():
			var e := RK._pop(heap); var i: int = e[1]
			if queued.has(i): continue
			queued[i] = true; touched[i] = true
			var dlt := _cell(st, i)
			if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); RK._push(heap, -st.fill[st.to[i]], st.to[i])
	pond_mask(st)
	return {"touched": touched.size(), "window": order.size(), "expanded": expanded, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": false}

## pw = 1 pro sloupce mokrých tůní (prohlubeň, do které teče voda); suché prohlubně se nepočítají
static func pond_mask(st: Dictionary) -> void:
	var n: int = st.W * st.H
	var pw := PackedByteArray(); pw.resize(n)
	for x in ponds(st, float(st.L.get("cell_m2", 0.25)), float(st.L.get("u_m", 0.5)), false):
		if not x["suchá"]:
			for c in x.cells:
				if st.fill[c] >= st.hm[c] + 0.1: pw[c] = 1   # kreslí se a počítá jako „u vody“ až od 5 cm
	st.pw = pw

## propustnost prohlubně jako celku (Jan 19:48): D = Σ perm(buňka) · pit_q (kras = perm 1). Jednotky průtoku (l/s).
static func drain(st: Dictionary, comp: PackedInt32Array) -> float:
	var d := 0.0
	for i in comp:
		var m: int = st.mats[i]
		d += (1.0 if _soluble(m) else float(VS.table().get(m, [0.0])[0])) * float(st.L.get("pit_q", 0.0))
	return d

## události plnění po vrstvách: čas = objem vrstvy / (přítok − odtok); odtok ≥ přítok → nenaplní se (ponor), žádné události
static func fill_events(st: Dictionary, comp: PackedInt32Array, lo: float, hi: float, q: float, dr: float, cell_m2: float, u_m: float, q_to_m3: float) -> Array:
	var ev := []; var vol := 0.0; var t := 0.0; var lev := lo
	var net := q - dr
	while lev < hi - 0.01:   # hladina přelivu je o pár EPS (priority-flood) nad okrajem → zbytky < 0,01 U se slijí do poslední vrstvy
		var nl := minf(lev + 1.0, hi)
		if hi - nl < 0.01: nl = hi
		var area := 0
		for i in comp:
			if st.hm[i] < nl: area += 1
		var dv := area * cell_m2 * (nl - lev) * u_m
		vol += dv
		t = (t + dv / (net * q_to_m3)) if net > 0.0 else -1.0
		ev.append({"hladina_m": (nl - lo) * u_m, "plocha_m2": area * cell_m2, "objem_m3": vol, "cas_s": t})
		lev = nl
	return ev

## nastaví extra odtok na přelivu každé mokré tůně; podzemní voda vyjde na nejbližším okraji ostrova (vyvěračka ve stěně → vodopád do mlhy)
static func _apply_drains(st: Dictionary) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var old: PackedFloat64Array = st.extra.duplicate(); var old2: PackedFloat64Array = st.src2.duplicate()
	st.extra.fill(0.0); st.src2.fill(0.0); st.under = []; st.ug_bodies = []; st.lost_deep = 0.0
	if float(st.L.get("pit_q", 0.0)) > 0.0:
		var wetp := ponds(st, float(st.L.get("cell_m2", 0.25)), float(st.L.get("u_m", 0.5)), false).filter(func(x): return not x["suchá"] and x.outlet >= 0 and x.drain_lps > 0.0)
		if st.get("ug") == null:   # E47c: podzemím k nejbližšímu okraji
			for x in wetp:
				st.extra[x.outlet] = x.drain_lps
				var o: int = x.outlet; var best := -1; var bd := 1e9
				for i in W * H:
					if st.wall[i] == 0 and _border(st, i):
						var dd := Vector2(i / H - o / H, i % H - o % H).length()
						if dd < bd: bd = dd; best = i
				st.under.append({"from": o, "exit": best, "q": x.podzemi_lps, "z": x.dno - 4.0, "typ": "okraj"})
		else:   # E47d: po propustné vrstvě (podzemi.gd)
			var ents := []   # [v, pond]
			for x in wetp:
				var cols := Array(x.cells); cols.sort_custom(func(a, b): return st.hm[a] < st.hm[b])
				var v := -1
				for c in cols:
					v = UG.entry(st.ug, c)
					if v >= 0: break
				if v < 0:
					st.extra[x.outlet] = x.drain_lps; st.lost_deep += x.podzemi_lps   # pod tůní není propustné těleso → do hloubky (nemodeluje se)
				else: ents.append([v, x])
			var done := {}
			for k in ents.size():
				if done.has(k): continue
				if not st.has("ug_cache"): st.ug_cache = {}
				var ck := "m%d" % ents[k][0]
				if not st.ug_cache.has(ck): st.ug_cache[ck] = UG.solve(st.ug, PackedInt32Array([ents[k][0]]), 0.0)
				var r0: Dictionary = st.ug_cache[ck]
				var grp := []
				for j in range(k, ents.size()):
					if not done.has(j) and r0.members.has(ents[j][0]): grp.append(j); done[j] = true
				var vs := PackedInt32Array(); var q := 0.0; var excl := {}
				for j in grp:
					vs.append(ents[j][0]); q += ents[j][1].podzemi_lps
					for c in ents[j][1].cells: excl[c] = true
				var sk := "s%s|%.9f|%d" % [str(vs), q, excl.hash()]
				if not st.ug_cache.has(sk): st.ug_cache[sk] = UG.solve(st.ug, vs, q, excl)
				var r: Dictionary = st.ug_cache[sk].duplicate()
				for j in grp:
					var x: Dictionary = ents[j][1]
					if not r.closed: st.extra[x.outlet] = x.drain_lps   # uzavřené plné těleso nic nepřijímá → vše přeteče po povrchu
				if not r.closed and r.out_q > 0.0:
					var col: int = r.out[4]
					if r.out[3] == "povrch": st.src2[col] += r.out_q
					st.under.append({"from": ents[grp[0]][1].outlet, "exit": col, "q": r.out_q, "z": float(r.out[0]), "typ": r.out[3]})
				r.erase("members"); r.entries = vs; r.cache_key = sk
				st.ug_bodies.append(r)
	var chg := PackedInt32Array()
	for i in W * H:
		if old[i] != st.extra[i] or old2[i] != st.src2[i]: chg.append(i)
	return chg

## odtok přes okraj ostrova: [{gi, q}]
static func edge_falls(st: Dictionary) -> Array:
	var out := []
	if not st.edge_out: return out
	for i in st.W * st.H:
		if st.wall[i] == 0 and _border(st, i) and st.eff[i] > 0.0: out.append({"gi": i, "q": st.eff[i]})
	return out

## tůně: souvislé oblasti fill > hm; přítok Q (l/s) = odtoky okolí do tůně + prameny v ní. Události po vrstvách U = 0,5 m.
static func ponds(st: Dictionary, cell_m2 := 0.25, u_m := 0.5, events := true, q_to_m3 := 0.001) -> Array:
	var W: int = st.W; var H: int = st.H; var n := W * H
	var seen := PackedByteArray(); seen.resize(n)
	var out := []
	for s in n:
		if seen[s] == 1 or st.wall[s] == 1 or st.fill[s] <= st.hm[s] + 0.01: continue   # vodní těleso souvisle (> 5 mm); kreslí se jen hloubka ≥ 5 cm
		var comp := PackedInt32Array([s]); seen[s] = 1; var k := 0
		var inc := {}
		while k < comp.size():
			var i := comp[k]; k += 1
			var x := i / H; var y := i % H
			for d in 8:
				var qx: int = x + DX[d]; var qy: int = y + DY[d]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if seen[j] == 1 or st.wall[j] == 1: continue
				if st.fill[j] > st.hm[j] + 0.01: seen[j] = 1; comp.append(j)
		var inside := {}
		for i in comp: inside[i] = true
		var q := 0.0; var lo := 1e9; var hi := -1e9
		for i in comp:   # přítok = největší průtok buňkou tůně (= co odtéká přelivem; voda přitéká i přes mělký okraj < 5 cm)
			q = maxf(q, st.ain[i]); lo = minf(lo, st.hm[i]); hi = maxf(hi, st.fill[i])
		var dr := drain(st, comp); var outlet := -1; var amax := -1.0
		for i in comp:
			if st.ain[i] > amax: amax = st.ain[i]; outlet = i
		var ev := fill_events(st, comp, lo, hi, q, dr, cell_m2, u_m, q_to_m3) if events else []
		var vol := 0.0
		for e in ev: vol = e.objem_m3
		out.append({"cells": comp, "q_lps": q, "drain_lps": dr, "hloubka_m": (hi - lo) * u_m, "objem_m3": vol, "udalosti": ev, "suchá": q <= 0.0,
			"nenaplni_se": q > 0.0 and dr >= q, "podzemi_lps": minf(dr, q), "preliv_lps": maxf(q - dr, 0.0), "outlet": outlet, "dno": lo})
	return out
