extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/geo_fn.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Spojité funkce terénu a hornin (Jan 2026-11-18 16:42): buňky jsou jen VZORKY. Materiál se počítá funkcí bodu světa
## (X, Y, Z v metrech) v středu buňky, takže stejný blueprint dá stejný tvar při libovolném rozlišení.
##
## Parametry funkcí jsou na ŘÍDICÍ mřížce s roztečí U = 0,5 m (16 × 16 bodů na blok 8 × 8 m): povrch hm_f a hranice
## vrstev bs[k] (desetinná čísla v jednotkách U). Mezi řídicími body se interpoluje bilineárně PŘES HRANICE BLOKŮ
## (u švu se berou řídicí body souseda), takže funkce je spojitá i přes šev. Chybí-li soused, okraj se zrcadlí.
## Při 16 × 16 × 64 padnou středy buněk přesně na řídicí body (váha 1) → výsledek nezávisí na pozdějších sousedech.
## Všechny délky v tabulkách (poloměry těles, sníh, mocnosti) jsou v jednotkách U a převádějí se jedním násobkem na metry.
##
## API (viz README „Funkční API“):
##   world_fn(slots, own)              kontext světa (záznamy bloků s hm_f, bs) + rozpracovaný blok
##   block_info(wf, slot, bp, p)       konstanty bloku: profil, vrstvy, tělesa (středy v m), šumy
##   surface_m(wf, slot, X, Y)         výška povrchu v m
##   boundary_m(wf, slot, k, X, Y)     vršek vrstvy k v m
##   column(wf, info, X, Y)            povrch + všechny hranice v jednom sloupci (cache pro vzorkování)
##   material(info, col, X, Y, Z)      MaterialId v bodě (bez minerálů)
##   sample(wf, info, n, x0, x1, cells) buňky n × n × 4n (sloupce x0..x1), index (x · n + y) · 4n + z
##   minerals(cells, n, wf, info, minerals, seed)  minerály ve spojitém prostoru, počty zachované (× (n/16)³)

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const BG = preload("res://scripts/teren/zaklad/block_gen.gd")
const H = preload("res://scripts/teren/zaklad/stable_hash.gd")
const Ore = preload("res://scripts/teren/zaklad/ore_v0.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const HT = preload("res://scripts/teren/hostitele.gd")
const G2 = preload("res://scripts/teren/geo2.gd")

const U := 0.5      # m, rozteč řídicí mřížky = délková jednotka tabulek
const BW := 8.0     # m, šířka bloku
const BHT := 32.0   # m, výška bloku

static func world_fn(slots: Dictionary, own: Dictionary = {}) -> Dictionary:
	return {"slots": slots, "own": own}

static func _rec(wf: Dictionary, s: Vector2i):
	if not wf.own.is_empty() and wf.own.slot == s:
		return wf.own
	return wf.slots.get(s, null)

## řídicí hodnota (jednotky U) v řídicím bodě světa (gx, gy); field −1 = povrch, k ≥ 0 = hranice vrstvy k
static func _ctl(wf: Dictionary, home: Vector2i, k: int, gx: int, gy: int) -> float:
	var s := Vector2i(floori(gx / 16.0), floori(gy / 16.0))
	var r = _rec(wf, s)
	if r == null or (k >= 0 and r.bs.size() <= k):
		s = home; r = _rec(wf, home)
		gx = clampi(gx, home.x * 16, home.x * 16 + 15); gy = clampi(gy, home.y * 16, home.y * 16 + 15)
	var i := (gx - s.x * 16) * 16 + (gy - s.y * 16)
	if k == -2:   # povrch PŘED erozí (E47); bez eroze = hm_f
		return r.hm_pre[i] if r.has("hm_pre") else r.hm_f[i]
	return r.hm_f[i] if k < 0 else r.bs[k][i]

static func _field(wf: Dictionary, home: Vector2i, k: int, X: float, Y: float) -> float:
	var fx := X / U - 0.5; var fy := Y / U - 0.5
	var ix := floori(fx); var iy := floori(fy)
	var tx := fx - ix; var ty := fy - iy
	var a := _ctl(wf, home, k, ix, iy)
	if tx < 1e-9 and ty < 1e-9:
		return a * U
	var b := _ctl(wf, home, k, ix + 1, iy)
	var c := _ctl(wf, home, k, ix, iy + 1)
	var d := _ctl(wf, home, k, ix + 1, iy + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty) * U

static func surface_m(wf: Dictionary, slot: Vector2i, X: float, Y: float) -> float:
	return _field(wf, slot, -1, X, Y)

static func boundary_m(wf: Dictionary, slot: Vector2i, k: int, X: float, Y: float) -> float:
	return _field(wf, slot, k, X, Y)

static func block_info(wf: Dictionary, slot: Vector2i, bp: Dictionary, p: Dictionary) -> Dictionary:
	var prof := G2.kind_of(bp.shape)
	var kind := "nizina" if bp.shape in ["louka", "prohlubeň"] else ("kopec" if prof == "mirne" else ("hora" if prof.begins_with("hora") else prof))
	var crys: Array = HR.layers(HR.ZONES[1], p)
	var zone_of := PackedByteArray(); zone_of.resize(256); zone_of.fill(255)
	for e in HR.raw().rocks:
		var zi := HR.ZONES.find(e.zone)
		if zi >= 0 and e.kind == "layer": zone_of[int(e.id)] = zi
	var info := {"slot": slot, "bp": bp, "p": p, "prof": prof, "kind": kind,
		"lay": HR.pool(p).map(func(e): return int(e.id)),
		"core_id": int(crys[crys.size() - 1].id) if not crys.is_empty() else Mat.GRANITE,
		"tk": 0 if kind == "nizina" else (1 if kind == "kopec" else 2),
		"zone_of": zone_of, "mtn": HR.mountain(p).filter(func(e): return kind in e.types),
		"mnoise": BG.noise(int(bp.seed), "BP_MTN_M", 0, 0.4, 2),   # 0,4 / m
		"vent": HR.special("vent", p) if kind == "sopka" else {},
		"dep": HR.id_of(str(p.get("ero_deposit", "gravel_sand")))}   # nános eroze (E47)
	# tělesa: středy v metrech světa
	var bodies := []
	for kd in ["pipe", "dome", "vein", "contact"]:
		var e := HR.special(kd, p)
		if e.is_empty(): continue
		var demo: Array = p.demo_pipes if kd == "pipe" else (p.demo_domes if kd == "dome" else [])
		if kd == "contact":
			var around := {}; var inn := {}
			for k in e.body.around: around[HR.id_of(k)] = true
			for k in e.body["in"]: inn[HR.id_of(k)] = true
			bodies.append({"kind": kd, "e": e, "around": around, "in": inn}); continue
		var reach := 4.0 if kd == "pipe" else (6.0 if kd == "dome" else float(e.body.extent))
		for c in G2._centers(e, slot, p, demo, reach):
			var b := {"kind": kd, "e": e, "c": c[0] * U}
			if kd == "pipe":
				b.zt = (float(G2.zone_tops(c[0].x, c[0].y, p)[1]) + float(e.body.top_above_crystalline)) * U
			elif kd == "dome":
				b.zb = float(G2.zone_tops(c[0].x, c[0].y, p)[1]) * U
			elif kd == "vein":
				b.planes = []
				for k in int(e.body.planes):
					var rng := Ore.Rng.new(H.mix(c[1], "PLANE", k))
					var nrm := Vector3(rng.range_i(-100, 100), rng.range_i(-100, 100), rng.range_i(-30, 30)).normalized()
					var cz: float = 13.0 + rng.range_i(0, 12)
					b.planes.append([Vector3(c[0].x + rng.range_i(-4, 4), c[0].y + rng.range_i(-4, 4), cz) * U, nrm])
			bodies.append(b)
	info.bodies = bodies
	return info

static func column(wf: Dictionary, info: Dictionary, X: float, Y: float) -> Dictionary:
	var bs := PackedFloat64Array(); bs.resize(info.lay.size())
	for k in bs.size():
		bs[k] = boundary_m(wf, info.slot, k, X, Y)
	var col := {"h": surface_m(wf, info.slot, X, Y), "bs": bs}
	var r = _rec(wf, info.slot)
	col.h0 = _field(wf, info.slot, -2, X, Y) if r != null and r.has("hm_pre") else col.h
	return col

static func _mountain_rock(info: Dictionary, X: float, Y: float, Z: float) -> int:
	var rel: float = (Z / U - float(info.p.surf_ref)) / 21.0 + 0.06 * info.mnoise.get_noise_3d(X, Y, Z)
	var last := -1
	for e in info.mtn:
		last = int(e.id)
		if rel >= e.rel[0] and rel < e.rel[1]:
			return int(e.id)
	return last if last >= 0 else Mat.DIRT

static func material(info: Dictionary, col: Dictionary, X: float, Y: float, Z: float) -> int:
	var h: float = col.h
	if Z >= h:
		return Mat.AIR
	var p: Dictionary = info.p
	var kind: String = info.kind; var prof: String = info.prof
	var d := h - Z
	# E47 eroze po vrstvách: h0 = povrch před erozí. Nános (Z ≥ h0) = štěrk/písek pod drnem; v korytě se půda a kůže hor
	# měří od PŮVODNÍHO povrchu, takže eroze půdu prořízne a odkryje horninu. Bez eroze h0 = h → beze změny.
	var h0: float = col.get("h0", h)
	var ds := h0 - Z if h0 > h else d
	var dep := Z >= h0
	var snow := (kind == "hora" or kind == "sopka") and h >= (float(p.snowline) + 1.0) * U
	var grass := (not snow) and h < (float(p.treeline) + 1.0) * U
	var soil := 0.0
	if grass:
		soil = (float(p.soil) if kind == "nizina" else (1.0 if h < (float(p.treeline) - 3.0) * U else 0.0)) * U
	var skin := 0.0 if (kind == "nizina" or h <= (float(p.surf_ref) + 2.0) * U or prof == "hora_v") else float(info.tk) * U
	var m := -1
	if snow and d < 2.0 * U:
		m = Mat.SNOW
	elif dep:
		m = Mat.GRASS if grass and d < U else int(info.dep)
	elif grass and ds < U:
		m = Mat.GRASS
	elif grass and ds < U + soil:
		m = Mat.DIRT
	elif prof != "hora_v" and ds < (2.0 * U if snow else (U if grass else 0.0)) + soil + skin:
		m = _mountain_rock(info, X, Y, Z)
	else:
		var bs: PackedFloat64Array = col.bs
		for k in bs.size():
			if Z < bs[k]:
				m = info.lay[k]; break
		if m < 0:
			m = Mat.DIRT if kind == "nizina" else (info.core_id if prof == "hora_v" else _mountain_rock(info, X, Y, Z))
	m = _bodies(info, col, X, Y, Z, m)
	if not info.vent.is_empty():
		var lx: float = X - info.slot.x * BW - BW * 0.5; var ly: float = Y - info.slot.y * BW - BW * 0.5
		var vb: Dictionary = info.vent.body
		if Vector2(lx, ly).length() < lerpf(float(vb.r), float(vb.r_top), Z / h) * U:
			m = int(info.vent.id)
	return m

static func _bodies(info: Dictionary, col: Dictionary, X: float, Y: float, Z: float, m: int) -> int:
	var zo: PackedByteArray = info.zone_of
	for b in info.bodies:
		var e: Dictionary = b.e
		match b.kind:
			"pipe":
				if m in [Mat.AIR, Mat.GRASS, Mat.DIRT, Mat.SNOW]: continue
				if Z < minf(b.zt, col.h - U) and Vector2(X, Y).distance_to(b.c) < lerpf(float(e.body.r0), float(e.body.r1), Z / b.zt) * U:
					m = int(e.id)
			"dome":
				var zt: float = float(e.body.top) * U
				if Z < b.zb - 2.0 * U or Z >= minf(zt, col.h - 2.0 * U): continue
				var t: float = (Z - b.zb) / maxf(zt - b.zb, U)
				var r: float = float(e.body.r_stem) if t < 0.65 else lerpf(float(e.body.r_stem), float(e.body.r_cap), sqrt((t - 0.65) / 0.35)) * (1.0 - 0.3 * pow(maxf(t - 0.9, 0.0) / 0.1, 2))
				if Vector2(X, Y).distance_to(b.c) < r * U and (zo[m] == 2 or zo[m] == 1 and t < 0.1):
					m = int(e.id)
			"vein":
				if zo[m] != 1: continue
				for pl in b.planes:
					var q: Vector3 = Vector3(X, Y, Z) - pl[0]
					if absf(q.dot(pl[1])) < float(e.body.half) * U and q.length() < float(e.body.extent) * U:
						m = int(e.id); break
			"contact":
				# skarn: karbonát do svislé vzdálenosti width od granitoidní vrstvy ve stejném sloupci (spojitá náhrada BFS)
				if not b["in"].has(m): continue
				var bs: PackedFloat64Array = col.bs
				var lo := 0.0
				for k in bs.size():
					if b.around.has(info.lay[k]) and bs[k] - lo > 1e-6:
						var dz: float = maxf(lo - Z, Z - bs[k])
						if dz < float(e.body.width) * U:
							m = int(e.id); break
					lo = maxf(lo, bs[k])
	return m

## buňky n × n × 4n, sloupce x ∈ [x0, x1); vzorek = střed buňky
static func sample(wf: Dictionary, info: Dictionary, n: int, x0: int, x1: int, cells: PackedByteArray) -> void:
	var c := BW / n; var nz := 4 * n
	var ox: float = info.slot.x * BW; var oy: float = info.slot.y * BW
	for x in range(x0, x1):
		for y in n:
			var X: float = ox + (x + 0.5) * c; var Y: float = oy + (y + 0.5) * c
			var col := column(wf, info, X, Y)
			var base := (x * n + y) * nz
			for z in nz:
				cells[base + z] = material(info, col, X, Y, (z + 0.5) * c)
			if bool(info.p.get("p81_tenke", false)): keep_thin(info, col, X, Y, c, nz, base, cells)

## E81 (p81_tenke): konzervativní vzorkování tenkých vrstev. Vrstva, která je ve sloupci podle funkce (mocnost >
## p81_min_m), ale nepadl na ni žádný střed buňky, dostane jednu buňku: tu, ve které leží bod vrstvy, kde funkce opravdu
## dává tuto vrstvu (ne kryt půdy, ne těleso; zkouší se 9 bodů uvnitř vrstvy zdola). Když je buňka obsazená jinou tenkou vrstvou
## nebo by tím zmizela jiná vrstva (její jediná buňka ve sloupci), zkusí se soused nad/pod podle polohy (pořadí vrstev
## se zachová). Nejtenčí vrstvy mají přednost. Vrstva tenčí než p81_min_m se naopak do buněk nedá vůbec (buňka dostane
## vrstvu nad ní). Konec vyklínění pak určuje funkce (t = p81_min_m), ne rozlišení.
## Počty v info._k81 (pridano, posun = o buňku vedle, konflikt = nevešla se, kryt = funkce ji nikde nedává).
static func keep_thin(info: Dictionary, col: Dictionary, X: float, Y: float, c: float, nz: int, base: int, cells: PackedByteArray) -> void:
	var tmin := float(info.p.get("p81_min_m", 0.05))
	var bs: PackedFloat64Array = col.bs
	var top := float(col.h)
	var have := {}
	for zz in nz: have[cells[base + zz]] = true
	var lo := 0.0
	var cand := []
	for k in bs.size():   # kandidát = vrstva s mocností > tmin, která ve sloupci buněk vůbec není
		var hi: float = minf(bs[k], top)
		if hi - lo > tmin and not have.has(int(info.lay[k])): cand.append([hi - lo, lo, hi, int(info.lay[k])])
		elif hi - lo > 0.0 and hi - lo <= tmin:   # pod prahem: vrstva se v buňkách neobjeví (ani když na ni padne střed)
			var m0 := int(info.lay[k])
			for z in range(maxi(floori(lo / c - 0.5), 0), mini(ceili(hi / c), nz)):
				var zc := (z + 0.5) * c
				if zc < lo or zc >= hi or cells[base + z] != m0: continue
				var rep := material(info, col, X, Y, hi + 1e-4) if hi + 1e-4 < top else material(info, col, X, Y, maxf(lo - 1e-4, 0.0))
				if rep == m0 or rep == 0: continue
				cells[base + z] = rep
				if not info.has("_k81"): info._k81 = {"pridano": 0, "posun": 0, "konflikt": 0, "kryt": 0, "odebrano": 0}
				info._k81.odebrano += 1
		lo = maxf(lo, hi)
	if cand.is_empty(): return
	cand.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	if not info.has("_k81"): info._k81 = {"pridano": 0, "posun": 0, "konflikt": 0, "kryt": 0, "odebrano": 0}
	var taken := {}   # buňka → střed vrstvy, která ji dostala
	for e in cand:
		var m := int(e[3])
		var Z := -1.0
		for q in 9:   # zdola nahoru: u vrstvy těsně pod půdou je vidět jen spodek
			var zq: float = lerpf(float(e[1]), float(e[2]), (q + 0.5) / 9.0)
			if material(info, col, X, Y, zq) == m: Z = zq; break
		if Z < 0.0: info._k81.kryt += 1; continue
		if have.has(m): continue
		var z0 := floori(Z / c)
		var ref: float = taken.get(z0, (z0 + 0.5) * c)
		var d := -1 if Z < ref else 1
		var ok := false
		for z in [z0, z0 + d, z0 - d]:
			if z < 0 or z >= nz or taken.has(z): continue
			var old := cells[base + z]
			if old == 0 or old == m: continue
			var only := true
			for zz in nz:
				if zz != z and cells[base + zz] == old: only = false; break
			if only: continue
			cells[base + z] = m; taken[z] = Z; have[m] = true; ok = true
			info._k81.pridano += 1
			if z != z0: info._k81.posun += 1
			break
		if not ok: info._k81.konflikt += 1

static func sample_all(wf: Dictionary, info: Dictionary, n: int) -> PackedByteArray:
	var cells := PackedByteArray(); cells.resize(n * n * 4 * n)
	sample(wf, info, n, 0, n, cells)
	return cells

## Minerály ve spojitém prostoru (Jan 16:42). Počet v blueprintu = objem v základních buňkách (0,125 m³).
## Při buňce c = 8/n m je cíl N · (n/16)³ buněk (objem zůstává). Ložisko = shluky kolem středů v METRECH (seed,
## jen v hostiteli podle funkce materiálu), potenciál φ = max(1 − |P − C| / R) + 0,15 · šum(P); vybere se přesně cíl
## hostitelských buněk s nejvyšším φ (shoda φ → index). Hostitel nestačí → schodek se nahlásí, jinam nic.
static func minerals(cells: PackedByteArray, n: int, wf: Dictionary, info: Dictionary, minerals: Dictionary, seed: int) -> Array:
	var reps := []
	var ks := minerals.keys(); ks.sort()
	for mat in ks:
		if not is_cavity(int(mat)):
			reps.append(mineral_one(cells, n, wf, info, int(mat), int(minerals[mat]), seed))
	# Jan 17:38: nejvýš jedna dutina; VODA i VZDUCH zároveň = neplatný blueprint → žádná dutina
	if int(minerals.get(CAV_WATER, 0)) > 0 and int(minerals.get(CAV_AIR, 0)) > 0:
		return reps
	for mat in ks:
		if is_cavity(int(mat)) and int(minerals[mat]) > 0:
			reps.append(cavity_one(cells, n, wf, info, int(mat), int(minerals[mat]), seed))
	return reps

static func mineral_one(cells: PackedByteArray, n: int, wf: Dictionary, info: Dictionary, mat: int, count: int, seed: int) -> Dictionary:
	var spec: Dictionary = HT.table()[mat]
	var hosts := {}
	for hh in spec.host: hosts[int(hh)] = true
	var f := float(n) / 16.0
	var target := int(round(count * f * f * f))
	var rng := Ore.Rng.new(H.mix(seed, "BP_MINF", mat))
	var heap := maxi(int(spec.supply[1]), 1)
	var nb := clampi(ceili(float(count) / heap), 1, 6)
	var R := pow(3.0 * float(count) / nb * U * U * U / (4.0 * PI), 1.0 / 3.0) * 1.3 + U
	var centres := []
	var ox: float = info.slot.x * BW; var oy: float = info.slot.y * BW
	for b in nb:
		for tries in 300:
			var P := Vector3(ox + rng.u16() / 65535.0 * BW, oy + rng.u16() / 65535.0 * BW, rng.u16() / 65535.0 * BHT)
			var col := column(wf, info, P.x, P.y)
			if hosts.has(material(info, col, P.x, P.y, P.z)):
				centres.append(P); break
	var nz := BG.noise(seed, "BP_MINF_N", mat, 0.6, 2)
	var c := BW / n; var NZ := 4 * n
	var cand := []
	for i in cells.size():
		if not hosts.has(cells[i]): continue
		var x := i / (n * NZ); var y := (i / NZ) % n; var z := i % NZ
		var P := Vector3(ox + (x + 0.5) * c, oy + (y + 0.5) * c, (z + 0.5) * c)
		var phi: float = -1.0
		for C in centres:
			phi = maxf(phi, 1.0 - P.distance_to(C) / R)
		cand.append([phi + 0.15 * nz.get_noise_3dv(P), i])
	var host_cells := cand.size()
	cand.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var placed := mini(target, cand.size())
	for t in placed:
		cells[cand[t][1]] = mat
	return {"mat": mat, "name": HT.name_of(mat), "hosts": HT.hosts_text(mat), "host_cells": host_cells,
		"target": target, "placed": placed, "shortfall": target - placed, "count_base": count, "blobs": centres.size()}


## ---------- dutiny (Jan 16:56): VODA a VZDUCH v seznamu materiálů blueprintu, počty jako minerály (objem, × (n/16)³)
## voda (klíč 250) = rezervoár: dutina uvnitř souvislé NEPROPUSTNÉ horniny (perm = 0 ve sdílené tabulce vody), každá
##   buňka dutiny má do vzdálenosti stěny (0,5 m) ve všech 6 směrech jen nepropustného hostitele → dno, stěny i strop drží
##   vodu; dutina se zaplní vodou (gen-v3 FULL), takže je stabilní (validátor: voda v uzavřené pánvi).
## vzduch (klíč 0) = jeskyně: dutina v pevné hornině (ne půda, písek, štěrk, spraš, jíl), nad každou buňkou je do výšky
##   stropu (1 m) nosná hornina a do povrchu aspoň 2 m. Bez vody (prosáknout může jen vsakování gen-v3).
## Střed dutiny se hledá ve SPOJITÉM prostoru (podmínky se ověřují funkcí materiálu), výběr buněk podle φ jako minerály.
const CAV_AIR := 0
const CAV_WATER := 250
const SOFT := ["topsoil", "gravel_sand", "loess", "weathered_clay", "conglomerate", "siltstone", "hill_sand", "weathered_volcanic", "subalpine_scree"]

static func is_cavity(m: int) -> bool:
	return m == CAV_AIR or m == CAV_WATER

static func cavity_name(m: int) -> String:
	return "voda (podzemní rezervoár)" if m == CAV_WATER else "vzduch (jeskyně)"

static var _perm := {}
static func impermeable() -> Dictionary:
	if _perm.is_empty():
		const VP = preload("res://scripts/teren/zaklad/voda_params.gd")
		var d: Dictionary = VP.load_shared_table()
		var mins := HT.table()
		for k in d.materials:
			var e: Dictionary = d.materials[k]
			var id := int(e.id)
			if float(e.perm) <= 0.0 and id != Mat.SNOW and not mins.has(id) and id < CAV_WATER:
				_perm[id] = true
	return _perm

static func _bearing(m: int) -> bool:
	if m in [Mat.AIR, Mat.GRASS, Mat.DIRT, Mat.SNOW, Mat.SAND, Mat.CLAY] or HT.table().has(m):
		return false
	for k in SOFT:
		if HR.id_of(k) == m: return false
	return true

static var KARST := []
static func _ok_point(wf: Dictionary, info: Dictionary, kind: int, P: Vector3, karst := false) -> bool:
	if KARST.is_empty():
		for k in ["deep_limestone", "dolomite", "cave_limestone", "limestone_outcrop"]: KARST.append(HR.id_of(k))
	var col := column(wf, info, P.x, P.y)
	if P.z > col.h - 2.0 or P.z < 2.0: return false   # ≥ 2 m pod povrchem i nad dnem bloku
	if kind == CAV_WATER:
		var imp := impermeable()
		for o in [Vector3.ZERO, Vector3(U, 0, 0), Vector3(-U, 0, 0), Vector3(0, U, 0), Vector3(0, -U, 0), Vector3(0, 0, U), Vector3(0, 0, -U)]:
			var Q: Vector3 = P + o
			if not imp.has(material(info, column(wf, info, Q.x, Q.y), Q.x, Q.y, Q.z)): return false
		return true
	for dz in [0.0, 0.25, 0.5, 0.75, 1.0]:
		if not _bearing(material(info, col, P.x, P.y, P.z + dz)): return false
	if karst:   # jeskyně přednostně v karbonátech (krasové jeskyně), jinak v jakékoli nosné hornině
		return material(info, col, P.x, P.y, P.z) in KARST
	return true

static func cavity_one(cells: PackedByteArray, n: int, wf: Dictionary, info: Dictionary, kind: int, count: int, seed: int) -> Dictionary:
	var f := float(n) / 16.0
	var target := int(round(count * f * f * f))
	var c := BW / n; var NZ := 4 * n
	var wall := maxi(int(round(U / c)), 1); var roof := maxi(int(round(1.0 / c)), 1); var depth := 2.0
	var imp := impermeable()
	var ox: float = info.slot.x * BW; var oy: float = info.slot.y * BW
	# kandidáti na mřížce: podmínka hostitele s tloušťkou stěny / stropu v METRECH (počet buněk podle c)
	var cand := []
	var hm := PackedFloat64Array(); hm.resize(n * n)
	for x in n:
		for y in n:
			var top := 0
			for z in NZ:
				if cells[(x * n + y) * NZ + z] != Mat.AIR: top = z + 1
			hm[x * n + y] = top * c
	# masky hostitele (rychle, bez volání funkcí na buňku)
	var hostm := PackedByteArray(); hostm.resize(cells.size())
	var bear := {}
	for i in cells.size():
		var m := cells[i]
		if kind == CAV_WATER:
			hostm[i] = 1 if imp.has(m) else 0
		else:
			if not bear.has(m): bear[m] = _bearing(m)
			hostm[i] = 1 if bear[m] else 0
	var ok := PackedByteArray(); ok.resize(cells.size())
	var sx := n * NZ
	for x in n:
		for y in n:
			var lim := hm[x * n + y] - depth
			for z in range(int(ceil(2.0 / c)), NZ):
				if (z + 0.5) * c > lim: break
				var i := (x * n + y) * NZ + z
				if hostm[i] == 0: continue
				var good := true
				if kind == CAV_WATER:
					for k in range(1, wall + 1):
						if x - k < 0 or x + k >= n or y - k < 0 or y + k >= n or z - k < 0 or z + k >= NZ: good = false; break
						if hostm[i - k * sx] == 0 or hostm[i + k * sx] == 0 or hostm[i - k * NZ] == 0 or hostm[i + k * NZ] == 0 or hostm[i - k] == 0 or hostm[i + k] == 0:
							good = false; break
				else:
					for k in range(1, roof + 1):
						if z + k >= NZ or hostm[i + k] == 0: good = false; break
				if good: ok[i] = 1
	var rng := Ore.Rng.new(H.mix(seed, "BP_CAV", kind))
	var centre = null
	for tries in 1200:
		var P := Vector3(ox + 0.5 + rng.u16() / 65535.0 * (BW - 1.0), oy + 0.5 + rng.u16() / 65535.0 * (BW - 1.0), 0.5 + rng.u16() / 65535.0 * (BHT - 1.0))
		if _ok_point(wf, info, kind, P, kind == CAV_AIR and tries < 900):
			centre = P; break
	var nz := BG.noise(seed, "BP_CAV_N", kind, 0.8, 2)
	var R := pow(3.0 * float(count) * U * U * U / (4.0 * PI), 1.0 / 3.0) * 1.2 + U
	var list := []
	for i in cells.size():
		if ok[i] == 0: continue
		var x := i / (n * NZ); var y := (i / NZ) % n; var z := i % NZ
		var P := Vector3(ox + (x + 0.5) * c, oy + (y + 0.5) * c, (z + 0.5) * c)
		var phi: float = -10.0 if centre == null else 1.0 - P.distance_to(centre) / R
		# jeskyně spíš plochá (strop vodorovný), rezervoár čočka: svislá vzdálenost váží víc
		if centre != null: phi = 1.0 - Vector3(P.x - centre.x, P.y - centre.y, (P.z - centre.z) * 1.8).length() / R
		list.append([phi + 0.1 * nz.get_noise_3dv(P), i])
	list.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	# Jan 17:38: právě JEDNA souvislá dutina. Roste z buňky s nejvyšším φ, vždy přidá souseda (6-sousedství) s nejvyšším φ
	# z hranice, jen přes kandidáty. Když souvislá oblast nestačí, zbytek je schodek.
	var out := PackedInt32Array()
	if centre != null and not list.is_empty() and target > 0:
		var phi := {}
		for e in list: phi[e[1]] = e[0]
		var taken := {}
		var front := {list[0][1]: true}
		while out.size() < target and not front.is_empty():
			var best := -1; var bp := -1e18
			for fc in front:
				var v: float = phi[fc]
				if v > bp or (v == bp and fc < best): bp = v; best = fc
			front.erase(best); taken[best] = true; out.append(best)
			var x := best / (n * NZ); var y := (best / NZ) % n; var z := best % NZ
			for d in 6:
				var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz2: int = z + Ore.DZ[d]
				if nx < 0 or ny < 0 or nz2 < 0 or nx >= n or ny >= n or nz2 >= NZ: continue
				var j := (nx * n + ny) * NZ + nz2
				if phi.has(j) and not taken.has(j): front[j] = true
		for ci in out: cells[ci] = Mat.AIR
	var kept := out.size()
	return {"mat": kind, "name": cavity_name(kind), "hosts": "nepropustná hornina, stěna 0,5 m" if kind == CAV_WATER else "nosná hornina, strop 1 m",
		"host_cells": list.size(), "target": target, "placed": kept, "shortfall": target - kept, "cells": out,
		"centre": centre, "reason": "" if kept == target else "hostitel chybí nebo nestačí"}

## ---------- pevnost (Jan 16:58, 17:01): v tabulkách jsou jen DATA load (kolik buněk 0,5 m unese nad sebou) a cantilever
## (kolik buněk převisne bez podpory). Výpočet zřícení se zatím NEDĚLÁ (Jan 17:01), dutiny se podle pevnosti nemění.
