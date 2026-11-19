extends SceneTree
## E66 test vody ostrova bez scény: vygeneruje startovní bloky gen bp (jako Island.generate_start), postaví vodu
## (scripts/voda/ostrov_voda.gd), pak provede výkopy u vody (lokální přepočet + kroky R) a po každém porovná se
## čerstvým plným výpočtem (check_full). Volby: --vykopu=N, --hloubka=N buněk, --kontrola=0|1, --bloky=kind:seed,... ,
## --bp.<param>=hodnota (parametry studie). Výstup: shots/66_parita/voda_e66.json.
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var spec := _arg("bloky", "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404").split(";")
	var blocks := {}
	var gen := []
	for e in spec:
		var a := e.split(":")
		var xy := a[0].split(",")
		var b := Block.new()
		b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null])
		T.commit(b)
		blocks[b.slot] = b
		gen.append(b.gen_ms)
		print("blok %s %s seed %d: %.0f ms" % [b.slot, b.kind, b.seed, b.gen_ms])
	var v := OV.new()
	v.build(blocks)
	print("voda plný výpočet: ", v.ms)
	print("souhrn: ", v.summary())
	var n := int(_arg("vykopu", "12")); var dep := int(_arg("hloubka", "2")); var chk := _arg("kontrola", "1") == "1"
	# výkopy: sloupce koryta / tůní / u pramenů, deterministicky
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0: cand.append(i)
	for sp in v.springs: cand.append(sp.gi)
	var edits := []; var bad_tot := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	for k in mini(n, cand.size()):
		var gi: int = cand[rng.randi_range(0, cand.size() - 1)]
		var a := v.slot_of(gi)
		var b = blocks[a[0]]
		var ci: int = a[1] * 16 + a[2]
		var h0: int = b.hm[ci]
		var nh := maxi(h0 - dep, 1)
		for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
		b.hm[ci] = nh
		var r := v.edit(a[0], a[1], a[2], nh)
		var steps := 0; var smax := 0.0
		while v.pending():
			var t := Time.get_ticks_usec()
			v.step(); steps += 1
			smax = maxf(smax, (Time.get_ticks_usec() - t) / 1000.0)
		var e := {"gi": gi, "ms": r.ms, "surf_ms": r.surf_ms, "ug_ms": (r.ug.ms if r.has("ug") else 0.0), "r_steps": steps, "r_step_max_ms": smax,
			"okno": r.surf.get("window", 0), "sucho": r.surf.get("dry", false)}
		if chk:
			var bad: Dictionary = v.check_full()
			e.neshod = bad
			bad_tot += int(bad.fill) + int(bad.eff) + int(bad.to)
		edits.append(e)
		print("výkop %d sloupec %d %d→%d: %.1f ms (povrch %.1f, podzemí %.1f), kroků R %d (max %.1f ms)%s" % [k + 1, gi, h0, nh, r.ms, r.surf_ms, e.ug_ms, steps, smax, (" neshod %s" % str(e.neshod)) if chk else ""])
	var out := {"bloky_ms": gen, "voda_ms": v.ms, "souhrn": v.summary(), "vykopy": edits, "neshod_celkem": bad_tot, "souhrn_po": v.summary(), "ug_stats": (v.ug._st if not v.ug.is_empty() else {})}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/66_parita"))
	FileAccess.open(ProjectSettings.globalize_path("res://shots/66_parita/voda_e66.json"), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	print("souhrn po výkopech: ", out.souhrn_po)
	print("podzemí počítadla: ", out.ug_stats)
	print("neshod s plným výpočtem celkem: ", bad_tot)
	quit()
