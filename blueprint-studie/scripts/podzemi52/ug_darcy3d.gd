extends RefCounted
## E52 varianta 5 podle Jana (22:40): ustálený Darcy na voxelové mřížce, konečné objemy.
##  K buňky = perm ze sdílené tabulky · K0 (dutina/kras = K_dut); K stěny = harmonický průměr 2·Ka·Kb/(Ka+Kb) (0, je-li jedna nepropustná)
##  Q_AB = K_AB · S / L · (P_A − P_B), S = c², L = c; v každé buňce ΣQ = 0 → řídká soustava A p = b, řeší CG (Jacobi předpodmínění)
##  okrajové podmínky: pevná výška na vstupu (buňky pod odtokem tůně = hladina tůně) a na výstupech (výchoz na povrch,
##  okraj ostrova = otevřeno, P = výška buňky), jinde nulový tok. Souvislost tělesa = BFS (ug_pole, ploché pole).
##  Plnění v čase zůstává po vrstvách z (objem pórů / přítok) z BFS, žádná Richardsova rovnice ani LBM.
## Běží uvnitř ug_mrizka (hrubá mřížka 32 / blok). Rozdělení odtoku mezi výstupy z Darcyho, celkový čistý odtok z BFS (q − průsak).

const P = preload("res://scripts/podzemi52/ug_pole.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const SELF = preload("res://scripts/podzemi52/ug_darcy3d.gd")

static func make(W: int, H: int, NZ: int, mat, top: PackedInt32Array, wall: PackedByteArray, p: Dictionary) -> Dictionary:
	var c := P.make(W, H, NZ, mat, top, wall, p)
	var k0 := float(p.get("p52_k0", 1e-3)); var kd := float(p.get("p52_k_dut", 1.0))
	var kl := PackedFloat32Array(); kl.resize(256)
	var t := VS.table()
	for m in 256:
		var e: Array = t.get(m, [0.0])
		kl[m] = kd if (m == 0 or P.UG._soluble(m)) else float(e[0]) * k0
	c.klut = kl; c.cg_it = int(p.get("p52_cg_it", 5000)); c.cg_tol = float(p.get("p52_cg_tol", 1e-6))
	var idx := PackedInt32Array(); idx.resize(W * H * NZ); idx.fill(-1); c.idx = idx   # buňka → neznámá (−1), −2 = pevná výška
	c.cm = float(p.get("voda_cell_m", 0.5))   # už škálované na mřížku podzemí (voda64.scaled)
	c.impl = SELF; c.stats = {"solve_ms": 0.0, "solves": 0, "cells": 0, "cg_ms": 0.0, "cg_it": [], "unknowns": 0}
	return c

static func entry(ctx: Dictionary, col: int) -> int:
	return P.entry(ctx, col)

static func touched(ctx: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool:
	return P.touched(ctx, cache, ch, hv)

static func solve(ctx: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var r := P.solve(ctx, entries, q, excl)
	var t0 := Time.get_ticks_usec()
	var W: int = ctx.W; var H: int = ctx.H; var NZ: int = ctx.NZ
	var mat: PackedByteArray = ctx.mat; var top: PackedInt32Array = ctx.top; var wall: PackedByteArray = ctx.wall
	var vis: PackedByteArray = ctx.vis; var g: int = r.gen; var idx: PackedInt32Array = ctx.idx
	var kl: PackedFloat32Array = ctx.klut
	var lst: PackedInt32Array = r.list
	var cm: float = ctx.cm
	# pevné výšky: vstup = hladina tůně (vrch sloupce vstupu), výstupy = buňka s otevřenou stěnou (vzduch nad terénem / okraj mapy)
	var hfix := {}   # buňka → [výška m, typ]
	for e in entries:
		hfix[e] = [float(top[e / NZ]) * cm, "vstup"]
	for v in lst:
		if hfix.has(v): continue
		var col := v / NZ; var z := v - col * NZ; var x := col / H; var y := col - x * H
		if x == 0 or y == 0 or x == W - 1 or y == H - 1: hfix[v] = [(z + 0.5) * cm, "okraj"]; continue
		for d in 4:
			var qx := x + (1 if d == 0 else (-1 if d == 1 else 0)); var qy := y + (1 if d == 2 else (-1 if d == 3 else 0))
			var c2 := qx * H + qy
			if wall[c2] == 0 and z >= top[c2] and not excl.has(c2): hfix[v] = [(z + 0.5) * cm, "povrch"]; break
		if not hfix.has(v) and z + 1 < NZ and z + 1 >= top[col] and not excl.has(col): hfix[v] = [(z + 0.5) * cm, "povrch"]
	# neznámé
	var unk := PackedInt32Array()
	for v in lst:
		if hfix.has(v): idx[v] = -2
		else: idx[v] = unk.size(); unk.append(v)
	var nu := unk.size()
	# CSR: soused j (neznámá) nebo pevná (do b)
	var rp := PackedInt32Array(); rp.resize(nu + 1)
	var cj := PackedInt32Array(); var cv := PackedFloat64Array()
	var diag := PackedFloat64Array(); diag.resize(nu)
	var b := PackedFloat64Array(); b.resize(nu)
	var HZ := H * NZ
	for a in nu:
		var v := unk[a]; rp[a] = cj.size()
		var ka: float = kl[mat[v]]
		for u in _nb6(v, W, H, NZ):
			if u < 0 or vis[u] != g: continue
			var kb: float = kl[mat[u]]
			if ka <= 0.0 or kb <= 0.0: continue
			var kf := 2.0 * ka * kb / (ka + kb) * cm   # K · S / L = K · c² / c
			diag[a] += kf
			if idx[u] >= 0: cj.append(idx[u]); cv.append(kf)
			else: b[a] += kf * float(hfix[u][0])
	rp[nu] = cj.size()
	# CG s Jacobiho předpodmíněním: A p = b, A = diag − offdiag
	var pv := PackedFloat64Array(); pv.resize(nu)
	for a in nu: pv[a] = (float(unk[a] % NZ) + 0.5) * cm   # start: výška buňky (tlak 0); jen voda ze vstupu ho zvedá
	var res := _cg(rp, cj, cv, diag, b, pv, int(ctx.cg_it), float(ctx.cg_tol))
	# průtoky z pevných buněk (výstup > 0 = voda vytéká)
	var outs := {}; var qin := 0.0; var qnet := 0.0
	for v in hfix:
		var hv: float = hfix[v][0]; var ty: String = hfix[v][1]; var kv: float = kl[mat[v]]
		if kv <= 0.0: continue
		var qq := 0.0
		for u in _nb6(v, W, H, NZ):
			if u < 0 or vis[u] != g: continue
			var kb: float = kl[mat[u]]
			if kb <= 0.0: continue
			var hu: float = pv[idx[u]] if idx[u] >= 0 else float(hfix[u][0])
			qq += 2.0 * kv * kb / (kv + kb) * cm * (hu - hv)
		if ty == "vstup": qin -= qq
		else: qnet += qq
		if ty != "vstup" and qq > 0.0:
			var key := "%s:%d" % [ty, v / NZ]
			outs[key] = float(outs.get(key, 0.0)) + qq
	for v in lst: idx[v] = -1
	var tot := 0.0
	for kk in outs: tot += float(outs[kk])
	var by := {"okraj": 0.0, "povrch": 0.0}
	var lst2 := []
	for kk in outs:
		var fr := float(outs[kk]) / maxf(tot, 1e-30)
		by[String(kk).get_slice(":", 0)] += fr
		lst2.append([kk, fr])
	lst2.sort_custom(func(a, c): return a[1] > c[1])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	ctx.stats.cg_ms += ms; ctx.stats.cg_it.append(res.it); ctx.stats.unknowns = maxi(int(ctx.stats.unknowns), nu)
	r.darcy3d = {"unknowns": nu, "fixed": hfix.size(), "it": res.it, "rel_res": res.rel, "ms": ms, "q_darcy_m3s": qin, "q_out_m3s": tot,
		"bal": (qnet - qin) / maxf(absf(qin), 1e-30), "q_net_m3s": qnet, "podil": by, "n_out": outs.size(), "top": lst2.slice(0, 8), "nnz": cj.size()}
	r.erase("list")
	return r

static func _nb6(v: int, W: int, H: int, NZ: int) -> PackedInt32Array:
	var col := v / NZ; var z := v - col * NZ; var x := col / H; var y := col - x * H
	return PackedInt32Array([v + H * NZ if x < W - 1 else -1, v - H * NZ if x > 0 else -1, v + NZ if y < H - 1 else -1,
		v - NZ if y > 0 else -1, v + 1 if z < NZ - 1 else -1, v - 1 if z > 0 else -1])

static func _cg(rp: PackedInt32Array, cj: PackedInt32Array, cv: PackedFloat64Array, dg: PackedFloat64Array, b: PackedFloat64Array, x: PackedFloat64Array, maxit: int, tol: float) -> Dictionary:
	var n := dg.size()
	var r := PackedFloat64Array(); r.resize(n); var z := PackedFloat64Array(); z.resize(n)
	var p := PackedFloat64Array(); p.resize(n); var ap := PackedFloat64Array(); ap.resize(n)
	var bn := 0.0
	for i in n: bn += b[i] * b[i]
	bn = sqrt(maxf(bn, 1e-300))
	for i in n:
		var s := dg[i] * x[i]
		for k in range(rp[i], rp[i + 1]): s -= cv[k] * x[cj[k]]
		r[i] = b[i] - s; z[i] = r[i] / dg[i] if dg[i] > 0.0 else 0.0; p[i] = z[i]
	var rz := 0.0
	for i in n: rz += r[i] * z[i]
	var it := 0; var rel := 1.0
	while it < maxit:
		it += 1
		var pap := 0.0
		for i in n:
			var s := dg[i] * p[i]
			for k in range(rp[i], rp[i + 1]): s -= cv[k] * p[cj[k]]
			ap[i] = s; pap += p[i] * s
		if pap <= 0.0: break
		var al := rz / pap; var rn := 0.0
		for i in n:
			x[i] += al * p[i]; r[i] -= al * ap[i]; rn += r[i] * r[i]
		rel = sqrt(rn) / bn
		if rel < tol: break
		var rz2 := 0.0
		for i in n: z[i] = r[i] / dg[i] if dg[i] > 0.0 else 0.0; rz2 += r[i] * z[i]
		var be := rz2 / rz; rz = rz2
		for i in n: p[i] = z[i] + be * p[i]
	return {"it": it, "rel": rel}
