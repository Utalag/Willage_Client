extends SceneTree
## godot --headless --path . -s res://tools/test_eroze51.gd -- [--klic=hodnota]   (E51 eroze a usazování událostmi)
const B = preload("res://scripts/eroze51/beh51.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var g := func(f): return ProjectSettings.globalize_path("res://shots/" + f)
	print("\n".join(B.run_all(p, g.call("test_eroze51.txt"), g.call("bench_eroze51.txt"), g.call("eroze51.json"))))
	quit()
