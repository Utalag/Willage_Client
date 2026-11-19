extends Node
## Tok vody po kopání (simulace scripts/gen3/water_flow.gd). Kopání tok spustí přes start(), ve hře se posouvá
## v _process po FLOW_BUDGET_MS za snímek a překresluje jen vodu; headless (flow_sync) se dopočítá hned.

const WaterFlow = preload("res://scripts/gen3/water_flow.gd")
const FLOW_BUDGET_MS := 6.0

@export var island_path: NodePath
@onready var island = get_node(island_path)

var flows: Array = []            # rozběhnuté toky vody [{slot, flow, delta, w_old}] (water_flow.gd)
var flow_sync := false           # true = tok se dopočítá hned při kopání (headless, testy)
var last_flow := {}              # poslední dokončený tok (box, tiky, ms, kontrola)

## Jan 20:39: místní tok vody po otevření buňky (jeskyně, nasycená půda); dl = záznam delty kopání
func start(b, sl: Vector2i, lx: int, ly: int, lz: int, dl: Dictionary, w_old: int) -> void:
	var f = WaterFlow.start(b, lx, ly, lz)
	if f != null:
		flows.append({"slot": sl, "flow": f, "delta": dl, "w_old": w_old, "sync": flow_sync})
		if flow_sync:
			finish_all()

func _process(_dt: float) -> void:
	tick()
	# E66 gen bp: kroky R podzemí (pevný počet operací na krok, ne podle času → výsledek nezávisí na snímcích)
	if island.voda != null:
		if flow_sync: island.water_finish()
		else: island.water_step(int(island.TerenBP.p.get("voda_r_kroku", 1)))

func tick() -> void:
	if flows.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var e: Dictionary = flows[0]
	while not e.flow.done and (Time.get_ticks_usec() - t0) < FLOW_BUDGET_MS * 1000:
		e.flow.step_n(4)
	if e.flow.done:
		_finish(e)
		flows.pop_front()
	else:
		e.flow.write_preview()
		island.remesh_water(e.slot)

func finish_all() -> void:
	if island.voda != null: island.water_finish()
	while not flows.is_empty():
		_finish(flows.pop_front())

## konečný zápis (zachování součtu), kontrola jako delta, záznam do delty kopání
func _finish(e: Dictionary) -> void:
	var f = e.flow
	f.finish()
	var v: Dictionary = WaterFlow.validate(f)
	last_flow = {"slot": e.slot, "box": f.box(), "ticks": f.ticks, "ms": f.ms, "cells": f.box_cells(), "valid": v}
	if not v.ok:
		push_warning("tok vody: kontrola delty selhala %s" % str(v.errors))
	e.delta["flow"] = {"box": f.box(), "ticks": f.ticks, "moved_units": v.moved_units, "water": f.changes()}
	if not e.get("sync", false):
		island._remesh(e.slot)   # mokrá půda a voda z dat (při synchronním toku překreslí kopání samo)
