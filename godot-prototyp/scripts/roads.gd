@tool
## Cesty: A* po povrchu ostrova (globální sloupce gx, gz).
## Průchozí: sloupec patří vloženému bloku (ne mlha, ne mezera), není pod stavbou,
## krok na souseda (4-okolí) má |Δhm| ≤ MAX_STEP = 4 buňky (1 buňka = 0,5 m). Větší útesy, mlha a voda neprojdou.
## Cena kroku = step_cost(|Δhm|): 0 -> 1, 1 -> 1,5 (rampa), 2..4 -> 1 + 2,5·Δ (schody, penalizace).
## Heuristika = Manhattan (přípustná). Shody řeší pořadí sousedů (deterministicky).
## Terén se nemění: rampy a schody jsou objekty vrstvy cesty, stojí na nižším sloupci a vedou k hraně vyššího.
extends RefCounted

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const BS := J.BS
const CELL_H := J.CELL_M     # výška buňky (m)
const MAX_STEP := 4          # větší rozdíl = útes, neprůchozí
const STAIR_FROM := 2        # od 2 buněk se staví schody (1 buňka = rampa)
const Toon = preload("res://scripts/toon.gd")
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func height(island, g: Vector2i) -> int:
	var s := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(s):
		return -1
	var b = island.blocks[s]
	var lx := g.x - s.x * BS
	var ly := g.y - s.y * BS
	var h: int = b.hm[lx * BS + ly]
	return h if h > 0 else -1

## A* mezi dvěma sloupci; blocked = Dictionary {Vector2i: true} (stavby). Vrací [] když cesta není.
## Stav = (sloupec, směr příchodu, čeká-po-sestupu). Schody o 3–4 buňky bez rovného nájezdu/výjezdu mají přirážku
## TURN_PENALTY, takže trasa dá přednost rovnému úseku, na který se schody roztáhnou (2 sloupce).
const TURN_PENALTY := 2.0
static func _key(c: Vector2i, dir: int, pend: int) -> int:
	return ((c.x + 2048) * 8192 + (c.y + 2048)) * 16 + dir * 2 + pend

static func find(island, a: Vector2i, b: Vector2i, blocked := {}) -> Array:
	if height(island, a) < 0 or height(island, b) < 0:
		return []
	var open := [[_h(a, b), 0.0, a, 4, 0]]   # [f, g, sloupec, směr příchodu (4 = žádný), čeká-po-sestupu]
	var came := {}
	var gs := {_key(a, 4, 0): 0.0}
	var closed := {}
	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			if open[i][0] < open[bi][0] - 1e-9:
				bi = i
		var cur: Vector2i = open[bi][2]
		var cdir: int = open[bi][3]
		var cpend: int = open[bi][4]
		var ck := _key(cur, cdir, cpend)
		open.remove_at(bi)
		if closed.has(ck):
			continue
		if cur == b:
			var path := [cur]
			while came.has(ck):
				ck = came[ck]
				path.push_front(Vector2i(ck / 16 / 8192 - 2048, (ck / 16) % 8192 - 2048))
			return path
		closed[ck] = true
		var hc := height(island, cur)
		for k in 4:
			var n: Vector2i = cur + NEI[k]
			if blocked.has(n) and n != b:
				continue
			var hn := height(island, n)
			if hn < 0 or absi(hn - hc) > MAX_STEP:
				continue
			var cost := step_cost(absi(hn - hc))
			if cpend == 1 and k != cdir:
				cost += TURN_PENALTY             # po velkém sestupu hned zahnout
			if hn - hc >= 3 and k != cdir:
				cost += TURN_PENALTY             # velký výstup bez rovného nájezdu
			var npend := 1 if hc - hn >= 3 else 0
			var nk := _key(n, k, npend)
			if closed.has(nk):
				continue
			var g: float = gs[ck] + cost
			if not gs.has(nk) or g < gs[nk]:
				gs[nk] = g
				came[nk] = ck
				open.append([g + _h(n, b), g, n, k, npend])
	return []

## všechny sloupce dosažitelné ze startu (stejná pravidla jako A*)
static func reachable(island, a: Vector2i, blocked := {}) -> Dictionary:
	var seen := {a: true}
	var q := [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		var hc := height(island, c)
		for d in NEI:
			var n: Vector2i = c + d
			if seen.has(n) or blocked.has(n):
				continue
			var hn := height(island, n)
			if hn < 0 or absi(hn - hc) > MAX_STEP:
				continue
			seen[n] = true
			q.append(n)
	return seen

static func step_cost(dh: int) -> float:
	if dh == 0:
		return 1.0
	if dh < STAIR_FROM:
		return 1.5
	return 1.0 + 2.5 * dh

static func _h(p: Vector2i, q: Vector2i) -> float:
	return absi(p.x - q.x) + absi(p.y - q.y)

## Trasa přes body (start, průjezdní body…, cíl). Vrací [] když některý úsek neexistuje.
static func route(island, pts: Array, blocked := {}) -> Array:
	var out := []
	for i in range(pts.size() - 1):
		var seg := find(island, pts[i], pts[i + 1], blocked)
		if seg.is_empty():
			return []
		if not out.is_empty():
			seg.remove_at(0)
		out.append_array(seg)
	return out

## Vrstva cesty: jeden mesh (dlaždice, rampy, schody) s kawaii materiálem a obrysem.
## Na sloupci, ze kterého trasa stoupá k vyššímu sousedovi, místo dlaždice stojí rampa (Δ = 1) nebo schody (Δ 2–4).
const ROAD_COL := Color(0.96, 0.86, 0.70)
const STAIR_COL := Color(0.90, 0.84, 0.90)
const T := 0.06   # tloušťka dlaždice

## Kusy cesty: pro každý sloupec, ze kterého trasa stoupá, jeden kus {d, hu, fill, idx, run}:
## - údolí (sloupec stoupá k oběma sousedům) = sloučení: plošina do výšky nižšího souseda + jedny schody/rampa k vyššímu;
## - stoupání o 3–4 buňky s rovným přímým nájezdem = schody roztažené na 2 sloupce (run 2).
static func pieces(island, path: Array) -> Dictionary:
	var pc := {}
	for i in range(path.size() - 1):
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		var ha := height(island, a)
		var hb := height(island, b)
		if ha == hb:
			continue
		var lo: Vector2i = a if ha < hb else b
		var hi: Vector2i = b if ha < hb else a
		var li := i if ha < hb else i + 1
		var hu := maxi(ha, hb)
		if pc.has(lo):
			var e: Dictionary = pc[lo]
			if hu > e.hu:
				pc[lo] = {"d": hi - lo, "hu": hu, "fill": e.hu, "idx": li, "run": 1}
			else:
				e.fill = hu
		else:
			pc[lo] = {"d": hi - lo, "hu": hu, "fill": height(island, lo), "idx": li, "run": 1}
	var used := {}
	for lo in pc:
		var e: Dictionary = pc[lo]
		if e.hu - e.fill < 3 or e.fill != height(island, lo):
			continue
		var pp: Vector2i = lo - e.d
		var k: int = e.idx
		var adj: bool = (k > 0 and path[k - 1] == pp) or (k + 1 < path.size() and path[k + 1] == pp)
		if adj and height(island, pp) == e.fill and not pc.has(pp) and not used.has(pp):
			e.run = 2
			used[pp] = true
	pc["_used"] = used
	return pc

static func build_layer(island, path: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Cesta"
	if path.is_empty():
		return root
	var pc := pieces(island, path)
	var used: Dictionary = pc["_used"]
	var tiles := SurfaceTool.new(); tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stairs := 0
	var has_st := false
	for p in path:
		if pc.has(p) or used.has(p):
			continue
		_cobble(tiles, p, height(island, p) * CELL_H)
	for lo in pc:
		if lo is String:
			continue
		var e: Dictionary = pc[lo]
		has_st = true
		var hl := height(island, lo)
		var y0 := hl * CELL_H
		if e.fill > hl:   # plošina v údolí (sloučení dvou stoupání)
			_box(st, lo, Vector2i(1, 0), 0.0, 1.0, -0.5, 0.5, y0 - T, e.fill * CELL_H + 0.03, e.fill * CELL_H + 0.03, STAIR_COL.darkened(0.08))
		var ys: float = e.fill * CELL_H + 0.03
		var ye: float = e.hu * CELL_H + 0.03
		var dh: int = e.hu - e.fill
		var t0: float = 1.0 - e.run
		if dh == 0:
			continue
		if dh < STAIR_FROM:
			_box(st, lo, e.d, t0, 1.0, -0.5, 0.5, y0 - T, ys, ye, ROAD_COL)   # rampa
			continue
		stairs += 1
		var n := dh * 2 * int(e.run)  # při run 2 nižší stupně (0,125 m)
		for k in n:
			var top := ys + (ye - ys) * float(k + 1) / n
			var ta := t0 + float(e.run) * k / n
			var tb := t0 + float(e.run) * (k + 1) / n
			_box(st, lo, e.d, ta, tb, -0.42, 0.42, y0 - T, top, top, STAIR_COL)
		for w in [-0.46, 0.46]:
			_box(st, lo, e.d, t0, t0 + 0.12, w - 0.04, w + 0.04, ys - 0.03, ys + 0.35, ys + 0.35, ROAD_COL.darkened(0.25))
	var mt := MeshInstance3D.new()
	mt.mesh = tiles.commit()
	mt.material_override = Toon.object_mat(Color(1, 1, 1), 0.0, true)
	mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mt)
	if has_st:
		var ms := MeshInstance3D.new()
		ms.mesh = st.commit()
		ms.material_override = Toon.object_mat(Color(1, 1, 1), 0.0, true)
		ms.material_overlay = Toon.outline_mat(Color(0.70, 0.60, 0.70), 0.02)
		root.add_child(ms)
	root.set_meta("stairs", stairs)
	var spread := 0; var merged := 0
	for lo in pc:
		if lo is String: continue
		if pc[lo].run == 2: spread += 1
		if pc[lo].fill > height(island, lo): merged += 1
	root.set_meta("spread", spread); root.set_meta("merged", merged)
	return root

## dlažba: podklad (spárovací malta) + 2 × 2 kameny s drobnou odchylkou výšky a barvy (deterministicky z polohy)
const MORTAR := Color(0.84, 0.74, 0.64)
static func _cobble(st: SurfaceTool, p: Vector2i, y0: float) -> void:
	_box(st, p, Vector2i(1, 0), 0.0, 1.0, -0.5, 0.5, y0 - T, y0 + 0.01, y0 + 0.01, MORTAR)
	for q in 4:
		var hsh := absi((p.x * 73856093) ^ (p.y * 19349663) ^ (q * 83492791)) % 1000
		var j := hsh / 1000.0
		var t := 0.04 + (q % 2) * 0.48
		var w := -0.46 + (q / 2) * 0.48
		var top := y0 + 0.035 + j * 0.02
		var c := ROAD_COL.lerp(Color(1.0, 0.93, 0.82), j * 0.6).darkened(0.06 * fmod(j * 7.0, 1.0))
		_box(st, p, Vector2i(1, 0), t, t + 0.44, w, w + 0.44, y0, top, top, c)

## hranol nad sloupcem p ve směru d: t (0 = vzdálená strana, 1 = strana k d), šířka ±hw,
## spodek yb, vršek lineárně yt0 (t0) -> yt1 (t1)
static func _prism(st: SurfaceTool, p: Vector2i, d: Vector2i, t0: float, t1: float, hw: float,
		yb: float, yt0: float, yt1: float, col: Color) -> void:
	_box(st, p, d, t0, t1, -hw, hw, yb, yt0, yt1, col)

static func _prism_w(st: SurfaceTool, p: Vector2i, d: Vector2i, t0: float, t1: float, w0: float, w1: float,
		yb: float, yt: float, col: Color) -> void:
	_box(st, p, d, t0, t1, w0, w1, yb, yt, yt, col)

static func _box(st: SurfaceTool, p: Vector2i, d: Vector2i, t0: float, t1: float, w0: float, w1: float,
		yb: float, yt0: float, yt1: float, col: Color) -> void:
	var c := Vector3(p.x + 0.5, 0, p.y + 0.5)
	var dv := Vector3(d.x, 0, d.y)
	var q := Vector3(-d.y, 0, d.x)
	var P := func(t: float, w: float, y: float) -> Vector3:
		return c + dv * (t - 0.5) + q * w + Vector3(0, y, 0)
	var v := [
		P.call(t0, w0, yb), P.call(t1, w0, yb), P.call(t1, w1, yb), P.call(t0, w1, yb),
		P.call(t0, w0, yt0), P.call(t1, w0, yt1), P.call(t1, w1, yt1), P.call(t0, w1, yt0)]
	var ctr := Vector3.ZERO
	for x in v:
		ctr += x
	ctr /= 8.0
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		_quad(st, v[f[0]], v[f[1]], v[f[2]], v[f[3]], ctr, col)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ctr: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-6:
		n = (c - a).cross(d - a)
	var out := ((a + b + c + d) * 0.25 - ctr)
	if n.dot(out) > 0.0:   # Godot: přední strana = po směru hodinových ručiček -> obrátit pořadí
		var t := b; b = d; d = t
		n = -n
	var nn := -n.normalized()
	for x in [a, b, c, a, c, d]:
		st.set_normal(nn)
		st.set_color(col)
		st.add_vertex(x)

## Sloupce zabrané stavbou (půdorys 3 × 3 kolem středu) a sloupec před dveřmi (+z).
static func footprint(c: Vector2i) -> Array:
	var out := []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			out.append(c + Vector2i(dx, dz))
	return out

static func door(c: Vector2i) -> Vector2i:
	return c + Vector2i(0, 2)
