extends RefCounted
## KOPIE z blueprint-studie/scripts/svet64/beh64.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E50: běh světa 8 × 8 v jemných buňkách (64 × 64 × 256 na blok). Hrubý svět = E49 (svet8/beh.gd coarse),
## detail blok po bloku (blok64.gd) od první dlaždice do šířky, voda na jemné mřížce (voda64.gd).
## Měří každou fázi zvlášť (čas na stěnu, RSS, peak), zapíše shots/bench_svet64.txt a data pro GIF / izo (shots/svet64/).

const B8 = preload("res://scripts/studie_testy/beh.gd")
const DL = preload("res://scripts/teren/svet/dlazdice.gd")
const BK = preload("res://scripts/teren/svet64/blok64.gd")
const V = preload("res://scripts/teren/svet64/voda64.gd")
const M = preload("res://scripts/teren/svet64/mereni.gd")
const W = preload("res://scripts/teren/world.gd")
const Mat = preload("res://scripts/teren/zaklad/mat.gd")

static func detail(c: Dictionary, p: Dictionary, limit: int, log := true) -> Dictionary:
	var T8: int = c.t.T
	var world = W.new(); world.w = T8; world.h = T8
	var by := {}
	for e in c.tiles: by[e.slot] = e
	var f: Array = p.s8_first
	var ord := DL.order(T8, Vector2i(int(f[0]), int(f[1])))
	if limit > 0: ord = ord.slice(0, limit)
	var fine := {}; var per := []
	var t0 := Time.get_ticks_usec()
	for s in ord:
		var t1 := Time.get_ticks_usec()
		var bp: Dictionary = by[s].bp
		if int(p.s64_dutina_n) > 0 and String(bp.shape) in String(p.s64_dutina_typy).split(","):   # E50: dutiny ve světě (E49 je nemá)
			bp = bp.duplicate(true); bp.minerals[0 if String(p.s64_dutina) == "vzduch" else 250] = int(p.s64_dutina_n)
		var b := BK.run(world, s, bp, p)
		b.total = M.ms(t1)
		fine[s] = b; per.append(b)
		if log: print("blok %s %s %.0f ms (navázání %.0f, vrstvy %.0f, minerály %.0f, dutiny %.0f), RSS %.0f MB" % [str(s), by[s].bp.shape, b.total,
			b.ms["navázání"], b.ms["vrstvy"], b.ms["minerály"], b.ms["dutiny"], M.mem().rss_mb])
	return {"world": world, "order": ord, "fine": fine, "per": per, "ms": M.ms(t0)}

## švy jemných buněk: |Δ povrch| a podíl různých buněk ve sloupci přes šev vs. uvnitř (sousední sloupce uprostřed bloku)
static func seams(fine: Dictionary, n: int) -> Dictionary:
	var NZ := 4 * n
	var sh := [0.0, 0, 0.0, 0]; var sm := [0, 0, 0, 0]; var shmax := 0
	for s in fine:
		var a: Dictionary = fine[s]
		for d in 2:
			var nbs: Vector2i = s + (Vector2i(1, 0) if d == 0 else Vector2i(0, 1))
			for side in 2:   # 0 = šev k sousedovi, 1 = uvnitř (sloupec n/2 − 1 | n/2)
				var b: Dictionary
				if side == 0:
					if not fine.has(nbs): continue
					b = fine[nbs]
				else: b = a
				for t in n:
					var ia: int; var ib: int
					if d == 0:
						ia = ((n - 1) if side == 0 else (n / 2 - 1)) * n + t; ib = (0 if side == 0 else n / 2) * n + t
					else:
						ia = t * n + ((n - 1) if side == 0 else (n / 2 - 1)); ib = t * n + (0 if side == 0 else n / 2)
					var dh := absi(int(a.hm[ia]) - int(b.hm[ib]))
					sh[side * 2] += dh; sh[side * 2 + 1] += 1
					if side == 0: shmax = maxi(shmax, dh)
					var diff := 0
					var ca: PackedByteArray = a.cells; var cb: PackedByteArray = b.cells
					var ba := ia * NZ; var bb := ib * NZ
					for z in NZ:
						if ca[ba + z] != cb[bb + z]: diff += 1
					sm[side * 2] += diff; sm[side * 2 + 1] += NZ
	return {"surf_seam": sh[0] / maxf(sh[1], 1), "surf_in": sh[2] / maxf(sh[3], 1), "surf_max": shmax,
		"mat_seam": float(sm[0]) / maxf(sm[1], 1), "mat_in": float(sm[2]) / maxf(sm[3], 1)}

static func _f(v: float) -> String:
	return ("%.2f s" % (v / 1000.0)) if v >= 1000.0 else ("%.0f ms" % v)

static func run_all(p: Dictionary, out_txt: String, data_dir: String) -> PackedStringArray:
	var L := PackedStringArray()
	var n := int(p.s64_n)
	var mem0 := M.mem()
	var T0 := Time.get_ticks_usec()
	var c := B8.coarse(p, int(p.s8_frames))
	var mem_c := M.mem()
	var d := detail(c, p, int(p.s64_bloky))
	var mem_d := M.mem()
	var t0 := Time.get_ticks_usec()
	var wr := V.run(d.fine, c.t.T, p)
	var ms_voda := M.ms(t0)
	var total := M.ms(T0)
	var mem_v := M.mem()
	var T8: int = c.t.T
	L.append("# E50 svět %d × %d bloků po %d × %d × %d buňkách (%s), buňka %.3f m, svět %d × %d × %d = %.1f M buněk" % [T8, T8, n, n, 4 * n,
		Time.get_datetime_string_from_system(), 8.0 / n, T8 * n, T8 * n, 4 * n, pow(T8 * n, 2) * 4 * n / 1e6])
	L.append("stroj: %s, %d jader, Godot %s, GDScript na 1 vlákně" % [OS.get_processor_name(), OS.get_processor_count(), Engine.get_version_info().string])
	L.append("")
	L.append("| fáze | čas | RSS po fázi |")
	L.append("|---|---|---|")
	var cs := 0.0
	for k in c.ms: L.append("| %s | %s | |" % [k, _f(c.ms[k])]); cs += float(c.ms[k])
	L.append("| **hrubý svět celkem** | **%s** | %.0f MB |" % [_f(cs), mem_c.rss_mb])
	var keys := ["navázání", "vrstvy", "minerály", "dutiny"]
	var per: Array = d.per
	for k in keys:
		var st := M.stats(per.map(func(b): return float(b.ms[k])))
		L.append("| 6 blok: %s | Σ %s (min %s / med %s / max %s) | |" % [k, _f(st.sum), _f(st.min), _f(st.med), _f(st.max)])
	var withc := per.filter(func(b): return int(b.cav_target) > 0)
	if not withc.is_empty():
		var cst := M.stats(withc.map(func(b): return float(b.ms["dutiny"])))
		L.append("| 6 blok: dutiny jen v %d blocích s dutinou | min %s / med %s / max %s | |" % [withc.size(), _f(cst.min), _f(cst.med), _f(cst.max)])
	var bt := M.stats(per.map(func(b): return float(b.total)))
	L.append("| **6 detail %d bloků** | **%s** (blok min %s / med %s / max %s) | %.0f MB |" % [per.size(), _f(d.ms), _f(bt.min), _f(bt.med), _f(bt.max), mem_d.rss_mb])
	for k in wr.ms: L.append("| 7 voda: %s | %s | |" % ["mřížka (+ 3D buňky podzemí)" if k == "mřížka" else k, _f(wr.ms[k])])
	L.append("| **7 voda celkem** (mřížka %d × %d, %d na blok) | **%s** | %.0f MB |" % [wr.W, wr.W, wr.nv, _f(ms_voda), mem_v.rss_mb])
	L.append("| **CELKEM generování** | **%s** | peak %.0f MB |" % [_f(total), mem_v.peak_mb])
	L.append("")
	L.append("paměť: start RSS %.0f MB; po hrubém %.0f; po detailu %.0f; po mřížce vody %.0f; po podzemí %.0f; peak (VmHWM) %.0f MB; Godot static %.0f MB" % [
		mem0.rss_mb, mem_c.rss_mb, mem_d.rss_mb, wr.mem_grid.rss_mb, wr.get("mem_ug", wr.mem_grid).rss_mb, mem_v.peak_mb, mem_v.godot_mb])
	# podle typu dlaždice
	var by := {}
	for e in c.tiles: by[e.slot] = e.bp.shape
	var ty := {}
	for b in per:
		var k: String = by[b.slot]
		if not ty.has(k): ty[k] = []
		ty[k].append(float(b.total))
	L.append("blok podle typu (medián): " + ", ".join(ty.keys().map(func(k): return "%s %s (%d)" % [k, _f(M.stats(ty[k]).med), ty[k].size()])))
	var slow: Dictionary = per[0]
	for b in per: if float(b.total) > float(slow.total): slow = b
	L.append("nejpomalejší blok %s %s: %s" % [str(slow.slot), by[slow.slot], _f(slow.total)])
	var mt := 0; var msh := 0; var ct := 0; var cp := 0
	for b in per: mt += int(b.min_target); msh += int(b.min_short); ct += int(b.cav_target); cp += int(b.cav_placed)
	L.append("minerály: cíl %d buněk (× (n/16)³), schodek %d; dutiny %d / %d buněk" % [mt, msh, cp, ct])
	var sm := seams(d.fine, n)
	L.append("švy jemných buněk: povrch |Δ| %.2f buňky (uvnitř %.2f, max %d); jiné buňky ve sloupci přes šev %.2f %% (uvnitř %.2f %%)" % [
		sm.surf_seam, sm.surf_in, sm.surf_max, 100.0 * sm.mat_seam, 100.0 * sm.mat_in])
	var cm := 8.0 / int(wr.nv)
	var s1 := V.summary(wr.surf, cm)
	var qs := 0.0
	for sp in wr.springs: qs += float(sp.q)
	L.append("voda: %d pramenů %.1f l/s; povrch: %d mokrých sloupců, %d zahloubených (medián %.2f m, max %.2f m), %d vodopádů, okraj %d × %.2f l/s, tůně %d (%d sloupců)" % [
		wr.springs.size(), qs, s1.wet, s1.carved, s1.med_m, s1.max_m, s1.falls, s1.edge_n, s1.edge_q, s1.ponds, s1.pond_m3])
	if wr.has("both"):
		var s2 := V.summary(wr.both, cm)
		for bd in wr.both.st.get("ug_bodies", []):
			L.append("  podzemní těleso: %d buněk, přítok %.2f l/s, průsak %.2f, výstup %s, uzavřené %s, plní se %s, objem do výstupu %.1f m³, z %d–%d" % [
				int(bd.cells), float(bd.q_in), float(bd.leak), str(bd.out[3]) + " z " + str(bd.out[0]) if bd.out is Array and bd.out.size() > 3 else "—",
				str(bd.get("closed", false)), "ne" if bd.get("never_fills", false) else "ano", float(bd.volume_m3), int(bd.zmin), int(bd.get("z_out", -1))])
		L.append("voda s podzemím: okraj po povrchu %.2f l/s, z podzemí %d výtoků %.2f l/s, těles %d (%d buněk), ztráty %.2f l/s, mokrých %d" % [
			s2.edge_q, s2.under_n, s2.under_q, s2.bodies, s2.body_cells, s2.lost, s2.wet])
	var h := BK.hash_cells(d.fine, d.order)
	L.append("hash jemných buněk %s" % h.left(16))
	var dn := int(p.s64_det_bloky)
	if dn > 0:
		var d2 := detail(B8.coarse(p, int(p.s8_frames)), p, dn, false)
		var h1 := BK.hash_cells(d.fine, d.order.slice(0, dn)); var h2 := BK.hash_cells(d2.fine, d2.order)
		L.append("determinismus prvních %d bloků 2×: %s / %s → %s" % [dn, h1.left(12), h2.left(12), "STEJNÉ" if h1 == h2 else "RŮZNÉ!"])
	if bool(p.s64_e49):
		var t9 := Time.get_ticks_usec()
		var d9 := B8.detail(c, p)
		L.append("srovnání E49 (16 × 16 × 64, celá pipeline v2 s validátorem): detail %s, blok průměr %s; poměr E50/E49 %.0f ×" % [
			_f(M.ms(t9)), _f(M.ms(t9) / d9.per.size()), d.ms / maxf(M.ms(t9), 1.0) * d9.per.size() / maxf(per.size(), 1)])
	FileAccess.open(out_txt, FileAccess.WRITE).store_string("\n".join(L) + "\n")
	if bool(p.s64_data): save(c, d, wr, n, data_dir)
	return L

## binární data pro GIF (Python) a izo (Godot): povrch, vrch materiálu, voda, řezy na dvou okrajích světa
static func save(c: Dictionary, d: Dictionary, wr: Dictionary, n: int, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var T8: int = c.t.T; var S := T8 * n; var NZ := 4 * n
	var hf := PackedFloat32Array(); hf.resize(S * S)
	var top := PackedByteArray(); top.resize(S * S)
	var cutx := PackedByteArray(); cutx.resize(S * NZ)   # řez x = S − 1 (index y · NZ + z)
	var cuty := PackedByteArray(); cuty.resize(S * NZ)   # řez y = S − 1 (index x · NZ + z)
	var ordm := PackedInt32Array(); ordm.resize(T8 * T8); ordm.fill(-1)
	for k in d.order.size():
		var s: Vector2i = d.order[k]; ordm[s.x * T8 + s.y] = k
		var b: Dictionary = d.fine[s]
		for x in n:
			for y in n:
				var i := x * n + y; var g := (s.x * n + x) * S + s.y * n + y
				hf[g] = b.hf[i]
				var h: int = b.hm[i]
				top[g] = b.cells[i * NZ + h - 1] if h > 0 else 0
				if s.x == T8 - 1 and x == n - 1:
					for z in NZ: cutx[(s.y * n + y) * NZ + z] = b.cells[i * NZ + z]
				if s.y == T8 - 1 and y == n - 1:
					for z in NZ: cuty[(s.x * n + x) * NZ + z] = b.cells[i * NZ + z]
	var r: Dictionary = wr.get("both", wr.surf)
	var Wv: int = wr.W
	var wat := PackedByteArray(); wat.resize(Wv * Wv)   # 1 koryto, 2 tůň, 3 pramen, 4 vodopád, 5 výtok z podzemí
	var effv := PackedFloat32Array(); effv.resize(Wv * Wv)
	var st: Dictionary = r.st
	TOK_mask(st)
	for i in Wv * Wv:
		effv[i] = r.eff[i]
		if r.eff[i] >= float(st.L.thr): wat[i] = 1
		if st.pw[i] == 1: wat[i] = 2
	for f in r.falls: wat[f.top] = 4
	for u in st.under: if int(u.exit) >= 0: wat[int(u.exit)] = 5
	for sp in wr.springs: wat[sp.gi] = 3
	var post := PackedFloat32Array(); post.resize(Wv * Wv)
	var fillv := PackedFloat32Array(); fillv.resize(Wv * Wv)
	for i in Wv * Wv: post[i] = wr.hm_post[i]; fillv[i] = st.fill[i]
	for e in [["hf.f32", hf.to_byte_array()], ["top.u8", top], ["cutx.u8", cutx], ["cuty.u8", cuty], ["wat.u8", wat], ["eff.f32", effv.to_byte_array()],
		["post.f32", post.to_byte_array()], ["fill.f32", fillv.to_byte_array()], ["order.i32", ordm.to_byte_array()]]:
		FileAccess.open(dir + "/" + e[0], FileAccess.WRITE).store_buffer(e[1])
	var meta := {"S": S, "NZ": NZ, "n": n, "T": T8, "Wv": Wv, "cell_m": 8.0 / n, "pal": Array(preload("res://scripts/teren/horniny.gd").palette()).map(func(cc): return cc.to_html(false)),
		"R": c.t.R, "raw": Array(c.raw), "rain": Array(c.w.rain), "ero": c.ef.map(func(a): return Array(a)), "hm": Array(c.t.hm), "acc": Array(c.rv.acc),
		"river": Array(c.rv.river), "lake": Array(c.rv.lake), "bio": Array(c.bio),
		"tiles": c.tiles.map(func(e): return {"slot": [e.slot.x, e.slot.y], "shape": e.bp.shape})}
	FileAccess.open(dir + "/meta.json", FileAccess.WRITE).store_string(JSON.stringify(meta))

static func TOK_mask(st: Dictionary) -> void:
	preload("res://scripts/voda/tok.gd").pond_mask(st)
