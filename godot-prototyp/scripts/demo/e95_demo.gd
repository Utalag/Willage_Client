extends Node
## E95: kopání ve hře (main.tscn, digging.dig) s p95_async_voda a bez něj: blokování hlavního vlákna při výkopu (celý
## herní výkop včetně sítě terénu), čas kroku vody na snímek, konečný otisk vody. Spuštění:
##   godot --headless --path . res://demo.tscn -- --e95-bench [--bp.p95_async_voda=true] [--e95-mezera=20] [--e95-out=...]
const T = preload("res://scripts/teren/ostrov_teren.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const BS := 16
var m

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _ready() -> void:
	m = get_parent()
	m.set_game_process(false)   # kroky vody voláme sami (jako water_flow_runner._process)
	_bench.call_deferred()

func _g(v, gi: int) -> Vector2i:
	return Vector2i(gi / v.H, gi % v.H) - T.OFF * BS

func _bench() -> void:
	var isl = m.island
	var v = isl.voda
	var on: bool = isl.voda_async != null
	var mezera := int(_arg("e95-mezera", "20"))
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0 and not isl.occupied.has(_g(v, i)): cand.append(i)
	var rng := RandomNumberGenerator.new(); rng.seed = 95
	var digs := []; var frame_ms := []
	for k in 8:
		var gi: int = cand[rng.randi_range(0, cand.size() - 1)]
		var t0 := Time.get_ticks_usec()
		var txt: String = m.digging.dig(_g(v, gi))
		digs.append({"gi": gi, "text": txt, "dig_ms": (Time.get_ticks_usec() - t0) / 1000.0})
		for f in mezera:
			await get_tree().process_frame
			var ts := Time.get_ticks_usec()
			isl.water_step(int(T.p.get("voda_r_kroku", 1)))
			frame_ms.append((Time.get_ticks_usec() - ts) / 1000.0)
	var tf := Time.get_ticks_usec()
	if on: isl.water_finish_async()
	else: isl.water_finish()
	var fin_ms := (Time.get_ticks_usec() - tf) / 1000.0
	var tr := Time.get_ticks_usec()
	for k in 3: isl.render_water()
	var render_ms := (Time.get_ticks_usec() - tr) / 3000.0
	var tre := Time.get_ticks_usec()
	isl.refresh_after_edit(digs[0].get("sl", Vector2i(1, 1)) if false else isl.blocks.keys()[0], 5, 5)
	var refresh_ms := (Time.get_ticks_usec() - tre) / 1000.0
	var fm := frame_ms.duplicate(); fm.sort()
	var dm := digs.map(func(d): return float(d.dig_ms)); dm.sort()
	var out := {"p95_async_voda": on, "mezera_snimku": mezera, "digs": digs, "dig_ms_max": dm[-1], "dig_ms_p50": dm[dm.size() / 2],
		"voda_na_snimek_ms": {"p50": fm[fm.size() / 2], "max": fm[-1], "nad_33ms": fm.filter(func(x): return x > 33.3).size()},
		"dokonceni_na_konci_ms": fin_ms, "render_vody_ms": render_ms, "prestavba_terenu_ms": refresh_ms, "otisk": H68.otisk(v.st), "neshod_plny": v.check_full(),
		"pamet_pohled_B": (isl.voda_async.front.bytes() if on else 0)}
	print("E95 hra: ", JSON.stringify(out))
	var path := ProjectSettings.globalize_path(_arg("e95-out", "res://shots/e95/hra.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	isl._async_stop()
	get_tree().quit()
