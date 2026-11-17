extends "res://scripts/main.gd"
## Procedurální zem louky pod trsy C (Jan 17. 11.: „Když máme procedurální písek, co zkusit i procedurálně tu trávu?“).
## Čtyři stejné záhony s trsy C, liší se jen zemí (a ve 3. variantě tónem trsů):
##   0 = dnešní plochá zem, 1 = procedurální jemná, 2 = procedurální výrazná, 3 = sladěná (zem + trsy ze stejného šumu).
## Spuštění: SCENE=res://proc.tscn ./run.sh shots | bench  (parametry pg_* v scripts/params.gd)

const VKEYS := ["P0", "P1", "P2", "P3"]
const VTITLES := ["0 · dnešní plochá zem", "1 · procedurální jemná", "2 · procedurální výrazná", "3 · sladěná: zem + trsy"]
var ground_nodes: Array = []
var ground_mats: Array = []
var tuft_nodes: Array = []

func _init() -> void:
	prefix = "32_trava_procedural"

func _strength(i: int) -> float:
	return [0.0, Par.g("pg_s1"), Par.g("pg_s2"), Par.g("pg_s3")][i]

func _set_mp(m: ShaderMaterial, s: float) -> void:
	m.set_shader_parameter("mp_cell", cell)
	m.set_shader_parameter("mp_strength", s)
	m.set_shader_parameter("mp_macro_scale", Par.g("pg_macro_scale"))
	m.set_shader_parameter("mp_macro", Par.g("pg_macro"))
	m.set_shader_parameter("mp_yellow", Par.g("pg_yellow"))
	m.set_shader_parameter("mp_dry", Par.g("pg_dry"))
	m.set_shader_parameter("mp_dry_cov", Par.g("pg_dry_cov"))
	m.set_shader_parameter("mp_lush", Par.g("pg_lush"))
	m.set_shader_parameter("mp_lush_cov", Par.g("pg_lush_cov"))

func _build_ground() -> void:
	var w := 2.0 * patch_size + GAP * cell + 4.0 * cell
	var d := 2.0 * patch_size + GAP * cell + 3.0 * cell
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, cell * 0.5, d)
	slab.mesh = bm
	slab.position = Vector3(w * 0.5 - 2.0 * cell, -cell * 0.25 - 0.004, d * 0.5 - 1.5 * cell)
	slab.material_override = _toon(Color(0.66, 0.84, 0.55), true)
	add_child(slab)
	for oi in origins.size():
		var o: Vector3 = origins[oi]
		var base := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(patch_size, patch_size)
		base.mesh = pm
		base.position = o + Vector3(patch_size * 0.5, 0.001, patch_size * 0.5)
		var m: ShaderMaterial
		if oi == 0:
			m = _toon(Color(0.30, 0.50, 0.30), true)   # přesně dnešní podklad pod C (main.gd)
			m.set_shader_parameter("grid_dark", 0.0)
		else:
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/meadow_ground.gdshader")
			_set_mp(m, _strength(oi))
			m.set_shader_parameter("streak", Par.g("pg_streak"))
			m.set_shader_parameter("streak_w", Par.g("pg_streak_w"))
			m.set_shader_parameter("streak_len", Par.g("pg_streak_len"))
			m.set_shader_parameter("grain", Par.g("pg_grain"))
			m.set_shader_parameter("clover", Par.g("pg_clover"))
			m.set_shader_parameter("desat", Par.g("pg_desat"))
			ground_mats.append(m)
		base.material_override = m
		add_child(base)
		ground_nodes.append(base)

func _build_grass() -> void:
	var tmap := GB.type_map(n, int(Par.g("tall_rows")), int(Par.g("seed")))
	var ttex := GB.type_texture(tmap, n)
	var torig := Vector2(-cell, -cell)
	var tsize := Vector2(origins[3].x + patch_size + cell - torig.x, origins[3].z + patch_size + cell - torig.y)
	trail = Trail.new(torig, tsize, Par.g("trail_px") / cell)
	var seed := int(Par.g("seed"))
	grass_mats = []
	var wd := deg_to_rad(Par.g("wind_dir_deg"))
	var tot := 0
	var tris := 0
	for i in 4:
		var mc := ShaderMaterial.new()
		mc.shader = load("res://shaders/grass_tuft.gdshader")
		if i == 3:
			_set_mp(mc, _strength(3))
			mc.set_shader_parameter("ground_match", Par.g("pg_match3"))
		var arr := []
		for kind in 3:
			var mm := GB.tuft_multimesh(kind, tmap, n, cell, origins[i], seed)   # stejné rozmístění na všech záhonech
			if i == 0:
				tot += mm.instance_count
				tris += mm.instance_count * (6 if kind < 2 else 15)
			arr.append(_add_mm(i, mm, mc))
		tuft_nodes.append(arr)
		nodes[VKEYS[i]] = arr
		patch_of[VKEYS[i]] = i
		grass_mats.append(mc)
	counts["C"] = tot
	counts["C_tris"] = tris
	for m in grass_mats + ground_mats:
		m.set_shader_parameter("type_tex", ttex)
		m.set_shader_parameter("trail_tex", trail.tex)
		m.set_shader_parameter("trail_rect", trail.rect())
		m.set_shader_parameter("wind_dir", Vector2(cos(wd), sin(wd)))
		m.set_shader_parameter("wind_strength", Par.g("wind_strength"))
		m.set_shader_parameter("wind_gust", Par.g("wind_gust"))
		m.set_shader_parameter("wind_speed", Par.g("wind_speed") * cell)
		m.set_shader_parameter("wind_scale", Par.g("wind_scale") / cell)
		m.set_shader_parameter("t_hold", Par.g("trample_hold"))
		m.set_shader_parameter("t_recover", Par.g("trample_recover"))
		m.set_shader_parameter("t_bend", Par.g("trample_bend"))
	for i in 4:
		var o: Vector3 = origins[i]
		grass_mats[i].set_shader_parameter("patch_rect", Vector4(o.x, o.z, patch_size, patch_size))
	grass_mats.append_array(ground_mats)   # _advance() jim posílá čas a postavičky

func _build_labels() -> void:
	for i in 4:
		var l := Label3D.new()
		l.text = VTITLES[i]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.outline_size = 14
		l.modulate = Color(0.32, 0.25, 0.42)
		l.outline_modulate = Color(1, 1, 1)
		l.pixel_size = 0.006 * cell
		l.position = origins[i] + Vector3(patch_size * 0.5, 0.9 * cell, -0.9 * cell)
		add_child(l)
		labels.append(l)

func _tufts(on: bool) -> void:
	for arr in tuft_nodes:
		for nd in arr:
			nd.visible = on

func _labels(on: bool) -> void:
	for l in labels:
		l.visible = on

## mřížka 2 × 2 s popisky (ffmpeg drawtext)
func _grid_lab(name: String, views: Array, sub := "") -> void:
	var tmp := []
	for i in views.size():
		_set_cam(views[i])
		var nm := "_tmp_%d.png" % i
		await _shot(nm)
		tmp.append(ProjectSettings.globalize_path("res://shots/" + nm))
	var out := ProjectSettings.globalize_path("res://shots/" + name)
	var args := ["-y", "-loglevel", "error"]
	for t in tmp:
		args.append_array(["-i", t])
	var font := "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
	var fc := ""
	for i in 4:
		var txt: String = (VTITLES[i] + sub).replace(":", "\\:")
		fc += "[%d]drawtext=fontfile=%s:text='%s':x=24:y=20:fontsize=40:fontcolor=0x50406a:borderw=5:bordercolor=white[v%d];" % [i, font, txt, i]
	fc += "[v0][v1]hstack[t];[v2][v3]hstack[b];[t][b]vstack,scale=1280:-1"
	args.append_array(["-filter_complex", fc, out])
	var o := []
	OS.execute("ffmpeg", args, o, true)
	if o.size() > 0 and str(o[0]).length() > 0:
		print(o)
	for t in tmp:
		DirAccess.remove_absolute(t)
	print("ulozeno ", out)

func _run_shots() -> void:
	_sim_to(0.4)
	_labels(true)
	_set_cam(_overview())
	await _shot(prefix + "_prehled.png")
	_tufts(false)
	await _shot(prefix + "_prehled_bez_trsu.png")
	_labels(false)
	await _grid_lab(prefix + "_srovnani_bez_trsu.png", VKEYS.map(func(k): return _detail(k, 3.4, Vector3(5, 0, 5))), " (bez trsů)")
	_tufts(true)
	await _grid_lab(prefix + "_srovnani_detail.png", VKEYS.map(func(k): return _detail(k, 2.6)))
	await _grid_lab(prefix + "_srovnani_stredni.png", VKEYS.map(func(k): return _detail(k, 5.5, Vector3(5, 0, 5))))
	for i in [1, 2, 3]:
		_set_cam(_detail(VKEYS[i], 2.6))
		await _shot(prefix + "_detail_%d.png" % i)
	_sim_to(4.6)
	await _grid_lab(prefix + "_srovnani_pruchod.png", range(4).map(func(i): return _follow(i, 3.2 * cell)))
	get_tree().quit()

func _run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_labels(false)
	var out := []
	for tf in [true, false]:
		for view in ["celek", "detail"]:
			for i in 4:
				for j in 4:
					ground_nodes[j].visible = (j == i) or view == "detail"
					for nd in tuft_nodes[j]:
						nd.visible = tf and j == i
				if view == "celek":
					_set_cam(_overview())
				else:
					_set_cam(_detail(VKEYS[i], 3.2, Vector3(3, 0, 3)))
				for k in 30:
					_advance(STEP)
					await RenderingServer.frame_post_draw
				var t0 := Time.get_ticks_usec()
				var frames := 90
				for k in frames:
					_advance(STEP)
					await RenderingServer.frame_post_draw
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
				var line := "%s %s %s: %.1f ms/snímek" % [VTITLES[i], view, "s trsy" if tf else "bez trsů", ms]
				print(line)
				out.append(line)
	out.append("C trsy+kvítky na záhon %d (%d trojúhelníků); renderer %s" % [counts["C"], counts["C_tris"], RenderingServer.get_video_adapter_name()])
	var f := FileAccess.open("res://shots/bench_procedural.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	get_tree().quit()
