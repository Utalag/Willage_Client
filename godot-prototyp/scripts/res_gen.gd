extends RefCounted
## EXPERIMENT (režim -- --res-test): generátor bloku s nastavitelným rozlišením.
## Všechny šumy, vrstvy, terasy a prahy se počítají ve FYZICKÝCH jednotkách, takže blok má při jakémkoli
## rozlišení stejný tvar, jen jemnější. Referenční mřížka = výchozí hra: buňka 1 × 1 × 0,5, blok 16 × 16 × 64.
## Převod: vodorovně u = x_fyz − 0,5 (u = lx v referenci), výška v ref. buňkách zl = y_fyz / 0,5.
## Bez transformací (zrcadlení, rotace, posun), bez sousedů a bez vegetace – jen pro srovnávací render.
## Výchozí hra dál používá block_gen.gd; ten se tu jen čte (noise, profile_at, u01, konstanty).

const Mat = preload("res://scripts/mat.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const REF_CXY := 1.0
const REF_CZ := 0.5

## Výsledek: {cells (index (x*nxy + y)*nz + z), hm (počet plných buněk), gen_ms}
static func generate(kind: String, seed: int, nxy: int, nz: int, cxy: float, cz: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var L := nxy * cxy                      # fyzická šířka bloku
	var n := BlockGen.noise(seed, "HEIGHT", 0, 0.07)
	var n2 := BlockGen.noise(seed, "HEIGHT", 1, 0.18)
	var terr := kind == "kopec" or kind == "hora"
	# souřadnice středů buněk v ref. jednotkách
	var us := PackedFloat64Array()
	us.resize(nxy)
	for i in nxy:
		us[i] = ((i + 0.5) * cxy) / REF_CXY - 0.5
	# makro pole m (v2.2) normalizované přes celý blok
	var prof := PackedFloat64Array()
	if terr:
		var mn := BlockGen.noise(seed, "HEIGHT", 5, BlockGen.MACRO_FREQ, BlockGen.MACRO_OCTAVES)
		var raw := PackedFloat64Array(); raw.resize(nxy * nxy)
		var lo := 1e9; var hi := -1e9
		for i in nxy:
			for j in nxy:
				var v := mn.get_noise_2d(us[i], us[j])
				raw[i * nxy + j] = v; lo = minf(lo, v); hi = maxf(hi, v)
		var span := maxf(hi - lo, 0.05)
		var off := BlockGen.MACRO_SHIFT * (2.0 * BlockGen.u01(seed, "HEIGHT", 6) - 1.0)
		var edge: float = BlockGen.EDGE_DROP[kind]
		var half := L * 0.5
		prof.resize(nxy * nxy)
		for i in nxy:
			for j in nxy:
				var ax := absf((i + 0.5) * cxy - half) / half
				var ay := absf((j + 0.5) * cxy - half) / half
				var r := pow(ax * ax * ax * ax + ay * ay * ay * ay, 0.25)
				var fall := edge * clampf((r - 0.6) / 0.4, 0.0, 1.0)
				prof[i * nxy + j] = clampf((raw[i * nxy + j] - lo) / span + off - fall, 0.0, 1.0)
	# výšky: v ref. buňkách (float), pak na buňky cílové mřížky
	var hm := PackedInt32Array(); hm.resize(nxy * nxy)
	for i in nxy:
		for j in nxy:
			var lx := us[i]; var ly := us[j]
			var h := 32.0
			match kind:
				"louka":
					h = 31.0 + 1.8 * n.get_noise_2d(lx, ly) + 0.6 * n2.get_noise_2d(lx, ly)
				"kopec", "hora":
					var base := BlockGen.profile_at(kind, prof[i * nxy + j])
					if kind == "hora":
						h = base + 0.9 * n.get_noise_2d(lx, ly) + 0.5 * n2.get_noise_2d(lx, ly)
						if base >= 46.0:
							h += 1.6 * maxf(n2.get_noise_2d(lx, ly), 0.0)
					else:
						h = base + 0.8 * n.get_noise_2d(lx, ly) + 0.4 * n2.get_noise_2d(lx, ly)
				"piscina":
					h = 30.0 + 1.2 * n.get_noise_2d(lx * 0.7, ly * 0.7) + 2.0 * maxf(n2.get_noise_2d(lx * 0.5, ly), 0.0)
			# h je v ref. buňkách (0,5) -> fyzická výška -> zaokrouhlení na buňky cílové mřížky (cz)
			hm[i * nxy + j] = clampi(int(round(h * REF_CZ / cz)), 1, nz - 1)
	var cells := _fill(kind, seed, nxy, nz, cxy, cz, us, hm)
	return {"cells": cells, "hm": hm, "gen_ms": (Time.get_ticks_usec() - t0) / 1000.0}

static func _stone(nb: Dictionary, x: float, ly: float, zl: float) -> int:
	var v: float = zl + 5.0 * nb.s0.get_noise_2d(x, ly) + 2.0 * nb.s2.get_noise_3d(x, zl, ly)
	var m := Mat.BASALT
	if v >= 21.0 + 2.0 * nb.s1.get_noise_2d(x, ly):
		m = Mat.LIMESTONE
		if nb.s3.get_noise_3d(x, zl * 0.7, ly) > 0.5:
			m = Mat.GRANITE
	elif v >= 11.0 + 2.0 * nb.s1.get_noise_2d(ly, x):
		m = Mat.GRANITE
	if m != Mat.BASALT and nb.cu.get_noise_3d(x, zl * 1.6, ly) > 0.55:
		m = Mat.COPPER
	elif m != Mat.LIMESTONE and nb.fe.get_noise_3d(x * 1.3, zl, ly * 1.3) > 0.55:
		m = Mat.IRON
	return m

static func _fill(kind: String, s: int, nxy: int, nz: int, cxy: float, cz: float, us: PackedFloat64Array, hm: PackedInt32Array) -> PackedByteArray:
	var nb := {
		"s0": BlockGen.noise(s, "STRATA", 0, 0.05), "s1": BlockGen.noise(s, "STRATA", 1, 0.06),
		"s2": BlockGen.noise(s, "STRATA", 2, 0.12), "s3": BlockGen.noise(s, "STRATA", 3, 0.07),
		"cu": BlockGen.noise(s, "ORE", 0, 0.16), "fe": BlockGen.noise(s, "ORE", 1, 0.14),
	}
	var dn := BlockGen.noise(s, "SOIL", 0, 0.15)
	var sn := BlockGen.noise(s, "SOIL", 1, 0.11)
	var cl := BlockGen.noise(s, "SOIL", 2, 0.08)
	var cells := PackedByteArray(); cells.resize(nxy * nxy * nz)
	var terraced := kind == "kopec" or kind == "hora"
	var kz := cz / REF_CZ           # kolik ref. buněk na jednu cílovou na výšku
	var kxy := cxy / REF_CXY
	for i in nxy:
		for j in nxy:
			var sx := us[i]; var sy := us[j]
			var hc: int = hm[i * nxy + j]
			var h := hc * kz                # výška povrchu v ref. buňkách
			var slope := 0.0                # strmost v ref. buňkách na ref. buňku vodorovně
			for d in BlockGen.DIRS:
				var a: int = i + d.x; var b: int = j + d.y
				if a >= 0 and b >= 0 and a < nxy and b < nxy:
					slope = maxf(slope, absf(hm[a * nxy + b] - hc) * kz / kxy)
			var dirt := clampi(1 + int((dn.get_noise_2d(sx, sy) + 1.0) * 1.6), 1, 3)
			var sub := clampi(1 + int((sn.get_noise_2d(sx, sy) + 1.0) * 1.2), 1, 3)
			var sub_m := Mat.CLAY if cl.get_noise_2d(sx, sy) > -0.1 else Mat.SAND
			var top := Mat.GRASS
			var soil := Mat.DIRT
			if kind == "piscina":
				top = Mat.SAND; soil = Mat.SAND; sub += 1
				sub_m = Mat.CLAY if cl.get_noise_2d(sx, sy) > 0.4 else Mat.SAND
			if terraced:
				if h >= BlockGen.ROCK_LZ:
					top = -1
			elif slope >= 3.0 or (h >= 41.0 and slope >= 2.0):
				top = -1
			if h >= BlockGen.SNOW_LZ:
				top = Mat.SNOW
			for lz in hc:
				# hloubka v ref. buňkách od povrchu ke spodku buňky (vrchní buňka = 0 v referenci)
				var depth := int(floor(h - (lz + 1) * kz + 1e-6))  # ref. vrstva, do které spadá vrch buňky
				var m: int
				if top >= 0 and depth == 0:
					m = top
				elif top >= 0 and top != Mat.SNOW and depth <= dirt:
					m = soil
				elif top >= 0 and top != Mat.SNOW and depth <= dirt + sub:
					m = sub_m
				else:
					var zl := (lz + 0.5) * kz - 0.5   # střed buňky v ref. souřadnici výšky
					m = _stone(nb, sx, sy, zl)
				cells[(i * nxy + j) * nz + lz] = m
	return cells
