extends Node3D
## Uzel Preview: průhledný náhled blueprintu ve slotu. Sloupce změněné dorovnáním okrajů oranžově, ostatní zeleně;
## volitelně jen šablona (před dorovnáním).

const Mat = preload("res://scripts/kopie/mat.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")
const BV = preload("res://scripts/uzly/block_views.gd")

var ghost: StandardMaterial3D

func _ready() -> void:
	ghost = StandardMaterial3D.new()
	ghost.vertex_color_use_as_albedo = true
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = Color(1, 1, 1, 0.6)
	ghost.cull_mode = BaseMaterial3D.CULL_BACK

func clear() -> void:
	for c in get_children():
		c.queue_free()

## ctx po preview_steps: hm (dorovnaný), hm_raw, changed
func show_ghost(ctx: Dictionary, template_only := false) -> void:
	clear()
	var hm: PackedInt32Array = ctx.hm_raw if template_only else ctx.hm
	var cells := PackedByteArray(); cells.resize(16 * 16 * 64)
	for i in 256:
		var m := Mat.GRASS
		if not template_only and ctx.changed[i]:
			m = Mat.CLAY_DEPOSIT   # oranžová = dorovnaný okraj
		for z in hm[i]:
			cells[i * 64 + z] = m
	var mi := MeshInstance3D.new()
	mi.mesh = Mesher.build(cells, [null, null, null, null], -1)
	mi.material_override = ghost
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = BV.slot_pos(ctx.slot)
	add_child(mi)
