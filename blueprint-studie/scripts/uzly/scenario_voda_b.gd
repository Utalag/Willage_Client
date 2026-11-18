extends Node
## Uzel ScenarioVodaB (E47b/c, --voda47b): 3D snímky 47b_iso_pred / _po, 47b_vodopad, 47b_ponor, 47b_okraj (+ snímky pro GIF 47b_vodopad.gif).
## Svět v2 (sled 46) → prameny (jediný zdroj vody) → strže ~2 m (strze.gd) → uložené koryto (tok.gd). Voda = koryto (tenká vrstva) + tůně do hladiny přelivu.
## Pramen = bílo-tyrkysová kulička, vodopád = průsvitná svislá stěna + pěna, ponor = tmavý kotouč (+ šachta v řezu), okraj ostrova = stěna vody dolů do mlhy.

const T = preload("res://scripts/bp/tests_horniny.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const ES = preload("res://scripts/voda/eroze_svet.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const TB = preload("res://scripts/voda/tests_voda_b.gd")

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

var GH := 48

func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	if c.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0: m.emission_enabled = true; m.emission = Color(c.r, c.g, c.b); m.emission_energy_multiplier = emit
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _top(w, gi: int) -> float:   # výška povrchu sloupce v jednotkách scény (buňka = 0,5)
	var r: Dictionary = w.slots[Vector2i(gi / GH / 16, (gi % GH) / 16)]
	return float(r.hm[((gi / GH) % 16) * 16 + (gi % GH) % 16]) * 0.5

func _add(mesh: Mesh, mat: Material, pos: Vector3, rot_y := 0.0) -> void:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.position = pos; m.rotation.y = rot_y
	V.add_child(m)

func _marks(w, sz: Dictionary, shaft := false) -> void:
	var sheet := _mat(Color(0.78, 0.9, 1.0, 0.72), 0.25); var foam := _mat(Color(1, 1, 1, 0.9), 0.4)
	for f in sz.falls:
		if not _vis(f.top): continue
		var tx: int = f.top / GH; var ty: int = f.top % GH; var fx: int = f.foot / GH; var fy: int = f.foot % GH
		var yt := _top(w, f.top) + 0.12; var yf := _top(w, f.foot)
		var d := Vector2(fx - tx, fy - ty).normalized()
		var bm := BoxMesh.new(); bm.size = Vector3(0.9, yt - yf, 0.12)
		var pos := Vector3(tx + 0.5 + d.x * 0.55, (yt + yf) * 0.5, ty + 0.5 + d.y * 0.55)
		_add(bm, sheet, pos, atan2(d.x, d.y))
		var cap := BoxMesh.new(); cap.size = Vector3(0.9, 0.08, 0.9)
		_add(cap, sheet, Vector3(tx + 0.5, yt - 0.02, ty + 0.5), atan2(d.x, d.y))
		for k in 7:
			var sp := SphereMesh.new(); var rr := 0.12 + 0.05 * (k % 3); sp.radius = rr; sp.height = rr * 2
			_add(sp, foam, Vector3(fx + 0.5 + 0.32 * cos(k * 0.9) - d.x * 0.2, yf + 0.08, fy + 0.5 + 0.32 * sin(k * 0.9) - d.y * 0.2))
	_water(w)
	var dark := _mat(Color(0.05, 0.06, 0.12)); var karst := _mat(Color(0.0, 0.75, 0.85), 0.5); var tube := _mat(Color(0.1, 0.25, 0.7, 0.85), 0.3)
	for i in sz.sink.size():
		if sz.sink[i] == 0 or not _vis(i): continue
		var gx: int = i / GH; var gy: int = i % GH; var y := _top(w, i)
		var cy := CylinderMesh.new(); cy.top_radius = 0.48; cy.bottom_radius = 0.35; cy.height = 0.12
		_add(cy, karst if sz.sink[i] == 2 else dark, Vector3(gx + 0.5, y + 0.2, gy + 0.5))
		if shaft:
			var tb := BoxMesh.new(); tb.size = Vector3(0.5, 3.0, 0.06)   # na čelní ploše řezu, aby byla vidět
			_add(tb, tube, Vector3(gx + 0.5, y - 1.5, gy + 1.03))

var _row := -1; var _cut := -1   # při řezu se kreslí jen řada bloků _row a místní y ≤ _cut
func _vis(gi: int) -> bool:
	return _row < 0 or ((gi % GH) / 16 == _row and (gi % GH) % 16 <= _cut)

var cs := {}   # uložené koryto (tok.gd) pro kreslení vody
var springs := []

func _water(w) -> void:
	if cs.is_empty(): return
	var wm := _mat(Color(0.2, 0.5, 0.95, 0.8), 0.15); var pm := _mat(Color(0.1, 0.32, 0.8, 0.72), 0.1)
	var W: int = cs.W
	for i in W * GH:
		if cs.wall[i] == 1 or not _vis(i): continue
		var y := _top(w, i); var lv: float = cs.fill[i] * 0.5
		if cs.pw[i] == 1 and lv > y + 0.05:
			var bm := BoxMesh.new(); bm.size = Vector3(1, lv - y, 1)
			_add(bm, pm, Vector3(i / GH + 0.5, y + (lv - y) * 0.5, i % GH + 0.5))
		elif cs.eff[i] > 0.0:
			var bm := BoxMesh.new(); bm.size = Vector3(0.7 + 0.06 * minf(cs.eff[i], 5.0), 0.14, 0.7 + 0.06 * minf(cs.eff[i], 5.0))
			_add(bm, wm, Vector3(i / GH + 0.5, y + 0.07, i % GH + 0.5))
	var sm := _mat(Color(0.75, 1.0, 1.0), 1.2)
	for sp in springs:
		if not _vis(sp.gi): continue
		var sph := SphereMesh.new(); sph.radius = 0.35; sph.height = 0.7
		_add(sph, sm if sp.aktivni else _mat(Color(0.4, 0.4, 0.4)), Vector3(sp.gi / GH + 0.5, _top(w, sp.gi) + 0.35, sp.gi % GH + 0.5))
	# okraj ostrova: stěna vody dolů a mlha
	var sheet := _mat(Color(0.78, 0.9, 1.0, 0.65), 0.3); var mist := _mat(Color(0.95, 0.97, 1.0, 0.28), 0.2)
	var falls_e := TOK.edge_falls(cs).map(func(e): return [e.gi, _top(w, e.gi) + 0.1])
	for u in cs.under: falls_e.append([u.exit, float(u.z) * 0.5])   # vyvěračka ve stěně: podzemní voda z tůně vyteče pod povrchem
	for fe in falls_e:
		var i: int = fe[0]; var x := i / GH; var yy := i % GH
		if not _vis(i): continue
		var o := Vector2(-1 if x == 0 else (1 if x == W - 1 else 0), -1 if yy == 0 else (1 if yy == GH - 1 else 0))
		if o.x != 0 and o.y != 0: o.y = 0
		var top: float = fe[1]; var bot := -7.0
		var bm := BoxMesh.new(); bm.size = Vector3(0.95, top - bot, 0.14)
		_add(bm, sheet, Vector3(x + 0.5 + o.x * 0.58, (top + bot) * 0.5, yy + 0.5 + o.y * 0.58), atan2(o.x, o.y))
		for k in 6:
			var sp := SphereMesh.new(); var r := 1.2 + 0.4 * (k % 3); sp.radius = r; sp.height = r * 1.4
			var pr := Vector2(o.y, o.x) * (k - 2.5) * 0.7
			_add(sp, mist, Vector3(x + 0.5 + o.x * (1.4 + 0.3 * (k % 2)) + pr.x, bot - 0.35 * (k % 3), yy + 0.5 + o.y * (1.4 + 0.3 * (k % 2)) + pr.y))

func _show(w, sz, text: String, name: String, center: Vector3, size: float, dir: Vector3, cut := -1, row := -1, shaft := false) -> void:
	var blocks := {}
	for s in w.order:
		var r: Dictionary = w.slots[s]
		blocks[s] = {"cells": r.cells, "water": r.get("water_sim", PackedInt32Array())}
	V.clear()
	var opts := {"wet": false}
	_row = row if cut >= 0 else -1; _cut = cut
	if cut >= 0: opts = {"wet": false, "cut_axis": "y", "cut": cut, "keep": func(s): return s.y == row}
	V.show_blocks(blocks, opts)
	if sz != null: _marks(w, sz, shaft)
	C.frame(center, size, dir)
	U.say(text)
	LG.clear()
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/47b_%s.png" % name))
	print("shot ", name)

func run() -> void:
	Mesher.PALETTE = HR.palette()
	var p: Dictionary = S.params
	p.geo = "v2"
	var w0 = T.build(p)
	GH = w0.h * 16

	var er := ES.run(w0, p, "strze")
	var w1 = er.world; var sz: Dictionary = er.rep.strze
	springs = sz.springs
	var g := TB._grid_hm(w1)
	var wall := PackedByteArray(); wall.resize(g.size()); wall.fill(1)
	for s in w1.order:
		for i in 256: wall[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16] = 0
	cs = TOK.make(g, w1.w * 16, GH, wall, sz.mats, PRM.src(springs, g, g.size()), TOK.losses(p, true), bool(p.ostrov_okraj))
	TOK.route(cs)
	var sinks := PackedInt32Array()
	for i in sz.sink.size():
		if sz.sink[i] > 0: sinks.append(i)
	var eq := 0.0
	for e in TOK.edge_falls(cs): eq += e.q
	var c0 := Vector3(24, 18, 24); var d0 := Vector3(0.9, 1.0, 1.3)
	var keep := cs; cs = {}
	await _show(w0, null, "E47c před: 8 bloků v2, bez vody (déšť je jen vizuální)", "iso_pred", c0, 62, d0)
	cs = keep
	await _show(w1, sz, "E47c po: %d pramenů (%.0f l/s) → strže medián ~%.0f m, %d vodopádů ve strži, %d ponor, tůně do hladiny přelivu\n%d vodopádů přes okraj ostrova do mlhy (%.1f l/s)" % [springs.size(), springs.reduce(func(a, x): return a + float(x.q), 0.0), float(p.strz_target_m), sz.falls.size(), sinks.size(), TOK.edge_falls(cs).size(), eq], "iso_po", c0, 62, d0)
	# vodopád: nejvyšší
	var best: Dictionary = sz.falls[0] if not sz.falls.is_empty() else {}
	for f in sz.falls:
		if f.drop_m > best.drop_m: best = f
	if not best.is_empty():
		var fc := Vector3(best.top / GH + 0.5, _top(w1, best.top) - 0.5, best.top % GH + 0.5)
		await _show(w1, sz, "vodopád %.1f m (spád ≥ %.1f m po proudu ze strže), pod ním tůň %.1f m vymletá do horniny" % [best.drop_m, float(p.vodopad_m), float(p.tun_k) * best.drop_m if float(p.tun_k) * best.drop_m < float(p.tun_max_m) else float(p.tun_max_m)], "vodopad", fc, 13, Vector3(0.8, 0.75, 1.1))
		for k in 24:   # krátké oblétnutí pro GIF
			var a := TAU * k / 24.0
			await _show(w1, sz, "", "gif_%02d" % k, fc, 13, Vector3(cos(a) * 1.3, 0.85, sin(a) * 1.3))
	# okraj ostrova: největší odtok přes okraj
	var be := {}
	for e in TOK.edge_falls(cs):
		if be.is_empty() or e.q > be.q: be = e
	if not be.is_empty():
		var i: int = be.gi; var x := i / GH; var yy := i % GH; var W: int = cs.W
		var o := Vector3(-1 if x == 0 else (1 if x == W - 1 else 0), 0, -1 if yy == 0 else (1 if yy == GH - 1 else 0))
		if o.x != 0 and o.z != 0: o.z = 0
		await _show(w1, sz, "okraj plovoucího ostrova: potok %.1f l/s přepadá přes okraj do mlhy, dál se nesimuluje" % be.q, "okraj", Vector3(x + 0.5 - o.x * 4.0, (_top(w1, i) - 7.0) * 0.5, yy + 0.5 - o.z * 4.0), 44, o * 1.0 + Vector3(0, 0.45, 0) + Vector3(o.z, 0, o.x) * 0.6)
	# ponor: kras s největším průtokem, jinak největší
	var bs := -1; var bk := -1.0
	for i in sinks:
		var score: float = sz.acc[i] + (1000.0 if sz.sink[i] == 2 else 0.0)
		if score > bk: bk = score; bs = i
	var pit := false
	if bs < 0 and not cs.under.is_empty():   # bez ponoru: přeliv tůně, která odvádí vodu do propustné vrstvy (Jan 19:48)
		var bu: Dictionary = cs.under[0]
		for u in cs.under:
			if u.q > bu.q: bu = u
		bs = bu.from; pit = true
		sz.sink[bs] = 1
	if bs >= 0:
		var gx: int = bs / GH; var gy: int = bs % GH
		var sc := Vector3(gx + 0.5, _top(w1, bs) - 1.0, gy + 0.5)
		if pit:
			var uq := 0.0
			for u in cs.under:
				if u.from == bs: uq = u.q
			await _show(w1, sz, "tůň odvádí %.1f l/s do propustné vrstvy (odtok prohlubně = Σ perm, Jan 19:48), zbytek přetéká přelivem\nřez y = %d, modrá šachta = podzemím k vyvěračce ve stěně ostrova → vodopád do mlhy" % [uq, gy % 16], "ponor", Vector3(gx + 0.5, _top(w1, bs) - 1.0, gy + 0.5), 16, Vector3(0.35, 0.55, 1.0), gy % 16, gy / 16, true)
		else:
			await _show(w1, sz, "ponor (%s): potok %.1f l/s mizí do podzemí (%s hornina)\nřez y = %d, modrá šachta = kudy voda odchází (zvodeň se nemodeluje, voda zmizí)" % ["kras" if sz.sink[bs] == 2 else "propustná", sz.acc[bs], "rozpustná" if sz.sink[bs] == 2 else "propustná", gy % 16], "ponor", sc, 14, Vector3(0.35, 0.55, 1.0), gy % 16, gy / 16, true)
	print("falls ", sz.falls.size(), " sink ", bs)
