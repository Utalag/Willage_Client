extends "res://tools/hranice_e80.gd"
## E83: determinismus. Části: --casti=beh,poradi,prekryv,citlivost --out=cesta
## beh = otisky jednoho běhu (2× v procesu; dva procesy porovná volající přes --out), poradi = pořadí vložení bloků,
## prekryv = pořadí operací překryvu, citlivost = posun řídicích hodnot o ε (riziko jiné platformy)

func h_bytes(a: PackedByteArray) -> String:
	return a.hex_encode().sha256_text().substr(0, 16)

func blocks_hash(blocks: Dictionary, order: Array, what: String) -> String:
	var a := PackedByteArray()
	for s in order:
		var b = blocks[s]
		if what == "geo": a.append_array(b.geo)
		elif what == "cells": a.append_array(b.cells)
		elif what == "hm": a.append_array(b.hm.to_byte_array())
	return h_bytes(a)

## otisky jednoho průchodu: generování → voda → tunel (E78) → živý stav → uložení → načtení
func fingerprint(spec: String, flags: Dictionary) -> Dictionary:
	T.reset()
	for k in flags: T.p[k] = flags[k]
	var g := gen_blocks(spec); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var r := {"geo": blocks_hash(blocks, order, "geo"), "cells": blocks_hash(blocks, order, "cells"), "hm": blocks_hash(blocks, order, "hm")}
	var v := OV.new(); v.build(blocks)
	r.voda = v.hydro().otisk
	var touched := {}
	sc_tunel(blocks, touched)
	if flags.get("p79_chodby", false):
		var zm := {}
		for s in touched: zm[s] = P78.sync79(blocks[s]).geo
		v.edit79(zm)
	else:
		apply_live(v, blocks, touched)
	r.prekryv = P78.otisk(blocks); r.prekryv_05 = P78.otisk(blocks, true)
	r.voda_lokalne = v.hydro().otisk
	var vf := OV.new(); vf.build(blocks); r.voda_plne = vf.hydro().otisk
	var js := JSON.stringify(P78.save(blocks, order))
	r.zaznam = js.sha256_text().substr(0, 16)
	T.reset()
	for k in flags: T.p[k] = flags[k]
	var bl2: Dictionary = P78.load_into(JSON.parse_string(js), Block, BlockGen, T)
	r.nacteno = P78.otisk(bl2)
	var v2 := OV.new(); v2.build(bl2); r.voda_nacteno = v2.hydro().otisk
	v.dispose(); vf.dispose(); v2.dispose()
	return r

func part_beh() -> Dictionary:
	var out := {}
	var variants := {"vychozi": {}, "p76_p79": {"p76_prameny": true, "p79_chodby": true}}
	for spec_name in ["START", "jine"]:
		var spec: String = START if spec_name == "START" else "0,0:kopec:7;1,0:louka:8;0,1:hora:9;1,1:sopka:10"
		for vn in variants:
			var a := fingerprint(spec, variants[vn]); var b := fingerprint(spec, variants[vn])
			var key: String = spec_name + "_" + vn
			out[key] = {"otisky": a, "druhy_beh_stejny": a == b}
			print("běh %s: 2× v procesu stejné %s, %s" % [key, a == b, JSON.stringify(a)])
	return out

## vzdálenost sloupce (x, y) bloku s od nejbližšího švu s jiným blokem ostrova (ve sloupcích 0,5 m)
static func seam_dist(s: Vector2i, x: int, y: int, present: Dictionary) -> int:
	var d := 99
	if present.has(s + Vector2i(-1, 0)): d = mini(d, x)
	if present.has(s + Vector2i(1, 0)): d = mini(d, 15 - x)
	if present.has(s + Vector2i(0, -1)): d = mini(d, y)
	if present.has(s + Vector2i(0, 1)): d = mini(d, 15 - y)
	return d

func gen_one(slot: Vector2i, kind: String, seed: int):
	var b := Block.new(); b.kind = kind; b.seed = seed; b.slot = slot
	BlockGen.build(b, [null, null, null, null]); T.commit(b); P78.attach(b)
	return b

func part_poradi() -> Dictionary:
	var out := {}
	var specs := {}
	for e in START.split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		specs[Vector2i(int(xy[0]), int(xy[1]))] = [a[1], int(a[2])]
	var orderA: Array = specs.keys()
	var orders := {"A": orderA, "obracene": orderA.duplicate(), "B": [Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]}
	orders.obracene.reverse()
	var res := {}
	for on in orders:
		T.reset()
		var bl := {}
		for s in orders[on]: bl[s] = gen_one(s, specs[s][0], specs[s][1])
		var v := OV.new(); v.build(bl)
		res[on] = {"bl": bl, "voda": v.hydro().otisk}
		v.dispose()
	# rozdíly proti pořadí A po blocích a podle vzdálenosti od švu
	for on in ["obracene", "B"]:
		var r := {"voda_stejna": res[on].voda == res.A.voda, "bloky": {}}
		for s in orderA:
			var a = res.A.bl[s]; var b = res[on].bl[s]
			var hist := {"0-1": 0, "2-5": 0, "6-15": 0}; var hmd := 0; var tot := 0
			for x in 16:
				for y in 16:
					var ci := x * 16 + y
					if a.hm[ci] != b.hm[ci]: hmd += 1
					var dd := seam_dist(s, x, y, specs)
					for z in 64:
						if a.geo[ci * 64 + z] != b.geo[ci * 64 + z]:
							tot += 1
							hist["0-1" if dd <= 1 else ("2-5" if dd <= 5 else "6-15")] += 1
			var pos_a: int = orderA.find(s); var pos_b: int = orders[on].find(s)
			r.bloky[str(s)] = {"jinych_bunek": tot, "jinych_vysek": hmd, "podle_vzdalenosti_od_svu": hist, "poradi_A": pos_a, "poradi": pos_b}
		out[on] = r
		print("pořadí %s proti A: voda stejná %s, %s" % [on, r.voda_stejna, JSON.stringify(r.bloky)])
	# pravidlo: blok závisí jen na skutečných sousedech položených před ním
	var rule := {}
	for on in orders:
		var placed := []
		for s in orders[on]:
			T.reset()
			var nb := []
			for q in placed:
				if absi(q.x - s.x) + absi(q.y - s.y) == 1: T.commit(res[on].bl[q]); nb.append(str(q))
			var b2 = gen_one(s, specs[s][0], specs[s][1])
			rule["%s_%s" % [on, s]] = {"sousede": nb, "jinych": _ndiff(b2.geo, res[on].bl[s].geo)}
			placed.append(s)
	out.jen_sousede = rule
	# diagonální a vzdálený blok
	T.reset(); var alone = gen_one(Vector2i(1, 1), specs[Vector2i(1, 1)][0], specs[Vector2i(1, 1)][1])
	T.reset(); T.commit(res.A.bl[Vector2i(0, 0)]); var diag = gen_one(Vector2i(1, 1), specs[Vector2i(1, 1)][0], specs[Vector2i(1, 1)][1])
	T.reset(); gen_one(Vector2i(4, 4), "hora", 999); var far = gen_one(Vector2i(1, 1), specs[Vector2i(1, 1)][0], specs[Vector2i(1, 1)][1])
	out.diagonalni_jinych = _ndiff(alone.geo, diag.geo); out.vzdaleny_jinych = _ndiff(alone.geo, far.geo)
	# mřížka 0,25 m z funkcí: blok (0,0) vzorkovaný sám proti po příchodu sousedů (E80)
	T.reset()
	var g := gen_blocks(START)
	var wfa := wf_all(); var b0 = g[0][Vector2i(0, 0)]; var ws0 := T.wslot(Vector2i(0, 0))
	var wf0 := FN.world_fn({ws0: T.world.slots[ws0]})
	var f025 := {}
	for n in [16, 32]:
		var c0: PackedByteArray = FN.sample_all(wf0, FN.block_info(wf0, ws0, T.world.slots[ws0].bp, T.p), n)
		var c1: PackedByteArray = FN.sample_all(wfa, info_of(wfa, b0), n)
		f025[str(n)] = _ndiff(c0, c1)
	out.funkce_po_prichodu_sousedu = f025
	print("jen sousedé: %s; diagonální %d, vzdálený %d; vzorek bloku (0,0) sám → se sousedy: %s" % [JSON.stringify(rule), out.diagonalni_jinych, out.vzdaleny_jinych, JSON.stringify(f025)])
	return out

## operace překryvu na různých buňkách ve dvou pořadích; stejná buňka: vykopat → zasypat proti zasypat → vykopat
func part_prekryv_poradi() -> Dictionary:
	return {"vychozi": prekryv_poradi(false), "p76_p79": prekryv_poradi(true)}

func prekryv_poradi(use79: bool) -> Dictionary:
	var fl := {"p76_prameny": true, "p79_chodby": true} if use79 else {}
	T.reset(); var g := gen_blocks(START); var bl: Dictionary = g[0]
	var rng := RandomNumberGenerator.new(); rng.seed = 83
	var ops := []; var used := {}
	while ops.size() < 400:
		var gx := rng.randi_range(0, 63); var gy := rng.randi_range(0, 63)
		var s := surf(bl, gx, gy)
		if s <= 4: continue
		var dig := rng.randf() < 0.7
		var fz := rng.randi_range(1, s - 1) if dig else s + rng.randi_range(0, 3)
		var key := Vector3i(gx, gy, fz)
		if used.has(key): continue
		used[key] = true; ops.append([gx, gy, fz, 0 if dig else DIRT])
	var res := {}
	for on in ["A", "B"]:
		T.reset()
		for k in fl: T.p[k] = fl[k]
		g = gen_blocks(START); bl = g[0]
		var v := OV.new(); v.build(bl)
		var seq := ops.duplicate()
		if on == "B":
			var r2 := RandomNumberGenerator.new(); r2.seed = 8383
			for i in range(seq.size() - 1, 0, -1):
				var j := r2.randi_range(0, i); var t = seq[i]; seq[i] = seq[j]; seq[j] = t
		var touched := {}; var ok := 0
		for o in seq:
			if fop(bl, touched, o[0], o[1], o[2], o[3]): ok += 1
		if use79:
			var zm := {}
			for s2 in touched: zm[s2] = P78.sync79(bl[s2]).geo
			v.edit79(zm)
		else: apply_live(v, bl, touched)
		var vf := OV.new(); vf.build(bl)
		res[on] = {"uspesnych": ok, "prekryv": P78.otisk(bl), "voda_lokalne": v.hydro().otisk, "voda_plne": vf.hydro().otisk}
		v.dispose(); vf.dispose()
	# stejná buňka
	var same := {}
	for on in ["kopat_zasypat", "zasypat_kopat"]:
		T.reset(); g = gen_blocks(START); bl = g[0]
		var t := {}
		var gx := 20; var gy := 20; var fz := surf(bl, gx, gy) - 3
		if on == "kopat_zasypat": fop(bl, t, gx, gy, fz, 0); fop(bl, t, gx, gy, fz, DIRT)
		else: fop(bl, t, gx, gy, fz, DIRT); fop(bl, t, gx, gy, fz, 0)
		same[on] = {"bunka": fget(bl, gx, gy, fz), "prekryv": P78.otisk(bl)}
	var out := {"ruzne_bunky": res, "ruzne_bunky_stejne": res.A.prekryv == res.B.prekryv and res.A.voda_plne == res.B.voda_plne, "ruzne_bunky_voda_lokalne_stejna": res.A.voda_lokalne == res.B.voda_lokalne, "stejna_bunka": same}
	print("překryv (p79 %s): různé buňky %s, stejná buňka %s" % [use79, JSON.stringify(res), JSON.stringify(same)])
	return out

## citlivost: řídicí hodnoty (povrch, hranice) + ε → kolik buněk se změní při 0,5 a 0,25 m
func part_citlivost() -> Dictionary:
	T.reset(); var g := gen_blocks(START); var bl: Dictionary = g[0]
	var out := {}
	var base := {}
	for eps_m in [1e-12, 1e-9, 1e-6, 1e-3]:
		for sg in [1.0, -1.0]:
			var key := "%s%s" % ["+" if sg > 0 else "-", String.num_scientific(eps_m)]
			var slots := {}
			for ws in T.world.slots:
				var r: Dictionary = T.world.slots[ws].duplicate()
				var hm2 := PackedFloat64Array(r.hm_f)
				for i in hm2.size(): hm2[i] += sg * eps_m / FN.U
				r.hm_f = hm2
				var bs2 := []
				for a in r.bs:
					var c := PackedFloat64Array(a)
					for i in c.size(): c[i] += sg * eps_m / FN.U
					bs2.append(c)
				r.bs = bs2
				if r.has("hm_pre"):
					var hp := PackedFloat64Array(r.hm_pre)
					for i in hp.size(): hp[i] += sg * eps_m / FN.U
					r.hm_pre = hp
				slots[ws] = r
			var wf2 := FN.world_fn(slots); var wf1 := wf_all()
			var e := {}
			for n in [16, 32]:
				var d := 0; var tot := 0
				for s in g[1]:
					var ws := T.wslot(s)
					var bkey := "%s_%d" % [s, n]
					if not base.has(bkey): base[bkey] = FN.sample_all(wf1, FN.block_info(wf1, ws, T.world.slots[ws].bp, T.p), n)
					var c2: PackedByteArray = FN.sample_all(wf2, FN.block_info(wf2, ws, slots[ws].bp, T.p), n)
					d += _ndiff(base[bkey], c2); tot += c2.size()
				e[str(n)] = {"jinych": d, "z": tot}
			out[key] = e
			print("citlivost %s: %s" % [key, JSON.stringify(e)])
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/determinismus_e83.gd": return
	T.reset()
	var out := {}
	var parts := _arg("casti", "beh,poradi,prekryv,citlivost").split(",")
	if "beh" in parts: out.beh = part_beh()
	if "poradi" in parts: out.poradi = part_poradi()
	if "prekryv" in parts: out.prekryv = part_prekryv_poradi()
	if "citlivost" in parts: out.citlivost = part_citlivost()
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
