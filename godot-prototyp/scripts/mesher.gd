@tool
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
## dual_mask (volitelně, 17 × 17 z ShoreFields.cell_mask()): duální dlaždice ti, tj ∈ −1..15, které kreslí
## DualGridMesher; horní stěny (po čtvrtinách) a boční stěny (po polovinách) uvnitř nich se vynechají.
## discovered (volitelně, 16 × 16 × 64): 1 = ukaž skutečný materiál. Prázdné pole = nic neskrývat (x-ray / vypnuté skrytí).
## Neutrální barva a textura (hlína nebo skála) platí pro neodkryté buňky; s hloubkou se stěna mírně ztmaví.
## gen-v3 (20:14): neodkrytý vzduch pod povrchem (jeskyně, discovered != 2) se při skrytí kreslí jako plná neutrální buňka;
## wet (volitelně, voda v buňce 0..4096 z Block.water): mokrá půda pod povrchem se ztmaví, jen když je vidět skutečný materiál.
## Ložiskový jíl (12) má barvu svou, texturu jílu.
const WET_COL := Color(0.36, 0.40, 0.58)
static func build(cells: PackedByteArray, nbs: Array, slice_z: int, tint := Color(1, 1, 1), dual_mask := PackedByteArray(), discovered := PackedByteArray(), neutral_mat := 2, neutral_col := Color(0.66, 0.50, 0.40), darken := 0.25, wet := PackedInt32Array()) -> ArrayMesh:
	var use_mask := dual_mask.size() == 17 * 17
	var use_hide := discovered.size() == BS * BS * BH
	var use_wet := wet.size() == BS * BS * BH
	var top_y := BH if slice_z < 0 else mini(slice_z, BH)
	var col_hm := PackedInt32Array()
	if use_hide or use_wet:
		col_hm.resize(BS * BS)
		for x in BS:
			for z in BS:
				var src := (x * BS + z) * BH
				var h := 0
				for y in BH:
					if cells[src + y] != 0:
						h = y + 1
				col_hm[x * BS + z] = h
	var pad := PackedByteArray()
	pad.resize(P * P * PY)
	for x in BS:
		for z in BS:
			var src := (x * BS + z) * BH
			var dst := _pidx(x, z, 0)
			for y in top_y:
				var v := cells[src + y]
				if use_hide and v == Mat.AIR and y < col_hm[x * BS + z] and discovered[src + y] != 2:
					v = neutral_mat   # skrytá jeskyně: plná neutrální buňka (discovered = 0 → neutrální vzhled)
				pad[dst + y] = v
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
				var draw_m := m
				var base: Color = Mat.COLORS[m]
				if use_hide and m != Mat.FOG and discovered[(x * BS + z) * BH + y] == 0:
					draw_m = neutral_mat
					base = neutral_col
					var depth := maxi(0, col_hm[x * BS + z] - 1 - y)
					var dt := clampf(float(depth) / 24.0, 0.0, 1.0)
					var fogc := Color(0.55, 0.58, 0.62)
					base = base.lerp(fogc, dt * darken * 0.5)
					var kd := 1.0 - darken * dt
					base = Color(base.r * kd, base.g * kd, base.b * kd)
				elif use_wet and m != Mat.AIR:
					var wi := wet[(x * BS + z) * BH + y]
					if wi > 0 and y < col_hm[x * BS + z] - 1:
						base = base.lerp(WET_COL, 0.38 * clampf(wi / 1638.0, 0.0, 1.0))
				var tex_m := Mat.CLAY if draw_m == Mat.CLAY_DEPOSIT else draw_m
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
					var flip: bool = ao[0] + ao[2] > ao[1] + ao[3]
					var kk := [0.0, 0.0, 0.0, 0.0]
					for i in 4:
						kk[i] = AO_LEVELS[ao[i]] * (1.0 if n.y > 0 else (0.82 if n.y == 0 else 0.6))
					var pieces := [[0.0, 1.0, 0.0, 1.0]]   # rozsah x0, x1, z0, z1 v jednotkové buňce
					if use_mask and n.y >= 0:
						pieces = _pieces(dual_mask, x, z, n)
						if pieces.is_empty():
							continue
					for pc in pieces:
						var start := verts.size()
						for i in 4:
							var c0: Vector3 = corners[i]
							var cv := Vector3(lerpf(pc[0], pc[1], c0.x), c0.y, lerpf(pc[2], pc[3], c0.z))
							# stínění vrcholu: bilineárně z rohů stěny (u celé stěny = původní hodnota)
							var k := 0.0
							for jj in 4:
								var cj: Vector3 = corners[jj]
								var wgt := 1.0
								if n.x == 0: wgt *= cv.x if cj.x > 0.5 else 1.0 - cv.x
								if n.y == 0: wgt *= cv.y if cj.y > 0.5 else 1.0 - cv.y
								if n.z == 0: wgt *= cv.z if cj.z > 0.5 else 1.0 - cv.z
								k += wgt * kk[jj]
							uvs.append(Vector2(cv.x if ta.x != 0 else cv.y, cv.z if tb.z != 0 else cv.y))
							edges.append_array(ef)
							verts.append(Vector3(x + cv.x, (y + cv.y) * CELL_H, z + cv.z))
							norms.append(Vector3(n))
							cols.append(Color(c.r * k, c.g * k, c.b * k))
							uv2s.append(Vector2(tex_m, k * k0))
						if flip:
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

## části stěny mimo duální dlaždice: horní stěna po čtvrtinách, boční po polovinách (spodní se nedělí)
static func _pieces(mask: PackedByteArray, x: int, z: int, n: Vector3i) -> Array:
	var xs := [[0.0, 0.5, x - 1], [0.5, 1.0, x]]   # polovina buňky v ose x → dlaždice ti
	var zs := [[0.0, 0.5, z - 1], [0.5, 1.0, z]]
	if n.x != 0:
		var ti := x if n.x > 0 else x - 1
		xs = [[0.0, 1.0, ti]]
	if n.z != 0:
		var tj := z if n.z > 0 else z - 1
		zs = [[0.0, 1.0, tj]]
	var out := []
	var all := true
	for a in xs:
		for b in zs:
			if mask[(int(a[2]) + 1) * 17 + (int(b[2]) + 1)] == 1:
				all = false
			else:
				out.append([a[0], a[1], b[0], b[1]])
	if all:
		return [[0.0, 1.0, 0.0, 1.0]]
	return out

static func _solid(pad: PackedByteArray, p: Vector3i) -> bool:
	if p.x < -1 or p.z < -1 or p.y < -1 or p.x > BS or p.z > BS or p.y > BH:
		return false
	return pad[_pidx(p.x, p.z, p.y)] != 0
