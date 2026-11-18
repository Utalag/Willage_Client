extends Node3D
## Uzel BlockViews: kreslí vložené bloky (toon), volitelně řez a obarvení mokré půdy; volná voda jako modré kvádry.

const Mat = preload("res://scripts/kopie/mat.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")
const SD = preload("res://scripts/bp/sides.gd")

var toon: ShaderMaterial
var water_mat: StandardMaterial3D

func _ready() -> void:
	toon = ShaderMaterial.new()
	toon.shader = load("res://terrain_toon.gdshader")
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.35, 0.62, 0.95, 0.75)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func clear() -> void:
	for c in get_children():
		c.queue_free()

static func slot_pos(s: Vector2i) -> Vector3:
	return Vector3(s.x * 16, 0, s.y * 16)

## blocks: {Vector2i: {cells, water?}}; opts: cut_axis ("x"/"y"/""), cut (místní souřadnice, maže > cut), keep (Callable(slot) -> bool), lift (y posun), wet (bool)
func show_blocks(blocks: Dictionary, opts := {}) -> void:
	var axis: String = opts.get("cut_axis", "")
	var cut: int = opts.get("cut", 99)
	var lift: float = opts.get("lift", 0.0)
	for s in blocks:
		if opts.has("keep") and not opts.keep.call(s):
			continue
		var r: Dictionary = blocks[s]
		var cells: PackedByteArray = r.cells.duplicate()
		var water: PackedInt32Array = r.get("water", PackedInt32Array())
		var pond := []
		for c in cells.size():
			var x := c / 1024; var y := (c / 64) % 16
			if (axis == "y" and y > cut) or (axis == "x" and x > cut):
				cells[c] = 0
				continue
			if water.size() == 0 or water[c] <= 0:
				continue
			if cells[c] == Mat.AIR:
				pond.append(c)
			elif opts.get("wet", true):
				if cells[c] == Mat.DIRT or cells[c] == Mat.GRASS: cells[c] = Mat.VIEW_WET_DIRT
				elif cells[c] == Mat.SAND: cells[c] = Mat.VIEW_WET_SAND
		var nbs := [null, null, null, null]
		if axis == "":
			for d in 4:
				var n: Vector2i = s + SD.DIRS[d]
				if blocks.has(n): nbs[d] = blocks[n].cells
		var m := MeshInstance3D.new()
		m.mesh = Mesher.build(cells, nbs, -1)
		m.material_override = toon
		m.position = slot_pos(s) + Vector3(0, lift, 0)
		add_child(m)
		for c in pond:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1, 0.5 * water[c] / 4096.0, 1)
			b.mesh = bm; b.material_override = water_mat
			b.position = slot_pos(s) + Vector3(c / 1024 + 0.5, lift + (c % 64) * 0.5 + bm.size.y * 0.5, (c / 64) % 16 + 0.5)
			add_child(b)
