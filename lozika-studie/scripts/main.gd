extends Node3D
## Studie ložisek a žil (ore-v0 + přesný cílový souhrn). Režimy za --: --vectors [--out=soubor], --stress, --bench, --shots.

const Mat = preload("res://scripts/mat.gd")
const Ore = preload("res://scripts/ore_v0.gd")
const T = preload("res://scripts/tests.gd")
const Mesher = preload("res://scripts/mesher.gd")

var cam: Camera3D
var hud: Label
var root: Node3D
var toon_mat: ShaderMaterial
var ghost_mat: StandardMaterial3D

func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.split("=", true, 1)[1]
	return def

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--vectors" in args:
		var p := _arg("out", ProjectSettings.globalize_path("res://vectors/ore_v0_vectors.json"))
		var cs := T.export_vectors(p)
		var bad := 0
		for c in cs:
			if not c.allExact:
				print("  ne-přesně: ", c.id, " schodek ", c.shortfall)
				bad += 1
		print("vektory: %d případů, %d s výslovným schodkem -> %s" % [cs.size(), bad, p])
		get_tree().quit(); return
	if "--caves" in args:
		const CT = preload("res://scripts/cave_tests.gd")
		var cs := CT.vectors(ProjectSettings.globalize_path(_arg("out", "res://vectors/cave_v0_vectors.json")))
		for c in cs:
			print(c.id, " jeskyně ", c.caveTarget.cave_air, "→", c.caveAirPlaced, " voda ", c.water.target, "→", c.water.placed, " těsnění ", c.water.sealedCells, " validátor ", c.validator.ok, " rudy ", c.ores.map(func(o): return "%d/%d" % [o.placed, o.target]), " ", c.wvb1Header)
		get_tree().quit(); return
	if "--cave-sim" in args:
		const CT = preload("res://scripts/cave_tests.gd")
		print("\n".join(CT.sim_report(ProjectSettings.globalize_path("res://shots/cave_sim.txt"), int(_arg("blocks", "8")), int(_arg("ticks", "600")))))
		get_tree().quit(); return
	if "--cave-stress" in args:
		const CT = preload("res://scripts/cave_tests.gd")
		print("\n".join(CT.stress(ProjectSettings.globalize_path("res://shots/cave_stress.txt"), int(_arg("seeds", "30")))))
		get_tree().quit(); return
	if "--gen3" in args:
		const G3 = preload("res://scripts/gen3_tests.gd")
		var cs := G3.vectors(ProjectSettings.globalize_path(_arg("out", "res://vectors/gen_v3_vectors.json")))
		for c in cs:
			print(c.id, " zásobník ", c["in"].stack.map(func(i): return "%s %d" % [i.material, i.count]), " hash ", c["in"].stackHash.left(12), " přesně ", c.materials.all(func(m): return m.shortfall == 0), " voda ", c.water, " validátor ", c.validator, " vrstvy ", c.layering, " proto ", c.layeringPrototype)
		get_tree().quit(); return
	if "--gen3-stress" in args:
		const G3 = preload("res://scripts/gen3_tests.gd")
		print("\n".join(G3.stress(ProjectSettings.globalize_path("res://shots/gen3_stress.txt"), int(_arg("seeds", "15")))))
		get_tree().quit(); return
	if "--gen3-ablation" in args:
		const G3 = preload("res://scripts/gen3_tests.gd")
		print("\n".join(G3.ablation(ProjectSettings.globalize_path("res://shots/gen3_ablace.txt"))))
		get_tree().quit(); return
	if "--gen3-sim" in args:
		const G3 = preload("res://scripts/gen3_tests.gd")
		print("\n".join(G3.sim(ProjectSettings.globalize_path("res://shots/gen3_sim.txt"), int(_arg("ticks", "400")))))
		get_tree().quit(); return
	if "--stress" in args:
		T.stress(ProjectSettings.globalize_path("res://shots/stress.txt"), int(_arg("seeds", "40")))
		get_tree().quit(); return
	if "--bench" in args:
		T.bench(ProjectSettings.globalize_path("res://shots/bench.txt"))
		get_tree().quit(); return
	_setup()
	if "--cave-shots" in args:
		await _cave_shots()
	elif "--gen3-shots" in args:
		await _gen3_shots()
	else:
		await _shots()
	get_tree().quit()

func _setup() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86); sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-55, 25, 0)
	add_child(sun)
	toon_mat = ShaderMaterial.new()
	toon_mat.shader = load("res://terrain_toon.gdshader")
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.vertex_color_use_as_albedo = true
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(1, 1, 1, 0.10)
	ghost_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1; cam.far = 400.0; add_child(cam)
	var cl := CanvasLayer.new(); add_child(cl)
	hud = Label.new(); hud.position = Vector2(14, 10)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color(0.12, 0.13, 0.2))
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.8); sb.set_content_margin_all(8)
	hud.add_theme_stylebox_override("normal", sb)
	cl.add_child(hud)
	root = Node3D.new(); add_child(root)

func _only(cells: PackedByteArray, keep: Array) -> PackedByteArray:
	var c := cells.duplicate()
	for i in c.size():
		if not (c[i] in keep):
			c[i] = 0
	return c

## jeden blok na pozici off: rudy v toon stylu, zbytek jako průsvitný obal (ghost=true) nebo plný terén
## before: objem před ore-v0 → kreslí se jen buňky, které ore-v0 přepsal (základní jíl z půdy se nekreslí);
## bez before se kreslí jen měď a železo (prototyp se šumovými rudami)
func _add_block(cells: PackedByteArray, off: Vector3, ghost := true, before := PackedByteArray()) -> void:
	if ghost:
		var g := MeshInstance3D.new()
		g.mesh = Mesher.build(cells, [null, null, null, null], -1)
		g.material_override = ghost_mat; g.position = off
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(g)
		var o := MeshInstance3D.new()
		var oc := _only(cells, [Mat.COPPER, Mat.IRON])
		if before.size() == cells.size():
			oc = cells.duplicate()
			for i in oc.size():
				if oc[i] == before[i]:
					oc[i] = 0
		o.mesh = Mesher.build(oc, [null, null, null, null], -1)
		o.material_override = toon_mat; o.position = off
		root.add_child(o)
	else:
		var m := MeshInstance3D.new()
		m.mesh = Mesher.build(cells, [null, null, null, null], -1)
		m.material_override = toon_mat; m.position = off
		root.add_child(m)

func _clear() -> void:
	for ch in root.get_children():
		ch.queue_free()

func _frame(center: Vector3, size: float, dir := Vector3(0.9, 1.0, 1.3)) -> void:
	cam.size = size
	cam.position = center + dir.normalized() * 120.0
	cam.look_at(center, Vector3.UP)

func _snap(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/37_lozika_%s.png" % name))
	print("shot ", name)

func _desc(res: Dictionary) -> String:
	var parts := []
	for rep in res.per_ore:
		if rep.target > 0:
			parts.append("%s %d/%d" % [Mat.NAMES[rep.material], rep.placed, rep.target])
	return ", ".join(parts)

func _placed(kind: String, seed: int, bonus: int, tg := {}) -> Array:
	var b := T.base_block(kind, seed)
	var c := b.cells.duplicate()
	var sk := Ore.specs_for(kind)
	var t := tg if not tg.is_empty() else Ore.server_target(seed, bonus, sk)
	var res := Ore.place(c, seed, t, sk)
	return [c, res, b.cells]

func _shots() -> void:
	var legend := "jen buňky rozmístěné ore-v0: měď = tyrkys, železo = červená, jíl = lososový; horniny průsvitné"
	# 1–3: louka, kopec, hora (dva seedy vedle sebe, bonus 50 %)
	for kc in [["louka", 101, 404], ["kopec", 303, 2302], ["hora", 202, 1000]]:
		_clear()
		var txt := ""
		for j in 2:
			var r := _placed(kc[0], kc[1 + j], 50)
			_add_block(r[0], Vector3(j * 22, 0, 0), true, r[2])
			txt += "\n%s %d: %s" % [kc[0], kc[1 + j], _desc(r[1])]
		_frame(Vector3(19, 12, 8), 44)
		hud.text = "ore-v0, cíl ze serveru (bonus 50 %%)%s\n%s" % [txt, legend]
		await _snap(kc[0])
	# 4: tvary v čistém hostiteli (žula / žula / hlína), cíl 150
	_clear()
	var specs: Array = [Ore.CATALOG.copper, Ore.CATALOG.iron, Ore.CATALOG.clay]
	var hosts := [Mat.GRANITE, Mat.GRANITE, Mat.DIRT]
	var txt2 := ""
	for si in 3:
		var c := T.solid(hosts[si])
		var c0 := c.duplicate()
		var res := Ore.place(c, 7 + si, {specs[si].material: 150}, [specs[si]])
		_add_block(c, Vector3(si * 22, 0, 0), true, c0)
		txt2 += "  %s = %s (%d)" % [specs[si].name, specs[si].shape, res.placed[specs[si].material]]
	_frame(Vector3(30, 12, 8), 58)
	hud.text = "Tvary ore-v0 v čistém hostiteli, 150 buněk:" + txt2 + "\nžíla (náhodná procházka, setrvačnost 70 %), čočka (BFS p 0,55), sloj (vodorovně 0,8 / svisle 0,1)"
	await _snap("tvary")
	# 5: řez horou: polovina bloku (lx >= 8) odebraná, plný toon terén
	_clear()
	var rr := _placed("hora", 202, 50)
	var cut: PackedByteArray = rr[0].duplicate()
	for x in range(8, 16):
		for y in 16:
			for z in 64:
				cut[Ore.idx(x, y, z)] = 0
	_add_block(cut, Vector3.ZERO, false)
	var rr2 := _placed("louka", 101, 50)
	var cut2: PackedByteArray = rr2[0].duplicate()
	for x in range(8, 16):
		for y in 16:
			for z in 64:
				cut2[Ore.idx(x, y, z)] = 0
	_add_block(cut2, Vector3(0, 0, 22), false)
	_frame(Vector3(6, 10, 18), 46, Vector3(1.4, 0.8, 0.5))
	hud.text = "Řez v lx = 8: louka 101 (vlevo) a hora 202 (vpravo), bonus 50 %\n" + "měď tyrkys, železo červená, jíl lososový (i základní jíl z půdy); vápenec béžový, žula růžová, čedič modrošedý"
	await _snap("rez")
	# 6: srovnání: prototyp (šumové rudy) vs. ore-v0, stejný blok
	_clear()
	var lb := T.legacy_block("hora", 202)
	_add_block(lb.cells, Vector3.ZERO)
	var r6 := _placed("hora", 202, 0)
	_add_block(r6[0], Vector3(22, 0, 0), true, r6[2])
	_frame(Vector3(19, 12, 8), 44)
	hud.text = "hora 202 – vlevo prototyp (šum: Cu %d, Fe %d buněk), vpravo ore-v0 bonus 0 %%\n(%s); kreslí se jen rudy (u ore-v0 i jíl, který ore-v0 přidal); horniny průsvitné" % [lb.summary[Mat.COPPER], lb.summary[Mat.IRON], _desc(r6[1])]
	await _snap("srovnani")
	# 7: zátěž: obří cíle a malý hostitel
	_clear()
	var r7 := _placed("hora", 202, 0, {Mat.COPPER: 3000, Mat.IRON: 3000, Mat.CLAY_DEPOSIT: 1500})
	_add_block(r7[0], Vector3.ZERO, true, r7[2])
	var lc := T.base_block("louka", 101).cells
	var tiny := T.tiny_host(lc)
	var tiny0 := tiny.duplicate()
	var res8 := Ore.place(tiny, 101, {Mat.COPPER: 200, Mat.IRON: 60}, Ore.specs_for("louka"))
	_add_block(tiny, Vector3(22, 0, 0), true, tiny0)
	_frame(Vector3(19, 12, 8), 44)
	hud.text = "Zátěž: vlevo hora 202, cíl Cu 3000 / Fe 3000 / jíl 1500 (%s)\nvpravo malý hostitel (27 buněk žuly): %s – zbytek přes L4 do čediče" % [_desc(r7[1]), _desc(res8)]
	await _snap("zatez")

# ---------------- cave-v0 snímky (38_jeskyne_*)
const CT = preload("res://scripts/cave_tests.gd")
const Cave = preload("res://scripts/cave_v0.gd")

func _water_mesh(cells: PackedByteArray, water: PackedInt32Array, off: Vector3, sim = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for c in cells.size():
		var f := 0.0
		var x := c / 1024; var y := (c / 64) % 16; var z := c % 64
		if sim != null:
			f = sim.w[x + y * 16 + z * 256] if sim.mat[x + y * 16 + z * 256] == 0 else 0.0
		else:
			f = float(water[c]) / Cave.FULL
		if f < 0.02:
			continue
		n += 1
		var a := Vector3(x, z * 0.5, y) + off
		var bmax := a + Vector3(1, 0.5 * minf(f, 1.0), 1)
		var vs := [Vector3(a.x, a.y, a.z), Vector3(bmax.x, a.y, a.z), Vector3(bmax.x, a.y, bmax.z), Vector3(a.x, a.y, bmax.z),
			Vector3(a.x, bmax.y, a.z), Vector3(bmax.x, bmax.y, a.z), Vector3(bmax.x, bmax.y, bmax.z), Vector3(a.x, bmax.y, bmax.z)]
		for q in [[4, 5, 6, 7], [0, 3, 2, 1], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7]]:
			st.add_vertex(vs[q[0]]); st.add_vertex(vs[q[1]]); st.add_vertex(vs[q[2]])
			st.add_vertex(vs[q[0]]); st.add_vertex(vs[q[2]]); st.add_vertex(vs[q[3]])
	if n == 0:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.55, 0.95, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	mi.material_override = m
	root.add_child(mi)

## průsvitné horniny; jeskynní vzduch (bez vody) fialově, rudy, voda modře
func _cave_ghost(r: Dictionary, off: Vector3) -> void:
	var cells: PackedByteArray = r.cells
	var g := MeshInstance3D.new()
	g.mesh = Mesher.build(cells, [null, null, null, null], -1)
	g.material_override = ghost_mat; g.position = off
	root.add_child(g)
	var v := PackedByteArray()
	v.resize(cells.size())
	for c in cells.size():
		var m := cells[c]
		if m == Mat.AIR and c % 64 < r.hm[c / 64] and r.water[c] == 0:
			v[c] = Mat.VIEW_CAVE
		elif m in Mat.ORES:
			v[c] = m
	var o := MeshInstance3D.new()
	o.mesh = Mesher.build(v, [null, null, null, null], -1)
	o.material_override = toon_mat; o.position = off
	root.add_child(o)
	_water_mesh(cells, r.water, off)

func _cave_desc(r: Dictionary) -> String:
	return "%s %d: jeskyně %d/%d, voda %.0f/%d (validátor %s)" % [r.kind, r.seed, r.cave.cave_air_placed, r.cave.cave_air_target, r.water_rep.placed, r.water_rep.target, "OK" if r.valid.ok else "CHYBA"]

func _cave_shots() -> void:
	var legend := "fialová = jeskyně (sály, chodby, šachty), modrá = voda v rezervoárech, tyrkys/červená/oranžová = Cu/Fe/ložiskový jíl"
	for kc in [["louka", 101, 404], ["kopec", 303, 2302], ["hora", 202, 1000]]:
		_clear()
		var txt := ""
		for j in 2:
			var r := CT.pipeline(kc[0], kc[1 + j], 0, 2, 1)
			_cave_ghost(r, Vector3(j * 22, 0, 0))
			txt += "\n" + _cave_desc(r)
		_frame(Vector3(19, 12, 8), 44)
		hud.text = "cave-v0 (jeskyně ×2), horniny průsvitné" + txt + "\n" + legend
		await _snap2("38_jeskyne_" + kc[0])
	# řez: hora 1000, voda ×3, rovina řezu přes největší rezervoár
	_clear()
	var rr := CT.pipeline("hora", 1000, 0, 2, 3)
	var bs := Cave.basins(rr.cells, rr.hm)
	var bx := 8
	var bw := 0
	for b in bs:
		var s := 0
		for c: int in b.cells:
			s += rr.water[c]
		if s > bw:
			bw = s
			var xs := []
			for c: int in b.cells:
				xs.append(c / 1024)
			xs.sort(); bx = xs[xs.size() / 2]
	var cut: PackedByteArray = rr.cells.duplicate()
	var wcut: PackedInt32Array = rr.water.duplicate()
	for c in cut.size():
		if c / 1024 > bx:
			cut[c] = 0; wcut[c] = 0
	_add_block(cut, Vector3.ZERO, false)
	_water_mesh(cut, wcut, Vector3.ZERO)
	_frame(Vector3(8, 14, 8), 36, Vector3(1.4, 0.8, 0.5))
	hud.text = "Řez horou 1000 v lx = %d (jeskyně ×2, voda ×3): rezervoár v žule/čediči, hladina vodorovně\n%s" % [bx, _cave_desc(rr)]
	await _snap2("38_jeskyne_rez")
	# kopání do rezervoáru a simulace voda-studie 400 tiků
	_clear()
	var d := CT.dig_test(rr, 400)
	if d.ok:
		var dc: PackedByteArray = d.cells.duplicate()
		var sy: int = (d.dug_cells[0] / 64) % 16
		for c in dc.size():
			if (c / 64) % 16 > sy:
				dc[c] = 0
		_add_block(dc, Vector3.ZERO, false)
		var sim = d.sim
		for c in dc.size():
			if (c / 64) % 16 > sy:
				sim.w[(c / 1024) + ((c / 64) % 16) * 16 + (c % 64) * 256] = 0.0
		_water_mesh(dc, PackedInt32Array(), Vector3.ZERO, sim)
		_frame(Vector3(8, 14, 8), 36, Vector3(0.5, 0.8, 1.4))
		hud.text = "Kopání (řez v ly = %d): chodba (%d buněk) z nejnižší vodní vrstvy %d, po 400 tikách simulace voda-studie\nvoda v chodbě %.2f buňky, validátor po prokopání: %d chyb (pánev otevřená)" % [sy, d.dug, d.layer, d.waterInTunnel, d.validatorAfterDig.errors]
	else:
		hud.text = "kopání: " + d.reason
	await _snap2("38_jeskyne_kopani")

func _snap2(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)

## ---------- gen-v3 snímky
const G3T = preload("res://scripts/gen3_tests.gd")

## řez (odstraní lx > cut); mokrá hlína / nasycený písek jako přebarvené buňky, volná voda (v jeskyních, jezírko) modře
func _gen3_cut(cells: PackedByteArray, water: PackedInt32Array, hm: PackedInt32Array, off: Vector3, cut: int, overlay := true) -> void:
	var c2: PackedByteArray = cells.duplicate()
	var w2 := PackedInt32Array()
	w2.resize(cells.size())
	for c in c2.size():
		if c / 1024 > cut:
			c2[c] = 0
			continue
		if water.size() == 0:
			continue
		if c2[c] == Mat.AIR:
			w2[c] = water[c]
		elif overlay and water[c] > 0:
			if c2[c] == Mat.DIRT or c2[c] == Mat.GRASS: c2[c] = Mat.VIEW_WET_DIRT
			elif c2[c] == Mat.SAND: c2[c] = Mat.VIEW_WET_SAND
	_add_block(c2, off, false)
	if water.size() > 0:
		_water_mesh(c2, w2, off)

func _g3desc(g: Dictionary) -> String:
	var ok: bool = g.reps.all(func(r): return r.shortfall == 0)
	var la: Dictionary = G3T.layering(g.cells); var lp: Dictionary = G3T.layering(g.proto_cells)
	var wr: Dictionary = g.water_rep
	return "%s %d: materiály přesně %s, validátor %s | voda %d → póry %.0f, jeskyně %.0f, jezírko %.0f, odtok %.0f\n   vrstevnatost (čistota vrstev kamene) %.2f, prototyp %.2f" % [g.kind, g.seed,
		"ano" if ok else "NE", "OK" if g.valid.ok else "CHYBA", wr.target, wr.pores, wr.free_cave, wr.pond, wr.runoff, la.purity, lp.purity]

func _gen3_shots() -> void:
	var legend := "vlevo prototyp (STRATA), vpravo gen-v3 v3 (kameny stratum, rudy v kameni, zadržená voda, voda podle okraje); řez v lx = 8\nfialově-šedá = mokrá hlína (i zadržená nad jílem), světle modrá = mokrý písek, modrá = volná voda (jeskyně, jezírko), díry = suché jeskyně"
	for kc in [["louka", 101], ["kopec", 303], ["hora", 1000], ["piscina", 4504]]:
		_clear()
		var g := G3T.run(kc[0], kc[1])
		_gen3_cut(g.proto_cells, PackedInt32Array(), g.hm, Vector3.ZERO, 8)
		_gen3_cut(g.cells, g.water, g.hm, Vector3(22, 0, 0), 8)
		_frame(Vector3(19, 12, 8), 46, Vector3(1.4, 0.8, 0.5))
		hud.text = legend + "\n" + _g3desc(g)
		await _snap2("39_genv3_rez_" + kc[0] + "_v3")
	# mokro: voda ×5 (louka 404) a voda ×5 (piscina 4504)
	_clear()
	var txt := ""
	var j := 0
	for kc in [["louka", 404], ["piscina", 4504]]:
		var g := G3T.run(kc[0], kc[1], 0, 1, 1, 5)
		_gen3_cut(g.cells, g.water, g.hm, Vector3(j * 22, 0, 0), 8)
		txt += "\n" + _g3desc(g)
		j += 1
	_frame(Vector3(19, 12, 8), 46, Vector3(1.4, 0.8, 0.5))
	hud.text = "gen-v3, voda ×5: hladina podzemní vody, pod ní mokrá hlína / nasycený písek, nad nejnižší okraj bloku nic (zbytek = odtok)" + txt
	await _snap2("39_genv3_mokro_v3")
	# jeskyně s vodou: průsvitné horniny
	_clear()
	txt = ""
	j = 0
	for kc in [["kopec", 303, 1], ["hora", 202, 5]]:
		var g := G3T.run(kc[0], kc[1], 0, kc[2])
		var gw: PackedInt32Array = g.water.duplicate()
		for c in gw.size():
			if g.cells[c] != Mat.AIR: gw[c] = 0   # jen volná voda (v pórech se nekreslí)
		_cave_ghost({"cells": g.cells, "water": gw, "hm": g.hm}, Vector3(j * 22, 0, 0))
		txt += "\n" + _g3desc(g) + (" (jeskyně ×%d)" % kc[2] if kc[2] > 1 else "")
		j += 1
	_frame(Vector3(19, 12, 8), 44)
	hud.text = "gen-v3: jeskyně (fialově suché, modře volná voda, která do nich vtekla z povrchu; voda v pórech se nekreslí)\nrudy tyrkys/červená, ložiskový jíl oranžová" + txt
	await _snap2("39_genv3_jeskyne_v3")
