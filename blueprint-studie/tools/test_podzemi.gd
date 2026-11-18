extends SceneTree
## godot --headless --path . -s res://tools/test_podzemi.gd   (E47d testy podzemí → shots/test_podzemi.txt)
const TP = preload("res://scripts/voda/tests_podzemi.gd")
func _init() -> void:
	var L := TP.run_all()
	FileAccess.open(ProjectSettings.globalize_path("res://shots/test_podzemi.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
	print("\n".join(L))
	quit()
