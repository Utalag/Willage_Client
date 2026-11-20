extends RefCounted
## E92: mírnější svahy herního ostrova (příznak p92_svah, výchozí VYPNUTO) a statistiky sklonu.
## limit(): stejný algoritmus jako E56 (scripts/teren/svet/svah.gd, tepelná eroze, hmota se zachová), ale vrací nové pole
## (PackedFloat64Array v Dictionary se do funkce předává hodnotou). Výška v buňkách 0,5 m, rozteč bodů dx_m.

const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

static func limit(src: PackedFloat64Array, R: int, max_slope: float, passes: int, dx_m := 0.5, cell_m := 0.5) -> Dictionary:
	var hm := src.duplicate()
	var d := PackedFloat64Array(); d.resize(R * R)
	var it := 0; var worst := 0.0
	var lim0 := max_slope * dx_m / cell_m
	while it < passes:
		it += 1
		d.fill(0.0); worst = 0.0
		for x in R:
			for y in R:
				var i := x * R + y
				for k in 8:
					var qx: int = x + DX[k]; var qy: int = y + DY[k]
					if qx < 0 or qy < 0 or qx >= R or qy >= R: continue
					var j := qx * R + qy
					var lim := lim0 * (1.4142 if k >= 4 else 1.0)
					var e := hm[i] - hm[j] - lim
					if e > 0.0:
						worst = maxf(worst, e)
						d[i] -= e * 0.125; d[j] += e * 0.125
		for i in R * R: hm[i] += d[i]
		if worst < 0.02: break
	return {"hm": hm, "passes": it, "worst_cells": worst}

static func smooth(src: PackedFloat64Array, R: int, n: int, w: float) -> PackedFloat64Array:
	var hm := src.duplicate()
	var t := PackedFloat64Array(); t.resize(R * R)
	for k in n:
		for x in R:
			for y in R:
				var s := 0.0; var c := 0
				for qx in range(maxi(x - 1, 0), mini(x + 2, R)):
					for qy in range(maxi(y - 1, 0), mini(y + 2, R)): s += hm[qx * R + qy]; c += 1
				t[x * R + y] = (1.0 - w) * hm[x * R + y] + w * s / c
		for i in R * R: hm[i] = t[i]
	return hm

## hook pro ostrov_teren.build: povrch šablony (ctx.raw, 16 × 16 bodů po 0,5 m) → omezený
static func apply(ctx: Dictionary, p: Dictionary) -> void:
	if not bool(p.get("p92_svah", false)):
		return
	var raw: PackedFloat64Array = ctx.raw
	var n := int(p.get("p92_hladit", 0))
	if n > 0:
		raw = smooth(raw, 16, n, float(p.get("p92_hladit_w", 0.5)))
	var r := limit(raw, 16, float(p.get("p92_max_sklon", 1.0)), int(p.get("p92_pasy", 200)))
	ctx.raw = r.hm
	ctx.rep["p92"] = {"passes": r.passes, "worst_cells": r.worst_cells}

## statistiky výškové mapy W × H (výšky v metrech, rozteč dx_m): sklon ze 4 sousedů (největší rozdíl), schod, reliéf
static func stats(h: PackedFloat64Array, W: int, H: int, dx_m: float, mask := PackedByteArray()) -> Dictionary:
	var sl := PackedFloat64Array()
	var step := 0.0
	var lo := 1e9; var hi := -1e9
	var n30 := 0; var n45 := 0; var n60 := 0
	for x in W:
		for y in H:
			var i := x * H + y
			if mask.size() > 0 and mask[i] == 0: continue
			lo = minf(lo, h[i]); hi = maxf(hi, h[i])
			var dmax := 0.0
			for k in 4:
				var qx: int = x + DX[k]; var qy: int = y + DY[k]
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if mask.size() > 0 and mask[j] == 0: continue
				dmax = maxf(dmax, absf(h[i] - h[j]))
			step = maxf(step, dmax)
			var a := rad_to_deg(atan(dmax / dx_m))
			sl.append(a)
			if a > 30.0: n30 += 1
			if a > 45.0: n45 += 1
			if a > 60.0: n60 += 1
	sl.sort()
	var n := sl.size()
	return {"bodu": n, "sklon_p50": snappedf(sl[n / 2], 0.1), "sklon_p90": snappedf(sl[int(n * 0.9)], 0.1),
		"sklon_p95": snappedf(sl[int(n * 0.95)], 0.1), "sklon_max": snappedf(sl[n - 1], 0.1),
		"nad_30_pct": snappedf(100.0 * n30 / n, 0.1), "nad_45_pct": snappedf(100.0 * n45 / n, 0.1), "nad_60_pct": snappedf(100.0 * n60 / n, 0.1),
		"schod_max_m": snappedf(step, 0.01), "relief_m": snappedf(hi - lo, 0.01), "min_m": snappedf(lo, 0.01), "max_m": snappedf(hi, 0.01),
		"hist_10st": _hist(sl), "grad": grad(h, W, H, dx_m, mask)}

## sklon z centrálních rozdílů přes 2 rozteče (odstraní schody kvantování 0,5 m): p50 / p95, podíl nad 30° a 45°;
## sev = podíl strmých (> 45°) bodů v pásu 2 bodů kolem vnitřních švů bloků po 16 (jen pro ostrov)
static func grad(h: PackedFloat64Array, W: int, H: int, dx_m: float, mask := PackedByteArray()) -> Dictionary:
	var sl := PackedFloat64Array()
	var n30 := 0; var n45 := 0; var s45 := 0
	for x in range(1, W - 1):
		for y in range(1, H - 1):
			var gx := (h[(x + 1) * H + y] - h[(x - 1) * H + y]) / (2.0 * dx_m)
			var gy := (h[x * H + y + 1] - h[x * H + y - 1]) / (2.0 * dx_m)
			var a := rad_to_deg(atan(sqrt(gx * gx + gy * gy)))
			sl.append(a)
			if a > 30.0: n30 += 1
			if a > 45.0:
				n45 += 1
				if W == 32 and (absi(x - 16) <= 2 or absi(y - 16) <= 2 or absi(x - 15) <= 1 or absi(y - 15) <= 1): s45 += 1
	sl.sort()
	var n := sl.size()
	return {"p50": snappedf(sl[n / 2], 0.1), "p95": snappedf(sl[int(n * 0.95)], 0.1), "max": snappedf(sl[n - 1], 0.1),
		"nad_30_pct": snappedf(100.0 * n30 / n, 0.1), "nad_45_pct": snappedf(100.0 * n45 / n, 0.1),
		"strme_u_svu_pct": snappedf(100.0 * s45 / maxi(n45, 1), 0.1) if W == 32 else -1.0}

static func _hist(sl: PackedFloat64Array) -> Array:
	var b := []; b.resize(9); b.fill(0)
	for a in sl: b[mini(int(a / 10.0), 8)] += 1
	return b.map(func(v): return snappedf(100.0 * v / sl.size(), 0.1))

## pata hory: vodorovná vzdálenost od vrcholu k nejbližšímu bodu, kde výška klesne pod čtvrtinu převýšení nad minimem
static func pata(h: PackedFloat64Array, W: int, H: int, dx_m: float) -> Dictionary:
	var lo := 1e9; var hi := -1e9; var pk := 0
	for i in W * H:
		lo = minf(lo, h[i])
		if h[i] > hi: hi = h[i]; pk = i
	var px := pk / H; var py := pk % H
	var thr := lo + 0.25 * (hi - lo)
	var best := 1e9
	for i in W * H:
		if h[i] <= thr:
			best = minf(best, Vector2(i / H - px, i % H - py).length() * dx_m)
	return {"vrchol_m": snappedf(hi, 0.01), "pata_m": snappedf(best, 0.01), "prevyseni_m": snappedf(hi - lo, 0.01)}

## ---------------------------------------------------------------- blok 128 m z funkce světa E90
const L90 = preload("res://scripts/teren/lod90.gd")
const PR = preload("res://scripts/teren/params.gd")

## dlaždice 128 m s největším převýšením na mapě E90 (24 × 24), vzorky po 4 m
static func best_tile() -> Dictionary:
	var f := L90.fn(L90.P, PR.defaults())
	var best := Vector2i.ZERO; var br := -1.0
	for tx in 24:
		for ty in 24:
			var lo := 1e9; var hi := -1e9
			for i in 33:
				for j in 33:
					var h := L90.h_m(f, tx * 128.0 + i * 4.0, ty * 128.0 + j * 4.0)
					lo = minf(lo, h); hi = maxf(hi, h)
			if hi - lo > br: br = hi - lo; best = Vector2i(tx, ty)
	return {"tile": best, "relief_4m": br, "f": f}

## výšky dlaždice po 0,5 m (257 × 257 bodů, okraje sdílené); max_slope > 0 → omezovač na 1 m mřížce, pak bilineárně
static func tile_heights(f: Dictionary, t: Vector2i, max_slope: float, passes := 1500) -> Dictionary:
	var o := Vector2(t.x * 128.0, t.y * 128.0)
	var info := {}
	var N := 257
	var h := PackedFloat64Array(); h.resize(N * N)
	if max_slope <= 0.0:
		for i in N:
			for j in N:
				h[i * N + j] = L90.h_m(f, o.x + i * 0.5, o.y + j * 0.5)
		return {"h": h, "N": N, "dx": 0.5, "info": info}
	var M := 129
	var c := PackedFloat64Array(); c.resize(M * M)
	for i in M:
		for j in M:
			c[i * M + j] = L90.h_m(f, o.x + i, o.y + j) * 2.0   # v buňkách 0,5 m
	var t0 := Time.get_ticks_usec()
	var r := limit(c, M, max_slope, passes, 1.0, 0.5)
	info = {"passes": r.passes, "worst_cells": snappedf(r.worst_cells, 0.001), "ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)}
	var g: PackedFloat64Array = r.hm
	# jemný rozdíl funkce (0,5 m) proti 1 m mřížce se přičte zpět → povrch dál z funkce, jen hrubý tvar omezený
	for i in N:
		for j in N:
			var x := i * 0.5; var y := j * 0.5
			var x0 := mini(int(x), M - 2); var y0 := mini(int(y), M - 2)
			var fx := x - x0; var fy := y - y0
			var lim := lerpf(lerpf(g[x0 * M + y0], g[(x0 + 1) * M + y0], fx), lerpf(g[x0 * M + y0 + 1], g[(x0 + 1) * M + y0 + 1], fx), fy) * 0.5
			var raw1 := lerpf(lerpf(c[x0 * M + y0], c[(x0 + 1) * M + y0], fx), lerpf(c[x0 * M + y0 + 1], c[(x0 + 1) * M + y0 + 1], fx), fy) * 0.5
			h[i * N + j] = lim + (L90.h_m(f, o.x + x, o.y + y) - raw1)
	return {"h": h, "N": N, "dx": 0.5, "info": info}
