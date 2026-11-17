extends RefCounted
## Vzorek skály: voxelová mřížka nx × nz × ny buněk (vápenec / žula), deterministicky ze seedu.
## Index buňky (x * nz + z) * ny + y – stejně jako mesher prototypu (x, z vodorovně, y výška).
## Tvar: výchoz/útes – zadní část vysoká, ke středu stupně dolů, souvislá spodní vrstva, výklenky;
## vpředu osamocené kameny (1 buňka) a shluky 2–6 buněk.

const Mat = preload("res://scripts/mat.gd")

var nx := 10
var nz := 10
var ny := 4
var cells := PackedByteArray()

static func _noise(seed: int, freq: float, oct := 2) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = oct
	return n

func idx(x: int, z: int, y: int) -> int:
	return (x * nz + z) * ny + y

## vzduch mimo mřížku; pod mřížkou (y < 0) je podloží jen pod sloupci, které mají plnou spodní buňku
## (kámen „sedí“ v zemi, ale prázdná místa nemají skalní podlahu)
func solid(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= nx or z >= nz or y >= ny:
		return false
	if y < 0:
		return cells[idx(x, z, 0)] != 0
	return cells[idx(x, z, y)] != 0

func mat_at(x: int, y: int, z: int) -> int:
	if x < 0 or z < 0 or x >= nx or z >= nz or y < 0 or y >= ny:
		return 0
	return cells[idx(x, z, y)]

## Vzorek obsahuje tři situace (zadání Jana): souvislou vrstvu/útes (vzadu), malé shluky 2–6 buněk
## a osamocené buňky (vpředu). Shluky se nedotýkají ničeho jiného ani úhlopříčně.
const CLUSTERS := [6, 4, 3, 2, 1, 1, 1, 1]   # velké první, kameny vyplní zbytek

func generate(seed: int, sx := 10, sz := 10, sy := 4) -> void:
	nx = sx; nz = sz; ny = sy
	cells.resize(nx * nz * ny)
	cells.fill(0)
	# souřadnice šumu jsou v „buňkách vzorku 10 × 10 × 4“, takže větší mřížka = stejný tvar ve větším
	var kx := 10.0 / nx
	var ky := 4.0 / ny
	var edge := _noise(seed, 0.16)
	var holes := _noise(seed + 1, 0.30, 1)
	var strata := _noise(seed + 2, 0.12)
	for x in nx:
		for z in nz:
			var fx := (x + 0.5) * kx
			var fz := (z + 0.5) * kx
			var e := fx + 1.6 * edge.get_noise_2d(fz, 3.0)
			if e > 5.0:
				continue                     # před útesem volno pro shluky a kameny
			var h := 4.0
			if e > 2.2: h = 3.0
			if e > 3.3: h = 2.0
			if e > 4.2: h = 1.0              # souvislá spodní vrstva
			if fz > 8.0 + 1.2 * edge.get_noise_2d(fx, 40.0): h = minf(h, 2.0)
			var hc := int(round(maxf(h, 0.0) / ky))
			for y in mini(hc, ny):
				var fy := (y + 0.5) * ky
				if fy > 1.0 and holes.get_noise_3d(fx, fy * 1.4, fz) > 0.4:
					continue  # výklenek
				var v := fy + 0.9 * strata.get_noise_3d(fx, fy * 0.5, fz)
				cells[idx(x, z, y)] = Mat.GRANITE if v < 1.6 else Mat.LIMESTONE
	# shluky a osamocené kameny
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	for size in CLUSTERS:
		for attempt in 200:
			var start := Vector3i(rng.randi_range(0, nx - 1), 0, rng.randi_range(0, nz - 1))
			var cl: Array[Vector3i] = [start]
			for g in size - 1:
				var from: Vector3i = cl[rng.randi_range(0, cl.size() - 1)]
				var dirs := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1), Vector3i(0,1,0)]
				var d: Vector3i = dirs[rng.randi_range(0, 4)]
				var c2 := from + d
				if d.y == 1 and (rng.randf() > 0.3 or from.y >= 1): c2 = from + Vector3i(0, 0, 1)   # nahoru jen výjimečně a max. o 1
				if not c2 in cl: cl.append(c2)
			if cl.size() != size or not _free_for(cl):
				continue
			var m := Mat.GRANITE if rng.randf() < 0.5 else Mat.LIMESTONE
			for c in cl:
				cells[idx(c.x, c.z, c.y)] = m
			break

## buňky shluku jsou uvnitř mřížky a v okolí 3 × 3 × 3 kolem nich není nic plného (mimo shluk)
func _free_for(cl: Array[Vector3i]) -> bool:
	for c in cl:
		if c.x < 0 or c.z < 0 or c.x >= nx or c.z >= nz or c.y >= ny:
			return false
		if c.y > 0 and not (c - Vector3i(0, 1, 0)) in cl:
			return false   # žádné převisy shluku
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var q := c + Vector3i(dx, dy, dz)
					if q in cl or q.y < 0:
						continue
					if q.x >= 0 and q.z >= 0 and q.x < nx and q.z < nz and q.y < ny and cells[idx(q.x, q.z, q.y)] != 0:
						return false
	return true

## souvislé komponenty (sousedství přes stěny), vrací Array[Array[Vector3i]]
func components() -> Array:
	var seen := {}
	var out := []
	for x in nx:
		for z in nz:
			for y in ny:
				var c := Vector3i(x, y, z)
				if cells[idx(x, z, y)] == 0 or seen.has(c):
					continue
				var comp: Array[Vector3i] = []
				var st: Array[Vector3i] = [c]
				seen[c] = true
				while not st.is_empty():
					var p: Vector3i = st.pop_back()
					comp.append(p)
					for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
						var q: Vector3i = p + d
						if q.x < 0 or q.z < 0 or q.y < 0 or q.x >= nx or q.z >= nz or q.y >= ny:
							continue
						if cells[idx(q.x, q.z, q.y)] != 0 and not seen.has(q):
							seen[q] = true
							st.append(q)
				out.append(comp)
	return out

## kopie jen s vybranými buňkami (pro stavbu jedné komponenty)
func subset(cl: Array) -> RefCounted:
	var s = get_script().new()
	s.nx = nx; s.nz = nz; s.ny = ny
	s.cells = PackedByteArray(); s.cells.resize(cells.size())
	for c in cl:
		s.cells[idx(c.x, c.z, c.y)] = cells[idx(c.x, c.z, c.y)]
	return s
