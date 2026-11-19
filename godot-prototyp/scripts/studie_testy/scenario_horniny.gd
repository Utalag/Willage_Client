extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/scenario_horniny.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Sled pro geologii v2 (snímky 46): jako studie 45 + vyzdvižená hora (0,0) vedle prohlubně a nad kopcem, sopka (2,0) vedle prohlubně
## a nad loukou, zvrásněná hora (1,2) vedle kopce (2,2) a pod svahem (stejný seed tvaru jako vyzdvižená → srovnání profilů).
## Ukázkový kimberlitový komín pod loukou (2,1) a solný dóm na švu (0,1)|(1,1) (params demo_pipes / demo_domes).

const BP = preload("res://scripts/teren/blueprint.gd")
const C := 8; const FE := 9; const CD := 12
const WATER := 250; const AIR := 0   # dutiny: podzemní rezervoár a jeskyně (Jan 16:56)
const DIA := 100; const GEM := 101; const RM := 102; const FETI := 103; const COAL := 104; const LIG := 105; const GAR := 106; const AU := 107

static func sequence() -> Array:
	return [
		[Vector2i(0, 1), BP.make("kopec", 303, {C: 20, FE: 24, GAR: 6, COAL: 30}, 120)],
		[Vector2i(2, 1), BP.make("louka", 101, {DIA: 6, FETI: 20, COAL: 40, LIG: 30}, 150)],
		[Vector2i(1, 1), BP.make("svah", 7, {C: 30, FE: 10, CD: 40, AIR: 90}, 120)],
		[Vector2i(1, 0), BP.make("prohlubeň", 55, {FE: 30, LIG: 40}, 200)],
		[Vector2i(0, 0), BP.make("hora_vyzdvizena", 1000, {C: 40, GEM: 8, RM: 12, AU: 6, GAR: 10}, 80)],
		[Vector2i(2, 2), BP.make("kopec", 909, {C: 40, FE: 40, FETI: 15, WATER: 60}, 120)],
		[Vector2i(2, 0), BP.make("sopka", 77, {FE: 20, FETI: 10, AU: 4}, 60)],
		[Vector2i(1, 2), BP.make("hora_zvrasnena", 1000, {C: 30, FE: 20, COAL: 20, GAR: 8}, 80)],
	]

## Klín (Jan 16:46, skica inspirace/skica-klin.jpg [16]): levý blok má vrstvy 1, 2, 4, 5, 6, 7, pravý 1, 3, 5, 6, 7.
## Čísla = sedimenty v pořadí tabulky: 1 hlubinný vápenec, 2 prachovec, 3 slepenec, 4 sádrovec, 5 dolomit, 6 jílová břidlice,
## 7 křemenný pískovec. Ostatní sedimenty jsou v obou blocích vypnuté. Levý se vloží první, pravý je nový blok.
const KLIN := ["deep_limestone", "siltstone", "conglomerate", "gypsum", "dolomite", "shale", "quartz_sandstone"]
const SED_OTHER := ["cave_limestone", "weathered_clay", "gravel_sand", "loess"]

static func klin_sequence() -> Array:
	var l := BP.make("louka", 4242, {C: 10}, 100)
	l.rocks_on = [KLIN[0], KLIN[1], KLIN[3], KLIN[4], KLIN[5], KLIN[6]]; l.rocks_off = SED_OTHER + [KLIN[2]]
	var r := BP.make("louka", 4343, {C: 10}, 100)
	r.rocks_on = [KLIN[0], KLIN[2], KLIN[4], KLIN[5], KLIN[6]]; r.rocks_off = SED_OTHER + [KLIN[1], KLIN[3]]
	return [[Vector2i(0, 5), l], [Vector2i(1, 5), r]]
