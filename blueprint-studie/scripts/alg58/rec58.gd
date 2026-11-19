extends RefCounted
## E58: záznam volání podzemí během běhu povrchu (obal ug_funkce: entry / touched beze změny, solve zapíše argumenty).
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
static func entry(c: Dictionary, s: int) -> int: return F.entry(c, s)
static func touched(c: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool: return F.touched(c, cache, ch, hv)
static func col_of(c: Dictionary, s: int) -> int: return F.col_of(c, s)
static func solve(c: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	c._rec.append({"e": Array(entries), "q": q, "x": excl.keys()})
	return F.solve(c, entries, q, excl)
