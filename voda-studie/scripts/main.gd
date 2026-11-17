extends Node3D
## Studie vody a propustnosti pro Willage (Jan 2026-11-17 15:47 / 15:51).
## Simulace je v scripts/water_sim.gd (čistá data), tady jen scénáře, vykreslení, snímky a měření.
## Režimy (za --): bez parametru = interaktivně (mezerník běh/pauza, V pohled, 1–6 scénář, N jeden tik),
##   --shots (všechny scénáře nebo --scen=k), --bench. Parametry viz scripts/params.gd (-- --klic=hodnota).

const Par = preload("res://scripts/params.gd")
const M = preload("res://scripts/materials.gd")
const Scen = preload("res://scripts/scenarios.gd")

const VIEWS := ["voda", "nasycení (řez)", "průchodnost"]
var mode := "play"
var cam: Camera3D
var root: Node3D
var hud: Label
var water_mat: ShaderMaterial
var solid_mat: StandardMaterial3D
var overlay_mat: StandardMaterial3D
var cxy := 1.0
var cz := 0.5
var sc: Dictionary
var sim
var view := 0
var running := false
var acc := 0.0
var sim_t := 0.0
var cur_title := ""
var dig_note := ""
var stats_lines := PackedStringArray()

func _ready() -> void:
	Par.parse_cli()
	for a in OS.get_cmdline_user_args():
		if a in ["--shots", "--bench"]:
			mode = a.substr(2)
	cxy = Par.g("cell_xy"); cz = Par.g("cell_z")
	if mode == "bench":
		_bench()
		get_tree().quit()
		return
	_setup_env()
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.render_priority = 1
	solid_mat = StandardMaterial3D.new()
	solid_mat.vertex_color_use_as_albedo = true
	solid_mat.roughness = 1.0
	solid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay_mat = StandardMaterial3D.new()
	overlay_mat.vertex_color_use_as_albedo = true
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.render_priority = 2
	overlay_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1; cam.far = 300.0
	add_child(cam)
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(14, 10)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_color_override("font_color", Color(0.12, 0.13, 0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.78)
	sb.set_content_margin_all(8)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	hud.add_theme_stylebox_override("normal", sb)
	cl.add_child(hud)
	root = Node3D.new()
	add_child(root)
	if mode == "shots":
		await _shots()
		get_tree().quit()
	else:
		_load(maxi(Par.i("scen"), 1))

func _setup_env() -> void:   # stejné prostředí jako napojeni-studie
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.55
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

func _load(n: int) -> void:
	sc = Scen.make(n, Par.P)
	sc["n"] = n
	sim = sc.sim
	cur_title = Scen.LIST[n - 1][2]
	dig_note = ""
	if sc.has("sources"):
		for so in sc.sources:
			if so.type == "underground_pocket":
				sc.cut = so.cells[0].y + 1
	var c := Vector3(sim.NX * cxy * 0.5, sim.NZ * cz * 0.35, sim.NY * cxy * 0.5)
	var dir := Vector3(0.9, 1.05, 1.3).normalized()
	cam.size = maxf(sim.NX, sim.NY) * cxy * 1.2
	c += Vector3(0, cam.size * 0.12, 0)        # vzorek trochu níž v obraze, nahoře je popisek
	cam.position = c + dir * 40.0
	cam.look_at(c, Vector3.UP)
	_rebuild()

## kopání naplánované na tik (scénáře 5 a 6)
func _apply_digs() -> void:
	for d in sc.digs:
		if d.tick == sim.tick:
			for c in d.cells:
				sim.dig(c.x, c.y, c.z)
			dig_note = "vykopáno v tiku %d: %s" % [d.tick, d.label]

func _step() -> void:
	_apply_digs()
	sim.step()

func _process(dt: float) -> void:
	sim_t += dt
	if water_mat:
		water_mat.set_shader_parameter("sim_time", sim_t)
	if mode != "play" or sim == null:
		return
	if running:
		acc += dt
		var ts := Par.g("tick_s")
		var any := false
		while acc >= ts:
			acc -= ts
			_step()
			any = true
		if any:
			_rebuild()

func _unhandled_input(e: InputEvent) -> void:
	if mode != "play" or not (e is InputEventKey) or not e.pressed:
		return
	match e.keycode:
		KEY_SPACE: running = not running
		KEY_V:
			view = (view + 1) % 3
			_rebuild()
		KEY_N:
			_step(); _rebuild()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_load(e.keycode - KEY_0)

# ------------------------------------------------------------------ vykreslení
func _hidden(y: int) -> bool:
	return view == 1 and y >= int(sc.cut)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)

## kvádr [p0, p1] – jen stěny podle masky (bit 0 +x, 1 -x, 2 +y(svět), 3 -y, 4 +z, 5 -z)
func _box(st: SurfaceTool, p0: Vector3, p1: Vector3, col: Color, mask: int) -> void:
	if mask & 1: _quad(st, Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p0.y, p1.z), Vector3.RIGHT, col)
	if mask & 2: _quad(st, Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p0.y, p0.z), Vector3.LEFT, col)
	if mask & 4: _quad(st, Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p1.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p1.y, p0.z), Vector3.UP, col)
	if mask & 8: _quad(st, Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p0.y, p1.z), Vector3.DOWN, col)
	if mask & 16: _quad(st, Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p0.y, p1.z), Vector3.BACK, col)
	if mask & 32: _quad(st, Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3.FORWARD, col)

func _is_solid_vis(x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0 or x >= sim.NX or y >= sim.NY or z >= sim.NZ:
		return false
	if _hidden(y):
		return false
	return sim.mat[sim.idx(x, y, z)] != M.AIR

func _wlev(x: int, y: int, z: int) -> float:   # výška vody v buňce 0..1 (pro boky vody); -1 = pevná / mimo
	if x < 0 or y < 0 or x >= sim.NX or y >= sim.NY or _hidden(y):
		return 0.0
	var i: int = sim.idx(x, y, z)
	if sim.mat[i] != M.AIR:
		return -1.0
	if z + 1 < sim.NZ and sim.mat[i + sim.A] == M.AIR and sim.w[i + sim.A] >= Par.g("draw_min"):
		return 1.0
	return minf(sim.w[i], 1.0) if sim.w[i] >= Par.g("draw_min") else 0.0

func _rebuild() -> void:
	for ch in root.get_children():
		ch.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ws := SurfaceTool.new()
	ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dm := Par.g("draw_min")
	var nw := 0
	for z in sim.NZ:
		for y in sim.NY:
			if _hidden(y):
				continue
			for x in sim.NX:
				var i: int = sim.idx(x, y, z)
				var m: int = sim.mat[i]
				var p0 := Vector3(x * cxy, z * cz, y * cxy)
				var p1 := p0 + Vector3(cxy, cz, cxy)
				if m != M.AIR:
					var mask := 0
					if not _is_solid_vis(x + 1, y, z): mask |= 1
					if not _is_solid_vis(x - 1, y, z): mask |= 2
					if not _is_solid_vis(x, y, z + 1): mask |= 4
					if not _is_solid_vis(x, y + 1, z): mask |= 16
					if not _is_solid_vis(x, y - 1, z): mask |= 32
					if mask == 0:
						continue
					var col: Color = M.COLORS[m]
					var hsh := float(hash(i * 7919) % 1000) / 1000.0
					col = col * (0.94 + 0.06 * hsh)
					if view == 1 and sim.cap[i] > 0.0:
						var s: float = clampf(sim.w[i] / sim.cap[i], 0.0, 1.0)
						col = col.lerp(Color(0.10, 0.30, 0.85), s * 0.8)
					col.a = 1.0
					if m == M.GRASS and view != 1:
						_box(st, p0, p1, col, mask & 4)
						_box(st, p0, p1, M.COLORS[M.DIRT].lerp(col, 0.35), mask & ~4)
					else:
						_box(st, p0, p1, col, mask)
				elif sim.w[i] >= dm:
					nw += 1
					var lv: float = minf(sim.w[i], 1.0)
					var below_air: bool = z > 0 and sim.mat[i - sim.A] == M.AIR and sim.w[i - sim.A] < 0.9 and sim.w[i] < 0.5
					var depth := _col_depth(x, y)
					var fl: float = clampf(sim.flux[i] * 12.0, 0.0, 1.0)
					var wc := Color(depth, fl, 0, 1)
					if below_air:   # padající voda: svislý pramínek
						var half: float = clampf(sqrt(sim.w[i]) * 0.6, 0.12, 0.5) * cxy
						var cc := (p0 + p1) * 0.5
						_box(ws, Vector3(cc.x - half, p0.y, cc.z - half), Vector3(cc.x + half, p1.y, cc.z + half), Color(depth, 1.0, 0, 1), 63)
						continue
					var top := p0.y + lv * cz
					var above_w := _wlev(x, y, z + 1) if z + 1 < sim.NZ else 0.0
					if above_w > 0.0:
						top = p1.y
					else:
						_box(ws, p0, Vector3(p1.x, top + 0.005, p1.z), wc, 4)
					var sides := [[1, 0, 1], [-1, 0, 2], [0, 1, 16], [0, -1, 32]]
					for sd in sides:
						var nl := _wlev(x + sd[0], y + sd[1], z)
						if nl < 0.0:
							continue
						var nt: float = p0.y + nl * cz
						if nt < top - 0.01:
							_box(ws, Vector3(p0.x, nt, p0.z), Vector3(p1.x, top, p1.z), wc, sd[2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = solid_mat
	root.add_child(mi)
	if nw > 0:
		var wm := MeshInstance3D.new()
		wm.mesh = ws.commit()
		wm.material_override = water_mat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wm)
	if view == 2:
		_walk_overlay()
	_markers()
	_hud()

func _col_depth(x: int, y: int) -> float:
	var d := 0.0
	for z in sim.NZ:
		var i: int = sim.idx(x, y, z)
		if sim.mat[i] == M.AIR:
			d += sim.w[i]
	return d * cz

func _walk_overlay() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := [Color(0.25, 0.85, 0.30, 0.62), Color(1.0, 0.82, 0.15, 0.70), Color(0.92, 0.18, 0.15, 0.70)]
	for y in sim.NY:
		for x in sim.NX:
			var r: Array = sim.walk(x, y)
			var h: float = (r[2] + 1) * cz + r[1] + 0.03
			var p0 := Vector3(x * cxy + 0.06, h, y * cxy + 0.06)
			var p1 := Vector3((x + 1) * cxy - 0.06, h, (y + 1) * cxy - 0.06)
			_box(st, p0, p1, cols[r[0]], 4)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = overlay_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

func _markers() -> void:
	if not sc.has("sources") and sc.n != 2 and sc.n != 3 and sc.n != 4:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for so in sim.sources:
		var col := Color(0.1, 0.9, 1.0)
		var c := Vector3.ZERO
		match so.type:
			"top_flow":
				c = Vector3((so.x + 0.5) * cxy, (sim.surface_z(so.x, so.y) + 2.2) * cz, (so.y + 0.5) * cxy)
			"hillside_spring":
				col = Color(1.0, 0.3, 0.85)
				c = Vector3((so.x + 0.5 + so.dir.x * 0.55) * cxy, (so.z + 0.5) * cz, (so.y + 0.5 + so.dir.y * 0.55) * cxy)
			"underground_pocket":
				if view != 1:
					continue
				col = Color(1.0, 0.55, 0.1)
				for cc in so.cells:
					if _hidden(cc.y):
						continue
					var q0 := Vector3(cc.x * cxy, cc.z * cz, cc.y * cxy)
					_box(st, q0 + Vector3(0, -0.02, -0.02), q0 + Vector3(cxy, 0.04, cxy + 0.02), col, 63)
				continue
		var hs := 0.16
		_box(st, c - Vector3(hs, hs, hs), c + Vector3(hs, hs, hs), col, 63)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm := StandardMaterial3D.new()
	mm.vertex_color_use_as_albedo = true
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	root.add_child(mi)

func _hud() -> void:
	var tot: float = sim.total()
	var fr: float = sim.free_water()
	var t := "%s\npohled: %s · tik %d\nvoda %.2f (volná %.2f, v zemi %.2f) · přiteklo %.2f · odteklo %.2f · odpar %.2f" % [
		cur_title, VIEWS[view], sim.tick, tot, fr, tot - fr, sim.in_total + sim.initial, sim.out_total, sim.evap_total]
	if view == 2:
		t += "\nzelená průchozí · žlutá pomalé (mělká voda, bláto) · červená neprůchozí"
	if view == 1:
		t += "\nřez vzorkem: modřejší = nasycenější"
	if dig_note != "":
		t += "\n" + dig_note
	if sc.n == 2:
		t += "\nčelo vody (řada z %d): louka %d · písek %d" % [sim.NY, _front(sc.compare_x[0]) + 1, _front(sc.compare_x[1]) + 1]
		t += "\npovrchový odtok: louka %.2f (od tiku %d) · písek %.2f (od tiku %d)" % _cmp2()
	hud.text = t

## nejvzdálenější řada (y), kam ve pruhu doteklo povrchem aspoň „film“ volné vody
func _front(rg: Array) -> int:
	var f := -1
	for y in sim.NY:
		for x in range(rg[0], rg[1] + 1):
			var zs: int = sim.surface_z(x, y)
			if zs + 1 < sim.NZ and sim.w[sim.idx(x, y, zs + 1)] >= Par.g("film"):
				f = y
	return f

func _cmp2() -> Array:
	var r := []
	for rg in sc.compare_x:
		var o := 0.0
		var first := -1
		for x in range(rg[0], rg[1] + 1):
			o += sim.out_surf_by_x[x]
			var f: int = sim.first_surf_by_x[x]
			if f >= 0 and (first < 0 or f < first):
				first = f
		r.append(o); r.append(first)
	return r

# ------------------------------------------------------------------ snímky
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _shots() -> void:
	var pw := Par.i("panel_w")
	var ph := Par.i("panel_h")
	var only := Par.i("scen")
	var finals := []
	for row in Scen.LIST:
		var n: int = row[0]
		if only > 0 and n != only:
			continue
		_load(n)
		var phases: Array = sc.phases
		var sheet := Image.create(pw * phases.size(), ph * 3, false, Image.FORMAT_RGBA8)
		for pi in phases.size():
			while sim.tick < phases[pi]:
				_step()
			_stat_line(n)
			for v in 3:
				view = v
				_rebuild()
				var img: Image = await _grab()
				if pi == phases.size() - 1 and v == 0:
					finals.append(img.duplicate())
				if n == 6 and v == 0 and pi == 2:
					img.save_png(ProjectSettings.globalize_path("res://shots/35_voda_6_prameny_detail.png"))
				img.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(img, Rect2i(0, 0, pw, ph), Vector2i(pi * pw, v * ph))
		var path := "res://shots/35_voda_%d_%s.png" % [n, row[1]]
		sheet.save_png(ProjectSettings.globalize_path(path))
		print("ulozeno ", path)
		view = 0
	if finals.size() >= 4:
		var cols := 3
		var rows := int(ceil(finals.size() / float(cols)))
		var sh := Image.create(pw * cols, ph * rows, false, Image.FORMAT_RGBA8)
		sh.fill(Color(1, 1, 1))
		for k in finals.size():
			var im: Image = finals[k]
			im.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
			sh.blit_rect(im, Rect2i(0, 0, pw, ph), Vector2i((k % cols) * pw, (k / cols) * ph))
		sh.save_png(ProjectSettings.globalize_path("res://shots/35_voda_srovnani.png"))
	var f := FileAccess.open("res://shots/stats.txt", FileAccess.WRITE)
	f.store_string("\n".join(stats_lines) + "\n")

func _stat_line(n: int) -> void:
	var tot: float = sim.total()
	var fr: float = sim.free_water()
	var walk := [0, 0, 0]
	for y in sim.NY:
		for x in sim.NX:
			walk[sim.walk(x, y)[0]] += 1
	var l := "scen %d tik %4d  voda %.3f volna %.3f zem %.3f  pocatek %.3f in %.3f out %.3f odpar %.3f  bilance(max chyba/tik) %s  pruchozi/pomale/neprujezdne %d/%d/%d" % [
		n, sim.tick, tot, fr, tot - fr, sim.initial, sim.in_total, sim.out_total, sim.evap_total, String.num_scientific(sim.bal_err_max), walk[0], walk[1], walk[2]]
	if n == 2:
		l += "  celo vody louka %d pisek %d" % [_front(sc.compare_x[0]) + 1, _front(sc.compare_x[1]) + 1]
		l += "  povrchovy odtok louka %.3f (od tiku %d) pisek %.3f (od tiku %d)" % _cmp2()
		var so := [0.0, 0.0]
		for k in 2:
			for x in range(sc.compare_x[k][0], sc.compare_x[k][1] + 1):
				so[k] += sim.out_by_x[x] - sim.out_surf_by_x[x]
		l += "  odtok zemi louka %.3f pisek %.3f" % so
	stats_lines.append(l)
	print(l)

# ------------------------------------------------------------------ měření
func _bench() -> void:
	var lines := PackedStringArray()
	lines.append("Bench studie vody – %s, GDScript, Godot %s, 1 vlákno" % [Time.get_datetime_string_from_system(), Engine.get_version_info().string])
	for row in Scen.LIST:
		var s0 := Scen.make(row[0], Par.P)
		sc = s0; sc["n"] = row[0]; sim = s0.sim
		var T := 200
		var t0 := Time.get_ticks_usec()
		for k in T:
			_step()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / T
		var cs: int = sim.checksum()
		# determinismus: druhý běh od nuly musí dát stejný kontrolní součet
		var s1 := Scen.make(row[0], Par.P)
		sc = s1; sc["n"] = row[0]; sim = s1.sim
		for k in T:
			_step()
		lines.append("scen %d %-18s %dx%dx%d  %.3f ms/tik  aktivni bunky %d  determinismus %s  max chyba bilance %s  in %.2f out %.2f odpar %.2f" % [
			row[0], row[1], sim.NX, sim.NY, sim.NZ, ms, sim.active_cells(), "OK" if cs == sim.checksum() else "LIŠÍ SE", String.num_scientific(sim.bal_err_max),
			sim.in_total + sim.initial, sim.out_total, sim.evap_total])
	# celý blok 16 × 16 × 64 (žula, vápenec, jíl, hlína/písek, louka kolem vrstvy 31), déšť
	var Sim = load("res://scripts/water_sim.gd")
	var b = Sim.new(16, 16, 64, Par.P)
	var noise := FastNoiseLite.new()
	noise.seed = Par.i("seed")
	noise.frequency = 0.08
	for y in 16:
		for x in 16:
			var top := 30 + int(round(noise.get_noise_2d(x, y) * 3.0))
			for z in top + 1:
				var m := M.GRANITE
				if z > 12: m = M.LIMESTONE
				if z > 22: m = M.CLAY
				if z > 25: m = M.SAND if (x + y) % 7 < 3 else M.DIRT
				if z == top: m = M.GRASS
				b.set_mat(x, y, z, m)
	b.open_sides = 15
	b.rain = 0.01
	sim = b
	sc = {"digs": [], "n": 0}
	for pass_ in 2:
		var T := 50
		var t0 := Time.get_ticks_usec()
		for k in T:
			sim.step()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / T
		lines.append("blok 16x16x64 (%d bunek), dest, tiky %d–%d: %.2f ms/tik, aktivni bunky %d" % [16 * 16 * 64, pass_ * T, (pass_ + 1) * T, ms, sim.active_cells()])
	var f := FileAccess.open("res://shots/bench.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	for l in lines:
		print(l)
