extends RefCounted
## E52: svět svet64 (E50) se vygeneruje jednou a uloží (jemné buňky + záznamy bloků na řídicí mřížce), varianty pak
## běží každá ve vlastním procesu nad stejnými daty. Soubor = store_var {T, n, order, blocks: slot → {cells, hm, hf, rec}}.

const B8 = preload("res://scripts/svet8/beh.gd")
const B64 = preload("res://scripts/svet64/beh64.gd")
const BK = preload("res://scripts/svet64/blok64.gd")
const REC_KEYS := ["bp", "slot", "hm", "hm_f", "hm_raw", "bs"]

static func build(p: Dictionary, path: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var c := B8.coarse(p, int(p.s8_frames))
	var d := B64.detail(c, p, int(p.s64_bloky), false)
	var blocks := {}
	for s in d.order:
		var b: Dictionary = d.fine[s]
		var r: Dictionary = d.world.slots[s]
		var rec := {}
		for k in REC_KEYS: rec[k] = r[k]
		blocks[s] = {"cells": b.cells, "hm": b.hm, "hf": b.hf, "rec": rec}
	var data := {"T": int(c.t.T), "n": int(p.s64_n), "order": d.order, "blocks": blocks, "hash": BK.hash_cells(d.fine, d.order).left(16),
		"ms": (Time.get_ticks_usec() - t0) / 1000.0}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_var(data, false)
	f.close()
	return data

static func load_data(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var d: Dictionary = f.get_var(false)
	f.close()
	return d

## world (bp/world.gd) se záznamy bloků pro geo_fn (hm_f, bs) – funkce nad vrstvami
static func world_of(d: Dictionary):
	var w = load("res://scripts/bp/world.gd").new()
	w.w = int(d.T); w.h = int(d.T)
	for s in d.order: w.commit(d.blocks[s].rec.duplicate())
	return w
