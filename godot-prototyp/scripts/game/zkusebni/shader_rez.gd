extends RefCounted
## E95: za běhu upravené shadery pro E91 (průhlednost překážek) a svislý řez ostrovem.
## Úprava kódu shaderu je v scripts/game/pruhlednost91.gd (E91 + ZK_REZ_CODE); tady je jen:
##  - převod StandardMaterial3D (voda, plochý terén, domek, cesty) na jednoduchý ShaderMaterial, aby šel řezat,
##  - 3D textura buněk bloků (plná id geo) + paleta, ze které shader barví plochu řezu,
##  - nastavování uniform každý snímek. Vypnuto = původní materiály a shadery (nic nezůstane).
const PR = preload("res://scripts/game/pruhlednost91.gd")
const TR = preload("res://scripts/teren/tridy.gd")
const Mat = preload("res://scripts/mat.gd")
const BS := 16

static var on := false
static var _conv := {}       # BaseMaterial3D → ShaderMaterial
static var _swaps := []      # [uzel, "o" | index, původní materiál]
static var _cells: ImageTexture3D = null
static var _slots: ImageTexture = null
static var _pal: ImageTexture = null
static var _sig := ""
static var terrain_mats := {}   # ShaderMaterial terénu (barví plochu řezu materiálem)

static func _std_code(m: BaseMaterial3D) -> String:
	var rm := []
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: rm.append("unshaded")
	rm.append("cull_disabled" if m.cull_mode == BaseMaterial3D.CULL_DISABLED else ("cull_front" if m.cull_mode == BaseMaterial3D.CULL_FRONT else "cull_back"))
	var alpha := m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if alpha: rm.append("blend_mix, depth_draw_opaque")
	if m.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT: rm.append("diffuse_lambert")
	if m.specular_mode == BaseMaterial3D.SPECULAR_DISABLED: rm.append("specular_disabled")
	var s := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(rm)
	s += "uniform vec4 albedo : source_color = vec4(1.0);\nuniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;\n"
	s += "uniform bool use_tex = false;\nuniform bool use_vc = false;\nuniform bool vc_srgb = false;\nuniform float roughness = 1.0;\nuniform float metallic = 0.0;\n"
	s += "void fragment() {\n\tvec4 c = albedo;\n\tif (use_tex) c *= texture(tex, UV);\n"
	s += "\tif (use_vc) { vec3 v = COLOR.rgb; if (vc_srgb) v = mix(pow((v + vec3(0.055)) / 1.055, vec3(2.4)), v / 12.92, lessThan(v, vec3(0.04045))); c *= vec4(v, COLOR.a); }\n"
	s += "\tALBEDO = c.rgb;\n\tROUGHNESS = roughness;\n\tMETALLIC = metallic;\n"
	if alpha: s += "\tALPHA = c.a;\n"
	s += "}\n"
	return s

static func _convert(m: BaseMaterial3D) -> ShaderMaterial:
	if _conv.has(m): return _conv[m]
	var sh := Shader.new(); sh.code = _std_code(m)
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.set_shader_parameter("albedo", m.albedo_color)
	sm.set_shader_parameter("use_tex", m.albedo_texture != null)
	if m.albedo_texture: sm.set_shader_parameter("tex", m.albedo_texture)
	sm.set_shader_parameter("use_vc", m.vertex_color_use_as_albedo)
	sm.set_shader_parameter("vc_srgb", m.vertex_color_is_srgb)
	sm.set_shader_parameter("roughness", m.roughness)
	sm.set_shader_parameter("metallic", m.metallic)
	sm.render_priority = m.render_priority
	_conv[m] = sm
	return sm

static func _swap_std(n: Node, skip: Array) -> void:
	if n in skip: return
	if n is GeometryInstance3D:
		if n.material_override is BaseMaterial3D:
			_swaps.append([n, "o", n.material_override])
			n.material_override = _convert(n.material_override)
		elif n is MeshInstance3D and n.material_override == null and n.mesh:
			for i in n.mesh.get_surface_count():
				var m = n.get_surface_override_material(i)
				if m == null: m = n.mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					_swaps.append([n, i, n.get_surface_override_material(i)])
					n.set_surface_override_material(i, _convert(m))
	for c in n.get_children(): _swap_std(c, skip)

## zapne (nebo doplní nové uzly): převod standardních materiálů + úprava všech ShaderMaterialů pod root
static func enable(root: Node, island: Node, skip: Array = []) -> int:
	on = true
	_swap_std(root, skip)
	var n := PR.enable(root, skip, true)
	terrain_mats.clear()
	for k in ["toon_mat", "flat_mat"]:
		var m = island.get(k)
		if m is ShaderMaterial: terrain_mats[m] = true
		elif m is BaseMaterial3D and _conv.has(m): terrain_mats[_conv[m]] = true
	if island.get("surface") != null:
		for c in island.get_children():
			if c is MeshInstance3D and c.material_override is ShaderMaterial and c.material_override.shader and str(c.material_override.shader.resource_path).contains("terrain"):
				terrain_mats[c.material_override] = true
	update_cells(island)
	return n

static func disable() -> void:
	PR.disable()
	for s in _swaps:
		var nd = s[0]
		if not is_instance_valid(nd): continue
		if typeof(s[1]) == TYPE_STRING: nd.material_override = s[2]
		else: nd.set_surface_override_material(s[1], s[2])
	_swaps.clear()
	terrain_mats.clear()
	on = false

## 3D textura: šířka 64 (výška buňky), výška 256 (x · 16 + z), vrstva = blok; zk_slots 8 × 8 (slot + 3 → vrstva + 1)
static func update_cells(island: Node, force := false) -> void:
	var keys: Array = island.blocks.keys()
	var sig := str(keys.size())
	for s in keys:
		var b = island.blocks[s]
		sig += "|%s:%d" % [s, hash(b.geo) if b.geo.size() == BS * BS * 64 else 0]
	if sig == _sig and not force and _cells != null: return
	_sig = sig
	var imgs: Array[Image] = []
	var si := Image.create(8, 8, false, Image.FORMAT_R8)
	for s in keys:
		var b = island.blocks[s]
		var g: PackedByteArray = b.geo if b.geo.size() == BS * BS * 64 else PackedByteArray()
		if g.is_empty(): continue
		var ix: int = s.x + 3; var iz: int = s.y + 3
		if ix < 0 or iz < 0 or ix >= 8 or iz >= 8: continue
		imgs.append(Image.create_from_data(64, 256, false, Image.FORMAT_R8, g))
		si.set_pixel(ix, iz, Color8(imgs.size(), 0, 0))
	if imgs.is_empty(): imgs.append(Image.create(64, 256, false, Image.FORMAT_R8))
	_cells = ImageTexture3D.new()
	_cells.create(Image.FORMAT_R8, 64, 256, imgs.size(), false, imgs)
	_slots = ImageTexture.create_from_image(si)
	if _pal == null:
		var pal := TR.palette(); var cls := TR.classes()
		var pi := Image.create(256, 1, false, Image.FORMAT_RGBA8)
		for id in 256:
			var c: Color = pal[id] if id < pal.size() else Color(0, 0, 0, 0)
			var k: int = cls[id]
			if id == TR.CAV_WATER: c = Color(0.25, 0.5, 0.95, 1.0)
			elif k == Mat.AIR or id == Mat.FOG: c = Color(0, 0, 0, 0)
			elif c.a < 0.5: c = Mat.COLORS[k]; c.a = 1.0
			else: c.a = 1.0
			pi.set_pixel(id, 0, c)
		_pal = ImageTexture.create_from_image(pi)

## uniformy řezu: osa 0 vyp, 1 X, 2 Z; pos 0..1 přes rozsah ostrova (ve světě); cam = pozice kamery (strana řezu)
static func set_rez(island: Node, osa: int, pos: float, cam_pos: Vector3) -> void:
	var lo := Vector2(1e9, 1e9); var hi := Vector2(-1e9, -1e9)
	for s in island.blocks:
		lo = Vector2(minf(lo.x, s.x * BS), minf(lo.y, s.y * BS)); hi = Vector2(maxf(hi.x, (s.x + 1) * BS), maxf(hi.y, (s.y + 1) * BS))
	var xf: Transform3D = island.global_transform
	var nl := Vector3(1, 0, 0) if osa == 1 else Vector3(0, 0, 1)
	var t := lerpf(lo.x, hi.x, pos) if osa == 1 else lerpf(lo.y, hi.y, pos)
	var p0 := xf * (nl * t)
	var nw := (xf.basis * nl).normalized()
	var d := nw.dot(p0)
	var side := 1.0 if nw.dot(cam_pos) - d > 0.0 else -1.0
	var inv := Projection(xf.affine_inverse())
	for m in PR.mats:
		m.set_shader_parameter("zk_rez", 1 if osa > 0 else 0)
		m.set_shader_parameter("zk_rez_n", nw)
		m.set_shader_parameter("zk_rez_d", d)
		m.set_shader_parameter("zk_rez_side", side)
		m.set_shader_parameter("zk_rez_mat", terrain_mats.has(m))
		m.set_shader_parameter("zk_inv", inv)
		m.set_shader_parameter("zk_cells", _cells)
		m.set_shader_parameter("zk_slots", _slots)
		m.set_shader_parameter("zk_pal", _pal)

## E91 v herní scéně: „postava“ = bod terénu uprostřed obrazovky
static func set_pruhl(on91: bool, prm: Dictionary, feet: Vector3, to_cam: Vector3) -> void:
	PR.set_params(int(prm.get("p91_mode", 1)) if on91 else 0, feet, to_cam, prm)
