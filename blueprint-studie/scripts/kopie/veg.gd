extends RefCounted
## Vegetace: samostatná vrstva nad buňkami terénu. Základní porost se generuje deterministicky ze seedu bloku
## (účel "VEG"), každý druh má skóre a smí jen na vhodný povrchový materiál. Hráč bude sázet sám (později).

const Mat = preload("res://scripts/kopie/mat.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const BS := 16

enum { NONE, TUFT, FLOWERS, BUSH, CONIFER, DECIDUOUS, CACTUS, DRY_GRASS, MOSS }
const COUNT := 9
const NAMES := ["–", "trs trávy", "květiny", "keř", "jehličnan", "listnáč", "kaktus", "suchá tráva", "mech"]
const SCORE := [0, 1, 3, 4, 6, 6, 5, 1, 2]  # veg-v2: kaktus 8 -> 5 (na písčině je běžný)
const TREE := [false, false, false, false, true, true, false, false, false]  # stromy jen na sudé mřížce zdroje
const SURFACES := [
	[], [Mat.GRASS], [Mat.GRASS], [Mat.GRASS, Mat.DIRT], [Mat.GRASS], [Mat.GRASS],
	[Mat.SAND], [Mat.SAND], [Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT],
]
# hustota (pravděpodobnost na sloupec; u stromů podmíněně na sloupcích sudé mřížky) podle receptu
const DENSITY := {
	"louka":   [0.0, 0.45, 0.10, 0.03, 0.04, 0.16, 0.03, 0.25, 0.15],
	"kopec":   [0.0, 0.35, 0.06, 0.03, 0.14, 0.14, 0.03, 0.25, 0.15],
	"hora":    [0.0, 0.25, 0.03, 0.02, 0.30, 0.04, 0.03, 0.25, 0.15],
	"piscina": [0.0, 0.20, 0.02, 0.03, 0.00, 0.04, 0.11, 0.42, 0.15],  # veg-v2: víc kaktusů a suché trávy
}
const RARITY_THRESHOLDS := [0.0, 4.37, 4.90, 5.39, 6.48]  # rarity-v2 vážený průměr (v1: [0, 1.8, 2.1, 2.5, 2.9])  # průměrné skóre na rostlinu (zatímní, kalibrováno)

## Vygeneruje porost pro hotový blok (po všech transformacích). Výsledek: pole záznamů
## {s: druh, lx, ly, lz (povrch = hm), ox, oy (posun v buňce), yaw (°), scale}
static func generate(b) -> Array:
	var out := []
	for lx in BS:
		for ly in BS:
			var h: int = b.hm[lx * BS + ly]
			if h <= 0:
				continue
			var surf: int = b.cells[(lx * BS + ly) * 64 + h - 1]
			var src := _to_src(lx, ly, b.mirror, b.rot)
			var tree_ok := src.x % 2 == 0 and src.y % 2 == 0
			var r := H.mix(b.seed, "VEG", src.x * BS + src.y)
			var u := float(r & 0xFFFFFF) / 16777216.0
			var dens: Array = DENSITY[b.kind]
			var acc := 0.0
			var pick := NONE
			for s in range(1, COUNT):
				if not SURFACES[s].has(surf):
					continue
				if TREE[s] and not tree_ok:
					continue
				acc += dens[s]
				if u < acc:
					pick = s
					break
			if pick == NONE:
				continue
			# posun v buňce ve zdrojovém rámci, pak stejná transformace jako blok (zrcadlení, rotace)
			var ox := (float(H.shr(r, 24) & 0xFF) / 255.0 - 0.5) * 0.6
			var oy := (float(H.shr(r, 32) & 0xFF) / 255.0 - 0.5) * 0.6
			if b.mirror:
				ox = -ox
			for i in b.rot:
				var t := ox
				ox = -oy
				oy = t
			out.append({
				"s": pick, "lx": lx, "ly": ly, "lz": h, "ox": ox, "oy": oy,
				"yaw": float(H.shr(r, 40) & 0xFF) / 256.0 * 360.0,
				"scale": 0.8 + float(H.shr(r, 48) & 0xFF) / 255.0 * 0.4,
			})
	return out

static func _to_src(lx: int, ly: int, mirror: bool, rot: int) -> Vector2i:
	var p := Vector2i(lx, ly)
	for i in rot:
		p = Vector2i(p.y, BS - 1 - p.x)
	if mirror:
		p.x = BS - 1 - p.x
	return p

static func summary(veg: Array) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize(COUNT)
	for v in veg:
		s[v.s] += 1
	return s

static func score_of(sm: PackedInt32Array) -> int:
	var t := 0
	for i in COUNT:
		t += sm[i] * SCORE[i]
	return t

## rarity-v2: vážený průměr, váha z katalogu (výchozí s²)
static func weight(i: int) -> float:
	return float(SCORE[i] * SCORE[i])

static func mean_score(sm: PackedInt32Array) -> float:
	var ws := 0.0
	var s := 0.0
	for i in range(1, COUNT):
		ws += sm[i] * weight(i)
		s += sm[i] * weight(i) * SCORE[i]
	return s / maxf(ws, 1e-9)

static func mean_score_v1(sm: PackedInt32Array) -> float:
	var n := 0
	for i in range(1, COUNT):
		n += sm[i]
	return float(score_of(sm)) / maxf(n, 1.0)

static func rarity_of(sm: PackedInt32Array) -> int:
	var sc := mean_score(sm)
	var r := 0
	for i in RARITY_THRESHOLDS.size():
		if sc >= RARITY_THRESHOLDS[i]:
			r = i
	return r
