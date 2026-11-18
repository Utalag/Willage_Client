extends Node
## Uzel Placer: vložení blueprintu po snímcích (kroky z pipeline.gd, nejvýš budget_ms na snímek) s průběhem.
## Výsledek je stejný jako při běhu naráz (stejné kroky ve stejném pořadí), ověřuje to hash v režimu --shots.

signal progress(fraction: float, label: String)
signal finished(rec: Dictionary)

const PL = preload("res://scripts/bp/pipeline.gd")

@export var svet: NodePath
var paused := false
var _ctx := {}
var _steps := []
var _i := 0
var _budget := 6.0

func busy() -> bool:
	return _i < _steps.size()

func start(slot: Vector2i, bp: Dictionary) -> void:
	var s = get_node(svet)
	_ctx = PL.new_ctx(s.world, slot, bp, s.params)
	_steps = PL.steps(_ctx)
	_i = 0
	_budget = float(s.params.budget_ms)
	progress.emit(0.0, _steps[0][0])

func _process(_dt: float) -> void:
	if paused or not busy():
		return
	var t0 := Time.get_ticks_usec()
	while busy():
		var tq := Time.get_ticks_usec()
		_steps[_i][1].call()
		var key: String = _steps[_i][0].split(":")[0]
		_ctx.ms[key] = _ctx.ms.get(key, 0.0) + (Time.get_ticks_usec() - tq) / 1000.0
		_i += 1
		if (Time.get_ticks_usec() - t0) / 1000.0 >= _budget:
			break
	if busy():
		progress.emit(float(_i) / _steps.size(), _steps[_i][0])
	else:
		var rec := PL.record(_ctx)
		get_node(svet).world.commit(rec)
		progress.emit(1.0, "hotovo")
		finished.emit(rec)
