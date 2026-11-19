extends SceneTree
## E55 testy režimu podle dna + E47d demo testy (včetně funkce auto) → shots/test_podzemi55.txt
func _init() -> void:
	var T = load("res://scripts/podzemi52/testy52.gd")
	var L: PackedStringArray = T.run_all()
	L.append_array(T.run_e55())
	FileAccess.open(ProjectSettings.globalize_path("res://shots/test_podzemi55.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
	print("\n".join(L))
	quit()
