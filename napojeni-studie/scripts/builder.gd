extends RefCounted
## Stavba obou přístupů nad stejnými daty (data.gd):
##   1 = klasická mřížka: materiál i výška na buňku, přechod řeší každá buňka na svých hranách
##       (silnější soused přesahuje pásem do slabší buňky, jako Wang/blob dlaždice) → schody, rovné břehy.
##   2 = duální mřížka: dlaždice posunuté o půl buňky, roh dlaždice = střed datové buňky; tvar i materiál
##       dlaždice vychází ze 4 rohů (marching squares) → zaoblené rohy, svahy mezi středy buněk.
## Mesh se staví po vzorcích (jako po blocích); dlaždice na hranici vzorku čte o 1 buňku víc od souseda.

const Par = preload("res://scripts/params.gd")
const D = preload("res://scripts/data.gd")

const COL_GRASS := Color(0.56, 0.80, 0.47)
const COL_SAND := Color(0.98, 0.89, 0.62)
const COL_BED := Color(0.86, 0.80, 0.60)
const COL_DIRT := Color(0.66, 0.50, 0.40)
const COL_SAND_SOIL := Color(0.90, 0.78, 0.55)

var d: D
var app: int
var P: int
var T: int
var splat := PackedFloat32Array()   # T*T*3 váhy (tráva, písek, dno)
var hgt := PackedFloat32Array()     # T*T výška povrchu
var sd := PackedFloat32Array()      # T*T vzdálenost k čáře vody (buňky, + souš, − voda)
var ged := PackedFloat32Array()     # T*T vzdálenost od okraje louky (buňky, jen uvnitř trávy)
var dtg := PackedFloat32Array()     # T*T vzdálenost k louce (buňky, jen mimo trávu) – pás „tráva v písku“
var splat_tex: ImageTexture
var field_tex: ImageTexture
var ms := {}                        # časy jednotlivých kroků
var tris := 0
## tvar duální mřížky: 0 = současná (svah střed–střed, smoothstep), 1 = posun izočáry k silnějšímu materiálu,
## 2 = plošina + krátké zkosení na hraně buňky, 3 = hybrid (malé prvky a schody > hyb_step jako kvádry, jinak duální)
var shape := 0
var feature := PackedByteArray()    # hybrid: buňka je samostatný vyvýšený prvek → kvádr nad duálním povrchem
var bh := PackedInt32Array()        # hybrid: výška (vrstvy) podkladu pod kvádry – kvádr nahrazen okolím
var bmat := PackedByteArray()       # hybrid: materiál podkladu pod kvádry
const EPS := 0.012                  # poloviční šířka svislé stěny v hybridu (× buňka)

func _init(data: D, approach: int, shape_mode := 0) -> void:
	d = data
	app = approach
	shape = shape_mode
	if shape == 3:
		_find_features()
	P = Par.i("splat_px")
	T = d.N * P

func height(x: float, z: float) -> float:
	if app == 1:
		return d.height_grid(x, z)
	if shape <= 1:
		return d.height_dual(x, z)
	var t := tile(x, z)
	if shape == 3:
		var cx := int(clampf(x, 0, d.N - 0.001)); var cz := int(clampf(z, 0, d.N - 0.001))
		if feature[d.idx(cx, cz)] == 1:
			return d.h_at(cx, cz)    # vršek kvádru
	return t[2] * _h(t[0], t[1]) + t[3] * _h(t[0] + 1, t[1]) + t[4] * _h(t[0], t[1] + 1) + t[5] * _h(t[0] + 1, t[1] + 1)

## výška / materiál pro duální povrch (u hybridu podklad bez kvádrů)
func _h(x: int, z: int) -> float:
	return bh[d.idx(x, z)] * d.cz if shape == 3 else d.h_at(x, z)

func _m(x: int, z: int) -> int:
	return bmat[d.idx(x, z)] if shape == 3 else d.m_at(x, z)

## hybrid: souvislé skupiny stejného materiálu do hyb_small buněk = samostatný prvek (kámen, trs, vršek ostrůvku)
func _find_features() -> void:
	var N := d.N
	feature.resize(N * N)
	var seen := PackedByteArray(); seen.resize(N * N)
	for i0 in N * N:
		if seen[i0] == 1:
			continue
		var m := d.mat[i0]
		var comp := [i0]
		var stack := [i0]
		seen[i0] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % N; var z := i / N
			for dd in D.DIRS:
				var nx: int = x + dd.x; var nz: int = z + dd.y
				if not d.inside(nx, nz):
					continue
				var j := nz * N + nx
				if seen[j] == 0 and d.mat[j] == m:
					seen[j] = 1
					stack.append(j)
					comp.append(j)
		if comp.size() <= Par.i("hyb_small"):
			for i in comp:
				feature[i] = 1
	# podklad: buňka prvku dostane materiál a výšku okolí; kvádr jen když prvek není níž než okolí
	bh = d.hl.duplicate()
	bmat = d.mat.duplicate()
	for i in N * N:
		if feature[i] == 0:
			continue
		var x := i % N; var z := i / N
		var cnt := [0, 0, 0]
		var hs := []
		for dd in D.DIRS:
			if d.inside(x + dd.x, z + dd.y):
				var j: int = (z + dd.y) * N + x + dd.x
				if feature[j] == 0:
					cnt[d.mat[j]] += 1
					hs.append(d.hl[j])
		if hs.is_empty():
			feature[i] = 0
			continue
		hs.sort()
		var hb: int = hs[hs.size() / 2]
		if hb > d.hl[i]:
			feature[i] = 0      # prohlubeň: necháme duální mřížce
			continue
		var best := 0
		for k in 3:
			if cnt[k] > cnt[best]:
				best = k
		bh[i] = hb
		bmat[i] = best

## šířka zkosení pro dvojici sousedních buněk (stejná z obou stran → bez trhlin mezi dlaždicemi)
func pair_bevel(ax: int, az: int, bx: int, bz: int) -> float:
	if shape == 2:
		return Par.g("bevel")
	var ia := d.idx(ax, az); var ib := d.idx(bx, bz)
	var sharp := absi(bh[ia] - bh[ib]) >= Par.i("hyb_step")
	return EPS * 2.0 if sharp else Par.g("hyb_bevel")

## náběh 0→1 přes hranu buňky (t = 0,5) o šířce b, vyhlazený
static func ramp(t: float, b: float) -> float:
	var u := clampf((t - 0.5) / maxf(b, 1e-4) + 0.5, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## dlaždice v bodě: [i0, j0, wa, wb, wc, wd] – váhy 4 rohů (středů buněk) pro výšku i materiál (tvary 2 a 3)
func tile(x: float, z: float) -> Array:
	var gx := x - 0.5; var gz := z - 0.5
	var i0 := int(floor(gx)); var j0 := int(floor(gz))
	var fx := gx - i0; var fz := gz - j0
	var ext := ramp(fx, pair_bevel(i0, j0, i0 + 1, j0))
	var exb := ramp(fx, pair_bevel(i0, j0 + 1, i0 + 1, j0 + 1))
	# svislý směr: náběh levé a pravé hrany dlaždice zvlášť, mezi nimi lineárně (hrany sedí se sousední dlaždicí)
	var ez := lerpf(ramp(fz, pair_bevel(i0, j0, i0, j0 + 1)), ramp(fz, pair_bevel(i0 + 1, j0, i0 + 1, j0 + 1)), fx)
	return [i0, j0, (1.0 - ext) * (1.0 - ez), ext * (1.0 - ez), (1.0 - exb) * ez, exb * ez]

## souřadnice čar sítě v úseku [a, b] (dlaždice začínají ve středech buněk)
func _lines(a: float, b: float) -> PackedFloat32Array:
	var offs := []
	var S := Par.i("dual_sub")
	if shape == 2:
		var bv := Par.g("bevel")
		offs = [0.0, 0.5 - bv * 0.5, 0.5 - bv * 0.25, 0.5, 0.5 + bv * 0.25, 0.5 + bv * 0.5]
	else:
		for k in S:
			offs.append(float(k) / S)
		if shape == 3:
			offs.append_array([0.5 - EPS, 0.5 + EPS])
	var out := [a, b]
	for c in range(int(floor(a - 0.5)) - 1, int(ceil(b)) + 1):
		for o in offs:
			var x: float = c + 0.5 + o
			if x > a + 1e-4 and x < b - 1e-4:
				out.append(x)
	out.sort()
	return PackedFloat32Array(out)

# ------------------------------------------------------------------ materiálová mapa (splat)
func build_splat() -> void:
	var t0 := Time.get_ticks_usec()
	var nz := FastNoiseLite.new()
	nz.seed = Par.i("seed") + 77
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.9
	nz.fractal_octaves = 2
	splat.resize(T * T * 3)
	hgt.resize(T * T)
	var band := Par.g("edge_band")
	var en := Par.g("edge_noise")
	var es := Par.g("edge_soft")
	var dn := Par.g("dual_noise")
	var dsf := Par.g("dual_soft")
	for tz in T:
		for tx in T:
			var x := (tx + 0.5) / P
			var z := (tz + 0.5) / P
			var nv := nz.get_noise_2d(x * d.cxy, z * d.cxy)
			var w := [0.0, 0.0, 0.0]
			if app == 1:
				var cx := int(x); var cz := int(z)
				var u := x - cx; var v := z - cz
				var m := d.m_at(cx, cz)
				var b := band * (1.0 + en * nv)
				var other := 0.0
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx == 0 and dz == 0) or not d.inside(cx + dx, cz + dz):
							continue
						var k := d.m_at(cx + dx, cz + dz)
						if D.PRIO[k] <= D.PRIO[m]:
							continue
						var dist: float
						if dx != 0 and dz != 0:
							dist = Vector2(u, v).distance_to(Vector2(1.0 if dx > 0 else 0.0, 1.0 if dz > 0 else 0.0))
						elif dx != 0:
							dist = 1.0 - u if dx > 0 else u
						else:
							dist = 1.0 - v if dz > 0 else v
						var e := 1.0 - smoothstep(b - es, b + es, dist)
						w[k] = maxf(w[k], e)
						other = maxf(other, e)
				w[m] = 1.0 - other
			else:
				var gx := x - 0.5; var gz := z - 0.5
				var i0 := int(floor(gx)); var j0 := int(floor(gz))
				var fx := gx - i0; var fz := gz - j0
				if shape >= 2:
					var t := tile(x, z)
					w[_m(i0, j0)] += t[2]
					w[_m(i0 + 1, j0)] += t[3]
					w[_m(i0, j0 + 1)] += t[4]
					w[_m(i0 + 1, j0 + 1)] += t[5]
				else:
					w[d.m_at(i0, j0)] += (1.0 - fx) * (1.0 - fz)
					w[d.m_at(i0 + 1, j0)] += fx * (1.0 - fz)
					w[d.m_at(i0, j0 + 1)] += (1.0 - fx) * fz
					w[d.m_at(i0 + 1, j0 + 1)] += fx * fz
				if shape == 3 and feature[d.idx(int(x), int(z))] == 1:
					w = [0.0, 0.0, 0.0]
					w[d.m_at(int(x), int(z))] = 1.0
				if shape == 1:
					# posun izočáry: silnější (vyvýšený) materiál dostane náskok → osamělá buňka si drží skoro celou plochu
					for k in 3:
						if w[k] > 0.0:
							w[k] += Par.g("iso_bias") * D.PRIO[k] * 0.5
				w[D.GRASS] += dn * nv
				w[D.SAND] -= dn * nv * 0.5
				var wm := maxf(w[0], maxf(w[1], w[2]))
				for k in 3:
					w[k] = clampf((w[k] - wm + dsf) / dsf, 0.0, 1.0)
			var s: float = w[0] + w[1] + w[2]
			var i := tz * T + tx
			for k in 3:
				splat[i * 3 + k] = w[k] / maxf(s, 1e-5)
			hgt[i] = height(x, z)
	ms["splat"] = (Time.get_ticks_usec() - t0) / 1000.0

# ------------------------------------------------------------------ vzdálenostní pole (voda, okraj louky)
func build_fields() -> void:
	var t0 := Time.get_ticks_usec()
	var water := PackedByteArray(); water.resize(T * T)
	var land := PackedByteArray(); land.resize(T * T)
	var notgrass := PackedByteArray(); notgrass.resize(T * T)
	for i in T * T:
		var wet := hgt[i] < d.wl
		water[i] = 1 if wet else 0
		land[i] = 0 if wet else 1
		notgrass[i] = 1 if (wet or splat[i * 3] < 0.5) else 0
	var to_water := _chamfer(water)
	var to_land := _chamfer(land)
	var to_edge := _chamfer(notgrass)
	var isgrass := PackedByteArray(); isgrass.resize(T * T)
	for i in T * T:
		isgrass[i] = 1 - notgrass[i] if land[i] == 1 else 0
	var to_grass := _chamfer(isgrass)
	dtg.resize(T * T)
	sd.resize(T * T)
	ged.resize(T * T)
	for i in T * T:
		sd[i] = (to_water[i] if land[i] == 1 else -to_land[i]) / P
		ged[i] = to_edge[i] / P
		dtg[i] = to_grass[i] / P
	# textury pro shadery
	var si := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	var fi := Image.create_empty(T, T, false, Image.FORMAT_RGBAH)
	for tz in T:
		for tx in T:
			var i := tz * T + tx
			si.set_pixel(tx, tz, Color(splat[i * 3], splat[i * 3 + 1], splat[i * 3 + 2], 1.0))
			fi.set_pixel(tx, tz, Color(hgt[i], clampf(sd[i], -8.0, 8.0), minf(ged[i], 8.0), minf(dtg[i], 8.0)))
	splat_tex = ImageTexture.create_from_image(si)
	field_tex = ImageTexture.create_from_image(fi)
	ms["fields"] = (Time.get_ticks_usec() - t0) / 1000.0

## dvouprůchodová chamfer vzdálenost (texely) k nejbližšímu texelu se src = 1; okraj scény se nepočítá jako hranice
func _chamfer(src: PackedByteArray) -> PackedFloat32Array:
	var dd := PackedFloat32Array(); dd.resize(T * T)
	var INF := 1e6
	for i in T * T:
		dd[i] = 0.0 if src[i] == 1 else INF
	const R2 := 1.4142
	for z in T:
		for x in T:
			var i := z * T + x
			var v := dd[i]
			if v == 0.0:
				continue
			if x > 0: v = minf(v, dd[i - 1] + 1.0)
			if z > 0:
				v = minf(v, dd[i - T] + 1.0)
				if x > 0: v = minf(v, dd[i - T - 1] + R2)
				if x < T - 1: v = minf(v, dd[i - T + 1] + R2)
			dd[i] = v
	for z in range(T - 1, -1, -1):
		for x in range(T - 1, -1, -1):
			var i := z * T + x
			var v := dd[i]
			if v == 0.0:
				continue
			if x < T - 1: v = minf(v, dd[i + 1] + 1.0)
			if z < T - 1:
				v = minf(v, dd[i + T] + 1.0)
				if x < T - 1: v = minf(v, dd[i + T + 1] + R2)
				if x > 0: v = minf(v, dd[i + T - 1] + R2)
			dd[i] = v
	return dd

func tex_at(arr: PackedFloat32Array, x: float, z: float) -> float:
	var tx := clampi(int(x * P), 0, T - 1)
	var tz := clampi(int(z * P), 0, T - 1)
	return arr[tz * T + tx]

func grass_at(x: float, z: float) -> float:
	var tx := clampi(int(x * P), 0, T - 1)
	var tz := clampi(int(z * P), 0, T - 1)
	return splat[(tz * T + tx) * 3]

# ------------------------------------------------------------------ meshe
class MB:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cus := PackedFloat32Array()
	var idx := PackedInt32Array()
	func quad(p: Array, n: Vector3, c: Color, top: float, edges: Array) -> void:
		var s := v.size()
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in 4:
			v.append(p[k]); nrm.append(n); col.append(c); uv.append(uvs[k]); uv2.append(Vector2(top, 0))
			cus.append_array(edges)
		idx.append_array([s, s + 1, s + 2, s, s + 2, s + 3])
	func commit() -> ArrayMesh:
		var am := ArrayMesh.new()
		if v.is_empty():
			return am
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_CUSTOM0] = cus
		arr[Mesh.ARRAY_INDEX] = idx
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		return am

func _hn(x: int, z: int) -> float:
	return d.h_at(x, z) if d.inside(x, z) else 0.0

## mesh jednoho vzorku (sx, sz)
func sample_mesh(sx: int, sz: int) -> ArrayMesh:
	var mb := MB.new()
	if app == 1:
		_grid_mesh(mb, sx, sz)
	else:
		_dual_mesh(mb, sx, sz)
	tris += mb.idx.size() / 3
	return mb.commit()

func _mat_col(m: int) -> Color:
	return [COL_GRASS, COL_SAND, COL_BED][m]

func _soil_col(m: int) -> Color:
	return COL_DIRT if m == D.GRASS else COL_SAND_SOIL

func _grid_mesh(mb: MB, sx: int, sz: int) -> void:
	var c := d.cxy
	for z in range(sz * d.n, sz * d.n + d.n):
		for x in range(sx * d.n, sx * d.n + d.n):
			var h := d.h_at(x, z)
			var m := d.m_at(x, z)
			var lw := [1.0 if _hn(x - 1, z) < h else 0.0, 1.0 if _hn(x + 1, z) < h else 0.0,
				1.0 if _hn(x, z - 1) < h else 0.0, 1.0 if _hn(x, z + 1) < h else 0.0]
			mb.quad([Vector3(x * c, h, z * c), Vector3((x + 1) * c, h, z * c), Vector3((x + 1) * c, h, (z + 1) * c), Vector3(x * c, h, (z + 1) * c)],
				Vector3.UP, _mat_col(m), 1.0, lw)
			var hl: int = d.hl[d.idx(x, z)]
			for dir in D.DIRS:
				var nh := _hn(x + dir.x, z + dir.y)
				if nh >= h:
					continue
				var t := Vector2i(1, 0) if dir.x == 0 else Vector2i(0, 1)
				var bx := float(x + (1 if dir.x > 0 else 0))
				var bz := float(z + (1 if dir.y > 0 else 0))
				for L in range(int(floor(nh / d.cz + 0.001)), hl):
					var y0 := L * d.cz
					var y1 := (L + 1) * d.cz
					var p0 := Vector3(bx * c, y0, bz * c)
					var tv := Vector3(t.x * c, 0, t.y * c)
					var e := [1.0 if _hn(x - t.x, z - t.y) <= y0 else 0.0, 1.0 if _hn(x + t.x, z + t.y) <= y0 else 0.0,
						0.0, 1.0 if L == hl - 1 else 0.0]
					mb.quad([p0, p0 + tv, p0 + tv + Vector3(0, d.cz, 0), p0 + Vector3(0, d.cz, 0)],
						Vector3(dir.x, 0, dir.y), _mat_col(m) if L == hl - 1 else _soil_col(m), 0.0, e)

## hybrid: samostatné prvky jako kvádry (vršek v barvě materiálu, boky po vrstvách, obrysy jako v přístupu 1)
func _feature_blocks(mb: MB, sx: int, sz: int) -> void:
	var c := d.cxy
	for z in range(sz * d.n, sz * d.n + d.n):
		for x in range(sx * d.n, sx * d.n + d.n):
			if feature[d.idx(x, z)] == 0:
				continue
			var h := d.h_at(x, z)
			var m := d.m_at(x, z)
			var y := h + 0.004
			mb.quad([Vector3(x * c, y, z * c), Vector3((x + 1) * c, y, z * c), Vector3((x + 1) * c, y, (z + 1) * c), Vector3(x * c, y, (z + 1) * c)],
				Vector3.UP, _mat_col(m), 0.0, [1.0, 1.0, 1.0, 1.0])
			for dir in D.DIRS:
				var t := Vector2i(1, 0) if dir.x == 0 else Vector2i(0, 1)
				var bx := float(x + (1 if dir.x > 0 else 0))
				var bz := float(z + (1 if dir.y > 0 else 0))
				var y0 := minf(height(bx + (t.x * 0.5 if dir.x == 0 else dir.x * 0.05), bz + (t.y * 0.5 if dir.y == 0 else dir.y * 0.05)), h) - 0.3
				var p0 := Vector3(bx * c, y0, bz * c)
				var tv := Vector3(t.x * c, 0, t.y * c)
				mb.quad([p0, p0 + tv, p0 + tv + Vector3(0, y - y0, 0), p0 + Vector3(0, y - y0, 0)],
					Vector3(dir.x, 0, dir.y), _mat_col(m) if y - y0 < d.cz * 1.2 else _soil_col(m), 0.0, [1.0, 1.0, 0.0, 1.0])

func _region(s: int) -> Vector2:
	var a := 0.0 if s == 0 else s * d.n + 0.5
	var b := float(d.N) if s == 1 else s * d.n + d.n + 0.5
	return Vector2(a, b)

func _dual_mesh(mb: MB, sx: int, sz: int) -> void:
	var c := d.cxy
	var S := Par.i("dual_sub")
	var rx := _region(sx); var rz := _region(sz)
	var lx := _lines(rx.x, rx.y); var lz := _lines(rz.x, rz.y)
	var nx := lx.size() - 1; var nzz := lz.size() - 1
	var z0 := [0.0, 0.0, 0.0, 0.0]
	var e := 0.05
	var hv := []
	for j in nzz + 1:
		for i in nx + 1:
			hv.append(Vector3(lx[i] * c, height(lx[i], lz[j]), lz[j] * c))
	var flat := shape >= 2   # tvary se zkosením: ploché normály (svislé stěny by vyhlazení rozmazalo)
	for j in nzz:
		for i in nx:
			var p: Array = [hv[j * (nx + 1) + i], hv[j * (nx + 1) + i + 1], hv[(j + 1) * (nx + 1) + i + 1], hv[(j + 1) * (nx + 1) + i]]
			var s := mb.v.size()
			var fn := Vector3.UP
			if flat:
				fn = (p[3] - p[1]).cross(p[2] - p[0]).normalized()
				if fn.y < 0.0:
					fn = -fn
			for k in 4:
				var q: Vector3 = p[k]
				var nn := fn
				if not flat:
					var x := q.x / c; var z := q.z / c
					nn = Vector3(-(height(x + e, z) - height(x - e, z)) / (2 * e * c), 1.0, -(height(x, z + e) - height(x, z - e)) / (2 * e * c)).normalized()
				mb.v.append(q); mb.nrm.append(nn); mb.col.append(Color.WHITE); mb.uv.append(Vector2.ZERO); mb.uv2.append(Vector2(1, 0))
				mb.cus.append_array(z0)
			mb.idx.append_array([s, s + 1, s + 2, s, s + 2, s + 3])
	if shape == 3:
		_feature_blocks(mb, sx, sz)
	# boky dioramatu na okraji scény (jen vlastník okraje)
	var sides := []
	if sz == 0: sides.append([Vector2i(0, -1), rz.x])
	if sz == 1: sides.append([Vector2i(0, 1), rz.y])
	if sx == 0: sides.append([Vector2i(-1, 0), rx.x])
	if sx == 1: sides.append([Vector2i(1, 0), rx.y])
	for sd_ in sides:
		var dir: Vector2i = sd_[0]
		var fix: float = sd_[1]
		var r := rx if dir.x == 0 else rz
		var ls := lx if dir.x == 0 else lz
		for k in ls.size() - 1:
			var a := ls[k]; var b := ls[k + 1]
			var pa := Vector2(a, fix) if dir.x == 0 else Vector2(fix, a)
			var pb := Vector2(b, fix) if dir.x == 0 else Vector2(fix, b)
			var ha := height(pa.x, pa.y); var hb := height(pb.x, pb.y)
			var mid := (pa + pb) * 0.5
			var m := d.m_at(int(clampf(mid.x, 0, d.N - 0.01)), int(clampf(mid.y, 0, d.N - 0.01)))
			var s := mb.v.size()
			for q in [Vector3(pa.x * c, 0, pa.y * c), Vector3(pb.x * c, 0, pb.y * c), Vector3(pb.x * c, hb, pb.y * c), Vector3(pa.x * c, ha, pa.y * c)]:
				mb.v.append(q); mb.nrm.append(Vector3(dir.x, 0, dir.y)); mb.col.append(_soil_col(m))
				mb.uv.append(Vector2(0.5, q.y / maxf(ha, hb))); mb.uv2.append(Vector2(0, 0))
				mb.cus.append_array([0.0, 0.0, 0.0, 1.0])
			mb.idx.append_array([s, s + 1, s + 2, s, s + 2, s + 3])

## vodní hladina + boční stěny vody na okraji scény (pro oba přístupy stejné)
func water_mesh() -> ArrayMesh:
	var mb := MB.new()
	var c := d.cxy
	var L := d.N * c
	var y := d.wl
	mb.quad([Vector3(0, y, 0), Vector3(L, y, 0), Vector3(L, y, L), Vector3(0, y, L)], Vector3.UP, Color.WHITE, 1.0, [0.0, 0.0, 0.0, 0.0])
	var S := 8
	for side in 4:
		for k in d.N * S:
			var a := float(k) / S; var b := float(k + 1) / S
			var pa: Vector2; var pb: Vector2; var nv: Vector3
			match side:
				0: pa = Vector2(a, 0); pb = Vector2(b, 0); nv = Vector3(0, 0, -1)
				1: pa = Vector2(a, d.N); pb = Vector2(b, d.N); nv = Vector3(0, 0, 1)
				2: pa = Vector2(0, a); pb = Vector2(0, b); nv = Vector3(-1, 0, 0)
				_: pa = Vector2(d.N, a); pb = Vector2(d.N, b); nv = Vector3(1, 0, 0)
			var ha := height(clampf(pa.x, 0.001, d.N - 0.001), clampf(pa.y, 0.001, d.N - 0.001))
			var hb := height(clampf(pb.x, 0.001, d.N - 0.001), clampf(pb.y, 0.001, d.N - 0.001))
			if ha >= y and hb >= y:
				continue
			mb.quad([Vector3(pa.x * c, minf(ha, y), pa.y * c), Vector3(pb.x * c, minf(hb, y), pb.y * c), Vector3(pb.x * c, y, pb.y * c), Vector3(pa.x * c, y, pa.y * c)],
				nv, Color.WHITE, 0.0, [0.0, 0.0, 0.0, 0.0])
	return mb.commit()
