extends Node
## Uzel ScenarioSvet8 (E49, --svet8): 3D snímek detailního světa 8 × 8 bloků (bez textu) → shots/49_svet_8x8_iso.png

const B = preload("res://scripts/svet8/beh.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")

@export var svet: NodePath
@export var views: NodePath
@export var ui: NodePath
@export var rig: NodePath
@export var legend: NodePath

func run() -> void:
	Mesher.PALETTE = HR.palette()
	var p: Dictionary = get_node(svet).params
	p.geo = "v2"
	var d := B.detail(B.coarse(p, int(p.s8_frames)), p)   # stejný počet dávek eroze jako bench (dávky mají vlastní seed)
	var V = get_node(views)
	V.clear(); V.show_blocks(d.world.slots, {"wet": false})
	get_node(legend).clear(); get_node(ui).say("")
	get_node(ui).get_node("Hud").visible = false
	get_node(rig).frame(Vector3(64, 14, 64), 150)
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/49_svet_8x8_iso.png"))
	print("shot svet8 iso")
