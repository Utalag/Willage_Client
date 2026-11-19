extends SceneTree
## E66 test parity: stejné testy jako ve studii, ale nad přenesenými moduly prototypu (scripts/teren, scripts/voda, scripts/studie_testy).
## godot --headless --path . -s res://tools/parita_e66.gd -- --test=v1|sled46|svet8|voda|voda_b|voda_bb|vse
## Porovná otisky s referencí studie (E61) a vypíše PARITA OK / NESHODA. Výstupy testů jdou do shots/66_parita/.
const PR = preload("res://scripts/teren/params.gd")
const REF := {"v1": "dda863feffe6f611", "sled46": "d8af7f59b6f8da70", "svet8": "ec0681cc6426", "voda": "a14136754dd1", "voda_b": "5ae2b366e84a", "voda_bb": "e8cbbc78ca88"}
const PAT := {"v1": "běh 2 ", "sled46": "2 běhy:", "svet8": "determinismus 2×:", "voda": "determinismus eroze (okraj) 2×:", "voda_b": "determinismus 2×:", "voda_bb": "determinismus 2×:"}

func _run(t: String, p: Dictionary) -> PackedStringArray:
	var g := func(n): return ProjectSettings.globalize_path("res://shots/66_parita/" + n)
	match t:
		"v1": return load("res://scripts/studie_testy/tests.gd").run_all(p, g.call("bench.txt"))
		"sled46": return load("res://scripts/studie_testy/tests_horniny.gd").run_all(p, g.call("bench_horniny.txt"))
		"svet8": return load("res://scripts/studie_testy/beh.gd").run_all(p, g.call("bench_svet8.txt"), g.call("svet8.json"))
		"voda": return load("res://scripts/studie_testy/tests_voda.gd").run_all(p, g.call("bench_voda.txt"), g.call("voda_eroze.json"))
		"voda_b": return load("res://scripts/studie_testy/tests_voda_b.gd").run_all(p, g.call("bench_voda_c.txt"), g.call("voda_eroze_c.json"))
		"voda_bb": return load("res://scripts/studie_testy/tests_voda_b.gd").run_b(p, g.call("bench_voda_b.txt"), g.call("voda_eroze_b.json"))
	return PackedStringArray()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/66_parita"))
	var args := OS.get_cmdline_user_args()
	var t := "vse"
	var rest := PackedStringArray()
	for a in args:
		if a.begins_with("--test="): t = a.substr(7)
		else: rest.append(a)
	var p := PR.apply_args(PR.defaults(), rest)
	var tests: Array = REF.keys() if t == "vse" else [t]
	var ok := true
	var out := PackedStringArray()
	for k in tests:
		var t0 := Time.get_ticks_msec()
		var L := _run(k, p)
		var found := ""
		for line in "\n".join(L).split("\n"):
			if String(line).begins_with(PAT[k]) and String(line).contains("STEJNÉ"):
				found = line
		var hit := found.contains(REF[k])
		ok = ok and hit
		var msg := "PARITA %s %s: %s (ref %s, %.1f s) | %s" % ["OK" if hit else "NESHODA", k, "otisk sedí" if hit else "jiný otisk", REF[k], (Time.get_ticks_msec() - t0) / 1000.0, found]
		print(msg); out.append(msg)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/66_parita/parita_%s.txt" % t), FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	print("PARITA CELKEM: %s" % ("OK" if ok else "NESHODA"))
	quit(0 if ok else 1)
