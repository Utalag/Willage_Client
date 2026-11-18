extends RefCounted
## E47c prameny: jediný zdroj vody (déšť je jen vizuální). Pramen = zvláštní buňka {gi, z, q (l/s), druh, aktivni}.
## Druhy: "snih" (vrcholy / sníh), "kontakt" (propustná nad nepropustnou na svahu), "kras" (vyvěračka v rozpustné hornině).
## Uzavřený pramen (zasypaný, buňka nad ním není volná) neteče vůbec – žádný tlak ani prosakování; po otevření teče znovu.

const VS = preload("res://scripts/voda/voda_svet.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const Mat = preload("res://scripts/kopie/mat.gd")

static func _perm(m: int) -> float:
	var e: Array = VS.table().get(m, [0.0, 0.0, 0.0, 0.0])
	return float(e[0])

static func _slope(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray, i: int) -> float:
	var x := i / H; var y := i % H; var s := 0.0
	for d in 4:
		var qx: int = x + SZ.DX[d]; var qy: int = y + SZ.DY[d]
		if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
		var j := qx * H + qy
		if wall[j] == 0: s = maxf(s, hm[i] - hm[j])
	return s

## mat_d(gi, hloubka_U) → MaterialId v dané hloubce pod povrchem (0 = povrchová buňka)
static func find(hm: PackedFloat64Array, W: int, H: int, wall: PackedByteArray, mat_d: Callable, p: Dictionary) -> Array:
	var cand := []   # [skóre, gi, druh, q]
	var hs := []
	for i in W * H:
		if wall[i] == 0: hs.append(hm[i])
	hs.sort()
	var peak: float = hs[int(float(p.pram_peak_q) * (hs.size() - 1))]
	for i in W * H:
		if wall[i] == 1: continue
		var x := i / H; var y := i % H
		if x == 0 or y == 0 or x == W - 1 or y == H - 1: continue   # na okraji ostrova by hned přepadl
		var s := _slope(hm, W, H, wall, i)
		var top: int = mat_d.call(i, 0)
		if hm[i] >= peak or top == Mat.SNOW:
			cand.append([3000.0 + hm[i], i, "snih", float(p.pram_q_snih)])
		var m2: int = mat_d.call(i, 4); var m4: int = mat_d.call(i, 8)
		if s >= float(p.pram_slope):
			if _perm(m2) >= float(p.ponor_perm) and _perm(m4) <= 0.05:
				cand.append([2000.0 + s, i, "kontakt", float(p.pram_q_kontakt)])
			if SZ.soluble(m2) or SZ.soluble(top):   # vyvěračka: na okraji krasového tělesa (nižší soused nerozpustný), co nejníž
				var rim := false
				for d in 4:
					var qx: int = x + SZ.DX[d]; var qy: int = y + SZ.DY[d]
					if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
					var j := qx * H + qy
					if wall[j] == 0 and hm[j] < hm[i] and not SZ.soluble(mat_d.call(j, 4)) and not SZ.soluble(mat_d.call(j, 0)): rim = true
				if rim: cand.append([1000.0 - hm[i], i, "kras", float(p.pram_q_kras)])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	var dmin := float(p.pram_dist); var kinds := {}
	for c in cand:
		if out.size() >= int(p.pram_max): break
		if kinds.get(c[2], 0) >= int(p.pram_max_druh): continue
		var ok := true
		for o in out:
			if Vector2(o.gi / H - c[1] / H, o.gi % H - c[1] % H).length() < dmin: ok = false; break
		if ok:
			out.append({"gi": c[1], "z": int(hm[c[1]]), "q": c[3], "druh": c[2], "aktivni": true})
			kinds[c[2]] = kinds.get(c[2], 0) + 1
	return out

## aktivní ⇔ buňka nad pramenem je volná (povrch sloupce ≤ z + 1); uzavřený pramen dává 0
static func is_open(s: Dictionary, hm: PackedFloat64Array) -> bool:
	return hm[s.gi] <= float(s.z) + 1.0

static func src(springs: Array, hm: PackedFloat64Array, n: int) -> PackedFloat64Array:
	var q := PackedFloat64Array(); q.resize(n)
	for s in springs:
		s.aktivni = is_open(s, hm)
		if s.aktivni: q[s.gi] += float(s.q)
	return q
