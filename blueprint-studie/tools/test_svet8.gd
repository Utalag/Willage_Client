extends SceneTree
## godot --headless --path . -s res://tools/test_svet8.gd -- [--klic=hodnota]   (E49 svět 8 × 8)
const B = preload("res://scripts/svet8/beh.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	print("\n".join(B.run_all(p, ProjectSettings.globalize_path("res://shots/bench_svet8.txt"), ProjectSettings.globalize_path("res://shots/svet8.json"))))
	quit()
