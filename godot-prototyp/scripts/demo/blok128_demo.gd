extends Node
## E96: blok 128 m. `-- --blok128-shots [--surface.p96_blok128=true] [--shot-dir=cesta] [--out=cesta.json]`
## Snímky: herní kamera, celý blok shora a izometricky, detail s postavou 1,75 m a domem 4 × 4 × 3 m, detail vody / vodopádu.
## V každém záběru změří čas snímku, trojúhelníky, draw calls a objekty (Performance), na konci paměť a časy generování.
## Funguje i bez příznaku (ostrov START) pro srovnání.
const Block = preload("res://scripts/block.gd")
const J = preload("res://scripts/jednotky.gd")
const B96 = preload("res://scripts/teren/blok96.gd")
const BS := J.BS

var m
var dir := ""
var res := {"zabery": {}}
var lab: Label

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _ready() -> void:
	m = get_parent()
	dir = _arg("shot-dir", ProjectSettings.globalize_path("res://shots/e96/"))
	DirAccess.make_dir_recursive_absolute(dir)
	m.set_game_process(false)
	_shots.call_deferred()

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.rig.center = c; m.cam.size = size; m.rig.yaw = yaw; m.rig.pitch = pitch
	m.rig.place()

func _rss() -> float:
	var o := []
	OS.execute("sh", ["-c", "grep VmRSS /proc/%d/status" % OS.get_process_id()], o)
	return float(String(o[0]).split(":")[1].strip_edges().split(" ")[0]) / 1024.0 if o.size() > 0 and ":" in String(o[0]) else 0.0

## snímek + měření záběru (30 snímků: průměr času, max trojúhelníků / draw calls / objektů)
func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var t := Time.get_ticks_usec(); var prims := 0.0; var draws := 0.0; var objs := 0.0
	for i in 30:
		await RenderingServer.frame_post_draw
		prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs = maxf(objs, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	res.zabery[name] = {"snimek_ms": snappedf((Time.get_ticks_usec() - t) / 30000.0, 0.1), "trojuhelniky": int(prims), "draw_calls": int(draws), "objekty": int(objs), "zaber_m": m.cam.size}
	m.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("uloženo ", name, " ", res.zabery[name])

func _label() -> void:
	lab = Label.new()
	lab.position = Vector2(16, 12)
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
	lab.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	lab.add_theme_constant_override("outline_size", 8)
	var cl := CanvasLayer.new(); cl.layer = 10; cl.add_child(lab); add_child(cl)

func _top(g: Vector2i) -> Vector3:
	return m.island.to_global(Vector3(g.x + 0.5, m.island.col_h(g) * Block.CELL_H, g.y + 0.5))

func _mesh(mesh: Mesh, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mi.material_override = mat
	mi.position = pos
	m.add_child(mi)

func _shots() -> void:
	if m.ui: m.ui.visible = false
	_label()
	var on := B96.on()
	var tag := "blok128" if on else "start"
	var n := B96.N if on else 2
	var w_m: float = n * BS * m.island.scale.x
	# postava a dům: u bloku 128 m z místa startu (Main už postavu a domek postavil), u START jako E94
	var gf: Vector2i = m.island.spawn96.postava if on else Vector2i(24, 24)
	var gh: Vector2i = m.island.spawn96.dum if on else Vector2i(30, 18)
	var cap := CapsuleMesh.new(); cap.height = J.hj_m(J.POSTAVA_HJ); cap.radius = 0.25
	if not on: _mesh(cap, _top(gf) + Vector3(0, cap.height / 2.0, 0), Color(0.85, 0.2, 0.2))
	var box := BoxMesh.new(); box.size = Vector3(4.0, 3.0, 4.0)
	var gb := gh + Vector2i(10, 0)   # modelový dům 4 × 4 × 3 m vedle domku hry
	_mesh(box, _top(gb) + Vector3(0, 1.5, 0), Color(0.95, 0.9, 0.75))
	var mid: Vector3 = m.island.to_global(Vector3(n * BS / 2.0, 22 * Block.CELL_H * 2.0, n * BS / 2.0))
	lab.text = "E96 %s: herní kamera (střed %s, záběr %.0f m)" % [tag, str(m.rig.center.snapped(Vector3(0.1, 0.1, 0.1))), m.cam.size]
	await _snap("96_%s_hra_kamera" % tag)
	lab.text = "E96 %s: celý ostrov %.0f × %.0f m shora" % [tag, w_m, w_m]
	_cam(mid, w_m * 1.15, 0.0, -89.9)
	await _snap("96_%s_cely_shora" % tag)
	lab.text = "E96 %s: celý ostrov %.0f × %.0f m izometricky" % [tag, w_m, w_m]
	_cam(mid, w_m * 1.5)
	await _snap("96_%s_cely_iso" % tag)
	lab.text = "E96 %s: detail 16 m, postava 1,75 m (červená), dům 4 × 4 × 3 m (béžový), domek hry" % tag
	_cam(_top(gf) + Vector3(0, 1.0, 0), 16.0)
	await _snap("96_%s_detail" % tag)
	# voda: největší vodopád uvnitř ostrova, jinak přes okraj, jinak sloupec s největším průtokem
	var v = m.island.voda
	var gw = null; var info := ""
	if v != null:
		var best := -1.0
		for f in v.falls:
			var q := float(f.q) * (2.0 if not f.edge else 1.0)
			if q > best: best = q; gw = f.top; info = "vodopád %.1f l/s, výška %.1f m%s" % [float(f.q), float(f.drop_u) * 0.5, " (přes okraj)" if f.edge else ""]
	if gw != null:
		var a: Array = v.slot_of(int(gw))
		var g := Vector2i(a[0].x * BS + a[1], a[0].y * BS + a[2])
		lab.text = "E96 %s: detail vody 24 m, %s" % [tag, info]
		_cam(_top(g), 24.0)
		res.voda_detail = {"sloupec": [g.x, g.y], "info": info}
		await _snap("96_%s_voda" % tag)
	res.cas_ms = m.island.ms96
	res.start = {"postava": [gf.x, gf.y], "dum": [gh.x, gh.y], "vyska_m": m.island.col_h(gf) * Block.CELL_H}
	res.pamet = {"rss_mb": _rss(), "godot_staticka_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"buffery_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1),
		"uzlu": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	res.bloku = m.island.blocks.size()
	res.voda = m.island.voda.summary() if m.island.voda != null else {}
	res.voda_ms = m.island.voda.ms if m.island.voda != null else {}
	# kopání ve hře: 4 výkopy u postavy (Digging + lokální přepočet vody + přestavba povrchu)
	var dig := []
	if m.digging.has_method("dig"):
		for k in 4:
			var g := gf + Vector2i(3 + k, 2)
			var t := Time.get_ticks_usec()
			m.digging.dig(g, false)
			m.island.water_finish()
			dig.append(snappedf((Time.get_ticks_usec() - t) / 1000.0, 0.1))
	res.vykop_hra_ms = dig
	print("E96 kopání ve hře (ms): ", dig)
	lab.text = "E96 %s: detail po 4 výkopech u postavy" % tag
	_cam(_top(gf) + Vector3(0, 1.0, 0), 16.0)
	await _snap("96_%s_detail_vykop" % tag)
	var outp := _arg("out", "")
	if outp != "": FileAccess.open(outp, FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	print("E96 výsledek: ", JSON.stringify(res))
	get_tree().quit()
