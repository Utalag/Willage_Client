extends Node
## Stavby z lišty: domek, studna, mlýn, políčko (Blender glTF, načtené za běhu bez importu).
## Půdorys size × size kolem středu, dveře před přední stranou (+z, otočené o rot·90°). Stavba stojí na nejvyšší
## buňce pod půdorysem. Náhled (duch) jede za myší: zelený = lze postavit.

signal cell_inspected(g: Vector2i)   # panel vpravo má ukázat blok pod sloupcem g
signal hint_changed                  # změnil se režim → přepsat nápovědu

const Roads = preload("res://scripts/roads.gd")
const Toon = preload("res://scripts/toon.gd")
const BS := 16

const BTYPES := [
	{"name": "Domek", "glb": "domek", "size": 3, "col": Color(0.95, 0.70, 0.80)},
	{"name": "Studna", "glb": "studna", "size": 1, "col": Color(0.70, 0.82, 0.98)},
	{"name": "Větrný mlýn", "glb": "mlyn", "size": 3, "col": Color(0.98, 0.90, 0.75)},
	{"name": "Políčko", "glb": "pole", "size": 3, "col": Color(0.75, 0.92, 0.65)},
]

@export var island_path: NodePath
@export var ui_path: NodePath
@onready var island = get_node(island_path)
@onready var ui = get_node(ui_path)

var houses: Array[Vector2i] = []   # středy staveb (globální sloupce)
var bdata := {}          # střed -> {t, rot}
var _bscenes := {}       # typ -> [GLTFDocument, GLTFState]
var build_sel := -1              # vybraná stavba v liště (−1 = žádná)
var build_rot := 0
var build_ghost: Node3D
var build_mark: MeshInstance3D
var build_at = null
var ghost_mat: StandardMaterial3D

func names_and_colors() -> Array:
	var bn := []; var bc := []
	for t in BTYPES: bn.append(t.name); bc.append(t.col)
	return [bn, bc]

func fp_of(c: Vector2i, t: int) -> Array:
	var hs: int = BTYPES[t].size / 2
	var out := []
	for dx in range(-hs, hs + 1):
		for dz in range(-hs, hs + 1):
			out.append(c + Vector2i(dx, dz))
	return out

func door_of(c: Vector2i, t: int, rot: int) -> Vector2i:
	var o := Vector2i(0, BTYPES[t].size / 2 + 1)
	for i in rot:
		o = Vector2i(-o.y, o.x)
	return c + o

func fp(c: Vector2i) -> Array:
	return fp_of(c, bdata[c].t if bdata.has(c) else 0)

func door(c: Vector2i) -> Vector2i:
	return door_of(c, bdata[c].t if bdata.has(c) else 0, bdata[c].rot if bdata.has(c) else 0)

func _bscene(t: int) -> Node3D:
	if not _bscenes.has(t):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/%s.glb" % BTYPES[t].glb), "res://assets/", st) != OK:
			push_warning("%s.glb se nepodařilo načíst" % BTYPES[t].glb)
			return null
		_bscenes[t] = [doc, st]
	var node: Node3D = _bscenes[t][0].generate_scene(_bscenes[t][1])
	Toon.apply_to(node, 0.035)
	return node

func add_house(c: Vector2i) -> void:
	add_building(c, 0, 0)

func add_building(c: Vector2i, t: int, rot: int) -> void:
	var node := _bscene(t)
	if node == null:
		return
	var top := 0
	for f in fp_of(c, t):
		top = maxi(top, Roads.height(island, f))
		island.occupied[f] = true
	node.position = Vector3(c.x + 0.5, top * 0.5, c.y + 0.5)
	node.rotation.y = deg_to_rad(-90.0 * rot)
	island.add_child(node)
	island.props.append(node)
	houses.append(c)
	bdata[c] = {"t": t, "rot": rot}
	island.refresh_blocks(slots_of(fp_of(c, t)))   # povrch pod stavbou je na buňkách

## místo pro stavbu: půdorys v ostrově, volný, rozdíl výšek ≤ 1, dveře volné a nejvýš o 1 buňku jinde
func site_ok(c: Vector2i, t: int, rot: int) -> bool:
	var lo := 999; var hi := -1
	for f in fp_of(c, t):
		var h := Roads.height(island, f)
		if h < 0 or island.occupied.has(f):
			return false
		lo = mini(lo, h); hi = maxi(hi, h)
	var fpc := fp_of(c, t)
	for h in houses:   # nezastavět dveře jiné stavby
		if fpc.has(door(h)):
			return false
	var dc := door_of(c, t, rot)
	var dh := Roads.height(island, dc)
	return hi - lo <= 1 and dh >= 0 and not island.occupied.has(dc) and absi(dh - hi) <= 1

static func slots_of(cells: Array) -> Array:
	var out := []
	for g in cells:
		var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
		if not out.has(s):
			out.append(s)
	return out

## nejbližší rovné místo pro stavbu ve slotu (rozdíl výšek půdorysu ≤ 1, dveře dosažitelné)
func find_site(slot: Vector2i, reach := {}, t := 0, rot := 0) -> Variant:
	var best = null
	var bd := 1e9
	for lx in range(2, 14):
		for ly in range(2, 12):
			var c := slot * BS + Vector2i(lx, ly)
			if not site_ok(c, t, rot):
				continue
			if not reach.is_empty() and not reach.has(door_of(c, t, rot)):
				continue
			var d := Vector2(lx - 7.5, ly - 7.0).length()
			if d < bd:
				bd = d; best = c
	return best

## sloupec na stavbě → její dveře (začátek / konec cesty)
func snap_to_door(g: Vector2i) -> Vector2i:
	for h in houses:
		if fp(h).has(g):
			return door(h)
	return g

func building_at(g: Vector2i):
	for h in houses:
		if fp(h).has(g):
			return h
	return null

## všechny půdorysy staveb (pro trasy cest)
func footprints() -> Dictionary:
	var blocked := {}
	for h in houses:
		for f in fp(h):
			blocked[f] = true
	return blocked

# ---------------------------------------------------------------- náhled stavby z lišty
## výběr stavby i (ostatní režimy zruší Main před voláním)
func pick(i: int) -> void:
	build_sel = i
	ui.select_building(i)
	if build_ghost: build_ghost.queue_free()
	build_ghost = _bscene(i)
	if build_ghost == null:
		build_sel = -1
		return
	build_ghost.visible = false
	_ghostify(build_ghost)
	island.add_child(build_ghost)
	if build_mark == null:
		build_mark = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		build_mark.mesh = pm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		build_mark.material_override = mm
		island.add_child(build_mark)
	build_mark.visible = false
	hint_changed.emit()

func _ghostify(n: Node) -> void:
	if ghost_mat == null:
		ghost_mat = StandardMaterial3D.new()
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if n is MeshInstance3D:
		n.material_override = ghost_mat
		n.material_overlay = null
		for i in n.get_surface_override_material_count():
			n.set_surface_override_material(i, null)
	for c in n.get_children():
		_ghostify(c)

func hover(g) -> void:
	if build_sel < 0 or build_ghost == null:
		return
	build_at = g
	if g == null:
		build_ghost.visible = false; build_mark.visible = false
		return
	var top := 0
	for f in fp_of(g, build_sel):
		top = maxi(top, Roads.height(island, f))
	var ok := site_ok(g, build_sel, build_rot)
	build_ghost.visible = true
	build_ghost.position = Vector3(g.x + 0.5, top * 0.5, g.y + 0.5)
	build_ghost.rotation.y = deg_to_rad(-90.0 * build_rot)
	var sz: int = BTYPES[build_sel].size
	(build_mark.mesh as PlaneMesh).size = Vector2(sz + 0.8, sz + 0.8)
	build_mark.position = Vector3(g.x + 0.5, top * 0.5 + 0.06, g.y + 0.5)
	(build_mark.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.95, 0.55, 0.55) if ok else Color(1.0, 0.40, 0.45, 0.55)
	ghost_mat.albedo_color = Color(0.55, 1.0, 0.65, 0.6) if ok else Color(1.0, 0.45, 0.5, 0.6)
	build_mark.visible = true

func click() -> void:
	if build_at != null and site_ok(build_at, build_sel, build_rot):
		add_building(build_at, build_sel, build_rot)
		cell_inspected.emit(build_at)
		cancel()

func cancel() -> void:
	build_sel = -1
	build_at = null
	if build_ghost: build_ghost.queue_free(); build_ghost = null
	if build_mark: build_mark.visible = false
	if ui: ui.select_building(-1)
	hint_changed.emit()

## glTF materiály z Blenderu: bez lesku, o kousek tmavší (jinak jsou ve scéně přesvícené). Zatím nepoužito.
static func tame_materials(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var c: StandardMaterial3D = m.duplicate()
				c.albedo_color = c.albedo_color.darkened(0.18)
				c.roughness = 1.0
				c.metallic = 0.0
				c.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				n.set_surface_override_material(i, c)
	for ch in n.get_children():
		tame_materials(ch)
