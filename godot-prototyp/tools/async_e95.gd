extends SceneTree
## E95: asynchronní voda po kopání (scripts/voda/async95.gd) proti synchronní verzi (jako hra dnes: water_finish, edit,
## kroky R po snímcích). Volby: --rezim=sync|fronta|slouceni, --seq=S1..S5, --cas=virt|real (real = smyčka 60 tiků/s se
## zátěží hlavního vlákna --zatez_ms na snímek), --zpozdeni=N tiků (převzetí výsledku), --okamzite=0|1, --out=cesta.
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const A95 = preload("res://scripts/voda/async95.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const B128 = preload("res://scripts/voda/blok128_voda95.gd")   # --svet=blok128: celý blok 128 m z funkce (256 × 256, bez podzemí)
const TICK_US := 16667

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

var blocks := {}
var terr := PackedFloat64Array()   # blok128: terén v hlavním vlákně (buňky), model vody má vlastní kopii

## posloupnost výkopů [[gi, tick], ...] (tick = kdy hráč kopne)
func _seq(v, name: String) -> Array:
	var cand := []
	for i in v.W * v.H:
		if v.island[i] == 1 and v.level(i) >= 0.0 and i / v.H > 1 and i % v.H > 1 and i / v.H < v.W - 2 and i % v.H < v.H - 2: cand.append(i)
	var spr := []
	for sp in v.springs: cand.append(sp.gi); spr.append(sp.gi)
	var rng := RandomNumberGenerator.new()
	var gis := []; var iv := 120
	match name:
		"S1", "S2", "S4":
			rng.seed = 66
			for k in mini(12, cand.size()): gis.append(cand[rng.randi_range(0, cand.size() - 1)])
			if name == "S2": gis.reverse()
			if name == "S4": gis = gis.slice(0, 6); iv = 1   # dávka: kop každý tik
		"S3":
			rng.seed = 95
			for k in 6: gis.append(cand[rng.randi_range(0, cand.size() - 1)])
			for s in spr: gis.append(s)   # výkopy pramenů (zdroj se zavře / otevře)
			iv = 60
		"B1", "B2":   # blok128: koryta (ne tůně) a suché okraje tůní (výkop může tůň vypustit), kop každé 2 s / dávka každý tik
			rng.seed = 128
			var kor := []; var rim := []
			for i in cand:
				if not v.is_pond(i): kor.append(i)
			for i in v.W * v.H:
				var x: int = i / v.H; var y: int = i % v.H
				if x < 2 or y < 2 or x >= v.W - 2 or y >= v.H - 2 or v.level(i) >= 0.0: continue
				for d in [1, -1, v.H, -v.H]:
					if v.is_pond(i + d): rim.append(i); break
			for k in 6:
				if not kor.is_empty(): gis.append(kor[rng.randi_range(0, kor.size() - 1)])
				if not rim.is_empty(): gis.append(rim[rng.randi_range(0, rim.size() - 1)])
			if name == "B2": gis = gis.slice(0, 6); iv = 1
		"S5":   # výkop během přítoku: další kop dřív, než předchozí výpočet doběhne; stejný sloupec dvakrát
			rng.seed = 5
			var a: int = cand[rng.randi_range(0, cand.size() - 1)]
			var b: int = spr[0] if not spr.is_empty() else a + 1
			gis = [a, a, b, a + 1, b, a + v.H]; iv = 20
	var out := []
	for k in gis.size(): out.append([gis[k], 30 + k * iv])
	return out

func _dig(v, gi: int, dep: int) -> Array:   # změna terénu (hlavní vlákno, hned); vrací [slot, lx, ly, nh]
	if not terr.is_empty():
		var nh0 := maxi(int(terr[gi]) - dep, 1)
		terr[gi] = nh0
		return [Vector2i.ZERO, gi / 256, gi % 256, nh0]
	var a: Array = v.slot_of(gi)
	var b = blocks[a[0]]
	var ci: int = a[1] * 16 + a[2]
	var h0: int = b.hm[ci]
	var nh := maxi(h0 - dep, 1)
	for z in range(nh, h0): b.geo[ci * 64 + z] = 0; b.cells[ci * 64 + z] = 0
	b.hm[ci] = nh
	return [a[0], a[1], a[2], nh]

func _busy(ms: float) -> void:
	var t := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t < int(ms * 1000.0): pass

func _stats(a: Array) -> Dictionary:
	if a.is_empty(): return {}
	var s := a.duplicate(); s.sort()
	var sum := 0.0
	for x in s: sum += x
	return {"n": s.size(), "prumer": snappedf(sum / s.size(), 0.01), "p50": snappedf(s[s.size() / 2], 0.01), "p95": snappedf(s[int(s.size() * 0.95)], 0.01),
		"p99": snappedf(s[int(s.size() * 0.99)], 0.01), "max": snappedf(s[-1], 0.01), "nad_33ms": s.filter(func(x): return x > 33.3).size(), "nad_100ms": s.filter(func(x): return x > 100.0).size()}

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var svet := _arg("svet", "ostrov")
	var v
	var tb0 := Time.get_ticks_usec()
	if svet == "blok128":
		v = B128.z_funkce(int(_arg("pram_max", "16")))
		terr = v.hm.duplicate()
		print("blok128 dlaždice %s: postavení %.0f ms (%s), prameny %d, souhrn %s" % [v.dlazdice, (Time.get_ticks_usec() - tb0) / 1000.0, v.ms, v.springs.size(), v.summary()])
	elif svet.begins_with("ostrov") and svet.length() > 6:   # ostrovNxN: N × N bloků bp (16 sloupců po 0,5 m) s podzemím
		var nb := int(svet.substr(6).split("x")[0])
		T.reset(Vector2i(1, 1), nb + 2)
		var kinds := ["louka", "kopec", "hora", "louka"]
		for bx in nb:
			for by in nb:
				var b := Block.new()
				b.kind = kinds[(bx * 3 + by) % 4]; b.seed = 1000 + bx * 37 + by; b.slot = Vector2i(bx, by)
				BlockGen.build(b, [null, null, null, null])
				T.commit(b)
				blocks[b.slot] = b
		print("ostrov %d×%d bloků: generování %.0f ms" % [nb, nb, (Time.get_ticks_usec() - tb0) / 1000.0])
		v = OV.new()
		v.build(blocks)
	else:
		for e in "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404".split(";"):
			var a := e.split(":"); var xy := a[0].split(",")
			var b := Block.new()
			b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
			BlockGen.build(b, [null, null, null, null])
			T.commit(b)
			blocks[b.slot] = b
		v = OV.new()
		v.build(blocks)
	var rezim := _arg("rezim", "sync"); var seqn := _arg("seq", "S1"); var cas := _arg("cas", "virt")
	var lat := int(_arg("zpozdeni", "30")); var zat := float(_arg("zatez_ms", "8")); var dep := int(_arg("hloubka", "2"))
	var seq := _seq(v, seqn)
	if int(_arg("vykopu", "0")) > 0: seq = seq.slice(0, int(_arg("vykopu", "0")))
	print("E95 režim %s, %s, čas %s, výkopů %d, plný výpočet %.0f ms, otisk %s" % [rezim, seqn, cas, seq.size(), float(v.ms.celkem), H68.otisk(v.st)])
	var out := {"svet": svet, "voda_ms": v.ms, "souhrn": v.summary(), "rezim": rezim, "seq": seqn, "cas": cas, "zpozdeni": lat, "zatez_ms": zat, "vykopy": seq, "cpu": OS.get_processor_count()}
	var frames := []; var digs := []; var otisky := []
	var tick := 0; var di := 0
	var t_start := Time.get_ticks_usec()
	var real := cas == "real"
	if rezim == "sync":
		var cur := {}   # rozpracovaný výkop (kroky R po snímcích)
		while di < seq.size() or v.pending():
			var tf := Time.get_ticks_usec()
			if di < seq.size() and tick >= int(seq[di][1]):
				var tb := Time.get_ticks_usec()
				var fin := 0
				while v.pending(): v.step(); fin += 1   # water_finish (hra před dalším výkopem)
				var tfin := (Time.get_ticks_usec() - tb) / 1000.0
				if not cur.is_empty():
					cur.hotovo_ms = (Time.get_ticks_usec() - int(cur.t_us)) / 1000.0
					if fin > 0 or true: otisky.append(H68.otisk(v.st))
				var d := _dig(v, int(seq[di][0]), dep)
				var r: Dictionary = v.edit(d[0], d[1], d[2], d[3])
				cur = {"gi": seq[di][0], "tick": tick, "t_us": tb, "dokonceni_predchoziho_ms": tfin, "edit_ms": (Time.get_ticks_usec() - tb) / 1000.0 - tfin,
					"blok_hlavni_ms": (Time.get_ticks_usec() - tb) / 1000.0, "r_kroku": 0, "r_max_ms": 0.0}
				digs.append(cur); di += 1
				if not v.pending(): cur.hotovo_ms = cur.blok_hlavni_ms
			elif v.pending():
				var ts := Time.get_ticks_usec()
				v.step()   # voda_r_kroku = 1 krok na snímek
				var sm := (Time.get_ticks_usec() - ts) / 1000.0
				cur.r_kroku += 1; cur.r_max_ms = maxf(cur.r_max_ms, sm)
				if not v.pending(): cur.hotovo_ms = (Time.get_ticks_usec() - int(cur.t_us)) / 1000.0
			if real:
				_busy(zat)
				frames.append((Time.get_ticks_usec() - tf) / 1000.0)
				var nxt := t_start + (tick + 1) * TICK_US
				if Time.get_ticks_usec() < nxt: OS.delay_usec(nxt - Time.get_ticks_usec())
			tick += 1
		otisky.append(H68.otisk(v.st))
		for c in digs: if not c.has("hotovo_ms"): c.hotovo_ms = -1.0
	else:
		var av = A95.new(v, rezim, (1 << 30) if not real and lat >= 0 else lat)
		av.s_otiskem = true
		av.okamzite = _arg("okamzite", "1") == "1"
		var waits := []
		while di < seq.size() or av.busy() or not av._pending.is_empty():
			var tf := Time.get_ticks_usec()
			if di < seq.size() and tick >= int(seq[di][1]):
				var tb := Time.get_ticks_usec()
				var d := _dig(v, int(seq[di][0]), dep)   # hlavní vlákno mění jen bloky (model vody nečte)
				var t2 := Time.get_ticks_usec()
				var id: int = av.submit(tick, d[0], d[1], d[2], d[3])
				var t3 := Time.get_ticks_usec()
				digs.append({"gi": seq[di][0], "tick": tick, "id": id, "blok_hlavni_ms": (t3 - tb) / 1000.0, "submit_ms": (t3 - t2) / 1000.0})
				di += 1
			var tp := Time.get_ticks_usec()
			var pr: Dictionary = av.poll(tick)
			if pr.zmena or pr.ceka_ms > 0.0: waits.append({"tick": tick, "ceka_ms": pr.ceka_ms, "poll_ms": (Time.get_ticks_usec() - tp) / 1000.0, "prevzato": pr.prevzato})
			if not real and di >= seq.size() and not av._pending.is_empty():
				av.finish_all()
			if real:
				_busy(zat)
				frames.append((Time.get_ticks_usec() - tf) / 1000.0)
				var nxt := t_start + (tick + 1) * TICK_US
				if Time.get_ticks_usec() < nxt: OS.delay_usec(nxt - Time.get_ticks_usec())
			tick += 1
		av.finish_all()
		out.pamet_pohled_B = av.front.bytes()
		v = av.stop()
		for z in av.zaznam:
			if String(z.get("otisk", "")) != "": otisky.append(z.otisk)
		out.ulohy = av.zaznam
		out.prevzeti = waits
		otisky.append(H68.otisk(v.st))
	out.digs = digs
	out.otisky = otisky
	out.otisk_konec = H68.otisk(v.st)
	out.neshod_plny = v.check_full()
	out.ticku = tick
	out.celkem_s = (Time.get_ticks_usec() - t_start) / 1e6
	if real: out.snimky = _stats(frames)
	out.blok_hlavni = _stats(digs.map(func(x): return float(x.blok_hlavni_ms)))
	var path := _arg("out", "res://shots/e95/vysledek.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	print("otisk konec %s, neshod %s, blokování hlavního vlákna %s, snímky %s, celkem %.1f s" % [out.otisk_konec, out.neshod_plny, out.blok_hlavni, out.get("snimky", {}), out.celkem_s])
	print("otisky: ", otisky)
	v.dispose()
	quit()
