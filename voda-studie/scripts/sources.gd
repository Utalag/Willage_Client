extends RefCounted
## Rozmístění zdrojů vody v bloku ze seedu (deterministicky, stejně na klientu i serveru).
## Typy (Jan 15:51): top_flow (přítok shora / z bloku proti proudu), hillside_spring (vyvěrá ze svahu),
## underground_pocket (skrytá kapsa, uvolní se prokopáním).
const M = preload("res://scripts/materials.gd")

static func place(s, seed_: int, P: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var out := []
	# top_flow: náhodný sloupec na severním (horním) okraji
	for k in int(P["src_top"]):
		var x := rng.randi_range(1, s.NX - 2)
		out.append({"type": "top_flow", "x": x, "y": 0, "rate": float(P["top_rate"])})
	# hillside_spring: kandidáti = pevná buňka se vzduchem vedle (stěna svahu) a pevnou buňkou nad sebou nebo je to vrchol
	var cand := []
	var D := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for z in range(1, s.NZ - 1):
		for y in range(1, s.NY - 1):
			for x in range(1, s.NX - 1):
				if s.mat[s.idx(x, y, z)] == M.AIR:
					continue
				for d in D:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if s.mat[s.idx(nx, ny, z)] == M.AIR and s.mat[s.idx(nx, ny, z - 1)] != M.AIR:
						cand.append([x, y, z, d])
	for k in int(P["src_hill"]):
		if cand.is_empty():
			break
		var c: Array = cand[rng.randi_range(0, cand.size() - 1)]
		out.append({"type": "hillside_spring", "x": c[0], "y": c[1], "z": c[2], "dir": c[3], "rate": float(P["hill_rate"])})
	# underground_pocket: buňky aspoň 2 vrstvy pod povrchem, obklopené pevným materiálem
	for k in int(P["src_pocket"]):
		var x0 := rng.randi_range(2, s.NX - 4)
		var y0 := rng.randi_range(s.NY / 2, s.NY - 3)
		var cells := []
		var nc := int(P["pocket_cells"])
		var side := maxi(1, int(ceil(sqrt(float(nc)))))
		for i in nc:
			cells.append(Vector3i(x0 + i % side, y0 + i / side, 0))
		var so := {"type": "underground_pocket", "cells": cells, "rate": float(P["pocket_recharge"])}
		out.append(so)
	for so in out:
		s.add_source(so)
	return out
