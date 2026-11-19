extends RefCounted
## E53 C: pravidlo rozlévání (Jan 22:18–22:24) jako průchody přes celé pole (Jacobi: každý průchod čte jen minulý stav).
## Buňka vodu nese, nebo ne. Propustnost k = kolik buňka přenese za jednotku času (průchod). Dopředu (směr z gradientu
## hladiny S = z + lvl) jde min(přítok, cap), cap = k · (1 + α · hloubka). Čerstvý přebytek se dělí na obě boční strany
## v celých násobcích k (strop poloviny na stranu +90°). Boční paket pokračuje stejným směrem do další buňky, dokud ho
## volná kapacita nepohltí. Zeď / vyšší břeh na obou stranách → přebytek se hromadí (V roste, lvl = floor(V / v_cell)),
## hladina stoupá, až přeteče. Šířka toku tak vyjde ceil(Q / cap) celých buněk.

const DX := [1, 1, 0, -1, -1, -1, 0, 1]
const DY := [0, 1, 1, 1, 0, -1, -1, -1]

## z, k, src: n = W·H (index x·H + y). opts: alpha, v_cell, max_passes, tol, lvl0 (počáteční hladiny), depth (vyhloubení).
## Vrací {q, lvl, passes, edge_out, ms, steady, acc}.
static func run(W: int, H: int, z: PackedFloat64Array, k: PackedFloat64Array, src: PackedFloat64Array, wall: PackedByteArray, o: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n := W * H
	var alpha := float(o.get("alpha", 0.5)); var vcell := float(o.get("v_cell", 50.0))
	var maxp := int(o.get("max_passes", 3000)); var tol := float(o.get("tol", 1e-9))
	var lvl: PackedFloat64Array = o.get("lvl0", PackedFloat64Array()).duplicate()
	if lvl.size() != n: lvl.resize(n)
	var dep: PackedFloat64Array = o.get("depth", PackedFloat64Array())
	if dep.size() != n: dep = PackedFloat64Array(); dep.resize(n)
	var V := PackedFloat64Array(); V.resize(n)
	for i in n: V[i] = lvl[i] * vcell
	var fin := PackedFloat64Array(); fin.resize(n)
	var lat := PackedFloat64Array(); lat.resize(8 * n)   # lat[s·n + i] = paket v buňce i, pohyb ve směru s
	if o.has("state"):   # pokračovat z ustáleného stavu (lokální přepočet po změně)
		fin = o.state.fin.duplicate(); lat = o.state.lat.duplicate(); V = o.state.V.duplicate()
	# okno [ax..bx]×[ay..by]: mění se jen buňky okna, prstenec kolem (r*) dál posílá svůj zmrazený výstup
	var ax := int(o.get("ax", 0)); var bx := int(o.get("bx", W - 1)); var ay := int(o.get("ay", 0)); var by := int(o.get("by", H - 1))
	var rx0 := maxi(ax - 1, 0); var rx1 := mini(bx + 1, W - 1); var ry0 := maxi(ay - 1, 0); var ry1 := mini(by + 1, H - 1)
	var cells := PackedInt32Array(); var ring := PackedInt32Array()
	for x in range(rx0, rx1 + 1):
		for y in range(ry0, ry1 + 1):
			if x >= ax and x <= bx and y >= ay and y <= by: cells.append(x * H + y)
			ring.append(x * H + y)
	var nfin := PackedFloat64Array(); nfin.resize(n)
	var nlat := PackedFloat64Array(); nlat.resize(8 * n)
	var S := PackedFloat64Array(); S.resize(n)
	var cap := PackedFloat64Array(); cap.resize(n)
	var dirn := PackedInt32Array(); dirn.resize(n)
	var passes := 0; var steady := false; var edge_out := 0.0; var acc_last := 0.0
	while passes < maxp:
		passes += 1
		# průchod 1: hladina, kapacita, směr z gradientu (každá buňka sama, čte jen S sousedů)
		if passes == 1:
			for i in n: S[i] = z[i] + lvl[i]
		for i in ring:
			S[i] = z[i] + lvl[i]
			cap[i] = 0.0 if wall[i] == 1 else k[i] * (1.0 + alpha * (lvl[i] + dep[i]))
		for i in ring:
			var x := i / H; var y := i % H
			var best := 0.0; var bd := -1
			if wall[i] == 0:
				for d in 8:
					var qx: int = x + DX[d]; var qy: int = y + DY[d]
					var g: float
					if qx < 0 or qy < 0 or qx >= W or qy >= H: g = 1e9   # okraj = odtok
					else:
						var j := qx * H + qy
						if wall[j] == 1: continue
						g = (S[i] - S[j]) / (1.4142 if d % 2 == 1 else 1.0)
					if g > best + 1e-12: best = g; bd = d
			dirn[i] = bd
		# průchod 2: rozdělení (rozptyl do nových polí)
		for i in ring:
			nfin[i] = src[i]
			for s in 8: nlat[s * n + i] = 0.0
		var acc := 0.0; var eo := 0.0
		for i in ring:
			if wall[i] == 1: continue
			var inside := ring.size() == cells.size() or ((i / H) >= ax and (i / H) <= bx and (i % H) >= ay and (i % H) <= by)
			var lin := 0.0
			for s in 8: lin += lat[s * n + i]
			var tot := fin[i] + lin
			if tot <= 1e-12: continue
			var c := cap[i]
			var fwd := minf(tot, c); var left := tot - fwd
			var fresh := minf(left, maxf(fin[i] - c, 0.0)); var latl := left - fresh
			var x := i / H; var y := i % H
			var d := dirn[i]
			if d < 0:
				if inside: V[i] += fwd; acc += fwd
			else:
				var qx: int = x + DX[d]; var qy: int = y + DY[d]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: eo += fwd
				else: nfin[qx * H + qy] += fwd
			if latl > 1e-12:
				var fr := latl / lin
				for s in 8:
					var pk := lat[s * n + i] * fr
					if pk <= 0.0: continue
					var j := _side(W, H, z, wall, S[i], x, y, s)
					if j == -2: eo += pk
					elif j < 0:
						if inside: V[i] += pk; acc += pk
					else: nlat[s * n + j] += pk
			if fresh > 1e-12:
				var dd := maxi(d, 0)
				var sp := (dd + 2) % 8; var sm := (dd + 6) % 8
				var jp := _side(W, H, z, wall, S[i], x, y, sp); var jm := _side(W, H, z, wall, S[i], x, y, sm)
				var u := roundf(fresh / maxf(k[i], 1e-9))
				var h1 := minf(ceilf(u / 2.0) * k[i], fresh); var h2 := fresh - h1
				if jp == -1 and jm == -1:
					if inside: V[i] += fresh; acc += fresh
				else:
					if jp == -1: h2 += h1; h1 = 0.0
					if jm == -1: h1 += h2; h2 = 0.0
					if h1 > 0.0:
						if jp == -2: eo += h1
						else: nlat[sp * n + jp] += h1
					if h2 > 0.0:
						if jm == -2: eo += h2
						else: nlat[sm * n + jm] += h2
		# hladina z nahromaděného objemu (celé buňky)
		var ch := 0.0
		for i in cells:
			if V[i] > 0.0: lvl[i] = maxf(lvl[i], floorf(V[i] / vcell))
			ch = maxf(ch, absf(nfin[i] - fin[i])); fin[i] = nfin[i]
			for s in 8:
				ch = maxf(ch, absf(nlat[s * n + i] - lat[s * n + i])); lat[s * n + i] = nlat[s * n + i]
		edge_out = eo; acc_last = acc
		if ch < tol and acc < tol: steady = true; break
	var q := PackedFloat64Array(); q.resize(n)
	for i in n:
		q[i] = fin[i]
		for s in 8: q[i] += lat[s * n + i]
	return {"q": q, "lvl": lvl, "passes": passes, "edge_out": edge_out, "acc": acc_last, "steady": steady,
		"ms": (Time.get_ticks_usec() - t0) / 1000.0, "dir": dirn, "cap": cap,
		"state": {"fin": fin, "lat": lat, "V": V}, "cells": cells.size()}

## soused do strany s: index, -1 = nelze (zeď / vyšší břeh), -2 = mimo mapu (odtok)
static func _side(W: int, H: int, z: PackedFloat64Array, wall: PackedByteArray, si: float, x: int, y: int, s: int) -> int:
	var qx: int = x + DX[s]; var qy: int = y + DY[s]
	if qx < 0 or qy < 0 or qx >= W or qy >= H: return -2
	var j := qx * H + qy
	if wall[j] == 1 or z[j] > si + 1e-9: return -1
	return j

## šířka toku v řezu x (počet mokrých buněk) a hodnoty
static func width(q: PackedFloat64Array, H: int, x: int) -> int:
	var c := 0
	for y in H:
		if q[x * H + y] > 1e-9: c += 1
	return c
