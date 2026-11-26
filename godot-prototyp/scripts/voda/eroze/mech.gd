extends RefCounted
## KOPIE z blueprint-studie/scripts/eroze51/mech.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E51 mechanika toku: eroze a usazování jako UDÁLOSTI v jedné globální haldě (žádné tiky). Tok = E47c (voda/tok.gd).
## Sloupec = zásobník buněk (0,5 m, index sloupec · NZ + z), hm = počet pevných buněk. Mokrý sloupec (tekoucí voda
## eff ≥ práh nebo tůň pw) má právě jednu platnou položku ve frontě (generace gen; staré se přeskočí).
##  eroze:  v ≥ ero_v vrchu → odpočet R (m³ vody) klesá rychlostí Q (· (v/ero_v)^k); R = 0 → buňka odnesena
##  nános:  tůň a v < sed_v nánosu → A (m³ usazeniny) roste c0 · Q_tůně / sloupců (+ odnesená hmota shora); plná buňka → +1
##  změna:  TOK.update (lokálně po proudu) → dotčené sloupce: dopočítat postup do teď a naplánovat znovu
## Kopání / položení hráčem vynuluje odpočet sloupce.

const TOK = preload("res://scripts/voda/tok.gd")
const HY = preload("res://scripts/voda/eroze/hydro.gd")
const Heap = preload("res://scripts/voda/eroze/halda.gd")
const LI = preload("res://scripts/voda/litry.gd")   # E94: jeden tvar l → m³

var p: Dictionary
var W := 0; var H := 0; var NZ := 0
var cells := PackedByteArray()
var hm := PackedInt32Array()
var st: Dictionary
var q := Heap.new()
var R := PackedFloat64Array(); var A := PackedFloat64Array()
var re := PackedFloat64Array(); var rd := PackedFloat64Array(); var tl := PackedFloat64Array()
var gen := PackedInt32Array(); var vel := PackedFloat64Array(); var mode := PackedByteArray()   # 0 nic, 1 eroze, 2 nános
var now := 0.0
var dep := 0
var cellv := HY.CELL * HY.CELL * HY.CELL
var evlog := []          # [čas, sloupec, "eroze"/"nanos"/"kopani"/"polozeni"]
var stats := {"events": 0, "stale": 0, "ero": 0, "dep": 0, "upd_ms": [], "resched": [], "q_max": 0, "lost_m3": 0.0, "to_pond_m3": 0.0, "c0_m3": 0.0, "kept": 0}
var _pc := {}          # sloupec tůně → [Q l/s, plocha m², sloupců] (platí v jedné dávce přeplánování)

func _init(params: Dictionary, w: int, h: int, nz: int, c: PackedByteArray, wall: PackedByteArray, src: PackedFloat64Array) -> void:
	p = params; W = w; H = h; NZ = nz; cells = c
	var n := W * H
	hm.resize(n)
	var hf := PackedFloat64Array(); hf.resize(n)
	var mats := PackedInt32Array(); mats.resize(n)
	for i in n:
		hm[i] = _top(i); hf[i] = hm[i]; mats[i] = top_mat(i)
	st = TOK.make(hf, W, H, wall, mats, src, TOK.losses(p, true), true)
	TOK.route(st)
	for a in [R, A, re, rd, tl, vel]: a.resize(n)
	gen.resize(n); mode.resize(n)
	dep = HY.id_of(String(p.e51_nanos))
	for i in n: R[i] = float(HY.mat(top_mat(i))[1])
	var all := {}
	for i in n: all[i] = true
	_resched(range(n), all)

func _top(i: int) -> int:
	var h := 0
	for z in NZ:
		if cells[i * NZ + z] != 0: h = z + 1
	return h

func top_mat(i: int) -> int:
	return cells[i * NZ + hm[i] - 1] if hm[i] > 0 else 0

func wet(i: int) -> bool:
	return st.wall[i] == 0 and (st.eff[i] >= float(st.L.thr) or st.pw[i] == 1)

func _advance(i: int) -> void:
	var dt := now - tl[i]
	if dt > 0.0:
		R[i] = maxf(R[i] - re[i] * dt, 0.0); A[i] += rd[i] * dt
	tl[i] = now

## tůň: BFS přes pw (8-sousedé), Q = největší přítok v tůni (jako tok.ponds)
func _pond(i: int) -> Array:
	if _pc.has(i): return _pc[i]
	var comp := [i]; var seen := {i: true}; var k := 0; var qmax := 0.0
	while k < comp.size():
		var c: int = comp[k]; k += 1
		qmax = maxf(qmax, st.ain[c])
		var x := c / H; var y := c % H
		for d in 8:
			var qx: int = x + TOK.DX[d]; var qy: int = y + TOK.DY[d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var j := qx * H + qy
			if st.pw[j] == 1 and not seen.has(j): seen[j] = true; comp.append(j)
	var e := [qmax, comp.size() * HY.CELL * HY.CELL, comp.size(), comp]
	for c in comp: _pc[c] = e
	return e

## rychlost a režim sloupce
func hydraulics(i: int) -> Array:
	if not wet(i): return [0.0, 0]
	var m := HY.mat(top_mat(i))
	if st.pw[i] == 1:
		var e := _pond(i)
		var v := HY.pond_v(float(e[0]) / LI.L_NA_M3, (st.fill[i] - st.hm[i]) * HY.CELL, float(e[1]))
		if v < float(HY.mat(dep)[2]): return [v, 2]
		return [v, 1 if v >= float(m[0]) and hm[i] > 1 else 0]
	var s := _slope(i)
	var v: float = HY.manning(st.eff[i] / LI.L_NA_M3, s, p).v
	return [v, 1 if v >= float(m[0]) and hm[i] > 1 else 0]

## sklon po proudu přes e51_s_len sloupců (výšky jsou celé buňky → jinak by mezi schody byl sklon 0); přes okraj e51_s_edge
func _slope(i: int) -> float:
	var j := i; var dist := 0.0
	for k in int(p.e51_s_len):
		var t: int = st.to[j]
		if t < 0:
			if k == 0: return float(p.e51_s_edge)
			break
		dist += 1.4142 if (t / H != j / H and t % H != j % H) else 1.0
		j = t
	return (st.hm[i] - st.hm[j]) / maxf(dist, 1.0)

## force = sloupce s vynulovaným / změněným odpočtem; ostatní se znovu zařadí, jen když se změnila rychlost odpočtu
func _resched(list, force := {}) -> void:
	_pc = {}
	for i in list:
		_advance(i)
		var hv := hydraulics(i)
		var ore := re[i]; var ord := rd[i]; var om := mode[i]
		vel[i] = hv[0]; mode[i] = hv[1]
		re[i] = 0.0; rd[i] = 0.0
		var dt := INF
		if mode[i] == 1:
			var m := HY.mat(top_mat(i))
			var qm: float = st.eff[i] / LI.L_NA_M3 if st.pw[i] == 0 else float(_pond(i)[0]) / LI.L_NA_M3
			re[i] = qm * pow(vel[i] / float(m[0]), float(p.e51_k))
			if re[i] > 0.0: dt = R[i] / re[i]
		elif mode[i] == 2:
			var e := _pond(i)
			rd[i] = float(p.e51_c0) * float(e[0]) / LI.L_NA_M3 / float(e[2])
			var need := cellv * (1.0 - float(HY.mat(dep)[3]))
			if rd[i] > 0.0: dt = maxf(need - A[i], 0.0) / rd[i]
		if not force.has(i) and om == mode[i] and absf(ore - re[i]) <= 1e-12 * maxf(ore, 1e-30) and absf(ord - rd[i]) <= 1e-12 * maxf(ord, 1e-30):
			stats.kept += 1; continue   # rychlost beze změny → stávající položka ve frontě platí dál
		gen[i] += 1
		if dt < INF: q.push(now + dt, i, gen[i])
	stats.q_max = maxi(stats.q_max, q.size())

## změna výšky sloupců → lokální přepočet toku (E47c) → přeplánovat dotčené
func _changed(ch: Array) -> void:
	var cc := PackedInt32Array(ch); var hv := PackedFloat64Array()
	for i in ch: hv.append(float(hm[i])); st.mats[i] = top_mat(i)
	var u := TOK.update(st, cc, hv, st.src, int(p.e51_margin))
	stats.upd_ms.append(float(u.ms))
	var aff := {}
	for i in ch: aff[i] = true
	for i in u.cells: aff[i] = true
	stats.resched.append(aff.size())
	var force := {}
	for i in ch: force[i] = true
	_resched(aff.keys(), force)

## odnesená pevná hmota → první tůň po proudu (nános), jinak přes okraj do mlhy
func _carry(i: int, vol: float) -> Array:
	var j := i; var guard := 0
	while j >= 0 and st.pw[j] == 0 and guard < W * H:
		j = st.to[j]; guard += 1
	if j < 0: stats.lost_m3 += vol; return []
	_pc = {}
	var e := _pond(j)
	for c in e[3]:
		_advance(c); A[c] += vol / float(e[2])
	stats.to_pond_m3 += vol
	return e[3]

## jedna událost; false = fronta prázdná nebo za t_end
func step(t_end: float) -> bool:
	while q.size() > 0:
		if q.top_time() > t_end: return false
		var e := q.pop()
		var i: int = e[1]
		if int(e[2]) != gen[i]: stats.stale += 1; continue
		now = float(e[0]); stats.events += 1
		_advance(i)
		var ch := [i]
		if mode[i] == 1:
			var m := top_mat(i)
			cells[i * NZ + hm[i] - 1] = 0; hm[i] -= 1
			R[i] = float(HY.mat(top_mat(i))[1]); A[i] = 0.0
			stats.ero += 1; evlog.append([now, i, "eroze", m])
			ch.append_array(_carry(i, cellv * (1.0 - float(HY.mat(m)[3]))))   # tůň s novým nánosem: vynutit nové časy
		elif mode[i] == 2:
			if hm[i] >= NZ: continue
			A[i] = maxf(A[i] - cellv * (1.0 - float(HY.mat(dep)[3])), 0.0)
			cells[i * NZ + hm[i]] = dep; hm[i] += 1
			R[i] = float(HY.mat(dep)[1])
			stats.dep += 1; evlog.append([now, i, "nanos", dep])
		_changed(ch)
		return true
	return false

func run_until(t_end: float, max_events := 1 << 30) -> int:
	var k := 0
	while k < max_events and step(t_end): k += 1
	if t_end < INF: now = maxf(now, t_end)   # čas běží dál i bez událostí
	return k

## hráč: vykopat vrchní buňku / položit materiál (odpočet sloupce se vynuluje)
func dig(i: int, t: float) -> void:
	now = t; _advance(i)
	cells[i * NZ + hm[i] - 1] = 0; hm[i] -= 1
	R[i] = float(HY.mat(top_mat(i))[1]); A[i] = 0.0
	evlog.append([now, i, "kopani", 0]); _changed([i])

func place(i: int, m: int, t: float) -> void:
	now = t; _advance(i)
	cells[i * NZ + hm[i]] = m; hm[i] += 1
	R[i] = float(HY.mat(m)[1]); A[i] = 0.0
	evlog.append([now, i, "polozeni", m]); _changed([i])

func live() -> int:
	var k := 0
	for i in W * H:
		if mode[i] != 0 and (re[i] > 0.0 or rd[i] > 0.0): k += 1
	return k

## čas příští platné události sloupce (pro testy), INF = žádná
func due(i: int) -> float:
	if re[i] > 0.0: return tl[i] + R[i] / re[i]
	if rd[i] > 0.0: return tl[i] + maxf(cellv * (1.0 - float(HY.mat(dep)[3])) - A[i], 0.0) / rd[i]
	return INF
