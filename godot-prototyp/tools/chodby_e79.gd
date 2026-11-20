extends "res://tools/prekryv_e78.gd"
## E79: lokální přepočet vody po změně dutin (ostrov_voda.edit79, p79_chodby) proti plnému přepočtu a proti staré cestě
## E78 (edit jen po sloupcích se změněnou výškou). Scénáře E78 + chodba přes zvodnělou vrstvu + šachta z povrchu do dna
## tůně, obě pořadí kopání. Volby: --scenare=... --rezimy=stara,e79 --out=cesta (spouštět s --bp.p76_prameny=true)

func box(blocks: Dictionary, touched: Dictionary, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, mat := 0) -> int:
	var n := 0
	for gx in range(mini(x0, x1), maxi(x0, x1) + 1):
		for gy in range(mini(y0, y1), maxi(y0, y1) + 1):
			if gx < 0 or gy < 0 or gx > 63 or gy > 63: continue
			for fz in range(z0, z1):
				if fop(blocks, touched, gx, gy, fz, mat): n += 1
	return n

## dávky operací: Array[Callable(blocks, touched) -> int]
func batches_for(name: String, blocks: Dictionary, v) -> Array:
	var b := []
	match name:
		"tunel", "tunel_obracene":
			var L := 60; var y0 := 14; var x0 := 2
			var low := 999
			for gx in range(x0, x0 + L):
				for gy in range(y0, y0 + 4): low = mini(low, surf(blocks, gx, gy))
			var top := low - 12; var bot := top - 8
			var sh := func(bl, t):
				var n := 0
				for gx in range(x0, x0 + 4):
					for gy in range(y0, y0 + 4): n += box(bl, t, gx, gx, gy, gy, bot, surf(bl, gx, gy))
				return n
			var tu := func(bl, t): return box(bl, t, x0, x0 + L - 1, y0, y0 + 3, bot, top)
			var pl := func(bl, t):
				var n := 0
				for gx in range(40, 44):
					for gy in range(40, 44):
						var s0 := surf(bl, gx, gy); n += box(bl, t, gx, gx, gy, gy, s0, s0 + 2, DIRT)
				return n
			var fi := func(bl, t): return box(bl, t, x0 + L - 2, x0 + L - 1, y0, y0 + 1, bot, bot + 2, DIRT)
			b = [sh, tu, pl, fi] if name == "tunel" else [tu, fi, pl, sh]
		"dlouhy":
			b = [func(bl, t): return sc_dlouhy(bl, t)]
		"n1", "n10", "n100", "n1000":
			var cnt := int(name.substr(1))
			b = [func(bl, t): return sc_rand(bl, t, cnt)]
		"zvodnela", "zvodnela_obracene":
			var g := _aquifer(v)
			if g.is_empty(): return []
			var gx: int = g.gx; var gy: int = g.gy; var z0: int = g.z0; var z1: int = g.z1
			var sx := clampi(gx - 20, 0, 59)   # šachta 5 m od místa ve vrstvě
			var sh := func(bl, t):
				var n := 0
				for x in range(sx, sx + 4):
					for y in range(gy, gy + 4): n += box(bl, t, x, x, y, y, z0, surf(bl, x, y))
				return n
			var tu := func(bl, t): return box(bl, t, sx, mini(gx + 12, 63), gy, gy + 3, z0, z1)
			b = [sh, tu] if name == "zvodnela" else [tu, sh]
			_info = g
		"tun", "tun_obracene":
			var g := _pond(v, blocks)
			if g.is_empty(): return []
			var px: int = g.px; var py: int = g.py; var pb: int = g.pb; var sx: int = g.sx; var sy: int = g.sy
			var top := pb - 4; var bot := top - 8
			var sh := func(bl, t):
				var n := 0
				for x in range(sx, sx + 4):
					for y in range(sy, sy + 4): n += box(bl, t, x, x, y, y, bot, surf(bl, x, y))
				return n
			var tu := func(bl, t): return box(bl, t, sx, px + 3, sy, sy + 3, bot, top) + box(bl, t, px, px + 3, sy, py + 3, bot, top)
			var pr := func(bl, t): return box(bl, t, px, px + 3, py, py + 3, top, pb + 1)
			b = [sh, tu, pr] if name == "tun" else [tu, pr, sh]
			_info = g
	return b

var _info := {}

## místo ve zvodnělé vrstvě: těleso s vodou (q_in > 0), pásmo s hladinou aspoň 1 m nad spodkem, uvnitř ostrova
func _aquifer(v) -> Dictionary:
	var ug: Dictionary = v.ug
	var best := {}
	for r in v.st.get("ug_bodies", []):
		if bool(r.closed) or float(r.q_in) <= 0.0 or r.entries.is_empty(): continue
		var id: int = ug.comp[r.entries[0]]; var L := float(r.z_out)
		for bb in ug.lo.size():
			if ug.comp[bb] != id or ug.body[bb] == 0 or ug.mat[bb] == 0: continue
			var lo := float(ug.lo[bb]); var hi := minf(float(ug.hi[bb]), L)
			if hi - lo < 1.0: continue
			var a: Array = v.slot_of(int(ug.bcol[bb]))
			if v.island[int(ug.bcol[bb])] == 0 or not v.blocks.has(a[0]): continue
			var gx: int = a[0].x * 32 + 2 * a[1]; var gy: int = a[0].y * 32 + 2 * a[2]
			if gx < 22 or gy > 58: continue
			var z0 := int(ceil(lo / 0.25)); z0 += z0 % 2
			var z1 := mini(z0 + 8, int(floor(hi / 0.25)))
			var d := {"gx": gx, "gy": gy, "z0": z0, "z1": z1, "lo_m": lo, "hladina_m": L, "q_in": float(r.q_in), "teleso": id, "mat": int(ug.mat[bb])}
			if best.is_empty() or float(r.q_in) > float(best.q_in) or (float(r.q_in) == float(best.q_in) and hi - lo > float(best.get("m", 0.0))):
				d.m = hi - lo; best = d
	return best

## nejhlubší tůň uvnitř ostrova + suchý sloupec 3–6 sloupců od ní na šachtu
func _pond(v, blocks: Dictionary) -> Dictionary:
	var best := -1; var bd := 0.0
	for gi in v.W * v.H:
		if v.island[gi] == 0 or not v.is_pond(gi): continue
		var a: Array = v.slot_of(gi)
		if a[1] < 1 or a[2] < 1 or a[1] > 14 or a[2] > 14: continue
		var d: float = v.st.fill[gi] - v.st.hm[gi]
		if d > bd: bd = d; best = gi
	if best < 0: print("  tůň: žádná uvnitř bloku"); return {}
	var a: Array = v.slot_of(best)
	var px: int = a[0].x * 32 + 2 * a[1]; var py: int = a[0].y * 32 + 2 * a[2]
	for r in range(3, 11):
		for dv in [[r, 0], [-r, 0], [0, r], [0, -r]]:
			var sx: int = px + 2 * int(dv[0]); var sy: int = py + 2 * int(dv[1])
			if sx < 0 or sx > 60 or sy < 0 or sy > 60: continue
			var a2 := at(sx, sy)
			if not blocks.has(a2[0]): continue
			var g2: int = v.gi_of(a2[0], a2[1] / 2, a2[2] / 2)
			if not v.is_pond(g2) and v.level(g2) < 0.0:
				return {"px": px, "py": py, "pb": surf(blocks, px, py), "sx": sx, "sy": sy, "hloubka_m": bd * 0.5, "gi": best}
	print("  tůň %d: bez suchého místa na šachtu" % best)
	return {}

static func diff2(s1: Dictionary, s2: Dictionary) -> Dictionary:
	var o := {}
	for k in ["fill", "eff", "extra", "src2", "to"]:
		var a := []
		for i in s1[k].size():
			if s1[k][i] != s2[k][i]: a.append([i, s1[k][i], s2[k][i], s1.hm[i], s2.hm[i]])
		o[k] = a.slice(0, 6); o[k + "_n"] = a.size()
	var u1 := []; var u2 := []
	for u in s1.get("under", []): u1.append("%d|%d|%.9f|%.6f|%s" % [int(u.from), int(u.exit), float(u.q), float(u.z), String(u.typ)])
	for u in s2.get("under", []): u2.append("%d|%d|%.9f|%.6f|%s" % [int(u.from), int(u.exit), float(u.q), float(u.z), String(u.typ)])
	o.under_jen_lokalne = u1.filter(func(x): return not x in u2)
	o.under_jen_plne = u2.filter(func(x): return not x in u1)
	return o

func run79(name: String, mode: String) -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var v := OV.new(); v.build(blocks)
	var w0: String = v.hydro().otisk
	_info = {}
	var bs := batches_for(name, blocks, v)
	if bs.is_empty(): print("%s: scénář nenalezen" % name); v.dispose(); return {"scenar": name, "nenalezen": true}
	var n := 0; var loc_ms := 0.0; var log := []
	for bf in bs:
		var touched := {}
		n += int(bf.call(blocks, touched))
		var t0 := Time.get_ticks_usec()
		var zm := {}
		for s in touched:
			var d: Dictionary = P78.sync79(blocks[s])
			if mode == "e79": zm[s] = d.geo
			else:
				for ci in d.hm:
					v.edit(s, ci / 16, ci % 16, int(blocks[s].hm[ci]))
					while v.pending(): v.step()
		var e := {}
		if mode == "e79": e = v.edit79(zm)
		var bms := (Time.get_ticks_usec() - t0) / 1000.0
		loc_ms += bms
		var lg := {"cesta": e.get("cesta", "stara"), "ms": bms, "edit79_ms": e.get("ms", 0.0), "podzemi_ms": e.get("podzemi_ms", 0.0), "okno": e.get("okno", 0), "voda": v.hydro().otisk}
		if _arg("kazda", "1") == "1":   # plný přepočet po každé dávce (kontrola, do času se nepočítá)
			var vb := OV.new(); vb.build(blocks); lg.voda_plne = vb.hydro().otisk; lg.shoda = lg.voda == lg.voda_plne; lg.neshod = diff(v.st, vb.st)
			if not lg.shoda: lg.rozdil = diff2(v.st, vb.st); print("  dávka ", log.size(), " rozdíl: ", JSON.stringify(lg.rozdil))
			vb.dispose()
		log.append(lg)
	var w_loc: String = v.hydro().otisk
	if _arg("ladit", "") == "1":
		var st2: Dictionary = v.st.duplicate(true); st2.ug = v.ug; st2.ug_cache = {}
		v._route(st2)
		print("  ladění: plný _route nad lokálním stavem → ", OV.H68.otisk(st2))
	var bil_loc: Dictionary = v.hydro().bilance
	var vf := OV.new(); var t1 := Time.get_ticks_usec(); vf.build(blocks); var full_ms := (Time.get_ticks_usec() - t1) / 1000.0
	var w_full: String = vf.hydro().otisk
	if _arg("ladit", "") == "1":   # E85: obsazení a plný výpočet se stejným obsazením (check_full) proti čerstvému
		var c1 := v.claims.keys(); c1.sort(); var c2 := vf.claims.keys(); c2.sort()
		var cf: Dictionary = v.check_full()
		print("  ladění: obsazeno lokálně %s čerstvě %s; check_full %s %s; čerstvý %s" % [str(c1), str(c2), JSON.stringify(cf), v.full_otisk, w_full])
	var bil_full: Dictionary = vf.hydro().bilance
	var d := diff(v.st, vf.st)
	var dd := diff2(v.st, vf.st)
	if w_loc != w_full: print("  rozdíl: ", JSON.stringify(dd))
	var r := {"rozdil": dd, "scenar": name, "rezim": mode, "zmen": n, "davek": bs.size(), "voda_puvodni": w0, "voda_lokalne": w_loc, "voda_plne": w_full,
		"shoda": w_loc == w_full, "neshod": d, "chyba_bilance_lokalne": float(bil_loc.chyba_svet), "chyba_bilance_plne": float(bil_full.chyba_svet),
		"lokalne_ms": loc_ms, "plne_ms": full_ms, "davky": log, "bunky": P78.otisk(blocks), "info": _info.duplicate(),
		"pod_vstup_lokalne": float(bil_loc.podzemi_vstup), "pod_vstup_plne": float(bil_full.podzemi_vstup), "prameny_lokalne": float(bil_loc.prameny_z_podzemi), "prameny_plne": float(bil_full.prameny_z_podzemi)}
	print("%s [%s]: %d změn v %d dávkách, voda lokálně %s plně %s (původně %s) shoda %s neshod %s, bilance %s / %s, lokálně %.0f ms, plně %.0f ms, buňky %s; dávky %s" % [name, mode, n, bs.size(), w_loc, w_full, w0, str(r.shoda), str(d), String.num_scientific(r.chyba_bilance_lokalne), String.num_scientific(r.chyba_bilance_plne), loc_ms, full_ms, r.bunky, str(log.map(func(x): return [x.cesta, int(x.ms), x.voda, x.get("shoda", "?")]))])
	v.dispose(); vf.dispose()
	return r

func _init() -> void:
	if get_script().resource_path != "res://tools/chodby_e79.gd": return   # E80 nástroj dědí pomocné funkce
	var out := []
	for name in _arg("scenare", "tunel,tunel_obracene,dlouhy,n1,n10,n100,n1000,zvodnela,zvodnela_obracene,tun,tun_obracene").split(","):
		for mode in _arg("rezimy", "stara,e79").split(","): out.append(run79(name, mode))
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
