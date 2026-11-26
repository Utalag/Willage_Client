extends RefCounted
## Útvary jako funkce světa (1.7, E84): SDF z hashe světové mřížky, přes švy.
## Žíla, čočka/peň, dóm, komín, kras/dutina, skarn na kontaktu granitoidu.
## cavity_one se nepoužívá. Jádro převzaté z tools/implicit_e84.gd (zkusebni-vse).
const H = preload("res://scripts/stable_hash.gd")
const HU = preload("res://scripts/v1/hostitele_utvaru.gd")

const PEG := 38
const SKARN := 42
const KIMB := 21
const SUL := 47
const KARST := [44, 49, 5]
const VZDUCH := 0
const GRANITOID := {6: true, 36: true, 37: true}

# rozteč m, četnost, dosah m (E84 + dóm/komín)
const GRID := {
	"zila": [10.0, 0.7, 7.0],
	"cocka": [12.0, 0.6, 4.5],
	"kras": [14.0, 0.8, 22.0],
	"dome": [16.0, 0.35, 8.0],
	"pipe": [20.0, 0.25, 10.0],
}

var svet
var geo
var host                      # hostitelské horniny útvarů (A1), data/v1/utvary_hostitele.json
var fast := true
var _cx := 1e300
var _cy := 1e300
var _cfeats: Array = []
var _zs := {}

func _init(s, g) -> void:
	svet = s
	geo = g
	host = HU.new(bool(svet.p.get("a1_hostitele", true)))

static func _u(h: int) -> float:
	return float(H.shr(h, 40)) / 16777216.0

static func _lat(seed: int, i: int, j: int, k: int) -> float:
	return _u(H.splitmix64(H.splitmix64(H.splitmix64(seed ^ i) ^ j) ^ k)) * 2.0 - 1.0

static func vnoise(seed: int, x: float, y: float, z: float) -> float:
	var xi := floori(x); var yi := floori(y); var zi := floori(z)
	var tx := x - xi; var ty := y - yi; var tz := z - zi
	tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty); tz = tz * tz * (3.0 - 2.0 * tz)
	var a := lerpf(_lat(seed, xi, yi, zi), _lat(seed, xi + 1, yi, zi), tx)
	var b := lerpf(_lat(seed, xi, yi + 1, zi), _lat(seed, xi + 1, yi + 1, zi), tx)
	var c := lerpf(_lat(seed, xi, yi, zi + 1), _lat(seed, xi + 1, yi, zi + 1), tx)
	var d := lerpf(_lat(seed, xi, yi + 1, zi + 1), _lat(seed, xi + 1, yi + 1, zi + 1), tx)
	return lerpf(lerpf(a, b, ty), lerpf(c, d, ty), tz)

static func _norm(v: Array) -> Array:
	var l := sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
	if l < 1e-15: return [0.0, 0.0, 1.0]
	return [v[0] / l, v[1] / l, v[2] / l]

static func _cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]

func _rr(hsh: int, k: int) -> float:
	return _u(H.mix(hsh, "R", k))

## útvary, jejichž obálka může zasáhnout bod (x, y)
func features_u(x: float, y: float) -> Array:
	if x == _cx and y == _cy:
		return _cfeats
	var out: Array = []
	for kd in GRID.keys():
		var G: float = GRID[kd][0]
		var R: float = GRID[kd][2]
		var gi0 := floori((x - R) / G)
		var gi1 := floori((x + R) / G)
		var gj0 := floori((y - R) / G)
		var gj1 := floori((y + R) / G)
		for gi in range(gi0, gi1 + 1):
			for gj in range(gj0, gj1 + 1):
				var hsh: int = H.mix(int(svet.sd), "E84_" + String(kd), gi * 7919 + gj)
				if _u(hsh) >= float(GRID[kd][1]): continue
				var cx := gi * G + _rr(hsh, 1) * G
				var cy := gj * G + _rr(hsh, 2) * G
				var f: Dictionary = _make(String(kd), hsh, cx, cy)
				f.gid = "%s_%d_%d" % [kd, gi, gj]
				var bx: Array = f.box
				if x >= bx[0] and x <= bx[3] and y >= bx[1] and y <= bx[4]:
					out.append(f)
	_cx = x
	_cy = y
	_cfeats = out
	return out

func _make(kd: String, hsh: int, cx: float, cy: float) -> Dictionary:
	var zk := "%d_%d" % [int(round(cx * 4.0)), int(round(cy * 4.0))]
	var zs: float
	if _zs.has(zk):
		zs = float(_zs[zk])
	else:
		zs = float(svet.vyska_tvar(cx, cy))
		_zs[zk] = zs
	var P := PackedFloat64Array()
	var box: Array = []
	match kd:
		"zila":
			var cz := clampf(zs * (0.35 + 0.30 * _rr(hsh, 3)), 4.0, maxf(zs - 2.0, 4.0))
			var n := _norm([_rr(hsh, 4) * 2.0 - 1.0, _rr(hsh, 5) * 2.0 - 1.0, (_rr(hsh, 6) * 2.0 - 1.0) * 0.4])
			var u := _norm(_cross(n, [0.0, 0.0, 1.0])); var v := _cross(n, u)
			var t0 := 0.15 + 0.25 * _rr(hsh, 7); var a := 3.0 + 3.0 * _rr(hsh, 8); var b := 2.0 + 2.0 * _rr(hsh, 9)
			for q in [cx, cy, cz] + n + u + v + [t0, a, b, 0.3, 0.35]: P.append(q)
			var e := maxf(a, b) + 0.3 + t0
			box = [cx - e, cy - e, cz - e, cx + e, cy + e, cz + e]
		"cocka":
			var cz := clampf(zs * (0.30 + 0.35 * _rr(hsh, 3)), 3.0, maxf(zs - 2.0, 3.0))
			var n := _norm([_rr(hsh, 4) * 2.0 - 1.0, _rr(hsh, 5) * 2.0 - 1.0, _rr(hsh, 6) * 2.0 - 1.0])
			var u := _norm(_cross(n, [0.0, 0.0, 1.0])); var v := _cross(n, u)
			var ra := 2.0 + 2.0 * _rr(hsh, 7); var rb := 1.5 + 1.5 * _rr(hsh, 8); var rc := 0.5 + 0.7 * _rr(hsh, 9)
			for q in [cx, cy, cz] + u + v + n + [ra, rb, rc]: P.append(q)
			box = [cx - ra, cy - ra, cz - ra, cx + ra, cy + ra, cz + ra]
		"dome":
			var cz := clampf(zs * (0.55 + 0.20 * _rr(hsh, 3)), 6.0, maxf(zs - 3.0, 6.0))
			var ra := 3.0 + 4.0 * _rr(hsh, 7); var rb := 3.0 + 4.0 * _rr(hsh, 8); var rc := 6.0 + 8.0 * _rr(hsh, 9)
			for q in [cx, cy, cz, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, ra, rb, rc]: P.append(q)
			var e := maxf(ra, maxf(rb, rc))
			box = [cx - e, cy - e, cz - e, cx + e, cy + e, cz + e]
		"pipe":
			var cz := clampf(zs * 0.35, 8.0, maxf(zs * 0.5, 8.0))
			var ra := 0.8 + 1.2 * _rr(hsh, 7); var rb := ra; var rc := cz * (0.7 + 0.4 * _rr(hsh, 9))
			for q in [cx, cy, cz, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, ra, rb, rc]: P.append(q)
			var e := maxf(ra, rc)
			box = [cx - e, cy - e, 0.0, cx + e, cy + e, cz + rc]
		"kras":
			var dir := _norm([_rr(hsh, 3) * 2.0 - 1.0, _rr(hsh, 4) * 2.0 - 1.0, 0.0])
			var z0 := clampf(zs * (0.65 + 0.15 * _rr(hsh, 5)) - 2.0, 2.0, maxf(zs - 2.5, 2.0))
			var x := cx; var y := cy
			var nodes: Array = []
			for i in 6:
				nodes.append([x, y, z0 + (_rr(hsh, 10 + i) - 0.5) * 1.2, 0.5 + 0.6 * _rr(hsh, 20 + i)])
				dir = _norm([dir[0] + 0.6 * (_rr(hsh, 30 + i) * 2.0 - 1.0), dir[1] + 0.6 * (_rr(hsh, 40 + i) * 2.0 - 1.0), 0.0])
				x += 3.0 * dir[0]; y += 3.0 * dir[1]
			var zmin := 1e9
			for nd in nodes:
				for q in nd: P.append(q)
				zmin = minf(zmin, float(nd[2]))
			for q in [2.2, 1.8, 1.2, 0.25, 0.5, zmin + 0.4]: P.append(q)
			var e := 2.2 + 0.25 + 0.1
			box = [1e9, 1e9, 1e9, -1e9, -1e9, -1e9]
			for nd in nodes:
				for k in 3:
					box[k] = minf(box[k], float(nd[k]) - e)
					box[k + 3] = maxf(box[k + 3], float(nd[k]) + e)
	return {"k": kd, "P": P, "box": box, "seed": hsh & 0x7FFFFFFF}

func sdf(f: Dictionary, X: float, Y: float, Z: float) -> float:
	var P: PackedFloat64Array = f.P
	var qx := X - P[0]; var qy := Y - P[1]; var qz := Z - P[2]
	match String(f.k):
		"zila":
			var fr := P[16]
			var s := qx * P[3] + qy * P[4] + qz * P[5]
			var a := (qx * P[6] + qy * P[7] + qz * P[8]) / P[13]
			var b := (qx * P[9] + qy * P[10] + qz * P[11]) / P[14]
			var tail := P[12] * maxf(1.0 - (a * a + b * b), 0.0) - maxf(sqrt(a * a + b * b) - 1.0, 0.0) * minf(P[13], P[14])
			if fast and absf(s) - P[15] - tail > 0.0: return absf(s) - P[15] - tail
			return absf(s + P[15] * vnoise(int(f.seed), X * fr, Y * fr, Z * fr)) - tail
		"cocka", "dome", "pipe":
			var x := (qx * P[3] + qy * P[4] + qz * P[5]) / P[12]
			var y := (qx * P[6] + qy * P[7] + qz * P[8]) / P[13]
			var z := (qx * P[9] + qy * P[10] + qz * P[11]) / P[14]
			var k0 := sqrt(x * x + y * y + z * z)
			var k1 := sqrt(x * x / (P[12] * P[12]) + y * y / (P[13] * P[13]) + z * z / (P[14] * P[14]))
			return k0 * (k0 - 1.0) / maxf(k1, 1e-12)
		"kras":
			var fr := P[28]; var A := P[27]
			if fast:
				var d0 := _kras_d(P, X, Y, Z)
				if d0 - A * 2.165 > 0.0: return d0 - A * 2.165
			var wx := X + A * vnoise(int(f.seed), X * fr, Y * fr, Z * fr)
			var wy := Y + A * vnoise(int(f.seed) + 1, X * fr, Y * fr, Z * fr)
			var wz := Z + A * vnoise(int(f.seed) + 2, X * fr, Y * fr, Z * fr)
			return _kras_d(P, wx, wy, wz)
	return 1e9

func _kras_d(P: PackedFloat64Array, wx: float, wy: float, wz: float) -> float:
	var d := 1e9
	for i in 5:
		var o := i * 4
		var bax := P[o + 4] - P[o]; var bay := P[o + 5] - P[o + 1]; var baz := P[o + 6] - P[o + 2]
		var pax := wx - P[o]; var pay := wy - P[o + 1]; var paz := wz - P[o + 2]
		var denom := bax * bax + bay * bay + baz * baz
		var h := clampf((pax * bax + pay * bay + paz * baz) / maxf(denom, 1e-15), 0.0, 1.0)
		var dx := pax - bax * h; var dy := pay - bay * h; var dz := paz - baz * h
		d = minf(d, sqrt(dx * dx + dy * dy + dz * dz) - lerpf(P[o + 3], P[o + 7], h))
	var x := (wx - P[8]) / P[24]; var y := (wy - P[9]) / P[25]; var z := (wz - P[10]) / P[26]
	var k0 := sqrt(x * x + y * y + z * z)
	var k1 := sqrt(x * x / (P[24] * P[24]) + y * y / (P[25] * P[25]) + z * z / (P[26] * P[26]))
	return minf(d, k0 * (k0 - 1.0) / maxf(k1, 1e-12))

func _skarn_d(x: float, y: float, z: float, hr: Array) -> float:
	var W := 1.5
	var d := 1e9
	var prev_g := false
	var prev_z1 := 0.0
	for e in hr:
		var id := int(e.id)
		var g := GRANITOID.has(id)
		if g != prev_g and not hr.is_empty():
			d = minf(d, absf(z - float(e.z0 if g else prev_z1)))
		prev_g = g
		prev_z1 = float(e.z1)
	if d >= 1e8: return 1e9
	var nd := d - W * (1.0 + 0.5 * vnoise(svet.sd ^ 84, x * 0.5, y * 0.5, z * 0.5))
	return nd

func feat_mat(f: Dictionary, z: float, vrstva_id := -1) -> int:
	match String(f.k):
		"kras": return VZDUCH
		"dome": return SUL
		"pipe": return KIMB
		"zila", "cocka":
			# občas minerál v žíle, jen když je hornina jeho hostitel (katalog minerálů); jinak pegmatit
			if _u(H.mix(int(f.seed), "MIN", int(floor(z * 4.0)))) < 0.08:
				var m := 8 if _u(H.mix(int(f.seed), "MIN2", 0)) < 0.5 else 9
				if vrstva_id < 0 or host.mineral_ok(m, vrstva_id): return m
			return PEG
	return PEG

## smí útvar typu `kd` vzniknout v hornině `vrstva_id` (A1)? Vypnuto (a1_hostitele = false) = původní chování kroku 3.
func host_ok(kd: String, vrstva_id: int, povrch_m: float, z: float) -> bool:
	if not host.povoleno: return _host_ok_puvodni(kd, vrstva_id, povrch_m, z)
	return host.je_hostitel(kd, vrstva_id, povrch_m - z)

## původní krok 3 (`a1_hostitele` = false): jen kras měl hostitele, ostatní vždy ano. Slouží k porovnání „před“.
func _host_ok_puvodni(kd: String, vrstva_id: int, povrch_m: float, z: float) -> bool:
	match kd:
		"skarn", "cocka", "zila", "dome", "pipe": return true
		"kras": return vrstva_id in KARST and povrch_m - z >= 2.0
	return false

## materiál útvaru v bodě, nebo -1 když útvar bod nemění
func mat(x: float, y: float, z: float, vrstva_id: int, povrch_m: float, hr: Array) -> int:
	return mat_feats(features_u(x, y), x, y, z, vrstva_id, povrch_m, hr)

## stejné jako mat, ale se seznamem útvarů spočteným jednou pro sloupec
func mat_feats(feats: Array, x: float, y: float, z: float, vrstva_id: int, povrch_m: float, hr: Array) -> int:
	var best := 1e9
	var bm := -1
	# pořadí E84: skarn → čočka → žíla → kras (mladší přepisuje); dóm/komín s čočkou
	var sd0 := _skarn_d(x, y, z, hr)
	if sd0 < 0.0 and GRANITOID.has(vrstva_id) == false and host_ok("skarn", vrstva_id, povrch_m, z):
		# skarn jen při kontaktu, ne uvnitř masivu granitoidu daleko od hranice
		best = sd0
		bm = SKARN
	for f in feats:
		var bx: Array = f.box
		if z < float(bx[2]) or z > float(bx[5]): continue
		if not host_ok(String(f.k), vrstva_id, povrch_m, z): continue
		var d := sdf(f, x, y, z)
		if d < 0.0 and d <= best:
			best = d
			bm = feat_mat(f, z, vrstva_id)
	return bm
