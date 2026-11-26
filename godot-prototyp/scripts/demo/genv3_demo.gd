extends Node
## gen-v3 v prototypu (Jan 20:14), přidá ho demo_runner.gd:
##   -- --genv3-shots [--gen=proto|v3] [--tag=X]   screenshoty shots/41_genv3_proto_*<_tag>.png
##   -- --genv3-bench [--gen=proto|v3] [--tag=X]   měření vložení a kopání + validátor a determinismus → shots/41_genv3_proto_bench<_tag>.txt

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const BlockGen = preload("res://scripts/block_gen.gd")
const Block = preload("res://scripts/block.gd")
const Mat = preload("res://scripts/mat.gd")
const Params = preload("res://scripts/surface/surface_params.gd")
const Gen3 = preload("res://scripts/gen3/gen3_proto.gd")
const Vec = preload("res://scripts/vectors.gd")
const BS := J.BS
const BH := J.BH

var m
var tag := ""
var p

func _ready() -> void:
	m = get_parent()
	p = Params.inst()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	m.set_game_process(false)
	if "--genv3-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

func _sfx(base: String, ext: String) -> String:
	return "41_genv3_proto_%s%s.%s" % [base, ("_" + tag) if tag != "" else "", ext]

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.rig.center = c; m.cam.size = size; m.rig.yaw = yaw; m.rig.pitch = pitch
	m.rig.place()

func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://shots/")
	DirAccess.make_dir_recursive_absolute(d)
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo shots/", name)

func _place(s: Vector2i, kind: String, seed: int) -> float:
	var t0 := Time.get_ticks_usec()
	var b = m.island.make_block(kind, seed, "gen-v3")
	b.slot = s
	BlockGen.build(b, m.island.neighbor_hms(s))
	m.island.place(b)
	return (Time.get_ticks_usec() - t0) / 1000.0

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	l.add_theme_constant_override("outline_size", 8)
	var cl := CanvasLayer.new()
	cl.layer = 10
	cl.add_child(l)
	add_child(cl)
	return l

## nejvyšší buňka jeskyně s vodou (vzduch pod povrchem s vodou) na ostrově: [slot, lx, ly, lz] nebo []
func _find_cave_water() -> Array:
	var best := []
	for s in m.island.blocks:
		var b: Block = m.island.blocks[s]
		if b.water.size() != b.cells.size():
			continue
		for x in BS:
			for z in BS:
				var h: int = b.hm[x * BS + z]
				for y in h:
					var i := (x * BS + z) * BH + y
					if b.cells[i] == Mat.AIR and b.water[i] > 0 and (best.is_empty() or y > best[3]):
						best = [s, x, z, y]
	return best

## nejvyšší buňka jeskyně (vzduch pod povrchem) v bloku s: [lx, ly, lz] nebo []
func _find_cave(s: Vector2i) -> Array:
	var b: Block = m.island.blocks[s]
	var best := []
	for x in range(2, BS - 2):
		for z in range(2, BS - 2):
			var h: int = b.hm[x * BS + z]
			for y in h:
				if b.cells[(x * BS + z) * BH + y] == Mat.AIR and (best.is_empty() or y > best[2]):
					best = [x, z, y]
	return best

func _shots() -> void:
	if m.ui:
		m.ui.visible = false
	m.island.set_textured(true)
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)
	_place(Vector2i(2, 0), "kopec", 2302)
	_place(Vector2i(2, 1), "piscina", 4504)
	var lab := _label("")
	var gl := "gen-v3 (zásobník ze serveru)" if BlockGen.gen_version == "v3" else "gen proto (STRATA)"

	lab.text = "%s: ostrov (louka 101, hora 202, kopec 303, louka 404, kopec 2302, písčina 4504), skrytí podzemí zapnuto" % gl
	_cam(Vector3(24, 14, 16), 70.0)
	await _snap(_sfx("ostrov", "png"))

	# řez přes jeskyni s vodou (nebo aspoň jeskyni hory)
	var cw := _find_cave_water()
	var cs: Vector2i = cw[0] if not cw.is_empty() else Vector2i(1, 0)
	var cz: int = (cw[3] + 1) if not cw.is_empty() else 24
	var cc := Vector3(cs.x * BS + 8, cz * 0.5, cs.y * BS + 8)
	m.island.set_slice(cz)
	lab.text = "%s: řez ve vrstvě %d, skrytí podzemí (x-ray vypnuto): jeskyně a materiály skryté" % [gl, cz]
	_cam(cc, 34.0, 30.0, -50.0)
	await _snap(_sfx("rez", "png"))
	p.set_param("xray", true)
	lab.text = "%s: řez ve vrstvě %d, x-ray: skutečné materiály, jeskyně, voda z dat (modře), mokrá půda tmavší" % [gl, cz]
	await _snap(_sfx("rez_xray", "png"))
	p.set_param("xray", false)
	m.island.set_slice(-1)

	# jezírko: volná voda nad povrchem (v datech)
	var pond := []
	for s in m.island.blocks:
		var b: Block = m.island.blocks[s]
		if b.water.size() != b.cells.size():
			continue
		for x in BS:
			for z in BS:
				var h: int = b.hm[x * BS + z]
				if h < BH and b.water[(x * BS + z) * BH + h] > 0:
					pond = [s, x, z, h]
	if pond.is_empty():
		print("jezírko: na ostrově žádné před kopáním (voda se při přidělení podle okraje vsákne celá)")
	else:
		lab.text = "%s: jezírko z dat bloku %s" % [gl, str(pond[0])]
		_cam(Vector3(pond[0].x * BS + pond[1], pond[3] * 0.5, pond[0].y * BS + pond[2]), 20.0)
		await _snap(_sfx("jezirko", "png"))
	# jáma v louce 404 (blok (1, 1)): stěny jámy ukážou skutečné materiály (odkryté)
	var pit := Vector2i(21, 27)
	var msg := ""
	for k in 7:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				msg = m.digging.dig(pit + Vector2i(dx, dz))
	print("jáma ", pit, ": ", msg)
	lab.text = "%s: jáma 5 × 5 × 7 v louce 404 – stěny jámy odkryté (skutečné materiály, mokrá půda tmavší), okolí skryté" % gl
	_cam(Vector3(pit.x + 0.5, 12.5, pit.y + 0.5), 14.0, 225.0, -50.0)
	await _snap(_sfx("jama", "png"))

	# prokopání do jeskyně (shora šachtou 2 × 2), jeskyně se odkryje i s vodou
	var hs := Vector2i(1, 0)
	var cv := _find_cave(hs)
	if not cw.is_empty():
		hs = cw[0]; cv = [cw[1], cw[2], cw[3]]
	if not cv.is_empty():
		var g0 := Vector2i(hs.x * BS + cv[0], hs.y * BS + cv[1])
		var b: Block = m.island.blocks[hs]
		var opened := false
		for k in 40:
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				m.digging.dig(g0 + d)
			var h: int = b.hm[cv[0] * BS + cv[1]]
			if h <= cv[2] + 1:
				opened = true
				break
		print("šachta do jeskyně ", hs, " ", cv, ": otevřeno ", opened, ", povrch sloupce ", b.hm[cv[0] * BS + cv[1]])
		lab.text = "%s: šachta 2 × 2 prokopaná do jeskyně (blok %s) – jeskyně se odkryla, voda z dat modře" % [gl, str(hs)]
		_cam(Vector3(g0.x + 1, cv[2] * 0.5 + 2.0, g0.y + 1), 18.0, 200.0, -60.0)
		await _snap(_sfx("jeskyne_odkryta", "png"))
		m.island.set_slice(cv[2] + 2)
		lab.text = "%s: totéž v řezu (vrstva %d), skrytí zapnuto: vidět je jen odkrytá jeskyně" % [gl, cv[2] + 2]
		_cam(Vector3(g0.x + 1, cv[2] * 0.5, g0.y + 1), 30.0, 30.0, -55.0)
		await _snap(_sfx("jeskyne_odkryta_rez", "png"))
		m.island.set_slice(-1)

	get_tree().quit()

func _dig_pair(g: Vector2i) -> float:
	var t0 := Time.get_ticks_usec()
	m.digging.dig(g)
	m.digging.dig(g, true)
	return (Time.get_ticks_usec() - t0) / 2000.0

func _bench() -> void:
	var out := []
	var gv: String = BlockGen.gen_version
	out.append("generátor: %s (%s)" % [gv, Gen3.VERSION if gv == "v3" else "proto-v2.2 STRATA"])
	# 1) samotné generování bloku (bez ostrova): 4 recepty × 10 seedů
	var kinds := ["louka", "kopec", "hora", "piscina"]
	var tot := {}
	var srv := 0.0; var gen := 0.0; var val := 0.0
	var valid := 0; var exact := 0; var det := 0; var n := 0
	for k in kinds:
		var t := 0.0
		for i in 10:
			var seed := 1000 + 37 * i
			var b := Block.new(); b.kind = k; b.seed = seed
			BlockGen.build(b, [null, null, null, null])
			t += b.gen_ms
			n += 1
			var b2 := Block.new(); b2.kind = k; b2.seed = seed
			BlockGen.build(b2, [null, null, null, null])
			if b.cells == b2.cells and b.water == b2.water:
				det += 1
			if gv == "v3":
				srv += b.gen3.ms_server; gen += b.gen3.ms_generate; val += b.gen3.ms_validate
				if b.gen3.valid.ok: valid += 1
				if b.gen3.shortfall.keys() == ["water_units"]:
					exact += 1
		tot[k] = t / 10.0
	out.append("generování bloku (průměr z 10 seedů, bez sousedů): louka %.1f ms, kopec %.1f ms, hora %.1f ms, písčina %.1f ms" % [tot.louka, tot.kopec, tot.hora, tot.piscina])
	out.append("determinismus: %d/%d bloků stejně při dvou bězích (buňky i voda)" % [det, n])
	if gv == "v3":
		out.append("v3 rozpad: zástupce serveru %.1f ms, generátor (rozmístění + voda) %.1f ms, validátor %.1f ms na blok" % [srv / n, gen / n, val / n])
		out.append("v3: validátor OK %d/%d, přesné počty (schodek jen voda nebo nic) %d/%d" % [valid, n, exact, n])
	# 2) vložení do ostrova a kopání (skrytí podzemí zapnuto, výchozí)
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)
	var ins := []
	for e in [[Vector2i(2, 0), "kopec", 2302], [Vector2i(2, 1), "piscina", 4504], [Vector2i(-1, 0), "hora", 1000], [Vector2i(0, 2), "louka", 1777]]:
		var t := _place(e[0], e[1], e[2])
		var b: Block = m.island.blocks[e[0]]
		ins.append("%s %d %.0f ms (generování %.1f, síť %.1f)" % [e[1], e[2], t, b.gen_ms, b.mesh_ms])
	out.append("vložení do ostrova: " + ", ".join(ins))
	var dm := 0.0; var de := 0.0
	for i in 4:
		dm += _dig_pair(Vector2i(2 * BS + 6 + i, 8))
		de += _dig_pair(Vector2i(2 * BS, 4 + i))
	out.append("kopání + položení (průměr 4): střed bloku %.1f ms, hrana bloku %.1f ms" % [dm / 4.0, de / 4.0])
	# 3) validátor na blocích ostrova (před kopáním už neplatí přesné počty – kopání je delta, proto jen nekopané bloky)
	if gv == "v3":
		var vi := []
		for s in m.island.blocks:
			var b: Block = m.island.blocks[s]
			vi.append("%s %s %s" % [str(s), b.kind, "OK" if b.gen3.valid.ok else "CHYBA " + str(b.gen3.valid.errors.slice(0, 2))])
		out.append("validátor při vložení (s dorovnáním stran k sousedům): " + ", ".join(vi))
		var cx := 0; var cn := 0
		for c in Vec.GEN3_CASES:
			if c[2] or c[3] != 0 or c[4] != 0 or c[5] != 0.0:
				continue
			cn += 1
			var bs := Vec.gen3_block(c, false)
			var bp := Vec.gen3_block(c, true)
			cx += 1 if bs.gen3.valid.ok and bp.gen3.valid.ok else 0
		out.append("validátor vektorů (s SOIL_COLS i bez): %d/%d" % [cx, cn])
	for line in out:
		print(line)
	var path := ProjectSettings.globalize_path("res://shots/") + _sfx("bench", "txt")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print("uloženo shots/", _sfx("bench", "txt"))
	get_tree().quit()
