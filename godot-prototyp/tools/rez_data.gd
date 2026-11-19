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
	var path := _arg("out", "/tmp/rez_data.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out))
	print("rez_data: %d bloků → %s" % [blocks.size(), path])
	quit()
