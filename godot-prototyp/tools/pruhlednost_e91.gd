extends SceneTree
## E91: průhlednost překážek v izometrii – měření a snímky (studie, výchozí hra beze změny).
## Spuštění (potřebuje obraz, ne --headless):
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --path . -s res://tools/pruhlednost_e91.gd \
##     -- --p91_pruhlednost=1 --out=/tmp/e91.json --shots=/tmp/e91s [--snimku=120]
## Bez --p91_pruhlednost=1 se nic nestaví (příznak je výchozí vypnutý).
## Scény: hlavní ostrov prototypu (main.tscn), postava = kapsle 1,8 × r 0,35 (purpurová, bez stínování, neořezává se).
##   kopec: postava na nejnižším místě, které terén zakrývá ze všech tří výšek kapsle
##   chodba: vodorovná chodba 2 × 4 buňky vyřezaná do hory (blok (1,0)) od okraje k vrcholu, postava na konci
## Metody: pred (nic), A válec (dither), B řez shaderem, AB (A + B), C řez sítí (island.set_slice), C2 skrytí bloků.
const PR = preload("res://scripts/game/pruhlednost91.gd")
const BS := 16

var main
var island
var hero: MeshInstance3D
var res := {}
var shots := ""
var frames := 120

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _initialize() -> void:
	if _arg("p91_pruhlednost", "0") != "1":
		print("E91: příznak p91_pruhlednost je vypnutý (výchozí) – nic se nestaví")
		quit()
		return
	shots = _arg("shots", "")
	frames = int(_arg("snimku", "60"))
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	if shots == "":
		return
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("snímek ", name)

## podíl pixelů postavy (purpurová) na obrazovce
func _hero_px() -> int:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.2 and c.b > 0.85:
				n += 1
	return n

func hm_at(x: float, z: float) -> float:
	var g := Vector2i(floori(x), floori(z))
	var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(s):
		return -1.0
	var b = island.blocks[s]
	return b.hm[(g.x - s.x * BS) * BS + (g.y - s.y * BS)] * 0.5

func _to_cam() -> Vector3:
	return main.cam.global_transform.basis.z.normalized()

func _cam_on(feet: Vector3, size := 26.0) -> void:
	main.rig.center = feet + Vector3(0, 0.9, 0)
	main.cam.size = size
	main.rig.place()

## postava za kopcem: nejnižší sloupec, který terén zakrývá ze všech tří výšek kapsle
func _find_hidden() -> Vector3:
	var d := _to_cam()
	var best := Vector3.ZERO
	var best_y := 1e9
	for s in island.blocks:
		for lx in range(1, BS - 1):
			for ly in range(1, BS - 1):
				var x: float = s.x * BS + lx + 0.5
				var z: float = s.y * BS + ly + 0.5
				var fy := hm_at(x, z)
				var ok := true
				for hh in [0.3, 0.9, 1.6]:
					var p0 := Vector3(x, fy + hh, z)
					var hit := false
					var t := 0.6
					while t < 60.0:
						var q := p0 + d * t
						var h := hm_at(q.x, q.z)
						if h > q.y:
							hit = true; break
						t += 0.25
					if not hit:
						ok = false; break
				if ok and fy < best_y:
					best_y = fy; best = Vector3(x, fy, z)
	return best

## vodorovná chodba v bloku hory (1,0): řádek vrcholu, od západního okraje k vrcholu, 2 buňky široká, 4 vysoká
func _dig_tunnel() -> Dictionary:
	var s := Vector2i(1, 0)
	var b = island.blocks[s]
	var pk := Vector2i.ZERO
	var ph := -1
	for lx in BS:
		for ly in range(1, BS - 2):
			if b.hm[lx * BS + ly] > ph:
				ph = b.hm[lx * BS + ly]; pk = Vector2i(lx, ly)
	var ly0 := pk.y
	var floor_z: int = b.hm[0 * BS + ly0]
	for ly in [ly0, ly0 + 1]:
		floor_z = mini(floor_z, b.hm[0 * BS + ly])
	floor_z = maxi(floor_z, 1)
	var t0 := Time.get_ticks_usec()
	var cut := 0
	for lx in range(0, pk.x + 1):
		for ly in [ly0, ly0 + 1]:
			var col: int = (lx * BS + ly) * 64
			for z in range(floor_z, mini(floor_z + 4, 64)):
				if b.cells[col + z] != 0:
					b.cells[col + z] = 0; cut += 1
			var h := 0
			for z in 64:
				if b.cells[col + z] != 0: h = z + 1
			b.hm[lx * BS + ly] = h
	b.recount()
	for n in island.area_of(s):
		island.refresh_discovered(n)
	island.refresh_blocks([s])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var end_x := s.x * BS + pk.x - 0.5 + 0.5
	var feet := Vector3(end_x - 0.5, floor_z * 0.5, s.y * BS + ly0 + 1.0)
	return {"feet": feet, "peak_cells": ph, "floor_cells": floor_z, "overburden_m_cells": ph - floor_z, "cut_cells": cut,
		"len_cells": pk.x + 1, "rebuild_ms": ms, "slot": s}

func _all_meshes() -> Array:
	return island.meshes.values()

## čas snímku: průměr a medián (zeď mezi snímky) + render CPU/GPU z RenderingServeru
func _bench(tag: String) -> Dictionary:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _frames(10)
	var dts := []
	var cpu := 0.0
	var gpu := 0.0
	var last := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	dts.sort()
	var avg := 0.0
	for v in dts: avg += v
	avg /= dts.size()
	var r := {"snimek_prumer_ms": snappedf(avg, 0.01), "snimek_median_ms": snappedf(dts[dts.size() / 2], 0.01),
		"snimek_p90_ms": snappedf(dts[int(dts.size() * 0.9)], 0.01),
		"render_cpu_ms": snappedf(cpu / frames, 0.001), "render_gpu_ms": snappedf(gpu / frames, 0.001)}
	print("  %s: %s" % [tag, r])
	return r

func _mode(mode: int, feet: Vector3, prm := {}) -> void:
	PR.set_params(mode, feet, _to_cam(), prm)

func _scene(name: String, feet: Vector3, size: float, under: bool) -> Dictionary:
	var out := {"nohy": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)], "v_podzemi": under}
	hero.position = feet + Vector3(0, 0.9, 0)
	_cam_on(feet, size)
	# reference: kolik pixelů má postava bez terénu
	island.visible = false
	var ref := await _hero_px()
	island.visible = true
	out["postava_px_bez_terenu"] = ref
	var methods := {}
	# snímky a viditelnost postavy
	for m in [["pred", 0], ["A_valec", 1], ["B_rez", 2], ["AB", 3]]:
		_mode(m[1], feet)
		await _snap("91_%s_%s" % [name, m[0]])
		var px := await _hero_px()
		methods[m[0]] = {"viditelnost_postavy": snappedf(px / float(maxi(ref, 1)), 0.001)}
	# čas snímku: 3 kola střídavě (pred, A, B, AB), medián mediánů
	var runs := {}
	for k in 3:
		for m in [["pred", 0], ["A_valec", 1], ["B_rez", 2], ["AB", 3]]:
			_mode(m[1], feet)
			var r := await _bench("%s %s kolo %d" % [name, m[0], k + 1])
			if not runs.has(m[0]): runs[m[0]] = []
			runs[m[0]].append(r)
	for key in runs:
		var med := []
		var cpu := []
		for r in runs[key]:
			med.append(r.snimek_median_ms); cpu.append(r.render_cpu_ms)
		med.sort(); cpu.sort()
		methods[key]["cas"] = {"snimek_median_ms": med[1], "render_cpu_ms": cpu[1], "kola_median_ms": med}
	var px: int
	_mode(0, feet)
	# C: řez sítí na CPU nad nohama + 3 buňky (1,5 m)
	var z := int(round(feet.y / 0.5)) + 3
	var t0 := Time.get_ticks_usec()
	island.set_slice(z)
	var c_on := (Time.get_ticks_usec() - t0) / 1000.0
	await _snap("91_%s_C_rez_site" % name)
	px = await _hero_px()
	var cb := await _bench(name + " C")
	t0 = Time.get_ticks_usec()
	island.set_slice(-1)
	var c_off := (Time.get_ticks_usec() - t0) / 1000.0
	methods["C_rez_site"] = {"viditelnost_postavy": snappedf(px / float(maxi(ref, 1)), 0.001), "cas": cb,
		"zapnuti_ms": snappedf(c_on, 0.1), "vypnuti_ms": snappedf(c_off, 0.1), "rez_bunka": z}
	# C2: skrýt celé bloky na paprsku
	var hide: Array = PR.blocks_on_ray(feet, 1.8, _to_cam(), island.blocks.keys(), BS, 40.0,
		Vector2i(floori(feet.x / BS), floori(feet.z / BS)))
	t0 = Time.get_ticks_usec()
	for s in hide:
		island.meshes[s].visible = false
		if island.surface: island.surface.set_block_visible(s, false) if island.surface.has_method("set_block_visible") else null
	var c2 := (Time.get_ticks_usec() - t0) / 1000.0
	await _snap("91_%s_C2_bloky" % name)
	px = await _hero_px()
	methods["C2_bloky"] = {"viditelnost_postavy": snappedf(px / float(maxi(ref, 1)), 0.001), "skryte_bloky": hide.map(func(v): return str(v)),
		"prepnuti_ms": snappedf(c2, 0.001)}
	for s in hide:
		island.meshes[s].visible = true
	out["metody"] = methods
	return out

func _run() -> void:
	await _frames(5)
	main.set_game_process(false)
	if main.ui: main.ui.visible = false
	if main.dev_panel and main.dev_panel is CanvasItem: main.dev_panel.visible = false
	island = main.island
	main.rig.yaw = 45.0; main.rig.pitch = -35.0
	main.rig.place()
	await _frames(5)
	res["okno"] = [1280, 800]
	res["renderer"] = RenderingServer.get_video_adapter_name()
	# postava
	hero = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35; cm.height = 1.8
	hero.mesh = cm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1, 0, 1)
	hero.material_override = hm
	hero.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hero)
	# základ bez příznaku (jen pro srovnání času snímku, shadery původní)
	_cam_on(Vector3(16, 8, 16), 40.0)
	await _snap("91_ostrov_vychozi")
	res["vychozi_cas"] = await _bench("výchozí ostrov")
	# zapnutí: kopie shaderů s vloženým kódem
	var t0 := Time.get_ticks_usec()
	var n := PR.enable(root, [hero], true)
	_mode(0, Vector3.ZERO)
	await _frames(1)
	var t_first := (Time.get_ticks_usec() - t0) / 1000.0
	var shs := {}
	for m in PR.mats:
		shs[m.shader] = true
	var added := PR.uniforms_code(true).split("\n").size() + 2
	res["zapnuti"] = {"materialu": n, "shaderu": shs.size(), "prvni_snimek_s_prekladem_ms": snappedf(t_first, 0.1),
		"radku_navic_na_shader": added}
	# cena nastavení uniformů (každý snímek při pohybu postavy)
	t0 = Time.get_ticks_usec()
	for i in 100:
		_mode(3, Vector3(10, 8, 10))
	res["set_params_ms"] = snappedf((Time.get_ticks_usec() - t0) / 100000.0, 0.001)
	_mode(0, Vector3.ZERO)
	_cam_on(Vector3(16, 8, 16), 40.0)
	res["zapnuto_mode0_cas"] = await _bench("zapnuto, režim 0")
	# kopec
	var feet := _find_hidden()
	print("kopec: postava ", feet)
	res["kopec"] = await _scene("kopec", feet, 26.0, PR.underground(feet, 1.8, hm_at))
	# chodba
	var tn := _dig_tunnel()
	print("chodba: ", tn)
	res["chodba_vyrez"] = {"nohy": str(tn.feet), "vrchol_bunek": tn.peak_cells, "podlaha_bunek": tn.floor_cells,
		"nadlozi_bunek": tn.overburden_m_cells, "vyrezano_bunek": tn.cut_cells, "delka_bunek": tn.len_cells,
		"prestavba_ms": snappedf(tn.rebuild_ms, 0.1)}
	res["chodba"] = await _scene("chodba", tn.feet, 22.0, PR.underground(tn.feet, 1.8, hm_at))
	# AB s řezem všude (kruh vypnut) jen snímek
	_mode(2, tn.feet, {"p91_cut_r": 100000.0})
	await _snap("91_chodba_B_rez_vsude")
	_mode(0, tn.feet)
	PR.disable()
	var outp := _arg("out", "")
	if outp != "":
		var f := FileAccess.open(outp, FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  ", false))
		f.close()
	print("E91 hotovo")
	quit()
