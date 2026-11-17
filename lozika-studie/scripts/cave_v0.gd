extends RefCounted
## cave-v0 (návrh Willage-backend, druhá část lozika-a-zily-v0.md; Jan 18:33 „Přidej do generování země i vzduch jako jeskyně
## a vodní rezervoáry … Voda však musí splňovat podmínky, aby neodtekla.“). NESCHVÁLENO – jen studie.
## Pořadí: terén → horniny → JESKYNĚ → VODA → rudy (ore-v0) → vegetace.
## Jeskyně = ore-v0 s „rudou“ Air (sál / chodba / šachta + rezervoár pro vodu), přesný cílový počet buněk, záložní stupně L1–L5.
## Voda NENÍ materiál: jde do vrstvy water (u16 na buňku, FULL = 1 buňka), jen do uzavřených pánví pod hladinou L.

const Mat = preload("res://scripts/mat.gd")
const Ore = preload("res://scripts/ore_v0.gd")
const H = preload("res://scripts/stable_hash.gd")
const BS := 16
const BH := 64
const N := BS * BS * BH

const FULL := 4096          # 1 buňka vody ve vrstvě water (u16); = jednotka water_total ve WVB1 (1/4096 buňky)
const ROOF := 2             # strop jeskyně: aspoň 2 pevné buňky pod povrchem sloupce i sousedních sloupců
const MARGIN := 1           # jeskyně nesahá k hraně bloku (lx, ly = 0/15) ani na dno (lz = 0)
const RES_HEAD_PCT := 125   # rezervoár = 125 % objemu vody (vzduch nad hladinou)
static var perm_leak := 0.05  # propustný = propustnost > perm_leak (tabulka voda-studie)

## propustnost z voda-studie/scripts/params.gd (perm_*); rudy, mlha = 0; sníh jako hlína (v tabulce není)
## propustnost podle MaterialId ze SDÍLENÉ tabulky ../sdilene/materialy_voda.json (od 19:18; dřív vlastní kopie s vápencem 0,10 a sněhem 0,30)
static var PERM := _perm_table()
static func _perm_table() -> PackedFloat32Array:
	var d := preload("res://scripts/voda_params.gd").load_shared_table()
	var t := PackedFloat32Array()
	t.resize(Mat.COUNT)
	for k in d.get("materials", {}):
		var m: Dictionary = d.materials[k]
		if int(m.id) < Mat.COUNT:
			t[int(m.id)] = float(m.perm)
	perm_leak = float(d.get("perm_leak", 0.05))
	return t

static func leaky(m: int) -> bool:
	return m != Mat.AIR and PERM[m] > perm_leak

## katalog jeskynních tvarů (výchozí hodnoty; recept je může přepsat)
const CATALOG := {
	"reservoir": {"name": "reservoir", "key": "reservoir", "material": Mat.AIR, "host": [Mat.GRANITE, Mat.BASALT],
		"seeds": [1, 1], "supply": [20, 80], "lz": [3, 30], "shape": "chamber", "pH": 42598, "pV": 26214,
		"relax": [[Mat.LIMESTONE, Mat.CLAY], [Mat.DIRT, Mat.SAND]]},
	"chamber": {"name": "chamber", "key": "chamber", "material": Mat.AIR, "host": [Mat.LIMESTONE],
		"seeds": [1, 2], "supply": [30, 90], "lz": [6, 44], "shape": "chamber", "pH": 40632, "pV": 19660,
		"relax": [[Mat.GRANITE, Mat.CLAY], [Mat.BASALT, Mat.DIRT, Mat.SAND]]},
	"tunnel": {"name": "tunnel", "key": "tunnel", "material": Mat.AIR, "host": [Mat.LIMESTONE, Mat.GRANITE],
		"seeds": [1, 2], "supply": [20, 60], "lz": [6, 44], "shape": "vein", "height": 2, "branch": 3277,
		"dirW": {"horiz": 4, "vert": 1}, "relax": [[Mat.BASALT, Mat.CLAY], [Mat.DIRT, Mat.SAND]]},
	"shaft": {"name": "shaft", "key": "shaft", "material": Mat.AIR, "host": [Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT],
		"seeds": [0, 1], "supply": [8, 20], "lz": [6, 44], "shape": "vein", "keep": 62259, "branch": 0,
		"dirW": {"horiz": 0, "vert": 1}, "relax": [[Mat.CLAY, Mat.DIRT, Mat.SAND]]},
}
const SHAPES := ["chamber", "tunnel", "shaft"]
## voda na recept [min, max] buněk (zástupce serveru)
const WATER := {"louka": [0, 40], "kopec": [0, 60], "hora": [10, 90], "piscina": [0, 30]}

## ---------- zástupce serveru: {"cave_air": n, "water": w} (voda v celých buňkách), vždy rozmístitelné: cave_air >= rezervoár
static func server_target(kind: String, seed: int, bonus_pct := 0) -> Dictionary:
	var r := Ore.Rng.new(H.mix(seed, "CAVE_TARGET", 0))
	var air := 0
	for k in SHAPES:
		var sp: Dictionary = CATALOG[k]
		var n := r.range_i(sp.seeds[0], sp.seeds[1])
		for i in n:
			air += r.range_i(sp.supply[0], sp.supply[1])
	var wr: Array = WATER.get(kind, [0, 40])
	var w := r.range_i(wr[0], wr[1])
	air += air * bonus_pct / 100
	w += w * bonus_pct / 100
	return {"cave_air": air + reservoir_size(w), "water": w}

static func reservoir_size(w: int) -> int:
	return (w * RES_HEAD_PCT + 99) / 100

## maska, kam smí jeskyně: strop ROOF pod povrchem (i u sousedních sloupců), okraj MARGIN, ne dno
static func eligibility(hm: PackedInt32Array) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(N)
	for x in range(MARGIN, BS - MARGIN):
		for y in range(MARGIN, BS - MARGIN):
			var top: int = hm[x * BS + y]
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				top = mini(top, hm[(x + d[0]) * BS + (y + d[1])])
			for z in range(1, top - ROOF):
				e[(x * BS + y) * BH + z] = 1
	return e

## ---------- jeskyně: přesný počet buněk vzduchu; rezervoár první (velikost podle vody), zbytek do tvarů podle průměrů katalogu
static func carve(cells: PackedByteArray, hm: PackedInt32Array, seed: int, target: Dictionary) -> Dictionary:
	var total: int = target.get("cave_air", 0)
	var res := mini(total, reservoir_size(target.get("water", 0)))
	var rest := total - res
	var means := []
	var msum := 0
	for k in SHAPES:
		var m := Ore.normal_mean(CATALOG[k])
		means.append(m); msum += m
	var t := {"reservoir": res}
	var acc := 0
	for i in SHAPES.size():
		var v: int = rest * int(means[i]) / maxi(msum, 1) if i < SHAPES.size() - 1 else rest - acc
		t[SHAPES[i]] = v; acc += v
	var specs := [CATALOG["reservoir"]]
	for k in SHAPES:
		specs.append(CATALOG[k])
	Ore.elig = eligibility(hm)
	var r := Ore.place(cells, H.mix(seed, "CAVE", 0), t, specs)
	Ore.elig = PackedByteArray()
	r["split"] = t
	var placed := 0
	for k in r.placed:
		placed += r.placed[k]
	r["cave_air_target"] = total
	r["cave_air_placed"] = placed
	r["cave_air_shortfall"] = total - placed
	return r

## ---------- pánve: souvislé oblasti jeskynního vzduchu (vzduch pod povrchem, 6-sousedství)
## Pro každou: escape = nejnižší lz, kde by voda unikla (hrana bloku, dno, povrchový vzduch, propustný soused z boku nebo zespodu),
## L = escape − 1 (bez úniku: L = nejvyšší buňka = uzavřená dutina, smí být plná).
static func basins(cells: PackedByteArray, hm: PackedInt32Array) -> Array:
	var lab := PackedInt32Array()
	lab.resize(N); lab.fill(-1)
	var out := []
	for c0 in N:
		if lab[c0] >= 0 or cells[c0] != Mat.AIR or c0 % BH >= hm[c0 / BH]:
			continue
		var id := out.size()
		var q := PackedInt32Array([c0])
		lab[c0] = id
		var head := 0
		var esc := 999
		var zmax := 0
		var leaks := []     # [z, propustná buňka]
		while head < q.size():
			var c := q[head]; head += 1
			var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
			zmax = maxi(zmax, z)
			if x == 0 or y == 0 or x == BS - 1 or y == BS - 1 or z == 0:
				esc = mini(esc, z)
			for d in 6:
				var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
				if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
					continue
				var n := (nx * BS + ny) * BH + nz
				var m := cells[n]
				if m == Mat.AIR:
					if nz >= hm[nx * BS + ny]:
						if d != 4:
							esc = mini(esc, z)    # povrchový vzduch z boku / zespodu (vstup jeskyně)
						else:
							esc = mini(esc, z + 1)  # otvor ve stropě: voda unikne až při zaplnění buňky
					elif lab[n] < 0:
						lab[n] = id; q.append(n)
				elif d != 4 and leaky(m):
					esc = mini(esc, z)
					leaks.append([z, n])
		var level := (esc - 1) if esc < 999 else zmax
		var cap := 0
		for c in q:
			if c % BH <= level:
				cap += 1
		out.append({"id": id, "cells": q, "level": level, "escape": esc, "zmax": zmax, "cap": cap, "leaks": leaks})
	return out

## ---------- voda: přesně target buněk (× FULL) do pánví odspodu po vodorovných vrstvách;
## W1 utěsnit: propustné buňky na únikové výšce největší netěsné pánve -> jíl (CLAY, nepropustný), opakovat; W2 schodek.
static func fill_water(cells: PackedByteArray, hm: PackedInt32Array, target_cells: int, prefer := PackedByteArray()) -> Dictionary:
	var water := PackedInt32Array()
	water.resize(N)
	var rep := {"target": target_cells, "placed_units": 0, "placed": 0.0, "sealed": 0, "seal_rounds": 0, "shortfall": 0, "basins_used": 0}
	if target_cells <= 0:
		rep["water"] = water
		return rep
	var bs := basins(cells, hm)
	var rounds := 0
	while _capacity(bs) < target_cells and rounds < 64:
		# největší netěsná pánev, kde utěsnění zvedne hladinu
		var best := -1
		var best_n := -1
		for b in bs:
			if b.leaks.size() > 0 and b.cells.size() - b.cap > 0 and b.cells.size() > best_n:
				best = b.id; best_n = b.cells.size()
		if best < 0:
			break
		var b: Dictionary = bs[best]
		var sealed := 0
		for lk in b.leaks:
			if lk[0] == b.escape and cells[lk[1]] != Mat.CLAY:
				cells[lk[1]] = Mat.CLAY; sealed += 1
		if sealed == 0:
			break
		rep.sealed += sealed
		rounds += 1
		bs = basins(cells, hm)
	rep.seal_rounds = rounds
	# pořadí pánví: obsahující rezervoár (prefer) první, pak podle kapacity
	var order := range(bs.size())
	order.sort_custom(func(a, b):
		var pa := _pref(bs[a], prefer); var pb := _pref(bs[b], prefer)
		if pa != pb:
			return pa > pb
		if bs[a].cap != bs[b].cap:
			return bs[a].cap > bs[b].cap
		return a < b)
	var left := target_cells * FULL
	for bi in order:
		if left <= 0:
			break
		var b: Dictionary = bs[bi]
		if b.cap <= 0:
			continue
		rep.basins_used += 1
		var layers := {}
		for c in b.cells:
			var z: int = c % BH
			if z <= b.level:
				if not layers.has(z):
					layers[z] = PackedInt32Array()
				layers[z].append(c)
		var zs := layers.keys()
		zs.sort()
		for z in zs:
			if left <= 0:
				break
			var lay: PackedInt32Array = layers[z]
			if left >= lay.size() * FULL:
				for c in lay:
					water[c] = FULL
				left -= lay.size() * FULL
			else:
				var each := left / lay.size()
				var extra := left - each * lay.size()
				for i in lay.size():
					water[lay[i]] = each + (1 if i < extra else 0)
				left = 0
	rep.placed_units = target_cells * FULL - left
	rep.placed = float(rep.placed_units) / FULL
	rep.shortfall = (left + FULL - 1) / FULL
	rep["water"] = water
	return rep

static func _pref(b: Dictionary, prefer: PackedByteArray) -> int:
	if prefer.is_empty():
		return 0
	for c in b.cells:
		if prefer[c] == 1:
			return 1
	return 0

static func _capacity(bs: Array) -> int:
	var s := 0
	for b in bs:
		s += b.cap
	return s

## ---------- kontrola jako na serveru (world.water_unstable)
static func validate(cells: PackedByteArray, hm: PackedInt32Array, water: PackedInt32Array) -> Dictionary:
	var errs := []
	var lab := PackedInt32Array()
	lab.resize(N); lab.fill(-1)
	var bs := basins(cells, hm)
	for b in bs:
		for c in b.cells:
			lab[c] = b.id
	var top := {}
	for c in N:
		if water[c] <= 0:
			continue
		var z := c % BH
		if cells[c] != Mat.AIR:
			errs.append({"code": "world.water_unstable", "reason": "water_in_solid", "cell": c}); continue
		var bid := lab[c]
		if bid < 0:
			errs.append({"code": "world.water_unstable", "reason": "surface_water_outside_basin", "cell": c}); continue
		var b: Dictionary = bs[bid]
		var x := c / (BS * BH); var y := (c / BH) % BS
		if x == 0 or y == 0 or x == BS - 1 or y == BS - 1 or z == 0:
			errs.append({"code": "world.water_unstable", "reason": "at_block_edge", "cell": c})
		if z > b.level:
			errs.append({"code": "world.water_unstable", "reason": "above_level", "cell": c, "level": b.level})
		top[bid] = maxi(top.get(bid, -1), z)
		if water[c] > FULL:
			errs.append({"code": "world.water_unstable", "reason": "over_full", "cell": c})
	# vodorovná hladina: pod nejvyšší vodní vrstvou pánve musí být každá buňka pánve plná
	for bid in top:
		var b: Dictionary = bs[bid]
		for c in b.cells:
			if c % BH < top[bid] and water[c] < FULL:
				errs.append({"code": "world.water_unstable", "reason": "not_level", "cell": c})
				break
	return {"ok": errs.is_empty(), "errors": errs.slice(0, 20), "error_count": errs.size()}

static func water_volume(water: PackedInt32Array) -> float:
	var s := 0
	for v in water:
		s += v
	return float(s) / FULL

static func cave_air(cells: PackedByteArray, hm: PackedInt32Array) -> int:
	var n := 0
	for c in N:
		if cells[c] == Mat.AIR and c % BH < hm[c / BH]:
			n += 1
	return n
