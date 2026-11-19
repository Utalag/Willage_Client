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

## testovací zdroje podzemí (jako blueprint-studie/tools/e67.gd): místní minima povrchu řídicí mřížky → F.entry, po tělesech
func _minima_calls(c: Dictionary) -> Array:
	var UGF = load("res://scripts/voda/podzemi/ug_funkce.gd")
	var U = load("res://scripts/voda/podzemi/ug58.gd")
	var W: int = c.W; var H: int = c.H
	var r: int = int(c.get("r", 1)); var Ws: int = int(c.get("Ws", W))
	var by := {}
	for cc in W * H:
		if c.wall[cc] == 1: continue
		var x := cc / H; var y := cc % H; var hh: float = c.h[cc]; var low := true; var lower := false
		for d in 4:
			var qx: int = x + [1, -1, 0, 0][d]; var qy: int = y + [0, 0, 1, -1][d]
			if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
			var c2 := qx * H + qy
			if c.wall[c2] == 1: continue
			if float(c.h[c2]) < hh - 1e-9: low = false
			if float(c.h[c2]) > hh + 1e-9: lower = true
		if not (low and lower): continue
		var e: int = UGF.entry(c, (x * r + r / 2) * Ws + y * r + r / 2)
		if e < 0: continue
		var k: int = c.comp[e]
		if not by.has(k): by[k] = PackedInt32Array()
		by[k].append(e)
	var ks := by.keys(); ks.sort()
	var res := []
	var calls := []
	for k in ks:
		var ents: PackedInt32Array = by[k]; ents.sort()
		calls.append({"ents": ents, "q": 0.02 * ents.size(), "excl": {}, "x": [], "ex": {}, "final": true})
	var st := {"exact": 0, "fallback": 0, "skipped": 0}
	for ci in calls.size(): res.append(U._one(c, calls, ci, false, false, false, 0.0625, st))
	return res

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
			if _arg("zdroje", "hra") == "minima":   # ukázka: zdroj v každém místním minimu povrchu (0,02 l/s), seskupené po tělesech
				bodies = _minima_calls(c2)
				out.zdroje = "minima"
			var fill := {}   # sloupec řídicí mřížky → [[lo, top, index hladiny]]
			var film := {}   # E67 pretok: protékající voda (mokrá pásma sestupu) → [[lo, lo + film]]
			var fm := float(c2.get("film67", 0.5))
			var hl := []; var vy := []
			for r in bodies:
				if r.has("pits67"):   # E67: stojatá voda jen v pastech (vana po práh / jezero do výstupu)
					for pt in r.pits67:
						if float(pt.objem_m3) <= 0.0: continue
						var hi_ := hl.size()
						hl.append({"hladina": snappedf(float(pt.hladina), 0.001), "typ": "vana" if String(pt.typ) == "prah" else ("do vystupu" if String(pt.typ) == "vystup" else String(pt.typ)),
							"pasem": int(pt.pasem), "objem_m3": snappedf(float(pt.objem_m3), 0.01)})
						for bb in pt.bands:
							var top := minf(float(c2.hi[bb]), float(pt.hladina))
							if top - float(c2.lo[bb]) <= 0.0001: continue
							var cc0: int = c2.bcol[bb]
							if not fill.has(cc0): fill[cc0] = []
							fill[cc0].append([snappedf(c2.lo[bb], 0.001), snappedf(top, 0.001), hi_])
					for bb in r.wet67:
						var cc1: int = c2.bcol[bb]
						if not film.has(cc1): film[cc1] = []
						film[cc1].append([snappedf(c2.lo[bb], 0.001), snappedf(minf(float(c2.hi[bb]), float(c2.lo[bb]) + fm), 0.001)])
					for o in r.outs67:
						var s7: int = int(o[2])
						var g7 := Vector2i(s7 / v.H, s7 % v.H) - T.OFF * 16
						vy.append([g7.x, g7.y, snappedf(float(o[0]), 0.001), String(o[1]), snappedf(float(o[3]), 0.0001)])
					continue
				var L: float = float(r.z_out)
				var hi2 := hl.size()
				hl.append({"hladina": snappedf(L, 0.001), "typ": "teleso (" + String(r.get("rezim_tel", "")) + ")", "pasem": r.comp_ids.size(), "objem_m3": snappedf(float(r.volume_m3), 0.01)})
				for bb in r.comp_ids:
					var top2 := minf(float(c2.hi[bb]), L)
					if top2 - float(c2.lo[bb]) <= 0.0001: continue
					var cc2: int = c2.bcol[bb]
					if not fill.has(cc2): fill[cc2] = []
					fill[cc2].append([snappedf(c2.lo[bb], 0.001), snappedf(top2, 0.001), hi2])
				if not r.out.is_empty():
					var s_: int = int(r.out[4])
					var g3 := Vector2i(s_ / v.H, s_ % v.H) - T.OFF * 16
					vy.append([g3.x, g3.y, snappedf(float(r.out[0]), 0.001), String(r.out[3]), snappedf(float(r.out_q), 0.0001)])
				tv.append({"hladina": snappedf(L, 0.001), "rezim": String(r.get("rezim_tel", "")), "uzavrene": bool(r.closed)})
			vy.sort_custom(func(a1, b1): return float(a1[4]) > float(b1[4]))
			var gf := {}
			for i in v.W * v.H:
				if v.island[i] == 0: continue
				var cc3: int = UGF.col_of(c2, i)
				var g2 := Vector2i(i / v.H, i % v.H) - T.OFF * 16
				if fill.has(cc3): gw["%d,%d" % [g2.x, g2.y]] = fill[cc3]
				if film.has(cc3): gf["%d,%d" % [g2.x, g2.y]] = film[cc3]
			out.protok_voda = gf; out.hladiny_voda = hl; out.vystupy_voda = vy
			out.rezim_vody = "pretok" if String(c2.get("rezim67", "")) == "pretok" else "auto"
			out.okraj67 = bool(c2.get("okraj67", false))
		out.podzemni_voda = gw; out.telesa_voda = tv
		v.dispose()
	var path := _arg("out", "/tmp/rez_data.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out))
	print("rez_data: %d bloků → %s" % [blocks.size(), path])
	quit()
