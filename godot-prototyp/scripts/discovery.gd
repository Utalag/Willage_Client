@tool
extends RefCounted
## Které buňky jsou „odkryté“: mají stěnu u vzduchu nad výškovou mapou (obloha nebo jáma).
## Chybějící soused (mlha, okraj ostrova) se nepočítá, takže boky bloku pod povrchem zůstanou skryté.
## Řez (slice) buňku neodkryje – jen ji uřízne; materiál se ukáže, až ji hráč odkope.
## gen-v3 (20:14) přidal jeskyně pod povrchem: vzduch pod hm je odkrytý (hodnota 2), jen když je spojený s oblohou
## (prokopáním); BFS běží jen z buněk nad hm, které sousedí se vzduchem pod hm sousedního sloupce, takže blok bez
## otevřené jeskyně stojí stejně jako dřív. Pevné buňky u odkrytého vzduchu jeskyně = 1. Neodkrytý vzduch jeskyně
## mesher kreslí jako plnou neutrální buňku (jeskyně není vidět ani v řezu), voda v něm se nekreslí.
## Poznámka na později: klient má v paměti celé pole, upravený klient by mohl vidět do země. Teď to neřešíme.

const BS := 16
const BH := 64
const P := BS + 2

## cells: jen pro jeskyně (vzduch pod hm); nbs se nepoužijí, platí hms.
static func compute(cells: PackedByteArray, _nbs: Array, hms: Array, hm: PackedInt32Array) -> PackedByteArray:
	var ph := PackedInt32Array()
	ph.resize(P * P)
	ph.fill(-1)
	for x in BS:
		for z in BS:
			ph[(x + 1) * P + (z + 1)] = hm[x * BS + z]
	for si in 4:
		if hms[si] == null:
			continue
		var nh: PackedInt32Array = hms[si]
		for t in BS:
			var x: int
			var z: int
			var nx: int
			var nz: int
			match si:
				0:
					x = t; z = -1; nx = t; nz = BS - 1
				1:
					x = BS; z = t; nx = 0; nz = t
				2:
					x = t; z = BS; nx = t; nz = 0
				_:
					x = -1; z = t; nx = BS - 1; nz = t
			ph[(x + 1) * P + (z + 1)] = nh[nx * BS + nz]

	var out := PackedByteArray()
	out.resize(BS * BS * BH)
	const DIR4 := [[1, 0], [-1, 0], [0, 1], [0, -1]]
	for x in BS:
		for z in BS:
			var h: int = hm[x * BS + z]
			if h <= 0:
				continue
			var low := h
			for d in DIR4:
				var nh2: int = ph[(x + 1 + d[0]) * P + (z + 1 + d[1])]
				if nh2 >= 0 and nh2 < low:
					low = nh2
			var src := (x * BS + z) * BH
			for y in range(mini(low, h - 1), h):
				out[src + y] = 1
	_caves(cells, hm, out)
	return out

const D6 := [BH * BS, -BH * BS, BH, -BH, 1, -1]
## vzduch pod hm spojený s oblohou (vzduchem nad hm v bloku): 2 = odkrytý vzduch, pevné sousední buňky 1
static func _caves(cells: PackedByteArray, hm: PackedInt32Array, out: PackedByteArray) -> void:
	if cells.size() != BS * BS * BH:
		return
	var q := PackedInt32Array()
	for x in BS:
		for z in BS:
			var h: int = hm[x * BS + z]
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var nz: int = z + d[1]
				if nx < 0 or nz < 0 or nx >= BS or nz >= BS:
					continue
				var nh: int = hm[nx * BS + nz]
				for y in range(h, nh):   # nad vlastním hm (obloha), pod hm souseda
					var n := (nx * BS + nz) * BH + y
					if cells[n] == 0 and out[n] != 2:
						out[n] = 2; q.append(n)
	var i := 0
	while i < q.size():
		var c := q[i]; i += 1
		var x := c / (BS * BH)
		var z := (c / BH) % BS
		var y := c % BH
		for k in 6:
			if (k == 0 and x == BS - 1) or (k == 1 and x == 0) or (k == 2 and z == BS - 1) or (k == 3 and z == 0) or (k == 4 and y == BH - 1) or (k == 5 and y == 0):
				continue
			var n: int = c + D6[k]
			if cells[n] == 0:
				if out[n] != 2 and (n % BH) < hm[n / BH]:
					out[n] = 2; q.append(n)
			else:
				if out[n] == 0: out[n] = 1
