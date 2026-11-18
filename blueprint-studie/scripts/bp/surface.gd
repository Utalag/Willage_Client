extends RefCounted
## Náhled: dorovnání okrajů povrchu na sousedy. Korekce c = harmonická funkce v pásu `band` od stran se sousedem:
## okrajový sloupec = výška přiléhajícího sloupce souseda (Dirichlet), sloupce dál než `band` od všech sousedů = 0
## (vnitřek drží svůj tvar), strany bez souseda Neumann. Výška = round(šablona + c).

const HM = preload("res://scripts/bp/harmonic.gd")
const SD = preload("res://scripts/bp/sides.gd")

## nb_edges[d] = PackedFloat64Array(16) výšek přiléhajících sloupců souseda na straně d, nebo null
static func adapt(raw: PackedFloat64Array, nb_edges: Array, band: int, p: Dictionary) -> Dictionary:
	var g := HM.grid()
	var val: PackedFloat64Array = g.val; var kind: PackedByteArray = g.kind
	var any := false
	for d in 4:
		if nb_edges[d] == null or band <= 0:
			continue
		any = true
		for t in 16:
			var o := SD.own(d, t)
			var q := HM.pidx(o.x, o.y)
			var want: float = nb_edges[d][t] - raw[o.x * 16 + o.y]
			if kind[q] == 1:
				val[q] = (val[q] + want) * 0.5   # roh mezi dvěma sousedy: průměr
			else:
				kind[q] = 1; val[q] = want
	var iters := 0
	if any:
		for x in 16:
			for y in 16:
				var q := HM.pidx(x, y)
				if kind[q] == 1:
					continue
				var near := 99
				for d in 4:
					if nb_edges[d] != null:
						near = mini(near, SD.dist(d, x, y))
				if near >= band:
					kind[q] = 1; val[q] = 0.0
		iters = HM.solve(val, kind, p.iters, p.omega)
	var c := HM.inner(val)
	var hf := PackedFloat64Array(); hf.resize(256)
	var hm := PackedInt32Array(); hm.resize(256)
	var changed := PackedByteArray(); changed.resize(256)
	var raw_i := PackedInt32Array(); raw_i.resize(256)
	for i in 256:
		hf[i] = raw[i] + c[i]
		hm[i] = clampi(int(round(hf[i])), 2, 62)
		raw_i[i] = clampi(int(round(raw[i])), 2, 62)
		changed[i] = 1 if hm[i] != raw_i[i] else 0
	return {"hm_f": hf, "hm": hm, "hm_raw": raw_i, "changed": changed, "iters": iters}
