extends RefCounted
## E47: déšť a tok vody přes CELÝ svět naráz simulací voda-studie (kopie voda_sim.gd, beze změny pravidel).
## Výřez = všechny bloky světa, svisle od (nejnižší povrch − voda_depth) po nejvyšší povrch + 2. Vlastnosti buněk
## (propustnost, pórovitost, odpor, zadržení) podle MaterialId ze sdílené tabulky + horniny_voda.json; nepropustné
## (perm ≤ perm_leak) vodu nepojmou (jako gen-v3 a water_flow.gd). Okraje světa otevřené (odtok), chybějící blok = nepropustná stěna.
## Výstup po sloupcích: hloubka volné vody (m) = kaluže/jezera, tok = součet bočního toku volné vody za celý běh (kudy teče).

const VSim = preload("res://scripts/kopie/voda_sim.gd")
const VP = preload("res://scripts/kopie/voda_params.gd")
const Mat = preload("res://scripts/kopie/mat.gd")

static var _T := {}
static func table() -> Dictionary:
	if _T.is_empty():
		var d := VP.load_shared_table()
		var leak := float(d.get("perm_leak", 0.05))
		for k in d.materials:
			var e: Dictionary = d.materials[k]
			var perm := float(e.perm)
			var cap := float(e.por) if perm > leak else 0.0
			_T[int(e.id)] = [clampf(perm, 0.0, 1.0), cap, float(e.res), minf(float(e.get("ret", 0.0)), cap)]
	return _T

static func sim_params(p: Dictionary) -> Dictionary:
	return {"cell_xy": 1.0, "cell_z": 0.5, "evap": 0.0, "evap_soil": 0.0, "edge_drain": 1,
		"flow_air": 1.0, "flow_ground": 1.0, "infil": float(p.get("voda_infil", 0.10)), "perm_scale": 1.0, "film": 0.03,
		"walk_slow_m": 0.05, "walk_deep_m": 0.30, "walk_mud_s": 0.95}

## sinks = indexy mřížky světa (gx · GH + gy) s ponorem (E47b): z nejnižší vzduchové buňky nad povrchem se každý tik odebere
## až ponor_rate volné vody (zmizí do podzemí, počítá se jako „ponor“).
static func run(w, p: Dictionary, sinks := PackedInt32Array()) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var GW: int = w.w * 16; var GH: int = w.h * 16
	var lo := 64; var hi := 0
	for s in w.order:
		for v in w.slots[s].hm:
			lo = mini(lo, v); hi = maxi(hi, v)
	var z0 := maxi(lo - int(p.get("voda_depth", 6)), 0); var z1 := mini(hi + 2, 64)
	var NZ := z1 - z0
	var s = VSim.new(GW, GH, NZ, sim_params(p))
	s.open_sides = 15
	var T := table()
	for gx in GW:
		for gy in GH:
			var sl := Vector2i(gx / 16, gy / 16)
			var r = w.slots.get(sl, null)
			for z in NZ:
				var zz := z + z0
				var m := 0
				if r == null:
					m = Mat.GRANITE   # chybějící blok = nepropustná stěna (déšť na ni nepadá, voda se o ni zastaví)
				else:
					m = r.cells[((gx % 16) * 16 + gy % 16) * 64 + zz]
				var i: int = s.idx(gx, gy, z)
				if m == 0: continue
				s.mat[i] = 6   # pevná (jen příznak „ne vzduch“ pro voda_sim), vlastnosti podle tabulky
				var e: Array = T.get(m, [0.0, 0.0, 0.1, 0.0])
				s.kp[i] = e[0]; s.cap[i] = e[1]; s.res[i] = e[2]; s.ret[i] = e[3]
	s.rain = float(p.get("voda_rain", 0.01)); s.rain_ticks = int(p.get("voda_rain_ticks", 40))
	var ticks := int(p.get("voda_ticks", 360))
	var A: int = GW * GH
	var flow := PackedFloat32Array(); flow.resize(A)
	var pon := 0.0
	var rate := float(p.get("ponor_rate", 0.2))
	var scol := PackedInt32Array()
	for gi in sinks: scol.append((gi / GH) + (gi % GH) * GW)
	for t in ticks:
		s.step()
		for c in scol:
			for z in range(1, NZ):
				var i := c + z * A
				if s.mat[i] == 0 and s.mat[i - A] != 0:
					var tk := minf(s.w[i], rate); s.w[i] -= tk; pon += tk
					break
		for i in s.flux.size():
			var f: float = s.flux[i]
			if f > 0.0 and s.mat[i] == 0:
				flow[i % A] += f
	# výstup po sloupcích
	var depth := PackedFloat32Array(); depth.resize(A)
	var pooled := 0.0; var wet := 0
	for c in A:
		var dsum := 0.0
		for z in NZ:
			var i := c + z * A
			if s.mat[i] == 0: dsum += s.w[i]
		depth[c] = dsum * 0.5
		pooled += dsum
		if depth[c] >= 0.02: wet += 1
	# zápis volné vody do záznamů (jednotky 1/4096) pro vykreslení kaluží
	for sl in w.order:
		var r: Dictionary = w.slots[sl]
		var wa := PackedInt32Array(); wa.resize(16384)
		for c in 16384:
			var lx := c / 1024; var ly := (c / 64) % 16; var zz := c % 64
			if zz < z0 or zz >= z1: continue
			var i: int = s.idx(sl.x * 16 + lx, sl.y * 16 + ly, zz - z0)
			if s.mat[i] == 0 and s.w[i] > 0.02: wa[c] = int(round(minf(s.w[i], 1.0) * 4096))
		r.water_sim = wa
	# soustředění toku: podíl celkového toku v nejsilnějších 5 % sloupců
	var fl := Array(flow); fl.sort(); fl.reverse()
	var tot := 0.0; var top := 0.0
	for k in fl.size():
		tot += fl[k]
		if k < fl.size() / 20: top += fl[k]
	return {"GW": GW, "GH": GH, "z0": z0, "NZ": NZ, "depth": depth, "flow": flow, "rain_in": s.in_total,
		"out": s.out_total, "pooled_m3": pooled * 0.5 * 0.25, "wet_cols": wet, "flow_top5": top / maxf(tot, 1e-9),
		"bal_err": s.bal_err_max, "ponor": pon, "ticks": ticks, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "total": s.total()}
