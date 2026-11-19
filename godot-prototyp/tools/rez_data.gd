extends SceneTree
## Data pro řezy (tools/rez_gif.sh): vygeneruje bloky gen bp jako hra (bez scény, bez GPU) a uloží plná id buněk,
## výšky, paletu a české názvy materiálů a volitelně podzemní tělesa (ug_funkce, stejně jako voda ve hře) do JSON.
## Volby: --bloky="x,y:typ:seed;..." (výchozí startovní ostrov), --podzemi=0|1, --out=cesta.json, --bp.<param>=hodnota.
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Mat = preload("res://scripts/mat.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const HT = preload("res://scripts/teren/hostitele.gd")
const F = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const V64 = preload("res://scripts/teren/svet64/voda64.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var blocks := {}
	var out := {"bloky": [], "nazvy": {}, "barvy": {}}
	for e in _arg("bloky", "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404").split(";"):
		var a := e.split(":")
		var xy := a[0].split(",")
		var b := Block.new()
		b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null])
		T.commit(b)
		blocks[b.slot] = b
		out.bloky.append({"slot": [b.slot.x, b.slot.y], "typ": b.kind, "seed": b.seed, "geo": Marshalls.raw_to_base64(b.geo), "hm": Array(b.hm)})
	# paleta a názvy: horniny (data/teren/poradi_hornin.json), minerály (mineraly_hostitele.json), základní id 0–12 z Mat
	var pal := HR.palette()
	for m in Mat.COUNT:
		if pal[m].a == 0.0: pal[m] = Mat.COLORS[m]
		out.nazvy[str(m)] = Mat.NAMES[m]
	for e in HR.raw().rocks:
		if e.kind != "air": out.nazvy[str(int(e.id))] = String(e.name)
	var tab := HT.table()
	for m in tab: out.nazvy[str(int(m))] = String(tab[m].label)
	out.nazvy["0"] = "vzduch / dutina"; out.nazvy["250"] = "dutina s vodou"
	pal[250] = Color(0.2, 0.45, 0.95)
	for i in 256:
		if pal[i].a > 0.0: out.barvy[str(i)] = pal[i].to_html(false)
	# podzemí: pásma těles po sloupcích [spodek m, vršek m, těleso]; největší těleso zvlášť
	if _arg("podzemi", "1") == "1":
		var p := V64.scaled(T.p, 16); p.p52_rezim = "auto"
		var c := F.from_world(T.world, T.fine(blocks), 16, 16, p)
		var size := {}
		for b in c.lo.size():
			if c.body[b] == 1: size[c.comp[b]] = int(size.get(c.comp[b], 0)) + 1
		var big := -1
		for k in size: if big < 0 or size[k] > size[big]: big = k
		var cols := {}
		var H: int = c.H
		for b in c.lo.size():
			if c.body[b] == 0: continue
			var cc: int = c.bcol[b]
			var g := Vector2i(cc / H, cc % H) - T.OFF * 16
			var key := "%d,%d" % [g.x, g.y]
			if not cols.has(key): cols[key] = []
			cols[key].append([snappedf(c.lo[b], 0.001), snappedf(c.hi[b], 0.001), 1 if c.comp[b] == big else 2])
		var VS = load("res://scripts/voda/voda_svet.gd"); var UG = load("res://scripts/voda/podzemi.gd")
		var bm := []
		for m in 256:
			var e: Array = VS.table().get(m, [0.0, 0.0])
			if m == 0 or UG._soluble(m) or float(e[0]) >= float(p.ponor_perm): bm.append(m)
		out.telesove_mat = bm
		out.podzemi = {"sloupce": cols, "teles": c.n_comp, "nejvetsi_pasem": size.get(big, 0)}
		c.clear()
	# voda (volitelně, --voda=1): hladina po sloupcích ostrova z ostrov_voda.gd (stejný výpočet jako ve hře)
	if _arg("voda", "0") == "1":
		var OV = load("res://scripts/voda/ostrov_voda.gd")
		var v = OV.new()
		v.build(blocks)
		var wv := {}
		for i in v.W * v.H:
			if v.island[i] == 0: continue
			var lv: float = v.level(i)
			if lv < 0.0: continue
			var g := Vector2i(i / v.H, i % v.H) - T.OFF * 16
			wv["%d,%d" % [g.x, g.y]] = [snappedf(lv, 0.001), 1 if v.is_pond(i) else 0]
		out.voda = wv
		# podzemní voda ze stavu řešiče podzemí (tok60 st.ug_bodies po doběhnutí kroků R): každé těleso, do kterého teče voda
		# z tůní, má hladinu z_out a výstup (pramen na povrchu / okraj ostrova); výplň = pásma tělesa od spodku po hladinu
		var gw := {}; var tv := []
		if not v.ug.is_empty():
			var n_st := 0
			while v.pending() and n_st < 10000:
				v.step(); n_st += 1
			var UGF = load("res://scripts/voda/podzemi/ug_funkce.gd")
			var c2: Dictionary = v.ug
			var bodies: Array = v.st.get("ug_bodies", [])
			var fill := {}   # sloupec řídicí mřížky → [[lo, top, index tělesa]]
			for bi in bodies.size():
				var r: Dictionary = bodies[bi]
				var L: float = float(r.z_out)
				for b in r.comp_ids:
					var top := minf(float(c2.hi[b]), L)
					if top - float(c2.lo[b]) <= 0.0001: continue
					var cc: int = c2.bcol[b]
					if not fill.has(cc): fill[cc] = []
					fill[cc].append([snappedf(c2.lo[b], 0.001), snappedf(top, 0.001), bi])
				var o := {"hladina": snappedf(L, 0.001), "uzavrene": bool(r.closed), "nenaplni": bool(r.never_fills),
					"q_in": snappedf(float(r.q_in), 0.0001), "out_q": snappedf(float(r.out_q), 0.0001), "objem_m3": snappedf(float(r.volume_m3), 0.1),
					"pasem": r.comp_ids.size(), "typ": "", "vystup": [], "rezim": String(r.get("rezim_tel", "")),
					"prusak_q": snappedf(float(r.leak), 0.0001)}
				if not r.out.is_empty():
					var s_: int = int(r.out[4])
					var g3 := Vector2i(s_ / v.H, s_ % v.H) - T.OFF * 16
					o.typ = String(r.out[3]); o.vystup = [g3.x, g3.y, snappedf(float(r.out[0]), 0.001)]
				tv.append(o)
			for i in v.W * v.H:
				if v.island[i] == 0: continue
				var cc2: int = UGF.col_of(c2, i)
				if not fill.has(cc2): continue
				var g2 := Vector2i(i / v.H, i % v.H) - T.OFF * 16
				gw["%d,%d" % [g2.x, g2.y]] = fill[cc2]
		out.podzemni_voda = gw; out.telesa_voda = tv
		v.dispose()
	var path := _arg("out", "/tmp/rez_data.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out))
	print("rez_data: %d bloků → %s" % [blocks.size(), path])
	quit()
