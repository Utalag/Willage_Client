extends Node
## Skrytí podzemí na bocích a řezech bloku (přidá ji main.gd):
##   -- --skryti-shots [--tag=X]   screenshoty shots/40_skryti_*<_tag>.png
##   -- --skryti-bench [--tag=X]   měření → shots/40_skryti_bench<_tag>.txt

const BlockGen = preload("res://scripts/block_gen.gd")
const Mat = preload("res://scripts/mat.gd")
const Mesher = preload("res://scripts/mesher.gd")
const Discovery = preload("res://scripts/discovery.gd")
const Params = preload("res://scripts/surface/surface_params.gd")
const BS := 16

var m
var tag := ""
var p

func _ready() -> void:
	m = get_parent()
	p = Params.inst()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	m.set_process(false)
	if "--skryti-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

func _sfx(base: String, ext: String) -> String:
	return "40_skryti_%s%s.%s" % [base, ("_" + tag) if tag != "" else "", ext]

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.center = c
	m.cam.size = size
	m.yaw = yaw
	m.pitch = pitch
	m._place_camera()

func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://shots/")
	DirAccess.make_dir_recursive_absolute(d)
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo shots/", name)

func _height(g: Vector2i) -> int:
	var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not m.island.blocks.has(s):
		return 0
	var b = m.island.blocks[s]
	var lx := g.x - s.x * BS
	var ly := g.y - s.y * BS
	return b.hm[lx * BS + ly]

func _face_h(sx: int, sz: int, edge: String) -> int:
	var hmax := 0
	for t in BS:
		var g: Vector2i
		match edge:
			"N": g = Vector2i(sx * BS + t, sz * BS)
			"S": g = Vector2i(sx * BS + t, sz * BS + BS - 1)
			"E": g = Vector2i(sx * BS + BS - 1, sz * BS + t)
			_: g = Vector2i(sx * BS, sz * BS + t)
		hmax = maxi(hmax, _height(g))
	return hmax

func _place(s: Vector2i, kind: String, seed: int) -> float:
	var t0 := Time.get_ticks_usec()
	var b = m._make_block(kind, seed, "skrytí")
	b.slot = s
	BlockGen.build(b, m.island.neighbor_hms(s))
	m.island.place(b)
	return (Time.get_ticks_usec() - t0) / 1000.0

## jáma u severní hrany hory (1, 0): zvenku je v bok vykousnutý výřez, zadní stěna jámy ukáže materiál
func _dig_pit() -> Vector2i:
	var pit := Vector2i(24, 2)
	var msg := ""
	for k in 10:
		for dx in range(-2, 3):
			for dz in range(0, 5):
				var g := Vector2i(pit.x + dx, dz)
				if _height(g) > 4:
					msg = m._dig(g)
	print("jáma u ", pit, ": ", msg)
	return pit

func _shots() -> void:
	if m.ui:
		m.ui.visible = false
	m.island.set_textured(true)
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)

	var hn := _face_h(1, 0, "N")
	var mid_y := hn * 0.5 * 0.5
	print("severní bok hory: max výška ", hn, " buněk")
	_cam(Vector3(24, mid_y, 0.2), 24.0, 180.0, -16.0)
	await _snap(_sfx("bok", "png"))

	var sl := mini(maxi(hn - 14, 22), hn - 2)
	m.island.set_slice(sl)
	_cam(Vector3(24, sl * 0.5, 6.0), 28.0, 200.0, -42.0)
	await _snap(_sfx("rez", "png"))
	m.island.set_slice(-1)

	var pit := _dig_pit()
	_cam(Vector3(24, mid_y - 1.0, 0.2), 22.0, 180.0, -20.0)
	await _snap(_sfx("jama", "png"))
	_cam(Vector3(pit.x + 0.5, _height(pit) * 0.5 + 1.5, pit.y + 0.5), 14.0, 200.0, -52.0)
	await _snap(_sfx("jama_nahled", "png"))

	p.set_param("xray", true)
	_cam(Vector3(24, mid_y, 0.2), 24.0, 180.0, -16.0)
	await _snap(_sfx("xray", "png"))
	m.island.set_slice(sl)
	_cam(Vector3(24, sl * 0.5, 6.0), 28.0, 200.0, -42.0)
	await _snap(_sfx("xray_rez", "png"))
	m.island.set_slice(-1)
	get_tree().quit()

func _micro(hide: bool) -> Dictionary:
	var s := Vector2i(1, 0)
	var b = m.island.blocks[s]
	var nbs = m.island.neighbor_cells(s)
	var hms = m.island.neighbor_hms(s)
	var t0 := Time.get_ticks_usec()
	var disc := PackedByteArray()
	var n := 8
	for i in n:
		disc = Discovery.compute(b.cells, nbs, hms, b.hm)
	var disc_ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var nmat: int = Mat.DIRT if p.undiscovered_look == 0 else Mat.GRANITE
	var use_disc := disc if hide else PackedByteArray()
	t0 = Time.get_ticks_usec()
	var mesh_ms := 0.0
	for i in n:
		var t1 := Time.get_ticks_usec()
		Mesher.build(b.cells, nbs, -1, Color(1, 1, 1), PackedByteArray(), use_disc, nmat, p.col_undiscovered, p.undiscovered_darken)
		mesh_ms += (Time.get_ticks_usec() - t1) / 1000.0
	mesh_ms /= n
	return {"disc": disc_ms, "mesh": mesh_ms, "disc_n": disc.size()}

func _dig_pair(g: Vector2i) -> float:
	var t0 := Time.get_ticks_usec()
	var a = m._dig(g)
	var b = m._dig(g, true)
	print("  kop+položení ", g, ": ", a, " / ", b)
	return (Time.get_ticks_usec() - t0) / 2000.0

func _bench() -> void:
	var out := []
	# mikro: stejný blok, jen síť a výpočet odkrytí (průměr 8 běhů)
	var off := _micro(false)
	var on := _micro(true)
	out.append("mikro (hora 202, 8 běhů): discovery %.2f ms; síť bez skrytí %.1f ms, se skrytím %.1f ms" % [on.disc, off.mesh, on.mesh])

	# vložení a kopání: stejně velké okolí (sloty (2,0) a (-1,0) se neovlivňují, oba mají 2 sousedy)
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", false)
	var t_place_off := _place(Vector2i(2, 0), "kopec", 5151)
	var dmid_off := _dig_pair(Vector2i(2 * BS + 8, 8))
	var dedge_off := _dig_pair(Vector2i(2 * BS, 8))
	out.append("skrytí vypnuto: vložení kopce 5151 na (2,0) %.0f ms (z toho síť %.1f ms), kopání střed %.0f ms, hrana %.0f ms" % [
		t_place_off, m.island.blocks[Vector2i(2, 0)].mesh_ms, dmid_off, dedge_off])

	p.set_param("hide_undiscovered", true)
	var t_place_on := _place(Vector2i(-1, 0), "kopec", 5151)
	var dmid_on := _dig_pair(Vector2i(-1 * BS + 8, 8))
	var dedge_on := _dig_pair(Vector2i(-1 * BS + BS - 1, 8))  # východní hrana k ostrovu
	out.append("skrytí zapnuto: vložení kopce 5151 na (-1,0) %.0f ms (z toho síť %.1f ms), kopání střed %.0f ms, hrana %.0f ms" % [
		t_place_on, m.island.blocks[Vector2i(-1, 0)].mesh_ms, dmid_on, dedge_on])

	for line in out:
		print(line)
	var path := ProjectSettings.globalize_path("res://shots/") + _sfx("bench", "txt")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print("uloženo shots/", _sfx("bench", "txt"))
	get_tree().quit()
