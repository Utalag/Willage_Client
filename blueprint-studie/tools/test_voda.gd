extends SceneTree
## godot --headless --path . -s res://tools/test_voda.gd -- [--klic=hodnota]   (E47 voda a eroze)
const TV = preload("res://scripts/voda/tests_voda.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	print("\n".join(TV.run_all(p, ProjectSettings.globalize_path("res://shots/bench_voda.txt"), ProjectSettings.globalize_path("res://shots/voda_eroze.json"))))
	quit()
