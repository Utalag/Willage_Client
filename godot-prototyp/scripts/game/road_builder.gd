extends Node
## Cesty (režim C): kliknutí na domek / bod = start, další body = průjezdní, poslední = cíl, Enter postaví.
## Trasu hledá scripts/roads.gd (A* s krokem ≤ 1 buňka, schody); začátek / konec na stavbě se přichytí ke dveřím.

signal cell_inspected(g: Vector2i)
signal hint_changed

const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/game/buildings.gd")

@export var island_path: NodePath
@export var ui_path: NodePath
@export var buildings_path: NodePath
@onready var island = get_node(island_path)
@onready var ui = get_node(ui_path)
@onready var buildings = get_node(buildings_path)

var road_mode := false
var road_pts: Array = []           # body trasy (globální sloupce)
var road_marks: Array[Node3D] = []
var last_road: Array = []

## trasa přes zadané body; začátek/konec na domku se přichytí ke dveřím
func build_road(pts: Array) -> bool:
	var snapped := []
	for p in pts:
		snapped.append(buildings.snap_to_door(p))
	var blocked: Dictionary = buildings.footprints()
	var path := Roads.route(island, snapped, blocked)
	if path.is_empty():
		return false
	last_road = path
	var layer := Roads.build_layer(island, path)
	island.add_child(layer)
	island.roads.append(layer)
	for g in path:
		island.occupied[g] = true
	island.refresh_blocks(Buildings.slots_of(path))   # povrch pod cestou je na buňkách
	return true

## klik v režimu cest: bod trasy (g = sloupec pod myší nebo null)
func click(g) -> void:
	if g == null:
		return
	cell_inspected.emit(g)
	g = buildings.snap_to_door(g)
	road_pts.append(g)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3; sm.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.75) if road_pts.size() == 1 else Color(1.0, 0.85, 0.4)
	sm.material = mat
	m.mesh = sm
	m.position = Vector3(g.x + 0.5, Roads.height(island, g) * Roads.CELL_H + 0.4, g.y + 0.5)
	island.add_child(m)
	road_marks.append(m)
	hint_changed.emit()

func finish() -> void:
	if road_pts.size() >= 2:
		if not build_road(road_pts):
			ui.set_hint("Cesta neexistuje: v cestě je útes (krok > 1 buňka), mlha nebo mezera. C nový pokus")
			clear_marks()
			return
	clear_marks()
	hint_changed.emit()

func clear_marks() -> void:
	for m in road_marks:
		m.queue_free()
	road_marks.clear()
	road_pts.clear()
