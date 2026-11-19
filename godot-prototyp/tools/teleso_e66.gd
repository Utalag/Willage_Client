extends SceneTree
## E66b diagnostika: proč je pod ostrovem jedno velké podzemní těleso. Postaví 4 startovní bloky gen bp (jako hra),
## podzemí ug_funkce.from_world (stejně jako ostrov_voda.gd) a vypíše tělesa: počet, velikost (sloupce, pásma, objem),
## materiály (id, jméno, perm, por) a které bloky / švy těleso spojuje. Mapu a řez největšího tělesa uloží jako JSON
## (shots/66_parita/teleso_e66.json) pro obrázek (tools/teleso_obrazek.py).
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const F = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const UG = preload("res://scripts/voda/podzemi.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const V64 = preload("res://scripts/teren/svet64/voda64.gd")

func _name(m: int) -> String:
	for e in HR.raw().rocks:
		if int(e.id) == m: return String(e.key)
	var names := ["vzduch/dutina", "tráva", "hlína", "písek", "jíl", "vápenec", "žula", "čedič", "měď", "železo", "sníh", "mlha", "ložiskový jíl"]
	return names[m] if m < names.size() else "id %d" % m

func _comps(c: Dictionary, mode: String) -> Dictionary:
	var n: int = c.lo.size(); var H: int = c.H
	var ok := PackedByteArray(); ok.resize(n)
	for b in n:
		var m: int = c.mat[b]
		var on: bool = c.body[b] == 1
		if mode.begins_with("bez_pudy") and (m == 1 or m == 2): on = false
		if mode == "bez_pudy_a_sadrovce" and m == 48: on = false
		if mode.begins_with("jen_") and m != int(mode.substr(4)): on = false
		ok[b] = 1 if on else 0
	var lab := PackedInt32Array(); lab.resize(n)
	var k := 0; var best := {"n": 0, "max_b": 0, "max_c": 0, "max_v": 0.0}
	for b0 in n:
		if ok[b0] == 0 or lab[b0] != 0: continue
		k += 1; lab[b0] = k
		var q := [b0]; var i := 0; var cols := {}; var v := 0.0
		while i < q.size():
			var u: int = q[i]; i += 1
			cols[c.bcol[u]] = true; v += (c.hi[u] - c.lo[u]) * c.A * c.por[u]
			for j in range(c.ns[u], c.ns[u + 1]):
				var w: int = c.nb[j]
				if ok[w] == 0 or lab[w] != 0: continue
				if minf(c.hi[u], c.hi[w]) < maxf(c.lo[u], c.lo[w]) - 1e-6: continue
				if mode == "svy_bloku":
					var cu: int = c.bcol[u]; var cw: int = c.bcol[w]
					if Vector2i(cu / H / 16, cu % H / 16) != Vector2i(cw / H / 16, cw % H / 16): continue
				lab[w] = k; q.append(w)
		if q.size() > best.max_b: best.max_b = q.size(); best.max_c = cols.size(); best.max_v = v
	best.n = k
	return best

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var blocks := {}
	for e in [[Vector2i(0, 0), "louka", 101], [Vector2i(1, 0), "hora", 202], [Vector2i(0, 1), "kopec", 303], [Vector2i(1, 1), "louka", 404]]:
		var b := Block.new(); b.kind = e[1]; b.seed = e[2]; b.slot = e[0]
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	var p := V64.scaled(T.p, 16); p.p52_rezim = "auto"
	var c := F.from_world(T.world, T.fine(blocks), 16, 16, p)
	var tab := VS.table()
	var W: int = c.W; var H: int = c.H
	var n_b: int = c.lo.size()
	var nc: int = c.n_comp
	var size := {}; var vol := {}; var cols := {}; var slots := {}; var mats := {}
	for b in n_b:
		if c.body[b] == 0: continue
		var k: int = c.comp[b]
		size[k] = int(size.get(k, 0)) + 1
		vol[k] = float(vol.get(k, 0.0)) + (c.hi[b] - c.lo[b]) * c.A * c.por[b]
		if not cols.has(k): cols[k] = {}; slots[k] = {}; mats[k] = {}
		var cc: int = c.bcol[b]
		cols[k][cc] = true
		slots[k][T.islot(Vector2i(cc / H / 16, cc % H / 16))] = true
		var m: int = c.mat[b]
		mats[k][m] = float(mats[k].get(m, 0.0)) + (c.hi[b] - c.lo[b])
	var ks := size.keys(); ks.sort_custom(func(a, b): return size[a] > size[b])
	var land := 0
	for i in W * H: if c.wall[i] == 0: land += 1
	print("pásem celkem %d, těles %d, sloupců ostrova %d, ponor_perm %.2f" % [n_b, nc, land, c.perm_min])
	var out := {"n_bands": n_b, "n_comp": nc, "land": land, "bodies": []}
	for i in mini(8, ks.size()):
		var k = ks[i]
		var ml := []
		var mk: Array = mats[k].keys(); mk.sort_custom(func(a, b): return mats[k][a] > mats[k][b])
		for m in mk:
			var e: Array = tab.get(m, [0.0, 0.0])
			ml.append({"id": m, "jmeno": _name(m), "mocnost_m": snappedf(mats[k][m], 0.01), "perm": e[0], "por": (e[1] if e.size() > 1 else 0.0), "kras": UG._soluble(m)})
		var bo := {"comp": k, "pasem": size[k], "sloupcu": cols[k].size(), "objem_m3": snappedf(vol[k], 0.1), "bloky": str(slots[k].keys()), "materialy": ml}
		out.bodies.append(bo)
		print(JSON.stringify(bo))
	# materiály pásem v celém ostrově: mocnost, z toho v tělesech
	var allm := {}
	for b in n_b:
		var m: int = c.mat[b]
		if not allm.has(m): allm[m] = [0.0, 0.0]
		allm[m][0] += c.hi[b] - c.lo[b]
		if c.body[b] == 1: allm[m][1] += c.hi[b] - c.lo[b]
	var al := []
	for m in allm:
		var e: Array = tab.get(m, [0.0, 0.0])
		al.append({"id": m, "jmeno": _name(m), "perm": e[0], "por": (e[1] if e.size() > 1 else 0.0), "m_celkem": snappedf(allm[m][0], 0.1), "m_v_telese": snappedf(allm[m][1], 0.1)})
	al.sort_custom(func(a, b): return a.m_celkem > b.m_celkem)
	out.materialy = al
	for e in al: print("  mat ", JSON.stringify(e))
	# mapa: comp největšího tělesa na sloupec (nejvyšší pásmo), řez y = střed ostrova (x přes ostrov): pásma s materiálem a příznakem
	var big = ks[0] if not ks.is_empty() else -1
	var mapa := []
	for gx in W:
		var row := []
		for gy in H:
			var gi := gx * H + gy
			var v := -1
			if c.wall[gi] == 0:
				v = 0
				for b in range(c.cs[gi], c.cs[gi + 1]):
					if c.body[b] == 1: v = 2 if c.comp[b] == big else maxi(v, 1)
			row.append(v)
		mapa.append(row)
	out.mapa = mapa
	var rezy := {}
	for gyl in [T.OFF.y * 16 + 8, T.OFF.y * 16 + 24]:
		var rez := []
		for gx in W:
			var gi: int = gx * H + gyl
			var lst := []
			for b in range(c.cs[gi], c.cs[gi + 1]):
				lst.append([c.lo[b], c.hi[b], c.mat[b], c.body[b], 1 if (c.body[b] == 1 and c.comp[b] == big) else 0])
			rez.append({"h": c.h[gi], "wall": c.wall[gi], "b": lst})
		rezy[str(gyl)] = rez
	out.rezy = rezy
	out.off = [T.OFF.x * 16, T.OFF.y * 16]
	# kontrola artefaktů: třída hry vs plné id v blocích (kolik buněk nese plné id propustné horniny pod jinou třídou)
	var cls := {}
	for s in blocks:
		var b = blocks[s]
		for i in b.geo.size():
			var g: int = b.geo[i]
			if g == 0: continue
			var e: Array = tab.get(g, [0.0, 0.0])
			if e[0] >= c.perm_min or UG._soluble(g):
				var key := "%s→%d" % [_name(g), b.cells[i]]
				cls[key] = int(cls.get(key, 0)) + 1
	out.propustne_bunky_trida = cls
	print("propustné buňky (plné id → třída hry): ", cls)
	# pokusy (jen počítání souvislosti, výpočet vody se nemění): bez půdy (tráva 1, topsoil 2), bez sádrovce s perm 0, řez po švech bloků
	out.pokusy = {}
	for nm in ["vse", "bez_pudy", "bez_pudy_a_sadrovce", "svy_bloku", "jen_52", "jen_5", "jen_44", "jen_3", "jen_2", "jen_1"]:
		var r := _comps(c, nm)
		out.pokusy[nm] = r
		print("pokus %s: těles %d, největší %d pásem / %d sloupců (%.0f %% ostrova), objem %.1f m3" % [nm, r.n, r.max_b, r.max_c, 100.0 * r.max_c / land, r.max_v])
	FileAccess.open(ProjectSettings.globalize_path("res://shots/66_parita/teleso_e66.json"), FileAccess.WRITE).store_string(JSON.stringify(out))
	c.clear()
	quit()
