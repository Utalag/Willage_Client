extends RefCounted
## Vykreslení vegetace bloku: každý druh jeden MultiMeshInstance3D (trsy, květiny, suchá tráva, mech procedurálně,
## stromy/keř/kaktus z .glb vytvořených Blenderem). Výška buňky 0,5.

const Veg = preload("res://scripts/veg.gd")
const Toon = preload("res://scripts/toon.gd")
const Grass = preload("res://scripts/grass.gd")
const CELL_H := 0.5
const MODELS := {Veg.BUSH: "ker", Veg.CONIFER: "jehlicnan", Veg.DECIDUOUS: "listnac", Veg.CACTUS: "kaktus"}
const FLOWER_COLORS := [Color(1.0, 0.62, 0.78), Color(1.0, 0.92, 0.45), Color(0.98, 0.98, 1.0), Color(0.75, 0.62, 1.0)]

# jen vykreslení (data se nemění): kaktus a suchá tráva větší, ať jsou na písčině vidět
const RENDER_SCALE := {Veg.CACTUS: 1.7, Veg.DRY_GRASS: 1.5}

static var _meshes := {}
static var _wind: ShaderMaterial

static func _wind_mat() -> ShaderMaterial:
	if _wind == null:
		_wind = ShaderMaterial.new()
		_wind.shader = load("res://veg_wind.gdshader")
		Toon.register(_wind)
	return _wind

## trs: n trojúhelníkových stébel do kruhu, spodek tmavší
static func _tuft(n: int, h: float, base: Color, tip: Color, spread := 0.18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := TAU * float(i) / n + 0.4 * i
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.05
		var hh := h * (0.75 + 0.25 * ((i * 37) % 10) / 10.0)
		st.set_color(base); st.add_vertex(d * 0.04 - side)
		st.set_color(base); st.add_vertex(d * 0.04 + side)
		st.set_color(tip); st.add_vertex(d * spread + Vector3(0, hh, 0))
	return st.commit()

static func _flower() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := Color(0.45, 0.72, 0.42)
	for i in 3:  # stonky
		var a := TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.1
		st.set_color(g); st.add_vertex(d + Vector3(-0.02, 0, 0))
		st.set_color(g); st.add_vertex(d + Vector3(0.02, 0, 0))
		st.set_color(g); st.add_vertex(d * 1.4 + Vector3(0, 0.32, 0))
		# kvítek: malý bílý (barvu dá instance) dvojitý trojúhelník
		var c := d * 1.4 + Vector3(0, 0.32, 0)
		for k in 4:
			var b := TAU * k / 4.0
			var p1 := c + Vector3(cos(b), 0.02, sin(b)) * 0.08
			var p2 := c + Vector3(cos(b + TAU / 4.0), 0.02, sin(b + TAU / 4.0)) * 0.08
			st.set_color(Color.WHITE); st.add_vertex(c + Vector3(0, 0.03, 0))
			st.set_color(Color.WHITE); st.add_vertex(p1)
			st.set_color(Color.WHITE); st.add_vertex(p2)
	return st.commit()

static func _moss() -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.06, 0.45)
	var am := ArrayMesh.new()
	var arr := bm.get_mesh_arrays()
	var cols := PackedColorArray()
	for v in arr[Mesh.ARRAY_VERTEX]:
		cols.append(Color(0.55, 0.70, 0.50))
	arr[Mesh.ARRAY_COLOR] = cols
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

static func _glb_mesh(name: String) -> Mesh:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/%s.glb" % name), "res://assets/", st) != OK:
		return null
	var root: Node = doc.generate_scene(st)
	var mi := _find_mesh(root)
	var mesh: Mesh = Toon.with_smooth_normals(mi.mesh) if mi else null
	if mesh:
		for i in mesh.get_surface_count():
			var m = mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				m.roughness = 1.0
				m.metallic = 0.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				# Blender ukládá barvu lineárně; převedeme, ať pastelové barvy nejsou vybledlé
				m.albedo_color = m.albedo_color.srgb_to_linear()
				mesh.surface_set_material(i, Toon.object_mat(m.albedo_color, 0.03))
	root.free()
	return mesh

static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null

static func mesh_for(s: int) -> Mesh:
	if _meshes.has(s):
		return _meshes[s]
	var m: Mesh
	match s:
		Veg.TUFT: m = _tuft(6, 0.42, Color(0.50, 0.76, 0.42), Color(0.78, 0.96, 0.60))
		Veg.DRY_GRASS: m = _tuft(6, 0.36, Color(0.60, 0.50, 0.30), Color(0.86, 0.72, 0.42), 0.22)
		Veg.FLOWERS: m = _flower()
		Veg.MOSS: m = _moss()
		_: m = _glb_mesh(MODELS[s])
	_meshes[s] = m
	return m

## Uzel s vegetací bloku (v lokálních souřadnicích bloku). S blokem b se přidá tráva C (grass.gd):
## louka z trsů na travnatých sloupcích, květiny a suchá tráva sdílí její shader (vítr, rozhrnování).
## occ(lx, ly) -> bool: sloupec zabraný stavbou nebo cestou (tráva tu neroste).
## surf (volitelně ShoreFields bloku): rostliny stojí na výšce duálního povrchu, pod hladinou se nekreslí.
static func build(veg: Array, b = null, occ := Callable(), surf = null) -> Node3D:
	var root := Node3D.new()
	var grass_on := b != null and Grass.enabled()
	if grass_on:
		for n in Grass.build(b, veg, occ if occ.is_valid() else func(_x, _y): return false, surf):
			root.add_child(n)
	if surf:
		var kept := []
		for v in veg:
			if not surf.wet_local(v.lx + 0.5 + v.ox, v.ly + 0.5 + v.oy):
				kept.append(v)
		veg = kept
	var by := {}
	for v in veg:
		if grass_on and v.s in [Veg.TUFT, Veg.FLOWERS, Veg.DRY_GRASS]:
			continue
		if not by.has(v.s):
			by[v.s] = []
		by[v.s].append(v)
	for s in by:
		var list: Array = by[s]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = s == Veg.FLOWERS
		mm.mesh = mesh_for(s)
		if mm.mesh == null:
			continue
		mm.instance_count = list.size()
		for i in list.size():
			var v = list[i]
			var sc: float = v.scale * RENDER_SCALE.get(s, 1.0)
			var basis := Basis(Vector3.UP, deg_to_rad(v.yaw)).scaled(Vector3(sc, sc, sc))
			var pos := Vector3(v.lx + 0.5 + v.ox, v.lz * CELL_H, v.ly + 0.5 + v.oy)
			if surf:
				pos.y = surf.height_local(pos.x, pos.z)
			mm.set_instance_transform(i, Transform3D(basis, pos))
			if mm.use_colors:
				mm.set_instance_color(i, FLOWER_COLORS[int(v.yaw) % FLOWER_COLORS.size()])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if s in [Veg.TUFT, Veg.DRY_GRASS, Veg.FLOWERS, Veg.MOSS]:
			mmi.material_override = _wind_mat()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root
