extends RefCounted
## E50 voda na jemné mřížce celého světa: W = T · nv sloupců na stranu (nv = s64_voda_n, dělitel s64_n), výšky v buňkách
## vodní mřížky (buňka cm = 8/nv m). Stejné moduly jako E47c/d: prameny.gd, strze.gd (tok.gd), podzemi.gd.
## Parametry v buňkách / na sloupec se přepočtou f = nv/16 (vzdálenosti × f, průtok na sloupec / f², objem buňky / f³).

const PRM = preload("res://scripts/voda/prameny.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const M = preload("res://scripts/svet64/mereni.gd")

static func scaled(p: Dictionary, nv: int) -> Dictionary:
	var f := float(nv) / 16.0
	var q := p.duplicate(true)
	q.voda_cell_m = 8.0 / nv
	q.pram_dist = float(p.pram_dist) * f
	q.ug_hloubka = int(round(float(p.ug_hloubka) * f))
	q.tok_margin = int(round(float(p.tok_margin) * f))
	q.pit_drain_q = float(p.pit_drain_q) / (f * f)
	q.ponor_inf_q = float(p.ponor_inf_q) / (f * f)
	q.ponor_cap_q = float(p.ponor_cap_q) / (f * f)
	q.ug_leak_q = float(p.ug_leak_q) / (f * f)
	q.ug_cell_m3 = 0.125 / (f * f * f)
	return q

## fine: slot → {cells, hm, hf}; vrací {W, hm (spojitý povrch), wall, top, mat3 (jen s podzemím), mat_d}
static func grid(fine: Dictionary, T: int, n: int, nv: int, with3d: bool) -> Dictionary:
	var k := n / nv; var NZ := 4 * n; var NZv := 4 * nv
	var W := T * nv
	var g := PackedFloat64Array(); g.resize(W * W)
	var top := PackedInt32Array(); top.resize(W * W)
	var wall := PackedByteArray(); wall.resize(W * W); wall.fill(1)
	var mat3 := PackedByteArray()
	if with3d: mat3.resize(W * W * NZv)
	for s in fine:
		var b: Dictionary = fine[s]
		var cells: PackedByteArray = b.cells
		for x in nv:
			for y in nv:
				var fi := (x * k + k / 2) * n + y * k + k / 2
				var gi: int = (s.x * nv + x) * W + s.y * nv + y
				wall[gi] = 0
				g[gi] = float(b.hf[fi]) / k
				top[gi] = (int(b.hm[fi]) + k - 1) / k
				if with3d:
					var base := gi * NZv; var fb := fi * NZ
					for z in NZv: mat3[base + z] = cells[fb + z * k + k / 2]
	var mat_d := func(gi: int, d: int) -> int:   # d v buňkách řídicí mřížky (0,5 m) jako v E47c
		var gx := gi / W; var gy := gi % W
		var s := Vector2i(gx / nv, gy / nv)
		var b: Dictionary = fine[s]
		var fi := ((gx % nv) * k + k / 2) * n + (gy % nv) * k + k / 2
		var z := clampi(int(b.hm[fi]) - 1 - d * n / 16, 0, NZ - 1)
		return int(b.cells[fi * NZ + z])
	return {"W": W, "hm": g, "wall": wall, "top": top, "mat3": mat3, "NZ": NZv, "mat_d": mat_d}

static func run(fine: Dictionary, T: int, p: Dictionary) -> Dictionary:
	var n := int(p.s64_n); var nv := int(p.s64_voda_n)
	var q := scaled(p, nv)
	var with3d := bool(p.s64_podzemi)
	var nu := int(p.get("s64_ug_n", nv))   # E52 (Jan 21:14): podzemí na hrubší mřížce, povrch dál nv
	var ms := {}
	var t0 := Time.get_ticks_usec()
	var G := grid(fine, T, n, nv, with3d and nu == nv)
	ms["mřížka"] = M.ms(t0)
	var W: int = G.W
	t0 = Time.get_ticks_usec()
	var springs := PRM.find(G.hm, W, W, G.wall, G.mat_d, q)
	var src := PRM.src(springs, G.hm, W * W)
	ms["prameny"] = M.ms(t0)
	var dd := int(round(float(q.strz_target_m) / float(q.voda_cell_m)))
	var mat_d: Callable = G.mat_d
	var mat_at := func(gi: int) -> int: return mat_d.call(gi, dd * 16 / nv)
	t0 = Time.get_ticks_usec()
	var h1: PackedFloat64Array = G.hm.duplicate()
	var r1 := SZ.run(h1, W, W, G.wall, mat_at, q, src)
	ms["povrch (koryto + strže)"] = M.ms(t0)
	var out := {"W": W, "nv": nv, "springs": springs, "surf": r1, "hm_post": h1, "ms": ms, "mem_grid": M.mem()}
	if with3d:
		t0 = Time.get_ticks_usec()
		var ug: Dictionary
		if nu == nv: ug = UG.make(W, W, G.NZ, G.mat3, G.top, G.wall, q)
		else:
			var Gu := grid(fine, T, n, nu, true)
			var alg = load("res://scripts/podzemi52/ug_pole.gd") if String(p.get("s64_ug_alg", "pole")) == "pole" else load("res://scripts/podzemi52/ug_slovnik.gd")
			var inner: Dictionary = alg.make(Gu.W, Gu.W, Gu.NZ, Gu.mat3, Gu.top, Gu.wall, scaled(p, nu))
			ug = load("res://scripts/podzemi52/ug_mrizka.gd").make(inner, W, G.hm, G.wall, nv / nu)
		var h2: PackedFloat64Array = G.hm.duplicate()
		var r2 := SZ.run(h2, W, W, G.wall, mat_at, q, src, ug)
		var tot := M.ms(t0)
		ms["podzemí: povrch + podzemí"] = tot
		ms["podzemí: navíc proti povrchu"] = tot - float(ms["povrch (koryto + strže)"])
		out.both = r2; out.hm_post = h2
		out.mem_ug = M.mem()
	return out

## souhrn čísel jednoho výsledku strze.run
static func summary(r: Dictionary, cm: float) -> Dictionary:
	var st: Dictionary = r.st
	var wet := 0; var carved := 0; var ds := []
	var eff: PackedFloat64Array = r.eff
	for i in eff.size():
		if eff[i] >= float(st.L.thr): wet += 1
		if r.chan[i] == 1: carved += 1; ds.append(r.depth[i] * cm)
	ds.sort()
	var eq := 0.0
	for e in r.edge: eq += float(e.q)
	var uq := 0.0
	for u in st.under: uq += float(u.q)
	var ponds := TOK.ponds(st, cm * cm, cm, false).filter(func(x): return not x["suchá"])
	var pv := 0.0
	for x in ponds: pv += x.cells.size()
	var bodies: Array = st.get("ug_bodies", [])
	var bcells := 0
	for b in bodies: bcells += int(b.get("cells", 0)) if typeof(b.get("cells", 0)) == TYPE_INT else 0
	return {"wet": wet, "carved": carved, "med_m": ds[ds.size() / 2] if not ds.is_empty() else 0.0, "max_m": ds[-1] if not ds.is_empty() else 0.0,
		"falls": r.falls.size(), "edge_n": r.edge.size(), "edge_q": eq, "under_n": st.under.size(), "under_q": uq,
		"ponds": ponds.size(), "pond_m3": pv, "lost": float(r.lost), "bodies": bodies.size(), "body_cells": bcells}
