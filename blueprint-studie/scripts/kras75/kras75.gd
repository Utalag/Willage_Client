extends RefCounted
## E75 (Jan 2026-11-19 20:53, hypotéza): eroze v podzemí po tělesech – kras. Nematerializované podzemí se neeroduje po
## buňkách. Průsak pórovitou vrstvou je zanedbatelný; u rozpustných hornin (sdílená tabulka: rozp_kg_m3, hustota_kg_m3)
## se z průtoku tělesem počítá rozpuštěný objem za čas jako hodnota u tělesa (po pásmech jeho hlavní cesty). Voda vstupuje
## nenasycená a podél cesty se nasycuje exponenciálně s délkou λ: pásmo b dostane r_b = Q · s · (e^(−d_in/λ) − e^(−d_out/λ)),
## s = rozp / hustota (m³ horniny na m³ vody), takže součet po cestě ≤ Q · s. Odpočet do prahu (jedna herní buňka) je
## událost jako v E51 (předpočítaný čas = zbytek / rychlost, remíza podle pásma). Událost → dutina v pásmu u hladiny
## (tvar: sloupec, pásmo, vršek, počet buněk 0,25 m, 4 na vrstvu sloupce 0,5 m), buňky se materializují až při prokopání.
## Zpětná vazba: pórovitost pásma + objem dutiny, propustnost dutiny (perm75) → přepočet vody (E68) a nové rychlosti.
## Kopání / položení: postup se dopočítá do teď, odpočet pásem prokopaného sloupce se vynuluje.
const VP = preload("res://scripts/kopie/voda_params.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const LI = preload("res://scripts/voda/litry.gd")   # E94: jeden tvar l → m³
const CELL := 0.25
const E := 1e-12

static var _S := {}
## materiál → s (m³ rozpuštěné horniny na m³ vody v rovnováze); jen rozpustné horniny
static func sol() -> Dictionary:
	if _S.is_empty():
		var d: Dictionary = VP.load_shared_table()
		for k in d.get("materials", {}):
			var e: Dictionary = d.materials[k]
			if e.has("rozp_kg_m3") and float(e.get("hustota_kg_m3", 0.0)) > 0.0 and float(e.rozp_kg_m3) > 0.0:
				_S[int(e.id)] = float(e.rozp_kg_m3) / float(e.hustota_kg_m3)
		_S[-1] = 0.0   # značka „načteno“
	return _S

static func make(p: Dictionary) -> Dictionary:
	return {"lam": float(p.get("p75_delka_m", 100.0)), "prah": float(p.get("p75_prah_m3", CELL * CELL * CELL)),
		"perm_dut": float(p.get("p75_perm_dutina", 1.0)), "zr": float(p.get("p75_zrychleni", 1.0)), "now": 0.0, "D": {}, "dut": {}, "rate": {}, "ztop": {}, "col": {},
		"mat": {}, "log": [], "stats": {"udalosti": 0, "rates_ms": 0.0, "pasem": 0}}

## nejkratší cesta pásem tělesa od vstupů k pásmu výstupu (BFS, sousedé podle id) jen nasycenou zónou (dno pásma pod
## hladinou L; vstupy a výstup vždy) → voda teče u hladiny (epifreatická zóna) → [[pásmo, d_in m, d_out m], ...]
static func _path(c: Dictionary, ents: Array, goal: int, L := INF) -> Array:
	var par := {}; var qu := []
	for e in ents:
		if e >= 0 and not par.has(e): par[e] = -1; qu.append(e)
	var k := 0; var hit := -1
	while k < qu.size():
		var b: int = qu[k]; k += 1
		if b == goal: hit = b; break
		var nb := []
		for x in F._nbrs(c, b): nb.append(int(x[0]))
		nb.sort()
		for b2 in nb:
			if par.has(b2): continue
			if b2 != goal and float(c.lo[b2]) >= L - 1e-6: continue
			par[b2] = b; qu.append(b2)
	if hit < 0: return []
	var seq := []
	var b := hit
	while b >= 0: seq.push_front(b); b = int(par[b])
	return _dist(c, seq)

static func _step(c: Dictionary, a: int, b: int) -> float:
	if int(c.bcol[a]) == int(c.bcol[b]): return absf((float(c.lo[a]) + float(c.hi[a])) - (float(c.lo[b]) + float(c.hi[b]))) * 0.5
	return float(c.side)

static func _dist(c: Dictionary, seq: Array) -> Array:
	var out := []; var d := 0.0
	for i in seq.size():
		var b: int = seq[i]
		var l := float(c.side) if i + 1 >= seq.size() else maxf(_step(c, b, int(seq[i + 1])), float(c.side) * 0.5)
		out.append([b, d, d + l]); d += l
	return out

## E67: vzdálenost mokrých pásem od vstupu (BFS přes mokrá pásma a pasti) → {pásmo: d m}
static func _wet_dist(c: Dictionary, ents: Array, wet: Dictionary) -> Dictionary:
	var dist := {}; var qu := []
	for e in ents:
		if e >= 0 and not dist.has(e): dist[e] = 0.0; qu.append(e)
	var k := 0
	while k < qu.size():
		var b: int = qu[k]; k += 1
		var nb := []
		for x in F._nbrs(c, b): nb.append(int(x[0]))
		nb.sort()
		for b2 in nb:
			if wet.has(b2) and not dist.has(b2): dist[b2] = float(dist[b]) + _step(c, b, b2); qu.append(b2)
	return dist

## rychlosti rozpouštění (m³ horniny za herní s) po pásmech ze všech těles; vršek dutiny = hladina / proud v pásmu
static func rates(c: Dictionary, bodies: Array, K: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var S := sol(); var lam: float = K.lam
	var rate := {}; var ztop := {}
	var film := float(c.get("film67", 0.5))
	for r in bodies:
		if bool(r.get("closed", false)): continue
		var ents: Array = Array(r.get("entries", PackedInt32Array()))
		var segs := []   # [pásmo, q l/s, d_in, d_out, vršek]
		if r.has("wet67"):
			var wet := {}
			var wl: PackedInt32Array = r.wet67; var wq: PackedFloat64Array = r.get("wetq67", PackedFloat64Array())
			for i in wl.size(): wet[int(wl[i])] = float(wq[i]) if i < wq.size() else 0.0
			for p in r.get("pits67", []):
				for b in p.bands: wet[int(b)] = float(wet.get(int(b), 0.0)) + float(p.q_in) / maxf(p.bands.size(), 1)
			var dist := _wet_dist(c, ents, wet)
			var ks := wet.keys(); ks.sort()
			for b in ks:
				if not dist.has(b): continue
				var d0 := float(dist[b])
				segs.append([b, float(wet[b]), d0, d0 + float(c.side), minf(float(c.hi[b]), float(c.lo[b]) + film)])
		elif not Array(r.get("out", [])).is_empty():
			var q := float(r.q_in)
			var L := float(r.z_out)
			for e in _path(c, ents, int(r.out[2]), L): segs.append([int(e[0]), q, float(e[1]), float(e[2]), minf(float(c.hi[int(e[0])]), L)])
		for sg in segs:
			var b: int = sg[0]
			var s := float(S.get(int(c.mat[b]), 0.0))
			if s <= 0.0 or float(sg[1]) <= 0.0: continue
			var f := exp(-float(sg[2]) / lam) - exp(-float(sg[3]) / lam)
			rate[b] = float(rate.get(b, 0.0)) + float(sg[1]) / LI.L_NA_M3 * s * f * float(K.get("zr", 1.0))   # zr: herní zrychlení (1 = reálně)
			ztop[b] = maxf(float(ztop.get(b, -INF)), float(sg[4]))
			K.col[b] = int(c.bcol[b]); K.mat[b] = int(c.mat[b])
	K.rate = rate; K.ztop = ztop
	K.stats.pasem = rate.size()
	K.stats.rates_ms = (Time.get_ticks_usec() - t0) / 1000.0

## postup do času t (herní s) bez překročení prahu (volající hlídá next_event)
static func advance(K: Dictionary, t: float) -> void:
	var dt := t - float(K.now)
	if dt <= 0.0: return
	var ks: Array = K.rate.keys(); ks.sort()
	for b in ks: K.D[b] = float(K.D.get(b, 0.0)) + float(K.rate[b]) * dt
	K.now = t

## nejbližší událost [čas, pásmo] (předpočítaný čas = zbytek / rychlost; remíza = menší pásmo), jinak [INF, -1]
static func next_event(K: Dictionary) -> Array:
	var bt := INF; var bb := -1
	var ks: Array = K.rate.keys(); ks.sort()
	for b in ks:
		var r := float(K.rate[b])
		if r <= 0.0: continue
		var t := float(K.now) + maxf(float(K.prah) - float(K.D.get(b, 0.0)), 0.0) / r
		if t < bt: bt = t; bb = b
	return [bt, bb]

## událost: odpočet pásma b dosáhl prahu → dutina +1 buňka
static func fire(K: Dictionary, b: int) -> void:
	K.D[b] = maxf(float(K.D.get(b, 0.0)) - float(K.prah), 0.0)
	if float(K.D[b]) < 1e-15: K.D[b] = 0.0
	K.dut[b] = float(K.dut.get(b, 0.0)) + float(K.prah)
	K.stats.udalosti += 1
	K.log.append([float(K.now), b, float(K.dut[b])])

## zpětná vazba do pásem: pórovitost + objem dutiny, propustnost dutiny (jednou na kontext; pórovitost z geologie)
static func apply(c: Dictionary, K: Dictionary) -> Array:
	if not c.has("_por75"): c._por75 = {}
	if not c.has("perm75"): c.perm75 = {}
	var ch := []
	var ks: Array = K.dut.keys(); ks.sort()
	for b in ks:
		if b >= c.lo.size(): continue
		if not c._por75.has(b): c._por75[b] = float(c.por[b])
		var th := maxf(float(c.hi[b]) - float(c.lo[b]), 1e-6)
		var np := minf(float(c._por75[b]) + float(K.dut[b]) / (float(c.A) * th), 1.0)
		if float(c.por[b]) != np: c.por[b] = np; ch.append(b)
		c.perm75[b] = float(K.perm_dut)
	return ch

## tvar dutiny pásma b: buňky 0,25 m shora od vršku (hladina / proud), 4 na vrstvu sloupce řídicí mřížky → [[z, i], ...]
static func cells(K: Dictionary, b: int) -> Array:
	var n := int(floor(float(K.dut.get(b, 0.0)) / (CELL * CELL * CELL) + 1e-9))
	var out := []
	var zt := float(K.ztop.get(b, 0.0))
	for i in n: out.append([zt - (i / 4 + 0.5) * CELL, i % 4])
	return out

## kopání / položení ve sloupci cc (řídicí mřížka): dopočítat do teď, vynulovat odpočet pásem sloupce, materializovat
## buňky dutin ve výšce [z1, z0) → počet buněk vzduchu
static func on_dig(K: Dictionary, t: float, cc: int, z0: float, z1: float) -> Dictionary:
	advance(K, t)
	var reset := 0; var air := 0
	var ks: Array = K.col.keys(); ks.sort()
	for b in ks:
		if int(K.col[b]) != cc: continue
		if float(K.D.get(b, 0.0)) > 0.0: K.D[b] = 0.0; reset += 1
		for e in cells(K, b):
			if float(e[0]) >= z1 and float(e[0]) < z0: air += 1
	return {"vynulovano": reset, "bunek_dutiny": air}

static func otisk(K: Dictionary) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	h.update(PackedFloat64Array([float(K.now)]).to_byte_array())
	for k in ["D", "dut", "rate"]:
		var ks: Array = K[k].keys(); ks.sort()
		var ids := PackedInt32Array(); var vs := PackedFloat64Array()
		for b in ks: ids.append(int(b)); vs.append(float(K[k][b]))
		h.update(k.to_utf8_buffer())
		if not ids.is_empty(): h.update(ids.to_byte_array()); h.update(vs.to_byte_array())
	return h.finish().hex_encode().substr(0, 16)
