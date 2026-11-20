extends SceneTree
## E86: otočení výřezu po 90° (scripts/teren/otoceni86.gd, prenos76.place, ug_funkce.bands76 s p86_otoceni).
## A: otočení dat výřezu = otočení souřadnic (nezávislá kontrola přes metry), rot⁴ = id, skládání, hrany, počty, prameny.
## B: otočené FUNKCE (hm_f, bs) znovu navzorkované generátorem (geo_fn.sample, 16 i 32 na blok) proti otočeným buňkám,
##    minerály a dutiny znovu z generátoru proti otočeným; rozdíly po kategoriích.
## C: celý pipeline se šablonou povrchu otočenou o rot (bez sousedů) proti otočenému vygenerovanému bloku.
## D: ostrov – výřez otočený rot 0–3 vložený vedle bloků ostrova: lokálně = plně, bilance, pásma podzemí = otočená pásma
##    původu (p86 zap / vyp), prameny, švy.
## Volby: --cast=A,B,C,D --vyrez=kopec:707 --slot=2,0;0,-1 --dz=0 --p86=1,0 --out=cesta --bp.<klíč>=hodnota
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const P76 = preload("res://scripts/voda/prenos76.gd")
const R = preload("res://scripts/teren/otoceni86.gd")
const FN = preload("res://scripts/teren/geo_fn.gd")
const PL = preload("res://scripts/teren/pipeline.gd")
const WD = preload("res://scripts/teren/world.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const HT = preload("res://scripts/teren/hostitele.gd")
const MN = preload("res://scripts/teren/minerals.gd")
const SD = preload("res://scripts/teren/sides.gd")
const START := "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404"

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func gen_blocks(spec: String) -> Dictionary:
	var blocks := {}
	for e in spec.split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	return blocks

func origin_spec() -> String:
	var vy := _arg("vyrez", "kopec:707").split(":")
	return _arg("puvod", "0,0:hora:808;1,0:louka:909;0,1:%s:%s;1,1:piscina:606;-1,1:louka:505" % [vy[0], vy[1]])

## ---------- A: data
func _src_of_m(x: int, y: int, r: int) -> Vector2i:   # nezávisle na R.xy: střed sloupce v metrech → otočený → index
	var l := R.local_m((x + 0.5) * 0.5, (y + 0.5) * 0.5, r)
	return Vector2i(floori(l.x / 0.5), floori(l.y / 0.5))

func check_rot(cut: Dictionary, rc: Dictionary, r: int) -> Dictionary:
	var bad := {"hm": 0, "hm_gen": 0, "hm_f": 0, "hm_raw": 0, "hm_pre": 0, "bs": 0, "geo": 0, "cells": 0, "water": 0, "rec_cells": 0, "rec_water": 0}
	for x in 16:
		for y in 16:
			var q := _src_of_m(x, y, r)
			var s := x * 16 + y; var d := q.x * 16 + q.y
			if rc.hm[d] != cut.hm[s]: bad.hm += 1
			if rc.hm_gen[d] != cut.hm_gen[s]: bad.hm_gen += 1
			for k in ["hm_f", "hm_raw", "hm_pre"]:
				if cut.rec.has(k) and rc.rec[k][d] != cut.rec[k][s]: bad[k] += 1
			for k in cut.rec.bs.size():
				if rc.rec.bs[k][d] != cut.rec.bs[k][s]: bad.bs += 1
			for z in 64:
				if rc.geo[d * 64 + z] != cut.geo[s * 64 + z]: bad.geo += 1
				if rc.cells[d * 64 + z] != cut.cells[s * 64 + z]: bad.cells += 1
				if rc.rec.cells[d * 64 + z] != cut.rec.cells[s * 64 + z]: bad.rec_cells += 1
				if cut.water.size() == 16384 and rc.water[d * 64 + z] != cut.water[s * 64 + z]: bad.water += 1
				if cut.rec.water.size() == 16384 and rc.rec.water[d * 64 + z] != cut.rec.water[s * 64 + z]: bad.rec_water += 1
	return bad

func hist(a: PackedByteArray) -> Dictionary:
	var h := {}
	for c in a: h[c] = h.get(c, 0) + 1
	return h

func same_cut(a: Dictionary, b: Dictionary) -> bool:
	if a.geo != b.geo or a.cells != b.cells or a.hm != b.hm or a.hm_gen != b.hm_gen or a.water != b.water: return false
	if a.rec.hm_f != b.rec.hm_f or a.rec.cells != b.rec.cells: return false
	for k in a.rec.bs.size():
		if a.rec.bs[k] != b.rec.bs[k]: return false
	return str(a.prameny) == str(b.prameny)

func part_a(ob: Dictionary, v0) -> Dictionary:
	var out := {}
	for s in ob:
		var cut := P76.cutout(ob[s], v0)
		var e := {"typ": ob[s].kind, "seed": ob[s].seed, "prameny": cut.prameny.size(), "rot": {}}
		var cav_cells := 0
		for c in cut.rec.rep.get("cavities", []): cav_cells += c.get("cells", []).size()
		e.dutina_bunek = cav_cells
		var h0 := hist(cut.geo)
		var t0 := Time.get_ticks_usec()
		for r in [1, 2, 3]:
			var rc := R.cutout(cut, r)
			var bad := check_rot(cut, rc, r)
			var tot := 0
			for k in bad: tot += bad[k]
			# rot 1 r-krát = rot r; rot⁴ = id
			var rr := cut
			for i in r: rr = R.cutout(rr, 1)
			var four := cut
			for i in 4: four = R.cutout(four, r)
			# hrany: strana d původu = strana (d + r) mod 4 otočeného (hm_f, pořadí podle t; obrácené?)
			var edges := []
			for d in 4:
				var a := []; var b := []
				for t in 16:
					var o1 := SD.own(d, t); a.append(cut.rec.hm_f[o1.x * 16 + o1.y])
					var o2 := SD.own(R.side(d, r), t); b.append(rc.rec.hm_f[o2.x * 16 + o2.y])
				var br := b.duplicate(); br.reverse()
				# pořadí podle indexů sloupců (nezávisle na hodnotách; volné okraje bývají konstantní = surf_ref)
				var ia := []; var ib := []
				for t in 16:
					var o1 := SD.own(d, t); var q1 := R.xy(o1.x, o1.y, r, 16); var o2 := SD.own(R.side(d, r), t)
					ia.append(q1.x * 16 + q1.y); ib.append(o2.x * 16 + o2.y)
				var ibr := ib.duplicate(); ibr.reverse()
				var order := "stejne" if ia == ib else ("obracene" if ia == ibr else "JINAK")
				var val: bool = (a == b and order == "stejne") or (a == br and order == "obracene")
				edges.append("%s→%s %s%s" % [SD.NAMES[d], SD.NAMES[R.side(d, r)], order, "" if val else " HODNOTY JINAK"])
			# dutiny: buňky v otočeném geo jsou dutina; prameny: sloupec pod pramenem stejný
			var cav_ok := 0; var cav_n := 0
			for c in rc.rec.rep.get("cavities", []):
				for i in c.get("cells", []):
					cav_n += 1
					if rc.rec.cells[int(i)] == int(c.mat) or (int(c.mat) == FN.CAV_WATER and rc.rec.cells[int(i)] == 0): cav_ok += 1
			var sp_ok := 0
			for k in cut.prameny.size():
				var a: Array = cut.prameny[k]; var b: Array = rc.prameny[k]
				var sa := (int(a[0]) * 16 + int(a[1])) * 64; var sb := (int(b[0]) * 16 + int(b[1])) * 64
				if cut.geo.slice(sa, sa + 64) == rc.geo.slice(sb, sb + 64) and a[2] == b[2]: sp_ok += 1
			e.rot[str(r)] = {"neshod": bad, "neshod_celkem": tot, "rot1_rkrat_stejne": same_cut(rr, rc), "rot4_identita": same_cut(four, R.cutout(cut, 0)),
				"hrany": edges, "pocty_stejne": hist(rc.geo) == h0, "dutina_bunek_ok": "%d/%d" % [cav_ok, cav_n], "prameny_ok": "%d/%d" % [sp_ok, cut.prameny.size()]}
		# skládání a ∘ b = a + b
		var comp_bad := 0
		for a in 4:
			for b in 4:
				if not same_cut(R.cutout(R.cutout(cut, a), b), R.cutout(cut, a + b)): comp_bad += 1
		e.skladani_neshod = comp_bad
		e.ms_3_otoceni_a_kontroly = (Time.get_ticks_usec() - t0) / 1000.0
		var t1 := Time.get_ticks_usec(); R.cutout(cut, 1); e.ms_otoceni = (Time.get_ticks_usec() - t1) / 1000.0
		out[str(s)] = e
		print("A %s %s:%d prameny %d dutina %d: %s skládání neshod %d, otočení %.1f ms" % [s, ob[s].kind, ob[s].seed, cut.prameny.size(), cav_cells,
			str(e.rot.keys().map(func(k): return "rot%s neshod %d rot1^r %s rot4 %s hrany %s počty %s dutina %s prameny %s" % [k, e.rot[k].neshod_celkem, e.rot[k].rot1_rkrat_stejne, e.rot[k].rot4_identita, e.rot[k].hrany, e.rot[k].pocty_stejne, e.rot[k].dutina_bunek_ok, e.rot[k].prameny_ok])),
			comp_bad, e.ms_otoceni])
	return out

## ---------- B: funkce
func _cats(p: Dictionary) -> Dictionary:
	var c := {}
	for kd in ["pipe", "dome", "vein", "contact", "vent"]:
		var e := HR.special(kd, p)
		if not e.is_empty(): c[int(e.id)] = "teleso_" + kd
	for e in HR.mountain(p): c[int(e.id)] = c.get(int(e.id), "hornina_hor")
	for m in HT.table(): c[int(m)] = "mineral"
	c[0] = "vzduch_dutina"; c[FN.CAV_WATER] = "dutina_voda"
	return c

func _minerals_on(cells: PackedByteArray, n: int, wf: Dictionary, info: Dictionary, bp: Dictionary) -> void:
	for m in MN.order(bp.minerals):
		if not FN.is_cavity(m): FN.mineral_one(cells, n, wf, info, m, int(bp.minerals[m]), bp.seed)
	for m in MN.order(bp.minerals):
		if FN.is_cavity(m) and int(bp.minerals[m]) > 0: FN.cavity_one(cells, n, wf, info, m, int(bp.minerals[m]), bp.seed)

func _cmp(a: PackedByteArray, b: PackedByteArray, cats: Dictionary) -> Dictionary:
	var out := {"neshod": 0, "kategorie": {}, "pary": {}}
	for i in a.size():
		if a[i] == b[i]: continue
		out.neshod += 1
		var k: String = cats.get(int(a[i]), cats.get(int(b[i]), "vrstva_povrch"))
		out.kategorie[k] = out.kategorie.get(k, 0) + 1
		var pk := "%d→%d" % [a[i], b[i]]
		out.pary[pk] = out.pary.get(pk, 0) + 1
	var ks: Array = out.pary.keys()
	ks.sort_custom(func(x, y): return out.pary[x] > out.pary[y])
	var top := {}
	for k in ks.slice(0, 6): top[k] = out.pary[k]
	out.pary = top
	return out

func part_b(ob: Dictionary) -> Dictionary:
	var out := {}
	var p: Dictionary = T.p.duplicate()
	var cats := _cats(p)
	var ns := Array(_arg("n", "16,32").split(",")).map(func(x): return int(x))
	for s in ob:
		var rec: Dictionary = ob[s].bp_rec
		var ws: Vector2i = rec.slot
		var e := {"typ": ob[s].kind, "seed": ob[s].seed}
		# kontrola: vzorek neotočené funkce v samostatném světě = uložené buňky (bez minerálů a dutin)
		var wf0 := FN.world_fn({ws: rec})
		var info0 := FN.block_info(wf0, ws, rec.bp, p)
		for n: int in ns:
			var nz: int = 4 * n
			var t0 := Time.get_ticks_usec()
			var base0 := FN.sample_all(wf0, info0, n)
			var full0 := base0.duplicate(); _minerals_on(full0, n, wf0, info0, rec.bp)
			var en := {"ms_vzorek": (Time.get_ticks_usec() - t0) / 1000.0, "rot": {}}
			if n == 16:
				en.kontrola_ulozene = _cmp(rec.cells, full0, cats)
				# minerály v původním světě (sousedé) – vliv sousedů na středy ložisek
				var wfw := FN.world_fn(T.world.slots)
				var fw := FN.sample_all(wfw, FN.block_info(wfw, ws, rec.bp, p), 16); _minerals_on(fw, 16, wfw, FN.block_info(wfw, ws, rec.bp, p), rec.bp)
				en.kontrola_ulozene_svet = _cmp(rec.cells, fw, cats)
			for r in [1, 2, 3]:
				var rr := R.record(rec, r)
				var wf := FN.world_fn({ws: rr})
				var info := FN.block_info(wf, ws, rr.bp, p)
				var base := FN.sample_all(wf, info, n)
				var full := base.duplicate(); _minerals_on(full, n, wf, info, rr.bp)
				var exp_base: PackedByteArray = R.cells(base0, r, n, nz)
				var exp_full: PackedByteArray = R.cells(full0, r, n, nz)
				var mc := 0; var mr := 0
				for i in full.size():
					if exp_full[i] != full[i] and (cats.get(int(exp_full[i]), "") in ["mineral", "vzduch_dutina", "dutina_voda"] or cats.get(int(full[i]), "") in ["mineral", "vzduch_dutina", "dutina_voda"]):
						mc += 1
				en.rot[str(r)] = {"zaklad": _cmp(exp_base, base, cats), "vse": _cmp(exp_full, full, cats), "mineraly_dutiny_neshod": mc, "bunek": full.size()}
			e[str(n)] = en
			print("B %s %s:%d n %d (%.0f ms): %s" % [s, ob[s].kind, ob[s].seed, n, en.ms_vzorek, str(en.rot.keys().map(func(k): return "rot%s základ %d %s | vše %d, min+dut %d" % [k, en.rot[k].zaklad.neshod, str(en.rot[k].zaklad.kategorie), en.rot[k].vse.neshod, en.rot[k].mineraly_dutiny_neshod]))])
			if en.has("kontrola_ulozene"): print("   kontrola: samostatný svět proti uloženým %d %s, svět původu %d" % [en.kontrola_ulozene.neshod, str(en.kontrola_ulozene.kategorie), en.kontrola_ulozene_svet.neshod])
		out[str(s)] = e
	return out

## ---------- C: celý pipeline s otočenou šablonou
func _gen(bp: Dictionary, ws: Vector2i, shift: int, r: int) -> Dictionary:
	var world := WD.new(); world.w = T.SIZE; world.h = T.SIZE
	var pp: Dictionary = T.p.duplicate()
	pp.surface_shift = float(T.p.surface_shift) + float(shift)
	var ctx := PL.new_ctx(world, ws, bp, pp)
	var st := PL.steps(ctx)
	var i := 0
	while i < st.size():
		st[i][1].call()
		if i == 0 and r != 0: ctx.raw = R.cols(ctx.raw, r)
		i += 1
	return PL.record(ctx)

func _dmax(a, b) -> Array:
	var m := 0.0; var s := 0.0; var n := 0
	for i in a.size():
		var d := absf(float(a[i]) - float(b[i])); m = maxf(m, d); s += d
		if d > 1e-9: n += 1
	return [m, s / maxf(a.size(), 1), n]

func part_c(ob: Dictionary) -> Dictionary:
	var out := {}
	var cats := _cats(T.p)
	for s in ob:
		var b = ob[s]
		var bp: Dictionary = b.bp_rec.bp
		var ws := T.wslot(s)
		var rec0 := _gen(bp, ws, b.shift, 0)
		var e := {"typ": b.kind, "seed": b.seed, "rot": {}}
		for r in [1, 2, 3]:
			var rg := _gen(bp, ws, b.shift, r)
			var rx := R.record(rec0, r)
			var bsd := []
			for k in rx.bs.size(): bsd.append(_dmax(rx.bs[k], rg.bs[k]))
			var bsm := 0.0
			for d in bsd: bsm = maxf(bsm, d[0])
			var hd := _dmax(rx.hm, rg.hm)
			e.rot[str(r)] = {"raw": _dmax(R.cols(rec0.raw if rec0.has("raw") else rec0.hm_raw, r), rg.hm_raw), "hm_f": _dmax(rx.hm_f, rg.hm_f), "hm": hd, "bs_max_u": bsm, "bs": bsd,
				"bunky": _cmp(rx.cells, rg.cells, cats)}
			print("C %s %s:%d rot %d: hm_f max %.4f U (%d sloupců), hm max %d buněk (%d sl.), hranice vrstev max %.3f U, buňky neshod %d %s" % [s, b.kind, b.seed, r,
				e.rot[str(r)].hm_f[0], e.rot[str(r)].hm_f[2], int(hd[0]), hd[2], bsm, e.rot[str(r)].bunky.neshod, str(e.rot[str(r)].bunky.kategorie)])
		out[str(s)] = e
	return out

## ---------- D: ostrov
static func diff(s1: Dictionary, s2: Dictionary) -> Dictionary:
	var d := {"fill": 0, "eff": 0, "to": 0}
	for i in s1.fill.size():
		if s1.fill[i] != s2.fill[i]: d.fill += 1
		if s1.eff[i] != s2.eff[i]: d.eff += 1
		if s1.to[i] != s2.to[i]: d.to += 1
	return d

static func col_bands(ug: Dictionary, ws: Vector2i, x: int, y: int) -> String:
	var W: int = ug.W
	var c: int = (ws.x * 16 + x) * W + ws.y * 16 + y
	var a := []
	for b in range(ug.cs[c], ug.cs[c + 1]): a.append("%d:%.4f:%.4f" % [int(ug.mat[b]), float(ug.lo[b]), float(ug.hi[b])])
	return ",".join(a)

func seams(v, blocks: Dictionary, tslot: Vector2i) -> Dictionary:
	var b = blocks[tslot]
	var out := {"strany": []}
	var inner := 0.0
	for x in 16:
		for y in 16:
			if x < 15: inner = maxf(inner, absf(b.bp_rec.hm_f[x * 16 + y] - b.bp_rec.hm_f[(x + 1) * 16 + y]))
			if y < 15: inner = maxf(inner, absf(b.bp_rec.hm_f[x * 16 + y] - b.bp_rec.hm_f[x * 16 + y + 1]))
	out.vnitrni_max_u = inner
	for d in 4:
		var ns: Vector2i = tslot + SD.DIRS[d]
		if not blocks.has(ns): out.strany.append(null); continue
		var nb = blocks[ns]
		var m := 0.0; var su := 0.0; var mh := 0
		for t in 16:
			var o := SD.own(d, t); var c := SD.nb(d, t)
			var dd := absf(b.bp_rec.hm_f[o.x * 16 + o.y] - nb.bp_rec.hm_f[c.x * 16 + c.y]); m = maxf(m, dd); su += dd
			mh = maxi(mh, absi(b.hm[o.x * 16 + o.y] - nb.hm[c.x * 16 + c.y]))
		out.strany.append({"strana": SD.NAMES[d], "max_u": m, "prumer_u": su / 16.0, "max_bunek": mh})
	return out

func part_d() -> Dictionary:
	var oslot := Vector2i(0, 1)
	T.reset()
	var ob := gen_blocks(origin_spec())
	var v0 := OV.new(); v0.build(ob)
	var cut := P76.cutout(ob[oslot], v0)
	var ug0: Dictionary = v0.ug
	var ows := T.wslot(oslot)
	var ob_keys := []
	for x in 16:
		for y in 16: ob_keys.append(col_bands(ug0, ows, x, y))
	var res := {"prameny_vyrezu": cut.prameny, "otisk_puvod": v0.hydro().otisk, "vlozeni": []}
	var runs := []
	for p86 in _arg("p86", "1,0").split(","):
		for ss in _arg("slot", "2,0;0,-1").split(";"):
			for r in Array(_arg("rot", "0,1,2,3").split(",")).map(func(x): return int(x)):
				if p86 == "0" and r == 0: continue
				runs.append([p86 == "1", Vector2i(ss.split(",")[0].to_int(), ss.split(",")[1].to_int()), r])
	for rn in runs:
		var on: bool = rn[0]; var tslot: Vector2i = rn[1]; var r: int = rn[2]; var dz := int(_arg("dz", "0"))
		T.reset()
		T.p.p86_otoceni = on
		var blocks := gen_blocks(_arg("bloky", START))
		var v := OV.new(); v.build(blocks)
		var rc := R.cutout(cut, r)
		var b = P76.place(rc, tslot, dz)
		T.commit(b)
		blocks[tslot] = b
		var loc: Dictionary = v.place76(b)
		var h_loc: Dictionary = v.hydro()
		var v2 := OV.new()
		var t0 := Time.get_ticks_usec(); v2.build(blocks); var full_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var h_full: Dictionary = v2.hydro()
		var d := diff(v.st, v2.st)
		# pásma podzemí: otočený sloupec výřezu = sloupec původu (dz 0)
		var tws := T.wslot(tslot)
		var same_all := 0; var same_in := 0; var n_in := 0
		for x in 16:
			for y in 16:
				var q := R.xy(x, y, r, 16)
				var ok: bool = col_bands(v2.ug, tws, q.x, q.y) == ob_keys[x * 16 + y]
				if ok: same_all += 1
				if x > 0 and y > 0 and x < 15 and y < 15:
					n_in += 1
					if ok: same_in += 1
		# prameny výřezu na ostrově: na otočených místech (uložené z původu)
		var sp_exp := []
		for e in rc.prameny: sp_exp.append("%d,%d,%d" % [e[0], e[1], int(e[2]) + dz])
		var sp_got := []
		for s in v2.springs:
			var a: Array = v2.slot_of(int(s.gi))
			if a[0] == tslot: sp_got.append("%d,%d,%d" % [a[1], a[2], int(s.z)])
		sp_exp.sort(); sp_got.sort()
		var reg := P76.region(v2, tslot)
		var e := {"p86": on, "slot": [tslot.x, tslot.y], "rot": r, "dz": dz, "lokalne": loc, "plny_ms": full_ms, "otisk_lokalne": h_loc.otisk, "otisk_plny": h_full.otisk,
			"neshod": d, "bilance_lokalne": h_loc.bilance.chyba_svet, "bilance_plny": h_full.bilance.chyba_svet, "okraj_lps": h_full.bilance.okraj,
			"pasma_stejne_vse": "%d/256" % same_all, "pasma_stejne_vnitrek": "%d/%d" % [same_in, n_in], "prameny_ocekavane": sp_exp, "prameny_ostrov": sp_got,
			"prameny_stejne": sp_exp == sp_got, "svy": seams(v2, blocks, tslot), "region": reg}
		res.vlozeni.append(e)
		print("D p86 %s slot %s rot %d: lokálně %.0f ms, plný %.0f ms, otisk %s / %s neshod %s, bilance %s / %s, pásma %s (vnitřek %s), prameny %s %s" % [on, tslot, r, loc.celkem_ms, full_ms,
			h_loc.otisk, h_full.otisk, str(d), str(e.bilance_lokalne), str(e.bilance_plny), e.pasma_stejne_vse, e.pasma_stejne_vnitrek, e.prameny_stejne, str(sp_got)])
		print("   švy: vnitřní max %.3f U, strany %s; okraj %.4f l/s, region %s" % [e.svy.vnitrni_max_u, str(e.svy.strany.map(func(x): return null if x == null else "%s max %.3f U / %d b., průměr %.3f" % [x.strana, x.max_u, x.max_bunek, x.prumer_u])), float(e.okraj_lps), str(reg)])
		v.dispose(); v2.dispose()
	v0.dispose()
	return res

func _init() -> void:
	BlockGen.gen_version = "bp"
	var out := {}
	var parts := _arg("cast", "A,B,C,D")
	if "A" in parts or "B" in parts or "C" in parts:
		T.reset()
		var ob := gen_blocks(origin_spec())
		var v0 := OV.new(); v0.build(ob)
		if "A" in parts: out.A = part_a(ob, v0)
		v0.dispose()
		if "B" in parts: out.B = part_b(ob)
		if "C" in parts: out.C = part_c(ob)
	if "D" in parts: out.D = part_d()
	var path := _arg("out", "")
	if path != "": FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	quit()
