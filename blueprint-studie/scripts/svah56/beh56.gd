extends RefCounted
## E56 mírnější výškové přechody: svět 8 × 8 (E49) před / po (s56_on), metriky sklonu, pata hory, švy, typy dlaždic.
const B = preload("res://scripts/svet8/beh.gd")
const TV = preload("res://scripts/voda/tests_voda.gd")

static func _grid(w, T: int, key: String) -> PackedFloat64Array:
	var N := T * 16; var g := PackedFloat64Array(); g.resize(N * N)
	for tx in T:
		for ty in T:
			var a = w.slots[Vector2i(tx, ty)][key]
			for x in 16:
				for y in 16: g[(tx * 16 + x) * N + ty * 16 + y] = float(a[x * 16 + y])
	return g

static func _pct(a: Array, q: float) -> float:
	return a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)] if not a.is_empty() else 0.0

## sklon mezi sousedními sloupci 0,5 m: výšky v buňkách 0,5 m → tan = Δ buněk
static func metrics(hf: PackedFloat64Array, hi: PackedFloat64Array, N: int) -> Dictionary:
	var sl := []; var steep45 := 0; var steep30 := 0; var step := 0.0
	for x in N:
		for y in N:
			var i := x * N + y; var mx := 0.0
			for d in [[1, 0], [0, 1], [-1, 0], [0, -1]]:
				var qx: int = x + d[0]; var qy: int = y + d[1]
				if qx < 0 or qy < 0 or qx >= N or qy >= N: continue
				var j := qx * N + qy
				mx = maxf(mx, absf(hf[i] - hf[j]))
				step = maxf(step, absf(hi[i] - hi[j]))
			var deg := rad_to_deg(atan(mx))
			sl.append(deg)
			if deg > 45.0: steep45 += 1
			if deg > 30.0: steep30 += 1
	sl.sort()
	# nejvyšší vrchol a pata: vzdálenost od vrcholu, kde výška klesne na čtvrtinu převýšení (průměr 8 směrů)
	var top := 0; var lo := INF
	for i in N * N:
		if hf[i] > hf[top]: top = i
		lo = minf(lo, hf[i])
	var thr := lo + 0.25 * (hf[top] - lo)
	var tx := top / N; var ty := top % N; var ds := []
	for d in [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
		var k := 0
		while true:
			k += 1
			var qx: int = tx + d[0] * k; var qy: int = ty + d[1] * k
			if qx < 0 or qy < 0 or qx >= N or qy >= N: k -= 1; break
			if hf[qx * N + qy] <= thr: break
		ds.append(k * 0.5 * (1.4142 if d[0] != 0 and d[1] != 0 else 1.0))
	var pat := 0.0
	for v in ds: pat += v
	return {"p50": _pct(sl, 0.5), "p95": _pct(sl, 0.95), "max": sl[-1], "nad45_pct": 100.0 * steep45 / sl.size(), "nad30_pct": 100.0 * steep30 / sl.size(),
		"schod_max": step, "vrchol_m": hf[top] * 0.5, "vrchol": [tx, ty], "prevyseni_m": (hf[top] - lo) * 0.5, "pata_m": pat / ds.size()}

static func run_all(p: Dictionary) -> Dictionary:
	var out := {}; var L := PackedStringArray()
	for v in ["pred", "po"]:
		var q := p.duplicate(true); q.s56_on = v == "po"
		var t0 := Time.get_ticks_usec()
		var c := B.coarse(q, int(q.s8_frames))
		var d := B.detail(c, q)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var w = d.world; var T: int = c.t.T; var N := T * 16
		var hf := _grid(w, T, "hm_f"); var hi := _grid(w, T, "hm")
		var m := metrics(hf, hi, N)
		var cnt := {}
		for e in c.tiles: cnt[e.bp.shape] = cnt.get(e.bp.shape, 0) + 1
		var ok := 0
		for s in w.order: if w.slots[s].rep.valid.ok: ok += 1
		var ss := TV.surf_seam(w)
		m.ms = ms; m.typy = cnt; m.valid = ok; m.sev = ss.seam; m.sev_max = ss.seam_max; m.hash = w.hash().left(12)
		m.limiter = c.t.get("s56", {}); m.limiter_po_erozi = c.t.get("s56_po_erozi", {})
		out[v] = m
		out[v + "_hf"] = Array(hf); out.N = N
		L.append("%s: sklon p50 %.1f° p95 %.1f° max %.1f° | nad 45° %.2f %%, nad 30° %.2f %% | schod max %d buněk | vrchol %.1f m (převýšení %.1f m), pata %.1f m | typy %s | švy povrchu %.2f (max %.2f), validátor %d/%d | %.1f s | hash %s" % [
			v, m.p50, m.p95, m.max, m.nad45_pct, m.nad30_pct, int(m.schod_max), m.vrchol_m, m.prevyseni_m, m.pata_m, str(cnt), m.sev, m.sev_max, ok, w.order.size(), ms / 1000.0, m.hash])
	out.L = L
	return out
