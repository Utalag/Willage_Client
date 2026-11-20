extends "res://tools/determinismus_e83.gd"
## E85: rozhodnutí Bloku 2 (Jan 2026-11-20 03:26) za příznakem p85_blok2 / p85_jemne / p85_okraj / p85_vrstvy.
## Části: --casti=jemne,okraj,vrstvy,voda --out=cesta
## jemne  = definice 0,25 m z funkcí proti zjemnění 0,5 m: čas, rozdíl, nedotčený blok po sync beze změny
## okraj  = šachta na dno, chodba ven bokem, chodba přes vnitřní šev, náhodné výkopy → dno a obvod plné
## vrstvy = tenké vrstvy (< 0,25 m) před a po, co zbude (ořez povrchem / krytem), buňky jinak, vrstvy bez buňky
## voda   = otisky generování → voda → chodba (E78) → edit79 → uložení → načtení s příznaky (p74_*, p76 výchozí zapnuté)
const UF = preload("res://scripts/voda/podzemi/ug_funkce.gd")

func flags_on(f: Dictionary) -> void:
	T.reset()
	for k in f: T.p[k] = f[k]

func gen(f: Dictionary) -> Array:
	flags_on(f)
	return gen_blocks(START)

static func ndiff(a: PackedByteArray, b: PackedByteArray, skip := {}) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i] and not (skip.has(int(a[i])) or skip.has(int(b[i]))): n += 1
	return n

# ---------------- 1) 0,25 m z funkcí ----------------
func part_jemne() -> Dictionary:
	var out := {"bloky": []}
	var g := gen({"p85_jemne": true}); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var tot := {"bunek": 0, "jine": 0, "jine_bez_min_dutin": 0, "pevne_vzduch": 0}
	for s in order:
		var b = blocks[s]
		var t0 := Time.get_ticks_usec(); var f := P78.fine_fn(b); var tf := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec(); var r := P78.refine(b.def78); var tr := (Time.get_ticks_usec() - t0) / 1000.0
		var skip := {}
		for m in T.world.slots[T.wslot(s)].bp.minerals: skip[int(m)] = true
		skip[0] = false; skip.erase(0)
		var d := ndiff(f, r); var dm := ndiff(f, r, skip)
		var sa := 0
		for i in f.size():
			if (f[i] == 0) != (r[i] == 0): sa += 1
		# nedotčený blok: sync z definice 0,25 m nesmí změnit buňky 0,5 m ani výšky; překryv prázdný
		var geo0: PackedByteArray = b.geo.duplicate(); var hm0: PackedInt32Array = b.hm.duplicate()
		P78.fine(b); var sy := P78.sync79(b)
		var row := {"slot": [s.x, s.y], "ms_z_funkci": tf, "ms_zjemneni": tr, "jine": d, "jine_proc": 100.0 * d / f.size(),
			"jine_bez_mineralu_dutin": dm, "pevne_vzduch": sa, "sync_zmeneno_geo": ndiff(geo0, b.geo), "sync_hm": sy.hm.size(),
			"sync_geo_sloupcu": sy.geo.size(), "prekryv_nedotceny": P78.overlay(b).size(), "def85_stejne_jako_attach": f == b.def85}
		out.bloky.append(row)
		tot.bunek += f.size(); tot.jine += d; tot.jine_bez_min_dutin += dm; tot.pevne_vzduch += sa
		print("jemné %s: z funkcí %.0f ms, zjemnění %.1f ms; jiné %d (%.2f %%), bez minerálů a dutin %d, pevné/vzduch %d; nedotčený: geo %d, hm %d, překryv %d" % [str(s), tf, tr, d, row.jine_proc, dm, sa, row.sync_zmeneno_geo, row.sync_hm, row.prekryv_nedotceny])
	out.celkem = tot
	# jedna 0,25 m operace: změní jen svou buňku 0,5 m (zbytek bloku zůstane podle pipeline)
	var b = blocks[order[0]]
	var geo0: PackedByteArray = b.geo.duplicate()
	var fz := -1
	for z in range(127, -1, -1):
		if P78.fine(b)[P78.fidx(10, 10, z)] != 0: fz = z; break
	P78.op(b, 10, 10, fz, 0); P78.sync79(b)
	out.jedna_operace = {"geo_jinak": ndiff(geo0, b.geo), "prekryv": P78.overlay(b).size()}
	print("jedna operace 0,25 m: buněk 0,5 m jinak %d, překryv %d" % [out.jedna_operace.geo_jinak, out.jedna_operace.prekryv])
	return out

# ---------------- 2) dno a okraj ----------------
func part_okraj() -> Dictionary:
	var out := {}
	for on in [false, true]:
		var g := gen({"p85_okraj": on}); var blocks: Dictionary = g[0]
		var touched := {}
		var r := {}
		# šachta 1 × 1 m (4 × 4 jemné) uprostřed bloku (0,0) z povrchu až na z = 0
		var ok := 0; var no := 0; var no_dno := 0
		for gx in range(14, 18):
			for gy in range(14, 18):
				for fz in range(surf(blocks, gx, gy) - 1, -1, -1):
					if fop(blocks, touched, gx, gy, fz, 0): ok += 1
					else:
						no += 1
						if fz == 0: no_dno += 1
		r.sachta = {"vykopano": ok, "odmitnuto": no, "odmitnuto_dno": no_dno}
		# chodba ve výšce 3 m ven bokem: z x = 20 na x = 0 (západ bloku (0,0), bez souseda) a z y = 20 na y = 0
		var cz := 12
		var side := {"zapad": [0, 0], "sever": [0, 0]}
		for gx in range(20, -1, -1):
			for gy in range(20, 24):
				if fop(blocks, touched, gx, gy, cz, 0): side.zapad[0] += 1
				else: side.zapad[1] += 1
		for gy in range(20, -1, -1):
			for gx in range(24, 28):
				if fop(blocks, touched, gx, gy, cz, 0): side.sever[0] += 1
				else: side.sever[1] += 1
		r.bok = side
		# chodba přes vnitřní šev (0,0) | (1,0) a (0,0) | (0,1)
		var sev := [0, 0]
		for gx in range(26, 38):
			for gy in range(8, 10):
				if fop(blocks, touched, gx, gy, cz, 0): sev[0] += 1
				else: sev[1] += 1
		for gy in range(26, 38):
			for gx in range(8, 10):
				if fop(blocks, touched, gx, gy, cz, 0): sev[0] += 1
				else: sev[1] += 1
		r.vnitrni_sev = {"vykopano": sev[0], "odmitnuto": sev[1]}
		# 3000 náhodných výkopů po celém ostrově, i na dně a okraji
		var rng := RandomNumberGenerator.new(); rng.seed = 85
		var rn := [0, 0]
		for i in 3000:
			var gx := rng.randi_range(0, 63); var gy := rng.randi_range(0, 63); var fz := rng.randi_range(0, 3)
			if fop(blocks, touched, gx, gy, fz, 0): rn[0] += 1
			else: rn[1] += 1
		r.nahodne = {"vykopano": rn[0], "odmitnuto": rn[1]}
		# kontrola: díry ve dnu (vrstva z = 0 vzduch) a v obvodu (obvodový sloupec ostrova má vykopanou buňku pod původním povrchem)
		var holes := 0; var rim := 0
		for s in blocks:
			var b = blocks[s]; var f := P78.fine(b); var d := P78.deffine(b)
			for fx in 32:
				for fy in 32:
					if f[P78.fidx(fx, fy, 0)] == 0: holes += 1
					var gx: int = s.x * 32 + fx; var gy: int = s.y * 32 + fy
					if gx == 0 or gy == 0 or gx == 63 or gy == 63:
						for fz in 128:
							var i := P78.fidx(fx, fy, fz)
							if d[i] != 0 and f[i] == 0: rim += 1
		r.dno_der = holes; r.obvod_vykopano = rim
		# položit do obvodu a na dno jde (jen kopat je zakázané)
		var b0 = blocks[Vector2i(0, 0)]
		r.polozit_dno_sachty = P78.op(b0, 14, 14, 0, DIRT)
		out["zapnuto" if on else "vypnuto"] = r
		print("okraj %s: %s" % ["zapnuto" if on else "vypnuto", JSON.stringify(r)])
	return out

# ---------------- 3) vrstvy ≥ 0,25 m ----------------
func thin_stats(f: Dictionary) -> Dictionary:
	var g := gen(f); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var wf := wf_all()
	var r := {"sloupcu": 0, "tenkych_def": 0, "tenkych_viditelnych": 0, "min_viditelna_m": 9.0, "vrstev_sloupec_prumer": 0.0, "bez_bunky_05": 0, "bez_bunky_025": 0,
		"vrstev_ve_sloupci": 0, "cells16": {}, "cells32": {}, "otisk_geo": blocks_hash(blocks, order, "geo")}
	var tmin := 0.25
	for s in order:
		var b = blocks[s]; var info := info_of(wf, b)
		var c32 := FN.sample_all(wf, info, 32)
		r.cells16[str(s)] = b.geo; r.cells32[str(s)] = c32
		var ox: float = info.slot.x * FN.BW; var oy: float = info.slot.y * FN.BW
		for x in 32:
			for y in 32:
				var X := ox + (x + 0.5) * 0.25; var Y := oy + (y + 0.5) * 0.25
				var col := FN.column(wf, info, X, Y)
				r.sloupcu += 1
				var bs: PackedFloat64Array = col.bs; var lo := 0.0
				for k in bs.size():
					var t := bs[k] - lo
					if t > 1e-9 and t < tmin - 1e-9: r.tenkych_def += 1
					lo = maxf(lo, bs[k])
				# viditelné vrstvy (pásma vody: kryt půdy, kůže hor, ořez povrchem)
				var present := {}
				for bd in UF.bands(info, col, X, Y):
					var m := int(bd[2]); var t: float = bd[1] - bd[0]
					if not (m in info.lay): continue
					r.vrstev_ve_sloupci += 1; present[m] = true
					if t < tmin - 1e-9: r.tenkych_viditelnych += 1; r.min_viditelna_m = minf(r.min_viditelna_m, t)
				# vrstva podle funkce ve sloupci, ale žádná buňka (0,25 m: tento sloupec; 0,5 m: sloupec x/2, y/2)
				var nz32 := 128; var have32 := {}; var have16 := {}
				for z in nz32: have32[c32[(x * 32 + y) * nz32 + z]] = true
				for z in 64: have16[b.geo[((x / 2) * 16 + y / 2) * 64 + z]] = true
				for m in present:
					if not have32.has(m): r.bez_bunky_025 += 1
					if not have16.has(m): r.bez_bunky_05 += 1
	r.vrstev_sloupec_prumer = float(r.vrstev_ve_sloupci) / r.sloupcu
	return r

func part_vrstvy() -> Dictionary:
	var a := thin_stats({}); var b := thin_stats({"p85_vrstvy": true})
	var d16 := 0; var d32 := 0
	for k in a.cells16:
		d16 += ndiff(a.cells16[k], b.cells16[k]); d32 += ndiff(a.cells32[k], b.cells32[k])
	for r in [a, b]: r.erase("cells16"); r.erase("cells32")
	# šev: hranice ze dvou sousedních bloků ve stejném bodě švu (s příznakem)
	var g := gen({"p85_vrstvy": true}); var wf := wf_all()
	var bl: Dictionary = g[0]
	var ia := info_of(wf, bl[Vector2i(0, 0)]); var ib := info_of(wf, bl[Vector2i(1, 0)])
	var seam: float = (ia.slot.x + 1) * FN.BW; var sd := 0
	for t in 64:
		var Y: float = ia.slot.y * FN.BW + (t + 0.5) * 0.125
		var ca := FN.column(wf, ia, seam, Y); var cb := FN.column(wf, ib, seam, Y)
		for k in ca.bs.size():
			if absf(ca.bs[k] - cb.bs[k]) > 1e-9: sd += 1
	var out := {"vypnuto": a, "zapnuto": b, "bunky_jinak_05": d16, "bunky_jinak_025": d32, "sev_hranic_jinak": sd}
	print("vrstvy vypnuto: ", JSON.stringify(a)); print("vrstvy zapnuto: ", JSON.stringify(b))
	print("vrstvy buňky jinak 0,5 m %d / 65 536, 0,25 m %d / 524 288; šev hranic jinak %d" % [d16, d32, sd])
	return out

# ---------------- 4) voda ----------------
func part_voda() -> Dictionary:
	var out := {}
	var variants := {"vychozi": {}, "p79": {"p79_chodby": true}, "p85_blok2": {"p85_blok2": true}, "p85_blok2_p79": {"p85_blok2": true, "p79_chodby": true}, "p79_p85_voda": {"p79_chodby": true, "p85_voda": true}}
	for vn in variants:
		var a := fingerprint(START, variants[vn]); var b := fingerprint(START, variants[vn])
		var ok: bool = a.prekryv == a.nacteno and a.voda_lokalne == a.voda_plne and a.voda_plne == a.voda_nacteno
		out[vn] = {"otisky": a, "druhy_beh_stejny": a == b, "lokalne_plne_nacteno": ok,
			"prepinace": {"p74_gw": T.p.get("p74_gw"), "p74_vyzvednout": T.p.get("p74_vyzvednout"), "p74_hladina": T.p.get("p74_hladina"), "p76_prameny": T.p.get("p76_prameny")}}
		print("voda %s: 2× stejné %s, překryv = načtený a voda lokálně = plně = načtená %s; %s" % [vn, a == b, ok, JSON.stringify(a)])
	return out

## E85: který přepínač E74/E76 rozbije lokální = plný u edit79 (každý zvlášť vypnutý)
func part_voda74() -> Dictionary:
	var out := {}
	var base := {"p79_chodby": true}
	var variants := {"p79": {}, "bez_gw": {"p74_gw": false}, "bez_vyzvednout": {"p74_vyzvednout": false}, "bez_hladina": {"p74_hladina": false},
		"bez_prameny": {"p76_prameny": false}, "bez_p74": {"p74_gw": false, "p74_vyzvednout": false, "p74_hladina": false}}
	for vn in variants:
		var fl := base.duplicate(); fl.merge(variants[vn], true)
		var a := fingerprint(START, fl)
		out[vn] = {"voda_lokalne": a.voda_lokalne, "voda_plne": a.voda_plne, "voda_nacteno": a.voda_nacteno, "lokalne_plne": a.voda_lokalne == a.voda_plne}
		print("voda74 %s: lokálně %s plně %s načteno %s → %s" % [vn, a.voda_lokalne, a.voda_plne, a.voda_nacteno, a.voda_lokalne == a.voda_plne])
	return out

## E85: rozbor edit79 + p74_vyzvednout: lokální stav proti plnému se stejnými obsazeními (check_full) a proti čerstvému
func diag74(flags: Dictionary) -> Dictionary:
	T.reset()
	for k in flags: T.p[k] = flags[k]
	var g := gen_blocks(START); var blocks: Dictionary = g[0]
	var v := OV.new(); v.build(blocks)
	var c0 := v.claims.keys(); c0.sort()
	var touched := {}
	sc_tunel(blocks, touched)
	var zm := {}
	for s in touched: zm[s] = P78.sync79(blocks[s]).geo
	var e: Dictionary = v.edit79(zm)
	var c1 := v.claims.keys(); c1.sort()
	var r := {"cesta": e.get("cesta", ""), "obsazeno_pred": c0, "obsazeno_po": c1, "lokalne": v.hydro().otisk}
	r.check_full = v.check_full(); r.plny_se_stejnymi = v.full_otisk
	var vf := OV.new(); vf.build(blocks)
	var c2 := vf.claims.keys(); c2.sort()
	r.cerstvy = vf.hydro().otisk; r.obsazeno_cerstvy = c2
	r.gw_lokalne = str(v.gw.hash()); r.gw_cerstvy = str(vf.gw.hash())
	v.dispose(); vf.dispose()
	return r

func part_diag74() -> Dictionary:
	var out := {}
	for vn in ["p79", "p79_p85"]:
		var fl := {"p79_chodby": true}
		if vn == "p79_p85": fl.p85_blok2 = true
		out[vn] = diag74(fl)
		print("diag74 %s: %s" % [vn, JSON.stringify(out[vn])])
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/blok2_e85.gd": return
	var out := {}
	var parts := _arg("casti", "jemne,okraj,vrstvy,voda").split(",")
	if "jemne" in parts: out.jemne = part_jemne()
	if "okraj" in parts: out.okraj = part_okraj()
	if "vrstvy" in parts: out.vrstvy = part_vrstvy()
	if "voda" in parts: out.voda = part_voda()
	if "voda74" in parts: out.voda74 = part_voda74()
	if "diag74" in parts: out.diag74 = part_diag74()
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
