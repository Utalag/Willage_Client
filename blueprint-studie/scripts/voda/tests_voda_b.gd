extends RefCounted
## E47b měření: strže ~2 m (stream power), ponory, vodopády; voda před a po. → shots/bench_voda_b.txt, shots/voda_eroze_b.json

const T = preload("res://scripts/bp/tests_horniny.gd")
const MT = preload("res://scripts/bp/metrics.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const ES = preload("res://scripts/voda/eroze_svet.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const TV = preload("res://scripts/voda/tests_voda.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const UG = preload("res://scripts/voda/podzemi.gd")

static func _name(m: int) -> String:
	for e in HR.raw().rocks:
		if int(e.id) == m: return e.name
	return ["vzduch", "tráva", "hlína", "písek", "jíl"][m] if m < 5 else str(m)

static func _pct(a: Array, q: float) -> float:
	if a.is_empty(): return 0.0
	var b := a.duplicate(); b.sort()
	return float(b[clampi(int(q * (b.size() - 1)), 0, b.size() - 1)])

static func run_b(p0: Dictionary, out_txt: String, out_json: String) -> PackedStringArray:
	var p: Dictionary = p0.duplicate(); p.voda_zdroj = "plocha"
	var L := PackedStringArray()
	var t0 := Time.get_ticks_usec()
	var w0 = T.build(p)
	L.append("# E47b strže, ponory, vodopády (%s)" % Time.get_datetime_string_from_system())
	var wat0 := VS.run(w0, p)
	L.append(TV.fmt_w("voda před", wat0))
	var er := ES.run(w0, p, "strze")
	var w1 = er.world; var st: Dictionary = er.rep; var sz: Dictionary = st.strze
	var GH: int = w1.h * 16
	# hloubky koryt
	var dep := []; var bycls := {"měkké (k 1,2–1,3)": [], "sedimenty (k 1,0)": [], "tvrdé (k ≤ 0,7)": []}
	var nch := 0
	for i in sz.chan.size():
		if sz.chan[i] == 0: continue
		nch += 1
		var dm: float = sz.depth[i] * 0.5
		dep.append(dm)
		var k := SZ.erod(sz.mats[i])
		bycls["měkké (k 1,2–1,3)" if k >= 1.2 else ("sedimenty (k 1,0)" if k >= 1.0 else "tvrdé (k ≤ 0,7)")].append(dm)
	L.append("koryta: %d sloupců (%.1f %%), K %.3f | hloubka medián %.2f m, p10 %.2f, p90 %.2f, max %.2f m" % [nch, 100.0 * nch / (w1.order.size() * 256), sz.K, _pct(dep, 0.5), _pct(dep, 0.1), _pct(dep, 0.9), _pct(dep, 1.0)])
	for c in bycls:
		var a: Array = bycls[c]
		L.append("  %s: %d sloupců, medián %.2f m, p90 %.2f m" % [c, a.size(), _pct(a, 0.5), _pct(a, 0.9)])
	# ponory
	var sinks := PackedInt32Array(); var sm := {}; var ss := {}
	for i in sz.sink.size():
		if sz.sink[i] > 0:
			sinks.append(i)
			var nm := _name(sz.mats[i]); sm[nm] = sm.get(nm, 0) + 1
			var sl: Vector2i = Vector2i(i / GH / 16, (i % GH) / 16); var sh: String = w1.slots[sl].bp.shape
			ss[sh] = ss.get(sh, 0) + 1
	L.append("  z toho krasové ponory %d, ostatní = konec ztrácejícího se toku v propustné hornině" % sz.n_karst)
	L.insert(L.size() - 1, "")
	L.append("ponory: %d sloupců, pohlceno %.0f z %.0f sloupců průtoku | hornina: %s | bloky: %s" % [sinks.size(), sz.lost, float(w1.order.size() * 256),
		", ".join(sm.keys().map(func(k): return "%s %d" % [k, sm[k]])), ", ".join(ss.keys().map(func(k): return "%s %d" % [k, ss[k]]))])
	# vodopády
	var fd := []; var fs := {}
	for f in sz.falls:
		fd.append(f.drop_m)
		var sl: Vector2i = Vector2i(f.top / GH / 16, (f.top % GH) / 16); var sh: String = w1.slots[sl].bp.shape
		fs[sh] = fs.get(sh, 0) + 1
	L.append("vodopády (spád ≥ %.1f m): %d, výška medián %.2f m, max %.2f m | bloky: %s | tůň max %.2f m" % [float(p.vodopad_m), fd.size(), _pct(fd, 0.5), _pct(fd, 1.0),
		", ".join(fs.keys().map(func(k): return "%s %d" % [k, fs[k]])), sz.plunge_max * 0.5])
	for th in [1.0, 2.0, 3.0]:
		var q: Dictionary = p.duplicate(); q.vodopad_m = th
		var e2 := ES.run(w0, q, "strze")
		L.append("  citlivost: vodopad_m %.1f → %d vodopádů" % [th, e2.rep.strze.falls.size()])
	for pi in [0.0, 0.25, 0.5, 1.5]:
		var q: Dictionary = p.duplicate(); q.ponor_inf = pi
		var z2: Dictionary = ES.run(w0, q, "strze").rep.strze
		var nc := 0; var mx := 0.0
		for i in z2.chan.size():
			if z2.chan[i] == 1: nc += 1; mx = maxf(mx, z2.eff[i])
		L.append("  citlivost: ponor_inf %.2f → koryt %d sloupců, ponorů %d (kras %d), max průtok %.0f sloupců" % [pi, nc, Array(z2.sink).count(1) + Array(z2.sink).count(2), z2.n_karst, mx])
	var ex := TV.exposure(w0, w1, p)
	var s1 := TV.surf_seam(w1)
	var ids := HR.pool(p).map(func(e): return int(e.id))
	var m1 := MT.seams(w1.slots, "hm", ids, T.ignore(p))
	L.append("eroze strze: změna povrchu průměr %.2f U, max odběr %.2f U | šev povrchu %.2f (max %.2f, uvnitř %.2f), zlom %.2f (uvnitř %.2f) | švy vrstev %.2f (uvnitř %.2f) | jiný materiál navrchu %.0f %%, odkrytá vrstva %.0f %% | odneseno minerálů %d | strže %.0f ms, převzorkování %.0f ms" % [
		st.mean_change, st.max_cut, s1.seam, s1.seam_max, s1.inner, s1.kink, s1.kink_inner, MT.mean_seam(m1), MT.mean_inner(m1), ex.changed * 100, ex.layer * 100, st.minerals_lost, sz.ms, st.ms_resample])
	var wat1 := VS.run(w1, p, sinks)
	L.append(TV.fmt_w("voda po (strze, ponory)", wat1) + ", pohltily ponory %.0f buněk" % wat1.ponor)
	var wat2 := VS.run(w1, p)
	L.append(TV.fmt_w("voda po (strze, bez ponorů)", wat2))
	var a = ES.run(w0, p, "strze").world; var b = ES.run(w0, p, "strze").world
	L.append("determinismus 2×: %s / %s → %s" % [a.hash().left(12), b.hash().left(12), "STEJNÉ" if a.hash() == b.hash() else "RŮZNÉ!"])
	L.append("celkem %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	FileAccess.open(out_txt, FileAccess.WRITE).store_string("\n".join(L) + "\n")
	var data := {"before": TV.dump_world(w0, wat0), "after": TV.dump_world(w1, wat1), "pal": Array(HR.palette()).map(func(c): return c.to_html(false)),
		"chan": Array(sz.chan), "sink": Array(sz.sink), "depth": Array(sz.depth), "acc": Array(sz.eff),
		"falls": sz.falls.map(func(f): return [f.top, f.foot, f.drop_m]), "slots": w0.order.map(func(s): return [s.x, s.y, w0.slots[s].bp.shape])}
	FileAccess.open(out_json, FileAccess.WRITE).store_string(JSON.stringify(data))
	return L


static func _grid_hm(w) -> PackedFloat64Array:
	var GH: int = w.h * 16
	var g := PackedFloat64Array(); g.resize(w.w * 16 * GH)
	for s in w.order:
		var r: Dictionary = w.slots[s]
		for i in 256: g[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16] = r.hm_f[i]
	return g

static func _cmp(a: Dictionary, b: Dictionary) -> Dictionary:
	var md := 0.0; var inter := 0; var uni := 0; var ea := 0.0; var eb := 0.0
	for i in a.eff.size():
		md = maxf(md, absf(a.eff[i] - b.eff[i]))
		var wa: bool = a.eff[i] > 0.0; var wb: bool = b.eff[i] > 0.0
		if wa and wb: inter += 1
		if wa or wb: uni += 1
	for f in TOK.edge_falls(a): ea += f.q
	for f in TOK.edge_falls(b): eb += f.q
	for u in a.under: ea += u.q if u.typ == "okraj" else 0.0
	for u in b.under: eb += u.q if u.typ == "okraj" else 0.0
	return {"max": md, "jac": float(inter) / maxf(uni, 1), "edge_a": ea, "edge_b": eb}

static func _full(st: Dictionary) -> Dictionary:
	var f := TOK.make(st.hm.duplicate(), st.W, st.H, st.wall, st.mats, st.src.duplicate(), st.L, st.edge_out)
	if st.get("ug") != null: f.ug = st.ug   # bez mezipaměti těles → plný výpočet i podzemí
	var r := TOK.route(f); f.ms_full = r.ms
	return f

static func _demo(L: PackedStringArray, st: Dictionary, name: String, ch: PackedInt32Array, hv: PackedFloat64Array, springs: Array, p: Dictionary) -> Dictionary:
	var hm2: PackedFloat64Array = st.hm.duplicate()
	for k in ch.size(): hm2[ch[k]] = hv[k]
	var q := PRM.src(springs, hm2, hm2.size())
	var u := TOK.update(st, ch, hv, q, int(p.tok_margin))
	var f := _full(st)
	var c := _cmp(st, f)
	var act := springs.filter(func(s): return s.aktivni).size()
	L.append("  %s: změněno %d sloupců → %s, okno %d, dotčeno %d z %d sloupců (rozšíření okna %d×), %.1f ms (plný přepočet %.1f ms) | aktivní prameny %d/%d | přes okraj vč. podzemí %.2f l/s (plný %.2f) | vs plný: max rozdíl průtoku %.3f l/s, shoda mokrých sloupců %.0f %%" % [
		name, ch.size(), "SUCHO, nic se nesimuluje" if u.dry else "přepočet", u.window, u.touched, st.W * st.H, u.expanded, u.ms, f.ms_full, act, springs.size(), c.edge_a, c.edge_b, c.max, c.jac * 100])
	return u

static func run_all(p: Dictionary, out_txt: String, out_json: String) -> PackedStringArray:
	var L := PackedStringArray()
	var t0 := Time.get_ticks_usec()
	var w0 = T.build(p)
	L.append("# E47c voda jen z pramenů, strže, ponory, vodopády, okraj ostrova, lokální přepočet, plnění tůní (%s)" % Time.get_datetime_string_from_system())
	var er := ES.run(w0, p, "strze")
	var w1 = er.world; var st: Dictionary = er.rep; var sz: Dictionary = st.strze
	var W: int = w1.w * 16; var GH: int = w1.h * 16
	var springs: Array = sz.springs
	var qs := 0.0; var kinds := {}
	for s in springs: qs += s.q; kinds[s.druh] = kinds.get(s.druh, 0) + 1
	L.append("prameny: %d (%s), celkem %.1f l/s; déšť jen vizuální (0 l/s)" % [springs.size(), ", ".join(kinds.keys().map(func(k): return "%s %d" % [k, kinds[k]])), qs])
	for s in springs: L.append("  %s (%d, %d) z %d U, %.1f l/s, hornina 2 m pod povrchem: %s" % [s.druh, s.gi / GH, s.gi % GH, s.z, s.q, _name(sz.mats[s.gi])])
	var dep := []; var nch := 0; var wet := 0
	for i in sz.chan.size():
		if sz.eff[i] > 0.0: wet += 1
		if sz.chan[i] == 1: nch += 1; dep.append(sz.depth[i] * 0.5)
	L.append("tok: mokrých sloupců %d (%.1f %%), z toho zahloubené koryto %d | hloubka strže medián %.2f m, p10 %.2f, p90 %.2f, max %.2f m" % [wet, 100.0 * wet / (w1.order.size() * 256), nch, _pct(dep, 0.5), _pct(dep, 0.1), _pct(dep, 0.9), _pct(dep, 1.0)])
	var ns := 0
	for i in sz.sink.size(): if sz.sink[i] > 0: ns += 1
	L.append("ponory: %d (kras %d), pohltily %.2f l/s" % [ns, sz.n_karst, sz.lost])
	var fd := []
	for f in sz.falls: fd.append(f.drop_m)
	L.append("vodopády ve strži (spád ≥ %.1f m): %d, výška medián %.2f m, max %.2f m, tůň pod nimi max %.2f m" % [float(p.vodopad_m), fd.size(), _pct(fd, 0.5), _pct(fd, 1.0), sz.plunge_max * 0.5])
	var eq := 0.0
	for e in sz.edge: eq += e.q
	L.append("okraj ostrova: %d vodopádů přes okraj do mlhy, %.2f l/s (%.0f %% vody z pramenů), dál se nesimuluje" % [sz.edge.size(), eq, 100.0 * eq / maxf(qs, 1e-9)])
	var s1 := TV.surf_seam(w1)
	var ids := HR.pool(p).map(func(e): return int(e.id))
	var m1 := MT.seams(w1.slots, "hm", ids, T.ignore(p))
	L.append("eroze: změna povrchu průměr %.2f U, max odběr %.2f U | šev povrchu %.2f (uvnitř %.2f) | švy vrstev %.2f (uvnitř %.2f) | odneseno minerálů %d | strže %.0f ms, převzorkování %.0f ms" % [st.mean_change, st.max_cut, s1.seam, s1.inner, MT.mean_seam(m1), MT.mean_inner(m1), st.minerals_lost, sz.ms, st.ms_resample])
	# uložené koryto na erodovaném terénu
	var g := _grid_hm(w1)
	var wall := PackedByteArray(); wall.resize(g.size()); wall.fill(1)
	for s in w1.order:
		for i in 256: wall[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16] = 0
	var cs := TOK.make(g, W, GH, wall, sz.mats, PRM.src(springs, g, g.size()), TOK.losses(p, true), bool(p.ostrov_okraj))
	if bool(p.podzemi_vrstva): cs.ug = UG.ctx_world(w1, p)
	var rr := TOK.route(cs)
	L.append("uložené koryto po erozi: plný výpočet %.1f ms" % rr.ms)
	# tůně a jejich plnění
	var pd := TOK.ponds(cs)
	var wetp := pd.filter(func(x): return not x["suchá"])
	L.append("tůně: %d prohlubní, mokrých (s přítokem) %d; odtok prohlubně = Σ perm · %.3f l/s na sloupec (Jan 19:48)" % [pd.size(), wetp.size(), float(p.pit_drain_q)])
	var uq := 0.0; var eq2 := 0.0
	for u in cs.under: uq += u.q
	for e in TOK.edge_falls(cs): eq2 += e.q
	L.append("podzemí (E47d, po propustné vrstvě): %d těles, do hloubky bez tělesa %.2f l/s" % [cs.get("ug_bodies", []).size(), cs.get("lost_deep", 0.0)])
	for b in cs.get("ug_bodies", []):
		var ev: Array = b.events
		L.append("  těleso %d buněk (z %d–%d), přítok %.2f l/s, průsak %.2f l/s, objem do výstupu %.1f m³ → %s, podzemní jezero %d buněk dutin | výstup %s | cesta po vrstvě %d buněk" % [
			b.cells, b.zmin, b.z_out, b.q_in, b.leak, b.volume_m3,
			"NENAPLNÍ SE" if b.never_fills else ("plné za %.0f s (%.1f h)" % [ev[-1].cas_s, ev[-1].cas_s / 3600.0] if not ev.is_empty() else "?"),
			b.lake.size(), ("žádný (uzavřené, po naplnění nepřijímá)" if b.closed else "%s z=%d sloupec (%d, %d), %.2f l/s" % [b.out[3], b.out[0], b.out[4] / GH, b.out[4] % GH, b.out_q]), b.path.size()])
	L.append("ustálené rozdělení (uloženo, dál se nepočítá): přes okraj po povrchu %.2f l/s, z podzemí výtoky %.2f l/s (%d), ztráty v ponorech po cestě %.2f l/s, z %.1f l/s pramenů" % [eq2, uq, cs.under.size(), qs - eq2 - uq, qs])
	var ponds_out := []
	for x in wetp:
		var ev: Array = x.udalosti
		L.append("  tůň %d sloupců, přítok %.2f l/s, odtok do podzemí %.2f l/s, hloubka %.2f m, objem %.1f m³ → %s | ustáleno: podzemí %.2f, přeliv %.2f l/s | %d událostí po 0,5 m: %s" % [x.cells.size(), x.q_lps, x.drain_lps, x.hloubka_m, x.objem_m3,
			"NENAPLNÍ SE (ponor)" if x.nenaplni_se else "plná za %.0f s (%.1f h)" % [ev[-1].cas_s, ev[-1].cas_s / 3600.0], x.podzemi_lps, x.preliv_lps, ev.size(),
			", ".join(ev.map(func(e): return "%.1f m @ %.0f s" % [e.hladina_m, e.cas_s]))])
		ponds_out.append(Array(x.cells).filter(func(c): return cs.fill[c] >= cs.hm[c] + 0.1))
	# lokální přepočet: sucho, hráz, zasypaný pramen, odkopaný pramen
	L.append("lokální přepočet (okraj okna %d sloupců):" % int(p.tok_margin))
	var far := -1; var bd := -1.0
	for i in g.size():
		if wall[i] == 1 or TOK._border(cs, i): continue
		var dm := 1e9
		for j in g.size():
			if cs.eff[j] > 0.0 or cs.fill[j] > cs.hm[j] + 0.01:
				dm = minf(dm, Vector2(i / GH - j / GH, i % GH - j % GH).length())
		if dm > bd: bd = dm; far = i
	var ch := PackedInt32Array(); var hv := PackedFloat64Array()
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var j := (far / GH + dx) * GH + far % GH + dy
			ch.append(j); hv.append(cs.hm[j] + 4.0)
	_demo(L, cs, "kopeček 2 m daleko od vody (%.0f sloupců od nejbližší vody)" % bd, ch, hv, springs, p)
	var dam := -1; var be := -1.0
	for i in g.size():
		if cs.eff[i] > be and not TOK._border(cs, i) and cs.fill[i] <= cs.hm[i] + 0.01 and cs.src[i] == 0.0:
			var ok := true
			for s in springs:
				if Vector2(i / GH - s.gi / GH, i % GH - s.gi % GH).length() < 4.0: ok = false
			if ok: be = cs.eff[i]; dam = i
	ch = PackedInt32Array(); hv = PackedFloat64Array()
	var fdx: int = cs.to[dam] / GH - dam / GH; var fdy: int = cs.to[dam] % GH - dam % GH   # hráz napříč tokem, 7 sloupců
	for k in range(-3, 4):
		var jx: int = dam / GH - fdy * k; var jy: int = dam % GH + fdx * k
		if jx < 0 or jy < 0 or jx >= W or jy >= GH: continue
		var j := jx * GH + jy
		if wall[j] == 0 and not TOK._border(cs, j): ch.append(j); hv.append(maxf(cs.hm[j], cs.hm[dam] + 4.0))
	var np0 := TOK.ponds(cs, 0.25, 0.5, false).filter(func(x): return not x["suchá"]).size()
	_demo(L, cs, "hráz 2 m (7 sloupců napříč) přes potok %.2f l/s v (%d, %d)" % [be, dam / GH, dam % GH], ch, hv, springs, p)
	L.append("    mokrých tůní před hrází %d, po %d" % [np0, TOK.ponds(cs, 0.25, 0.5, false).filter(func(x): return not x["suchá"]).size()])
	for x in TOK.ponds(cs):
		if x["suchá"]: continue
		var near := false
		for c in x.cells:
			if Vector2(c / GH - dam / GH, c % GH - dam % GH).length() <= 3.0: near = true
		if near:
			var ev: Array = x.udalosti
			L.append("    za hrází tůň %d sloupců, přítok %.2f l/s, %.2f m hluboká, %.1f m³ → přeteče za %.0f s; události: %s" % [x.cells.size(), x.q_lps, x.hloubka_m, x.objem_m3, ev[-1].cas_s, ", ".join(ev.map(func(e): return "%.1f m @ %.0f s" % [e.hladina_m, e.cas_s]))])
	var sp: Dictionary = springs[0]
	_demo(L, cs, "zasypaný pramen %s (%d, %d) o 1,5 m" % [sp.druh, sp.gi / GH, sp.gi % GH], PackedInt32Array([sp.gi]), PackedFloat64Array([cs.hm[sp.gi] + 3.0]), springs, p)
	_demo(L, cs, "pramen znovu odkopaný", PackedInt32Array([sp.gi]), PackedFloat64Array([cs.hm[sp.gi] - 3.0]), springs, p)
	var a = ES.run(w0, p, "strze").world; var b = ES.run(w0, p, "strze").world
	L.append("determinismus 2×: %s / %s → %s" % [a.hash().left(12), b.hash().left(12), "STEJNÉ" if a.hash() == b.hash() else "RŮZNÉ!"])
	L.append("celkem %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	FileAccess.open(out_txt, FileAccess.WRITE).store_string("\n".join(L) + "\n")
	var data := {"before": TV.dump_world(w0, {"depth": [], "flow": []}), "after": TV.dump_world(w1, {"depth": [], "flow": []}), "pal": Array(HR.palette()).map(func(c): return c.to_html(false)),
		"chan": Array(sz.chan), "sink": Array(sz.sink), "depth": Array(sz.depth), "eff": Array(sz.eff), "ponds": ponds_out,
		"falls": sz.falls.map(func(f): return [f.top, f.foot, f.drop_m]), "edge": sz.edge.map(func(e): return [e.gi, e.q]),
		"springs": springs.map(func(s): return [s.gi, s.druh, s.q]), "under": cs.under.map(func(u): return [u.from, u.exit, u.q]), "slots": w0.order.map(func(s): return [s.x, s.y, w0.slots[s].bp.shape])}
	FileAccess.open(out_json, FileAccess.WRITE).store_string(JSON.stringify(data))
	return L
