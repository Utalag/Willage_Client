extends RefCounted
## E60: optimalizovaná kopie tok.update a odtoků tůní (tok.gd se nemění). Výsledek musí být bit po bitu stejný (tools/alg60_tok.gd).
const T = preload("res://scripts/voda/tok.gd")
static var PR := {}
static var M0 := 0   # E60: počáteční okraj okna (0 = margin jako tok.gd); okno se samo zvětší, když okraj neodvádí
static var KOLA := 4      # E68: nejvýš kol povrch ↔ podzemí v update (4 = dosavadní)
static var TOL := 0.0     # E68: konec smyčky, když se extra / src2 změní nejvýš o TOL l/s (0 = jen bitová shoda, dosavadní)
static var KOLO := {}     # E68: poslední update: {"kola", "zmena", "ustaleno", "cyklus"}
static var CYKLUS := false   # E68: smyčka se opakuje (stejný stav odtoků jako v dřívějším kole) → skončit v kanonickém členu cyklu

static var ACC := false      # E73 p73_zrychleni: skok smyčky podle posledních dvou přírůstků výtoků pramenů (src2)

## E73: zrychlení smyčky povrch ↔ podzemí. x = src2 na nenulových výtocích po kole; d1 = x_k − x_{k−1}, d2 = x_{k−1} − x_{k−2}.
## d1 = r · d2 na všech buňkách (stejné buňky): r < 1 → geometrická řada, skok na limitu x + d1 · r / (1 − r); r ≈ 1
## (lineární růst do kapacity) → skok x + d1 · J (J = 2, 4, 8 … do 1024). Vrací buňky, kde se src2 změnilo (pak se povrch
## dopočítá); další kolo spočítá skutečný stav ze skoku, konec až při bitové shodě (pevný bod).
static func acc_step(st: Dictionary, h: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ks: Array = []
	for i in st.get("_xn", {}):
		if st.src2[i] != 0.0: ks.append(i)
	ks.sort()
	var x := PackedFloat64Array()
	for i in ks: x.append(st.src2[i])
	if h.has("x2") and h.k1 == ks and h.k2 == ks and not ks.is_empty():
		var x1: PackedFloat64Array = h.x1; var x2: PackedFloat64Array = h.x2
		var n2 := 0.0; var dd := 0.0; var n1 := 0.0
		for k in ks.size():
			var d1 := x[k] - x1[k]; var d2 := x1[k] - x2[k]
			n2 += d2 * d2; dd += d1 * d2; n1 += d1 * d1
		if n2 > 1e-24 and n1 > 1e-24:
			var r := dd / n2; var res := 0.0
			for k in ks.size():
				var e := (x[k] - x1[k]) - r * (x1[k] - x2[k]); res += e * e
			if r > 0.0 and res <= 1e-12 * n1:
				var f := 0.0
				if r < 1.0 - 1e-6: f = r / (1.0 - r)
				else: f = float(h.get("J", 2.0)); h.J = minf(f * 2.0, 1024.0)
				for k in ks.size():
					var i: int = ks[k]
					st.src2[i] = maxf(x[k] + (x[k] - x1[k]) * f, 0.0); out.append(i)
				h.erase("x1"); h.erase("x2"); h.skoky = int(h.get("skoky", 0)) + 1
				return out
	if h.has("x1"): h.x2 = h.x1; h.k2 = h.k1
	h.x1 = x; h.k1 = ks
	return out

## E68: otisk stavu odtoků tůní a výtoků z podzemí (extra / src2 na nenulových indexech)
static func sig(st: Dictionary) -> String:
	var ks: Array = st.get("_xn", {}).keys(); ks.sort()
	var a := PackedFloat64Array(); var ix := PackedInt32Array()
	for i in ks: ix.append(i); a.append(st.extra[i]); a.append(st.src2[i])
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	h.update("xn".to_utf8_buffer())
	if not ix.is_empty(): h.update(ix.to_byte_array()); h.update(a.to_byte_array())
	return h.finish().hex_encode().substr(0, 16)

## E68: hlídání cyklu; vrací true = skončit (stav je kanonický člen cyklu: nejmenší otisk)
static func cyc_step(st: Dictionary, cs: Dictionary) -> bool:
	var sg := sig(st)
	if cs.has("min"):
		return sg == String(cs.min)
	if cs.seen.has(sg):
		var j: int = cs.seen[sg]
		var m := sg
		for k in range(j, cs.list.size()):
			if String(cs.list[k]) < m: m = String(cs.list[k])
		cs.min = m; cs.perioda = cs.list.size() - j
		return sg == m
	cs.seen[sg] = cs.list.size(); cs.list.append(sg)
	return false
static var FAST_POND := true   # E60: stejná tůň (stejné buňky) → propustnost dna (drain) se nepočítá znovu, materiály se výkopem nemění

## E60: jako tok._pond_dict(events = false) pro nezměněný tvar tůně; drain z minulého slovníku (stejné buňky, stejné pořadí součtu)
static func _pond_dict_soft(st: Dictionary, comp: PackedInt32Array, old: Dictionary) -> Dictionary:
	var ain: PackedFloat64Array = st.ain; var hm: PackedFloat64Array = st.hm; var fill: PackedFloat64Array = st.fill
	var q := 0.0; var lo := 1e9; var hi := -1e9; var outlet := -1; var amax := -1.0
	for i in comp:
		var a: float = ain[i]
		q = maxf(q, a); lo = minf(lo, hm[i]); hi = maxf(hi, fill[i])
		if a > amax: amax = a; outlet = i
	var dr: float = old.drain_lps
	var vy := []
	if bool(st.L.get("q73", false)):   # E73 p73_pritok: přítok = součet výtokových buněk (jako tok._pond_dict)
		var r73 := T._vyt73(st, comp); q = r73[0]; outlet = r73[1]; vy = r73[2]
	var um := float(st.L.get("u_m", 0.5))
	var d := {"cells": comp, "q_lps": q, "drain_lps": dr, "hloubka_m": (hi - lo) * um, "objem_m3": 0.0, "udalosti": [], "suchá": q <= 0.0,
		"nenaplni_se": q > 0.0 and dr >= q, "podzemi_lps": minf(dr, q), "preliv_lps": maxf(q - dr, 0.0), "outlet": outlet, "dno": lo}
	if not vy.is_empty(): d.vyt = vy
	return d

static var FAST_FLOOD := true   # E60: flood okna s haldou v packed polích (pořadí (fill, index) stejné jako reky.gd → stejný výsledek)

## E60: priority-flood okna jako tok._flood(local = true), halda ve dvou packed polích bez alokací na prvek
static func _flood60(st: Dictionary, inside: PackedByteArray, seeds: PackedInt32Array) -> PackedInt32Array:
	var W: int = st.W; var H: int = st.H
	var fill: PackedFloat64Array = st.fill; var hm: PackedFloat64Array = st.hm; var wall: PackedByteArray = st.wall
	var done := T._scratch(st, "_done")
	var hk := PackedFloat64Array(); var hi := PackedInt32Array(); var n := 0
	hk.resize(seeds.size() + 64); hi.resize(seeds.size() + 64)
	var order := PackedInt32Array()
	for s in seeds:
		done[s] = 1
		# push
		if n == hk.size(): hk.resize(n * 2); hi.resize(n * 2)
		var c := n; n += 1; var v: float = fill[s]
		while c > 0:
			var pa := (c - 1) >> 1
			if hk[pa] < v or (hk[pa] == v and hi[pa] < s): break
			hk[c] = hk[pa]; hi[c] = hi[pa]; c = pa
		hk[c] = v; hi[c] = s
	while n > 0:
		var i := hi[0]
		n -= 1
		if n > 0:   # pop: poslední prvek dolů
			var v: float = hk[n]; var id: int = hi[n]; var c := 0
			while true:
				var l := 2 * c + 1
				if l >= n: break
				var m := l
				var r := l + 1
				if r < n and (hk[r] < hk[l] or (hk[r] == hk[l] and hi[r] < hi[l])): m = r
				if v < hk[m] or (v == hk[m] and id < hi[m]): break
				hk[c] = hk[m]; hi[c] = hi[m]; c = m
			hk[c] = v; hi[c] = id
		order.append(i)
		var x := i / H; var y := i % H; var fi: float = fill[i] + T.EPS
		for d in 8:
			var qx: int = x + T.DX[d]; var qy: int = y + T.DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if done[j] == 1 or wall[j] == 1 or inside[j] == 0: continue
			done[j] = 1
			var fj: float = maxf(hm[j], fi); fill[j] = fj
			if n == hk.size(): hk.resize(n * 2); hi.resize(n * 2)
			var c := n; n += 1
			while c > 0:
				var pa := (c - 1) >> 1
				if hk[pa] < fj or (hk[pa] == fj and hi[pa] < j): break
				hk[c] = hk[pa]; hi[c] = hi[pa]; c = pa
			hk[c] = fj; hi[c] = j
	for i in seeds: done[i] = 0
	for i in order: done[i] = 0
	return order
## lokální přepočet po změně terénu ve sloupcích ch na výšky hv (a stavu pramenů v src_new)
## E51b (Jan 22:09): skutečně lokální – okno + okraj, pomocná pole se znovu používají a nulují jen zapsané buňky,
## tůně (seznam, pw) se přepočtou jen kolem dotčených sloupců, odtoky tůní jen ze změněných položek. Výsledek beze změny.
static func update(st: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array, src_new: PackedFloat64Array, margin: int) -> Dictionary:
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
		KOLO = {"kola": 0, "zmena": 0.0, "ustaleno": true, "cyklus": 0}
		return {"touched": 0, "window": 0, "expanded": 0, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": true, "cells": PackedInt32Array()}
	var x0 := W; var x1 := 0; var y0 := H; var y1 := 0
	for i in region:
		x0 = mini(x0, i / H); x1 = maxi(x1, i / H); y0 = mini(y0, i % H); y1 = maxi(y1, i % H)
	var m := margin if M0 <= 0 else mini(M0, margin); var expanded := 0
	PR.okno0 = Time.get_ticks_usec()
	var ins := T._scratch(st, "_ins")   # 1 = uvnitř okna, 2 = okraj okna (pevná fill), 0 = mimo
	var ring := PackedInt32Array(); var order := PackedInt32Array()
	var ax := 0; var bx := 0; var ay := 0; var by := 0
	var saved := PackedFloat64Array()   # fill obdélníku okna před změnou (pro zvětšení okna)
	var fl: PackedFloat64Array = st.fill; var hmv: PackedFloat64Array = st.hm; var wl: PackedByteArray = st.wall
	var eo: bool = st.edge_out
	while true:
		ring = PackedInt32Array()
		ax = maxi(x0 - m, 0); bx = mini(x1 + m, W - 1); ay = maxi(y0 - m, 0); by = mini(y1 + m, H - 1)
		saved.resize((bx - ax + 1) * (by - ay + 1))
		var k := 0
		for x in range(ax, bx + 1):
			var xb := x == 0 or x == W - 1
			var xe := (x == ax and ax > 0) or (x == bx and bx < W - 1)
			for y in range(ay, by + 1):
				var i := x * H + y
				saved[k] = fl[i]; k += 1
				if wl[i] == 1: continue
				if xb or y == 0 or y == H - 1:
					fl[i] = hmv[i]; ring.append(i); ins[i] = 2
				elif xe or (y == ay and ay > 0) or (y == by and by < H - 1):
					ring.append(i); ins[i] = 2
				else:
					ins[i] = 1; fl[i] = hmv[i]
		order = _flood60(st, ins, ring) if FAST_FLOOD else T._flood(st, ins, ring, true)
		# okraj okna musí dál mít odtok dolů (soused s nižší fill); jinak by se změnila fill i za oknem → zvětšit okno
		var leak := false
		for r in ring:
			var x := r / H; var y := r % H
			if x == 0 or y == 0 or x == W - 1 or y == H - 1: continue
			var sup := false; var fr: float = fl[r] - 1e-9
			for d in 8:
				var j: int = (x + T.DX[d]) * H + y + T.DY[d]   # okraj okna není okraj mapy → sousedé existují
				if wl[j] == 0 and fl[j] < fr: sup = true; break
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
	# E60: D8 a průtok jen tam, kde se něco změnilo (fill buňky nebo souseda, cíl odtoku, přítok); jinak by _cell / _to
	# zapsaly stejné hodnoty. Mimo okno stejně jako tok.gd (halda po proudu).
	var nwy := by - ay + 1
	var fc := PackedByteArray(); fc.resize((bx - ax + 1) * nwy)   # 1 = fill se změnil, 2 = jen soused se změnil (→ znovu _to)
	var kk := 0
	var chl := PackedInt32Array()
	for x in range(ax, bx + 1):
		for y in range(ay, by + 1):
			if fl[x * H + y] != saved[kk]: chl.append(kk)
			kk += 1
	for c in chl: fc[c] = 1
	for c in chl:
		var cx := c / nwy; var cy := c % nwy
		for dx in range(-1, 2):
			var qx := cx + dx
			if qx < 0 or qx > bx - ax: continue
			for dy in range(-1, 2):
				var qy := cy + dy
				if qy < 0 or qy >= nwy: continue
				if fc[qx * nwy + qy] == 0: fc[qx * nwy + qy] = 2
	var nd := T._scratch(st, "_nd60")
	for c in ch: nd[c] = 1
	var ot := PackedInt32Array(); ot.resize(order.size())
	for k in order.size():
		var i := order[k]; ot[k] = st.to[i]
		var x := i / H; var y := i % H
		var f: int = fc[(x - ax) * nwy + y - ay]
		if f != 0: T._to(st, i)
		if f == 1: nd[i] = 1
		var tn: int = st.to[i]
		if tn != ot[k]:
			if ot[k] >= 0: nd[ot[k]] = 1
			if tn >= 0: nd[tn] = 1
	var heap := []
	var dirty := PackedInt32Array(ch)
	for k in range(order.size() - 1, -1, -1):
		var i := order[k]
		if nd[i] == 0: continue
		var e0: float = st.eff[i]
		T._cell(st, i); touched[i] = true; dirty.append(i)
		if st.eff[i] != e0 and st.to[i] >= 0: nd[st.to[i]] = 1
	for k in order.size():
		var i := order[k]
		var j1: int = ot[k]; var j2: int = st.to[i]
		if j1 >= 0 and nd[j1] == 1 and ins[j1] == 0 and not touched.has(j1): T.RK._push(heap, -fl[j1], j1)
		if j2 >= 0 and j2 != j1 and nd[j2] == 1 and ins[j2] == 0 and not touched.has(j2): T.RK._push(heap, -fl[j2], j2)
	for k in order.size():
		var i := order[k]; nd[i] = 0
		if ot[k] >= 0: nd[ot[k]] = 0
		if st.to[i] >= 0: nd[st.to[i]] = 0
	for c in ch: nd[c] = 0
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
	var kol := 0; var zm := 0.0; var ust := false
	var cs := {"seen": {}, "list": []}
	var ah := {}
	for it in KOLA:
		var ox := {}
		for i in st.get("_xn", {}): ox[i] = [st.extra[i], st.src2[i]]
		var chg := _apply_drains(st, dirty)
		kol += 1
		dirty = PackedInt32Array()
		if chg.is_empty(): ust = true; zm = 0.0; break
		zm = 0.0
		for i in chg:
			var o: Array = ox.get(i, [0.0, 0.0])
			zm = maxf(zm, maxf(absf(st.extra[i] - float(o[0])), absf(st.src2[i] - float(o[1]))))
		for i in chg: T.RK._push(heap, -st.fill[i], i)
		queued = {}
		while not heap.is_empty():
			var e := T.RK._pop(heap); var i: int = e[1]
			if queued.has(i): continue
			queued[i] = true; touched[i] = true; dirty.append(i)
			var dlt := T._cell(st, i)
			if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); T.RK._push(heap, -st.fill[st.to[i]], st.to[i])
		if TOL > 0.0 and zm <= TOL: ust = true; break
		if CYKLUS and cyc_step(st, cs): break
		if ACC:   # E73: skok smyčky → povrch po proudu od změněných výtoků
			var jc := acc_step(st, ah)
			if not jc.is_empty():
				for i in jc: T.RK._push(heap, -st.fill[i], i)
				queued = {}
				while not heap.is_empty():
					var e := T.RK._pop(heap); var i: int = e[1]
					if queued.has(i): continue
					queued[i] = true; touched[i] = true; dirty.append(i)
					var dlt := T._cell(st, i)
					if dlt > 1e-9 and st.to[i] >= 0: queued.erase(st.to[i]); T.RK._push(heap, -st.fill[st.to[i]], st.to[i])
	KOLO = {"kola": kol, "zmena": zm, "ustaleno": ust, "cyklus": int(cs.get("perioda", 0)), "skoky": int(ah.get("skoky", 0))}
	PR.odtoky = Time.get_ticks_usec()
	_ponds_cached(st, dirty)   # pw a seznam tůní kolem posledních změn
	PR.tune = Time.get_ticks_usec()
	return {"touched": touched.size(), "window": order.size(), "expanded": expanded, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "dry": false,
		"cells": PackedInt32Array(touched.keys())}   # E51: dotčené sloupce (přeplánování událostí)

## pw = 1 pro sloupce mokrých tůní (prohlubeň, do které teče voda); suché prohlubně se nepočítají
static func pond_mask(st: Dictionary) -> void:
	_ponds_cached(st, null)

## E51b: seznam tůní (jako T.ponds(…, false)) a pw udržované lokálně. dirty = null → celý přepočet; jinak jen tůně
## dotčené změněnými sloupci (a jejich 8 sousedy). Tůň = souvislá oblast od nejmenšího indexu (stejné pořadí jako T.ponds()).
static func _ponds_cached(st: Dictionary, dirty) -> Array:
	var n: int = st.W * st.H
	var cm2 := float(st.L.get("cell_m2", 0.25)); var um := float(st.L.get("u_m", 0.5))
	if dirty == null or not st.has("_pd"):
		var pw := PackedByteArray(); pw.resize(n)
		var pk := PackedInt32Array(); pk.resize(n); pk.fill(-1)
		var pd := {}
		for x in T.ponds(st, cm2, um, false):
			var key: int = x.cells[0]
			pd[key] = x
			for c in x.cells: pk[c] = key
			if not x["suchá"]:
				for c in x.cells:
					if st.fill[c] >= st.hm[c] + 0.1: pw[c] = 1   # kreslí se a počítá jako „u vody“ až od 5 cm
		st.pw = pw; st._pk = pk; st._pd = pd; st._pend = PackedInt32Array(); st._kd60 = true
	else:
		var allc: PackedInt32Array = st.get("_pend", PackedInt32Array())
		allc.append_array(dirty)
		st._pend = PackedInt32Array()
		if not allc.is_empty(): _ponds_refresh(st, allc, cm2, um)
	# E60: seřazené klíče tůní se drží, dokud se množina klíčů nezmění (_kd60)
	# (_pd jiný objekt = nový plný přepočet v tok.gd → znovu; kopii nemíchat s tok.update na stejném stavu)
	if st.get("_kd60", true) or not st.has("_ks60") or not is_same(st._pd, st.get("_ks60_of")) or st._ks60.size() != st._pd.size():
		var ks: Array = st._pd.keys(); ks.sort(); st._ks60 = ks; st._kd60 = false; st._ks60_of = st._pd
	var pd: Dictionary = st._pd
	var out := []; out.resize(st._ks60.size())
	var k := 0
	for key in st._ks60: out[k] = pd[key]; k += 1
	return out

static func _pwet(st: Dictionary, j: int) -> bool:
	return st.wall[j] == 0 and st.fill[j] > st.hm[j] + 0.01

static func _pond_drop(st: Dictionary, key: int, seeds: Dictionary) -> void:
	var pk: PackedInt32Array = st._pk; var pw: PackedByteArray = st.pw
	for c in st._pd[key].cells: pk[c] = -1; pw[c] = 0; seeds[c] = true
	st._pd.erase(key); st._kd60 = true

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
		var x := _pond_dict_soft(st, comp, st._pd[key]) if FAST_POND else T._pond_dict(st, comp, cm2, um, false, 0.001)
		st._pd[key] = x
		var wp: bool = not x["suchá"]
		for c in comp: pw[c] = 1 if wp and st.fill[c] >= st.hm[c] + 0.1 else 0
	for key in hard:
		if st._pd.has(key): _pond_drop(st, key, seeds)
	var seen := T._scratch(st, "_seen")
	var marked := PackedInt32Array(); var mins := []
	for s in seeds:
		if seen[s] == 1 or not _pwet(st, s): continue
		var comp := PackedInt32Array([s]); seen[s] = 1; var k := 0; var mn: int = s
		while k < comp.size():
			var i := comp[k]; k += 1
			mn = mini(mn, i)
			var x := i / H; var y := i % H
			for d in 8:
				var qx: int = x + T.DX[d]; var qy: int = y + T.DY[d]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if seen[j] == 1 or not _pwet(st, j): continue
				if pk[j] >= 0: _pond_drop(st, pk[j], seeds)   # nedotčená tůň se napojila → přepočítat i ji
				seen[j] = 1; comp.append(j)
		marked.append_array(comp); mins.append(mn)
	for i in marked: seen[i] = 0
	marked = PackedInt32Array()
	for mn in mins:
		var comp := T._pond_comp(st, mn, seen)
		marked.append_array(comp)
		var x := T._pond_dict(st, comp, cm2, um, false, 0.001)
		st._pd[mn] = x; st._kd60 = true
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
		d += (1.0 if T._soluble(m) else float(T.VS.table().get(m, [0.0])[0])) * float(st.L.get("pit_q", 0.0))
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
static func _ugi(st: Dictionary):
	return st.ug.get("impl", T.UG)

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
		var t_a := Time.get_ticks_usec()
		var wetp := []
		for x in _ponds_cached(st, dirty):
			if not x["suchá"] and x.outlet >= 0 and x.drain_lps > 0.0: wetp.append(x)
		PR.pc = float(PR.get("pc", 0.0)) + (Time.get_ticks_usec() - t_a) / 1000.0; PR.np = wetp.size()
		if st.get("ug") == null:   # E47c: podzemím k nejbližšímu okraji
			for x in wetp:
				T._set_drain(st, x, wr)
				var o: int = x.outlet; var best := -1; var bd := 1e9
				if not st.has("_bl"):   # okrajové sloupce vzestupně (stejné pořadí jako průchod celou mřížkou)
					var bl := PackedInt32Array()
					for i in W * H:
						if st.wall[i] == 0 and T._border(st, i): bl.append(i)
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
			var fed: Dictionary = T._fed_map(st, prev_under, wetp) if bool(st.L.get("v73", false)) else {}
			for x in wetp:
				var cols := Array(x.cells); cols.sort_custom(func(a, b): return st.hm[a] < st.hm[b])
				var v := -1
				for c in cols:
					v = _ugi(st).entry(st.ug, c)
					if v >= 0: break
				if v < 0:
					T._set_drain(st, x, wr); st.lost_deep += x.podzemi_lps   # pod tůní není propustné těleso → do hloubky (nemodeluje se)
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
					if T._fed73(st, ents[j][1], r0, fed): continue   # E73 p73_vyver: tůň zavodněná pramenem tohoto tělesa – pramen v ní smí zůstat
					for c in ents[j][1].cells: excl[c] = true
				# E83: přesný klíč (bity q, seřazené buňky), dřív "%.9f" a 32bitový excl.hash() – kolize = výsledek z mezipaměti jiného vstupu
				var ek := excl.keys(); ek.sort()
				var sk := "s%s|%s|%s" % [str(vs), PackedFloat64Array([q]).to_byte_array().hex_encode(), str(ek)]
				if not st.ug_cache.has(sk): st.ug_cache[sk] = _ugi(st).solve(st.ug, vs, q, excl)
				var r: Dictionary = st.ug_cache[sk].duplicate()
				for j in grp:
					var x: Dictionary = ents[j][1]
					if not r.closed: T._set_drain(st, x, wr)   # uzavřené plné těleso nic nepřijímá → vše přeteče po povrchu
				if not r.closed and r.out_q > 0.0 and r.has("outs67"):   # E67 pretok: víc výstupů (prameny / okraj) s vlastním průtokem
					for o in r.outs67:
						var col67: int = o[2]
						if float(o[3]) <= 0.0: continue
						if o[1] == "povrch": st.src2[col67] += float(o[3]); wr.append(col67)
						st.under.append({"v0": ents[grp[0]][0], "from": ents[grp[0]][1].outlet, "exit": col67, "q": float(o[3]), "z": float(o[0]), "typ": o[1]})
				elif not r.closed and r.out_q > 0.0:
					var col: int = r.out[4]
					if r.out[3] == "povrch": st.src2[col] += r.out_q; wr.append(col)
					st.under.append({"v0": ents[grp[0]][0], "from": ents[grp[0]][1].outlet, "exit": col, "q": r.out_q, "z": float(r.out[0]), "typ": r.out[3]})
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
