extends Node
## Hlavní demo prototypu (přesunuto z main.gd): `-- --demo` = scénář se screenshoty shots/01–22 a SELFTEST výpisy,
## `-- --video` = scénář pro natáčení (--write-movie --fixed-fps 30). Spouští ho demo_runner.gd jako dítě uzlu Main.

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const Mat = preload("res://scripts/mat.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Roads = preload("res://scripts/roads.gd")
const Toon = preload("res://scripts/toon.gd")
const Block = preload("res://scripts/block.gd")
const IslandS = preload("res://scripts/island.gd")
const BS := J.BS

var m            # Main (main.gd)
var island
var ui
var cam: Camera3D
var rig
var bld          # Buildings
var roads        # Roads
var dig          # Digging
var pl           # Placement

func _ready() -> void:
	m = get_parent()
	island = m.island; ui = m.ui; cam = m.cam; rig = m.rig
	bld = m.buildings; roads = m.roads; dig = m.digging; pl = m.placement
	if "--demo" in OS.get_cmdline_user_args():
		_demo()
	elif "--video" in OS.get_cmdline_user_args():
		_video()

## kopání: jáma 3 × 3 hluboká 4 buňky na louce, pak 3 buňky zpět; delta do vectors/delta_sample.json
func _demo_dig() -> void:
	var pit = null
	for sl in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]:
		for lx in range(3, 12):
			for ly in range(3, 12):
				var c: Vector2i = sl * BS + Vector2i(lx, ly)
				var ok := true
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var g := c + Vector2i(dx, dz)
						if island.occupied.has(g) or Roads.height(island, g) < 8: ok = false
				if ok and pit == null: pit = c
	if pit == null:
		print("kopání: nenašel jsem volné místo"); return
	dig.dig_mode = true
	rig.yaw = 315.0; rig.pitch = -52.0; rig.center = Vector3(pit.x + 0.5, Roads.height(island, pit) * 0.5, pit.y + 0.5); cam.size = 13.0; rig.place()
	m.show_block_at(pit)
	ui.set_inventory(dig.inventory, "(M kopání)")
	m.update_hint()
	await _snap("21a_pred_kopanim.png")
	var b: Block = island.blocks[Vector2i(floori(pit.x / 16.0), floori(pit.y / 16.0))]
	var r0 := Mat.score_of(b.summary)
	var msg := ""
	for k in 6:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				msg = dig.dig(pit + Vector2i(dx, dz))
	var li: Array = dig.inv_list()
	dig.place_mat = Mat.LIMESTONE if dig.inventory[Mat.LIMESTONE] > 0 else li[0]   # jako klávesa 1–9
	for dz in range(-1, 2):
		msg = dig.dig(pit + Vector2i(-1, dz), true)
	# zakázané případy
	var fog := Vector2i(-40, -40)
	print("kopání: jáma u ", pit, ", poslední: ", msg, "; skóre ", r0, " -> ", Mat.score_of(b.summary),
		"; mlha: ", dig.dig(fog), "; pod cestou: ", dig.dig(roads.last_road[0]) if not roads.last_road.is_empty() else "-")
	ui.set_hint("KOPÁNÍ: " + msg + " · Shift+klik položit · Esc konec")
	await _snap("21b_po_kopani.png")
	dig.export_deltas(_out_dir("vectors") + "delta_sample.json")
	dig.dig_mode = false; rig.pitch = -35.0
	m.update_hint()

## stavby z lišty: studna, mlýn, políčko + cesty k jejich dveřím, náhled domku (zelený = lze postavit)
func _demo_buildings() -> void:
	ui.show_tab(1)
	var reach := Roads.reachable(island, bld.door(bld.houses[0]), island.occupied)
	var placed := []
	for spec in [[1, Vector2i(0, 1), 0], [2, Vector2i(1, 1), 1], [3, Vector2i(0, 1), 0]]:
		var c = bld.find_site(spec[1], reach, spec[0], spec[2])
		if c == null:
			for sl in island.blocks:
				c = bld.find_site(sl, reach, spec[0], spec[2])
				if c != null: break
		print("stavba ", bld.BTYPES[spec[0]].name, ": ", c)
		if c != null:
			bld.add_building(c, spec[0], spec[2])
			placed.append(c)
			reach = Roads.reachable(island, bld.door(bld.houses[0]), island.occupied)
	for c in placed:
		print("cesta k ", bld.BTYPES[bld.bdata[c].t].name, ": ", roads.build_road([bld.houses[0], c]))
	rig.yaw = 315.0; rig.center = Vector3(15, 16, 21); cam.size = 26.0; rig.place()
	m.pick_building(0)
	var hv = bld.find_site(Vector2i(0, 1), {}, 0, 0)
	if hv == null: hv = bld.find_site(Vector2i(1, 1), {}, 0, 0)
	bld.hover(hv)
	if hv != null:
		m.show_block_at(hv)
		var wc: Vector2i = placed[0] if placed.size() > 0 else hv
		rig.yaw = 30.0
		rig.center = Vector3((hv.x + wc.x) * 0.5 + 2.5, Roads.height(island, hv) * 0.5, (hv.y + wc.y) * 0.5 + 0.5); rig.place()
	var bl := []
	for h in bld.houses: bl.append("%s %s" % [bld.BTYPES[bld.bdata[h].t].name, h])
	print("stavby: ", ", ".join(bl), "; náhled domku na ", hv)
	await _snap("22_stavby.png")
	rig.yaw = 315.0
	bld.cancel()
	ui.show_tab(0)

## cesty: 2 další domky, trasy mezi nimi, test pickingu sloupce myší a test nedosažitelného cíle
func _demo_roads() -> void:
	var reach := Roads.reachable(island, bld.door(bld.houses[0]), island.occupied)
	for slot in [Vector2i(1, 1), Vector2i(0, 1)]:
		var c = bld.find_site(slot, reach)
		print("domek ve slotu ", slot, ": ", c)
		if c != null:
			bld.add_house(c)
	# picking: klik na promítnutý střed sloupce musí vrátit týž sloupec
	var probe: Vector2i = bld.door(bld.houses[0]) + Vector2i(0, 1)
	var sp := cam.unproject_position(Vector3(probe.x + 0.5, Roads.height(island, probe) * 0.5, probe.y + 0.5))
	var got = island.cell_at_ray(cam.project_ray_origin(sp), cam.project_ray_normal(sp))
	print("SELFTEST cesty picking: ", "OK" if got == probe else "CHYBA %s != %s" % [got, probe])
	var t := Time.get_ticks_usec()
	var ok1: bool = bld.houses.size() > 1 and roads.build_road([bld.houses[0], bld.houses[1]])
	var ok2: bool = bld.houses.size() > 2 and roads.build_road([bld.houses[0], bld.houses[0] + Vector2i(-2, 6), bld.houses[2]])
	print("cesty: domek0->domek1 %s, domek0->bod->domek2 %s (%.1f ms)" % [ok1, ok2, (Time.get_ticks_usec() - t) / 1000.0])
	# útes > 4 buňky: najdi sloupec, kam se ze dveří nedá dojít ani se schody, a ověř, že A* cestu nenajde
	var hb := {}
	for hh in bld.houses:
		for f in bld.fp(hh): hb[f] = true
	var rr := Roads.reachable(island, bld.door(bld.houses[0]), hb)
	var unreach := 0; var sample = null
	for sl in island.blocks:
		for lx in BS:
			for ly in BS:
				var g: Vector2i = sl * BS + Vector2i(lx, ly)
				if not rr.has(g) and not hb.has(g) and Roads.height(island, g) > 0:
					unreach += 1
					if sample == null: sample = g
	if sample != null:
		var p := Roads.find(island, bld.door(bld.houses[0]), sample, hb)
		print("SELFTEST cesty útes: nedosažitelných sloupců %d, A* k %s: %s" % [unreach, sample, "nenalezena OK" if p.is_empty() else "CHYBA nalezena"])
	# cesta na terasu: nejvyšší sloupec kopce (0,1) dosažitelný s krokem ≤ 4, který s krokem ≤ 1 dosažitelný není
	var blocked := {}
	for hh in bld.houses:
		for f in bld.fp(hh): blocked[f] = true
	var r4 := Roads.reachable(island, bld.door(bld.houses[0]), blocked)
	var best := Vector2i(-999, -999); var bh := -1
	for g in r4:
		if Vector2i(floori(g.x / 16.0), floori(g.y / 16.0)) in [Vector2i(0, 1), Vector2i(1, 0)]:
			var hg := Roads.height(island, g)
			if hg > bh: bh = hg; best = g
	var ok3: bool = bh > 0 and roads.build_road([bld.houses[0], best])
	var st_at = null
	for i in range(1, roads.last_road.size()):
		if absi(Roads.height(island, roads.last_road[i]) - Roads.height(island, roads.last_road[i - 1])) >= Roads.STAIR_FROM:
			st_at = roads.last_road[i - 1] if Roads.height(island, roads.last_road[i - 1]) < Roads.height(island, roads.last_road[i]) else roads.last_road[i]
			break
	var nst := 0; var nsp := 0; var nmg := 0
	for r in island.roads:
		nst += int(r.get_meta("stairs", 0)); nsp += int(r.get_meta("spread", 0)); nmg += int(r.get_meta("merged", 0))
	print("schody: celkem %d, roztažené na 2 sloupce %d, sloučená údolí %d" % [nst, nsp, nmg])
	print("cesta na terasu ", best, " (hm ", bh, "): ", ok3, ", schodů na ostrově celkem ", nst, ", první schody u ", st_at)
	rig.yaw = 315.0; rig.center = Vector3(18, 21, 13); cam.size = 52.0; rig.place()
	ui.set_hint("CESTY: klikni na domek/bod (start), další body = průjezdní, poslední = cíl · Enter postavit · Esc zrušit")
	await _snap("15_cesty.png")
	if st_at != null:
		rig.yaw = 225.0
		rig.center = Vector3(st_at.x + 2.5, Roads.height(island, st_at) * 0.5 + 3.0, st_at.y + 0.5); cam.size = 16.0; rig.place()
		m.show_block_at(st_at)
		await _snap("17_schody_detail.png")
		rig.yaw = 315.0; rig.center = Vector3(18, 21, 13); cam.size = 52.0; rig.place()
	await _demo_dig()
	await _demo_buildings()
	# objekty: kawaii vyp / zap (stejný záběr)
	var h0: Vector2i = bld.houses[0]
	rig.center = Vector3(h0.x + 2.0, Roads.height(island, h0) * 0.5 + 1.0, h0.y + 3.0); cam.size = 16.0; rig.place()
	island.set_kawaii(false); Toon.set_on(false)
	await _snap("18a_objekty_plochy.png")
	island.set_kawaii(true); Toon.set_on(true)
	await _snap("18b_objekty_kawaii.png")
	cam.size = 9.0; rig.place()
	island.set_bevel(true)
	await _snap("19b_hrany_zaoblene.png")
	island.set_bevel(false)
	await _snap("19a_hrany_ostre.png")
	# hero: ostrov doplněný o další bloky (auto napojení), bez UI
	for e in [[Vector2i(0, 2), "piscina", 4504], [Vector2i(-1, 1), "louka", 1777], [Vector2i(1, 2), "kopec", 2302], [Vector2i(2, 0), "kopec", 2302]]:
		if island.is_valid(e[0]):
			var nb := IslandS.make_block(e[1], e[2], "hero")
			nb.slot = e[0]
			BlockGen.build(nb, island.neighbor_hms(nb.slot))
			island.place(nb)
	var hs = bld.find_site(Vector2i(-1, 1), Roads.reachable(island, bld.door(bld.houses[2]), island.occupied))
	if hs != null:
		bld.add_house(hs)
		roads.build_road([bld.houses[2], hs])
	ui.visible = false
	rig.yaw = 315.0; rig.pitch = -32.0; rig.center = Vector3(16, 14, 26); cam.size = 58.0; rig.place()
	await _snap("20_hero.png")
	island.set_bevel(true)
	await _snap("20b_hero_hrany.png")
	island.set_bevel(false)
	island.set_textured(true)
	await _snap("20c_hero_textury.png")
	island.set_textured(false)
	ui.visible = true; rig.pitch = -35.0
	rig.yaw = 315.0; rig.center = Vector3(18, 21, 13); cam.size = 52.0; rig.place()
	island.set_textured(true)
	await _snap("16_textury.png")
	rig.center = Vector3(7, 17, 9); cam.size = 24.0; rig.place()
	await _snap("16b_textury_detail.png")
	island.set_textured(false)
	rig.yaw = 45.0
	m.update_hint()

## simulovaná myš: výběr kandidáta, najetí na platný slot, klik, R, Enter
func _selftest_mouse() -> void:
	rig.yaw = 45.0; rig.center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; rig.place()
	await get_tree().process_frame
	pl.pick(2)
	var target := Vector2i(-1, 0)
	var p := cam.unproject_position(island.slot_origin(target) + Vector3(BS / 2.0, island.SURF_Y, BS / 2.0))
	var mm := InputEventMouseMotion.new()
	mm.position = p
	get_viewport().push_input(mm)
	await get_tree().process_frame
	var hover_ok: bool = island.hover_slot == target and island.preview_mi.visible
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true; mb.position = p
	get_viewport().push_input(mb)
	var kr := InputEventKey.new()
	kr.keycode = KEY_R; kr.pressed = true
	get_viewport().push_input(kr)
	var ke := InputEventKey.new()
	ke.keycode = KEY_ENTER; ke.pressed = true
	get_viewport().push_input(ke)
	await get_tree().process_frame
	var placed: bool = island.blocks.has(target) and island.blocks[target].rot == 1
	print("SELFTEST myš: najetí %s, klik+R+Enter %s" % ["OK" if hover_ok else "CHYBA", "OK" if placed else "CHYBA"])
	await _snap("09_selftest_mys.png")

## galerie: hory a kopce s různými seedy vedle sebe (bez sousedů)
func _seed_gallery(fname: String, items := [["hora", 202], ["hora", 1000], ["hora", 7777], ["kopec", 303], ["kopec", 2302], ["kopec", 5151]], with_veg := false, size := 84.0) -> void:
	const Mesher = preload("res://scripts/mesher.gd")
	island.visible = false
	ui.visible = false
	var g := Node3D.new()
	m.add_child(g)
	for i in items.size():
		var b := IslandS.make_block(items[i][0], items[i][1], "")
		BlockGen.build(b, [null, null, null, null])
		var mi := MeshInstance3D.new()
		mi.mesh = Mesher.build(b.cells, [null, null, null, null], -1)
		mi.material_override = island.terrain_mat
		var cols := 3 if items.size() > 4 else 2
		var gap := 28 if items.size() > 4 else 24
		mi.position = Vector3((i % cols) * gap, 0, (i / cols) * gap)
		g.add_child(mi)
		if with_veg:
			var vn: Node3D = island.VegRender.build(b.veg, b)
			vn.position = mi.position
			g.add_child(vn)
		var l := Label3D.new()
		l.text = "%s %d (%s)" % [items[i][0], items[i][1], BlockGen.relief_version]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0014
		l.font_size = 34
		l.outline_size = 10
		l.outline_modulate = Color(0.35, 0.25, 0.45)
		var mx := 0
		for v in b.hm: mx = maxi(mx, v)
		l.position = mi.position + Vector3(8, mx * 0.5 + 4.0, 8)
		g.add_child(l)
	rig.yaw = 45.0; rig.pitch = -30.0; rig.center = Vector3(36, 14, 22) if items.size() > 4 else Vector3(20, 16, 20); cam.size = size; rig.place()
	await _snap(fname)
	g.queue_free()
	island.visible = true
	ui.visible = true
	rig.pitch = -35.0

## kontrola: rozdíl výšky povrchu na hranách vůči sousedům (0 = navazuje, velký = útes)
func _print_edges(b: Block) -> void:
	var nh: Array = island.neighbor_hms(b.slot)
	for si in 4:
		if nh[si] == null:
			continue
		var d: Vector2i = BlockGen.DIRS[si]
		var diffs := []
		for t in BS:
			var ex := t if d.x == 0 else (BS - 1 if d.x > 0 else 0)
			var ey := t if d.y == 0 else (BS - 1 if d.y > 0 else 0)
			var nx := ex if d.x == 0 else BS - 1 - ex
			var ny := ey if d.y == 0 else BS - 1 - ey
			diffs.append(nh[si][nx * BS + ny] - b.hm[ex * BS + ey])
		print("hrana %s (režim %d): rozdíly %s" % [BlockGen.SIDE_NAMES[si], b.sides[si], diffs])

# ---------------------------------------------------------------- demo / screenshoty
## výstupní složka: v editoru/projektu res://<name>/, v exportované hře user://<name>/ (res:// je jen pro čtení)
func _out_dir(name: String) -> String:
	var d := ProjectSettings.globalize_path("res://%s/" % name) if OS.has_feature("editor") else ProjectSettings.globalize_path("user://%s/" % name)
	DirAccess.make_dir_recursive_absolute(d)
	return d
func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var dir := _out_dir("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir + name)
	print("uloženo shots/", name)

func _demo() -> void:
	await _snap("01_start.png")
	# kandidát: unikátní hora, zrcadlení + rotace 90° + posun +2, západ auto
	ui.select_card(5)
	pl.pick(5)
	pl.locked_slot = Vector2i(2, 0)
	pl.preview.slot = pl.locked_slot
	pl.preview.mirror = true
	pl.preview.rot = 1
	pl.preview.shift = 2
	island.set_hover(pl.locked_slot)
	pl.rebuild_preview()
	await _snap("02_nahled_hora.png")
	pl.confirm()
	# louka níž (−3) mezi horou a startovní loukou: západ dorovnat 4, sever ponechat (útes)
	ui.select_card(0)
	pl.pick(0)
	pl.locked_slot = Vector2i(2, 1)
	pl.preview.slot = pl.locked_slot
	pl.preview.shift = -3
	pl.preview.sides = PackedInt32Array([5, 0, 0, 4])
	island.set_hover(pl.locked_slot)
	pl.rebuild_preview()
	await _snap("03_nahled_louka.png")
	pl.confirm()
	_print_edges(island.blocks[Vector2i(2, 1)])
	ui.show_block(island.blocks[Vector2i(2, 1)], "Vložen na (2, 1)", false)
	await _snap("04_vlozeno.png")
	rig.center = Vector3(40, 15, 22); cam.size = 46.0; rig.place()
	await _snap("05_detail_hran.png")
	rig.yaw = 135.0; rig.place()
	await _snap("06_detail_otoceno.png")
	rig.yaw = 45.0; rig.center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; rig.place()
	rig.center = Vector3(7, 17, 9); cam.size = 24.0; rig.place()
	island.set_kawaii(false); Toon.set_on(false)
	await _snap("14a_plochy.png")
	island.set_kawaii(true); Toon.set_on(true)
	await _snap("07_domek.png")
	rig.center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; rig.place()
	island.set_slice(29)
	await _snap("08_rez.png")
	island.set_slice(-1)
	await _demo_roads()
	await _selftest_mouse()
	BlockGen.relief_version = "v2.1"
	await _seed_gallery("10_hory_kopce_seedy.png")
	BlockGen.relief_version = "v2.2"
	await _seed_gallery("11_terasy_seedy.png")
	await _seed_gallery("13_vegetace.png", [["louka", 101], ["kopec", 2302], ["hora", 7777], ["piscina", 4504]], true, 40.0)
	var g := 0.0
	var m := 0.0
	for t in island.gen_times: g += t
	for t in island.mesh_times: m += t
	print("PRŮMĚR na blok: generování %.1f ms, mesh %.1f ms (%d bloků)" % [g / island.gen_times.size(), m / island.mesh_times.size(), island.gen_times.size()])
	get_tree().quit()

# ---------------------------------------------------------------- video (-- --video, natáčí se přes --write-movie --fixed-fps 30)
var _vframe := 0
func _vwait(sec: float) -> void:
	for i in maxi(1, int(round(sec * 30.0))):
		await get_tree().process_frame
		_vframe += 1

## plynulý přesun kamery (smoothstep), délka v sekundách při 30 fps
func _cam_to(c: Vector3, s: float, y: float, p: float, dur: float) -> void:
	var c0: Vector3 = rig.center; var s0 := cam.size; var y0: float = rig.yaw; var p0: float = rig.pitch
	var n := maxi(1, int(round(dur * 30.0)))
	for i in n:
		var t := float(i + 1) / n
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		rig.center = c0.lerp(c, t); cam.size = lerpf(s0, s, t); rig.yaw = lerpf(y0, y, t); rig.pitch = lerpf(p0, p, t)
		rig.place()
		await get_tree().process_frame
		_vframe += 1

func _vmark(name: String) -> void:
	print("VIDEO úsek ", name, " od snímku ", _vframe, " (", "%.2f" % (_vframe / 30.0), " s)")

func _hpos(g: Vector2i, up := 0.0) -> Vector3:
	return Vector3(g.x + 0.5, Roads.height(island, g) * 0.5 + up, g.y + 0.5)

func _video() -> void:
	# 1) startovní ostrov, pomalý oblet
	_vmark("start")
	rig.yaw = 20.0; rig.pitch = -33.0; cam.size = 70.0; rig.place()
	await _vwait(0.4)
	await _cam_to(rig.center, 64.0, 60.0, -35.0, 3.6)
	# 2) vložení bloku: unikátní hora, rotace, zrcadlení, posun výšky
	_vmark("vkládání")
	ui.select_card(5); pl.pick(5)
	await _vwait(0.6)
	pl.locked_slot = Vector2i(2, 0); pl.preview.slot = pl.locked_slot
	island.set_hover(pl.locked_slot); pl.rebuild_preview()
	await _cam_to(Vector3(30, 15, 16), 62.0, 45.0, -35.0, 1.2)
	var steps := [func(): pl.preview.rot = 1, func(): pl.preview.rot = 2, func(): pl.preview.mirror = true, func(): pl.preview.shift = 1, func(): pl.preview.shift = 2]
	for st in steps:
		st.call(); pl.rebuild_preview(); m.update_hint()
		await _vwait(0.75)
	pl.confirm()
	await _vwait(0.6)
	# 3) terasy: louka níž (−3) se západním dorovnáním
	_vmark("terasy")
	ui.select_card(0); pl.pick(0)
	pl.locked_slot = Vector2i(2, 1); pl.preview.slot = pl.locked_slot
	pl.preview.shift = -3; pl.preview.sides = PackedInt32Array([5, 0, 0, 4])
	island.set_hover(pl.locked_slot); pl.rebuild_preview()
	await _cam_to(Vector3(34, 15, 24), 56.0, 45.0, -35.0, 1.0)
	await _vwait(0.5)
	pl.confirm()
	await _cam_to(_hpos(Vector2i(8, 24), 2.0), 26.0, 20.0, -30.0, 2.2)
	await _vwait(0.4)
	# 4) vegetace ve větru: detail u domku, pomalý drift
	_vmark("vítr")
	var hp := _hpos(bld.houses[0], 1.0)
	await _cam_to(hp + Vector3(1, 0, -1), 12.0, 25.0, -28.0, 1.6)
	await _cam_to(hp + Vector3(2, 0, 0), 10.5, 45.0, -26.0, 3.6)
	# 5) cesty se schody
	_vmark("cesty")
	ui.set_hint("CESTY: klikni na domek/bod (start), další body = průjezdní, poslední = cíl · Enter postavit · Esc zrušit")
	var reach := Roads.reachable(island, bld.door(bld.houses[0]), island.occupied)
	for slot in [Vector2i(1, 1), Vector2i(0, 1)]:
		var c = bld.find_site(slot, reach)
		if c != null: bld.add_house(c)
	await _cam_to(Vector3(18, 21, 13), 50.0, -45.0, -35.0, 2.2)
	if bld.houses.size() > 1: roads.build_road([bld.houses[0], bld.houses[1]])
	await _vwait(0.7)
	if bld.houses.size() > 2: roads.build_road([bld.houses[0], bld.houses[0] + Vector2i(-2, 6), bld.houses[2]])
	await _vwait(0.7)
	var blocked := {}
	for hh in bld.houses:
		for f in bld.fp(hh): blocked[f] = true
	var r4 := Roads.reachable(island, bld.door(bld.houses[0]), blocked)
	var best := Vector2i(-999, -999); var bh := -1
	for g in r4:
		if Vector2i(floori(g.x / 16.0), floori(g.y / 16.0)) in [Vector2i(0, 1), Vector2i(1, 0)]:
			var hg := Roads.height(island, g)
			if hg > bh: bh = hg; best = g
	if bh > 0: roads.build_road([bld.houses[0], best])
	var st_at = null
	for i in range(1, roads.last_road.size()):
		if absi(Roads.height(island, roads.last_road[i]) - Roads.height(island, roads.last_road[i - 1])) >= Roads.STAIR_FROM:
			st_at = roads.last_road[i - 1] if Roads.height(island, roads.last_road[i - 1]) < Roads.height(island, roads.last_road[i]) else roads.last_road[i]
			break
	await _vwait(0.6)
	if st_at != null:
		_vmark("schody")
		await _cam_to(_hpos(st_at, 3.0) + Vector3(2, 0, 0), 16.0, -135.0, -35.0, 2.4)
		m.show_block_at(st_at)
		await _cam_to(_hpos(st_at, 3.0) + Vector3(1, 0, 1), 14.0, -120.0, -33.0, 2.0)
	# 6) stavby z lišty: náhled jede za myší, zelená = lze postavit
	_vmark("stavby")
	ui.show_tab(1)
	reach = Roads.reachable(island, bld.door(bld.houses[0]), island.occupied)
	var site = bld.find_site(Vector2i(1, 1), reach, 2, 0)
	if site == null: site = bld.find_site(Vector2i(0, 1), reach, 2, 0)
	if site != null:
		await _cam_to(_hpos(site, 1.5), 22.0, -45.0, -38.0, 2.0)
		m.pick_building(2)
		for k in range(-5, 1):
			bld.hover(site + Vector2i(k, -absi(k) / 2))
			await _vwait(0.25)
		await _vwait(0.4)
		bld.click()
		roads.build_road([bld.houses[0], site])
		await _vwait(0.8)
	ui.show_tab(0)
	# 7) kopání: jáma 3 × 3, pak položení vápence
	_vmark("kopání")
	var pit = null
	for sl in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]:
		for lx in range(3, 12):
			for ly in range(3, 12):
				var c: Vector2i = sl * BS + Vector2i(lx, ly)
				var ok := true
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var g := c + Vector2i(dx, dz)
						if island.occupied.has(g) or bld.building_at(g) != null or Roads.height(island, g) < 8: ok = false
				if ok and pit == null: pit = c
	if pit != null:
		dig.dig_mode = true
		ui.set_inventory(dig.inventory, "(M kopání)")
		m.update_hint()
		await _cam_to(_hpos(pit), 14.0, -45.0, -50.0, 2.0)
		for k in 5:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					dig.dig(pit + Vector2i(dx, dz))
					await _vwait(0.067)
		var li: Array = dig.inv_list()
		dig.place_mat = Mat.LIMESTONE if dig.inventory[Mat.LIMESTONE] > 0 else li[0]
		dig.refresh_inv()
		await _vwait(0.5)
		for dz in range(-1, 2):
			ui.set_hint("KOPÁNÍ: " + dig.dig(pit + Vector2i(-1, dz), true) + " · Shift+klik položit · 1–9 materiál · Esc konec")
			await _vwait(0.35)
		await _vwait(0.6)
		dig.dig_mode = false
		m.update_hint()
	# 8) závěr: odjezd na celek
	_vmark("závěr")
	await _cam_to(Vector3(20, 15, 18), 66.0, 0.0, -35.0, 3.2)
	await _vwait(0.8)
	_vmark("konec")
	get_tree().quit()