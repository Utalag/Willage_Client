extends SceneTree
## godot --headless --path . -s res://tools/test_voda_b.gd -- [--b] [--klic=hodnota]
## výchozí E47c (prameny) → shots/bench_voda_c.txt + voda_eroze_c.json; --b = E47b (voda z plochy, srovnání) → bench_voda_b.txt + voda_eroze_b.json
const TB = preload("res://scripts/voda/tests_voda_b.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var p := PR.apply_args(PR.defaults(), args)
	var g := func(n): return ProjectSettings.globalize_path("res://shots/" + n)
	if "--b" in args: print("\n".join(TB.run_b(p, g.call("bench_voda_b.txt"), g.call("voda_eroze_b.json"))))
	else: print("\n".join(TB.run_all(p, g.call("bench_voda_c.txt"), g.call("voda_eroze_c.json"))))
	quit()
