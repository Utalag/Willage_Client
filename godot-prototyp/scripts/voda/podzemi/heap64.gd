extends RefCounted
## KOPIE z blueprint-studie/scripts/alg64/heap64.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E64 K: binární halda s kanonickým pořadím. Vybírá NEJVYŠŠÍ hodnotu, při shodě nejmenší id.
## Pořadí výběru tedy závisí jen na (hodnota, id), ne na pořadí vkládání.
var hk := PackedFloat64Array()
var hi := PackedInt32Array()

func size() -> int:
	return hk.size()

func clear() -> void:
	hk.resize(0); hi.resize(0)

func push(v: float, id: int) -> void:
	hk.append(v); hi.append(id)
	var c := hk.size() - 1
	while c > 0:
		var pa := (c - 1) >> 1
		var pv := hk[pa]
		if v < pv or (v == pv and id > hi[pa]): break
		hk[c] = pv; hi[c] = hi[pa]
		c = pa
	hk[c] = v; hi[c] = id

## vrací id; hodnotu před voláním čti v top_v()
func top_v() -> float:
	return hk[0]

func pop() -> int:
	var tid := hi[0]
	var m := hk.size() - 1
	var lv := hk[m]; var li := hi[m]
	hk.resize(m); hi.resize(m)
	if m == 0: return tid
	var c := 0
	while true:
		var l := 2 * c + 1
		if l >= m: break
		var r := l + 1
		var s := l
		if r < m and (hk[r] > hk[l] or (hk[r] == hk[l] and hi[r] < hi[l])): s = r
		if hk[s] < lv or (hk[s] == lv and hi[s] > li): break
		hk[c] = hk[s]; hi[c] = hi[s]
		c = s
	hk[c] = lv; hi[c] = li
	return tid
