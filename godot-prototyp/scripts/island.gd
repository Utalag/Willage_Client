extends Node3D
## Ostrov: sloty v přibližném kruhu, umístěné bloky, mlha, zvýraznění platných slotů a náhled.

const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Mesher = preload("res://scripts/mesher.gd")
const VegRender = preload("res://scripts/veg_render.gd")
const BS := 16
const CELL_H := 0.5
const SURF_Y := 32 * CELL_H       # výchozí povrch (střed výšky)
const CENTER := Vector2(1.0, 1.0) # střed rozložení ve slotech (start 2 × 2 = sloty 0..1)
const RADIUS := 2.6

var slots: Array[Vector2i] = []   # všechna místa ostrova (blok nebo mlha)
var blocks := {}                  # Vector2i -> Block
var meshes := {}                  # Vector2i -> MeshInstance3D
var fogs := {}                    # Vector2i -> Node3D
var frames := {}                  # Vector2i -> MeshInstance3D (platné sloty)
var slice_z := -1
var terrain_mat: Material          # aktuální (flat nebo kawaii)
var flat_mat: StandardMaterial3D
var toon_mat: ShaderMaterial
var kawaii := true
var has_textures := false
var textured := false

var bevel := false
func set_bevel(on: bool) -> void:
	bevel = on
	toon_mat.set_shader_parameter("use_bevel", on)

## textury materiálů (jen v kawaii režimu); vypnuto = čisté barvy
func set_textured(on: bool) -> void:
	textured = on and has_textures
	toon_mat.set_shader_parameter("use_tex", textured)
var fog_shader: Shader
var frame_shader: Shader
var preview_mi: MeshInstance3D
var preview_labels: Array[Label3D] = []
var preview_block: Block
var hover_slot = null
var vegs := {}                    # Vector2i -> Node3D (vegetace bloku)
var preview_veg: Node3D
var props: Array[Node3D] = []   # objekty na povrchu (domky)
var occupied := {}              # globální sloupec (Vector2i) -> true: stavba nebo cesta, vegetace tu neroste
var roads: Array[Node3D] = []

## vegetace bloku bez rostlin na zabraných sloupcích (stavby, cesty)
func veg_filtered(b: Block) -> Array:
	if occupied.is_empty():
		return b.veg
	var out := []
	var o := slot_origin(b.slot)
	for r in b.veg:
		if not occupied.has(Vector2i(int(o.x) + r.lx, int(o.z) + r.ly)):
			out.append(r)
	return out

## zabraný sloupec bloku (pro trávu C)
func occ_fn(b: Block) -> Callable:
	var o := slot_origin(b.slot)
	return func(lx: int, ly: int) -> bool: return occupied.has(Vector2i(int(o.x) + lx, int(o.z) + ly))

func refresh_veg(s: Vector2i) -> void:
	if not vegs.has(s):
		return
	vegs[s].queue_free()
	var vn := VegRender.build(veg_filtered(blocks[s]), blocks[s], occ_fn(blocks[s]))
	vn.position = slot_origin(s)
	vn.visible = slice_z < 0
	add_child(vn)
	vegs[s] = vn

## paprsek -> globální sloupec povrchu (pochod po výškové mapě), nebo null
func cell_at_ray(origin: Vector3, dir: Vector3):
	var p := origin
	if dir.y < 0 and p.y > 40.0:  # přeskoč prázdný prostor nad ostrovem
		p += dir * ((p.y - 40.0) / -dir.y)
	for i in 1600:
		var g := Vector2i(floori(p.x), floori(p.z))
		var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
		if blocks.has(s):
			var b: Block = blocks[s]
			var h: int = b.hm[(g.x - s.x * BS) * BS + (g.y - s.y * BS)]
			if p.y <= h * CELL_H:
				return g
		if p.y < -2.0:
			return null
		p += dir * 0.1
	return null

func _init() -> void:
	for sx in range(-3, 5):
		for sz in range(-3, 5):
			if Vector2(sx + 0.5, sz + 0.5).distance_to(CENTER) <= RADIUS:
				slots.append(Vector2i(sx, sz))

func setup() -> void:
	flat_mat = StandardMaterial3D.new()
	flat_mat.vertex_color_use_as_albedo = true
	flat_mat.vertex_color_is_srgb = true
	flat_mat.roughness = 1.0
	flat_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	flat_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	toon_mat = ShaderMaterial.new()
	toon_mat.shader = load("res://terrain_toon.gdshader")
	var imgs: Array[Image] = []
	for i in range(1, 11):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/tex/%02d.png" % i)) != OK:
			imgs.clear(); break
		img.convert(Image.FORMAT_RGB8)
		img.generate_mipmaps()
		imgs.append(img)
	if imgs.size() == 10:
		var ta := Texture2DArray.new()
		var err := ta.create_from_images(imgs)
		if err != OK:
			push_warning("textury: Texture2DArray selhalo")
		toon_mat.set_shader_parameter("tex_arr", ta)
		has_textures = true
	terrain_mat = toon_mat if kawaii else flat_mat
	fog_shader = load("res://fog.gdshader")
	frame_shader = load("res://highlight.gdshader")
	for s in slots:
		_make_fog(s)
	preview_mi = MeshInstance3D.new()
	preview_mi.material_override = terrain_mat
	add_child(preview_mi)
	for i in 4:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0014
		l.font_size = 34
		l.outline_size = 10
		l.modulate = Color(1, 1, 1)
		l.outline_modulate = Color(0.35, 0.25, 0.45)
		l.visible = false
		add_child(l)
		preview_labels.append(l)

func slot_origin(s: Vector2i) -> Vector3:
	return Vector3(s.x * BS, 0, s.y * BS)

func is_fog(s: Vector2i) -> bool:
	return slots.has(s) and not blocks.has(s)

## platný slot: mlha sousedící hranou s ostrovem
func is_valid(s: Vector2i) -> bool:
	if not is_fog(s):
		return false
	for d in BlockGen.DIRS:
		if blocks.has(s + d):
			return true
	return false

func neighbor_hms(s: Vector2i) -> Array:
	var out := []
	for d in BlockGen.DIRS:
		out.append(blocks[s + d].hm if blocks.has(s + d) else null)
	return out

func neighbor_cells(s: Vector2i) -> Array:
	var out := []
	for d in BlockGen.DIRS:
		out.append(blocks[s + d].cells if blocks.has(s + d) else null)
	return out

## Vloží hotový (vygenerovaný) blok do ostrova; slot opustí mlhu.
func place(b: Block) -> void:
	blocks[b.slot] = b
	if fogs.has(b.slot):
		fogs[b.slot].queue_free()
		fogs.erase(b.slot)
	var mi := MeshInstance3D.new()
	mi.material_override = terrain_mat
	mi.position = slot_origin(b.slot)
	add_child(mi)
	meshes[b.slot] = mi
	_remesh(b.slot)
	var vn := VegRender.build(veg_filtered(b), b, occ_fn(b))
	vn.position = slot_origin(b.slot)
	vn.visible = slice_z < 0
	add_child(vn)
	vegs[b.slot] = vn
	for d in BlockGen.DIRS:  # sousedé: data beze změny, jen skrytí stěn na společné hraně
		if blocks.has(b.slot + d):
			_remesh(b.slot + d)
	refresh_frames()

func _remesh(s: Vector2i) -> void:
	var t := Time.get_ticks_usec()
	meshes[s].mesh = Mesher.build(blocks[s].cells, neighbor_cells(s), slice_z)
	blocks[s].mesh_ms = (Time.get_ticks_usec() - t) / 1000.0

## přepnutí vzhledu: kawaii (toon + obrysy) / původní plochý
func set_kawaii(on: bool) -> void:
	kawaii = on
	terrain_mat = toon_mat if on else flat_mat
	for s in meshes:
		meshes[s].material_override = terrain_mat
	preview_mi.material_override = terrain_mat

func set_slice(z: int) -> void:
	slice_z = z
	for s in blocks:
		_remesh(s)
	for s in fogs:
		fogs[s].visible = z < 0
	for p in props:
		p.visible = z < 0
	for v in vegs:
		vegs[v].visible = z < 0
	refresh_frames()
	if preview_block:
		show_preview(preview_block)

func _make_fog(s: Vector2i) -> void:
	if blocks.has(s):
		return
	var root := Node3D.new()
	root.position = slot_origin(s) + Vector3(BS / 2.0, 0, BS / 2.0)
	add_child(root)
	var layers := 18  # hodně tenkých vrstev = plynulý přechod bez pruhů na stěnách ostrova
	for l in layers:
		var pm := PlaneMesh.new()
		pm.size = Vector2(BS - 0.4, BS - 0.4)
		var mat := ShaderMaterial.new()
		mat.shader = fog_shader
		mat.set_shader_parameter("layer_alpha", 0.36 if l == layers - 1 else 0.05)
		mat.set_shader_parameter("seed", float(l) * 1.7 + s.x * 3.1 + s.y * 5.3)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 1.5 + l * 0.9
		root.add_child(mi)
	fogs[s] = root

var show_frames := false

func refresh_frames() -> void:
	for s in frames:
		frames[s].queue_free()
	frames.clear()
	if slice_z >= 0 or not show_frames:
		return
	for s in slots:
		if not is_valid(s):
			continue
		var pm := PlaneMesh.new()
		pm.size = Vector2(BS - 0.2, BS - 0.2)
		var mat := ShaderMaterial.new()
		mat.shader = frame_shader
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = slot_origin(s) + Vector3(BS / 2.0, 16.6, BS / 2.0)
		add_child(mi)
		frames[s] = mi
	_update_frame_colors()

func set_hover(s) -> void:
	hover_slot = s
	_update_frame_colors()

func _update_frame_colors() -> void:
	for s in frames:
		var m: ShaderMaterial = frames[s].material_override
		var hot: bool = hover_slot != null and s == hover_slot
		m.set_shader_parameter("color", Color(1.0, 0.55, 0.75) if hot else Color(1.0, 0.86, 0.45))
		m.set_shader_parameter("strength", 0.95 if hot else 0.45)
		frames[s].visible = not (preview_block != null and preview_block.slot == s)

func show_preview(b: Block) -> void:
	preview_block = b
	var t := Time.get_ticks_usec()
	preview_mi.mesh = Mesher.build(b.cells, neighbor_cells(b.slot), slice_z)
	b.mesh_ms = (Time.get_ticks_usec() - t) / 1000.0
	preview_mi.position = slot_origin(b.slot)
	preview_mi.visible = true
	if preview_veg:
		preview_veg.queue_free()
	preview_veg = VegRender.build(b.veg, b)
	preview_veg.position = slot_origin(b.slot)
	preview_veg.visible = slice_z < 0
	add_child(preview_veg)
	if fogs.has(b.slot):
		fogs[b.slot].visible = false
	var nh := neighbor_hms(b.slot)
	for i in 4:
		var d: Vector2i = BlockGen.DIRS[i]
		var l := preview_labels[i]
		var mode: int = b.sides[i]
		var mtxt := "auto" if mode == 0 else ("ponechat" if mode == 5 else "dorovnat %d" % mode)
		l.text = "%s: %s" % [BlockGen.SIDE_NAMES[i], mtxt] if nh[i] != null else BlockGen.SIDE_NAMES[i]
		var c := Vector3(BS / 2.0 + d.x * BS * 0.42, 0, BS / 2.0 + d.y * BS * 0.42)
		var tx := clampi(int(c.x), 0, BS - 1)
		var tz := clampi(int(c.z), 0, BS - 1)
		c.y = b.hm[tx * BS + tz] * CELL_H + 2.5
		l.position = slot_origin(b.slot) + c
		l.visible = true
	_update_frame_colors()

func hide_preview() -> void:
	preview_block = null
	preview_mi.visible = false
	if preview_veg:
		preview_veg.queue_free()
		preview_veg = null
	for l in preview_labels:
		l.visible = false
	for s in fogs:
		fogs[s].visible = slice_z < 0
	_update_frame_colors()

## paprsek z kamery -> slot (průsečík s rovinou výchozího povrchu)
func slot_at_ray(origin: Vector3, dir: Vector3):
	if absf(dir.y) < 0.0001:
		return null
	var t := (SURF_Y - origin.y) / dir.y
	var p := origin + dir * t
	var s := Vector2i(floori(p.x / BS), floori(p.z / BS))
	return s if slots.has(s) else null
