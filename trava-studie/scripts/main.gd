extends Node3D
## Studie trávy pro Willage: čtyři záhony 10 × 10 buněk (2 × 2):
##   A = shell texturing (hustá srst), A2 = shell, řidší „koberec“ (vzadu),
##   B = instancovaná stébla (MultiMesh), C = instancované trsy z prototypu veg-v2 (vpředu).
## Zadní řady = vysoká „srst“ (0,15 × buňka), přední = nízká (0,05 × buňka). Dvě stejné postavičky
## (jedna na každém záhonu) jdou současně stejnou trasou po obou záhonech, tráva se rozhrnuje a pružně vrací; celé to fouká vítr.
## Režimy (za --): bez parametru = interaktivně, --shots = screenshoty, --movie = video (s --write-movie),
## --bench = měření výkonu. Parametry viz scripts/params.gd (-- --klic=hodnota).

const Par = preload("res://scripts/params.gd")
const Trail = preload("res://scripts/trail.gd")
const GB = preload("res://scripts/grass_build.gd")

const STEP := 1.0 / 30.0
const GAP := 2.0          # mezera mezi záhony (buňky)

var cell: float
var n: int
var patch_size: float
var origins: Array[Vector3] = []
var sim_t := 0.0
var trail
var shell_mat: ShaderMaterial
var blade_mat: ShaderMaterial
var grass_mats: Array[ShaderMaterial] = []
var chars: Array[Node3D] = []
var char_prev: Array[Vector2] = []
var cam: Camera3D
const KEYS := ["A", "A2", "B", "C"]
const TITLES := ["A · hustá srst (shell)", "A2 · řidší koberec (shell)", "B · stébla (MultiMesh)", "C · trsy z prototypu (MultiMesh)"]
var nodes := {}          # klíč → pole uzlů záhonu
var patch_of := {}       # klíč → index záhonu
var prefix := "27_trava_trsy"
var counts := {}
var labels: Array[Label3D] = []
var mode := "play"
var paused := false
var cam_mode := 0
var trail_us := 0.0
var blade_count := 0

func _ready() -> void:
	Par.parse_cli()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--shots", "--movie", "--bench"]:
			mode = a.substr(2)
	cell = Par.g("cell_edge")
	n = int(Par.g("patch_cells"))
	patch_size = n * cell
	var step := patch_size + GAP * cell
	origins = [Vector3(0, 0, 0), Vector3(step, 0, 0), Vector3(0, 0, step), Vector3(step, 0, step)]
	for i in KEYS.size():
		patch_of[KEYS[i]] = i
	for a in args:
		if a.begins_with("--prefix="):
			prefix = a.substr(9)
	_setup_env()
	_build_ground()
	_build_grass()
	_build_chars()
	_build_labels()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 200.0
	add_child(cam)
	_set_cam(_overview())
	_advance(0.0)
	if mode == "shots":
		_run_shots()
	elif mode == "bench":
		_run_bench()

# ------------------------------------------------------------------ scéna
func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

func _toon(col: Color, ground := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon.gdshader")
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("ground", ground)
	m.set_shader_parameter("cell", cell)
	return m

func _build_ground() -> void:
	# podstavec (hlína, nahoře posekaný trávník), jedna buňka vysoký
	var w := 2.0 * patch_size + GAP * cell + 4.0 * cell
	var d := 2.0 * patch_size + GAP * cell + 3.0 * cell
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, cell * 0.5, d)
	slab.mesh = bm
	slab.position = Vector3(w * 0.5 - 2.0 * cell, -cell * 0.25 - 0.004, d * 0.5 - 1.5 * cell)
	slab.material_override = _toon(Color(0.66, 0.84, 0.55), true)
	add_child(slab)
	# tmavý podklad pod trávou (kořeny)
	for oi in origins.size():
		var o: Vector3 = origins[oi]
		var base := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(patch_size, 0.01, patch_size)
		base.mesh = pm
		base.position = o + Vector3(patch_size * 0.5, -0.004, patch_size * 0.5)
		var bmat := _toon(Color(0.36, 0.60, 0.37) if oi != 3 else Color(0.30, 0.50, 0.30), true)
		bmat.set_shader_parameter("grid_dark", 0.0)
		base.material_override = bmat
		add_child(base)

func _shell_mat(i: int, dens: float, dens_s: float, rr: float, rt: float, fill: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass_shell.gdshader")
	m.set_shader_parameter("max_h", Par.g("tall_h") * cell)
	m.set_shader_parameter("density", dens / cell)
	m.set_shader_parameter("density_short", dens_s / cell)
	m.set_shader_parameter("rad_root", rr)
	m.set_shader_parameter("rad_tip", rt)
	m.set_shader_parameter("fill", fill)
	return m

func _add_shell(i: int, mat: ShaderMaterial) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GB.shell_mesh(patch_size, int(Par.g("shell_layers")), Par.g("tall_h") * cell)
	mi.position = origins[i]
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _add_mm(i: int, mm: MultiMesh, mat: ShaderMaterial) -> Node3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(origins[i] + Vector3(-1, -0.1, -1), Vector3(patch_size + 2, maxf(Par.g("tall_h"), Par.g("tuft_tall_h")) * cell * 1.5 + 0.3, patch_size + 2))
	add_child(mmi)
	return mmi

func _build_grass() -> void:
	var tmap := GB.type_map(n, int(Par.g("tall_rows")), int(Par.g("seed")))
	var ttex := GB.type_texture(tmap, n)
	var torig := Vector2(-cell, -cell)
	var tsize := Vector2(origins[3].x + patch_size + cell - torig.x, origins[3].z + patch_size + cell - torig.y)
	trail = Trail.new(torig, tsize, Par.g("trail_px") / cell)
	var seed := int(Par.g("seed"))
	# A) hustá srst
	var ma := _shell_mat(0, Par.g("shell_density"), Par.g("shell_density_short"), 0.62, 0.08, 1.0)
	nodes["A"] = [_add_shell(0, ma)]
	# A2) řidší koberec
	var ma2 := _shell_mat(1, Par.g("carpet_density"), Par.g("carpet_density_short"), Par.g("carpet_rad_root"), Par.g("carpet_rad_tip"), Par.g("carpet_fill"))
	ma2.set_shader_parameter("col_root", Color(0.25, 0.43, 0.28))
	nodes["A2"] = [_add_shell(1, ma2)]
	# B) stébla
	var mb := ShaderMaterial.new()
	mb.shader = load("res://shaders/grass_blade.gdshader")
	mb.set_shader_parameter("tall_cut", (Par.g("tall_h") + Par.g("short_h")) * 0.5 * cell * 0.9)
	var bmm := GB.blade_multimesh(tmap, n, cell, origins[2], seed)
	blade_count = bmm.instance_count
	counts["B"] = bmm.instance_count
	nodes["B"] = [_add_mm(2, bmm, mb)]
	# C) trsy z prototypu
	var mc := ShaderMaterial.new()
	mc.shader = load("res://shaders/grass_tuft.gdshader")
	nodes["C"] = []
	var tot := 0
	var tris := 0
	for kind in 3:
		var mm := GB.tuft_multimesh(kind, tmap, n, cell, origins[3], seed)
		tot += mm.instance_count
		tris += mm.instance_count * (6 if kind < 2 else 15)
		nodes["C"].append(_add_mm(3, mm, mc))
	counts["C"] = tot
	counts["C_tris"] = tris
	var mats := {"A": ma, "A2": ma2, "B": mb, "C": mc}
	grass_mats = []
	var wd := deg_to_rad(Par.g("wind_dir_deg"))
	for k in KEYS:
		var m: ShaderMaterial = mats[k]
		var o: Vector3 = origins[patch_of[k]]
		grass_mats.append(m)
		m.set_shader_parameter("patch_rect", Vector4(o.x, o.z, patch_size, patch_size))
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

func _build_chars() -> void:
	for i in KEYS.size():
		var root := Node3D.new()
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = Par.g("char_r")
		cm.height = Par.g("char_h")
		body.mesh = cm
		body.position.y = Par.g("char_h") * 0.5
		body.material_override = _toon(Color(0.96, 0.62, 0.70))
		root.add_child(body)
		for s in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.035
			sm.height = 0.07
			eye.mesh = sm
			eye.position = Vector3(s * 0.075, Par.g("char_h") * 0.68, -Par.g("char_r") * 0.92)
			eye.material_override = _toon(Color(0.16, 0.13, 0.2))
			root.add_child(eye)
		add_child(root)
		chars.append(root)
		char_prev.append(Vector2.ZERO)

func _build_labels() -> void:
	for i in KEYS.size():
		var l := Label3D.new()
		l.text = TITLES[i]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.outline_size = 14
		l.modulate = Color(0.32, 0.25, 0.42)
		l.outline_modulate = Color(1, 1, 1)
		l.pixel_size = 0.006 * cell
		l.position = origins[i] + Vector3(patch_size * 0.5, 0.9 * cell, -0.9 * cell)
		add_child(l)
		labels.append(l)

# ------------------------------------------------------------------ trasa postavičky
## trasa v buňkách (lokálně na záhonu): vstup zleva vysokou trávou, oblouk, návrat nízkou, odchod ven
func _path_point(s: float) -> Vector2:
	var r := 2.5
	var a := 7.5
	var arc := PI * r
	var total := a + arc + a
	var d := clampf(s, 0.0, 1.0) * total
	var p: Vector2
	if d < a:
		p = Vector2(-1.0 + d, 2.5)
	elif d < a + arc:
		var ang := -PI * 0.5 + (d - a) / r
		p = Vector2(6.5, 5.0) + Vector2(cos(ang), sin(ang)) * r
	else:
		p = Vector2(6.5 - (d - a - arc), 7.5)
	return p

func _char_pos(i: int, t: float) -> Vector2:
	var s := t / Par.g("walk_time")
	var p := _path_point(s) * cell
	return Vector2(origins[i].x, origins[i].z) + p

func _advance(dt: float) -> void:
	sim_t += dt
	var t0 := Time.get_ticks_usec()
	var t_loop := fmod(sim_t, Par.g("walk_time") + 4.0) if mode == "play" else sim_t
	for i in chars.size():
		var p := _char_pos(i, t_loop)
		var p2 := _char_pos(i, t_loop + 0.05)
		var mv := p2 - p
		var moving := mv.length() > 1e-4
		var md := mv.normalized() if moving else Vector2.ZERO
		var bob := absf(sin(t_loop * 9.0)) * 0.06 if moving else 0.0
		chars[i].position = Vector3(p.x, bob, p.y)
		if moving:
			chars[i].rotation.y = atan2(-md.x, -md.y)
		if moving or dt == 0.0:
			trail.stamp(p, md, Par.g("trample_r") * cell, sim_t, Par.g("trample_hold"), Par.g("trample_recover"))
		char_prev[i] = p
	trail.upload()
	trail_us = float(Time.get_ticks_usec() - t0)
	var cs := []
	for c in chars:
		cs.append(Vector4(c.position.x, c.position.z, Par.g("char_r") * 1.6, 0))
	for m in grass_mats:
		m.set_shader_parameter("sim_time", sim_t)
		m.set_shader_parameter("chars", cs)

# ------------------------------------------------------------------ kamera
func _overview() -> Dictionary:
	var c := (origins[3] + Vector3(patch_size, 0, patch_size)) * 0.5
	return {"center": c, "size": patch_size * 2.05}

func _set_cam(v: Dictionary) -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(45.0), 0), EULER_ORDER_YXZ)
	cam.transform = Transform3D(basis, v.center + basis.z * 60.0)
	cam.size = v.size

func _follow(i: int, size: float) -> Dictionary:
	return {"center": chars[i].position * Vector3(1, 0, 1) + Vector3(0, 0.1, 0), "size": size}

func _process(delta: float) -> void:
	if mode == "shots" or mode == "bench":
		return
	if mode == "movie":
		_advance(STEP)
		_movie_cam()
		return
	if not paused:
		_advance(delta)
	match cam_mode:
		0: _set_cam(_overview())
		_: _set_cam(_follow(cam_mode - 1, 3.2 * cell))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_1: cam_mode = 0
			KEY_2: cam_mode = 1
			KEY_3: cam_mode = 2
			KEY_4: cam_mode = 3
			KEY_5: cam_mode = 4
			KEY_SPACE: paused = not paused

# ------------------------------------------------------------------ video
## 0–3 s celek, najetí na C (trsy), sledování, přejezd na A2 (koberec), návrat na celek (obnova trávy)
func _movie_cam() -> void:
	var t := sim_t
	var ov := _overview()
	var fc := _follow(patch_of["C"], 3.4 * cell)
	var fa := _follow(patch_of["A2"], 3.4 * cell)
	var v: Dictionary
	if t < 3.0:
		v = ov
	elif t < 4.5:
		v = _lerp_view(ov, fc, smoothstep(3.0, 4.5, t))
	elif t < 6.8:
		v = fc
	elif t < 7.8:
		v = _lerp_view(fc, fa, smoothstep(6.8, 7.8, t))
	elif t < 9.2:
		v = fa
	else:
		v = _lerp_view(fa, ov, smoothstep(9.2, 10.7, t))
	_set_cam(v)

func _lerp_view(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"center": a.center.lerp(b.center, k), "size": lerpf(a.size, b.size, k)}

# ------------------------------------------------------------------ screenshoty
func _sim_to(t: float) -> void:
	while sim_t + STEP * 0.5 < t:
		_advance(STEP)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shots/" + name)
	img.save_png(path)
	print("ulozeno ", path)

func _detail(k: String, size: float, local := Vector3(6, 0, 5)) -> Dictionary:
	return {"center": origins[patch_of[k]] + local * cell, "size": size * cell}

## 4 výřezy (A, A2, B, C) složené do mřížky 2 × 2 (ffmpeg)
func _grid(name: String, views: Array) -> void:
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
	args.append_array(["-filter_complex", "[0][1]hstack[t];[2][3]hstack[b];[t][b]vstack,scale=1280:-1", out])
	OS.execute("ffmpeg", args)
	for t in tmp:
		DirAccess.remove_absolute(t)
	print("ulozeno ", out)

func _run_shots() -> void:
	for l in labels:
		l.visible = true
	_sim_to(0.4)
	_set_cam(_overview())
	await _shot(prefix + "_prehled.png")
	for l in labels:
		l.visible = false
	await _grid(prefix + "_srovnani_klid.png", KEYS.map(func(k): return _detail(k, 2.6)))
	_set_cam(_detail("C", 2.6))
	await _shot(prefix + "_detail_C_klid.png")
	_set_cam(_detail("A2", 2.6))
	await _shot(prefix + "_detail_A2_klid.png")
	_sim_to(4.6)
	for l in labels:
		l.visible = true
	_set_cam(_overview())
	await _shot(prefix + "_pruchod.png")
	for l in labels:
		l.visible = false
	await _grid(prefix + "_srovnani_pruchod.png", range(4).map(func(i): return _follow(i, 3.2 * cell)))
	_set_cam(_follow(patch_of["C"], 3.2 * cell))
	await _shot(prefix + "_pruchod_detail_C.png")
	_set_cam(_follow(patch_of["A2"], 3.2 * cell))
	await _shot(prefix + "_pruchod_detail_A2.png")
	_sim_to(7.6)
	await _grid(prefix + "_srovnani_nizka.png", range(4).map(func(i): return _follow(i, 3.2 * cell)))
	_set_cam(_follow(patch_of["C"], 3.2 * cell))
	await _shot(prefix + "_pruchod_nizka_C.png")
	_sim_to(12.5)
	for l in labels:
		l.visible = true
	_set_cam(_overview())
	await _shot(prefix + "_po_obnove.png")
	for l in labels:
		l.visible = false
	_set_cam(_detail("C", 4.0, Vector3(4, 0, 4)))
	await _shot(prefix + "_po_obnove_detail_C.png")
	get_tree().quit()

# ------------------------------------------------------------------ výkon
func _run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for l in labels:
		l.visible = false
	var out := []
	var cfgs := [["A"], ["A2"], ["B"], ["C"], KEYS]
	for cfg in cfgs:
		for view in ["celek", "detail"]:
			for k in KEYS:
				for nd in nodes[k]:
					nd.visible = k in cfg
			if view == "celek":
				_set_cam(_overview())
			else:
				_set_cam(_detail(cfg[0], 3.2, Vector3(3, 0, 3)))
			for i in 30:
				_advance(STEP)
				await RenderingServer.frame_post_draw
			var t0 := Time.get_ticks_usec()
			var frames := 90
			var tr := 0.0
			for i in frames:
				_advance(STEP)
				tr += trail_us
				await RenderingServer.frame_post_draw
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
			var line := "%s %s: %.1f ms/snímek, stopa (CPU) %.2f ms" % ["+".join(cfg), view, ms, tr / frames / 1000.0]
			print(line)
			out.append(line)
	out.append("instance: B stébla %d (x5 trojúhelníků), C trsy+kvítky %d (%d trojúhelníků); A/A2 %d vrstev (48 trojúhelníků); renderer %s" % [counts["B"], counts["C"], counts["C_tris"], int(Par.g("shell_layers")), RenderingServer.get_video_adapter_name()])
	var f := FileAccess.open("res://shots/bench.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print(out[-1])
	get_tree().quit()
