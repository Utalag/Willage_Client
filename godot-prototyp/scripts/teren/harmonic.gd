extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/harmonic.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Harmonická (Laplaceova) interpolace na mřížce 16 × 16 s obalem 18 × 18 (index (i + 1) · 18 + (j + 1), i, j ∈ −1..16).
## kind: 0 = neznámá (řeší se), 1 = pevná hodnota (Dirichlet), 2 = Neumann (kopie sousední buňky uvnitř, nulový spád).
## Gauss–Seidel s převrelaxací (SOR), pevné pořadí průchodu → stejný vstup = stejný výsledek (deterministické) [1][2].

const P := 18

static func pidx(i: int, j: int) -> int:
	return (i + 1) * P + (j + 1)

static func grid() -> Dictionary:
	var v := PackedFloat64Array(); v.resize(P * P)
	var k := PackedByteArray(); k.resize(P * P)
	for t in P * P:
		k[t] = 2   # obal výchozí Neumann, rohy obalu stencil nepoužije
	for i in 16:
		for j in 16:
			k[pidx(i, j)] = 0
	return {"val": v, "kind": k}

## vrací počet iterací; val se mění na místě
static func solve(val: PackedFloat64Array, kind: PackedByteArray, iters := 600, omega := 1.8, tol := 1e-5) -> int:
	var has_fixed := false
	for t in kind:
		if t == 1:
			has_fixed = true; break
	if not has_fixed:
		return 0   # samé Neumannovy okraje: řešení je konstanta, korekce 0
	var it := 0
	while it < iters:
		for t in 16:
			if kind[pidx(-1, t)] == 2: val[pidx(-1, t)] = val[pidx(0, t)]
			if kind[pidx(16, t)] == 2: val[pidx(16, t)] = val[pidx(15, t)]
			if kind[pidx(t, -1)] == 2: val[pidx(t, -1)] = val[pidx(t, 0)]
			if kind[pidx(t, 16)] == 2: val[pidx(t, 16)] = val[pidx(t, 15)]
		var mx := 0.0
		for i in 16:
			for j in 16:
				var p := pidx(i, j)
				if kind[p] != 0:
					continue
				var d := (val[p - P] + val[p + P] + val[p - 1] + val[p + 1]) * 0.25 - val[p]
				val[p] += omega * d
				mx = maxf(mx, absf(d))
		it += 1
		if mx < tol:
			break
	return it

## vnitřek 16 × 16 (index x · 16 + y)
static func inner(val: PackedFloat64Array) -> PackedFloat64Array:
	var o := PackedFloat64Array(); o.resize(256)
	for i in 16:
		for j in 16:
			o[i * 16 + j] = val[pidx(i, j)]
	return o
