extends Node
## Ukázka a měření trávy C v hlavním prototypu (přidá ji main.gd):
##   -- --grass-shots  screenshoty shots/28_trava_C_*.png (celek, detail, průchod postavičky)
##   -- --grass-bench  měření snímku a počtu instancí: startovní ostrov a plný ostrov (všechny sloty) → shots/28_trava_C_bench.txt
## Skript nesahá na trávu přímo (jen přes strom uzlů), takže jde pustit i ve starší verzi prototypu (srovnání před/po).

const Roads = preload("res://scripts/roads.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const STEP := 1.0 / 30.0
var m           # main.gd
var Grass = null
var walker: Node3D
var out := []
var tag := ""

func _ready() -> void:
	m = get_parent()
	if FileAccess.file_exists("res://scripts/grass.gd"):
		Grass = load("res://scripts/grass.gd")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	m.set_process(false)   # žádné posouvání kamery klávesami, simulaci trávy řídíme sami
	if "--grass-map" in OS.get_cmdline_user_args():
		_map(); m.get_tree().quit(); return
	if "--grass-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

## ladění: mapa sloupců startovních bloků (T vysoká, s nízká, # strom/keř, H zabráno, . jiný povrch)
func _map() -> void:
	for slot in m.island.blocks:
		var b = m.island.blocks[slot]
		var tall = Grass.tall_map(b)
		var occ: Callable = m.island.occ_fn(b)
		var trees := {}
		for v in b.veg:
			if v.s in [4, 5, 3, 6]: trees[Vector2i(v.lx, v.ly)] = true
		print("blok ", slot, " ", b.kind, " (řádek = ly, sloupec = lx)")
		for ly in 16:
			var row := ""
			for lx in 16:
				var h: int = b.hm[lx * 16 + ly]
				var g: bool = b.cells[(lx * 16 + ly) * 64 + h - 1] == 1
				row += "H" if occ.call(lx, ly) else ("#" if trees.has(Vector2i(lx, ly)) else ((("T" if tall[lx * 16 + ly] else "s") if g else ".")))
			print(row, "   ", ly)

func _tick(dt: float) -> void:
	if Grass:
		Grass.tick(dt)

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.center = c; m.cam.size = size; m.yaw = yaw; m.pitch = pitch
	m._place_camera()

func _gy(p: Vector2) -> float:
	return Roads.height(m.island, Vector2i(floori(p.x), floori(p.y))) * 0.5

# ------------------------------------------------------------------ postavička
func _make_walker() -> void:
	const Toon = preload("res://scripts/toon.gd")
	walker = Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.2; cm.height = 0.7
	body.mesh = cm
	body.position.y = 0.35
	body.material_override = Toon.object_mat(Color(0.96, 0.62, 0.70).srgb_to_linear(), 0.02)
	walker.add_child(body)
	for s in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035; sm.height = 0.07
		eye.mesh = sm
		eye.position = Vector3(s * 0.075, 0.48, -0.184)
		eye.material_override = Toon.object_mat(Color(0.16, 0.13, 0.2), 0.0)
		walker.add_child(eye)
	m.add_child(walker)

## trasa (svět XZ): přímka z path_a do path_b za walk_dur s, pak postavička stojí (startovní louka (1, 1))
var path_a := Vector2(23.0, 27.0)
var path_b := Vector2(28.5, 27.0)
var walk_dur := 5.0
func _path(t: float) -> Vector2:
	return path_a.lerp(path_b, clampf(t / walk_dur, 0.0, 1.0))

var walk_t := 0.0
func _walk(dt: float) -> void:
	walk_t += dt
	var p := _path(walk_t)
	var mv := _path(walk_t + 0.05) - p
	var md := mv.normalized() if mv.length() > 1e-4 else Vector2.ZERO
	walker.position = Vector3(p.x, _gy(p) + (absf(sin(walk_t * 9.0)) * 0.06 if md != Vector2.ZERO else 0.0), p.y)
	if md != Vector2.ZERO:
		walker.rotation.y = atan2(-md.x, -md.y)
	if Grass:
		Grass.touch("demo", p, md)
	_tick(dt)

func _start_walk(a: Vector2, b: Vector2, dur: float) -> void:
	path_a = a; path_b = b; walk_dur = dur; walk_t = 0.0

func _sim(sec: float) -> void:
	for i in int(round(sec / STEP)):
		_walk(STEP)

func _snap(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://shots/")
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo shots/", name)

func _shots() -> void:
	m.ui.visible = false
	_make_walker()
	_walk(0.0)
	_cam(Vector3(16, 15, 16), 66.0)
	for i in 10: _tick(STEP)
	await _snap("28_trava_C_prehled.png")
	var c := Vector2(25.5, 25.5)
	walker.visible = false
	_cam(Vector3(c.x, _gy(c), c.y), 9.0)
	await _snap("28_trava_C_detail.png")
	walker.visible = true
	# průchod vysokou trávou: postavička jde 5,5 buňky za 5 s
	_sim(3.4)
	var w := walker.position
	_cam(w + Vector3(-0.8, 0, 0), 5.0)
	await _snap("28_trava_C_pruchod.png")
	_sim(2.0)
	_cam(w + Vector3(0.2, 0, 0), 5.0)
	await _snap("28_trava_C_pruchod_po_1_5s.png")
	_sim(2.5)
	await _snap("28_trava_C_pruchod_obnova.png")
	# nízká tráva
	_start_walk(Vector2(17.5, 19.5), Vector2(23.0, 19.5), 5.0)
	_sim(3.4)
	w = walker.position
	_cam(w + Vector3(-0.8, 0, 0), 5.0)
	await _snap("28_trava_C_pruchod_nizka.png")
	m.get_tree().quit()

# ------------------------------------------------------------------ měření
func _count() -> Array:
	var inst := 0
	var vis := 0
	var nodes := 0
	for v in m.island.vegs.values():
		for n in v.get_children():
			if n is MultiMeshInstance3D and n.multimesh:
				inst += n.multimesh.instance_count
				vis += n.multimesh.instance_count if n.multimesh.visible_instance_count < 0 else n.multimesh.visible_instance_count
				nodes += 1
	return [inst, nodes, vis]

func _measure(label: String, frames := 60) -> void:
	for i in 15:
		_walk(STEP)
		await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	var prims := 0
	for i in frames:
		_walk(STEP)
		await RenderingServer.frame_post_draw
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	var c := _count()
	var line := "%s %s: %.1f ms/snímek, %d trojúhelníků/snímek, %d instancí vegetace (kreslených %d, %d MultiMesh), %d bloků" % [tag, label, ms, prims / frames, c[0], c[2], c[1], m.island.blocks.size()]
	print(line)
	out.append(line)

func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	m.ui.visible = false
	_make_walker()
	_cam(Vector3(16, 15, 16), 66.0)
	await _measure("start (4 bloky) celek")
	_cam(Vector3(25, 16, 25), 9.0)
	await _measure("start detail louky")
	# plný ostrov: všechny sloty doplnit bloky (stejné seedy v obou verzích)
	var kinds := ["louka", "kopec", "louka", "hora", "louka", "piscina"]
	var i := 0
	var t0 := Time.get_ticks_usec()
	for s in m.island.slots:
		if m.island.blocks.has(s):
			continue
		var b = m._make_block(kinds[i % kinds.size()], 5000 + i * 37, "plný ostrov")
		b.slot = s
		BlockGen.build(b, m.island.neighbor_hms(s))
		m.island.place(b)
		i += 1
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	out.append("%s doplnění %d bloků (generování + mesh + vegetace): %.0f ms" % [tag, i, build_ms])
	print(out[-1])
	_cam(Vector3(16, 15, 16), 118.0)
	await _measure("plný ostrov celek")
	_cam(Vector3(25, 16, 25), 9.0)
	await _measure("plný ostrov detail louky")
	# čas stavby vegetace jednoho bloku (průměr přes ostrov)
	if Grass or true:
		var VR = load("res://scripts/veg_render.gd")
		var t1 := Time.get_ticks_usec()
		var n := 0
		for s in m.island.blocks:
			var b = m.island.blocks[s]
			var vn: Node3D = VR.build(m.island.veg_filtered(b), b, m.island.occ_fn(b)) if m.island.has_method("occ_fn") else VR.build(m.island.veg_filtered(b))
			vn.free()
			n += 1
		out.append("%s stavba vegetace bloku: %.1f ms průměr (%d bloků)" % [tag, (Time.get_ticks_usec() - t1) / 1000.0 / n, n])
		print(out[-1])
	out.append("%s renderer: %s" % [tag, RenderingServer.get_video_adapter_name()])
	var fn := ProjectSettings.globalize_path("res://shots/28_trava_C_bench%s.txt" % ("_" + tag if tag != "" else ""))
	var f := FileAccess.open(fn, FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	m.get_tree().quit()
