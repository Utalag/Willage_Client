extends RefCounted
## Přístup C: hladký povrch nad voxely (Surface Nets) v low-poly fazetovém vzhledu.
## Hustota = trilineární interpolace plnosti buněk (středy buněk) + 3D šum ve fyzických souřadnicích.
## Vzorkování res bodů na buňku (výchozí 2 = fazety o velikosti půl buňky). Izoplocha 0,5.
## Barva vrcholu = materiál nejbližší plné buňky × AO (kolik hmoty je před plochou = dutina).

const Mat = preload("res://scripts/mat.gd")
static var res := 2.0         # vzorků na buňku (menší = větší fazety, víc low-poly)
static var noise_amp := 0.2
static var ledges := 0.09     # vodorovné římsy v geometrii (vrstvy horniny), 2 na buňku výšky
static var facet_jitter := 0.04  # náhodný posun vrcholů (v buňkách) → větší, nepravidelné fazety
static var sharpen := true   # zostření přechodů (smoothstep) → svislé stěny a ploché vršky jako útes
static var relax := 0          # počet průchodů vyhlazení vrcholů (0 = surová síť)

static var _occ := PackedFloat32Array()
static var _blur := PackedFloat32Array()   # průměr obsazenosti 3 × 3 × 3 = „hmotnost“ okolí
static var _ox := 0; static var _oy := 0; static var _oz := 0   # rozměry pole obsazenosti (s okrajem 1)
static var _nz: FastNoiseLite

static func _blur_at(cx: int, cy: int, cz: int) -> float:
	cx += 1; cy += 1; cz += 1
	if cx < 0 or cy < 0 or cz < 0 or cx >= _ox or cy >= _oy or cz >= _oz:
		return 0.0
	return _blur[(cx * _oz + cz) * _oy + cy]

static func _occ_at(cx: int, cy: int, cz: int) -> float:
	cx += 1; cy += 1; cz += 1
	if cx < 0 or cy < 0 or cz < 0 or cx >= _ox or cy >= _oy or cz >= _oz:
		return 0.0
	return _occ[(cx * _oz + cz) * _oy + cy]

## hustota v bodě p (souřadnice v buňkách, střed buňky i je i + 0,5)
static func density(p: Vector3, cell: Vector3) -> float:
	var q := p - Vector3(0.5, 0.5, 0.5)
	var i := Vector3i(floori(q.x), floori(q.y), floori(q.z))
	var f := q - Vector3(i)
	if sharpen:
		f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var v := 0.0
	var mass := 0.0
	for dx in 2:
		for dy in 2:
			for dz in 2:
				var w := (f.x if dx == 1 else 1.0 - f.x) * (f.y if dy == 1 else 1.0 - f.y) * (f.z if dz == 1 else 1.0 - f.z)
				if w > 0.0:
					v += w * _occ_at(i.x + dx, i.y + dy, i.z + dz)
					mass += w * _blur_at(i.x + dx, i.y + dy, i.z + dz)
	var ph := p * cell
	# osamocené kameny a malé shluky: méně šumu a říms → oblé kameny; souvislá skála: plný šum, římsy, praskliny
	var rough := smoothstep(0.12, 0.45, mass)
	var led := rough * ledges * sin(p.y * TAU * 2.0 + 1.3 * _nz.get_noise_2d(ph.x, ph.z)) * clampf(v * 4.0 * (1.0 - v), 0.0, 1.0)
	return v + (0.35 + 0.65 * rough) * noise_amp * _nz.get_noise_3d(ph.x * 2.8, ph.y * 2.8, ph.z * 2.8) + led

static func build(ch, seed: int, cell: Vector3) -> ArrayMesh:
	_nz = FastNoiseLite.new(); _nz.seed = seed + 17; _nz.frequency = 0.9; _nz.fractal_octaves = 2
	_nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ox = ch.nx + 2; _oy = ch.ny + 3; _oz = ch.nz + 2
	_occ.resize(_ox * _oy * _oz)
	for x in range(-1, ch.nx + 1):
		for z in range(-1, ch.nz + 1):
			for y in range(-1, ch.ny + 2):
				_occ[((x + 1) * _oz + (z + 1)) * _oy + (y + 1)] = 1.0 if ch.solid(x, y, z) else 0.0
	_blur.resize(_occ.size())
	for x in _ox:
		for z in _oz:
			for y in _oy:
				var a := 0.0
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						for dy in range(-1, 2):
							a += _occ_at(x - 1 + dx, y - 1 + dy, z - 1 + dz)
				_blur[(x * _oz + z) * _oy + y] = a / 27.0
	var s := 1.0 / res
	var o := Vector3(-1.0, -0.25, -1.0)          # spodek mírně pod y = 0 (podloží), aby se dno neuzavíralo
	var gx := int((ch.nx + 2) * res) + 1
	var gy := int((ch.ny + 1.25) * res) + 1
	var gz := int((ch.nz + 2) * res) + 1
	var d := PackedFloat32Array(); d.resize(gx * gy * gz)
	for i in gx:
		for k in gz:
			for j in gy:
				d[(i * gz + k) * gy + j] = density(o + Vector3(i, j, k) * s, cell) - 0.5
	# vrchol v každé krychli se změnou znaménka = průměr průsečíků hran
	var vid := {}
	var vpos := PackedVector3Array()
	var corners := [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(1,1,0), Vector3i(0,0,1), Vector3i(1,0,1), Vector3i(0,1,1), Vector3i(1,1,1)]
	var edges := [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]
	for i in gx - 1:
		for k in gz - 1:
			for j in gy - 1:
				var vals := []
				var pos := 0; var neg := 0
				for c in corners:
					var v: float = d[((i + c.x) * gz + (k + c.z)) * gy + (j + c.y)]
					vals.append(v)
					if v > 0.0: pos += 1
					else: neg += 1
				if pos == 0 or neg == 0:
					continue
				var acc := Vector3.ZERO; var cnt := 0
				for e in edges:
					var a: float = vals[e[0]]; var b: float = vals[e[1]]
					if (a > 0.0) != (b > 0.0):
						var t := a / (a - b)
						acc += Vector3(corners[e[0]]).lerp(Vector3(corners[e[1]]), t); cnt += 1
				vid[Vector3i(i, j, k)] = vpos.size()
				var hj := Vector3(_hf(i, j, k, 1), _hf(i, j, k, 2) * 0.6, _hf(i, j, k, 3)) * facet_jitter
				var vp := o + (Vector3(i, j, k) + acc / cnt) * s
				vpos.append(vp + hj * clampf(vp.y / 0.6, 0.0, 1.0))   # u země bez šumu (jinak se okraj překládá)
	# quady přes hrany mřížky se změnou znaménka
	var quads := []
	for i in range(1, gx - 1):
		for k in range(1, gz - 1):
			for j in range(1, gy - 1):
				var v0: float = d[(i * gz + k) * gy + j]
				for ax in 3:
					var e := Vector3i(1, 0, 0) if ax == 0 else (Vector3i(0, 1, 0) if ax == 1 else Vector3i(0, 0, 1))
					var ii := i + e.x; var jj := j + e.y; var kk := k + e.z
					if ii >= gx or jj >= gy or kk >= gz:
						continue
					var v1: float = d[(ii * gz + kk) * gy + jj]
					if (v0 > 0.0) == (v1 > 0.0):
						continue
					var u := Vector3i(0, 1, 0) if ax == 0 else (Vector3i(0, 0, 1) if ax == 1 else Vector3i(1, 0, 0))
					var w := Vector3i(0, 0, 1) if ax == 0 else (Vector3i(1, 0, 0) if ax == 1 else Vector3i(0, 1, 0))
					var base := Vector3i(i, j, k)
					var c := [base - u - w, base - w, base, base - u]
					var ok := true
					for cc in c:
						if not vid.has(cc): ok = false
					if not ok:
						continue
					var q := [vid[c[0]], vid[c[1]], vid[c[2]], vid[c[3]]]
					quads.append([q, v0 > 0.0, ax])
	# vyhlazení (Laplace, jen mírně) – zbaví síť schodů mřížky, fazety zůstanou
	var nbr := []; nbr.resize(vpos.size())
	for qi in quads:
		var q: Array = qi[0]
		for t in 4:
			var a: int = q[t]; var b: int = q[(t + 1) % 4]
			if nbr[a] == null: nbr[a] = {}
			if nbr[b] == null: nbr[b] = {}
			nbr[a][b] = true; nbr[b][a] = true
	for it in relax:
		var np := vpos.duplicate()
		for vi in vpos.size():
			if nbr[vi] == null or vpos[vi].y < 0.05:
				continue
			var acc := Vector3.ZERO
			for b in nbr[vi]:
				acc += vpos[b]
			np[vi] = vpos[vi].lerp(acc / nbr[vi].size(), 0.5)
		vpos = np
	# barvy a normály vrcholů
	var vcol := PackedColorArray(); vcol.resize(vpos.size())
	var vmat := PackedFloat32Array(); vmat.resize(vpos.size())
	var vn := PackedVector3Array(); vn.resize(vpos.size())
	for vi in vpos.size():
		var p := vpos[vi]
		var g := Vector3(density(p + Vector3(0.15, 0, 0), cell) - density(p - Vector3(0.15, 0, 0), cell),
			density(p + Vector3(0, 0.15, 0), cell) - density(p - Vector3(0, 0.15, 0), cell),
			density(p + Vector3(0, 0, 0.15), cell) - density(p - Vector3(0, 0, 0.15), cell))
		var n := -g.normalized() if g.length() > 1e-5 else Vector3.UP
		vn[vi] = n
		var inside := p - n * 0.35
		var m: int = ch.mat_at(floori(inside.x), floori(inside.y), floori(inside.z))
		if m == 0:
			m = _nearest_mat(ch, inside)
		var cav := clampf(density(p + n * 0.7, cell) * 1.6, 0.0, 1.0)   # hmota před plochou = dutina
		var k := 1.0 - 0.42 * cav
		var bc: Color = Mat.COLORS[m]
		vcol[vi] = Color(bc.r * k, bc.g * k, bc.b * k)
		vmat[vi] = m
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray(); var uv2s := PackedVector2Array()
	for qi in quads:
		var q: Array = qi[0]
		# orientace celého quadu podle hrany mřížky: ven = směrem od plného konce hrany (stabilní i v ostrých koutech)
		var ax: int = qi[2]
		var outd := Vector3.ZERO
		outd[ax] = -1.0 if qi[1] else 1.0
		var qn: Vector3 = (vpos[q[1]] - vpos[q[0]]).cross(vpos[q[2]] - vpos[q[0]]) + (vpos[q[2]] - vpos[q[0]]).cross(vpos[q[3]] - vpos[q[0]])
		var flip := qn.dot(outd) < 0.0   # Godot: přední strana = CW (ověřeno renderem)
		# úhlopříčka quadu: ta, u které oba trojúhelníky míří ven (nerovinné quady se jinak „přeloží“)
		var sgn := -1.0 if flip else 1.0
		var tri := [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
		var alt := [[q[0], q[1], q[3]], [q[1], q[2], q[3]]]
		if _split_score(vpos, alt, outd, sgn) > _split_score(vpos, tri, outd, sgn):
			tri = alt
		for t in tri:
			var order: Array = [t[0], t[2], t[1]] if flip else t
			for vi in order:
				verts.append(vpos[vi] * cell); norms.append(vn[vi]); cols.append(vcol[vi]); uv2s.append(Vector2(vmat[vi], 1.0))
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_TEX_UV2] = uv2s
	var am := ArrayMesh.new()
	if verts.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

static func _nearest_mat(ch, p: Vector3) -> int:
	var best := Mat.LIMESTONE; var bd := 1e9
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var m: int = ch.mat_at(c.x + dx, c.y + dy, c.z + dz)
				if m != 0:
					var dd := (Vector3(c.x + dx, c.y + dy, c.z + dz) + Vector3(0.5, 0.5, 0.5)).distance_squared_to(p)
					if dd < bd: bd = dd; best = m
	return best

static func _hf(a: int, b: int, c: int, d: int) -> float:
	var v := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	v = v ^ (v >> 16)
	return float(v & 0xFFFF) / 32768.0 - 1.0

static func _split_score(vp: PackedVector3Array, tris: Array, outd: Vector3, sgn: float) -> float:
	var sc := 1e9
	for t in tris:
		var n: Vector3 = (vp[t[1]] - vp[t[0]]).cross(vp[t[2]] - vp[t[0]])
		sc = minf(sc, sgn * n.normalized().dot(outd))
	return sc
