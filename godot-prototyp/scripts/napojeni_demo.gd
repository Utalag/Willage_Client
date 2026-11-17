extends Node
## Ukázka a měření napojení povrchu louka / písek / voda v hlavním prototypu (přidá ji main.gd):
##   -- --napojeni-shots [--tag=X] [--only=a,b]  screenshoty shots/34_napojeni_*<_tag>.png
##   -- --napojeni-bench [--tag=X]                měření → shots/34_napojeni_bench<_tag>.txt
## Skript sahá jen na main/island (ne na povrch přímo), takže běží i ve starší verzi prototypu (srovnání před/po).
## Rozložení: startovní ostrov + písčina 4504 o vrstvu níž (pláž), louka 1201 o vrstvu níž (tůňky)
## a louka 5000 o 2 vrstvy níž (jezírko s travnatým břehem). Hladina = water_lz 30 (sloupce pod vrstvou 30 jsou pod vodou).

const BlockGen = preload("res://scripts/block_gen.gd")
const STEP := 1.0 / 30.0
var m
var tag := ""
var only := []
var out := []
const EXTRA := [[Vector2i(2, 1), "piscina", 4504, -1], [Vector2i(1, 2), "louka", 1201, -1], [Vector2i(2, 2), "louka", 5000, -2]]

func _ready() -> void:
	m = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	m.set_process(false)
	if "--napojeni-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

func _place(s: Vector2i, kind: String, seed: int, shift: int) -> float:
	var t0 := Time.get_ticks_usec()
	var b = m._make_block(kind, seed, "napojení")
	b.slot = s
	b.shift = shift
	BlockGen.build(b, m.island.neighbor_hms(s))
	m.island.place(b)
	return (Time.get_ticks_usec() - t0) / 1000.0

func _layout() -> Array:
	var ts := []
	for e in EXTRA:
		ts.append(_place(e[0], e[1], e[2], e[3]))
	return ts

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.center = c; m.cam.size = size; m.yaw = yaw; m.pitch = pitch
	m._place_camera()

func _tick(n := 10) -> void:
	var G = load("res://scripts/grass.gd")
	for i in n:
		G.tick(STEP)

func _name(base: String) -> String:
	return "34_napojeni_%s%s.png" % [base, ("_" + tag) if tag != "" else ""]

func _want(k: String) -> bool:
	return only.is_empty() or k in only

func _snap(name: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://shots/")
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo shots/", name)

## výška sloupce (globálně) a horní materiál
func _col(g: Vector2i) -> Array:
	var s := Vector2i(floori(g.x / 16.0), floori(g.y / 16.0))
	if not m.island.blocks.has(s):
		return [-1, -1]
	var b = m.island.blocks[s]
	var lx := g.x - s.x * 16; var ly := g.y - s.y * 16
	var h: int = b.hm[lx * 16 + ly]
	return [h, b.cells[(lx * 16 + ly) * 64 + h - 1]]

## místo v bloku s, kde v okolí r sloupců jsou zároveň: pod vodou (h < 30), písek a tráva nad vodou (want_sand)
func _find(s: Vector2i, want_sand: bool) -> Vector3:
	var best := Vector3(s.x * 16 + 8, 15, s.y * 16 + 8)
	var bs := -1.0
	for lx in range(2, 14):
		for ly in range(2, 14):
			var w := 0; var sa := 0; var gr := 0
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var c := _col(Vector2i(s.x * 16 + lx + dx, s.y * 16 + ly + dz))
					if c[0] < 0: continue
					if c[0] < 30: w += 1
					elif c[1] == 3: sa += 1
					elif c[1] == 1: gr += 1
			var sc := float(mini(w, 8) + mini(gr, 8)) + (float(mini(sa, 8)) if want_sand else -2.0 * sa)
			if w == 0 or gr == 0 or (want_sand and sa == 0):
				continue
			if sc > bs:
				bs = sc
				best = Vector3(s.x * 16 + lx + 0.5, 15, s.y * 16 + ly + 0.5)
	return best

func _shots() -> void:
	m.ui.visible = false
	_layout()
	_tick(20)
	if _want("ostrov"):
		_cam(Vector3(20, 15, 20), 70.0)
		await _snap(_name("ostrov"))
	if _want("plaz"):
		var c := _find(Vector2i(2, 1), true)
		print("pláž: ", c)
		_cam(c, 11.0)
		await _snap(_name("plaz_detail"))
	if _want("louka_voda"):
		var c := _find(Vector2i(2, 2), false)
		print("louka u vody: ", c)
		_cam(c, 11.0)
		await _snap(_name("louka_u_vody_detail"))
	if _want("sev"):
		# křížení hranic bloků (1,1) | (2,1) / (1,2) | (2,2) – x = 32, z = 32
		_cam(Vector3(32, 15, 32), 14.0)
		await _snap(_name("sev_bloku"))
	if _want("louka"):
		_cam(Vector3(24.5, 15.5, 22.5), 9.0)
		await _snap(_name("louka_procedural_detail"))
	if _want("kopec"):
		_cam(Vector3(8, 16, 24), 22.0)
		await _snap(_name("kopec_utesy"))
	if _want("panel"):
		_cam(Vector3(30, 15, 28), 30.0)
		_tick(10)
		await _snap("34_ladici_okno%s.png" % (("_" + tag) if tag != "" else ""))
	if "paramtest" in only:   # jen na vyžádání (--only=paramtest)
		await _paramtest()
	m.get_tree().quit()

## test živého ladění: změna uniformu, změna s přestavbou (zpožděná), předvolba přes ladicí okno (je-li načtené)
func _paramtest() -> void:
	var P = load("res://scripts/surface/surface_params.gd").inst()
	var GP = load("res://scripts/grass_params.gd").inst()
	_cam(Vector3(36, 15, 30), 26.0)
	P.set_param("water_lz", 31)
	GP.set_param("tufts_short", 10)
	await m.get_tree().create_timer(0.8).timeout
	await _snap("34_napojeni_test_hladina31.png")
	var dev: Node = null
	for c in m.get_children():
		if c.get_script() and "dev_runtime" in c.get_script().resource_path:
			dev = c
	if dev:
		dev.preset_name.text = "test_hladina31"
		dev.tabs.current_tab = 0
		dev._save()
		P.reset_defaults()
		print("po resetu water_lz = ", P.water_lz)
		dev._refresh_presets()
		for i in dev.preset_list.item_count:
			if dev.preset_list.get_item_text(i) == "test_hladina31":
				dev.preset_list.select(i)
		dev._load()
		print("po načtení předvolby water_lz = ", P.water_lz)
	P.reset_defaults()
	GP.reset_defaults()
	await m.get_tree().create_timer(0.1).timeout
	print("reset: water_lz = ", P.water_lz, ", tufts_short = ", GP.tufts_short)

# ------------------------------------------------------------------ měření
func _measure(label: String, frames := 40) -> void:
	for i in 10:
		_tick(1)
		await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	var prims := 0
	for i in frames:
		_tick(1)
		await RenderingServer.frame_post_draw
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	out.append("%s %s: %.1f ms/snímek, %d trojúhelníků/snímek, %d bloků" % [tag, label, ms, prims / frames, m.island.blocks.size()])
	print(out[-1])

func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	m.ui.visible = false
	var ts := _layout()
	out.append("%s vložení bloku (gen + kostky + povrch sousedů + vegetace): %s ms" % [tag, ", ".join(ts.map(func(t): return "%.0f" % t))])
	print(out[-1])
	_cam(Vector3(20, 15, 20), 70.0)
	await _measure("7 bloků celek")
	_cam(_find(Vector2i(2, 1), true), 11.0)
	await _measure("detail pláže")
	# plný ostrov
	var kinds := ["louka", "kopec", "louka", "hora", "louka", "piscina"]
	var i := 0
	var t0 := Time.get_ticks_usec()
	for s in m.island.slots:
		if m.island.blocks.has(s):
			continue
		_place(s, kinds[i % kinds.size()], 5000 + i * 37, 0)
		i += 1
	out.append("%s doplnění %d bloků: %.0f ms (%.0f ms/blok)" % [tag, i, (Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 1000.0 / i])
	print(out[-1])
	_cam(Vector3(16, 15, 16), 118.0)
	await _measure("plný ostrov celek")
	_cam(_find(Vector2i(2, 1), true), 11.0)
	await _measure("plný ostrov detail pláže")
	# kopání uprostřed bloku a u hrany (vykopat + položit zpět)
	var dig := []
	for g in [Vector2i(24, 24), Vector2i(31, 24)]:
		var t1 := Time.get_ticks_usec()
		m._dig(g)
		m._dig(g, true)
		dig.append((Time.get_ticks_usec() - t1) / 2000.0)
	out.append("%s kopání (průměr kop + položení): uprostřed bloku %.0f ms, u hrany %.0f ms" % [tag, dig[0], dig[1]])
	print(out[-1])
	# přestavba kostek jednoho bloku a povrchu
	var t2 := Time.get_ticks_usec()
	for s in m.island.blocks:
		m.island._remesh(s)
	out.append("%s kostková síť bloku: %.1f ms průměr" % [tag, (Time.get_ticks_usec() - t2) / 1000.0 / m.island.blocks.size()])
	print(out[-1])
	if "surface" in m.island and m.island.surface:
		var sf = m.island.surface
		sf.last_ms = {"fields": 0.0, "mesh": 0.0, "n": 0}
		for s in m.island.blocks:
			sf.build_fields(s)
			sf.build_meshes(s)
		out.append("%s povrch bloku: pole %.1f ms + duální síť a voda %.1f ms průměr (%d bloků)" % [tag, sf.last_ms.fields / sf.last_ms.n, (sf.last_ms.mesh) / sf.last_ms.n, sf.last_ms.n])
		print(out[-1])
	out.append("%s renderer: %s" % [tag, RenderingServer.get_video_adapter_name()])
	var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/34_napojeni_bench%s.txt" % (("_" + tag) if tag != "" else "")), FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	m.get_tree().quit()
