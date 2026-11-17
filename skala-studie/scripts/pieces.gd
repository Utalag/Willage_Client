extends RefCounted
## Přístup D: kamenné kusy z Blenderu (blender/kameny.py → assets/kamen_XX.glb, 8 variant).
## build(): každá viditelná buňka = jeden kus (varianta, otočení, převrácení podle hashe), 1,12× přerostlý.
## build_hybrid(): podle souvislých komponent – 1 buňka = samostatný kámen, 2–6 buněk = jeden balvan
## (kus z Blenderu natažený na obal shluku), větší = souvislá skála (Surface Nets jen nad touto komponentou).

const Mat = preload("res://scripts/mat.gd")
static var meshes: Array[Mesh] = []
static var overscale := 1.12

static func load_meshes() -> void:
	if not meshes.is_empty():
		return
	for i in 8:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/kamen_%02d.glb" % i), "res://assets/", st) != OK:
			push_warning("kamen_%02d.glb nenačten" % i)
			continue
		var root: Node = doc.generate_scene(st)
		var mi := _find_mesh(root)
		if mi:
			meshes.append(_fix_winding(mi.mesh))
		root.free()

static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r: return r
	return null

static func _h(a: int, b: int, c: int, d: int) -> int:
	var v := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	return (v ^ (v >> 16)) & 0x7FFFFFFF

## mats: Dictionary materiál -> ShaderMaterial; vrátí uzel s MultiMeshInstance3D, počet kusů, trojúhelníků
static func build(ch, seed: int, cell: Vector3, mats: Dictionary) -> Array:
	load_meshes()
	var groups := {}   # [varianta, materiál] -> Array[Transform3D]
	var count := 0
	var tris := 0
	for x in ch.nx:
		for z in ch.nz:
			for y in ch.ny:
				var m: int = ch.mat_at(x, y, z)
				if m == 0:
					continue
				var exposed := false
				for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
					if not ch.solid(x + d.x, y + d.y, z + d.z):
						exposed = true
				if not exposed:
					continue
				var h := _h(x, y, z, seed)
				var v := h % meshes.size()
				var rot := (h >> 4) % 4
				var flip := ((h >> 7) & 1) == 1     # vzhůru nohama (otočení o 180° kolem X) – bez zrcadlení, které by obrátilo plochy
				var b := Basis(Vector3.UP, rot * PI * 0.5)
				if flip: b = b * Basis(Vector3.RIGHT, PI)
				var sc := overscale * (0.97 + 0.08 * float((h >> 9) % 100) / 100.0)
				b = Basis.from_scale(cell * sc) * b
				var jit := Vector3(float((h >> 3) % 7) - 3.0, 0.0, float((h >> 11) % 7) - 3.0) * 0.012
				var t := Transform3D(b, (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5) + jit) * cell)
				var key := Vector2i(v, m)
				if not groups.has(key): groups[key] = []
				groups[key].append(t)
				count += 1
				tris += meshes[v].get_faces().size() / 3
	var root := Node3D.new()
	for key in groups:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key.x]
		var ts: Array = groups[key]
		mm.instance_count = ts.size()
		for i in ts.size():
			mm.set_instance_transform(i, ts[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[key.y]
		root.add_child(mmi)
	return [root, count, tris]

const Nets = preload("res://scripts/nets_mesher.gd")
static var cluster_max := 6

## hybrid podle komponent; vrací [uzel, počet kamenů, počet balvanů, počet skal, trojúhelníků]
static func build_hybrid(ch, seed: int, cell: Vector3, mats: Dictionary, rock_vcol: Material) -> Array:
	load_meshes()
	var root := Node3D.new()
	var tris := 0
	var n1 := 0; var n2 := 0; var n3 := 0
	for comp in ch.components():
		if comp.size() > cluster_max:
			var am: ArrayMesh = Nets.build(ch.subset(comp), seed, cell)
			var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = rock_vcol
			root.add_child(mi)
			tris += am.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3 if am.get_surface_count() > 0 else 0
			n3 += 1
			continue
		var lo := Vector3i(1 << 20, 1 << 20, 1 << 20); var hi := -lo
		for c in comp:
			lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
			hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
		var c0: Vector3i = comp[0]
		var h := _h(c0.x, c0.y, c0.z, seed)
		var v := h % meshes.size()
		var m: int = ch.mat_at(c0.x, c0.y, c0.z)
		var ext := Vector3(hi - lo) + Vector3.ONE        # obal v buňkách
		var b := Basis()
		var sc: Vector3
		if comp.size() == 1:
			# samostatný kámen: menší, libovolně otočený kolem svislé osy, trochu zapuštěný
			b = Basis(Vector3.UP, float(h % 360) * PI / 180.0)
			var k := 0.78 + 0.14 * float((h >> 9) % 100) / 100.0
			sc = Vector3(k, k * (0.75 + 0.2 * float((h >> 5) % 10) / 10.0), k)
			n1 += 1
		else:
			# balvan: kus natažený na obal shluku (otočení jen o 180°, aby obal seděl), lehce přerostlý
			b = Basis(Vector3.UP, PI * float((h >> 4) % 2))
			sc = ext * 1.04
			n2 += 1
		if ((h >> 7) & 1) == 1:
			b = b * Basis(Vector3.RIGHT, PI)
		var center := (Vector3(lo) + ext * 0.5) * cell
		center.y = (lo.y + sc.y * 0.5 - 0.08) * cell.y   # spodek kousek pod zemí
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[v]
		mi.transform = Transform3D(Basis.from_scale(sc * cell) * b, center)
		mi.material_override = mats[m]
		root.add_child(mi)
		tris += meshes[v].get_faces().size() / 3
	return [root, n1, n2, n3, tris]

## některé varianty mají po řezech v Blenderu obrácené pořadí vrcholů (záporný objem) → obrátit trojúhelníky
static func _fix_winding(mesh: Mesh) -> Mesh:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var vol := 0.0
	for t in range(0, ind.size(), 3):
		vol += vs[ind[t]].dot(vs[ind[t + 1]].cross(vs[ind[t + 2]]))
	# Godot: přední strana = po směru hodinových ručiček → pro správně orientovaný mesh je objem záporný
	if vol > 0.0:
		for t in range(0, ind.size(), 3):
			var a := ind[t + 1]; ind[t + 1] = ind[t + 2]; ind[t + 2] = a
		arr[Mesh.ARRAY_INDEX] = ind
		print("kamen: obrácené trojúhelníky opraveny")
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
