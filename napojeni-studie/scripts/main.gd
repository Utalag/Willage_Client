extends Node3D
## Studie napojování terénu (louka, písek, voda) pro Willage.
## Dva přístupy vedle sebe nad STEJNÝMI daty (2 × 2 vzorky 10 × 10 × 4: louka, píščina, voda, pobřeží):
##   1 = klasická mřížka s přechody na hranách buněk (vlevo), 2 = duální mřížka Oskara Stålberga (vpravo).
## Doplňky (mokrý písek, pěna a vlnky u břehu, řídnutí trávy k okraji) jdou zapnout nad oběma.
## Režimy (za --): bez parametru = interaktivně (1/2/3 kamera, E doplňky, G mřížka), --shots, --movie, --bench.
## Parametry viz scripts/params.gd (-- --klic=hodnota).

const Par = preload("res://scripts/params.gd")
const Data = preload("res://scripts/data.gd")
const Builder = preload("res://scripts/builder.gd")
const Grass = preload("res://scripts/grass.gd")

const STEP := 1.0 / 30.0
const GAP := 6.0
const TITLES := ["1 · klasická mřížka (přechod na hranách buněk)", "2 · duální mřížka (dlaždice z rohů)"]

var data
var bld := []                 # Builder pro přístup 1 a 2
var origin := []              # posun přístupu ve světě
var nodes := []              # všechny uzly přístupu
var grass_plain := []
var grass_thin := []
var grass_mix := []
var bank_nodes := []        # trsy na travnatém břehu
var reed_nodes := []        # rákos
var shore := [true, true, 0.3]   # bank, reeds, foam_bank
var VAR := []                # varianty: [přístup 1|2, tvar duální mřížky, popisek]
var nv := 2
var look := [1, 1, true]   # sand_look, sand_detail, bands
var t_mats := []
var w_mats := []
var g_mats := []
var labels := []
var cam: Camera3D
var sim_t := 0.0
var mode := "play"
var extras_on := true
var cam_mode := 0
var cxy := 1.0
var times := {}
var inst := []

func _ready() -> void:
	Par.parse_cli()
	for a in OS.get_cmdline_user_args():
		if a in ["--shots", "--movie", "--bench", "--stats", "--mekkost", "--hrana", "--samostatne", "--louka_voda"]:
			mode = a.substr(2)
	cxy = Par.g("cell_xy")
	_setup_env()
	var t0 := Time.get_ticks_usec()
	data = Data.new()
	times["data"] = data.gen_ms
	var N: int = data.N
	if mode == "samostatne":
		VAR = [[1, 0, "klasická mřížka (pro srovnání)"], [2, 0, "duální · současná"], [2, 1, "duální · posun izočáry"],
			[2, 2, "duální · plošina + zkosení"], [2, 3, "duální · hybrid (malé prvky a schody jako kvádry)"]]
	else:
		VAR = [[1, 0, TITLES[0]], [2, Par.i("dual_shape"), TITLES[1]]]
	nv = VAR.size()
	origin = []
	for ai in nv:
		origin.append(Vector3((N + GAP) * cxy * ai, 0, 0))
		nodes.append([]); grass_plain.append([]); grass_thin.append([]); grass_mix.append([]); bank_nodes.append([]); reed_nodes.append([]); inst.append(0)
	for ai in nv:
		_build_approach(ai)
	times["celkem"] = (Time.get_ticks_usec() - t0) / 1000.0
	_build_labels()
	for l in labels:
		l.visible = mode == "play"
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 300.0
	add_child(cam)
	_set_extras(true)
	_set_look([Par.i("sand_look"), Par.i("sand_detail"), Par.i("bands") == 1])
	_set_shore(_shore_default())
	_set_cam(_overview_both())
	_advance(0.0)
	_print_stats()
	if mode == "shots":
		_run_shots()
	elif mode == "bench":
		_run_bench()
	elif mode == "stats":
		get_tree().quit()
	elif mode == "mekkost":
		_run_mekkost()
	elif mode == "hrana":
		_run_hrana()
	elif mode == "samostatne":
		_run_samostatne()
	elif mode == "louka_voda":
		_run_louka_voda()

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
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _build_approach(ai: int) -> void:
	var b = Builder.new(data, VAR[ai][0], VAR[ai][1])
	bld.append(b)
	var o: Vector3 = origin[ai]
	var N: int = data.N
	b.build_splat()
	b.build_fields()
	var rect := Vector4(o.x, o.z, N * cxy, N * cxy)
	var tm := ShaderMaterial.new()
	tm.shader = load("res://shaders/terrain.gdshader")
	tm.set_shader_parameter("splat_tex", b.splat_tex)
	tm.set_shader_parameter("field_tex", b.field_tex)
	tm.set_shader_parameter("rect", rect)
	tm.set_shader_parameter("cell", cxy)
	tm.set_shader_parameter("water_level", data.wl)
	tm.set_shader_parameter("wet_w", Par.g("wet_w"))
	tm.set_shader_parameter("wet_h", Par.g("wet_h"))
	tm.set_shader_parameter("wet_dark", Par.g("wet_dark"))
	for k in ["sand_tex_contrast", "band_water", "band_grass", "sand_tex_scale"]:
		tm.set_shader_parameter(k, Par.g(k))
	tm.set_shader_parameter("tex_scale", 0.25 / cxy)
	tm.set_shader_parameter("sand_tex", _tex("03"))
	tm.set_shader_parameter("grass_tex", _tex("01"))
	t_mats.append(tm)
	var t0 := Time.get_ticks_usec()
	for sz in 2:
		for sx in 2:
			var mi := MeshInstance3D.new()
			mi.mesh = b.sample_mesh(sx, sz)
			mi.material_override = tm
			mi.position = o
			add_child(mi)
			nodes[ai].append(mi)
	b.ms["mesh"] = (Time.get_ticks_usec() - t0) / 1000.0
	# voda
	t0 = Time.get_ticks_usec()
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("field_tex", b.field_tex)
	wm.set_shader_parameter("rect", rect)
	wm.set_shader_parameter("cell", cxy)
	wm.set_shader_parameter("water_level", data.wl)
	for k in ["foam_w", "wave_reach", "wave_freq", "wave_speed"]:
		wm.set_shader_parameter(k, Par.g(k))
	w_mats.append(wm)
	var wmi := MeshInstance3D.new()
	wmi.mesh = b.water_mesh()
	wmi.material_override = wm
	wmi.position = o
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)
	nodes[ai].append(wmi)
	b.ms["water"] = (Time.get_ticks_usec() - t0) / 1000.0
	# tráva C
	t0 = Time.get_ticks_usec()
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass_tuft.gdshader")
	var blank := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	gm.set_shader_parameter("trail_tex", ImageTexture.create_from_image(blank))
	gm.set_shader_parameter("trail_rect", Vector4(-1000, -1000, 1, 1))
	var wd := deg_to_rad(Par.g("wind_dir_deg"))
	gm.set_shader_parameter("wind_dir", Vector2(cos(wd), sin(wd)))
	gm.set_shader_parameter("wind_strength", Par.g("wind_strength"))
	gm.set_shader_parameter("wind_gust", Par.g("wind_gust"))
	gm.set_shader_parameter("wind_speed", Par.g("wind_speed") * cxy)
	gm.set_shader_parameter("wind_scale", Par.g("wind_scale") / cxy)
	gm.set_shader_parameter("chars", [Vector4(-999, -999, 0.01, 0), Vector4(-999, -999, 0.01, 0), Vector4(-999, -999, 0.01, 0), Vector4(-999, -999, 0.01, 0)])
	g_mats.append(gm)
	for thin in [false, true]:
		for sz in 2:
			for sx in 2:
				var mms: Array = Grass.build(b, sx, sz, thin)
				for mm in mms:
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					mmi.material_override = gm
					mmi.position = o
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					mmi.custom_aabb = AABB(Vector3(sx * data.n * cxy - 1, 0, sz * data.n * cxy - 1), Vector3(data.n * cxy + 2, 4, data.n * cxy + 2))
					add_child(mmi)
					nodes[ai].append(mmi)
					(grass_thin if thin else grass_plain)[ai].append(mmi)
					if thin == true:
						inst[ai] += mm.instance_count
	for sz in 2:
		for sx in 2:
			for mm in Grass.build(b, sx, sz, false, true):
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = gm
				mmi.position = o
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.custom_aabb = AABB(Vector3(sx * data.n * cxy - 1, 0, sz * data.n * cxy - 1), Vector3(data.n * cxy + 2, 4, data.n * cxy + 2))
				add_child(mmi)
				nodes[ai].append(mmi)
				grass_mix[ai].append(mmi)
				inst[ai] += mm.instance_count
	var tb := Time.get_ticks_usec()
	for sz in 2:
		for sx in 2:
			var bm: Array = Grass.build_bank(b, sx, sz)
			for k in 2:
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = bm[k]
				mmi.material_override = gm
				mmi.position = o
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.custom_aabb = AABB(Vector3(sx * data.n * cxy - 1, 0, sz * data.n * cxy - 1), Vector3(data.n * cxy + 2, 4, data.n * cxy + 2))
				add_child(mmi)
				nodes[ai].append(mmi)
				(bank_nodes if k == 0 else reed_nodes)[ai].append(mmi)
				b.ms["bank_inst"] = b.ms.get("bank_inst", 0) + bm[k].instance_count
	b.ms["bank"] = (Time.get_ticks_usec() - tb) / 1000.0
	for k in ["bank_reach", "mud_w"]:
		tm.set_shader_parameter(k, Par.g(k))
	b.ms["grass"] = (Time.get_ticks_usec() - t0) / 1000.0

var _tex_cache := {}
func _tex(nm: String) -> ImageTexture:
	if not _tex_cache.has(nm):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/tex/%s.png" % nm))
		img.generate_mipmaps()
		_tex_cache[nm] = ImageTexture.create_from_image(img)
	return _tex_cache[nm]

## vzhled písku: [sand_look 0/1, sand_detail 0/1/2, bands]
func _set_look(l: Array) -> void:
	look = l
	for m in t_mats:
		m.set_shader_parameter("sand_look", l[0])
		m.set_shader_parameter("sand_detail", l[1])
		m.set_shader_parameter("bands", l[2])
	_vis_grass_mix()

func _vis_grass_mix() -> void:
	for k in nv:
		for n in grass_mix[k]:
			n.visible = look[2] and Par.i("mix_tufts") >= 0 and _approach_visible(k) and grass_shown
		for n in bank_nodes[k]:
			n.visible = shore[0] and _approach_visible(k) and grass_shown
		for n in reed_nodes[k]:
			n.visible = shore[1] and _approach_visible(k) and grass_shown

func _shore_default() -> Array:
	var auto := Par.i("layout") == 1
	return [Par.i("bank") == 1 or (Par.i("bank") < 0 and auto), Par.i("reeds") == 1 or (Par.i("reeds") < 0 and auto), Par.g("foam_bank") if auto or Par.i("bank") == 1 else 1.0]

## louka u vody: [travnatý břeh + bahno, rákos, síla pěny u louky]
func _set_shore(sh: Array) -> void:
	shore = sh
	for m in t_mats:
		m.set_shader_parameter("bank", sh[0])
	for m in w_mats:
		m.set_shader_parameter("foam_bank", sh[2])
	_vis_grass_mix()
var shown_ai := -1
var grass_shown := true
func _approach_visible(k: int) -> bool:
	return shown_ai < 0 or shown_ai == k

func _build_labels() -> void:
	for ai in nv:
		var l := Label3D.new()
		l.text = VAR[ai][2]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.outline_size = 14
		l.modulate = Color(0.32, 0.25, 0.42)
		l.outline_modulate = Color(1, 1, 1)
		l.pixel_size = 0.012 * cxy
		l.position = origin[ai] + Vector3(data.N * cxy * 0.5, 0.0, data.N * cxy + 4.0 * cxy)
		add_child(l)
		labels.append(l)

func _print_stats() -> void:
	var out := []
	out.append("data (4 vzorky, dorovnání stran): %.1f ms" % times["data"])
	for ai in nv:
		var b = bld[ai]
		out.append("%s: splat %.0f ms, pole %.0f ms, mesh %.0f ms (%d trojúhelníků), voda %.0f ms, tráva %.0f ms (%d instancí s řídnutím)" % [
			VAR[ai][2], b.ms["splat"], b.ms["fields"], b.ms["mesh"], b.tris, b.ms["water"], b.ms["grass"], inst[ai]])
	out.append("stavba celkem %.0f ms (GDScript, splat %d px/buňku)" % [times["celkem"], Par.i("splat_px")])
	for l in out:
		print(l)
	times["lines"] = out

# ------------------------------------------------------------------ přepínače
func _set_extras(on: bool) -> void:
	extras_on = on
	for m in t_mats:
		m.set_shader_parameter("extras", on)
	for m in w_mats:
		m.set_shader_parameter("extras", on)
	for ai in nv:
		for n in grass_plain[ai]:
			n.visible = not on
		for n in grass_thin[ai]:
			n.visible = on

func _show_only(ai: int) -> void:
	shown_ai = ai
	for k in nv:
		for n in nodes[k]:
			if n in grass_plain[k]:
				n.visible = (ai < 0 or ai == k) and not extras_on
			elif n in grass_thin[k]:
				n.visible = (ai < 0 or ai == k) and extras_on
			else:
				n.visible = ai < 0 or ai == k
	for l in labels:
		l.visible = false
	_vis_grass_mix()

func _set_grass(on: bool) -> void:
	for k in nv:
		for n in grass_plain[k] + grass_thin[k]:
			n.visible = on and _approach_visible(k) and ((n in grass_thin[k]) == extras_on)
	grass_shown = on
	_vis_grass_mix()

func _advance(dt: float) -> void:
	sim_t += dt
	for m in w_mats:
		m.set_shader_parameter("sim_time", sim_t)
	for m in g_mats:
		m.set_shader_parameter("sim_time", sim_t)

# ------------------------------------------------------------------ kamera
func _overview_both() -> Dictionary:
	var c: Vector3 = (origin[0] + origin[1] + Vector3(data.N * cxy, 0, data.N * cxy)) * 0.5
	return {"center": c + Vector3(0, 1.0, 0), "size": (2 * data.N + GAP) * cxy * 0.78}

func _view(ai: int, cx: float, cz: float, size: float) -> Dictionary:
	return {"center": origin[ai] + Vector3(cx * cxy, 1.0, cz * cxy), "size": size * cxy}

func _set_cam(v: Dictionary, pitch := -35.0, yaw := 45.0) -> void:
	if pitch < -80.0:
		yaw = 0.0
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0), EULER_ORDER_YXZ)
	cam.transform = Transform3D(basis, v.center + basis.z * 80.0)
	cam.size = v.size

func _lerp_view(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"center": a.center.lerp(b.center, k), "size": lerpf(a.size, b.size, k)}

func _process(delta: float) -> void:
	if mode in ["shots", "bench", "stats", "mekkost", "hrana", "samostatne", "louka_voda"]:
		return
	if mode == "movie":
		_advance(STEP)
		_movie_cam()
		return
	_advance(delta)
	match cam_mode:
		0: _set_cam(_overview_both())
		1: _set_cam(_view(0, 10, 10, 7))
		2: _set_cam(_view(1, 10, 10, 7))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_1: cam_mode = 0
			KEY_2: cam_mode = 1
			KEY_3: cam_mode = 2
			KEY_E: _set_extras(not extras_on)
			KEY_G:
				for m in t_mats:
					m.set_shader_parameter("grid_overlay", (int(m.get_shader_parameter("grid_overlay")) + 1) % 3)

## 0–2,5 s oba přístupy, najetí na křížení 4 vzorků v 1, přejezd na stejné místo ve 2, pobřeží ve 2, zpět
func _movie_cam() -> void:
	var t := sim_t
	var ov := _overview_both()
	var a := _view(0, 10, 10, 7.5)
	var b := _view(1, 10, 10, 7.5)
	var c := _view(1, 15, 14, 8.5)
	var v: Dictionary
	if t < 2.5: v = ov
	elif t < 4.0: v = _lerp_view(ov, a, smoothstep(2.5, 4.0, t))
	elif t < 6.0: v = a
	elif t < 7.2: v = _lerp_view(a, b, smoothstep(6.0, 7.2, t))
	elif t < 9.2: v = b
	elif t < 10.2: v = _lerp_view(b, c, smoothstep(9.2, 10.2, t))
	elif t < 12.0: v = c
	else: v = _lerp_view(c, ov, smoothstep(12.0, 13.5, t))
	_set_cam(v)

# ------------------------------------------------------------------ screenshoty
func _shot(name: String) -> String:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shots/" + name)
	img.save_png(path)
	return path

## tiles: [[pohled, ai (-1 = oba), popisek, doplňky, mřížka(0–2), pitch]]; layout "h" (vedle sebe) nebo "2x2"
func _compose(name: String, tiles: Array, layout := "h") -> void:
	var paths := []
	for i in tiles.size():
		var tl: Array = tiles[i]
		_set_extras(tl[3])
		_show_only(tl[1])
		for m in t_mats:
			m.set_shader_parameter("grid_overlay", tl[4])
		_set_grass(tl[6] if tl.size() > 6 else true)
		if tl.size() > 7:
			_set_look(tl[7])
		else:
			_set_look([Par.i("sand_look"), Par.i("sand_detail"), Par.i("bands") == 1])
		_set_shore(tl[8] if tl.size() > 8 else _shore_default())
		_set_cam(tl[0], tl[5] if tl.size() > 5 else -35.0)
		paths.append(await _shot("_tmp_%d.png" % i))
	for m in t_mats:
		m.set_shader_parameter("grid_overlay", 0)
	var out := ProjectSettings.globalize_path("res://shots/" + name)
	var args := ["-y", "-loglevel", "error"]
	for p in paths:
		args.append_array(["-i", p])
	var font := "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
	var fc := ""
	for i in tiles.size():
		var txt: String = tiles[i][2].replace(":", "\\:").replace("'", "")
		fc += "[%d]drawtext=fontfile=%s:text='%s':x=18:y=16:fontsize=34:fontcolor=0x3a2d4a:box=1:boxcolor=white@0.8:boxborderw=8[t%d];" % [i, font, txt, i]
	if layout == "2x2":
		fc += "[t0][t1]hstack[a];[t2][t3]hstack[b];[a][b]vstack,scale=1920:-1"
	elif layout == "v":
		for i in tiles.size():
			fc += "[t%d]scale=960:-1[s%d];" % [i, i]
		for i in tiles.size():
			fc += "[s%d]" % i
		fc += "vstack=inputs=%d" % tiles.size()
	elif layout == "3x2":
		fc += "[t0][t1]hstack[a];[t2][t3]hstack[b];[t4][t5]hstack[c];[a][b][c]vstack=inputs=3,scale=1920:-1"
	elif tiles.size() == 1:
		fc += "[t0]scale=1280:-1"
	else:
		for i in tiles.size():
			fc += "[t%d]" % i
		fc += "hstack=inputs=%d,scale=1920:-1" % tiles.size()
	args.append_array(["-filter_complex", fc, out])
	var outp := []
	var rc := OS.execute("ffmpeg", args, outp, true)
	if rc != 0:
		print("ffmpeg chyba: ", outp)
	for p in paths:
		DirAccess.remove_absolute(p)
	print("ulozeno ", out)

func _pair(name: String, cx: float, cz: float, size: float, extras := true, what := "") -> void:
	await _compose(name, [
		[_view(0, cx, cz, size), 0, "1 mřížka · " + what, extras, 0],
		[_view(1, cx, cz, size), 1, "2 duální · " + what, extras, 0]])

func _run_shots() -> void:
	_advance(1.3)
	# celek obou přístupů
	await _compose("29_napojeni_prehled.png", [[_overview_both(), -1, "vlevo 1 klasická mřížka (přechod na hranách buněk) · vpravo 2 duální mřížka (dlaždice z rohů)", true, 0]])
	var N: float = data.N
	var ov0 := _view(0, N * 0.5, N * 0.5, N * 1.2)
	var ov1 := _view(1, N * 0.5, N * 0.5, N * 1.2)
	await _compose("29_napojeni_prehled_srovnani.png", [
		[ov0, 0, "1 mřížka · bez doplňků", false, 0], [ov1, 1, "2 duální · bez doplňků", false, 0],
		[ov0, 0, "1 mřížka · s doplňky", true, 0], [ov1, 1, "2 duální · s doplňky", true, 0]], "2x2")
	var h := N * 0.5
	await _pair("29_napojeni_sev_louka_pisek.png", h, h * 0.45, 7.0, true, "šev vzorků louka | píščina")
	await _pair("29_napojeni_sev_louka_voda.png", h * 0.45, h, 7.0, true, "šev vzorků louka / voda")
	await _pair("29_napojeni_kriz_vzorku.png", h, h, 7.0, true, "křížení 4 vzorků")
	await _pair("29_napojeni_pobrezi_vzorek.png", h * 1.5, h * 1.45, 8.0, true, "pobřeží uvnitř vzorku")
	await _pair("29_napojeni_ostrov.png", h * 0.62, h * 1.58, 6.0, true, "ostrůvek ve vodě")
	await _pair("29_napojeni_pisek_ostruvky.png", h * 1.5, h * 0.5, 8.0, true, "tráva v písku")
	# shora s mřížkami: bílá = datové buňky, červeně = duální dlaždice (rohy ve středech buněk)
	await _compose("29_napojeni_shora_mrizky.png", [
		[_view(0, h, h, 9.0), 0, "1 mřížka · shora, bílá = buňky", false, 1, -89.9, false],
		[_view(1, h, h, 9.0), 1, "2 duální · červeně = dlaždice", false, 2, -89.9, false]])
	_set_grass(true)
	# doplňky zblízka: bez / s
	await _compose("29_napojeni_doplnky_detail.png", [
		[_view(0, h * 1.35, h * 1.3, 6.0), 0, "1 mřížka · bez doplňků", false, 0],
		[_view(0, h * 1.35, h * 1.3, 6.0), 0, "1 mřížka · s doplňky", true, 0],
		[_view(1, h * 1.35, h * 1.3, 6.0), 1, "2 duální · bez doplňků", false, 0],
		[_view(1, h * 1.35, h * 1.3, 6.0), 1, "2 duální · s doplňky", true, 0]], "2x2")
	get_tree().quit()

# ------------------------------------------------------------------ vzhled písku a měkkost přechodů (30_*)
const OLD := [0, 0, false]
const NEW_TEX := [1, 1, true]
const NEW_PROC := [1, 2, true]

func _run_mekkost() -> void:
	_advance(1.3)
	var h: float = data.N * 0.5
	var v0 := _view(0, h * 1.35, h * 1.3, 6.5)
	var v1 := _view(1, h * 1.35, h * 1.3, 6.5)
	await _compose("30_napojeni_mekkost_pisek.png", [
		[v0, 0, "1 · původní písek", true, 0, -35.0, true, OLD], [v1, 1, "2 · původní písek", true, 0, -35.0, true, OLD],
		[v0, 0, "1 · nový písek + textura Gemini + pásy", true, 0, -35.0, true, NEW_TEX], [v1, 1, "2 · nový písek + textura Gemini + pásy", true, 0, -35.0, true, NEW_TEX],
		[v0, 0, "1 · nový písek + procedurální zrno + pásy", true, 0, -35.0, true, NEW_PROC], [v1, 1, "2 · nový písek + procedurální zrno + pásy", true, 0, -35.0, true, NEW_PROC]], "3x2")
	var p0 := _view(0, h * 1.5, h * 1.45, 8.0)
	var p1 := _view(1, h * 1.5, h * 1.45, 8.0)
	await _compose("30_napojeni_mekkost_pasy.png", [
		[p0, 0, "1 · nový písek, bez pásů", true, 0, -35.0, true, [1, 2, false]], [p1, 1, "2 · nový písek, bez pásů", true, 0, -35.0, true, [1, 2, false]],
		[p0, 0, "1 · nový písek, s pásy", true, 0, -35.0, true, NEW_PROC], [p1, 1, "2 · nový písek, s pásy", true, 0, -35.0, true, NEW_PROC]], "2x2")
	var o0 := _view(0, h, h, data.N * 1.2)
	var o1 := _view(1, h, h, data.N * 1.2)
	await _compose("30_napojeni_mekkost_prehled.png", [
		[o0, 0, "1 · původní písek", true, 0, -35.0, true, OLD], [o1, 1, "2 · původní písek", true, 0, -35.0, true, OLD],
		[o0, 0, "1 · nový písek + procedurální zrno + pásy", true, 0, -35.0, true, NEW_PROC], [o1, 1, "2 · nový písek + procedurální zrno + pásy", true, 0, -35.0, true, NEW_PROC]], "2x2")
	await _compose("30_napojeni_mekkost_detail_2.png", [
		[_view(1, h * 1.45, h * 1.5, 3.5), 1, "2 · původní písek", true, 0, -35.0, true, OLD],
		[_view(1, h * 1.45, h * 1.5, 3.5), 1, "2 · nový + Gemini + pásy", true, 0, -35.0, true, NEW_TEX],
		[_view(1, h * 1.45, h * 1.5, 3.5), 1, "2 · nový + procedurální + pásy", true, 0, -35.0, true, NEW_PROC]])
	get_tree().quit()

## jeden řádek srovnání měkkosti hrany materiálu (spouští run.sh hrana s různými --edge_soft/--dual_soft)
func _run_hrana() -> void:
	_advance(1.3)
	var tag := "x"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	var h: float = data.N * 0.5
	await _compose("_hrana_%s.png" % tag, [
		[_view(0, h * 1.35, h * 1.3, 6.5), 0, "1 · %s (edge_soft %.2f)" % [tag, Par.g("edge_soft")], true, 0],
		[_view(1, h * 1.35, h * 1.3, 6.5), 1, "2 · %s (dual_soft %.2f)" % [tag, Par.g("dual_soft")], true, 0]])
	get_tree().quit()

# ------------------------------------------------------------------ samostatné buňky v duální mřížce (31_*)
func _rows(name: String, cx: float, cz: float, size: float, what: String) -> void:
	var tiles := []
	for ai in nv:
		tiles.append([_view(ai, cx, cz, size), ai, VAR[ai][2] + " · " + what, true, 0])
	await _compose(name, tiles, "v")

func _run_samostatne() -> void:
	_advance(1.3)
	var h: float = data.N * 0.5
	await _rows("31_napojeni_samostatne_pisek_ostruvky.png", h * 1.5, h * 0.5, 8.0, "tráva v písku")
	await _rows("31_napojeni_samostatne_ostrov.png", h * 0.62, h * 1.58, 6.0, "ostrůvek ve vodě")
	await _rows("31_napojeni_samostatne_sev_louka_voda.png", h * 0.45, h, 7.0, "louka / voda")
	var tiles := []
	for ai in nv:
		tiles.append([_view(ai, h, h, data.N * 1.2), ai, VAR[ai][2], true, 0])
	tiles.append([_view(nv - 1, h * 1.5, h * 0.5, 7.0), nv - 1, "hybrid shora (bílá = buňky)", true, 1, -89.9, false])
	await _compose("31_napojeni_samostatne_prehled.png", tiles, "3x2")
	# výkon: celek každé varianty
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Array = times["lines"].duplicate()
	_set_extras(true)
	_set_look([Par.i("sand_look"), Par.i("sand_detail"), Par.i("bands") == 1])
	for ai in nv:
		for view in ["celek", "detail"]:
			_show_only(ai)
			_set_grass(true)
			_set_cam(_view(ai, h, h, data.N * 1.2) if view == "celek" else _view(ai, h * 1.5, h * 0.5, 5.0))
			for i in 20:
				_advance(STEP)
				await RenderingServer.frame_post_draw
			var t0 := Time.get_ticks_usec()
			for i in 60:
				_advance(STEP)
				await RenderingServer.frame_post_draw
			var line := "%s %s: %.1f ms/snímek" % [VAR[ai][2], view, float(Time.get_ticks_usec() - t0) / 60000.0]
			print(line)
			out.append(line)
	var f := FileAccess.open("res://shots/bench_samostatne.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	get_tree().quit()

# ------------------------------------------------------------------ louka přímo u vody (33_*), spouštět s --layout=1
const SH_OFF := [false, false, 1.0]
const SH_BANK := [true, false, 0.3]
const SH_ALL := [true, true, 0.3]

func _run_louka_voda() -> void:
	_advance(1.3)
	var h: float = data.N * 0.5
	var o0 := _view(0, h, h, data.N * 1.2); var o1 := _view(1, h, h, data.N * 1.2)
	var tl := func(v, ai, txt, sh): return [v, ai, txt, true, 0, -35.0, true, [Par.i("sand_look"), Par.i("sand_detail"), Par.i("bands") == 1], sh]
	await _compose("33_napojeni_louka_voda_prehled.png", [
		tl.call(o0, 0, "1 klasická · bez úprav břehu", SH_OFF), tl.call(o1, 1, "2 duální · bez úprav břehu", SH_OFF),
		tl.call(o0, 0, "1 klasická · travnatý břeh, bahno, rákos", SH_ALL), tl.call(o1, 1, "2 duální · travnatý břeh, bahno, rákos", SH_ALL)], "2x2")
	# plochý břeh (nízká louka 0,15 m nad hladinou) a vyšší břehy o 1 a 2 vrstvy
	var views := [["plochy_breh", h * 0.55, h * 1.0, 6.0, "plochý břeh (+0,15 m)"],
		["breh_1_vrstva", h * 1.25, h * 1.0, 6.0, "břeh o 1 vrstvu výš"],
		["breh_2_vrstvy", h * 1.75, h * 1.0, 6.0, "břeh o 2 vrstvy výš"],
		["jazyk_ostruvek", h * 0.9, h * 1.45, 8.0, "travnatý jazyk a ostrůvek ve vodě"]]
	for v in views:
		await _compose("33_napojeni_louka_voda_%s.png" % v[0], [
			tl.call(_view(0, v[1], v[2], v[3]), 0, "1 klasická · " + v[4], SH_ALL),
			tl.call(_view(1, v[1], v[2], v[3]), 1, "2 duální · " + v[4], SH_ALL)])
	# možnosti v duální mřížce zblízka
	var vd := _view(1, h * 0.8, h * 1.05, 5.0)
	await _compose("33_napojeni_louka_voda_moznosti.png", [
		tl.call(vd, 1, "2 · bez úprav (proužek dna, plná pěna)", SH_OFF),
		tl.call(vd, 1, "2 · travnatý břeh + bahno + slabší pěna", SH_BANK),
		tl.call(vd, 1, "2 · + rákos", SH_ALL),
		tl.call(vd, 1, "2 · + rákos, pěna jako u pláže", [true, true, 1.0])], "2x2")
	# výkon
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Array = times["lines"].duplicate()
	for ai in nv:
		out.append("%s: břeh a rákos %.0f ms, %d instancí" % [VAR[ai][2], bld[ai].ms["bank"], bld[ai].ms["bank_inst"]])
		for sh in [SH_OFF, SH_ALL]:
			_set_extras(true)
			_show_only(ai)
			_set_grass(true)
			_set_shore(sh)
			_set_cam(_view(ai, h, h, data.N * 1.2))
			for i in 20:
				_advance(STEP)
				await RenderingServer.frame_post_draw
			var t0 := Time.get_ticks_usec()
			for i in 60:
				_advance(STEP)
				await RenderingServer.frame_post_draw
			var line := "%s %s: %.1f ms/snímek" % [VAR[ai][2], "s břehem a rákosem" if sh[0] else "bez úprav", float(Time.get_ticks_usec() - t0) / 60000.0]
			print(line)
			out.append(line)
	var f := FileAccess.open("res://shots/bench_louka_voda.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	get_tree().quit()

# ------------------------------------------------------------------ výkon
func _run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Array = times["lines"].duplicate()
	var N: float = data.N
	for ai in nv:
		for ex in [false, true]:
			for view in ["celek", "detail"]:
				_set_extras(ex)
				_show_only(ai)
				_set_cam(_view(ai, N * 0.5, N * 0.5, N * 1.2) if view == "celek" else _view(ai, N * 0.5, N * 0.5, 5.0))
				for i in 20:
					_advance(STEP)
					await RenderingServer.frame_post_draw
				var t0 := Time.get_ticks_usec()
				var frames := 60
				for i in frames:
					_advance(STEP)
					await RenderingServer.frame_post_draw
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
				var line := "přístup %d %s %s: %.1f ms/snímek" % [ai + 1, "s doplňky" if ex else "bez doplňků", view, ms]
				print(line)
				out.append(line)
	out.append("renderer: %s" % RenderingServer.get_video_adapter_name())
	var f := FileAccess.open("res://shots/bench.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	get_tree().quit()
