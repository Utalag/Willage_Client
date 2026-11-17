extends RefCounted
## Tráva varianta C (schválená pro louky, trava-studie): trsy a kvítky z veg-v2 jako instance MultiMesh.
## Rozmístění podle materiálové mapy daného přístupu (tráva jen tam, kde splat říká trávu a povrch je nad vodou).
## thin = doplněk „řídnutí k okraji“: hustota a výška trsů klesají v pásu thin_w od okraje louky, přibývá suchých trsů.

const Par = preload("res://scripts/params.gd")

## trs trávy z prototypu (veg_render.gd, _tuft), normalizovaný na výšku 1 (kopie z trava-studie/grass_build.gd)
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

## vrací [MultiMesh zelené, suché, kvítky] pro jeden vzorek; bld = builder daného přístupu
static func build(bld, sx: int, sz: int, thin: bool, mix := false) -> Array:
	var d = bld.d
	var c: float = d.cxy
	var rng := RandomNumberGenerator.new()
	rng.seed = Par.i("seed") * 31 + sx * 7 + sz * 13 + bld.app * 101   # stejné náhodné pozice pro thin i bez
	var th := Par.g("tuft_h") * c
	var items := [[], [], []]
	var fcols := [Color(1.0, 0.62, 0.78), Color(1.0, 0.92, 0.45), Color(0.98, 0.98, 1.0), Color(0.75, 0.62, 1.0)]
	var tw := Par.g("thin_w")
	for z in range(sz * d.n, sz * d.n + d.n):
		for x in range(sx * d.n, sx * d.n + d.n):
			var cnt := Par.i("tufts") + 1
			for j in cnt:
				var is_flower := j == cnt - 1
				var px := x + rng.randf(); var pz := z + rng.randf()
				var r_keep := rng.randf(); var r_dry := rng.randf(); var r_h := rng.randf_range(0.7, 1.15)
				var yaw := rng.randf() * TAU; var r_w := rng.randf_range(0.85, 1.2)
				var cd := Color(rng.randf(), rng.randf(), 0, 0)
				var la := rng.randf() * TAU; var lm := rng.randf_range(0.0, 0.2)
				cd.b = cos(la) * lm; cd.a = sin(la) * lm
				var fc: Color = fcols[rng.randi() % 4]
				if is_flower and r_keep > Par.g("flowers"):
					continue
				var mixk := 0.0
				if mix:
					# řídké nízké trsy v pásu „tráva v písku“ (jen mimo louku)
					if is_flower or bld.grass_at(px, pz) >= 0.5:
						continue
					var dg: float = bld.tex_at(bld.dtg, px, pz)
					mixk = 1.0 - smoothstep(0.0, Par.g("band_grass"), dg)
					if r_keep > Par.g("mix_tufts") * mixk:
						continue
				elif bld.grass_at(px, pz) < 0.5:
					continue
				var y: float = bld.height(px, pz)
				if y < d.wl + 0.02:
					continue
				var k := 1.0
				if thin:
					k = smoothstep(0.0, tw, bld.tex_at(bld.ged, px, pz))
					if not is_flower and r_keep > lerpf(Par.g("thin_min"), 1.0, k):
						continue
					if is_flower and k < 0.75:
						continue
				if mix:
					k = 0.35 + 0.4 * mixk
				var kind := 2 if is_flower else (1 if r_dry < Par.g("tuft_dry") + (0.3 * (1.0 - k) if thin else 0.0) else 0)
				var hh := th * r_h * (lerpf(0.5, 1.0, k) if kind != 2 else 1.0)
				var ww := hh * r_w
				var b := Basis(Vector3.UP, yaw).scaled_local(Vector3(ww, hh, ww))
				items[kind].append([Transform3D(b, Vector3(px * c, y, pz * c)), cd, fc if kind == 2 else Color.WHITE])
	var out := []
	for kind in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		match kind:
			0: mm.mesh = tuft_mesh(6, Color(0.50, 0.76, 0.42), Color(0.78, 0.96, 0.60))
			1: mm.mesh = tuft_mesh(6, Color(0.62, 0.58, 0.34), Color(0.86, 0.72, 0.42), 0.22)
			2: mm.mesh = flower_mesh()
		mm.instance_count = items[kind].size()
		for i in items[kind].size():
			var it = items[kind][i]
			mm.set_instance_transform(i, it[0])
			mm.set_instance_custom_data(i, it[1])
			mm.set_instance_color(i, it[2])
		out.append(mm)
	return out

## rákos: 5 dlouhých úzkých listů + stonek s hnědou palicí, normalizováno na výšku 1 (UV.y = výška pro ohyb ve větru)
static func reed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color(0.38, 0.56, 0.30)
	var tip := Color(0.70, 0.84, 0.48)
	for i in 7:
		var a := TAU * i / 7.0 + 0.7 * i
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		var hh := 0.65 + 0.3 * ((i * 53) % 10) / 10.0
		st.set_color(base); st.set_uv(Vector2(0, 0)); st.add_vertex(d * 0.03 - side)
		st.set_color(base); st.set_uv(Vector2(1, 0)); st.add_vertex(d * 0.03 + side)
		st.set_color(tip); st.set_uv(Vector2(0.5, hh)); st.add_vertex(d * 0.12 + Vector3(0, hh, 0))
	# stonek a palice (dvě zkřížené plošky)
	var brown := Color(0.48, 0.32, 0.20)
	for k in 2:
		var ax := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		var w := ax * 0.02
		var quads := [[0.0, 0.78, w, base], [0.72, 0.96, ax * 0.055, brown]]
		for qd in quads:
			var y0: float = qd[0]; var y1: float = qd[1]; var ww: Vector3 = qd[2]; var cc: Color = qd[3]
			for v in [[-ww, y0], [ww, y0], [ww, y1], [-ww, y0], [ww, y1], [-ww, y1]]:
				st.set_color(cc); st.set_uv(Vector2(0, v[1])); st.add_vertex(v[0] + Vector3(0, v[1], 0))
	return st.commit()

## travnatý břeh a rákos pro jeden vzorek: [MultiMesh trsy na břehu, MultiMesh rákos]
static func build_bank(bld, sx: int, sz: int) -> Array:
	var d = bld.d
	var c: float = d.cxy
	var rng := RandomNumberGenerator.new()
	rng.seed = Par.i("seed") * 17 + sx * 5 + sz * 11 + bld.app * 7 + 999
	var nz := FastNoiseLite.new()
	nz.seed = Par.i("seed") + 5
	nz.frequency = 0.6
	var bank := []
	var reeds := []
	var th := Par.g("tuft_h") * c
	for z in range(sz * d.n, sz * d.n + d.n):
		for x in range(sx * d.n, sx * d.n + d.n):
			# trsy na travnatém břehu (dno nad hladinou u louky, kde splat trávu nemá)
			for j in int(Par.i("tufts") * 0.6):
				var px := x + rng.randf(); var pz := z + rng.randf()
				var r_h := rng.randf_range(0.6, 1.0); var yaw := rng.randf() * TAU
				if bld.grass_at(px, pz) >= 0.5:
					continue
				var y: float = bld.height(px, pz)
				var sdv: float = bld.tex_at(bld.sd, px, pz)
				if y < d.wl + 0.02 or sdv < Par.g("mud_w") or bld.tex_at(bld.dtg, px, pz) > Par.g("bank_reach"):
					continue
				var hh := th * 0.7 * r_h
				bank.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(hh, hh, hh)), Vector3(px * c, y, pz * c)))
			# rákos v trsech na čáře vody u louky (mělká voda a bahno)
			for j in int(ceil(Par.g("reed_density"))):
				var px := x + rng.randf(); var pz := z + rng.randf()
				var r_h := rng.randf_range(0.7, 1.2); var yaw := rng.randf() * TAU; var r_k := rng.randf()
				var sdv: float = bld.tex_at(bld.sd, px, pz)
				if sdv < -0.38 or sdv > 0.12:
					continue
				var dg: float = bld.tex_at(bld.dtg, px, pz)
				if dg - absf(sdv) > 0.5:
					continue    # u břehu není louka (pláž) → bez rákosu
				if nz.get_noise_2d(px * c, pz * c) < -0.1 or r_k > Par.g("reed_density") / ceil(Par.g("reed_density")):
					continue
				var y: float = bld.height(px, pz)
				if d.wl - y > 0.4:
					continue
				var hh := Par.g("reed_h") * c * r_h
				reeds.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(hh * 0.8, hh, hh * 0.8)), Vector3(px * c, y, pz * c)))
	var out := []
	for k in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = tuft_mesh(6, Color(0.50, 0.76, 0.42), Color(0.78, 0.96, 0.60)) if k == 0 else reed_mesh()
		var arr: Array = bank if k == 0 else reeds
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
			mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
			mm.set_instance_color(i, Color.WHITE)
		out.append(mm)
	return out
