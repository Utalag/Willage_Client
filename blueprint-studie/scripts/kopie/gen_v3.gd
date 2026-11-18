extends RefCounted
## ZMĚNA V KOPII (blueprint-studie 2026-11-18 16:30): masky a tabulky vody na 256 MaterialId; caps()/rets() čtou i rozšíření ../sdilene/horniny_voda.json (VPar.load_shared_table ho připojí).
## gen-v3 „postupné vrstvení do hlíny“ (Jan 18:45, rozhodnutí 18:46–18:50; NÁVRH, viz willage-backend/generovani-bloku-v3.md).
## Nahrazuje STRATA + ore-v0 + cave-v0. Kód růstu, záložních stupňů (L1–L5) a schodku je ore_v0.gd (beze změny),
## kontrola stability volné vody vychází z cave_v0.gd (pánve), rozšířená o vodu v pórech (hladina podzemní vody).
## 1 tvar: povrch z receptu a seedu (generátor prototypu), pod povrchem HLÍNA, povrchová slupka (tráva, sníh) zůstává.
## 2 JEDNA fáze (Jan 18:56, ruší fázi B): všechny materiály souhrnu (horniny, písek, jíl, ložiskový jíl, rudy, jeskyně)
##   vzestupně podle počtu (shoda → MaterialId, jeskyně = 0), každý jen do hlíny, hotové se nepřepisují.
## 3 (zrušeno 18:56: fáze B rudy do kamene; stará varianta jen ve shots/gen3_stress_fazeB_1849.txt)
## 4 voda: W objemů buňky se nalije na povrch a vsákne: propustné = hlína, písek, tráva, vzduch; plní odspodu souvislou
##   propustnou oblast spojenou s povrchem (hladina podzemní vody), co se nevejde do půdy, zůstane v prohlubni (jezírko);
##   hrany bloku pod povrchem jsou zavřené (bez přetékání mezi bloky), povrchová voda nesmí přes nejnižší okraj bloku.

const Mat = preload("res://scripts/kopie/mat.gd")
const Ore = preload("res://scripts/kopie/ore_v0.gd")
const Cave = preload("res://scripts/kopie/cave_v0.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const BS := 16
const BH := 64
const N := BS * BS * BH
const FULL := Cave.FULL
const STONES := [Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT]
const ORES := [Mat.COPPER, Mat.IRON]
const CAVE_KEY := 0          # vzduch pod povrchem = jeskyně (MaterialId 0)
const S = preload("res://scripts/kopie/gen3_stack.gd")
# pórovitost = kolik vody buňka pojme (voda-studie por_*), vzduch 1
## kapacita vody podle MaterialId ze SDÍLENÉ tabulky ../sdilene/materialy_voda.json (Jan 19:18): pórovitost, když perm > perm_leak, jinak 0
const VPar = preload("res://scripts/kopie/voda_params.gd")
static var CAPS := PackedFloat32Array()
static var PROF := {}
static func _pt(k: String, t0: int) -> void:
	PROF[k] = PROF.get(k, 0.0) + (Time.get_ticks_usec() - t0) / 1000.0

## pásmo semínek z lzMin/lzMax položky (≥ 0 absolutně, < 0 hloubka pod povrchem)
static func _band(it: Dictionary, hm: PackedInt32Array) -> Array:
	if it.lzMin >= 0:
		return [it.lzMin, it.lzMax]
	var lo := 64; var hi := 0
	for h in hm:
		lo = mini(lo, h); hi = maxi(hi, h)
	return [maxi(lo + it.lzMin, 1), maxi(hi + it.lzMax, 1)]

## položka zásobníku → specifikace růstu ore_v0 (hostitel vždy jen HLÍNA; tvar a parametry nese položka)
static func _spec(it: Dictionary, hm: PackedInt32Array) -> Dictionary:
	var heap: int = it.get("maxHeap", 100)
	var name: String = "jeskyně" if it.material == Mat.AIR else Mat.NAMES[it.material]
	var host: Array = [UNSET] if it.get("host", -1) < 0 else [it.host]   # 19:19 (c): ruda uvnitř kamene
	var sp := {"name": name, "key": it.material, "material": it.material, "host": host,
		"seeds": [1, 1], "supply": [maxi(heap * 6 / 10, 1), heap], "lz": _band(it, hm), "shape": S.SHAPES[it.shape].name, "relax": []}
	match it.shape:
		S.SHAPE_LAYER, S.SHAPE_CHAMBER:
			sp["pH"] = it.pH_u16; sp["pV"] = it.pV_u16
		S.SHAPE_VEIN:
			sp["keep"] = it.inertia_permille * 65536 / 1000
			sp["branch"] = it.branch_permille * 65536 / 1000
			sp["dirW"] = {"horiz": 2, "vert": 3}
	return sp

## pásmo hloubek: buňka (x, y, z) s hloubkou d = povrch sloupce − z v [d_from, d_to] (d = 1 je nejvyšší buňka pod povrchem)
static func depth_mask(hm: PackedInt32Array, d_from: int, d_to: int) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(N)
	for x in BS:
		for y in BS:
			var h: int = hm[x * BS + y]
			for d in range(maxi(d_from, 1), d_to + 1):
				var z := h - d
				if z >= 1:
					e[(x * BS + y) * BH + z] = 1
	return e

## sál: semínka i růst jen pod střechou (roof buněk pod nejnižším povrchem sloupce a 4 sousedů) a margin od stran bloku, ne lz = 0
static func chamber_mask(hm: PackedInt32Array, roof: int, margin: int) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(N)
	for x in range(margin, BS - margin):
		for y in range(margin, BS - margin):
			var top: int = hm[x * BS + y]
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = clampi(x + d[0], 0, BS - 1); var ny: int = clampi(y + d[1], 0, BS - 1)
				top = mini(top, hm[nx * BS + ny])
			for z in range(1, top - roof):
				e[(x * BS + y) * BH + z] = 1
	return e

## základní objem: povrch z prototypu, pod povrchem hlína, slupka (tráva / sníh) z prototypu zůstává
## UNSET = dosud nepřiřazená buňka pod povrchem (vnitřní hodnota generátoru; MaterialId mlhy 11, v zásobníku zakázaný,
## ve výsledku nesmí zůstat). Od 19:18 (Jan, varianta 2) je hlína běžná položka zásobníku a do UNSET se šíří vše.
const UNSET := Mat.FOG

## objem k rozdělení = počet buněk UNSET v základním objemu (pod povrchem bez slupky tráva/sníh)
static func free_volume(proto_cells: PackedByteArray, hm: PackedInt32Array) -> int:
	var n := 0
	for c in base_volume(proto_cells, hm):
		if c == UNSET: n += 1
	return n

static func base_volume(proto_cells: PackedByteArray, hm: PackedInt32Array) -> PackedByteArray:
	var c := PackedByteArray()
	c.resize(N)
	for x in BS:
		for y in BS:
			var h: int = hm[x * BS + y]
			for z in h:
				var i := (x * BS + y) * BH + z
				var m := proto_cells[i]
				c[i] = m if (z == h - 1 and (m == Mat.GRASS or m == Mat.SNOW)) else UNSET
	return c

## generování podle ZÁSOBNÍKU ze serveru (Jan 18:58): dekódované položky gen3_stack.gd [{material, count, shape, params}] v daném pořadí.
## Generátor je materiálově agnostický: pořadí NEŘADÍ (to dělá server), každá položka jen do nepřiřazených buněk (UNSET), nic nepřepisuje.
## Varianta 2 (Jan 19:18): hlína je položka (vrstva u povrchu), kámen dostane zbytek objemu, Σ count == V − slupka.
## tvar chamber: semínka i růst jen v masce chamber_mask(roof, margin) (jeskyně pod povrchem, ne u stran bloku).
## Stream náhody položky = H.mix(seed, "GEN3", pořadí v zásobníku). Hlína = zbytek. water = objem buněk k nalití.
## vstup = bajty zásobníku; neplatný zásobník → {ok:false, error world.stack_invalid}
static func generate_bytes(proto_cells: PackedByteArray, hm: PackedInt32Array, seed: int, stack_bytes: PackedByteArray, water := 0) -> Dictionary:
	var d := S.decode(stack_bytes)
	if not d.ok:
		return d
	# varianta 2: zásobník musí rozdělit PŘESNĚ celý objem pod povrchem (Σ count == V − slupka)
	var tot := 0
	for it in d.items:
		if it.get("host", -1) < 0:
			tot += int(it.count)
	var vf := free_volume(proto_cells, hm)
	if tot != vf:
		return {"ok": false, "error": {"code": "world.stack_invalid", "reason": "volume_mismatch", "item": -1, "want": vf, "got": tot}}
	var g := generate(proto_cells, hm, seed, d.items, water)
	g["ok"] = true
	g["stack_hash"] = S.hash(stack_bytes)
	g["stack"] = d.items
	return g

static func generate(proto_cells: PackedByteArray, hm: PackedInt32Array, seed: int, stack: Array, water := 0) -> Dictionary:
	var cells := base_volume(proto_cells, hm)
	var t0 := Time.get_ticks_usec()
	var reps := []
	for i in stack.size():
		var it: Dictionary = stack[i]
		var sp := _spec(it, hm)
		var tq := Time.get_ticks_usec()
		if it.shape == S.SHAPE_STRATUM:
			reps.append(_stratum(cells, it, seed, i))
			_pt("stratum", tq)
			continue
		var depth_item: bool = it.lzMin < 0
		if it.shape == S.SHAPE_CHAMBER:
			Ore.elig = chamber_mask(hm, it.roof, it.margin)
		elif depth_item:
			# hloubka pod povrchem VLASTNÍHO sloupce (19:18): semínka i růst L0–L3 jen v pásmu hloubek
			Ore.elig = depth_mask(hm, -it.lzMax, -it.lzMin)
			sp.lz = [1, BH - 1]
		_pt("mask", tq); tq = Time.get_ticks_usec()
		var r := Ore.place(cells, H.mix(seed, "GEN3", i), {sp.key: int(it.count)}, [sp])
		_pt("place", tq); tq = Time.get_ticks_usec()
		var rep: Dictionary = r.per_ore[0]
		if depth_item:
			Ore.elig = PackedByteArray()   # L4 (dokud není vše) už bez pásma, aby počet seděl vždy
		_sweep(cells, rep, sp, seed * 31 + i)
		_pt("sweep", tq); tq = Time.get_ticks_usec()
		Ore.elig = PackedByteArray()
		if it.shape == S.SHAPE_LAYER:
			rep["holes_swapped"] = _fill_holes(cells, rep, it.material)
		_pt("holes", tq)
		reps.append(rep)
	var layer_mats := []
	for it in stack:
		if it.shape == S.SHAPE_LAYER and not (it.material in layer_mats):
			layer_mats.append(it.material)
	var tsp := Time.get_ticks_usec()
	var specks_swapped := _swap_specks(cells, layer_mats)
	_pt("specks", tsp)
	var t1 := Time.get_ticks_usec()
	var t2 := t1
	var wr := infiltrate(cells, hm, water)
	var t3 := Time.get_ticks_usec()
	return {"cells": cells, "water": wr.water, "reps": reps, "water_rep": wr, "order": stack.map(func(it): return it.material), "specks_swapped": specks_swapped,
		"ms": {"A": (t1 - t0) / 1000.0, "B": (t2 - t1) / 1000.0, "water": (t3 - t2) / 1000.0}}

## L4 gen-v3 („vkládat, dokud není vše rozmístěno“, Jan 18:45): bez stropu semínek – semínko skenem do libovolné volné
## buňky hostitele (hlína / kámen) a BFS bez náhody, dokud schodek > 0 nebo hostitel nedojde. Zbytek = L5 schodek.
static func _sweep(cells: PackedByteArray, rep: Dictionary, sp: Dictionary, seed: int) -> void:
	if rep.shortfall <= 0:
		return
	var host := PackedByteArray()
	host.resize(256)
	for m in sp.host:
		host[m] = 1
	var rng := Ore.Rng.new(H.mix(seed, "GEN3_SWEEP", 0))
	var own: PackedInt32Array = rep.cells
	var got := 0
	while rep.shortfall - got > 0:
		var c := Ore._scan_host(cells, host, rng.range_i(0, N - 1), 0, BH - 1)
		if c < 0:
			break
		cells[c] = sp.material; own.append(c); got += 1
		got += Ore._grow_bodies(cells, PackedInt32Array([c]), rep.shortfall - got, host, sp.material)
	rep.by_level[4] += got
	rep.placed += got
	rep.shortfall -= got
	rep.by_level[5] = rep.shortfall

static func caps() -> PackedFloat32Array:
	if CAPS.is_empty():
		var d := VPar.load_shared_table()
		CAPS.resize(256)
		var leak := float(d.get("perm_leak", 0.05))
		for k in d.get("materials", {}):
			var m: Dictionary = d.materials[k]
			if int(m.id) < 256:
				CAPS[int(m.id)] = float(m.por) if float(m.perm) > leak else 0.0
	return CAPS

## výměna děr (varianta 2, proti tečkám jiného materiálu v kameni): nepřiřazená buňka bez nepřiřazeného souseda, kterou
## z ≥ 3 stran obklopuje právě rozmístěná položka, se přidá položce; za ni se vrátí okrajová buňka tělesa s nejvíc (≥ 2)
## nepřiřazenými sousedy. Počet položky se nemění, pořadí deterministické (index vzestupně).
static func _fill_holes(cells: PackedByteArray, rep: Dictionary, mat: int) -> int:
	var own: PackedInt32Array = rep.cells
	var swaps := 0
	var ci := 0
	# kandidáti: nepřiřazení sousedé vlastních buněk (seřazení podle indexu kvůli determinismu)
	var cand := {}
	for o in own:
		var ox := o / (BS * BH); var oy := (o / BH) % BS; var oz := o % BH
		for d in 6:
			var nx: int = ox + Ore.DX[d]; var ny: int = oy + Ore.DY[d]; var nz: int = oz + Ore.DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			var n := (nx * BS + ny) * BH + nz
			if cells[n] == UNSET:
				cand[n] = true
	var keys := cand.keys()
	keys.sort()
	for c: int in keys:
		if cells[c] != UNSET:
			continue
		var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
		var free := 0; var mine := 0
		for d in 6:
			var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			var m := cells[(nx * BS + ny) * BH + nz]
			if m == UNSET: free += 1
			elif m == mat: mine += 1
		if free > 0 or mine < 3:
			continue
		# najít okrajovou buňku vlastního tělesa (od indexu ci dál, kruhově)
		var best := -1; var bi := -1
		for k in own.size():
			var j := (ci + k) % own.size()
			var o := own[j]
			if cells[o] != mat:
				continue
			if _free_n(cells, o) >= 2:
				best = o; bi = j
				break
		if best < 0:
			break
		cells[best] = UNSET; cells[c] = mat; own[bi] = c; ci = bi + 1
		swaps += 1
	return swaps

## úklid teček (19:18): buňka materiálu vrstvy bez jediného souseda stejného materiálu, jejíž sousedé jsou většinou materiál M
## (také vrstva), se vymění s buňkou M, která leží u tělesa původního materiálu (≥ 2 jeho sousedé) a sama tečka není.
## Počty se nemění, jen polohy; deterministicky (index vzestupně), nejvýš jeden průchod.
const SPECK_R := 4
static func _swap_specks(cells: PackedByteArray, mats: Array) -> int:
	var is_l := PackedByteArray()
	is_l.resize(256)
	for m in mats:
		is_l[m] = 1
	var swaps := 0
	for c in N:
		var a := cells[c]
		if is_l[a] == 0 or _same_n(cells, c, a) > 0:
			continue
		# většinový soused
		var cnt := {}
		var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
		for d in 6:
			var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			var m := cells[(nx * BS + ny) * BH + nz]
			if is_l[m] == 1:
				cnt[m] = cnt.get(m, 0) + 1
		var mm := -1; var best := 0
		for m in cnt:
			if cnt[m] > best or (cnt[m] == best and m < mm):
				best = cnt[m]; mm = m
		if mm < 0 or best < 3:
			continue
		# hledat jen v okolí ±R (krychle), deterministicky po indexu
		var done := false
		for ox in range(maxi(x - SPECK_R, 0), mini(x + SPECK_R, BS - 1) + 1):
			for oy in range(maxi(y - SPECK_R, 0), mini(y + SPECK_R, BS - 1) + 1):
				for oz in range(maxi(z - SPECK_R, 0), mini(z + SPECK_R, BH - 1) + 1):
					var o := (ox * BS + oy) * BH + oz
					if cells[o] == mm and _same_n(cells, o, a) >= 2 and _same_n(cells, o, mm) >= 1:
						cells[o] = a; cells[c] = mm
						swaps += 1; done = true
						break
				if done: break
			if done: break
	return swaps

static func _same_n(cells: PackedByteArray, c: int, m: int) -> int:
	var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
	var n := 0
	for d in 6:
		var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
		if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
			continue
		if cells[(nx * BS + ny) * BH + nz] == m: n += 1
	return n

## 19:19 (e) stratum: klíč buňky = z + vlna(x, y) (hodnotový šum 2D ze seedu a pořadí položky, amplituda amp_tenths/10,
## krok `scale`); vyplní prvních `count` nepřiřazených buněk podle klíče (přihrádkové řazení, shoda → index). O(N), přesně.
static func _stratum(cells: PackedByteArray, it: Dictionary, seed: int, i: int) -> Dictionary:
	var amp: float = it.amp_tenths / 10.0
	var sc: int = it.scale
	var rng := Ore.Rng.new(H.mix(seed, "GEN3_STRAT", i))
	var gx := BS / sc + 2
	var grid := PackedFloat32Array()
	grid.resize(gx * gx)
	for k in grid.size():
		grid[k] = (rng.u16() / 65535.0) * 2.0 - 1.0
	const SUB := 8
	var nb := (BH + 2 * 17) * SUB
	var buckets := []
	buckets.resize(nb)
	for x in BS:
		for y in BS:
			var fx := float(x) / sc; var fy := float(y) / sc
			var ix := int(fx); var iy := int(fy)
			var tx := fx - ix; var ty := fy - iy
			tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty)
			var a := lerpf(grid[ix * gx + iy], grid[(ix + 1) * gx + iy], tx)
			var b := lerpf(grid[ix * gx + iy + 1], grid[(ix + 1) * gx + iy + 1], tx)
			var off := lerpf(a, b, ty) * amp
			var base := (x * BS + y) * BH
			for z in BH:
				if cells[base + z] != UNSET:
					continue
				var k := clampi(int(floor((z + off + 17.0) * SUB)), 0, nb - 1)
				if buckets[k] == null:
					buckets[k] = PackedInt32Array()
				buckets[k].append(base + z)
	var left: int = it.count
	var own := PackedInt32Array()
	for k in nb:
		if left <= 0:
			break
		if buckets[k] == null:
			continue
		var bk: PackedInt32Array = buckets[k]
		bk.sort()
		for c in bk:
			if left <= 0:
				break
			cells[c] = it.material; own.append(c); left -= 1
	var placed: int = it.count - left
	return {"name": Mat.NAMES[it.material], "key": it.material, "material": it.material, "target": it.count, "placed": placed,
		"shortfall": left, "by_level": [placed, 0, 0, 0, 0, left], "cells": own}

static func _free_n(cells: PackedByteArray, c: int) -> int:
	var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
	var n := 0
	for d in 6:
		var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
		if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
			continue
		if cells[(nx * BS + ny) * BH + nz] == UNSET: n += 1
	return n

static func cap_of(m: int) -> float:
	return caps()[m] if m < 256 else 0.0

## ---------- vsakování: souvislá propustná oblast spojená s povrchovým vzduchem, plnění odspodu po vrstvách
## zadržená voda (19:19 b) v jednotkách 1/4096 podle MaterialId (ret ze sdílené tabulky)
static var RETS := PackedInt32Array()
static var PERCHED := 2
static func rets() -> PackedInt32Array:
	if RETS.is_empty():
		var d := VPar.load_shared_table()
		RETS.resize(256)
		PERCHED = int(d.get("perched_depth", 2))
		for k in d.get("materials", {}):
			var m: Dictionary = d.materials[k]
			if int(m.id) < 256:
				RETS[int(m.id)] = int(round(float(m.get("ret", 0.0)) * FULL))
	return RETS

static func capu(m: int) -> int:
	return int(round(cap_of(m) * FULL))

## kolik vody buňka zadrží nad hladinou: písek vždy (Jan 18:50 „v písku se drží“), hlína / tráva jen nad jílem
## (zavěšená voda: jíl nebo ložiskový jíl nejvýš PERCHED buněk pod ní, mezi nimi propustná zemina)
static var RETENTION := true   # (b) přepínač pro srovnání
static func ret_cell(cells: PackedByteArray, c: int) -> int:
	if not RETENTION:
		return 0
	var m := cells[c]
	if m == Mat.SAND:
		return rets()[m]
	if m != Mat.DIRT and m != Mat.GRASS:
		return 0
	var z := c % BH
	for k in range(1, PERCHED + 1):
		if z - k < 0:
			return 0
		var b := cells[c - k]
		if b == Mat.CLAY or b == Mat.CLAY_DEPOSIT:
			return rets()[m]
		if cap_of(b) <= 0.0 or b == Mat.AIR:
			return 0
	return 0

static func _rim(hm: PackedInt32Array) -> int:
	var esc := BH
	for x in BS:
		for y in BS:
			if x == 0 or y == 0 or x == BS - 1 or y == BS - 1:
				esc = mini(esc, hm[x * BS + y])
	return esc

## vsakování (19:19): (b) nejdřív zadržená voda v buňkách nad hladinou (shora dolů), zbytek do hladiny podzemní vody
## odspodu jen přes propustné buňky spojené s povrchem pod okrajem (e); hladina a zadržená voda se dorovnají iterací.
static func infiltrate(cells: PackedByteArray, hm: PackedInt32Array, w_cells: int) -> Dictionary:
	var water := PackedInt32Array()
	water.resize(N)
	var rep := {"target": w_cells, "placed": 0.0, "pores": 0.0, "free_cave": 0.0, "pond": 0.0, "runoff": 0.0, "level": -1, "retained": 0.0}
	if w_cells <= 0:
		rep["water"] = water; rep["runoff_units"] = 0
		return rep
	var esc := _rim(hm)
	var reg := _surface_region(cells, hm, esc)
	var layers := {}
	var ret_list := []    # [z, c, r]
	for c in reg:
		var z: int = c % BH
		var r := ret_cell(cells, c)
		if r > 0:
			ret_list.append([z, c, r])
		if z >= esc:
			continue
		if not layers.has(z):
			layers[z] = PackedInt32Array()
		layers[z].append(c)
	ret_list.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var zs := layers.keys()
	zs.sort()
	var W := w_cells * FULL
	var L := BH
	var tab := {}
	var R := 0
	for it in 64:
		R = 0
		for e in ret_list:
			if e[0] > L:
				R += e[2]
		var res := _table(cells, layers, zs, maxi(W - R, 0))
		if res.level == L or it == 63:
			tab = res
			break
		L = res.level
		tab = res
	# zapsat: zadržená voda (jen nad hladinou, shora dolů, dokud zbývá), pak hladina
	var left := W - int(tab.used)
	var lvl: int = tab.level
	for e in ret_list:
		if e[0] <= lvl or left <= 0:
			continue
		var r: int = mini(e[2], left)
		water[e[1]] = r; left -= r
		rep.retained += float(r) / FULL
	for c in tab.water:
		water[c] = tab.water[c]
	var have := W - left
	for c in reg:
		if water[c] <= 0:
			continue
		var v := float(water[c]) / FULL
		if cells[c] == Mat.AIR:
			if c % BH >= hm[c / BH]:
				rep.pond += v
			else:
				rep.free_cave += v
		else:
			rep.pores += v
	rep.placed = float(have) / FULL
	rep.runoff = float(left) / FULL
	rep["runoff_units"] = left
	rep.level = lvl
	rep["water"] = water
	return rep

## hladina: plné vrstvy odspodu, poslední vrstva poměrně (celá čísla, zbytek po indexu)
static func _table(cells: PackedByteArray, layers: Dictionary, zs: Array, A: int) -> Dictionary:
	var out := {}
	var left := A
	var lvl := -1
	for z in zs:
		if left <= 0:
			break
		var lay: PackedInt32Array = layers[z]
		var cs := 0
		for c in lay:
			cs += capu(cells[c])
		if cs <= 0:
			continue
		lvl = z
		if left >= cs:
			for c in lay:
				out[c] = capu(cells[c])
			left -= cs
		else:
			var given := 0
			for c in lay:
				var v := capu(cells[c]) * left / cs
				out[c] = v; given += v
			var rest := left - given
			var i := 0
			while rest > 0 and i < lay.size() * 2:
				var c := lay[i % lay.size()]
				if out[c] < capu(cells[c]):
					out[c] += 1; rest -= 1
				i += 1
			left = rest
			break
	return {"water": out, "level": lvl, "used": A - left}

## propustné buňky (a vzduch) spojené s povrchem; vzduch nad terénem jen pod okrajem (výš voda stejně nesmí), 19:19 (e)
static func _surface_region(cells: PackedByteArray, hm: PackedInt32Array, esc: int) -> PackedInt32Array:
	var seen := PackedByteArray()
	seen.resize(N)
	var q := PackedInt32Array()
	for x in BS:
		for y in BS:
			var h: int = hm[x * BS + y]
			var base := (x * BS + y) * BH
			if h >= 1 and cap_of(cells[base + h - 1]) > 0.0:
				seen[base + h - 1] = 1; q.append(base + h - 1)
			for z in range(h, mini(esc, BH)):
				if cells[base + z] == Mat.AIR and seen[base + z] == 0:
					seen[base + z] = 1; q.append(base + z)
	var head := 0
	while head < q.size():
		var c := q[head]; head += 1
		var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
		for d in 6:
			var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			var n := (nx * BS + ny) * BH + nz
			if seen[n] != 0 or cap_of(cells[n]) <= 0.0:
				continue
			if cells[n] == Mat.AIR and nz >= hm[nx * BS + ny] and nz >= esc:
				continue
			seen[n] = 1; q.append(n)
	return q

## ---------- kontrola jako na serveru
## souhrn: KAŽDÝ materiál přesně podle souhrnu (Jan 18:56), jeskyně přesně, hlína = V − Σ souhrnu;
## voda: celkový objem = vydaný − odtok (nahlášený), volná voda stabilní (hladina pod únikem, vodorovná, pod ní vše nasycené).
## reported = nahlášený schodek z hlavičky WVB1 {klíč -> počet, "water_units" -> jednotky odtoku}
## souhrn ze zásobníku (pro kontrolu): {material -> Σ count}, podzemní vzduch pod klíčem CAVE_KEY, "water"
## 19:19 (c): ruda s hostitelem přepíše hostitele → konečný počet hostitele = vydaný − Σ jeho rud
static func summary_of(stack: Array, water: int) -> Dictionary:
	var s := {"water": water}
	for it in stack:
		var k: int = it.material
		s[k] = s.get(k, 0) + int(it.count)
	for it in stack:
		if it.get("host", -1) >= 0:
			s[it.host] = s.get(it.host, 0) - int(it.count)
	return s

static func validate(cells: PackedByteArray, hm: PackedInt32Array, water: PackedInt32Array, summary: Dictionary, reported := {}) -> Dictionary:
	var errs := []
	# 19:19 (e) JEDEN průchod: počty materiálů, jeskyně, součet vody, kontrola buněk, seznam mokrých buněk
	var cnt := PackedInt32Array(); cnt.resize(256)
	var cave := 0; var tot := 0
	var wet := PackedInt32Array()
	for c in N:
		var m := cells[c]
		cnt[m] += 1
		if m == Mat.AIR and c % BH < hm[c / BH]:
			cave += 1
		var v := water[c]
		if v <= 0:
			continue
		tot += v
		wet.append(c)
		var cu := capu(m)
		if cu <= 0:
			errs.append({"code": "world.water_unstable", "reason": "water_in_impermeable", "cell": c})
		elif v > cu + 1:
			errs.append({"code": "world.water_unstable", "reason": "over_capacity", "cell": c})
	for k in summary:
		if k is String:
			continue
		var wantk: int = summary[k] - reported.get(k, 0)
		var got: int = cave if k == CAVE_KEY else cnt[k]
		if got != wantk:
			errs.append({"code": "world.summary_mismatch", "mat": "jeskyně" if k == CAVE_KEY else Mat.NAMES[k], "want": wantk, "got": got})
	if cnt[UNSET] > 0:
		errs.append({"code": "world.summary_mismatch", "mat": "nepřiřazeno", "want": 0, "got": cnt[UNSET]})
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY, Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT, Mat.COPPER, Mat.IRON, Mat.CLAY_DEPOSIT]:
		if cnt[m] > 0 and not summary.has(m):
			errs.append({"code": "world.summary_mismatch", "mat": Mat.NAMES[m], "want": 0, "got": cnt[m]})
	var want: int = summary.get("water", 0) * FULL - int(reported.get("water_units", 0))
	if tot != want:
		errs.append({"code": "world.water_mismatch", "want": want, "got": tot})
	# stabilita jen pro oblasti s vodou: hladina = nejvyšší buňka s vodou nad zadržené množství; pod ní vše nasycené,
	# nad ní jen zadržená voda (písek, hlína nad jílem ≤ ret), volná voda pod nejnižším okrajem bloku
	var esc_edge := _rim(hm)
	var lab := PackedByteArray(); lab.resize(N)
	for c0 in wet:
		if lab[c0] != 0 or capu(cells[c0]) <= 0:
			continue
		var q := PackedInt32Array([c0]); lab[c0] = 1
		var head := 0
		var top := -1
		var open_surface := false
		while head < q.size():
			var c := q[head]; head += 1
			if water[c] > ret_cell(cells, c):
				top = maxi(top, c % BH)
			var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
			if cells[c] == Mat.AIR and z >= hm[x * BS + y]:
				open_surface = true
			for d in 6:
				var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
				if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
					continue
				var n := (nx * BS + ny) * BH + nz
				if lab[n] != 0 or capu(cells[n]) <= 0:
					continue
				if cells[n] == Mat.AIR and nz >= hm[nx * BS + ny] and nz >= esc_edge:
					open_surface = true
					continue
				lab[n] = 1; q.append(n)
		if top >= 0 and open_surface and top >= esc_edge:
			errs.append({"code": "world.water_unstable", "reason": "above_block_rim", "top": top, "rim": esc_edge})
		for c in q:
			var z := c % BH
			if z < top and water[c] < capu(cells[c]) - 1:
				errs.append({"code": "world.water_unstable", "reason": "not_saturated_below_level", "cell": c, "top": top})
				break
			if z > top and water[c] > ret_cell(cells, c):
				errs.append({"code": "world.water_unstable", "reason": "above_level", "cell": c})
				break
	return {"ok": errs.is_empty(), "errors": errs.slice(0, 10), "error_count": errs.size()}
