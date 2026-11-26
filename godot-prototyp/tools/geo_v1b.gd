extends SceneTree
## Krok 3b: testy A1 (hostitelé útvarů) a A10 (šum mocnosti podle horniny), celé bloky 128 m z funkce světa.
## godot --headless --path . -s tools/geo_v1b.gd -- --rezim=hostitele|vrstvy|sum --bloky=14,14;15,15 --xy=2 --z=0.5 --out=res://shots/krok03b --jmeno=x.json
const TH = preload("res://tools/geo_v1b/test_hostitele.gd")
const TV = preload("res://tools/geo_v1b/test_vrstvy.gd")
const TS = preload("res://tools/geo_v1b/test_sum.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _bloky() -> Array:
	var out := []
	for b in _arg("bloky", "14,14;15,15;16,16").split(";"):
		var q := b.split(",")
		out.append([int(q[0]), int(q[1])])
	return out

func _init() -> void:
	var par := {"seed": int(_arg("seed", "49"))}
	var rezim := _arg("rezim", "sum")
	var od := _arg("out", "res://shots/krok03b")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(od))
	var res := {}
	var t0 := Time.get_ticks_msec()
	match rezim:
		"hostitele": res = TH.new().run(par, _bloky(), float(_arg("xy", "2")), float(_arg("z", "0.5")))
		"vrstvy": res = TV.new().run(par, _bloky(), float(_arg("xy", "2")))
		"sum": res = TS.new().run(par)
	res["ms"] = Time.get_ticks_msec() - t0
	res["bloky"] = _bloky()
	var f := FileAccess.open(ProjectSettings.globalize_path(od + "/" + _arg("jmeno", rezim + ".json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	quit(0 if bool(res.get("ok", res.get("chyb", 1) == 0)) else 1)
