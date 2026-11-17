extends RefCounted
## Generátor bloku v2 (sdílená spec s backendem, viz README „Specifikace generátoru“).
## Osy podle plánu backendu: lx, ly = vodorovně (0–15), lz = výška (0–63). V Godotu: lx → x, ly → z, lz → y.
## Index buňky: (lx * 16 + ly) * 64 + lz, smyčky vždy v pořadí lx, ly, lz.
## Pořadí transformací: zrcadlení X → rotace 90°·k → posun výšky → dorovnání stran. Mlha není v generátoru.

const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const H = preload("res://scripts/stable_hash.gd")
const Veg = preload("res://scripts/veg.gd")
const Gen3 = preload("res://scripts/gen3/gen3_proto.gd")
const BS := 16
const BH := 64
const GENERATOR_VERSION := 2

const BLEND_MAX := 6     # auto: |rozdíl| <= 6 buněk se dorovná, větší = útes
const AUTO_CELLS := 3    # auto dorovnává na 3 buňkách
const SNOW_LZ := 49
const ROCK_LZ := 46   # v2.2: od této výšky je povrch kopce/hory holý kámen

# strany: sever (-ly), východ (+lx), jih (+ly), západ (-lx)
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDE_NAMES := ["S", "V", "J", "Z"]

## FastNoiseLite s explicitními parametry (stejné musí použít C#)
static func noise(seed: int, purpose: String, layer: int, freq: float, octaves := 5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = H.noise_seed(seed, purpose, layer)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.offset = Vector3.ZERO
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	n.fractal_weighted_strength = 0.0
	n.domain_warp_enabled = false
	return n

## Výšková mapa povrchu (počet plných buněk sloupce) ve zdrojových souřadnicích (před transformací).
static func base_heightmap(kind: String, seed: int) -> PackedInt32Array:
	var n := noise(seed, "HEIGHT", 0, 0.07)
	var n2 := noise(seed, "HEIGHT", 1, 0.18)
	var terr := kind == "kopec" or kind == "hora"
	var rel := {}
	var prof := PackedFloat64Array()
	if terr and relief_version == "v2.1":
		rel = _relief_setup(kind, seed)
	elif terr:
		prof = _profile_field(kind, seed)
	var hm := PackedInt32Array()
	hm.resize(BS * BS)
	for lx in BS:
		for ly in BS:
			var h := 32.0
			match kind:
				"louka":
					h = 31.0 + 1.8 * n.get_noise_2d(lx, ly) + 0.6 * n2.get_noise_2d(lx, ly)
				"kopec", "hora":
					if relief_version == "v2.1":
						h = _relief(kind, lx, ly, n, n2, rel)
					else:
						h = _terrace(kind, prof[lx * BS + ly], lx, ly, n, n2)
				"piscina":
					h = 30.0 + 1.2 * n.get_noise_2d(lx * 0.7, ly * 0.7) + 2.0 * maxf(n2.get_noise_2d(lx * 0.5, ly), 0.0)
			hm[lx * BS + ly] = clampi(int(round(h)), 1, BH - 1)
	return hm

## Generátor podzemí: "v3" = gen-v3 (zásobník ze serveru, Jan 20:14, výchozí), "proto" = původní STRATA se šumovými rudami.
## CLI: -- --gen=proto|v3. Tvar povrchu, dorovnání stran a slupka jsou v obou stejné.
static var gen_version := "v3":
	set(v):
		gen_version = v
		Mat.rarity_gen = v   # prahy rarity-v2 podle generátoru (Mat.thresholds)

static func apply_cli() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gen="):
			var v := a.substr(6)
			if v in ["proto", "v3"]:
				gen_version = v
			else:
				push_warning("neznámý generátor --gen=%s (proto | v3)" % v)

## Verze tvaru kopce a hory: "v2.2" (profil nad makro-šumem, výchozí) nebo "v2.1" (eliptické vrcholy, jen pro srovnání)
static var relief_version := "v2.2"

# ---- proto-v2.2: výškový profil nad makro-šumem (technika z devlogu JohnBrx)
# Řídicí body profilu (m ∈ [0,1] -> lz), po částech lineární; police = vodorovné úseky, strmé úseky = útesy.
const PROFILES := {
	"kopec": [[0.0, 30.0], [0.30, 30.0], [0.36, 34.0], [0.62, 34.0], [0.68, 39.0], [1.0, 39.0]],
	"hora": [[0.0, 31.0], [0.24, 31.0], [0.30, 37.0], [0.48, 37.0], [0.54, 43.0], [0.72, 43.0],
		[0.78, 47.0], [1.0, 48.0]],
}
const MACRO_FREQ := 0.045     # makro-šum HEIGHT/5: v bloku 16 buněk asi 0,7 periody = jeden výrazný tvar
const MACRO_OCTAVES := 2     # makro jen 2 oktávy: čára útesu se vlní, ale nedrolí na jednotlivé buňky
const MACRO_SHIFT := 0.12     # posun m podle seedu: off = MACRO_SHIFT·(2·u(HEIGHT, 6) − 1)
const EDGE_DROP := {"kopec": 0.2, "hora": 0.35}  # vysoká patra se drží dál od hran bloku (žádné krabice)

static func profile_at(kind: String, m: float) -> float:
	var pts: Array = PROFILES[kind]
	if m <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if m <= pts[i][0]:
			var x0: float = pts[i - 1][0]; var y0: float = pts[i - 1][1]
			var x1: float = pts[i][0]; var y1: float = pts[i][1]
			return y0 + (y1 - y0) * (m - x0) / (x1 - x0)
	return pts[pts.size() - 1][1]

## m(lx, ly): makro-šum normalizovaný na rozsah bloku [0,1] + posun podle seedu, oříznutý na [0,1]
static func _profile_field(kind: String, seed: int) -> PackedFloat64Array:
	var mn := noise(seed, "HEIGHT", 5, MACRO_FREQ, MACRO_OCTAVES)
	var raw := PackedFloat64Array()
	raw.resize(BS * BS)
	var lo := 1e9
	var hi := -1e9
	for lx in BS:
		for ly in BS:
			var v := mn.get_noise_2d(lx, ly)
			raw[lx * BS + ly] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.05)
	var off := MACRO_SHIFT * (2.0 * u01(seed, "HEIGHT", 6) - 1.0)
	var out := PackedFloat64Array()
	out.resize(BS * BS)
	var edge: float = EDGE_DROP[kind]
	for lx in BS:
		for ly in BS:
			var i := lx * BS + ly
			# okrajový pokles: superelipsa p=4 (zaoblený čtverec), od r = 0,6 k okraji lineárně až o EDGE_DROP
			var ax := absf(lx - 7.5) / 8.0
			var ay := absf(ly - 7.5) / 8.0
			var r := pow(ax * ax * ax * ax + ay * ay * ay * ay, 0.25)
			var fall := edge * clampf((r - 0.6) / 0.4, 0.0, 1.0)
			out[i] = clampf((raw[i] - lo) / span + off - fall, 0.0, 1.0)
	return out

## výška = profil(m) + malý detail (menší než výška útesu, aby útesy zůstaly ostré)
static func _terrace(kind: String, m: float, lx: int, ly: int, n: FastNoiseLite, n2: FastNoiseLite) -> float:
	var base := profile_at(kind, m)
	if kind == "hora":
		var h := base + 0.9 * n.get_noise_2d(lx, ly) + 0.5 * n2.get_noise_2d(lx, ly)
		if base >= 46.0:  # skalnaté vršky: horní patra drsnější (výchozy)
			h += 1.6 * maxf(n2.get_noise_2d(lx, ly), 0.0)
		return h
	return base + 0.8 * n.get_noise_2d(lx, ly) + 0.4 * n2.get_noise_2d(lx, ly)

# ---- proto-v2.1 (ponecháno pro srovnání): eliptické vrcholy, warp, hřebeny, římsy
## u(seed, purpose, k) = (mix(seed, purpose, k) & 0xFFFFFF) / 2^24  -> [0, 1)
static func u01(seed: int, purpose: String, k: int) -> float:
	return float(H.mix(seed, purpose, k) & 0xFFFFFF) / 16777216.0

## Nepravidelný reliéf (proto-v2.1) pro kopec a horu: několik eliptických vrcholů mimo střed
## s nesouměrnými svahy, ruční domain warp, hřebeny (ridged) u hory a místní terasy (římsy).
static func _relief_setup(kind: String, seed: int) -> Dictionary:
	var hora := kind == "hora"
	var peaks := []
	var count := 3 if hora else 2
	var main_amp := 0.0
	for i in count:
		var k := i * 8
		var amp: float
		if i == 0:
			amp = (12.0 + 8.0 * u01(seed, "PEAK", k + 2)) if hora else (5.0 + 5.0 * u01(seed, "PEAK", k + 2))
			main_amp = amp
		else:
			amp = main_amp * ((0.35 + 0.40 * u01(seed, "PEAK", k + 2)) if hora else (0.30 + 0.50 * u01(seed, "PEAK", k + 2)))
		var rx := (5.5 if hora else 5.5) + 4.0 * u01(seed, "PEAK", k + 4)
		var ang := PI * u01(seed, "PEAK", k + 3)
		peaks.append({
			"cx": 3.0 + 10.0 * u01(seed, "PEAK", k + 0),
			"cy": 3.0 + 10.0 * u01(seed, "PEAK", k + 1),
			"amp": amp,
			"cos": cos(ang), "sin": sin(ang),
			"rx": rx,
			"ry": rx * (0.55 + 0.45 * u01(seed, "PEAK", k + 5)),
			"skew": 0.6 * (2.0 * u01(seed, "PEAK", k + 6) - 1.0),
		})
	return {
		"hora": hora, "peaks": peaks, "main_amp": main_amp,
		"warp": noise(seed, "HEIGHT", 2, 0.08),
		"ridge": noise(seed, "HEIGHT", 3, 0.10),
		"ledge": noise(seed, "HEIGHT", 4, 0.06),
	}

static func _relief(kind: String, lx: int, ly: int, n: FastNoiseLite, n2: FastNoiseLite, r: Dictionary) -> float:
	var hora: bool = r.hora
	var wa := 3.0 if hora else 2.0
	var w: FastNoiseLite = r.warp
	var wx := lx + wa * w.get_noise_2d(lx, ly)
	var wy := ly + wa * w.get_noise_2d(lx + 40.0, ly - 40.0)
	var top := 0.0
	var sum := 0.0
	for p in r.peaks:
		var dx: float = wx - p.cx
		var dy: float = wy - p.cy
		var a: float = dx * p.cos + dy * p.sin
		var b: float = -dx * p.sin + dy * p.cos
		a = a / (1.0 + p.skew) if a > 0.0 else a / (1.0 - p.skew)  # nesouměrný svah
		var q := sqrt((a / p.rx) * (a / p.rx) + (b / p.ry) * (b / p.ry))
		var f := maxf(0.0, 1.0 - q)
		f = pow(f, 1.3) if hora else f * f * (3.0 - 2.0 * f)
		var v: float = p.amp * f
		top = maxf(top, v)
		sum += v
	var h := (33.0 if hora else 32.0) + top + 0.15 * (sum - top)
	if hora:
		var rv := 1.0 - absf(r.ridge.get_noise_2d(wx, wy))
		h += 4.0 * rv * rv * (0.3 + 0.7 * clampf(top / r.main_amp, 0.0, 1.0))
		h += 1.5 * n.get_noise_2d(lx, ly) + 1.2 * n2.get_noise_2d(lx, ly)
	else:
		h += 1.6 * n.get_noise_2d(lx, ly) + 0.6 * n2.get_noise_2d(lx, ly)
	# římsy: v místech, kde je šum říms vysoko, se výška stáhne k terase
	var step := 3.0 if hora else 2.0
	var m := clampf((r.ledge.get_noise_2d(lx, ly) - 0.1) * 3.0, 0.0, 1.0) * 0.8
	h = lerpf(h, floorf(h / step) * step, m)
	return h

## Cílové (lx, ly) -> zdrojové: inverzní rotace, pak zrcadlení.
## Dopředně: zrcadlení (lx -> 15 - lx), pak rotace o 90° k-krát: (lx, ly) -> (15 - ly, lx).
static func to_src(lx: int, ly: int, mirror: bool, rot: int) -> Vector2i:
	var p := Vector2i(lx, ly)
	for i in rot:
		p = Vector2i(p.y, BS - 1 - p.x)
	if mirror:
		p.x = BS - 1 - p.x
	return p

## neighbors: Array[4] výškových map sousedů (nebo null) ve směrech DIRS
static func build(b: Block, neighbors: Array) -> void:
	var t0 := Time.get_ticks_usec()
	var base := base_heightmap(b.kind, b.seed)
	var hm := PackedInt32Array()
	hm.resize(BS * BS)
	# 1) zrcadlení, 2) rotace, 3) posun výšky
	for lx in BS:
		for ly in BS:
			var s := to_src(lx, ly, b.mirror, b.rot)
			hm[lx * BS + ly] = clampi(base[s.x * BS + s.y] + b.shift, 1, BH - 1)
	# 4) dorovnání stran – mění se jen nový blok, sousedé nikdy
	b.edge_profiles = [null, null, null, null]
	for si in 4:
		var nh0 = neighbors[si]
		if nh0 == null:
			continue
		var d0: Vector2i = DIRS[si]
		var prof := PackedInt32Array()
		for t in BS:
			var ex0 := t if d0.x == 0 else (BS - 1 if d0.x > 0 else 0)
			var ey0 := t if d0.y == 0 else (BS - 1 if d0.y > 0 else 0)
			var nx0 := ex0 if d0.x == 0 else BS - 1 - ex0
			var ny0 := ey0 if d0.y == 0 else BS - 1 - ey0
			prof.append(nh0[nx0 * BS + ny0])
		b.edge_profiles[si] = prof
	for si in 4:
		var nh = neighbors[si]
		if nh == null:
			continue
		var mode: int = b.sides[si]
		if mode == 5:
			continue  # ponechat
		var d: Vector2i = DIRS[si]
		for t in BS:
			var ex := t if d.x == 0 else (BS - 1 if d.x > 0 else 0)
			var ey := t if d.y == 0 else (BS - 1 if d.y > 0 else 0)
			var nx := ex if d.x == 0 else BS - 1 - ex
			var ny := ey if d.y == 0 else BS - 1 - ey
			var diff: int = nh[nx * BS + ny] - hm[ex * BS + ey]
			var cells_n := mode
			if mode == 0:
				if absi(diff) > BLEND_MAX:
					continue  # velký rozdíl -> útes
				cells_n = AUTO_CELLS
			for dd in cells_n:
				var lx := ex - d.x * dd
				var ly := ey - d.y * dd
				var w := float(cells_n - dd) / float(cells_n)
				hm[lx * BS + ly] = clampi(int(round(hm[lx * BS + ly] + diff * w)), 1, BH - 1)
	b.hm = hm
	b.hm_gen = hm.duplicate()
	_fill(b)
	b.recount()
	b.veg = Veg.generate(b)
	b.veg_summary = Veg.summary(b.veg)
	b.veg_summary_orig = b.veg_summary.duplicate()
	b.summary_orig = b.summary.duplicate()
	b.gen_ms = (Time.get_ticks_usec() - t0) / 1000.0

## kámen podle zdrojové výšky zl (= lz - posun; může být záporná = dogenerováno ze seedu)
static func _stone(nb: Dictionary, x: int, ly: int, zl: int, ore: float, with_ore := true) -> int:
	# FastNoiseLite 3D: (x, y, z) = (lx, lz, ly)
	var v: float = zl + 5.0 * nb.s0.get_noise_2d(x, ly) + 2.0 * nb.s2.get_noise_3d(x, zl, ly)
	var m := Mat.BASALT
	if v >= 21.0 + 2.0 * nb.s1.get_noise_2d(x, ly):
		m = Mat.LIMESTONE
		if nb.s3.get_noise_3d(x, zl * 0.7, ly) > 0.5:
			m = Mat.GRANITE
	elif v >= 11.0 + 2.0 * nb.s1.get_noise_2d(ly, x):
		m = Mat.GRANITE
	if not with_ore:
		return m   # gen-v3: rudy rozmístí zásobník, základ je bez šumových rud
	if m != Mat.BASALT and nb.cu.get_noise_3d(x, zl * 1.6, ly) > 0.55 - ore:
		m = Mat.COPPER
	elif m != Mat.LIMESTONE and nb.fe.get_noise_3d(x * 1.3, zl, ly * 1.3) > 0.55 - ore:
		m = Mat.IRON
	return m

static func _fill(b: Block) -> void:
	var s := b.seed
	var nb := {
		"s0": noise(s, "STRATA", 0, 0.05), "s1": noise(s, "STRATA", 1, 0.06),
		"s2": noise(s, "STRATA", 2, 0.12), "s3": noise(s, "STRATA", 3, 0.07),
		"cu": noise(s, "ORE", 0, 0.16), "fe": noise(s, "ORE", 1, 0.14),
	}
	var dn := noise(s, "SOIL", 0, 0.15)
	var sn := noise(s, "SOIL", 1, 0.11)
	var cl := noise(s, "SOIL", 2, 0.08)
	var cells := PackedByteArray()
	cells.resize(BS * BS * BH)
	var hm := b.hm
	var terraced := relief_version == "v2.2" and (b.kind == "kopec" or b.kind == "hora")
	var v3 := gen_version == "v3"
	for lx in BS:
		for ly in BS:
			var src := to_src(lx, ly, b.mirror, b.rot)
			var sx := src.x
			var sy := src.y
			var h: int = hm[lx * BS + ly]
			var slope := 0
			for d in DIRS:
				var kx: int = lx + d.x
				var ky: int = ly + d.y
				if kx >= 0 and ky >= 0 and kx < BS and ky < BS:
					slope = maxi(slope, absi(hm[kx * BS + ky] - h))
			var dirt := clampi(1 + int((dn.get_noise_2d(sx, sy) + 1.0) * 1.6), 1, 3)
			var sub := clampi(1 + int((sn.get_noise_2d(sx, sy) + 1.0) * 1.2), 1, 3)
			var sub_m := Mat.CLAY if cl.get_noise_2d(sx, sy) > -0.1 else Mat.SAND
			var top := Mat.GRASS
			var soil := Mat.DIRT
			if b.kind == "piscina":
				top = Mat.SAND; soil = Mat.SAND; sub += 1
				sub_m = Mat.CLAY if cl.get_noise_2d(sx, sy) > 0.4 else Mat.SAND
			if terraced:
				# v2.2: police mají trávu až k hraně útesu (jako v devlogu); holý kámen jen ve vysokých patrech hory
				if h >= ROCK_LZ:
					top = -1
			elif slope >= 3 or (h >= 41 and slope >= 2):
				top = -1  # strmý svah: holý kámen
			if h >= SNOW_LZ:
				top = Mat.SNOW
			for lz in h:
				var depth := h - 1 - lz
				var m: int
				if top >= 0 and depth == 0:
					m = top
				elif top >= 0 and top != Mat.SNOW and depth <= dirt:
					m = soil
				elif top >= 0 and top != Mat.SNOW and depth <= dirt + sub:
					m = sub_m
				else:
					# posun nahoru dogeneruje spodní řady ze seedu (zl < 0), posun dolů spodní řady odebere
					m = _stone(nb, sx, sy, lz - b.shift, b.ore_bonus, not v3)
				cells[(lx * BS + ly) * BH + lz] = m
	b.gen = gen_version
	if v3:
		Gen3.apply(b, cells)
		return
	b.cells = cells
	b.water = PackedInt32Array()
	b.gen3 = {}
