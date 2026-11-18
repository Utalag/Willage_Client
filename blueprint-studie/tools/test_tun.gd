extends SceneTree
## godot --headless --path . -s res://tools/test_tun.gd   (Janův příklad plnění prohlubně, → shots/test_tun.txt)
const TT = preload("res://scripts/voda/tests_tun.gd")
func _init() -> void:
	var L := TT.run_all()
	FileAccess.open(ProjectSettings.globalize_path("res://shots/test_tun.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
	print("\n".join(L))
	quit()
