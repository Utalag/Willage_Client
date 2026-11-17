extends RefCounted
## cave-v0: celý řetězec (terén → jeskyně → voda → rudy), vektory, zátěž, kontrola simulací voda-studie, kopání, bench.

const Mat = preload("res://scripts/mat.gd")
const Ore = preload("res://scripts/ore_v0.gd")
const Cave = preload("res://scripts/cave_v0.gd")
const T = preload("res://scripts/tests.gd")
const VSim = preload("res://scripts/voda_sim.gd")
const VPar = preload("res://scripts/voda_params.gd")
const VM = preload("res://scripts/voda_mat.gd")
const BS := 16
const BH := 64

## cave_x: násobek jeskyní (bez rezervoáru), water_x: násobek vody (rezervoár roste s ní, jak to vydá server)
static func pipeline(kind: String, seed: int, bonus := 0, cave_x := 1, water_x := 1, rock_override := -1) -> Dictionary:
	var b := T.base_block(kind, seed)
	var cells := b.cells.duplicate()
	if rock_override >= 0:   # zátěž: všechny horniny nahradit jedním materiálem
		for i in cells.size():
			if cells[i] in [Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT]:
				cells[i] = rock_override
	var hm := b.hm
	var ct := Cave.server_target(kind, seed, bonus)
	var w0: int = ct.water
	var shapes: int = ct.cave_air - Cave.reservoir_size(w0)
	ct.water = w0 * water_x
	ct.cave_air = shapes * cave_x + Cave.reservoir_size(ct.water)
	var t0 := Time.get_ticks_usec()
	var cr := Cave.carve(cells, hm, seed, ct)
	var t1 := Time.get_ticks_usec()
	var prefer := PackedByteArray()
	prefer.resize(cells.size())
	for c in cr.per_ore[0].cells:
		prefer[c] = 1
	var wr := Cave.fill_water(cells, hm, ct.water, prefer)
	var t2 := Time.get_ticks_usec()
	var air_before_ores := Cave.cave_air(cells, hm)
	var sk := Ore.specs_for(kind)
	var ot := Ore.server_target(seed, bonus, sk)
	var orr := Ore.place(cells, seed, ot, sk)
	var t3 := Time.get_ticks_usec()
	var val := Cave.validate(cells, hm, wr.water)
	var t4 := Time.get_ticks_usec()
	return {"kind": kind, "seed": seed, "cells": cells, "hm": hm, "water": wr.water, "cave_target": ct, "cave": cr, "water_rep": wr,
		"ore": orr, "ore_target": ot, "valid": val, "ores_kept_caves": Cave.cave_air(cells, hm) == air_before_ores,
		"ms": {"caves": (t1 - t0) / 1000.0, "water": (t2 - t1) / 1000.0, "ores": (t3 - t2) / 1000.0, "validate": (t4 - t3) / 1000.0}}

static func _levels(rep: Dictionary) -> Dictionary:
	var lv := {}
	for i in 6:
		if rep.by_level[i] > 0:
			lv[Ore.LEVELS[i]] = rep.by_level[i]
	return lv

static func case_doc(id: String, note: String, r: Dictionary) -> Dictionary:
	var shapes := []
	for rep in r.cave.per_ore:
		shapes.append({"shape": rep.key, "target": rep.target, "placed": rep.placed, "shortfall": rep.shortfall, "byLevel": _levels(rep)})
	var ores := []
	for rep in r.ore.per_ore:
		ores.append({"ore": Mat.NAMES[rep.material], "materialId": rep.material, "target": rep.target, "placed": rep.placed, "shortfall": rep.shortfall, "byLevel": _levels(rep)})
	var wr: Dictionary = r.water_rep
	var hdr := Ore.shortfall_header(r.ore)
	var sf: Dictionary = hdr.shortfall.duplicate()
	if r.cave.cave_air_shortfall > 0:
		sf["cave_air"] = r.cave.cave_air_shortfall
	if wr.shortfall > 0:
		sf["water"] = wr.shortfall
	var summ := Ore.count(r.cells)
	var sm := {}
	for m in range(1, Mat.COUNT):
		if summ[m] > 0:
			sm[Mat.NAMES[m]] = summ[m]
	sm["vzduch (jeskyně)"] = Cave.cave_air(r.cells, r.hm)
	sm["voda (objem, buňky)"] = Cave.water_volume(r.water)
	var wb := PackedByteArray()
	for v in r.water:
		wb.append(v & 255); wb.append(v >> 8)
	return {"id": id, "recipe": r.kind, "seed": r.seed, "note": note,
		"caveTarget": r.cave_target, "caveAirPlaced": r.cave.cave_air_placed, "shapes": shapes,
		"water": {"target": wr.target, "placed": wr.placed, "shortfall": wr.shortfall, "sealedCells": wr.sealed, "sealRounds": wr.seal_rounds, "basinsUsed": wr.basins_used},
		"ores": ores, "oresKeptCaves": r.ores_kept_caves,
		"wvb1Header": {"shortfall": sf, "serverAcceptsOres": hdr.accepted},
		"validator": {"ok": r.valid.ok, "errorCount": r.valid.error_count, "firstErrors": r.valid.errors.slice(0, 3)},
		"summary": sm,
		"sha256MaterialLayer": T.sha256(r.cells), "sha256WaterLayer": T.sha256(wb)}

static func vectors(path: String) -> Array:
	var out := []
	var rs := []
	for kc in [["louka", 101], ["louka", 404], ["kopec", 303], ["kopec", 2302], ["hora", 202], ["hora", 1000], ["piscina", 4504]]:
		var r := pipeline(kc[0], kc[1])
		rs.append(r)
		out.append(case_doc("%s_%d" % kc, "běžný cíl", r))
	out.append(case_doc("zatez_jeskyne_x5_hora202", "jeskyně ×5", pipeline("hora", 202, 0, 5)))
	out.append(case_doc("zatez_jeskyne_x10_louka101", "jeskyně ×10", pipeline("louka", 101, 0, 10)))
	out.append(case_doc("zatez_voda_x5_hora1000", "voda ×5 (rezervoár roste s ní)", pipeline("hora", 1000, 0, 1, 5)))
	out.append(case_doc("zatez_vse_vapenec_hora202", "všechny horniny = vápenec (propustný 0,10 > 0,05): rezervoár musí utěsnit", pipeline("hora", 202, 0, 1, 2, Mat.LIMESTONE)))
	out.append(case_doc("zatez_vse_pisek_louka101", "všechny horniny = písek (0,80): těsnění jílem", pipeline("louka", 101, 0, 1, 2, Mat.SAND)))
	out.append(case_doc("zatez_vse_zula_louka101", "všechny horniny = žula: bez úniku", pipeline("louka", 101, 0, 2, 2, Mat.GRANITE)))
	var doc := {"caveVersion": "cave-v0-study-1", "order": "terén → horniny → jeskyně → voda → rudy",
		"waterLayer": "u16 na buňku, %d = plná buňka (= jednotka water_total ve WVB1, 1/4096)" % Cave.FULL,
		"permeable": "propustnost z voda-studie > %.2f (písek 0,80, hlína 0,30, tráva 0,25, vápenec 0,10 propustné; jíl, žula, čedič, rudy ne)" % Cave.perm_leak,
		"roof": Cave.ROOF, "margin": Cave.MARGIN, "reservoirHeadroomPct": Cave.RES_HEAD_PCT,
		"cases": out}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	return out

## ---------- simulace voda-studie na vygenerovaném bloku
static func _sim_mat(m: int) -> int:
	match m:
		Mat.COPPER, Mat.IRON, Mat.FOG: return VM.GRANITE
		Mat.CLAY_DEPOSIT: return VM.CLAY
		Mat.SNOW: return VM.DIRT
	return m

static func make_sim(cells: PackedByteArray, water: PackedInt32Array, evap := false) -> Object:
	if not VPar.P.has("perm_dirt"):
		VPar.apply_shared_table()
	var P: Dictionary = VPar.P.duplicate()
	if not evap:
		P.evap = 0.0; P.evap_soil = 0.0
	var s := VSim.new(BS, BS, BH, P)
	s.open_sides = 15
	for x in BS:
		for y in BS:
			for z in BH:
				var c := (x * BS + y) * BH + z
				var i := x + y * BS + z * BS * BS
				s.mat[i] = _sim_mat(cells[c])
				s.w[i] = float(water[c]) / Cave.FULL
	s.reset_props()
	return s

static func sim_run(cells: PackedByteArray, water: PackedInt32Array, ticks: int, evap := false) -> Dictionary:
	var s = make_sim(cells, water, evap)
	var w0: PackedFloat32Array = s.w.duplicate()
	var tot0: float = s.total()
	var t0 := Time.get_ticks_usec()
	for k in ticks:
		s.step()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / ticks
	var moved := 0.0
	var in_solid := 0.0
	for i in s.w.size():
		moved += absf(s.w[i] - w0[i])
		if s.mat[i] != VM.AIR:
			in_solid += s.w[i]
	return {"ticks": ticks, "volume0": tot0, "volume": s.total(), "drift": s.total() - tot0, "out": s.out_total, "evap": s.evap_total,
		"moved_half": moved * 0.5, "in_solid": in_solid, "ms_tick": ms, "sim": s}

## kopání: chodba 2 buňky vysoká od nejnižší vodní vrstvy největší pánve do strany (8 buněk), pak simulace
static func dig_test(r: Dictionary, ticks: int, above := false) -> Dictionary:
	var cells: PackedByteArray = r.cells.duplicate()
	var water: PackedInt32Array = r.water.duplicate()
	var bs := Cave.basins(cells, r.hm)
	var best := {}
	var bw := 0
	for b in bs:
		var s := 0
		for c: int in b.cells:
			s += water[c]
		if s > bw:
			bw = s; best = b
	if best.is_empty():
		return {"ok": false, "reason": "bez vody"}
	# vybraná vrstva: nejnižší vodní (pod hladinou) nebo první suchá nad hladinou (kontrola)
	var zsel := 999
	var ztop := -1
	for c: int in best.cells:
		if water[c] > 0:
			zsel = mini(zsel, c % BH); ztop = maxi(ztop, c % BH)
	if above:
		zsel = ztop + 1
	var start := -1
	var dirx := 1
	for c: int in best.cells:
		if c % BH != zsel:
			continue
		var x := c / (BS * BH)
		if start < 0 or x > start / (BS * BH):
			start = c
	if start < 0:
		return {"ok": false, "reason": "vrstva %d v pánvi není" % zsel}
	var sx := start / (BS * BH); var sy := (start / BH) % BS
	if sx > 7:
		dirx = -1
		for c: int in best.cells:   # od nejmenšího x doleva by bylo krátké, jdeme od nejmenšího x opačně
			if c % BH == zsel and c / (BS * BH) < sx:
				sx = c / (BS * BH); sy = (c / BH) % BS
		dirx = -1
	var dug := PackedInt32Array()
	var x: int = sx + dirx
	while dug.size() < 16 and x >= 1 and x <= BS - 2:
		for dz in 2:
			var c := (x * BS + sy) * BH + zsel + dz
			if cells[c] != Mat.AIR:
				cells[c] = Mat.AIR; dug.append(c)
		x += dirx
	var val := Cave.validate(cells, r.hm, water)
	var sr := sim_run(cells, water, ticks)
	var s = sr.sim
	var in_tunnel := 0.0
	for c in dug:
		var cx := c / (BS * BH); var cy := (c / BH) % BS; var cz := c % BH
		in_tunnel += s.w[cx + cy * BS + cz * BS * BS]
	return {"ok": true, "layer": zsel, "dug": dug.size(), "validatorAfterDig": {"ok": val.ok, "errors": val.error_count},
		"waterInTunnel": in_tunnel, "drift": sr.drift, "out": sr.out, "in_solid": sr.in_solid, "cells": cells, "sim": s, "dug_cells": dug}

static func sim_report(path: String, nblocks := 8, ticks := 600) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Kontrola stability: simulace voda-studie (kopie water_sim.gd, výchozí parametry, odpar 0, všechny strany bloku odtékají), %d tiků" % ticks)
	lines.append("blok | voda (buňky) | posun objemu | odtok z bloku | voda v pórech | přesunuto (½Σ|Δw|) | validátor | ms/tik")
	var kinds := ["louka", "kopec", "hora", "piscina"]
	for i in nblocks:
		var k: String = kinds[i % 4]
		var seed := 7000 + i * 31
		var r := pipeline(k, seed)
		var sr := sim_run(r.cells, r.water, ticks)
		lines.append("%s %d | %.3f | %+.6f | %.6f | %.6f | %.6f | %s | %.1f" % [k, seed, sr.volume0, sr.drift, sr.out, sr.in_solid, sr.moved_half, "OK" if r.valid.ok else "CHYBA", sr.ms_tick])
	# zátěž: vápenec všude (těsnění) a s odparem
	var rl := pipeline("hora", 202, 0, 1, 2, Mat.LIMESTONE)
	var s2 := sim_run(rl.cells, rl.water, ticks)
	lines.append("hora 202 vše vápenec (utěsněno %d buněk) | %.3f | %+.6f | %.6f | %.6f | %.6f | %s | %.1f" % [rl.water_rep.sealed, s2.volume0, s2.drift, s2.out, s2.in_solid, s2.moved_half, "OK" if rl.valid.ok else "CHYBA", s2.ms_tick])
	# kontrola bez těsnění: stejný blok, voda nalitá i nad hladinu (co by server odmítl)
	var bad: PackedInt32Array = rl.water.duplicate()
	var bs := Cave.basins(rl.cells, rl.hm)
	for b in bs:
		for c: int in b.cells:
			bad[c] = Cave.FULL
	var vb := Cave.validate(rl.cells, rl.hm, bad)
	var s3 := sim_run(rl.cells, bad, ticks)
	lines.append("NEGATIVNÍ: všechny pánve plné až po strop | %.3f | %+.6f | %.6f | %.6f | %.6f | validátor %d chyb | %.1f" % [s3.volume0, s3.drift, s3.out, s3.in_solid, s3.moved_half, vb.error_count, s3.ms_tick])
	var r9 := pipeline("hora", 1000)
	var s4 := sim_run(r9.cells, r9.water, ticks, true)
	lines.append("hora 1000 s odparem voda-studie (0,0005/tik a sloupec) | %.3f | %+.6f (odpar %.4f) | %.6f | | | | %.1f" % [s4.volume0, s4.drift, s4.evap, s4.out, s4.ms_tick])
	lines.append("")
	lines.append("Kopání do rezervoáru (chodba 2 buňky vysoká, až 8 buněk do strany), %d tiků:" % ticks)
	for kc in [["hora", 1000], ["kopec", 303], ["hora", 202]]:
		var r := pipeline(kc[0], kc[1], 0, 1, 2)
		var d := dig_test(r, ticks)
		var d2 := dig_test(r, ticks, true)
		if d.ok:
			lines.append("%s %d: pod hladinou (vrstva %d, %d buněk) → voda v chodbě %.2f buněk, validátor po prokopání %d chyb, odtok %.4f | nad hladinou (vrstva %s): voda v chodbě %.4f" % [kc[0], kc[1], d.layer, d.dug, d.waterInTunnel, d.validatorAfterDig.errors, d.out, str(d2.get("layer", "-")), d2.get("waterInTunnel", 0.0)])
		else:
			lines.append("%s %d: %s" % [kc[0], kc[1], d.reason])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return lines

static func stress(path: String, nseeds := 30) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Zátěž cave-v0: %d seedů × 4 recepty. Jeskyně: naplnění a podíl tvarů se stupněm L1/L2/L3/L4/L5. Voda: naplnění, těsnění, validátor." % nseeds)
	lines.append("recept | měřítko | jeskyně cíl→umístěno | L1 / L2 / L3 / L4 / L5 | voda cíl→umístěno | těsnění (bloků, buněk) | validátor OK | rudy přesně | ms jeskyně / voda / rudy")
	var scales := [["běžné", 0, 1, 1], ["bonus 50 %", 50, 1, 1], ["jeskyně ×3", 0, 3, 1], ["jeskyně ×5", 0, 5, 1], ["jeskyně ×10", 0, 10, 1], ["voda ×3", 0, 1, 3], ["voda ×5", 0, 1, 5]]
	for k in ["louka", "kopec", "hora", "piscina"]:
		for sc in scales:
			var ct := 0; var cp := 0; var wt := 0; var wp := 0.0
			var trig := [0, 0, 0, 0, 0, 0]
			var nsh := 0; var sealed_b := 0; var sealed_c := 0; var vok := 0; var oex := 0
			var ms := [0.0, 0.0, 0.0]
			for s in nseeds:
				var r := pipeline(k, 5000 + s * 17, sc[1], sc[2], sc[3])
				ct += r.cave.cave_air_target; cp += r.cave.cave_air_placed
				for rep in r.cave.per_ore:
					if rep.target > 0:
						nsh += 1
						for i in range(1, 6):
							if rep.by_level[i] > 0:
								trig[i] += 1
				wt += r.water_rep.target; wp += r.water_rep.placed
				if r.water_rep.sealed > 0:
					sealed_b += 1; sealed_c += r.water_rep.sealed
				if r.valid.ok:
					vok += 1
				if r.ore.ok and r.ores_kept_caves:
					oex += 1
				ms[0] += r.ms.caves; ms[1] += r.ms.water; ms[2] += r.ms.ores
			var p := func(v): return "%.0f %%" % (100.0 * v / maxi(nsh, 1))
			lines.append("%-7s | %-11s | %6d→%6d (%.2f %%) | %s / %s / %s / %s / %s | %5d→%8.1f (%.2f %%) | %d, %d | %d/%d | %d/%d | %.1f / %.1f / %.1f" % [k, sc[0], ct, cp, 100.0 * cp / maxi(ct, 1),
				p.call(trig[1]), p.call(trig[2]), p.call(trig[3]), p.call(trig[4]), p.call(trig[5]), wt, wp, 100.0 * wp / maxi(wt, 1),
				sealed_b, sealed_c, vok, nseeds, oex, nseeds, ms[0] / nseeds, ms[1] / nseeds, ms[2] / nseeds])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return lines
