extends Node
## Uzel ScenarioPodzemi (E47d, --voda47d): podzemní voda po propustné vrstvě.
## 47d_vrstva (svět, rentgen: jen propustné těleso + cesta vody + výtok ve stěně), 47d_rez (řez u výtoku ve stěně ostrova),
## 47d_cocka (demo blok: uzavřená čočka plná vody přetéká do tůně 4 × 4), 47d_jezero (demo blok: dutina zaplněná = podzemní jezero, pak po vrstvě ke stěně).

const T = preload("res://scripts/bp/tests_horniny.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const ES = preload("res://scripts/voda/eroze_svet.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const TB = preload("res://scripts/voda/tests_voda_b.gd")
const TP = preload("res://scripts/voda/tests_podzemi.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")
const Mat = preload("res://scripts/kopie/mat.gd")

@export var svet: NodePath
@export var views: NodePath
@export var ui: NodePath
@export var rig: NodePath
@export var legend: NodePath
@onready var S = get_node(svet)
@onready var V = get_node(views)
@onready var U = get_node(ui)
@onready var C = get_node(rig)
@onready var LG = get_node(legend)

func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	if c.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0: m.emission_enabled = true; m.emission = Color(c.r, c.g, c.b); m.emission_energy_multiplier = emit
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _box(size: Vector3, mat: Material, pos: Vector3, rot := 0.0) -> void:
	var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; b.mesh = bm; b.material_override = mat; b.position = pos; b.rotation.y = rot
	V.add_child(b)

func _ball(r: float, mat: Material, pos: Vector3) -> void:
	var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; b.mesh = sm; b.material_override = mat; b.position = pos
	V.add_child(b)

## stěna vody přes okraj ostrova do mlhy: sloupec (x, y), výška y0 (jednotky scény), směr ven o
func _edge_fall(x: int, y: int, y0: float, o: Vector2, bot := -7.0) -> void:
	_box(Vector3(0.95, y0 - bot, 0.14), _mat(Color(0.78, 0.9, 1.0, 0.7), 0.3), Vector3(x + 0.5 + o.x * 0.58, (y0 + bot) * 0.5, y + 0.5 + o.y * 0.58), atan2(o.x, o.y))
	var mist := _mat(Color(0.95, 0.97, 1.0, 0.3), 0.2)
	for k in 6:
		var pr := Vector2(o.y, o.x) * (k - 2.5) * 0.7
		_ball(1.2 + 0.4 * (k % 3), mist, Vector3(x + 0.5 + o.x * (1.4 + 0.3 * (k % 2)) + pr.x, bot - 0.35 * (k % 3), y + 0.5 + o.y * (1.4 + 0.3 * (k % 2)) + pr.y))

func _shot(name: String, text: String, center: Vector3, size: float, dir: Vector3) -> void:
	C.frame(center, size, dir)
	U.say(text); LG.clear()
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/47d_%s.png" % name))
	print("shot ", name)

## demo blok 16 × 16 × 64 z funkce f(x, y, z) → materiál
func _block(f: Callable) -> PackedByteArray:
	var cells := PackedByteArray(); cells.resize(16 * 16 * 64)
	for x in 16:
		for y in 16:
			for z in 64: cells[(x * 16 + y) * 64 + z] = f.call(x, y, z)
	return cells

func _ctx_block(cells: PackedByteArray, p: Dictionary) -> Dictionary:
	var mat := PackedInt32Array(); mat.resize(16 * 16 * 64)
	var top := PackedInt32Array(); top.resize(256)
	for c in 256:
		var t := 0
		for z in 64:
			mat[c * 64 + z] = cells[c * 64 + z]
			if cells[c * 64 + z] != 0: t = z + 1
		top[c] = t
	var q := p.duplicate(); q.ug_leak_q = 0.0
	return UG.make(16, 16, 64, mat, top, PackedByteArray(Array(range(256)).map(func(_i): return 0)), q)

func _demo(name: String, cells: PackedByteArray, entry: Vector3i, cut: int, p: Dictionary, text_fn: Callable) -> void:
	var ctx := _ctx_block(cells, p)
	var r := UG.solve(ctx, PackedInt32Array([(entry.x * 16 + entry.y) * 64 + entry.z]), 1.5)
	V.clear()
	V.show_blocks({Vector2i(0, 0): {"cells": cells}}, {"wet": false, "cut_axis": "y", "cut": cut, "keep": func(s): return true})
	var sat := _mat(Color(0.15, 0.45, 1.0, 0.55), 0.25); var lake := _mat(Color(0.1, 0.3, 0.85, 0.85), 0.2); var pth := _mat(Color(0.6, 1.0, 1.0), 1.5)
	for v in r.saturated:
		var c: int = v / 64; var z: int = v % 64; var x := c / 16; var y := c % 16
		if y > cut: continue
		if ctx.mat[v] == 0: _box(Vector3(1, 0.5, 1), lake, Vector3(x + 0.5, z * 0.5 + 0.25, y + 0.5))
		elif y == cut: _box(Vector3(1.0, 0.5, 0.08), sat, Vector3(x + 0.5, z * 0.5 + 0.25, y + 1.05))   # nasycené póry na čele řezu
	for v in r.path:
		var c: int = v / 64; var y := c % 16
		if y <= cut: _ball(0.16, pth, Vector3(c / 16 + 0.5, (v % 64) * 0.5 + 0.25, y + 1.12))
	_ball(0.35, _mat(Color(0.75, 1.0, 1.0), 1.2), Vector3(entry.x + 0.5, ctx.top[entry.x * 16 + entry.y] * 0.5 + 0.35, entry.y + 0.5))   # vstup (odtok tůně / ponor)
	var shaft := _mat(Color(0.1, 0.25, 0.7, 0.85), 0.3)
	var ty: float = ctx.top[entry.x * 16 + entry.y] * 0.5
	_box(Vector3(0.4, ty - entry.z * 0.5, 0.06), shaft, Vector3(entry.x + 0.5, (ty + entry.z * 0.5) * 0.5, entry.y + 1.05))
	await text_fn.call(r, ctx)

func run() -> void:
	Mesher.PALETTE = HR.palette()
	var p: Dictionary = S.params
	p.geo = "v2"
	var qs := HR.id_of("quartz_sandstone"); var imp := TP._imperm()
	# --- demo čočka → tůň 4 × 4
	var lens := func(x: int, y: int, z: int) -> int:
		var t := 30 if x < 8 else 24
		if x >= 10 and x <= 13 and y >= 6 and y <= 9: t = 21
		if z >= t: return 0
		if x >= 2 and x <= 11 and y >= 5 and y <= 10 and z >= 16 and z <= 20: return qs   # čočka (pod tůní tvoří její dno)
		if z == t - 1: return Mat.GRASS
		return imp
	await _demo("cocka", _block(lens), Vector3i(2, 7, 20), 7, p, func(r, ctx):
		var pit := _mat(Color(0.1, 0.32, 0.8, 0.75), 0.1)
		for x in range(10, 14):
			for y in range(6, 8):
				_box(Vector3(1, 1.5, 1), pit, Vector3(x + 0.5, 21 * 0.5 + 0.75, y + 0.5))
		for x in range(14, 16): _box(Vector3(1, 0.14, 1), _mat(Color(0.2, 0.5, 0.95, 0.8)), Vector3(x + 0.5, 12.07, 7.5))
		_edge_fall(15, 7, 12.1, Vector2(1, 0))
		var ev: Array = r.events
		await _shot("cocka", "uzavřená propustná čočka (pískovec, por %.2f) v nepropustné hornině: přítok 1,5 l/s, %.1f m³ pórů → plná za %.0f min\npak přetéká nejnižším výstupem do tůně 4 × 4 (%s z=%d), tůň se plní a přepadá přes okraj ostrova do mlhy" % [
			float(UG.VS.table()[qs][1]), r.volume_m3, ev[-1].cas_s / 60.0, r.out[3], r.out[0]], Vector3(8, 9, 8), 24, Vector3(0.25, 0.4, 1.0)))
	# --- demo dutina → podzemní jezero → okraj
	var cav := func(x: int, y: int, z: int) -> int:
		if z >= 30: return 0
		if z == 29: return Mat.GRASS
		if x >= 6 and x <= 9 and y >= 5 and y <= 9 and z >= 12 and z <= 17: return 0
		if x >= 1 and y >= 4 and y <= 11 and z >= 18 and z <= 21: return qs
		return imp
	await _demo("jezero", _block(cav), Vector3i(1, 7, 21), 7, p, func(r, ctx):
		var ox: int = r.out[4] / 16; var oy: int = r.out[4] % 16
		_edge_fall(ox, oy, r.out[0] * 0.5 + 0.5, Vector2(1, 0))
		await _shot("jezero", "voda teče po propustné vrstvě, narazí na dutinu a zaplní ji = podzemní jezero (%d buněk)\npak teče dál po vrstvě k okraji ostrova (z=%d) a vytéká ze stěny do mlhy; %.1f m³ → %.0f min do výtoku" % [
			r.lake.size(), r.out[0], r.volume_m3, r.events[-1].cas_s / 60.0], Vector3(8, 9, 8), 24, Vector3(0.25, 0.4, 1.0)))
	# --- svět: rentgen propustného tělesa + cesta + výtok
	var w0 = T.build(p)
	var er := ES.run(w0, p, "strze")
	var w1 = er.world; var sz: Dictionary = er.rep.strze
	var GH: int = w1.h * 16
	var g := TB._grid_hm(w1)
	var wall := PackedByteArray(); wall.resize(g.size()); wall.fill(1)
	for s in w1.order:
		for i in 256: wall[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16] = 0
	var cs := TOK.make(g, w1.w * 16, GH, wall, sz.mats, PRM.src(sz.springs, g, g.size()), TOK.losses(p, true), true)
	cs.ug = UG.ctx_world(w1, p)
	TOK.route(cs)
	if cs.ug_bodies.is_empty(): print("žádné těleso"); return
	var b: Dictionary = cs.ug_bodies[0]
	var mem: Dictionary = cs.ug_cache[b.cache_key].members
	var blocks := {}
	for s in w1.order:
		var r: Dictionary = w1.slots[s]
		var cells: PackedByteArray = r.cells.duplicate()
		for c in 256:
			var col: int = (s.x * 16 + c / 16) * GH + s.y * 16 + c % 16
			for z in 64:
				if cells[c * 64 + z] != 0 and not mem.has(col * 64 + z): cells[c * 64 + z] = 0
		blocks[s] = {"cells": cells}
	V.clear(); V.show_blocks(blocks, {"wet": false})
	var pth := _mat(Color(0.3, 1.0, 1.0), 2.0); pth.no_depth_test = true; pth.render_priority = 10   # rentgen: cesta prosvítá horninou
	for v in b.path: _ball(0.3, pth, Vector3((v / 64) / GH + 0.5, (v % 64) * 0.5 + 0.6, (v / 64) % GH + 0.5))
	var pond := _mat(Color(0.1, 0.32, 0.8, 0.6), 0.1)
	for i in g.size():
		if cs.pw[i] == 1: _box(Vector3(1, 0.2, 1), pond, Vector3(i / GH + 0.5, cs.fill[i] * 0.5, i % GH + 0.5))
	var ex: int = b.out[4]
	_edge_fall(ex / GH, ex % GH, b.out[0] * 0.5 + 0.5, Vector2(1, 0) if ex / GH == w1.w * 16 - 1 else Vector2(0, 1))
	await _shot("vrstva", "rentgen: jen propustné těleso pod jezerem (%d buněk: půda, spraš, písek, pískovec u povrchu; ostatní horniny skryté), modře hladina jezera\nodtok jezera %.2f l/s jde po vrstvě (tyrkysově cesta, %d buněk) a vytéká ze stěny ostrova %.2f l/s (průsak %.2f l/s)" % [
		b.cells, b.q_in, b.path.size(), b.out_q, b.leak], Vector3(24, 12, 24), 60, Vector3(0.9, 1.0, 1.3))
	# řez u výtoku
	var row: int = (ex % GH) / 16; var cut: int = (ex % GH) % 16
	var bl2 := {}
	for s in w1.order: bl2[s] = {"cells": w1.slots[s].cells}
	V.clear(); V.show_blocks(bl2, {"wet": false, "cut_axis": "y", "cut": cut, "keep": func(s): return s.y == row})
	var sat := _mat(Color(0.15, 0.45, 1.0, 0.6), 0.3)
	for v in b.path:
		var col: int = v / 64
		if col % GH == ex % GH: _box(Vector3(1.0, 0.5, 0.08), sat, Vector3(col / GH + 0.5, (v % 64) * 0.5 + 0.25, col % GH + 1.05))
		elif (col % GH) / 16 == row and (col % GH) % 16 < cut: pass
	_edge_fall(ex / GH, ex % GH, b.out[0] * 0.5 + 0.5, Vector2(1, 0) if ex / GH == w1.w * 16 - 1 else Vector2(0, 1))
	await _shot("rez", "řez y = %d u výtoku: podzemní voda vychází z propustné vrstvy ve stěně ostrova (z = %d) a padá do mlhy\nmodře nasycené buňky cesty v rovině řezu" % [ex % GH, b.out[0]],
		Vector3(ex / GH - 6.0, b.out[0] * 0.5 - 4.0, ex % GH), 34, Vector3(0.6, 0.3, 1.0))
