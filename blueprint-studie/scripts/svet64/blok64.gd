extends RefCounted
## E50: jeden detailní blok v jemných buňkách n × n × 4n (výchozí 64 × 64 × 256, buňka 8/n m).
## Navázání na sousedy (povrch + mocnosti vrstev) běží na řídicí mřížce 16 × 16 kroky pipeline v2 (stejné jako E49);
## buňky jsou vzorky spojitých funkcí (geo_fn, Jan 16:42), minerály a dutiny drží objem (× (n/16)³).
## Fáze bloku s časem: navázání, vrstvy (cíle + vzorky), minerály, dutiny. Vsakování a validátor gen-v3 jsou jen 16³·4 → vynechány.

const PL = preload("res://scripts/bp/pipeline.gd")
const FN = preload("res://scripts/bp/geo_fn.gd")
const MN = preload("res://scripts/bp/minerals.gd")
const BP = preload("res://scripts/bp/blueprint.gd")
const Mat = preload("res://scripts/kopie/mat.gd")
const M = preload("res://scripts/svet64/mereni.gd")

## krok pipeline → fáze E50
static func _phase(label: String) -> String:
	if label.begins_with("povrch: dorovnání") or label.begins_with("vrstvy: mocnost"): return "navázání"
	if label.begins_with("povrch") or label.begins_with("vrstvy"): return "vrstvy"
	return ""

static func run(world, slot: Vector2i, bp: Dictionary, p: Dictionary) -> Dictionary:
	var n := int(p.s64_n); var NZ := 4 * n
	var ms := {"navázání": 0.0, "vrstvy": 0.0, "minerály": 0.0, "dutiny": 0.0}
	var ctx := PL.new_ctx(world, slot, bp, p)
	for st in PL.steps_v2(ctx):
		var ph := _phase(st[0])
		if ph == "": continue
		var t0 := Time.get_ticks_usec()
		st[1].call()
		ms[ph] += M.ms(t0)
	var t1 := Time.get_ticks_usec()
	var cells := FN.sample_all(ctx.wf, ctx.fi, n)
	var hm := PackedInt32Array(); hm.resize(n * n)
	var hf := PackedFloat32Array(); hf.resize(n * n)   # spojitý povrch v buňkách (pro vodu a stínování)
	var c := FN.BW / n
	for x in n:
		for y in n:
			var i := x * n + y
			var h := 0
			for z in NZ:
				if cells[i * NZ + z] != Mat.AIR: h = z + 1
			hm[i] = h
			hf[i] = FN.surface_m(ctx.wf, slot, slot.x * FN.BW + (x + 0.5) * c, slot.y * FN.BW + (y + 0.5) * c) / c
	ms["vrstvy"] += M.ms(t1)
	var mins := []
	t1 = Time.get_ticks_usec()
	for m in MN.order(bp.minerals):
		if FN.is_cavity(m): continue
		mins.append(FN.mineral_one(cells, n, ctx.wf, ctx.fi, m, int(bp.minerals[m]), bp.seed))
	ms["minerály"] = M.ms(t1)
	var cav := []
	t1 = Time.get_ticks_usec()
	var val := BP.validate(bp)
	for m in MN.order(bp.minerals):
		if not FN.is_cavity(m) or not val.ok or int(bp.minerals[m]) <= 0: continue
		cav.append(FN.cavity_one(cells, n, ctx.wf, ctx.fi, m, int(bp.minerals[m]), bp.seed))
	ms["dutiny"] = M.ms(t1)
	# záznam na řídicí mřížce pro sousedy (navázání čte hm_f a bs), jemné buňky zvlášť
	var hm16 := PackedInt32Array(); hm16.resize(256)
	for i in 256: hm16[i] = int(ceil(ctx.hm_f[i]))
	var rec := {"bp": bp, "slot": slot, "hm": hm16, "hm_f": ctx.hm_f, "hm_raw": ctx.hm_raw, "changed": ctx.changed, "bs": ctx.bs,
		"cells": PackedByteArray(), "water": PackedInt32Array(), "rep": ctx.rep, "ms": ms}
	world.commit(rec)
	var short := 0; var target := 0
	for r in mins: short += int(r.shortfall); target += int(r.target)
	var cav_n := 0; var cav_t := 0
	for r in cav: cav_n += int(r.placed); cav_t += int(r.target)
	return {"slot": slot, "cells": cells, "hm": hm, "hf": hf, "ms": ms, "min_target": target, "min_short": short,
		"cav_placed": cav_n, "cav_target": cav_t, "n_min": mins.size()}

## SHA-256 jemných buněk v pořadí slotů
static func hash_cells(fine: Dictionary, order: Array) -> String:
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256)
	for s in order:
		var hdr := PackedByteArray(); hdr.resize(2); hdr.encode_u8(0, s.x); hdr.encode_u8(1, s.y)
		hc.update(hdr); hc.update(fine[s].cells)
	return hc.finish().hex_encode()
