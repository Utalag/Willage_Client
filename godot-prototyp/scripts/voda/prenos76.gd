extends RefCounted
## E76: výřez terénu z průzkumného světa na ostrov – jen lokální studie klienta (žádná datová smlouva s backendem).
## Výřez v paměti = blueprint (typ, seed, posun) + slot původu + záznam bloku (hm, hm_f, bs, buňky) + prameny výřezu
## (místní souřadnice). Geometrie, materiály a zdroje se přenesou hotové, STAV VODY NE: po vložení se voda přepočítá
## v novém okolí (ostrov_voda.place76 lokálně nebo build plně) a z ustáleného stavu se znovu naplánují události.
## Otočení po 90° se nedělá (není triviální: pole, šum hornin i tělesa by se musela otáčet).

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const Block = preload("res://scripts/block.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const MC = preload("res://scripts/voda/eroze/mech.gd")
const HY = preload("res://scripts/voda/eroze/hydro.gd")
const BS := J.BS
const BH := J.BH

## výřez z bloku průzkumného světa; v = voda toho světa (ostrov_voda) → prameny ležící v bloku
static func cutout(b, v) -> Dictionary:
	var sp := []
	if v != null:
		for s in v.springs:
			var a: Array = v.slot_of(int(s.gi))
			if a[0] == b.slot: sp.append([a[1], a[2], int(s.z), float(s.q), String(s.druh)])
	return {"kind": b.kind, "seed": b.seed, "shift": b.shift, "ore_bonus": b.ore_bonus, "puvod": T.wslot(b.slot),
		"rec": b.bp_rec.duplicate(true), "geo": b.geo.duplicate(), "cells": b.cells.duplicate(), "hm": b.hm.duplicate(),
		"hm_gen": b.hm_gen.duplicate(), "water": b.water.duplicate(), "prameny": sp, "gen3": b.gen3.duplicate(true)}

## sloupec 64 buněk posunutý o dz (dz > 0: zdola se opakuje spodní buňka, dz < 0: spodek se odřízne, nahoru vzduch)
static func _shift_cells(a, dz: int):
	var out = a.duplicate()
	if dz == 0 or a.is_empty(): return out
	for c in a.size() / BH:
		var base: int = c * BH
		for z in BH:
			var zs := z - dz
			if zs < 0: out[base + z] = a[base]
			elif zs >= BH: out[base + z] = 0
			else: out[base + z] = a[base + zs]
	return out

static func _add(a, dz: float):
	var out = a.duplicate()
	for i in out.size(): out[i] = out[i] + (int(dz) if typeof(out[i]) == TYPE_INT else dz)
	return out

## vložení na slot ostrova s posunem dz (buňky): nový Block + záznam ve světě studie (napojení dalších bloků, podzemí)
static func place(cut: Dictionary, slot: Vector2i, dz: int):
	var b := Block.new()
	b.kind = cut.kind; b.seed = int(cut.seed); b.ore_bonus = float(cut.ore_bonus); b.slot = slot; b.shift = int(cut.shift)
	b.gen = "bp"
	var rec: Dictionary = cut.rec.duplicate(true)
	rec.slot = T.wslot(slot)
	for k in ["hm", "hm_f", "hm_raw", "hm_pre"]:
		if rec.has(k): rec[k] = _add(rec[k], dz)
	var bs := []
	for x in rec.bs: bs.append(_add(x, dz))
	rec.bs = bs
	rec.cells = _shift_cells(cut.rec.cells, dz)
	if rec.has("water"): rec.water = _shift_cells(cut.rec.water, dz)
	rec.t76 = {"puvod": cut.puvod, "dz": dz}
	b.bp_rec = rec
	b.geo = _shift_cells(cut.geo, dz)
	b.cells = _shift_cells(cut.cells, dz)
	b.water = _shift_cells(cut.water, dz) if cut.water.size() == BS * BS * BH else PackedInt32Array()
	b.hm = _add(cut.hm, dz); b.hm_gen = _add(cut.hm_gen, dz)
	for k in BS * BS:
		b.hm[k] = clampi(b.hm[k], 1, BH - 1); b.hm_gen[k] = clampi(b.hm_gen[k], 1, BH - 1)
	b.gen3 = cut.gen3.duplicate(true)
	var sp := []
	for e in cut.prameny: sp.append([e[0], e[1], int(e[2]) + dz, e[3], e[4]])
	b.prameny76 = sp
	b.prenos76 = {"puvod": cut.puvod, "dz": dz}
	return b

## voda v oblasti jednoho bloku: prameny, tůně, koryto, vodopády, odtok přes okraj ostrova / do sousedů, výstupy podzemí
static func region(v, slot: Vector2i) -> Dictionary:
	var r := {"prameny": 0, "prameny_lps": 0.0, "tun_sloupcu": 0, "koryto_sloupcu": 0, "vodopady": 0, "vodopady_okraj": 0, "okraj_lps": 0.0,
		"do_sousedu_lps": 0.0, "z_sousedu_lps": 0.0, "vystupy_podzemi": 0, "vystupy_lps": 0.0}
	var inb := func(gi: int) -> bool: return v.island[gi] == 1 and v.slot_of(gi)[0] == slot
	for s in v.springs:
		if inb.call(int(s.gi)) and bool(s.aktivni): r.prameny += 1; r.prameny_lps += float(s.q)
	for x in BS:
		for y in BS:
			var gi: int = v.gi_of(slot, x, y)
			if v.is_pond(gi): r.tun_sloupcu += 1
			elif v.st.eff[gi] >= float(v.st.L.thr): r.koryto_sloupcu += 1
			var j: int = v.st.to[gi]
			if j >= 0 and not inb.call(j) and v.island[j] == 1: r.do_sousedu_lps += float(v.st.eff[gi])
	for i in v.W * v.H:
		var j: int = v.st.to[i]
		if j >= 0 and v.island[i] == 1 and not inb.call(i) and inb.call(j): r.z_sousedu_lps += float(v.st.eff[i])
	for f in v.falls:
		if inb.call(int(f.top)):
			if f.edge: r.vodopady_okraj += 1; r.okraj_lps += float(f.q)
			else: r.vodopady += 1
	for u in v.st.get("under", []):
		if int(u.exit) >= 0 and inb.call(int(u.exit)): r.vystupy_podzemi += 1; r.vystupy_lps += float(u.q)
	return r

## události z ustáleného stavu vody: plnění tůní (hydro68.udalosti), příchod vody (čas toku od pramene po D8, Manning),
## E51 eroze / nános (odpočty v haldě, mech.gd). old = předchozí plán (sloupec → R, A) nebo {}; fresh = sloupce s plným
## odpočtem (výřez); only = přeplánovat jen tyto sloupce (prázdné = všechny mokré)
static func events(v, old: Dictionary, fresh: Dictionary, only: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var pond: Array = H68.udalosti(v.st)
	var t1 := Time.get_ticks_usec()
	var arr := _arrival(v)
	var t2 := Time.get_ticks_usec()
	var mc = _mech(v, old, fresh, only)
	var t3 := Time.get_ticks_usec()
	var first := INF
	if mc.q.size() > 0: first = mc.q.top_time()
	var tp := INF
	for e in pond:
		if float(e[0]) >= 0.0: tp = minf(tp, float(e[0]))
	return {"tune": pond.size(), "tune_prvni_s": tp, "tune_ms": (t1 - t0) / 1000.0,
		"prichod": arr.n, "prichod_max_s": arr.tmax, "prichod_ms": (t2 - t1) / 1000.0,
		"eroze_aktivni": mc.live(), "eroze_fronta": mc.q.size(), "eroze_preplanovano": mc.stats.events_resched, "eroze_prvni_s": first, "eroze_ms": (t3 - t2) / 1000.0,
		"celkem_ms": (t3 - t0) / 1000.0, "_mc": mc}

## příchod vody: od každého aktivního pramene po D8, čas úseku = délka / rychlost (Manning); první příchod na sloupec
static func _arrival(v) -> Dictionary:
	var st: Dictionary = v.st
	var tarr := {}
	var tmax := 0.0
	for s in v.springs:
		if not bool(s.aktivni): continue
		var i: int = int(s.gi); var t := 0.0; var g := 0
		while i >= 0 and g < 100000:
			g += 1
			if tarr.has(i) and float(tarr[i]) <= t: break
			tarr[i] = t
			var j: int = st.to[i]
			if j < 0 or float(st.eff[i]) < float(st.L.thr) and float(st.fill[i]) <= float(st.hm[i]) + 0.01: break
			var dx := 1.4142 if (j / v.H != i / v.H and j % v.H != i % v.H) else 1.0
			var dist: float = dx * HY.CELL   # sloupec i buňka 0,5 m
			var s_ := maxf((float(st.hm[i]) - float(st.hm[j])) * HY.CELL / dist, float(v.p.get("e51_s_min", 0.005)))
			var vel: float = HY.manning(maxf(float(st.eff[i]), 1e-6) / 1000.0, s_, v.p).v
			t += dist / maxf(vel, 1e-6)
			tmax = maxf(tmax, t)
			i = j
	return {"n": tarr.size(), "tmax": tmax}

## E51 plán nad stavem vody ostrova (bez vlastního toku): buňky sloupců z bloků, odpočty z old (dopočítané do teď) nebo plné
static func _mech(v, old: Dictionary, fresh: Dictionary, only: Dictionary):
	var n: int = v.W * v.H
	var mc = MC.new(v.p, 1, 1, BH, _one_col(), PackedByteArray([0]), PackedFloat64Array([0.0]))
	mc.W = v.W; mc.H = v.H; mc.NZ = BH
	var cells := PackedByteArray(); cells.resize(n * BH)
	var hm := PackedInt32Array(); hm.resize(n)
	for s in v.blocks:
		var b = v.blocks[s]
		for x in BS:
			for y in BS:
				var gi: int = v.gi_of(s, x, y); var k: int = x * BS + y
				hm[gi] = b.hm[k]
				for z in BH: cells[gi * BH + z] = b.geo[k * BH + z]
	mc.cells = cells; mc.hm = hm; mc.st = v.st
	for a in [mc.R, mc.A, mc.re, mc.rd, mc.tl, mc.vel]: a.resize(n)
	mc.gen.resize(n); mc.mode.resize(n)
	mc.dep = HY.id_of(String(v.p.e51_nanos))
	var lst := []
	for i in n:
		if v.island[i] == 0: continue
		if old.has(i) and not fresh.has(i): mc.R[i] = float(old[i][0]); mc.A[i] = float(old[i][1])
		else: mc.R[i] = float(HY.mat(mc.top_mat(i))[1])
		if only.is_empty() or only.has(i): lst.append(i)
	var all := {}
	for i in lst: all[i] = true
	mc._resched(lst, all)
	mc.stats.events_resched = lst.size()
	return mc

static func _one_col() -> PackedByteArray:
	var a := PackedByteArray(); a.resize(BH); return a

## sloupce k přeplánování po vložení: výřez + prstenec e51_s_len + 1 (sklon po proudu) + sloupce, kde se voda změnila
## (fill, eff, to, ain, pw) + celé tůně, kterých se změna dotkla (nános podle přítoku celé tůně)
static func dirty(v, st_old: Dictionary, slot: Vector2i) -> Dictionary:
	var only := {}; var nchg := 0
	var st: Dictionary = v.st
	for i in v.W * v.H:
		if v.island[i] == 1 and (st.fill[i] != st_old.fill[i] or st.eff[i] != st_old.eff[i] or st.to[i] != st_old.to[i] or st.ain[i] != st_old.ain[i] or st.pw[i] != st_old.pw[i]):
			only[i] = true; nchg += 1
	var ring := int(v.p.get("e51_s_len", 4)) + 1
	var ws := T.wslot(slot)
	for x in range(-ring, BS + ring):
		for y in range(-ring, BS + ring):
			var gx: int = ws.x * BS + x; var gy: int = ws.y * BS + y
			if gx >= 0 and gy >= 0 and gx < v.W and gy < v.H and v.island[gx * v.H + gy] == 1: only[gx * v.H + gy] = true
	var seen := {}
	for i in only.keys():
		if st.pw[i] != 1 or seen.has(i): continue
		var qu := [i]; seen[i] = true; var k := 0
		while k < qu.size():
			var c: int = qu[k]; k += 1
			only[c] = true
			var H: int = v.H; var W: int = v.W
			var x: int = c / H; var y: int = c % H
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var qx: int = x + dx; var qy: int = y + dy
					if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
					var j: int = qx * H + qy
					if st.pw[j] == 1 and not seen.has(j): seen[j] = true; qu.append(j)
	return {"only": only, "zmenene": nchg}

## odpočty plánu (sloupec → [R, A]) pro další přeplánování
static func counters(mc, v) -> Dictionary:
	var out := {}
	for i in v.W * v.H:
		if v.island[i] == 1: out[i] = [mc.R[i], mc.A[i]]
	return out
