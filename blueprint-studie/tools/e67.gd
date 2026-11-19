extends SceneTree
## E67: podzemí startovního ostrova (4 bloky bp jako prototyp: louka 101, hora 202, kopec 303, louka 404, svět 8 × 8 se sloty
## ostrova od (3, 3), mimo ostrov zeď) ve variantách: stará (auto), stará + O (okraj ostrova jako výstup), pretok + O
## (přetoky ve 3D), pretok bez O; navíc tělesa s krasem jen při perm ≥ ponor_perm (p67_kras=false).
## Zdroje = tůně: místní minima povrchu na ostrově (sloupec řídicí mřížky nejníž ze 4 sousedů), vstup F.entry, seskupené
## po tělesech jako tok60 (jedno volání na těleso, q = součet). Výkopy: --vykopu=N u zdrojů (2 m), u pretok kontrola proti
## čerstvému plnému výpočtu a dvě pořadí výkopů. Výstup shots/e67/ostrov.json (+ stav pro obrázek).
const PR = preload("res://scripts/bp/params.gd")
const PL = preload("res://scripts/bp/pipeline.gd")
const WD = preload("res://scripts/bp/world.gd")
const BP = preload("res://scripts/bp/blueprint.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const U = preload("res://scripts/alg58/ug58.gd")
const V64 = preload("res://scripts/svet64/voda64.gd")
const OFF := Vector2i(3, 3)
const SHAPE := {"louka": "louka", "kopec": "kopec", "hora": "hora_zvrasnena"}
const MIN := {"louka": {8: 10, 9: 14, 104: 20}, "kopec": {8: 20, 9: 24, 106: 6, 104: 30}, "hora_zvrasnena": {8: 30, 9: 20, 104: 20, 106: 8}}
const WAT := {"louka": 150, "kopec": 120, "hora_zvrasnena": 80}

## --bp.<klíč>=hodnota → parametry studie (E71)
static func bp_args(p: Dictionary) -> Dictionary:
	var a := PackedStringArray()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--bp."): a.append("--" + s.substr(5))
	return PR.apply_args(p, a)

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

var world
var p := {}
var fine := {}

func _build() -> void:
	p = PR.defaults()
	world = WD.new(); world.w = 8; world.h = 8
	for e in _arg("bloky", "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404").split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var shape: String = SHAPE[a[1]]; var seed := int(a[2])
		var mins: Dictionary = MIN[shape].duplicate()
		if seed % 3 == 0 and seed % 5 != 0: mins[0] = 90
		var bp := BP.make(shape, seed, mins, int(WAT[shape]))
		var ws := Vector2i(int(xy[0]), int(xy[1])) + OFF
		var ctx := PL.new_ctx(world, ws, bp, p.duplicate())
		for st in PL.steps(ctx): st[1].call()
		var rec := PL.record(ctx)
		world.commit(rec)
		fine[ws] = {"cells": rec.cells, "hm": rec.hm}

func _ctx(extra: Dictionary) -> Dictionary:
	var q := V64.scaled(p, 16); q.p52_rezim = "auto"
	q.p70_prumer = _arg("prumer", String(q.get("p70_prumer", "pomer")))   # E70
	q.p67_prune = _arg("prune", "1" if bool(q.get("p67_prune", true)) else "0") == "1"   # E70: srovnání bez slučování
	q = bp_args(q)
	q.merge(extra, true)
	return F.from_world(world, fine, 16, 16, q)

## tůně = místní minima povrchu (na ostrově), vstupy seskupené po tělesech
func _calls(c: Dictionary) -> Array:
	var W: int = c.W; var H: int = c.H
	var by := {}
	for cc in W * H:
		if c.wall[cc] == 1: continue
		var x := cc / H; var y := cc % H; var hh: float = c.h[cc]; var low := true; var lower := false
		for d in 4:
			var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
			var c2 := qx * H + qy
			if c.wall[c2] == 1: continue
			if float(c.h[c2]) < hh - 1e-9: low = false
			if float(c.h[c2]) > hh + 1e-9: lower = true
		if not (low and lower): continue
		var e := F.entry(c, cc)
		if e < 0: continue
		var k: int = c.comp[e]
		if not by.has(k): by[k] = PackedInt32Array()
		by[k].append(e)
	var ks := by.keys(); ks.sort()
	var out := []
	for k in ks:
		var ents: PackedInt32Array = by[k]; ents.sort()
		out.append({"ents": ents, "q": 0.02 * ents.size(), "excl": {}, "x": [], "ex": {}, "final": true})
	return out

func _sum(c: Dictionary, res: Array, label: String, ms: float) -> Dictionary:
	var wet := {}; var pitb := {}; var pits := []; var outs := {"okraj": 0, "povrch": 0}; var oq := {"okraj": 0.0, "povrch": 0.0}
	var vol := 0.0; var lv := []
	var oql := []   # E70: výstupy s průtokem (otisk rozdělení, nejen součtů)
	for r in res:
		vol += float(r.volume_m3)
		if r.has("pits67"):
			for b in r.wet67: wet[b] = true
			for pt in r.pits67:
				for b in pt.bands: pitb[b] = true
				if pt.objem_m3 > 0.0: pits.append({"hladina": snappedf(pt.hladina, 0.01), "dno": snappedf(pt.dno, 0.01), "pasem": pt.pasem, "typ": pt.typ, "objem_m3": snappedf(pt.objem_m3, 0.1)})
			for o in r.outs67:
				outs[o[1]] += 1; oq[o[1]] += float(o[3]); oql.append([int(o[2]), String(o[1]), float(o[3]), snappedf(float(o[0]), 1e-4)])
		else:
			for b in r.comp_ids:
				if float(c.lo[b]) < float(r.z_out) - 1e-6: pitb[b] = true
			if not r.out.is_empty():
				outs[r.out[3]] += 1; oq[r.out[3]] += float(r.out_q)
			lv.append(snappedf(float(r.z_out), 0.01))
	pits.sort_custom(func(a, b): return a.objem_m3 > b.objem_m3)
	oql.sort()
	var hq := HashingContext.new(); hq.start(HashingContext.HASH_SHA256); hq.update(JSON.stringify(oql.map(func(e): return [e[0], e[1], snappedf(e[2], 1e-9)])).to_utf8_buffer())
	return {"varianta": label, "volani": res.size(), "mokra_pasma": wet.size(), "pasma_pod_hladinou": pitb.size(), "pasti_s_vodou": pits.size(),
		"pasti": pits.slice(0, 12), "hladiny_stare": lv, "vystupy": outs, "vystupy_q_lps": oq, "objem_m3": snappedf(vol, 0.1), "ms": snappedf(ms, 0.1), "vystupy_otisk": hq.finish().hex_encode().substr(0, 16), "vystupy_q": oql}

func _run(label: String, extra: Dictionary) -> Array:
	var c := _ctx(extra)
	var calls := _calls(c)
	var t0 := Time.get_ticks_usec()
	var st := {"exact": 0, "fallback": 0, "skipped": 0}
	var res := []
	for ci in calls.size(): res.append(U._one(c, calls, ci, false, false, false, 0.0625, st))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var big := 0; var sz := {}
	for b in c.lo.size():
		if c.body[b] == 1: sz[c.comp[b]] = int(sz.get(c.comp[b], 0)) + 1
	for k in sz: big = maxi(big, sz[k])
	var s := _sum(c, res, label, ms)
	s.teles = c.n_comp; s.nejvetsi_teleso_pasem = big; s.pasem_teles = sz.values().reduce(func(a, b): return a + b, 0)
	return [s, c, calls, res]

func _digest(res: Array) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	for r in res:
		var s := "%.9f|%.9f|%.9f|%s|" % [float(r.z_out), float(r.out_q), float(r.volume_m3), str(r.out)]
		if r.has("pits67"):
			for pt in r.pits67: s += "%.9f,%d,%s;" % [pt.hladina, pt.pasem, pt.typ]
			s += str(r.wet67)
		h.update(s.to_utf8_buffer())
	return h.finish().hex_encode().substr(0, 16)

func _digs(extra: Dictionary, cols: Array) -> Dictionary:
	var R := _run("dig", extra)
	var c: Dictionary = R[1]; var calls: Array = R[2]; var res: Array = R[3]
	var ms := []; var bad := 0; var st := {"exact": 0, "fallback": 0, "skipped": 0}
	for cc in cols:
		var hv := floorf((float(c.h[cc]) - 2.0) / float(c.side))
		var t0 := Time.get_ticks_usec()
		res = U.edit(c, calls, res, cc, hv, "base", 0.0625, st)
		ms.append(snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1))
		if _arg("kontrola", "1") == "1":   # čerstvý plný výpočet se stejnými výkopy
			var fr := []
			for ci in calls.size(): fr.append(U._one(c, calls, ci, false, false, false, 0.0625, {"exact": 0, "fallback": 0, "skipped": 0}))
			if _digest(fr) != _digest(res): bad += 1
	var srt := ms.duplicate(); srt.sort()
	var avg := 0.0
	for m in ms: avg += m
	return {"ms": ms, "prumer": snappedf(avg / maxf(ms.size(), 1), 0.1), "max": srt[-1] if not srt.is_empty() else 0.0, "neshod": bad,
		"preskoceno_volani": st.skipped, "prepocteno_volani": st.exact, "otisk": _digest(res)}

func _init() -> void:
	var t0 := Time.get_ticks_usec()
	_build()
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var out := {"gen_ms": gen_ms, "varianty": []}
	var V := [["stara (auto)", {}], ["stara + O", {"p67_okraj": true}], ["pretok + O", {"p67_okraj": true, "p67_rezim": "pretok"}],
		["pretok bez O", {"p67_rezim": "pretok"}], ["stara, kras jen perm>=0.3", {"p67_kras": false}],
		["pretok + O, kras jen perm>=0.3", {"p67_okraj": true, "p67_rezim": "pretok", "p67_kras": false}]]
	var keep := {}
	for v in V:
		var R := _run(v[0], v[1])
		out.varianty.append(R[0]); print(JSON.stringify(R[0]))
		keep[v[0]] = R
	# výkopy u zdrojů pretok + O: dvě pořadí, kontrola proti plnému výpočtu
	var Rp: Array = keep["pretok + O"]
	var cols := []
	var c: Dictionary = Rp[1]
	for call in Rp[2]:
		for e in call.ents:
			var cc: int = c.bcol[e]
			for d in [0, 1, c.H, -1]:
				var c2: int = cc + d
				if c.wall[c2] == 0 and not cols.has(c2): cols.append(c2)
	cols = cols.slice(0, int(_arg("vykopu", "12")))
	var d1 := _digs({"p67_okraj": true, "p67_rezim": "pretok"}, cols)
	var rev := cols.duplicate(); rev.reverse()
	var d2 := _digs({"p67_okraj": true, "p67_rezim": "pretok"}, rev)
	var d0 := _digs({}, cols)
	out.vykopy = {"sloupce": cols, "pretok_O": d1, "pretok_O_obracene": d2, "stara_base": d0, "poradi_stejny_otisk": d1.otisk == d2.otisk}
	print(JSON.stringify(out.vykopy))
	# stav pro obrázek: pásma (lo, hi, sloupec) navštívená pretok + O
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/e67"))
	FileAccess.open(_arg("out", "res://shots/e67/ostrov.json"), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	print("e67: hotovo za %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	quit()
