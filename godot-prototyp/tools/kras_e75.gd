extends SceneTree
## E75: kras na ostrově prototypu (scripts/voda/podzemi/kras75.gd, p75_kras zapnuté). Postaví vodu, vypíše rozpustná
## pásma na cestách těles a rychlosti rozpouštění, provede výkopy jako voda_e66 (seed 66, --poradi=obracene) v čase 0,
## pak pustí kras do --dni herních dní nebo --udalosti událostí. Po každé události kontrola proti čerstvému plnému výpočtu
## (fill / eff / to a otisk vody) a otisk krasu. 1 herní den = 86 400 herních s = 10 min reálně (p71_cas 144).
## Volby: --vykopu=12 --hloubka=2 --dni=365 --udalosti=12 --kontrola=1 --bp.<param>=hodnota --out=cesta
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const K75 = preload("res://scripts/voda/podzemi/kras75.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const DEN := 86400.0

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _per_mat(v) -> Dictionary:
	var m := {}
	for b in v.kras.rate:
		var k := str(v.kras.mat[b])
		if not m.has(k): m[k] = [0, 0.0]
		m[k][0] += 1; m[k][1] += float(v.kras.rate[b])
	return m

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var blocks := {}
	for e in _arg("bloky", "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404").split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	var v := OV.new()
	v.build(blocks)
	if v.kras.is_empty(): print("CHYBA: p75_kras vypnuté"); quit(); return
	var res := {"voda_ms": v.ms, "souhrn": v.summary(), "hydro68": v.hydro(), "rates_ms": v.kras.stats.rates_ms, "pasem": v.kras.rate.size()}
	var tot := 0.0
	for b in v.kras.rate: tot += float(v.kras.rate[b])
	var ne := K75.next_event(v.kras)
	res.rychlost = {"celkem_m3_s": tot, "m3_za_herni_den": tot * DEN, "po_materialech": _per_mat(v), "prvni_udalost_dni": float(ne[0]) / DEN, "prvni_udalost_realne_min": float(ne[0]) / DEN * 10.0, "pasmo": ne[1]}
	var tq := 0.0
	for r in v.st.get("ug_bodies", []): tq += float(r.q_in)
	res.pruttok_l_s = tq
	print("E75 rozpustná pásma na cestách ", res.pasem, ", rychlost ", res.rychlost, ", průtok těles ", tq, " l/s, výpočet rychlostí ", res.rates_ms, " ms")
	# výkopy v čase 0 (jako voda_e66)
	var n := int(_arg("vykopu", "12")); var dep := int(_arg("hloubka", "2")); var chk := _arg("kontrola", "1") == "1"
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0: cand.append(i)
	for sp in v.springs: cand.append(sp.gi)
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	var seq := []
	for k in mini(n, cand.size()): seq.append(cand[rng.randi_range(0, cand.size() - 1)])
	if _arg("poradi", "") == "obracene": seq.reverse()
	var digs := []
	for k in seq.size():
		var gi: int = seq[k]
		var a := v.slot_of(gi)
		var b = blocks[a[0]]
		var ci: int = a[1] * 16 + a[2]
		var h0: int = b.hm[ci]
		var nh := maxi(h0 - dep, 1)
		for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
		b.hm[ci] = nh
		var r := v.edit(a[0], a[1], a[2], nh)
		while v.pending(): v.step()
		digs.append({"gi": gi, "ms": r.get("ms", 0.0), "kras": r.get("kras", {})})
	res.vykopy = digs
	res.otisk_kras_po_vykopech = K75.otisk(v.kras)
	res.rychlost_po_vykopech = _per_mat(v)
	# kras v čase
	var dni := float(_arg("dni", "365")); var nev := int(_arg("udalosti", "12"))
	var evs := []; var bad_tot := 0; var hb := 0
	var t := 0.0
	while evs.size() < nev:
		var got: Array = v.kras_run(dni * DEN, 1)
		if got.is_empty(): break
		var e: Dictionary = got[0]
		e.dni = float(e.t_s) / DEN; e.realne_min = e.dni * 10.0
		if chk:
			var bad: Dictionary = v.check_full()
			e.neshod = bad; bad_tot += int(bad.fill) + int(bad.eff) + int(bad.to)
			e.otisk_shoda = H68.otisk(v.st) == v.full_otisk
			if not e.otisk_shoda: hb += 1
		e.otisk_kras = K75.otisk(v.kras)
		evs.append(e)
		print("událost %d: den %.2f (%.0f min reálně), pásmo %d mat %d, dutina %.4f m³, přepočet %.0f ms%s" % [evs.size(), e.dni, e.realne_min, e.pasmo, e.mat, e.dutina_m3, e.ms, (" neshod %s otisk %s" % [str(e.neshod), e.otisk_shoda]) if chk else ""])
	res.udalosti = evs; res.neshod_celkem = bad_tot; res.otisk_neshod = hb
	res.cas_konec_dni = float(v.kras.now) / DEN
	res.otisk_kras = K75.otisk(v.kras); res.otisk_voda = H68.otisk(v.st)
	res.dutiny = {}
	for b in v.kras.dut: res.dutiny[str(b)] = {"m3": v.kras.dut[b], "bunek": K75.cells(v.kras, b).size(), "sloupec": v.kras.col.get(b, -1), "mat": v.kras.mat.get(b, -1), "vrsek_m": v.kras.ztop.get(b, 0.0)}
	res.hydro68_po = v.hydro(); res.souhrn_po = v.summary()
	print("E75 konec: den %.2f, událostí %d, neshod %d, otisk≠plný %d, otisk krasu %s, vody %s, chyba %s" % [res.cas_konec_dni, evs.size(), bad_tot, hb, res.otisk_kras, res.otisk_voda, str(res.hydro68_po.bilance.chyba_svet)])
	var o := _arg("out", "")
	if o != "": FileAccess.open(o, FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	v.dispose()
	quit()
