extends RefCounted
## Vektory (vectors/ore_v0_vectors.json), zátěžové testy (shots/stress.txt) a bench (shots/bench.txt).

const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const H = preload("res://scripts/stable_hash.gd")
const Ore = preload("res://scripts/ore_v0.gd")

const ORE_VERSION := "ore-v0.2-target"   # v0.2: ložiskový jíl vlastní ID, nižší zásoby, pořadí podle receptu, strop 5×, hlavička shortfall   # ore-v0 tvary + přesný cílový souhrn + záložní stupně L1–L5

static func base_block(kind: String, seed: int, rot := 0, mirror := false, shift := 0) -> Block:
	BlockGen.legacy_ore = false
	var b := Block.new()
	b.kind = kind; b.seed = seed; b.rot = rot; b.mirror = mirror; b.shift = shift
	BlockGen.build(b, [null, null, null, null])
	return b

static func legacy_block(kind: String, seed: int) -> Block:
	BlockGen.legacy_ore = true
	var b := Block.new()
	b.kind = kind; b.seed = seed
	BlockGen.build(b, [null, null, null, null])
	BlockGen.legacy_ore = false
	return b

## malý hostitel: všechna žula a vápenec -> čedič, kromě kostky žuly 3 × 3 × 3 (27 buněk)
static func tiny_host(cells: PackedByteArray) -> PackedByteArray:
	var c := cells.duplicate()
	for i in c.size():
		if c[i] == Mat.GRANITE or c[i] == Mat.LIMESTONE:
			c[i] = Mat.BASALT
	for x in range(6, 9):
		for y in range(6, 9):
			for z in range(14, 17):
				c[Ore.idx(x, y, z)] = Mat.GRANITE
	return c

## čistý vzorek pro tvary: celý objem pod lz 48 = hostitel tvaru
static func solid(mat: int) -> PackedByteArray:
	var c := PackedByteArray()
	c.resize(Ore.N)
	for i in c.size():
		if i % Ore.BH < 48:
			c[i] = mat
	return c

static func sha256(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return h.finish().hex_encode()

static func _names(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[Mat.NAMES[k]] = d[k]
	return o

static func _summary(s: PackedInt32Array) -> Dictionary:
	var o := {}
	for m in Mat.COUNT:
		if s[m] > 0:
			o[Mat.NAMES[m]] = s[m]
	return o

## jeden testovací případ: rozmístí target, ověří přesnost proti přepočtu objemu
static func run_case(id: String, kind: String, seed: int, cells: PackedByteArray, target: Dictionary, specs: Array, note: String, transform := {}) -> Dictionary:
	var before := Ore.count(cells)
	var c := cells.duplicate()
	var t0 := Time.get_ticks_usec()
	var res := Ore.place(c, seed, target, specs)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var after := Ore.count(c)
	var ores := []
	var all_exact := true
	for rep in res.per_ore:
		var m: int = rep.material
		var delta := after[m] - before[m]
		var exact: bool = rep.placed == rep.target and delta == rep.placed
		all_exact = all_exact and exact
		var lv := {}
		for i in 6:
			if rep.by_level[i] > 0:
				lv[Ore.LEVELS[i]] = rep.by_level[i]
		ores.append({"ore": Mat.NAMES[m], "materialId": m, "target": rep.target, "placed": rep.placed,
			"volumeDelta": delta, "shortfall": rep.shortfall, "exact": exact, "byLevel": lv,
			"seeds": {"planned": rep.seeds_planned, "placed": rep.seeds_placed, "dropped": rep.seeds_dropped, "extra": rep.extra_seeds}})
	return {"id": id, "recipe": kind, "seed": seed, "note": note, "transform": transform,
		"wvb1Header": _hdr(Ore.shortfall_header(res)),
		"oreSpecs": specs.map(func(s): return s.name),
		"target": _names(target), "placed": _names(res.placed), "shortfall": _names(res.shortfall),
		"allExact": all_exact, "ores": ores,
		"materialSummaryBefore": _summary(before), "materialSummaryAfter": _summary(after),
		"rarityV2After": {"score": snappedf(Mat.score_of(after), 0.0001), "class": Mat.rarity_of(after)},
		"sha256MaterialLayer": sha256(c), "fnv1a64MaterialLayer": H.hex(H.fnv1a64_bytes(c)),
		"_ms": ms, "_cells": c}

static func _hdr(h: Dictionary) -> Dictionary:
	var sf := {}
	for k in h.shortfall:
		sf[k] = h.shortfall[k]
	return {"shortfall": sf, "shortfallNames": _names_s(sf), "serverAccepts": h.accepted}

static func _names_s(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[Mat.NAMES[int(k)]] = d[k]
	return o

## kapacita hostitele: průměrný počet hostitelských buněk v rozsahu lz na blok (pro pořadí rud v receptu)
static func host_table(nseeds := 40) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Hostitel v rozsahu lz (průměr buněk na blok, %d seedů) – menší = užší hostitel = dřív v pořadí" % nseeds)
	for k in ["louka", "kopec", "hora", "piscina"]:
		var row := []
		for key in ["copper", "iron", "clay"]:
			var sp: Dictionary = Ore.CATALOG[key]
			var tot := 0
			for s in nseeds:
				var c := base_block(k, 5000 + s * 17).cells
				for i in c.size():
					var z := i % 64
					if z >= sp.lz[0] and z <= sp.lz[1] and c[i] in sp.host:
						tot += 1
			row.append("%s %d" % [key, tot / nseeds])
		lines.append("%-7s %s" % [k, ", ".join(row)])
	return lines

static func cases() -> Array:
	var out := []
	var S: Array = Ore.specs_for("louka")
	var CU: Dictionary = Ore.CATALOG.copper
	var FE: Dictionary = Ore.CATALOG.iron
	var CL: Dictionary = Ore.CATALOG.clay
	# 1) golden: 3 recepty × 2 seedy (stejné seedy jako vectors.json), bonus 0 % a 25 %
	for kc in [["louka", 101], ["louka", 404], ["kopec", 303], ["kopec", 2302], ["hora", 202], ["hora", 1000]]:
		var b := base_block(kc[0], kc[1])
		var sk := Ore.specs_for(kc[0])
		for bonus in [0, 25]:
			out.append(run_case("%s_%d_bonus%d" % [kc[0], kc[1], bonus], kc[0], kc[1], b.cells,
				Ore.server_target(kc[1], bonus, sk), sk, "golden: cíl ze server_target(seed, bonus), pořadí receptu"))
	# 2) každý tvar zvlášť (jedna ruda) na hoře 202 a v čistém hostiteli
	var h := base_block("hora", 202)
	for si in 3:
		var sp: Dictionary = S[si]
		out.append(run_case("tvar_%s_hora202" % sp.name, "hora", 202, h.cells, {sp.material: 150}, [sp], "jen %s (%s), cíl 150" % [sp.name, sp.shape]))
	out.append(run_case("tvar_vein_solid", "solid", 7, solid(Mat.GRANITE), {Mat.COPPER: 150}, [CU], "čistá žula, žíla 150"))
	out.append(run_case("tvar_pocket_solid", "solid", 7, solid(Mat.GRANITE), {Mat.IRON: 150}, [FE], "čistá žula, čočka 150"))
	out.append(run_case("tvar_layer_solid", "solid", 7, solid(Mat.DIRT), {Mat.CLAY_DEPOSIT: 150}, [CL], "čistá hlína, sloj 150"))
	# 3) zátěž
	var l := base_block("louka", 101)
	out.append(run_case("zatez_velky_cil_louka", "louka", 101, l.cells, {Mat.COPPER: 3000, Mat.IRON: 3000, Mat.CLAY_DEPOSIT: 1500}, S, "obří cíle"))
	out.append(run_case("zatez_velky_cil_hora", "hora", 202, h.cells, {Mat.COPPER: 3000, Mat.IRON: 3000, Mat.CLAY_DEPOSIT: 1500}, S, "obří cíle"))
	out.append(run_case("zatez_maly_hostitel", "louka", 101, tiny_host(l.cells), {Mat.COPPER: 200, Mat.IRON: 60}, S, "jen 27 buněk žuly, zbytek čedič"))
	out.append(run_case("zatez_nad_kapacitu", "louka", 101, l.cells, {Mat.COPPER: 20000}, S, "cíl větší než celý objem → schodek"))
	out.append(run_case("nulovy_cil", "louka", 101, l.cells, {}, S, "prázdný cíl = beze změny"))
	# 4) transformace (rudy se rozmisťují až v cílovém objemu po transformaci)
	var tb := base_block("hora", 202, 1, true, 2)
	out.append(run_case("transform_hora_202", "hora", 202, tb.cells, Ore.server_target(202, 0, Ore.specs_for("hora")), Ore.specs_for("hora"), "zrcadlení + rotace 90° + posun +2",
		{"mirror": true, "rotation": 90, "heightShift": 2}))
	return out

static func export_vectors(path: String) -> Array:
	var cs := cases()
	var clean := []
	for c in cs:
		var d: Dictionary = c.duplicate()
		d.erase("_ms"); d.erase("_cells")
		clean.append(d)
	var spec_doc := []
	for sp in Ore.SPECS:
		var d: Dictionary = sp.duplicate(true)
		d.material = Mat.NAMES[sp.material]
		d.host = sp.host.map(func(m): return Mat.NAMES[m])
		d.relax = sp.relax.map(func(l): return l.map(func(m): return Mat.NAMES[m]))
		spec_doc.append(d)
	var doc := {
		"oreVersion": ORE_VERSION,
		"generatorVersion": "proto-v2.2 bez šumových rud (legacy_ore = false)",
		"primaryCheck": "pro každou rudu placed == target a zároveň rozdíl počtu buněk v objemu == placed; jinak shortfall > 0 výslovně",
		"hashes": "sha256MaterialLayer / fnv1a64MaterialLayer jen pro opakovatelnost v Godotu (bitová shoda s C# už není požadavek, Jan 18:24)",
		"levels": Ore.LEVELS,
		"rng": "SplitMix64: stav = mix(seed,'ORE',specIndex); next = splitmix64(stav), stav += 0x9E3779B97F4A7C15; u16 = next>>>48; range(a,b) = a + (next>>>33) % (b-a+1)",
		"probabilities": {"pocket": Ore.P_POCKET, "layerH": Ore.P_LAYER_H, "layerV": Ore.P_LAYER_V, "veinKeep": Ore.P_VEIN_KEEP, "rule": "přijmout když u16 < P, P = floor(p*65536)"},
		"serverTargetStandIn": "server_target(seed, bonus%): r = SplitMix64(mix(seed,'ORE_TARGET',i)); n = range(seeds); base = Σ range(supply); target = base + base*bonus/100",
		"cell_index": "(lx*16+ly)*64+lz",
		"specs": spec_doc,
		"cases": clean,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	return cs

## zátěž: N seedů × recepty × měřítka cíle; míra naplnění a jak často běží záložní stupně
static func stress(path: String, nseeds := 40) -> void:
	var lines := PackedStringArray()
	lines.append("Zátěž ore-v0 + cílový souhrn: %d seedů × 4 recepty; měřítko = násobek cíle ze server_target(seed, bonus)" % nseeds)
	lines.append("sloupce: recept | měřítko | cíl celkem | umístěno | naplnění | podíl umístění rud se stupněm L1 / L2 / L3 / L4 / L5(schodek) | ms/blok")
	var scales := [["bonus 0 %", 0, 1], ["bonus 50 %", 50, 1], ["bonus 200 %", 200, 1], ["×5 (strop)", 0, 5], ["×20", 0, 20], ["×60", 0, 60]]
	var kinds := ["louka", "kopec", "hora", "piscina"]
	var bases := {}
	for k in kinds:
		bases[k] = []
		for s in nseeds:
			bases[k].append(base_block(k, 5000 + s * 17).cells)
	for k in kinds:
		for sc in scales:
			var tt := 0; var pp := 0; var nore := 0
			var trig := [0, 0, 0, 0, 0, 0]
			var ms := 0.0
			for s in nseeds:
				var seed := 5000 + s * 17
				var sk := Ore.specs_for(k)
				var tg := Ore.server_target(seed, sc[1], sk, false)
				for m in tg:
					tg[m] = tg[m] * sc[2]
				var c: PackedByteArray = bases[k][s].duplicate()
				var t0 := Time.get_ticks_usec()
				var res := Ore.place(c, seed, tg, sk)
				ms += (Time.get_ticks_usec() - t0) / 1000.0
				for rep in res.per_ore:
					if rep.target <= 0:
						continue
					nore += 1
					tt += rep.target; pp += rep.placed
					for i in range(1, 6):
						if rep.by_level[i] > 0:
							trig[i] += 1
			var pct := func(v): return "%5.1f %%" % (100.0 * v / maxi(nore, 1))
			lines.append("%-7s | %-11s | %7d | %7d | %6.2f %% | %s / %s / %s / %s / %s | %.2f" % [k, sc[0], tt, pp, 100.0 * pp / maxi(tt, 1),
				pct.call(trig[1]), pct.call(trig[2]), pct.call(trig[3]), pct.call(trig[4]), pct.call(trig[5]), ms / nseeds])
	lines.append("")
	lines.append_array(host_table(nseeds))
	# srovnání s rudami prototypu (šum) a dopad na raritu
	lines.append("")
	lines.append("Prototyp (šumové rudy) vs. ore-v0 bonus 0 %: průměr buněk mědi / železa a rozdělení tříd rarity-v2 (0..4)")
	for k in ["louka", "kopec", "hora"]:
		var lc := 0; var lf := 0; var oc := 0; var of := 0
		var rl := [0, 0, 0, 0, 0]; var ro := [0, 0, 0, 0, 0]
		for s in nseeds:
			var seed := 5000 + s * 17
			var lb := legacy_block(k, seed)
			lc += lb.summary[Mat.COPPER]; lf += lb.summary[Mat.IRON]
			rl[Mat.rarity_of(lb.summary)] += 1
			var c: PackedByteArray = bases[k][s].duplicate()
			Ore.place(c, seed, Ore.server_target(seed, 0, Ore.specs_for(k)), Ore.specs_for(k))
			var sm := Ore.count(c)
			oc += sm[Mat.COPPER]; of += sm[Mat.IRON]
			ro[Mat.rarity_of(sm)] += 1
		lines.append("%-6s prototyp Cu %6.1f Fe %6.1f třídy %s | ore-v0 Cu %5.1f Fe %5.1f třídy %s" % [k, float(lc) / nseeds, float(lf) / nseeds, str(rl), float(oc) / nseeds, float(of) / nseeds, str(ro)])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))

static func bench(path: String) -> void:
	var lines := PackedStringArray()
	var reps := 30
	for k in ["louka", "kopec", "hora"]:
		var gen := 0.0; var ore := 0.0; var legacy := 0.0
		for s in reps:
			var seed := 9000 + s
			var t0 := Time.get_ticks_usec()
			var b := base_block(k, seed)
			gen += (Time.get_ticks_usec() - t0) / 1000.0
			var c := b.cells.duplicate()
			t0 = Time.get_ticks_usec()
			Ore.place(c, seed, Ore.server_target(seed, 25, Ore.specs_for(k)), Ore.specs_for(k))
			ore += (Time.get_ticks_usec() - t0) / 1000.0
			t0 = Time.get_ticks_usec()
			legacy_block(k, seed)
			legacy += (Time.get_ticks_usec() - t0) / 1000.0
		lines.append("%-6s generátor bez rud %.1f ms | ore-v0 (bonus 25 %%) %.2f ms | generátor prototypu se šumovými rudami %.1f ms  (průměr z %d bloků)" % [k, gen / reps, ore / reps, legacy / reps, reps])
	# zátěžový bench
	var b2 := base_block("hora", 202)
	var t1 := Time.get_ticks_usec()
	for i in 5:
		Ore.place(b2.cells.duplicate(), 202, {Mat.COPPER: 3000, Mat.IRON: 3000, Mat.CLAY_DEPOSIT: 1500})
	lines.append("hora 202 obří cíle (Cu 3000, Fe 3000, jíl 1500): %.1f ms/blok" % ((Time.get_ticks_usec() - t1) / 5000.0))
	var b3 := base_block("louka", 101)
	t1 = Time.get_ticks_usec()
	Ore.place(b3.cells.duplicate(), 101, {Mat.COPPER: 20000})
	lines.append("louka 101 cíl nad kapacitu (Cu 20000 → schodek): %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	lines.append("Godot %s, GDScript, headless, box CPU" % Engine.get_version_info().string)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
