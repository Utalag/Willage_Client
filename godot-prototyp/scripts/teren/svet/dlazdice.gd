extends RefCounted
## KOPIE z blueprint-studie/scripts/svet8/dlazdice.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E49 fáze 5: řez hrubého světa na dlaždice T × T. Každá dlaždice dostane typ blueprintu podle hrubého terénu,
## podmnožinu hornin podle převládajícího biomu, minerály podle typu a povrch base_hm (hrubá výška bilineárně na 16 × 16
## řídicích bodů). Pořadí pravidel: sopka (z fáze 1) → jezero → hora (vyzdvižená / zvrásněná podle tektoniky) → kopec → svah → louka.

const BM = preload("res://scripts/teren/svet/biomy.gd")
const C := 8; const FE := 9; const CD := 12; const GEM := 101; const FETI := 103; const COAL := 104; const LIG := 105; const AU := 107
const TYPES := ["louka", "kopec", "svah", "prohlubeň", "hora_vyzdvizena", "hora_zvrasnena", "sopka"]
const MIN := {"louka": {COAL: 20, LIG: 20}, "kopec": {C: 15, FE: 15}, "svah": {FE: 15, CD: 20}, "prohlubeň": {LIG: 20},
	"hora_vyzdvizena": {C: 20, AU: 4, GEM: 4}, "hora_zvrasnena": {C: 15, FE: 10, COAL: 10}, "sopka": {FE: 10, FETI: 8, AU: 3}}
## podmnožina hornin podle biomu (klíče z data/poradi_hornin.json)
const SUB := {2: {"on": ["conglomerate"], "off": []}, 1: {"on": ["conglomerate"], "off": []}, 6: {"on": ["gypsum"], "off": []},
	5: {"on": ["siltstone"], "off": []}, 3: {"on": [], "off": ["loess"]}, 0: {"on": [], "off": ["loess"]},
	7: {"on": [], "off": ["loess", "gravel_sand"]}, 8: {"on": [], "off": ["loess", "gravel_sand"]}}

static func _bil(hm: PackedFloat64Array, R: int, fx: float, fy: float) -> float:
	fx = clampf(fx, 0.0, R - 1.001); fy = clampf(fy, 0.0, R - 1.001)
	var ix := int(fx); var iy := int(fy); var tx := fx - ix; var ty := fy - iy
	return lerpf(lerpf(hm[ix * R + iy], hm[(ix + 1) * R + iy], tx), lerpf(hm[ix * R + iy + 1], hm[(ix + 1) * R + iy + 1], tx), ty)

static func run(t: Dictionary, w: Dictionary, rv: Dictionary, bio: PackedByteArray, p: Dictionary) -> Array:
	var R: int = t.R; var T: int = t.T; var PX: int = t.PX
	var hm: PackedFloat64Array = t.hm
	var out := []
	for tx in T:
		for ty in T:
			var mean := 0.0; var mx := -1e9; var mn := 1e9; var lk := 0; var tect := 0.0; var rain := 0.0
			var cnt := {}
			var sx := 0.0; var sy := 0.0
			for x in PX:
				for y in PX:
					var i := (tx * PX + x) * R + ty * PX + y
					mean += hm[i]; mx = maxf(mx, hm[i]); mn = minf(mn, hm[i]); lk += rv.lake[i]; tect += t.tect[i]; rain += w.rain[i]
					if bio[i] != 1: cnt[bio[i]] = cnt.get(bio[i], 0) + 1
					sx += hm[i] * (x - (PX - 1) * 0.5); sy += hm[i] * (y - (PX - 1) * 0.5)
			var n := float(PX * PX)
			mean /= n; tect /= n; rain /= n
			var den := 0.0
			for x in PX: den += pow(x - (PX - 1) * 0.5, 2)
			var grad := Vector2(sx / (den * PX), sy / (den * PX)).length()   # sklon roviny (buněk na 1 m)
			var major := 4; var bc := -1
			for k in cnt:
				if cnt[k] > bc or (cnt[k] == bc and k < major): bc = cnt[k]; major = k
			var shape := "louka"
			if Vector2i(tx, ty) == t.volcano: shape = "sopka"
			elif lk / n >= float(p.s8_lake_frac): shape = "prohlubeň"
			elif mean >= float(p.s8_mtn_mean) or mx >= float(p.s8_mtn_max): shape = ("hora_vyzdvizena" if tect >= 0.0 else "hora_zvrasnena") if str(p.s8_force_mtn) == "" else str(p.s8_force_mtn)
			elif mx - mn >= float(p.s8_hill_relief) and mean >= float(p.surf_ref) + 1.0: shape = "kopec"
			elif grad >= float(p.s8_slope): shape = "svah"
			var base := PackedFloat64Array(); base.resize(256)
			for x in 16:
				for y in 16:
					var gx := tx * 16 + x; var gy := ty * 16 + y   # řídicí body světa → body hrubé mřížky (2 na 1 m)
					base[x * 16 + y] = _bil(hm, R, (gx + 0.5) * PX / 16.0 - 0.5, (gy + 0.5) * PX / 16.0 - 0.5)
			var sub: Dictionary = SUB.get(major, {"on": [], "off": []})
			var bp := {"shape": shape, "seed": int(p.world_seed) * 131 + tx * 17 + ty * 7919, "minerals": MIN[shape].duplicate(),
				"water": int(60 + 140 * rain), "base_hm": base, "base_off": [tx * 16, ty * 16], "base_seed": int(p.world_seed),
				"rocks_on": sub.on, "rocks_off": sub.off}
			out.append({"slot": Vector2i(tx, ty), "bp": bp, "biome": major, "mean": mean, "relief": mx - mn, "grad": grad,
				"tect": tect, "forced": str(p.s8_force_mtn) != ""})
	if bool(p.get("s8_massif", true)): _massifs(out, T)
	return out

## E49b: typ hory po souvislých masivech horských dlaždic (4-sousedství), podle průměrné tektoniky masivu
static func _massifs(out: Array, T: int) -> void:
	const SD = preload("res://scripts/teren/sides.gd")
	var by := {}
	for e in out: by[e.slot] = e
	var seen := {}
	for e in out:
		if not e.bp.shape.begins_with("hora") or seen.has(e.slot): continue
		var comp := [e.slot]; seen[e.slot] = true; var i := 0; var tsum := 0.0
		while i < comp.size():
			var s: Vector2i = comp[i]; i += 1
			tsum += float(by[s].tect)
			for d in 4:
				var n: Vector2i = s + SD.DIRS[d]
				if by.has(n) and not seen.has(n) and by[n].bp.shape.begins_with("hora"):
					seen[n] = true; comp.append(n)
		var shape := "hora_vyzdvizena" if tsum >= 0.0 else "hora_zvrasnena"
		for s in comp:
			if by[s].forced == false:
				by[s].bp.shape = shape; by[s].bp.minerals = MIN[shape].duplicate()

## pořadí vkládání: od první dlaždice do šířky (BFS, sousedé v pořadí SD.DIRS)
static func order(T: int, first: Vector2i) -> Array:
	const SD = preload("res://scripts/teren/sides.gd")
	var seen := {first: true}; var q := [first]; var i := 0
	while i < q.size():
		var s: Vector2i = q[i]; i += 1
		for d in 4:
			var n: Vector2i = s + SD.DIRS[d]
			if n.x >= 0 and n.y >= 0 and n.x < T and n.y < T and not seen.has(n):
				seen[n] = true; q.append(n)
	return q
