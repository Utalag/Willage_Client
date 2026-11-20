extends "res://tools/chodby_e79.gd"
## E80: kde končí funkce a pásma. Hranice mezi spojitými funkcemi (geo_fn, metry světa), vzorkovanými buňkami (0,5 m
## pipeline, 0,25 m) a překryvem hráče (prekryv78). Části: --casti=rozliseni,svy,prekryv,okraje,kriterium --out=cesta
## (voda v části okraje: spouštět s --bp.p76_prameny=true --bp.p79_chodby=true)
const FN = preload("res://scripts/teren/geo_fn.gd")

func wf_all() -> Dictionary:
	return FN.world_fn(T.world.slots)

func info_of(wf: Dictionary, b) -> Dictionary:
	var ws := T.wslot(b.slot)
	return FN.block_info(wf, ws, T.world.slots[ws].bp, T.p)

func sample(wf: Dictionary, info: Dictionary, b, n: int, mins := true) -> PackedByteArray:
	var c: PackedByteArray = FN.sample_all(wf, info, n)
	if mins: FN.minerals(c, n, wf, info, T.world.slots[T.wslot(b.slot)].bp.minerals, int(b.seed))
	return c

static func tops(c: PackedByteArray, n: int) -> PackedInt32Array:
	var t := PackedInt32Array(); t.resize(n * n)
	var nz := 4 * n
	for i in n * n:
		for z in range(nz - 1, -1, -1):
			if c[i * nz + z] != 0: t[i] = z + 1; break
	return t

static func is_min(m: int, mins: Dictionary) -> bool:
	return mins.has(m)

## 1) stejný svět při 0,5 m a 0,25 m: funkce 0,25 m proti zjemnění 0,5 m (to bere překryv)
func part_res() -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var wf := wf_all()
	var out := {"bloky": []}
	var tot := {"bunek": 0, "jine": 0, "jine_bez_min": 0, "pevne_vzduch": 0, "jine_geom": 0, "pevne_vzduch_geom": 0}
	for s in order:
		var b = blocks[s]; var info := info_of(wf, b)
		var mins := {}
		for m in T.world.slots[T.wslot(s)].bp.minerals: mins[int(m)] = true
		var t0 := Time.get_ticks_usec()
		var c16 := sample(wf, info, b, 16); var t16 := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		var c32 := sample(wf, info, b, 32); var t32 := (Time.get_ticks_usec() - t0) / 1000.0
		var g16 := sample(wf, info, b, 16, false); var g32 := sample(wf, info, b, 32, false)   # jen geometrie a horniny
		var r := P78.refine(b.geo); var rg := P78.refine(g16)
		var d := 0; var dm := 0; var sa := 0; var dg := 0; var sag := 0
		for i in r.size():
			if c32[i] != r[i]:
				d += 1
				if not (mins.has(int(c32[i])) or mins.has(int(r[i]))): dm += 1
			if (c32[i] == 0) != (r[i] == 0): sa += 1
			if g32[i] != rg[i]: dg += 1
			if (g32[i] == 0) != (rg[i] == 0): sag += 1
		var t32a := tops(c32, 32); var t16a := tops(b.geo, 16)
		var dh := []; var sumh := 0.0; var maxh := 0.0
		for fx in 32:
			for fy in 32:
				var h := absf(float(t32a[fx * 32 + fy]) * 0.25 - float(t16a[(fx / 2) * 16 + fy / 2]) * 0.5)
				sumh += h; maxh = maxf(maxh, h)
		var row := {"slot": [s.x, s.y], "kind": b.kind, "c16_rovno_pipeline": c16 == b.geo, "c16_jinych": _ndiff(c16, b.geo),
			"jine_proc": 100.0 * d / r.size(), "jine_bez_mineralu_proc": 100.0 * dm / r.size(), "pevne_vzduch_proc": 100.0 * sa / r.size(),
			"geom_jine_proc": 100.0 * dg / r.size(), "geom_pevne_vzduch_proc": 100.0 * sag / r.size(),
			"povrch_prumer_m": sumh / 1024.0, "povrch_max_m": maxh, "ms_16": t16, "ms_32": t32}
		out.bloky.append(row)
		tot.bunek += r.size(); tot.jine += d; tot.jine_bez_min += dm; tot.pevne_vzduch += sa; tot.jine_geom += dg; tot.pevne_vzduch_geom += sag
		print("rozlišení %s %s: 16 = pipeline %s; 0,25 m z funkcí proti zjemnění 0,5 m: jiné %.2f %% (bez minerálů %.2f %%), pevné/vzduch %.2f %%; jen geometrie %.2f %% / %.2f %%; povrch Ø %.3f m, max %.2f m; čas 16 %.0f ms, 32 %.0f ms" % [str(s), b.kind, str(row.c16_rovno_pipeline), row.jine_proc, row.jine_bez_mineralu_proc, row.pevne_vzduch_proc, row.geom_jine_proc, row.geom_pevne_vzduch_proc, row.povrch_prumer_m, row.povrch_max_m, t16, t32])
	out.celkem = {"jine_proc": 100.0 * tot.jine / tot.bunek, "jine_bez_mineralu_proc": 100.0 * tot.jine_bez_min / tot.bunek, "pevne_vzduch_proc": 100.0 * tot.pevne_vzduch / tot.bunek,
		"geom_jine_proc": 100.0 * tot.jine_geom / tot.bunek, "geom_pevne_vzduch_proc": 100.0 * tot.pevne_vzduch_geom / tot.bunek}
	print("rozlišení celkem: ", JSON.stringify(out.celkem))
	return out

static func _ndiff(a: PackedByteArray, b: PackedByteArray) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i]: n += 1
	return n

## 2) švy: spojitost funkcí přes šev, materiály přes šev, závislost vzorků na pozdějším sousedovi
func part_svy() -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var wf := wf_all()
	var out := {}
	# funkce: skok na švu x (bloky (0,0)|(1,0) a (0,1)|(1,1)) a y ((0,0)|(0,1), (1,0)|(1,1)) proti kroku 0,25 m uvnitř
	var jumps := {"povrch": 0.0, "hranice": 0.0}; var grad := {"povrch": 0.0, "hranice": 0.0}
	var nk: int = T.world.slots[T.wslot(order[0])].bs.size()
	for pair in [[Vector2i(0, 0), Vector2i(1, 0), 0], [Vector2i(0, 1), Vector2i(1, 1), 0], [Vector2i(0, 0), Vector2i(0, 1), 1], [Vector2i(1, 0), Vector2i(1, 1), 1]]:
		var a: Vector2i = T.wslot(pair[0]); var c: Vector2i = T.wslot(pair[1]); var ax: int = pair[2]
		for t in 64:
			var u: float = (t + 0.5) * FN.BW / 64.0
			var S: float = (c.x if ax == 0 else c.y) * FN.BW
			var pA := Vector2(S - 1e-6, a.y * FN.BW + u) if ax == 0 else Vector2(a.x * FN.BW + u, S - 1e-6)
			var pB := Vector2(S + 1e-6, a.y * FN.BW + u) if ax == 0 else Vector2(a.x * FN.BW + u, S + 1e-6)
			var pI := pA - (Vector2(0.25, 0) if ax == 0 else Vector2(0, 0.25))
			jumps.povrch = maxf(jumps.povrch, absf(FN.surface_m(wf, a, pA.x, pA.y) - FN.surface_m(wf, c, pB.x, pB.y)))
			grad.povrch = maxf(grad.povrch, absf(FN.surface_m(wf, a, pA.x, pA.y) - FN.surface_m(wf, a, pI.x, pI.y)))
			for k in nk:
				jumps.hranice = maxf(jumps.hranice, absf(FN.boundary_m(wf, a, k, pA.x, pA.y) - FN.boundary_m(wf, c, k, pB.x, pB.y)))
				grad.hranice = maxf(grad.hranice, absf(FN.boundary_m(wf, a, k, pA.x, pA.y) - FN.boundary_m(wf, a, k, pI.x, pI.y)))
	out.funkce = {"skok_na_svu_m": jumps, "max_krok_0_25m_uvnitr_m": grad}
	# materiály přes šev (buňky 0,5 m pipeline): podíl sousedních dvojic s jiným materiálem na švu proti uvnitř
	var seam := [0, 0]; var inner := [0, 0]
	for pair in [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(1, 1)]]:
		var A = blocks[pair[0]]; var B = blocks[pair[1]]
		for y in 16:
			for z in 64:
				var ma: int = A.geo[(15 * 16 + y) * 64 + z]; var mb: int = B.geo[(0 * 16 + y) * 64 + z]
				if ma == 0 and mb == 0: continue
				seam[1] += 1; if ma != mb: seam[0] += 1
				var mi: int = A.geo[(14 * 16 + y) * 64 + z]
				if ma == 0 and mi == 0: continue
				inner[1] += 1; if ma != mi: inner[0] += 1
	out.material = {"sev_jine_proc": 100.0 * seam[0] / maxi(seam[1], 1), "uvnitr_jine_proc": 100.0 * inner[0] / maxi(inner[1], 1)}
	# pořadí: první blok vzorkovaný sám (bez sousedů) proti vzorku po vložení všech
	var b0 = blocks[order[0]]; var ws0 := T.wslot(order[0])
	var wf0 := FN.world_fn({ws0: T.world.slots[ws0]})
	var inf0 := FN.block_info(wf0, ws0, T.world.slots[ws0].bp, T.p); var infA := info_of(wf, b0)
	var res := {}
	for n in [16, 32]:
		var c_alone := sample(wf0, inf0, b0, n, false); var c_all := sample(wf, infA, b0, n, false)
		var d := 0; var far := 0
		for i in c_all.size():
			if c_alone[i] != c_all[i]:
				d += 1
				var x: int = i / (n * 4 * n); var y: int = (i / (4 * n)) % n
				far = maxi(far, mini(mini(x, n - 1 - x), mini(y, n - 1 - y)))
		res[str(n)] = {"jinych": d, "proc": 100.0 * d / c_all.size(), "max_vzdalenost_od_svu_bunek": far}
	out.poradi_vlozeni = res
	print("švy: funkce skok %s (krok uvnitř %s), materiál šev %.1f %% / uvnitř %.1f %%, blok sám → po sousedech: %s" % [str(jumps), str(grad), out.material.sev_jine_proc, out.material.uvnitr_jine_proc, JSON.stringify(res)])
	return out

## 3) překryv po převzorkování a po změně verze funkcí
func _ov_stats(name: String, ov_all: Dictionary, defs_old: Dictionary, defs_new: Dictionary) -> Dictionary:
	var r := {"definice": name, "polozek": 0, "rovno_nove_definici": 0, "vykop_ve_vzduchu": 0, "polozeni_do_skaly": 0, "okoli_zmeneno": 0, "visi_polozene": 0, "definice_jine_proc": 0.0}
	var tot := 0; var dd := 0
	for s in ov_all:
		var o: Dictionary = ov_all[s]; var Do: PackedByteArray = defs_old[s]; var Dn: PackedByteArray = defs_new[s]
		for i in Do.size():
			tot += 1
			if Do[i] != Dn[i]: dd += 1
		var live := Dn.duplicate()
		for k in o: live[k] = o[k]
		var seen := {}
		for k in o:
			r.polozek += 1
			var m: int = o[k]
			if m == Dn[k]: r.rovno_nove_definici += 1
			if m == 0 and Dn[k] == 0: r.vykop_ve_vzduchu += 1
			if m != 0 and Do[k] == 0 and Dn[k] != 0: r.polozeni_do_skaly += 1
			if m != 0 and k % P78.NZ > 0 and live[k - 1] == 0 and not o.has(k - 1): r.visi_polozene += 1
			var z: int = k % P78.NZ; var col: int = k / P78.NZ; var fx: int = col / P78.N; var fy: int = col % P78.N
			for dv in [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]:
				var x2: int = fx + dv[0]; var y2: int = fy + dv[1]; var z2: int = z + dv[2]
				if not P78.inside(x2, y2, z2): continue
				var j: int = P78.fidx(x2, y2, z2)
				if o.has(j) or seen.has(j): continue
				seen[j] = true
				if Do[j] != Dn[j]: r.okoli_zmeneno += 1
		r.okoli_bunek = r.get("okoli_bunek", 0) + seen.size()
	r.definice_jine_proc = 100.0 * dd / maxi(tot, 1)
	print("překryv nad %s: %s" % [name, JSON.stringify(r)])
	return r

func _gen_defs(order: Array, mod: Dictionary) -> Dictionary:
	T.reset()
	for k in mod: T.p[k] = mod[k]
	var g := gen_blocks(START); var blocks: Dictionary = g[0]
	var d := {}
	for s in order: d[s] = P78.refine(blocks[s].geo)
	return d

func part_prekryv() -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var wf := wf_all()
	var touched := {}
	sc_tunel(blocks, touched)
	var ov := {}; var d_old := {}; var d32 := {}
	for s in order:
		ov[s] = P78.overlay(blocks[s]); d_old[s] = P78.refine(blocks[s].def78)
		d32[s] = sample(wf, info_of(wf, blocks[s]), blocks[s], 32)
	var out := {"funkce_0_25m": _ov_stats("funkce 0,25 m", ov, d_old, d32)}
	out.puda_plus_1 = _ov_stats("verze: půda +0,5 m (soil 3)", ov, d_old, _gen_defs(order, {"soil": int(T.params().soil) + 1}))
	out.povrch_plus_1 = _ov_stats("verze: povrch +0,5 m (surface_shift +1)", ov, d_old, _gen_defs(order, {"surface_shift": float(T.params().surface_shift) + 1.0}))
	out.stejna_verze = _ov_stats("stejná verze (kontrola)", ov, d_old, _gen_defs(order, {}))
	return out

## 4) okraje: hranice indexu, dno ostrova, chodba ven bokem a díra dnem → voda
func part_okraje() -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	var out := {}
	var b = blocks[order[0]]
	var f0: PackedByteArray = P78.fine(b).duplicate()
	var tests := {"z=128": P78.op(b, 0, 0, 128, 0), "z=-1": P78.op(b, 0, 0, -1, 0), "x=32": P78.op(b, 32, 0, 5, 0), "polozit_z=127": P78.op(b, 0, 0, 127, DIRT)}
	tests.zmenenych_bunek = _ndiff(f0, P78.fine(b))   # čekáno: jen položení z = 127 (pokud tam byl vzduch)
	out.meze = tests
	# dno ostrova: plné buňky v z = 0 (0,5 m)
	var dno := {}
	for s in order:
		var n := 0
		for ci in 256: if blocks[s].geo[ci * 64] != 0: n += 1
		dno[str(s)] = n
	out.dno_plnych_sloupcu = dno
	print("okraje: meze %s, dno plných sloupců z 256: %s" % [JSON.stringify(tests), JSON.stringify(dno)])
	# voda: díra dnem (šachta 1 × 1 m až do z = 0) a chodba ze zvodnělé vrstvy ven bokem ostrova
	out.dira_dnem = _water_case("dira", blocks, order)
	out.chodba_bokem = _water_case("bok", null, [])
	return out

func _water_case(kind: String, blocks0, order0: Array) -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]
	var v := OV.new(); v.build(blocks)
	var w0: String = v.hydro().otisk; var b0: Dictionary = v.hydro().bilance
	var touched := {}; var n := 0; var info := {}
	if kind == "dira":
		var gp := _pond(v, blocks)   # díra vedle tůně (suché místo z části E79)
		var sx: int = gp.sx; var sy: int = gp.sy
		for x in range(sx, sx + 4):
			for y in range(sy, sy + 4): n += box(blocks, touched, x, x, y, y, 0, surf(blocks, x, y))
		info = {"sx": sx, "sy": sy}
	else:
		var a := _aquifer(v)
		if a.is_empty():
			print("okraje voda bok: zvodnělá vrstva nenalezena"); v.dispose(); return {"nenalezeno": true}
		var gy: int = a.gy; var z0: int = a.z0; var z1: int = a.z1
		n += box(blocks, touched, 0, a.gx, gy, gy + 3, z0, z1)   # chodba až k okraji ostrova (x = 0)
		info = a
	var zm := {}
	for s in touched: zm[s] = P78.sync79(blocks[s]).geo
	var e: Dictionary = v.edit79(zm)
	var w1: String = v.hydro().otisk; var b1: Dictionary = v.hydro().bilance
	var vf := OV.new(); vf.build(blocks)
	var okr := 0
	for u in v.st.get("under", []): if String(u.typ) == "okraj": okr += 1
	var pond_in_hole := 0
	if kind == "dira":
		for x in range(info.sx / 2, info.sx / 2 + 2):
			for y in range(info.sy / 2, info.sy / 2 + 2):
				var a2 := at(x * 2, y * 2)
				var gi: int = v.gi_of(a2[0], a2[1] / 2, a2[2] / 2)
				if v.is_pond(gi) or v.level(gi) >= 0.0: pond_in_hole += 1
				info["hm_%d_%d" % [x, y]] = v.st.hm[gi]
	var r := {"zmen": n, "voda_pred": w0, "voda_po": w1, "plne": vf.hydro().otisk, "shoda": w1 == vf.hydro().otisk, "vystupu_okraj": okr,
		"okraj_lps_pred": float(b0.okraj), "okraj_lps_po": float(b1.okraj), "stena_po": float(b1.podzemi_stena), "do_hloubky_po": float(b1.do_hloubky),
		"chyba_bilance": float(b1.chyba_svet), "voda_v_dire_sloupcu": pond_in_hole, "info": info, "cesta": e.get("cesta", "")}
	print("okraje voda %s: %s" % [kind, JSON.stringify(r)])
	v.dispose(); vf.dispose()
	return r

## 5) kritérium a uložení
func sc_previs(blocks: Dictionary, touched: Dictionary) -> int:
	# nejvyšší schod povrchu mezi sousedními sloupci 0,25 m (ve směru x); podkopat vyšší stranu u paty: 2 m dovnitř, 1,5 m vysoko
	var best := [0, 0, 0, -1]
	for gx in range(2, 54):
		for gy in range(2, 58):
			var d := surf(blocks, gx + 1, gy) - surf(blocks, gx, gy)
			if d > best[3]: best = [gx, gy, surf(blocks, gx, gy), d]
	var n := 0
	var gx0: int = best[0] + 1; var gy0: int = best[1] - 4; var z0: int = best[2]
	n += box(blocks, touched, gx0, gx0 + 7, gy0, gy0 + 8, z0, z0 + 6)
	_info = {"schod_bunek_0_25": best[3], "x": gx0, "y": gy0, "z": z0}
	return n

func sc_oblouk(blocks: Dictionary, touched: Dictionary) -> int:
	# nejvyšší sloupec: průchod 1 × 2 m po x, strop 1 m pod vrcholem → v nižším okolí se otevře do vzduchu
	var best := [0, 0, -1]
	for gx in range(4, 60):
		for gy in range(4, 60):
			if surf(blocks, gx, gy) > best[2]: best = [gx, gy, surf(blocks, gx, gy)]
	var top: int = best[2] - 4; var bot := top - 8
	_info = {"x": best[0], "y": best[1], "vrchol": best[2]}
	return box(blocks, touched, best[0] - 16, best[0] + 16, best[1], best[1] + 3, bot, top)

## dvě chodby nad sebou (1 × 2 m, mezi nimi 1 m skály) ve stejných sloupcích – pásmo vody je spojí
func sc_dve(blocks: Dictionary, touched: Dictionary) -> int:
	var low := 999
	for gx in range(2, 34):
		for gy in range(40, 44): low = mini(low, surf(blocks, gx, gy))
	var t1 := low - 8; var b1 := t1 - 8; var t2 := b1 - 4; var b2 := t2 - 8
	_info = {"chodba1": [b1, t1], "chodba2": [b2, t2]}
	return box(blocks, touched, 2, 33, 40, 43, b1, t1) + box(blocks, touched, 2, 33, 40, 43, b2, t2)

func sc_jeskyne(blocks: Dictionary, touched: Dictionary) -> int:
	var nz := FastNoiseLite.new(); nz.seed = 80; nz.frequency = 0.15
	var cx := 48; var cy := 16
	var s := surf(blocks, cx, cy); var cz := s - 24   # střed 6 m pod povrchem
	var R := 10.0; var n := 0
	for gx in range(cx - 14, cx + 15):
		for gy in range(cy - 14, cy + 15):
			for fz in range(cz - 14, cz + 15):
				var q := Vector3(gx - cx, gy - cy, (fz - cz) * 1.3).length() / R + 0.45 * nz.get_noise_3d(gx, gy, fz)
				if q < 1.0 and fop(blocks, touched, gx, gy, fz, 0): n += 1
	_info = {"stred": [cx, cy, cz]}
	return n

## octree nad mřížkou bloku (4 krychle 32³ po z): uzel = 0 beze změny / 1 + hodnota (jednotný) / 2 + 8 dětí
static func _oct(o: Dictionary, x: int, y: int, z: int, size: int, out: PackedByteArray) -> void:
	var first := -2; var uni := true
	for dx in size:
		for dy in size:
			for dz in size:
				var k := P78.fidx(x + dx, y + dy, z + dz)
				var v: int = o.get(k, -1)
				if first == -2: first = v
				elif v != first: uni = false; break
			if not uni: break
		if not uni: break
	if uni:
		if first == -1: out.append(0)
		else: out.append(1); out.append(first)
		return
	out.append(2)
	var h := size / 2
	for c in 8: _oct(o, x + (c & 1) * h, y + ((c >> 1) & 1) * h, z + ((c >> 2) & 1) * h, h, out)

static func enc_oct(o: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	if o.is_empty(): return out
	for zc in 4: _oct(o, 0, 0, zc * 32, 32, out)
	return out

## husté cihly 8³: [id cihly u16][512 B, 255 = beze změny] jen pro dotčené cihly
static func enc_bricks(o: Dictionary) -> PackedByteArray:
	var br := {}
	for k in o:
		var z: int = k % P78.NZ; var col: int = k / P78.NZ; var fx: int = col / P78.N; var fy: int = col % P78.N
		var id := ((fx / 8) * 4 + fy / 8) * 16 + z / 8
		if not br.has(id):
			var a := PackedByteArray(); a.resize(512); a.fill(255); br[id] = a
		br[id][((fx % 8) * 8 + fy % 8) * 8 + z % 8] = o[k]
	var ids := br.keys(); ids.sort()
	var out := PackedByteArray()
	for id in ids:
		out.append(id & 255); out.append(id >> 8); out.append_array(br[id])
	return out

## třídy sloupců 0,5 m pro vodu (pásma ug_funkce) a 0,25 m pro uložení
func classify(b) -> Dictionary:
	var d := P78.refine(b.def78); var f: PackedByteArray = P78.fine(b)
	var c := {"beze_zmeny": 0, "vyska": 0, "intervaly": 0}
	var runs_tot := 0; var cols_ch := 0
	for col in P78.N * P78.N:
		var base := col * P78.NZ
		var same := true
		for z in P78.NZ:
			if f[base + z] != d[base + z]: same = false; break
		if same: c.beze_zmeny += 1; continue
		cols_ch += 1
		var tl := 0; var td := 0
		for z in P78.NZ:
			if f[base + z] != 0: tl = z + 1
			if d[base + z] != 0: td = z + 1
		var ok := true
		var lim := mini(tl, td)
		for z in lim:
			if f[base + z] != d[base + z]: ok = false; break
		if ok and tl > td:
			for z in range(td, tl): if f[base + z] == 0: ok = false; break
		if ok: c.vyska += 1
		else: c.intervaly += 1
		var r := 0; var z := 0   # úseky změn ve sloupci
		while z < P78.NZ:
			if f[base + z] != d[base + z]:
				r += 1
				while z < P78.NZ and f[base + z] != d[base + z]: z += 1
			else: z += 1
		runs_tot += r
	# sloupce 0,5 m: dutiny pod povrchem (ug_funkce: jedno pásmo od nejnižšího po nejvyšší vzduch)
	var w := {"beze_zmeny": 0, "vyska": 0, "jedna_dutina": 0, "vic_dutin": 0, "jemnejsi_nez_0_5": 0}
	for ci in 256:
		var x := ci / 16; var y := ci % 16
		var changed := false; var partial := false
		for z in 64:
			var nd := 0; var ns := 0
			for dx in 2:
				for dy in 2:
					for dz in 2:
						var k := P78.fidx(2 * x + dx, 2 * y + dy, 2 * z + dz)
						if f[k] != d[k]: nd += 1
						if f[k] == 0: ns += 1
			if nd > 0: changed = true
			if ns > 0 and ns < 8: partial = true
		if not changed: w.beze_zmeny += 1; continue
		if partial: w.jemnejsi_nez_0_5 += 1; continue
		var runs := 0; var inair := false
		for z in int(b.hm[ci]):
			var a: bool = b.geo[ci * 64 + z] == 0
			if a and not inair: runs += 1
			inair = a
		var runs_def := 0; inair = false
		for z in int(b.hm_gen[ci]):
			var a2: bool = b.def78[ci * 64 + z] == 0
			if a2 and not inair: runs_def += 1
			inair = a2
		if runs == runs_def: w.vyska += 1
		elif runs <= 1: w.jedna_dutina += 1
		else: w.vic_dutin += 1
	return {"sloupce_0_25": c, "useku_zmen": runs_tot, "zmenenych_sloupcu_0_25": cols_ch, "sloupce_0_5_voda": w}

func part_kriterium() -> Array:
	var out := []
	for name in _arg("scenare80", "tunel,dlouhy,n1000,previs,oblouk,jeskyne,dve").split(","):
		T.reset()
		var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
		var touched := {}; _info = {}
		var n := 0
		match name:
			"tunel": n = sc_tunel(blocks, touched)
			"dlouhy": n = sc_dlouhy(blocks, touched)
			"n1000": n = sc_rand(blocks, touched, 1000)
			"previs": n = sc_previs(blocks, touched)
			"oblouk": n = sc_oblouk(blocks, touched)
			"jeskyne": n = sc_jeskyne(blocks, touched)
			"dve": n = sc_dve(blocks, touched)
		for s in touched: P78.sync(blocks[s])
		var sz := {"A_klice": [0, 0], "B_intervaly": [0, 0], "C_octree": [0, 0], "D_cihly_8": [0, 0]}
		var cl := {}; var bricks := 0; var polozek := 0
		for s in order:
			var o: Dictionary = P78.overlay(blocks[s])
			polozek += o.size()
			var encs := {"A_klice": P78.enc_keys(o), "B_intervaly": P78.enc_runs(o), "C_octree": enc_oct(o), "D_cihly_8": enc_bricks(o)}
			for k in encs:
				sz[k][0] += encs[k].size(); sz[k][1] += P78.deflate(encs[k]).size()
			bricks += encs.D_cihly_8.size() / 514
			if not o.is_empty():
				var c := classify(blocks[s])
				for grp in ["sloupce_0_25", "sloupce_0_5_voda"]:
					if not cl.has(grp): cl[grp] = {}
					for k in c[grp]: cl[grp][k] = cl[grp].get(k, 0) + c[grp][k]
				cl.useku_zmen = cl.get("useku_zmen", 0) + c.useku_zmen
				cl.zmenenych_sloupcu_0_25 = cl.get("zmenenych_sloupcu_0_25", 0) + c.zmenenych_sloupcu_0_25
		var r := {"scenar": name, "zmen": n, "polozek": polozek, "velikost_raw_deflate": sz, "cihel_8": bricks, "plneni_cihel_proc": 100.0 * polozek / maxf(bricks * 512.0, 1.0),
			"tridy": cl, "useku_na_sloupec": float(cl.get("useku_zmen", 0)) / maxf(cl.get("zmenenych_sloupcu_0_25", 0), 1), "info": _info.duplicate()}
		print("kritérium %s: %d položek, %s, cihel %d (plnění %.0f %%), třídy %s, úseků na sloupec %.2f" % [name, polozek, JSON.stringify(sz), bricks, r.plneni_cihel_proc, JSON.stringify(cl), r.useku_na_sloupec])
		out.append(r)
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/hranice_e80.gd": return   # E81 nástroj dědí pomocné funkce
	var out := {}
	var parts := _arg("casti", "rozliseni,svy,prekryv,okraje,kriterium").split(",")
	if "rozliseni" in parts: out.rozliseni = part_res()
	if "svy" in parts: out.svy = part_svy()
	if "prekryv" in parts: out.prekryv = part_prekryv()
	if "okraje" in parts: out.okraje = part_okraje()
	if "kriterium" in parts: out.kriterium = part_kriterium()
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
