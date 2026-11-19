extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/scenario_data.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Ukázkový sled vložení na mřížce 3 × 3 (slot = Vector2i(x, y), y roste k jihu = +z v Godotu).
## 1 a 2 osamocené (regionální základ), 3 do mezery mezi dvěma sousedy, 4 a 5 s jedním sousedem.

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const BP = preload("res://scripts/teren/blueprint.gd")

static func sequence() -> Array:
	return [
		[Vector2i(0, 1), BP.make("kopec", 303, {Mat.COPPER: 20, Mat.IRON: 24, Mat.CLAY_DEPOSIT: 40}, 120)],
		[Vector2i(2, 1), BP.make("louka", 101, {Mat.COPPER: 12, Mat.IRON: 16}, 150)],
		[Vector2i(1, 1), BP.make("svah", 7, {Mat.COPPER: 30, Mat.IRON: 10, Mat.CLAY_DEPOSIT: 60}, 120)],
		[Vector2i(1, 0), BP.make("prohlubeň", 55, {Mat.IRON: 30, Mat.CLAY_DEPOSIT: 80}, 200)],
		[Vector2i(2, 2), BP.make("kopec", 909, {Mat.COPPER: 40, Mat.IRON: 40}, 120)],
	]
