extends RefCounted
## Tráva C v hlavním prototypu (převzato ze studie trava-studie, varianta C, schválena 17. 11. 2026):
## hustě instancované trsy z veg-v2 (MultiMesh) na každém travnatém sloupci + kvítky, vítr a rozhrnování stopou.
## - Jen vzhled: data vegetace (veg.gd), rarita i vektory se nemění. Vysoká/nízká tráva = hodnotový šum ze seedu
##   bloku (účel "GRASS") ve zdrojových souřadnicích, podíl vysoké podle receptu (grass_params.gd).
## - Trsy jen na povrchu z trávy (Mat.GRASS) a ne na zabraných sloupcích (stavby, cesty).
## - Rostliny z dat: „květiny“ a „suchá tráva“ se kreslí stejným shaderem (sdílí vítr i stopu), „trs trávy“
##   je teď součástí louky (žádný zvláštní velký trs). Mech, keře, stromy a kaktusy beze změny (veg_render.gd).
## - Jeden sdílený materiál; postavičky volají touch(), hra jednou za snímek tick(dt).

const Par = preload("res://scripts/grass_params.gd")
const Trail = preload("res://scripts/grass_trail.gd")
const Veg = preload("res://scripts/veg.gd")
const Mat = preload("res://scripts/mat.gd")
const H = preload("res://scripts/stable_hash.gd")
const Toon = preload("res://scripts/toon.gd")
const SurfPar = preload("res://scripts/surface/surface_params.gd")
const BS := 16
const CELL_H := 0.5
const FLOWER_COLORS := [Color(1.0, 0.62, 0.78), Color(1.0, 0.92, 0.45), Color(0.98, 0.98, 1.0), Color(0.75, 0.62, 1.0)]
enum { GREEN, DRY, FLOWER }

static var _mat: ShaderMaterial
static var _meshes := {}
static var trail
static var sim_t := 0.0
static var _chars := {}          # id -> Vector4(x, z, poloměr stínu, 0)
static var last_count := 0       # instancí v posledním sestaveném bloku
static var trail_us := 0.0       # CPU čas stopy v posledním tick()
const LOD_BUCKETS := 8
static var lod := 1.0            # podíl kreslených trsů (po osminách)
static var _lod_mms: Array = []  # WeakRef na MultiMesh trsů (kvůli úrovni detailu)

static func enabled() -> bool:
	Par.parse_cli()
	return Par.inst().enabled != 0

static func material() -> ShaderMaterial:
	if _mat == null:
		Par.parse_cli()
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://grass_tuft.gdshader")
		Toon.register(_mat)
		var ts := Par.g("trail_size")
		trail = Trail.new(Vector2(-ts * 0.5 + BS, -ts * 0.5 + BS), Vector2(ts, ts), Par.g("trail_px") / Par.g("cell_edge"))
		apply_params()
	return _mat

## přenese parametry do shaderu (po změně parametrů za běhu)
static func apply_params() -> void:
	var m := material()
	var cell := Par.g("cell_edge")
	var wd := deg_to_rad(Par.g("wind_dir_deg"))
	m.set_shader_parameter("trail_tex", trail.tex)
	m.set_shader_parameter("trail_rect", trail.rect())
	m.set_shader_parameter("wind_dir", Vector2(cos(wd), sin(wd)))
	m.set_shader_parameter("wind_strength", Par.g("wind_strength"))
	m.set_shader_parameter("wind_gust", Par.g("wind_gust"))
	m.set_shader_parameter("wind_speed", Par.g("wind_speed") * cell)
	m.set_shader_parameter("wind_scale", Par.g("wind_scale") / cell)
	m.set_shader_parameter("t_hold", Par.g("trample_hold"))
	m.set_shader_parameter("t_recover", Par.g("trample_recover"))
	m.set_shader_parameter("t_bend", Par.g("trample_bend"))

static func set_param(k: String, v) -> void:
	Par.inst().set(k, v)
	apply_params()

## úroveň detailu podle velikosti záběru ortho kamery; instance trsů jsou v bufferu po osminách
## (každý 8. trs každého sloupce), takže visible_instance_count řídne rovnoměrně po celé louce
static func update_lod(cam_size: float) -> void:
	var f := clampf(Par.g("lod_full_size") / maxf(cam_size, 0.01), Par.g("lod_min"), 1.0)
	f = ceilf(f * LOD_BUCKETS) / LOD_BUCKETS
	if is_equal_approx(f, lod):
		return
	lod = f
	var alive := []
	for w in _lod_mms:
		var mm = w.get_ref()
		if mm:
			mm.visible_instance_count = _lod_count(mm)
			alive.append(w)
	_lod_mms = alive

static func _lod_count(mm: MultiMesh) -> int:
	var b: PackedInt32Array = mm.get_meta("bucket_ends")
	return b[clampi(int(round(lod * LOD_BUCKETS)) - 1, 0, LOD_BUCKETS - 1)]

# ------------------------------------------------------------------ simulace (vítr, stopa)
## postavička na pozici (svět XZ), směr pohybu (nulový = stojí). id = libovolný klíč postavičky.
## Okno stopy jede za první postavičkou, která se ozve; ostatní mimo okno trávu nerozhrnou (zatím).
static func touch(id, pos: Vector2, move_dir: Vector2, shadow_r := 0.32) -> void:
	material()
	var t0 := Time.get_ticks_usec()
	if _chars.is_empty() or _chars.keys()[0] == id:
		if trail.follow(pos):
			_mat.set_shader_parameter("trail_rect", trail.rect())
	if move_dir != Vector2.ZERO:
		trail.stamp(pos, move_dir, Par.g("trample_r") * Par.g("cell_edge"), sim_t, Par.g("trample_hold"), Par.g("trample_recover"))
	_chars[id] = Vector4(pos.x, pos.y, shadow_r, 0)
	trail_us += Time.get_ticks_usec() - t0

static func remove_char(id) -> void:
	_chars.erase(id)

static func tick(dt: float) -> void:
	material()
	sim_t += dt
	var t0 := Time.get_ticks_usec()
	trail.upload()
	var cs := []
	for k in _chars:
		if cs.size() < 4:
			cs.append(_chars[k])
	while cs.size() < 4:
		cs.append(Vector4(-1e5, -1e5, 0.001, 0))
	_mat.set_shader_parameter("sim_time", sim_t)
	_mat.set_shader_parameter("chars", cs)
	trail_us += Time.get_ticks_usec() - t0

# ------------------------------------------------------------------ geometrie (ze studie grass_build.gd)
## trs z veg_render._tuft normalizovaný na výšku 1, UV.y = výška pro ohyb
static func _tuft_mesh(n: int, base: Color, tip: Color, spread := 0.18) -> ArrayMesh:
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

## kvítky z veg_render._flower normalizované na výšku 1
static func _flower_mesh() -> ArrayMesh:
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

static func mesh(kind: int) -> ArrayMesh:
	if not _meshes.has(kind):
		match kind:
			GREEN: _meshes[kind] = _tuft_mesh(6, Color(0.50, 0.76, 0.42), Color(0.78, 0.96, 0.60))
			DRY: _meshes[kind] = _tuft_mesh(6, Color(0.62, 0.58, 0.34), Color(0.86, 0.72, 0.42), 0.22)
			FLOWER: _meshes[kind] = _flower_mesh()
	return _meshes[kind]

## vysoká tráva na sloupcích bloku (PackedByteArray 256, index lx * BS + ly): hodnotový šum ve zdrojovém rámci
static func tall_map(b) -> PackedByteArray:
	var share := Par.g("tall_" + b.kind) if Par.has("tall_" + b.kind) else 0.4
	var p := maxf(Par.g("tall_patch"), 1.0)
	var gn := int(ceil(BS / p)) + 2
	var out := PackedByteArray()
	out.resize(BS * BS)
	for lx in BS:
		for ly in BS:
			var s := Veg._to_src(lx, ly, b.mirror, b.rot)
			var fx := (s.x + 0.5) / p
			var fy := (s.y + 0.5) / p
			var ix := int(fx); var iy := int(fy)
			var ux := smoothstep(0.0, 1.0, fx - ix); var uy := smoothstep(0.0, 1.0, fy - iy)
			var n := lerpf(lerpf(_gv(b.seed, ix, iy, gn), _gv(b.seed, ix + 1, iy, gn), ux),
				lerpf(_gv(b.seed, ix, iy + 1, gn), _gv(b.seed, ix + 1, iy + 1, gn), ux), uy)
			# hodnotový šum má hodnoty kolem 0,5 → roztáhneme, aby podíl odpovídal parametru přibližně
			out[lx * BS + ly] = 1 if clampf((n - 0.5) * 1.8 + 0.5, 0.0, 1.0) < share else 0
	return out

static func _gv(seed: int, x: int, y: int, gn: int) -> float:
	return float(H.mix(seed, "GRASS", x * gn + y) & 0xFFFFFF) / 16777216.0

## Uzly trávy bloku (lokální souřadnice bloku). veg = už odfiltrované rostliny, occ(lx, ly) -> bool = sloupec zabraný.
## surf (volitelně ShoreFields bloku, duální povrch 2026-11-17): trs stojí na výšce povrchu, roste jen kde má
## povrch trávu (hranice podle duální mřížky, i kus do sousední písečné buňky), pod hladinou neroste,
## k okraji louky řídne (méně, nižší a sušší trsy, kvítky jen uvnitř) a v pásu před loukou jsou řídké nízké trsy v písku.
static func build(b, veg: Array, occ: Callable, surf = null) -> Array:
	var cell := Par.g("cell_edge")
	var sp = SurfPar.inst()
	var tall := tall_map(b)
	var tall_h := Par.g("tuft_tall_h") * cell
	var short_h := Par.g("tuft_short_h") * cell
	var buf := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var lb := []   # trsy po osminách: lb[kind][bucket]
	for k in 2:
		var a := []
		for i in LOD_BUCKETS:
			a.append(PackedFloat32Array())
		lb.append(a)
	var lc := [0, 0]
	var rng := RandomNumberGenerator.new()
	var hmin := 1 << 30
	var hmax := 0
	for lx in BS:
		for ly in BS:
			var hc: int = b.hm[lx * BS + ly]
			if hc <= 0:
				continue
			var top: int = b.cells[(lx * BS + ly) * 64 + hc - 1]
			if occ.call(lx, ly):
				continue
			if top != Mat.GRASS and not (surf and top == Mat.SAND):
				continue
			hmin = mini(hmin, hc - 2); hmax = maxi(hmax, hc)
			var s := Veg._to_src(lx, ly, b.mirror, b.rot)
			rng.seed = H.mix(b.seed, "GRASS_I", s.x * BS + s.y)
			var is_tall := tall[lx * BS + ly] == 1
			var y := hc * CELL_H
			var sand := top == Mat.SAND
			var base := Par.g("tufts_tall") if is_tall else Par.g("tufts_short")
			if sand:
				base = Par.g("tufts_short")   # tráva přesahující do písku / pás trávy v písku: nízké trsy
			var dry := Par.g("tuft_dry")
			var simple_y: float = surf.simple_col(lx, ly, sp.thin_w) if surf else -1.0
			for kind in 3:
				var cnt := (Par.g("flowers_tall") if is_tall and not sand else 0.0) if kind == FLOWER else base * (dry if kind == DRY else 1.0 - dry)
				var c := int(floor(cnt)) + (1 if rng.randf() < cnt - floor(cnt) else 0)
				for j in c:
					var hh := (tall_h if is_tall and not sand else short_h) * rng.randf_range(0.7, 1.15)
					if kind == FLOWER:
						hh = tall_h * rng.randf_range(0.9, 1.15)
					var wr := Par.g("tuft_w_tall") if is_tall and not sand else Par.g("tuft_w_short")
					var col: Color = FLOWER_COLORS[rng.randi() % 4] if kind == FLOWER else Color(1, 1, 1)
					var px := lx + rng.randf()
					var pz := ly + rng.randf()
					var ww := rng.randf_range(0.85, 1.2)
					var kd := kind
					var py := y
					if surf:
						var r_keep := rng.randf()
						var r_dry := rng.randf()
						if simple_y >= 0.0:
							py = simple_y
							var dst0: PackedFloat32Array = buf[kd]
							if kd != FLOWER:
								dst0 = lb[kd][lc[kd] % LOD_BUCKETS]
								lc[kd] += 1
							_put(dst0, rng, Vector3(px * cell, py, pz * cell), hh, hh * wr * ww, col)
							continue
						py = surf.height_local(px, pz)
						if py < surf.wl + 0.02:
							continue
						var k := 1.0
						if surf.grass_local(px, pz) >= 0.5:
							k = smoothstep(0.0, sp.thin_w, surf.ged_local(px, pz))
							if kind == FLOWER and k < 0.75:
								continue
							if kind != FLOWER and r_keep > lerpf(sp.thin_min, 1.0, k):
								continue
							if kind == GREEN and r_dry < 0.3 * (1.0 - k):
								kd = DRY
						else:
							# pás „tráva v písku“ před loukou: řídké nízké trsy
							if kind == FLOWER:
								continue
							var mixk := 1.0 - smoothstep(0.0, sp.band_grass, surf.dtg_local(px, pz))
							if r_keep > sp.mix_tufts * mixk:
								continue
							k = 0.35 + 0.4 * mixk
						if kind != FLOWER:
							hh *= lerpf(0.5, 1.0, k)
					elif sand:
						continue
					var dst: PackedFloat32Array = buf[kd]
					if kd != FLOWER:
						dst = lb[kd][lc[kd] % LOD_BUCKETS]
						lc[kd] += 1
					_put(dst, rng, Vector3(px * cell, py, pz * cell), hh, hh * wr * ww, col)
	# rostliny z dat vegetace, které teď kreslí tráva (sdílí vítr a stopu)
	for v in veg:
		if v.s == Veg.FLOWERS or v.s == Veg.DRY_GRASS:
			rng.seed = H.mix(b.seed, "GRASS_V", v.lx * BS + v.ly)
			var kind := FLOWER if v.s == Veg.FLOWERS else DRY
			var hh: float = (Par.g("flower_h") if kind == FLOWER else Par.g("dry_h")) * v.scale
			var col: Color = FLOWER_COLORS[int(v.yaw) % FLOWER_COLORS.size()] if kind == FLOWER else Color(1, 1, 1)
			hmin = mini(hmin, v.lz); hmax = maxi(hmax, v.lz)
			var vp := Vector3(v.lx + 0.5 + v.ox, v.lz * CELL_H, v.ly + 0.5 + v.oy)
			if surf:
				if surf.wet_local(vp.x, vp.z):
					continue
				vp.y = surf.height_local(vp.x, vp.z)
			_put(buf[kind], rng, vp, hh, hh * (1.3 if kind == DRY else 1.0), col, deg_to_rad(v.yaw))
	# trsy z rostlin (suchá tráva) jdou do první osminy (kreslí se vždy), pak osminy za sebou
	var ends := [PackedInt32Array(), PackedInt32Array()]
	for k in 2:
		var merged := buf[k] as PackedFloat32Array
		for i in LOD_BUCKETS:
			merged.append_array(lb[k][i])
			ends[k].append(merged.size() / 20)
		buf[k] = merged
	var out := []
	last_count = 0
	if hmax == 0:
		return out
	var top := maxf(tall_h, Par.g("dry_h") * 1.2) * 1.5 + 0.3
	var aabb := AABB(Vector3(-1, hmin * CELL_H - 0.2, -1), Vector3(BS * cell + 2, (hmax - hmin) * CELL_H + top + 0.4, BS * cell + 2))
	for kind in 3:
		var n: int = buf[kind].size() / 20
		if n == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh(kind)
		mm.instance_count = n
		mm.buffer = buf[kind]
		if kind != FLOWER:
			mm.set_meta("bucket_ends", ends[kind])
			mm.visible_instance_count = _lod_count(mm)
			_lod_mms.append(weakref(mm))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = aabb
		mmi.name = ["trava_zelena", "trava_sucha", "kvitky"][kind]
		out.append(mmi)
		last_count += n
	return out

## jedna instance do bufferu: transform 3 × 4 (řádky), barva, custom (fáze, odstín, klidový náklon xy)
static func _put(a: PackedFloat32Array, rng: RandomNumberGenerator, pos: Vector3, hh: float, ww: float, col: Color, yaw := -1.0) -> void:
	var bs := Basis(Vector3.UP, rng.randf() * TAU if yaw < 0.0 else yaw).scaled_local(Vector3(ww, hh, ww))
	var la := rng.randf() * TAU
	var lm := rng.randf_range(0.0, 0.2)
	a.append_array([bs.x.x, bs.y.x, bs.z.x, pos.x, bs.x.y, bs.y.y, bs.z.y, pos.y, bs.x.z, bs.y.z, bs.z.z, pos.z,
		col.r, col.g, col.b, col.a, rng.randf(), rng.randf(), cos(la) * lm, sin(la) * lm])
