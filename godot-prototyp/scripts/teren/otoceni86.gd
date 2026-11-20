extends RefCounted
## E86: otočení výřezu (bloku) po 90° kolem středu bloku – jen studie klienta (TODO Blok 3).
## rot ∈ {0, 1, 2, 3} = 0°, 90°, 180°, 270°. Mřížka n × n: rot 1 zobrazí (x, y) → (n − 1 − y, x), směr (dx, dy) → (−dy, dx),
## strana d (0 −y, 1 +x, 2 +y, 3 −x) → (d + rot) mod 4. V místních metrech bloku (X, Y ∈ [0, 8]): (X, Y) → (8 − Y, X).
## Otočení je permutace sloupců (z se nemění): bijekce na buňky, rot⁴ = identita, rot a ∘ rot b = rot (a + b).
## Výřez E76 (prenos76.cutout) se otočí CELÝ: pole po sloupcích (hm, hm_gen, hm_f, hm_raw, hm_pre, changed, bs[k]), buňky,
## geo, voda, indexy buněk dutin v záznamu, prameny (lx, ly). Výkopy = hm proti hm_gen → otočí se s nimi.
## Podzemí: ug_funkce.bands76 s p86_otoceni převede cílový bod inverzní rotací do souřadnic původu (šum hornin jako v původu).

const BW := 8.0
const NZ := 64

static func norm(r: int) -> int:
	return ((r % 4) + 4) % 4

static func inv(r: int) -> int:
	return norm(4 - norm(r))

## (x, y) v mřížce n × n → otočené (x', y')
static func xy(x: int, y: int, r: int, n: int) -> Vector2i:
	match norm(r):
		1: return Vector2i(n - 1 - y, x)
		2: return Vector2i(n - 1 - x, n - 1 - y)
		3: return Vector2i(y, n - 1 - x)
	return Vector2i(x, y)

## místní metry bloku (0..8) → otočené
static func local_m(X: float, Y: float, r: int) -> Vector2:
	match norm(r):
		1: return Vector2(BW - Y, X)
		2: return Vector2(BW - X, BW - Y)
		3: return Vector2(Y, BW - X)
	return Vector2(X, Y)

static func side(d: int, r: int) -> int:
	return norm(d + r)

## pole po sloupcích (index x · n + y), libovolný Packed*Array / Array
static func cols(a, r: int, n := 16):
	if norm(r) == 0 or a == null: return a.duplicate() if a != null else null
	var out = a.duplicate()
	if a.size() != n * n: return out
	for x in n:
		for y in n:
			var q := xy(x, y, r, n)
			out[q.x * n + q.y] = a[x * n + y]
	return out

## pole po buňkách (index (x · n + y) · nz + z); prázdné / jiné velikosti beze změny
static func cells(a, r: int, n := 16, nz := NZ):
	if a == null: return null
	var out = a.duplicate()
	if norm(r) == 0 or a.size() != n * n * nz: return out
	for x in n:
		for y in n:
			var q := xy(x, y, r, n)
			var s := (x * n + y) * nz; var d := (q.x * n + q.y) * nz
			for z in nz: out[d + z] = a[s + z]
	return out

static func cell_idx(i: int, r: int, n := 16, nz := NZ) -> int:
	var x := i / (n * nz); var y := (i / nz) % n; var z := i % nz
	var q := xy(x, y, r, n)
	return (q.x * n + q.y) * nz + z

## záznam bloku světa studie (pipeline.record) otočený o r; slot, bp a ostatní beze změny
static func record(rec: Dictionary, r: int) -> Dictionary:
	var o := rec.duplicate(true)
	if norm(r) == 0: return o
	for k in ["hm", "hm_f", "hm_raw", "hm_pre", "changed"]:
		if rec.has(k) and rec[k] != null: o[k] = cols(rec[k], r)
	var bs := []
	for b in rec.get("bs", []): bs.append(cols(b, r))
	o.bs = bs
	for k in ["cells", "water"]:
		if rec.has(k) and rec[k] != null: o[k] = cells(rec[k], r)
	if rec.has("rep") and rec.rep.has("cavities"):
		var cv := []
		for e in rec.rep.cavities:
			var e2: Dictionary = e.duplicate(true)
			if e.has("cells"):
				var ci := PackedInt32Array()
				for i in e.cells: ci.append(cell_idx(int(i), r))
				e2.cells = ci
			if e.get("centre") != null:   # střed v metrech světa původu → otočený kolem středu bloku původu
				var s: Vector2i = rec.slot
				var c: Vector3 = e.centre
				var l := local_m(c.x - s.x * BW, c.y - s.y * BW, r)
				e2.centre = Vector3(s.x * BW + l.x, s.y * BW + l.y, c.z)
			cv.append(e2)
		o.rep.cavities = cv
	return o

## výřez E76 otočený o r (skládá se s předchozím otočením: cut.rot)
static func cutout(cut: Dictionary, r: int) -> Dictionary:
	var o := cut.duplicate(true)
	o.rot = norm(int(cut.get("rot", 0)) + r)
	if norm(r) == 0: return o
	o.rec = record(cut.rec, r)
	for k in ["geo", "cells", "water"]: o[k] = cells(cut[k], r)
	for k in ["hm", "hm_gen"]: o[k] = cols(cut[k], r)
	var sp := []
	for e in cut.prameny:
		var q := xy(int(e[0]), int(e[1]), r, 16)
		sp.append([q.x, q.y, e[2], e[3], e[4]])
	o.prameny = sp
	return o
