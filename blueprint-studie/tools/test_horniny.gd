extends SceneTree
## godot --headless --path . -s res://tools/test_horniny.gd -- [--klic=hodnota]
const T = preload("res://scripts/bp/tests_horniny.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	print("\n".join(T.run_all(p, ProjectSettings.globalize_path("res://shots/bench_horniny.txt"))))
	quit()
