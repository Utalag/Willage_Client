extends SceneTree
## godot --headless --path . -s res://tools/test_podzemi52.gd -- --p52_var=testy|slovnik|pole|funkce|povrch [--p52_ug_n=32 --p52_rezim=preliv …]
## E52: každá varianta ve vlastním procesu (peak paměti patří jen jí) → shots/podzemi52/<název>.json; testy → shots/test_podzemi52.txt
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	if String(p.p52_var) == "testy":
		var T = load("res://scripts/podzemi52/testy52.gd")
		var L: PackedStringArray = T.run_all()
		FileAccess.open(ProjectSettings.globalize_path("res://shots/test_podzemi52.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
		print("\n".join(L))
	else:
		var B = load("res://scripts/podzemi52/beh52.gd")
		print(B.run_one(p))
	quit()
