extends SceneTree
## ./run.sh dohnani54 → shots/test_dohnani54.txt (E54 dohnání, ranné zastavení, bilance)
const PR = preload("res://scripts/bp/params.gd")
const D = preload("res://scripts/dohnani54/beh54.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var L := D.run_all(p)
	print("\n".join(L))
	FileAccess.open(ProjectSettings.globalize_path("res://shots/test_dohnani54.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
	quit()
