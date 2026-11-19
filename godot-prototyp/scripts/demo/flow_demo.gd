extends Node
## Tok vody po kopání (Jan 20:39), přidá ho demo_runner.gd:
##   -- --flow-shots [--tag=X]   časová řada: jáma ze strany prokopnutá do jeskyně s vodou → shots/42_tok_*<_tag>.png
##   -- --flow-bench [--tag=X]   měření kopání s tokem, kontrola delty, determinismus → shots/42_tok_bench<_tag>.txt

const BlockGen = preload("res://scripts/block_gen.gd")
const Block = preload("res://scripts/block.gd")
const Mat = preload("res://scripts/mat.gd")
const Params = preload("res://scripts/surface/surface_params.gd")
const WF = preload("res://scripts/gen3/water_flow.gd")
const BS := 16
const BH := 64
const PIT_LEN := 3      # jáma za stěnou: 3 sloupce do délky × 3 do šířky
const PIT_DEPTH := 3    # dno jámy 3 buňky pod hladinou jeskyně
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var m
var tag := ""
var p
var lab: Label

func _ready() -> void:
	m = get_parent()
	p = Params.inst()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	m.set_game_process(false)
	if "--flow-shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	else:
		_bench.call_deferred()

func _sfx(base: String, ext: String) -> String:
	return "42_tok_%s%s.%s" % [base, ("_" + tag) if tag != "" else "", ext]

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

func _place(s: Vector2i, kind: String, seed: int) -> float:
	var t0 := Time.get_ticks_usec()
	var b = m.island.make_block(kind, seed, "gen-v3")
	b.slot = s
	BlockGen.build(b, m.island.neighbor_hms(s))
	m.island.place(b)
	return (Time.get_ticks_usec() - t0) / 1000.0

func _label() -> void:
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

## místo pro jámu ze strany: buňka jeskyně s vodou A (horní hladina), sousední sloupec N (stěna) ve směru d, za ní suchá jáma.
## [slot, ax, ay, az, d] – jeskyně s nejvíc vodou (výraznější tok), při shodě vyšší hladina
func _find_site() -> Array:
	var best := []
	var best_v := -1
	for s in m.island.blocks:
		var b: Block = m.island.blocks[s]
		if b.water.size() != b.cells.size():
			continue
		for x in range(1, BS - 1):
			for y in range(1, BS - 1):
				for z in range(4, b.hm[x * BS + y]):
					var c := (x * BS + y) * BH + z
					if b.cells[c] != Mat.AIR or b.water[c] <= 0 or (b.cells[c + 1] == Mat.AIR and b.water[c + 1] > 0):
						continue
					for d in DIRS:
						var ok := true
						var pp := Vector2i(-d.y, d.x)
						for k in range(1, PIT_LEN + 2):
							for j in range(-1, 2):
								var q: Vector2i = Vector2i(x, y) + d * k + pp * j
								if q.x < 0 or q.y < 0 or q.x >= BS or q.y >= BS or m.island.occupied.has(s * BS + q):
									ok = false; break
								var qc: int = (q.x * BS + q.y) * BH + z
								if b.cells[qc] == Mat.AIR or b.hm[q.x * BS + q.y] < z + 3:
									ok = false; break
								for zz in range(z - PIT_DEPTH - 1, b.hm[q.x * BS + q.y]):   # suchá jáma: voda přiteče jen z jeskyně
									if WF._mobile(b, (q.x * BS + q.y) * BH + zz) or (b.cells[(q.x * BS + q.y) * BH + zz] == Mat.AIR and k > 1):
										ok = false; break
								if not ok: break
							if not ok: break
						if ok:
							var vol := _cave_water(b, c)
							if vol > best_v or (vol == best_v and z > best[3]):
								best = [s, x, y, z, d]; best_v = vol
							break
	return best

## volná voda (jednotky) v souvislé zatopené části jeskyně od buňky c
func _cave_water(b: Block, c0: int) -> int:
	var seen := {c0: true}
	var q := [c0]
	var t := 0
	var i := 0
	while i < q.size():
		var c: int = q[i]; i += 1
		t += b.water[c]
		for o in [BS * BH, -BS * BH, BH, -BH, 1, -1]:
			var n: int = c + o
			if n < 0 or n >= b.cells.size() or seen.has(n) or b.cells[n] != Mat.AIR or b.water[n] <= 0:
				continue
			if absi(n / BH % BS - c / BH % BS) > 1:
				continue
			seen[n] = true
			q.append(n)
	return t

func _pit_cols(site: Array) -> Array:
	var d: Vector2i = site[4]
	var pp := Vector2i(-d.y, d.x)
	var o: Vector2i = site[0] * BS + Vector2i(site[1], site[2])
	var cols := []
	for k in range(2, PIT_LEN + 2):
		for j in range(-1, 2):
			cols.append(o + d * k + pp * j)
	return cols

## vykope jámu za stěnou až po hladinu − 2 (stěna N zůstane) – toky v nasycené půdě se dopočítají hned
func _dig_pit(site: Array) -> void:
	var b: Block = m.island.blocks[site[0]]
	m.water.flow_sync = true
	for g in _pit_cols(site):
		var l: Vector2i = g - site[0] * BS
		var guard := 0
		while b.hm[l.x * BS + l.y] > site[3] - PIT_DEPTH and guard < 64:
			m.digging.dig(g); guard += 1

func _wall(site: Array) -> Vector2i:
	return site[0] * BS + Vector2i(site[1], site[2]) + site[4]

## stěnu N kope shora až po hladinu jeskyně; poslední vykopnutá buňka otevře jeskyni ze strany
func _dig_wall_to_opening(site: Array, sync: bool) -> void:
	var b: Block = m.island.blocks[site[0]]
	var g := _wall(site)
	var l: Vector2i = g - site[0] * BS
	m.water.flow_sync = true
	while b.hm[l.x * BS + l.y] > site[3] + 1:
		m.digging.dig(g)
	m.water.flow_sync = sync
	m.digging.dig(g)

## voda v jámě (sloupce jámy a stěny, vzduch nad dnem) a v jeskyni (zbytek) v buňkách
func _pit_water(site: Array) -> float:
	var b: Block = m.island.blocks[site[0]]
	var t := 0
	for g in _pit_cols(site) + [_wall(site)]:
		var l: Vector2i = g - site[0] * BS
		for z in BH:
			var c := (l.x * BS + l.y) * BH + z
			if b.cells[c] == Mat.AIR:
				t += b.water[c]
	return t / 4096.0

func _shots() -> void:
	if m.ui:
		m.ui.visible = false
	m.island.set_textured(true)
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)
	_place(Vector2i(2, 0), "kopec", 404)     # kopce s jeskyní s vodou v suché skále (jáma nenasákne z okolí)
	_place(Vector2i(2, 1), "kopec", 4504)
	_label()
	var site := _find_site()
	if site.is_empty():
		print("tok: na ostrově není jeskyně s vodou vhodná pro jámu ze strany")
		get_tree().quit(); return
	print("tok: místo ", site)
	var s: Vector2i = site[0]
	var d: Vector2i = site[4]
	var g := _wall(site)
	var yaw := rad_to_deg(atan2(float(d.x), float(d.y)))   # kamera za jámou, dívá se přes jámu na stěnu k jeskyni
	var cpit := Vector3(g.x + 0.5 + d.x * 0.5, (site[3] - 1) * 0.5, g.y + 0.5 + d.y * 0.5)
	var cslice := Vector3(g.x + 0.5, site[3] * 0.5, g.y + 0.5)
	print("tok: voda v jeskyni %.2f buňky" % (_cave_water(m.island.blocks[s], (site[1] * BS + site[2]) * BH + site[3]) / 4096.0))
	_dig_pit(site)
	lab.text = "tok vody: jáma 3 × 3 vykopaná vedle jeskyně s vodou (blok %s), stěna k jeskyni zatím stojí – jeskyně skrytá" % str(s)
	_cam(cpit, 11.0, yaw, -62.0)
	await _snap(_sfx("0_jama_pred", "png"))
	p.set_param("xray", true)
	m.island.set_slice(site[3] + 1)
	lab.text = "tok vody: totéž v řezu (vrstva %d) s x-ray – za stěnou jeskyně s vodou (modře, z dat bloku)" % (site[3] + 1)
	_cam(cslice, 18.0, yaw, -70.0)
	await _snap(_sfx("0_jama_pred_rez", "png"))
	p.set_param("xray", false)
	m.island.set_slice(-1)
	# otevření ze strany: tok se nedopočítá hned, krokujeme ho po snímcích
	_dig_wall_to_opening(site, false)
	if m.water.flows.is_empty():
		print("tok: otevření nespustilo tok"); get_tree().quit(); return
	var e: Dictionary = m.water.flows[0]
	var f = e.flow
	print("tok: výřez ", f.box(), " (", f.box_cells(), " buněk)")
	var marks := [0, 6, 20, -1]
	var names := ["1_otevreno", "2_tik06", "3_tik20", "4_ustaleno"]
	for k in marks.size():
		if marks[k] < 0:
			m.water.finish_all()
		else:
			f.step_n(marks[k] - f.ticks)
			f.write_preview()
			m.island._remesh(s)
		var info := "tik %d" % f.ticks if marks[k] >= 0 else "ustáleno po %d tikách (kontrola delty %s)" % [f.ticks, "OK" if m.water.last_flow.valid.ok else "CHYBA"]
		lab.text = "tok vody: stěna prokopnutá do jeskyně ze strany – %s, voda v jámě %.2f buňky (simulace voda-studie jen ve výřezu %d × %d × %d)" % [info, _pit_water(site), f.nx, f.ny, f.nz]
		_cam(cpit, 11.0, yaw, -62.0)
		await _snap(_sfx(names[k], "png"))
		m.island.set_slice(site[3] + 1)
		lab.text = "řez ve vrstvě %d (skrytí zapnuto, jeskyně odkrytá prokopáním): %s" % [site[3] + 1, info]
		_cam(cslice, 18.0, yaw, -70.0)
		await _snap(_sfx(names[k] + "_rez", "png"))
		m.island.set_slice(-1)
	get_tree().quit()

## ---------- měření ----------
func _hash(b: Block) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b.cells); hc.update(b.hm.to_byte_array()); hc.update(b.water.to_byte_array())
	return hc.finish().hex_encode().substr(0, 16)

func _snapshot(b: Block) -> Array:
	return [b.cells.duplicate(), b.hm.duplicate(), b.water.duplicate()]

func _restore(b: Block, sn: Array) -> void:
	b.cells = sn[0].duplicate(); b.hm = sn[1].duplicate(); b.water = sn[2].duplicate()
	b.recount()
	m.island.refresh_after_edit(b.slot, 8, 8)

func _bench() -> void:
	var out := []
	out.append("tok vody po kopání (water_flow.gd: simulace voda-studie ve výřezu, CALM_EPS %s/tik × %d tiků, ověření %d tiků ≤ %.3f buňky)" % [str(WF.CALM_EPS), WF.CALM_TICKS, WF.VERIFY_TICKS, WF.VERIFY_EPS])
	p.set_param("xray", false)
	p.set_param("hide_undiscovered", true)
	var ins := []
	for e in [[Vector2i(2, 0), "kopec", 404], [Vector2i(2, 1), "kopec", 4504], [Vector2i(-1, 0), "hora", 1000], [Vector2i(0, 2), "piscina", 4504]]:
		var t := _place(e[0], e[1], e[2])
		var b: Block = m.island.blocks[e[0]]
		ins.append("%s %d %.0f ms (validátor %.1f ms %s)" % [e[1], e[2], t, b.gen3.ms_validate, "OK" if b.gen3.valid.ok else "CHYBA"])
	out.append("vložení (validátor vždy): " + ", ".join(ins))
	var allv := []
	for s in m.island.blocks:
		var b: Block = m.island.blocks[s]
		allv.append("OK" if b.gen3.get("valid", {}).get("ok", false) else "CHYBA")
	out.append("validátor při vložení na všech %d blocích ostrova: %d OK" % [allv.size(), allv.count("OK")])
	# 1) kopání v suchu (jen kontrola spouštěče) vs. bez toku
	m.water.flow_sync = true
	var t0 := Time.get_ticks_usec()
	for i in 4:
		m.digging.dig(Vector2i(-BS + 6 + i, 8))
	out.append("kopání v suchu (spouštěč nic nenašel): %.1f ms na buňku, toků %d" % [(Time.get_ticks_usec() - t0) / 4000.0, m.water.flows.size()])
	# 2) jáma ze strany do jeskyně s vodou (stejné místo jako ve screenshotech)
	var site := _find_site()
	if site.is_empty():
		out.append("jáma ze strany: místo nenalezeno")
	else:
		var b: Block = m.island.blocks[site[0]]
		_dig_pit(site)
		var g := _wall(site)
		var l: Vector2i = g - site[0] * BS
		m.water.flow_sync = true
		while b.hm[l.x * BS + l.y] > site[3] + 1:
			m.digging.dig(g)
		var sn := _snapshot(b)
		var w0 := 0
		for v in b.water: w0 += v
		t0 = Time.get_ticks_usec()
		m.digging.dig(g)
		var tdig := (Time.get_ticks_usec() - t0) / 1000.0
		var lf: Dictionary = m.water.last_flow
		var h1 := _hash(b)
		var w1 := 0
		for v in b.water: w1 += v
		var dl: Dictionary = m.digging.deltas[site[0]].back()
		out.append("jáma ze strany do jeskyně (blok %s, hladina lz %d): kopání + tok do ustálení %.0f ms, z toho simulace %.0f ms (%d tiků, %.2f ms/tik), výřez %s = %d buněk" % [str(site[0]), site[3], tdig, lf.ms, lf.ticks, lf.ms / maxf(lf.ticks, 1), str(lf.box), lf.cells])
		out.append("  delta: přesunuto %d jednotek (%.2f buňky), změněných buněk vody %d, součet vody bloku před %d − vykopáno %d = po %d (%s); kontrola delty %s, ověření max %.4f" % [lf.valid.moved_units, lf.valid.moved_units / 4096.0, dl.flow.water.size(), w0, dl.get("water_old", 0), w1, "sedí" if w0 - dl.get("water_old", 0) == w1 else "NESEDÍ", "OK" if lf.valid.ok else "CHYBA " + str(lf.valid.errors), lf.valid.verify_max_delta])
		out.append("  voda v jámě po ustálení %.2f buňky" % _pit_water(site))
		# determinismus: znovu synchronně, a po snímcích (kroky 1, 3, 7 tiků) přes _flow_tick
		_restore(b, sn)
		m.digging.dig(g)
		var h2 := _hash(b)
		var hs := []
		for chunk in [1, 3, 7]:
			_restore(b, sn)
			m.water.flow_sync = false
			m.digging.dig(g)
			var f = m.water.flows[0].flow
			while not f.done:
				f.step_n(chunk)
				f.write_preview()
			m.water.finish_all()
			hs.append(_hash(b))
			m.water.flow_sync = true
		var same := h1 == h2 and hs.count(h1) == hs.size()
		out.append("  determinismus: synchronně 2× a po snímcích (po 1, 3, 7 tikách) %s (%s)" % ["shodné" if same else "ROZDÍLNÉ", ", ".join([h1, h2] + hs)])
		# ve hře: rozpočet na snímek
		_restore(b, sn)
		m.water.flow_sync = false
		m.digging.dig(g)
		var frames := 0
		var fmax := 0.0
		while not m.water.flows.is_empty():
			var tf := Time.get_ticks_usec()
			m.water.tick()
			fmax = maxf(fmax, (Time.get_ticks_usec() - tf) / 1000.0)
			frames += 1
		out.append("  ve hře (rozpočet %.0f ms/snímek + náhled vody): %d snímků (≈ %.1f s při 60 fps), nejdelší snímek %.1f ms, výsledek %s" % [m.water.FLOW_BUDGET_MS, frames, frames / 60.0, fmax, "shodný" if _hash(b) == h1 else "ROZDÍLNÝ"])
		m.water.flow_sync = true
	# 3) kopání pod hladinou v písčině (nasycený písek, voda přitéká do jámy z okolí)
	var pb: Block = m.island.blocks[Vector2i(0, 2)]
	var pg := Vector2i(8, 2 * BS + 8)
	var nf := 0; var tsum := 0.0; var tk := 0; var okc := 0
	t0 = Time.get_ticks_usec()
	for k in 8:
		var before: Dictionary = m.water.last_flow
		m.digging.dig(pg)
		if m.water.last_flow != before:
			nf += 1; tk += m.water.last_flow.ticks; tsum += m.water.last_flow.ms; okc += 1 if m.water.last_flow.valid.ok else 0
	var tall := (Time.get_ticks_usec() - t0) / 1000.0
	out.append("písčina 4504, sloupec (8, 8) kopaný 8 buněk dolů: %.0f ms celkem, toků %d (kontrola delty OK %d), tiků %d, simulace %.0f ms, povrch sloupce lz %d" % [tall, nf, okc, tk, tsum, pb.hm[8 * BS + 8]])
	# 4) průzkum na samotných blocích: 4 recepty × 6 seedů, sloupec vedle jeskyně s vodou kopaný až do otevření
	var nfl := 0; var nok := 0; var tks := []; var mss := []; var cells := []; var sites := 0; var det := 0
	for k in ["kopec", "hora", "louka", "piscina"]:
		for i in 6:
			var r1 := _sweep_one(k, 2000 + 37 * i)
			if r1.is_empty():
				continue
			sites += 1
			var r2 := _sweep_one(k, 2000 + 37 * i)
			if r1.hash == r2.hash: det += 1
			nfl += r1.flows; nok += r1.ok
			tks.append_array(r1.ticks); mss.append_array(r1.ms); cells.append_array(r1.cells)
	out.append("průzkum (bloky bez ostrova, 4 recepty × 6 seedů, sloupec vedle jeskyně s vodou do otevření): míst %d, toků %d, kontrola delty OK %d/%d, determinismus %d/%d" % [sites, nfl, nok, nfl, det, sites])
	if nfl > 0:
		out.append("  tiků do ustálení: medián %d, max %d; simulace: medián %.0f ms, max %.0f ms; výřez: medián %d, max %d buněk" % [_med(tks), _mx(tks), _med(mss), _mx(mss), _med(cells), _mx(cells)])
	for line in out:
		print(line)
	var path := ProjectSettings.globalize_path("res://shots/") + _sfx("bench", "txt")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/"))
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string("\n".join(out) + "\n")
	fa.close()
	print("uloženo shots/", _sfx("bench", "txt"))
	get_tree().quit()

func _med(a: Array) -> float:
	var s := a.duplicate(); s.sort()
	return s[s.size() / 2]

func _mx(a: Array) -> float:
	var r := 0.0
	for v in a: r = maxf(r, v)
	return r

## blok bez ostrova: sloupec vedle nejvyšší jeskyně s vodou se kope shora až do hladiny (jako _dig bez UI)
func _sweep_one(kind: String, seed: int) -> Dictionary:
	var b := Block.new(); b.kind = kind; b.seed = seed
	BlockGen.build(b, [null, null, null, null])
	var best := []
	for x in range(3, 13):
		for y in range(3, 13):
			for z in b.hm[x * BS + y]:
				var c := (x * BS + y) * BH + z
				if b.cells[c] == Mat.AIR and b.water[c] > 0 and b.cells[c + BS * BH] != Mat.AIR and (best.is_empty() or z > best[2]):
					best = [x, y, z]
	if best.is_empty():
		return {}
	var x: int = best[0] + 1; var y: int = best[1]
	var r := {"flows": 0, "ok": 0, "ticks": [], "ms": [], "cells": []}
	while b.hm[x * BS + y] > best[2]:
		var h: int = b.hm[x * BS + y]
		var c := (x * BS + y) * BH + h - 1
		var nh := h - 1
		while nh > 0 and b.cells[(x * BS + y) * BH + nh - 1] == Mat.AIR:
			nh -= 1
		b.hm[x * BS + y] = nh
		b.cells[c] = Mat.AIR; b.water[c] = 0
		var f = WF.start(b, x, y, h - 1)
		if f:
			f.finish()
			var v := WF.validate(f)
			r.flows += 1; r.ok += 1 if v.ok else 0
			r.ticks.append(f.ticks); r.ms.append(f.ms); r.cells.append(f.box_cells())
	r["hash"] = _hash(b)
	return r
