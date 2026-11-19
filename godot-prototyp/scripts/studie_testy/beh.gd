extends RefCounted
## KOPIE z blueprint-studie/scripts/svet8/beh.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E49: celý běh malého světa 8 × 8 (fáze 1–6) s časy, metrikami švů a daty pro GIF (shots/svet8.json, tools/gif_svet8.py).

const HT = preload("res://scripts/teren/svet/hruby_teren.gd")
const PO = preload("res://scripts/teren/svet/pocasi.gd")
const RK = preload("res://scripts/teren/svet/reky.gd")
const BM = preload("res://scripts/teren/svet/biomy.gd")
const DL = preload("res://scripts/teren/svet/dlazdice.gd")
const W = preload("res://scripts/teren/world.gd")
const PL = preload("res://scripts/teren/pipeline.gd")
const MT = preload("res://scripts/studie_testy/metrics.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const T = preload("res://scripts/studie_testy/tests_horniny.gd")
const TV = preload("res://scripts/studie_testy/tests_voda.gd")

static func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

static func coarse(p: Dictionary, frames: int) -> Dictionary:
	var ms := {}
	var t0 := Time.get_ticks_usec()
	var t := HT.run(int(p.world_seed), p); ms["1 hrubý terén"] = _ms(t0)
	var raw: PackedFloat64Array = t.hm.duplicate()
	t0 = Time.get_ticks_usec()
	var w := PO.run(t, p); ms["2 počasí"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	var ef := RK.erode(t, w, p, frames)
	if bool(p.get("s56_on", false)) and float(p.get("s56_max_slope", 0.0)) > 0.0:   # E56: řeky nesmí znovu vyrýt strmé stěny
		t.s56_po_erozi = load("res://scripts/teren/svet/svah.gd").limit(t.hm, int(t.R), float(p.s56_max_slope), int(p.get("s56_pasy", 200)))
	var rv := RK.rivers(t, w, p); ms["3 eroze + řeky"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	var bio := BM.run(t, w, rv, p); ms["4 biomy"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	var tiles := DL.run(t, w, rv, bio, p); ms["5 dlaždice"] = _ms(t0)
	return {"t": t, "raw": raw, "w": w, "ef": ef, "rv": rv, "bio": bio, "tiles": tiles, "ms": ms}

static func detail(c: Dictionary, p: Dictionary) -> Dictionary:
	var T8: int = c.t.T
	var world = W.new(); world.w = T8; world.h = T8
	var by := {}
	for e in c.tiles: by[e.slot] = e
	var f: Array = p.s8_first
	var ord := DL.order(T8, Vector2i(int(f[0]), int(f[1])))
	var t0 := Time.get_ticks_usec()
	var per := []
	for s in ord:
		var t1 := Time.get_ticks_usec()
		PL.run_sync(world, s, by[s].bp, p)
		per.append(_ms(t1))
	return {"world": world, "order": ord, "per": per, "ms": _ms(t0)}

static func top_rgb(world, s: Vector2i) -> Array:
	var r: Dictionary = world.slots[s]
	var out := []
	for i in 256:
		var h: int = r.hm[i]
		out.append(r.cells[i * 64 + h - 1] if h > 0 else 0)
	return out

static func run_all(p: Dictionary, out_txt: String, out_json: String) -> PackedStringArray:
	var L := PackedStringArray()
	var t0 := Time.get_ticks_usec()
	var c := coarse(p, int(p.s8_frames))
	var d := detail(c, p)
	var total := _ms(t0)
	var w = d.world
	L.append("# E49 malý svět %d × %d bloků (%s)" % [c.t.T, c.t.T, Time.get_datetime_string_from_system()])
	for k in c.ms: L.append("%s: %.0f ms" % [k, c.ms[k]])
	var per: Array = d.per
	var pmax := 0.0; for v in per: pmax = maxf(pmax, v)
	L.append("6 detail: %d dlaždic od %s do šířky, %.1f s (průměr %.0f ms, max %.0f ms)" % [per.size(), str(d.order[0]), d.ms / 1000.0, d.ms / per.size(), pmax])
	L.append("CELKEM %.1f s (hrubý svět %.2f s)" % [total / 1000.0, (total - d.ms) / 1000.0])
	var cnt := {}
	for e in c.tiles: cnt[e.bp.shape] = cnt.get(e.bp.shape, 0) + 1
	L.append("typy dlaždic: " + ", ".join(cnt.keys().map(func(k): return "%s %d" % [k, cnt[k]])))
	var bc := {}
	for b in c.bio: bc[BM.NAMES[b]] = bc.get(BM.NAMES[b], 0) + 1
	L.append("biomy (body hrubé mřížky): " + ", ".join(bc.keys().map(func(k): return "%s %d" % [k, bc[k]])))
	var rp := 0; var lp := 0
	for i in c.rv.river.size(): rp += c.rv.river[i]; lp += c.rv.lake[i]
	L.append("řeky %d bodů (%.1f %%), jezera %d bodů, sopka v dlaždici %s" % [rp, 100.0 * rp / c.rv.river.size(), lp, str(c.t.volcano)])
	var ids := HR.pool(p).map(func(e): return int(e.id))
	var m := MT.seams(w.slots, "hm", ids, T.ignore(p))
	var ss := TV.surf_seam(w)
	L.append("švy vrstev %.2f (uvnitř %.2f) | povrch buňky šev %.2f (uvnitř %.2f) | šev hm_f %.2f (max %.2f), zlom %.2f (uvnitř %.2f)" % [
		MT.mean_seam(m), MT.mean_inner(m), m.surf_seam, m.surf_inner, ss.seam, ss.seam_max, ss.kink, ss.kink_inner])
	L.append("švy vrstev podrobně: " + MT.fmt(m))
	var ab := T.abrupt(w, p)
	L.append("náhlé vrstvy: " + T.fmt_abrupt(ab))
	var ok := 0; var exact := 0
	for s in w.order:
		var r: Dictionary = w.slots[s]
		if r.rep.valid.ok: ok += 1
		if r.rep.valid.minerals_exact: exact += 1
	L.append("validátor OK %d/%d, minerály přesně %d/%d" % [ok, w.order.size(), exact, w.order.size()])
	var h1: String = w.hash()
	var d2 := detail(coarse(p, int(p.s8_frames)), p)
	L.append("determinismus 2×: %s / %s → %s" % [h1.left(12), d2.world.hash().left(12), "STEJNÉ" if h1 == d2.world.hash() else "RŮZNÉ!"])
	FileAccess.open(out_txt, FileAccess.WRITE).store_string("\n".join(L) + "\n")
	var tiles := []
	for e in c.tiles:
		tiles.append({"slot": [e.slot.x, e.slot.y], "shape": e.bp.shape, "biome": e.biome})
	var det := []
	for s in d.order:
		det.append({"slot": [s.x, s.y], "hm_f": Array(w.slots[s].hm_f), "top": top_rgb(w, s)})
	var data := {"R": c.t.R, "T": c.t.T, "raw": Array(c.raw), "rain": Array(c.w.rain), "ero": c.ef.map(func(a): return Array(a)),
		"hm": Array(c.t.hm), "acc": Array(c.rv.acc), "river": Array(c.rv.river), "lake": Array(c.rv.lake), "fill": Array(c.rv.fill),
		"bio": Array(c.bio), "tiles": tiles, "detail": det, "types": DL.TYPES, "pal": Array(HR.palette()).map(func(cc): return cc.to_html(false))}
	FileAccess.open(out_json, FileAccess.WRITE).store_string(JSON.stringify(data))
	return L
