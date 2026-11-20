extends Node
## E89: měřítko scény. `-- --meritko-shots [--surface.p89_meritko=true|false] [--shot-prefix=94_]` → shots/<prefix><vyp|zap>_*.png
## (výchozí prefix 89_meritko_). E94: navíc záběr hory START izometricky.
## Postava 1,75 m (kapsle) a dům 4 × 4 × 3 m stojí ve scéně v metrech (1 jednotka Godotu = 1 m), terén podle příznaku:
## vyp = dnešní buňka 1 × 1 × 0,5 jednotky (vodorovně natažená 2×), zap = 0,5 × 0,5 × 0,5 (metry).
const Block = preload("res://scripts/block.gd")
const J = preload("res://scripts/jednotky.gd")
const Params = preload("res://scripts/surface/surface_params.gd")
const BS := J.BS

var m
var p
var pre := "89_meritko_"
var tit := "E89"

func _ready() -> void:
	m = get_parent()
	p = Params.inst()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-prefix="): pre = a.split("=", true, 1)[1]; tit = "E" + pre.trim_suffix("_").get_slice("_", 0)
	m.set_game_process(false)
	_shots.call_deferred()

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.rig.center = c; m.cam.size = size; m.rig.yaw = yaw; m.rig.pitch = pitch
	m.rig.place()

func _snap(name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://shots/")
	DirAccess.make_dir_recursive_absolute(d)
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo shots/", name)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	l.add_theme_constant_override("outline_size", 8)
	var cl := CanvasLayer.new(); cl.layer = 10; cl.add_child(l); add_child(cl)
	return l

## povrch sloupce (globální sloupec gx, gz) jako bod scény
func _top(g: Vector2i) -> Vector3:
	var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	var b: Block = m.island.blocks[s]
	var h: int = b.hm[(g.x - s.x * BS) * BS + (g.y - s.y * BS)]
	return m.island.to_global(Vector3(g.x + 0.5, h * Block.CELL_H, g.y + 0.5))

func _mesh(mesh: Mesh, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mi.material_override = mat
	mi.position = pos
	m.add_child(mi)
	return mi

func _shots() -> void:
	if m.ui:
		m.ui.visible = false
	m.island.set_textured(true)
	var on: bool = p.p89_meritko
	var tag := "zap" if on else "vyp"
	var sc: Vector3 = m.island.scale
	var lab := _label("")
	# postava a dům v metrech (stojí na povrchu louky 404, blok (1, 1))
	var gf := Vector2i(24, 24); var gh := Vector2i(30, 18)
	var pf := _top(gf)
	var cap := CapsuleMesh.new(); cap.height = J.hj_m(J.POSTAVA_HJ); cap.radius = 0.25
	_mesh(cap, pf + Vector3(0, cap.height / 2.0, 0), Color(0.85, 0.2, 0.2))
	var ph := _top(gh)
	var box := BoxMesh.new(); box.size = Vector3(4.0, 3.0, 4.0)
	_mesh(box, ph + Vector3(0, 1.5, 0), Color(0.95, 0.9, 0.75))
	var mid: Vector3 = m.island.to_global(Vector3(16, 16, 16))
	var w_m: float = 32.0 * sc.x   # šířka ostrova 2 × 2 bloky ve scéně
	lab.text = tit + " p89_meritko %s: ostrov 2 × 2 bloky = %.0f × %.0f jednotek scény, buňka %.2f × %.2f × %.2f; postava 1,75 m, dům 4 × 4 × 3 m" % [tag, w_m, w_m, sc.x, Block.CELL_H, sc.z]
	var lab0 := lab.text
	lab.text = "%s p89_meritko %s: výchozí kamera hry (střed %s, záběr %.0f)" % [tit, tag, str(m.rig.center), m.cam.size]
	await _snap("%s%s_hra_kamera.png" % [pre, tag])
	lab.text = lab0
	_cam(mid, w_m * 2.2)
	await _snap("%s%s_ostrov.png" % [pre, tag])
	lab.text = tit + " p89_meritko %s: detail 16 m, postava 1,75 m (červená), dům 4 × 4 × 3 m" % tag
	_cam(pf + Vector3(0, 1.0, 0), 16.0)
	await _snap("%s%s_detail.png" % [pre, tag])
	lab.text = tit + " p89_meritko %s: hora (blok (1, 0)) z boku, stejná velikost záběru 24 m" % tag
	_cam(m.island.to_global(Vector3(24, 16, 8)), 24.0, 90.0, -10.0)
	await _snap("%s%s_hora_bok.png" % [pre, tag])
	# E94: druhá postava na vrcholu hory START (nejvyšší sloupec bloku (1, 0)) pro srovnání výšky
	var hb: Block = m.island.blocks[Vector2i(1, 0)]
	var top_g := Vector2i(16, 0); var top_h := -1
	for lx in BS:
		for lz in BS:
			if hb.hm[lx * BS + lz] > top_h: top_h = hb.hm[lx * BS + lz]; top_g = Vector2i(16 + lx, lz)
	var pt := _top(top_g)
	_mesh(cap, pt + Vector3(0, cap.height / 2.0, 0), Color(0.85, 0.2, 0.2))
	print(tit, " vrchol hory START: sloupec ", top_g, " výška ", top_h * Block.CELL_H, " m, louka u postavy ", pf.y, " m (scéna y)")
	lab.text = "%s p89_meritko %s: hora START (blok (1, 0)) izometricky, záběr 20 m; postava 1,75 m, dům 4 × 4 × 3 m" % [tit, tag]
	_cam(m.island.to_global(Vector3(24, 22, 8)), 20.0)
	await _snap("%s%s_hora.png" % [pre, tag])
	# paprsek myši: střed obrazovky → sloupec (kontrola převodu do místních souřadnic)
	var vp: Vector2 = m.get_viewport().get_visible_rect().size / 2.0
	_cam(pf, 16.0)
	await RenderingServer.frame_post_draw
	var g = m.island.cell_at_ray(m.cam.project_ray_origin(vp), m.cam.project_ray_normal(vp))
	print(tit, " paprsek středem na postavu: sloupec ", g, " (čekám ", gf, ")")
	get_tree().quit()
