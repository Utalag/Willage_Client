extends RefCounted
## E60 profil: kopie tok.update (tok.gd se nemění) s časy po fázích v PR.
const T = preload("res://scripts/voda/tok.gd")
static var PR := {}
static func update_prof(st: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array, src_new: PackedFloat64Array, margin: int) -> Dictionary:
	var t0 := Time.get_ticks_usec(); PR.t0 = t0
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
				if qx >= 0 and qy >= 0 and qx < W and qy < H and (T.wet(st, qx * H + qy) or st.pw[qx * H + qy] == 1): near_water = true
	if not near_water:
		# jen fill změněných buněk (aby příští porovnání sedělo), tok beze změny
		for i in ch: st.fill[i] = maxf(st.fill[i], st.hm[i])
		if st.has("_pend"): st._pend.append_array(ch)   # E51b: tůně kolem se dopočítají při příštím přepočtu
		return {"touched": 0, "window": 0, "expanded": 0, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": true, "cells": PackedInt32Array()}
	PR.okno0 = Time.get_ticks_usec()
	var x0 := W; var x1 := 0; var y0 := H; var y1 := 0
	for i in region:
		x0 = mini(x0, i / H); x1 = maxi(x1, i / H); y0 = mini(y0, i % H); y1 = maxi(y1, i % H)
	var m := margin; var expanded := 0
	var ins := T._scratch(st, "_ins")   # 1 = uvnitř okna, 2 = okraj okna (pevná fill), 0 = mimo
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
				if T._border(st, i):
					st.fill[i] = st.hm[i]; ring.append(i); ins[i] = 2
				elif edge:
					ring.append(i); ins[i] = 2
				else:
					ins[i] = 1; st.fill[i] = st.hm[i]
		order = T._flood(st, ins, ring, true)
		# okraj okna musí dál mít odtok dolů (soused s nižší fill); jinak by se změnila fill i za oknem → zvětšit okno
		var leak := false
		for r in ring:
			if T._border(st, r): continue
			var x := r / H; var y := r % H; var sup := false
			for d in 8:
				var qx: int = x + T.DX[d]; var qy: int = y + T.DY[d]
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
	PR.flood = Time.get_ticks_usec()
	var ot := PackedInt32Array(); ot.resize(order.size())
	for k in order.size(): ot[k] = st.to[order[k]]; T._to(st, order[k])
	# přepočet průtoku v okně (od nejvyšších), pak jen po proudu, dokud se mění
	var heap := []
	var dirty := PackedInt32Array(ch)
	for k in range(order.size() - 1, -1, -1):
		var i := order[k]
		T._cell(st, i); touched[i] = true; dirty.append(i)
		for j in [ot[k], st.to[i]]:
			if j >= 0 and not touched.has(j) and ins[j] == 0: T.RK._push(heap, -st.fill[j], j)
	for x in range(ax, bx + 1):   # vrátit nuly v pomocném poli
		for y in range(ay, by + 1): ins[x * H + y] = 0
	PR.d8_okno = Time.get_ticks_usec()
	var queued := {}
	while not heap.is_empty():
		var e := T.RK._pop(heap); var i: int = e[1]
		if queued.has(i): continue
		queued[i] = true; touched[i] = true; dirty.append(i)
		var dlt := T._cell(st, i)
		if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); T.RK._push(heap, -st.fill[st.to[i]], st.to[i])
	PR.po_proudu = Time.get_ticks_usec()
	# odtoky tůní: změněné přelivy přepočítat po proudu
	for it in 4:
		var chg := T._apply_drains(st, dirty)
		dirty = PackedInt32Array()
		if chg.is_empty(): break
		for i in chg: T.RK._push(heap, -st.fill[i], i)
		queued = {}
		while not heap.is_empty():
			var e := T.RK._pop(heap); var i: int = e[1]
			if queued.has(i): continue
			queued[i] = true; touched[i] = true; dirty.append(i)
			var dlt := T._cell(st, i)
			if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); T.RK._push(heap, -st.fill[st.to[i]], st.to[i])
	PR.odtoky = Time.get_ticks_usec()
	T._ponds_cached(st, dirty)   # pw a seznam tůní kolem posledních změn
	PR.tune = Time.get_ticks_usec()
	return {"touched": touched.size(), "window": order.size(), "expanded": expanded, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": false,
		"cells": PackedInt32Array(touched.keys())}   # E51: dotčené sloupce (přeplánování událostí)
