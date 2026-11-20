extends RefCounted
## E66: podzemí ostrova pro tok (st.ug.impl): E52 varianta 4 = funkce nad vrstvami (pásma), režim auto E55
## (nepropustné dno → preliv / pramen, propustné → nádrž s průsakem), E58 A+B+C+D, E64 K (sestup bez závislosti na pořadí),
## I (oprava se zárukou shody), P (flood z paměti), R (kroky po pevném počtu operací, nikdy podle času).
## Rozhraní pro tok.gd: entry / col_of / touched / solve. Každé volání solve se zaregistruje (vstupy, q, vyloučené sloupce),
## výkop jde přes ug64.edit nad všemi registrovanými voláními (stejně jako blueprint-studie/tools/alg64_ug.gd).
const F = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const U = preload("res://scripts/voda/podzemi/ug58.gd")
const U64 = preload("res://scripts/voda/podzemi/ug64.gd")
const SELF = preload("res://scripts/voda/podzemi_ostrov.gd")

## world, fine: svět studie a jemné buňky bloků (scripts/teren/ostrov_teren.gd); W, hs, wall, cm: povrchová mřížka toku
## cache (E79, volitelná): funkční pásma z prvního postavení, další postavení počítá znovu jen dutiny
static func make(world, fine: Dictionary, p: Dictionary, W: int, hs: PackedFloat64Array, wall: PackedByteArray, cm: float, cache = null) -> Dictionary:
	var q: Dictionary = p.duplicate()
	q.p52_rezim = "auto"
	var c := F.from_world(world, fine, 16, 16, q, cache)
	F.set_surface(c, W, hs, wall, cm)
	c.impl = SELF
	c._var = String(p.get("voda_ug_var", "A+B+C+D+K+I+P+R"))
	c._dz = float(p.p58_dz)
	c._budget = int(p.p64_budget)
	c._bfs_max = int(p.get("p58_bfs_max", 20000))
	c._ents = {}
	c._useD = U.has_flag(c._var, "D")
	c._calls = []; c._keys = {}; c._res = []; c._changed = false
	c._st = {"builds": 0, "floods": 0, "results": 0, "fallback": 0, "exact": 0, "skipped": 0, "rebuilds": 0, "deltas": 0, "gone": 0, "reach": 0, "splits": 0}
	c._digs = []   # [sloupec povrchu, výška] pro kontrolu proti čerstvému výpočtu
	U64.setup(c, c._var, c._budget)
	return c

static func entry(c: Dictionary, s: int) -> int: return F.entry(c, s)
static func col_of(c: Dictionary, s: int) -> int: return F.col_of(c, s)

## tok.update volá po změně terénu; výkop už provedl dig() → vrátí, jestli se výsledek některého volání změnil
static func touched(c: Dictionary, _cache: Dictionary, _ch: PackedInt32Array, _hv: PackedFloat64Array) -> bool:
	var r: bool = c._changed
	c._changed = false
	return r

static func _key(entries: PackedInt32Array, q: float, excl: Dictionary) -> String:
	var ks := excl.keys(); ks.sort()
	return "%s|%.9f|%s" % [str(entries), q, str(ks)]

static func solve(c: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var key := _key(entries, q, excl)
	if c._keys.has(key): return c._res[c._keys[key]]
	for e in entries: c._ents[e] = true
	var call := {"ents": entries, "q": q, "excl": excl, "x": excl.keys(), "ex": U.ex_of(c, excl.keys()), "final": true}
	c._calls.append(call)
	var i: int = c._calls.size() - 1
	c._keys[key] = i
	var v: String = c._var
	var r := U._one(c, c._calls, i, U.has_flag(v, "A"), U.has_flag(v, "B"), U.has_flag(v, "C"), c._dz, c._st)
	c._res.append(r)
	return r

static func _digest(c: Dictionary) -> String:
	var s := ""
	for r in c._res: s += U64.digest_res(r)
	return s

## výkop sloupce povrchu s na výšku hv (buňky); položení (hv výš) podzemí nemění (jako ve studii)
static func dig(c: Dictionary, s: int, hv: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var d0 := _digest(c)
	c._digs.append([s, hv])
	c._res = U64.edit(c, c._calls, c._res, s, hv, c._var, c._dz, c._st)
	c._changed = _digest(c) != d0
	return {"ms": (Time.get_ticks_usec() - t0) / 1000.0, "pending": U64.pending(c), "changed": c._changed, "X": int(c.get("_x64", 0))}

static func pending(c: Dictionary) -> bool:
	return U64.pending(c)

## jeden krok R (pevný počet operací); po dokončení všech kroků nastaví _changed, když se výsledek změnil
static func step(c: Dictionary, budget := -1) -> bool:
	if not U64.pending(c): return false
	var d0 := _digest(c)
	U64.step(c, c._calls, c._res, c._budget if budget < 0 else budget)
	if _digest(c) != d0: c._changed = true
	return U64.pending(c)
