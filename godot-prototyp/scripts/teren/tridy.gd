@tool
extends RefCounted
## E66: plné MaterialId terénu studie (0–255: horniny 20+, minerály 100+, dutina vody 250) → herní třída prototypu (Mat 0–12).
## Hra (kopání, inventář, rarita, vegetace, povrch) pracuje dál s třídami v Block.cells, plné id je v Block.geo
## (vzhled v rentgenu / řezu a vlastnosti vody). Barvy plných id = ladicí paleta hornin z data/teren/poradi_hornin.json.

const Mat = preload("res://scripts/mat.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const CAV_WATER := 250

## měkké sedimenty → písek, jílovité → jíl, karbonáty a ostatní sedimenty → vápenec, hory a krystalinikum → žula, plášť → čedič
const SAND_KEYS := ["loess", "hill_sand", "subalpine_scree", "gravel_sand", "sandstone_towers", "quartz_sandstone", "conglomerate"]
const CLAY_KEYS := ["siltstone", "shale", "flysch", "weathered_clay", "weathered_volcanic"]
const BASALT_KEYS := ["volcanic_conduit", "black_coal", "lignite", "diabase"]
## minerály: železo a Fe-Ti → železo, ostatní rudy a drahokamy → měď (herní „ruda“), ložiskový jíl zůstává
const IRON_KEYS := ["iron", "fe_ti"]

static var _cls := PackedByteArray()
static var _pal := PackedColorArray()

static func classes() -> PackedByteArray:
	if not _cls.is_empty():
		return _cls
	var c := PackedByteArray(); c.resize(256)
	for m in 256:
		c[m] = Mat.GRANITE
	for m in Mat.COUNT:
		c[m] = m
	c[Mat.FOG] = Mat.GRANITE
	for e in HR.raw().rocks:
		var id := int(e.id)
		if id < Mat.COUNT: continue
		var k: String = e.key
		var z: String = e.zone
		var t := Mat.GRANITE
		if k in SAND_KEYS: t = Mat.SAND
		elif k in CLAY_KEYS: t = Mat.CLAY
		elif k in BASALT_KEYS or z == "plast": t = Mat.BASALT
		elif z == "sedimenty": t = Mat.LIMESTONE
		elif k == "limestone_outcrop": t = Mat.LIMESTONE
		elif k == "eternal_snow": t = Mat.SNOW
		c[id] = t
	var HT = load("res://scripts/teren/hostitele.gd")
	var tab: Dictionary = HT.table()
	for m in tab:
		var id := int(m)
		if id < Mat.COUNT or id > 255: continue
		var key := String(tab[m].get("name", ""))
		c[id] = Mat.IRON if key in IRON_KEYS else Mat.COPPER
	c[CAV_WATER] = Mat.AIR
	_cls = c
	return c

## barvy plných id (alfa 0 = použij barvu třídy prototypu); základní id 0–12 mají vždy barvy prototypu
static func palette() -> PackedColorArray:
	if not _pal.is_empty():
		return _pal
	var p := HR.palette()
	p.resize(256)
	for m in Mat.COUNT:
		p[m] = Color(0, 0, 0, 0)
	_pal = p
	return p

## buňky geo → třídy (stejná délka)
static func to_classes(geo: PackedByteArray) -> PackedByteArray:
	var c := classes()
	var out := PackedByteArray(); out.resize(geo.size())
	for i in geo.size():
		out[i] = c[geo[i]]
	return out

static func name_of(m: int) -> String:
	if m < Mat.COUNT: return Mat.NAMES[m]
	if m == CAV_WATER: return "voda (rezervoár)"
	for e in HR.raw().rocks:
		if int(e.id) == m: return e.name
	var HT = load("res://scripts/teren/hostitele.gd")
	return HT.name_of(m)
