extends RefCounted
## KOPIE z blueprint-studie/scripts/kopie/voda_sim.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## KOPIE z voda-studie/scripts/water_sim.gd (od 19:19 se zadrženou vodou ret_*), jen cesta k materiálům – kontrola stability gen-v3.
## Buněčná simulace vody na mřížce buněk (studie pro Willage). ČISTÁ DATA, žádné vykreslování,
## žádná náhoda, pevné pořadí kroků => deterministická a přenositelná na backend (server tiky).
##
## Každá buňka nese materiál (mat) a objem vody (w, v jednotkách „plná buňka“):
##   vzduch pojme 1,0 (volná voda = rybník, potok), pevný materiál pojme svou pórovitost (voda v zemi).
## Jeden tik:
##   1 zdroje (déšť, entity zdrojů: top_flow / hillside_spring / underground_pocket)
##   2 svislý pád a vsakování shora dolů (vzduch padá celý, do země podle propustnosti) [4][9][14]
##   3 rozlévání do stran z kopie stavu (Jacobi – nezávisí na pořadí buněk): volná voda podle rozdílu hladin
##      a odporu povrchu pod ní, voda v zemi podle rozdílu nasycení × propustnost (zjednodušený Darcy) [4][5]
##      otevřené strany vzorku = odtok mimo mapu
##   4 přetlak: co přeteče kapacitu, jde o buňku výš (stoupání hladiny, vyvěrání) [2][4]
##   5 odpar z volné hladiny a z mokrého povrchu
## Vsakování: volná voda nad propustnou buňkou proteče nejvýš propustnost × infil za tik (infil = vsak plně propustné buňky).
## Bilance: in_tick / out_tick / evap_tick a chyba bilance (total − předchozí − in + out + evap).

const M = preload("res://scripts/teren/zaklad/voda_mat.gd")
const EPS := 1e-5

var NX: int
var NY: int
var NZ: int
var A: int                       # buněk ve vrstvě
var P: Dictionary
var mat: PackedByteArray
var w: PackedFloat32Array
var cap: PackedFloat32Array
var kp: PackedFloat32Array
var res: PackedFloat32Array
var ret: PackedFloat32Array          # zadržená (nepohyblivá) voda v pórech, ret_* ze sdílené tabulky (Jan 19:19)
var open_sides := 0              # 1 = -x (západ), 2 = +x (východ), 4 = -y (sever), 8 = +y (jih)
var rain := 0.0
var rain_ticks := -1
var sources := []                # entity zdrojů (slovníky), viz add_source
var tick := 0
# bilance
var in_tick := 0.0
var out_tick := 0.0
var evap_tick := 0.0
var in_total := 0.0
var out_total := 0.0
var evap_total := 0.0
var initial := 0.0
var bal_err_max := 0.0
var out_by_x: PackedFloat32Array        # odtok podle sloupce x (povrch + země), pro srovnání ve scénáři 2
var out_surf_by_x: PackedFloat32Array
var first_out_by_x: PackedInt32Array
var first_surf_by_x: PackedInt32Array   # první tik povrchového odtoku (volná voda) ve sloupci x
var _d: PackedFloat32Array
var flux: PackedFloat32Array           # objem, který buňka za poslední tik poslala do stran (pro „peřeje“ ve vykreslení)

func _init(nx: int, ny: int, nz: int, params: Dictionary) -> void:
	NX = nx; NY = ny; NZ = nz; A = nx * ny; P = params
	var n := A * nz
	mat.resize(n); w.resize(n); flux.resize(n); cap.resize(n); kp.resize(n); res.resize(n); ret.resize(n); _d.resize(n)
	out_by_x.resize(nx); out_surf_by_x.resize(nx); first_out_by_x.resize(nx); first_out_by_x.fill(-1); first_surf_by_x.resize(nx); first_surf_by_x.fill(-1)
	for i in n:
		_props(i)

func idx(x: int, y: int, z: int) -> int:
	return x + y * NX + z * A

func _props(i: int) -> void:
	var p: Vector3 = M.props(mat[i], P)
	kp[i] = p.x; cap[i] = p.y; res[i] = p.z
	ret[i] = 0.0 if mat[i] == M.AIR else minf(float(P.get("ret_" + M.KEYS[mat[i]], 0.0)), cap[i])

func set_mat(x: int, y: int, z: int, m: int) -> void:
	var i := idx(x, y, z)
	mat[i] = m
	_props(i)

## kopání: buňka se změní na vzduch, voda v jejích pórech zůstane jako volná voda; okolní voda do ní nateče
func dig(x: int, y: int, z: int) -> void:
	set_mat(x, y, z, M.AIR)

func reset_props() -> void:
	for i in mat.size():
		_props(i)

## ---------- entity zdrojů (Jan 15:51) ----------
## top_flow:          přítok shora / z bloku proti proudu do volné buňky nad povrchem v (x, y)
## hillside_spring:   pramen ve svahu: voda vyvěrá ze stěny buňky (x, y, z) do sousední volné buňky ve směru dir
## underground_pocket: zavřená kapsa vzduchových buněk plná vody; dotéká do ní recharge, jen dokud není plná
##                    (kapsa „pod tlakem“). Po prokopání se voda přes přetlak dere nahoru do šachty.
func add_source(s: Dictionary) -> void:
	if s.type == "underground_pocket":
		for c in s.cells:
			var i: int = idx(c.x, c.y, c.z)
			mat[i] = M.AIR; _props(i)
			w[i] = 1.0
			initial += 1.0
	sources.append(s)

## kapsa je otevřená, když sousedí se vzduchovou buňkou, která do ní nepatří (prokopáno)
func _pocket_open(s: Dictionary) -> bool:
	for c in s.cells:
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1)]:
			var n: Vector3i = c + d
			if n.x < 0 or n.y < 0 or n.z < 0 or n.x >= NX or n.y >= NY or n.z >= NZ:
				continue
			if mat[idx(n.x, n.y, n.z)] == M.AIR and not s.cells.has(n):
				return true
	return false

func total() -> float:
	var t := 0.0
	for v in w:
		t += v
	return t

func free_water() -> float:
	var t := 0.0
	for i in w.size():
		if mat[i] == M.AIR:
			t += w[i]
	return t

func _add(i: int, v: float) -> void:
	w[i] += v
	in_tick += v

## nejvyšší pevná buňka sloupce (-1 = sloupec je celý vzduch)
func surface_z(x: int, y: int) -> int:
	for z in range(NZ - 1, -1, -1):
		if mat[idx(x, y, z)] != M.AIR:
			return z
	return -1

func step() -> void:
	in_tick = 0.0; out_tick = 0.0; evap_tick = 0.0
	var before := total()
	# 1 zdroje ------------------------------------------------------------------
	if rain > 0.0 and (rain_ticks < 0 or tick < rain_ticks):
		for c in A:
			var top := c + (NZ - 1) * A
			if cap[top] > 0.0:
				_add(top, rain)
	for s in sources:
		match s.type:
			"top_flow":
				var z := surface_z(s.x, s.y) + 1
				if z < NZ:
					_add(idx(s.x, s.y, z), s.rate)
			"hillside_spring":
				var t := idx(s.x + s.dir.x, s.y + s.dir.y, s.z)
				if mat[t] == M.AIR:
					_add(t, s.rate)
			"underground_pocket":
				var n: int = s.cells.size()
				if _pocket_open(s):
					# prokopaná kapsa: dotok běží dál, přetlak (krok 4) ho vytlačí nahoru šachtou
					for c in s.cells:
						_add(idx(c.x, c.y, c.z), s.rate / n)
				else:
					var room := 0.0
					for c in s.cells:
						var i: int = idx(c.x, c.y, c.z)
						room += maxf(cap[i] - w[i], 0.0)
					var add := minf(s.rate, room)
					if add > EPS:
						for c in s.cells:
							var i: int = idx(c.x, c.y, c.z)
							_add(i, add * maxf(cap[i] - w[i], 0.0) / room)
	# 2 svislý pád a vsakování (shora dolů, voda propadne za tik i přes víc buněk) -----------
	var infil := float(P["infil"])
	for c in A:
		for z in range(NZ - 1, 0, -1):
			var i := c + z * A
			var mob := w[i] - ret[i]         # zadržená voda (ret) nepadá
			if mob <= EPS:
				continue
			var j := i - A
			var k := minf(kp[i], kp[j])
			if k <= 0.0:
				continue
			var room := cap[j] - w[j]
			if room <= EPS:
				continue
			var amt := minf(mob, room)
			if mat[i] != M.AIR or mat[j] != M.AIR:
				amt = minf(amt, k * infil)   # vsakování / prosak: nejvýš propustnost × infil za tik
			w[i] -= amt
			w[j] += amt
	# 3 do stran (Jacobi z kopie: nezávisí na pořadí) ---------------------------------
	_d.fill(0.0)
	flux.fill(0.0)
	var fa := float(P["flow_air"])
	var fg := float(P["flow_ground"])
	var film := float(P["film"])
	var drain := int(P["edge_drain"]) == 1
	var DX := [-1, 1, 0, 0]
	var DY := [0, 0, -1, 1]
	var SIDE := [1, 2, 4, 8]
	var amts := [0.0, 0.0, 0.0, 0.0]
	var tgt := [0, 0, 0, 0]
	for i in w.size():
		var wi := w[i]
		var avail := wi - ret[i]             # do stran teče jen pohyblivá voda nad ret
		if avail <= EPS or cap[i] <= 0.0:
			continue
		var air := mat[i] == M.AIR
		var z := i / A
		var x := i % NX
		var y := (i / NX) % NY
		var floor_res := 0.0
		if air:
			if wi < film:
				continue
			if z > 0:
				var b := i - A
				if mat[b] == M.AIR and w[b] < 0.999:
					continue          # voda právě padá, do stran neteče
				floor_res = 0.0 if mat[b] == M.AIR else res[b]
		var si := wi / cap[i]
		var tot := 0.0
		for d in 4:
			amts[d] = 0.0
			var nx: int = x + DX[d]
			var ny: int = y + DY[d]
			if nx < 0 or ny < 0 or nx >= NX or ny >= NY:
				if drain and (open_sides & SIDE[d]) != 0:
					var c0 := fa * (1.0 - floor_res) if air else fg * kp[i]
					amts[d] = c0 * si * cap[i] * 0.2     # okraj = prázdný soused stejného druhu
					tgt[d] = -1
					tot += amts[d]
				continue
			var j := nx + ny * NX + z * A
			if cap[j] <= 0.0:
				continue
			var sj := w[j] / cap[j]
			if sj >= si:
				continue
			var c := 0.0
			if air and mat[j] == M.AIR:
				c = fa * (1.0 - floor_res)
			else:
				c = fg * minf(kp[i], kp[j])
			amts[d] = c * (si - sj) * cap[i] * cap[j] / (cap[i] + cap[j]) * 0.4
			tgt[d] = j
			tot += amts[d]
		if tot <= EPS:
			continue
		var sc := 1.0 if tot <= avail else avail / tot
		for d in 4:
			if amts[d] <= 0.0:
				continue
			var a: float = amts[d] * sc
			_d[i] -= a
			flux[i] += a
			if tgt[d] < 0:
				out_tick += a
				out_by_x[x] += a
				if air:
					out_surf_by_x[x] += a
					if first_surf_by_x[x] < 0:
						first_surf_by_x[x] = tick
				if first_out_by_x[x] < 0:
					first_out_by_x[x] = tick
			else:
				_d[tgt[d]] += a
	for i in w.size():
		w[i] += _d[i]
	# 4 přetlak: přebytek nad kapacitu jde o buňku výš ---------------------------------
	for c in A:
		for z in NZ - 1:
			var i := c + z * A
			var ex := w[i] - cap[i]
			if ex > EPS and cap[i + A] > 0.0:
				w[i] -= ex
				w[i + A] += ex
	# 5 odpar --------------------------------------------------------------------
	var ev := float(P["evap"])
	var evs := float(P["evap_soil"])
	for c in A:
		for z in range(NZ - 1, -1, -1):
			var i := c + z * A
			if mat[i] == M.AIR:
				if w[i] > EPS:
					var e := minf(w[i], ev)
					w[i] -= e; evap_tick += e
					break
				continue
			if w[i] > EPS:
				var e2 := minf(w[i], evs)
				w[i] -= e2; evap_tick += e2
			break
	in_total += in_tick; out_total += out_tick; evap_total += evap_tick
	var err := absf(total() - before - in_tick + out_tick + evap_tick)
	bal_err_max = maxf(bal_err_max, err)
	tick += 1

## ---------- průchodnost (pro hledání cest a kopání na backendu) ----------
## vrací [stav 0 průchozí / 1 pomalé / 2 neprůchozí, hloubka vody v m, z povrchu]
func walk(x: int, y: int) -> Array:
	var zs := surface_z(x, y)
	var depth := 0.0
	for z in range(zs + 1, NZ):
		var i := idx(x, y, z)
		if w[i] <= EPS:
			break
		depth += w[i]
	depth *= float(P["cell_z"])
	var st := 0
	if depth >= float(P["walk_deep_m"]):
		st = 2
	elif depth >= float(P["walk_slow_m"]):
		st = 1
	elif zs >= 0 and cap[idx(x, y, zs)] > 0.0 and w[idx(x, y, zs)] / cap[idx(x, y, zs)] >= float(P["walk_mud_s"]):
		st = 1
	return [st, depth, zs]

func checksum() -> int:
	return hash(w.to_byte_array())

func active_cells() -> int:
	var n := 0
	for v in w:
		if v > EPS:
			n += 1
	return n
