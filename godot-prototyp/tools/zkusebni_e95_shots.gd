extends SceneTree
## E95: snímky zkušebního panelu (bublina) a svislého řezu. Potřebuje obraz:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path . -s res://tools/zkusebni_e95_shots.gd -- --shots=adresář
const PN = preload("res://scripts/game/zkusebni/panel.gd")

var shots := ""

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _initialize() -> void:
	shots = _arg("shots", "/tmp/e95shots")
	DirAccess.make_dir_recursive_absolute(shots)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()

func _ready_wait() -> void:
	while true:
		await process_frame
		if PN.aktivni != null and PN.regen_t0 == 0 and PN.aktivni.is_inside_tree(): break
	for i in 10: await process_frame

func _snap(name: String) -> void:
	for i in 8: await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("snímek ", name)

func _hover(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var ev := InputEventMouseMotion.new()
	ev.position = p; ev.global_position = p
	root.get_viewport().push_input(ev)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 1500:
		await process_frame
		var ev2 := InputEventMouseMotion.new(); ev2.position = p + Vector2(0.01, 0); ev2.global_position = ev2.position
		if Time.get_ticks_msec() - t < 100: root.get_viewport().push_input(ev2)

func _run() -> void:
	await _ready_wait()
	var pn = PN.aktivni
	await _hover(pn.ctrls["p82_vapenec"])
	await _snap("e95_panel_bublina")
	await _hover(pn.ctrls["zk_rez"])
	await _snap("e95_panel_bublina_rez")
	pn.nastav("zk_rez", 1); pn.nastav("zk_rez_pos", 0.5)
	for i in 30: await process_frame
	await _hover(pn.ctrls["zk_rez_pos"])
	await _snap("e95_rez_x_bublina")
	pn.sbaleno = true; pn._refresh()
	await _snap("e95_rez_x")
	pn.nastav("zk_rez_pos", 0.3)
	await _snap("e95_rez_x_030")
	pn.nastav("zk_rez", 2); pn.nastav("zk_rez_pos", 0.55)
	await _snap("e95_rez_z")
	pn.main.rig.yaw += 90.0; pn.main.rig.place()
	await _snap("e95_rez_z_otoceno")
	pn.main.rig.yaw -= 90.0; pn.main.rig.place()
	pn.nastav("zk_rez", 0)
	pn.nastav("p90_lod", true)
	pn.main.rig.get_node("Camera").size = 140.0; pn.main.rig.place()
	await _snap("e95_lod_okoli")
	pn.nastav("p90_lod", false)
	pn.sbaleno = false; pn._refresh()
	await _snap("e95_panel")
	quit()
