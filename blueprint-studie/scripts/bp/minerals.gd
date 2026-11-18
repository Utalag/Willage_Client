extends RefCounted
## Vtisknutí minerálů a kovů blueprintu v PŘESNÝCH počtech, jen do povolených hostitelů (data/mineraly_hostitele.json)
## a jen v novém bloku. Růst ore_v0 (L0–L3) + dosazení gen-v3 _sweep (L4 bez pásma lz, ale pořád jen hostitel).
## Když hostitel dojde, zbytek je SCHODEK v hlášení (jinam se nedává).

const Mat = preload("res://scripts/kopie/mat.gd")
const Ore = preload("res://scripts/kopie/ore_v0.gd")
const G = preload("res://scripts/kopie/gen_v3.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const HT = preload("res://scripts/bp/hostitele.gd")

## pořadí: vzestupně podle MaterialId (deterministické, nezávislé na pořadí klíčů ve slovníku)
static func order(minerals: Dictionary) -> Array:
	var ks := minerals.keys()
	ks.sort()
	return ks

static func host_count(cells: PackedByteArray, hosts: Array) -> int:
	var n := 0
	for c in cells:
		if c in hosts:
			n += 1
	return n

static func press_one(cells: PackedByteArray, mat: int, count: int, seed: int) -> Dictionary:
	var sp: Dictionary = HT.table()[mat].duplicate(true)
	var avail := host_count(cells, sp.host)
	Ore.elig = PackedByteArray()
	var r := Ore.place(cells, H.mix(seed, "BP_MIN", mat), {sp.key: count}, [sp])
	var rep: Dictionary = r.per_ore[0]
	G._sweep(cells, rep, sp, H.mix(seed, "BP_SWEEP", mat))
	return {"mat": mat, "name": HT.name_of(mat), "hosts": HT.hosts_text(mat), "host_cells": avail,
		"target": count, "placed": rep.placed, "shortfall": rep.shortfall, "by_level": rep.by_level}
