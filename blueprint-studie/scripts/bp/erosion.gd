extends RefCounted
## Volitelná hydraulická eroze kapkami (podle Lague / Mei et al. [5][6]) na desetinné výškové mapě 16 × 16.
## Deterministická (Rng ze seedu), běží PŘED dorovnáním okrajů, takže švy neovlivní.

const Ore = preload("res://scripts/kopie/ore_v0.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")

static func _h(hm: PackedFloat64Array, x: float, y: float) -> Vector3:
	var ix := clampi(int(x), 0, 14); var iy := clampi(int(y), 0, 14)
	var u := x - ix; var v := y - iy
	var a := hm[ix * 16 + iy]; var b := hm[(ix + 1) * 16 + iy]; var c := hm[ix * 16 + iy + 1]; var d := hm[(ix + 1) * 16 + iy + 1]
	var gx := (b - a) * (1 - v) + (d - c) * v
	var gy := (c - a) * (1 - u) + (d - b) * u
	return Vector3(gx, gy, a * (1 - u) * (1 - v) + b * u * (1 - v) + c * (1 - u) * v + d * u * v)

static func _add(hm: PackedFloat64Array, x: float, y: float, amt: float) -> void:
	var ix := clampi(int(x), 0, 14); var iy := clampi(int(y), 0, 14)
	var u := x - ix; var v := y - iy
	hm[ix * 16 + iy] += amt * (1 - u) * (1 - v); hm[(ix + 1) * 16 + iy] += amt * u * (1 - v)
	hm[ix * 16 + iy + 1] += amt * (1 - u) * v; hm[(ix + 1) * 16 + iy + 1] += amt * u * v

static func run(hm: PackedFloat64Array, seed: int, droplets: int) -> Dictionary:
	var before := hm.duplicate()
	var rng := Ore.Rng.new(H.mix(seed, "EROSION", 0))
	const INERTIA := 0.05; const CAP := 4.0; const MIN_CAP := 0.01; const ERODE := 0.3; const DEPOSIT := 0.3
	const EVAP := 0.02; const GRAV := 4.0; const STEPS := 30
	for _d in droplets:
		var px := rng.range_i(0, 14999) / 1000.0; var py := rng.range_i(0, 14999) / 1000.0
		var dx := 0.0; var dy := 0.0; var speed := 1.0; var water := 1.0; var sed := 0.0
		for _s in STEPS:
			var g := _h(hm, px, py)
			dx = dx * INERTIA - g.x * (1 - INERTIA); dy = dy * INERTIA - g.y * (1 - INERTIA)
			var l := sqrt(dx * dx + dy * dy)
			if l < 1e-9:
				break
			dx /= l; dy /= l
			var nx := px + dx; var ny := py + dy
			if nx < 0 or ny < 0 or nx >= 15 or ny >= 15:
				break
			var dh := _h(hm, nx, ny).z - g.z
			var cap := maxf(-dh * speed * water * CAP, MIN_CAP)
			if sed > cap or dh > 0:
				var amt := minf(dh, sed) if dh > 0 else (sed - cap) * DEPOSIT
				sed -= amt; _add(hm, px, py, amt)
			else:
				var amt := minf((cap - sed) * ERODE, -dh)
				sed += amt; _add(hm, px, py, -amt)
			speed = sqrt(maxf(speed * speed + dh * GRAV, 0.0)); water *= 1 - EVAP
			px = nx; py = ny
	var dsum := 0.0
	for i in 256:
		dsum += absf(hm[i] - before[i])
	return {"mean_change": dsum / 256.0}
