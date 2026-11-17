extends Node3D
## Studie skály: stejný vzorek (voxely vápenec/žula) vykreslený čtyřmi přístupy A–D, stejná kamera a světlo.
## Přepínače (za `--`): --cell=0.5,0.5 (šířka, výška buňky), --seed=7, --size=10,10,4 (x, z, výška),
##   --only=ABCD, --suffix=_neco (přípona souborů), --scale-test (jen časy pro blok 32 × 32 × 64, bez renderu).

const Chunk = preload("res://scripts/chunk.gd")
const CubeMesher = preload("res://scripts/cube_mesher.gd")
const Breakup = preload("res://scripts/breakup_mesher.gd")
const Nets = preload("res://scripts/nets_mesher.gd")
const Pieces = preload("res://scripts/pieces.gd")
const Mat = preload("res://scripts/mat.gd")

var cam: Camera3D
var tex_arr: Texture2DArray
var cell := Vector3(0.5, 0.5, 0.5)
var seed := 7
var size := Vector3i(10, 10, 4)
var stats := []

static func arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _ready() -> void:
	var c := arg("cell", "0.5,0.5").split(",")
	cell = Vector3(float(c[0]), float(c[1]), float(c[0]))
	seed = int(arg("seed", "7"))
	var s := arg("size", "10,10,4").split(",")
	size = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	_load_tex()
	if "--scale-test" in OS.get_cmdline_user_args():
		_scale_test()
		get_tree().quit()
		return
	_setup_scene()
	if "--block" in OS.get_cmdline_user_args():
		await load("res://scripts/block_test.gd").new().run(self)
		get_tree().quit()
		return
	await _render_all(arg("only", "ABCD"), arg("suffix", ""))
	get_tree().quit()

func _load_tex() -> void:
	var imgs: Array[Image] = []
	for i in range(1, 11):
		var img := Image.new()
		img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/tex/%02d.png" % i))
		img.convert(Image.FORMAT_RGB8)
		img.generate_mipmaps()
		imgs.append(img)
	tex_arr = Texture2DArray.new()
	tex_arr.create_from_images(imgs)

func _outline(w: float) -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = load("res://outline.gdshader")
	o.set_shader_parameter("width", w)
	return o

func rock_mat(vcol: bool, m := 0) -> ShaderMaterial:
	var r := ShaderMaterial.new()
	r.shader = load("res://rock.gdshader")
	r.set_shader_parameter("tex_arr", tex_arr)
	r.set_shader_parameter("cell", cell)
	r.set_shader_parameter("use_vcol", vcol)
	if m > 0:
		r.set_shader_parameter("base_col", Mat.COLORS[m])
		r.set_shader_parameter("mat_id", float(m))
	r.next_pass = _outline(0.035 * cell.x)
	return r

## postaví jeden přístup; vrací [uzel, ms, trojúhelníky, poznámka]
func build(kind: String, ch) -> Array:
	var t0 := Time.get_ticks_usec()
	var node: Node3D
	var tris := 0
	var note := ""
	match kind:
		"A":
			var am: ArrayMesh = CubeMesher.build_res(ch.cells, ch.nx, ch.ny, cell.x, cell.y)
			var mat := ShaderMaterial.new()
			mat.shader = load("res://terrain_toon.gdshader")
			mat.set_shader_parameter("tex_arr", tex_arr)
			mat.set_shader_parameter("use_tex", true)
			var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = mat
			node = mi; tris = _tris(am)
		"B":
			var am: ArrayMesh = Breakup.build(ch, seed, cell)
			var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = rock_mat(true)
			node = mi; tris = _tris(am)
		"C":
			var am: ArrayMesh = Nets.build(ch, seed, cell)
			var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = rock_mat(true)
			node = mi; tris = _tris(am)
		"D":
			var mats := {Mat.LIMESTONE: rock_mat(false, Mat.LIMESTONE), Mat.GRANITE: rock_mat(false, Mat.GRANITE)}
			var r: Array = Pieces.build_hybrid(ch, seed, cell, mats, rock_mat(true))
			node = r[0]; tris = r[4]; note = "(%d kamenů, %d balvanů, %d souvislých skal)" % [r[1], r[2], r[3]]
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	return [node, ms, tris, note]

func _tris(am: ArrayMesh) -> int:
	if am.get_surface_count() == 0:
		return 0
	var a := am.surface_get_arrays(0)
	if a[Mesh.ARRAY_INDEX] != null and a[Mesh.ARRAY_INDEX].size() > 0:
		return a[Mesh.ARRAY_INDEX].size() / 3
	return a[Mesh.ARRAY_VERTEX].size() / 3

func _render_all(only: String, suffix: String) -> void:
	var ch := Chunk.new()
	var tg := Time.get_ticks_usec()
	ch.generate(seed, size.x, size.y, size.z)
	print("SKALA data %d×%d×%d, buňka %s: generování %.1f ms" % [size.x, size.y, size.z, cell, (Time.get_ticks_usec() - tg) / 1000.0])
	var W := size.x * cell.x
	var Hh := size.z * cell.y
	var dir := ProjectSettings.globalize_path("res://shots/")
	DirAccess.make_dir_recursive_absolute(dir)
	var lines := []
	for k in only:
		var r := build(k, ch)
		var node: Node3D = r[0]
		add_child(node)
		var line := "SKALA %s%s: stavba %.1f ms, trojúhelníků %d %s" % [k, suffix, r[1], r[2], r[3]]
		print(line); lines.append(line)
		_cam(Vector3(W * 0.5, Hh * 0.35, W * 0.5), W * 1.32, 45.0, -33.0)
		await _snap(dir + "24_skala_%s%s.png" % [k, suffix])
		_cam(Vector3(W * 0.68, Hh * 0.55, W * 0.62), W * 0.55, 45.0, -28.0)
		await _snap(dir + "24_skala_%s%s_detail.png" % [k, suffix])
		node.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(dir + "24_skala_casy%s.txt" % suffix, FileAccess.WRITE)
	for l in lines: f.store_line(l)

func dir() -> String:
	var d := ProjectSettings.globalize_path("res://shots/")
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _snap(path: String) -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("uloženo ", path.get_file())

func _cam(center: Vector3, sz: float, yaw: float, pitch: float) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0), EULER_ORDER_YXZ)
	cam.size = sz
	cam.transform = Transform3D(b, center + b.z * 100.0)

func _setup_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 1.0; cam.far = 300.0
	add_child(cam); cam.current = true
	# podložka: pastelová tráva o buňku širší než vzorek, těsně pod y = 0
	var W := size.x * cell.x
	var pm := BoxMesh.new(); pm.size = Vector3(W + 4.0 * cell.x, 0.2, size.y * cell.x + 4.0 * cell.x)
	var g := MeshInstance3D.new(); g.mesh = pm; g.name = "Podlozka"
	g.position = Vector3(W * 0.5, -0.1 - 0.002, size.y * cell.x * 0.5)
	var gm := ShaderMaterial.new(); gm.shader = load("res://rock.gdshader")
	gm.set_shader_parameter("use_vcol", false); gm.set_shader_parameter("base_col", Color(0.66, 0.80, 0.58))
	gm.set_shader_parameter("use_tex", false); gm.set_shader_parameter("strata_strength", 0.0)
	gm.set_shader_parameter("crack_strength", 0.0)
	g.material_override = gm
	add_child(g)

## Škálování: časy a trojúhelníky pro plný blok 32 × 32 × 64 (stejný generátor, tvar zvětšený)
func _scale_test() -> void:
	var ch := Chunk.new()
	var t0 := Time.get_ticks_usec()
	ch.generate(seed, 32, 32, 64)
	print("SCALE data 32×32×64: %.0f ms, plných buněk %d" % [(Time.get_ticks_usec() - t0) / 1000.0, ch.cells.count(Mat.LIMESTONE) + ch.cells.count(Mat.GRANITE)])
	for k in arg("only", "ABCD"):
		var r := build(k, ch)
		print("SCALE %s 32×32×64: stavba %.0f ms, trojúhelníků %d %s" % [k, r[1], r[2], r[3]])
		r[0].free()
