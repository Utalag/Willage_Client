extends RefCounted
## Stavba geometrie pro oba přístupy. Deterministické (RandomNumberGenerator se seedem).
const Par = preload("res://scripts/params.gd")

## mapa typů trávy po buňkách: 1.0 = vysoká, short/tall = nízká. Zadní řady vysoké, hranice nepravidelně po buňkách.
static func type_map(n: int, tall_rows: int, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ratio := Par.g("short_h") / Par.g("tall_h")
	var m := PackedFloat32Array()
	m.resize(n * n)
	for cz in n:
		for cx in n:
			var tall := cz < tall_rows
			var r := rng.randf()
			if cz == tall_rows - 1 and r < 0.25:
				tall = false
			elif cz == tall_rows and r < 0.3:
				tall = true
			m[cz * n + cx] = 1.0 if tall else ratio
	return m

static func type_texture(m: PackedFloat32Array, n: int) -> ImageTexture:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RF)
	for cz in n:
		for cx in n:
			img.set_pixel(cx, cz, Color(m[cz * n + cx], 0, 0))
	return ImageTexture.create_from_image(img)

## A) vrstvy: jeden ArrayMesh se všemi N čtverci nad sebou, index vrstvy v UV2.x (1 draw call)
static func shell_mesh(size: float, layers: int, max_h: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in layers:
		var f := float(i) / float(layers - 1)
		var y := f * max_h + 0.002
		var b := v.size()
		for c in [Vector2(0, 0), Vector2(size, 0), Vector2(size, size), Vector2(0, size)]:
			v.append(Vector3(c.x, y, c.y))
			uv2.append(Vector2(f, 0))
			nrm.append(Vector3.UP)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## B) jedno stéblo: zúžený pásek výšky 1, šířky 1 u kořene (UV.y = 0 kořen → 1 špička)
static func blade_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	var ts := [0.0, 0.38, 0.72]
	var ws := [0.5, 0.36, 0.2]
	for i in 3:
		for s in [-1.0, 1.0]:
			v.append(Vector3(s * ws[i], ts[i], 0))
			uv.append(Vector2(0.5 + s * 0.5, ts[i]))
			nrm.append(Vector3(0, 0, 1))
	v.append(Vector3(0, 1, 0))
	uv.append(Vector2(0.5, 1.0))
	nrm.append(Vector3(0, 0, 1))
	var idx := PackedInt32Array([0, 1, 3, 0, 3, 2, 2, 3, 5, 2, 5, 4, 4, 5, 6])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## B) MultiMesh: počet stébel na buňku podle typu; transform = otočení + měřítko (šířka, výška), custom = fáze, odstín, klidový náklon
static func blade_multimesh(m: PackedFloat32Array, n: int, cell: float, origin: Vector3, seed: int) -> MultiMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7
	var tall_h := Par.g("tall_h") * cell
	var short_h := Par.g("short_h") * cell
	var counts := PackedInt32Array()
	var total := 0
	for i in n * n:
		var c := int(Par.g("blades_tall")) if m[i] > 0.6 else int(Par.g("blades_short"))
		counts.append(c)
		total += c
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = blade_mesh()
	mm.instance_count = total
	var buf := PackedFloat32Array()
	buf.resize(total * 16)
	var k := 0
	for cz in n:
		for cx in n:
			var i := cz * n + cx
			var tall := m[i] > 0.6
			var hb := tall_h if tall else short_h
			var wb := (Par.g("blade_w_tall") if tall else Par.g("blade_w_short")) * cell
			for j in counts[i]:
				var px := origin.x + (cx + rng.randf()) * cell
				var pz := origin.z + (cz + rng.randf()) * cell
				var yaw := rng.randf() * TAU
				var hh := hb * rng.randf_range(0.6, 1.0)
				var ww := wb * rng.randf_range(0.7, 1.2)
				var b := Basis(Vector3.UP, yaw).scaled_local(Vector3(ww, hh, ww))
				var o := k * 16
				buf[o + 0] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = px
				buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = origin.y
				buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = pz
				var la := rng.randf() * TAU
				var lm := rng.randf_range(0.0, 0.25)
				buf[o + 12] = rng.randf()
				buf[o + 13] = rng.randf()
				buf[o + 14] = cos(la) * lm
				buf[o + 15] = sin(la) * lm
				k += 1
	mm.buffer = buf
	return mm

## C) trs trávy z prototypu (godot-prototyp/scripts/veg_render.gd, _tuft): n trojúhelníkových stébel do kruhu,
## normalizováno na výšku 1 (originál h = 0,42), UV.y = výška pro ohyb, barva z vrcholů (spodek tmavší)
static func tuft_mesh(n: int, base: Color, tip: Color, spread := 0.18) -> ArrayMesh:
	var h0 := 0.42
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := TAU * float(i) / n + 0.4 * i
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.05 / h0
		var hh := 0.75 + 0.25 * ((i * 37) % 10) / 10.0
		st.set_color(base); st.set_uv(Vector2(0, 0)); st.add_vertex(d * 0.04 / h0 - side)
		st.set_color(base); st.set_uv(Vector2(1, 0)); st.add_vertex(d * 0.04 / h0 + side)
		st.set_color(tip); st.set_uv(Vector2(0.5, hh)); st.add_vertex(d * spread / h0 + Vector3(0, hh, 0))
	return st.commit()

## C) kvítky z prototypu (_flower), normalizováno na výšku 1 (originál 0,35)
static func flower_mesh() -> ArrayMesh:
	var h0 := 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := Color(0.45, 0.72, 0.42)
	for i in 3:
		var a := TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.1
		for v in [[d + Vector3(-0.02, 0, 0), 0.0], [d + Vector3(0.02, 0, 0), 0.0], [d * 1.4 + Vector3(0, 0.32, 0), 0.32]]:
			st.set_color(g); st.set_uv(Vector2(0, v[1] / h0)); st.add_vertex(v[0] / h0)
		var c: Vector3 = d * 1.4 + Vector3(0, 0.32, 0)
		for k in 4:
			var b := TAU * k / 4.0
			var p1 := c + Vector3(cos(b), 0.02, sin(b)) * 0.08
			var p2 := c + Vector3(cos(b + TAU / 4.0), 0.02, sin(b + TAU / 4.0)) * 0.08
			for p in [c + Vector3(0, 0.03, 0), p1, p2]:
				st.set_color(Color.WHITE); st.set_uv(Vector2(0, p.y / h0)); st.add_vertex(p / h0)
	return st.commit()

## C) MultiMesh trsů: kind 0 = zelený trs, 1 = suchý trs, 2 = kvítky. Stejné rozmístění po buňkách jako B.
static func tuft_multimesh(kind: int, m: PackedFloat32Array, n: int, cell: float, origin: Vector3, seed: int) -> MultiMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 101 + kind * 7919
	var tall_h := Par.g("tuft_tall_h") * cell
	var short_h := Par.g("tuft_short_h") * cell
	var fcols := [Color(1.0, 0.62, 0.78), Color(1.0, 0.92, 0.45), Color(0.98, 0.98, 1.0), Color(0.75, 0.62, 1.0)]
	var items := []
	for cz in n:
		for cx in n:
			var tall := m[cz * n + cx] > 0.6
			var cnt: float
			if kind == 2:
				cnt = Par.g("flowers_tall") if tall else 0.0
			else:
				var base := Par.g("tufts_tall") if tall else Par.g("tufts_short")
				cnt = base * (Par.g("tuft_dry") if kind == 1 else 1.0 - Par.g("tuft_dry"))
			var c := int(floor(cnt)) + (1 if rng.randf() < cnt - floor(cnt) else 0)
			for j in c:
				items.append([cx, cz, tall])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	var dry_tip := Color(0.86, 0.72, 0.42)
	match kind:
		0: mm.mesh = tuft_mesh(6, Color(0.50, 0.76, 0.42), Color(0.78, 0.96, 0.60))
		1: mm.mesh = tuft_mesh(6, Color(0.62, 0.58, 0.34), dry_tip, 0.22)
		2: mm.mesh = flower_mesh()
	mm.instance_count = items.size()
	for k in items.size():
		var it = items[k]
		var tall: bool = it[2]
		var hb := tall_h if tall else short_h
		var hh := hb * rng.randf_range(0.7, 1.15)
		if kind == 2:
			hh = tall_h * rng.randf_range(0.9, 1.15)
		var wr := Par.g("tuft_w_tall") if tall else Par.g("tuft_w_short")
		var ww := hh * wr * rng.randf_range(0.85, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(ww, hh, ww))
		var pos := origin + Vector3((it[0] + rng.randf()) * cell, 0, (it[1] + rng.randf()) * cell)
		mm.set_instance_transform(k, Transform3D(b, pos))
		var la := rng.randf() * TAU
		var lm := rng.randf_range(0.0, 0.2)
		mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf(), cos(la) * lm, sin(la) * lm))
		mm.set_instance_color(k, fcols[rng.randi() % 4] if kind == 2 else Color(1, 1, 1))
	return mm
