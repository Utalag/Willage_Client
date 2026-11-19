extends RefCounted
## E58 A: kbelíková fronta pro monotónní priority-flood. Kbelík = floor((klíč − k0) / dz); v aktuálním kbelíku malá
## binární halda (klíč, id) → pořadí výběru je přesně stejné jako u jedné haldy (reky.gd _push/_pop), jen levnější.
var dz: float
var k0: float
var cur := 0
var bk_k: Array = []   # kbelík → PackedFloat64Array klíčů
var bk_i: Array = []   # kbelík → PackedInt32Array id
var hk := PackedFloat64Array()
var hi := PackedInt32Array()
var n := 0
var moved := 0

func _init(dz_: float, k0_: float) -> void:
	dz = dz_; k0 = k0_

func _less(a: int, b: int) -> bool:
	return hk[a] < hk[b] or (hk[a] == hk[b] and hi[a] < hi[b])

func _hpush(k: float, id: int) -> void:
	hk.append(k); hi.append(id)
	var c := hk.size() - 1
	while c > 0:
		var pa := (c - 1) / 2
		if not _less(c, pa): break
		var tk := hk[pa]; hk[pa] = hk[c]; hk[c] = tk
		var ti := hi[pa]; hi[pa] = hi[c]; hi[c] = ti
		c = pa

func push(k: float, id: int) -> void:
	n += 1
	var b := int(floor((k - k0) / dz))
	if b <= cur:
		_hpush(k, id); return
	while bk_k.size() <= b:
		bk_k.append(PackedFloat64Array()); bk_i.append(PackedInt32Array())
	var a: PackedFloat64Array = bk_k[b]; a.append(k); bk_k[b] = a
	var ai: PackedInt32Array = bk_i[b]; ai.append(id); bk_i[b] = ai

func empty() -> bool:
	return n == 0

## vrací [klíč, id]; volat jen když not empty()
func pop() -> Array:
	while hk.is_empty():
		cur += 1
		if cur < bk_k.size():
			var a: PackedFloat64Array = bk_k[cur]; var ai: PackedInt32Array = bk_i[cur]
			for j in a.size(): _hpush(a[j], ai[j])
			moved += a.size()
			bk_k[cur] = PackedFloat64Array(); bk_i[cur] = PackedInt32Array()
	n -= 1
	var tk := hk[0]; var ti := hi[0]
	var lk := hk[hk.size() - 1]; var li := hi[hi.size() - 1]
	hk.resize(hk.size() - 1); hi.resize(hi.size() - 1)
	if not hk.is_empty():
		hk[0] = lk; hi[0] = li
		var c := 0; var m := hk.size()
		while true:
			var l := 2 * c + 1; var r := l + 1; var s := c
			if l < m and _less(l, s): s = l
			if r < m and _less(r, s): s = r
			if s == c: break
			var xk := hk[s]; hk[s] = hk[c]; hk[c] = xk
			var xi := hi[s]; hi[s] = hi[c]; hi[c] = xi
			c = s
	return [tk, ti]
