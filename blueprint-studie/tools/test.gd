extends SceneTree
## bez scény: godot --headless --path . -s res://tools/test.gd -- [--klic=hodnota]
const T = preload("res://scripts/bp/tests.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	print("\n".join(T.run_all(p, ProjectSettings.globalize_path("res://shots/bench.txt"))))
	quit()
