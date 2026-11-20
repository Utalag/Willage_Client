@tool
class_name ShoreFields
extends RefCounted
## Data povrchu jednoho bloku pro duální mřížku a doplňky pobřeží (jen vzhled, data bloků se nemění).
## Čte sloupce bloku i sousedů (včetně úhlopříčných) do okna (16 + 2·pad)², takže sousední bloky vidí stejná
## data a na hranicích nevznikají švy [1][2]. Obsahuje:
##  - třídu sloupce: GRASS / SAND (měkký povrch nad vodou), BED (měkký povrch pod hladinou), HARD (skála, sníh,
##    hlína po kopání, sloupec pod stavbou nebo cestou), NONE (mlha / mimo ostrov);
##  - masku duálních dlaždic: roh dlaždice = střed buňky; dlaždice je duální, když jsou všechny 4 rohy měkké
##    a rozdíl jejich výšek je nejvýš slope_max_layers vrstev (jinak ji kreslí kostkový mesher, stěna na buňkách);
##  - výšku povrchu (duální: interpolace mezi středy, jinak schod buňky), váhy materiálů (marching squares =
##    bilineární váhy rohů + šum + ostrá hranice, stejně jako shader);
##  - vzdálenostní pole (chamfer) k čáře vody, od okraje louky a k louce → textura pro shadery [15][21].
## Hladina vody: v datech prototypu voda není; sloupec louky/písku pod vrstvou water_lz se jen kreslí jako dno.

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const Mat = preload("res://scripts/mat.gd")
const BS := J.BS
const BH := J.BH
const CELL_H := J.CELL_M
enum { NONE, GRASS, SAND, BED, HARD }

var slot := Vector2i.ZERO
var pad := 4
var G := 24
var FP := 4
var T := 96
var wl := 15.0
var ox := 0
var oz := 0
var cls := PackedByteArray()      # G·G, index pz·G + px
var hl := PackedInt32Array()      # výška sloupce ve vrstvách (NONE = výška souseda, kvůli normálám)
var dual := PackedByteArray()     # (G-1)², dlaždice (i, j) s rohy (i, j) … (i+1, j+1), index j·(G-1) + i
var hgt := PackedFloat32Array()   # T·T výška povrchu (m)
var gw := PackedFloat32Array()    # T·T váha trávy po zostření
var sd := PackedFloat32Array()    # T·T vzdálenost k čáře vody (buňky; + souš, − voda)
var ged := PackedFloat32Array()   # T·T vzdálenost od okraje louky (uvnitř trávy)
var dtg := PackedFloat32Array()   # T·T vzdálenost k louce (mimo trávu)
var splat_tex: ImageTexture
var field_tex: ImageTexture
var has_water := false
var any_dual := false
var build_ms := 0.0
var _ease_k := 1.0
var _dn := 0.12
var _dsf := 0.06

func _init(island, s: Vector2i, p) -> void:
	var t0 := Time.get_ticks_usec()
	slot = s
	pad = p.field_pad
	G = BS + 2 * pad
	FP = p.field_px
	T = G * FP
	wl = p.water_y()
	_ease_k = p.dual_ease
	_dn = p.dual_noise
	_dsf = p.dual_soft
	ox = s.x * BS - pad
	oz = s.y * BS - pad
	_read_columns(island, p)
	_tiles(p)
	_fields()
	build_ms = (Time.get_ticks_usec() - t0) / 1000.0

# ------------------------------------------------------------------ sloupce a dlaždice
func _read_columns(island, p) -> void:
	cls.resize(G * G)
	hl.resize(G * G)
	var occ: Dictionary = island.occupied
	for pz in G:
		for px in G:
			var gx := ox + px
			var gz := oz + pz
			var bs := Vector2i(floori(gx / float(BS)), floori(gz / float(BS)))
			var i := pz * G + px
			if not island.blocks.has(bs):
				cls[i] = NONE
				hl[i] = -1
				continue
			var b = island.blocks[bs]
			var lx := gx - bs.x * BS
			var ly := gz - bs.y * BS
			var h: int = b.hm[lx * BS + ly]
			hl[i] = h
			var top: int = b.cells[(lx * BS + ly) * BH + h - 1] if h > 0 else Mat.AIR
			if (top == Mat.GRASS or top == Mat.SAND) and not occ.has(Vector2i(gx, gz)):
				if p.water_enabled and h < p.water_lz:
					cls[i] = BED
					has_water = true
				else:
					cls[i] = GRASS if top == Mat.GRASS else SAND
			else:
				cls[i] = HARD
				if p.water_enabled and h * CELL_H < wl:
					has_water = true
	# mlha: výška nejbližšího platného souseda (jen pro normály na okraji, dlaždice tam stejně nejsou duální)
	for it in 3:
		for i in G * G:
			if hl[i] >= 0:
				continue
			var x := i % G; var z := i / G
			var best := -1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x; var nz: int = z + d.y
				if nx >= 0 and nz >= 0 and nx < G and nz < G:
					best = maxi(best, hl[nz * G + nx])
			if best >= 0:
				hl[i] = -2 - best   # dočasně záporně (ať se v tomto průchodu nešíří dál)
		for i in G * G:
			if hl[i] <= -2:
				hl[i] = -2 - hl[i]
	for i in G * G:
		if hl[i] < 0:
			hl[i] = 32

static func soft(c: int) -> bool:
	return c == GRASS or c == SAND or c == BED

func _tiles(p) -> void:
	var G1 := G - 1
	dual.resize(G1 * G1)
	var mx: int = p.slope_max_layers
	for j in G1:
		for i in G1:
			var a := j * G + i
			var ok: bool = p.dual_enabled and soft(cls[a]) and soft(cls[a + 1]) and soft(cls[a + G]) and soft(cls[a + G + 1])
			if ok:
				var h0 := hl[a]; var h1 := hl[a + 1]; var h2 := hl[a + G]; var h3 := hl[a + G + 1]
				ok = maxi(maxi(h0, h1), maxi(h2, h3)) - mini(mini(h0, h1), mini(h2, h3)) <= mx
			dual[j * G1 + i] = 1 if ok else 0
			if ok and i >= pad - 1 and j >= pad - 1 and i < pad + BS and j < pad + BS:
				any_dual = true

## je duální dlaždice s levým horním rohem v buňce (i, j) okna?
func is_dual(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= G - 1 or j >= G - 1:
		return false
	return dual[j * (G - 1) + i] == 1

## maska pro kostkový mesher: dlaždice ti, tj ∈ −1..15 (lokálně v bloku), index (ti + 1) · 17 + (tj + 1)
func cell_mask() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(17 * 17)
	for ti in range(-1, BS):
		for tj in range(-1, BS):
			out[(ti + 1) * 17 + (tj + 1)] = 1 if is_dual(ti + pad, tj + pad) else 0
	return out

# ------------------------------------------------------------------ výška a materiál (souřadnice okna, buňka = 1)
func _ease(t: float) -> float:
	return lerpf(t, t * t * (3.0 - 2.0 * t), _ease_k)

func hcell(i: int, j: int) -> float:
	return hl[clampi(j, 0, G - 1) * G + clampi(i, 0, G - 1)] * CELL_H

## duální výška (interpolace mezi středy buněk); používá se ve vrcholech sítě i mimo duální dlaždice (normály)
func dual_h(x: float, z: float) -> float:
	var gx := x - 0.5; var gz := z - 0.5
	var i0 := floori(gx); var j0 := floori(gz)
	var fx := _ease(gx - i0); var fz := _ease(gz - j0)
	return lerpf(lerpf(hcell(i0, j0), hcell(i0 + 1, j0), fx), lerpf(hcell(i0, j0 + 1), hcell(i0 + 1, j0 + 1), fx), fz)

## vykreslená výška: v duální dlaždici interpolace, jinak schod buňky
func height(x: float, z: float) -> float:
	if is_dual(floori(x - 0.5), floori(z - 0.5)):
		return dual_h(x, z)
	return hcell(floori(x), floori(z))

## váhy (tráva, písek, dno) po šumu a zostření – stejný výpočet jako terrain_surface.gdshader
func weights(x: float, z: float) -> Vector3:
	var i0 := floori(x - 0.5); var j0 := floori(z - 0.5)
	var w := Vector3.ZERO
	if is_dual(i0, j0):
		var c0: int = cls[clampi(j0, 0, G - 1) * G + clampi(i0, 0, G - 1)]
		if c0 == cls[clampi(j0, 0, G - 1) * G + clampi(i0 + 1, 0, G - 1)] \
				and c0 == cls[clampi(j0 + 1, 0, G - 1) * G + clampi(i0, 0, G - 1)] \
				and c0 == cls[clampi(j0 + 1, 0, G - 1) * G + clampi(i0 + 1, 0, G - 1)]:
			return _onehot(i0, j0)   # jednotná dlaždice: šum ani zostření nemění výsledek
		var fx := x - 0.5 - i0; var fz := z - 0.5 - j0
		w += _onehot(i0, j0) * (1.0 - fx) * (1.0 - fz)
		w += _onehot(i0 + 1, j0) * fx * (1.0 - fz)
		w += _onehot(i0, j0 + 1) * (1.0 - fx) * fz
		w += _onehot(i0 + 1, j0 + 1) * fx * fz
	else:
		return _onehot(floori(x), floori(z))
	var nv := vnoise((ox + x) * 0.9, (oz + z) * 0.9) * 2.0 - 1.0
	w.x += _dn * nv
	w.y -= _dn * nv * 0.5
	var wm := maxf(w.x, maxf(w.y, w.z))
	w = Vector3(clampf((w.x - wm + _dsf) / _dsf, 0, 1), clampf((w.y - wm + _dsf) / _dsf, 0, 1), clampf((w.z - wm + _dsf) / _dsf, 0, 1))
	var s := w.x + w.y + w.z
	return w / maxf(s, 1e-5)

func _onehot(i: int, j: int) -> Vector3:
	match cls[clampi(j, 0, G - 1) * G + clampi(i, 0, G - 1)]:
		GRASS: return Vector3(1, 0, 0)
		SAND: return Vector3(0, 1, 0)
		BED: return Vector3(0, 0, 1)
	return Vector3.ZERO

func cls_at(x: float, z: float) -> int:
	return cls[clampi(floori(z), 0, G - 1) * G + clampi(floori(x), 0, G - 1)]

# --- lokální souřadnice bloku (0..16) pro trávu a vegetaci
func height_local(lx: float, lz: float) -> float:
	return height(lx + pad, lz + pad)

func grass_local(lx: float, lz: float) -> float:
	return weights(lx + pad, lz + pad).x

func _tex(arr: PackedFloat32Array, lx: float, lz: float) -> float:
	var tx := clampi(int((lx + pad) * FP), 0, T - 1)
	var tz := clampi(int((lz + pad) * FP), 0, T - 1)
	return arr[tz * T + tx]

func ged_local(lx: float, lz: float) -> float:
	return _tex(ged, lx, lz)

func dtg_local(lx: float, lz: float) -> float:
	return _tex(dtg, lx, lz)

func wet_local(lx: float, lz: float) -> bool:
	return height_local(lx, lz) < wl + 0.02

## rychlá cesta pro trávu: výška sloupce (m), je-li celé okolí 3×3 rovná louka daleko od okraje
## (pak výška = schod, váha trávy 1, ztenčení 0, sucho); jinak −1 → přesný výpočet po trsech
var _simple := PackedFloat32Array()
func simple_col(lx: int, ly: int, min_ged: float) -> float:
	if _simple.is_empty():
		_simple.resize(BS * BS)
		for x in BS:
			for z in BS:
				var i := x + pad; var j := z + pad
				var h0: int = hl[j * G + i]
				var ok: bool = cls[j * G + i] == GRASS and h0 * CELL_H >= wl + 0.02
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						var q: int = (j + dj) * G + i + di
						if cls[q] != GRASS or hl[q] != h0:
							ok = false
				_simple[x * BS + z] = ged_local(x + 0.5, z + 0.5) - 0.75 if ok else -1.0
	var g: float = _simple[lx * BS + ly]
	if g < 0.0 or g < min_ged:
		return -1.0
	return hl[(ly + pad) * G + lx + pad] * CELL_H

## shoda s shaderem (hash12 / vnoise z surface_common.gdshaderinc)
static func _fr(v: float) -> float:
	return v - floor(v)

static func hash12(px: float, py: float) -> float:
	var a := _fr(px * 0.1031); var b := _fr(py * 0.1031); var c := a
	var d := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += d; b += d; c += d
	return _fr((a + b) * c)

static func vnoise(x: float, y: float) -> float:
	var ix := floorf(x); var iy := floorf(y)
	var fx := x - ix; var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx); var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(hash12(ix, iy), hash12(ix + 1, iy), ux), lerpf(hash12(ix, iy + 1), hash12(ix + 1, iy + 1), ux), uy)

# ------------------------------------------------------------------ vzdálenostní pole a textury
func _fields() -> void:
	var n := T * T
	hgt.resize(n); gw.resize(n)
	var water := PackedByteArray(); water.resize(n)
	var land := PackedByteArray(); land.resize(n)
	var notgrass := PackedByteArray(); notgrass.resize(n)
	var isgrass := PackedByteArray(); isgrass.resize(n)
	var nw := 0; var nl := 0; var nng := 0; var ng := 0
	var inv := 1.0 / FP
	for tz in T:
		var z := (tz + 0.5) * inv
		for tx in T:
			var x := (tx + 0.5) * inv
			var i := tz * T + tx
			var c := cls_at(x, z)
			var h := height(x, z)
			hgt[i] = h
			if c == NONE:
				continue
			var w := weights(x, z) if soft(c) or is_dual(floori(x - 0.5), floori(z - 0.5)) else Vector3.ZERO
			gw[i] = w.x
			var wet := h < wl
			if wet:
				water[i] = 1; nw += 1
			else:
				land[i] = 1; nl += 1
			if soft(c):
				if wet or w.x < 0.5:
					notgrass[i] = 1; nng += 1
				elif not wet:
					isgrass[i] = 1; ng += 1
	var to_water := _chamfer(water, nw)
	var to_land := _chamfer(land, nl)
	var to_edge := _chamfer(notgrass, nng)
	var to_grass := _chamfer(isgrass, ng)
	sd.resize(n); ged.resize(n); dtg.resize(n)
	var fdata := PackedFloat32Array(); fdata.resize(n * 4)
	for i in n:
		sd[i] = clampf((to_water[i] if land[i] == 1 else -to_land[i]) * inv, -8.0, 8.0)
		ged[i] = minf(to_edge[i] * inv, 8.0)
		dtg[i] = minf(to_grass[i] * inv, 8.0)
		fdata[i * 4] = hgt[i]; fdata[i * 4 + 1] = sd[i]; fdata[i * 4 + 2] = ged[i]; fdata[i * 4 + 3] = dtg[i]
	var fi := Image.create_from_data(T, T, false, Image.FORMAT_RGBAF, fdata.to_byte_array())
	fi.convert(Image.FORMAT_RGBAH)
	field_tex = ImageTexture.create_from_image(fi)
	var sdata := PackedByteArray(); sdata.resize(G * G * 4)
	for i in G * G:
		var c := cls[i]
		sdata[i * 4] = 255 if c == GRASS else 0
		sdata[i * 4 + 1] = 255 if c == SAND else 0
		sdata[i * 4 + 2] = 255 if c == BED else 0
		sdata[i * 4 + 3] = 255 if soft(c) else 0
	splat_tex = ImageTexture.create_from_image(Image.create_from_data(G, G, false, Image.FORMAT_RGBA8, sdata))

## dvouprůchodová chamfer vzdálenost v texelech k nejbližšímu texelu se src = 1 (okraj okna není hranice);
## bez zdroje vrací „daleko“ (přeskočí výpočet – louka bez vody a písku nic nepočítá)
func _chamfer(src: PackedByteArray, count: int) -> PackedFloat32Array:
	var dd := PackedFloat32Array(); dd.resize(T * T)
	if count == 0:
		dd.fill(1e4)
		return dd
	const INF := 1e6
	const R2 := 1.4142
	for i in T * T:
		dd[i] = 0.0 if src[i] == 1 else INF
	for z in T:
		for x in T:
			var i := z * T + x
			var v := dd[i]
			if v == 0.0:
				continue
			if x > 0: v = minf(v, dd[i - 1] + 1.0)
			if z > 0:
				v = minf(v, dd[i - T] + 1.0)
				if x > 0: v = minf(v, dd[i - T - 1] + R2)
				if x < T - 1: v = minf(v, dd[i - T + 1] + R2)
			dd[i] = v
	for z in range(T - 1, -1, -1):
		for x in range(T - 1, -1, -1):
			var i := z * T + x
			var v := dd[i]
			if v == 0.0:
				continue
			if x < T - 1: v = minf(v, dd[i + 1] + 1.0)
			if z < T - 1:
				v = minf(v, dd[i + T] + 1.0)
				if x < T - 1: v = minf(v, dd[i + T + 1] + R2)
				if x > 0: v = minf(v, dd[i + T - 1] + R2)
			dd[i] = v
	return dd

## obdélník okna ve světě (pro shadery): počátek XZ, velikost XZ
func rect() -> Vector4:
	return Vector4(ox, oz, G, G)
