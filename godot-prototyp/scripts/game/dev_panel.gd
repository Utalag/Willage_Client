extends Node
## Vývojový ladicí panel: zaregistruje ukazatele do ParamRegistry a jen s `-- --dev` načte doplňky
## res://addons/*/dev_runtime.gd (jako děti tohoto uzlu). Bez `--dev` a v exportu (doplňky vyřazené) nedělá nic.

const ParamRegistry_ = preload("res://scripts/param_registry.gd")

@export var island_path: NodePath
@onready var island = get_node(island_path)

## volá Main na konci startu (po ostrově, UI a kameře)
func activate() -> void:
	ParamRegistry_.register_stat("Instance vegetace (kreslené)", self, &"veg_instances")
	ParamRegistry_.register_stat("Bloků", self, &"block_count")
	ParamRegistry_.register("Voda E67 (podzemí, prahy)", load("res://scripts/voda/voda_e67_params.gd").inst())
	ParamRegistry_.load_dev_addons(self)   # jen s -- --dev a jen když doplněk existuje (v exportu není)
	add_child(load("res://scripts/game/zkusebni/panel.gd").new())   # E95: zkušební panel přepínačů (větev zkusebni-vse)

func block_count() -> int:
	return island.blocks.size()

func veg_instances() -> int:
	var n := 0
	for v in island.vegs.values():
		for c in v.get_children():
			if c is MultiMeshInstance3D and c.multimesh:
				n += c.multimesh.instance_count if c.multimesh.visible_instance_count < 0 else c.multimesh.visible_instance_count
	return n
