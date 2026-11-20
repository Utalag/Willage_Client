extends "res://tools/hranice_e80.gd"
## E84: implicitní útvary nad vrstvami geo_fn bez plných voxelů (samostatný nástroj, hra se nemění).
## R0 = dnes (geo_fn._bodies: skarn jen svislá vzdálenost; dutina cavity_one roste po buňkách v bloku).
## R1 = procedurální vzdálenostní funkce (SDF) vyhodnocené v bodě: žíla (deska se zúžením + warp), čočka pegmatitu
##      (elipsoid, Quilez – dolní mez), skarn (vzdálenost po normále hranice granitoidu + šum šířky), kras (řetěz kapslí
##      + komora, warp). Středy z hashe světové mřížky, ořez obálkou (AABB). Jen float64 skaláry, + − × ÷ sqrt floor,
##      vlastní hashový šum (žádný FastNoiseLite, žádný Vector3 = float32).
## R2 = tytéž funkce převedené na intervaly [lo, hi) ve sloupci (krok |d| / L, půlení) → tvar pásem vody (ug_funkce).
## Části: --casti=cas,svy,det,f32,prekryv,pasma --out=cesta
const UF = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const H = preload("res://scripts/teren/zaklad/stable_hash.gd")
const G2 = preload("res://scripts/teren/geo2.gd")
const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const PEG := 38
const SKARN := 42
const KARST := [44, 49, 5, 56]
const LIP := 2.0          # mez Lipschitz pro krokování intervalů (warp a zúžení < 1)
const HMIN := 0.02        # nejmenší krok m
const ORDER := ["skarn", "cocka", "zila", "kras"]   # od nejstaršího: kontaktní metamorfóza → pegmatit → žíla → rozpouštění
var use_skarn := true; var use_feats := true; var skarn_noise := true   # rozpad času / vliv šumu
var fast := true          # vyřazení podle meze (bez šumu) – výsledek stejný, jen rychlejší
var f32 := false          # varianta: parametry i body zaokrouhlené na float32 (jako Vector3 / C# float)

# ---------------- čísla a šum (port: jen celá čísla mod 2^64 a IEEE + − × ÷ sqrt) ----------------
func _r(v: float) -> float:
	if not f32: return v
	var a := PackedFloat32Array([v]); return float(a[0])

static func _u(h: int) -> float:   # horních 24 bitů → [0, 1) přesně
	return float(H.shr(h, 40)) / 16777216.0

static func _lat(seed: int, i: int, j: int, k: int) -> float:
	return _u(H.splitmix64(H.splitmix64(H.splitmix64(seed ^ i) ^ j) ^ k)) * 2.0 - 1.0

## hodnotový šum 3D, trilineárně se smoothstep; |∇| ≤ 1,5 · √3 · 2 · f
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
	return [v[0] / l, v[1] / l, v[2] / l]

static func _cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]

# ---------------- útvary: generování z hashe světové mřížky ----------------
const GRID := {"zila": [10.0, 0.7, 7.0], "cocka": [12.0, 0.6, 4.5], "kras": [14.0, 0.8, 22.0]}   # rozteč m, četnost, dosah m

func _rr(hsh: int, k: int) -> float:
	return _u(H.mix(hsh, "R", k))

## útvary, jejichž obálka zasahuje blok ws (ořez bloku); stejné (gi, gj) → stejný útvar pro každý blok
func features(ws: Vector2i) -> Array:
	var ox := ws.x * BW_; var oy := ws.y * BW_
	var out := []
	for kd in ["zila", "cocka", "kras"]:
		var G: float = GRID[kd][0]; var R: float = GRID[kd][2]
		for gi in range(floori((ox - R) / G), floori((ox + BW_ + R) / G) + 1):
			for gj in range(floori((oy - R) / G), floori((oy + BW_ + R) / G) + 1):
				var hsh := H.mix(int(T.p.world_seed), "E84_" + kd, gi * 7919 + gj)
				if _u(hsh) >= float(GRID[kd][1]): continue
				var f := _make(kd, hsh, gi * G + _rr(hsh, 1) * G, gj * G + _rr(hsh, 2) * G)
				f.gid = "%s_%d_%d" % [kd, gi, gj]
				var bx: Array = f.box
				if bx[3] > ox and bx[0] < ox + BW_ and bx[4] > oy and bx[1] < oy + BW_: out.append(f)
	return out

const BW_ := 8.0

func _make(kd: String, hsh: int, cx: float, cy: float) -> Dictionary:
	var P := PackedFloat64Array()
	var box := []
	match kd:
		"zila":   # c, n, u, v, t0, a, b, A, freq
			var cz := 5.0 + _rr(hsh, 3) * 14.0
			var n := _norm([_rr(hsh, 4) * 2.0 - 1.0, _rr(hsh, 5) * 2.0 - 1.0, (_rr(hsh, 6) * 2.0 - 1.0) * 0.4])
			var u := _norm(_cross(n, [0.0, 0.0, 1.0])); var v := _cross(n, u)
			var t0 := 0.15 + 0.25 * _rr(hsh, 7); var a := 3.0 + 3.0 * _rr(hsh, 8); var b := 2.0 + 2.0 * _rr(hsh, 9)
			for x in [cx, cy, cz] + n + u + v + [t0, a, b, 0.3, 0.35]: P.append(_r(x))
			var e := maxf(a, b) + 0.3 + t0
			box = [cx - e, cy - e, cz - e, cx + e, cy + e, cz + e]
		"cocka":  # c, n, u, v, r(3)
			var cz := 3.0 + _rr(hsh, 3) * 12.0
			var n := _norm([_rr(hsh, 4) * 2.0 - 1.0, _rr(hsh, 5) * 2.0 - 1.0, _rr(hsh, 6) * 2.0 - 1.0])
			var u := _norm(_cross(n, [0.0, 0.0, 1.0])); var v := _cross(n, u)
			var ra := 2.0 + 2.0 * _rr(hsh, 7); var rb := 1.5 + 1.5 * _rr(hsh, 8); var rc := 0.5 + 0.7 * _rr(hsh, 9)
			for x in [cx, cy, cz] + u + v + n + [ra, rb, rc]: P.append(_r(x))
			box = [cx - ra, cy - ra, cz - ra, cx + ra, cy + ra, cz + ra]
		"kras":   # nodes (6 × [x, y, z, r]), chamber node 2 (rx, ry, rz), A, freq, zw
			var dir := _norm([_rr(hsh, 3) * 2.0 - 1.0, _rr(hsh, 4) * 2.0 - 1.0, 0.0])
			var off := 1.5 + 3.5 * _rr(hsh, 5)
			var x := cx; var y := cy
			var nodes := []
			for i in 6:
				var zt: float = float(G2.zone_tops(x / FN.U, y / FN.U, T.p)[1]) * FN.U   # horizont: vršek krystalinika (funkce světa)
				nodes.append([x, y, zt + off + (_rr(hsh, 10 + i) - 0.5) * 0.8, 0.5 + 0.6 * _rr(hsh, 20 + i)])
				dir = _norm([dir[0] + 0.6 * (_rr(hsh, 30 + i) * 2.0 - 1.0), dir[1] + 0.6 * (_rr(hsh, 40 + i) * 2.0 - 1.0), 0.0])
				x += 3.0 * dir[0]; y += 3.0 * dir[1]
			var zmin := 1e9
			for nd in nodes:
				for q in nd: P.append(_r(q))
				zmin = minf(zmin, nd[2])
			for q in [2.2, 1.8, 1.2, 0.25, 0.5, zmin + 0.4]: P.append(_r(q))
			var e := 2.2 + 0.25 + 0.1
			box = [1e9, 1e9, 1e9, -1e9, -1e9, -1e9]
			for nd in nodes:
				for k in 3:
					box[k] = minf(box[k], nd[k] - e); box[k + 3] = maxf(box[k + 3], nd[k] + e)
	return {"k": kd, "P": P, "box": box, "seed": hsh & 0x7FFFFFFF}

## vzdálenost (záporná uvnitř) útvaru f v bodě
func sdf(f: Dictionary, X: float, Y: float, Z: float) -> float:
	var P: PackedFloat64Array = f.P
	X = _r(X); Y = _r(Y); Z = _r(Z)
	var qx := X - P[0]; var qy := Y - P[1]; var qz := Z - P[2]
	match f.k:
		"zila":
			var fr := P[16]
			var s := qx * P[3] + qy * P[4] + qz * P[5]
			var a := (qx * P[6] + qy * P[7] + qz * P[8]) / P[13]; var b := (qx * P[9] + qy * P[10] + qz * P[11]) / P[14]
			var tail := P[12] * maxf(1.0 - (a * a + b * b), 0.0) - maxf(sqrt(a * a + b * b) - 1.0, 0.0) * minf(P[13], P[14])
			if fast and absf(s) - P[15] - tail > 0.0: return absf(s) - P[15] - tail   # warp posune s nejvýš o A → jistě venku
			return absf(s + P[15] * vnoise(f.seed, X * fr, Y * fr, Z * fr)) - tail
		"cocka":
			var x := (qx * P[3] + qy * P[4] + qz * P[5]) / P[12]; var y := (qx * P[6] + qy * P[7] + qz * P[8]) / P[13]; var z := (qx * P[9] + qy * P[10] + qz * P[11]) / P[14]
			var k0 := sqrt(x * x + y * y + z * z)
			var k1 := sqrt(x * x / (P[12] * P[12]) + y * y / (P[13] * P[13]) + z * z / (P[14] * P[14]))
			return k0 * (k0 - 1.0) / maxf(k1, 1e-12)
		"kras":
			var fr := P[28]; var A := P[27]
			if fast:   # bez warpu: kapsle i elipsoid jsou meze Lipschitz 1 → d(warp) ≥ d0 − A·√3
				var d0 := _kras_d(P, X, Y, Z)
				if d0 - A * 2.165 > 0.0: return d0 - A * 2.165   # √3 · 1,25 (poloměr kapsle se mění → mez ~1,2)
			var wx := X + A * vnoise(f.seed, X * fr, Y * fr, Z * fr); var wy := Y + A * vnoise(f.seed + 1, X * fr, Y * fr, Z * fr); var wz := Z + A * vnoise(f.seed + 2, X * fr, Y * fr, Z * fr)
			return _kras_d(P, wx, wy, wz)
	return 1e9

func _kras_d(P: PackedFloat64Array, wx: float, wy: float, wz: float) -> float:
			var d := 1e9
			for i in 5:   # kapsle uzel i → i+1 (Quilez sdCapsule, poloměr lineárně)
				var o := i * 4
				var bax := P[o + 4] - P[o]; var bay := P[o + 5] - P[o + 1]; var baz := P[o + 6] - P[o + 2]
				var pax := wx - P[o]; var pay := wy - P[o + 1]; var paz := wz - P[o + 2]
				var h := clampf((pax * bax + pay * bay + paz * baz) / (bax * bax + bay * bay + baz * baz), 0.0, 1.0)
				var dx := pax - bax * h; var dy := pay - bay * h; var dz := paz - baz * h
				d = minf(d, sqrt(dx * dx + dy * dy + dz * dz) - lerpf(P[o + 3], P[o + 7], h))
			var x := (wx - P[8]) / P[24]; var y := (wy - P[9]) / P[25]; var z := (wz - P[10]) / P[26]
			var k0 := sqrt(x * x + y * y + z * z)
			var k1 := sqrt(x * x / (P[24] * P[24]) + y * y / (P[25] * P[25]) + z * z / (P[26] * P[26]))
			return minf(d, k0 * (k0 - 1.0) / maxf(k1, 1e-12))

# ---------------- skarn: vzdálenost po normále hranice granitoidu ----------------
## plochy granitoidu ve sloupci: [z plochy, 1/cos sklonu]; gradient centrální diferencí ±U/2 přes bilineární pole
func skarn_col(wf: Dictionary, info: Dictionary, cb: Dictionary, col: Dictionary, X: float, Y: float) -> Array:
	var out := []
	var bs: PackedFloat64Array = col.bs
	var lo := 0.0; var klo := -1
	var e := FN.U * 0.5
	for k in bs.size():
		if cb.around.has(info.lay[k]) and bs[k] - lo > 1e-6:
			for kk in [klo, k]:
				if kk < 0: continue
				var gx := (FN.boundary_m(wf, info.slot, kk, X + e, Y) - FN.boundary_m(wf, info.slot, kk, X - e, Y)) / (2.0 * e)
				var gy := (FN.boundary_m(wf, info.slot, kk, X, Y + e) - FN.boundary_m(wf, info.slot, kk, X, Y - e)) / (2.0 * e)
				out.append([bs[kk] if kk == k else lo, sqrt(1.0 + gx * gx + gy * gy)])
		if bs[k] > lo: lo = bs[k]; klo = k
	return out

func skarn_d(info: Dictionary, cb: Dictionary, sk: Array, X: float, Y: float, Z: float) -> float:
	var W: float = float(cb.e.body.width) * FN.U
	var d := 1e9
	for s in sk: d = minf(d, absf(Z - float(s[0])) / float(s[1]))
	if not skarn_noise: return d - W
	if d >= 1.5 * W: return d - 1.5 * W   # mimo i při největší šířce → šum se nepočítá
	return d - W * (1.0 + 0.5 * vnoise(int(info.p.world_seed) ^ 84, X * 0.5, Y * 0.5, Z * 0.5))

# ---------------- vzorkování bloku ----------------
func _contact(info: Dictionary) -> Dictionary:
	for b in info.bodies:
		if b.kind == "contact": return b
	return {}

func base_info(info: Dictionary) -> Dictionary:
	var i2 := info.duplicate(); i2.bodies = info.bodies.filter(func(b): return b.kind != "contact"); return i2

## host: smí útvar kind nahradit materiál m v bodě?
func host_ok(kd: String, info: Dictionary, cb: Dictionary, m: int, col: Dictionary, Z: float) -> bool:
	match kd:
		"skarn": return not cb.is_empty() and cb["in"].has(m)
		"cocka", "zila": return info.zone_of[m] == 1
		"kras": return m in KARST and float(col.h) - Z >= 2.0
	return false

func feat_mat(f: Dictionary, Z: float) -> int:
	if f.k == "kras": return FN.CAV_WATER if Z < f.P[29] else Mat.AIR
	return PEG

## R1: celý blok bod po bodu. mode "geo" = jen geo_fn (výchozí skarn), "r1" = útvary SDF. st = počty buněk podle útvaru
func sample_r1(wf: Dictionary, info: Dictionary, feats: Array, n: int, mode: String, st: Dictionary) -> PackedByteArray:
	var c := BW_ / n; var nz := 4 * n
	var cells := PackedByteArray(); cells.resize(n * n * nz)
	var ox: float = info.slot.x * BW_; var oy: float = info.slot.y * BW_
	var bi := base_info(info) if mode == "r1" else info
	var cb := _contact(info)
	for x in n:
		for y in n:
			var X: float = ox + (x + 0.5) * c; var Y: float = oy + (y + 0.5) * c
			var col := FN.column(wf, bi, X, Y)
			var base := (x * n + y) * nz
			if mode == "geo":
				for z in nz: cells[base + z] = FN.material(bi, col, X, Y, (z + 0.5) * c)
				continue
			var fs := []
			for f in feats:
				if X > f.box[0] and X < f.box[3] and Y > f.box[1] and Y < f.box[4]: fs.append(f)
			var sk := skarn_col(wf, info, cb, col, X, Y) if not cb.is_empty() and use_skarn else []
			if not use_feats: fs = []
			for z in nz:
				var Z := (z + 0.5) * c
				var m := FN.material(bi, col, X, Y, Z)
				if m != 0:
					if not sk.is_empty() and host_ok("skarn", info, cb, m, col, Z) and skarn_d(info, cb, sk, X, Y, Z) < 0.0: m = SKARN; st.skarn = st.get("skarn", 0) + 1
					for f in fs:
						if Z <= f.box[2] or Z >= f.box[5] or not host_ok(f.k, info, cb, m, col, Z): continue
						if sdf(f, X, Y, Z) < 0.0:
							m = feat_mat(f, Z); st[f.k] = st.get(f.k, 0) + 1
				cells[base + z] = m
	return cells

## R2: intervaly [lo, hi) ve sloupci, kde d < 0 (bez podmínky hostitele) → {ci: [[lo, hi, i_feat], ...]}
func intervals_col(f: Dictionary, X: float, Y: float, z0: float, z1: float, evals: Array) -> Array:
	return march(func(z: float) -> float: return sdf(f, X, Y, z), z0, z1, evals)

## intervaly {fn(z) < 0} na [z0, z1]: krok |d| / LIP (≥ HMIN), změna znaménka → půlení 22× (~1e-8 m)
func march(fn: Callable, z0: float, z1: float, evals: Array) -> Array:
	var out := []
	var z := maxf(z0, 0.0); z1 = minf(z1, FN.BHT)
	var d: float = fn.call(z); evals[0] += 1
	var start := z if d < 0.0 else -1.0
	while z < z1:
		var z2 := minf(z + maxf(absf(d) / LIP, HMIN), z1)
		var d2: float = fn.call(z2); evals[0] += 1
		if (d < 0.0) != (d2 < 0.0):
			var a := z; var b := z2
			for it in 22:
				var mm := (a + b) * 0.5; var dm: float = fn.call(mm); evals[0] += 1
				if (dm < 0.0) == (d < 0.0): a = mm
				else: b = mm
			if d2 < 0.0: start = b
			else: out.append([start, b]); start = -1.0
		z = z2; d = d2
	if start >= 0.0: out.append([start, z1])
	return out

func r2_build(info: Dictionary, feats: Array, n: int, evals: Array) -> Dictionary:
	var c := BW_ / n
	var ox: float = info.slot.x * BW_; var oy: float = info.slot.y * BW_
	var iv := {}
	for x in n:
		for y in n:
			var X: float = ox + (x + 0.5) * c; var Y: float = oy + (y + 0.5) * c
			var lst := []
			for i in feats.size():
				var f: Dictionary = feats[i]
				if not (X > f.box[0] and X < f.box[3] and Y > f.box[1] and Y < f.box[4]): continue
				for e in intervals_col(f, X, Y, f.box[2], f.box[5], evals): lst.append([e[0], e[1], i])
			if not lst.is_empty(): iv[x * n + y] = lst
	return iv

## buňky z intervalů: geo_fn bez skarnu + skarn R1 + intervaly (pořadí útvarů jako R1)
func r2_fill(wf: Dictionary, info: Dictionary, feats: Array, iv: Dictionary, n: int) -> PackedByteArray:
	var c := BW_ / n; var nz := 4 * n
	var cells := PackedByteArray(); cells.resize(n * n * nz)
	var ox: float = info.slot.x * BW_; var oy: float = info.slot.y * BW_
	var bi := base_info(info); var cb := _contact(info)
	for x in n:
		for y in n:
			var X: float = ox + (x + 0.5) * c; var Y: float = oy + (y + 0.5) * c
			var col := FN.column(wf, bi, X, Y)
			var sk := skarn_col(wf, info, cb, col, X, Y) if not cb.is_empty() else []
			var lst: Array = iv.get(x * n + y, [])
			var base := (x * n + y) * nz
			for z in nz:
				var Z := (z + 0.5) * c
				var m := FN.material(bi, col, X, Y, Z)
				if m != 0:
					if not sk.is_empty() and host_ok("skarn", info, cb, m, col, Z) and skarn_d(info, cb, sk, X, Y, Z) < 0.0: m = SKARN
					var last := -1
					for e in lst:   # intervaly jsou po útvarech v pořadí feats → poslední platný vyhrává jako v R1
						if Z >= e[0] and Z < e[1] and int(e[2]) > last and host_ok(feats[e[2]].k, info, cb, m, col, Z):
							m = feat_mat(feats[e[2]], Z); last = int(e[2])
				cells[base + z] = m
	return cells

## pořadí útvarů v seznamu bloku: podle ORDER, pak gid (na pořadí v bloku nezávisí)
func sorted_feats(ws: Vector2i) -> Array:
	var fs := features(ws)
	fs.sort_custom(func(a, b): return ORDER.find(a.k) < ORDER.find(b.k) or (a.k == b.k and a.gid < b.gid))
	return fs

static func _hb(a: PackedByteArray) -> String:
	return a.hex_encode().sha256_text().substr(0, 16)

func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

# ---------------- části ----------------
var G := {}   # sdílený ostrov
func island() -> void:
	if not G.is_empty(): return
	T.reset()
	var g := gen_blocks(START)
	G.blocks = g[0]; G.order = g[1]; G.wf = wf_all()
	G.info = {}; G.feats = {}
	for s in G.order:
		G.info[s] = info_of(G.wf, G.blocks[s]); G.feats[s] = sorted_feats(G.info[s].slot)

## čas a paměť
func part_cas() -> Dictionary:
	island()
	var out := {"bloky": [], "utvary": {}}
	var tot := {}
	for s in G.order:
		var info: Dictionary = G.info[s]; var fs: Array = G.feats[s]
		var row := {"slot": [s.x, s.y], "utvaru": fs.size(), "druhy": {}}
		for f in fs: row.druhy[f.k] = row.druhy.get(f.k, 0) + 1
		for n in [16, 32]:
			var st := {}
			var t0 := Time.get_ticks_usec(); var cg := sample_r1(G.wf, info, fs, n, "geo", {}); var tg := _ms(t0)
			t0 = Time.get_ticks_usec(); var c1 := sample_r1(G.wf, info, fs, n, "r1", st); var t1 := _ms(t0)
			var ev := [0]
			t0 = Time.get_ticks_usec(); var iv := r2_build(info, fs, n, ev); var tb := _ms(t0)
			t0 = Time.get_ticks_usec(); var c2 := r2_fill(G.wf, info, fs, iv, n); var tf := _ms(t0)
			var cav := c1.duplicate()
			t0 = Time.get_ticks_usec(); var cr := FN.cavity_one(cav, n, G.wf, info, FN.CAV_AIR, 60, int(G.blocks[s].seed)); var tc := _ms(t0)
			use_feats = false; t0 = Time.get_ticks_usec(); sample_r1(G.wf, info, fs, n, "r1", {}); var ts := _ms(t0); use_feats = true
			use_skarn = false; t0 = Time.get_ticks_usec(); sample_r1(G.wf, info, fs, n, "r1", {}); var tu := _ms(t0); use_skarn = true
			skarn_noise = false; use_feats = false; var stn := {}; sample_r1(G.wf, info, fs, n, "r1", stn); skarn_noise = true; use_feats = true
			var niv := 0
			for k in iv: niv += iv[k].size()
			var r2bad := _ndiff(c1, c2)
			var skr0 := 0; var skr1 := 0
			for i in cg.size():
				if cg[i] == SKARN: skr0 += 1
				if c1[i] == SKARN: skr1 += 1
			row[str(n)] = {"ms_geo": tg, "ms_r1": t1, "ms_r1_jen_skarn": ts, "ms_r1_jen_utvary": tu, "skarn_r1_bez_sumu": stn.get("skarn", 0), "ms_r2_intervaly": tb, "ms_r2_bunky": tf, "ms_r0_dutina": tc,
				"r1_bunek": st, "skarn_r0": skr0, "skarn_r1": skr1, "r2_jine_nez_r1": r2bad, "intervalu": niv, "sloupcu_s_intervaly": iv.size(),
				"vyhodnoceni_sdf_r2": ev[0], "r0_dutina_bunek": cr.placed, "r0_dutina_schodek": cr.shortfall,
				"hash_r1": _hb(c1), "hash_r2": _hb(c2)}
			for k in ["ms_geo", "ms_r1", "ms_r1_jen_skarn", "ms_r1_jen_utvary", "ms_r2_intervaly", "ms_r2_bunky", "ms_r0_dutina"]:
				var kk := "%s_%d" % [k, n]; tot[kk] = tot.get(kk, 0.0) + row[str(n)][k] / G.order.size()
			print("čas %s n=%d: geo %.0f ms, R1 %.0f ms, R2 intervaly %.0f ms + buňky %.0f ms, R0 dutina %.0f ms; útvary %s; skarn R0 %d / R1 %d; R2≠R1 %d; intervalů %d" % [str(s), n, tg, t1, tb, tf, tc, JSON.stringify(st), skr0, skr1, r2bad, niv])
		# stejná dutina při 0,5 a 0,25 m? (buňky 0,25 m: zjemněná 0,5 m proti přímé 0,25 m, průnik / sjednocení)
		var g16 := sample_r1(G.wf, info, fs, 16, "geo", {}); var g32 := sample_r1(G.wf, info, fs, 32, "geo", {})
		var a16 := g16.duplicate(); var a32 := g32.duplicate()
		_mark(a16, FN.cavity_one(a16, 16, G.wf, info, FN.CAV_AIR, 60, int(G.blocks[s].seed)).cells)
		_mark(a32, FN.cavity_one(a32, 32, G.wf, info, FN.CAV_AIR, 60, int(G.blocks[s].seed)).cells)
		var r16 := sample_r1(G.wf, info, fs, 16, "r1", {}); var r32 := sample_r1(G.wf, info, fs, 32, "r1", {})
		var fa := P78.refine(a16); var fr := P78.refine(r16); var fg := P78.refine(g16)
		var io := {"r0": [0, 0], "r1": [0, 0]}
		for i in fa.size():
			var x0 := fa[i] == MARK; var x1 := a32[i] == MARK
			if x0 or x1: io.r0[1] += 1
			if x0 and x1: io.r0[0] += 1
			var y0 := fr[i] in [0, FN.CAV_WATER] and fg[i] != fr[i]; var y1 := r32[i] in [0, FN.CAV_WATER] and g32[i] != r32[i]
			if y0 or y1: io.r1[1] += 1
			if y0 and y1: io.r1[0] += 1
		row.dutina_05_proti_025 = {"r0_prunik_sjednoceni": io.r0, "r1_prunik_sjednoceni": io.r1}
		print("dutina 0,5 vs 0,25 m %s: R0 %s, R1 %s" % [str(s), str(io.r0), str(io.r1)])
		out.bloky.append(row)
	out.prumer_ms = tot
	# paměť: parametry útvaru (float64) a záznam intervalu
	var byk := {}
	for s in G.order:
		for f in G.feats[s]: byk[f.gid] = f
	for gid in byk:
		var f: Dictionary = byk[gid]
		var e: Dictionary = out.utvary.get(f.k, {"pocet": 0, "B": 0})
		e.pocet += 1; e.B = f.P.size() * 8 + 8 + 48   # parametry + seed + obálka (6 × f64)
		out.utvary[f.k] = e
	print("průměr ms: ", JSON.stringify(tot)); print("útvary: ", JSON.stringify(out.utvary))
	return out

## švy: stejný bod švu z obou sousedních bloků (útvary bez hostitele i plný materiál R1); řez dutiny R0 / R1 na švu
func part_svy() -> Dictionary:
	island()
	var out := {}
	var pairs := [[Vector2i(0, 0), Vector2i(1, 0), 0], [Vector2i(0, 1), Vector2i(1, 1), 0], [Vector2i(0, 0), Vector2i(0, 1), 1], [Vector2i(1, 0), Vector2i(1, 1), 1]]
	for pr in pairs:
		var A: Vector2i = pr[0]; var B: Vector2i = pr[1]; var ax: int = pr[2]
		var ia: Dictionary = G.info[A]; var ib: Dictionary = G.info[B]
		var fa: Array = G.feats[A]; var fb: Array = G.feats[B]
		var seam: float = (ia.slot.x + 1) * BW_ if ax == 0 else (ia.slot.y + 1) * BW_
		var other: float = ia.slot.y * BW_ if ax == 0 else ia.slot.x * BW_
		var bad := 0; var badm := 0; var inside := 0; var pts := 0
		var ba := base_info(ia); var bb := base_info(ib)
		for t in 64:
			var X: float = seam if ax == 0 else other + (t + 0.5) * 0.125
			var Y: float = other + (t + 0.5) * 0.125 if ax == 0 else seam
			var cola := FN.column(G.wf, ba, X, Y); var colb := FN.column(G.wf, bb, X, Y)
			var ska := skarn_col(G.wf, ia, _contact(ia), cola, X, Y); var skb := skarn_col(G.wf, ib, _contact(ib), colb, X, Y)
			for zz in 256:
				var Z := (zz + 0.5) * 0.125
				pts += 1
				var ga := -1; var gb := -1
				for f in fa:
					if X >= f.box[0] and X <= f.box[3] and Y >= f.box[1] and Y <= f.box[4] and Z > f.box[2] and Z < f.box[5] and sdf(f, X, Y, Z) < 0.0: ga = f.gid.hash() if false else fa.find(f) ; break
				for f in fb:
					if X >= f.box[0] and X <= f.box[3] and Y >= f.box[1] and Y <= f.box[4] and Z > f.box[2] and Z < f.box[5] and sdf(f, X, Y, Z) < 0.0: gb = fb.find(f); break
				var na: String = fa[ga].gid if ga >= 0 else ""; var nb: String = fb[gb].gid if gb >= 0 else ""
				if na != "": inside += 1
				if na != nb: bad += 1
				var ma := FN.material(ba, cola, X, Y, Z); var mb := FN.material(bb, colb, X, Y, Z)
				if ma != 0 and not ska.is_empty() and host_ok("skarn", ia, _contact(ia), ma, cola, Z) and skarn_d(ia, _contact(ia), ska, X, Y, Z) < 0.0: ma = SKARN
				if mb != 0 and not skb.is_empty() and host_ok("skarn", ib, _contact(ib), mb, colb, Z) and skarn_d(ib, _contact(ib), skb, X, Y, Z) < 0.0: mb = SKARN
				if ma != mb: badm += 1
		# řez dutiny na švu při 0,5 m: buňka dutiny u švu, za švem pevná nosná hornina (ne dutina)
		var cut := {}
		for mode in ["r0", "r1"]:
			var ca: PackedByteArray; var cbb: PackedByteArray
			if mode == "r1":
				ca = sample_r1(G.wf, ia, fa, 16, "r1", {}); cbb = sample_r1(G.wf, ib, fb, 16, "r1", {})
			else:
				ca = sample_r1(G.wf, ia, fa, 16, "geo", {}); cbb = sample_r1(G.wf, ib, fb, 16, "geo", {})
				var ra := FN.cavity_one(ca, 16, G.wf, ia, FN.CAV_AIR, 60, int(G.blocks[A].seed)); var rb := FN.cavity_one(cbb, 16, G.wf, ib, FN.CAV_AIR, 60, int(G.blocks[B].seed))
				ca = _mark(ca, ra.cells); cbb = _mark(cbb, rb.cells)
			var ga := sample_r1(G.wf, ia, fa, 16, "geo", {}); var gb := sample_r1(G.wf, ib, fb, 16, "geo", {})
			var k := 0; var cav := 0; var both := 0; var tot := 0
			for i in ca.size():
				if _iscav(ca[i], ga[i], mode): tot += 1
			for t in 16:
				for z in 64:
					var i1 := ((15 * 16 + t) * 64 + z) if ax == 0 else ((t * 16 + 15) * 64 + z)
					var i2 := ((0 * 16 + t) * 64 + z) if ax == 0 else ((t * 16 + 0) * 64 + z)
					var c1 := _iscav(ca[i1], ga[i1], mode); var c2 := _iscav(cbb[i2], gb[i2], mode)
					if c1 or c2: cav += 1
					if c1 and c2: both += 1
					if c1 != c2 and (ca[i1] if c2 else cbb[i2]) != 0: k += 1
			cut[mode] = {"dutina_bloku_A": tot, "bunek_dutiny_u_svu": cav, "pokracuje_pres_sev": both, "stena_na_svu": k}
		var key := "%s|%s" % [A, B]
		out[key] = {"bodu": pts, "utvar_jinak": bad, "bodu_v_utvaru": inside, "material_jinak": badm, "dutina_rez": cut}
		print("šev %s: bodů %d, útvar z obou stran jinak %d (v útvaru %d), materiál R1 jinak %d, řez dutiny %s" % [key, pts, bad, inside, badm, JSON.stringify(cut)])
	return out

const MARK := 251
static func _mark(c: PackedByteArray, lst: PackedInt32Array) -> PackedByteArray:
	for i in lst: c[i] = MARK
	return c

static func _iscav(m: int, g: int, mode: String) -> bool:
	if mode == "r0": return m == MARK
	return (m == 0 or m == FN.CAV_WATER) and g != m

## determinismus: 2× v procesu (otisky do --out porovná volající), float32
func part_det() -> Dictionary:
	island()
	var out := {}
	for s in G.order:
		var a := []
		for rep in 2:
			var fs := sorted_feats(G.info[s].slot)
			a.append(_hb(sample_r1(G.wf, G.info[s], fs, 32, "r1", {})))
		out[str(s)] = {"hash32": a[0], "stejne": a[0] == a[1]}
	print("det: ", JSON.stringify(out))
	return out

func part_f32() -> Dictionary:
	island()
	var out := {}
	for s in G.order:
		var info: Dictionary = G.info[s]
		var e := {}
		for n in [16, 32]:
			f32 = false; var a := sample_r1(G.wf, info, sorted_feats(info.slot), n, "r1", {})
			f32 = true; var b := sample_r1(G.wf, info, sorted_feats(info.slot), n, "r1", {})
			f32 = false
			# body na hraně: |d| < 1e-6 m v středech buněk uvnitř obálek
			var fs := sorted_feats(info.slot); var knife := 0; var tested := 0
			var c: float = BW_ / n
			for x in range(0, n, 2):
				for y in range(0, n, 2):
					var X: float = info.slot.x * BW_ + (x + 0.5) * c; var Y: float = info.slot.y * BW_ + (y + 0.5) * c
					for f in fs:
						if not (X > f.box[0] and X < f.box[3] and Y > f.box[1] and Y < f.box[4]): continue
						for z in 4 * n:
							var Z: float = (z + 0.5) * c
							if Z <= f.box[2] or Z >= f.box[5]: continue
							tested += 1
							if absf(sdf(f, X, Y, Z)) < 1e-6: knife += 1
			e[str(n)] = {"f32_jinych_bunek": _ndiff(a, b), "z": a.size(), "body_na_hrane_1e6": knife, "testovano": tested}
		out[str(s)] = e
		print("f32 %s: %s" % [str(s), JSON.stringify(e)])
	return out

## překryv E78: definice 0,5 m (zjemněná) proti 0,25 m z funkcí jen kvůli útvarům; kopání chodbou přes kras
func part_prekryv() -> Dictionary:
	island()
	var out := {}
	for s in G.order:
		var info: Dictionary = G.info[s]; var fs: Array = G.feats[s]
		var g16 := sample_r1(G.wf, info, fs, 16, "geo", {}); var g32 := sample_r1(G.wf, info, fs, 32, "geo", {})
		var r16 := sample_r1(G.wf, info, fs, 16, "r1", {}); var r32 := sample_r1(G.wf, info, fs, 32, "r1", {})
		var fg := P78.refine(g16); var fr := P78.refine(r16)
		var dg := 0; var dr := 0; var o := {}
		for i in fr.size():
			if g32[i] != fg[i]: dg += 1
			if r32[i] != fr[i]:
				dr += 1
				if (g32[i] == fg[i]): o[i] = r32[i]
		var b := Block.new(); b.slot = s; b.geo = r16; P78.attach(b)
		# chodba 0,25 m po x ve výšce středu prvního krasu bloku
		var noop := 0; var ops := 0
		var hit := -1
		for i in fr.size():
			if fr[i] == 0 and fg[i] != 0: hit = i; break
		if hit >= 0:
			var fy := (hit / P78.NZ) % P78.N; var fz := hit % P78.NZ
			for fx in 32:
				ops += 1
				if not P78.op(b, fx, fy, fz, 0): noop += 1
		var ov := P78.overlay(b)
		out[str(s)] = {"bunek_025": fr.size(), "jine_geo_bez_utvaru": dg, "jine_s_utvary": dr, "navic_jen_utvary": o.size(),
			"navic_runs_B": P78.enc_runs(o).size(), "navic_deflate_B": P78.deflate(P78.enc_runs(o)).size(),
			"chodba_op": ops, "chodba_noop_uz_dutina": noop, "prekryv_po_chodbe": ov.size()}
		print("překryv %s: %s" % [str(s), JSON.stringify(out[str(s)])])
	return out

## pásma vody: dutiny krasu jako intervaly ∩ nosná pásma karbonátu (ug_funkce.bands) při sloupcích 0,5 m
func part_pasma() -> Dictionary:
	island()
	var out := {}
	for s in G.order:
		var info: Dictionary = G.info[s]; var fs: Array = G.feats[s].filter(func(f): return f.k == "kras")
		var nb0 := 0; var nb1 := 0; var vol := 0.0; var volw := 0.0; var nsk := 0
		var ox: float = info.slot.x * BW_; var oy: float = info.slot.y * BW_
		var ev := [0]
		for x in 16:
			for y in 16:
				var X := ox + (x + 0.5) * 0.5; var Y := oy + (y + 0.5) * 0.5
				var col := FN.column(G.wf, info, X, Y)
				var bands: Array = UF.bands(info, col, X, Y)
				nb0 += bands.size()
				var cb := _contact(info)
				var sk := skarn_col(G.wf, info, cb, col, X, Y) if not cb.is_empty() else []
				var skv := [] if sk.is_empty() else march(func(z: float) -> float: return skarn_d(info, cb, sk, X, Y, z), 0.0, float(col.h), ev)
				var cuts := []
				for f in fs:
					if not (X > f.box[0] and X < f.box[3] and Y > f.box[1] and Y < f.box[4]): continue
					for e in intervals_col(f, X, Y, f.box[2], f.box[5], ev): cuts.append([e[0], e[1], f])
				var nb := 0
				for bd in bands:
					var lo: float = bd[0]; var hi: float = bd[1]
					if not (int(bd[2]) in KARST): nb += 1; continue
					hi = minf(hi, float(col.h) - 2.0)
					var pieces := [[float(bd[0]), float(bd[1]), 0]]
					if not cb.is_empty() and cb["in"].has(int(bd[2])):   # skarn = nerozpustný: vyřízne se z karbonátu dřív než kras
						for sv in skv:
							var np0 := []
							for p in pieces:
								var a0 := maxf(float(sv[0]), p[0]); var b0 := minf(float(sv[1]), p[1])
								if p[2] != 0 or b0 <= a0: np0.append(p); continue
								if a0 > p[0]: np0.append([p[0], a0, 0])
								np0.append([a0, b0, 3]); nsk += 1
								if b0 < p[1]: np0.append([b0, p[1], 0])
							pieces = np0
					for cu in cuts:
						var a := maxf(cu[0], lo); var b := minf(cu[1], hi)
						if b <= a: continue
						var np := []
						for p in pieces:
							if p[2] != 0 or b <= p[0] or a >= p[1]: np.append(p); continue
							var a1 := maxf(a, p[0]); var b1 := minf(b, p[1])
							if a1 > p[0]: np.append([p[0], a1, 0])
							var zw: float = cu[2].P[29]
							if a1 < zw: np.append([a1, minf(b1, zw), 2]); volw += (minf(b1, zw) - a1) * 0.25
							if b1 > zw: np.append([maxf(a1, zw), b1, 1])
							vol += (b1 - a1) * 0.25
							if b1 < p[1]: np.append([b1, p[1], 0])
						pieces = np
					nb += pieces.size()
				nb1 += nb
		var r16 := sample_r1(G.wf, info, G.feats[s], 16, "r1", {}); var r32 := sample_r1(G.wf, info, G.feats[s], 32, "r1", {})
		var c16 := 0; var c32 := 0
		var t16 := sample_r1(G.wf, info, G.feats[s], 16, "geo", {}); var t32 := sample_r1(G.wf, info, G.feats[s], 32, "geo", {})
		for i in r16.size():
			if FN.is_cavity(r16[i]) and not FN.is_cavity(t16[i]) or (r16[i] == 0 and t16[i] != 0): c16 += 1
		for i in r32.size():
			if (r32[i] == 0 and t32[i] != 0) or (r32[i] == FN.CAV_WATER and t32[i] != FN.CAV_WATER): c32 += 1
		out[str(s)] = {"pasem_bez": nb0, "pasem_se_skarnem_a_krasem": nb1, "skarnovych_pasem": nsk, "objem_intervaly_m3": vol, "z_toho_voda_m3": volw,
			"objem_bunky_05_m3": c16 * 0.125, "objem_bunky_025_m3": c32 * 0.015625, "sdf_vyhodnoceni": ev[0]}
		print("pásma %s: %s" % [str(s), JSON.stringify(out[str(s)])])
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/implicit_e84.gd": return
	var out := {}
	var parts := _arg("casti", "cas,svy,det,f32,prekryv,pasma").split(",")
	var t0 := Time.get_ticks_usec()
	if "cas" in parts: out.cas = part_cas()
	if "svy" in parts: out.svy = part_svy()
	if "det" in parts: out.det = part_det()
	if "f32" in parts: out.f32 = part_f32()
	if "prekryv" in parts: out.prekryv = part_prekryv()
	if "pasma" in parts: out.pasma = part_pasma()
	print("celkem %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
