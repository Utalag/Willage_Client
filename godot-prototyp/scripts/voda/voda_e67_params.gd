@tool
extends "res://scripts/tunable_params.gd"
## E67 (větev e67-podzemi-okraje): laditelné prahy podzemní vody pro ladicí panel (-- --dev). Hodnoty žijí v parametrech
## bp (scripts/teren/ostrov_teren.gd T.p, CLI --bp.<klíč>=hodnota); tady se jen zrcadlí a změna se zapíše zpět do T.p.
## Simulační (voda_e67, p67_prune, p67_prune_min) se projeví při dalším plném výpočtu vody, prahy kreslení při další síti vody.
const TT = preload("res://scripts/teren/ostrov_teren.gd")

@export var voda_e67 := false                                    ## podzemí jako přetoky ve 3D + výstup ve stěně ostrova
@export var p67_prune := true                                    ## sloučit slabé větve do nejsilnější (hmota zůstává)
@export_range(0.0, 1.0, 0.005) var p67_prune_min := 0.1          ## práh slučování větví, l/s
@export_range(0.0, 1.0, 0.005) var p67_min_vytok_render := 0.02  ## výstup (vývěr ve stěně / pramen) slabší se nekreslí, l/s
@export_range(0.0, 1.0, 0.005) var p67_min_tok_render := 0.02    ## protékající větev slabší se nekreslí (řezy), l/s

static var _inst
static func inst():
	if _inst == null:
		_inst = load("res://scripts/voda/voda_e67_params.gd").new()
		_inst.pull()
		_inst.param_changed.connect(_inst._push)
	return _inst

## načti z T.p (výchozí hodnoty + CLI --bp.*)
func pull() -> void:
	TT.ensure()
	for k in param_names():
		if TT.p.has(k): set(k, TT.p[k])

func _push(prop: String) -> void:
	TT.ensure()
	TT.p[prop] = get(prop)
	if prop == "voda_e67":
		TT.p.p67_okraj = voda_e67; TT.p.p67_rezim = "pretok" if voda_e67 else ""

func rebuild_props() -> PackedStringArray:
	return PackedStringArray(["voda_e67", "p67_prune", "p67_prune_min", "p67_min_vytok_render"])

func labels() -> Dictionary:
	return {"voda_e67": "E67 přetoky ve 3D", "p67_prune": "Slučovat slabé větve", "p67_prune_min": "Práh slučování (l/s)",
		"p67_min_vytok_render": "Kreslit výstupy od (l/s)", "p67_min_tok_render": "Kreslit větve od (l/s)"}
