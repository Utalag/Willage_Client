extends SceneTree
## E76: voda po přenosu výřezu a po novém postavení ostrova (scripts/voda/prenos76.gd, ostrov_voda.gd, p76_prameny, p76_mat_gen).
## Část A (nález E74): výkopy lokálně → nové postavení ze stejných bloků a „načtení“ (bloky znovu z typu + seedu + překryvu
## výkopů + uložených pramenů) → otisk a neshody proti lokálnímu stavu.
## Část B: výřez z průzkumného světa (jiní sousedé, jiný slot) vložený vedle bloků ostrova s posunem dz → plný a lokální
## přepočet, bilance, změny proti původu, přeplánování událostí.
## Volby: --cast=A,B --vykopu=12 --hloubka=2 --vyrez=kopec:707 --slot=2,0 --dz=0,4,-4 --bp.<klíč>=hodnota --out=cesta
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const P76 = preload("res://scripts/voda/prenos76.gd")
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

## výkop: vrchní buňky sloupce pryč (jako voda_e66) + lokální přepočet a kroky R
func dig(v, blocks: Dictionary, gi: int, dep: int) -> void:
	var a: Array = v.slot_of(gi)
	var b = blocks[a[0]]
	var ci: int = a[1] * 16 + a[2]
	var h0: int = b.hm[ci]; var nh := maxi(h0 - dep, 1)
	for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
	b.hm[ci] = nh
	v.edit(a[0], a[1], a[2], nh)
	while v.pending(): v.step()

static func diff(s1: Dictionary, s2: Dictionary) -> Dictionary:
	var d := {"fill": 0, "eff": 0, "to": 0}
	for i in s1.fill.size():
		if s1.fill[i] != s2.fill[i]: d.fill += 1
		if s1.eff[i] != s2.eff[i]: d.eff += 1
		if s1.to[i] != s2.to[i]: d.to += 1
	return d

static func spring_set(v) -> Array:
	var a := []
	for sp in v.springs: a.append("%d|%d|%.4f|%s" % [int(sp.gi), int(sp.z), float(sp.q), String(sp.druh)])
	a.sort()
	return a

## uložení: jen to, co je potřeba k načtení (typ, seed, slot, posun, překryv výkopů, uložené prameny)
static func save(blocks: Dictionary, order: Array) -> Array:
	var out := []
	for s in order:
		var b = blocks[s]
		var ov := []
		for k in 256:
			if b.hm[k] != b.hm_gen[k]: ov.append([k, int(b.hm[k])])
		out.append({"kind": b.kind, "seed": b.seed, "slot": [s.x, s.y], "shift": b.shift, "vykopy": ov, "prameny76": b.prameny76})
	return out

func load_blocks(data: Array) -> Dictionary:
	T.reset()
	var blocks := {}
	for e in data:
		var b := Block.new(); b.kind = e.kind; b.seed = int(e.seed); b.slot = Vector2i(int(e.slot[0]), int(e.slot[1])); b.shift = int(e.shift)
		BlockGen.build(b, [null, null, null, null]); T.commit(b)
		for o in e.vykopy:
			var k: int = o[0]; var nh: int = o[1]
			for z in range(nh, b.hm[k]): b.geo[k * 64 + z] = 0; b.cells[k * 64 + z] = 0
			b.hm[k] = nh
		b.prameny76 = e.prameny76
		blocks[b.slot] = b
	return blocks

func part_a() -> Dictionary:
	T.reset()
	var blocks := gen_blocks(_arg("bloky", START))
	var order := blocks.keys()
	var v := OV.new(); v.build(blocks)
	var h_first: String = v.hydro().otisk
	var sp0 := spring_set(v)
	var n := int(_arg("vykopu", "12")); var dep := int(_arg("hloubka", "2"))
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0: cand.append(i)
	for sp in v.springs: cand.append(sp.gi)
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	var seq := []
	for k in mini(n, cand.size()): seq.append(cand[rng.randi_range(0, cand.size() - 1)])
	var t0 := Time.get_ticks_usec()
	for gi in seq: dig(v, blocks, gi, dep)
	var dig_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var loc: String = v.hydro().otisk
	var chk: Dictionary = v.check_full()
	# nové postavení ze stejných bloků (jako po vložení dalšího bloku nebo po restartu scény)
	var v2 := OV.new()
	t0 = Time.get_ticks_usec(); v2.build(blocks); var reb_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var reb: String = v2.hydro().otisk
	var d_reb := diff(v.st, v2.st)
	var sp_loc := spring_set(v); var sp_reb := spring_set(v2)
	var sp_d := 0
	for x in sp_loc: if not x in sp_reb: sp_d += 1
	for x in sp_reb: if not x in sp_loc: sp_d += 1
	# načtení: bloky znovu z uloženého minima
	var data := save(blocks, order)
	var js := JSON.stringify(data)
	var bl3 := load_blocks(JSON.parse_string(js))
	var v3 := OV.new(); t0 = Time.get_ticks_usec(); v3.build(bl3); var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var lod: String = v3.hydro().otisk
	var d_load := diff(v.st, v3.st)
	var r := {"otisk_prvni": h_first, "prameny_prvni": sp0.size(), "vykopu": seq.size(), "vykopy_ms": dig_ms, "otisk_lokalne": loc, "check_full": chk,
		"otisk_znovu": reb, "znovu_neshod": d_reb, "znovu_ms": reb_ms, "prameny_jinak": sp_d, "prameny_lokalne": sp_loc.size(), "prameny_znovu": sp_reb.size(),
		"otisk_nacteni": lod, "nacteni_neshod": d_load, "nacteni_ms": load_ms, "ulozeno_bajtu": js.length(),
		"bilance_lokalne": v.hydro().bilance.chyba_svet, "bilance_znovu": v2.hydro().bilance.chyba_svet}
	print("A: první otisk %s, prameny %d; %d výkopů %.0f ms → lokálně %s (check_full %s)" % [h_first, sp0.size(), seq.size(), dig_ms, loc, str(chk)])
	print("A: nové postavení %s (%.0f ms) neshod %s, prameny jinak %d (%d → %d); načtení %s (%.0f ms) neshod %s, uloženo %d B" % [reb, reb_ms, str(d_reb), sp_d, sp_loc.size(), sp_reb.size(), lod, load_ms, str(d_load), js.length()])
	v.dispose(); v2.dispose(); v3.dispose()
	return r


## pásma podzemí sloupců bloku (slot světa) → klíče pro srovnání materiálů původ / ostrov (bez posunu dz)
static func bands_of(ug: Dictionary, ws: Vector2i, dzm: float, inner: bool, zmin := 0.0) -> Array:
	var out := []
	var W: int = ug.W
	for x in 16:
		for y in 16:
			if inner and (x == 0 or y == 0 or x == 15 or y == 15): continue
			var c: int = (ws.x * 16 + x) * W + ws.y * 16 + y
			var a := []
			for b in range(ug.cs[c], ug.cs[c + 1]):   # v souřadnicích původu, oříznuto na z ≥ zmin (dno se posunem mění)
				var lo := maxf(float(ug.lo[b]) - dzm, zmin); var hi := float(ug.hi[b]) - dzm
				if hi > lo + 1e-6: a.append("%d:%.3f:%.3f" % [int(ug.mat[b]), lo, hi])
			out.append(",".join(a))
	return out

static func same_frac(a: Array, b: Array) -> float:
	var k := 0
	for i in a.size(): if a[i] == b[i]: k += 1
	return float(k) / maxf(a.size(), 1)

func part_b() -> Dictionary:
	var vy := _arg("vyrez", "kopec:707").split(":")
	var origin_spec := _arg("puvod", "0,0:hora:808;1,0:louka:909;0,1:%s:%s;1,1:piscina:606;-1,1:louka:505" % [vy[0], vy[1]])
	var oslot := Vector2i(0, 1)
	# 1) průzkumný svět: výřez s jinými sousedy, voda v původu
	T.reset()
	var ob := gen_blocks(origin_spec)
	var v0 := OV.new(); v0.build(ob)
	var reg0 := P76.region(v0, oslot)
	var cut := P76.cutout(ob[oslot], v0)
	var ug0 := v0.ug
	var o_h: String = v0.hydro().otisk
	print("B původ: výřez %s seed %s na slotu %s, prameny výřezu %d, voda v bloku %s" % [vy[0], vy[1], oslot, cut.prameny.size(), str(reg0)])
	var res := {"puvod": {"region": reg0, "otisk": o_h, "prameny_vyrezu": cut.prameny}, "vlozeni": []}
	var runs := []
	for ss in _arg("slot", "2,0;0,-1").split(";"):
		for dzs in _arg("dz", "0,4,-4").split(","): runs.append([Vector2i(ss.split(",")[0].to_int(), ss.split(",")[1].to_int()), int(dzs)])
	for rn in runs:
		var tslot: Vector2i = rn[0]; var dz: int = rn[1]
		# 2) ostrov: startovní bloky, voda, plán událostí
		T.reset()
		var blocks := gen_blocks(_arg("bloky", START))
		var v := OV.new(); v.build(blocks)
		var tot0: Dictionary = v.hydro().bilance
		var ev0: Dictionary = P76.events(v, {}, {}, {})
		var cnt0: Dictionary = P76.counters(ev0._mc, v)
		var st_old := {"fill": v.st.fill.duplicate(), "eff": v.st.eff.duplicate(), "to": v.st.to.duplicate(), "ain": v.st.ain.duplicate(), "pw": v.st.pw.duplicate()}
		# 3) vložení výřezu: lokálně
		var b = P76.place(cut, tslot, dz)
		T.commit(b)
		blocks[tslot] = b
		var loc: Dictionary = v.place76(b)
		var h_loc: Dictionary = v.hydro()
		var reg_loc := P76.region(v, tslot)
		# přeplánování: výřez s plnými odpočty, jinde odpočty zachované; jen sloupce, kde se voda změnila (+ výřez)
		var fresh := {}
		for x in 16:
			for y in 16: fresh[v.gi_of(tslot, x, y)] = true
		var dd76: Dictionary = P76.dirty(v, st_old, tslot)
		var only: Dictionary = dd76.only; var nchg: int = dd76.zmenene
		var ev1: Dictionary = P76.events(v, cnt0, fresh, only)
		var ev_all: Dictionary = P76.events(v, cnt0, fresh, {})
		# shoda plánu: nezměněné sloupce drží starou položku (čas z plánu před vložením), přeplánované novou → = plné přeplánování
		var due_bad := 0; var due_n := 0
		var m0 = ev0._mc; var m1 = ev1._mc; var mf = ev_all._mc
		for i in v.W * v.H:
			if v.island[i] == 0: continue
			var tf: float = mf.due(i)
			var tl: float = m1.due(i) if only.has(i) else (m0.due(i) if i < m0.R.size() and st_old.fill.size() > i and v.island[i] == 1 and not fresh.has(i) else INF)
			if tf < INF or tl < INF:
				due_n += 1
				if not (tf == tl or absf(tf - tl) <= 1e-9 * maxf(absf(tf), 1.0)):
					due_bad += 1
					if _arg("ladit", "0") == "1" and due_bad <= 5: print("ladit plán ", i, " only ", only.has(i), " fresh ", fresh.has(i), " full ", tf, " lok ", tl, " m0 ", m0.due(i), " mode0 ", m0.mode[i], " modef ", mf.mode[i], " re0 ", m0.re[i], " ref ", mf.re[i], " R0 ", m0.R[i], " Rf ", mf.R[i], " slot ", v.slot_of(i))
		# 4) plný přepočet: nové postavení ze všech bloků (výřez s uloženými prameny)
		var v2 := OV.new()
		var t0 := Time.get_ticks_usec(); v2.build(blocks); var full_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var h_full: Dictionary = v2.hydro()
		var d := diff(v.st, v2.st)
		var zm := maxf(0.0, -dz * 0.5)
		var ug0_in := bands_of(ug0, T.wslot(oslot), 0.0, true, zm); var ug0_all := bands_of(ug0, T.wslot(oslot), 0.0, false, zm)
		var ug_in := bands_of(v2.ug, T.wslot(tslot), dz * 0.5, true, zm); var ug_all := bands_of(v2.ug, T.wslot(tslot), dz * 0.5, false, zm)
		var reg_full := P76.region(v2, tslot)
		if _arg("ladit", "0") == "1":
			var g0: int = v2.gi_of(tslot, 8, 8)
			print("ladit hm ", v2.st.hm[g0], " fill ", v2.st.fill[g0], " island ", v2.island[g0], " b.hm ", b.hm[8 * 16 + 8], " prameny ", v2.springs, " p76 ", b.prameny76, " slot_of ", v2.slot_of(g0))
		# kontrola: stejné sloupce výřezu jako v původu (povrch)
		var hsame := 0
		for k in 256: if b.hm[k] - dz == cut.hm[k]: hsame += 1
		var e := {"slot": [tslot.x, tslot.y], "dz": dz, "lokalne": loc, "plny_ms": full_ms, "plny_casti": v2.ms.duplicate(), "otisk_lokalne": h_loc.otisk, "otisk_plny": h_full.otisk, "neshod": d,
			"bilance_lokalne": h_loc.bilance, "bilance_plny": h_full.bilance, "bilance_pred": tot0, "region_lokalne": reg_loc, "region_plny": reg_full,
			"pasma_stejne_vnitrek": same_frac(ug0_in, ug_in), "pasma_stejne_vse": same_frac(ug0_all, ug_all), "povrch_stejny": hsame,
			"udalosti_pred": _ev(ev0), "udalosti_po_lokalne": _ev(ev1), "udalosti_po_vse": _ev(ev_all), "zmenenych_sloupcu_vody": nchg, "plan_neshod": due_bad, "plan_polozek": due_n,
			"prameny_ostrov": v.springs.size(), "souhrn": v.summary()}
		res.vlozeni.append(e)
		print("B slot %s dz %d: lokálně %.0f ms (podzemí %.0f, povrch %.0f), plný %.0f ms; otisk %s / %s neshod %s; bilance chyba %s / %s; okraj %.4f → %.4f l/s" % [tslot, dz, loc.celkem_ms, loc.podzemi_ms, loc.povrch_ms, full_ms, h_loc.otisk, h_full.otisk, str(d), str(h_loc.bilance.chyba_svet), str(h_full.bilance.chyba_svet), float(tot0.okraj), float(h_full.bilance.okraj)])
		print("   výřez na ostrově %s" % str(reg_full))
		print("   pásma stejná jako v původu: vnitřek %.3f, vše %.3f; povrch stejný %d/256" % [e.pasma_stejne_vnitrek, e.pasma_stejne_vse, hsame])
		print("   události před %s | po (jen změněné, %d sloupců vody jinak) %s | po (vše) %s | plán: %d položek, neshod %d" % [str(e.udalosti_pred), nchg, str(e.udalosti_po_lokalne), str(e.udalosti_po_vse), due_n, due_bad])
		v.dispose(); v2.dispose()
	v0.dispose()
	return res

static func _ev(e: Dictionary) -> Dictionary:
	var o := e.duplicate(); o.erase("_mc"); return o

func _init() -> void:
	BlockGen.gen_version = "bp"
	var out := {}
	if "A" in _arg("cast", "A,B"): out.A = part_a()
	if "B" in _arg("cast", "A,B"): out.B = part_b()
	var path := _arg("out", "")
	if path != "": FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	quit()
