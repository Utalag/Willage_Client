extends RefCounted
## Vložení blueprintu jako seznam KROKŮ [popis, Callable]. Stejné kroky běží naráz (server, testy) i po snímcích
## (uzel Placer s ukazatelem průběhu) – výsledek je čistá funkce (stav sousedů, tvar, seed, pořadí vložení).

const Mat = preload("res://scripts/kopie/mat.gd")
const G = preload("res://scripts/kopie/gen_v3.gd")
const BP = preload("res://scripts/bp/blueprint.gd")
const SF = preload("res://scripts/bp/surface.gd")
const ST = preload("res://scripts/bp/strata.gd")
const MN = preload("res://scripts/bp/minerals.gd")
const ER = preload("res://scripts/bp/erosion.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const G2 = preload("res://scripts/bp/geo2.gd")
const FN = preload("res://scripts/bp/geo_fn.gd")
const SD = preload("res://scripts/bp/sides.gd")

static func new_ctx(world, slot: Vector2i, bp: Dictionary, p: Dictionary) -> Dictionary:
	return {"world": world, "slot": slot, "bp": bp, "p": p, "ms": {}, "rep": {}}

## jen náhled (kroky 1–2): tvar šablony a dorovnané okraje
static func preview_steps(ctx: Dictionary) -> Array:
	var s := []
	s.append(["povrch: šablona blueprintu", func():
		ctx.raw = BP.raw_height(ctx.bp, float(ctx.p.surface_shift))
		if ctx.p.erosion:
			ctx.rep.erosion = ER.run(ctx.raw, ctx.bp.seed, ctx.p.droplets)])
	s.append(["povrch: dorovnání okrajů na sousedy", func():
		var a := SF.adapt(ctx.raw, ctx.world.edge_heights(ctx.slot), ctx.p.band, ctx.p)
		ctx.hm = a.hm; ctx.hm_f = a.hm_f; ctx.hm_raw = a.hm_raw; ctx.changed = a.changed
		ctx.rep.surface_iters = a.iters])
	return s

static func steps(ctx: Dictionary) -> Array:
	if ctx.p.geo == "v2":
		return steps_v2(ctx)
	var s := preview_steps(ctx)
	ctx.bs = []
	for k in ST.K:
		s.append(["vrstvy: %s – navázání na sousedy" % Mat.NAMES[ST.LAYERS[k]], func():
			# cíl počítá z výšek PO dorovnání (desetinných), aby drape sledoval skutečný povrch
			var t := ST.target(ctx.slot, ctx.hm_f, ctx.bp.seed, k, ctx.p)
			var r := ST.continue_field(t, ctx.world.edge_bounds(ctx.slot, k), ctx.p)
			ctx.bs.append(r.b)
			ctx.rep["iters_%d" % k] = r.iters])
	s.append(["vrstvy: monotónnost", func():
		ST.monotone(ctx.bs)
		ctx.cells = PackedByteArray(); ctx.cells.resize(G.N)])
	for x0 in range(0, 16, 2):
		s.append(["buňky: sloupce %d–%d" % [x0, x0 + 1], func(): ST.fill(ctx.cells, ctx.hm, ctx.bs, ctx.p.soil, x0, x0 + 2)])
	_tail(ctx, s)
	return s

## v2: tabulka pořadí hornin, profily podle tvaru, navázání v mocnostech (klíny), buňky = vzorky spojitých funkcí (geo_fn)
static func preview_steps_v2(ctx: Dictionary) -> Array:
	var s := []
	s.append(["povrch: šablona blueprintu", func():
		if G2.is87(ctx.bp.shape, ctx.p):   # E87: masiv vyzdvižené hory = funkce světa (p87_jadro_hory)
			ctx.raw = G2.massif87_block(ctx.slot, ctx.p)
			ctx.m87 = {"base": ctx.raw.duplicate(), "p": ctx.p}
		else:
			ctx.raw = BP.raw_height(ctx.bp, float(ctx.p.surface_shift))
		if ctx.p.erosion:
			ctx.rep.erosion = ER.run(ctx.raw, ctx.bp.seed, ctx.p.droplets)])
	s.append(["povrch: dorovnání okrajů na sousedy / regionální základ", func():
		# Jan 16:44: okraj = přesně funkce souseda; chybí-li soused, výchozí hodnota = regionální základ (surf_ref)
		var e: Array = ctx.world.edge_heights_f(ctx.slot)
		var real := e.map(func(v): return v != null)
		for d in 4:
			if e[d] == null:
				var r := PackedFloat64Array(); r.resize(16); r.fill(float(ctx.p.surf_ref))
				# E49: když blueprint nese povrch z hrubého světa (base_hm), regionální základ povrchu = hrubý svět na vlastním okraji
				if ctx.bp.has("base_hm"):
					for t in 16:
						var o := SD.own(d, t); r[t] = float(ctx.bp.base_hm[o.x * 16 + o.y])
				e[d] = r
		if ctx.has("m87"):
			# E87: volná strana = funkce masivu (ne surf_ref); soused masivu předá ODCHYLKU od funkce, jiný soused výšku jako dřív
			for d in 4:
				var nb = ctx.world.neighbour(ctx.slot, d)
				if nb != null and not nb.has("m87"): continue
				var r := PackedFloat64Array(); r.resize(16)
				for t in 16:
					var o := SD.own(d, t)
					r[t] = float(ctx.m87.base[o.x * 16 + o.y])
					if nb != null:
						var c := SD.nb(d, t); r[t] += float(nb.hm_f[c.x * 16 + c.y]) - float(nb.m87.base[c.x * 16 + c.y])
				e[d] = r
		var a := SF.adapt(ctx.raw, e, ctx.p.band, ctx.p, real)
		ctx.hm = a.hm; ctx.hm_f = a.hm_f; ctx.hm_raw = a.hm_raw; ctx.changed = a.changed
		ctx.rep.surface_iters = a.iters])
	return s

static func sub_of(bp: Dictionary) -> Dictionary:
	return {"on": bp.get("rocks_on", []), "off": bp.get("rocks_off", [])}

static func steps_v2(ctx: Dictionary) -> Array:
	var s := preview_steps_v2(ctx)
	var nl := HR.pool(ctx.p).size()
	var band := maxi(int(round(float(ctx.p.taper_m) / FN.U)), 1)
	s.append(["vrstvy: vlastní tvar blueprintu a regionální základ", func():
		ctx.targets = G2.targets(ctx.slot, ctx.hm_f, ctx.bp.shape, ctx.bp.seed, ctx.p, sub_of(ctx.bp))
		var flat := PackedFloat64Array(); flat.resize(256); flat.fill(float(ctx.p.surf_ref))
		var pr: Dictionary = ctx.p.duplicate(); pr.strata_noise = 0.0
		# regionální základ = regionální funkce hranic (bez tvaru a šumu blueprintu) s podmnožinou hornin blueprintu
		ctx.regional = G2.targets(ctx.slot, flat, "louka", 0, pr, sub_of(ctx.bp))
		# výchozí hodnoty hranic na okrajích: funkce souseda v přiléhajícím řídicím bodě, jinak regionální základ
		if ctx.has("m87"): ctx.m87.tg = G2.bounds87(ctx.targets)
		ctx.starts = []
		ctx.real = []
		for d in 4:
			var nb = ctx.world.neighbour(ctx.slot, d)
			ctx.real.append(nb != null and nb.bs.size() == nl)
			var arr := []
			for k in nl:
				var e := PackedFloat64Array(); e.resize(16)
				for t in 16:
					var o := SD.own(d, t); var c := SD.nb(d, t)
					if ctx.has("m87") and (nb == null or (nb.has("m87") and nb.bs.size() == nl)):
						# E87: volná strana = vlastní cíl masivu (ne regionální rovina), soused masivu = přenos odchylky od cíle
						e[t] = float(ctx.m87.tg[k][o.x * 16 + o.y])
						if nb != null: e[t] += float(nb.bs[k][c.x * 16 + c.y]) - float(nb.m87.tg[k][c.x * 16 + c.y])
					elif nb != null and nb.bs.size() == nl:
						e[t] = nb.bs[k][c.x * 16 + c.y]
					else:
						e[t] = ctx.regional[k][o.x * 16 + o.y]
				arr.append(e)
			ctx.starts.append(arr)
		ctx.th = []
		ctx.rep.wedges = 0])
	for k in nl:
		s.append(["vrstvy: mocnost %d/%d – navázání na sousedy (klíny)" % [k + 1, nl], func():
			var th := PackedFloat64Array(); th.resize(256)
			for i in 256:
				var lo: float = 0.0 if k == 0 else maxf(ctx.targets[k - 1][i], 0.0)
				var hi: float = ctx.targets[k][i]
				th[i] = maxf(hi - lo, 0.0)
				if k > 0: ctx.targets[k][i] = maxf(hi, lo)   # průběžné maximum: mocnost nikdy záporná
			if not ctx.p.get("continue", true):
				ctx.th.append(th); return
			var sth := []
			for d in 4:
				var e := PackedFloat64Array(); e.resize(16)
				for t in 16:
					e[t] = maxf(ctx.starts[d][k][t] - (0.0 if k == 0 else ctx.starts[d][k - 1][t]), 0.0)
				sth.append(e)
			var r := ST.continue_thick(th, sth, band, ctx.p, ctx.real)
			ctx.th.append(r.th)])
	s.append(["vrstvy: hranice = součet mocností", func():
		ctx.bs = []
		var acc := PackedFloat64Array(); acc.resize(256)
		for k in nl:
			for i in 256: acc[i] += ctx.th[k][i]
			ctx.bs.append(acc.duplicate())
		ctx.cells = PackedByteArray(); ctx.cells.resize(G.N)
		ctx.wf = FN.world_fn(ctx.world.slots, {"slot": ctx.slot, "hm_f": ctx.hm_f, "bs": ctx.bs})
		ctx.fi = FN.block_info(ctx.wf, ctx.slot, ctx.bp, ctx.p)])
	for x0 in range(0, 16, 2):
		s.append(["buňky: vzorky funkcí, sloupce %d–%d" % [x0, x0 + 1], func(): FN.sample(ctx.wf, ctx.fi, 16, x0, x0 + 2, ctx.cells)])
	s.append(["tělesa: souhrn", func():
		var rep := {"pipe": 0, "dome": 0, "vein": 0, "contact": 0}
		var ids := {}
		for kd in rep: ids[int(HR.special(kd, ctx.p).get("id", -1))] = kd
		for c in ctx.cells:
			if ids.has(c): rep[ids[c]] += 1
		ctx.rep.bodies = rep
		for i in 256:   # výška sloupce podle vzorků
			var h := 0
			for z in 64:
				if ctx.cells[i * 64 + z] != Mat.AIR: h = z + 1
			ctx.hm[i] = h])
	ctx.rep.minerals = []
	ctx.rep.cavities = []
	for m in MN.order(ctx.bp.minerals):
		if FN.is_cavity(m): continue
		s.append(["minerály: %s" % HT.name_of(m), func():
			ctx.rep.minerals.append(FN.mineral_one(ctx.cells, 16, ctx.wf, ctx.fi, m, int(ctx.bp.minerals[m]), ctx.bp.seed))])
	# Jan 16:56: VODA a VZDUCH v seznamu materiálů = podzemní rezervoár a jeskyně (po minerálech, aby stěny byly čistý hostitel)
	# Jan 17:38: nejvýš JEDNA dutina na blok. Blueprint s oběma neprojde BP.validate → generátor nevytvoří žádnou a nahlásí chybu.
	ctx.rep.blueprint = BP.validate(ctx.bp)
	for m in MN.order(ctx.bp.minerals):
		if not FN.is_cavity(m) or not ctx.rep.blueprint.ok or int(ctx.bp.minerals[m]) <= 0: continue
		s.append(["dutiny: %s" % FN.cavity_name(m), func():
			ctx.rep.cavities.append(FN.cavity_one(ctx.cells, 16, ctx.wf, ctx.fi, m, int(ctx.bp.minerals[m]), ctx.bp.seed))])
	s.append(["voda: vsakování gen-v3", func():
		var wr := G.infiltrate(ctx.cells, ctx.hm, int(ctx.bp.water))
		ctx.water = wr.water; ctx.rep.water = wr
		# rezervoár: dutina uzavřená nepropustným hostitelem se zaplní celá (FULL na buňku)
		ctx.rep.reservoir_cells = 0
		for r in ctx.rep.cavities:
			if r.mat != FN.CAV_WATER: continue
			for c in r.get("cells", []):
				ctx.water[c] = G.FULL; ctx.rep.reservoir_cells += 1])
	s.append(["kontrola: validátor gen-v3", func():
		ctx.rep.valid = validate(ctx)])
	return s

static func _tail(ctx: Dictionary, s: Array) -> void:
	ctx.rep.minerals = []
	for m in MN.order(ctx.bp.minerals):
		s.append(["minerály: %s" % HT.name_of(m), func():
			ctx.rep.minerals.append(MN.press_one(ctx.cells, m, int(ctx.bp.minerals[m]), ctx.bp.seed))])
	s.append(["voda: vsakování gen-v3", func():
		var wr := G.infiltrate(ctx.cells, ctx.hm, int(ctx.bp.water))
		ctx.water = wr.water; ctx.rep.water = wr])
	s.append(["kontrola: validátor gen-v3", func():
		ctx.rep.valid = validate(ctx)])

## souhrn pro validátor: skutečné počty hornin a půdy, CÍLOVÉ počty minerálů (schodek jako hlášený), voda
static func validate(ctx: Dictionary) -> Dictionary:
	var cnt := PackedInt32Array(); cnt.resize(256)
	for c in ctx.cells:
		cnt[c] += 1
	var summ := {"water": int(ctx.bp.water) + int(ctx.rep.get("reservoir_cells", 0))}
	var reported := {"water_units": ctx.rep.water.get("runoff_units", 0)}
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY, Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT]:
		summ[m] = cnt[m]
	for r in ctx.rep.minerals:
		summ[r.mat] = r.target
		if r.shortfall > 0:
			reported[r.mat] = r.shortfall
	var v := G.validate(ctx.cells, ctx.hm, ctx.water, summ, reported)
	var exact: bool = ctx.rep.minerals.all(func(r): return r.shortfall == 0)
	return {"ok": v.ok, "errors": v.errors, "minerals_exact": exact}

static func record(ctx: Dictionary) -> Dictionary:
	var r := {"bp": ctx.bp, "slot": ctx.slot, "hm": ctx.hm, "hm_f": ctx.hm_f, "hm_raw": ctx.hm_raw, "changed": ctx.changed,
		"bs": ctx.bs, "cells": ctx.cells, "water": ctx.water, "rep": ctx.rep, "ms": ctx.ms}
	if ctx.has("m87"): r.m87 = ctx.m87   # E87: čistá funkce masivu (base povrch, tg hranice) pro sousedy a jemné vzorkování
	return r

## naráz: provede kroky, změří čas každého a vloží blok do světa
static func run_sync(world, slot: Vector2i, bp: Dictionary, p: Dictionary) -> Dictionary:
	var ctx := new_ctx(world, slot, bp, p)
	var st := steps(ctx)
	var i := 0
	while i < st.size():   # steps() přidává kroky postupně, seznam se nemění
		var t0 := Time.get_ticks_usec()
		st[i][1].call()
		var key: String = st[i][0].split(":")[0]
		ctx.ms[key] = ctx.ms.get(key, 0.0) + (Time.get_ticks_usec() - t0) / 1000.0
		i += 1
	var rec := record(ctx)
	world.commit(rec)
	return rec
