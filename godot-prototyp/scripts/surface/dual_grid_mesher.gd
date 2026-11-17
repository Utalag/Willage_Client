class_name DualGridMesher
extends RefCounted
## Duální mřížka (Oskar Stålberg / Townscaper [1][2][4]): zobrazovací dlaždice posunuté o půl buňky, roh dlaždice
## = střed datové buňky, výška se mezi středy interpoluje (smoothstep). Kreslí jen povrch louky, písku a dna;
## data, kopání, stavby, cesty, skála a útesy zůstávají na buňkách (mesher.gd dostane masku duálních dlaždic
## a jejich část vynechá). Blok vlastní dlaždice s levým horním rohem ve svých buňkách (ti, tj ∈ 0..15),
## rohy na hranici čte z okna ShoreFields → sousední bloky na sebe navazují bez švů [22][23].
## Na hranici duální a kostkové dlaždice doplní svislý „lem“ mezi křivkou svahu a schodem buněk (bez děr).
## Materiál (splat) se nepočítá na CPU: shader vzorkuje malou texturu tříd buněk s lineárním filtrem, což jsou
## přesně bilineární váhy 4 rohů dlaždice (marching squares), a přidá šum + ostrou hranici.

const Mat = preload("res://scripts/mat.gd")
const BS := 16

static func build(f, sub: int) -> ArrayMesh:
	var S := maxi(sub, 1)
	var N := BS * S + 3          # body mřížky k = −1 .. 16·S + 1 (krajní jen kvůli normálám)
	var p := float(f.pad)
	var hv := PackedFloat32Array(); hv.resize(N * N)
	for kz in N:
		var z := 0.5 + (kz - 1) / float(S)
		for kx in N:
			hv[kz * N + kx] = f.dual_h(0.5 + (kx - 1) / float(S) + p, z + p)
	var vmap := PackedInt32Array(); vmap.resize(N * N); vmap.fill(-1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	var inds := PackedInt32Array()
	var dx := 2.0 / S
	var pad: int = f.pad
	for tj in BS:
		for ti in BS:
			if not f.is_dual(ti + pad, tj + pad):
				continue
			for sz in S:
				for sx in S:
					var kx := 1 + ti * S + sx
					var kz := 1 + tj * S + sz
					var q := [kz * N + kx, kz * N + kx + 1, (kz + 1) * N + kx + 1, (kz + 1) * N + kx]
					var ids := []
					for k in q:
						if vmap[k] < 0:
							var ix: int = k % N; var iz: int = k / N
							vmap[k] = verts.size()
							verts.append(Vector3(0.5 + (ix - 1) / float(S), hv[k], 0.5 + (iz - 1) / float(S)))
							norms.append(Vector3(-(hv[k + 1] - hv[k - 1]) / dx, 1.0, -(hv[k + N] - hv[k - N]) / dx).normalized())
							cols.append(Color.WHITE)
							uv2.append(Vector2(1, 0))
						ids.append(vmap[k])
					inds.append_array([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]])
			_skirts(f, ti, tj, S, verts, norms, cols, uv2, inds)
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = inds
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## lem na hranách duální dlaždice (ti, tj), za kterými je kostková dlaždice: mezi křivkou svahu a schodem buněk
static func _skirts(f, ti: int, tj: int, S: int, verts: PackedVector3Array, norms: PackedVector3Array,
		cols: PackedColorArray, uv2: PackedVector2Array, inds: PackedInt32Array) -> void:
	var pad: int = f.pad
	var i := ti + pad; var j := tj + pad
	# [soused (di, dj), roh a, roh b, pevná osa x? , souřadnice]
	var edges := [
		[Vector2i(-1, 0), Vector2i(i, j), Vector2i(i, j + 1)],
		[Vector2i(1, 0), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)],
		[Vector2i(0, -1), Vector2i(i, j), Vector2i(i + 1, j)],
		[Vector2i(0, 1), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)],
	]
	for e in edges:
		var d: Vector2i = e[0]
		if f.is_dual(i + d.x, j + d.y):
			continue
		var a: Vector2i = e[1]; var b: Vector2i = e[2]
		var ha: float = f.hcell(a.x, a.y); var hb: float = f.hcell(b.x, b.y)
		if is_equal_approx(ha, hb):
			continue
		var ts := []
		for k in S + 1:
			ts.append(float(k) / S)
		if S % 2 == 1:
			ts.append(0.5); ts.sort()
		var ca := Vector2(a.x + 0.5, a.y + 0.5); var cb := Vector2(b.x + 0.5, b.y + 0.5)
		var hi_c: int = f.cls[a.y * f.G + a.x] if ha > hb else f.cls[b.y * f.G + b.x]
		var base: Color = Mat.COLORS[Mat.GRASS] if hi_c == f.GRASS else Mat.COLORS[Mat.SAND]
		var col := Color(base.r * 0.82, base.g * 0.82, base.b * 0.82)
		var nrm := Vector3(d.x, 0, d.y)
		for k in ts.size() - 1:
			var t0: float = ts[k]; var t1: float = ts[k + 1]
			var p0 := ca.lerp(cb, t0); var p1 := ca.lerp(cb, t1)
			var y0: float = f.dual_h(p0.x, p0.y); var y1: float = f.dual_h(p1.x, p1.y)
			var st := ha if (t0 + t1) * 0.5 < 0.5 else hb
			if absf(y0 - st) < 1e-3 and absf(y1 - st) < 1e-3:
				continue
			var q := [Vector3(p0.x - pad, y0, p0.y - pad), Vector3(p1.x - pad, y1, p1.y - pad),
				Vector3(p1.x - pad, st, p1.y - pad), Vector3(p0.x - pad, st, p0.y - pad)]
			for side in 2:   # obě strany (lem je vidět z duální i z kostkové strany)
				var s0 := verts.size()
				for v in q:
					verts.append(v); norms.append(nrm if side == 0 else -nrm); cols.append(col); uv2.append(Vector2(0, 0))
				if side == 0:
					inds.append_array([s0, s0 + 1, s0 + 2, s0, s0 + 2, s0 + 3])
				else:
					inds.append_array([s0, s0 + 2, s0 + 1, s0, s0 + 3, s0 + 2])

## vodní hladina bloku (jeden čtverec přes buňky bloku; shader zahodí místa nad hladinou podle pole výšek)
## + boční stěny vody na okraji ostrova (strana bez souseda)
## gen-v3 (20:14): u bloku s vrstvou vody v datech (Block.water) se hladina water_lz nekreslí nad „vnitřní souší“ = sloupec,
## který měl při vygenerování (hm_gen) i všech 8 sousedů v bloku povrch na úrovni hladiny nebo výš. Vykopaná jáma nebo šachta
## v souši se tak vizuálně nezaplaví (v datech tam voda není); jáma u břehu (do 1 sloupce od vody) zaplavená zůstává.
static func build_water(f, island_blocks: Dictionary) -> ArrayMesh:
	var y: float = f.wl
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var inds := PackedInt32Array()
	var blk = island_blocks.get(f.slot)
	var dry := PackedByteArray()
	if blk != null and blk.water.size() > 0 and blk.hm_gen.size() == BS * BS:
		dry.resize(BS * BS)
		var wlz: float = y / 0.5   # buňka 0,5 m
		for x in BS:
			for z in BS:
				var ok := true
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var nx: int = x + dx; var nz: int = z + dz
						if nx < 0 or nz < 0 or nx >= BS or nz >= BS:
							continue
						if blk.hm_gen[nx * BS + nz] < wlz:
							ok = false
				dry[x * BS + z] = 1 if ok else 0
	if dry.is_empty():
		verts.append_array([Vector3(0, y, 0), Vector3(BS, y, 0), Vector3(BS, y, BS), Vector3(0, y, BS)])
		for i in 4:
			norms.append(Vector3.UP); uv2.append(Vector2(1, 0))
		inds.append_array([0, 1, 2, 0, 2, 3])
	else:
		for x in BS:
			for z in BS:
				if dry[x * BS + z] == 1:
					continue
				var s0 := verts.size()
				verts.append_array([Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1)])
				for i in 4:
					norms.append(Vector3.UP); uv2.append(Vector2(1, 0))
				inds.append_array([s0, s0 + 1, s0 + 2, s0, s0 + 2, s0 + 3])
	var pad: int = f.pad
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for si in 4:
		var d: Vector2i = dirs[si]
		if island_blocks.has(f.slot + d):
			continue
		for t in BS:
			var cx := t if d.x == 0 else (BS - 1 if d.x > 0 else 0)
			var cz := t if d.y == 0 else (BS - 1 if d.y > 0 else 0)
			var h: float = f.hcell(cx + pad, cz + pad)
			if h >= y:
				continue
			var a: Vector3; var b: Vector3
			match si:
				0: a = Vector3(t, 0, 0); b = Vector3(t + 1, 0, 0)
				1: a = Vector3(BS, 0, t); b = Vector3(BS, 0, t + 1)
				2: a = Vector3(t + 1, 0, BS); b = Vector3(t, 0, BS)
				_: a = Vector3(0, 0, t + 1); b = Vector3(0, 0, t)
			var s0 := verts.size()
			for v in [Vector3(a.x, h, a.z), Vector3(b.x, h, b.z), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z)]:
				verts.append(v); norms.append(Vector3(d.x, 0, d.y)); uv2.append(Vector2(0, 0))
			inds.append_array([s0, s0 + 1, s0 + 2, s0, s0 + 2, s0 + 3])
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = inds
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
