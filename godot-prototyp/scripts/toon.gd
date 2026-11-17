extends RefCounted
## Sdílené kawaii materiály objektů (vegetace, domky, cesty). set_on() přepíná všechny najednou (klávesa T).

static var on := true
static var _mats: Array[ShaderMaterial] = []      # toon materiály (uniform toon_on)
static var _outlines: Array[ShaderMaterial] = []  # obrysy (uniform enabled)
static var _cache := {}

## barva je lineární; outline = šířka obrysu (0 = bez obrysu)
static func object_mat(lin: Color, outline := 0.025, vcol := false) -> ShaderMaterial:
	var key := "%s|%s|%s" % [lin, outline, vcol]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://object_toon.gdshader")
	m.set_shader_parameter("albedo", lin)
	m.set_shader_parameter("use_vcol", vcol)
	m.set_shader_parameter("toon_on", on)
	_mats.append(m)
	if outline > 0.0:
		m.next_pass = outline_mat(lin, outline)
	_cache[key] = m
	return m

static func outline_mat(lin: Color, w: float) -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = load("res://outline.gdshader")
	o.set_shader_parameter("color", Color(lin.r * 0.45, lin.g * 0.45, lin.b * 0.45))
	o.set_shader_parameter("width", w)
	o.set_shader_parameter("enabled", on)
	_outlines.append(o)
	return o

## registrace cizího materiálu s uniformem toon_on (např. vítr)
static func register(m: ShaderMaterial) -> void:
	m.set_shader_parameter("toon_on", on)
	_mats.append(m)

static func set_on(v: bool) -> void:
	on = v
	for m in _mats:
		m.set_shader_parameter("toon_on", v)
	for o in _outlines:
		o.set_shader_parameter("enabled", v)

## všechny StandardMaterial3D v podstromu nahradí toon materiálem (barva sRGB -> lineární, tmavší o dark)
static func apply_to(n: Node, outline := 0.025, dark := 0.0) -> void:
	if n is MeshInstance3D and n.mesh:
		n.mesh = with_smooth_normals(n.mesh)
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var c: Color = m.albedo_color.darkened(dark).srgb_to_linear()
				n.set_surface_override_material(i, object_mat(c, outline))
	for ch in n.get_children():
		apply_to(ch, outline, dark)

## Obrysy bez děr na ostrých hranách: do CUSTOM0 uloží vyhlazenou normálu (průměr normál všech vrcholů na stejné pozici),
## outline.gdshader ji použije místo ostré normály. Vrací novou ArrayMesh se stejnými materiály.
static func with_smooth_normals(mesh: Mesh) -> Mesh:
	if mesh == null or not (mesh is ArrayMesh):
		return mesh
	var am := ArrayMesh.new()
	var acc := {}
	var surfs := []
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		surfs.append(arr)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var k := (vs[i] * 1000.0).round()
			acc[k] = acc.get(k, Vector3.ZERO) + ns[i]
	for si in surfs.size():
		var arr: Array = surfs[si]
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var c0 := PackedFloat32Array()
		c0.resize(vs.size() * 4)
		for i in vs.size():
			var n: Vector3 = acc[(vs[i] * 1000.0).round()]
			n = n.normalized() if n.length() > 1e-5 else arr[Mesh.ARRAY_NORMAL][i]
			c0[i * 4] = n.x; c0[i * 4 + 1] = n.y; c0[i * 4 + 2] = n.z; c0[i * 4 + 3] = 1.0
		arr[Mesh.ARRAY_CUSTOM0] = c0
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		am.surface_set_material(si, mesh.surface_get_material(si))
	return am
