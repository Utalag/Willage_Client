extends SceneTree
## E75: syntetický test krasu (scripts/kras75/kras75.gd). Mísa s tůní jako tools/e68.gd, ale těleso je VÁPENEC (mat 5,
## cave_limestone) pod polopropustnou krycí vrstvou; tůň odtéká do vápence, pramen u komínu na svahu. Kras: rychlosti
## po pásmech hlavní cesty, události do --udalosti, po každé zpětná vazba (pórovitost, propustnost dutiny) a LOKÁLNÍ
## přepočet (E68 update kolem vstupů a výstupů) proti čerstvému plnému výpočtu (nový kontext + stejný stav krasu).
## Výkopy v čase 0 ve dvou pořadích → otisk krasu a vody. Volby: --zdroj=0.1 --pit_q=0.07 --udalosti=8 --hornina=5 --ponor=0.3 --ladit=0 --nic=0
## --rezim=auto,pretok --bp.<klíč>=hodnota --out=cesta
const PR = preload("res://scripts/bp/params.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const H68 = preload("res://scripts/hydro68/hydro68.gd")
const K75 = preload("res://scripts/kras75/kras75.gd")
const M0 := 9300   # nepropustná
const MC := 9302   # polopropustná krycí vrstva (pod ponor_perm)
const CH = preload("res://scripts/voda/cas_hry.gd")   # sloučení E75 + E77: čas hry na jednom místě
const DEN := CH.DEN_S
var pcas := {}   # parametry pro převod na reálný čas (p71_cas)
var MS := 5

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

static func bp_args(p: Dictionary) -> Dictionary:
	var a := PackedStringArray()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--bp."): a.append("--" + s.substr(5))
	return PR.apply_args(p, a)

func _terrain(W: int) -> PackedFloat64Array:
	var m := W / 2; var hm := PackedFloat64Array(); hm.resize(W * W)
	var hx := m; var hy := m - 4
	for x in W:
		for y in W:
			var r := sqrt(float((x - m) * (x - m) + (y - m) * (y - m)))
			var h := 10.0 + 0.4 * r if r <= 5.0 else 12.0 - 0.3 * (r - 5.0)
			var d := sqrt(float((x - hx) * (x - hx) + (y - hy) * (y - hy)))
			h += 4.0 * maxf(0.0, 1.0 - d / 2.5)
			hm[x * W + y] = snappedf(h, 0.01)
	return hm

func _build(W: int, p: Dictionary, zdroj: float, pit_q: float, digs: Array) -> Dictionary:
	var t := VS.table()
	t[M0] = [0.0, 0.0, 1.0, 0.0]; t[MC] = [0.2, 0.3, 1.0, 0.0]
	var m := W / 2; var hm := _terrain(W); var n := W * W
	var pipe := m * W + (m - 3)
	var c := F._new(W, W, 1.0, p)
	var mats := PackedInt32Array(); mats.resize(n)
	for x in W:
		for y in W:
			var gi := x * W + y
			var r := sqrt(float((x - m) * (x - m) + (y - m) * (y - m)))
			var h: float = hm[gi]
			var lst := []
			if x == 0 or y == 0 or x == W - 1 or y == W - 1: lst = [[0.0, h, M0]]
			elif gi == pipe: lst = [[0.0, 2.0, M0], [2.0, h, MS]]
			else: lst = [[0.0, 2.0, M0], [2.0, 8.0, MS], [8.0, h, MC if r <= 5.0 else M0]]
			c.wall[gi] = 0; c.h[gi] = h; c.cols[gi] = lst
			mats[gi] = MC if r <= 5.0 else M0
	F._finish(c)
	F.set_surface(c, W, PackedFloat64Array(), c.wall, 1.0)
	c.impl = F
	var src := PackedFloat64Array(); src.resize(n)
	src[(m - 1) * W + (m - 2)] = zdroj
	var L := TOK.losses(p, true); L.pit_q = pit_q
	var wall := PackedByteArray(); wall.resize(n)
	var st := TOK.make(hm, W, W, wall, mats, src, L, true)
	st.ug = c
	for d in digs:   # výkop: povrch i podzemí (stejně jako ostrov_voda.edit + F.touched)
		st.hm[int(d[0])] = float(d[1])
		F.touched(c, {}, PackedInt32Array([int(d[0])]), PackedFloat64Array([float(d[1])]))
	return st

func _full(st: Dictionary) -> void:
	H68.full(st, 200, 1e-9, true, bool(st.get("_acc", true)))

func _local(st: Dictionary) -> void:
	st.ug_cache = {}
	var ch := PackedInt32Array(); var hh := PackedFloat64Array(); var seen := {}
	for u in st.get("under", []):
		for k in ["from", "exit"]:
			var i: int = int(u[k])
			if i >= 0 and not seen.has(i): seen[i] = true; ch.append(i); hh.append(st.hm[i])
	H68.update(st, ch, hh, st.src, 3, 200, 1e-9, true, true)

func _run(W: int, p: Dictionary, zdroj: float, pit_q: float, digs: Array, nev: int) -> Dictionary:
	var st := _build(W, p, zdroj, pit_q, digs)
	var t0 := Time.get_ticks_usec()
	_full(st)
	var full_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var K := K75.make(p)
	if _arg("ladit", "0") == "1":
		for r in st.ug_bodies: print("ladit těleso entries %s out %s z_out %s q_in %s cesta %s" % [str(r.get("entries")), str(r.get("out")), str(r.get("z_out")), str(r.q_in), str(K75._path(st.ug, Array(r.get("entries", [])), int(r.out[2]) if not Array(r.get("out", [])).is_empty() else -1, float(r.z_out)))])
	K75.rates(st.ug, st.ug_bodies, K)
	var tot := 0.0; var pm := {}
	for b in K.rate:
		tot += float(K.rate[b]); var mk := str(K.mat[b])
		pm[mk] = float(pm.get(mk, 0.0)) + float(K.rate[b])
	var q := 0.0
	for r in st.ug_bodies: q += float(r.q_in)
	var ne := K75.next_event(K)
	var out := {"plny_ms": full_ms, "prutok_l_s": q, "pasem": K.rate.size(), "rychlost_m3_s": tot, "m3_za_den": tot * DEN, "max_m3_s": q * 0.001 * float(K75.sol().get(MS, 0.0)),
		"po_materialech": pm, "prvni_dni": float(ne[0]) / DEN, "prvni_min_realne": CH.realne_min(float(ne[0]), pcas), "rates_ms": K.stats.rates_ms, "udalosti": []}
	var bad := 0; var bad_tol := 0
	for k in nev:
		var ev := K75.next_event(K)
		if int(ev[1]) < 0: break
		K75.advance(K, float(ev[0])); K75.fire(K, int(ev[1]))
		var t1 := Time.get_ticks_usec()
		if _arg("nic", "0") != "1": K75.apply(st.ug, K)
		_local(st)
		K75.rates(st.ug, st.ug_bodies, K)
		var lms := (Time.get_ticks_usec() - t1) / 1000.0
		# čerstvý plný výpočet se stejným stavem krasu
		var s2 := _build(W, p, zdroj, pit_q, digs)
		if _arg("nic", "0") != "1": K75.apply(s2.ug, K)
		var t2 := Time.get_ticks_usec()
		_full(s2)
		var fms := (Time.get_ticks_usec() - t2) / 1000.0
		var same := H68.otisk(st) == H68.otisk(s2)
		if _arg("ladit", "0") == "1":
			var md := 0.0; var nd := 0
			for i in st.fill.size():
				var dd: float = absf(st.fill[i] - s2.fill[i]); if dd > 0.0: nd += 1; md = maxf(md, dd)
			var nt := 0
			for i in st.to.size(): if st.to[i] != s2.to[i]: nt += 1
			var ua := []; var ub := []
			for u in st.under: ua.append([u.from, u.exit, snappedf(u.q, 1e-9), String(u.typ)])
			for u in s2.under: ub.append([u.from, u.exit, snappedf(u.q, 1e-9), String(u.typ)])
			for kk in ["eff", "extra", "src2"]:
				var m2 := 0.0; var n2 := 0
				for i in st[kk].size():
					var d3: float = absf(st[kk][i] - s2[kk][i]); if d3 > 0.0: n2 += 1; m2 = maxf(m2, d3)
				print("ladit %s: rozdílů %d max %s" % [kk, n2, String.num_scientific(m2)])
			for j in mini(st.under.size(), s2.under.size()): print("ladit under q %s z %s" % [str(st.under[j].q - s2.under[j].q), str(st.under[j].z - s2.under[j].z)])
			print("ladit: fill rozdílů %d max %s, to rozdílů %d, under lok %s plný %s" % [nd, str(md), nt, str(ua), str(ub)])
		var dmax := 0.0
		for kk in ["fill", "eff", "extra", "src2"]:
			for i in st[kk].size(): dmax = maxf(dmax, absf(st[kk][i] - s2[kk][i]))
		if st.under.size() != s2.under.size() or st.to != s2.to: dmax = INF
		else:
			for j in st.under.size(): dmax = maxf(dmax, absf(float(st.under[j].q) - float(s2.under[j].q)))
		if not same: bad += 1
		if dmax > 1e-12: bad_tol += 1
		var b := H68.bilance(st)
		out.udalosti.append({"dni": float(ev[0]) / DEN, "min_realne": CH.realne_min(float(ev[0]), pcas), "pasmo": int(ev[1]), "dutina_m3": float(K.dut[int(ev[1])]),
			"lokalne_ms": lms, "max_rozdil": dmax, "plny_ms": fms, "shoda": same, "chyba": b.chyba_svet, "prameny": b.prameny_z_podzemi, "objem_m3": float(st.ug_bodies[0].volume_m3) if not st.ug_bodies.is_empty() else 0.0})
		s2.ug.clear(); s2.clear()
	out.neshod = bad; out.neshod_1e12 = bad_tol; out.otisk_kras = K75.otisk(K); out.otisk_voda = H68.otisk(st)
	var dts := {}
	for b in K.dut: dts[str(b)] = {"m3": K.dut[b], "bunek": K75.cells(K, b).size(), "vrsek_m": K.ztop.get(b, 0.0)}
	out.dutiny = dts
	st.ug.clear(); st.clear()
	return out

func _init() -> void:
	var W := 15; var zdroj := float(_arg("zdroj", "0.1")); var pit_q := float(_arg("pit_q", "0.07")); var nev := int(_arg("udalosti", "8"))
	MS = int(_arg("hornina", "5"))
	var m := W / 2
	var digs := [[(m + 1) * W + m, 9.0], [m * W + (m + 1), 9.2]]   # dva výkopy v tůni
	var res := {}
	for rz in _arg("rezim", "auto,pretok").split(","):
		var p := PR.defaults()
		p.p52_rezim = "auto"; p.ponor_perm = float(_arg("ponor", "0.3"))
		if rz == "pretok": p.p67_rezim = "pretok"
		p = bp_args(p)
		pcas = p
		var a := _run(W, p, zdroj, pit_q, [], nev)
		var d1 := _run(W, p, zdroj, pit_q, digs, 2)
		var rd := digs.duplicate(); rd.reverse()
		var d2 := _run(W, p, zdroj, pit_q, rd, 2)
		res[rz] = {"bez_vykopu": a, "vykopy": d1, "vykopy_obracene": d2, "poradi_stejny_otisk": d1.otisk_kras == d2.otisk_kras and d1.otisk_voda == d2.otisk_voda}
		print("%s: průtok %.4f l/s, pásem %d, rozpouštění %s m³/s (%s m³/den, strop Q·s %s), první dutina den %.2f (%.0f min reálně), rychlosti %.2f ms, plný %.0f ms" % [rz, a.prutok_l_s, a.pasem, str(a.rychlost_m3_s), str(a.m3_za_den), str(a.max_m3_s), a.prvni_dni, a.prvni_min_realne, a.rates_ms, a.plny_ms])
		for e in a.udalosti: print("   den %.2f (%.0f min) pásmo %d dutina %.4f m³ | lokálně %.0f ms, plný %.0f ms, shoda %s (max rozdíl %s), chyba %s, prameny %.4f, objem %.3f" % [e.dni, e.min_realne, e.pasmo, e.dutina_m3, e.lokalne_ms, e.plny_ms, e.shoda, String.num_scientific(e.max_rozdil), str(e.chyba), e.prameny, e.objem_m3])
		print("   neshod přesně %d, nad 1e-12 %d, otisk krasu %s, výkopy obě pořadí stejné: %s (%s / %s)" % [a.neshod, a.neshod_1e12, a.otisk_kras, res[rz].poradi_stejny_otisk, d1.otisk_kras, d2.otisk_kras])
	FileAccess.open(_arg("out", "res://shots/e75/kras.json"), FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	quit()
