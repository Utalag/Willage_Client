extends SceneTree
## E78: překryv změn po kopání (scripts/teren/prekryv78.gd). Ostrov 4 bloky, změny v mřížce 0,25 m → uložit jen překryv
## (záznam E76 + buňky) → načíst (bloky znovu z definice + překryv) → otisk buněk a vody proti živému stavu.
## Scénáře: chodba (šachta z povrchu + vodorovná chodba 1 × 2 m přes dva bloky, položení hlíny, zasypání), náhodné
## výkopy 1, 10, 100, 1000 buněk, testy pořadí. Velikosti proti celému poli WVB1. Voda: --bp.p76_prameny=true.
## Volby: --scenare=tunel,n1,n10,n100,n1000 --delka=64 --out=cesta
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const P78 = preload("res://scripts/teren/prekryv78.gd")
const START := "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404"
const DIRT := 2

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func gen_blocks(spec: String) -> Array:
	var blocks := {}; var order := []
	for e in spec.split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); P78.attach(b); blocks[b.slot] = b; order.append(b.slot)
	return [blocks, order]

## globální jemné souřadnice ostrova → [slot, fx, fy]
static func at(gx: int, gy: int) -> Array:
	return [Vector2i(floori(gx / 32.0), floori(gy / 32.0)), posmod(gx, 32), posmod(gy, 32)]

func fop(blocks: Dictionary, touched: Dictionary, gx: int, gy: int, fz: int, mat: int) -> bool:
	var a := at(gx, gy)
	if not blocks.has(a[0]): return false
	touched[a[0]] = true
	return P78.op(blocks[a[0]], a[1], a[2], fz, mat)

func fget(blocks: Dictionary, gx: int, gy: int, fz: int) -> int:
	var a := at(gx, gy)
	return P78.fine(blocks[a[0]])[P78.fidx(a[1], a[2], fz)]

func surf(blocks: Dictionary, gx: int, gy: int) -> int:   # nejvyšší plná buňka 0,25 m + 1
	var a := at(gx, gy)
	if not blocks.has(a[0]): return 0
	return 2 * int(blocks[a[0]].hm[(a[1] / 2) * 16 + a[2] / 2])

## scénář chodby: šachta 1 × 1 m z povrchu, chodba šířka 1 m, výška 2 m, délka `delka` buněk 0,25 m po ose x; pak
## položení hlíny na povrch (vršek 1 × 1 m, dvě vrstvy), zasypání konce chodby hlínou (2 × 2 × 2) a jedné buňky
## původním materiálem (tím z překryvu zmizí)
func sc_tunel(blocks: Dictionary, touched: Dictionary) -> int:
	var L := int(_arg("delka", "60"))
	var y0 := 14; var x0 := 2
	var low := 999
	for gx in range(x0, x0 + L):
		for gy in range(y0, y0 + 4): low = mini(low, surf(blocks, gx, gy))
	var top := low - 12          # strop chodby 3 m pod nejnižším povrchem na trase
	var bot := top - 8
	var n := 0
	# šachta
	for gx in range(x0, x0 + 4):
		for gy in range(y0, y0 + 4):
			for fz in range(bot, surf(blocks, gx, gy)):
				if fop(blocks, touched, gx, gy, fz, 0): n += 1
	for gx in range(x0, x0 + L):
		for gy in range(y0, y0 + 4):
			for fz in range(bot, top):
				if fop(blocks, touched, gx, gy, fz, 0): n += 1
	# položit hlínu na povrch u bloku (0,1)
	for gx in range(40, 44):
		for gy in range(40, 44):
			var s := surf(blocks, gx, gy)
			for fz in range(s, s + 2):
				if fop(blocks, touched, gx, gy, fz, DIRT): n += 1
	# zasypat konec chodby hlínou
	for gx in range(x0 + L - 2, x0 + L):
		for gy in range(y0, y0 + 2):
			for fz in range(bot, bot + 2):
				if fop(blocks, touched, gx, gy, fz, DIRT): n += 1
	# zasypat jednu buňku původním materiálem
	var a := at(x0 + 10, y0)
	var orig: int = P78.refine(blocks[a[0]].def78)[P78.fidx(a[1], a[2], bot)]
	if orig != 0 and fop(blocks, touched, x0 + 10, y0, bot, orig): n += 1
	return n

## dlouhá chodba: had přes všechny 4 bloky (4 řady po 16 m + 3 spojky), průřez 1 × 2 m, ve stálé výšce pod povrchem
func sc_dlouhy(blocks: Dictionary, touched: Dictionary) -> int:
	var rows := [4, 20, 36, 52]
	var low := 999
	for gx in 64:
		for gy in 64: low = mini(low, surf(blocks, gx, gy))
	var top := low - 12; var bot := top - 8
	var n := 0
	var path := []
	for r in rows.size():
		for gx in range(0, 64): path.append([gx, rows[r]])
		if r + 1 < rows.size():
			var ex := 60 if r % 2 == 0 else 0
			for gy in range(rows[r] + 4, rows[r + 1]): path.append([ex, gy])
	for c in path:   # řada: 4 buňky do šířky v y; spojka: 4 buňky do šířky v x
		var row: bool = c[1] in rows
		for w in 4:
			var gx: int = c[0] if row else c[0] + w
			var gy: int = c[1] + w if row else c[1]
			for fz in range(bot, top):
				if fop(blocks, touched, gx, gy, fz, 0): n += 1
	return n

func sc_rand(blocks: Dictionary, touched: Dictionary, cnt: int) -> int:
	var rng := RandomNumberGenerator.new(); rng.seed = 78
	var n := 0; var tries := 0
	while n < cnt and tries < cnt * 50:
		tries += 1
		var gx := rng.randi_range(0, 63); var gy := rng.randi_range(0, 63)
		var s := surf(blocks, gx, gy)
		if s <= 2: continue
		var fz := rng.randi_range(1, s - 1)
		if fop(blocks, touched, gx, gy, fz, 0): n += 1
	return n

## živý stav: jemné změny → buňky 0,5 m → lokální přepočet vody po sloupcích, kterým se změnila výška
func apply_live(v, blocks: Dictionary, touched: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec(); var cols := 0
	for s in touched:
		var ch: Array = P78.sync(blocks[s])
		for ci in ch:
			v.edit(s, ci / 16, ci % 16, int(blocks[s].hm[ci])); cols += 1
			while v.pending(): v.step()
	return {"sloupcu": cols, "ms": (Time.get_ticks_usec() - t0) / 1000.0}

func sizes(blocks: Dictionary, order: Array) -> Dictionary:
	var r := {"polozek": 0, "a_raw": 0, "a_def": 0, "b_raw": 0, "b_def": 0, "wvb1_05_raw": 0, "wvb1_05_def": 0, "wvb1_025_raw": 0, "wvb1_025_def": 0}
	var ok := true
	for s in order:
		var b = blocks[s]
		var o: Dictionary = P78.overlay(b)
		var ea := P78.enc_keys(o); var eb := P78.enc_runs(o)
		if P78.dec_keys(ea) != o or P78.dec_runs(eb) != o: ok = false
		r.polozek += o.size(); r.a_raw += ea.size(); r.a_def += P78.deflate(ea).size()
		r.b_raw += eb.size(); r.b_def += P78.deflate(eb).size()
		var fn: PackedByteArray = P78.fine(b)
		r.wvb1_05_raw += b.geo.size(); r.wvb1_05_def += P78.deflate(b.geo).size()
		r.wvb1_025_raw += fn.size(); r.wvb1_025_def += P78.deflate(fn).size()
	r.kodovani_zpet_ok = ok
	return r

func run_scenario(name: String) -> Dictionary:
	T.reset()
	var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
	# kontrola definice: buňky 0,5 m → 0,25 m → 0,5 m beze změny, výška = hm_gen
	var def_ok := true
	for s in order:
		var b = blocks[s]
		var geo0: PackedByteArray = b.geo.duplicate(); var hm0: PackedInt32Array = b.hm.duplicate()
		P78.fine(b); P78.sync(b)
		if b.geo != geo0 or b.hm != hm0: def_ok = false
	var v := OV.new(); v.build(blocks)
	var w0: String = v.hydro().otisk; var o0 := P78.otisk(blocks)
	var touched := {}
	var t0 := Time.get_ticks_usec()
	var n := 0
	if name == "tunel": n = sc_tunel(blocks, touched)
	elif name == "dlouhy": n = sc_dlouhy(blocks, touched)
	else: n = sc_rand(blocks, touched, int(name.substr(1)))
	var op_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var lv := apply_live(v, blocks, touched)
	var live_f := P78.otisk(blocks); var live_c := P78.otisk(blocks, true)
	var w_loc: String = v.hydro().otisk
	var vf := OV.new(); t0 = Time.get_ticks_usec(); vf.build(blocks); var full_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var w_full: String = vf.hydro().otisk
	var d_lf: Dictionary = diff(v.st, vf.st)
	var sz := sizes(blocks, order)
	var js := JSON.stringify(P78.save(blocks, order))
	# načtení
	T.reset()
	t0 = Time.get_ticks_usec(); gen_blocks(START); var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	T.reset()
	t0 = Time.get_ticks_usec()
	var bl2: Dictionary = P78.load_into(JSON.parse_string(js), Block, BlockGen, T)
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var v2 := OV.new(); t0 = Time.get_ticks_usec(); v2.build(bl2); var w2_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var r := {"scenar": name, "definice_tam_a_zpet_ok": def_ok, "zmen_op": n, "op_ms": op_ms, "zive": lv,
		"otisk_puvodni": o0, "voda_puvodni": w0, "otisk_zive": live_f, "otisk_zive_05": live_c,
		"otisk_nacteno": P78.otisk(bl2), "otisk_nacteno_05": P78.otisk(bl2, true),
		"voda_zive_lokalne": w_loc, "voda_zive_plne": w_full, "voda_plne_ms": full_ms, "lokalne_vs_plne_neshod": d_lf,
		"voda_nacteno": v2.hydro().otisk, "nacteni_bloky_ms": load_ms, "jen_definice_ms": gen_ms, "nacteni_voda_ms": w2_ms,
		"zaznam_json_B": js.length(), "velikost": sz}
	r.bunky_shoda = r.otisk_zive == r.otisk_nacteno and r.otisk_zive_05 == r.otisk_nacteno_05
	r.voda_shoda_plne = r.voda_zive_plne == r.voda_nacteno
	r.voda_shoda_lokalne = r.voda_zive_lokalne == r.voda_nacteno
	print("%s: %d změn (%d položek překryvu), buňky %s, voda plně %s / lokálně %s (neshod %s), A %d/%d B, B %d/%d B, WVB1 0,5 m %d/%d, 0,25 m %d/%d, načtení %.0f (z toho definice %.0f) + voda %.0f ms" % [name, n, sz.polozek,
		str(r.bunky_shoda), str(r.voda_shoda_plne), str(r.voda_shoda_lokalne), str(d_lf), sz.a_raw, sz.a_def, sz.b_raw, sz.b_def, sz.wvb1_05_raw, sz.wvb1_05_def, sz.wvb1_025_raw, sz.wvb1_025_def, load_ms, gen_ms, w2_ms])
	v.dispose(); vf.dispose(); v2.dispose()
	return r

static func diff(s1: Dictionary, s2: Dictionary) -> Dictionary:
	var d := {"fill": 0, "eff": 0, "to": 0}
	for i in s1.fill.size():
		if s1.fill[i] != s2.fill[i]: d.fill += 1
		if s1.eff[i] != s2.eff[i]: d.eff += 1
		if s1.to[i] != s2.to[i]: d.to += 1
	return d

## pořadí: stejné operace v jiném pořadí na jedné buňce a na různých buňkách (bez vody, jen buňky)
func order_tests() -> Dictionary:
	var res := {}
	var seqs := {
		"vykopat_zasypat": [[0], [DIRT]],
		"zasypat_vykopat": [[DIRT], [0]],
		"vykopat_vratit_puvodni": [[0], [-1]],
		"ruzne_AB": [[0, "A"], [DIRT, "B"]],
		"ruzne_BA": [[DIRT, "B"], [0, "A"]],
	}
	for k in seqs:
		T.reset()
		var g := gen_blocks(START); var blocks: Dictionary = g[0]; var order: Array = g[1]
		var o0 := P78.otisk(blocks)
		var s := surf(blocks, 20, 20)
		var cz := s - 6                # první plná buňka jiná než hlína aspoň 1,5 m pod povrchem
		while cz > 1 and (fget(blocks, 20, 20, cz) == 0 or fget(blocks, 20, 20, cz) == DIRT): cz -= 1
		var C := [20, 20, cz]
		var A := [21, 20, s - 6]
		var B := [22, 22, surf(blocks, 22, 22)]   # vzduch nad povrchem
		var orig := fget(blocks, C[0], C[1], C[2])
		var touched := {}
		var log := []
		for st in seqs[k]:
			var m: int = st[0] if st[0] != -1 else orig
			var cell: Array = C
			if st.size() > 1: cell = A if st[1] == "A" else B
			log.append([m, fop(blocks, touched, cell[0], cell[1], cell[2], m)])
		for sl in touched: P78.sync(blocks[sl])
		var ov := 0
		for sl in order: ov += P78.overlay(blocks[sl]).size()
		res[k] = {"otisk": P78.otisk(blocks), "puvodni": o0, "polozek": ov, "operace_provedena": log, "material_C": fget(blocks, C[0], C[1], C[2]), "puvodni_C": orig}
		print("pořadí %s: otisk %s (původní %s), položek %d, operace %s, C %d (původně %d)" % [k, res[k].otisk, o0, ov, str(log), res[k].material_C, orig])
	return res

func _init() -> void:
	var out := {"pravidla": "buňka 0,25 m, překryv = konečný stav, položka = definice se maže, poslední operace na buňce vyhrává, buňka 0,5 m plná dokud zbývá 1 z 8"}
	out["poradi"] = order_tests()
	var sc := []
	for name in _arg("scenare", "tunel,dlouhy,n1,n10,n100,n1000").split(","): sc.append(run_scenario(name))
	out["scenare"] = sc
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
