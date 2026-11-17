extends Node3D
## Willage – hratelný prototyp ostrova: 4 startovní bloky, mlha, lišta kandidátů, náhled a vkládání bloků.
## Spuštění s `-- --demo` provede scénář a uloží screenshoty do shots/.

const Mat = preload("res://scripts/mat.gd")
const VegG = preload("res://scripts/veg.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const H = preload("res://scripts/stable_hash.gd")
const Vectors = preload("res://scripts/vectors.gd")
const WaterFlow = preload("res://scripts/gen3/water_flow.gd")
const IslandScript = preload("res://scripts/island.gd")
const UIScript = preload("res://scripts/ui.gd")
const Roads = preload("res://scripts/roads.gd")
const Toon = preload("res://scripts/toon.gd")
const Grass = preload("res://scripts/grass.gd")
const ParamRegistry_ = preload("res://scripts/param_registry.gd")
const BS := 16

# startovní ostrov: slot, typ, seed (pořadí = pořadí vkládání)
const START := [
	[Vector2i(0, 0), "louka", 101],
	[Vector2i(1, 0), "hora", 202],
	[Vector2i(0, 1), "kopec", 303],
	[Vector2i(1, 1), "louka", 404],
]

var island
var ui
var cam: Camera3D
var yaw := 45.0
var pitch := -35.0
var center := Vector3(BS, 15.0, BS)
var rng := RandomNumberGenerator.new()
var candidates: Array = []
var sel := -1            # vybraný kandidát
var preview: Block = null
var locked_slot = null   # slot zvolený kliknutím
var dragging := false
var houses: Array[Vector2i] = []   # středy domků (globální sloupce)
var road_mode := false
var road_pts: Array = []           # body trasy (globální sloupce)
var road_marks: Array[Node3D] = []
var last_road: Array = []
var dig_mode := false
var inventory := PackedInt32Array()
var deltas := {}                 # slot -> [{i, lx, ly, lz, old, new}] v pořadí operací
var flows: Array = []            # rozběhnuté toky vody [{slot, flow, delta, w_old}] (water_flow.gd)
var flow_sync := false           # true = tok se dopočítá hned při kopání (headless, testy)
var last_flow := {}              # poslední dokončený tok (box, tiky, ms, kontrola)
const FLOW_BUDGET_MS := 6.0
var build_sel := -1              # vybraná stavba v liště (−1 = žádná)
var build_rot := 0
var build_ghost: Node3D
var build_mark: MeshInstance3D
var build_at = null
var place_mat := -1              # materiál k položení (klávesy 1–9 v režimu kopání)

func _inv_list() -> Array:
	var out := []
	for m in range(1, Mat.COUNT):
		if inventory[m] > 0: out.append(m)
	return out

func _refresh_inv() -> void:
	if place_mat >= 0 and inventory[place_mat] <= 0:
		place_mat = -1
	if place_mat < 0 and not _inv_list().is_empty():
		place_mat = _inv_list()[0]
	ui.set_inventory(inventory, "(M kopání: klik kopat, Shift+klik položit, 1–9 materiál)" if dig_mode else "", place_mat)
var _house_state: GLTFState
var _house_doc: GLTFDocument
var gen_times: Array[float] = []
var mesh_times: Array[float] = []


func _make_block(kind: String, seed: int, title: String, category := "běžný") -> Block:
	var b := Block.new()
	b.kind = kind; b.seed = seed; b.title = title; b.category = category
	if category == "unikátní":
		b.ore_bonus = 0.12
	return b

func _random_candidate() -> Block:
	var kinds := ["louka", "kopec", "hora", "piscina"]
	var k: String = kinds[rng.randi() % kinds.size()]
	var nm: String = {"louka": "Louka", "kopec": "Kopec", "hora": "Hora", "piscina": "Písčina"}[k]
	return _make_block(k, rng.randi_range(1000, 99999), nm)

func _ready() -> void:
	BlockGen.apply_cli()   # -- --gen=proto|v3 (výchozí v3)
	if "--res-test" in OS.get_cmdline_user_args():
		# EXPERIMENT: srovnání rozlišení bloku (scripts/res_test.gd); hra se nespustí
		get_tree().root.add_child.call_deferred(load("res://scripts/res_test.gd").new())
		set_process(false); set_process_unhandled_input(false)
		queue_free()
		return
	if "--export-vectors" in OS.get_cmdline_user_args():
		Vectors.export_to(ProjectSettings.globalize_path("res://vectors/vectors.json"))
		Vectors.export_veg(ProjectSettings.globalize_path("res://vectors/veg_vectors.json"))
		Vectors.export_gen3(ProjectSettings.globalize_path("res://vectors/gen_v3_vectors.json"))
		get_tree().quit()
		return
	rng.seed = 2026
	_setup_env()
	island = IslandScript.new()
	add_child(island)
	island.setup()
	for s in START:
		var b := _make_block(s[1], s[2], "Start: " + s[1])
		b.slot = s[0]
		BlockGen.build(b, island.neighbor_hms(b.slot))
		island.place(b)
		_log_block(b)
	_place_prop()
	ui = UIScript.new()
	add_child(ui)
	ui.candidate_picked.connect(_on_pick)
	ui.settings_changed.connect(_rebuild_preview)
	ui.confirm_pressed.connect(_confirm)
	ui.cancel_pressed.connect(_cancel)
	var bn := []; var bc := []
	for t in BTYPES: bn.append(t.name); bc.append(t.col)
	ui.set_buildings(bn, bc)
	ui.building_picked.connect(_pick_building)
	ui.tab_changed.connect(func(k): if k == 0: _cancel_building())
	inventory.resize(Mat.COUNT)
	candidates = [
		_make_block("louka", 1201, "Louka"),
		_make_block("louka", 1777, "Louka"),
		_make_block("kopec", 2302, "Kopec"),
		_make_block("hora", 1000, "Hora Prvního dne", "pevný"),
		_make_block("piscina", 4504, "Písčina"),
		_make_block("hora", H.named_seed("Grrrrův štít"), "Grrrrův štít", "unikátní"),
	]
	ui.set_candidates(candidates)
	_setup_camera()
	_update_hint()
	ParamRegistry_.register_stat("Instance vegetace (kreslené)", self, &"_veg_instances")
	ParamRegistry_.register_stat("Bloků", self, &"_block_count")
	ParamRegistry_.load_dev_addons(self)   # jen s -- --dev a jen když doplněk existuje (v exportu není)
	if "--genv3-shots" in OS.get_cmdline_user_args() or "--genv3-bench" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/genv3_demo.gd").new())   # gen-v3 v prototypu: screenshoty 41_* / měření
	elif "--flow-shots" in OS.get_cmdline_user_args() or "--flow-bench" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/flow_demo.gd").new())    # tok vody po kopání: screenshoty 42_* / měření
	elif "--skryti-shots" in OS.get_cmdline_user_args() or "--skryti-bench" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/skryti_demo.gd").new())   # skrytí podzemí na bocích a řezech
	elif "--napojeni-shots" in OS.get_cmdline_user_args() or "--napojeni-bench" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/napojeni_demo.gd").new())   # povrch louka/písek/voda: screenshoty / měření
	elif "--grass-shots" in OS.get_cmdline_user_args() or "--grass-bench" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/grass_demo.gd").new())   # tráva C: screenshoty / měření
	elif "--demo" in OS.get_cmdline_user_args():
		_demo()
	elif "--video" in OS.get_cmdline_user_args():
		_video()

func _block_count() -> int:
	return island.blocks.size()

func _veg_instances() -> int:
	var n := 0
	for v in island.vegs.values():
		for c in v.get_children():
			if c is MultiMeshInstance3D and c.multimesh:
				n += c.multimesh.instance_count if c.multimesh.visible_instance_count < 0 else c.multimesh.visible_instance_count
	return n

func _log_block(b: Block) -> void:
	gen_times.append(b.gen_ms)
	mesh_times.append(b.mesh_ms)
	print("blok %s %s seed %d slot %s: generování %.1f ms, mesh %.1f ms" % [b.title, b.kind, b.seed, b.slot, b.gen_ms, b.mesh_ms])

# ---------------------------------------------------------------- vkládání
func _on_pick(i: int) -> void:
	sel = i
	var c: Block = candidates[i]
	preview = _make_block(c.kind, c.seed, c.title, c.category)
	locked_slot = null
	island.hide_preview()
	ui.show_block(null, "", false)
	ui.title_lbl.text = c.title
	ui.info_lbl.text = "Najeď na zvýrazněné místo v mlze a klikni."
	island.show_frames = true
	island.refresh_frames()
	_update_hint()

func _cancel() -> void:
	island.show_frames = false
	island.refresh_frames()
	sel = -1
	preview = null
	locked_slot = null
	island.hide_preview()
	ui.select_card(-1)
	ui.show_block(null, "", false)
	_update_hint()

func _preview_at(s) -> void:
	if preview == null:
		return
	if s == null or not island.is_valid(s):
		if locked_slot == null:
			island.hide_preview()
		return
	if island.preview_block != null and island.preview_block.slot == s and island.preview_mi.visible:
		return
	preview.slot = s
	_rebuild_preview()

func _rebuild_preview() -> void:
	if preview == null or not island.is_valid(preview.slot):
		return
	BlockGen.build(preview, island.neighbor_hms(preview.slot))
	island.show_preview(preview)
	var state := "zvoleno" if locked_slot != null else "náhled"
	ui.show_block(preview, "Místo %s (%s)" % [preview.slot, state], true, island.neighbor_hms(preview.slot))

func _confirm() -> void:
	if preview == null or not island.is_valid(preview.slot) or island.preview_block == null:
		return
	var b := preview
	island.hide_preview()
	island.show_frames = false
	island.place(b)
	_log_block(b)
	# kandidát se spotřeboval, na jeho místo přijde nový běžný blok
	candidates[sel] = _random_candidate()
	ui.set_candidates(candidates)
	sel = -1
	preview = null
	locked_slot = null
	ui.show_block(b, "Vložen na %s" % b.slot, false)
	_update_hint()

func _update_hint() -> void:
	var t := "Q/E otočit · kolečko zoom · WASD / prostřední tlačítko posun · PgUp/PgDn/Home řez · T vzhled · X textury · B hrany"
	t += " · C cesty · M kopání"
	if build_sel >= 0:
		t += "\nSTAVBA %s: klik = postavit na zelené místo (rozdíl ≤ 1 buňka, dveře volné) · R otočit · Esc zrušit" % BTYPES[build_sel].name
	elif dig_mode:
		t += "\nKOPÁNÍ: klik = vykopat vrchní buňku (do inventáře) · Shift+klik = položit z inventáře · 1–9 vybrat materiál · Esc konec"
	elif road_mode:
		t += "\nCESTY: klikni na domek/bod (start), další body = průjezdní body, poslední = cíl · Enter postavit · Esc zrušit · body: %d" % road_pts.size()
	elif preview != null:
		t += "\nR rotace · F zrcadlení · +/− výška · Enter uložit · Esc zrušit"
	ui.set_hint(t)

# ---------------------------------------------------------------- vstup
func _mouse_slot(pos: Vector2):
	return island.slot_at_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if dragging:
			_pan(-e.relative * cam.size / 800.0)
			return
		if build_sel >= 0:
			_build_hover(island.cell_at_ray(cam.project_ray_origin(e.position), cam.project_ray_normal(e.position)))
			return
		var s = _mouse_slot(e.position)
		island.set_hover(s if s != null and island.is_valid(s) and preview != null else null)
		if locked_slot == null:
			_preview_at(s)
	elif e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam.size = maxf(cam.size * 0.9, 18.0); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam.size = minf(cam.size * 1.1, 160.0); _place_camera()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT: dragging = true
			MOUSE_BUTTON_LEFT:
				if road_mode:
					_road_click(e.position)
					return
				if build_sel >= 0:
					_build_click()
					return
				if dig_mode:
					var gd = island.cell_at_ray(cam.project_ray_origin(e.position), cam.project_ray_normal(e.position))
					if gd != null:
						ui.set_hint("M kopání: " + _dig(gd, e.shift_pressed))
					return
				var s = _mouse_slot(e.position)
				if preview != null and s != null and island.is_valid(s):
					locked_slot = s
					preview.slot = s
					_rebuild_preview()
				elif preview == null and s != null and island.blocks.has(s):
					var b: Block = island.blocks[s]
					ui.show_block(b, "Na místě %s" % s, false)
	elif e is InputEventMouseButton and not e.pressed:
		if e.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: yaw += 90; _place_camera()
			KEY_E: yaw -= 90; _place_camera()
			KEY_PAGEDOWN: island.set_slice(40 if island.slice_z < 0 else maxi(island.slice_z - 1, 1))
			KEY_PAGEUP: island.set_slice(island.slice_z + 1 if island.slice_z >= 0 and island.slice_z < 63 else -1)
			KEY_HOME: island.set_slice(-1)
			KEY_T: island.set_kawaii(not island.kawaii); Toon.set_on(island.kawaii)
			KEY_X: island.set_textured(not island.textured)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var li := _inv_list()
				var k: int = e.keycode - KEY_1
				if dig_mode and k < li.size():
					place_mat = li[k]; _refresh_inv()
					ui.set_hint("KOPÁNÍ: k položení vybrán %s · Shift+klik položit" % Mat.NAMES[place_mat])
			KEY_B: island.set_bevel(not island.bevel)
			KEY_R:
				if build_sel >= 0:
					build_rot = (build_rot + 1) % 4
					var mp := get_viewport().get_mouse_position()
					_build_hover(island.cell_at_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp)))
				else:
					_edit(func(): preview.rot = (preview.rot + 1) % 4)
			KEY_M:
				dig_mode = not dig_mode and preview == null
				road_mode = false; _cancel_building()
				_refresh_inv()
				_update_hint()
			KEY_F: _edit(func(): preview.mirror = not preview.mirror)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _edit(func(): preview.shift = mini(preview.shift + 1, 4))
			KEY_MINUS, KEY_KP_SUBTRACT: _edit(func(): preview.shift = maxi(preview.shift - 1, -4))
			KEY_C:
				road_mode = not road_mode and preview == null
				_clear_road_marks(); _update_hint()
			KEY_ENTER, KEY_KP_ENTER:
				if road_mode: _road_finish()
				else: _confirm()
			KEY_ESCAPE:
				if build_sel >= 0:
					_cancel_building()
				elif dig_mode:
					dig_mode = false; _update_hint()
				elif road_mode:
					road_mode = false; _clear_road_marks(); _update_hint()
				else: _cancel()

func _edit(f: Callable) -> void:
	if preview == null:
		return
	f.call()
	_rebuild_preview()

func _process(dt: float) -> void:
	_flow_tick()
	Grass.tick(dt)   # tráva C: čas větru a stopy (postavičky volají Grass.touch)
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if v != Vector2.ZERO:
		_pan(v * dt * cam.size * 0.8)

func _pan(d: Vector2) -> void:
	var r := deg_to_rad(yaw)
	var right := Vector3(cos(r), 0, -sin(r))
	var fwd := Vector3(-sin(r), 0, -cos(r))
	center += right * d.x - fwd * d.y
	_place_camera()

# ---------------------------------------------------------------- scéna
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 66.0
	cam.near = 1.0
	cam.far = 500.0
	add_child(cam)
	_place_camera()

func _place_camera() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0), EULER_ORDER_YXZ)
	cam.transform = Transform3D(basis, center + basis.z * 200.0)
	Grass.update_lod(cam.size)   # tráva C: řidší trsy při oddálení
	# střed scény do volné plochy (vpravo panel 290 px, dole lišta 112 px), aby popisky nezajížděly pod panel
	var k := cam.size / 800.0
	var ui_on: bool = ui != null and ui.visible
	cam.h_offset = 145.0 * k if ui_on else 0.0
	cam.v_offset = -56.0 * k if ui_on else 0.0

func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)

## volitelný testovací domek z Blenderu (assets/domek.glb), načtený za běhu bez importu
func _place_prop() -> void:
	_add_house(Vector2i(6, 8))

## stavby: domek, studna, mlýn, políčko (Blender). Půdorys size × size kolem středu, dveře před přední stranou (+z, otočené o rot·90°).
const BTYPES := [
	{"name": "Domek", "glb": "domek", "size": 3, "col": Color(0.95, 0.70, 0.80)},
	{"name": "Studna", "glb": "studna", "size": 1, "col": Color(0.70, 0.82, 0.98)},
	{"name": "Větrný mlýn", "glb": "mlyn", "size": 3, "col": Color(0.98, 0.90, 0.75)},
	{"name": "Políčko", "glb": "pole", "size": 3, "col": Color(0.75, 0.92, 0.65)},
]
var bdata := {}          # střed -> {t, rot}
var _bscenes := {}       # typ -> [GLTFDocument, GLTFState]

func _fp_of(c: Vector2i, t: int) -> Array:
	var hs: int = BTYPES[t].size / 2
	var out := []
	for dx in range(-hs, hs + 1):
		for dz in range(-hs, hs + 1):
			out.append(c + Vector2i(dx, dz))
	return out

func _door_of(c: Vector2i, t: int, rot: int) -> Vector2i:
	var o := Vector2i(0, BTYPES[t].size / 2 + 1)
	for i in rot:
		o = Vector2i(-o.y, o.x)
	return c + o

func _fp(c: Vector2i) -> Array:
	return _fp_of(c, bdata[c].t if bdata.has(c) else 0)

func _door(c: Vector2i) -> Vector2i:
	return _door_of(c, bdata[c].t if bdata.has(c) else 0, bdata[c].rot if bdata.has(c) else 0)

func _bscene(t: int) -> Node3D:
	if not _bscenes.has(t):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/%s.glb" % BTYPES[t].glb), "res://assets/", st) != OK:
			push_warning("%s.glb se nepodařilo načíst" % BTYPES[t].glb)
			return null
		_bscenes[t] = [doc, st]
	var node: Node3D = _bscenes[t][0].generate_scene(_bscenes[t][1])
	Toon.apply_to(node, 0.035)
	return node

## stavba stojí na nejvyšší buňce pod půdorysem
func _add_house(c: Vector2i) -> void:
	_add_building(c, 0, 0)

func _add_building(c: Vector2i, t: int, rot: int) -> void:
	var node := _bscene(t)
	if node == null:
		return
	var top := 0
	for f in _fp_of(c, t):
		top = maxi(top, Roads.height(island, f))
		island.occupied[f] = true
	node.position = Vector3(c.x + 0.5, top * 0.5, c.y + 0.5)
	node.rotation.y = deg_to_rad(-90.0 * rot)
	island.add_child(node)
	island.props.append(node)
	houses.append(c)
	bdata[c] = {"t": t, "rot": rot}
	island.refresh_blocks(_slots_of(_fp_of(c, t)))   # povrch pod stavbou je na buňkách

## místo pro stavbu: půdorys v ostrově, volný, rozdíl výšek ≤ 1, dveře volné a nejvýš o 1 buňku jinde
func _site_ok(c: Vector2i, t: int, rot: int) -> bool:
	var lo := 999; var hi := -1
	for f in _fp_of(c, t):
		var h := Roads.height(island, f)
		if h < 0 or island.occupied.has(f):
			return false
		lo = mini(lo, h); hi = maxi(hi, h)
	var fp := _fp_of(c, t)
	for h in houses:   # nezastavět dveře jiné stavby
		if fp.has(_door(h)):
			return false
	var dc := _door_of(c, t, rot)
	var dh := Roads.height(island, dc)
	return hi - lo <= 1 and dh >= 0 and not island.occupied.has(dc) and absi(dh - hi) <= 1

func _slots_of(cells: Array) -> Array:
	var out := []
	for g in cells:
		var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
		if not out.has(s):
			out.append(s)
	return out

## nejbližší rovné místo pro domek ve slotu (rozdíl výšek půdorysu ≤ 1, dveře dosažitelné)
func _find_site(slot: Vector2i, reach := {}, t := 0, rot := 0) -> Variant:
	var best = null
	var bd := 1e9
	for lx in range(2, 14):
		for ly in range(2, 12):
			var c := slot * BS + Vector2i(lx, ly)
			if not _site_ok(c, t, rot):
				continue
			if not reach.is_empty() and not reach.has(_door_of(c, t, rot)):
				continue
			var d := Vector2(lx - 7.5, ly - 7.0).length()
			if d < bd:
				bd = d; best = c
	return best

## trasa přes zadané body; začátek/konec na domku se přichytí ke dveřím
func _build_road(pts: Array) -> bool:
	var snapped := []
	for p in pts:
		snapped.append(_snap_to_door(p))
	var blocked := {}
	for h in houses:
		for f in _fp(h):
			blocked[f] = true
	var path := Roads.route(island, snapped, blocked)
	if path.is_empty():
		return false
	last_road = path
	var layer := Roads.build_layer(island, path)
	island.add_child(layer)
	island.roads.append(layer)
	for g in path:
		island.occupied[g] = true
	island.refresh_blocks(_slots_of(path))   # povrch pod cestou je na buňkách
	return true

func _snap_to_door(g: Vector2i) -> Vector2i:
	for h in houses:
		if _fp(h).has(g):
			return _door(h)
	return g

func _building_at(g: Vector2i):
	for h in houses:
		if _fp(h).has(g):
			return h
	return null

# ---------------------------------------------------------------- kopání a stavění (M)
## kop = odebere nejvyšší buňku sloupce (do inventáře); place = položí materiál z inventáře na vrch.
## Materiál se zachovává (inventář), změny se zapisují jako delta (index buňky, starý/nový materiál).
func _dig(g: Vector2i, place := false, mat := -1) -> String:
	var sl := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(sl):
		return "mlha: kopat ani stavět nelze"
	if island.occupied.has(g):
		return "pod stavbou nebo cestou: nelze"
	var b: Block = island.blocks[sl]
	_flow_finish_all()   # rozběhnutý tok se před další změnou dokončí (výsledek nezávisí na snímcích)
	var lx := g.x - sl.x * BS
	var ly := g.y - sl.y * BS
	var h: int = b.hm[lx * BS + ly]
	var lz: int
	var old: int
	var nw: int
	if place:
		if mat < 0 and place_mat >= 0 and inventory[place_mat] > 0:
			mat = place_mat
		if mat < 0:
			for m in range(1, Mat.COUNT):
				if inventory[m] > 0: mat = m; break
		if mat < 0 or inventory[mat] <= 0:
			return "inventář je prázdný"
		if h >= 64:
			return "strop bloku (lz 63)"
		lz = h; old = b.cells[(lx * BS + ly) * 64 + lz]; nw = mat
		inventory[mat] -= 1
		b.hm[lx * BS + ly] = h + 1
	else:
		if h <= 0:
			return "dno bloku: pod lz 0 kopat nelze"
		lz = h - 1; old = b.cells[(lx * BS + ly) * 64 + lz]; nw = Mat.AIR
		if old == Mat.FOG or old == Mat.AIR:
			return "nelze"
		inventory[old] += 1
		# gen-v3: pod vykopanou buňkou může být jeskyně – povrch sloupce klesne na její dno (jeskyně se tím odkryje)
		var nh := h - 1
		while nh > 0 and b.cells[(lx * BS + ly) * 64 + nh - 1] == Mat.AIR:
			nh -= 1
		b.hm[lx * BS + ly] = nh
	var idx := (lx * BS + ly) * 64 + lz
	b.cells[idx] = nw
	var w_old := 0
	if b.water.size() == b.cells.size():
		w_old = b.water[idx]; b.water[idx] = 0   # voda v pórech odejde s materiálem (bez simulace; položená buňka je suchá)
	if not deltas.has(sl): deltas[sl] = []
	var dl := {"i": idx, "lx": lx, "ly": ly, "lz": lz, "old": old, "new": nw}
	if w_old > 0: dl["water_old"] = w_old
	deltas[sl].append(dl)
	b.recount()
	if not place:
		var f = WaterFlow.start(b, lx, ly, lz)   # Jan 20:39: místní tok vody po otevření (jeskyně, nasycená půda)
		if f != null:
			flows.append({"slot": sl, "flow": f, "delta": dl, "w_old": w_old, "sync": flow_sync})
			if flow_sync:
				_flow_finish_all()
	var kept := []
	for r in b.veg:   # rostlina na změněném sloupci zmizí
		if not (r.lx == lx and r.ly == ly): kept.append(r)
	b.veg = kept
	b.veg_summary = VegG.summary(b.veg)
	island.refresh_after_edit(sl, lx, ly)   # kostky, duální povrch a vegetace bloku (a sousedů u hrany)
	_show_block_at(g)
	_refresh_inv()
	return "%s %s (lz %d)" % ["položeno" if place else "vykopáno", Mat.NAMES[nw if place else old], lz]

## ---------- tok vody po kopání (scripts/gen3/water_flow.gd) ----------
## ve hře: _process posouvá tok po FLOW_BUDGET_MS za snímek a překresluje jen vodu; headless (flow_sync) se dopočítá hned
func _flow_tick() -> void:
	if flows.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var e: Dictionary = flows[0]
	while not e.flow.done and (Time.get_ticks_usec() - t0) < FLOW_BUDGET_MS * 1000:
		e.flow.step_n(4)
	if e.flow.done:
		_flow_finish(e)
		flows.pop_front()
	else:
		e.flow.write_preview()
		island.remesh_water(e.slot)

func _flow_finish_all() -> void:
	while not flows.is_empty():
		_flow_finish(flows.pop_front())

## konečný zápis (zachování součtu), kontrola jako delta, záznam do delty kopání
func _flow_finish(e: Dictionary) -> void:
	var f = e.flow
	f.finish()
	var v: Dictionary = WaterFlow.validate(f)
	last_flow = {"slot": e.slot, "box": f.box(), "ticks": f.ticks, "ms": f.ms, "cells": f.box_cells(), "valid": v}
	if not v.ok:
		push_warning("tok vody: kontrola delty selhala %s" % str(v.errors))
	e.delta["flow"] = {"box": f.box(), "ticks": f.ticks, "moved_units": v.moved_units, "water": f.changes()}
	if not e.get("sync", false):
		island._remesh(e.slot)   # mokrá půda a voda z dat (při synchronním toku překreslí kopání samo)

## ukázka formátu delty pro backend -> vectors/delta_sample.json
func _export_deltas(path: String) -> void:
	var blocks := []
	for sl in deltas:
		var b: Block = island.blocks[sl]
		var base := b.cells.duplicate()
		var ops: Array = deltas[sl]
		for k in range(ops.size() - 1, -1, -1):   # zpětně: původní objem bloku
			base[ops[k].i] = ops[k].old
		var out_ops := []
		for o in ops:
			out_ops.append({"i": o.i, "lx": o.lx, "ly": o.ly, "lz": o.lz, "old": o.old, "new": o.new,
				"oldName": Mat.NAMES[o.old], "newName": Mat.NAMES[o.new]})
		blocks.append({
			"slot": [sl.x, sl.y], "recipe": b.kind, "seed": b.seed,
			"transform": {"mirror": b.mirror, "rotation": b.rot * 90, "heightShift": b.shift},
			"sides": _sides_json(b.sides),
			"neighborEdgeProfiles": _edges_json(b.edge_profiles),
			"placedVolumeHash": H.hex(H.fnv1a64_bytes(base)),
			"resultVolumeHash": H.hex(H.fnv1a64_bytes(b.cells)),
			"ops": out_ops,
		})
	var inv := {}
	for m in range(1, Mat.COUNT):
		if inventory[m] > 0: inv[Mat.NAMES[m]] = inventory[m]
	var doc := {
		"deltaFormat": "delta-v0",
		"generatorVersion": "proto-v2.2",
		"cellIndex": "i = (lx*16+ly)*64+lz; materials: 0 air .. 10 snow, 11 fog",
		"semantics": "Baseline = volume right after placement: regenerate from recipe+seed, apply transform (mirror, rotation, heightShift), then side blending using sides + neighborEdgeProfiles stored at placement time (later changes to neighbours do not affect it). placedVolumeHash = FNV-1a 64 of the 16384 bytes of that baseline (check). ops apply in order; old must match current cell, else reject. resultVolumeHash = after all ops.",
		"edgeProfileOrder": "neighborEdgeProfiles keys N,E,S,W (DIRS (0,-1),(1,0),(0,1),(-1,0)); 16 surface heights of the neighbour cells touching the shared edge, index t along the edge (t = lx for N/S edges, t = ly for E/W edges, in the new block's coordinates); null = no neighbour",
		"sidesValues": "auto | blend1..blend4 | keep",
		"islandInventory": inv,
		"blocks": blocks,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	print("delta: uloženo ", path)

func _sides_json(sd: PackedInt32Array) -> Dictionary:
	var k := ["N", "E", "S", "W"]
	var out := {}
	for i in 4:
		out[k[i]] = "auto" if sd[i] == 0 else ("keep" if sd[i] == 5 else "blend%d" % sd[i])
	return out

func _edges_json(ep: Array) -> Dictionary:
	var k := ["N", "E", "S", "W"]
	var out := {}
	for i in 4:
		out[k[i]] = null if ep[i] == null else Array(ep[i])
	return out

## panel vpravo: blok pod sloupcem g (případně stavba na něm)
func _show_block_at(g: Vector2i) -> void:
	var sl := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(sl):
		return
	var b: Block = island.blocks[sl]
	var n := 0
	if deltas.has(sl): n = deltas[sl].size()
	ui.delta_txt = "\nZměny v bloku (delta): %d" % n if n > 0 else ""
	var txt := "Sloupec (%d, %d) v bloku %s" % [g.x - sl.x * BS, g.y - sl.y * BS, sl]
	var bh = _building_at(g)
	if bh != null:
		txt = "Stavba: %s · %s" % [BTYPES[bdata[bh].t].name, txt]
	elif island.occupied.has(g):
		txt = "Cesta · " + txt
	ui.show_block(b, txt, false)

# ---------------------------------------------------------------- stavby z lišty
func _pick_building(i: int) -> void:
	_cancel()
	road_mode = false; dig_mode = false
	build_sel = i
	ui.select_building(i)
	if build_ghost: build_ghost.queue_free()
	build_ghost = _bscene(i)
	if build_ghost == null:
		build_sel = -1
		return
	build_ghost.visible = false
	_ghostify(build_ghost)
	island.add_child(build_ghost)
	if build_mark == null:
		build_mark = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		build_mark.mesh = pm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		build_mark.material_override = mm
		island.add_child(build_mark)
	build_mark.visible = false
	_update_hint()

var ghost_mat: StandardMaterial3D
func _ghostify(n: Node) -> void:
	if ghost_mat == null:
		ghost_mat = StandardMaterial3D.new()
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if n is MeshInstance3D:
		n.material_override = ghost_mat
		n.material_overlay = null
		for i in n.get_surface_override_material_count():
			n.set_surface_override_material(i, null)
	for c in n.get_children():
		_ghostify(c)

func _build_hover(g) -> void:
	if build_sel < 0 or build_ghost == null:
		return
	build_at = g
	if g == null:
		build_ghost.visible = false; build_mark.visible = false
		return
	var top := 0
	for f in _fp_of(g, build_sel):
		top = maxi(top, Roads.height(island, f))
	var ok := _site_ok(g, build_sel, build_rot)
	build_ghost.visible = true
	build_ghost.position = Vector3(g.x + 0.5, top * 0.5, g.y + 0.5)
	build_ghost.rotation.y = deg_to_rad(-90.0 * build_rot)
	var sz: int = BTYPES[build_sel].size
	(build_mark.mesh as PlaneMesh).size = Vector2(sz + 0.8, sz + 0.8)
	build_mark.position = Vector3(g.x + 0.5, top * 0.5 + 0.06, g.y + 0.5)
	(build_mark.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.95, 0.55, 0.55) if ok else Color(1.0, 0.40, 0.45, 0.55)
	ghost_mat.albedo_color = Color(0.55, 1.0, 0.65, 0.6) if ok else Color(1.0, 0.45, 0.5, 0.6)
	build_mark.visible = true

func _build_click() -> void:
	if build_at != null and _site_ok(build_at, build_sel, build_rot):
		_add_building(build_at, build_sel, build_rot)
		_show_block_at(build_at)
		_cancel_building()

func _cancel_building() -> void:
	build_sel = -1
	build_at = null
	if build_ghost: build_ghost.queue_free(); build_ghost = null
	if build_mark: build_mark.visible = false
	if ui: ui.select_building(-1)
	_update_hint()

func _road_click(pos: Vector2) -> void:
	var g = island.cell_at_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
	if g == null:
		return
	_show_block_at(g)
	g = _snap_to_door(g)
	road_pts.append(g)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3; sm.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.75) if road_pts.size() == 1 else Color(1.0, 0.85, 0.4)
	sm.material = mat
	m.mesh = sm
	m.position = Vector3(g.x + 0.5, Roads.height(island, g) * 0.5 + 0.4, g.y + 0.5)
	island.add_child(m)
	road_marks.append(m)
	_update_hint()

func _road_finish() -> void:
	if road_pts.size() >= 2:
		if not _build_road(road_pts):
			ui.set_hint("Cesta neexistuje: v cestě je útes (krok > 1 buňka), mlha nebo mezera. C nový pokus")
			_clear_road_marks()
			return
	_clear_road_marks()
	_update_hint()

func _clear_road_marks() -> void:
	for m in road_marks:
		m.queue_free()
	road_marks.clear()
	road_pts.clear()

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
	dig_mode = true
	yaw = 315.0; pitch = -52.0; center = Vector3(pit.x + 0.5, Roads.height(island, pit) * 0.5, pit.y + 0.5); cam.size = 13.0; _place_camera()
	_show_block_at(pit)
	ui.set_inventory(inventory, "(M kopání)")
	_update_hint()
	await _snap("21a_pred_kopanim.png")
	var b: Block = island.blocks[Vector2i(floori(pit.x / 16.0), floori(pit.y / 16.0))]
	var r0 := Mat.score_of(b.summary)
	var msg := ""
	for k in 6:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				msg = _dig(pit + Vector2i(dx, dz))
	var li := _inv_list()
	place_mat = Mat.LIMESTONE if inventory[Mat.LIMESTONE] > 0 else li[0]   # jako klávesa 1–9
	for dz in range(-1, 2):
		msg = _dig(pit + Vector2i(-1, dz), true)
	# zakázané případy
	var fog := Vector2i(-40, -40)
	print("kopání: jáma u ", pit, ", poslední: ", msg, "; skóre ", r0, " -> ", Mat.score_of(b.summary),
		"; mlha: ", _dig(fog), "; pod cestou: ", _dig(last_road[0]) if not last_road.is_empty() else "-")
	ui.set_hint("KOPÁNÍ: " + msg + " · Shift+klik položit · Esc konec")
	await _snap("21b_po_kopani.png")
	_export_deltas(_out_dir("vectors") + "delta_sample.json")
	dig_mode = false; pitch = -35.0
	_update_hint()

## stavby z lišty: studna, mlýn, políčko + cesty k jejich dveřím, náhled domku (zelený = lze postavit)
func _demo_buildings() -> void:
	ui.show_tab(1)
	var reach := Roads.reachable(island, _door(houses[0]), island.occupied)
	var placed := []
	for spec in [[1, Vector2i(0, 1), 0], [2, Vector2i(1, 1), 1], [3, Vector2i(0, 1), 0]]:
		var c = _find_site(spec[1], reach, spec[0], spec[2])
		if c == null:
			for sl in island.blocks:
				c = _find_site(sl, reach, spec[0], spec[2])
				if c != null: break
		print("stavba ", BTYPES[spec[0]].name, ": ", c)
		if c != null:
			_add_building(c, spec[0], spec[2])
			placed.append(c)
			reach = Roads.reachable(island, _door(houses[0]), island.occupied)
	for c in placed:
		print("cesta k ", BTYPES[bdata[c].t].name, ": ", _build_road([houses[0], c]))
	yaw = 315.0; center = Vector3(15, 16, 21); cam.size = 26.0; _place_camera()
	_pick_building(0)
	var hv = _find_site(Vector2i(0, 1), {}, 0, 0)
	if hv == null: hv = _find_site(Vector2i(1, 1), {}, 0, 0)
	_build_hover(hv)
	if hv != null:
		_show_block_at(hv)
		var wc: Vector2i = placed[0] if placed.size() > 0 else hv
		yaw = 30.0
		center = Vector3((hv.x + wc.x) * 0.5 + 2.5, Roads.height(island, hv) * 0.5, (hv.y + wc.y) * 0.5 + 0.5); _place_camera()
	var bl := []
	for h in houses: bl.append("%s %s" % [BTYPES[bdata[h].t].name, h])
	print("stavby: ", ", ".join(bl), "; náhled domku na ", hv)
	await _snap("22_stavby.png")
	yaw = 315.0
	_cancel_building()
	ui.show_tab(0)

## cesty: 2 další domky, trasy mezi nimi, test pickingu sloupce myší a test nedosažitelného cíle
func _demo_roads() -> void:
	var reach := Roads.reachable(island, _door(houses[0]), island.occupied)
	for slot in [Vector2i(1, 1), Vector2i(0, 1)]:
		var c = _find_site(slot, reach)
		print("domek ve slotu ", slot, ": ", c)
		if c != null:
			_add_house(c)
	# picking: klik na promítnutý střed sloupce musí vrátit týž sloupec
	var probe: Vector2i = _door(houses[0]) + Vector2i(0, 1)
	var sp := cam.unproject_position(Vector3(probe.x + 0.5, Roads.height(island, probe) * 0.5, probe.y + 0.5))
	var got = island.cell_at_ray(cam.project_ray_origin(sp), cam.project_ray_normal(sp))
	print("SELFTEST cesty picking: ", "OK" if got == probe else "CHYBA %s != %s" % [got, probe])
	var t := Time.get_ticks_usec()
	var ok1 := houses.size() > 1 and _build_road([houses[0], houses[1]])
	var ok2 := houses.size() > 2 and _build_road([houses[0], houses[0] + Vector2i(-2, 6), houses[2]])
	print("cesty: domek0->domek1 %s, domek0->bod->domek2 %s (%.1f ms)" % [ok1, ok2, (Time.get_ticks_usec() - t) / 1000.0])
	# útes > 4 buňky: najdi sloupec, kam se ze dveří nedá dojít ani se schody, a ověř, že A* cestu nenajde
	var hb := {}
	for hh in houses:
		for f in _fp(hh): hb[f] = true
	var rr := Roads.reachable(island, _door(houses[0]), hb)
	var unreach := 0; var sample = null
	for sl in island.blocks:
		for lx in BS:
			for ly in BS:
				var g: Vector2i = sl * BS + Vector2i(lx, ly)
				if not rr.has(g) and not hb.has(g) and Roads.height(island, g) > 0:
					unreach += 1
					if sample == null: sample = g
	if sample != null:
		var p := Roads.find(island, _door(houses[0]), sample, hb)
		print("SELFTEST cesty útes: nedosažitelných sloupců %d, A* k %s: %s" % [unreach, sample, "nenalezena OK" if p.is_empty() else "CHYBA nalezena"])
	# cesta na terasu: nejvyšší sloupec kopce (0,1) dosažitelný s krokem ≤ 4, který s krokem ≤ 1 dosažitelný není
	var blocked := {}
	for hh in houses:
		for f in _fp(hh): blocked[f] = true
	var r4 := Roads.reachable(island, _door(houses[0]), blocked)
	var best := Vector2i(-999, -999); var bh := -1
	for g in r4:
		if Vector2i(floori(g.x / 16.0), floori(g.y / 16.0)) in [Vector2i(0, 1), Vector2i(1, 0)]:
			var hg := Roads.height(island, g)
			if hg > bh: bh = hg; best = g
	var ok3 := bh > 0 and _build_road([houses[0], best])
	var st_at = null
	for i in range(1, last_road.size()):
		if absi(Roads.height(island, last_road[i]) - Roads.height(island, last_road[i - 1])) >= Roads.STAIR_FROM:
			st_at = last_road[i - 1] if Roads.height(island, last_road[i - 1]) < Roads.height(island, last_road[i]) else last_road[i]
			break
	var nst := 0; var nsp := 0; var nmg := 0
	for r in island.roads:
		nst += int(r.get_meta("stairs", 0)); nsp += int(r.get_meta("spread", 0)); nmg += int(r.get_meta("merged", 0))
	print("schody: celkem %d, roztažené na 2 sloupce %d, sloučená údolí %d" % [nst, nsp, nmg])
	print("cesta na terasu ", best, " (hm ", bh, "): ", ok3, ", schodů na ostrově celkem ", nst, ", první schody u ", st_at)
	yaw = 315.0; center = Vector3(18, 21, 13); cam.size = 52.0; _place_camera()
	ui.set_hint("CESTY: klikni na domek/bod (start), další body = průjezdní, poslední = cíl · Enter postavit · Esc zrušit")
	await _snap("15_cesty.png")
	if st_at != null:
		yaw = 225.0
		center = Vector3(st_at.x + 2.5, Roads.height(island, st_at) * 0.5 + 3.0, st_at.y + 0.5); cam.size = 16.0; _place_camera()
		_show_block_at(st_at)
		await _snap("17_schody_detail.png")
		yaw = 315.0; center = Vector3(18, 21, 13); cam.size = 52.0; _place_camera()
	await _demo_dig()
	await _demo_buildings()
	# objekty: kawaii vyp / zap (stejný záběr)
	var h0: Vector2i = houses[0]
	center = Vector3(h0.x + 2.0, Roads.height(island, h0) * 0.5 + 1.0, h0.y + 3.0); cam.size = 16.0; _place_camera()
	island.set_kawaii(false); Toon.set_on(false)
	await _snap("18a_objekty_plochy.png")
	island.set_kawaii(true); Toon.set_on(true)
	await _snap("18b_objekty_kawaii.png")
	cam.size = 9.0; _place_camera()
	island.set_bevel(true)
	await _snap("19b_hrany_zaoblene.png")
	island.set_bevel(false)
	await _snap("19a_hrany_ostre.png")
	# hero: ostrov doplněný o další bloky (auto napojení), bez UI
	for e in [[Vector2i(0, 2), "piscina", 4504], [Vector2i(-1, 1), "louka", 1777], [Vector2i(1, 2), "kopec", 2302], [Vector2i(2, 0), "kopec", 2302]]:
		if island.is_valid(e[0]):
			var nb := _make_block(e[1], e[2], "hero")
			nb.slot = e[0]
			BlockGen.build(nb, island.neighbor_hms(nb.slot))
			island.place(nb)
	var hs = _find_site(Vector2i(-1, 1), Roads.reachable(island, _door(houses[2]), island.occupied))
	if hs != null:
		_add_house(hs)
		_build_road([houses[2], hs])
	ui.visible = false
	yaw = 315.0; pitch = -32.0; center = Vector3(16, 14, 26); cam.size = 58.0; _place_camera()
	await _snap("20_hero.png")
	island.set_bevel(true)
	await _snap("20b_hero_hrany.png")
	island.set_bevel(false)
	island.set_textured(true)
	await _snap("20c_hero_textury.png")
	island.set_textured(false)
	ui.visible = true; pitch = -35.0
	yaw = 315.0; center = Vector3(18, 21, 13); cam.size = 52.0; _place_camera()
	island.set_textured(true)
	await _snap("16_textury.png")
	center = Vector3(7, 17, 9); cam.size = 24.0; _place_camera()
	await _snap("16b_textury_detail.png")
	island.set_textured(false)
	yaw = 45.0
	_update_hint()

## simulovaná myš: výběr kandidáta, najetí na platný slot, klik, R, Enter
func _selftest_mouse() -> void:
	yaw = 45.0; center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; _place_camera()
	await get_tree().process_frame
	_on_pick(2)
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
	add_child(g)
	for i in items.size():
		var b := _make_block(items[i][0], items[i][1], "")
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
	yaw = 45.0; pitch = -30.0; center = Vector3(36, 14, 22) if items.size() > 4 else Vector3(20, 16, 20); cam.size = size; _place_camera()
	await _snap(fname)
	g.queue_free()
	island.visible = true
	ui.visible = true
	pitch = -35.0

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

## glTF materiály z Blenderu: bez lesku, o kousek tmavší (jinak jsou ve scéně přesvícené)
static func tame_materials(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var c: StandardMaterial3D = m.duplicate()
				c.albedo_color = c.albedo_color.darkened(0.18)
				c.roughness = 1.0
				c.metallic = 0.0
				c.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				n.set_surface_override_material(i, c)
	for ch in n.get_children():
		tame_materials(ch)

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
	_on_pick(5)
	locked_slot = Vector2i(2, 0)
	preview.slot = locked_slot
	preview.mirror = true
	preview.rot = 1
	preview.shift = 2
	island.set_hover(locked_slot)
	_rebuild_preview()
	await _snap("02_nahled_hora.png")
	_confirm()
	# louka níž (−3) mezi horou a startovní loukou: západ dorovnat 4, sever ponechat (útes)
	ui.select_card(0)
	_on_pick(0)
	locked_slot = Vector2i(2, 1)
	preview.slot = locked_slot
	preview.shift = -3
	preview.sides = PackedInt32Array([5, 0, 0, 4])
	island.set_hover(locked_slot)
	_rebuild_preview()
	await _snap("03_nahled_louka.png")
	_confirm()
	_print_edges(island.blocks[Vector2i(2, 1)])
	ui.show_block(island.blocks[Vector2i(2, 1)], "Vložen na (2, 1)", false)
	await _snap("04_vlozeno.png")
	center = Vector3(40, 15, 22); cam.size = 46.0; _place_camera()
	await _snap("05_detail_hran.png")
	yaw = 135.0; _place_camera()
	await _snap("06_detail_otoceno.png")
	yaw = 45.0; center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; _place_camera()
	center = Vector3(7, 17, 9); cam.size = 24.0; _place_camera()
	island.set_kawaii(false); Toon.set_on(false)
	await _snap("14a_plochy.png")
	island.set_kawaii(true); Toon.set_on(true)
	await _snap("07_domek.png")
	center = Vector3(BS * 1.2, 15.0, BS * 1.2); cam.size = 66.0; _place_camera()
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
	for t in gen_times: g += t
	for t in mesh_times: m += t
	print("PRŮMĚR na blok: generování %.1f ms, mesh %.1f ms (%d bloků)" % [g / gen_times.size(), m / mesh_times.size(), gen_times.size()])
	get_tree().quit()

# ---------------------------------------------------------------- video (-- --video, natáčí se přes --write-movie --fixed-fps 30)
var _vframe := 0
func _vwait(sec: float) -> void:
	for i in maxi(1, int(round(sec * 30.0))):
		await get_tree().process_frame
		_vframe += 1

## plynulý přesun kamery (smoothstep), délka v sekundách při 30 fps
func _cam_to(c: Vector3, s: float, y: float, p: float, dur: float) -> void:
	var c0 := center; var s0 := cam.size; var y0 := yaw; var p0 := pitch
	var n := maxi(1, int(round(dur * 30.0)))
	for i in n:
		var t := float(i + 1) / n
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		center = c0.lerp(c, t); cam.size = lerpf(s0, s, t); yaw = lerpf(y0, y, t); pitch = lerpf(p0, p, t)
		_place_camera()
		await get_tree().process_frame
		_vframe += 1

func _vmark(name: String) -> void:
	print("VIDEO úsek ", name, " od snímku ", _vframe, " (", "%.2f" % (_vframe / 30.0), " s)")

func _hpos(g: Vector2i, up := 0.0) -> Vector3:
	return Vector3(g.x + 0.5, Roads.height(island, g) * 0.5 + up, g.y + 0.5)

func _video() -> void:
	# 1) startovní ostrov, pomalý oblet
	_vmark("start")
	yaw = 20.0; pitch = -33.0; cam.size = 70.0; _place_camera()
	await _vwait(0.4)
	await _cam_to(center, 64.0, 60.0, -35.0, 3.6)
	# 2) vložení bloku: unikátní hora, rotace, zrcadlení, posun výšky
	_vmark("vkládání")
	ui.select_card(5); _on_pick(5)
	await _vwait(0.6)
	locked_slot = Vector2i(2, 0); preview.slot = locked_slot
	island.set_hover(locked_slot); _rebuild_preview()
	await _cam_to(Vector3(30, 15, 16), 62.0, 45.0, -35.0, 1.2)
	var steps := [func(): preview.rot = 1, func(): preview.rot = 2, func(): preview.mirror = true, func(): preview.shift = 1, func(): preview.shift = 2]
	for st in steps:
		st.call(); _rebuild_preview(); _update_hint()
		await _vwait(0.75)
	_confirm()
	await _vwait(0.6)
	# 3) terasy: louka níž (−3) se západním dorovnáním
	_vmark("terasy")
	ui.select_card(0); _on_pick(0)
	locked_slot = Vector2i(2, 1); preview.slot = locked_slot
	preview.shift = -3; preview.sides = PackedInt32Array([5, 0, 0, 4])
	island.set_hover(locked_slot); _rebuild_preview()
	await _cam_to(Vector3(34, 15, 24), 56.0, 45.0, -35.0, 1.0)
	await _vwait(0.5)
	_confirm()
	await _cam_to(_hpos(Vector2i(8, 24), 2.0), 26.0, 20.0, -30.0, 2.2)
	await _vwait(0.4)
	# 4) vegetace ve větru: detail u domku, pomalý drift
	_vmark("vítr")
	var hp := _hpos(houses[0], 1.0)
	await _cam_to(hp + Vector3(1, 0, -1), 12.0, 25.0, -28.0, 1.6)
	await _cam_to(hp + Vector3(2, 0, 0), 10.5, 45.0, -26.0, 3.6)
	# 5) cesty se schody
	_vmark("cesty")
	ui.set_hint("CESTY: klikni na domek/bod (start), další body = průjezdní, poslední = cíl · Enter postavit · Esc zrušit")
	var reach := Roads.reachable(island, _door(houses[0]), island.occupied)
	for slot in [Vector2i(1, 1), Vector2i(0, 1)]:
		var c = _find_site(slot, reach)
		if c != null: _add_house(c)
	await _cam_to(Vector3(18, 21, 13), 50.0, -45.0, -35.0, 2.2)
	if houses.size() > 1: _build_road([houses[0], houses[1]])
	await _vwait(0.7)
	if houses.size() > 2: _build_road([houses[0], houses[0] + Vector2i(-2, 6), houses[2]])
	await _vwait(0.7)
	var blocked := {}
	for hh in houses:
		for f in _fp(hh): blocked[f] = true
	var r4 := Roads.reachable(island, _door(houses[0]), blocked)
	var best := Vector2i(-999, -999); var bh := -1
	for g in r4:
		if Vector2i(floori(g.x / 16.0), floori(g.y / 16.0)) in [Vector2i(0, 1), Vector2i(1, 0)]:
			var hg := Roads.height(island, g)
			if hg > bh: bh = hg; best = g
	if bh > 0: _build_road([houses[0], best])
	var st_at = null
	for i in range(1, last_road.size()):
		if absi(Roads.height(island, last_road[i]) - Roads.height(island, last_road[i - 1])) >= Roads.STAIR_FROM:
			st_at = last_road[i - 1] if Roads.height(island, last_road[i - 1]) < Roads.height(island, last_road[i]) else last_road[i]
			break
	await _vwait(0.6)
	if st_at != null:
		_vmark("schody")
		await _cam_to(_hpos(st_at, 3.0) + Vector3(2, 0, 0), 16.0, -135.0, -35.0, 2.4)
		_show_block_at(st_at)
		await _cam_to(_hpos(st_at, 3.0) + Vector3(1, 0, 1), 14.0, -120.0, -33.0, 2.0)
	# 6) stavby z lišty: náhled jede za myší, zelená = lze postavit
	_vmark("stavby")
	ui.show_tab(1)
	reach = Roads.reachable(island, _door(houses[0]), island.occupied)
	var site = _find_site(Vector2i(1, 1), reach, 2, 0)
	if site == null: site = _find_site(Vector2i(0, 1), reach, 2, 0)
	if site != null:
		await _cam_to(_hpos(site, 1.5), 22.0, -45.0, -38.0, 2.0)
		_pick_building(2)
		for k in range(-5, 1):
			_build_hover(site + Vector2i(k, -absi(k) / 2))
			await _vwait(0.25)
		await _vwait(0.4)
		_build_click()
		_build_road([houses[0], site])
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
						if island.occupied.has(g) or _building_at(g) != null or Roads.height(island, g) < 8: ok = false
				if ok and pit == null: pit = c
	if pit != null:
		dig_mode = true
		ui.set_inventory(inventory, "(M kopání)")
		_update_hint()
		await _cam_to(_hpos(pit), 14.0, -45.0, -50.0, 2.0)
		for k in 5:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_dig(pit + Vector2i(dx, dz))
					await _vwait(0.067)
		var li := _inv_list()
		place_mat = Mat.LIMESTONE if inventory[Mat.LIMESTONE] > 0 else li[0]
		_refresh_inv()
		await _vwait(0.5)
		for dz in range(-1, 2):
			ui.set_hint("KOPÁNÍ: " + _dig(pit + Vector2i(-1, dz), true) + " · Shift+klik položit · 1–9 materiál · Esc konec")
			await _vwait(0.35)
		await _vwait(0.6)
		dig_mode = false
		_update_hint()
	# 8) závěr: odjezd na celek
	_vmark("závěr")
	await _cam_to(Vector3(20, 15, 18), 66.0, 0.0, -35.0, 3.2)
	await _vwait(0.8)
	_vmark("konec")
	get_tree().quit()
