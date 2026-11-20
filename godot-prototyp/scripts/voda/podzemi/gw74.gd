extends RefCounted
## KOPIE z blueprint-studie/scripts/gw74/gw74.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E74 (Jan 2026-11-19 20:47 / 20:49, hypotéza): hladina podzemní vody jako plocha funkce gw(x, y) – stejně jako hranice
## vrstev bs[k]. Řešiče (E52 nadrž / přeliv, E58 auto, E67 pretok + E73) dál počítají jen hrubý ustálený stav po tělesech
## (objem, výtok, prameny pro povrch). Z jejich výsledku se postaví plocha: na sloupec řídicí mřížky top / bot nejvyššího
## nasyceného intervalu (float32), kde jedna výška nestačí (víc oddělených intervalů, zavěšená voda), řídký tvar
## extra[sloupec] = [lo, hi, …]; mokrý film E67 zvlášť. Buňky s vodou se vzorkují až při kontaktu (výkop, obnažená vrstva).
## Výtoky: gw protne povrch nebo stěnu (soused níž než top) → výtok jen k vykreslení; voda teče až po obsazení pramene.
const E := 1e-6
const CELL := 0.25   # herní buňka (m), vzorkování při kontaktu

## sloupec → seřazené sloučené intervaly [[lo, hi], …]
static func _add(m: Dictionary, cc: int, lo: float, hi: float) -> void:
	if hi <= lo + E: return
	if not m.has(cc): m[cc] = []
	m[cc].append([lo, hi])

static func _merge(a: Array) -> Array:
	a.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out := []
	for e in a:
		if not out.is_empty() and float(e[0]) <= float(out[-1][1]) + E: out[-1][1] = maxf(float(out[-1][1]), float(e[1]))
		else: out.append([float(e[0]), float(e[1])])
	return out

## plocha z výsledků těles (st.ug_bodies) nad kontextem pásem c
static func build(c: Dictionary, bodies: Array) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n: int = int(c.W) * int(c.H)
	var sat := {}; var fil := {}
	var film := float(c.get("film67", 0.5))
	var tel := []
	for r in bodies:
		if r.has("pits67"):   # E67: pasti s hladinou + mokrý film u dna protékaných pásem
			for p in r.pits67:
				var L := float(p.hladina)
				for b in p.bands: _add(sat, int(c.bcol[b]), float(c.lo[b]), minf(float(c.hi[b]), L))
			for b in r.get("wet67", []): _add(fil, int(c.bcol[b]), float(c.lo[b]), minf(float(c.hi[b]), float(c.lo[b]) + film))
		else:                 # E52 / E58: jedna hladina tělesa
			var L := float(r.z_out)
			for b in r.comp_ids: _add(sat, int(c.bcol[b]), float(c.lo[b]), minf(float(c.hi[b]), L))
		tel.append({"objem_m3": float(r.volume_m3), "vytok": float(r.out_q), "prusak": float(r.leak), "q_in": float(r.q_in), "uzavreno": bool(r.closed)})
	var top := PackedFloat32Array(); top.resize(n); top.fill(-1.0)
	var bot := PackedFloat32Array(); bot.resize(n); bot.fill(-1.0)
	var extra := {}; var filmd := {}
	var keys := sat.keys(); keys.sort()
	for cc in keys:
		var iv := _merge(sat[cc])
		top[cc] = iv[-1][1]; bot[cc] = iv[-1][0]
		if iv.size() > 1:
			var ex := PackedFloat32Array()
			for k in iv.size() - 1: ex.append(iv[k][0]); ex.append(iv[k][1])
			extra[cc] = ex
	# kompaktní tvar: pod top jsou plná všechna propustná pásma sloupce (pravidlo z geologie) → výjimky jen kde to neplatí
	var vyj := {}
	for cc in keys:
		var iv := _merge(sat[cc])
		if not _same(iv, _rule(c, cc, float(top[cc]))):
			var ex := PackedFloat32Array()
			for e in iv: ex.append(e[0]); ex.append(e[1])
			vyj[cc] = ex
	var fk := fil.keys(); fk.sort()
	for cc in fk:   # film jen tam, kde není nasycená voda
		var iv := _merge(fil[cc])
		var fx := PackedFloat32Array()
		for e in iv:
			if not _in_sat(top, bot, extra, cc, (float(e[0]) + float(e[1])) * 0.5): fx.append(e[0]); fx.append(e[1])
		if not fx.is_empty(): filmd[cc] = fx
	return {"W": int(c.W), "H": int(c.H), "top": top, "bot": bot, "extra": extra, "film": filmd, "telesa": tel, "vyjimky": vyj,
		"claim": {}, "ms": (Time.get_ticks_usec() - t0) / 1000.0}

## pravidlo kompaktního tvaru: nasycené jsou všechny propustné části sloupce pod top (float32 jako uložená plocha)
static func _rule(c: Dictionary, cc: int, t: float) -> Array:
	var a := []
	for b in range(c.cs[cc], c.cs[cc + 1]):
		if c.body[b] == 1 and float(c.lo[b]) < t - E: a.append([float(c.lo[b]), minf(float(c.hi[b]), t)])
	return _merge(a)

static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if absf(float(a[i][0]) - float(b[i][0])) > 1e-4 or absf(float(a[i][1]) - float(b[i][1])) > 1e-4: return false
	return true

## je výška z ve sloupci cc pod hladinou (v nasyceném intervalu plochy)?
static func _in_sat(top: PackedFloat32Array, bot: PackedFloat32Array, extra: Dictionary, cc: int, z: float) -> bool:
	if top[cc] >= 0.0 and z >= bot[cc] - E and z < top[cc] - E: return true
	if extra.has(cc):
		var ex: PackedFloat32Array = extra[cc]
		for k in range(0, ex.size(), 2):
			if z >= ex[k] - E and z < ex[k + 1] - E: return true
	return false

static func sat(gw: Dictionary, cc: int, z: float) -> bool:
	return _in_sat(gw.top, gw.bot, gw.extra, cc, z)

static func _in_film(gw: Dictionary, cc: int, z: float) -> bool:
	if not gw.film.has(cc): return false
	var fx: PackedFloat32Array = gw.film[cc]
	for k in range(0, fx.size(), 2):
		if z >= fx[k] - E and z < fx[k + 1] - E: return true
	return false

## objem vody z plochy (m³) přes geologii: pórovitost pásma tělesa v intervalu (jen nasycená voda, ne film)
static func volume(c: Dictionary, gw: Dictionary) -> float:
	var v := 0.0
	var top: PackedFloat32Array = gw.top
	for cc in top.size():
		if top[cc] < 0.0: continue
		var iv := [[float(gw.bot[cc]), float(top[cc])]]
		if gw.extra.has(cc):
			var ex: PackedFloat32Array = gw.extra[cc]
			for k in range(0, ex.size(), 2): iv.append([float(ex[k]), float(ex[k + 1])])
		for b in range(c.cs[cc], c.cs[cc + 1]):
			if c.body[b] == 0: continue
			for e in iv:
				var ov := minf(float(c.hi[b]), e[1]) - maxf(float(c.lo[b]), e[0])
				if ov > E: v += float(c.por[b]) * float(c.A) * ov
	return v

## výtoky plochy: gw protne povrch sloupce (top ≥ h) nebo stěnu (soused níž než top) → [sloupec, z, typ]
static func outlets(c: Dictionary, gw: Dictionary) -> Array:
	var out := []
	var W: int = c.W; var H: int = c.H
	var top: PackedFloat32Array = gw.top
	for cc in top.size():
		if top[cc] < 0.0 or c.wall[cc] == 1: continue
		var t := float(top[cc])
		if t >= float(c.h[cc]) - E: out.append([cc, float(c.h[cc]), "povrch"]); continue
		var x := cc / H; var y := cc % H
		for d in 4:
			var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var c2 := qx * H + qy
			if c.wall[c2] == 1:
				if bool(c.get("okraj67", false)): out.append([cc, float(gw.bot[cc]), "okraj"]); break   # E67 O: stěna ostrova je výstup jen s p67_okraj
				continue
			if float(c.h[c2]) < t - E: out.append([cc, maxf(float(gw.bot[cc]), float(c.h[c2])), "stena"]); break
	return out

## vzorkování při kontaktu: výkop sloupce cc z výšky h0 na h1 (m) → buňky 0,25 m ve stěnách 4 sousedů a hladina v jámě.
## Stav buňky stěny: 0 suchá, 1 výtok (nasycená buňka u vzduchu), 2 mokrá / kape (film nebo 1 buňka nad hladinou).
static func contact(c: Dictionary, gw: Dictionary, cc: int, h0: float, h1: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var W: int = c.W; var H: int = c.H
	var x := cc / H; var y := cc % H
	var cnt := [0, 0, 0]; var cells := PackedByteArray()
	for d in 4:
		var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var c2 := qx * H + qy
		if c.wall[c2] == 1: continue
		var zt := minf(h0, float(c.h[c2]))
		var z := h1 + CELL * 0.5
		while z < zt:
			var s := 0
			if sat(gw, c2, z): s = 1
			elif _in_film(gw, c2, z) or sat(gw, c2, z - CELL): s = 2
			cells.append(s); cnt[s] += 1
			z += CELL
	var lvl := -1.0   # hladina v jámě: gw vlastního sloupce nad dnem výkopu
	if sat(gw, cc, h1 + CELL * 0.5): lvl = minf(float(gw.top[cc]) if float(gw.top[cc]) > h1 else h1, h0)
	return {"bunek": cells.size(), "sucha": cnt[0], "vytok": cnt[1], "mokra": cnt[2], "hladina_jamy": lvl, "cells": cells,
		"us": (Time.get_ticks_usec() - t0)}

## obsazení pramene (zachycení, napojení na koryto, výkop vedle) – sloupec povrchové mřížky výtoku
static func claim(gw: Dictionary, s: int) -> void:
	gw.claim[s] = true

## paměť (bajty serializace) a otisk plochy
static func bytes(gw: Dictionary) -> int:
	return var_to_bytes({"top": gw.top, "bot": gw.bot, "extra": gw.extra, "film": gw.film, "telesa": gw.telesa}).size()

## řídká varianta: jen sloupce s vodou (index + top + bot)
static func bytes_sparse(gw: Dictionary) -> int:
	var idx := PackedInt32Array(); var tb := PackedFloat32Array()
	for cc in gw.top.size():
		if gw.top[cc] >= 0.0: idx.append(cc); tb.append(gw.top[cc]); tb.append(gw.bot[cc])
	return var_to_bytes({"i": idx, "tb": tb, "extra": gw.extra, "film": gw.film, "telesa": gw.telesa}).size()

## kompaktní varianta: řídká plocha top (jen sloupce s vodou) + výjimky z pravidla + film; zbytek tvaru z geologie
static func bytes_compact(gw: Dictionary) -> int:
	var idx := PackedInt32Array(); var tp := PackedFloat32Array()
	for cc in gw.top.size():
		if gw.top[cc] >= 0.0: idx.append(cc); tp.append(gw.top[cc])
	return var_to_bytes({"i": idx, "t": tp, "vyjimky": gw.vyjimky, "film": gw.film, "telesa": gw.telesa}).size()

static func otisk(gw: Dictionary) -> String:
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256)
	hc.update(("gw|%d|%d|" % [gw.W, gw.H]).to_utf8_buffer())
	hc.update(gw.top.to_byte_array()); hc.update(gw.bot.to_byte_array())
	var ks: Array = gw.extra.keys(); ks.sort()
	for k in ks: hc.update(("x%d|" % k).to_utf8_buffer()); hc.update(PackedFloat32Array(gw.extra[k]).to_byte_array())
	ks = gw.film.keys(); ks.sort()
	for k in ks: hc.update(("f%d|" % k).to_utf8_buffer()); hc.update(PackedFloat32Array(gw.film[k]).to_byte_array())
	return hc.finish().hex_encode().substr(0, 16)
