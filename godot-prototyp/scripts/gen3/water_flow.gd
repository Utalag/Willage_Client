extends RefCounted
## Tok vody po kopání (Jan 20:39): UDÁLOSTNÍ a MÍSTNÍ simulace voda-studie (voda_sim.gd) jen v okolí vykopané buňky, běží do ustálení.
## - Spustí se, když kopání sáhne na pohyblivou vodu: vykopaná buňka nebo její 6 sousedů má vodu nad zadržením (ret) nebo volnou vodu.
## - Výřez (box): BFS z vykopané buňky přes vzduch jeskyní a prohlubní (jáma: pod povrchem sousedního sloupce) a buňky s pohyblivou vodou, nejvýš RXY sloupců a RZ vrstev,
##   + okraj MARGIN; nahoře až po nejvyšší povrch ve výřezu + 1 (jáma, šachta). Okraje výřezu i bloku jsou zavřené (tok mezi bloky zatím ne).
## - Ustálení: největší změna vody v buňce za tik < CALM_EPS po CALM_TICKS tiků za sebou (nebo MAX_TICKS).
## - Zápis zpět do Block.water v celých jednotkách 1/4096 se ZACHOVÁNÍM součtu (zbytky po zaokrouhlení podle největší desetinné části,
##   při shodě nižší index). Během běhu (ve hře po snímcích) se zapisuje jen náhled pro vykreslení; konečný stav nezávisí na dělení do snímků.
## - Kontrola jako delta (validate): součet vody v bloku = před tokem (vykopaná voda se počítá zvlášť), mimo výřez beze změny,
##   voda jen ve vzduchu a propustných buňkách do kapacity, a stav je ustálený (dalších VERIFY_TICKS tiků nic nepohne).

const Mat = preload("res://scripts/mat.gd")
const G = preload("res://scripts/gen3/gen_v3.gd")
const VSim = preload("res://scripts/gen3/voda_sim.gd")
const VM = preload("res://scripts/gen3/voda_mat.gd")
const WT = preload("res://scripts/gen3/water_table.gd")
const BS := 16
const BH := 64
const FULL := 4096
const RXY := 7
const RZ := 16
const MARGIN := 2
const CALM_EPS := 5e-5        # 0,2 jednotky 1/4096 za tik
const CALM_TICKS := 5
const MAX_TICKS := 1500
const VERIFY_TICKS := 30
const VERIFY_EPS := 0.015     # za VERIFY_TICKS tiků nejvýš půl tloušťky filmu (film 0,03): zbytky zaokrouhlení a kapky filmu nejsou tok

## parametry simulace: výchozí hodnoty voda-studie (params.gd), materiály ze sdílené tabulky, bez odparu a bez odtoku ze stran
static var _P := {}
static func params() -> Dictionary:
	if _P.is_empty():
		_P = {"cell_xy": 1.0, "cell_z": 0.5, "evap": 0.0, "evap_soil": 0.0, "edge_drain": 0,
			"flow_air": 1.0, "flow_ground": 1.0, "infil": 0.10, "perm_scale": 1.0, "film": 0.03,
			"walk_slow_m": 0.05, "walk_deep_m": 0.30, "walk_mud_s": 0.95}
		var d := WT.load_shared_table()
		for k in d.get("materials", {}):
			var m: Dictionary = d.materials[k]
			_P["perm_" + k] = float(m.perm); _P["por_" + k] = float(m.por); _P["res_" + k] = float(m.res)
			_P["ret_" + k] = float(m.get("ret", 0.0))
		_P["perm_leak"] = float(d.get("perm_leak", 0.05))
	return _P

static func sim_mat(m: int) -> int:
	match m:
		Mat.COPPER, Mat.IRON, Mat.FOG, Mat.SNOW: return VM.GRANITE   # nepropustné (sníh má ve sdílené tabulce perm 0)
		Mat.CLAY_DEPOSIT: return VM.CLAY
	return m

## pohyblivá voda v buňce (nad zadržením) nebo volná voda ve vzduchu
static func _mobile(b, c: int) -> bool:
	var w: int = b.water[c]
	if w <= 0:
		return false
	return b.cells[c] == Mat.AIR or w > G.ret_cell(b.cells, c) + 1

class Flow:
	var b
	var ox: int; var oy: int; var oz: int
	var nx: int; var ny: int; var nz: int
	var sim
	var before: PackedInt32Array       # Block.water před tokem (po vykopání buňky)
	var target := 0                    # součet jednotek ve výřezu (zachovává se)
	var ticks := 0
	var calm := 0
	var done := false
	var ms := 0.0
	var _prev: PackedFloat32Array

	func box_cells() -> int:
		return nx * ny * nz

	func cidx(x: int, y: int, z: int) -> int:
		return ((ox + x) * BS + (oy + y)) * BH + (oz + z)

	## n tiků (nebo do ustálení); true = ustáleno / limit
	func step_n(n: int) -> bool:
		var t0 := Time.get_ticks_usec()
		for k in n:
			if done:
				break
			sim.step()
			ticks += 1
			var mx := 0.0
			for i in sim.w.size():
				mx = maxf(mx, absf(sim.w[i] - _prev[i]))
			_prev = sim.w.duplicate()
			calm = calm + 1 if mx < CALM_EPS else 0
			if calm >= CALM_TICKS or ticks >= MAX_TICKS:
				done = true
		ms += (Time.get_ticks_usec() - t0) / 1000.0
		return done

	## náhled pro vykreslení během toku (bez zachování součtu; konečný stav zapíše finish)
	func write_preview() -> void:
		for z in nz:
			for y in ny:
				for x in nx:
					b.water[cidx(x, y, z)] = int(round(sim.w[x + y * nx + z * nx * ny] * FULL))

	## konečný zápis se zachováním součtu jednotek ve výřezu
	func finish() -> void:
		while not done:
			step_n(64)
		var n := box_cells()
		var u := PackedInt32Array(); u.resize(n)
		var fr := PackedFloat32Array(); fr.resize(n)
		var capu := PackedInt32Array(); capu.resize(n)
		var s := 0
		for z in nz:
			for y in ny:
				for x in nx:
					var i := x + y * nx + z * nx * ny
					var v := maxf(sim.w[i], 0.0) * FULL
					var c := cidx(x, y, z)
					capu[i] = FULL if b.cells[c] == Mat.AIR else G.capu(b.cells[c])
					u[i] = mini(int(floor(v)), capu[i])
					fr[i] = v - u[i]
					s += u[i]
		var diff := target - s
		if diff != 0:
			var order := range(n)
			if diff > 0:
				order.sort_custom(func(a, c): return fr[a] > fr[c] or (fr[a] == fr[c] and a < c))
			else:
				order.sort_custom(func(a, c): return u[a] > u[c] or (u[a] == u[c] and a < c))
			var guard := 0
			while diff != 0 and guard < 4:
				for i in order:
					if diff > 0 and u[i] < capu[i] and (fr[i] > 0.0 or guard > 0):
						u[i] += 1; diff -= 1
					elif diff < 0 and u[i] > 0:
						u[i] -= 1; diff += 1
					if diff == 0:
						break
				guard += 1
		for z in nz:
			for y in ny:
				for x in nx:
					b.water[cidx(x, y, z)] = u[x + y * nx + z * nx * ny]

	## seznam změn vody [index buňky, staré, nové] (delta bloku)
	func changes() -> Array:
		var out := []
		for z in nz:
			for y in ny:
				for x in nx:
					var c := cidx(x, y, z)
					if b.water[c] != before[c]:
						out.append([c, before[c], b.water[c]])
		return out

	func box() -> Array:
		return [ox, oy, oz, nx, ny, nz]

## vzduch v jeskyni nebo v prohlubni (jáma, šachta): pod povrchem svého sloupce nebo některého z 8 sousedních
static func _hollow(b, x: int, y: int, z: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var qx := x + dx; var qy := y + dy
			if qx >= 0 and qy >= 0 and qx < BS and qy < BS and z < b.hm[qx * BS + qy]:
				return true
	return false

## začne tok po vykopání buňky (lx, ly, lz); null = není co téct (žádná pohyblivá voda u buňky)
static func start(b, lx: int, ly: int, lz: int) -> Flow:
	if b.water.size() != b.cells.size():
		return null
	var c0 := (lx * BS + ly) * BH + lz
	var any := _mobile(b, c0)
	var D6 := [BH * BS, -BH * BS, BH, -BH, 1, -1]
	for k in 6:
		var n: int = c0 + D6[k]
		if n >= 0 and n < b.cells.size() and absi((n / BH) / BS - lx) <= 1 and absi((n / BH) % BS - ly) <= 1 and _mobile(b, n):
			any = true
	if not any:
		return null
	# BFS přes vzduch pod povrchem a pohyblivou vodu
	var seen := {c0: true}
	var q := [c0]
	var x0 := lx; var x1 := lx; var y0 := ly; var y1 := ly; var z0 := lz; var z1 := lz
	var i := 0
	while i < q.size():
		var c: int = q[i]; i += 1
		var x := c / (BS * BH); var y := (c / BH) % BS; var z := c % BH
		x0 = mini(x0, x); x1 = maxi(x1, x); y0 = mini(y0, y); y1 = maxi(y1, y); z0 = mini(z0, z); z1 = maxi(z1, z)
		for k in 6:
			var nx: int = x + [1, -1, 0, 0, 0, 0][k]
			var ny: int = y + [0, 0, 1, -1, 0, 0][k]
			var nz: int = z + [0, 0, 0, 0, 1, -1][k]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			if absi(nx - lx) > RXY or absi(ny - ly) > RXY or absi(nz - lz) > RZ:
				continue
			var n := (nx * BS + ny) * BH + nz
			if seen.has(n):
				continue
			if (b.cells[n] == Mat.AIR and _hollow(b, nx, ny, nz)) or _mobile(b, n):
				seen[n] = true
				q.append(n)
	x0 = maxi(x0 - MARGIN, 0); y0 = maxi(y0 - MARGIN, 0); z0 = maxi(z0 - MARGIN, 0)
	x1 = mini(x1 + MARGIN, BS - 1); y1 = mini(y1 + MARGIN, BS - 1)
	var top := z1 + MARGIN
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			top = maxi(top, b.hm[x * BS + y] + 1)
	z1 = mini(top, BH - 1)
	var f := Flow.new()
	f.b = b
	f.ox = x0; f.oy = y0; f.oz = z0
	f.nx = x1 - x0 + 1; f.ny = y1 - y0 + 1; f.nz = z1 - z0 + 1
	f.before = b.water.duplicate()
	var P := params()
	var s = VSim.new(f.nx, f.ny, f.nz, P)
	s.open_sides = 0
	var leak := float(P.perm_leak)
	var tot := 0
	for z in f.nz:
		for y in f.ny:
			for x in f.nx:
				var c := f.cidx(x, y, z)
				var si: int = x + y * f.nx + z * f.nx * f.ny
				s.mat[si] = sim_mat(b.cells[c])
				s.w[si] = float(b.water[c]) / FULL
				tot += b.water[c]
	s.reset_props()
	for si in s.mat.size():
		if s.mat[si] != VM.AIR and s.kp[si] <= leak:
			s.cap[si] = 0.0; s.ret[si] = 0.0     # nepropustné buňky vodu nepojmou (jako gen-v3: kapacita jen když perm > perm_leak)
	f.sim = s
	f.target = tot
	f._prev = s.w.duplicate()
	return f

## kontrola toku jako delta: before = voda před tokem (po vykopání), removed = jednotky vykopané s buňkou (jen do zprávy)
static func validate(f: Flow) -> Dictionary:
	var b = f.b
	var errs := []
	var s0 := 0; var s1 := 0
	for c in b.water.size():
		s0 += f.before[c]; s1 += b.water[c]
	if s0 != s1:
		errs.append({"code": "world.water_delta_not_conserved", "before": s0, "after": s1})
	var inside := {}
	for z in f.nz:
		for y in f.ny:
			for x in f.nx:
				inside[f.cidx(x, y, z)] = true
	var moved := 0
	for c in b.water.size():
		var w: int = b.water[c]
		if w != f.before[c]:
			moved += absi(w - f.before[c])
			if not inside.has(c):
				errs.append({"code": "world.water_delta_outside_box", "cell": c}); break
		if w < 0:
			errs.append({"code": "world.water_negative", "cell": c}); break
		var cap: int = FULL if b.cells[c] == Mat.AIR else G.capu(b.cells[c])
		if w > cap:
			errs.append({"code": "world.water_over_capacity", "cell": c, "water": w, "cap": cap}); break
	# ustálení: dalších VERIFY_TICKS tiků z konečného (celočíselného) stavu nic znatelně nepohne
	var g := start_box(b, f.box())
	var w0: PackedFloat32Array = g.sim.w.duplicate()
	for k in VERIFY_TICKS:
		g.sim.step()
	var mx := 0.0
	for i in w0.size():
		mx = maxf(mx, absf(g.sim.w[i] - w0[i]))
	if mx > VERIFY_EPS:
		errs.append({"code": "world.water_unstable_after_flow", "max_delta": mx})
	return {"ok": errs.is_empty(), "errors": errs.slice(0, 5), "moved_units": moved / 2, "verify_max_delta": mx}

## simulace na daném výřezu bez spouštěcí podmínky (pro kontrolu ustálení)
static func start_box(b, bx: Array) -> Flow:
	var f := Flow.new()
	f.b = b
	f.ox = bx[0]; f.oy = bx[1]; f.oz = bx[2]; f.nx = bx[3]; f.ny = bx[4]; f.nz = bx[5]
	f.before = b.water
	var P := params()
	var s = VSim.new(f.nx, f.ny, f.nz, P)
	s.open_sides = 0
	for z in f.nz:
		for y in f.ny:
			for x in f.nx:
				var si: int = x + y * f.nx + z * f.nx * f.ny
				s.mat[si] = sim_mat(b.cells[f.cidx(x, y, z)])
				s.w[si] = float(b.water[f.cidx(x, y, z)]) / FULL
	s.reset_props()
	var leak := float(P.perm_leak)
	for si in s.mat.size():
		if s.mat[si] != VM.AIR and s.kp[si] <= leak:
			s.cap[si] = 0.0; s.ret[si] = 0.0
	f.sim = s
	f._prev = s.w.duplicate()
	return f
