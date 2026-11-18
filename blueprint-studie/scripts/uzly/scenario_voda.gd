extends Node
## Uzel ScenarioVoda (E47, --voda): 3D snímky 47_voda_eroze_iso_pred / _po. Svět v2 (sled 46) → déšť (voda_sim přes celý svět)
## → eroze po vrstvách (okraj připnutý) → déšť znovu. Volná voda (kaluže, potoky) jako modré kvádry.

const T = preload("res://scripts/bp/tests_horniny.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const ES = preload("res://scripts/voda/eroze_svet.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")

@export var svet: NodePath
@export var views: NodePath
@export var ui: NodePath
@export var rig: NodePath
@export var legend: NodePath

@onready var S = get_node(svet)
@onready var V = get_node(views)
@onready var U = get_node(ui)
@onready var C = get_node(rig)
@onready var LG = get_node(legend)

func _show(w, text: String, name: String, cut := -1) -> void:
	var blocks := {}
	for s in w.order:
		var r: Dictionary = w.slots[s]
		blocks[s] = {"cells": r.cells, "water": r.get("water_sim", PackedInt32Array())}
	V.clear()
	var opts := {"wet": false}
	if cut >= 0: opts = {"wet": false, "cut_axis": "y", "cut": cut, "keep": func(s): return s.y == 0}
	V.show_blocks(blocks, opts)
	C.frame(Vector3(24, 18, 24) if cut < 0 else Vector3(24, 18, 8), 62 if cut < 0 else 46,
		Vector3(0.9, 1.0, 1.3) if cut < 0 else Vector3(0.15, 0.35, 1.0))
	U.say(text)
	LG.clear()
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/47_voda_eroze_%s.png" % name))
	print("shot ", name)

func run() -> void:
	Mesher.PALETTE = HR.palette()
	var p: Dictionary = S.params
	p.geo = "v2"
	var w0 = T.build(p)
	var v0 := VS.run(w0, p)
	await _show(w0, "E47 před erozí: 8 bloků v2, bouřka %.2f buňky × %d tiků (voda_sim přes celý svět)\nmodře volná voda po %d ticích: jezírko v prohlubni, stružky na svazích" % [float(p.voda_rain), int(p.voda_rain_ticks), int(p.voda_ticks)], "iso_pred")
	var er := ES.run(w0, p, "okraj")
	var w1 = er.world
	var v1 := VS.run(w1, p)
	await _show(w1, "E47 po erozi po vrstvách (%d kapek na blok, okraj připnutý → švy spojité)\nkoryta prořízla půdu a odkryla horniny, nános štěrku/písku; voda po stejné bouřce" % int(p.ero_droplets), "iso_po")
	await _show(w0, "E47 před erozí, řez y = 8 řadou hora vyzdvižená | prohlubeň | sopka", "iso_rez_pred", 8)
	await _show(w1, "E47 po erozi, řez y = 8: vrcholy a svahy snížené, hranice vrstev beze změny", "iso_rez_po", 8)
