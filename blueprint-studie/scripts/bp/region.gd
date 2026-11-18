extends RefCounted
## Regionální základ (Janova skica 1): souvislé vlnité vrstvy ve SVĚTOVÝCH souřadnicích ze seedu světa.
## Hranice vrstvy k (vršek vrstvy LAYERS[k]) = base[k] + amp[k] · fBm s domain warpingem [3][4] (FastNoiseLite).
## Protože pole je spojité přes celý svět, dva bloky postavené jen z regionu na sebe navazují samy.

const Mat = preload("res://scripts/kopie/mat.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const LAYERS := [Mat.BASALT, Mat.GRANITE, Mat.LIMESTONE, Mat.CLAY, Mat.SAND]

static var _cache := {}

static func _noise(world_seed: int, k: int, p: Dictionary) -> FastNoiseLite:
	var key := "%d_%d_%s" % [world_seed, k, str(p.region_freq)]
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = H.noise_seed(world_seed, "REGION", k)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = p.region_freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	n.domain_warp_enabled = true
	n.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	n.domain_warp_amplitude = p.region_warp
	n.domain_warp_frequency = p.region_freq * 0.5
	n.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_NONE
	_cache[key] = n
	return n

## pole hranice k pro blok ve slotu (16 × 16)
static func field(world_seed: int, slot: Vector2i, k: int, p: Dictionary) -> PackedFloat64Array:
	var n0 := _noise(world_seed, 99, p)   # společný tvar vlnění všech vrstev (rovnoběžné vrstvy jako na skice)
	var n := _noise(world_seed, k, p)
	var o := PackedFloat64Array(); o.resize(256)
	for x in 16:
		for y in 16:
			o[x * 16 + y] = float(p.region_base[k]) + float(p.region_amp[k]) * (0.75 * n0.get_noise_2d(slot.x * 16 + x, slot.y * 16 + y) + 0.25 * n.get_noise_2d(slot.x * 16 + x, slot.y * 16 + y))
	return o
