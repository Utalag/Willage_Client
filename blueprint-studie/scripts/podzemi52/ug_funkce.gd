extends RefCounted
## E52 varianta 4 (Jan 21:14–21:31): podzemní voda jako FUNKCE nad vrstvami, ne nad buňkami.
## Hranice vrstev jsou 2D matice na řídicí mřížce 0,5 m (hm_f, bs[k]). Každý sloupec řídicí mřížky = zásobník pásem
## [spodek, vršek) v metrech s materiálem (stejná pravidla jako geo_fn.material: sníh, drn, půda, kůže hor, vrstvy,
## výplň pod poslední hranicí). Propustná pásma (perm ≥ ponor_perm nebo kras) = těleso. Souvislost: pásma ve stejném
## sloupci, která se dotýkají, a pásma 4 sousedních sloupců s překryvem v z. Dutiny a čočky jsou buňkový zvláštní
## případ: přidají se jako další pásma (objem z buněk). Výsledná hladina = 2D funkce wt na řídicí mřížce (m).
## Režim nadrz: celé těleso jedna nádrž (stejně jako voda/podzemi.gd) → shoda se základem. Režim preliv: voda od vstupu
## steče na nejnižší dosažitelné místo, hladina stoupá (minimax po pásmech), dokud nedosáhne výstupu; zaplavená je jen
## pánev (a pánve, do kterých přeteče), průsak jen ze zaplavené části.
## Rozhraní pro tok.gd: entry(ctx, sloupec povrchu) → id pásma, solve(...) jako podzemi.gd, touched(...).

const VS = preload("res://scripts/voda/voda_svet.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const FN = preload("res://scripts/bp/geo_fn.gd")
const Mat = preload("res://scripts/kopie/mat.gd")
const SELF = preload("res://scripts/podzemi52/ug_funkce.gd")
const CH = preload("res://scripts/voda/cas_hry.gd")   # E77: čas hry na jednom místě
const E := 1e-6

class Members:
	var ctx: Dictionary
	var id: int
	func has(b: int) -> bool:
		return b >= 0 and b < ctx.comp.size() and ctx.comp[b] == id

## pásma jednoho sloupce podle geo_fn.material (bez těles: pně, kupole, žíly, sopouch) → [[lo, hi, mat], ...] zdola
static func bands(info: Dictionary, col: Dictionary, X: float, Y: float) -> Array:
	var U := FN.U
	var h: float = col.h
	var p: Dictionary = info.p
	var kind: String = info.kind; var prof: String = info.prof
	var snow := (kind == "hora" or kind == "sopka") and h >= (float(p.snowline) + 1.0) * U
	var grass := (not snow) and h < (float(p.treeline) + 1.0) * U
	var soil := 0.0
	if grass: soil = (float(p.soil) if kind == "nizina" else (1.0 if h < (float(p.treeline) - 3.0) * U else 0.0)) * U
	var skin := 0.0 if (kind == "nizina" or h <= (float(p.surf_ref) + 2.0) * U or prof == "hora_v") else float(info.tk) * U
	var top := []   # shora dolů [tloušťka, mat]
	var base := 0.0
	if snow: top.append([2.0 * U, Mat.SNOW]); base = 2.0 * U
	elif grass:
		top.append([U, Mat.GRASS]); base = U
		if soil > 0.0: top.append([soil, Mat.DIRT])
	var cover := base + soil
	if prof != "hora_v":
		var sk := skin
		if sk > 0.0:
			top.append([sk, FN._mountain_rock(info, X, Y, maxf(h - cover - sk * 0.5, 0.0))])
			cover += sk
	var ztop := maxf(h - cover, 0.0)
	var out := []
	var lo := 0.0
	var bs: PackedFloat64Array = col.bs
	for k in bs.size():
		var hi := minf(bs[k], ztop)
		if hi > lo + E: out.append([lo, hi, int(info.lay[k])])
		lo = maxf(lo, minf(bs[k], ztop))
	if lo < ztop - E:
		var m: int = Mat.DIRT if kind == "nizina" else (int(info.core_id) if prof == "hora_v" else FN._mountain_rock(info, X, Y, (lo + ztop) * 0.5))
		out.append([lo, ztop, m])
	var d0 := 0.0
	for e in top:
		var t: float = e[0]
		out.append([maxf(h - d0 - t, 0.0), maxf(h - d0, 0.0), int(e[1])])
		d0 += t
	return out.filter(func(b): return b[1] > b[0] + E)

## E76: výřez přenesený z jiného světa (t76 = {puvod: slot světa původu, dz: posun v buňkách}): pásma se vyhodnotí v souřadnicích
## původu (šum hornin podle místa původu, výška − dz), pak se posunou o dz; pod původním dnem pokračuje spodní pásmo.
## Pole vrstev (povrch, hranice) jsou už posunutá v záznamu a na švu se interpolují s novými sousedy.
static func bands76(info: Dictionary, col: Dictionary, X: float, Y: float, s: Vector2i, t76: Dictionary) -> Array:
	var o: Vector2i = t76.puvod
	var dzm := float(t76.dz) * FN.U
	var bs: PackedFloat64Array = col.bs.duplicate()
	for k in bs.size(): bs[k] -= dzm
	var c2 := {"h": float(col.h) - dzm, "bs": bs}
	var out := []
	for b in bands(info, c2, X + (o.x - s.x) * FN.BW, Y + (o.y - s.y) * FN.BW):
		var lo: float = maxf(float(b[0]) + dzm, 0.0); var hi: float = float(b[1]) + dzm
		if hi > lo + E: out.append([lo, hi, b[2]])
	if not out.is_empty() and float(out[0][0]) > E: out[0][0] = 0.0
	return out

## prázdný kontext; sloupce se plní add_col, pak finish
static func _new(W: int, H: int, side: float, p: Dictionary) -> Dictionary:
	var c := {"W": W, "H": H, "side": side, "A": side * side, "perm_min": float(p.ponor_perm), "depth_m": float(p.get("ug_hloubka_m", 6.0)),
		"q_to_m3": float(p.get("ug_q_to_m3", 0.001)), "leak_m2": float(p.get("ug_leak_m2", 0.002)), "rezim": String(p.get("p52_rezim", "nadrz")), "perm_dno": float(p.get("p55_perm_dno", 0.05)),
		"okraj67": bool(p.get("p67_okraj", false)), "kras67": bool(p.get("p67_kras", true)), "rezim67": String(p.get("p67_rezim", "")),
		"film67": float(p.get("p67_film_m", 0.5)), "prune67": bool(p.get("p67_prune", true)), "prune67_min": float(p.get("p67_prune_min", 0.1)), "slu72": bool(p.get("p72_slucovat", true)), "prus73": bool(p.get("p73_prusak_tok", false)), "slu72p": bool(p.get("p72_prusak", true)), "dosah72": float(p.get("p72_dosah_m", 0.0)), "remizy69": bool(p.get("p69_remizy", true)), "prumer70": String(p.get("p70_prumer", "pomer")), "kap71": bool(p.get("p71_kapacita", true)), "prus71": bool(p.get("p71_prusak", true)), "cas71": CH.faktor(p),
		"cols": [], "h": PackedFloat64Array(), "wall": PackedByteArray(), "impl": SELF, "gen": 0, "NZ": 1,
		"stats": {"solve_ms": 0.0, "solves": 0, "cells": 0, "build_ms": 0.0}}
	c.h.resize(W * H); c.wall.resize(W * H); c.wall.fill(1)
	c.cols.resize(W * H)
	for i in W * H: c.cols[i] = []
	return c

static func _finish(c: Dictionary) -> void:
	var W: int = c.W; var H: int = c.H
	var cs := PackedInt32Array(); cs.resize(W * H + 1)
	var lo := PackedFloat64Array(); var hi := PackedFloat64Array(); var mat := PackedInt32Array(); var por := PackedFloat64Array()
	var body := PackedByteArray(); var wq := PackedFloat64Array(); var bcol := PackedInt32Array()
	var t := VS.table()
	var pmin: float = c.perm_min; var lm2: float = c.leak_m2
	for i in W * H:
		cs[i] = lo.size()
		for b in c.cols[i]:
			var m: int = b[2]
			var e: Array = t.get(m, [0.0, 0.0])
			var pm := float(e[0])
			lo.append(b[0]); hi.append(b[1]); mat.append(m); bcol.append(i)
			var cav: bool = m == 0 or (b.size() > 3)
			var isb: bool = cav or (UG._soluble(m) and bool(c.get("kras67", true))) or pm >= pmin   # E67 p67_kras=false: kras jen s perm ≥ ponor_perm
			body.append(1 if isb else 0)
			var pr := float(e[1]) if e.size() > 1 else 0.0
			por.append(float(b[3]) if b.size() > 3 else (1.0 if m == 0 else (pr if pr > 0.0 else 0.05)))
			wq.append(pm * lm2 if (not isb and pm > 0.0 and pm < pmin) else 0.0)
	cs[W * H] = lo.size()
	c.cs = cs; c.lo = lo; c.hi = hi; c.mat = mat; c.por = por; c.body = body; c.wq = wq; c.bcol = bcol
	var lab := PackedInt32Array(); lab.resize(lo.size()); c.lab = lab
	var dist := PackedInt32Array(); dist.resize(lo.size()); c.dist = dist
	# sousedé (CSR): kandidáti při sestavení, platnost (překryv) se ověřuje při průchodu → výkop se projeví bez přestavby
	var ns := PackedInt32Array(); ns.resize(lo.size() + 1); var nb := PackedInt32Array()
	for b in lo.size():
		ns[b] = nb.size()
		if body[b] == 0: continue
		var cc := bcol[b]; var x := cc / H; var y := cc % H
		for b2 in range(cs[cc], cs[cc + 1]):
			if b2 != b and body[b2] == 1 and minf(hi[b], hi[b2]) >= maxf(lo[b], lo[b2]) - E: nb.append(b2)
		for d in 4:
			var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var c2 := qx * H + qy
			if c.wall[c2] == 1: continue
			for b2 in range(cs[c2], cs[c2 + 1]):
				if body[b2] == 1 and minf(hi[b], hi[b2]) > maxf(lo[b], lo[b2]) + E: nb.append(b2)
	ns[lo.size()] = nb.size()
	c.ns = ns; c.nb = nb
	# souvislá tělesa (štítek pro seskupení tůní nad stejným tělesem)
	var comp := PackedInt32Array(); comp.resize(lo.size())
	var nc := 0
	for b in lo.size():
		if body[b] == 0 or comp[b] != 0: continue
		nc += 1; comp[b] = nc
		var qu := PackedInt32Array([b]); var k := 0
		while k < qu.size():
			var u := qu[k]; k += 1
			for j in range(ns[u], ns[u + 1]):
				var v := nb[j]
				if comp[v] == 0: comp[v] = nc; qu.append(v)
	c.comp = comp; c.n_comp = nc
	var wt := PackedFloat32Array(); wt.resize(W * H); wt.fill(-1.0); c.wt = wt
	c.erase("cols")
	var lf := PackedFloat64Array(); lf.resize(lo.size())
	for b in lo.size():
		if body[b] == 1: lf[b] = _leak(c, b, INF)
	c.leakf = lf

## mapa povrchové mřížky (Ws sloupců na stranu, r = Ws / W sloupců povrchu na sloupec řídicí mřížky)
static func set_surface(c: Dictionary, Ws: int, hs: PackedFloat64Array, wall_s: PackedByteArray, cm_s: float) -> void:
	c.Ws = Ws; c.r = Ws / int(c.W); c.hs = hs; c.wall_s = wall_s; c.cm_s = cm_s

## svět: záznamy bloků (hm_f, bs) + dutiny z buněk (fine: slot → {cells, hm}, n buněk na blok, vzorek po nu)
## E79: cache (volitelná) = funkční pásma sloupců z prvního volání ({cols, wall, h}); další volání ze stejného světa
## (jen změna dutin po kopání) funkce nepočítá znovu
static func from_world(world, fine: Dictionary, n: int, nu: int, p: Dictionary, cache = null) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var T: int = world.w
	var W := T * 16
	var c := _new(W, W, FN.U, p)
	c.depth_m = float(p.ug_hloubka) * FN.U
	c.leak_m2 = float(p.ug_leak_q) / (FN.U * FN.U)
	if cache != null and cache.has("cols"):
		c.wall = cache.wall.duplicate(); c.h = cache.h.duplicate()
		for gi in W * W: c.cols[gi] = (cache.cols[gi] as Array).duplicate()
		_cavities(c, fine, n, nu, W)
		c.stats.build_ms = (Time.get_ticks_usec() - t0) / 1000.0
		return c
	var wf := FN.world_fn(world.slots)
	for s in world.order:
		var r: Dictionary = world.slots[s]
		var info := FN.block_info(wf, s, r.bp, p)
		for x in 16:
			for y in 16:
				var X: float = s.x * FN.BW + (x + 0.5) * FN.U; var Y: float = s.y * FN.BW + (y + 0.5) * FN.U
				var col := FN.column(wf, info, X, Y)
				var gi: int = (s.x * 16 + x) * W + s.y * 16 + y
				c.wall[gi] = 0; c.h[gi] = col.h
				c.cols[gi] = bands(info, col, X, Y) if not r.has("t76") else bands76(info, col, X, Y, s, r.t76)
	if cache != null:
		cache.wall = c.wall.duplicate(); cache.h = c.h.duplicate(); cache.cols = []
		for gi in W * W: cache.cols.append((c.cols[gi] as Array).duplicate())
	_cavities(c, fine, n, nu, W)
	c.stats.build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return c

## dutiny (zvláštní případ): buňky vzduchu pod povrchem → pásmo s objemem z buněk; pak _finish
static func _cavities(c: Dictionary, fine: Dictionary, n: int, nu: int, W: int) -> void:
	var ncav := 0
	if nu > 0 and not fine.is_empty():
		var k := n / nu; var NZ := 4 * n; var cm := FN.BW / nu
		var sub := nu / 16
		for s in fine:
			var b: Dictionary = fine[s]
			var cells: PackedByteArray = b.cells
			for x in 16:
				for y in 16:
					var cnt := 0; var zl := 1 << 30; var zh := -1
					for sx in sub:
						for sy in sub:
							var fx := ((x * sub + sx) * k + k / 2); var fy := ((y * sub + sy) * k + k / 2)
							var fi := fx * n + fy
							var hm: int = b.hm[fi]
							var base := fi * NZ
							var z0 := cells.find(0, base)
							while z0 >= 0 and z0 < base + hm:
								var z := (z0 - base)
								if z % k == k / 2 or k == 1:
									cnt += 1; zl = mini(zl, z / k); zh = maxi(zh, z / k)
								z0 = cells.find(0, z0 + 1)
					if cnt > 0:
						var gi: int = (s.x * 16 + x) * W + s.y * 16 + y
						var lo := zl * cm; var hi := (zh + 1) * cm
						c.cols[gi].append([lo, hi, 0, cnt * cm * cm * cm / (c.A * (hi - lo))])
						ncav += cnt
	_finish(c)
	c.stats.cav_cells = ncav

## z buněk (testy E47d, buňka = 1 m, objem 1): pásma = běhy stejného materiálu ve sloupci, vzduch pod top = dutina
static func from_cells(W: int, H: int, NZ: int, mat, top: PackedInt32Array, wall: PackedByteArray, p: Dictionary) -> Dictionary:
	var side := pow(float(p.get("ug_cell_m3", 1.0)), 1.0 / 3.0)
	var c := _new(W, H, side, p)
	c.depth_m = float(p.ug_hloubka) * side
	c.leak_m2 = float(p.ug_leak_q) / (side * side)
	c.q_to_m3 = float(p.get("ug_q_to_m3", 0.001))
	for gi in W * H:
		if wall[gi] == 1: continue
		c.wall[gi] = 0; c.h[gi] = top[gi] * side
		var lst := []
		var z := 0
		while z < top[gi]:
			var m: int = mat[gi * NZ + z]; var z1 := z
			while z1 < top[gi] and int(mat[gi * NZ + z1]) == m: z1 += 1
			lst.append([z * side, z1 * side, m])
			z = z1
		c.cols[gi] = lst
	_finish(c)
	set_surface(c, W, PackedFloat64Array(), wall, side)
	return c

static func _col_s(c: Dictionary, cc: int, border: bool) -> int:
	if not c.has("hs") or c.hs.is_empty(): return cc
	var r: int = c.r; var Ws: int = c.Ws; var W: int = c.W
	var ux := cc / W; var uy := cc % W
	var best := -1; var bh := INF
	for dx in r:
		for dy in r:
			var x := ux * r + dx; var y := uy * r + dy
			var s := x * Ws + y
			if c.wall_s[s] == 1: continue
			if border and not (x == 0 or y == 0 or x == Ws - 1 or y == Ws - 1): continue
			if c.hs[s] < bh: bh = c.hs[s]; best = s
	return best if best >= 0 else (ux * r + r / 2) * Ws + uy * r + r / 2

static func col_of(c: Dictionary, s: int) -> int:
	if not c.has("hs") or c.hs.is_empty(): return s
	var Ws: int = c.Ws; var r: int = c.r
	return (s / Ws / r) * int(c.W) + (s % Ws) / r

## pásmo tělesa ve sloupci, které obsahuje výšku z (m), jinak -1
static func band_at(c: Dictionary, cc: int, z: float) -> int:
	for b in range(c.cs[cc], c.cs[cc + 1]):
		if c.body[b] == 1 and c.lo[b] <= z + E and z < c.hi[b] - E: return b
	return -1

static func entry(c: Dictionary, s: int) -> int:
	var cc := col_of(c, s)
	if c.wall[cc] == 1: return -1
	var h: float = c.h[cc]; var best := -1
	for b in range(c.cs[cc], c.cs[cc + 1]):
		if c.body[b] == 1 and c.hi[b] > h - float(c.depth_m) + E and c.lo[b] < h - E and (best < 0 or c.hi[b] > c.hi[best]): best = b
	return best

## sousední pásma tělesa: [b2, olo (spodek překryvu = potřebná hladina), ohi]
static func _nbrs(c: Dictionary, b: int) -> Array:
	var out := []
	var lo: float = c.lo[b]; var hi: float = c.hi[b]; var cb: int = c.bcol[b]
	var nb: PackedInt32Array = c.nb
	for j in range(c.ns[b], c.ns[b + 1]):
		var b2 := nb[j]
		if c.body[b2] == 0: continue
		var olo := maxf(lo, c.lo[b2]); var ohi := minf(hi, c.hi[b2])
		if c.bcol[b2] == cb:
			if ohi >= olo - E: out.append([b2, olo, ohi])
		elif ohi > olo + E: out.append([b2, olo, ohi])
	return out

## výstupy pásma: [[z, typ, sloupec řídicí mřížky], ...]
static func _outs(c: Dictionary, b: int, excl: Dictionary) -> Array:
	var out := []
	var cc: int = c.bcol[b]; var W: int = c.W; var H: int = c.H
	var x := cc / H; var y := cc % H
	var lo: float = c.lo[b]; var hi: float = c.hi[b]
	if x == 0 or y == 0 or x == W - 1 or y == H - 1 or (bool(c.get("okraj67", false)) and wedge(c, cc)): out.append([lo, "okraj", cc])
	if hi >= float(c.h[cc]) - E and not excl.has(cc): out.append([hi, "povrch", cc])
	for d in 4:
		var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var c2 := qx * H + qy
		if c.wall[c2] == 1 or excl.has(c2): continue
		if float(c.h[c2]) < hi - E: out.append([maxf(lo, float(c.h[c2])), "povrch", c2])
	return out

## E67 O: sloupec sousedí se zdí (mimo ostrov) → odkrytá stěna, pásma z ní můžou vytéct (výstup „okraj“ ve výšce dna pásma)
static func wedge(c: Dictionary, cc: int) -> bool:
	var W: int = c.W; var H: int = c.H; var x := cc / H; var y := cc % H
	for d in 4:
		var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		if c.wall[qx * H + qy] == 1: return true
	return false

## průsak pásma do slabě propustného okolí (l/s), jen část pod hladinou L
static func _leak(c: Dictionary, b: int, L: float) -> float:
	var cc: int = c.bcol[b]; var W: int = c.W; var H: int = c.H
	var lo: float = c.lo[b]; var hi: float = minf(c.hi[b], L)
	if hi <= lo + E: return 0.0
	var s := 0.0
	for b2 in range(c.cs[cc], c.cs[cc + 1]):
		var w: float = c.wq[b2]
		if w <= 0.0: continue
		if absf(c.hi[b2] - lo) < E or (absf(c.lo[b2] - c.hi[b]) < E and c.hi[b] <= L + E): s += w * float(c.A)
	var x := cc / H; var y := cc % H
	for d in 4:
		var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var c2 := qx * H + qy
		if c.wall[c2] == 1: continue
		for b2 in range(c.cs[c2], c.cs[c2 + 1]):
			var w: float = c.wq[b2]
			if w <= 0.0: continue
			var ov := minf(hi, c.hi[b2]) - maxf(lo, c.lo[b2])
			if ov > E: s += w * ov * float(c.side)
	return s

static func _better(o: Array, z: float, d: int) -> bool:
	return o.is_empty() or z < float(o[0]) - E or (absf(z - float(o[0])) <= E and d < int(o[1]))

static func solve(c: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var ex := {}
	for s in excl: ex[col_of(c, s)] = true
	c.gen = int(c.gen) + 1
	var g: int = c.gen
	var r: Dictionary
	if String(c.get("rezim67", "")) == "pretok": r = load("res://scripts/podzemi52/ug67.gd").solve(c, entries, q, ex)   # E67 přetoky ve 3D
	elif String(c.rezim) == "auto": r = _solve_auto(c, entries, q, ex)
	else: r = _solve_preliv(c, entries, q, ex, g) if String(c.rezim) in ["preliv", "darcy"] else _solve_nadrz(c, entries, q, ex, g)
	if String(c.rezim) == "darcy" and q > 0.0 and not r.closed: r.darcy = darcy(c, r.comp_ids, float(r.z_out), entries, q - float(r.leak), ex)
	c.stats.solve_ms += (Time.get_ticks_usec() - t0) / 1000.0; c.stats.solves += 1; c.stats.cells += int(r.cells)
	return r

static func _result(c: Dictionary, comp: PackedInt32Array, L: float, best: Array, q: float, leak: float, entries: PackedInt32Array, closed: bool) -> Dictionary:
	var vol := 0.0; var lake := 0.0; var zmin := INF
	for b in comp: zmin = minf(zmin, c.lo[b])
	# objem po hladinách: rozdílové pole po 0,125 m (O(pásma + hladiny)), události po 0,5 m
	var dz := 0.125
	var nbin := maxi(int(ceil((L - zmin) / dz)) + 1, 1) if zmin < INF and L > -INF else 1
	var dif := PackedFloat64Array(); dif.resize(nbin + 2)
	for b in comp:
		var lo: float = c.lo[b]
		var top := minf(c.hi[b], L)
		var w := top - lo
		if w > E:
			var pa: float = float(c.por[b]) * float(c.A)
			vol += pa * w
			if int(c.mat[b]) == 0: lake += pa * w
			var cc: int = c.bcol[b]
			c.wt[cc] = maxf(c.wt[cc], top)
			var i0 := clampi(int((lo - zmin) / dz), 0, nbin); var i1 := clampi(int(ceil((top - zmin) / dz)), 0, nbin)
			var rate := pa * w / maxf((i1 - i0) * dz, E)   # rovnoměrně v pásmu (objem na m výšky)
			dif[i0] += rate; dif[i1] -= rate
	var net := q - leak
	var ev := []
	var run := 0.0; var cum := 0.0
	for i in nbin:
		run += dif[i]; cum += run * dz
		var z := zmin + (i + 1) * dz
		if (i + 1) % 4 == 0 or i == nbin - 1:
			var v := minf(cum, vol)
			ev.append({"z": minf(z, L), "objem_m3": v, "cas_s": (v / (net * float(c.q_to_m3))) if net > 0.0 else -1.0})
	if not ev.is_empty():
		ev[-1].objem_m3 = vol; ev[-1].cas_s = (vol / (net * float(c.q_to_m3))) if net > 0.0 else -1.0
	var out: Array = []
	if not best.is_empty():
		out = [best[0], best[1], best[2], best[3], _col_s(c, int(best[4]), String(best[3]) == "okraj")]
	var mem := Members.new(); mem.ctx = c; mem.id = c.comp[entries[0]] if not entries.is_empty() and entries[0] >= 0 else -1
	return {"cells": comp.size(), "q_in": q, "leak": minf(leak, q), "zmin": zmin, "z_out": L, "out": out, "events": ev, "volume_m3": vol,
		"never_fills": net <= 0.0, "out_q": maxf(net, 0.0) if not closed else 0.0, "closed": closed, "lake_m3": lake, "members": mem,
		"path": PackedInt32Array(), "lake": PackedInt32Array(), "comp_ids": comp}

## jedna nádrž (sémantika voda/podzemi.gd): BFS celého tělesa, hladina = nejnižší výstup, průsak ze všech pásem
static func _solve_nadrz(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary, g: int) -> Dictionary:
	var lab: PackedInt32Array = c.lab; var dist: PackedInt32Array = c.dist
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var body: PackedByteArray = c.body
	var bcol: PackedInt32Array = c.bcol; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb
	var hc: PackedFloat64Array = c.h; var wall: PackedByteArray = c.wall; var lf: PackedFloat64Array = c.leakf
	var W: int = c.W; var H: int = c.H
	var qu := PackedInt32Array()
	for e in entries:
		if e >= 0 and lab[e] != g: lab[e] = g; dist[e] = 0; qu.append(e)
	var k := 0; var best := []; var zmax := -INF; var leak := 0.0
	var bz := INF; var bd := 1 << 30
	var o67 := bool(c.get("okraj67", false))
	while k < qu.size():
		var b := qu[k]; k += 1
		var bl := lo[b]; var bh := hi[b]; var cc := bcol[b]; var db := dist[b]
		zmax = maxf(zmax, bh); leak += lf[b]
		var x := cc / H; var y := cc % H
		if (x == 0 or y == 0 or x == W - 1 or y == H - 1 or (o67 and wedge(c, cc))) and (bl < bz - E or (absf(bl - bz) <= E and db < bd)):
			bz = bl; bd = db; best = [bl, db, b, "okraj", cc]
		if bh >= hc[cc] - E and not ex.has(cc) and (bh < bz - E or (absf(bh - bz) <= E and db < bd)):
			bz = bh; bd = db; best = [bh, db, b, "povrch", cc]
		for d in 4:
			var qx := x; var qy := y
			match d:
				0: qx += 1
				1: qx -= 1
				2: qy += 1
				3: qy -= 1
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var c2 := qx * H + qy
			if wall[c2] == 1 or hc[c2] >= bh - E or ex.has(c2): continue
			var z := maxf(bl, hc[c2])
			if z < bz - E or (absf(z - bz) <= E and db < bd): bz = z; bd = db; best = [z, db, b, "povrch", c2]
		for j in range(ns[b], ns[b + 1]):
			var b2 := nb[j]
			if lab[b2] == g or body[b2] == 0: continue
			var olo := maxf(bl, lo[b2]); var ohi := minf(bh, hi[b2])
			if (bcol[b2] == cc and ohi >= olo - E) or ohi > olo + E:
				lab[b2] = g; dist[b2] = db + 1; qu.append(b2)
	var L: float = best[0] if not best.is_empty() else zmax
	var r := _result(c, qu, L, best, q, leak, entries, best.is_empty())
	r._best = best
	return r

## plnění a přelévání: sestup od vstupu (největší dosažitelná výška cap), pánev = nejnižší místo, pak hladina stoupá
## (minimax přes spodky překryvů) do prvního výstupu
static func _solve_preliv(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary, g: int) -> Dictionary:
	var lab: PackedInt32Array = c.lab
	var cap := {}
	var qu := []
	for e in entries:
		if e < 0: continue
		var cc: int = c.bcol[e]
		cap[e] = minf(c.hi[e], c.h[cc]); qu.append(e); lab[e] = g
	var k := 0
	while k < qu.size():
		var b: int = qu[k]; k += 1
		var cb: float = cap[b]
		for nb in _nbrs(c, b):
			var b2: int = nb[0]; var olo: float = nb[1]; var ohi: float = nb[2]
			var below: bool = c.bcol[b2] == c.bcol[b] and c.hi[b2] <= c.lo[b] + E
			if not below and cb <= olo + E: continue
			var nc := minf(cb, c.hi[b2]) if below else minf(cb, ohi)
			if not cap.has(b2) or nc > float(cap[b2]) + E:
				cap[b2] = nc; qu.append(b2); lab[b2] = g
	var pool := -1
	for b in cap:
		if pool < 0 or c.lo[b] < c.lo[pool] - E or (absf(c.lo[b] - c.lo[pool]) <= E and b < pool): pool = b
	if pool < 0: return _result(c, PackedInt32Array(), 0.0, [], q, 0.0, entries, true)
	var heap := []; var outs := []
	var done := {}
	var RK = load("res://scripts/svet8/reky.gd")
	RK._push(heap, c.lo[pool], pool)
	var comp := PackedInt32Array(); var best := []; var L := -INF; var n_pop := 0
	while not heap.is_empty():
		var it: Array = RK._pop(heap)
		var key: float = it[0]; var id: int = it[1]
		if id < 0:
			var o: Array = outs[-id - 1]
			best = [key, n_pop, o[3], o[1], o[2]]; L = key
			break
		if done.has(id): continue
		done[id] = true; comp.append(id); lab[id] = g; n_pop += 1
		L = maxf(L, c.hi[id])
		for o in _outs(c, id, ex):
			outs.append([o[0], o[1], o[2], id])
			RK._push(heap, maxf(key, float(o[0])), -outs.size())
		for nb in _nbrs(c, id):
			if not done.has(nb[0]): RK._push(heap, maxf(key, float(nb[1])), int(nb[0]))
	var closed := best.is_empty()
	var leak := 0.0
	for b in comp: leak += _leak(c, b, L)
	return _result(c, comp, L, best, q, leak, entries, closed)

## E55 (Jan 02:52): režim podle dna. Dno = pásma tělesa bez pásma tělesa přímo pod sebou; materiál přímo pod nimi
## (perm ≤ perm_dno → nepropustné, spodek ostrova → propustné). Vrací {a_prop, a_nep, cols_prop, cols_nep, mats}.
static func floor_of(c: Dictionary, comp: PackedInt32Array) -> Dictionary:
	var t := VS.table(); var A: float = c.A
	var ap := 0.0; var an := 0.0; var cp := PackedInt32Array(); var cn := PackedInt32Array(); var mats := {}
	var pd: float = c.perm_dno; var lm2: float = c.leak_m2; var sq := 0.0
	for b in comp:
		var cc: int = c.bcol[b]; var lo: float = c.lo[b]
		var under := -1
		for b2 in range(c.cs[cc], c.cs[cc + 1]):   # pásmo, které obsahuje z těsně pod spodkem (dutiny z buněk dělí pásma)
			if b2 != b and float(c.lo[b2]) < lo - 1e-4 and float(c.hi[b2]) >= lo - 1e-4 and (under < 0 or float(c.hi[b2]) > float(c.hi[under])): under = b2
		if under >= 0 and c.body[under] == 1 and c.comp[under] == c.comp[b]: continue   # pod ním je zase těleso
		var m := -1 if under < 0 else int(c.mat[under])
		var perm := 1.0 if m < 0 else float(t.get(m, [0.0])[0])
		if m == 0: perm = 1.0
		if perm <= pd: an += A; cn.append(cc)
		else: ap += A; cp.append(cc); sq += A * perm * lm2
		mats[m] = float(mats.get(m, 0.0)) + A
	return {"a_prop": ap, "a_nep": an, "cols_prop": cp, "cols_nep": cn, "mats": mats, "seep_q": sq}

static func _solve_auto(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary) -> Dictionary:
	c.gen = int(c.gen) + 1
	var rn := _solve_nadrz(c, entries, q, ex, int(c.gen))
	var fl := floor_of(c, rn.comp_ids)
	var at := float(fl.a_prop) + float(fl.a_nep)
	var f := float(fl.a_prop) / at if at > 0.0 else 1.0
	var r: Dictionary
	if f <= 1e-9:   # celé dno nepropustné → plnění pánve a přeliv nejnižším výchozem (pramen)
		c.gen = int(c.gen) + 1
		r = _solve_preliv(c, entries, q, ex, int(c.gen)); r.rezim_tel = "preliv"
	else:   # propustné / smíšené dno: průsak dolů = Σ plocha propustného dna · perm materiálu pod ním · leak_m2, zbytek nejnižším výstupem
		var lk := minf(float(fl.seep_q), q)
		r = _result(c, rn.comp_ids, float(rn.z_out), rn._best, q, lk, entries, rn._best.is_empty())
		r.rezim_tel = "nadrz" if f >= 1.0 - 1e-9 else "smes"
	r.erase("_best")
	r.dno = {"seep_q": fl.seep_q, "leak_nadrz": rn.leak, "a_prop_m2": fl.a_prop, "a_nep_m2": fl.a_nep, "f_prop": f, "cols_prop": fl.cols_prop, "cols_nep": fl.cols_nep, "mats": fl.mats}
	return r

static func touched(c: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool:
	var hit := false
	for k in ch.size():
		var cc := col_of(c, ch[k])
		var nh := hv[k] * float(c.get("cm_s", c.side))
		for b in range(c.cs[cc], c.cs[cc + 1]):
			if c.body[b] == 1 and c.lab[b] != 0 and c.hi[b] > float(c.h[cc]) - float(c.depth_m): hit = true
		if nh < float(c.h[cc]):   # výkop: celý sloupec řídicí mřížky (0,5 m) se sníží – jemnější výkop funkce neumí
			c.h[cc] = nh
			for b in range(c.cs[cc], c.cs[cc + 1]):
				c.hi[b] = minf(c.hi[b], nh)
				if c.hi[b] <= c.lo[b] + E: c.body[b] = 0
	return hit

## E52 varianta 5 (volitelná): Darcy ve 2D vrstvě nad zaplavenou oblastí (preliv). Neznámá = hladina h ve sloupcích
## řídicí mřížky, propustnost T = Σ K · nasycená mocnost (K = p52_darcy_k · perm, dutina perm 1), zdroj = přítok ve
## sloupcích vstupů, pevná hladina = výstupy oblasti do výšky L + p52_darcy_dz. Gauss–Seidel se SOR. Výsledek: rozdělení
## výtoku mezi výstupy (ne jen nejnižší), kopec hladiny nad L, počet iterací a čas.
static func darcy(c: Dictionary, comp: PackedInt32Array, L: float, entries: PackedInt32Array, q: float, ex: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var t := VS.table()
	var k0 := float(c.get("darcy_k", 1e-4)); var dz := float(c.get("darcy_dz", 0.5)); var it_max := int(c.get("darcy_it", 400))
	var T := {}   # sloupec → propustnost m²/s
	for b in comp:
		var w := minf(c.hi[b], L + dz) - float(c.lo[b])   # mocnost do L + dz (i pásmo s výstupem na spodku)
		if w <= E: continue
		var m: int = c.mat[b]
		var pm: float = 1.0 if m == 0 else float(t.get(m, [0.0])[0])
		var cc: int = c.bcol[b]
		T[cc] = float(T.get(cc, 0.0)) + k0 * maxf(pm, 0.05) * w
	var fixed := {}   # sloupec výstupu → hladina
	for b in comp:
		for o in _outs(c, b, ex):
			if float(o[0]) <= L + dz:
				var oc: int = c.bcol[b]   # výstup se modeluje v sloupci tělesa (soused je už mimo vrstvu)
				fixed[oc] = minf(float(fixed.get(oc, INF)), float(o[0]))
	var src := {}   # voda ze vstupu steče (nenasyceně) do pánve = první pásmo oblasti → zdroj tam
	if not comp.is_empty(): src[c.bcol[comp[0]]] = q
	for cc in src: if not T.has(cc): T[cc] = k0 * 0.05 * 0.1   # vstup nad oblastí: tenké spojení
	var cols: Array = T.keys(); cols.sort()
	var h := {}
	for cc in cols: h[cc] = float(fixed.get(cc, L))
	var H: int = c.H; var W: int = c.W
	var nbr := {}
	for cc in cols:
		var lst := []
		var x: int = cc / H; var y: int = cc % H
		for d in 4:
			var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var c2 := qx * H + qy
			if T.has(c2): lst.append([c2, 2.0 * float(T[cc]) * float(T[c2]) / (float(T[cc]) + float(T[c2]))])
		nbr[cc] = lst
	var om := 1.7; var it := 0; var res := INF; var seep := {}
	for cc in src:   # vstup bez spojení s oblastí (voda jen protéká sestupem) → zůstane na povrchu = průsak zpět
		if nbr[cc].is_empty(): seep[cc] = true; h[cc] = float(c.h[cc])
	while it < it_max:
		it += 1; res = 0.0
		for cc in cols:
			if fixed.has(cc): continue
			var sw := 0.0; var sh := 0.0
			for e in nbr[cc]: sw += float(e[1]); sh += float(e[1]) * float(h[e[0]])
			if sw <= 0.0: continue
			var hn := (sh + float(src.get(cc, 0.0)) / 1000.0) / sw
			var dv := om * (hn - float(h[cc]))
			var nh := float(h[cc]) + dv
			if nh > float(c.h[cc]): nh = float(c.h[cc]); seep[cc] = true   # hladina nad terénem → průsakový pramen (výtok)
			elif seep.has(cc) and hn < float(c.h[cc]) - 1e-4: seep.erase(cc)
			res = maxf(res, absf(nh - float(h[cc]))); h[cc] = nh
		if res < 1e-7: break
		if it % 200 == 0 and _darcy_bal(c, h, nbr, src, fixed, seep) > 0.99 * q: break   # bilance: výtok ≥ 99 % přítoku
	var outs := []
	var tot := 0.0; var tot_seep := 0.0
	var sinks := fixed.keys(); sinks.append_array(seep.keys())
	for oc in sinks:   # výtok = čistý přítok do sloupce s pevnou hladinou (výstup nebo průsak)
		var f := float(src.get(oc, 0.0))
		for e in nbr.get(oc, []): f += float(e[1]) * (float(h[e[0]]) - float(h[oc])) * 1000.0
		if f > 1e-6:
			outs.append([_col_s(c, oc, false), f, "výstup" if fixed.has(oc) else "průsak"]); tot += f
			if not fixed.has(oc): tot_seep += f
	outs.sort_custom(func(a, b): return a[1] > b[1])
	var mound := 0.0
	for cc in cols: mound = maxf(mound, float(h[cc]) - L)
	return {"outs": outs, "q_out": tot, "q_seep": tot_seep, "n_seep": seep.size(), "q_in": q, "n_out": outs.size(), "it": it, "res": res, "mound_m": mound, "cols": cols.size(), "ms": (Time.get_ticks_usec() - t0) / 1000.0}

static func _darcy_bal(c: Dictionary, h: Dictionary, nbr: Dictionary, src: Dictionary, fixed: Dictionary, seep: Dictionary) -> float:
	var tot := 0.0
	var sinks := fixed.keys(); sinks.append_array(seep.keys())
	for oc in sinks:
		var f := float(src.get(oc, 0.0))
		for e in nbr.get(oc, []): f += float(e[1]) * (float(h[e[0]]) - float(h[oc])) * 1000.0
		if f > 0.0: tot += f
	return tot
