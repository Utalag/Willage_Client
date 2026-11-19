extends RefCounted
## E51: jedna globální binární min-halda událostí v packed polích (čas, sloupec, generace). Zastaralé položky
## (generace sloupce se mezitím změnila) se nemažou, při výběru se přeskočí (líné mazání).

var t := PackedFloat64Array()
var c := PackedInt32Array()
var g := PackedInt32Array()
var n := 0

func size() -> int:
	return n

func push(time: float, cell: int, gen: int) -> void:
	if n == t.size():
		var m := maxi(16, n * 2)
		t.resize(m); c.resize(m); g.resize(m)
	var i := n; n += 1
	while i > 0:
		var p := (i - 1) >> 1
		if t[p] <= time: break
		t[i] = t[p]; c[i] = c[p]; g[i] = g[p]; i = p
	t[i] = time; c[i] = cell; g[i] = gen

## vrátí [čas, sloupec, generace] nejmenšího času a odebere ho
func pop() -> Array:
	var out := [t[0], c[0], g[0]]
	n -= 1
	if n > 0:
		var lt := t[n]; var lc := c[n]; var lg := g[n]
		var i := 0
		while true:
			var l := 2 * i + 1
			if l >= n: break
			var r := l + 1
			var m := r if r < n and t[r] < t[l] else l
			if t[m] >= lt: break
			t[i] = t[m]; c[i] = c[m]; g[i] = g[m]; i = m
		t[i] = lt; c[i] = lc; g[i] = lg
	return out

func top_time() -> float:
	return t[0] if n > 0 else INF
