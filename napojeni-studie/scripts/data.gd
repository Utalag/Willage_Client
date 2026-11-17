extends RefCounted
## Data studie: 2 × 2 vzorky (zmenšené bloky) po sample_n × sample_n buňkách, výška v celých vrstvách.
##   SZ = louka, SV = píščina (písek s ostrůvky trávy), JZ = voda (s písečným ostrůvkem), JV = pobřeží (voda → písek → louka uvnitř vzorku).
## Materiál je jeden na buňku (GRASS / SAND / WATER = písčité dno pod hladinou). Vzorky se vkládají postupně
## a každý nový dorovná výšky svých stran k už vloženým sousedům stejně jako block_gen.gd (auto | blend1–4 | keep).
## Souřadnice x, z jsou v buňkách (svět = × cell_xy), výšky v metrech.

const Par = preload("res://scripts/params.gd")
enum { GRASS, SAND, WATER }
const PRIO := [2, 1, 0]          # přístup 1: „silnější“ materiál přesahuje do slabšího souseda (tráva > písek > dno)
const KINDS := [["louka", "pisek"], ["voda", "pobrezi"]]   # [řádek z][sloupec x]
## layout 1 (Jan 14:34): louka přímo u vody, bez písku. SZ nízká louka (plochý břeh, 0,15 m nad hladinou),
## SV vyšší louka (vlevo o 1 vrstvu, vpravo o 2 vrstvy nad nízkou), JZ voda s travnatým jazykem, JV voda s jednobuněčným ostrůvkem
const KINDS_LV := [["louka_nizka", "louka_vysoka"], ["voda_jazyk", "voda_ostruvek"]]
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # S, V, J, Z

var n: int
var N: int
var cxy: float
var cz: float
var wl: float
var mat := PackedByteArray()
var hl := PackedInt32Array()     # výška sloupce ve vrstvách (povrch = hl × cell_z)
var placed := []                 # [sx, sz] v pořadí vkládání
var gen_ms := 0.0

func _init() -> void:
	n = Par.i("sample_n")
	N = n * 2
	cxy = Par.g("cell_xy")
	cz = Par.g("cell_z")
	wl = Par.g("water_level")
	mat.resize(N * N)
	hl.resize(N * N)
	var t0 := Time.get_ticks_usec()
	for p in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		_place(p[0], p[1])
	gen_ms = (Time.get_ticks_usec() - t0) / 1000.0

func idx(x: int, z: int) -> int:
	return clampi(z, 0, N - 1) * N + clampi(x, 0, N - 1)

func inside(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < N and z < N

func m_at(x: int, z: int) -> int:
	return mat[idx(x, z)]

func h_at(x: int, z: int) -> float:
	return hl[idx(x, z)] * cz

static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.seed = seed
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.frequency = freq
	f.fractal_octaves = 3
	return f

## vrstvy: souš vždy nad hladinou, dno vody vždy pod ní
func _land_min() -> int:
	return int(floor(wl / cz)) + 1

func _water_max() -> int:
	return maxi(int(ceil(wl / cz)) - 1, 1)

func _place(sx: int, sz: int) -> void:
	var kind: String = (KINDS_LV if Par.i("layout") == 1 else KINDS)[sz][sx]
	var s := Par.i("seed")
	var n1 := _noise(s + 1, 0.22)
	var n2 := _noise(s + 2, 0.35)
	var lm := PackedByteArray(); lm.resize(n * n)
	var lh := PackedInt32Array(); lh.resize(n * n)
	for lz in n:
		for lx in n:
			# šum ve fyzických souřadnicích → stejný tvar při jiném rozlišení
			var wx := (sx * n + lx + 0.5) * cxy
			var wz := (sz * n + lz + 0.5) * cxy
			var m := GRASS
			var h := Par.g("meadow_h") + Par.g("meadow_var") * n1.get_noise_2d(wx, wz)
			match kind:
				"pisek":
					m = SAND
					h = Par.g("sand_h") + Par.g("sand_var") * n1.get_noise_2d(wx, wz)
					if n2.get_noise_2d(wx, wz) > 0.32:
						m = GRASS   # ostrůvky trávy v písku (přechod uvnitř vzorku)
						h += cz
				"voda":
					var c := Vector2(n * 0.5, n * 0.5) * cxy
					var d := Vector2(lx + 0.5, lz + 0.5).distance_to(Vector2(n * 0.62, n * 0.58)) * cxy + 0.6 * n2.get_noise_2d(wx, wz)
					if d < 0.75 * cxy:
						m = GRASS; h = Par.g("meadow_h") - cz   # jednobuněčný travnatý vršek ostrůvku
					elif d < 2.3 * cxy:
						m = SAND; h = Par.g("sand_h")
					else:
						m = WATER; h = Par.g("bed_h")
				"louka_nizka":
					h = _land_min() * cz
				"louka_vysoka":
					h = (_land_min() + (1 if lx < n / 2 else 2)) * cz
				"voda_jazyk":
					m = WATER; h = Par.g("bed_h")
					if lx >= 3 and lx <= 5 + int(n2.get_noise_2d(wx, wz) > 0.2) and lz < 5:
						m = GRASS; h = _land_min() * cz
				"voda_ostruvek":
					m = WATER; h = Par.g("bed_h")
					if lx == n / 2 and lz == n / 2:
						m = GRASS; h = _land_min() * cz
				"pobrezi":
					# po úhlopříčce od SZ rohu: voda → písek → louka
					var t := float(lx + lz) / float(n) + 0.35 * n2.get_noise_2d(wx, wz)
					if t < 0.62:
						m = WATER; h = Par.g("bed_h")
					elif t < 1.12:
						m = SAND; h = Par.g("sand_h") + 0.15 * n1.get_noise_2d(wx, wz)
					else:
						m = GRASS
			lm[lz * n + lx] = m
			lh[lz * n + lx] = clampi(int(round(h / cz)), 1, Par.i("layers"))
	# dorovnání stran k už vloženým sousedům (logika block_gen.gd: mění se jen nový vzorek)
	var mode := Par.i("side_mode")
	for si in 4:
		var d: Vector2i = DIRS[si]
		var nb := [sx + d.x, sz + d.y]
		if not (nb in placed) or mode == 5:
			continue
		for t in n:
			var ex := t if d.x == 0 else (n - 1 if d.x > 0 else 0)
			var ey := t if d.y == 0 else (n - 1 if d.y > 0 else 0)
			var gx := sx * n + ex + d.x
			var gz := sz * n + ey + d.y
			var diff: int = hl[gz * N + gx] - lh[ey * n + ex]
			var cells_n := mode
			if mode == 0:
				if absi(diff) > Par.i("blend_max"):
					continue
				cells_n = Par.i("auto_cells")
			for dd in cells_n:
				var lx := ex - d.x * dd
				var ly := ey - d.y * dd
				var w := float(cells_n - dd) / float(cells_n)
				lh[ly * n + lx] = clampi(int(round(lh[ly * n + lx] + diff * w)), 1, Par.i("layers"))
	for lz in n:
		for lx in n:
			var k := lz * n + lx
			# voda a souš mají pevné meze (dorovnání nesmí zaplavit trávu ani vysušit dno)
			lh[k] = mini(lh[k], _water_max()) if lm[k] == WATER else maxi(lh[k], _land_min())
			mat[(sz * n + lz) * N + sx * n + lx] = lm[k]
			hl[(sz * n + lz) * N + sx * n + lx] = lh[k]
	placed.append([sx, sz])

# ------------------------------------------------------------------ výšky povrchu (metry)
## přístup 1: výška buňky (schody)
func height_grid(x: float, z: float) -> float:
	return h_at(int(floor(x)), int(floor(z)))

## přístup 2: duální mřížka – výšky jsou ve středech buněk (= rozích dlaždic), mezi nimi interpolace
func height_dual(x: float, z: float) -> float:
	var gx := x - 0.5
	var gz := z - 0.5
	var i0 := int(floor(gx)); var j0 := int(floor(gz))
	var fx := _ease(gx - i0); var fz := _ease(gz - j0)
	var a := h_at(i0, j0); var b := h_at(i0 + 1, j0)
	var c := h_at(i0, j0 + 1); var d := h_at(i0 + 1, j0 + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)

func _ease(t: float) -> float:
	var e := Par.g("dual_ease")
	return lerpf(t, t * t * (3.0 - 2.0 * t), e)
