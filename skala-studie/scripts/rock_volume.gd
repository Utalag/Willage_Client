extends RefCounted
## Přístup C pro celý blok: Surface Nets [1][2] jen v okolí povrchu, rozdělené na podbloky (chunky) pro rychlé úpravy.
## Nápad Jana: nezpracovávat všechny buňky, jen ty, které sousedí s povrchem; vnitřek zůstává v 3D poli.
##  - Sloupce buněk jsou 64bitové masky (bit y = plná buňka), takže „smíšené“ 2 × 2 × 2 bloky buněk
##    (něco plné, něco vzduch) se najdou několika bitovými operacemi na sloupec, bez procházení vnitřku.
##  - Hustota (šum, římsy) se počítá jen ve vzorcích uvnitř smíšených bloků; jinde je znaménko jasné
##    (plno = +0,5, vzduch = −0,5). Hodnoty se ukládají do mezipaměti (PackedFloat32Array + příznaky).
##  - Normála = gradient z 8 rohů krychle mřížky (žádné další vzorkování), dutiny = rozmazaná obsazenost.
##  - Úprava buňky zneplatní jen vzorky v okolí ±2 buněk a přestaví jen dotčené chunky.
## Tvar je stejný jako v nets_mesher.gd (přístup C ve vzorku), jen jinak spočítaný.

const Mat = preload("res://scripts/mat.gd")

var nx := 32
var nz := 32
var ny := 64
var cells := PackedByteArray()     # (x * nz + z) * ny + y
var cell := Vector3(0.5, 0.5, 0.5)
var res := 2.0
var noise_amp := 0.2
var ledges := 0.09
var facet_jitter := 0.04
var chunk := 16                    # velikost podbloku v buňkách
var seed := 7

var s := 0.5
var o := Vector3(-1.0, -0.25, -1.0)
var gx := 0; var gy := 0; var gz := 0
var d := PackedFloat32Array()
var dok := PackedByteArray()
var col := PackedInt64Array()      # sloupcové masky s okrajem 1: ((x + 1) * (nz + 2) + z + 1)
var blur := PackedFloat32Array()   # průměr 3 × 3 × 3 obsazenosti, (x+1, y+1, z+1), líně
var blok := PackedByteArray()
var nz_noise: FastNoiseLite
var cube_vid := PackedInt32Array()     # krychle mřížky -> index vrcholu v právě stavěném chunku
var cube_stamp := PackedInt32Array()
var stamp := 0
var BIT := {}
var prof := {}                         # profilování: jméno -> µs
var profiling := true
var cnt := {}                          # počítadla

func setup(cells_in: PackedByteArray, sx: int, sz: int, sy: int, cell_size: Vector3, samples_per_cell := 2.0) -> void:
	nx = sx; nz = sz; ny = sy; cells = cells_in; cell = cell_size; res = samples_per_cell
	assert(ny <= 64)
	s = 1.0 / res
	gx = int((nx + 2) * res) + 1
	gy = int((ny + 1.25) * res) + 1
	gz = int((nz + 2) * res) + 1
	d.resize(gx * gy * gz); dok.resize(gx * gy * gz); dok.fill(0)
	var nc := (gx - 1) * (gy - 1) * (gz - 1)
	cube_vid.resize(nc); cube_stamp.resize(nc); cube_stamp.fill(0)
	blur.resize((nx + 2) * (ny + 2) * (nz + 2)); blok.resize(blur.size()); blok.fill(0)
	nz_noise = FastNoiseLite.new(); nz_noise.seed = seed + 17; nz_noise.frequency = 0.9; nz_noise.fractal_octaves = 2
	nz_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for b in 64:
		BIT[1 << b] = b
	col.resize((nx + 2) * (nz + 2)); col.fill(0)
	for x in nx:
		for z in nz:
			var m := 0
			var base := (x * nz + z) * ny
			for y in ny:
				if cells[base + y] != 0:
					m |= 1 << y
			col[(x + 1) * (nz + 2) + z + 1] = m

# ---------------------------------------------------------------- obsazenost
func _col(x: int, z: int) -> int:
	if x < -1 or z < -1 or x > nx or z > nz:
		return 0
	return col[(x + 1) * (nz + 2) + z + 1]

## plná buňka? (y < 0 = podloží pod sloupcem s plnou spodní buňkou)
func occ(x: int, y: int, z: int) -> int:
	if y >= ny:
		return 0
	return (_col(x, z) >> maxi(y, 0)) & 1

func _blur_at(x: int, y: int, z: int) -> float:
	if x < -1 or z < -1 or y < -1 or x > nx or z > nz or y > ny:
		return 0.0
	var i := ((x + 1) * (nz + 2) + z + 1) * (ny + 2) + y + 1
	if blok[i]:
		return blur[i]
	var a := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := _col(x + dx, z + dz)
			if c == 0:
				continue
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < ny:
					a += (c >> maxi(yy, 0)) & 1
	blur[i] = a / 27.0
	blok[i] = 1
	return blur[i]

# ---------------------------------------------------------------- hustota
func get_d(i: int, j: int, k: int) -> float:
	var idx := (i * gz + k) * gy + j
	if dok[idx]:
		return d[idx]
	var v := _density(o + Vector3(i, j, k) * s)
	d[idx] = v
	dok[idx] = 1
	return v

func _density(p: Vector3) -> float:
	var q := p - Vector3(0.5, 0.5, 0.5)
	var cx := floori(q.x); var cy := floori(q.y); var cz := floori(q.z)
	var c00 := _col(cx, cz); var c10 := _col(cx + 1, cz); var c01 := _col(cx, cz + 1); var c11 := _col(cx + 1, cz + 1)
	var y0 := maxi(cy, 0); var y1 := maxi(cy + 1, 0)
	var o000 := (c00 >> y0) & 1 if cy < ny else 0
	var o100 := (c10 >> y0) & 1 if cy < ny else 0
	var o001 := (c01 >> y0) & 1 if cy < ny else 0
	var o101 := (c11 >> y0) & 1 if cy < ny else 0
	var o010 := (c00 >> y1) & 1 if cy + 1 < ny else 0
	var o110 := (c10 >> y1) & 1 if cy + 1 < ny else 0
	var o011 := (c01 >> y1) & 1 if cy + 1 < ny else 0
	var o111 := (c11 >> y1) & 1 if cy + 1 < ny else 0
	var sum := o000 + o100 + o001 + o101 + o010 + o110 + o011 + o111
	if sum == 0:
		return -0.5
	if sum == 8:
		return 0.5
	cnt["sum_noise"] = cnt.get("sum_noise", 0) + 1
	var f := q - Vector3(cx, cy, cz)
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var gxv := 1.0 - f.x; var gyv := 1.0 - f.y; var gzv := 1.0 - f.z
	var v := gxv * gyv * gzv * o000 + f.x * gyv * gzv * o100 + gxv * gyv * f.z * o001 + f.x * gyv * f.z * o101 \
		+ gxv * f.y * gzv * o010 + f.x * f.y * gzv * o110 + gxv * f.y * f.z * o011 + f.x * f.y * f.z * o111
	var mass := gxv * gyv * gzv * _blur_at(cx, cy, cz) + f.x * gyv * gzv * _blur_at(cx + 1, cy, cz) \
		+ gxv * gyv * f.z * _blur_at(cx, cy, cz + 1) + f.x * gyv * f.z * _blur_at(cx + 1, cy, cz + 1) \
		+ gxv * f.y * gzv * _blur_at(cx, cy + 1, cz) + f.x * f.y * gzv * _blur_at(cx + 1, cy + 1, cz) \
		+ gxv * f.y * f.z * _blur_at(cx, cy + 1, cz + 1) + f.x * f.y * f.z * _blur_at(cx + 1, cy + 1, cz + 1)
	var ph := p * cell
	var rough := smoothstep(0.12, 0.45, mass)
	var led := rough * ledges * sin(p.y * TAU * 2.0 + 1.3 * nz_noise.get_noise_2d(ph.x, ph.z)) * clampf(v * 4.0 * (1.0 - v), 0.0, 1.0)
	return v + (0.35 + 0.65 * rough) * noise_amp * nz_noise.get_noise_3d(ph.x * 2.8, ph.y * 2.8, ph.z * 2.8) + led - 0.5

# ---------------------------------------------------------------- chunky
func chunk_counts() -> Vector3i:
	return Vector3i(ceili(float(nx) / chunk), ceili(float(ny) / chunk), ceili(float(nz) / chunk))

## rozsah krychlí mřížky [a, b) na ose pro chunk c (krychle patří chunku podle polohy svého spodního rohu)
func _crange(c: int, n_ch: int, o_ax: float, g: int) -> Vector2i:
	var a := 0 if c == 0 else ceili((c * chunk - o_ax) / s)
	var b := g - 1 if c == n_ch - 1 else ceili(((c + 1) * chunk - o_ax) / s)
	return Vector2i(clampi(a, 0, g - 1), clampi(b, 0, g - 1))

func build_all() -> Array:
	var out := []
	var cc := chunk_counts()
	for a in cc.x:
		for b in cc.y:
			for c in cc.z:
				out.append([Vector3i(a, b, c), build_chunk(Vector3i(a, b, c))])
	return out

## mesh jednoho chunku (ArrayMesh, může být prázdný)
func build_chunk(ch: Vector3i) -> ArrayMesh:
	var cc := chunk_counts()
	var rx := _crange(ch.x, cc.x, o.x, gx); var ry := _crange(ch.y, cc.y, o.y, gy); var rz := _crange(ch.z, cc.z, o.z, gz)
	stamp += 1
	var t0 := Time.get_ticks_usec()
	# 1) kandidátní krychle = krychle, jejichž roh leží ve smíšeném bloku buněk (jen okolí povrchu)
	var cand := PackedInt32Array()
	var bx0 := floori(o.x + (rx.x - 1) * s - 0.5); var bx1 := floori(o.x + rx.y * s - 0.5)
	var bz0 := floori(o.z + (rz.x - 1) * s - 0.5); var bz1 := floori(o.z + rz.y * s - 0.5)
	var by0 := floori(o.y + (ry.x - 1) * s - 0.5); var by1 := floori(o.y + ry.y * s - 0.5)
	var ymask := 0
	for y in range(maxi(by0, 0), mini(by1, ny - 2) + 1):
		ymask |= 1 << y
	var ncube := Vector3i(gx - 1, gy - 1, gz - 1)
	for bx in range(maxi(bx0, -1), mini(bx1, nx - 1) + 1):
		for bz in range(maxi(bz0, -1), mini(bz1, nz - 1) + 1):
			var c1 := _col(bx, bz); var c2 := _col(bx + 1, bz); var c3 := _col(bx, bz + 1); var c4 := _col(bx + 1, bz + 1)
			var A := c1 & c2 & c3 & c4
			var O := c1 | c2 | c3 | c4
			if O == 0:
				continue
			var all2 := A & (A >> 1)
			var any2 := O | (O >> 1)
			var m := any2 & ~all2 & ymask & 0x7FFFFFFFFFFFFFFF
			var ys: Array[int] = []
			while m != 0:
				var low := m & -m
				ys.append(BIT[low])
				m ^= low
			if by0 <= -1 and (A & 1) == 0 and (O & 1) == 1:
				ys.append(-1)
			if by1 >= ny - 1 and ((O >> (ny - 1)) & 1) == 1:
				ys.append(ny - 1)
			for by in ys:
				cnt["smisene_bloky"] = cnt.get("smisene_bloky", 0) + 1
				# vzorky, jejichž blok je (bx, by, bz), a krychle, které je mají za roh
				var i0 := ceili((bx + 0.5 - o.x) / s) - 1; var i1 := ceili((bx + 1.5 - o.x) / s) - 1
				var j0 := ceili((by + 0.5 - o.y) / s) - 1; var j1 := ceili((by + 1.5 - o.y) / s) - 1
				var k0 := ceili((bz + 0.5 - o.z) / s) - 1; var k1 := ceili((bz + 1.5 - o.z) / s) - 1
				for i in range(maxi(maxi(i0, rx.x - 1), 0), mini(i1, rx.y - 1) + 1):
					for k in range(maxi(maxi(k0, rz.x - 1), 0), mini(k1, rz.y - 1) + 1):
						for j in range(maxi(maxi(j0, ry.x - 1), 0), mini(j1, ry.y - 1) + 1):
							var ci := (i * ncube.z + k) * ncube.y + j
							if cube_stamp[ci] != stamp:
								cube_stamp[ci] = stamp
								cube_vid[ci] = -2
								cand.append(ci)
	prof["kandidati"] = prof.get("kandidati", 0) + Time.get_ticks_usec() - t0
	# 2) vrcholy
	var t1 := Time.get_ticks_usec()
	var vpos := PackedVector3Array(); var vn := PackedVector3Array(); var vcol := PackedColorArray(); var vuv := PackedVector2Array()
	var own := PackedInt32Array()   # krychle uvnitř chunku (ne okraj) s vrcholem
	var vals := PackedFloat32Array(); vals.resize(8)
	for ci in cand:
		var j := ci % ncube.y; var k := (ci / ncube.y) % ncube.z; var i := ci / (ncube.y * ncube.z)
		var pos := 0
		var base_idx := (i * gz + k) * gy + j
		for t in 8:
			var idx := base_idx + ((t & 1) * gz + ((t >> 2) & 1)) * gy + ((t >> 1) & 1)
			var v: float
			if dok[idx]:
				v = d[idx]
			else:
				var th := Time.get_ticks_usec() if profiling else 0
				v = _density(o + Vector3(i + (t & 1), j + ((t >> 1) & 1), k + ((t >> 2) & 1)) * s)
				d[idx] = v; dok[idx] = 1
				if profiling: prof["hustota"] = prof.get("hustota", 0) + Time.get_ticks_usec() - th
			vals[t] = v
			if v > 0.0: pos += 1
		if pos == 0 or pos == 8:
			cube_vid[ci] = -1
			continue
		var tv := Time.get_ticks_usec() if profiling else 0
		var acc := Vector3.ZERO; var n := 0
		for e in 12:
			var a: int; var b: int
			if e < 4: a = [0, 2, 4, 6][e]; b = a + 1          # hrany podél x
			elif e < 8: a = [0, 1, 4, 5][e - 4]; b = a + 2    # podél y
			else: a = e - 8; b = a + 4                         # podél z
			var va := vals[a]; var vb := vals[b]
			if (va > 0.0) != (vb > 0.0):
				var tt := va / (va - vb)
				var pa := Vector3(a & 1, (a >> 1) & 1, (a >> 2) & 1)
				var pb := Vector3(b & 1, (b >> 1) & 1, (b >> 2) & 1)
				acc += pa.lerp(pb, tt); n += 1
		var g := Vector3(
			(vals[1] + vals[3] + vals[5] + vals[7]) - (vals[0] + vals[2] + vals[4] + vals[6]),
			(vals[2] + vals[3] + vals[6] + vals[7]) - (vals[0] + vals[1] + vals[4] + vals[5]),
			(vals[4] + vals[5] + vals[6] + vals[7]) - (vals[0] + vals[1] + vals[2] + vals[3]))
		var nrm := -g.normalized() if g.length() > 1e-6 else Vector3.UP
		var p := o + (Vector3(i, j, k) + acc / n) * s
		var hj := Vector3(_hf(i, j, k, 1), _hf(i, j, k, 2) * 0.6, _hf(i, j, k, 3)) * facet_jitter
		p += hj * clampf(p.y / 0.6, 0.0, 1.0)
		# materiál buňky kousek pod povrchem, dutina = hmota před plochou
		var ins := p - nrm * 0.35
		var m := _mat(floori(ins.x), floori(ins.y), floori(ins.z))
		if m == 0:
			m = _nearest_mat(ins)
		var fr := p + nrm * 0.7
		var cav := clampf(_blur_at(floori(fr.x), floori(fr.y), floori(fr.z)) * 2.2 - 0.3, 0.0, 1.0)
		var kk := 1.0 - 0.42 * cav
		var bc: Color = Mat.COLORS[m]
		cube_vid[ci] = vpos.size()
		vpos.append(p * cell); vn.append(nrm); vcol.append(Color(bc.r * kk, bc.g * kk, bc.b * kk)); vuv.append(Vector2(m, 1.0))
		if i >= rx.x and j >= ry.x and k >= rz.x:
			own.append(ci)
		if profiling: prof["vrcholy"] = prof.get("vrcholy", 0) + Time.get_ticks_usec() - tv
	# 3) quady přes hrany se změnou znaménka (hrana patří krychli, která ji má ve spodním rohu)
	var t2 := Time.get_ticks_usec()
	var inds := PackedInt32Array()
	for ci in own:
		var j := ci % ncube.y; var k := (ci / ncube.y) % ncube.z; var i := ci / (ncube.y * ncube.z)
		var v0 := get_d(i, j, k)
		for ax in 3:
			var e := Vector3i(1, 0, 0) if ax == 0 else (Vector3i(0, 1, 0) if ax == 1 else Vector3i(0, 0, 1))
			if (ax == 0 and (j == 0 or k == 0)) or (ax == 1 and (i == 0 or k == 0)) or (ax == 2 and (i == 0 or j == 0)):
				continue
			var v1 := get_d(i + e.x, j + e.y, k + e.z)
			if (v0 > 0.0) == (v1 > 0.0):
				continue
			var u := Vector3i(0, 1, 0) if ax == 0 else (Vector3i(0, 0, 1) if ax == 1 else Vector3i(1, 0, 0))
			var w := Vector3i(0, 0, 1) if ax == 0 else (Vector3i(1, 0, 0) if ax == 1 else Vector3i(0, 1, 0))
			var base := Vector3i(i, j, k)
			var q := PackedInt32Array()
			var ok := true
			for c in [base - u - w, base - w, base, base - u]:
				var cj: int = (c.x * ncube.z + c.z) * ncube.y + c.y
				if cube_stamp[cj] != stamp or cube_vid[cj] < 0:
					ok = false; break
				q.append(cube_vid[cj])
			if not ok:
				cnt["chybejici_quad"] = cnt.get("chybejici_quad", 0) + 1
				continue
			var outd := Vector3.ZERO
			outd[ax] = -1.0 if v0 > 0.0 else 1.0
			var qn := (vpos[q[1]] - vpos[q[0]]).cross(vpos[q[2]] - vpos[q[0]]) + (vpos[q[2]] - vpos[q[0]]).cross(vpos[q[3]] - vpos[q[0]])
			var flip := qn.dot(outd) < 0.0
			var sg := -1.0 if flip else 1.0
			var t_a := [q[0], q[1], q[2], q[0], q[2], q[3]]
			var t_b := [q[0], q[1], q[3], q[1], q[2], q[3]]
			var tri := t_b if _score(vpos, t_b, outd, sg) > _score(vpos, t_a, outd, sg) else t_a
			for tt in 2:
				if flip:
					inds.append_array([tri[tt * 3], tri[tt * 3 + 2], tri[tt * 3 + 1]])
				else:
					inds.append_array([tri[tt * 3], tri[tt * 3 + 1], tri[tt * 3 + 2]])
	prof["quady"] = prof.get("quady", 0) + Time.get_ticks_usec() - t2
	var t3 := Time.get_ticks_usec()
	var am := ArrayMesh.new()
	if inds.size() > 0:
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vpos; arr[Mesh.ARRAY_NORMAL] = vn
		arr[Mesh.ARRAY_COLOR] = vcol; arr[Mesh.ARRAY_TEX_UV2] = vuv; arr[Mesh.ARRAY_INDEX] = inds
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	prof["mesh"] = prof.get("mesh", 0) + Time.get_ticks_usec() - t3
	cnt["trojuhelniky"] = cnt.get("trojuhelniky", 0) + inds.size() / 3
	cnt["kandidatni_krychle"] = cnt.get("kandidatni_krychle", 0) + cand.size()
	prof["vrcholy_celkem"] = prof.get("vrcholy_celkem", 0) + t2 - t1
	return am

func _score(vp: PackedVector3Array, t: Array, outd: Vector3, sg: float) -> float:
	var a := (vp[t[1]] - vp[t[0]]).cross(vp[t[2]] - vp[t[0]]).normalized().dot(outd)
	var b := (vp[t[4]] - vp[t[3]]).cross(vp[t[5]] - vp[t[3]]).normalized().dot(outd)
	return minf(sg * a, sg * b)

func _mat(x: int, y: int, z: int) -> int:
	if x < 0 or z < 0 or x >= nx or z >= nz or y >= ny:
		return 0
	return cells[(x * nz + z) * ny + maxi(y, 0)]

func _nearest_mat(p: Vector3) -> int:
	var best := Mat.LIMESTONE; var bd := 1e9
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var m := _mat(c.x + dx, c.y + dy, c.z + dz)
				if m != 0:
					var dd := (Vector3(c.x + dx, c.y + dy, c.z + dz) + Vector3(0.5, 0.5, 0.5)).distance_squared_to(p)
					if dd < bd: bd = dd; best = m
	return best

static func _hf(a: int, b: int, c: int, dd: int) -> float:
	var v := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (dd * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	v = v ^ (v >> 16)
	return float(v & 0xFFFF) / 32768.0 - 1.0

# ---------------------------------------------------------------- úpravy
## nastaví buňku (0 = vykopat) a vrátí seznam chunků k přestavbě
func set_cell(x: int, y: int, z: int, m: int) -> Array:
	cells[(x * nz + z) * ny + y] = m
	var ci := (x + 1) * (nz + 2) + z + 1
	if m != 0: col[ci] |= 1 << y
	else: col[ci] &= ~(1 << y)
	# rozmazání: buňky ±1
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in range(-1, 2):
				var bx := x + dx; var by := y + dy; var bz := z + dz
				if bx >= -1 and bz >= -1 and by >= -1 and bx <= nx and bz <= nz and by <= ny:
					blok[((bx + 1) * (nz + 2) + bz + 1) * (ny + 2) + by + 1] = 0
	# vzorky, jejichž blok obsahuje buňku ±1 (hustota závisí na obsazenosti i rozmazání): bloky x−2 … x+1
	var lo := Vector3i(ceili((x - 1.5 - o.x) / s), ceili((y - 1.5 - o.y) / s), ceili((z - 1.5 - o.z) / s))
	var hi := Vector3i(ceili((x + 2.5 - o.x) / s) - 1, ceili((y + 2.5 - o.y) / s) - 1, ceili((z + 2.5 - o.z) / s) - 1)
	for i in range(maxi(lo.x, 0), mini(hi.x, gx - 1) + 1):
		for k in range(maxi(lo.z, 0), mini(hi.z, gz - 1) + 1):
			for j in range(maxi(lo.y, 0), mini(hi.y, gy - 1) + 1):
				dok[(i * gz + k) * gy + j] = 0
	# dotčené chunky: krychle lo−1 … hi (+1 kvůli okrajovým vrcholům)
	var out := []
	var cc := chunk_counts()
	for a in cc.x:
		var r := _crange(a, cc.x, o.x, gx)
		if r.y < lo.x - 1 or r.x - 1 > hi.x + 1: continue
		for b in cc.y:
			var ry := _crange(b, cc.y, o.y, gy)
			if ry.y < lo.y - 1 or ry.x - 1 > hi.y + 1: continue
			for c in cc.z:
				var rz := _crange(c, cc.z, o.z, gz)
				if rz.y < lo.z - 1 or rz.x - 1 > hi.z + 1: continue
				out.append(Vector3i(a, b, c))
	return out
