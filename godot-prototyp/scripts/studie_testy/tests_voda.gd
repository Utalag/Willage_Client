extends RefCounted
## KOPIE z blueprint-studie/scripts/voda/tests_voda.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E47 měření: eroze po vrstvách (režimy blok / okraj / svet) + déšť a tok vody před a po. Píše shots/bench_voda.txt
## a shots/voda_eroze.json (data pro tools/compose_voda.py).

const T = preload("res://scripts/studie_testy/tests_horniny.gd")
const MT = preload("res://scripts/studie_testy/metrics.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const SD = preload("res://scripts/teren/sides.gd")
const ES = preload("res://scripts/voda/eroze_svet.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")

const SECTIONS := {"nizina": Vector2i(2, 1), "hora_vyzdvizena": Vector2i(0, 0), "hora_zvrasnena": Vector2i(1, 2),
	"sopka": Vector2i(2, 0), "prohlubne": Vector2i(1, 0)}

## šev povrchu na funkci hm_f: průměrný |Δ| mezi sousedními řídicími body přes šev a uvnitř bloků (U)
static func surf_seam(w) -> Dictionary:
	var se := 0.0; var ns := 0; var inn := 0.0; var ni := 0; var mx := 0.0
	var ks := 0.0; var kmx := 0.0; var ki := 0.0; var nki := 0
	for s in w.order:
		var a: PackedFloat64Array = w.slots[s].hm_f
		for x in 16:
			for y in 16:
				if x < 15: inn += absf(a[(x + 1) * 16 + y] - a[x * 16 + y]); ni += 1
				if y < 15: inn += absf(a[x * 16 + y + 1] - a[x * 16 + y]); ni += 1
		for d in [1, 2]:   # +x a +y soused (každý šev jednou)
			var n: Vector2i = s + SD.DIRS[d]
			if not w.slots.has(n): continue
			var b: PackedFloat64Array = w.slots[n].hm_f
			var st: Vector2i = SD.DIRS[d]
			for t in 16:
				var o := SD.own(d, t); var c := SD.nb(d, t)
				var dd := absf(a[o.x * 16 + o.y] - b[c.x * 16 + c.y])
				se += dd; ns += 1; mx = maxf(mx, dd)
				# zlom (2. diference) přes šev: |(c − o) − ½((o − o′) + (c′ − c))|, o′ a c′ o bod dál od švu
				var o2: Vector2i = o - st; var c2: Vector2i = c + st
				var k := absf((b[c.x * 16 + c.y] - a[o.x * 16 + o.y]) - 0.5 * ((a[o.x * 16 + o.y] - a[o2.x * 16 + o2.y]) + (b[c2.x * 16 + c2.y] - b[c.x * 16 + c.y])))
				ks += k; kmx = maxf(kmx, k)
		for x in range(1, 15):
			for y in 16:
				ki += absf(a[(x + 1) * 16 + y] - 2.0 * a[x * 16 + y] + a[(x - 1) * 16 + y]); nki += 1
	return {"seam": se / maxi(ns, 1), "seam_max": mx, "inner": inn / maxi(ni, 1),
		"kink": ks / maxi(ns, 1), "kink_max": kmx, "kink_inner": ki / maxi(nki, 1)}

static func top_mat(r: Dictionary, i: int) -> int:
	var h: int = r.hm[i]
	return r.cells[i * 64 + h - 1] if h > 0 else 0

## kolik sloupců má po erozi na povrchu jiný materiál a kolik z nich odkrývá vrstvu (horninu z bs)
static func exposure(w0, w1, p: Dictionary) -> Dictionary:
	var lay := {}
	for e in HR.pool(p): lay[int(e.id)] = true
	var ch := 0; var rock := 0; var dep := 0; var n := 0
	var depid := HR.id_of(str(p.get("ero_deposit", "gravel_sand")))
	for s in w0.order:
		for i in 256:
			var a := top_mat(w0.slots[s], i); var b := top_mat(w1.slots[s], i)
			n += 1
			if a != b:
				ch += 1
				if lay.has(b) and b != depid: rock += 1
				if b == depid: dep += 1
	return {"changed": float(ch) / n, "layer": float(rock) / n, "deposit": float(dep) / n}

static func _grid(w, key: String) -> Array:
	var GW: int = w.w * 16; var GH: int = w.h * 16
	var g := []; g.resize(GW * GH); g.fill(null)
	for s in w.order:
		var r: Dictionary = w.slots[s]
		for i in 256:
			var gi: int = (s.x * 16 + i / 16) * GH + s.y * 16 + i % 16
			match key:
				"hm_f": g[gi] = r.hm_f[i]
				"top": g[gi] = top_mat(r, i)
	return g

## řez vrcholem bloku; y se bere z PŮVODNÍHO povrchu (hm_pre), aby před a po byl stejný řez
static func _section(w, s: Vector2i) -> Dictionary:
	var r: Dictionary = w.slots[s]
	var hh: PackedFloat64Array = r.get("hm_pre", r.hm_f)
	var yp := 8; var best := -1.0
	for i in 256:
		if hh[i] > best: best = hh[i]; yp = i % 16
	var out := []
	for x in 16:
		var col := []
		for z in 64: col.append(r.cells[(x * 16 + yp) * 64 + z])
		out.append(col)
	return {"y": yp, "cells": out}

static func dump_world(w, wat: Dictionary) -> Dictionary:
	var sec := {}
	for k in SECTIONS: sec[k] = _section(w, SECTIONS[k])
	return {"hm_f": _grid(w, "hm_f"), "top": _grid(w, "top"), "depth": Array(wat.depth), "flow": Array(wat.flow), "sections": sec}

static func fmt_w(t: String, v: Dictionary) -> String:
	return "%s: déšť %.0f buněk, odteklo %.0f, v kalužích %.2f m³, mokrých sloupců %d (≥ 2 cm), tok v nejsilnějších 5 %% sloupců %.0f %%, chyba bilance %.5f, %d tiků, %.1f s" % [
		t, v.rain_in, v.out, v.pooled_m3, v.wet_cols, v.flow_top5 * 100.0, v.bal_err, v.ticks, v.ms / 1000.0]

static func run_all(p: Dictionary, out_txt: String, out_json: String) -> PackedStringArray:
	var L := PackedStringArray()
	var t0 := Time.get_ticks_usec()
	var w0 = T.build(p)
	L.append("# E47 voda a eroze po vrstvách (%s)" % Time.get_datetime_string_from_system())
	L.append("svět: 8 bloků v2 (sled 46), stavba %.1f s; eroze %d kapek na blok" % [(Time.get_ticks_usec() - t0) / 1e6, int(p.get("ero_droplets", 3000))])
	var ids := HR.pool(p).map(func(e): return int(e.id))
	var m0 := MT.seams(w0.slots, "hm", ids, T.ignore(p))
	var s0 := surf_seam(w0)
	L.append("před erozí: šev povrchu hm_f %.2f U (max %.2f, uvnitř %.2f), zlom na švu %.2f (max %.2f, uvnitř %.2f) | švy vrstev %.2f (uvnitř %.2f) | povrch buňky šev %.2f" % [s0.seam, s0.seam_max, s0.inner, s0.kink, s0.kink_max, s0.kink_inner, MT.mean_seam(m0), MT.mean_inner(m0), m0.surf_seam])
	var wat0 := VS.run(w0, p)
	L.append(fmt_w("voda před", wat0))
	var data := {"before": dump_world(w0, wat0), "modes": {}, "pal": Array(HR.palette()).map(func(c): return c.to_html(false)),
		"slots": w0.order.map(func(s): return [s.x, s.y, w0.slots[s].bp.shape])}
	for mode in ["blok", "okraj", "svet"]:
		var er := ES.run(w0, p, mode)
		var w1 = er.world; var st: Dictionary = er.rep
		var m1 := MT.seams(w1.slots, "hm", ids, T.ignore(p))
		var s1 := surf_seam(w1)
		var ex := exposure(w0, w1, p)
		L.append("eroze %s: změna povrchu průměr %.2f U, max odběr %.2f U, max nános %.2f U, odběr %.0f / nános %.0f U³ | šev povrchu hm_f %.2f (max %.2f, uvnitř %.2f), zlom na švu %.2f (max %.2f, uvnitř %.2f) | švy vrstev %.2f (uvnitř %.2f) | povrch buňky šev %.2f | jiný materiál na povrchu %.0f %% sloupců, z toho odkrytá vrstva %.0f %%, nános %.0f %% | odneseno minerálů %d | eroze %.0f ms, převzorkování %.0f ms" % [
			mode, st.mean_change, st.max_cut, st.max_dep, st.cut, st.dep, s1.seam, s1.seam_max, s1.inner, s1.kink, s1.kink_max, s1.kink_inner, MT.mean_seam(m1), MT.mean_inner(m1), m1.surf_seam,
			ex.changed * 100, ex.layer * 100, ex.deposit * 100, st.minerals_lost, st.ms_erode, st.ms_resample])
		if mode != "blok":
			var wat1 := VS.run(w1, p)
			L.append(fmt_w("voda po (%s)" % mode, wat1))
			data.modes[mode] = dump_world(w1, wat1)
		else:
			data.modes[mode] = {"hm_f": _grid(w1, "hm_f")}
	# determinismus eroze
	var a = ES.run(w0, p, "okraj").world; var b = ES.run(w0, p, "okraj").world
	L.append("determinismus eroze (okraj) 2×: %s / %s → %s" % [a.hash().left(12), b.hash().left(12), "STEJNÉ" if a.hash() == b.hash() else "RŮZNÉ!"])
	L.append("celkem %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	FileAccess.open(out_txt, FileAccess.WRITE).store_string("\n".join(L) + "\n")
	FileAccess.open(out_json, FileAccess.WRITE).store_string(JSON.stringify(data))
	return L
