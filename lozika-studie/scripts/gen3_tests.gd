extends RefCounted
## gen-v3: zástupce serveru (souhrn), běh, vektory, zátěž, simulace voda-studie, „vrstevnatost“, bench.

const Mat = preload("res://scripts/mat.gd")
const Ore = preload("res://scripts/ore_v0.gd")
const Cave = preload("res://scripts/cave_v0.gd")
const G = preload("res://scripts/gen_v3.gd")
const SRV = preload("res://scripts/gen3_server.gd")
const S = preload("res://scripts/gen3_stack.gd")
const VParT = preload("res://scripts/voda_params.gd")
const T = preload("res://scripts/tests.gd")
const CT = preload("res://scripts/cave_tests.gd")
const H = preload("res://scripts/stable_hash.gd")
const POUR := {"louka": [60, 200], "kopec": [60, 220], "hora": [40, 160], "piscina": [80, 260]}

## zástupce serveru: horniny, písek, jíl jako v prototypu (STRATA, stejný recept a seed), jeskyně z cave-v0, rudy z ore-v0,
## jeskyně a ložiskový jíl se odečtou od kamene (Σ ≤ V); voda = nalité množství
## zástupce serveru, varianta 2 (Jan 19:18): hlína, písek, jíl ze STRATA prototypu (stejný recept a seed), rudy z ore-v0.2,
## jeskyně z cave-v0; KÁMEN dostane celý zbytek objemu (V − slupka − Σ ostatních), rozdělený poměrem kamenů STRATA.
static func summary_for(kind: String, seed: int, bonus := 0, cave_x := 1, ore_x := 1, water_x := 1) -> Dictionary:
	var b := T.base_block(kind, seed)
	var cnt := Ore.count(b.cells)
	var s := {}
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY]:
		s[m] = cnt[m]
	var sk := Ore.specs_for(kind)
	var ot := Ore.server_target(seed, bonus, sk)
	s[Mat.COPPER] = ot.get(Mat.COPPER, 0) * ore_x
	s[Mat.IRON] = ot.get(Mat.IRON, 0) * ore_x
	s[Mat.CLAY_DEPOSIT] = ot.get(Mat.CLAY_DEPOSIT, 0)
	var ct := Cave.server_target(kind, seed, bonus)
	s[G.CAVE_KEY] = ct.cave_air * cave_x
	var v_free := G.free_volume(b.cells, b.hm)
	var other := 0
	for k in s:
		if not SRV.ORE_IN_STONE or (k != Mat.COPPER and k != Mat.IRON):   # 19:19 (c): rudy rostou do kamene, objem nezabírají
			other += s[k]
	var rest := v_free - other
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY]:   # kdyby se nevešlo: ubrat z hlíny, pak písku, pak jílu
		if rest < 0:
			var t := mini(s[m], -rest)
			s[m] -= t; rest += t
	var st := 0
	for m in G.STONES:
		st += cnt[m]
	var acc := 0
	for i in 3:
		var m: int = G.STONES[i]
		var v: int = (rest * cnt[m] / maxi(st, 1)) if i < 2 else rest - acc
		s[m] = v; acc += v
	var r := Ore.Rng.new(H.mix(seed, "POUR", 0))
	var pr: Array = POUR.get(kind, [60, 200])
	s["pour"] = r.range_i(pr[0], pr[1]) * water_x
	s["water"] = s.pour
	return {"summary": s, "proto": b}

static var WATER_BY_RIM := true

static func run(kind: String, seed: int, bonus := 0, cave_x := 1, ore_x := 1, water_x := 1) -> Dictionary:
	var sp := summary_for(kind, seed, bonus, cave_x, ore_x, water_x)
	var b: Block = sp.proto
	var items := SRV.build_stack(sp.summary)
	# 19:19 (a): server přidělí vodu podle nejnižšího okraje bloku; (d) kontrola zásobníku při vydání
	var allot := SRV.water_allotment(b.hm, items) if WATER_BY_RIM else -1
	if allot >= 0:
		sp.summary.water = mini(sp.summary.pour, allot)
	var bytes := S.encode(items)
	var srv_errs := SRV.check_stack(S.decode(bytes).items, G.free_volume(b.cells, b.hm), sp.summary.water, allot)
	var g := G.generate_bytes(b.cells, b.hm, seed, bytes, sp.summary.water)
	g["stack_hex"] = bytes.hex_encode()
	g["server_errors"] = srv_errs
	g["pour"] = sp.summary.pour; g["allot"] = allot
	sp.summary = G.summary_of(g.stack, sp.summary.water)   # kontrola proti tomu, co server vydal (zásobník)
	var t0 := Time.get_ticks_usec()
	var rp := {"water_units": g.water_rep.get("runoff_units", 0)}
	for rep in g.reps:
		if rep.shortfall > 0:
			rp[rep.key] = rep.shortfall
	var v := G.validate(g.cells, b.hm, g.water, sp.summary, rp)
	g["validate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	g["valid"] = v
	g["summary"] = sp.summary
	g["hm"] = b.hm
	g["proto_cells"] = b.cells
	g["kind"] = kind; g["seed"] = seed
	return g

const Block = preload("res://scripts/block.gd")

static func _lv(rep: Dictionary) -> Dictionary:
	var lv := {}
	for i in 6:
		if rep.by_level[i] > 0:
			lv[Ore.LEVELS[i]] = rep.by_level[i]
	return lv

static func _kname(k) -> String:
	return "jeskyně" if k == G.CAVE_KEY else Mat.NAMES[k]

## vrstevnatost: pro každou výšku podíl nejčastějšího kamene mezi kameny ve vrstvě (průměr přes vrstvy s kamenem)
## + „hranice“: kolik sousedních dvojic kamenů (vodorovně) má různý materiál (menší = souvislejší vrstvy)
static func layering(cells: PackedByteArray) -> Dictionary:
	var purity := 0.0; var nz := 0
	var diff := 0; var pairs := 0
	for z in 64:
		var c3 := {}
		var tot := 0
		for x in 16:
			for y in 16:
				var m := cells[(x * 16 + y) * 64 + z]
				if m in G.STONES:
					c3[m] = c3.get(m, 0) + 1; tot += 1
					if x < 15:
						var m2 := cells[((x + 1) * 16 + y) * 64 + z]
						if m2 in G.STONES:
							pairs += 1
							if m2 != m: diff += 1
		if tot >= 16:
			var mx := 0
			for k in c3:
				mx = maxi(mx, c3[k])
			purity += float(mx) / tot; nz += 1
	# tečky: buňka kamene / hlíny bez jediného souseda (6) stejného materiálu; hluboká hlína = hlína > 4 buňky pod povrchem sloupce
	var specks := 0; var stc := 0; var dirt_specks := 0; var deep := 0
	for c in cells.size():
		var m := cells[c]
		var isst: bool = m in G.STONES
		if not isst and m != Mat.DIRT:
			continue
		if isst: stc += 1
		var x := c / 1024; var y := (c / 64) % 16; var z := c % 64
		if m == Mat.DIRT and z < _top(cells, x, y) - 4: deep += 1
		var same := false
		for d in 6:
			var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nzz: int = z + Ore.DZ[d]
			if nx < 0 or ny < 0 or nzz < 0 or nx >= 16 or ny >= 16 or nzz >= 64:
				continue
			if cells[(nx * 16 + ny) * 64 + nzz] == m:
				same = true; break
		if not same:
			if isst: specks += 1
			else: dirt_specks += 1
	return {"purity": purity / maxi(nz, 1), "boundary": float(diff) / maxi(pairs, 1), "stoneSpecks": specks, "dirtSpecks": dirt_specks, "deepDirt": deep}

static func _top(cells: PackedByteArray, x: int, y: int) -> int:
	for z in range(63, -1, -1):
		var m := cells[(x * 16 + y) * 64 + z]
		if m != Mat.AIR and m != Mat.FOG:
			return z + 1
	return 0

static func doc(id: String, g: Dictionary) -> Dictionary:
	var mats := []  # out: počty
	var sf := {}
	for rep in g.reps:
		mats.append({"material": _kname(rep.key), "target": rep.target, "placed": rep.placed, "shortfall": rep.shortfall, "byLevel": _lv(rep)})
		if rep.shortfall > 0:
			sf[str(rep.key)] = rep.shortfall
	var wr: Dictionary = g.water_rep
	if wr.get("runoff_units", 0) > 0:
		sf["water_units"] = wr.runoff_units
	var cnt := Ore.count(g.cells)
	var fin := {}
	for m in range(1, Mat.COUNT):
		if cnt[m] > 0:
			fin[Mat.NAMES[m]] = cnt[m]
	fin["jeskyně"] = Cave.cave_air(g.cells, g.hm)
	var wb := PackedByteArray()
	for v in g.water:
		wb.append(v & 255); wb.append(v >> 8)
	var issued := {}
	for k in g.summary:
		issued[k if k is String else _kname(k)] = g.summary[k]
	return {"id": id, "recipe": g.kind, "seed": g.seed,
		"in": {"stack": S.to_json(g.stack), "stackBytesHex": g.stack_hex, "stackHash": g.stack_hash, "water": g.summary.water,
			"waterPouredByRecipe": g.pour, "waterAllotmentByRim": g.allot, "serverStackCheck": g.server_errors},
		"issued": issued,
		"materials": mats, "water": {"poured": wr.target, "placed": snappedf(wr.placed, 0.001), "inPores": snappedf(wr.pores, 0.001),
			"freeInCaves": snappedf(wr.free_cave, 0.001), "pond": snappedf(wr.pond, 0.001), "retained": snappedf(wr.get("retained", 0.0), 0.001), "runoff": snappedf(wr.runoff, 0.001), "level": wr.level},
		"wvb1Header": {"shortfall": sf}, "validator": {"ok": g.valid.ok, "errorCount": g.valid.error_count, "firstErrors": g.valid.errors.slice(0, 3)},
		"final": fin, "layering": layering(g.cells), "layeringPrototype": layering(g.proto_cells),
		"sha256MaterialLayer": T.sha256(g.cells), "sha256WaterLayer": T.sha256(wb)}

static func vectors(path: String) -> Array:
	var out := []
	for kc in [["louka", 101], ["louka", 404], ["kopec", 303], ["kopec", 2302], ["hora", 202], ["hora", 1000], ["piscina", 4504]]:
		out.append(doc("%s_%d" % kc, run(kc[0], kc[1])))
	out.append(doc("zatez_jeskyne_x5_hora202", run("hora", 202, 0, 5)))
	out.append(doc("zatez_rudy_x5_louka101", run("louka", 101, 0, 1, 5)))
	out.append(doc("zatez_voda_x5_kopec303", run("kopec", 303, 0, 1, 1, 5)))
	out.append(doc("zatez_voda_x20_louka404", run("louka", 404, 0, 1, 1, 20)))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"genVersion": "gen-v3-study-4 (Jan 19:18 varianta 2 + 19:19 a–e)", "shapes": S.SHAPES, "waterUnit": "u16, %d = plná buňka objemu; v půdě nejvýš pórovitost × %d" % [G.FULL, G.FULL],
		"permeable": "hlína 0,40, písek 0,35, tráva 0,40 (pórovitost voda-studie), vzduch 1; ostatní nepropustné",
		"edges": "pod povrchem zavřené (bez přetékání mezi bloky); povrchová voda nesmí nad nejnižší okraj bloku, zbytek = odtok (shortfall water)",
		"cases": out}, "  ", false))
	f.close()
	return out

static func stress(path: String, nseeds := 15) -> PackedStringArray:
	var L := PackedStringArray()
	L.append("Zátěž gen-v3: %d seedů × 4 recepty. Přesně = všechny materiály placed == target; L1–L5 = podíl materiálů se stupněm; voda: nalito → umístěno (v pórech / v jeskyních / jezírko / odtok)" % nseeds)
	L.append("recept | měřítko | přesně | L1 / L2 / L3 / L5 | voda nalito → umístěno (póry / jeskyně / jezírko / odtok) | validátor | vrstevnatost gen-v3 vs prototyp (čistota, hranice) | tečky kamene / tečky hlíny / hlína > 4 pod povrchem (průměr na blok) | ms rozmístění / voda / kontrola")
	var scales := [["běžné", 0, 1, 1, 1], ["bonus 50 %", 50, 1, 1, 1], ["jeskyně ×5", 0, 5, 1, 1], ["rudy ×5", 0, 1, 5, 1], ["voda ×5", 0, 1, 1, 5], ["voda ×20", 0, 1, 1, 20]]
	for k in ["louka", "kopec", "hora", "piscina"]:
		for sc in scales:
			var ex := 0; var nm := 0; var trig := [0, 0, 0, 0, 0, 0]
			var wt := 0.0; var wp := 0.0; var wpo := 0.0; var wca := 0.0; var wpd := 0.0; var wro := 0.0
			var vok := 0; var pur := 0.0; var bnd := 0.0; var ppur := 0.0; var pbnd := 0.0
			var sk := 0.0; var dsk := 0.0; var dd := 0.0
			var ms := [0.0, 0.0, 0.0, 0.0]
			for s in nseeds:
				var g := run(k, 5000 + s * 17, sc[1], sc[2], sc[3], sc[4])
				var allx := true
				for rep in g.reps:
					nm += 1
					if rep.shortfall > 0: allx = false
					for i in range(1, 6):
						if rep.by_level[i] > 0: trig[i] += 1
				if allx: ex += 1
				var wr: Dictionary = g.water_rep
				wt += wr.target; wp += wr.placed; wpo += wr.pores; wca += wr.free_cave; wpd += wr.pond; wro += wr.runoff
				if g.valid.ok: vok += 1
				var la := layering(g.cells); var lp := layering(g.proto_cells)
				pur += la.purity; bnd += la.boundary; ppur += lp.purity; pbnd += lp.boundary
				sk += la.stoneSpecks; dsk += la.dirtSpecks; dd += la.deepDirt
				ms[0] += g.ms.A; ms[1] += g.ms.B; ms[2] += g.ms.water; ms[3] += g.validate_ms
			var p := func(v): return "%.0f %%" % (100.0 * v / maxi(nm, 1))
			var n := float(nseeds)
			L.append("%-7s | %-10s | %d/%d | %s / %s / %s / %s | %.0f → %.0f (%.0f / %.0f / %.0f / %.0f) | %d/%d | %.2f, %.2f vs %.2f, %.2f | %.1f / %.1f / %.1f | %.1f / %.1f / %.1f" % [k, sc[0], ex, nseeds,
				p.call(trig[1]), p.call(trig[2]), p.call(trig[3]), p.call(trig[5]), wt, wp, wpo, wca, wpd, wro, vok, nseeds,
				pur / n, bnd / n, ppur / n, pbnd / n, sk / n, dsk / n, dd / n, ms[0] / n, ms[2] / n, ms[3] / n])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
	return L

## simulace voda-studie (kopie), hrany zavřené (bez přetékání mezi bloky), odpar 0
## simulace voda-studie se SDÍLENOU tabulkou materiálů (vápenec 0 od 19:18), hrany zavřené, odpar 0
static func sim(path: String, ticks := 400) -> PackedStringArray:
	var L := _sim_part(ticks, false) + PackedStringArray([""]) + negative()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
	return L

static func _sim_part(ticks: int, lime_tight: bool) -> PackedStringArray:
	if not VParT.P.has("perm_dirt"):
		VParT.apply_shared_table()
	var L := PackedStringArray()
	L.append("gen-v3 + simulace voda-studie, sdílená tabulka v%d (vápenec perm %.2f)" % [int(VParT.P.get("table_version", 0)), float(VParT.P.get("perm_limestone", -1))])
	L.append("gen-v3 + simulace voda-studie (%d tiků, odpar 0, strany bloku zavřené): stabilita vsáknuté vody" % ticks)
	L.append("blok | voda | posun objemu | odtok | přesunuto (½Σ|Δw|) | max |Δw| buňky | voda ve vápenci po | validátor | ms/tik")
	for kc in [["louka", 101], ["kopec", 303], ["hora", 1000], ["piscina", 4504], ["louka", 404, 20], ["hora", 202, 5]]:
		var g := run(kc[0], kc[1], 0, 1, 1, kc[2] if kc.size() > 2 else 1)
		var s = CT.make_sim(g.cells, g.water)
		s.open_sides = 0
		var w0: PackedFloat32Array = s.w.duplicate()
		var tot0: float = s.total()
		var t0 := Time.get_ticks_usec()
		for i in ticks:
			s.step()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / ticks
		var mv := 0.0; var mx := 0.0; var lime := 0.0
		for i in s.w.size():
			var d := absf(s.w[i] - w0[i]); mv += d; mx = maxf(mx, d)
			if s.mat[i] == Mat.LIMESTONE: lime += s.w[i]
		L.append("%s %d%s | %.2f | %+.6f | %.6f | %.4f | %.4f | %.3f | %s | %.1f" % [kc[0], kc[1], (" voda ×%d" % kc[2]) if kc.size() > 2 else "", tot0, s.total() - tot0, s.out_total, mv * 0.5, mx, lime, "OK" if g.valid.ok else "CHYBA %d" % g.valid.error_count, ms])
	return L

## negativní test validátoru: tři úmyslná poškození bloku louka 101
static func negative() -> PackedStringArray:
	var L := PackedStringArray(["Negativní test validátoru (louka 101):"])
	var g := run("louka", 101)
	var rp := {"water_units": g.water_rep.get("runoff_units", 0)}
	var cases := [["1 buňka žuly → hlína", "mat"], ["voda 1/4 buňky přesunuta do žuly", "wsolid"], ["voda 1 buňky přidána navíc nahoru (nad hladinu)", "wtop"]]
	for cs in cases:
		var c: PackedByteArray = g.cells.duplicate()
		var w: PackedInt32Array = g.water.duplicate()
		var gi := c.find(Mat.GRANITE)
		match cs[1]:
			"mat": c[gi] = Mat.DIRT
			"wsolid":
				for i in w.size():
					if w[i] >= G.FULL / 4:
						w[i] -= G.FULL / 4; break
				w[gi] += G.FULL / 4
			"wtop":
				var hi := -1
				for i in w.size():
					if w[i] > 0 and (hi < 0 or i % 64 > hi % 64): hi = i
				if hi % 64 < 63 and c[hi + 1] == Mat.DIRT: w[hi + 1] += int(G.FULL * 0.4)
				else: w[hi] += 1
		var v := G.validate(c, g.hm, w, g.summary, rp)
		L.append("  %s → %s %s" % [cs[0], "OK (CHYBA testu!)" if v.ok else "odmítnuto (%d)" % v.error_count, str(v.errors.slice(0, 2))])
	L.append("Neplatný zásobník (world.stack_invalid):")
	var good := S.encode(g.stack)
	var bad := []
	var b1 := good.duplicate(); b1[2 + 6] = 9; bad.append(["neznámý tvar 9", b1])
	var b2 := good.duplicate(); b2.encode_u16(2 + 7, 8); bad.append(["params_len 8 místo %d" % good.decode_u16(9), b2])
	var b3 := good.slice(0, good.size() - 2); bad.append(["useknuté bajty", b3])
	var b4 := good.duplicate(); b4.append(0); bad.append(["bajt navíc", b4])
	var b5 := good.duplicate(); b5.encode_s32(2 + 9 + 4, 30); b5.encode_s32(2 + 9 + 8, 20); bad.append(["lzMin > lzMax", b5])
	var b6 := good.duplicate(); b6.encode_u16(2, Mat.FOG); bad.append(["materiál mlha (vnitřní UNSET)", b6])
	var b7 := good.duplicate(); b7.encode_u32(2 + 2, good.decode_u32(2 + 2) + 1); bad.append(["počet +1 (Σ ≠ V)", b7])
	for bb in bad:
		var r := G.generate_bytes(g.proto_cells, g.hm, 101, bb[1], 0)
		L.append("  %s → %s" % [bb[0], str(r.error) if not r.ok else "PŘIJATO (CHYBA testu!)"])
	# 19:19 (d) kontrola serveru při vydání
	L.append("Kontrola serveru při vydání (gen3_server.check_stack):")
	var vf := G.free_volume(g.proto_cells, g.hm)
	var items: Array = S.decode(good).items
	L.append("  platný zásobník → %s" % str(SRV.check_stack(items, vf, g.summary.water, g.allot)))
	var it2: Array = S.decode(good).items
	it2[it2.size() - 4].count += 5
	L.append("  kámen +5 (Σ > V − slupka) → %s" % str(SRV.check_stack(it2, vf)))
	var it3: Array = S.decode(good).items
	it3[0].count -= 1
	L.append("  první položka −1 (Σ < V) → %s" % str(SRV.check_stack(it3, vf)))
	var it4: Array = S.decode(good).items
	for it in it4:
		if it.get("host", -1) >= 0:
			it.count = 99999; break
	L.append("  ruda větší než hostitel → %s" % str(SRV.check_stack(it4, vf)))
	L.append("  voda nad přidělení podle okraje → %s" % str(SRV.check_stack(items, vf, g.allot + 1, g.allot)))
	return L


## ablace 19:19: přínos každého kroku (a)–(e) na stejných blocích (7 receptů/seedů × 3 seedy)
static func ablation(path: String) -> PackedStringArray:
	var L := PackedStringArray(["Ablace gen-v3 (19:19): 21 bloků (louka 101/404, kopec 303/2302, hora 202/1000, píščina 4504; seed + 0/1000/2000), voda ×1 a ×5",
		"varianta | přesně | validátor | čistota vrstev | hranice | tečky kamene | odtok (×1 / ×5, objemy na blok) | bloky s odtokem ×1 | zadrženo | Cu+Fe v kameni | ms rozmístění / voda / kontrola"])
	var variants := [["v3 vše (a+b+c+e)", true, true, true, true], ["bez (a) přidělení podle okraje", false, true, true, true],
		["bez (b) zadržené vody", true, false, true, true], ["bez (c) rud v kameni", true, true, false, true], ["bez (e) stratum (layer BFS)", true, true, true, false]]
	for v in variants:
		WATER_BY_RIM = v[1]; G.RETENTION = v[2]; SRV.ORE_IN_STONE = v[3]; SRV.STRATA = v[4]
		var n := 0; var ex := 0; var ok := 0; var pur := 0.0; var bnd := 0.0; var sk := 0.0; var ro1 := 0.0; var ro5 := 0.0; var rob := 0; var ret := 0.0
		var inst := 0; var ores := 0; var ms := [0.0, 0.0, 0.0]
		for kc in [["louka", 101], ["louka", 404], ["kopec", 303], ["kopec", 2302], ["hora", 202], ["hora", 1000], ["piscina", 4504]]:
			for s in 3:
				for wx in [1, 5]:
					var g := run(kc[0], kc[1] + s * 1000, 0, 1, 1, wx)
					var wr: Dictionary = g.water_rep
					if wx == 5:
						ro5 += wr.runoff
						continue
					n += 1
					if g.reps.all(func(r): return r.shortfall == 0): ex += 1
					if g.valid.ok: ok += 1
					var la := layering(g.cells)
					pur += la.purity; bnd += la.boundary; sk += la.stoneSpecks
					ro1 += wr.runoff; ret += wr.get("retained", 0.0)
					if wr.runoff > 0.0: rob += 1
					ms[0] += g.ms.A; ms[1] += g.ms.water; ms[2] += g.validate_ms
					for c in g.cells.size():
						var m: int = g.cells[c]
						if m == Mat.COPPER or m == Mat.IRON:
							ores += 1
							var st := 0
							for d in 6:
								var nb: int = c + [1024, -1024, 64, -64, 1, -1][d]
								if nb >= 0 and nb < g.cells.size() and g.cells[nb] in G.STONES: st += 1
							if st >= 4: inst += 1
		var f := float(n)
		L.append("%s | %d/%d | %d/%d | %.3f | %.3f | %.1f | %.1f / %.1f | %d/%d | %.1f | %.0f %% | %.1f / %.1f / %.1f" % [v[0], ex, n, ok, n, pur / f, bnd / f, sk / f, ro1 / f, ro5 / f, rob, n, ret / f,
			100.0 * inst / maxi(ores, 1), ms[0] / f, ms[1] / f, ms[2] / f])
	WATER_BY_RIM = true; G.RETENTION = true; SRV.ORE_IN_STONE = true; SRV.STRATA = true
	var fl := FileAccess.open(path, FileAccess.WRITE)
	fl.store_string("\n".join(L) + "\n")
	fl.close()
	return L
