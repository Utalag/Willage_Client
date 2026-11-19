@tool
class_name SurfaceRenderer
extends RefCounted
## Vykreslení povrchu louka / písek / voda nad bloky ostrova (vlastní ho island.gd):
## pro každý blok ShoreFields (okno dat se sousedy) → DualGridMesher (duální povrch + lem) a vodní hladina,
## maska duálních dlaždic pro kostkový mesher, pole pro trávu C (výška, řídnutí, pás trávy v písku).
## Parametry: SurfaceParams (Resource). Změna barev / sil → jen uniformy (hned); změna tvaru / polí / hustoty
## (SurfaceParams.rebuild_props) → přestavba všech bloků se zpožděním 0,4 s nebo hned přes request_rebuild().

const Params = preload("res://scripts/surface/surface_params.gd")
const GrassPar = preload("res://scripts/grass_params.gd")
const Fields = preload("res://scripts/surface/shore_fields.gd")
const Mesher = preload("res://scripts/surface/dual_grid_mesher.gd")
const Registry = preload("res://scripts/param_registry.gd")
const Grass = preload("res://scripts/grass.gd")
const Toon = preload("res://scripts/toon.gd")

var p
var island
var fields := {}        # slot -> ShoreFields
var surf_mi := {}       # slot -> MeshInstance3D (duální povrch)
var water_mi := {}      # slot -> MeshInstance3D (hladina)
var surf_mat := {}      # slot -> ShaderMaterial
var water_mat := {}
var enabled := true     # vypne řez (PageDown): pak se kreslí jen kostky
var last_ms := {"fields": 0.0, "mesh": 0.0, "n": 0}
var _surf_shader: Shader
var _water_shader: Shader
var _pending := 0

func _init(isl) -> void:
	island = isl
	p = Params.inst()
	_surf_shader = load("res://shaders/terrain_surface.gdshader")
	_water_shader = load("res://shaders/water_surface.gdshader")
	Registry.register("Povrch", p)
	Registry.register("Tráva", GrassPar.inst())
	p.param_changed.connect(_on_param)
	p.rebuild_requested.connect(rebuild_all)
	GrassPar.inst().param_changed.connect(_on_grass_param)
	GrassPar.inst().rebuild_requested.connect(rebuild_all)

func active() -> bool:
	return enabled

## okno dat bloku (volá island před stavbou sítě, i pro sousedy)
func build_fields(s: Vector2i) -> void:
	if not island.blocks.has(s):
		return
	fields[s] = Fields.new(island, s, p)

func field(s: Vector2i):
	return fields.get(s) if active() else null

func mask(s: Vector2i) -> PackedByteArray:
	var f = field(s)
	return f.cell_mask() if f and f.any_dual else PackedByteArray()

## duální povrch a voda bloku (po build_fields)
func build_meshes(s: Vector2i) -> void:
	var f = fields.get(s)
	if f == null:
		return
	var t0 := Time.get_ticks_usec()
	if not surf_mi.has(s):
		var mi := MeshInstance3D.new()
		mi.position = island.slot_origin(s)
		mi.name = "povrch_%d_%d" % [s.x, s.y]
		island.add_child(mi)
		surf_mi[s] = mi
		var m := ShaderMaterial.new()
		m.shader = _surf_shader
		Toon.register(m)
		surf_mat[s] = m
		mi.material_override = m
		_apply_surface(m)
		var wm := MeshInstance3D.new()
		wm.position = island.slot_origin(s)
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.name = "voda_%d_%d" % [s.x, s.y]
		island.add_child(wm)
		water_mi[s] = wm
		var w := ShaderMaterial.new()
		w.shader = _water_shader
		water_mat[s] = w
		wm.material_override = w
		_apply_water(w)
	var m: ShaderMaterial = surf_mat[s]
	m.set_shader_parameter("splat_tex", f.splat_tex)
	m.set_shader_parameter("field_tex", f.field_tex)
	m.set_shader_parameter("rect", f.rect())
	surf_mi[s].mesh = Mesher.build(f, p.dual_sub) if f.any_dual else null
	var w: ShaderMaterial = water_mat[s]
	w.set_shader_parameter("field_tex", f.field_tex)
	w.set_shader_parameter("rect", f.rect())
	water_mi[s].mesh = Mesher.build_water(f, island.blocks) if f.has_water and p.water_enabled else null
	surf_mi[s].visible = active()
	water_mi[s].visible = active()
	last_ms.mesh += (Time.get_ticks_usec() - t0) / 1000.0
	last_ms.fields += f.build_ms
	last_ms.n += 1

func set_enabled(on: bool) -> void:
	enabled = on
	for s in surf_mi:
		surf_mi[s].visible = on
		water_mi[s].visible = on

## výška povrchu ve světě (pro postavičky / ukazatele); bez pole = výška buňky
func surface_y(g: Vector2) -> float:
	var s := Vector2i(floori(g.x / 16.0), floori(g.y / 16.0))
	var f = field(s)
	if f == null:
		return -1.0
	return f.height_local(g.x - s.x * 16, g.y - s.y * 16)

# ------------------------------------------------------------------ parametry → shadery
static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

func _apply_look(m: ShaderMaterial) -> void:
	m.set_shader_parameter("sand_look", p.sand_look)
	m.set_shader_parameter("col_sand", _v(p.col_sand))
	m.set_shader_parameter("col_sand2", _v(p.col_sand2))
	m.set_shader_parameter("sand_detail", p.sand_detail)
	m.set_shader_parameter("sand_grain", p.sand_grain)
	m.set_shader_parameter("sand_ripple", p.sand_ripple)
	m.set_shader_parameter("sand_ripple_freq", p.sand_ripple_freq)
	m.set_shader_parameter("col_grass", _v(p.col_grass))
	m.set_shader_parameter("pg_enabled", p.pg_enabled)
	for k in ["pg_streak", "pg_streak_w", "pg_streak_len", "pg_grain", "pg_clover"]:
		m.set_shader_parameter(k, p.get(k))
	_apply_meadow(m)
	var wd := deg_to_rad(GrassPar.g("wind_dir_deg"))
	m.set_shader_parameter("wind_dir_s", Vector2(cos(wd), sin(wd)))

func _apply_meadow(m: ShaderMaterial) -> void:
	m.set_shader_parameter("mp_strength", p.pg_strength)
	m.set_shader_parameter("mp_macro_scale", p.pg_macro_scale)
	m.set_shader_parameter("mp_macro", p.pg_macro)
	m.set_shader_parameter("mp_yellow", p.pg_yellow)
	m.set_shader_parameter("mp_dry", p.pg_dry)
	m.set_shader_parameter("mp_dry_cov", p.pg_dry_cov)
	m.set_shader_parameter("mp_lush", p.pg_lush)
	m.set_shader_parameter("mp_lush_cov", p.pg_lush_cov)

func _apply_surface(m: ShaderMaterial) -> void:
	_apply_look(m)
	m.set_shader_parameter("dual_noise", p.dual_noise)
	m.set_shader_parameter("dual_soft", p.dual_soft)
	m.set_shader_parameter("col_bed", _v(p.col_bed))
	m.set_shader_parameter("col_bed2", _v(p.col_bed2))
	m.set_shader_parameter("bands", p.bands)
	m.set_shader_parameter("band_water", p.band_water)
	m.set_shader_parameter("band_grass", p.band_grass)
	m.set_shader_parameter("col_packed", _v(p.col_packed))
	m.set_shader_parameter("col_mixgrass", _v(p.col_mixgrass))
	m.set_shader_parameter("bank", p.bank)
	m.set_shader_parameter("bank_reach", p.bank_reach)
	m.set_shader_parameter("mud_w", p.mud_w)
	m.set_shader_parameter("col_mud", _v(p.col_mud))
	m.set_shader_parameter("col_bank_soil", _v(p.col_bank_soil))
	m.set_shader_parameter("water_level", p.water_y())
	m.set_shader_parameter("mat_line", p.mat_line)

func _apply_water(m: ShaderMaterial) -> void:
	m.set_shader_parameter("water_level", p.water_y())
	m.set_shader_parameter("extras", p.extras)
	m.set_shader_parameter("col_shallow", _v(p.col_shallow))
	m.set_shader_parameter("col_deep", _v(p.col_deep))
	m.set_shader_parameter("col_foam", _v(p.col_foam))
	for k in ["foam_w", "wave_reach", "wave_freq", "wave_speed", "foam_bank", "water_alpha"]:
		m.set_shader_parameter(k, p.get(k))

## kostkový terén (terrain_toon) a trsy trávy převezmou vzhled louky a písku
func apply_shared(toon_mat: ShaderMaterial) -> void:
	if toon_mat:
		_apply_look(toon_mat)
		toon_mat.set_shader_parameter("surface_look_on", true)
	var gm: ShaderMaterial = Grass.material()
	_apply_meadow(gm)
	gm.set_shader_parameter("ground_match", p.pg_match if p.pg_enabled else 0.0)

func apply_all() -> void:
	for s in surf_mat:
		_apply_surface(surf_mat[s])
		_apply_water(water_mat[s])
	apply_shared(island.toon_mat)

const HIDE_PROPS := ["hide_undiscovered", "xray", "undiscovered_look", "col_undiscovered", "undiscovered_darken", "wet_tint", "data_water"]

func _on_param(prop: String) -> void:
	if prop in HIDE_PROPS:
		island.rebuild_cube_meshes()
		return
	if p.needs_rebuild(prop):
		_schedule_rebuild()
	apply_all()

func _on_grass_param(prop: String) -> void:
	Grass.apply_params()
	if GrassPar.inst().needs_rebuild(prop):
		_schedule_rebuild()
	if prop == "wind_dir_deg":
		apply_all()

func _schedule_rebuild() -> void:
	_pending += 1
	var my := _pending
	await island.get_tree().create_timer(0.4).timeout
	if my == _pending:
		rebuild_all()

func rebuild_all() -> void:
	_pending += 1
	var t0 := Time.get_ticks_usec()
	island.rebuild_all_surfaces()
	print("povrch: přestavba %d bloků %.0f ms" % [island.blocks.size(), (Time.get_ticks_usec() - t0) / 1000.0])
