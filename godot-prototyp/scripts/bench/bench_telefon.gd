extends Node
## E93: benchmark pro telefon (scéna res://bench_telefon.tscn). Hra se nemění: scéna jen instancuje main.tscn jako dítě.
## Měří: generování ostrova START (bloky, síť, plná voda E66), čas snímku v pohledech, objekty / trojúhelníky / draw calls,
## paměť (Godot statická, video, RSS z /proc/self/status), kopání (lokální přepočet vody) a znovu plnou vodu.
## Výsledek: na obrazovce, v user://bench_telefon.json a ve schránce (dotyk / klik = znovu zkopírovat).
## Desktop: godot --path . res://bench_telefon.tscn [-- --out=/cesta.json --snimku=N --konec]
## E90 (LOD) a E91 (průhlednost) nejsou na main, proto tu nejsou.
const MAIN := "res://main.tscn"
const VERZE := "E93 bench_telefon v1"

var lab: Label
var res := {}
var main
var frames := 240
var text := ""

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _ready() -> void:
	frames = int(_arg("snimku", "240"))
	DisplayServer.screen_set_keep_on(true)
	var cl := CanvasLayer.new(); cl.layer = 20; add_child(cl)
	var bg := ColorRect.new(); bg.color = Color(1, 1, 1, 0.78); bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bg.size = Vector2(760, 2000); cl.add_child(bg)
	lab = Label.new(); lab.position = Vector2(12, 8); lab.size = Vector2(740, 2000)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color(0.1, 0.08, 0.15))
	cl.add_child(lab)
	_say("%s\nměřím… (asi 1–3 minuty, nezhasínej displej)" % VERZE)
	_run.call_deferred()

func _say(t: String) -> void:
	text = t
	lab.text = t
	print(t)

func _input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed and res.has("hotovo"):
		DisplayServer.clipboard_set(JSON.stringify(res))
		lab.text = text + "\n\n(zkopírováno do schránky)"

func _mem() -> Dictionary:
	var m := {"godot_static_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"godot_static_peak_mb": snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"textury_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buffery_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1)}
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f:
		while not f.eof_reached():
			var line := f.get_line()
			if line.begins_with("VmRSS:") or line.begins_with("VmHWM:"):
				var kb := int(line.split(":")[1].strip_edges().split(" ")[0])
				m["rss_mb" if line.begins_with("VmRSS") else "rss_peak_mb"] = snappedf(kb / 1024.0, 0.1)
	return m

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

## čas snímku: zeď mezi snímky (ms), percentily; render CPU/GPU z RenderingServeru (GPU může být 0, když ovladač neumí)
func _bench(nazev: String) -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _frames(30)
	var dts := PackedFloat64Array()
	var cpu := 0.0; var gpu := 0.0
	var last := Time.get_ticks_usec()
	var prims := 0.0; var draws := 0.0; var objs := 0.0
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0); last = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs = maxf(objs, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var s := dts.duplicate(); s.sort()
	var avg := 0.0
	for v in s: avg += v
	avg /= s.size()
	var r := {"snimek_prumer_ms": snappedf(avg, 0.01), "p50_ms": snappedf(s[s.size() / 2], 0.01),
		"p95_ms": snappedf(s[int(s.size() * 0.95)], 0.01), "p99_ms": snappedf(s[int(s.size() * 0.99)], 0.01),
		"fps": snappedf(1000.0 / avg, 0.1), "render_cpu_ms": snappedf(cpu / frames, 0.01), "render_gpu_ms": snappedf(gpu / frames, 0.01),
		"trojuhelniky": int(prims), "draw_calls": int(draws), "objekty": int(objs)}
	_say(text + "\n%s: %.1f ms (p95 %.1f), %d tri, %d draw calls" % [nazev, r.snimek_prumer_ms, r.p95_ms, r.trojuhelniky, r.draw_calls])
	return r

func _cam(c: Vector3, size: float, yaw: float) -> void:
	main.rig.center = c; main.cam.size = size; main.rig.yaw = yaw; main.rig.pitch = -35.0
	main.rig.place()

func _run() -> void:
	await _frames(2)
	res["verze"] = VERZE
	res["zarizeni"] = {"model": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(), "cpu": OS.get_processor_name(),
		"jader": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(), "gpu_vyrobce": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"okno": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"obrazovka": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y], "godot": Engine.get_version_info().string,
		"vsync": DisplayServer.window_get_vsync_mode(), "debug": OS.is_debug_build()}
	res["pamet_start"] = _mem()
	_say(text + "\nzařízení: %s, %s, %d jader, GPU %s" % [res.zarizeni.model, res.zarizeni.cpu, res.zarizeni.jader, res.zarizeni.gpu])
	await _frames(2)
	# 1) generování ostrova START jako hra (Main._ready: bloky, síť, povrch, vegetace, voda)
	var t0 := Time.get_ticks_usec()
	main = load(MAIN).instantiate()
	add_child(main)
	var t_all := (Time.get_ticks_usec() - t0) / 1000.0
	var isl = main.island
	var vms: Dictionary = isl.voda.ms if isl.voda != null else {}
	res["generovani"] = {"celkem_ms": snappedf(t_all, 0.1), "bloky_gen_ms": isl.gen_times.map(func(v): return snappedf(v, 0.1)),
		"bloky_sit_ms": isl.mesh_times.map(func(v): return snappedf(v, 0.1)), "voda_ms": vms}
	main.set_game_process(false)
	if main.ui: main.ui.visible = false
	await _frames(3)
	res["pamet_po_generovani"] = _mem()
	_say(text + "\ngenerování ostrova: %.0f ms (bloky %s ms), voda %s" % [t_all, str(res.generovani.bloky_gen_ms), str(vms.get("celkem", "?"))])
	# 2) čas snímku v pohledech
	var vs := {}
	_cam(Vector3(16, 15, 16), 40.0, 45.0); vs["prehled"] = await _bench("přehled ostrova")
	_cam(Vector3(16, 15, 16), 20.0, 45.0); vs["zoom"] = await _bench("zoom 20")
	_cam(Vector3(16, 15, 16), 40.0, 135.0); vs["otoceni"] = await _bench("otočeno o 90°")
	get_viewport().scaling_3d_scale = 0.5
	_cam(Vector3(16, 15, 16), 40.0, 45.0); vs["polovicni_3d"] = await _bench("přehled, 3D v polovičním rozlišení")
	get_viewport().scaling_3d_scale = 1.0
	res["snimky"] = vs
	res["pamet_po_snimcich"] = _mem()
	# 3) kopání: 8 výkopů (lokální přepočet vody), pak plná voda znovu
	var digs := []
	var cols := [Vector2i(5, 5), Vector2i(9, 3), Vector2i(12, 12), Vector2i(20, 20), Vector2i(26, 22), Vector2i(4, 20), Vector2i(14, 27), Vector2i(22, 9)]
	for g in cols:
		var t1 := Time.get_ticks_usec()
		var msg: String = main.digging.dig(g)
		main.water.finish_all()
		digs.append({"sloupec": [g.x, g.y], "ms": snappedf((Time.get_ticks_usec() - t1) / 1000.0, 0.1), "zprava": msg})
	t0 = Time.get_ticks_usec()
	isl.rebuild_water()
	var full := (Time.get_ticks_usec() - t0) / 1000.0
	var dsum := 0.0; var dmax := 0.0
	for d in digs: dsum += d.ms; dmax = maxf(dmax, d.ms)
	res["kopani"] = {"vykopy": digs, "prumer_ms": snappedf(dsum / digs.size(), 0.1), "max_ms": snappedf(dmax, 0.1), "plna_voda_znovu_ms": snappedf(full, 0.1)}
	_say(text + "\nkopání: průměr %.0f ms, max %.0f ms; plná voda znovu %.0f ms" % [res.kopani.prumer_ms, res.kopani.max_ms, full])
	res["pamet_konec"] = _mem()
	res["poznamka"] = "E90 LOD a E91 průhlednost nejsou na main (jen větve), v benchmarku nejsou."
	res["hotovo"] = Time.get_datetime_string_from_system()
	# 4) výstup
	var js := JSON.stringify(res, " ")
	var outp := _arg("out", "user://bench_telefon.json")
	var f := FileAccess.open(outp, FileAccess.WRITE)
	if f: f.store_string(js); f.close()
	DisplayServer.clipboard_set(JSON.stringify(res))
	var pv: Dictionary = vs.prehled
	_say("%s – HOTOVO\nzařízení: %s | %s | %d jader | GPU %s\ngenerování ostrova %.0f ms, voda %s ms\npřehled %.1f ms (%.0f fps, p95 %.1f), zoom %.1f ms, otočeno %.1f ms, 3D 50 %% %.1f ms\n%d trojúhelníků, %d draw calls, %d objektů\nkopání průměr %.0f / max %.0f ms, plná voda znovu %.0f ms\npaměť RSS %s MB (špička %s), Godot %s MB, video %s MB\nVýsledek je ve schránce (dotykem znovu zkopírovat) a v %s" % [
		VERZE, res.zarizeni.model, res.zarizeni.cpu, res.zarizeni.jader, res.zarizeni.gpu, res.generovani.celkem_ms, str(vms.get("celkem", "?")),
		pv.snimek_prumer_ms, pv.fps, pv.p95_ms, vs.zoom.snimek_prumer_ms, vs.otoceni.snimek_prumer_ms, vs.polovicni_3d.snimek_prumer_ms,
		pv.trojuhelniky, pv.draw_calls, pv.objekty, res.kopani.prumer_ms, res.kopani.max_ms, full,
		str(res.pamet_konec.get("rss_mb", "?")), str(res.pamet_konec.get("rss_peak_mb", "?")), str(res.pamet_konec.godot_static_mb), str(res.pamet_konec.video_mb),
		ProjectSettings.globalize_path(outp)])
	if "--konec" in OS.get_cmdline_user_args():
		await _frames(10)
		get_viewport().get_texture().get_image().save_png(_arg("snimek", "/tmp/bench_telefon.png"))
		get_tree().quit()
