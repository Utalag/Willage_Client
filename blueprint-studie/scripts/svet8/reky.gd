extends RefCounted
## E49 fáze 3: eroze kapkami na hrubé mřížce (eroze_mrizka.gd, po dávkách kvůli GIFu), pak řeky a jezera:
## vyplnění bezodtokých míst (priority-flood, Barnes et al. [20]), směr toku D8 po vyplněném povrchu, akumulace srážek,
## řeka = akumulace ≥ s8_river, koryto se zahloubí o min(2,5; 0,7 · ln(1 + acc / práh)) buněk; jezero = vyplněno o ≥ s8_lake.

const EM = preload("res://scripts/voda/eroze_mrizka.gd")

static func erode(t: Dictionary, w: Dictionary, p: Dictionary, chunks: int) -> Array:
	var R: int = t.R
	var frames := []
	var q := {"ero_cap": float(p.s8_ero_cap), "ero_erode": float(p.s8_ero_erode), "ero_deposit_rate": float(p.s8_ero_dep)}
	var per := int(float(p.s8_droplets) * R * R / chunks)
	for k in chunks:
		EM.run(t.hm, R, R, int(p.world_seed) + 31 * k, per, q)
		frames.append(t.hm.duplicate())
	return frames

## binární halda [výška, index]
static func _push(h: Array, v: float, i: int) -> void:
	h.append([v, i]); var c := h.size() - 1
	while c > 0:
		var pa := (c - 1) / 2
		if h[pa][0] < h[c][0] or (h[pa][0] == h[c][0] and h[pa][1] < h[c][1]): break
		var tmp = h[pa]; h[pa] = h[c]; h[c] = tmp; c = pa

static func _pop(h: Array) -> Array:
	var top: Array = h[0]; var last = h.pop_back()
	if h.is_empty(): return top
	h[0] = last; var c := 0
	while true:
		var l := 2 * c + 1; var r := l + 1; var m := c
		for k in [l, r]:
			if k < h.size() and (h[k][0] < h[m][0] or (h[k][0] == h[m][0] and h[k][1] < h[m][1])): m = k
		if m == c: break
		var tmp = h[m]; h[m] = h[c]; h[c] = tmp; c = m
	return top

static func rivers(t: Dictionary, w: Dictionary, p: Dictionary) -> Dictionary:
	var R: int = t.R; var hm: PackedFloat64Array = t.hm
	var fill := hm.duplicate()
	var done := PackedByteArray(); done.resize(R * R)
	var heap := []
	for i in R * R:
		var x := i / R; var y := i % R
		if x == 0 or y == 0 or x == R - 1 or y == R - 1:
			_push(heap, fill[i], i); done[i] = 1
	var order := PackedInt32Array()
	var DX := [1, -1, 0, 0, 1, 1, -1, -1]; var DY := [0, 0, 1, -1, 1, -1, 1, -1]
	while not heap.is_empty():
		var e := _pop(heap); var i: int = e[1]
		order.append(i)
		var x := i / R; var y := i % R
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= R or qy >= R: continue
			var j := qx * R + qy
			if done[j] == 1: continue
			done[j] = 1
			fill[j] = maxf(fill[j], fill[i] + 1e-3)
			_push(heap, fill[j], j)
	# D8 po vyplněném povrchu: nejstrmější spád
	var to := PackedInt32Array(); to.resize(R * R); to.fill(-1)
	for i in R * R:
		var x := i / R; var y := i % R; var best := 0.0
		for d in 8:
			var qx: int = x + DX[d]; var qy: int = y + DY[d]
			if qx < 0 or qy < 0 or qx >= R or qy >= R: continue
			var j := qx * R + qy
			var s := (fill[i] - fill[j]) / (1.4142 if d >= 4 else 1.0)
			if s > best: best = s; to[i] = j
	var acc := PackedFloat64Array(); acc.resize(R * R)
	for i in R * R: acc[i] = w.rain[i]
	for k in range(order.size() - 1, -1, -1):   # od nejvyšších dolů
		var i := order[k]
		if to[i] >= 0: acc[to[i]] += acc[i]
	var thr := float(p.s8_river)
	var river := PackedByteArray(); river.resize(R * R)
	var lake := PackedByteArray(); lake.resize(R * R)
	for i in R * R:
		if fill[i] - hm[i] >= float(p.s8_lake): lake[i] = 1
		elif acc[i] >= thr:
			river[i] = 1
			hm[i] -= minf(2.5, 0.7 * log(1.0 + acc[i] / thr))
	return {"fill": fill, "acc": acc, "river": river, "lake": lake}
