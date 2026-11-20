extends Node3D
## Willage – hratelný prototyp ostrova: 4 startovní bloky, mlha, lišta kandidátů, náhled a vkládání bloků.
## Main jen skládá dohromady uzly scény main.tscn (každý má vlastní skript ve scripts/game/) a rozděluje vstup
## podle režimu: vkládání bloku (Placement), stavby (Buildings), cesty (Roads), kopání (Digging).
## Demo / screenshoty / měření (-- --demo, --video, --*-shots, --*-bench, --res-test, --export-vectors) běží
## ve scéně demo.tscn (scripts/demo/demo_runner.gd); Main na ni při takovém přepínači přesměruje.

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Toon = preload("res://scripts/toon.gd")
const DemoRunner = preload("res://scripts/demo/demo_runner.gd")
const SP96 = preload("res://scripts/surface/surface_params.gd")   # E96: LOD přehledu bloku 128 m
const BS := J.BS

@onready var world = $World
@onready var island = $Island
@onready var rig = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera
@onready var placement = $Placement
@onready var buildings = $Buildings
@onready var roads = $Roads
@onready var digging = $Digging
@onready var water = $WaterFlow
@onready var ui = $UI
@onready var dev_panel = $DevPanel

func _ready() -> void:
	if get_parent() == get_tree().root and DemoRunner.wanted():
		# spuštěno přímo s přepínačem dema: hra se nesestaví, převezme to demo.tscn (stejné přepínače)
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred(DemoRunner.SCENE)
		return
	BlockGen.gen_version = island.generator
	BlockGen.apply_cli()   # -- --gen=proto|v3 (výchozí v3)
	island.setup()
	rig.set_meritko(island.m_na_bunku())   # E94: scéna v metrech → kamera v metrech (1 = beze změny)
	island.generate_start()
	if island.spawn96.is_empty():
		buildings.add_house(Vector2i(6, 8))   # testovací domek z Blenderu (assets/domek.glb)
	else:
		_start_b96()
	ui.candidate_picked.connect(placement.pick)
	ui.settings_changed.connect(placement.rebuild_preview)
	ui.confirm_pressed.connect(placement.confirm)
	ui.cancel_pressed.connect(placement.cancel)
	var nc: Array = buildings.names_and_colors()
	ui.set_buildings(nc[0], nc[1])
	ui.building_picked.connect(pick_building)
	ui.tab_changed.connect(func(k): if k == 0: buildings.cancel())
	for n in [placement, buildings, roads]:
		n.hint_changed.connect(update_hint)
	for n in [digging, buildings, roads]:
		n.cell_inspected.connect(show_block_at)
	placement.setup_candidates()
	rig.place()
	update_hint()
	dev_panel.activate()

## E96: blok 128 m – domek a postava (značka 1,75 m, hra zatím postavu nemá) na nejrovnějším místě u středu, kamera na ni
var postava96: MeshInstance3D
func _start_b96() -> void:
	buildings.add_house(island.spawn96.dum)
	var g: Vector2i = island.spawn96.postava
	var cap := CapsuleMesh.new(); cap.height = J.hj_m(J.POSTAVA_HJ); cap.radius = 0.25
	postava96 = MeshInstance3D.new(); postava96.mesh = cap
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.85, 0.2, 0.2); postava96.material_override = mat
	var top: Vector3 = island.to_global(Vector3(g.x + 0.5, island.col_h(g) * Block.CELL_H, g.y + 0.5))
	postava96.position = top + Vector3(0, cap.height / 2.0, 0)
	add_child(postava96)
	rig.center = top
	rig.zoom_max_k = 2.0   # 160 × 0,5 × 2 = 160 m záběr: celý blok 128 m
	var lz := float(SP96.inst().p96_lod_zaber)
	if lz > 0.0:   # LOD přehledu: nad lz m záběru jedna síť 1 m bez vegetace (E90)
		rig.placed.connect(func(sz: float): island.lod96_set(sz > lz))

## demo / testy: zastaví vše, co běží po snímcích (kamera WASD, tok vody, čas větru)
func set_game_process(on: bool) -> void:
	set_process(on)
	for n in [rig, water, world]:
		n.set_process(on)

func update_hint() -> void:
	var t := "Q/E otočit · kolečko zoom · WASD / prostřední tlačítko posun · PgUp/PgDn/Home řez · T vzhled · X textury · B hrany"
	t += " · C cesty · M kopání"
	if buildings.build_sel >= 0:
		t += "\nSTAVBA %s: klik = postavit na zelené místo (rozdíl ≤ 1 buňka, dveře volné) · R otočit · Esc zrušit" % buildings.BTYPES[buildings.build_sel].name
	elif digging.dig_mode:
		t += "\nKOPÁNÍ: klik = vykopat vrchní buňku (do inventáře) · Shift+klik = položit z inventáře · 1–9 vybrat materiál · Esc konec"
	elif roads.road_mode:
		t += "\nCESTY: klikni na domek/bod (start), další body = průjezdní body, poslední = cíl · Enter postavit · Esc zrušit · body: %d" % roads.road_pts.size()
	elif placement.preview != null:
		t += "\nR rotace · F zrcadlení · +/− výška · Enter uložit · Esc zrušit"
	ui.set_hint(t)

## výběr stavby z lišty: ostatní režimy se zruší
func pick_building(i: int) -> void:
	placement.cancel()
	roads.road_mode = false; digging.dig_mode = false
	buildings.pick(i)

## panel vpravo: blok pod sloupcem g (případně stavba na něm)
func show_block_at(g: Vector2i) -> void:
	var sl := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(sl):
		return
	var b: Block = island.blocks[sl]
	var n := 0
	if digging.deltas.has(sl): n = digging.deltas[sl].size()
	ui.delta_txt = "\nZměny v bloku (delta): %d" % n if n > 0 else ""
	var txt := "Sloupec (%d, %d) v bloku %s" % [g.x - sl.x * BS, g.y - sl.y * BS, sl]
	var bh = buildings.building_at(g)
	if bh != null:
		txt = "Stavba: %s · %s" % [buildings.BTYPES[buildings.bdata[bh].t].name, txt]
	elif island.occupied.has(g):
		txt = "Cesta · " + txt
	ui.show_block(b, txt, false)

# ---------------------------------------------------------------- vstup (kamera má vlastní: kolečko, tažení, Q/E, WASD)
func _mouse_slot(pos: Vector2):
	return island.slot_at_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))

func _mouse_cell(pos: Vector2):
	return island.cell_at_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))

func _unhandled_input(e: InputEvent) -> void:
	var preview = placement.preview
	if e is InputEventMouseMotion:
		if rig.dragging:
			return
		if buildings.build_sel >= 0:
			buildings.hover(_mouse_cell(e.position))
			return
		var s = _mouse_slot(e.position)
		island.set_hover(s if s != null and island.is_valid(s) and preview != null else null)
		if placement.locked_slot == null:
			placement.preview_at(s)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if roads.road_mode:
			roads.click(_mouse_cell(e.position))
			return
		if buildings.build_sel >= 0:
			buildings.click()
			return
		if digging.dig_mode:
			var gd = _mouse_cell(e.position)
			if gd != null:
				ui.set_hint("M kopání: " + digging.dig(gd, e.shift_pressed))
			return
		var s = _mouse_slot(e.position)
		if preview != null and s != null and island.is_valid(s):
			placement.lock(s)
		elif preview == null and s != null and island.blocks.has(s):
			ui.show_block(island.blocks[s], "Na místě %s" % s, false)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_PAGEDOWN: island.set_slice(40 if island.slice_z < 0 else maxi(island.slice_z - 1, 1))
			KEY_PAGEUP: island.set_slice(island.slice_z + 1 if island.slice_z >= 0 and island.slice_z < 63 else -1)
			KEY_HOME: island.set_slice(-1)
			KEY_T: island.set_kawaii(not island.kawaii); Toon.set_on(island.kawaii)
			KEY_X: island.set_textured(not island.textured)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				digging.select_mat(e.keycode - KEY_1)
			KEY_B: island.set_bevel(not island.bevel)
			KEY_R:
				if buildings.build_sel >= 0:
					buildings.build_rot = (buildings.build_rot + 1) % 4
					buildings.hover(_mouse_cell(get_viewport().get_mouse_position()))
				else:
					placement.edit(func(): placement.preview.rot = (placement.preview.rot + 1) % 4)
			KEY_M:
				digging.dig_mode = not digging.dig_mode and preview == null
				roads.road_mode = false; buildings.cancel()
				digging.refresh_inv()
				update_hint()
			KEY_F: placement.edit(func(): placement.preview.mirror = not placement.preview.mirror)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: placement.edit(func(): placement.preview.shift = mini(placement.preview.shift + 1, 4))
			KEY_MINUS, KEY_KP_SUBTRACT: placement.edit(func(): placement.preview.shift = maxi(placement.preview.shift - 1, -4))
			KEY_C:
				roads.road_mode = not roads.road_mode and preview == null
				roads.clear_marks(); update_hint()
			KEY_ENTER, KEY_KP_ENTER:
				if roads.road_mode: roads.finish()
				else: placement.confirm()
			KEY_ESCAPE:
				if buildings.build_sel >= 0:
					buildings.cancel()
				elif digging.dig_mode:
					digging.dig_mode = false; update_hint()
				elif roads.road_mode:
					roads.road_mode = false; roads.clear_marks(); update_hint()
				else: placement.cancel()
