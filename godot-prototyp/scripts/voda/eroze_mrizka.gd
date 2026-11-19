extends RefCounted
## KOPIE z blueprint-studie/scripts/voda/eroze_mrizka.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E47: kapková hydraulická eroze (Lague / Mei et al. [5][6], stejná pravidla jako bp/erosion.gd) na LIBOVOLNÉ mřížce W × H.
## hm v jednotkách U (0,5 m), index x · H + y. fixed[i] = 1 → bod se nemění (chybějící blok, připnutý okraj se řeší vahou zvlášť).
## Deterministická (Rng ze seedu). Parametry z p (ero_*), výchozí = erosion.gd.

const Ore = preload("res://scripts/teren/zaklad/ore_v0.gd")
const H = preload("res://scripts/teren/zaklad/stable_hash.gd")

static func _h(hm: PackedFloat64Array, W: int, Hh: int, x: float, y: float) -> Vector3:
	var ix := clampi(int(x), 0, W - 2); var iy := clampi(int(y), 0, Hh - 2)
	var u := x - ix; var v := y - iy
	var a := hm[ix * Hh + iy]; var b := hm[(ix + 1) * Hh + iy]; var c := hm[ix * Hh + iy + 1]; var d := hm[(ix + 1) * Hh + iy + 1]
	return Vector3((b - a) * (1 - v) + (d - c) * v, (c - a) * (1 - u) + (d - b) * u,
		a * (1 - u) * (1 - v) + b * u * (1 - v) + c * (1 - u) * v + d * u * v)

static func _add(hm: PackedFloat64Array, fixed: PackedByteArray, W: int, Hh: int, x: float, y: float, amt: float) -> void:
	var ix := clampi(int(x), 0, W - 2); var iy := clampi(int(y), 0, Hh - 2)
	var u := x - ix; var v := y - iy
	var ks := [ix * Hh + iy, (ix + 1) * Hh + iy, ix * Hh + iy + 1, (ix + 1) * Hh + iy + 1]
	var ws := [(1 - u) * (1 - v), u * (1 - v), (1 - u) * v, u * v]
	for j in 4:
		if fixed.is_empty() or fixed[ks[j]] == 0:
			hm[ks[j]] += amt * ws[j]

## vrací {mean_change, cut, dep} (objem v U³ na řídicí bod); hm se mění na místě
static func run(hm: PackedFloat64Array, W: int, Hh: int, seed: int, droplets: int, p: Dictionary, fixed := PackedByteArray()) -> Dictionary:
	var before := hm.duplicate()
	var rng := Ore.Rng.new(H.mix(seed, "EROSION_GRID", 0))
	var INERTIA := float(p.get("ero_inertia", 0.05)); var CAP := float(p.get("ero_cap", 4.0)); var MIN_CAP := 0.01
	var ERODE := float(p.get("ero_erode", 0.3)); var DEPOSIT := float(p.get("ero_deposit_rate", 0.3))
	var EVAP := 0.02; var GRAV := 4.0; var STEPS := int(p.get("ero_steps", 30))
	var mx := (W - 1) * 1000 - 1; var my := (Hh - 1) * 1000 - 1
	for _d in droplets:
		var px := rng.range_i(0, mx) / 1000.0; var py := rng.range_i(0, my) / 1000.0
		if not fixed.is_empty() and fixed[int(px) * Hh + int(py)] != 0: continue
		var dx := 0.0; var dy := 0.0; var speed := 1.0; var water := 1.0; var sed := 0.0
		for _s in STEPS:
			var g := _h(hm, W, Hh, px, py)
			dx = dx * INERTIA - g.x * (1 - INERTIA); dy = dy * INERTIA - g.y * (1 - INERTIA)
			var l := sqrt(dx * dx + dy * dy)
			if l < 1e-9: break
			dx /= l; dy /= l
			var nx := px + dx; var ny := py + dy
			if nx < 0 or ny < 0 or nx >= W - 1 or ny >= Hh - 1: break
			var dh := _h(hm, W, Hh, nx, ny).z - g.z
			var cap := maxf(-dh * speed * water * CAP, MIN_CAP)
			if sed > cap or dh > 0:
				var amt := minf(dh, sed) if dh > 0 else (sed - cap) * DEPOSIT
				sed -= amt; _add(hm, fixed, W, Hh, px, py, amt)
			else:
				var amt := minf((cap - sed) * ERODE, -dh)
				sed += amt; _add(hm, fixed, W, Hh, px, py, -amt)
			speed = sqrt(maxf(speed * speed + dh * GRAV, 0.0)); water *= 1 - EVAP
			px = nx; py = ny
	return stats(before, hm)

static func stats(before: PackedFloat64Array, hm: PackedFloat64Array) -> Dictionary:
	var s := 0.0; var cut := 0.0; var dep := 0.0; var mcut := 0.0; var mdep := 0.0
	for i in hm.size():
		var dd := hm[i] - before[i]
		s += absf(dd)
		if dd < 0: cut -= dd; mcut = maxf(mcut, -dd)
		else: dep += dd; mdep = maxf(mdep, dd)
	return {"mean_change": s / hm.size(), "cut": cut, "dep": dep, "max_cut": mcut, "max_dep": mdep}
