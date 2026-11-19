extends RefCounted
## E53 plošný tok maticemi: testy pravidla rozlévání (Jan 22:18–22:24) a srovnání s dnešním tokem (tok.gd) na mapě perf z E51.

const RZ = preload("res://scripts/plosne53/rozliv.gd")
const MV = preload("res://scripts/plosne53/mvoda.gd")
const SC = preload("res://scripts/eroze51/scenare.gd")
const MC = preload("res://scripts/eroze51/mech.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const ME = preload("res://scripts/svet64/mereni.gd")

static func _plane(W: int, H: int) -> PackedFloat64Array:
	var z := PackedFloat64Array(); z.resize(W * H)
	for x in W:
		for y in H: z[x * H + y] = 10.0 - 0.3 * x
	return z

static func _fill(n: int, v: float) -> PackedFloat64Array:
	var a := PackedFloat64Array(); a.resize(n); a.fill(v); return a

static func _widths(q: PackedFloat64Array, H: int, xs: Array) -> Array:
	var r := []
	for x in xs: r.append(RZ.width(q, H, x))
	return r

## --- testy (jednotky jako v Janově příkladu: přítok 4, písek k 0,5, další materiál k 0,25) ---
static func tests(p: Dictionary) -> PackedStringArray:
	var out := PackedStringArray(); var ok := true
	var W := 50; var H := 41; var n := W * H
	var z := _plane(W, H)
	var k := _fill(n, 0.5)
	for x in range(25, W):
		for y in H: k[x * H + y] = 0.25
	var src := _fill(n, 0.0); src[2 * H + 20] = 4.0
	var wall := PackedByteArray(); wall.resize(n)
	var o := {"alpha": float(p.p53_alpha), "v_cell": 50.0, "max_passes": int(p.p53_max)}
	# 1) Jan 22:23: 4 do písku 0,5 → 8 buněk, na 0,25 → 16
	var r := RZ.run(W, H, z, k, src, wall, o)
	var w := _widths(r.q, H, [5, 15, 24, 30, 45])
	var t1: bool = w[1] == 8 and w[2] == 8 and w[3] == 16 and w[4] == 16 and r.steady and absf(float(r.edge_out) - 4.0) < 1e-6
	ok = ok and t1
	out.append("1) Jan 22:23 přítok 4: šířky x=5,15,24 | 30,45 = %s (čekáno 8 | 16), ustáleno za %d průchodů, odtok okrajem %.3f, %.0f ms %s" % [str(w), r.passes, r.edge_out, r.ms, "OK" if t1 else "CHYBA"])
	# 2) málo místa: od x = 25 jen 12 buněk mezi břehy +1 buňka (potřeba 16) → hromadění, hladina stoupá, přeliv
	var z2 := z.duplicate()
	for x in range(25, W):
		for y in H:
			if y < 14 or y > 25: z2[x * H + y] += 1.0
	for a in [float(p.p53_alpha), 0.0]:
		var o2 := o.duplicate(); o2.alpha = a
		var r2 := RZ.run(W, H, z2, k, src, wall, o2)
		var over := 0; var lmax := 0.0; var inb := 0
		for x in range(25, W):
			for y in H:
				var i := x * H + y
				lmax = maxf(lmax, r2.lvl[i])
				if r2.q[i] > 1e-9:
					if y < 14 or y > 25: over += 1
					elif x == 40: inb += 1
		var t2: bool = r2.steady and absf(float(r2.edge_out) - 4.0) < 1e-3 and (lmax >= 1.0)
		ok = ok and t2
		out.append("2) koryto 12 buněk (potřeba 16), α=%.1f: šířka v korytě x=40 %d, mokré buňky za břehy %d, hladina max +%d buňky, %s za %d průchodů, odtok %.3f %s" % [a, inb, over, int(lmax), "ustáleno" if r2.steady else "NEUSTÁLENO", r2.passes, r2.edge_out, "OK" if t2 else "CHYBA"])
	# 3) zpětná vazba koryta: hlína k 0,5 dvě buňky nad žulou (k 0,25), od x = 35 žula na povrchu o 2 buňky níž (stupeň)
	var z3 := z.duplicate(); var zmin := z.duplicate(); var k3 := _fill(n, 0.5); var dep := _fill(n, 0.0)
	for x in W:
		for y in H:
			var i := x * H + y
			if x >= 35: z3[i] -= 2.0; zmin[i] = z3[i]; k3[i] = 0.25
			else: zmin[i] = z3[i] - 2.0
	var hist := []; var tot_p := 0; var tot_ms := 0.0
	for ep in int(p.p53_epoch):
		var o3 := o.duplicate(); o3.depth = dep; o3.alpha = float(p.p53_alpha)
		var r3 := RZ.run(W, H, z3, k3, src, wall, o3)
		tot_p += int(r3.passes); tot_ms += float(r3.ms)
		var w3 := _widths(r3.q, H, [5, 20, 40])
		var dmax := 0.0
		for i in n: dmax = maxf(dmax, dep[i])
		var q20 := 0.0
		for y in H: q20 = maxf(q20, r3.q[20 * H + y])
		hist.append([ep, w3, dmax, q20, r3.passes, r3.steady])
		# eroze celým polem: plná buňka (q = cap) nad prahem 0,5 v měkkém materiálu → o buňku níž
		var cut := 0
		for i in n:
			if r3.q[i] >= maxf(float(r3.cap[i]), 0.5) - 1e-9 and z3[i] > zmin[i] + 1e-9:
				z3[i] -= 1.0; dep[i] += 1.0; cut += 1
				if z3[i] <= zmin[i] + 1e-9: k3[i] = 0.25
		hist[-1].append(cut)
	# kritérium (Jan 22:24): po prvním vyhloubení se tok v hlíně zúží, na žule zůstane široký; další epochy jen hlásíme (viz negativa)
	var w0: Array = hist[0][1]; var w1: Array = hist[1][1]
	var t3: bool = int(w1[1]) < int(w0[1]) and int(w1[2]) >= 16 and int(w0[1]) == 8
	ok = ok and t3
	var hs := PackedStringArray()
	for h in hist: hs.append("ep%d šířky %s hloubka %d q_max(x=20) %.2f (%d průch.%s) vyhloubeno %d" % [h[0], str(h[1]), int(h[2]), h[3], h[4], "" if h[5] else " NEUST.", h[6]])
	out.append("3) zpětná vazba (šířky x=5,20 hlína | x=40 žula): " + " ; ".join(hs) + " → %s, celkem %d průchodů %.0f ms" % ["OK" if t3 else "CHYBA", tot_p, tot_ms])
	out.append("výsledek: " + ("VŠE OK" if ok else "CHYBA"))
	return out

## --- srovnání s tok.gd na mapě perf (E51) ---
static func bench(p: Dictionary) -> Dictionary:
	var N := int(p.p53_n)
	var s := SC.perf(N, int(p.world_seed))
	var W: int = s.W; var H: int = s.H; var n := W * H
	var m0 := ME.mem()
	var t0 := Time.get_ticks_usec()
	var m = MC.new(p, W, H, s.NZ, s.cells, s.wall, s.src)
	var ms_mech := (Time.get_ticks_usec() - t0) / 1000.0
	var st: Dictionary = m.st
	t0 = Time.get_ticks_usec()
	var st2 := TOK.make(st.hm.duplicate(), W, H, st.wall, st.mats, st.src, TOK.losses(p, true), true)
	TOK.route(st2)
	var ms_tok := (Time.get_ticks_usec() - t0) / 1000.0
	var res := {"N": N, "tok_ms": ms_tok, "mech_ms": ms_mech}
	var kmat := {2: float(p.p53_k_dirt), 3: float(p.p53_k_sand), 4: float(p.p53_k_clay)}
	var k := PackedFloat64Array(); k.resize(n)
	var lvl0 := PackedFloat64Array(); lvl0.resize(n)
	var wet_t := PackedByteArray(); wet_t.resize(n)
	var src_total := 0.0; var tok_out := 0.0
	for i in n:
		k[i] = float(kmat.get(m.top_mat(i), float(p.p53_k_rock)))
		lvl0[i] = maxf(0.0, st.fill[i] - st.hm[i])
		wet_t[i] = 1 if TOK.wet(st, i) else 0
		src_total += st.src[i]
		if TOK._border(st, i): tok_out += st.eff[i]
	res.src_lps = src_total; res.tok_out_lps = tok_out
	var ntw := 0
	for i in n: ntw += wet_t[i]
	res.tok_wet = ntw
	var o := {"alpha": float(p.p53_alpha), "v_cell": float(p.p53_vcell), "max_passes": int(p.p53_max)}
	# C rozlévání: studený start (tůně se musí naplnit) a teplý (hladiny tůní z priority-flood)
	for mode in ["cold", "warm"]:
		var oo := o.duplicate()
		if mode == "warm": oo.lvl0 = lvl0
		var r := RZ.run(W, H, st.hm, k, st.src, st.wall, oo)
		res["rz_" + mode] = {"passes": r.passes, "ms": r.ms, "ms_pass": float(r.ms) / maxf(1, r.passes), "steady": r.steady, "out_lps": r.edge_out, "acc_lps": r.acc,
			"jac": _jac(wet_t, r.q, r.lvl, lvl0, mode == "warm", 1e-9), "wet": _cnt(r.q, 1e-9)}
		if mode == "warm": res._rz = r
	# A mělká voda (m, m³/s)
	var b := PackedFloat64Array(); b.resize(n)
	var srcm := PackedFloat64Array(); srcm.resize(n)
	for i in n: b[i] = st.hm[i] * 0.5; srcm[i] = st.src[i] / 1000.0
	var oa := {"dt": float(p.p53_sw_dt), "cf": float(p.p53_sw_cf), "max_steps": int(p.p53_sw_max)}
	for mode in ["cold", "warm"]:
		var sw := MV.make(W, H, b, st.wall, srcm, 0.5)
		if mode == "warm":
			for i in n: sw.d[i] = lvl0[i] * 0.5
		var r := MV.run(sw, oa)
		var dq := PackedFloat64Array(); dq.resize(n)
		for i in n: dq[i] = sw.d[i] - (lvl0[i] * 0.5 if mode == "warm" else 0.0) + (0.0 if sw.d[i] < 0.002 else 1.0)
		var jw := 0; var ju := 0
		for i in n:
			var a: bool = sw.d[i] > 0.002
			if a and wet_t[i] == 1: jw += 1
			if a or wet_t[i] == 1: ju += 1
		res["sw_" + mode] = {"steps": r.steps, "sim_s": r.steps * float(p.p53_sw_dt), "ms": r.ms, "ms_step": float(r.ms) / maxf(1, r.steps), "steady": r.steady,
			"out_lps": float(r.out) * 1000.0, "jac": float(jw) / maxf(1, ju)}
		if mode == "warm": res._sw = sw
	# rychlost pro erozi: mělká voda vs Manning (E51) na korytech (ne tůně)
	var sw2: Dictionary = res._sw
	var ratios := []
	for i in n:
		if wet_t[i] == 0 or st.pw[i] == 1 or m.vel[i] <= 0.0 or sw2.d[i] < 0.002: continue
		var v: float = MV.flow(sw2, i).length() / (0.5 * sw2.d[i])
		ratios.append(v / m.vel[i])
	ratios.sort()
	res.v_ratio = {"n": ratios.size(), "p10": ratios[ratios.size() / 10] if ratios.size() > 0 else 0.0, "med": ratios[ratios.size() / 2] if ratios.size() > 0 else 0.0, "p90": ratios[ratios.size() * 9 / 10] if ratios.size() > 0 else 0.0}
	# B vektorové pole jako funkce: jednotkový průtok q = tok / l na řídicí mřížce, vzorky 1×/2×/4× bilineárně → průtok řezem x = N/2
	res.pole = _field(sw2, W, H)
	# lokální změna: prohloubit buňku koryta (největší průtok mimo tůň a okraj)
	var c := -1; var best := 0.0
	for i in n:
		var x := i / H; var y := i % H
		if x < 16 or y < 16 or x >= W - 16 or y >= H - 16: continue
		if wet_t[i] == 1 and st.pw[i] == 0 and st.eff[i] > best: best = st.eff[i]; c = i
	var mg := int(p.p53_margin)
	var cx := c / H; var cy := c % H
	var hv := PackedFloat64Array([st2.hm[c] - 1.0])
	t0 = Time.get_ticks_usec()
	var u := TOK.update(st2, PackedInt32Array([c]), hv, st2.src, int(p.e51_margin))
	res.loc = {"cell": [cx, cy], "q_lps": best, "tok_ms": (Time.get_ticks_usec() - t0) / 1000.0, "tok_touched": u.touched}
	var rz: Dictionary = res._rz
	var z2: PackedFloat64Array = st.hm.duplicate(); z2[c] -= 1.0
	var ol := o.duplicate(); ol.lvl0 = rz.lvl; ol.state = rz.state
	ol.ax = maxi(cx - mg, 0); ol.bx = mini(cx + mg, W - 1); ol.ay = maxi(cy - mg, 0); ol.by = mini(cy + mg, H - 1)
	var rl := RZ.run(W, H, z2, k, st.src, st.wall, ol)
	res.loc.rz = {"passes": rl.passes, "ms": rl.ms, "steady": rl.steady, "cells": rl.cells}
	var b2 := b.duplicate(); b2[c] -= 0.5; sw2.b = b2
	var oal := oa.duplicate(); oal.ax = ol.ax; oal.bx = ol.bx; oal.ay = ol.ay; oal.by = ol.by
	var rs := MV.run(sw2, oal)
	res.loc.sw = {"steps": rs.steps, "ms": rs.ms, "steady": rs.steady}
	# paměť: bajty na buňku podle polí (float64) + změřený peak procesu
	res.mem = {"rz_B_cell": 10 * 8 + 16 * 8 + 4 + 1, "sw_B_cell": 4 * 8 + 4 * 8 + 1, "tok_B_cell": 6 * 8 + 4 + 4 + 4 + 1 + 1 + 1,
		"peak_mb": ME.mem().peak_mb, "start_mb": m0.peak_mb}
	res.erase("_rz"); res.erase("_sw")
	return res

static func _cnt(q: PackedFloat64Array, eps: float) -> int:
	var c := 0
	for v in q: if v > eps: c += 1
	return c

static func _jac(wt: PackedByteArray, q: PackedFloat64Array, lvl: PackedFloat64Array, lvl0: PackedFloat64Array, warm: bool, eps: float) -> float:
	var a := 0; var u := 0
	for i in wt.size():
		var w := q[i] > eps or lvl[i] > 0.0
		if w and wt[i] == 1: a += 1
		if w or wt[i] == 1: u += 1
	return float(a) / maxf(1, u)

static func _field(sw: Dictionary, W: int, H: int) -> Dictionary:
	var n := W * H
	var qx := PackedFloat64Array(); qx.resize(n); var qy := PackedFloat64Array(); qy.resize(n)
	for i in n:
		var v := MV.flow(sw, i) / 0.5
		qx[i] = v.x; qy[i] = v.y
	var xc := W / 2
	# „pravda“: tok přes hrany mezi sloupci xc−1 a xc
	var f: PackedFloat64Array = sw.f; var truth := 0.0
	for y in H: truth += f[4 * ((xc - 1) * H + y)] - f[4 * (xc * H + y) + 1]
	var r := {"truth_lps": truth * 1000.0}
	for res_k: int in [1, 2, 4]:
		var Q := 0.0; var wid := 0.0; var l: float = 0.5 / res_k
		for a in H * res_k:
			var yy: float = (a + 0.5) / res_k - 0.5   # souřadnice vzorku v buňkách řídicí mřížky
			var v := _bil(qx, H, float(xc) - 0.5, yy)
			Q += v * l
			if absf(v) > 1e-4: wid += l
		r["r%d" % res_k] = {"q_lps": Q * 1000.0, "sirka_m": wid}
	return r

static func _bil(a: PackedFloat64Array, H: int, x: float, y: float) -> float:
	var x0 := int(floor(x)); var y0 := clampi(int(floor(y)), 0, H - 1); var y1 := mini(y0 + 1, H - 1)
	var fx := x - x0; var fy := clampf(y - floor(y), 0.0, 1.0)
	if y < 0.0: fy = 0.0
	var a00 := a[x0 * H + y0]; var a01 := a[x0 * H + y1]; var a10 := a[(x0 + 1) * H + y0]; var a11 := a[(x0 + 1) * H + y1]
	return lerpf(lerpf(a00, a01, fy), lerpf(a10, a11, fy), fx)
