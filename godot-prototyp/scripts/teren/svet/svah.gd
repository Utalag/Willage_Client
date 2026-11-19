extends RefCounted
## KOPIE z blueprint-studie/scripts/svah56/svah.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E56 mírnější přechody: operace nad hrubou výškovou mapou R × R (výška v buňkách 0,5 m, rozteč bodů dx_m metrů).
##  limit(): omezovač sklonu jako tepelná eroze, průchody celou mapou (Jacobi). Kde rozdíl sousedů přesáhne sklon ·
##           vzdálenost, čtvrtina přebytku se přesune dolů → hmota se zachová, svah se rozšíří.
##  smooth(): vyhlazení 3 × 3 (váha w = podíl průměru sousedů).

const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

static func limit(hm: PackedFloat64Array, R: int, max_slope: float, passes: int, dx_m := 1.0, cell_m := 0.5) -> Dictionary:
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
	return {"passes": it, "worst_cells": worst}

static func smooth(hm: PackedFloat64Array, R: int, n: int, w: float) -> void:
	var t := PackedFloat64Array(); t.resize(R * R)
	for k in n:
		for x in R:
			for y in R:
				var s := 0.0; var c := 0
				for qx in range(maxi(x - 1, 0), mini(x + 2, R)):
					for qy in range(maxi(y - 1, 0), mini(y + 2, R)): s += hm[qx * R + qy]; c += 1
				t[x * R + y] = (1.0 - w) * hm[x * R + y] + w * s / c
		for i in R * R: hm[i] = t[i]
