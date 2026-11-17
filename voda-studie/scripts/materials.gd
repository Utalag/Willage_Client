extends RefCounted
## Materiály studie vody. ID jsou STEJNÁ jako v godot-prototyp/scripts/mat.gd (backend je zná),
## fyzikální vlastnosti vody se čtou z params.gd (perm_*, por_*, res_*) a jdou ladit z CLI.

enum { AIR, GRASS, DIRT, SAND, CLAY, LIMESTONE, GRANITE, BASALT }
const COUNT := 8
const KEYS := ["air", "grass", "dirt", "sand", "clay", "limestone", "granite", "basalt"]
const NAMES := ["vzduch", "tráva (louka)", "hlína", "písek", "jíl", "vápenec (porézní skála)", "žula (pevná skála)", "čedič"]
# pastelová paleta z mat.gd (tráva, hlína, písek, jíl, vápenec, žula, čedič)
const COLORS := [
	Color(0, 0, 0, 0),
	Color(0.56, 0.80, 0.47),
	Color(0.66, 0.50, 0.40),
	Color(0.98, 0.89, 0.62),
	Color(0.92, 0.62, 0.52),
	Color(0.88, 0.82, 0.68),
	Color(0.80, 0.68, 0.74),
	Color(0.52, 0.55, 0.68),
]

## [propustnost, pórovitost, odpor povrchu] pro materiál m (vzduch = 1, 1, 0)
static func props(m: int, P: Dictionary) -> Vector3:
	if m == AIR:
		return Vector3(1.0, 1.0, 0.0)
	var k: String = KEYS[m]
	return Vector3(clampf(float(P["perm_" + k]) * float(P["perm_scale"]), 0.0, 1.0), float(P["por_" + k]), float(P["res_" + k]))
