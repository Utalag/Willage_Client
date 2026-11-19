extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/world.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Stav světa = vložené bloky ve slotech (mřížka W × H). Server by držel jen pořadí (slot, blueprint, seed);
## buňky, voda a pole hranic vrstev jsou deterministicky odvoditelné přehráním pořadí (zde uložené jako mezivýsledek).

const SD = preload("res://scripts/teren/sides.gd")

var w := 3
var h := 3
var slots := {}     # Vector2i -> záznam {bp, slot, order, hm, hm_f, hm_raw, bs: Array[5] PackedFloat64Array, cells, water, rep}
var order := []     # Vector2i v pořadí vložení

func inside(s: Vector2i) -> bool:
	return s.x >= 0 and s.y >= 0 and s.x < w and s.y < h

func neighbour(s: Vector2i, d: int):
	var n: Vector2i = s + SD.DIRS[d]
	return slots.get(n, null)

## výšky povrchu přiléhajících sloupců sousedů (desetinné, aby navázání nezáviselo na zaokrouhlení souseda víc než nutno)
func edge_heights(s: Vector2i) -> Array:
	var out := [null, null, null, null]
	for d in 4:
		var nb = neighbour(s, d)
		if nb == null:
			continue
		var e := PackedFloat64Array(); e.resize(16)
		for t in 16:
			var c := SD.nb(d, t)
			e[t] = float(nb.hm[c.x * 16 + c.y])
		out[d] = e
	return out

## jako edge_heights, ale z desetinné funkce povrchu hm_f (řídicí body souseda), ne z buněk
func edge_heights_f(s: Vector2i) -> Array:
	var out := [null, null, null, null]
	for d in 4:
		var nb = neighbour(s, d)
		if nb == null:
			continue
		var e := PackedFloat64Array(); e.resize(16)
		for t in 16:
			var c := SD.nb(d, t)
			e[t] = float(nb.hm_f[c.x * 16 + c.y])
		out[d] = e
	return out

func edge_bounds(s: Vector2i, k: int) -> Array:
	var out := [null, null, null, null]
	for d in 4:
		var nb = neighbour(s, d)
		if nb == null:
			continue
		var e := PackedFloat64Array(); e.resize(16)
		for t in 16:
			var c := SD.nb(d, t)
			e[t] = nb.bs[k][c.x * 16 + c.y]
		out[d] = e
	return out

func commit(rec: Dictionary) -> void:
	rec["order"] = order.size()
	slots[rec.slot] = rec
	order.append(rec.slot)

## SHA-256 celého světa: sloty v pevném pořadí (y, x), pro každý slot pořadí vložení, buňky a voda
func hash() -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	for y in h:
		for x in w:
			var s := Vector2i(x, y)
			if not slots.has(s):
				continue
			var r: Dictionary = slots[s]
			var hdr := PackedByteArray(); hdr.resize(4)
			hdr.encode_u8(0, x); hdr.encode_u8(1, y); hdr.encode_u16(2, r.order)
			hc.update(hdr)
			hc.update(r.cells)
			hc.update(r.water.to_byte_array())
	return hc.finish().hex_encode()
