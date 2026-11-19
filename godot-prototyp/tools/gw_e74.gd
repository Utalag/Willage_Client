extends SceneTree
## E74: hladina podzemní vody jako plocha gw(x, y) (scripts/voda/podzemi/gw74.gd) na ostrově prototypu. Postaví vodu
## (p74_gw zapnuté), změří paměť plochy proti pásmům a výsledkům těles, shodu objemu a výtoků s řešiči (E58 auto / E67
## pretok podle --bp.voda_e67, navíc E52 nadrž a přeliv nad stejnými vstupy), pak výkopy jako voda_e66 (seed 66,
## --poradi=obracene) se vzorkováním při kontaktu a nakonec otisk plochy proti čerstvému plnému výpočtu.
## Volby: --vykopu=12 --hloubka=2 --kontrola=1 --bp.<param>=hodnota --out=cesta
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const GW = preload("res://scripts/voda/podzemi/gw74.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const F = preload("res://scripts/voda/podzemi/ug_funkce.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _blocks() -> Dictionary:
	var blocks := {}
	for e in _arg("bloky", "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404").split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	return blocks

## bajty stavu vody v tělesech (výsledky řešičů bez odkazů na kontext)
func _bodies_bytes(bodies: Array) -> int:
	var a := []
	for r in bodies:
		var d := {}
		for k in r:
			if k == "members" or typeof(r[k]) == TYPE_OBJECT: continue
			d[k] = r[k]
		a.append(d)
	return var_to_bytes(a).size()

func _bands_bytes(c: Dictionary) -> int:
	var d := {}
	for k in ["cs", "lo", "hi", "mat", "por", "body", "wq", "bcol", "lab", "dist", "ns", "nb", "comp", "leakf", "h", "wall"]: d[k] = c[k]
	return var_to_bytes(d).size()

## E52 / E58 / E67 nad stejnými vstupy: objem řešiče a objem z plochy
func _modes(v, bodies: Array) -> Dictionary:
	var c: Dictionary = v.ug
	var out := {}
	var r0 := String(c.rezim); var r67 := String(c.get("rezim67", ""))
	var impl = c.impl
	for m in ["nadrz", "preliv", "auto", "pretok"]:
		c.rezim = "auto" if m == "pretok" else m; c.rezim67 = "pretok" if m == "pretok" else ""
		var rs := []; var vs := 0.0
		for r in bodies:
			var x: Dictionary = F.solve(c, PackedInt32Array(r.entries), float(r.q_in), {})
			vs += float(x.volume_m3); rs.append(x)
		var g := GW.build(c, rs)
		var vg := GW.volume(c, g)
		out[m] = {"objem_resic": snappedf(vs, 1e-6), "objem_plocha": snappedf(vg, 1e-6), "rozdil": vg - vs, "sloupcu": _wet_cols(g), "tvar": g.extra.size(), "vyjimek": g.vyjimky.size(), "kompakt_B": GW.bytes_compact(g), "film": g.film.size(), "otisk": GW.otisk(g)}
		for x in rs: x.erase("members")
	c.rezim = r0; c.rezim67 = r67
	return out

func _wet_cols(g: Dictionary) -> int:
	var n := 0
	for t in g.top: if t >= 0.0: n += 1
	return n

func _outs_check(v) -> Dictionary:
	var c: Dictionary = v.ug
	var go := GW.outlets(c, v.gw)
	var gs := {}
	for o in go: gs[int(o[0])] = String(o[2])
	var n := 0; var hit := 0; var near := 0; var miss := []
	for u in v.st.get("under", []):
		n += 1
		var cc: int = F.col_of(c, int(u.exit))
		if gs.has(cc): hit += 1; continue
		var x := cc / int(c.H); var y := cc % int(c.H); var f := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if gs.has((x + dx) * int(c.H) + y + dy): f = true
		if f: near += 1
		else: miss.append([String(u.typ), cc, snappedf(float(u.q), 1e-4)])
	var typy := {}
	for o in go: typy[o[2]] = int(typy.get(o[2], 0)) + 1
	return {"vytoku_plochy": go.size(), "typy": typy, "vystupu_resice": n, "na_vytoku": hit, "vedle": near, "mimo": miss}

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var blocks := _blocks()
	var v := OV.new()

	v.build(blocks)
	var bodies: Array = v.st.get("ug_bodies", [])
	var res := {"voda_ms": v.ms, "souhrn": v.summary(), "hydro68": v.hydro()}
	if v.gw.is_empty(): print("CHYBA: p74_gw vypnuté"); quit(); return
	res.pamet = {"plocha_B": GW.bytes(v.gw), "plocha_ridka_B": GW.bytes_sparse(v.gw), "plocha_kompakt_B": GW.bytes_compact(v.gw), "vyjimek": v.gw.vyjimky.size(), "pasma_B": _bands_bytes(v.ug), "telesa_vysledky_B": _bodies_bytes(bodies),
		"pasem": v.ug.lo.size(), "sloupcu": int(v.ug.W) * int(v.ug.H), "sloupcu_s_vodou": _wet_cols(v.gw), "tvar_sloupcu": v.gw.extra.size(), "film_sloupcu": v.gw.film.size(), "teles": bodies.size()}
	res.gw_ms = v.gw.ms
	var vs := 0.0
	for r in bodies: vs += float(r.volume_m3)
	var vg := GW.volume(v.ug, v.gw)
	res.objem = {"resic": vs, "plocha": vg, "rozdil": vg - vs}
	res.vytoky = _outs_check(v)
	res.otisk_pred = GW.otisk(v.gw)
	# vzorkování celé vodou zasažené části (všechny sloupce s vodou, buňky 0,25 m od bot po povrch) – horní mez kontaktu
	var tb := Time.get_ticks_usec(); var nb := 0; var nw := 0
	for cc in v.gw.top.size():
		if v.gw.top[cc] < 0.0: continue
		var z0 := float(v.gw.extra[cc][0]) if v.gw.extra.has(cc) else float(v.gw.bot[cc])
		var z := z0 + GW.CELL * 0.5
		while z < float(v.ug.h[cc]):
			nb += 1
			if GW.sat(v.gw, cc, z): nw += 1
			z += GW.CELL
	res.vzorek_vse = {"bunek": nb, "s_vodou": nw, "ms": (Time.get_ticks_usec() - tb) / 1000.0}
	print("E74 vzorek všech sloupců s vodou ", res.vzorek_vse)
	print("E74 paměť ", res.pamet, " stavba plochy ", res.gw_ms, " ms")
	print("E74 objem ", res.objem, " výtoky ", res.vytoky)
	# výkopy jako voda_e66
	var n := int(_arg("vykopu", "12")); var dep := int(_arg("hloubka", "2")); var chk := _arg("kontrola", "1") == "1"
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0: cand.append(i)
	for sp in v.springs: cand.append(sp.gi)
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	var seq := []
	for k in mini(n, cand.size()): seq.append(cand[rng.randi_range(0, cand.size() - 1)])
	if _arg("poradi", "") == "obracene": seq.reverse()
	var digs := []; var bad_tot := 0; var hydro_bad := 0; var gw_bad := 0
	for k in seq.size():
		var gi: int = seq[k]
		var a := v.slot_of(gi)
		var b = blocks[a[0]]
		var ci: int = a[1] * 16 + a[2]
		var h0: int = b.hm[ci]
		var nh := maxi(h0 - dep, 1)
		for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
		b.hm[ci] = nh
		var cc: int = F.col_of(v.ug, gi)
		var z0 := float(v.ug.h[cc])
		var r := v.edit(a[0], a[1], a[2], nh)
		while v.pending(): v.step()
		var kon := GW.contact(v.ug, v.gw, cc, z0, float(v.ug.h[cc]))
		kon.erase("cells")
		var e := {"gi": gi, "ms": r.get("ms", 0.0), "gw_ms": r.get("gw_ms", 0.0), "kontakt": kon, "otisk": GW.otisk(v.gw)}
		if chk:
			var bad: Dictionary = v.check_full()
			e.neshod = bad; bad_tot += int(bad.fill) + int(bad.eff) + int(bad.to)
			e.otisk_shoda = H68.otisk(v.st) == v.full_otisk
			e.gw_shoda = GW.otisk(v.gw) == GW.otisk(v.full_gw)
			if not e.otisk_shoda: hydro_bad += 1
			if not e.gw_shoda: gw_bad += 1
		digs.append(e)
		print("výkop %d sloupec %d: %.1f ms, plocha %.2f ms, kontakt %d buněk (výtok %d, mokrá %d, jáma %.2f) %d µs%s" % [k + 1, gi, e.ms, e.gw_ms, kon.bunek, kon.vytok, kon.mokra, kon.hladina_jamy, kon.us, (" neshod %s otisk %s plocha %s" % [str(e.neshod), e.otisk_shoda, e.gw_shoda]) if chk else ""])
	res.vykopy = digs; res.neshod_celkem = bad_tot; res.otisk_neshod = hydro_bad; res.plocha_neshod = gw_bad
	res.otisk_po = GW.otisk(v.gw)
	res.vytoky_po = _outs_check(v)
	var vs2 := 0.0
	for r in v.st.get("ug_bodies", []): vs2 += float(r.volume_m3)
	res.objem_po = {"resic": vs2, "plocha": GW.volume(v.ug, v.gw)}
	res.hydro68_po = v.hydro(); res.souhrn_po = v.summary()
	res.vyver74 = v.st.get("under", []).filter(func(u): return String(u.typ) == "vyver74").size()
	res.obsazeno = v.claims.size()
	# režimy E52 / E58 / E67 na čerstvě postaveném ostrově (stejný terén po výkopech, prameny znovu z terénu)
	var v2 := OV.new()
	v2.claims = v.claims.duplicate()
	v2.build(blocks)
	res.hydro_otisk_po = H68.otisk(v.st)
	res.rezimy = _modes(v2, v2.st.get("ug_bodies", []))   # E52 / E58 / E67 nad vstupy těles (na čerstvém výpočtu)
	print("E74 režimy ", res.rezimy)
	print("E74 po výkopech: otisk plochy ", res.otisk_po, " | hydro ", res.hydro_otisk_po, " | neshod ", bad_tot, " otisk ≠ plný ", hydro_bad, " plocha ≠ plná ", gw_bad, " | vyver74 ", res.vyver74, " obsazeno ", res.obsazeno)
	print("E74 bilance po ", res.hydro68_po.bilance.chyba_svet, " souhrn ", res.souhrn_po)
	var o := _arg("out", "")
	if o != "": FileAccess.open(o, FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	v.dispose(); v2.dispose()
	quit()
