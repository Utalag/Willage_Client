extends Node3D
## EXPERIMENT: srovnávací render rozlišení bloku (režim `-- --res-test`). Výchozí hra se nemění.
## Knoflíky (příkazová řádka, vše volitelné):
##   --res-xy=32    buněk na stranu bloku (vodorovně)
##   --res-z=64     buněk na výšku
##   --cell-xy=0.5  šířka buňky (světové jednotky)
##   --cell-z=0.5   výška buňky
##   --res-blocks=hora:7777,kopec:2302   které bloky renderovat (typ:seed)
##   --res-ref=16,64,1,0.5               referenční mřížka pro srovnání (nxy,nz,cxy,cz)
## Fyzická velikost bloku = res-xy·cell-xy × res-xy·cell-xy × res-z·cell-z.
## Když se zadá jen --res-xy, cell-xy se dopočítá tak, aby blok zůstal 16 jednotek široký.
## Výstup: shots/23_rozliseni_<ref>_vs_<test>_<typ><seed>_{bez_textur,textury}[_detail].png (vlevo ref, vpravo test).

const Mat = preload("res://scripts/mat.gd")
const ResGen = preload("res://scripts/res_gen.gd")
const ResMesher = preload("res://scripts/res_mesher.gd")

var cam: Camera3D
var mi: MeshInstance3D
var mat: ShaderMaterial

static func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _ready() -> void:
	var nxy := int(_arg("res-xy", "32"))
	var cxy := float(_arg("cell-xy", str(16.0 / nxy)))
	var nz := int(_arg("res-z", "64"))
	var cz := float(_arg("cell-z", "0.5"))
	var rp := _arg("res-ref", "16,64,1,0.5").split(",")
	var ref := [int(rp[0]), int(rp[1]), float(rp[2]), float(rp[3])]
	var test := [nxy, nz, cxy, cz]
	var blocks := []
	for t in _arg("res-blocks", "hora:7777,kopec:2302").split(","):
		var p := t.split(":")
		blocks.append([p[0], int(p[1])])
	_setup_scene()
	await _run(ref, test, blocks)
	get_tree().quit()

func _tag(g: Array) -> String:
	var s := "%d" % g[0]
	if g[1] != 64 or not is_equal_approx(g[3], 0.5) or not is_equal_approx(g[0] * g[2], 16.0):
		s += "x%d_c%sx%s" % [g[1], str(g[2]), str(g[3])]
	return s

func _run(ref: Array, test: Array, blocks: Array) -> void:
	var dir := ProjectSettings.globalize_path("res://shots/")
	var report := []
	for bk in blocks:
		var meshes := []
		for g in [ref, test]:
			var r := ResGen.generate(bk[0], bk[1], g[0], g[1], g[2], g[3])
			if g[0] == 16 and g[1] == 64 and is_equal_approx(g[2], 1.0) and is_equal_approx(g[3], 0.5):
				# kontrola: referenční mřížka musí dát přesně totéž co block_gen.gd hry
				var b = load("res://scripts/block.gd").new()
				b.kind = bk[0]; b.seed = bk[1]
				load("res://scripts/block_gen.gd").build(b, [null, null, null, null])
				print("RES kontrola %s %d: shoda s block_gen.gd = %s" % [bk[0], bk[1], b.cells == r.cells])
			var t0 := Time.get_ticks_usec()
			var m := ResMesher.build_res(r.cells, g[0], g[1], g[2], g[3])
			var mesh_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var vc := 0; var tc := 0
			if m.get_surface_count() > 0:
				var arr := m.surface_get_arrays(0)
				vc = arr[Mesh.ARRAY_VERTEX].size(); tc = arr[Mesh.ARRAY_INDEX].size() / 3
			var line := "RES %s %d | mřížka %d×%d×%d, buňka %s×%s×%s, blok %.1f×%.1f×%.1f | generování %.1f ms, mesh %.1f ms, vrcholů %d, trojúhelníků %d, buněk %d" % [
				bk[0], bk[1], g[0], g[0], g[1], str(g[2]), str(g[2]), str(g[3]), g[0] * g[2], g[0] * g[2], g[1] * g[3],
				r.gen_ms, mesh_ms, vc, tc, r.cells.size()]
			print(line)
			report.append(line)
			meshes.append([m, g])
		for tex in [false, true]:
			mat.set_shader_parameter("use_tex", tex)
			for detail in [false, true]:
				var names := []
				for k in 2:
					var g: Array = meshes[k][1]
					mi.mesh = meshes[k][0]
					var L: float = g[0] * g[2]
					var H: float = g[1] * g[3]
					if detail:
						_cam(Vector3(L * 0.5, H * 0.62, L * 0.5), 12.0)
					else:
						_cam(Vector3(L * 0.5, H * 0.45, L * 0.5), 34.0)
					var nm := "_tmp_%d.png" % k
					for i in 8:
						await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(dir + nm)
					names.append(nm)
				var out := "23_rozliseni_%s_vs_%s_%s%d_%s%s.png" % [_tag(ref), _tag(test), bk[0], bk[1],
					"textury" if tex else "bez_textur", "_detail" if detail else ""]
				# dvojice se spojí v Pythonu (PIL), tady jen dočasné snímky
				DirAccess.rename_absolute(dir + names[0], dir + out.replace(".png", "_L.png"))
				DirAccess.rename_absolute(dir + names[1], dir + out.replace(".png", "_R.png"))
				print("uloženo shots/", out, " (L/R)")
	var f := FileAccess.open(dir + "23_rozliseni_%s_vs_%s_casy.txt" % [_tag(ref), _tag(test)], FileAccess.WRITE)
	for l in report:
		f.store_line(l)

func _cam(center: Vector3, size: float) -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(45.0), 0), EULER_ORDER_YXZ)
	cam.size = size
	cam.transform = Transform3D(basis, center + basis.z * 200.0)

func _setup_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 1.0
	cam.far = 500.0
	add_child(cam)
	cam.current = true
	mat = ShaderMaterial.new()
	mat.shader = load("res://terrain_toon.gdshader")
	var imgs: Array[Image] = []
	for i in range(1, 11):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/tex/%02d.png" % i)) != OK:
			imgs.clear(); break
		img.convert(Image.FORMAT_RGB8)
		img.generate_mipmaps()
		imgs.append(img)
	if imgs.size() == 10:
		var ta := Texture2DArray.new()
		ta.create_from_images(imgs)
		mat.set_shader_parameter("tex_arr", ta)
	mi = MeshInstance3D.new()
	mi.material_override = mat
	add_child(mi)
