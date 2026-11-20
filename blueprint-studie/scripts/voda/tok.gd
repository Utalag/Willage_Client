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
	if springs: return {"thr": float(p.strz_thr_q), "cap": float(p.ponor_cap_q), "inf": float(p.ponor_inf_q), "perm_min": float(p.ponor_perm), "springs": true, "pit_q": float(p.pit_drain_q), "cell_m2": pow(float(p.get("voda_cell_m", 0.5)), 2.0), "u_m": float(p.get("voda_cell_m", 0.5)),
		"q73": bool(p.get("p73_pritok", false)), "v73": bool(p.get("p73_vyver", false)), "v74": bool(p.get("p74_vyzvednout", false)), "h74": bool(p.get("p74_hladina", true))}
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
static func _flood(st: Dictionary, inside: PackedByteArray, seeds: PackedInt32Array, local := false) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var fill: PackedFloat64Array = st.fill; var hm: PackedFloat64Array = st.hm; var wall: PackedByteArray = st.wall
	var done: PackedByteArray
	if local: done = _scratch(st, "_done")   # E51b: sdílené pole, po použití se vynulují jen navštívené
	else: done = PackedByteArray(); done.resize(W * H)
	if FLOOD_DZ > 0.0: return _flood_bq(st, inside, seeds, local, done)
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
	if local:
		for i in seeds: done[i] = 0
		for i in order: done[i] = 0
	return order

## E58 A (výchozí vypnuto): FLOOD_DZ > 0 → kbelíková fronta (alg58/bq58.gd), stejné pořadí (fill, index) jako halda
static var FLOOD_DZ := 0.0
static func _flood_bq(st: Dictionary, inside: PackedByteArray, seeds: PackedInt32Array, local: bool, done: PackedByteArray) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var fill: PackedFloat64Array = st.fill; var hm: PackedFloat64Array = st.hm; var wall: PackedByteArray = st.wall
	var k0 := INF
	for i in seeds: k0 = minf(k0, fill[i])
	var bq = load("res://scripts/alg58/bq58.gd").new(FLOOD_DZ, k0 if k0 < INF else 0.0)
	for i in seeds: bq.push(fill[i], i); done[i] = 1
	var order := PackedInt32Array()
	while not bq.empty():
		var e: Array = bq.pop(); var i: int = e[1]
		order.append(i)
		var x := i / H; var y := i % H
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if done[j] == 1 or wall[j] == 1 or inside[j] == 0: continue
			done[j] = 1; fill[j] = maxf(hm[j], fill[i] + EPS); bq.push(fill[j], j)
	if local:
		for i in seeds: done[i] = 0
		for i in order: done[i] = 0
	return order

## E51b: znovupoužitelné pomocné pole velikosti mřížky (nulové; kdo ho použije, vrátí nuly jen tam, kam psal)
static func _scratch(st: Dictionary, key: String) -> PackedByteArray:
	if not st.has(key):
		var a := PackedByteArray(); a.resize(st.W * st.H); st[key] = a
	return st[key]

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
		if _apply_drains(st, null).size() == 0: break
		for k in range(order.size() - 1, -1, -1): _cell(st, order[k])
	pond_mask(st)
	return {"ms": (Time.get_ticks_usec() - t0) / 1000.0, "cells": order.size()}

static func wet(st: Dictionary, i: int) -> bool:
	return st.ain[i] > 0.0 or st.eff[i] > 0.0

## lokální přepočet po změně terénu ve sloupcích ch na výšky hv (a stavu pramenů v src_new)
## E51b (Jan 22:09): skutečně lokální – okno + okraj, pomocná pole se znovu používají a nulují jen zapsané buňky,
## tůně (seznam, pw) se přepočtou jen kolem dotčených sloupců, odtoky tůní jen ze změněných položek. Výsledek beze změny.
static func update(st: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array, src_new: PackedFloat64Array, margin: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var W: int = st.W; var H: int = st.H; var n := W * H
	var touched := {}
	var region := ch.duplicate()
	if src_new != st.src:
		for i in n:
			if src_new[i] != st.src[i]: region.append(i)
	for k in ch.size(): st.hm[ch[k]] = hv[k]
	st.src = src_new
	if st.has("ug_cache") and st.get("ug") != null and st.ug.has("impl"):   # E52 varianta podzemí: sama pozná dotčené těleso
		if st.ug.impl.touched(st.ug, st.ug_cache, ch, hv): st.ug_cache.clear()
	elif st.has("ug_cache") and st.get("ug") != null:   # změna nad podzemním tělesem → těleso spočítat znovu
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
		if st.has("_pend"): st._pend.append_array(ch)   # E51b: tůně kolem se dopočítají při příštím přepočtu
		return {"touched": 0, "window": 0, "expanded": 0, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": true, "cells": PackedInt32Array()}
	var x0 := W; var x1 := 0; var y0 := H; var y1 := 0
	for i in region:
		x0 = mini(x0, i / H); x1 = maxi(x1, i / H); y0 = mini(y0, i % H); y1 = maxi(y1, i % H)
	var m := margin; var expanded := 0
	var ins := _scratch(st, "_ins")   # 1 = uvnitř okna, 2 = okraj okna (pevná fill), 0 = mimo
	var ring := PackedInt32Array(); var order := PackedInt32Array()
	var ax := 0; var bx := 0; var ay := 0; var by := 0
	var saved := PackedFloat64Array()   # fill obdélníku okna před změnou (pro zvětšení okna)
	while true:
		ring = PackedInt32Array()
		ax = maxi(x0 - m, 0); bx = mini(x1 + m, W - 1); ay = maxi(y0 - m, 0); by = mini(y1 + m, H - 1)
		saved.resize((bx - ax + 1) * (by - ay + 1))
		var k := 0
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				saved[k] = st.fill[i]; k += 1
				if st.wall[i] == 1: continue
				var edge := (x == ax and ax > 0) or (x == bx and bx < W - 1) or (y == ay and ay > 0) or (y == by and by < H - 1)
				if _border(st, i):
					st.fill[i] = st.hm[i]; ring.append(i); ins[i] = 2
				elif edge:
					ring.append(i); ins[i] = 2
				else:
					ins[i] = 1; st.fill[i] = st.hm[i]
		order = _flood(st, ins, ring, true)
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
		k = 0
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				if ins[i] == 1: st.fill[i] = saved[k]
				ins[i] = 0; k += 1
		m *= 2; expanded += 1
	var ot := PackedInt32Array(); ot.resize(order.size())
	for k in order.size(): ot[k] = st.to[order[k]]; _to(st, order[k])
	# přepočet průtoku v okně (od nejvyšších), pak jen po proudu, dokud se mění
	var heap := []
	var dirty := PackedInt32Array(ch)
	for k in range(order.size() - 1, -1, -1):
		var i := order[k]
		_cell(st, i); touched[i] = true; dirty.append(i)
		for j in [ot[k], st.to[i]]:
			if j >= 0 and not touched.has(j) and ins[j] == 0: RK._push(heap, -st.fill[j], j)
	for x in range(ax, bx + 1):   # vrátit nuly v pomocném poli
		for y in range(ay, by + 1): ins[x * H + y] = 0
	var queued := {}
	while not heap.is_empty():
		var e := RK._pop(heap); var i: int = e[1]
		if queued.has(i): continue
		queued[i] = true; touched[i] = true; dirty.append(i)
		var dlt := _cell(st, i)
		if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); RK._push(heap, -st.fill[st.to[i]], st.to[i])
	# odtoky tůní: změněné přelivy přepočítat po proudu
	for it in 4:
		var chg := _apply_drains(st, dirty)
		dirty = PackedInt32Array()
		if chg.is_empty(): break
		for i in chg: RK._push(heap, -st.fill[i], i)
		queued = {}
		while not heap.is_empty():
			var e := RK._pop(heap); var i: int = e[1]
			if queued.has(i): continue
			queued[i] = true; touched[i] = true; dirty.append(i)
			var dlt := _cell(st, i)
			if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); RK._push(heap, -st.fill[st.to[i]], st.to[i])
	_ponds_cached(st, dirty)   # pw a seznam tůní kolem posledních změn
	return {"touched": touched.size(), "window": order.size(), "expanded": expanded, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": false,
		"cells": PackedInt32Array(touched.keys())}   # E51: dotčené sloupce (přeplánování událostí)

## pw = 1 pro sloupce mokrých tůní (prohlubeň, do které teče voda); suché prohlubně se nepočítají
static func pond_mask(st: Dictionary) -> void:
	_ponds_cached(st, null)

## E51b: seznam tůní (jako ponds(…, false)) a pw udržované lokálně. dirty = null → celý přepočet; jinak jen tůně
## dotčené změněnými sloupci (a jejich 8 sousedy). Tůň = souvislá oblast od nejmenšího indexu (stejné pořadí jako ponds()).
static func _ponds_cached(st: Dictionary, dirty) -> Array:
	var n: int = st.W * st.H
	var cm2 := float(st.L.get("cell_m2", 0.25)); var um := float(st.L.get("u_m", 0.5))
	if dirty == null or not st.has("_pd"):
		var pw := PackedByteArray(); pw.resize(n)
		var pk := PackedInt32Array(); pk.resize(n); pk.fill(-1)
		var pd := {}
		for x in ponds(st, cm2, um, false):
			var key: int = x.cells[0]
			pd[key] = x
			for c in x.cells: pk[c] = key
			if not x["suchá"]:
				for c in x.cells:
					if st.fill[c] >= st.hm[c] + 0.1: pw[c] = 1   # kreslí se a počítá jako „u vody“ až od 5 cm
		st.pw = pw; st._pk = pk; st._pd = pd; st._pend = PackedInt32Array()
	else:
		var allc: PackedInt32Array = st.get("_pend", PackedInt32Array())
		allc.append_array(dirty)
		st._pend = PackedInt32Array()
		if not allc.is_empty(): _ponds_refresh(st, allc, cm2, um)
	var keys: Array = st._pd.keys(); keys.sort()
	var out := []
	for k in keys: out.append(st._pd[k])
	return out

static func _pwet(st: Dictionary, j: int) -> bool:
	return st.wall[j] == 0 and st.fill[j] > st.hm[j] + 0.01

static func _pond_drop(st: Dictionary, key: int, seeds: Dictionary) -> void:
	var pk: PackedInt32Array = st._pk; var pw: PackedByteArray = st.pw
	for c in st._pd[key].cells: pk[c] = -1; pw[c] = 0; seeds[c] = true
	st._pd.erase(key)

static func _ponds_refresh(st: Dictionary, dirty: PackedInt32Array, cm2: float, um: float) -> void:
	var W: int = st.W; var H: int = st.H
	var pk: PackedInt32Array = st._pk; var pw: PackedByteArray = st.pw
	# tvar tůní se mění jen tam, kde změněná buňka přešla mokrá ↔ suchá (pk ≥ 0 = byla mokrá); jinak stačí přepočítat
	# přítok, přeliv, dno a odtok tůně na stejných buňkách (bez BFS)
	var seeds := {}; var hard := {}; var soft := {}
	for c in dirty:
		var flip: bool = (pk[c] >= 0) != _pwet(st, c)
		if flip: seeds[c] = true
		var x := c / H; var y := c % H
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx := x + dx; var qy := y + dy
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if pk[j] >= 0:
					if flip: hard[pk[j]] = true
					elif dx == 0 and dy == 0: soft[pk[j]] = true
	for key in soft:
		if hard.has(key) or not st._pd.has(key): continue
		var comp: PackedInt32Array = st._pd[key].cells
		var x := _pond_dict(st, comp, cm2, um, false, 0.001)
		st._pd[key] = x
		var wp: bool = not x["suchá"]
		for c in comp: pw[c] = 1 if wp and st.fill[c] >= st.hm[c] + 0.1 else 0
	for key in hard:
		if st._pd.has(key): _pond_drop(st, key, seeds)
	var seen := _scratch(st, "_seen")
	var marked := PackedInt32Array(); var mins := []
	for s in seeds:
		if seen[s] == 1 or not _pwet(st, s): continue
		var comp := PackedInt32Array([s]); seen[s] = 1; var k := 0; var mn: int = s
		while k < comp.size():
			var i := comp[k]; k += 1
			mn = mini(mn, i)
			var x := i / H; var y := i % H
			for d in 8:
				var qx: int = x + DX[d]; var qy: int = y + DY[d]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if seen[j] == 1 or not _pwet(st, j): continue
				if pk[j] >= 0: _pond_drop(st, pk[j], seeds)   # nedotčená tůň se napojila → přepočítat i ji
				seen[j] = 1; comp.append(j)
		marked.append_array(comp); mins.append(mn)
	for i in marked: seen[i] = 0
	marked = PackedInt32Array()
	for mn in mins:
		var comp := _pond_comp(st, mn, seen)
		marked.append_array(comp)
		var x := _pond_dict(st, comp, cm2, um, false, 0.001)
		st._pd[mn] = x
		for c in comp: pk[c] = mn
		if not x["suchá"]:
			for c in comp:
				if st.fill[c] >= st.hm[c] + 0.1: pw[c] = 1
	for i in marked: seen[i] = 0

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
## E52: modul podzemí (výchozí podzemi.gd; varianta v ctx.impl má stejné entry / solve + touched)
## E74 + Jan 2026-11-20 01:49 (p74_vyzvednout + p74_hladina): neobsazený povrchový výtok vodu ze světa nepouští.
## 1) těleso se vyřeší jako dřív (stejný klíč → bez přepínače otisky beze změny); 2) má-li neobsazený povrchový výtok,
## vyřeší se znovu se všemi neobsazenými povrchovými sloupci vyřazenými z výstupů → hladina stoupne a voda vyjde jen
## obsazeným pramenem nebo okrajem; jinak je těleso plné (uzavřené → tůně přetečou po povrchu). Přirozené výtoky z 1)
## zůstanou vykreslené (vyver74, q 0) a obsadí se jako v E74. Vrací [výsledek (kopie), klíč, [[sloupec, z]]].
static func solve74(st: Dictionary, vs: PackedInt32Array, q: float, excl0: Dictionary) -> Array:
	var sk := "s%s|%.9f|%d" % [str(vs), q, excl0.hash()]
	if not st.ug_cache.has(sk): st.ug_cache[sk] = _ugi(st).solve(st.ug, vs, q, excl0)
	var r: Dictionary = st.ug_cache[sk]
	if not (bool(st.L.get("v74", false)) and bool(st.L.get("h74", false))) or r.closed or float(r.out_q) <= 0.0: return [r.duplicate(), sk, []]
	var claim: Dictionary = st.get("claim74", {})
	var hid := []
	if r.has("outs67"):
		for o in r.outs67:
			if float(o[3]) > 0.0 and String(o[1]) == "povrch" and not claim.has(int(o[2])): hid.append([int(o[2]), float(o[0])])
	elif String(r.out[3]) == "povrch" and not claim.has(int(r.out[4])): hid.append([int(r.out[4]), float(r.out[0])])
	if hid.is_empty(): return [r.duplicate(), sk, []]
	var e0 := excl0.keys(); e0.sort()
	var ck := claim.keys(); ck.sort()
	var sk2 := "h%s|%s|%s|%s" % [str(vs), PackedFloat64Array([q]).to_byte_array().hex_encode(), str(e0), str(ck)]   # E83: přesný klíč
	if not st.ug_cache.has(sk2):
		var excl := excl0.duplicate()
		for i in st.W * st.H:
			if not claim.has(i): excl[i] = true
		st.ug_cache[sk2] = _ugi(st).solve(st.ug, vs, q, excl)
	return [st.ug_cache[sk2].duplicate(), sk2, hid]

static func _ugi(st: Dictionary):
	return st.ug.get("impl", UG)

## E73 (p73_pritok): výtokové buňky tůně (D8 cíl mimo tůň) → [Q = Σ ain, buňka s největším ain, [[buňka, ain]]]
static func _vyt73(st: Dictionary, comp: PackedInt32Array) -> Array:
	var Q := 0.0; var outlet := -1; var amax := -1.0; var vyt := []
	for i in comp:
		var j: int = st.to[i]
		if j >= 0 and st.wall[j] == 0 and st.fill[j] > st.hm[j] + 0.01: continue   # cíl v tůni (souvislá složka) → není výtok
		var a: float = st.ain[i]
		Q += a; vyt.append([i, a])
		if a > amax: amax = a; outlet = i
	return [Q, outlet, vyt]

## odtok tůně do podzemí: E73 p73_pritok → kapacita rozdělená na výtokové buňky poměrem přítoku, jinak celá na přelivu
static func _set_drain(st: Dictionary, x: Dictionary, wr: PackedInt32Array) -> void:
	if x.has("vyt"):
		var Q: float = x.q_lps
		for e in x.vyt:
			var i: int = e[0]
			var d: float = float(x.drain_lps) * float(e[1]) / Q if Q > 0.0 else 0.0
			if d > 0.0: st.extra[i] += d; wr.append(i)
		return
	st.extra[x.outlet] = x.drain_lps; wr.append(x.outlet)

## E73 (p73_vyver): tůně napájené pramenem z minulého kola (výtok pramene teče po D8 do tůně) → {přeliv tůně: [vstup v0 tělesa]}
static func _fed_map(st: Dictionary, prev_under: Array, wetp: Array) -> Dictionary:
	var cellp := {}
	for x in wetp:
		for c in x.cells: cellp[c] = int(x.outlet)
	var out := {}
	for u in prev_under:
		if String(u.typ) != "povrch" or not u.has("v0"): continue
		var i: int = int(u.exit); var g := 0
		while i >= 0 and g < 1000000:
			if cellp.has(i):
				var k: int = cellp[i]
				if not out.has(k): out[k] = []
				if not out[k].has(int(u.v0)): out[k].append(int(u.v0))
				break
			i = st.to[i]; g += 1
	return out

## E73: tůň x napájí pramen tělesa r0 (pramen z minulého kola vyšel z tělesa se vstupem v0 ∈ členové r0) → její buňky se
## z výstupů nevylučují (vývěr zůstává v tůni, kterou sám zavodnil; voda z tůně zároveň prosakuje zpět)
static func _fed73(st: Dictionary, x: Dictionary, r0: Dictionary, fed: Dictionary) -> bool:
	if fed.is_empty() or not fed.has(int(x.outlet)): return false
	for v0 in fed[int(x.outlet)]:
		if r0.members.has(int(v0)): return true
	return false

static func _apply_drains(st: Dictionary, dirty = null) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	# E51b: extra / src2 jsou nenulové jen na přelivech tůní a výtocích z podzemí → pamatují se jejich indexy
	if not st.has("_xn"):
		var xn0 := {}
		for i in W * H:
			if st.extra[i] != 0.0 or st.src2[i] != 0.0: xn0[i] = true
		st._xn = xn0
	var prev: Dictionary = st._xn
	var oldv := {}
	for i in prev:
		oldv[i] = [st.extra[i], st.src2[i]]; st.extra[i] = 0.0; st.src2[i] = 0.0
	var prev_under: Array = st.get("under", [])   # E73 p73_vyver: výstupy minulého kola
	st.under = []; st.ug_bodies = []; st.lost_deep = 0.0
	var wr := PackedInt32Array()   # zapsané indexy
	if float(st.L.get("pit_q", 0.0)) > 0.0:
		var wetp := _ponds_cached(st, dirty).filter(func(x): return not x["suchá"] and x.outlet >= 0 and x.drain_lps > 0.0)
		if st.get("ug") == null:   # E47c: podzemím k nejbližšímu okraji
			for x in wetp:
				_set_drain(st, x, wr)
				var o: int = x.outlet; var best := -1; var bd := 1e9
				if not st.has("_bl"):   # okrajové sloupce vzestupně (stejné pořadí jako průchod celou mřížkou)
					var bl := PackedInt32Array()
					for i in W * H:
						if st.wall[i] == 0 and _border(st, i): bl.append(i)
					st._bl = bl
				if not st.has("_nbc"): st._nbc = {}
				if st._nbc.has(o): best = st._nbc[o]   # nejbližší okraj k přelivu (okraj se nemění)
				else:
					for i in st._bl:
						var dd := Vector2(i / H - o / H, i % H - o % H).length()
						if dd < bd: bd = dd; best = i
					st._nbc[o] = best
				st.under.append({"from": o, "exit": best, "q": x.podzemi_lps, "z": x.dno - 4.0, "typ": "okraj"})
		else:   # E47d: po propustné vrstvě (podzemi.gd)
			var ents := []   # [v, pond]
			var fed: Dictionary = _fed_map(st, prev_under, wetp) if bool(st.L.get("v73", false)) else {}
			for x in wetp:
				var cols := Array(x.cells); cols.sort_custom(func(a, b): return st.hm[a] < st.hm[b])
				var v := -1
				for c in cols:
					v = _ugi(st).entry(st.ug, c)
					if v >= 0: break
				if v < 0:
					_set_drain(st, x, wr); st.lost_deep += x.podzemi_lps   # pod tůní není propustné těleso → do hloubky (nemodeluje se)
				else: ents.append([v, x])
			var done := {}
			for k in ents.size():
				if done.has(k): continue
				if not st.has("ug_cache"): st.ug_cache = {}
				var ck := "m%d" % ents[k][0]
				if not st.ug_cache.has(ck): st.ug_cache[ck] = _ugi(st).solve(st.ug, PackedInt32Array([ents[k][0]]), 0.0)
				var r0: Dictionary = st.ug_cache[ck]
				var grp := []
				for j in range(k, ents.size()):
					if not done.has(j) and r0.members.has(ents[j][0]): grp.append(j); done[j] = true
				var vs := PackedInt32Array(); var q := 0.0; var excl := {}
				for j in grp:
					vs.append(ents[j][0]); q += ents[j][1].podzemi_lps
					if _fed73(st, ents[j][1], r0, fed): continue   # E73 p73_vyver: tůň zavodněná pramenem tohoto tělesa – pramen v ní smí zůstat
					for c in ents[j][1].cells: excl[c] = true
				var s74 := solve74(st, vs, q, excl)   # E74 + Jan 01:49: neobsazený výtok zvedá hladinu tělesa (p74_hladina)
				var sk: String = s74[1]
				var r: Dictionary = s74[0]
				for hv in s74[2]: st.under.append({"v0": ents[grp[0]][0], "from": ents[grp[0]][1].outlet, "exit": int(hv[0]), "q": 0.0, "z": float(hv[1]), "typ": "vyver74"})
				for j in grp:
					var x: Dictionary = ents[j][1]
					if not r.closed: _set_drain(st, x, wr)   # uzavřené plné těleso nic nepřijímá → vše přeteče po povrchu
				if not r.closed and r.out_q > 0.0 and r.has("outs67"):   # E67 pretok: víc výstupů (prameny / okraj) s vlastním průtokem (E73: jako tok60)
					for o in r.outs67:
						var col67: int = o[2]
						if float(o[3]) <= 0.0: continue
						var ty67: String = o[1]
						if ty67 == "povrch" and bool(st.L.get("v74", false)) and not st.get("claim74", {}).has(col67): ty67 = "vyver74"   # E74: neobsazený výtok jen k vykreslení
						if ty67 == "povrch": st.src2[col67] += float(o[3]); wr.append(col67)
						st.under.append({"v0": ents[grp[0]][0], "from": ents[grp[0]][1].outlet, "exit": col67, "q": float(o[3]), "z": float(o[0]), "typ": ty67})
				elif not r.closed and r.out_q > 0.0:
					var col: int = r.out[4]
					var ty: String = r.out[3]
					if ty == "povrch" and bool(st.L.get("v74", false)) and not st.get("claim74", {}).has(col): ty = "vyver74"   # E74: neobsazený výtok jen k vykreslení
					if ty == "povrch": st.src2[col] += r.out_q; wr.append(col)
					st.under.append({"v0": ents[grp[0]][0], "from": ents[grp[0]][1].outlet, "exit": col, "q": r.out_q, "z": float(r.out[0]), "typ": ty})
				r.erase("members"); r.entries = vs; r.cache_key = sk
				st.ug_bodies.append(r)
	var chg := PackedInt32Array()
	var xn := {}
	for i in wr:
		if st.extra[i] != 0.0 or st.src2[i] != 0.0: xn[i] = true
	var cand := {}
	for i in prev: cand[i] = true
	for i in wr: cand[i] = true
	for i in cand:
		var o: Array = oldv.get(i, [0.0, 0.0])
		if float(o[0]) != st.extra[i] or float(o[1]) != st.src2[i]: chg.append(i)
	chg.sort()
	st._xn = xn
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
		out.append(_pond_dict(st, _pond_comp(st, s, seen), cell_m2, u_m, events, q_to_m3))
	return out

## souvislá tůň od buňky s (BFS, 8-sousedé), seen se označí
static func _pond_comp(st: Dictionary, s: int, seen: PackedByteArray) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var comp := PackedInt32Array([s]); seen[s] = 1; var k := 0
	while k < comp.size():
		var i := comp[k]; k += 1
		var x := i / H; var y := i % H
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if seen[j] == 1 or st.wall[j] == 1: continue
			if st.fill[j] > st.hm[j] + 0.01: seen[j] = 1; comp.append(j)
	return comp

static func _pond_dict(st: Dictionary, comp: PackedInt32Array, cell_m2: float, u_m: float, events: bool, q_to_m3: float) -> Dictionary:
	var q := 0.0; var lo := 1e9; var hi := -1e9
	for i in comp:   # přítok = největší průtok buňkou tůně (= co odtéká přelivem; voda přitéká i přes mělký okraj < 5 cm)
		q = maxf(q, st.ain[i]); lo = minf(lo, st.hm[i]); hi = maxf(hi, st.fill[i])
	var dr := drain(st, comp); var outlet := -1; var amax := -1.0
	for i in comp:
		if st.ain[i] > amax: amax = st.ain[i]; outlet = i
	var vy := []
	if bool(st.L.get("q73", false)):   # E73 p73_pritok: přítok = součet výtokových buněk
		var r73 := _vyt73(st, comp); q = r73[0]; outlet = r73[1]; vy = r73[2]
	var ev := fill_events(st, comp, lo, hi, q, dr, cell_m2, u_m, q_to_m3) if events else []
	var vol := 0.0
	for e in ev: vol = e.objem_m3
	var d := {"cells": comp, "q_lps": q, "drain_lps": dr, "hloubka_m": (hi - lo) * u_m, "objem_m3": vol, "udalosti": ev, "suchá": q <= 0.0,
		"nenaplni_se": q > 0.0 and dr >= q, "podzemi_lps": minf(dr, q), "preliv_lps": maxf(q - dr, 0.0), "outlet": outlet, "dno": lo}
	if not vy.is_empty(): d.vyt = vy
	return d
