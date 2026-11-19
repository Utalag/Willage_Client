extends RefCounted
## E52 varianta 3: podzemí na hrubší mřížce (nu buněk na blok), povrchová voda na jemné (nv). Obal převádí sloupce:
## vstup tůně (jemný sloupec) → hrubý sloupec, výtok (hrubý sloupec) → nejnižší jemný sloupec v něm (u okraje okrajový).
## Uvnitř běží libovolná buňková varianta (slovník nebo pole) beze změny.

const SELF = preload("res://scripts/podzemi52/ug_mrizka.gd")

static func make(inner: Dictionary, Ws: int, hs: PackedFloat64Array, wall_s: PackedByteArray, f: int) -> Dictionary:
	return {"impl": SELF, "inner": inner, "Ws": Ws, "Wu": int(inner.W), "f": f, "hs": hs, "wall_s": wall_s, "stats": inner.stats, "NZ": inner.NZ, "top": inner.top}

static func _cu(ctx: Dictionary, col: int) -> int:
	var Ws: int = ctx.Ws; var f: int = ctx.f
	return (col / Ws / f) * int(ctx.Wu) + (col % Ws) / f

static func _cs(ctx: Dictionary, cu: int, border: bool) -> int:
	var Ws: int = ctx.Ws; var f: int = ctx.f; var Wu: int = ctx.Wu
	var ux := cu / Wu; var uy := cu % Wu
	var best := -1; var bh := INF
	for dx in f:
		for dy in f:
			var x := ux * f + dx; var y := uy * f + dy
			var c := x * Ws + y
			if ctx.wall_s[c] == 1: continue
			if border and not (x == 0 or y == 0 or x == Ws - 1 or y == Ws - 1): continue
			if ctx.hs[c] < bh: bh = ctx.hs[c]; best = c
	return best if best >= 0 else (ux * f + f / 2) * Ws + uy * f + f / 2

static func entry(ctx: Dictionary, col: int) -> int:
	return ctx.inner.impl.entry(ctx.inner, _cu(ctx, col))

static func solve(ctx: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var ex := {}
	for c in excl: ex[_cu(ctx, c)] = true
	var r: Dictionary = ctx.inner.impl.solve(ctx.inner, entries, q, ex)
	if not r.out.is_empty():
		var o: Array = r.out.duplicate()
		o[4] = _cs(ctx, int(o[4]), String(o[3]) == "okraj")
		r.out = o
	return r

static func touched(ctx: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool:
	var cu := PackedInt32Array(); var hu := PackedFloat64Array()
	for k in ch.size():
		cu.append(_cu(ctx, ch[k])); hu.append(hv[k] / float(ctx.f))
	return ctx.inner.impl.touched(ctx.inner, cache, cu, hu)
