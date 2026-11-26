extends SceneTree
## E96: ostrov = jeden blok 128 m (scripts/teren/blok96.gd) bez scény: generování 256 bloků (gen bp přes base_hm), plná voda
## (ostrov_voda, E68), výkopy u vody s lokálním přepočtem a kroky R, paměť. Volby: --vykopu=N (8), --kontrola=0|1 (0),
## --bp.<param> (parametry studie a p96_*), --out=cesta.json. Funguje i bez p96_blok128 (nástroj ho nepotřebuje, hru nemění).
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const B96 = preload("res://scripts/teren/blok96.gd")
const M = preload("res://scripts/teren/svet64/mereni.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _rss() -> float:
	var o := []
	OS.execute("sh", ["-c", "grep VmRSS /proc/%d/status" % OS.get_process_id()], o)
	return float(String(o[0]).split(":")[1].strip_edges().split(" ")[0]) / 1024.0 if o.size() > 0 and ":" in String(o[0]) else 0.0

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset(B96.OFF, B96.SIZE)
	var r := {"rss_start_mb": _rss()}
	var t0 := Time.get_ticks_usec()
	var spec := B96.start(T.p)
	r.funkce_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var blocks := {}; var kinds := {}; var gen := []
	var lo := 999; var hi := -1
	t0 = Time.get_ticks_usec()
	for e in spec:
		var b := Block.new(); b.kind = e.kind; b.seed = e.seed; b.slot = e.slot
		b.set_meta("p96_hm", e.hm)
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
		gen.append(b.gen_ms); kinds[b.kind] = kinds.get(b.kind, 0) + 1
		for v in b.hm: lo = mini(lo, v); hi = maxi(hi, v)
		if blocks.size() % 16 == 0 or blocks.size() <= 4: print("  blok %d/%d %s %s %.0f ms (%.0f s)" % [blocks.size(), spec.size(), b.slot, b.kind, b.gen_ms, (Time.get_ticks_usec() - t0) / 1e6])
		if blocks.size() >= int(_arg("bloku", "999")): break
	r.bloky_ms = (Time.get_ticks_usec() - t0) / 1000.0
	gen.sort()
	r.blok_ms_p50 = gen[gen.size() / 2]; r.blok_ms_max = gen[-1]
	r.typy = kinds; r.vyska_bunky = [lo, hi]
	r.rss_po_blocich_mb = _rss()
	var veg := 0
	for s in blocks: veg += blocks[s].veg.size()
	r.rostlin = veg
	print("E96 bloky: %d za %.0f ms (p50 %.0f, max %.0f), typy %s, výška %d–%d buněk, RSS %.0f MB" % [blocks.size(), r.bloky_ms, r.blok_ms_p50, r.blok_ms_max, kinds, lo, hi, r.rss_po_blocich_mb])
	var v := OV.new()
	t0 = Time.get_ticks_usec()
	v.build(blocks)
	r.voda_ms = (Time.get_ticks_usec() - t0) / 1000.0
	r.voda_casti = v.ms
	r.souhrn = v.summary()
	r.rss_po_vode_mb = _rss()
	print("voda: ", v.ms)
	print("souhrn: ", r.souhrn)
	var n := int(_arg("vykopu", "8")); var chk := _arg("kontrola", "0") == "1"
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0: cand.append(i)
	for sp in v.springs: cand.append(sp.gi)
	var rng := RandomNumberGenerator.new(); rng.seed = 96
	var edits := []; var bad_tot := 0
	for k in mini(n, cand.size()):
		var gi: int = cand[rng.randi_range(0, cand.size() - 1)]
		var a := v.slot_of(gi); var b = blocks[a[0]]; var ci: int = a[1] * 16 + a[2]
		var h0: int = b.hm[ci]; var nh := maxi(h0 - 2, 1)
		for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
		b.hm[ci] = nh
		var td := Time.get_ticks_usec()
		if k == 0 and not v.ug.is_empty():   # profil: kolik stojí otisk výsledků podzemí (dig ho počítá 2×) a hrubý povrch
			v.UGO._digest(v.ug); r.profil_digest_ms = (Time.get_ticks_usec() - td) / 1000.0
			print("profil: _digest podzemí %.0f ms, volání %d" % [r.profil_digest_ms, v.ug._calls.size()])
		var te := Time.get_ticks_usec()
		var er := v.edit(a[0], a[1], a[2], nh)
		var steps := 0; var smax := 0.0
		while v.pending():
			var t := Time.get_ticks_usec(); v.step(); steps += 1
			smax = maxf(smax, (Time.get_ticks_usec() - t) / 1000.0)
		var e := {"gi": gi, "ms": er.ms, "surf_ms": er.surf_ms, "ug_ms": (er.ug.ms if er.has("ug") else 0.0), "r_steps": steps, "r_step_max_ms": smax,
			"celkem_ms": (Time.get_ticks_usec() - te) / 1000.0, "okno": er.surf.get("window", 0)}
		if chk:
			var bad: Dictionary = v.check_full(); e.neshod = bad
			bad_tot += int(bad.fill) + int(bad.eff) + int(bad.to)
		edits.append(e)
		print("výkop %d: %.0f ms (povrch %.0f, podzemí %.0f), kroků R %d (max %.0f ms), celkem %.0f ms, okno %s%s" % [k + 1, er.ms, er.surf_ms, e.ug_ms, steps, smax, e.celkem_ms, str(e.okno), (" neshod %s" % str(e.neshod)) if chk else ""])
	r.vykopy = edits; r.neshod_celkem = bad_tot
	r.rss_konec_mb = _rss()
	r.pamet_godot_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var outp := _arg("out", "")
	if outp != "": FileAccess.open(outp, FileAccess.WRITE).store_string(JSON.stringify(r, " "))
	print("RSS konec %.0f MB, Godot statická %.0f MB" % [r.rss_konec_mb, r.pamet_godot_mb])
	quit()
