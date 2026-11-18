extends RefCounted
## Potvrzení: hranice vrstev nového bloku jako POKRAČOVÁNÍ sousedů.
## Cíl T_k = regionální základ R_k (svět) + drape_k · max(0, povrch − surf_ref) + strata_noise · fBm(seed blueprintu).
## B_k = T_k + c_k, c_k harmonická: v obalu za stranou se sousedem c = B_k(souseda, přiléhající sloupec) − T_k(okraj),
## strany bez souseda Neumann (nebo 0), volitelně c = 0 dál než strata_band od sousedů. Pak B_0 ≤ B_1 ≤ … (monotónnost).

const Mat = preload("res://scripts/kopie/mat.gd")
const BG = preload("res://scripts/kopie/block_gen.gd")
const HM = preload("res://scripts/bp/harmonic.gd")
const SD = preload("res://scripts/bp/sides.gd")
const R = preload("res://scripts/bp/region.gd")
const LAYERS := R.LAYERS
const K := 5

static func target(slot: Vector2i, hm_f: PackedFloat64Array, seed: int, k: int, p: Dictionary) -> PackedFloat64Array:
	var t := R.field(p.world_seed, slot, k, p)
	var n := BG.noise(seed, "BP_STRATA", k, 0.12, 3)
	for x in 16:
		for y in 16:
			var i := x * 16 + y
			t[i] += float(p.drape[k]) * maxf(0.0, hm_f[i] - float(p.surf_ref)) + float(p.strata_noise) * n.get_noise_2d(x, y)
	return t

## nb_b[d] = PackedFloat64Array(16) hranice k přiléhajících sloupců souseda, nebo null
static func continue_field(t: PackedFloat64Array, nb_b: Array, p: Dictionary) -> Dictionary:
	var g := HM.grid()
	var val: PackedFloat64Array = g.val; var kind: PackedByteArray = g.kind
	var any := false
	if p.get("continue", true):
		for d in 4:
			if nb_b[d] == null:
				continue
			any = true
			for t_ in 16:
				var gh := SD.ghost(d, t_); var o := SD.own(d, t_)
				var q := HM.pidx(gh.x, gh.y)
				kind[q] = 1; val[q] = nb_b[d][t_] - t[o.x * 16 + o.y]
	var iters := 0
	if any:
		for d in 4:
			if nb_b[d] == null and p.free_face == "zero":
				for t_ in 16:
					var gh := SD.ghost(d, t_)
					kind[HM.pidx(gh.x, gh.y)] = 1
		if int(p.strata_band) > 0:
			for x in 16:
				for y in 16:
					var near := 99
					for d in 4:
						if nb_b[d] != null:
							near = mini(near, SD.dist(d, x, y))
					if near >= int(p.strata_band):
						kind[HM.pidx(x, y)] = 1
		iters = HM.solve(val, kind, p.iters, p.omega)
	var c := HM.inner(val)
	var b := PackedFloat64Array(); b.resize(256)
	for i in 256:
		b[i] = t[i] + c[i]
	return {"b": b, "iters": iters}

static func monotone(bs: Array) -> void:
	for k in range(1, K):
		var lo: PackedFloat64Array = bs[k - 1]; var hi: PackedFloat64Array = bs[k]
		for i in 256:
			hi[i] = maxf(hi[i], lo[i])

## vyplnění sloupců x ∈ [x0, x1): tráva nahoře, hlína `soil` buněk pod ní, pod tím vrstvy podle B, mezera nad vrstvami = hlína
static func fill(cells: PackedByteArray, hm: PackedInt32Array, bs: Array, soil: int, x0: int, x1: int) -> void:
	for x in range(x0, x1):
		for y in 16:
			var i := x * 16 + y
			var h := hm[i]
			var base := i * 64
			for z in 64:
				var m := Mat.AIR
				if z == h - 1:
					m = Mat.GRASS
				elif z < h - 1 and z >= h - 1 - soil:
					m = Mat.DIRT
				elif z < h:
					m = Mat.DIRT
					var zc := z + 0.5
					for k in K:
						if zc < bs[k][i]:
							m = LAYERS[k]; break
				cells[base + z] = m

## ---------- v2 (Jan 16:44 + 16:46): navázání v MOCNOSTECH vrstev, sousedé jsou výchozí bod
## th = vlastní mocnost vrstvy (cíl blueprintu: tvar + šum) v řídicích bodech 16 × 16; sth[d] = mocnost na okraji d
## (16 hodnot) podle SOUSEDA (jeho funkce hranic v přiléhajícím řídicím bodě), nebo podle REGIONÁLNÍ desky, když soused
## chybí. Okrajový řídicí bod dostane PŘESNĚ hodnotu souseda (Dirichlet, roh = průměr), do vzdálenosti `band` řídicích bodů
## se korekce harmonicky (Laplace) rozplyne do vlastního tvaru, dál platí jen blueprint. Klín: soused vrstvu má, blok ne
## → th = 0, okraj = mocnost souseda → klín se ztenčí do nuly v délce `band`; opačně soused 0 → vrstva vyklíní ke straně.
## Výsledek je max(th + c, 0); hranice = kumulativní součet mocností (zdola), takže zůstanou seřazené.
static func continue_thick(th: PackedFloat64Array, sth: Array, band: int, p: Dictionary, real := [true, true, true, true]) -> Dictionary:
	var g := HM.grid()
	var val: PackedFloat64Array = g.val; var kind: PackedByteArray = g.kind
	var cnt := PackedByteArray(); cnt.resize(256)
	var acc := PackedFloat64Array(); acc.resize(256)
	var any := false
	# roh: skutečný soused má přednost před regionálním základem (jinak by roh byl průměr a na švu by vznikl skok)
	var pri := PackedByteArray(); pri.resize(256)
	for d in 4:
		if sth[d] == null: continue
		for t_ in 16:
			var o := SD.own(d, t_)
			pri[o.x * 16 + o.y] = maxi(pri[o.x * 16 + o.y], 2 if real[d] else 1)
	for d in 4:
		if sth[d] == null:
			continue
		for t_ in 16:
			var o := SD.own(d, t_)
			var i := o.x * 16 + o.y
			if (2 if real[d] else 1) < pri[i]: continue
			acc[i] += sth[d][t_] - th[i]; cnt[i] += 1
			if absf(sth[d][t_] - th[i]) > 1e-9: any = true
	var out := th.duplicate()
	if not any:
		return {"th": out, "iters": 0}
	for x in 16:
		for y in 16:
			var i := x * 16 + y
			var q := HM.pidx(x, y)
			if cnt[i] > 0:
				kind[q] = 1; val[q] = acc[i] / cnt[i]
				continue
			var near := 99
			for d in 4:
				if sth[d] != null:
					near = mini(near, SD.dist(d, x, y))
			if near >= band:
				kind[q] = 1; val[q] = 0.0
	var iters := HM.solve(val, kind, p.iters, p.omega)
	var c := HM.inner(val)
	for i in 256:
		out[i] = maxf(th[i] + c[i], 0.0)
	return {"th": out, "iters": iters}
