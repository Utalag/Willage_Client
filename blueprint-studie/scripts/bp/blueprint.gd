extends RefCounted
## Blueprint = šablona tvaru povrchu + seed + počty minerálů/kovů (+ voda k nalití). Bez složení podzemí.
## louka a kopec = generátor povrchu prototypu (block_gen v2.2), svah a prohlubeň = nové šablony studie.

const Mat = preload("res://scripts/kopie/mat.gd")
const BG = preload("res://scripts/kopie/block_gen.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const SHAPES := ["louka", "kopec", "svah", "prohlubeň", "hora", "hora_vyzdvizena", "hora_zvrasnena", "sopka"]

static func make(shape: String, seed: int, minerals: Dictionary, water := 120) -> Dictionary:
	return {"shape": shape, "seed": seed, "minerals": minerals, "water": water}

## Jan 17:38: blok má buď NIC, nebo právě JEDEN rezervoár (VODA, klíč 250), nebo právě JEDNU jeskyni (VZDUCH, klíč 0),
## nikdy obojí. Blueprint s VODOU i VZDUCHEM se ODMÍTNE (nerozhoduje se za autora). Počet ≤ 0 = dutina není.
const CAV_AIR := 0
const CAV_WATER := 250
static func validate(bp: Dictionary) -> Dictionary:
	var errs := []
	var w := int(bp.minerals.get(CAV_WATER, 0)); var a := int(bp.minerals.get(CAV_AIR, 0))
	if w > 0 and a > 0:
		errs.append({"code": "blueprint.cavity_conflict", "reason": "VODA %d i VZDUCH %d: blok smí mít jen rezervoár, nebo jen jeskyni" % [w, a]})
	for m in bp.minerals:
		if int(bp.minerals[m]) < 0:
			errs.append({"code": "blueprint.negative_count", "mat": m})
	return {"ok": errs.is_empty(), "errors": errs}

## rarita jen z minerálů a kovů (základní horniny se nepočítají): Σ počet × skóre materiálu (Mat.SCORE)
static func rarity_points(bp: Dictionary) -> float:
	var s := 0.0
	var t := HT.table()
	for m in bp.minerals:
		if m == 0 or m == 250: continue   # voda a vzduch (dutiny) se do rarity nepočítají
		s += bp.minerals[m] * (t[m].score if t.has(m) else Mat.SCORE[m])
	return s

## výšková mapa šablony (desetinná, 16 × 16, index x · 16 + y)
static func raw_height(bp: Dictionary, shift := 0.0) -> PackedFloat64Array:
	var o := PackedFloat64Array(); o.resize(256)
	var seed: int = bp.seed
	match bp.shape:
		"louka", "kopec", "hora", "hora_vyzdvizena", "hora_zvrasnena":
			var hm := BG.base_heightmap("hora" if bp.shape.begins_with("hora") else bp.shape, seed)
			for i in 256:
				o[i] = hm[i]
		"svah":
			var n := BG.noise(seed, "BP_SVAH", 0, 0.12, 3)
			for x in 16:
				for y in 16:
					o[x * 16 + y] = 28.0 + 14.0 * (y / 15.0) + 0.8 * n.get_noise_2d(x, y)
		"prohlubeň":
			var n := BG.noise(seed, "BP_DUL", 0, 0.12, 3)
			for x in 16:
				for y in 16:
					var r := Vector2(x - 7.5, y - 7.5).length() / 8.0
					o[x * 16 + y] = 32.0 - 10.0 * maxf(0.0, 1.0 - r * r) + 0.8 * n.get_noise_2d(x, y)
		"sopka":
			var n := BG.noise(seed, "BP_SOPKA", 0, 0.15, 3)
			for x in 16:
				for y in 16:
					var r := Vector2(x - 7.5, y - 7.5).length()
					var c := 22.0 * pow(clampf(1.0 - r / 8.5, 0.0, 1.0), 1.15) - (4.0 if r < 1.8 else 0.0)   # kužel + kráter
					o[x * 16 + y] = 31.0 + c + 0.6 * n.get_noise_2d(x, y)
	for i in 256:
		o[i] = minf(o[i] + shift, 61.0)
	return o
