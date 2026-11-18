extends SceneTree
## godot --headless --path . -s res://tools/test_svet64.gd -- [--klic=hodnota]   (E50 svět 8 × 8 po 64 × 64 × 256 buňkách)
const B = preload("res://scripts/svet64/beh64.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	print("\n".join(B.run_all(p, ProjectSettings.globalize_path("res://shots/%s.txt" % p.s64_out), ProjectSettings.globalize_path("res://shots/svet64"))))
	quit()
