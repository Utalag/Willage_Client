@tool
extends Node3D
## Ostrov: sloty v přibližném kruhu, umístěné bloky, mlha, zvýraznění platných slotů a náhled.
## Startovní bloky a generátor jsou parametry v Inspectoru (skupina „Startovní ostrov“). V editoru (@tool) se ostrov
## vygeneruje jako náhled ve 3D pohledu (vypínač „editor_preview“, tlačítko „Přegenerovat náhled“); za běhu ho
## sestaví Main (setup() + generate_start()). Uzly náhledu nemají vlastníka, do main.tscn se neukládají.

const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Mesher = preload("res://scripts/mesher.gd")
const Discovery = preload("res://scripts/discovery.gd")
const SurfaceParamsS = preload("res://scripts/surface/surface_params.gd")
const VegRender = preload("res://scripts/veg_render.gd")
const SurfaceRendererS = preload("res://scripts/surface/surface_renderer.gd")
const TerenBP = preload("res://scripts/teren/ostrov_teren.gd")
const TerenTridy = preload("res://scripts/teren/tridy.gd")
const OstrovVoda = preload("res://scripts/voda/ostrov_voda.gd")
const OstrovVodaRender = preload("res://scripts/voda/ostrov_voda_render.gd")
const J = preload("res://scripts/jednotky.gd")   # E89
const Grass = preload("res://scripts/grass.gd")
const BS := J.BS
const CELL_H := J.CELL_M
const SURF_Y := 32 * CELL_H       # výchozí povrch (střed výšky)
const CENTER := Vector2(1.0, 1.0) # střed rozložení ve slotech (start 2 × 2 = sloty 0..1)
const RADIUS := 2.6

@export_group("Startovní ostrov")
## generátor (CLI -- --gen=bp|proto|v3 má přednost): bp = terén a voda ze studie (E66), v3 = gen-v3, proto = původní vrstvy
@export_enum("bp", "v3", "proto") var generator: String = "bp"
## startovní bloky v pořadí vkládání: slot, typ (louka / kopec / hora / piscina) a seed
@export var start_slots: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
@export var start_kinds: PackedStringArray = ["louka", "hora", "kopec", "louka"]
@export var start_seeds: PackedInt32Array = [101, 202, 303, 404]
@export_group("Náhled v editoru")
## vygenerovat ostrov ve 3D pohledu editoru (asi 1 s); vypnout, když editor zdržuje
@export var editor_preview := true:
	set(v):
		editor_preview = v
		if Engine.is_editor_hint() and is_node_ready():
			_editor_rebuild()
@export_tool_button("Přegenerovat náhled", "Reload") var _regen_btn = _editor_rebuild

var gen_times: Array[float] = []
var mesh_times: Array[float] = []

var slots: Array[Vector2i] = []   # všechna místa ostrova (blok nebo mlha)
var blocks := {}                  # Vector2i -> Block
var meshes := {}                  # Vector2i -> MeshInstance3D
var wmeshes := {}                 # Vector2i -> MeshInstance3D: volná voda z dat bloku (gen-v3: jeskyně, jezírka)
var data_water_mat: StandardMaterial3D
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
## E66 gen bp: voda ostrova ze studie (prameny, koryta, tůně, vodopády, podzemí); null u jiných generátorů
var voda = null
var voda_mi := {}                 # "voda" / "vodopad" / "mlha" → MeshInstance3D
var voda_mats := {}
var voda_batch := false           # generate_start: voda se spočítá jednou po vložení všech bloků
var voda_log := true
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
var surface   # SurfaceRenderer: duální povrch louka/písek/voda (scripts/surface/)

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
	var vn := VegRender.build(veg_filtered(blocks[s]), blocks[s], occ_fn(blocks[s]), surface.field(s) if surface else null)
	vn.position = slot_origin(s)
	vn.visible = slice_z < 0
	add_child(vn)
	vegs[s] = vn

## blok a jeho existující sousedé (i úhlopříční) – duální dlaždice a pole sahají přes hranici
func area_of(s: Vector2i) -> Array:
	var out := []
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n := s + Vector2i(dx, dz)
			if blocks.has(n):
				out.append(n)
	return out

## přestavba povrchu, kostkové sítě a vegetace dotčených bloků (po kopání, stavbě, cestě, vložení)
func refresh_blocks(slots: Array, with_area := true) -> void:
	var todo := {}
	for s in slots:
		for n in (area_of(s) if with_area else [s]):
			todo[n] = true
	for s in todo:
		surface.build_fields(s)
	for s in todo:
		_remesh(s)
		surface.build_meshes(s)
	for s in todo:
		if vegs.has(s):
			refresh_veg(s)

## po změně sloupce (lx, ly) bloku sl: sousedé jen pokud sloupec leží v jejich okně polí
func refresh_after_edit(sl: Vector2i, lx: int, ly: int) -> void:
	var pad: int = surface.p.field_pad + 1
	var list := [sl]
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var okx: bool = dx == 0 or (dx < 0 and lx < pad) or (dx > 0 and lx >= BS - pad)
			var okz: bool = dz == 0 or (dz < 0 and ly < pad) or (dz > 0 and ly >= BS - pad)
			if okx and okz and blocks.has(sl + Vector2i(dx, dz)):
				list.append(sl + Vector2i(dx, dz))
	for s in list:
		refresh_discovered(s)
	refresh_blocks(list, false)

func rebuild_all_surfaces() -> void:
	refresh_blocks(blocks.keys(), false)

## jen kostkové sítě (skrytí podzemí, x-ray, neutrální textura) – pole povrchu se nemění
func rebuild_cube_meshes() -> void:
	for s in blocks:
		_remesh(s)
	if preview_block:
		show_preview(preview_block)

## přepočet odkrytých buněk bloku (po vložení, kopání, nebo když soused přibyl / změnil výšku)
func refresh_discovered(s: Vector2i) -> void:
	if not blocks.has(s):
		return
	if not _hide_on():
		blocks[s].discovered = PackedByteArray()  # přepočet až při zapnutém skrytí
		return
	blocks[s].discovered = Discovery.compute(blocks[s].cells, neighbor_cells(s), neighbor_hms(s), blocks[s].hm)

func _hide_on() -> bool:
	var p = surface.p if surface else SurfaceParamsS.inst()
	return p.hide_undiscovered and not p.xray

func _block_mesh(cells: PackedByteArray, nbs: Array, mask: PackedByteArray, discovered: PackedByteArray, water := PackedInt32Array(), geo := PackedByteArray()) -> ArrayMesh:
	var p = surface.p if surface else SurfaceParamsS.inst()
	var disc := discovered if _hide_on() else PackedByteArray()
	var nmat: int = Mat.DIRT if p.undiscovered_look == 0 else Mat.GRANITE
	var wet := water if p.wet_tint else PackedInt32Array()
	# E66 gen bp: skutečné horniny a minerály (plná id) jen v rentgenu; jinak třídy prototypu (podzemí skryté)
	var g := geo if p.xray and geo.size() == cells.size() else PackedByteArray()
	# E66b: bok ostrova jednou barvou bez textury (nastavení side_plain); v rentgenu skutečné materiály
	var sc: Color = p.col_side if p.side_plain and not p.xray else Color(0, 0, 0, 0)
	return Mesher.build(cells, nbs, slice_z, Color(1, 1, 1), mask, disc, nmat, p.col_undiscovered, p.undiscovered_darken, wet, g, TerenTridy.palette() if not g.is_empty() else PackedColorArray(), sc)

## gen-v3: volná voda z vrstvy vody bloku = buňky vzduchu s vodou (jeskyně pod hladinou, jezírko). Výška hladiny v buňce
## = voda / 4096. Při skrytí podzemí jen voda v odkrytém vzduchu (discovered 2) nebo nad povrchem. Vodní hladina
## prototypu (water_lz 30, jen vzhled, surface_renderer) se tím nemění.
func _data_water_mesh(b: Block) -> ArrayMesh:
	var am := ArrayMesh.new()
	var p = surface.p if surface else SurfaceParamsS.inst()
	if not p.data_water or b.water.size() != BS * BS * 64 or b.gen == "bp":   # bp: voda z ostrov_voda.gd
		return am
	var hide := _hide_on() and b.discovered.size() == BS * BS * 64
	var top := 64 if slice_z < 0 else mini(slice_z, 64)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for x in BS:
		for z in BS:
			var h: int = b.hm[x * BS + z]
			for y in top:
				var i := (x * BS + z) * 64 + y
				var w: int = b.water[i]
				if w <= 0 or b.cells[i] != Mat.AIR:
					continue
				if hide and y < h and b.discovered[i] != 2:
					continue
				var fy := clampf(w / 4096.0, 0.05, 1.0)
				var full_above := y + 1 < 64 and b.cells[i + 1] == Mat.AIR and b.water[i + 1] > 0
				var y0 := y * CELL_H
				var y1 := (y + (1.0 if full_above else fy)) * CELL_H
				_box(st, Vector3(x, y0, z), Vector3(x + 1, y1, z + 1), not full_above)
				n += 1
	if n == 0:
		return am
	st.generate_normals()
	return st.commit()

static func _box(st: SurfaceTool, a: Vector3, b: Vector3, with_top: bool) -> void:
	var q := [
		[Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)],
		[Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, a.y, a.z)],
		[Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)],
		[Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z), Vector3(a.x, a.y, a.z)],
		[Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z)],
	]
	for k in q.size():
		if k == 0 and not with_top:
			continue
		var f: Array = q[k]
		for t in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(f[t])

## paprsek -> globální sloupec povrchu (pochod po výškové mapě), nebo null
func cell_at_ray(origin: Vector3, dir: Vector3):
	if scale != Vector3.ONE:
		var rl := _ray_local(origin, dir); origin = rl[0]; dir = rl[1]
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

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_rebuild.call_deferred()
	elif SurfaceParamsS.inst().p89_meritko:
		scale = J.SCENA_DNES_M_NA_SC   # E89: scéna v metrech (buňka 0,5 × 0,5 × 0,5 m), data beze změny
	# E94: objekty (stromy, tráva, stavby) mají rozměry v metrech → v ostrově s měřítkem se vyrovnají (×2 vodorovně)
	VegRender.proti = protiskala()
	VegRender.metry = scale != Vector3.ONE
	Grass.proti = protiskala()

## E94: měřítko, které vrátí objekt v ostrově na metry (ostrov vodorovně ×0,5 → objekt ×2); bez p89_meritko jedničky
func protiskala() -> Vector3:
	return Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)

## E94: metrů na jednotku ostrova vodorovně (0,5 v metrech, 1 = dnešní scéna)
func m_na_bunku() -> float:
	return scale.x

## E89: paprsek ze scény do místních souřadnic ostrova (bez p89_meritko beze změny)
func _ray_local(origin: Vector3, dir: Vector3) -> Array:
	if scale == Vector3.ONE:
		return [origin, dir]
	var inv := global_transform.affine_inverse()
	return [inv * origin, inv.basis * dir]

## blok z receptu (typ, seed); unikátní blok má bonus rud
static func make_block(kind: String, seed: int, title: String, category := "běžný") -> Block:
	var b := Block.new()
	b.kind = kind; b.seed = seed; b.title = title; b.category = category
	if category == "unikátní":
		b.ore_bonus = 0.12
	return b

## vygeneruje a vloží startovní bloky (pořadí = pořadí vkládání, každý se napojí na už vložené sousedy)
func generate_start(log := true) -> void:
	voda_batch = true
	for i in start_slots.size():
		var kind: String = start_kinds[i] if i < start_kinds.size() else "louka"
		var b := make_block(kind, start_seeds[i] if i < start_seeds.size() else 101 * (i + 1), "Start: " + kind)
		b.slot = start_slots[i]
		BlockGen.build(b, neighbor_hms(b.slot))
		place(b)
		if log:
			log_block(b)
	voda_batch = false
	rebuild_water()

func log_block(b: Block) -> void:
	gen_times.append(b.gen_ms)
	mesh_times.append(b.mesh_ms)
	print("blok %s %s seed %d slot %s: generování %.1f ms, mesh %.1f ms" % [b.title, b.kind, b.seed, b.slot, b.gen_ms, b.mesh_ms])

## editor: smaže náhled (uzly bez vlastníka) a podle vypínače vygeneruje znovu
func _editor_rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	for c in get_children():
		if c.owner == null:
			remove_child(c)
			c.queue_free()
	blocks.clear(); meshes.clear(); wmeshes.clear(); fogs.clear(); frames.clear(); vegs.clear()
	props.clear(); roads.clear(); occupied.clear(); preview_labels.clear()
	preview_block = null; preview_veg = null; hover_slot = null; slice_z = -1
	if not editor_preview:
		return
	var t := Time.get_ticks_msec()
	BlockGen.gen_version = generator
	setup()
	generate_start(false)
	print("Island: náhled v editoru %d bloků za %d ms (%s)" % [blocks.size(), Time.get_ticks_msec() - t, generator])

func setup() -> void:
	flat_mat = StandardMaterial3D.new()
	flat_mat.vertex_color_use_as_albedo = true
	flat_mat.vertex_color_is_srgb = true
	flat_mat.roughness = 1.0
	flat_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	flat_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	data_water_mat = StandardMaterial3D.new()
	data_water_mat.albedo_color = Color(0.35, 0.62, 0.95, 0.62)
	data_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	data_water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	data_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	surface = SurfaceRendererS.new(self)
	surface.apply_shared(toon_mat)
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
		l.scale = protiskala()   # E94: popisek ve scéně v metrech nezúžit
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
	if b.gen == "bp":
		TerenBP.commit(b)   # blok se stane sousedem pro další bloky (navázání vrstev)
	if fogs.has(b.slot):
		fogs[b.slot].queue_free()
		fogs.erase(b.slot)
	var mi := MeshInstance3D.new()
	mi.material_override = terrain_mat
	mi.position = slot_origin(b.slot)
	add_child(mi)
	meshes[b.slot] = mi
	# povrch: okno dat bloku i sousedů (včetně úhlopříčných) se změnilo → pole, maska, duální síť, voda
	var area := area_of(b.slot)
	for s in area:
		surface.build_fields(s)
	for s in area:
		refresh_discovered(s)
	for s in area:   # sousedé: data beze změny, jen skrytí stěn na společné hraně a navázání povrchu
		_remesh(s)
		surface.build_meshes(s)
	var vn := VegRender.build(veg_filtered(b), b, occ_fn(b), surface.field(b.slot))
	vn.position = slot_origin(b.slot)
	vn.visible = slice_z < 0
	add_child(vn)
	vegs[b.slot] = vn
	for s in area:
		if s != b.slot:
			refresh_veg(s)
	refresh_frames()
	if not voda_batch:
		rebuild_water()

## E66: plný výpočet vody ostrova (po vložení bloku); jen pro bloky gen bp
func rebuild_water() -> void:
	if Engine.is_editor_hint():   # náhled v editoru bez vody (plný výpočet trvá sekundy)
		return
	var any := false
	for s in blocks:
		if blocks[s].gen == "bp": any = true
	if not any:
		return
	if voda == null:
		voda = OstrovVoda.new()
	voda.build(blocks)
	if voda_log:
		print("E66 voda: ", voda.ms, " ", voda.summary())
	render_water()

func _exit_tree() -> void:
	if voda != null:
		voda.dispose()
		voda = null

## jen síť vody ostrova (po změně vody nebo řezu)
func render_water() -> void:
	if voda == null:
		return
	if voda_mats.is_empty():
		voda_mats = OstrovVodaRender.mats()
	var m: Dictionary = OstrovVodaRender.build(voda, slice_z)
	for k in ["voda", "vodopad", "mlha"]:
		if not voda_mi.has(k):
			var mi := MeshInstance3D.new()
			mi.material_override = voda_mats[k]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			voda_mi[k] = mi
		voda_mi[k].mesh = m[k]

## E66: změna sloupce (kopání / položení) bloku gen bp → lokální přepočet vody (podzemí E64, povrch tok60)
func water_edit(sl: Vector2i, lx: int, ly: int) -> Dictionary:
	if voda == null or not blocks.has(sl) or blocks[sl].gen != "bp":
		return {}
	var r: Dictionary = voda.edit(sl, lx, ly, blocks[sl].hm[lx * BS + ly])
	render_water()
	return r

## E66: kroky R podzemí po snímcích (pevný počet operací na krok); po dokončení se síť vody obnoví
func water_step(n := 1) -> bool:
	if voda == null or not voda.pending():
		return false
	var more := true
	for k in n:
		more = voda.step()
		if not more: break
	if not more:
		render_water()
	return more

## E66: dokončit rozpracované kroky (před další změnou terénu; výsledek nezávisí na snímcích)
func water_finish() -> void:
	if voda == null: return
	var any := false
	while voda.pending():
		voda.step(); any = true
	if any: render_water()

## jen síť volné vody z dat (náhled běžícího toku po kopání, levné na snímek)
func remesh_water(s: Vector2i) -> void:
	if wmeshes.has(s) and blocks.has(s):
		wmeshes[s].mesh = _data_water_mesh(blocks[s])

func _remesh(s: Vector2i) -> void:
	var t := Time.get_ticks_usec()
	var mk: PackedByteArray = surface.mask(s) if surface and slice_z < 0 else PackedByteArray()
	var b: Block = blocks[s]
	if _hide_on() and b.discovered.size() != BS * BS * 64:
		refresh_discovered(s)
	meshes[s].mesh = _block_mesh(b.cells, neighbor_cells(s), mk, b.discovered, b.water if b.gen != "bp" else PackedInt32Array(), b.geo)
	if b.water.size() > 0 and b.gen != "bp":
		if not wmeshes.has(s):
			var wm := MeshInstance3D.new()
			wm.material_override = data_water_mat
			wm.position = slot_origin(s)
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(wm)
			wmeshes[s] = wm
		wmeshes[s].mesh = _data_water_mesh(b)
	elif wmeshes.has(s):
		wmeshes[s].queue_free()
		wmeshes.erase(s)
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
	surface.set_enabled(z < 0)   # v řezu jen kostky (duální povrch by zakryl řez)
	for s in blocks:
		_remesh(s)
	for s in fogs:
		fogs[s].visible = z < 0
	for p in props:
		p.visible = z < 0
	for v in vegs:
		vegs[v].visible = z < 0
	render_water()
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
		mat.set_shader_parameter("noise_k", 0.12 / scale.x)   # E94: stejný vzor na buňku i ve scéně v metrech
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 1.5 + l * 0.9
		mi.set_meta("nizka", l < layers - FOG_TOP_KEEP)
		root.add_child(mi)
	fogs[s] = root
	apply_fog_side(root)

## E66b: vrstvy mlhy ve slotech kolem ostrova (před bokem) jen při nastavení fog_side; vrstvy nad FOG_TOP_KEEP zůstanou vždy
const FOG_TOP_KEEP := 0   # 0 = při fog_side vyp. žádná vrstva (i horní příkrov dělal na boku rozmazané kosočtverce)
func apply_fog_side(root: Node3D = null) -> void:
	var p = surface.p if surface else SurfaceParamsS.inst()
	var lst: Array = [root] if root != null else fogs.values()
	for r in lst:
		for mi in r.get_children():
			if mi.get_meta("nizka", false): mi.visible = p.fog_side

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
	var disc := Discovery.compute(b.cells, neighbor_cells(b.slot), neighbor_hms(b.slot), b.hm)
	preview_mi.mesh = _block_mesh(b.cells, neighbor_cells(b.slot), PackedByteArray(), disc)
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
	if scale != Vector3.ONE:
		var rl := _ray_local(origin, dir); origin = rl[0]; dir = rl[1]
	if absf(dir.y) < 0.0001:
		return null
	var t := (SURF_Y - origin.y) / dir.y
	var p := origin + dir * t
	var s := Vector2i(floori(p.x / BS), floori(p.z / BS))
	return s if slots.has(s) else null
