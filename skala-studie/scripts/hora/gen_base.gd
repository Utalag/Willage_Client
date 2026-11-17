extends RefCounted
## Výřez z godot-prototyp/scripts/block_gen.gd (generátor v2, reliéf proto-v2.2): jen konstanty a funkce,
## které potřebuje res_gen.gd. Zkopírováno beze změny logiky, aby hora seed 7777 vypadala jako v prototypu.

const H = preload("res://scripts/hora/stable_hash.gd")

const SNOW_LZ := 49
const ROCK_LZ := 46   # v2.2: od této výšky je povrch kopce/hory holý kámen

# strany: sever (-ly), východ (+lx), jih (+ly), západ (-lx)
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDE_NAMES := ["S", "V", "J", "Z"]


## FastNoiseLite s explicitními parametry (stejné musí použít C#)
static func noise(seed: int, purpose: String, layer: int, freq: float, octaves := 5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = H.noise_seed(seed, purpose, layer)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.offset = Vector3.ZERO
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	n.fractal_weighted_strength = 0.0
	n.domain_warp_enabled = false
	return n


## Verze tvaru kopce a hory: "v2.2" (profil nad makro-šumem, výchozí) nebo "v2.1" (eliptické vrcholy, jen pro srovnání)
static var relief_version := "v2.2"

# ---- proto-v2.2: výškový profil nad makro-šumem (technika z devlogu JohnBrx)
# Řídicí body profilu (m ∈ [0,1] -> lz), po částech lineární; police = vodorovné úseky, strmé úseky = útesy.
const PROFILES := {
	"kopec": [[0.0, 30.0], [0.30, 30.0], [0.36, 34.0], [0.62, 34.0], [0.68, 39.0], [1.0, 39.0]],
	"hora": [[0.0, 31.0], [0.24, 31.0], [0.30, 37.0], [0.48, 37.0], [0.54, 43.0], [0.72, 43.0],
		[0.78, 47.0], [1.0, 48.0]],
}
const MACRO_FREQ := 0.045     # makro-šum HEIGHT/5: v bloku 16 buněk asi 0,7 periody = jeden výrazný tvar
const MACRO_OCTAVES := 2     # makro jen 2 oktávy: čára útesu se vlní, ale nedrolí na jednotlivé buňky
const MACRO_SHIFT := 0.12     # posun m podle seedu: off = MACRO_SHIFT·(2·u(HEIGHT, 6) − 1)
const EDGE_DROP := {"kopec": 0.2, "hora": 0.35}  # vysoká patra se drží dál od hran bloku (žádné krabice)

static func profile_at(kind: String, m: float) -> float:
	var pts: Array = PROFILES[kind]
	if m <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if m <= pts[i][0]:
			var x0: float = pts[i - 1][0]; var y0: float = pts[i - 1][1]
			var x1: float = pts[i][0]; var y1: float = pts[i][1]
			return y0 + (y1 - y0) * (m - x0) / (x1 - x0)
	return pts[pts.size() - 1][1]


## u(seed, purpose, k) = (mix(seed, purpose, k) & 0xFFFFFF) / 2^24  -> [0, 1)
static func u01(seed: int, purpose: String, k: int) -> float:
	return float(H.mix(seed, purpose, k) & 0xFFFFFF) / 16777216.0

