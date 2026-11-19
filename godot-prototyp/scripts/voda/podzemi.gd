extends RefCounted
## KOPIE z blueprint-studie/scripts/voda/podzemi.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E47d podzemní voda po propustné vrstvě (Jan 20:00). 3D buňky celého světa: index v = (x · H + y) · NZ + z.
## Těleso = souvislé (6-sousedé) buňky propustné horniny (perm ≥ ponor_perm), krasu nebo dutiny (vzduch pod povrchem).
## Plní se jako jedna nádrž po vrstvách z (události, žádné tiky) do nejnižšího výstupu: otevřený vzduch nad terénem
## (pramen ve svahu / stěně, výtok do tůně) nebo okraj ostrova (vyvěračka ve stěně → mlha). Bez výstupu se naplní a dál nic nepřijímá.
## Objem buňky: dutina = celá buňka, hornina = pórovitost por ze sdílené tabulky (kras bez por = 0,05).

const VS = preload("res://scripts/voda/voda_svet.gd")
const D6 := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

static var _SOL := {}
static func _soluble(m: int) -> bool:
	if _SOL.is_empty():
		var HR = load("res://scripts/teren/horniny.gd")
		for k in ["cave_limestone", "deep_limestone", "dolomite", "limestone_outcrop", "gypsum", "rock_salt"]: _SOL[HR.id_of(k)] = true
	return _SOL.has(m)

## ctx = {W, H, NZ, mat (PackedInt32Array), top (sloupec: první vzduch nad terénem), wall (sloupec), perm_min, leak_q}
static func ctx_world(w, p: Dictionary) -> Dictionary:
	var W: int = w.w * 16; var H: int = w.h * 16; var NZ := 64
	var mat := PackedInt32Array(); mat.resize(W * H * NZ)
	var top := PackedInt32Array(); top.resize(W * H)
	var wall := PackedByteArray(); wall.resize(W * H); wall.fill(1)
	for s in w.order:
		var r: Dictionary = w.slots[s]
		for c in 256:
			var col: int = (s.x * 16 + c / 16) * H + s.y * 16 + c % 16
			wall[col] = 0; top[col] = int(r.hm[c])
			for z in NZ: mat[col * NZ + z] = int(r.cells[c * 64 + z])
	return make(W, H, NZ, mat, top, wall, p)

static func make(W: int, H: int, NZ: int, mat, top: PackedInt32Array, wall: PackedByteArray, p: Dictionary) -> Dictionary:
	return {"W": W, "H": H, "NZ": NZ, "mat": mat, "top": top, "wall": wall, "perm_min": float(p.ponor_perm), "leak_q": float(p.ug_leak_q),
		"depth": int(p.ug_hloubka), "cell_m3": float(p.get("ug_cell_m3", 0.125)), "q_to_m3": float(p.get("ug_q_to_m3", 0.001))}

static func _perm(m: int) -> float:
	return float(VS.table().get(m, [0.0])[0])

static func body(ctx: Dictionary, v: int) -> bool:
	var col: int = v / ctx.NZ; var z: int = v % ctx.NZ
	if ctx.wall[col] == 1: return false
	var m: int = ctx.mat[v]
	if m == 0: return z < ctx.top[col]   # dutina
	return _soluble(m) or _perm(m) >= ctx.perm_min

static func vol(ctx: Dictionary, v: int) -> float:
	var m: int = ctx.mat[v]
	if m == 0: return 1.0
	var por := float(VS.table().get(m, [0.0, 0.0])[1])
	return por if por > 0.0 else 0.05

## nejvyšší buňka tělesa pod povrchem sloupce (do ctx.depth buněk), jinak -1
static func entry(ctx: Dictionary, col: int) -> int:
	var t: int = ctx.top[col]
	for z in range(t - 1, maxi(t - 1 - int(ctx.depth), -1), -1):
		var v: int = col * ctx.NZ + z
		if body(ctx, v): return v
	return -1

## jedno těleso od vstupů (stejné těleso = sečtený přítok). q v jednotkách průtoku (l/s), objem v m³ (ctx.cell_m3).
static func solve(ctx: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var W: int = ctx.W; var H: int = ctx.H; var NZ: int = ctx.NZ
	var dist := {}; var par := {}
	var qu := PackedInt32Array()
	for e in entries:
		if not dist.has(e): dist[e] = 0; par[e] = -1; qu.append(e)
	var k := 0; var leak := 0.0
	var zmin := NZ; var zmax := -1
	var outs := []   # [z, dist, v, typ, col]
	var vz := {}
	while k < qu.size():
		var v := qu[k]; k += 1
		var col := v / NZ; var z := v % NZ; var x := col / H; var y := col % H
		zmin = mini(zmin, z); zmax = maxi(zmax, z)
		vz[z] = float(vz.get(z, 0.0)) + vol(ctx, v)
		if x == 0 or y == 0 or x == W - 1 or y == H - 1: outs.append([z, dist[v], v, "okraj", col])
		for d in D6:
			var qx: int = x + d.x; var qy: int = y + d.y; var qz: int = z + d.z
			if qx < 0 or qy < 0 or qx >= W or qy >= H or qz < 0 or qz >= NZ: continue
			var c2 := qx * H + qy; var u := c2 * NZ + qz
			if dist.has(u): continue
			if body(ctx, u):
				dist[u] = dist[v] + 1; par[u] = v; qu.append(u)
			elif ctx.wall[c2] == 0 and ctx.mat[u] == 0 and qz >= ctx.top[c2]:
				if not excl.has(c2): outs.append([z, dist[v], v, "povrch", c2])   # výtok zpět do zdrojové tůně = smyčka, nepočítá se
			elif ctx.wall[c2] == 0 and ctx.mat[u] != 0:
				var pm := _perm(ctx.mat[u])
				if pm > 0.0 and pm < ctx.perm_min: leak += pm * float(ctx.leak_q)   # průsak do slabě propustného okolí
	outs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = outs[0] if not outs.is_empty() else []
	var z_out: int = out[0] if not out.is_empty() else zmax
	var net := q - leak
	var ev := []; var cum := 0.0; var t := 0.0
	for z in range(zmin, z_out + 1):
		cum += float(vz.get(z, 0.0)) * float(ctx.cell_m3)
		t = (cum / (net * float(ctx.q_to_m3))) if net > 0.0 else -1.0
		ev.append({"z": z, "objem_m3": cum, "cas_s": t})
	var path := PackedInt32Array()
	if not out.is_empty():
		var v: int = out[2]
		while v != -1: path.append(v); v = par[v]
		path.reverse()
	var lake := PackedInt32Array(); var saturated := PackedInt32Array()
	for v in dist:
		if v % NZ <= z_out and net > 0.0:
			saturated.append(v)
			if ctx.mat[v] == 0: lake.append(v)
	return {"cells": dist.size(), "q_in": q, "leak": minf(leak, q), "zmin": zmin, "z_out": z_out, "out": out, "events": ev, "volume_m3": cum,
		"never_fills": net <= 0.0, "out_q": maxf(net, 0.0) if not out.is_empty() else 0.0, "closed": out.is_empty(),
		"path": path, "lake": lake, "saturated": saturated, "members": dist}
