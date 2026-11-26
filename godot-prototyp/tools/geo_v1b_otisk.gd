extends SceneTree
## Otisk materiálů bloků 128 m (krok 3b). Spuštění: godot --headless --path . -s tools/geo_v1b_otisk.gd -- --a1=0|1 --a10=0|1 --bloky=14,14;15,15 --xy=2 --z=1
## Používá jen `vypln_sloupec`, takže běží i na kódu před krokem 3b (porovnání bitové shody).
const BL = preload("res://tools/geo_v1b/blok.gd")
const S = preload("res://scripts/v1/svet_fn.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	var par := {"seed": int(_arg("seed", "49"))}
	if _arg("a1", "1") == "0": par["a1_hostitele"] = false
	if _arg("a10", "1") == "0": par["a10_sum_hornin"] = false
	var svet = S.new(par)
	var xy := float(_arg("xy", "2")); var z := float(_arg("z", "1"))
	for b in _arg("bloky", "14,14").split(";"):
		var q := b.split(",")
		var t0 := Time.get_ticks_msec()
		var o: Dictionary = BL.otisk(svet, int(q[0]), int(q[1]), xy, z, 128.0)
		print("OTISK blok=", b, " hash=", o.hash, " bunek=", o.bunek, " ms=", Time.get_ticks_msec() - t0)
	quit()
