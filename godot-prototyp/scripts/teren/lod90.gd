extends RefCounted
## E90: plán vzorkování a LOD (TODO Blok 4). Svět je funkce výšky v metrech (vzorec E49 svet/hruby_teren.gd bez sopky,
## natažený vodorovně a s větším reliéfem jen pro test 3 × 3 km). Vzorkuje se jen povrchová slupka po kouscích:
## 0,25 m u hráče, 0,5 m dál, 1 m ve zbytku okolí, hrubá data 8 m (svisle 1 m) jinde. Švy: bok na okraji kousku
## sahá k nejnižšímu skutečnému sousedovi přes hranici (sešití), bez sešití jen k sousedovi ve stejném rozlišení.
## Příznak p90_lod (výchozí vyp): bez něj se nic nestaví. Herní kód modul nepoužívá.
const BG = preload("res://scripts/teren/zaklad/block_gen.gd")

const P := {"p90_lod": false, "p90_seed": 49, "p90_dlazdic": 24, "p90_dlazdice_m": 128.0, "p90_kousek_m": 16.0,
	"p90_natazeni": 8.0, "p90_relief": 3.0, "p90_daleko_m": 8.0, "p90_daleko_svisle_m": 1.0,
	"p90_r0": 1, "p90_r1": 3, "p90_okoli": 1, "p90_seti": true, "p90_slupka": 3}
const UROVNE := [0.25, 0.5, 1.0]
const BARVY_UROVNI := [Color(0.95, 0.35, 0.3), Color(0.95, 0.75, 0.25), Color(0.35, 0.7, 0.95), Color(0.6, 0.6, 0.6)]

## ---------------------------------------------------------------- funkce světa
static func fn(p: Dictionary, tp: Dictionary) -> Dictionary:
	var seed := int(p.p90_seed)
	return {"nb": BG.noise(seed, "S8_BASE", 0, 0.03, 4), "nr": BG.noise(seed, "S8_RIDGE", 0, 0.045, 3),
		"nm": BG.noise(seed, "S8_MTN", 0, 0.018, 2), "nl": BG.noise(seed, "S8_LAKE", 0, 0.04, 2),
		"ref": float(tp.surf_ref), "base": float(tp.s8_base_amp), "mtn": float(tp.s8_mtn_amp), "lake": float(tp.s8_lake_amp),
		"bias": float(tp.s8_mtn_bias), "k": float(p.p90_natazeni), "rel": float(p.p90_relief)}

## výška E49 v buňkách 0,5 m v bodě mřížky E49 (1 bod = 1 m), stejný vzorec jako hruby_teren.run (s56 vyp, bez sopky, s ořezem)
static func h49(f: Dictionary, x: float, y: float) -> float:
	var m := smoothstep(0.05, 0.45, f.nm.get_noise_2d(x, y) + float(f.bias))
	var rd := 1.0 - absf(f.nr.get_noise_2d(x, y))
	var lk := smoothstep(0.35, 0.7, f.nl.get_noise_2d(x, y)) * (1.0 - m)
	return clampf(float(f.ref) + float(f.base) * f.nb.get_noise_2d(x, y) + m * float(f.mtn) * (rd * rd) - float(f.lake) * lk, 28.0, 60.0)   # E49: ořez 14–30 m

## výška povrchu v metrech v bodě světa (x, y v m) – nezávislá na rozlišení
static func h_m(f: Dictionary, x: float, y: float) -> float:
	var r := float(f.ref) * 0.5
	return r + (h49(f, x / float(f.k), y / float(f.k)) * 0.5 - r) * float(f.rel)

## materiál povrchu (jen vzhled): 0 tráva, 1 skála, 2 sníh, 3 písek
static func mat(f: Dictionary, h: float, sklon: float) -> int:
	var r := float(f.ref) * 0.5
	if h > r + 24.0: return 2
	if sklon > 0.9: return 1
	if h < r - 6.0: return 3
	return 0

const BARVY_MAT := [Color(0.45, 0.68, 0.3), Color(0.55, 0.52, 0.5), Color(0.95, 0.96, 0.98), Color(0.86, 0.8, 0.6)]
const BARVA_BOK := Color(0.55, 0.42, 0.32)

## ---------------------------------------------------------------- plán úrovní
## hráči (m) → {detail: {dlaždice: true}, kousky: {kousek: úroveň}, plochy: [{o, s, c, vq, lvl, klic}]}
static func plan(p: Dictionary, hraci: Array) -> Dictionary:
	var T := int(p.p90_dlazdic); var TM := float(p.p90_dlazdice_m); var KM := float(p.p90_kousek_m)
	var kpd := int(TM / KM)
	var detail := {}
	for h in hraci:
		var t := Vector2i(floori(h.x / TM), floori(h.y / TM))
		for dx in range(-int(p.p90_okoli), int(p.p90_okoli) + 1):
			for dy in range(-int(p.p90_okoli), int(p.p90_okoli) + 1):
				var q := t + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < T and q.y < T: detail[q] = true
	var kousky := {}; var plochy := []
	for t in detail:
		for i in kpd:
			for j in kpd:
				var k := Vector2i(t.x * kpd + i, t.y * kpd + j)
				var d := 1 << 30
				for h in hraci:
					var hk := Vector2i(floori(h.x / KM), floori(h.y / KM))
					d = mini(d, maxi(absi(k.x - hk.x), absi(k.y - hk.y)))
				var lvl := 0 if d <= int(p.p90_r0) else (1 if d <= int(p.p90_r1) else 2)
				kousky[k] = lvl
				plochy.append({"o": Vector2(k.x * KM, k.y * KM), "s": KM, "c": float(UROVNE[lvl]), "vq": float(UROVNE[lvl]), "lvl": lvl, "klic": "k%d,%d" % [k.x, k.y]})
	for x in T:
		for y in T:
			if detail.has(Vector2i(x, y)): continue
			plochy.append({"o": Vector2(x * TM, y * TM), "s": TM, "c": float(p.p90_daleko_m), "vq": float(p.p90_daleko_svisle_m), "lvl": 3, "klic": "t%d,%d" % [x, y]})
	return {"detail": detail, "kousky": kousky, "plochy": plochy, "T": T, "TM": TM, "KM": KM}

## rozlišení v bodě světa: [c, vq, lvl]
static func uroven_v(pl: Dictionary, p: Dictionary, x: float, y: float) -> Array:
	var t := Vector2i(floori(x / pl.TM), floori(y / pl.TM))
	if pl.detail.has(t):
		var lvl: int = pl.kousky[Vector2i(floori(x / pl.KM), floori(y / pl.KM))]
		return [float(UROVNE[lvl]), float(UROVNE[lvl]), lvl]
	return [float(p.p90_daleko_m), float(p.p90_daleko_svisle_m), 3]

## vršek sloupce, do kterého padne bod (x, y), v rozlišení c (sloupce zarovnané na mřížku světa), svisle po vq
static func vrsek(f: Dictionary, c: float, vq: float, x: float, y: float) -> float:
	var cx := (floorf(x / c) + 0.5) * c; var cy := (floorf(y / c) + 0.5) * c
	return floorf(h_m(f, cx, cy) / vq) * vq

## spodek boku na okraji plochy v bodě (x, y) těsně za hranicí: se sešitím nejnižší skutečný soused podél úseku délky d,
## bez sešití soused ve vlastním rozlišení
static func spodek_okraje(f: Dictionary, pl: Dictionary, p: Dictionary, c: float, vq: float, x: float, y: float, tx: float, ty: float, d: float, sesit: bool) -> float:
	if not sesit: return vrsek(f, c, vq, x, y)
	var u := uroven_v(pl, p, x, y)
	var st := minf(c, float(u[0]))
	var n := maxi(1, int(round(d / st)))
	var lo := INF
	for k in n:
		var s := (float(k) + 0.5) * st
		lo = minf(lo, vrsek(f, float(u[0]), float(u[1]), x + tx * s, y + ty * s))
	return lo

## ---------------------------------------------------------------- stavba plochy
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## {vrsky: PackedFloat32Array, slupka: PackedByteArray, verts, norms, cols, tri, ms_fn, ms_sit}
static func stavba(f: Dictionary, pl: Dictionary, p: Dictionary, a: Dictionary, sesit: bool, barva_urovne := false) -> Dictionary:
	var c: float = a.c; var vq: float = a.vq; var o: Vector2 = a.o
	var n := int(round(float(a.s) / c)); var N := n + 2
	var t0 := Time.get_ticks_usec()
	var hh := PackedFloat32Array(); hh.resize(N * N)   # výška funkce středů sloupců (+ prstenec ve vlastním rozlišení)
	for i in N:
		for j in N:
			hh[i * N + j] = h_m(f, o.x + (i - 0.5) * c, o.y + (j - 0.5) * c)
	var top := PackedFloat32Array(); top.resize(N * N)
	for k in N * N: top[k] = floorf(hh[k] / vq) * vq
	var shell := PackedByteArray(); shell.resize(n * n * int(p.p90_slupka))
	var vrsky := PackedFloat32Array(); vrsky.resize(n * n)
	for i in n:
		for j in n:
			var k := (i + 1) * N + j + 1
			var sk := maxf(absf(hh[k + N] - hh[k - N]), absf(hh[k + 1] - hh[k - 1])) / (2.0 * c)
			var m := mat(f, hh[k], sk)
			vrsky[i * n + j] = top[k]
			for z in int(p.p90_slupka): shell[(i * n + j) * int(p.p90_slupka) + z] = m if z == 0 else 4   # 4 = podloží (hlína/skála)
	var ms_fn := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var V := PackedVector3Array(); var Nn := PackedVector3Array(); var C := PackedColorArray()
	var tint: Color = BARVY_UROVNI[int(a.lvl)]
	for i in n:
		for j in n:
			var k := (i + 1) * N + j + 1
			var x0 := o.x + i * c; var y0 := o.y + j * c; var tp := top[k]
			var col: Color = BARVY_MAT[shell[(i * n + j) * int(p.p90_slupka)]]
			if barva_urovne: col = col.lerp(tint, 0.55)
			_quad(V, Nn, C, Vector3(x0, tp, y0), Vector3(x0 + c, tp, y0), Vector3(x0 + c, tp, y0 + c), Vector3(x0, tp, y0 + c), Vector3.UP, col)   # po směru hodin shora (přední strana v Godotu)
			var bok := BARVA_BOK.lerp(tint, 0.55) if barva_urovne else BARVA_BOK
			for d in 4:
				var dv: Vector2i = DIRS[d]
				var ni := i + dv.x; var nj := j + dv.y
				var bot: float
				if ni >= 0 and nj >= 0 and ni < n and nj < n:
					bot = top[(ni + 1) * N + nj + 1]
				else:
					# bod těsně za hranicí na začátku hrany a směr podél hrany
					var ex := x0 + (c + 0.001 if dv.x > 0 else (-0.001 if dv.x < 0 else 0.0))
					var ey := y0 + (c + 0.001 if dv.y > 0 else (-0.001 if dv.y < 0 else 0.0))
					var tx := 0.0 if dv.x != 0 else 1.0; var ty := 1.0 if dv.x != 0 else 0.0
					bot = spodek_okraje(f, pl, p, c, vq, ex, ey, tx, ty, c, sesit) if not (dv.x == 0 and dv.y == 0) else tp
				if bot < tp:
					_wall(V, Nn, C, x0, y0, c, d, bot, tp, bok)
	var ms_sit := (Time.get_ticks_usec() - t0) / 1000.0
	return {"vrsky": vrsky, "slupka": shell, "V": V, "N": Nn, "C": C, "tri": V.size() / 3, "ms_fn": ms_fn, "ms_sit": ms_sit, "n": n}

static func _quad(V: PackedVector3Array, Nn: PackedVector3Array, C: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	V.append_array([a, b, c, a, c, d])
	for k in 6: Nn.append(nrm); C.append(col)

static func _wall(V: PackedVector3Array, Nn: PackedVector3Array, C: PackedColorArray, x0: float, y0: float, c: float, d: int, lo: float, hi: float, col: Color) -> void:
	match d:
		0: _quad(V, Nn, C, Vector3(x0 + c, hi, y0), Vector3(x0 + c, hi, y0 + c), Vector3(x0 + c, lo, y0 + c), Vector3(x0 + c, lo, y0), Vector3.RIGHT, col)
		1: _quad(V, Nn, C, Vector3(x0, hi, y0 + c), Vector3(x0, hi, y0), Vector3(x0, lo, y0), Vector3(x0, lo, y0 + c), Vector3.LEFT, col)
		2: _quad(V, Nn, C, Vector3(x0 + c, hi, y0 + c), Vector3(x0, hi, y0 + c), Vector3(x0, lo, y0 + c), Vector3(x0 + c, lo, y0 + c), Vector3.BACK, col)
		3: _quad(V, Nn, C, Vector3(x0, hi, y0), Vector3(x0 + c, hi, y0), Vector3(x0 + c, lo, y0), Vector3(x0, lo, y0), Vector3.FORWARD, col)

static func mesh(st: Dictionary) -> ArrayMesh:
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st.V; arr[Mesh.ARRAY_NORMAL] = st.N; arr[Mesh.ARRAY_COLOR] = st.C
	var m := ArrayMesh.new()
	if st.V.size() > 0: m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## ---------------------------------------------------------------- díry na švech
## pro hrany +x a +y každé plochy (každá hranice jednou): krok 0,25 m, díra = svislý úsek mezi vrškem jedné strany a vrškem
## druhé, který nepokryje bok ani jedné strany. Vrací {useku, s_dirou, plocha_m2, max_m, skok_max_m, kvant_max_m}
static func diry(f: Dictionary, pl: Dictionary, p: Dictionary, a: Dictionary, sesit: bool) -> Dictionary:
	var r := {"useku": 0, "s_dirou": 0, "plocha_m2": 0.0, "max_m": 0.0, "skok_max_m": 0.0, "ruzne_urovne": 0, "pary": {}}
	var c: float = a.c; var vq: float = a.vq; var o: Vector2 = a.o; var S: float = a.s
	var TOT := float(pl.T) * float(pl.TM)
	var st := 0.25
	for d in [0, 2]:
		var ex := o.x + S if d == 0 else o.x; var ey := o.y if d == 0 else o.y + S
		if (d == 0 and ex >= TOT) or (d == 2 and ey >= TOT): continue
		var tx := 0.0 if d == 0 else 1.0; var ty := 1.0 if d == 0 else 0.0
		var m := int(round(S / st))
		for k in m:
			var s := (k + 0.5) * st
			var px := ex + tx * s; var py := ey + ty * s
			var ub: Array = uroven_v(pl, p, px + 0.001, py + 0.001)
			var ta := vrsek(f, c, vq, px - (0.001 if d == 0 else 0.0), py - (0.001 if d == 2 else 0.0))
			var tb := vrsek(f, float(ub[0]), float(ub[1]), px + (0.001 if d == 0 else 0.0), py + (0.001 if d == 2 else 0.0))
			# spodek boku strany A v tomto bodě: celý sloupec A (úsek délky c od začátku sloupce)
			var sa0 := floorf((s) / c) * c
			var ba := spodek_okraje(f, pl, p, c, vq, ex + (0.001 if d == 0 else 0.0) + tx * sa0, ey + (0.001 if d == 2 else 0.0) + ty * sa0, tx, ty, c, sesit)
			var cb := float(ub[0])
			var sb0 := floorf(s / cb) * cb
			var bb := spodek_okraje(f, pl, p, cb, float(ub[1]), ex - (0.001 if d == 0 else 0.0) + tx * sb0, ey - (0.001 if d == 2 else 0.0) + ty * sb0, tx, ty, cb, sesit)
			var hole := maxf(0.0, minf(ta, ba) - tb) if ta > tb else maxf(0.0, minf(tb, bb) - ta)
			r.useku += 1
			var pk := "%d-%d" % [mini(int(a.lvl), int(ub[2])), maxi(int(a.lvl), int(ub[2]))]
			if not r.pary.has(pk): r.pary[pk] = {"useku": 0, "s_dirou": 0, "plocha_m2": 0.0, "skok_max_m": 0.0, "dira_max_m": 0.0}
			var pp: Dictionary = r.pary[pk]
			pp.useku += 1; pp.skok_max_m = maxf(pp.skok_max_m, absf(ta - tb))
			if hole > 1e-6: pp.s_dirou += 1; pp.plocha_m2 += hole * st; pp.dira_max_m = maxf(pp.dira_max_m, hole)
			if int(ub[2]) != int(a.lvl): r.ruzne_urovne += 1
			r.skok_max_m = maxf(r.skok_max_m, absf(ta - tb))
			if hole > 1e-6:
				r.s_dirou += 1; r.plocha_m2 += hole * st; r.max_m = maxf(r.max_m, hole)
	return r
