extends RefCounted
## Kostkový mesher: kreslí jen stěny sousedící se vzduchem, AO ve vrcholech, výška buňky 0,5.
## Okraje sousedních bloků se načtou do obalu 18 × 18 × 66, takže mezi bloky nevznikají zbytečné stěny.

const Mat = preload("res://scripts/mat.gd")
const BS := 16
const BH := 64
const CELL_H := 0.5
const P := BS + 2
const PY := BH + 2

const FACES := [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)]],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
]
const AO_LEVELS := [0.62, 0.76, 0.89, 1.0]

static func _pidx(x: int, z: int, y: int) -> int:
	return ((x + 1) * P + (z + 1)) * PY + (y + 1)

## cells: buňky bloku; nbs: Array[4] buněk sousedů (S, V, J, Z) nebo null; slice_z: -1 = bez řezu
static func build(cells: PackedByteArray, nbs: Array, slice_z: int, tint := Color(1, 1, 1)) -> ArrayMesh:
	var top_y := BH if slice_z < 0 else mini(slice_z, BH)
	var pad := PackedByteArray()
	pad.resize(P * P * PY)
	for x in BS:
		for z in BS:
			var src := (x * BS + z) * BH
			var dst := _pidx(x, z, 0)
			for y in top_y:
				pad[dst + y] = cells[src + y]
	# okraje sousedů: S (-z), V (+x), J (+z), Z (-x)
	for si in 4:
		var nc = nbs[si]
		if nc == null:
			continue
		for t in BS:
			var x: int; var z: int; var nx: int; var nz: int
			match si:
				0: x = t; z = -1; nx = t; nz = BS - 1
				1: x = BS; z = t; nx = 0; nz = t
				2: x = t; z = BS; nx = t; nz = 0
				_: x = -1; z = t; nx = BS - 1; nz = t
			var src := (nx * BS + nz) * BH
			var dst := _pidx(x, z, 0)
			for y in top_y:
				pad[dst + y] = nc[src + y]

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var inds := PackedInt32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()     # UV2: (materiál, stínění vrcholu) pro texturovaný režim
	var edges := PackedFloat32Array()  # CUSTOM0: které hrany stěny jsou obrys (u0, u1, v0, v1)
	for x in BS:
		for z in BS:
			for y in top_y:
				var m: int = pad[_pidx(x, z, y)]
				if m == Mat.AIR:
					continue
				var base: Color = Mat.COLORS[m]
				var r := float(absi((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) % 1000) / 1000.0
				var k0 := 0.95 + r * 0.07
				var c := Color(base.r * k0 * tint.r, base.g * k0 * tint.g, base.b * k0 * tint.b)
				for f in FACES:
					var n: Vector3i = f[0]
					if pad[_pidx(x + n.x, z + n.z, y + n.y)] != 0:
						continue
					var corners: Array = f[1]
					var ao := [0, 0, 0, 0]
					for i in 4:
						var cnr: Vector3 = corners[i]
						var o := Vector3i(x + n.x, y + n.y, z + n.z)
						var off := Vector3i(int(cnr.x) * 2 - 1, int(cnr.y) * 2 - 1, int(cnr.z) * 2 - 1)
						var a1 := Vector3i.ZERO
						var a2 := Vector3i.ZERO
						if n.x != 0:
							a1 = Vector3i(0, off.y, 0); a2 = Vector3i(0, 0, off.z)
						elif n.y != 0:
							a1 = Vector3i(off.x, 0, 0); a2 = Vector3i(0, 0, off.z)
						else:
							a1 = Vector3i(off.x, 0, 0); a2 = Vector3i(0, off.y, 0)
						var s1 := 1 if _solid(pad, o + a1) else 0
						var s2 := 1 if _solid(pad, o + a2) else 0
						var sc := 1 if _solid(pad, o + a1 + a2) else 0
						ao[i] = 0 if (s1 and s2) else 3 - (s1 + s2 + sc)
					# tečné osy stěny a obrysové hrany: soused ve směru tečny je vzduch (sráz / vypouklý roh)
					var ta := Vector3i(1, 0, 0) if n.x == 0 else Vector3i(0, 1, 0)
					var tb := Vector3i(0, 0, 1) if n.z == 0 else Vector3i(0, 1, 0)
					var c3 := Vector3i(x, y, z)
					var ef := [
						1.0 if not _solid(pad, c3 - ta) else 0.0, 1.0 if not _solid(pad, c3 + ta) else 0.0,
						1.0 if not _solid(pad, c3 - tb) else 0.0, 1.0 if not _solid(pad, c3 + tb) else 0.0]
					var start := verts.size()
					for i in 4:
						var cv: Vector3 = corners[i]
						uvs.append(Vector2(cv.x if ta.x != 0 else cv.y, cv.z if tb.z != 0 else cv.y))
						edges.append_array(ef)
						verts.append(Vector3(x + cv.x, (y + cv.y) * CELL_H, z + cv.z))
						norms.append(Vector3(n))
						var k: float = AO_LEVELS[ao[i]] * (1.0 if n.y > 0 else (0.82 if n.y == 0 else 0.6))
						cols.append(Color(c.r * k, c.g * k, c.b * k))
						uv2s.append(Vector2(m, k * k0))
					if ao[0] + ao[2] > ao[1] + ao[3]:
						inds.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
					else:
						inds.append_array([start, start + 1, start + 3, start + 1, start + 2, start + 3])
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = inds
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_CUSTOM0] = edges
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return am

static func _solid(pad: PackedByteArray, p: Vector3i) -> bool:
	if p.x < -1 or p.z < -1 or p.y < -1 or p.x > BS or p.z > BS or p.y > BH:
		return false
	return pad[_pidx(p.x, p.z, p.y)] != 0
