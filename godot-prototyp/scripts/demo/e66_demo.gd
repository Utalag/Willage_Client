extends Node
## E66 terén a voda ze studie v prototypu (gen bp), přidá ho demo_runner.gd:
##   -- --e66-shots   snímky ../blueprint-studie/shots/66_*.png: řeka, tůň, pramen, vodopád na okraji, rentgen řez
##   -- --e66-bench   měření vložení bloků, kopání u vody (lokální přepočet + kroky R) a kontrola proti plnému výpočtu
##                    → shots/66_parita/66_bench.txt

const BlockGen = preload("res://scripts/block_gen.gd")
const Params = preload("res://scripts/surface/surface_params.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const BS := 16
const CELL_H := 0.5

var m
var p
var lab: Label

func _ready() -> void:
	m = get_parent()
	p = Params.inst()
	m.set_game_process(false)
	if "--e66-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

func _v():
	return m.island.voda

## sloupec vodní mřížky → souřadnice ostrova (sloupec) a bod ve 3D
func _g(gi: int) -> Vector2i:
	var H: int = _v().H
	return Vector2i(gi / H, gi % H) - T.OFF * BS

func _pt(gi: int) -> Vector3:
	var g := _g(gi)
	return Vector3(g.x + 0.5, float(_v().st.hm[gi]) * CELL_H, g.y + 0.5)

func _cam(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	m.rig.center = c; m.cam.size = size; m.rig.yaw = yaw; m.rig.pitch = pitch
	m.rig.place()

func _label(t: String) -> void:
	if lab == null:
		lab = Label.new()
		lab.position = Vector2(16, 12)
		lab.add_theme_font_size_override("font_size", 20)
		lab.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
		lab.add_theme_color_override("font_outline_color", Color(1, 1, 1))
		lab.add_theme_constant_override("outline_size", 8)
		var cl := CanvasLayer.new()
		cl.layer = 10
		cl.add_child(lab)
		add_child(cl)
	lab.text = t

func _snap(name: String) -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	var d := ProjectSettings.globalize_path("res://../blueprint-studie/shots/")
	m.get_viewport().get_texture().get_image().save_png(d + name)
	print("uloženo blueprint-studie/shots/", name)

## nejsilnější koryto (ne tůň), střed největší tůně, pramen, vodopád přes okraj (nejvyšší průtok)
func _sites() -> Dictionary:
	var v = _v()
	var thr: float = v.st.L.thr
	var river := -1; var rq := 0.0
	var ponds := {}
	for i in v.W * v.H:
		if v.island[i] == 0: continue
		if v.is_pond(i):
			var k := snappedf(v.st.fill[i], 0.001)
			if not ponds.has(k): ponds[k] = []
			ponds[k].append(i)
		elif v.st.eff[i] >= thr and v.st.eff[i] > rq * 0.999 and v.level(i) >= 0.0:
			# střed toku: nejvyšší průtok, který ještě neteče přes okraj
			var j: int = v.st.to[i]
			if j >= 0 and v.island[j] == 1: rq = v.st.eff[i]; river = i
	var pond := -1; var pn := 0
	for k in ponds:
		if ponds[k].size() > pn: pn = ponds[k].size(); pond = ponds[k][ponds[k].size() / 2]
	var spring: int = v.springs[0].gi if not v.springs.is_empty() else -1
	# řeka: z pramene po D8 po proudu (12 kroků nebo do tůně / přes okraj) → bod uprostřed koryta
	if spring >= 0:
		var path := [spring]; var i: int = spring
		for k in 24:
			var j: int = v.st.to[i]
			if j < 0 or v.island[j] == 0 or v.is_pond(j): break
			path.append(j); i = j
		river = path[path.size() / 2]
	var edge := {}; var nf := {}
	for f in v.falls:
		if f.edge and (edge.is_empty() or f.q > edge.q): edge = f
		if not f.edge and (nf.is_empty() or f.q > nf.q): nf = f
	return {"reka": river, "tun": pond, "tun_n": pn, "pramen": spring, "okraj": edge, "vodopad": nf}

func _shots() -> void:
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)
	m.island.water_finish()
	var s := _sites()
	var v = _v()
	print("E66 místa: ", s)
	if s.reka >= 0:
		_label("E66 řeka: koryto z pramenů (priority-flood + D8, tok %.2f l/s)" % v.st.eff[s.reka])
		_cam(_pt(s.reka), 26.0, 35.0, -40.0)
		await _snap("66_reka.png")
	if s.tun >= 0:
		_label("E66 tůň: %d sloupců, hladina %.1f m" % [s.tun_n, v.st.fill[s.tun] * CELL_H])
		_cam(_pt(s.tun), 30.0, 50.0, -45.0)
		await _snap("66_tun.png")
	if s.pramen >= 0:
		var sp = v.springs[0]
		_label("E66 pramen (%s, %.2f l/s)" % [sp.druh, sp.q])
		_cam(_pt(s.pramen), 18.0, 20.0, -35.0)
		await _snap("66_pramen.png")
	if not s.okraj.is_empty():
		var c := _pt(s.okraj.top)
		_label("E66 vodopád přes okraj ostrova do mlhy (%.2f l/s)" % s.okraj.q)
		var g := _g(s.okraj.top)
		var out := Vector2(g.x + 0.5, g.y + 0.5) - Vector2(16.0, 16.0)   # od středu ostrova ven
		var yaw := rad_to_deg(atan2(out.x, out.y))
		_cam(c - Vector3(0, 4, 0), 30.0, yaw, -15.0)
		await _snap("66_vodopad_okraj.png")
	if not s.vodopad.is_empty():
		_label("E66 vodopád na ostrově (spád %.1f m)" % (s.vodopad.drop_u * CELL_H))
		_cam(_pt(s.vodopad.top), 20.0, 60.0, -30.0)
		await _snap("66_vodopad.png")
	# rentgen + řez: skutečné horniny, minerály a dutiny z plných id (Block.geo), voda nad řezem skrytá
	p.set_param("xray", true)
	m.island.set_slice(34)
	_label("E66 rentgen, řez lz 34: vrstvy hornin a minerály (výchozí stav: podzemí skryté)")
	_cam(Vector3(16, 14, 16), 44.0, 45.0, -50.0)
	await _snap("66_xray_rez.png")
	m.island.set_slice(-1)
	p.set_param("xray", false)
	_label("E66 ostrov: terén blueprint v2 + voda (pohled celkem)")
	_cam(Vector3(16, 14, 16), 52.0, 45.0, -35.0)
	await _snap("66_celek.png")
	get_tree().quit()

func _place(s: Vector2i, kind: String, seed: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var b = m.island.make_block(kind, seed, "E66")
	b.slot = s
	BlockGen.build(b, m.island.neighbor_hms(s))
	var tg := (Time.get_ticks_usec() - t0) / 1000.0
	m.island.place(b)
	return {"gen_ms": tg, "celkem_ms": (Time.get_ticks_usec() - t0) / 1000.0, "voda_ms": m.island.voda.ms.get("celkem", 0.0)}

func _bench() -> void:
	var out := []
	out.append("E66 terén a voda ze studie v prototypu (gen bp); %s" % Time.get_datetime_string_from_system())
	var v = _v()
	out.append("start 4 bloky: voda plný výpočet %s" % str(v.ms))
	out.append("souhrn: %s" % str(v.summary()))
	for e in [[Vector2i(2, 0), "kopec", 404], [Vector2i(-1, 1), "piscina", 4504]]:
		var r := _place(e[0], e[1], e[2])
		out.append("vložení %s %d na %s: generování %.0f ms, celkem s vodou a sítí %.0f ms (voda %.0f ms)" % [e[1], e[2], e[0], r.gen_ms, r.celkem_ms, r.voda_ms])
	v = _v()
	out.append("souhrn po vložení: %s" % str(v.summary()))
	m.water.flow_sync = true
	# kopání u vody: sloupce koryta a tůní (deterministicky)
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0 and not m.island.occupied.has(_g(i)): cand.append(i)
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	var n := 8; var tot := 0.0; var mx := 0.0; var bad := 0; var ms := []
	for k in mini(n, cand.size()):
		var gi: int = cand[rng.randi_range(0, cand.size() - 1)]
		var t0 := Time.get_ticks_usec()
		var txt: String = m.digging.dig(_g(gi))
		var t1 := (Time.get_ticks_usec() - t0) / 1000.0
		var le: Dictionary = v.last_edit
		var t2 := Time.get_ticks_usec()
		var steps := 0
		while v.pending(): v.step(); steps += 1
		var tr := (Time.get_ticks_usec() - t2) / 1000.0
		var chk: Dictionary = v.check_full()
		var nb := int(chk.fill) + int(chk.eff) + int(chk.to)
		bad += nb
		ms.append(t1); tot += t1; mx = maxf(mx, t1)
		out.append("kop %d %s: %s | kop celkem %.0f ms (voda %.0f: povrch %.0f, podzemí %.0f) | kroky R %d = %.0f ms | neshod s plným výpočtem %d" % [k + 1, _g(gi), txt, t1, le.get("ms", 0.0), le.get("surf_ms", 0.0), le.get("ug", {}).get("ms", 0.0), steps, tr, nb])
	out.append("kopání: průměr %.0f ms, max %.0f ms; neshod celkem %d" % [tot / maxf(ms.size(), 1), mx, bad])
	out.append("položení (bez změny podzemí):")
	var g0 := _g(cand[0])
	var t3 := Time.get_ticks_usec()
	var txt2: String = m.digging.dig(g0, true)
	out.append("  položení na %s: %s, %.0f ms; neshod %s" % [g0, txt2, (Time.get_ticks_usec() - t3) / 1000.0, str(v.check_full())])
	var d := ProjectSettings.globalize_path("res://shots/66_parita/")
	DirAccess.make_dir_recursive_absolute(d)
	FileAccess.open(d + "66_bench.txt", FileAccess.WRITE).store_string("\n".join(out) + "\n")
	for l in out: print(l)
	get_tree().quit()
