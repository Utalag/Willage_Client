@tool
## KOPIE z lozika-studie/scripts/ore_v0.gd (gen-v3-study-4) pro prototyp; změny jen cesty preload.
extends RefCounted
## ore-v0 „semínko se zásobou“ (návrh Willage-backend, lozika-a-zily-v0.md) + cílový souhrn (Jan 18:24–18:25):
## server při vydání bloku určí přesný počet buněk každé rudy (target), klient je rozmístí tvary ore-v0
## a musí umístit PŘESNĚ target buněk. Když semínka nestačí, běží záložní stupně L1–L4; zbytek = výslovný schodek (L5).
## Bitová shoda C# ↔ GDScript už není potřeba (Jan 18:24), náhoda je ale dál ze seedu → testy se dají zopakovat.
## Osy jako generátor: index (lx*16+ly)*64+lz, lx, ly vodorovně 0..15, lz výška 0..63.

const Mat = preload("res://scripts/mat.gd")
const H = preload("res://scripts/stable_hash.gd")
const BS := 16
const BH := 64
const N := BS * BS * BH

# směry v pevném pořadí: +x, −x, +y, −y, +z, −z  (x = lx, y = ly, z = lz)
const DX := [1, -1, 0, 0, 0, 0]
const DY := [0, 0, 1, -1, 0, 0]
const DZ := [0, 0, 0, 0, 1, -1]
const REV := [1, 0, 3, 2, 5, 4]

# pravděpodobnosti jako u16: přijmout, když next_u16() < P;  P = floor(p · 65536)
const P_POCKET := 36044      # 0,55
const P_LAYER_H := 52428     # 0,80
const P_LAYER_V := 6553      # 0,10
const P_VEIN_KEEP := 45875   # 0,70
const PLACE_TRIES := 8
const VEIN_RETRIES := 4      # žíla: kolikrát zkusit jiný směr, když je cíl blokovaný
const MAX_SEEDS := 64        # strop semínek jedné rudy v L0
const EXTRA_SEEDS := 16      # strop dalších semínek na jeden záložní stupeň

## Nikdy hostitel: vzduch (jeskyně se nezasypou), mlha, povrch (tráva, sníh) a rudy. Základní jíl (CLAY) hostitel být může,
## ložiskový jíl má od 18:34 vlastní ID (CLAY_DEPOSIT), takže se souhrny nepletou.
## (mlha vyjmuta 19:18: gen-v3 ji používá jako vnitřní UNSET; žádný recept ore-v0 mlhu jako hostitele nemá, chování ore-v0 beze změny)
const NEVER := [Mat.AIR, Mat.GRASS, Mat.SNOW, Mat.COPPER, Mat.IRON, Mat.CLAY_DEPOSIT]

## Katalog: výchozí parametry tvarů (Willage-backend 18:34, bod d: parametry v receptu, výchozí v katalogu).
## Zásoby sníženy na úroveň šumových rud prototypu (Cu ~16–23, Fe ~25 buněk na blok), aby rarita-v2 zůstala.
## relax = pořadí uvolnění hostitele v L4 (po úrovních).
const CATALOG := {
	"copper": {"name": "copper", "material": Mat.COPPER, "host": [Mat.GRANITE, Mat.LIMESTONE], "seeds": [1, 2], "supply": [8, 18],
		"lz": [8, 40], "shape": "vein", "branch": 5243, "dirW": {"horiz": 2, "vert": 3},
		"relax": [[Mat.BASALT], [Mat.DIRT, Mat.SAND]]},
	"iron": {"name": "iron", "material": Mat.IRON, "host": [Mat.GRANITE, Mat.BASALT], "seeds": [1, 2], "supply": [12, 22],
		"lz": [4, 36], "shape": "pocket", "relax": [[Mat.LIMESTONE], [Mat.DIRT, Mat.SAND]]},
	"clay": {"name": "clay", "material": Mat.CLAY_DEPOSIT, "host": [Mat.DIRT, Mat.SAND], "seeds": [0, 2], "supply": [40, 120],
		"lz": [24, 44], "shape": "layer", "relax": [[Mat.CLAY, Mat.LIMESTONE], [Mat.GRANITE, Mat.BASALT]]},
}
## Recept: pořadí rud = nejužší hostitel první (Willage-backend 18:34, bod b); změřeno v tests.gd host_table() na 40 blocích.
## Volitelně přepisy parametrů: {"order": [...], "override": {"copper": {"supply": [..]}}}
const RECIPES := {
	"louka": {"order": ["clay", "copper", "iron"]},
	"kopec": {"order": ["clay", "copper", "iron"]},
	"hora": {"order": ["clay", "copper", "iron"]},
	"piscina": {"order": ["clay", "copper", "iron"]},
}
const SERVER_CAP_X := 5   # server omezí cíl na 5× běžného průměru receptu
const SHORTFALL_TOL_PCT := 1  # server přijme schodek do 1 % cíle u každé rudy

## seznam specifikací pro recept v pořadí receptu (katalog + přepisy receptu)
static func specs_for(kind: String) -> Array:
	var r: Dictionary = RECIPES.get(kind, RECIPES["louka"])
	var out := []
	for k in r.order:
		var sp: Dictionary = CATALOG[k].duplicate(true)
		var ov: Dictionary = r.get("override", {}).get(k, {})
		for f in ov:
			sp[f] = ov[f]
		out.append(sp)
	return out

## kompatibilita: SPECS = pořadí receptu louky
static var SPECS: Array = specs_for("louka")

## STUDIE jeskyní: maska buněk, kam smí šíření (prázdná = všude). Nastavuje cave_v0.gd, pro rudy je prázdná.
static var elig := PackedByteArray()

static func key_of(sp: Dictionary):
	return sp.get("key", sp.material)

static func _ok(cells: PackedByteArray, host: PackedByteArray, c: int) -> bool:
	return host[cells[c]] == 1 and (elig.is_empty() or elig[c] == 1)

const LEVELS := ["L0 semínka", "L1 další semínka", "L2 dorůst tělesa", "L3 celá výška", "L4 uvolněný hostitel", "L5 schodek"]

# ---------------- RNG: SplitMix64 nad stable_hash (stav += GOLDEN, výstup = finalizér)
class Rng:
	var s := 0
	func _init(seed: int) -> void:
		s = seed
	func next() -> int:
		var r: int = H.splitmix64(s)
		s += H.GOLDEN
		return r
	func u16() -> int:
		return H.shr(next(), 48)
	## celé číslo v [a, b]; horních 31 bitů mod (b − a + 1)
	func range_i(a: int, b: int) -> int:
		if b <= a:
			return a
		return a + H.shr(next(), 33) % (b - a + 1)

static func idx(x: int, y: int, z: int) -> int:
	return (x * BS + y) * BH + z

static func _mask(list: Array) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(Mat.COUNT)
	for v in list:
		if not (v in NEVER):
			m[v] = 1
	return m

## ---------------- serverová strana (zástupce): cílový souhrn = základ z receptu a seedu + bonus v procentech
## Základ: pro každou rudu součet zásob náhodného počtu semínek (rozsahy receptu); bonus: +bonus_pct % navrch;
## strop: SERVER_CAP_X × běžný průměr (mean(seeds) × mean(supply)).
static func normal_mean(sp: Dictionary) -> int:
	return int(round((sp.seeds[0] + sp.seeds[1]) * 0.5 * (sp.supply[0] + sp.supply[1]) * 0.5))

static func server_cap(sp: Dictionary) -> int:
	return maxi(SERVER_CAP_X * normal_mean(sp), sp.supply[1])

static func server_target(seed: int, bonus_pct: int, specs := SPECS, capped := true) -> Dictionary:
	var out := {}
	for si in specs.size():
		var sp: Dictionary = specs[si]
		var r := Rng.new(H.mix(seed, "ORE_TARGET", si))
		var n := r.range_i(sp.seeds[0], sp.seeds[1])
		var base := 0
		for i in n:
			base += r.range_i(sp.supply[0], sp.supply[1])
		var t := base + (base * bonus_pct) / 100
		out[key_of(sp)] = mini(t, server_cap(sp)) if capped else t
	return out

## hlavička WVB1: shortfall {mat_id -> count}; přijato, když každý schodek <= 1 % cíle (zaokrouhleno dolů)
static func shortfall_header(res: Dictionary) -> Dictionary:
	var sf := {}
	var accepted := true
	for rep in res.per_ore:
		if rep.shortfall > 0:
			sf[str(key_of(rep))] = rep.shortfall
			if rep.shortfall * 100 > rep.target * SHORTFALL_TOL_PCT:
				accepted = false
	return {"shortfall": sf, "accepted": accepted}

## ---------------- hlavní vstup
## cells: objem po terénu a horninách (bez šumových rud), změní se na místě.
## target: {material -> přesný počet buněk}. Vrací {"per_ore": [...], "placed": {...}, "shortfall": {...}, "ok": bool}
static func place(cells: PackedByteArray, seed: int, target: Dictionary, specs := SPECS) -> Dictionary:
	var per := []
	var placed := {}
	var short := {}
	var ok := true
	for si in specs.size():
		var sp: Dictionary = specs[si]
		var t: int = target.get(key_of(sp), 0)
		var rep := _place_one(cells, H.mix(seed, "ORE", si), sp, t)
		per.append(rep)
		placed[key_of(sp)] = rep.placed
		if rep.shortfall > 0:
			short[key_of(sp)] = rep.shortfall
			ok = false
	return {"per_ore": per, "placed": placed, "shortfall": short, "ok": ok}

static func _place_one(cells: PackedByteArray, stream: int, sp: Dictionary, target: int) -> Dictionary:
	var rng := Rng.new(stream)
	var mat: int = sp.material
	var host := _mask(sp.host)
	var by_level := [0, 0, 0, 0, 0, 0]
	var rep := {"name": sp.name, "material": mat, "key": key_of(sp), "target": target, "placed": 0, "shortfall": 0,
		"by_level": by_level, "cells": PackedInt32Array(), "seeds_planned": 0, "seeds_placed": 0, "seeds_dropped": 0, "extra_seeds": 0}
	if target <= 0:
		return rep
	var own := PackedInt32Array()   # buňky této rudy (pro L2 a L4)
	# L0: semínka podle receptu, zásoby přepočtené tak, aby součet = target
	var n := rng.range_i(sp.seeds[0], sp.seeds[1])
	n = clampi(maxi(n, ceili(float(target) / float(sp.supply[1]))), 1, MAX_SEEDS)
	var w := PackedInt32Array()
	var wsum := 0
	for i in n:
		var v := rng.range_i(sp.supply[0], sp.supply[1])
		w.append(v); wsum += v
	var shares := _split(target, w, wsum)
	rep.seeds_planned = n
	var lz0: int = sp.lz[0]
	var lz1: int = sp.lz[1]
	for i in n:
		var c := -1
		for a in PLACE_TRIES:
			var x := rng.range_i(0, BS - 1)
			var y := rng.range_i(0, BS - 1)
			var z := rng.range_i(lz0, lz1)
			if _ok(cells, host, idx(x, y, z)):
				c = idx(x, y, z); break
		if c < 0:
			rep.seeds_dropped += 1
			continue
		rep.seeds_placed += 1
		by_level[0] += _grow(cells, c, shares[i], sp, host, mat, rng, own)
	var placed: int = by_level[0]
	# L1: další semínka (stejný hostitel, stejný rozsah lz), hledání skenem od náhodné buňky → najde, pokud hostitel existuje
	placed += _extra_seeds(cells, target - placed, sp, host, mat, rng, own, lz0, lz1, by_level, 1, rep)
	# L2: dorůst existující tělesa (BFS bez pravděpodobností, hostitel, libovolné lz)
	if placed < target:
		var g := _grow_bodies(cells, own, target - placed, host, mat)
		by_level[2] += g; placed += g
	# L3: semínka v celé výšce bloku
	placed += _extra_seeds(cells, target - placed, sp, host, mat, rng, own, 0, BH - 1, by_level, 3, rep)
	# L4: uvolněný hostitel po úrovních: nejdřív dorůst do nového hostitele, pak semínka
	for lvl in sp.relax:
		if placed >= target:
			break
		var hl: Array = sp.host.duplicate()
		for m in lvl:
			hl.append(m)
		host = _mask(hl)
		sp = sp.duplicate(); sp.host = hl
		var g := _grow_bodies(cells, own, target - placed, host, mat)
		by_level[4] += g; placed += g
		placed += _extra_seeds(cells, target - placed, sp, host, mat, rng, own, 0, BH - 1, by_level, 4, rep)
		if placed < target:
			g = _grow_bodies(cells, own, target - placed, host, mat)
			by_level[4] += g; placed += g
	rep.placed = placed
	rep.shortfall = target - placed
	rep["cells"] = own
	by_level[5] = rep.shortfall
	return rep

static func _split(total: int, w: PackedInt32Array, wsum: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var acc := 0
	for i in w.size():
		var v := (total * w[i]) / maxi(wsum, 1)
		out.append(v); acc += v
	var i := 0
	while acc < total:   # zbytek po jedné buňce od prvního semínka (deterministicky)
		out[i % w.size()] += 1; acc += 1; i += 1
	return out

static func _extra_seeds(cells: PackedByteArray, deficit: int, sp: Dictionary, host: PackedByteArray, mat: int, rng: Rng,
		own: PackedInt32Array, lz0: int, lz1: int, by_level: Array, lvl: int, rep: Dictionary) -> int:
	var got := 0
	var k := 0
	while got < deficit and k < EXTRA_SEEDS:
		k += 1
		var c := _scan_host(cells, host, rng.range_i(0, N - 1), lz0, lz1)
		if c < 0:
			break   # hostitel v rozsahu už není
		rep.extra_seeds += 1
		var budget := mini(deficit - got, maxi(sp.supply[1], (deficit - got) / 4))
		got += _grow(cells, c, budget, sp, host, mat, rng, own)
	by_level[lvl] += got
	return got

static func _scan_host(cells: PackedByteArray, host: PackedByteArray, start: int, lz0: int, lz1: int) -> int:
	for k in N:
		var c := (start + k) % N
		var z := c % BH
		if z >= lz0 and z <= lz1 and _ok(cells, host, c):
			return c
	return -1

## ---------------- šíření jednoho semínka; vrací počet přepsaných buněk (nejvýš budget)
static func _grow(cells: PackedByteArray, start: int, budget: int, sp: Dictionary, host: PackedByteArray, mat: int,
		rng: Rng, own: PackedInt32Array) -> int:
	if budget <= 0 or not _ok(cells, host, start):
		return 0
	if sp.shape == "vein":
		return _grow_vein(cells, start, budget, sp, host, mat, rng, own)
	var enq := PackedByteArray()
	enq.resize(N)
	var q := PackedInt32Array([start])
	enq[start] = 1
	var head := 0
	var got := 0
	var layer: bool = sp.shape == "layer"
	while head < q.size() and got < budget:
		var c := q[head]; head += 1
		if not _ok(cells, host, c):
			continue          # neplatná buňka se nepřepíše a nešíří se z ní
		cells[c] = mat; own.append(c); got += 1
		var x := c / (BS * BH)
		var y := (c / BH) % BS
		var z := c % BH
		for d in 6:
			var nx: int = x + DX[d]; var ny: int = y + DY[d]; var nz: int = z + DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue      # hranice bloku se nepřekračuje
			var n := idx(nx, ny, nz)
			if enq[n] == 1:
				continue
			var p := P_POCKET
			if sp.has("pH"):
				p = int(sp.pV) if d >= 4 else int(sp.pH)   # vlastní pravděpodobnosti (jeskynní sál, gen-v3 vrstva)
			elif layer:
				p = P_LAYER_V if d >= 4 else P_LAYER_H
			if rng.u16() < p:
				enq[n] = 1; q.append(n)
	return got

static func _pick_dir(rng: Rng, wh: int, wv: int, exclude: Array) -> int:
	var tot := 0
	for d in 6:
		if not (d in exclude):
			tot += wv if d >= 4 else wh
	if tot <= 0:
		return -1
	var r := rng.range_i(0, tot - 1)
	for d in 6:
		if d in exclude:
			continue
		r -= wv if d >= 4 else wh
		if r < 0:
			return d
	return -1

static func _step_ok(cells: PackedByteArray, host: PackedByteArray, c: int, d: int) -> int:
	var x: int = c / (BS * BH) + DX[d]
	var y: int = (c / BH) % BS + DY[d]
	var z: int = c % BH + DZ[d]
	if x < 0 or y < 0 or z < 0 or x >= BS or y >= BS or z >= BH:
		return -1
	var n := idx(x, y, z)
	return n if _ok(cells, host, n) else -1

## žíla: fronta „hlav“ (buňka, poslední směr); každá hlava udělá krok se setrvačností 70 %, jinak směr podle vah
## (bez couvání); s branch přidá druhou hlavu jiným směrem. Blokovaný cíl → až VEIN_RETRIES jiných směrů, pak hlava končí.
static func _grow_vein(cells: PackedByteArray, start: int, budget: int, sp: Dictionary, host: PackedByteArray, mat: int,
		rng: Rng, own: PackedInt32Array) -> int:
	var wh: int = sp.dirW.horiz
	var wv: int = sp.dirW.vert
	cells[start] = mat; own.append(start)
	var got := 1 + _tall(cells, host, start, mat, own, int(sp.get("height", 1)), budget - 1)
	var qc := PackedInt32Array([start])
	var qd := PackedInt32Array([-1])
	var head := 0
	while head < qc.size() and got < budget:
		var c := qc[head]; var prev := qd[head]; head += 1
		var ex := [] if prev < 0 else [REV[prev]]
		var d := prev if (prev >= 0 and rng.u16() < int(sp.get("keep", P_VEIN_KEEP))) else _pick_dir(rng, wh, wv, ex)
		var n := -1 if d < 0 else _step_ok(cells, host, c, d)
		var tries := 0
		while n < 0 and tries < VEIN_RETRIES:
			tries += 1
			d = _pick_dir(rng, wh, wv, ex + ([d] if d >= 0 else []))
			n = -1 if d < 0 else _step_ok(cells, host, c, d)
		if n < 0:
			continue
		cells[n] = mat; own.append(n); got += 1
		got += _tall(cells, host, n, mat, own, int(sp.get("height", 1)), budget - got)
		qc.append(n); qd.append(d)
		if got < budget and rng.u16() < int(sp.branch):
			var d2 := _pick_dir(rng, wh, wv, [d, REV[d]] + ex)
			var n2 := -1 if d2 < 0 else _step_ok(cells, host, c, d2)
			if n2 >= 0:
				cells[n2] = mat; own.append(n2); got += 1
				got += _tall(cells, host, n2, mat, own, int(sp.get("height", 1)), budget - got)
				qc.append(n2); qd.append(d2)
	return got

## chodba vysoká `height` buněk: přepíše i buňky nad krokem (jen hostitel a jen do zbylého rozpočtu)
static func _tall(cells: PackedByteArray, host: PackedByteArray, c: int, mat: int, own: PackedInt32Array, height: int, left: int) -> int:
	var got := 0
	for k in range(1, height):
		if got >= left or c % BH + k >= BH:
			break
		var u := c + k
		if not _ok(cells, host, u):
			break
		cells[u] = mat; own.append(u); got += 1
	return got

## L2 / L4: dorůst všechna tělesa rudy najednou (BFS z jejích buněk, sousedé v pevném pořadí, bez náhody)
static func _grow_bodies(cells: PackedByteArray, own: PackedInt32Array, budget: int, host: PackedByteArray, mat: int) -> int:
	if budget <= 0 or own.is_empty():
		return 0
	var enq := PackedByteArray()
	enq.resize(N)
	var q := PackedInt32Array()
	for c in own:
		enq[c] = 1; q.append(c)
	var head := 0
	var got := 0
	while head < q.size() and got < budget:
		var c := q[head]; head += 1
		var x := c / (BS * BH)
		var y := (c / BH) % BS
		var z := c % BH
		for d in 6:
			if got >= budget:
				break
			var nx: int = x + DX[d]; var ny: int = y + DY[d]; var nz: int = z + DZ[d]
			if nx < 0 or ny < 0 or nz < 0 or nx >= BS or ny >= BS or nz >= BH:
				continue
			var n := idx(nx, ny, nz)
			if enq[n] == 1 or not _ok(cells, host, n):
				continue
			enq[n] = 1
			cells[n] = mat; own.append(n); q.append(n); got += 1
	return got

## souhrn rud v objemu (kontrola: placed musí sedět s rozdílem počtů před a po)
static func count(cells: PackedByteArray) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize(Mat.COUNT)
	for c in cells:
		s[c] += 1
	return s
