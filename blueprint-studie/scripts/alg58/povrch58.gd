extends RefCounted
## E58 povrch B: graf pánví. Sestup D8 po hm → pánve (jáma = uzel), hrany mezi sousedními pánvemi s výškou přelivu
## max(h_i, h_j) (nejnižší na dvojici), priority-flood jen nad uzly od okrajových pánví (odtok přes okraj ostrova).
## fill_B = max(hm, hladina přelivu pánve). Bez epsilon spádu na rovinách → není bit po bitu stejné jako tok.gd.
const RK = preload("res://scripts/svet8/reky.gd")
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

static func basin_fill(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n := W * H
	var dn := PackedInt32Array(); dn.resize(n); dn.fill(-1)
	for i in n:
		if wall[i] == 1: continue
		var x := i / H; var y := i % H
		if x == 0 or y == 0 or x == W - 1 or y == H - 1: continue   # okraj = odtok
		var bh := hm[i]; var bj := -1
		for d in 8:
			var j: int = (x + DX[d]) * H + y + DY[d]
			if wall[j] == 1: continue
			if hm[j] < bh: bh = hm[j]; bj = j
		dn[i] = bj
	var t1 := Time.get_ticks_usec()
	# pánve: následuj sestup ke kořeni (jáma nebo okraj), komprese cesty
	var bas := PackedInt32Array(); bas.resize(n); bas.fill(-1)
	var nb := 0; var root := PackedInt32Array(); var outlet := PackedByteArray()
	var stack := PackedInt32Array()
	for i in n:
		if wall[i] == 1 or bas[i] >= 0: continue
		stack.resize(0)
		var j := i
		while bas[j] < 0 and dn[j] >= 0:
			stack.append(j); j = dn[j]
		if bas[j] < 0:
			bas[j] = nb; root.append(j)
			var x := j / H; var y := j % H
			outlet.append(1 if (x == 0 or y == 0 or x == W - 1 or y == H - 1) else 0)
			nb += 1
		var b := bas[j]
		for k in stack: bas[k] = b
	var t2 := Time.get_ticks_usec()
	# hrany: nejnižší přeliv mezi dvojicí pánví
	var ed := {}
	for i in n:
		if wall[i] == 1: continue
		var x := i / H; var y := i % H; var a := bas[i]
		for d in [0, 2, 4, 5]:   # každá dvojice jednou
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if wall[j] == 1: continue
			var b := bas[j]
			if a == b: continue
			var key := mini(a, b) * nb + maxi(a, b)
			var h := maxf(hm[i], hm[j])
			if not ed.has(key) or h < float(ed[key]): ed[key] = h
	var adj := []; adj.resize(nb)
	for k in nb: adj[k] = []
	for key in ed:
		var a := int(key) / nb; var b := int(key) % nb
		adj[a].append([b, ed[key]]); adj[b].append([a, ed[key]])
	var t3 := Time.get_ticks_usec()
	var lvl := PackedFloat64Array(); lvl.resize(nb); lvl.fill(INF)
	var done := PackedByteArray(); done.resize(nb)
	var heap := []
	for b in nb:
		if outlet[b] == 1: lvl[b] = -INF; RK._push(heap, -1e30, b)
	while not heap.is_empty():
		var e := RK._pop(heap); var a: int = e[1]
		if done[a] == 1: continue
		done[a] = 1
		var ka := lvl[a]
		for pr in adj[a]:
			var b: int = pr[0]; var kb := maxf(ka, float(pr[1]))
			if done[b] == 0 and kb < lvl[b]: lvl[b] = kb; RK._push(heap, kb, b)
	var fill := PackedFloat64Array(); fill.resize(n)
	for i in n:
		fill[i] = hm[i] if wall[i] == 1 or bas[i] < 0 else maxf(hm[i], lvl[bas[i]])
	var t4 := Time.get_ticks_usec()
	return {"fill": fill, "basins": nb, "edges": ed.size(), "ms": (t4 - t0) / 1000.0,
		"ms_parts": {"sestup": (t1 - t0) / 1000.0, "panve": (t2 - t1) / 1000.0, "hrany": (t3 - t2) / 1000.0, "graf_pf": (t4 - t3) / 1000.0}}
