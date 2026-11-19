extends SceneTree
## godot --headless --path . -s res://tools/cache_podzemi52.gd -- [--klic=hodnota]   (E52: vygeneruje svět svet64 do cache)
const C = preload("res://scripts/podzemi52/cache.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var path := ProjectSettings.globalize_path(String(p.p52_cache))
	var d := C.build(p, path)
	print("cache %s: %d bloků, hash jemných buněk %s, %.1f s" % [path, d.order.size(), d.hash, float(d.ms) / 1000.0])
	quit()
