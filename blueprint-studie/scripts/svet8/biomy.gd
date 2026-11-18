extends RefCounted
## E49 fáze 4: biomy z výšky, teploty, srážek, řek a jezer (jednoduchá Whittakerova tabulka [21]).
## 0 jezero, 1 řeka, 2 niva (u řeky), 3 mokřad, 4 louka, 5 les, 6 step, 7 skály, 8 sníh

const NAMES := ["jezero", "řeka", "niva", "mokřad", "louka", "les", "step", "skály", "sníh"]

static func run(t: Dictionary, w: Dictionary, rv: Dictionary, p: Dictionary) -> PackedByteArray:
	var R: int = t.R; var hm: PackedFloat64Array = t.hm
	var b := PackedByteArray(); b.resize(R * R)
	for i in R * R:
		var x := i / R; var y := i % R
		var near := false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var qx := x + dx; var qy := y + dy
				if qx >= 0 and qy >= 0 and qx < R and qy < R and rv.river[qx * R + qy] == 1: near = true
		var h: float = hm[i]; var r: float = w.rain[i]
		if rv.lake[i] == 1: b[i] = 0
		elif rv.river[i] == 1: b[i] = 1
		elif h >= float(p.snowline): b[i] = 8
		elif h >= float(p.treeline) - 3.0: b[i] = 7
		elif near and h < float(p.surf_ref) + 3.0: b[i] = 2
		elif r > 0.75 and h < float(p.surf_ref) + 1.0: b[i] = 3
		elif r < 0.3: b[i] = 6
		elif r > 0.5: b[i] = 5
		else: b[i] = 4
	return b
