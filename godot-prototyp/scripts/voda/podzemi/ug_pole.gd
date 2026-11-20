extends RefCounted
## KOPIE z blueprint-studie/scripts/podzemi52/ug_pole.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E52 varianta 2: stejný algoritmus jako voda/podzemi.gd (BFS tělesa, plnění po vrstvách z do nejnižšího výstupu), ale
## na plochých polích: materiál u8, štítek tělesa u8 (generace řešení), vzdálenost u16, fronta i32, objem po z.
## Těleso je omezené na dosah do hloubky vstupu: buňky nejvýš lim buněk pod povrchem sloupce (lim < 0 = bez omezení).

const VS = preload("res://scripts/voda/voda_svet.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const SELF = preload("res://scripts/voda/podzemi/ug_pole.gd")
const LI = preload("res://scripts/voda/litry.gd")   # E94: jeden tvar l → m³

class Members:
	var ctx: Dictionary
	var id: int
	func has(v: int) -> bool:
		return v >= 0 and v < ctx.lab.size() and ctx.lab[v] == id

static func luts(perm_min: float, leak_q: float) -> Dictionary:
	var bm := PackedByteArray(); bm.resize(256)
	var pv := PackedFloat32Array(); pv.resize(256)
	var wk := PackedFloat32Array(); wk.resize(256)
	var t := VS.table()
	for m in 256:
		var e: Array = t.get(m, [0.0, 0.0])
		var pm := float(e[0])
		if m != 0 and (UG._soluble(m) or pm >= perm_min): bm[m] = 1
		var por := float(e[1]) if e.size() > 1 else 0.0
		pv[m] = 1.0 if m == 0 else (por if por > 0.0 else 0.05)
		if m != 0 and pm > 0.0 and pm < perm_min: wk[m] = pm * leak_q
	return {"body": bm, "por": pv, "weak": wk}

static func make(W: int, H: int, NZ: int, mat, top: PackedInt32Array, wall: PackedByteArray, p: Dictionary) -> Dictionary:
	var m8: PackedByteArray
	if mat is PackedByteArray: m8 = mat
	else:
		m8 = PackedByteArray(); m8.resize(mat.size())
		for i in mat.size(): m8[i] = int(mat[i])
	var c := UG.make(W, H, NZ, m8, top, wall, p)
	var lim_m := float(p.get("p52_hloubka_m", -1.0))
	c.lim = int(round(lim_m / float(p.get("voda_cell_m", 0.5)))) if lim_m > 0.0 else -1
	c.lut = luts(c.perm_min, c.leak_q)
	var lab := PackedByteArray(); lab.resize(W * H * NZ); c.lab = lab   # štítek tělesa (1..255), trvalý → seskupení tůní
	var vis := PackedByteArray(); vis.resize(W * H * NZ); c.vis = vis   # navštíveno v tomto řešení (generace)
	c.next_id = 0
	var dist := PackedByteArray(); dist.resize(W * H * NZ * 2); c.dist = dist
	c.gen = 0
	c.impl = SELF; c.stats = {"solve_ms": 0.0, "solves": 0, "cells": 0}
	return c

static func _body(ctx: Dictionary, col: int, z: int) -> bool:
	if ctx.wall[col] == 1: return false
	var top: int = ctx.top[col]
	if z >= top: return false
	if int(ctx.lim) >= 0 and z < top - 1 - int(ctx.lim): return false
	var m: int = ctx.mat[col * int(ctx.NZ) + z]
	return m == 0 or ctx.lut.body[m] == 1

static func entry(ctx: Dictionary, col: int) -> int:
	var t: int = ctx.top[col]
	for z in range(t - 1, maxi(t - 1 - int(ctx.depth), -1), -1):
		if _body(ctx, col, z): return col * int(ctx.NZ) + z
	return -1

static func solve(ctx: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var W: int = ctx.W; var H: int = ctx.H; var NZ: int = ctx.NZ
	var mat: PackedByteArray = ctx.mat; var top: PackedInt32Array = ctx.top; var wall: PackedByteArray = ctx.wall
	var lab: PackedByteArray = ctx.lab; var dist: PackedByteArray = ctx.dist; var vis: PackedByteArray = ctx.vis
	var bm: PackedByteArray = ctx.lut.body; var pv: PackedFloat32Array = ctx.lut.por; var wk: PackedFloat32Array = ctx.lut.weak
	var lim: int = ctx.lim
	ctx.gen = int(ctx.gen) % 255 + 1
	if ctx.gen == 1: vis.fill(0)
	var g: int = ctx.gen
	var cid: int = lab[entries[0]] if not entries.is_empty() else 0
	if cid == 0: ctx.next_id = int(ctx.next_id) % 255 + 1; cid = ctx.next_id
	var qu := PackedInt32Array()
	for e in entries:
		if vis[e] != g: vis[e] = g; lab[e] = cid; dist.encode_u16(2 * e, 0); qu.append(e)
	var vz := PackedFloat64Array(); vz.resize(NZ)
	var k := 0; var leak := 0.0; var zmin := NZ; var zmax := -1
	var bz := 1 << 30; var bd := 1 << 30; var bv := -1; var bt := ""; var bc := -1
	var HZ := H * NZ
	while k < qu.size():
		var v := qu[k]; k += 1
		var col := v / NZ; var z := v - col * NZ; var x := col / H; var y := col - x * H
		var dv := dist.decode_u16(2 * v)
		if z < zmin: zmin = z
		if z > zmax: zmax = z
		vz[z] += pv[mat[v]]
		if (x == 0 or y == 0 or x == W - 1 or y == H - 1) and (z < bz or (z == bz and dv < bd)):
			bz = z; bd = dv; bv = v; bt = "okraj"; bc = col
		for d in 6:
			var qx := x; var qy := y; var qz := z
			match d:
				0: qx += 1
				1: qx -= 1
				2: qy += 1
				3: qy -= 1
				4: qz += 1
				5: qz -= 1
			if qx < 0 or qy < 0 or qx >= W or qy >= H or qz < 0 or qz >= NZ: continue
			var c2 := qx * H + qy; var u := c2 * NZ + qz
			if vis[u] == g: continue
			if wall[c2] == 1: continue
			var t2: int = top[c2]; var m: int = mat[u]
			var isb := qz < t2 and (m == 0 or bm[m] == 1) and (lim < 0 or qz >= t2 - 1 - lim)
			if isb:
				vis[u] = g; lab[u] = cid; dist.encode_u16(2 * u, mini(dv + 1, 65535)); qu.append(u)
			elif m == 0 and qz >= t2:
				if not excl.has(c2) and (z < bz or (z == bz and dv < bd)):
					bz = z; bd = dv; bv = v; bt = "povrch"; bc = c2
			elif m != 0:
				leak += wk[m]
	var has_out := bv >= 0
	var out: Array = [bz, bd, bv, bt, bc] if has_out else []
	var z_out: int = bz if has_out else zmax
	var net := q - leak
	var ev := []; var cum := 0.0; var t := 0.0
	for zz in range(zmin, z_out + 1):
		cum += vz[zz] * float(ctx.cell_m3)
		t = (cum / (net / float(ctx.l_na_m3))) if net > 0.0 else -1.0
		ev.append({"z": zz, "objem_m3": cum, "cas_s": t})
	var path := PackedInt32Array()
	if has_out:   # zpět po klesající vzdálenosti
		var v := bv
		path.append(v)
		while dist.decode_u16(2 * v) > 0:
			var dv := dist.decode_u16(2 * v); var col := v / NZ; var z := v - col * NZ; var x := col / H; var y := col - x * H
			var nxt := -1
			for o in [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]:
				var qx: int = x + o[0]; var qy: int = y + o[1]; var qz: int = z + o[2]
				if qx < 0 or qy < 0 or qx >= W or qy >= H or qz < 0 or qz >= NZ: continue
				var u := (qx * H + qy) * NZ + qz
				if vis[u] == g and dist.decode_u16(2 * u) == dv - 1: nxt = u; break
			if nxt < 0: break
			v = nxt; path.append(v)
		path.reverse()
	var lake := PackedInt32Array()
	if net > 0.0:
		for i in qu.size():
			var v := qu[i]
			if mat[v] == 0 and v % NZ <= z_out: lake.append(v)
	var mem := Members.new(); mem.ctx = ctx; mem.id = cid
	ctx.stats.solve_ms += (Time.get_ticks_usec() - t0) / 1000.0; ctx.stats.solves += 1; ctx.stats.cells += qu.size()
	return {"cells": qu.size(), "q_in": q, "leak": minf(leak, q), "zmin": zmin, "z_out": z_out, "out": out, "events": ev, "volume_m3": cum,
		"never_fills": net <= 0.0, "out_q": maxf(net, 0.0) if has_out else 0.0, "closed": not has_out, "path": path, "lake": lake, "members": mem, "list": qu, "gen": g}

static func touched(ctx: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool:
	var hit := false
	var NZ: int = ctx.NZ
	for c in ch:
		for z in [int(ctx.top[c]) - 1, int(ctx.top[c]) - 2]:
			if z >= 0 and ctx.lab[c * NZ + z] != 0: hit = true
	var S = load("res://scripts/voda/podzemi/ug_slovnik.gd")
	S.dig(ctx, ch, hv)
	return hit
