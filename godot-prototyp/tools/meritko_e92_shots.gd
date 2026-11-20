extends SceneTree
## E92: snímky testu měřítka (potřebuje obraz: xvfb-run … --rendering-driver opengl3).
##   ostrov START (main.tscn):  -- --p92_svah=1 --scena=ostrov --tag=vyp|s06 [--bp.p92_svah=true --bp.p92_max_sklon=0.6] --shots=dir
##   blok 128 m (funkce E90):   -- --p92_svah=1 --scena=blok128 --sklon=0|0.6 --tag=vyp|s06 --shots=dir
## Postava 1,75 m (kapsle r 0,25, červená) a dům 4 × 4 × 3 m (krémový, střecha) stojí v metrech (1 jednotka = 1 m).
## Ostrov: „dnes“ = buňka 1 × 1 × 0,5 jednotky (vodorovně natažená 2×), „metry“ = ostrov zmenšený vodorovně na 0,5 (E89 p89_meritko).
const S92 = preload("res://scripts/teren/svah92.gd")
const L90 = preload("res://scripts/teren/lod90.gd")
const BS := 16

var shots := ""
var tag := ""
var main
var lab: Label

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _initialize() -> void:
	if _arg("p92_svah", "0") != "1":
		print("E92: příznak p92_svah je vypnutý (výchozí) – nic se nestaví")
		quit(); return
	shots = _arg("shots", "/tmp/e92s"); tag = _arg("tag", "vyp")
	DirAccess.make_dir_recursive_absolute(shots)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var cl := CanvasLayer.new(); cl.layer = 10
	lab = Label.new(); lab.position = Vector2(16, 12)
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
	lab.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	lab.add_theme_constant_override("outline_size", 8)
	cl.add_child(lab)
	root.add_child.call_deferred(cl)
	if _arg("scena", "ostrov") == "ostrov":
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		_ostrov.call_deferred()
	else:
		_blok128.call_deferred()

func _snap(name: String) -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("snímek ", name)

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 1.0
	return m

## postava a dům (v metrech), nohy postavy v pf, dům střed podlahy v ph
func _figures(parent: Node, pf: Vector3, ph: Vector3) -> void:
	var cap := CapsuleMesh.new(); cap.height = 1.75; cap.radius = 0.25
	var mi := MeshInstance3D.new(); mi.mesh = cap; mi.material_override = _mat(Color(0.9, 0.15, 0.15))
	mi.position = pf + Vector3(0, 0.875, 0); parent.add_child(mi)
	var box := BoxMesh.new(); box.size = Vector3(4, 3, 4)
	var hb := MeshInstance3D.new(); hb.mesh = box; hb.material_override = _mat(Color(0.96, 0.9, 0.76))
	hb.position = ph + Vector3(0, 1.5, 0); parent.add_child(hb)
	var roof := PrismMesh.new(); roof.size = Vector3(4.4, 1.6, 4.4)
	var rf := MeshInstance3D.new(); rf.mesh = roof; rf.material_override = _mat(Color(0.8, 0.35, 0.3))
	rf.position = ph + Vector3(0, 3.8, 0); parent.add_child(rf)

func _cam(rig, cam: Camera3D, c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	rig.center = c; cam.size = size; rig.yaw = yaw; rig.pitch = pitch
	rig.place()

## ---------------------------------------------------------------- ostrov START
func _top(g: Vector2i) -> Vector3:
	var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	var b = main.island.blocks[s]
	var h: int = b.hm[(g.x - s.x * BS) * BS + (g.y - s.y * BS)]
	return main.island.to_global(Vector3(g.x + 0.5, h * 0.5, g.y + 0.5))

## nejnižší sloupec v obdélníku (aby postava stála volně, blízko kamery)
func _low(x0: int, x1: int, z0: int, z1: int) -> Vector2i:
	var best := Vector2i(x0, z0); var bh := 1e9
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var y := _top(Vector2i(x, z)).y
			if y < bh: bh = y; best = Vector2i(x, z)
	return best

func _ostrov() -> void:
	for i in 5: await process_frame
	main.set_game_process(false)
	if main.ui: main.ui.visible = false
	if main.dev_panel and main.dev_panel is CanvasItem: main.dev_panel.visible = false
	var holder := Node3D.new(); root.add_child(holder)
	var gf := Vector2i(19, 25); var gh := Vector2i(25, 26)
	var popis := "sklon ≤ 31° (p92_max_sklon 0,6)" if tag == "s06" else "výchozí terén"
	for metry in [false, true]:
		if metry and main.island.scale.x != 0.5:
			main.island.scale = Vector3(0.5, 1.0, 0.5)
		for c in holder.get_children(): c.queue_free()
		await process_frame
		_figures(holder, _top(_low(28, 31, 29, 31)), _top(gh))
		var mid: Vector3 = main.island.to_global(Vector3(16, 17, 16))
		var w: float = 32.0 * main.island.scale.x
		var jm := "metry" if metry else "dnes"
		lab.text = "E92 %s, %s: ostrov 2 × 2 bloky = %.0f × %.0f jednotek, buňka %.2f × 0,5 × %.2f; postava 1,75 m, dům 4 × 4 × 3 m" % [popis, "v metrech" if metry else "dnes (natažené 2×)", w, w, main.island.scale.x, main.island.scale.z]
		_cam(main.rig, main.cam, mid + Vector3(0, w * 0.15, 0), w * 2.1)
		await _snap("92_ostrov_%s_%s" % [jm, tag])
		for c in holder.get_children(): c.queue_free()
		await process_frame
		_figures(holder, _top(_low(18, 30, 0, 1)), _top(gh))
		lab.text = "E92 %s, %s: hora (blok (1, 0)) z boku, postava 1,75 m" % [popis, "v metrech" if metry else "dnes"]
		_cam(main.rig, main.cam, main.island.to_global(Vector3(22, 21, 14)), 16.0 if metry else 28.0, 150.0, -12.0)
		await _snap("92_hora_bok_%s_%s" % [jm, tag])
	quit()

## ---------------------------------------------------------------- blok 128 m
func _blok128() -> void:
	var sk := float(_arg("sklon", "0"))
	var bt := S92.best_tile()
	var th := S92.tile_heights(bt.f, bt.tile, sk)
	var N: int = th.N
	var h: PackedFloat64Array = th.h
	# sloupce 0,5 m: horní stěna + boky k nižším sousedům (výška zaokrouhlená na 0,25 m)
	var V := PackedVector3Array(); var Nn := PackedVector3Array(); var C := PackedColorArray()
	var q := func(v: float) -> float: return roundf(v * 4.0) / 4.0
	var M := N - 1
	var hc := PackedFloat64Array(); hc.resize(M * M)
	for i in M:
		for j in M:
			hc[i * M + j] = q.call((h[i * N + j] + h[(i + 1) * N + j] + h[i * N + j + 1] + h[(i + 1) * N + j + 1]) * 0.25)
	var ref := 15.5
	for i in M:
		for j in M:
			var y: float = hc[i * M + j]
			var gx := (hc[mini(i + 1, M - 1) * M + j] - hc[maxi(i - 1, 0) * M + j]) / 1.0
			var gy := (hc[i * M + mini(j + 1, M - 1)] - hc[i * M + maxi(j - 1, 0)]) / 1.0
			var sl := sqrt(gx * gx + gy * gy)
			var col := Color(0.45, 0.68, 0.3)
			if y > ref + 28.0: col = Color(0.95, 0.96, 0.98)
			elif sl > 0.9: col = Color(0.58, 0.55, 0.52)
			elif sl > 0.55: col = Color(0.55, 0.6, 0.36)
			var x0 := i * 0.5; var z0 := j * 0.5; var c := 0.5
			_quad(V, Nn, C, Vector3(x0, y, z0), Vector3(x0 + c, y, z0), Vector3(x0 + c, y, z0 + c), Vector3(x0, y, z0 + c), Vector3.UP, col)
			var side := Color(0.55, 0.42, 0.32)
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var ni: int = i + d[0]; var nj: int = j + d[1]
				var lo := y - 2.0
				if ni >= 0 and nj >= 0 and ni < M and nj < M: lo = hc[ni * M + nj]
				if lo >= y: continue
				var a: Vector3; var b: Vector3; var nrm := Vector3(d[0], 0, d[1])
				if d[0] == 1: a = Vector3(x0 + c, 0, z0 + c); b = Vector3(x0 + c, 0, z0)
				elif d[0] == -1: a = Vector3(x0, 0, z0); b = Vector3(x0, 0, z0 + c)
				elif d[1] == 1: a = Vector3(x0, 0, z0 + c); b = Vector3(x0 + c, 0, z0 + c)
				else: a = Vector3(x0 + c, 0, z0); b = Vector3(x0, 0, z0)
				_quad(V, Nn, C, Vector3(a.x, y, a.z), Vector3(b.x, y, b.z), Vector3(b.x, lo, b.z), Vector3(a.x, lo, a.z), nrm, side)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = Nn; arr[Mesh.ARRAY_COLOR] = C
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.mesh = am
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	var w3 := Node3D.new(); root.add_child(w3); w3.add_child(mi)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.75, 0.86, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.62, 0.68); e.ambient_light_energy = 0.6
	env.environment = e; w3.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); sun.light_energy = 1.1; w3.add_child(sun)
	# postava a dům: na úpatí nejvyšší hory (bod ve čtvrtině převýšení, nejblíž vrcholu) a dům 8 m vedle na rovnějším místě
	var lo := 1e9; var hi := -1e9; var pk := 0
	for k in M * M:
		lo = minf(lo, hc[k])
		if hc[k] > hi: hi = hc[k]; pk = k
	var thr := lo + 0.3 * (hi - lo)
	var bi := 0; var bd := 1e9
	for k in M * M:
		if absf(hc[k] - thr) < 0.5:
			var dd := Vector2(k / M - pk / M, k % M - pk % M).length()
			if dd < bd: bd = dd; bi = k
	var pf := Vector3((bi / M) * 0.5 + 0.25, hc[bi], (bi % M) * 0.5 + 0.25)
	var hi2 := mini(bi / M + 16, M - 1) * M + (bi % M)
	var ph := Vector3((hi2 / M) * 0.5 + 0.25, hc[hi2], (hi2 % M) * 0.5 + 0.25)
	_figures(w3, pf, ph)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.far = 2000.0
	w3.add_child(cam)
	var place := func(c: Vector3, size: float, yaw: float, pitch: float) -> void:
		var bs := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0), EULER_ORDER_YXZ)
		cam.transform = Transform3D(bs, c + bs.z * 400.0); cam.size = size
	cam.make_current()
	var popis := "sklon ≤ 31° (omezovač 0,6 na 1 m mřížce)" if sk > 0.0 else "funkce E90 beze změny"
	lab.text = "E92 blok 128 m (dlaždice %s funkce E90, převýšení %.0f m), %s; postava 1,75 m, dům 4 × 4 × 3 m (u úpatí)" % [str(bt.tile), hi - lo, popis]
	place.call(Vector3(64, (lo + hi) * 0.5, 64), 150.0, 45.0, -35.0)
	await _snap("92_blok128_cely_%s" % tag)
	lab.text = "E92 blok 128 m, %s: detail 30 m u úpatí hory, postava 1,75 m (červená), dům 4 × 4 × 3 m" % popis
	place.call(pf + Vector3(0, 2, 0), 30.0, 45.0, -35.0)
	await _snap("92_blok128_detail_%s" % tag)
	lab.text = "E92 blok 128 m, %s: profil z boku (pohled vodorovně), postava 1,75 m" % popis
	place.call(Vector3(64, (lo + hi) * 0.5, 64), 110.0, 90.0, -5.0)
	await _snap("92_blok128_bok_%s" % tag)
	quit()

func _quad(V: PackedVector3Array, Nn: PackedVector3Array, C: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		V.append(v); Nn.append(nrm); C.append(col)
