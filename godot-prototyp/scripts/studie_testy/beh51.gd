extends RefCounted
## KOPIE z blueprint-studie/scripts/eroze51/beh51.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E51 běh: testy (přesný čas odpočtu, kopání/položení vynuluje, zachování hmoty), scénáře koryto / tůň / hráz,
## výkon (fronta, události/s, přepočet, syntetická halda 1 M). Výstup shots/test_eroze51.txt, bench_eroze51.txt, eroze51.json.

const MC = preload("res://scripts/voda/eroze/mech.gd")
const SC = preload("res://scripts/studie_testy/scenare.gd")
const HY = preload("res://scripts/voda/eroze/hydro.gd")
const Heap = preload("res://scripts/voda/eroze/halda.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const DAY := 86400.0

static func make(s: Dictionary, p: Dictionary):
	return MC.new(p, s.W, s.H, s.NZ, s.cells.duplicate(), s.wall, s.src)

static func _hm(m) -> Array:
	return Array(m.hm)

static func _pond_info(m) -> Dictionary:
	var cols := 0; var vol := 0.0; var dmax := 0.0
	for i in m.W * m.H:
		if m.st.pw[i] == 1:
			var d: float = (m.st.fill[i] - m.st.hm[i]) * HY.CELL
			cols += 1; vol += d * HY.CELL * HY.CELL; dmax = maxf(dmax, d)
	return {"cols": cols, "vol": vol, "dmax": dmax}

static func _ms(a: Array) -> String:
	if a.is_empty(): return "—"
	var s := 0.0; var mx := 0.0
	for v in a: s += float(v); mx = maxf(mx, float(v))
	var b := a.duplicate(); b.sort()
	return "průměr %.2f ms, medián %.2f, max %.2f (n = %d)" % [s / a.size(), float(b[b.size() / 2]), mx, a.size()]

static func _sum(a: Array) -> float:
	var s := 0.0
	for v in a: s += float(v)
	return s

static func run_all(p: Dictionary, out_test: String, out_bench: String, out_json: String) -> PackedStringArray:
	var T := PackedStringArray(); var B := PackedStringArray(); var J := {}
	var ok := true
	var stamp := Time.get_datetime_string_from_system()
	T.append("# E51 testy (%s)" % stamp)
	B.append("# E51 eroze a usazování událostmi (%s), GDScript 1 vlákno, %s" % [stamp, OS.get_processor_name()])
	var days := float(p.e51_dni)
	# ---------- 1) koryto: měkký vs. tvrdý pruh
	var s1 := SC.koryto()
	var t0 := Time.get_ticks_usec()
	var m = make(s1, p)
	var init_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# test A: první událost buňky = R / Q přesně (k = 0)
	var probe := -1
	for x in range(6, 30):
		var i: int = x * s1.H + 3
		if m.mode[i] == 1: probe = i; break
	var expect := INF
	if probe >= 0: expect = float(HY.mat(m.top_mat(probe))[1]) / (m.st.eff[probe] / 1000.0)
	var a_ok := probe >= 0 and absf(m.due(probe) - expect) < 1e-6 * expect
	T.append("A odpočet = ero_vol / Q: sloupec %d, %s = %.0f m³ / %.2f l/s → %.0f s (fronta %.0f s) → %s" % [probe, "hlína", float(HY.mat(m.top_mat(probe))[1]),
		m.st.eff[probe], expect, m.due(probe), "OK" if a_ok else "CHYBA"])
	ok = ok and a_ok
	var prof := {"t": [], "soft": [], "hard": [], "vsoft": [], "vhard": []}
	var line := func(y: int) -> Array:
		var a := []
		for x in s1.W: a.append(m.hm[x * s1.H + y])
		return a
	var vline := func(y: int) -> Array:
		var a := []
		for x in s1.W: a.append(m.vel[x * s1.H + y])
		return a
	var hm0 := _hm(m)
	var t1 := Time.get_ticks_usec()
	var ev0: int = m.stats.events
	for d in [0.0, 3.0, 7.0, 15.0, 30.0, days].filter(func(v): return v <= days):
		m.run_until(d * DAY)
		prof.t.append(d); prof.soft.append(line.call(3)); prof.hard.append(line.call(9)); prof.vsoft.append(vline.call(3)); prof.vhard.append(vline.call(9))
	var run_ms := (Time.get_ticks_usec() - t1) / 1000.0
	var cut := [0.0, 0.0]; var cmax := [0, 0]
	for x in range(2, s1.W):
		for side in 2:
			var y: int = s1.yc[side]; var i: int = x * s1.H + y
			var dz: int = hm0[i] - m.hm[i]
			cut[side] += dz; cmax[side] = maxi(cmax[side], dz)
	var ne: int = m.stats.events - ev0
	B.append("")
	B.append("## 1 koryto %d × %d, 2 × pramen 5 l/s, %.0f dní" % [s1.W, s1.H, days])
	B.append("zahloubení osy koryta: měkký pruh (hlína / písek) průměr %.2f m, max %.1f m; tvrdý (hlína 1 buňka na žule) průměr %.2f m, max %.1f m" % [
		cut[0] / (s1.W - 2) * HY.CELL, cmax[0] * HY.CELL, cut[1] / (s1.W - 2) * HY.CELL, cmax[1] * HY.CELL])
	B.append("události %d (eroze %d, nános %d, zastaralé %d, ponechané beze změny %d), fronta max %d, živé položky na konci %d; start %.1f ms, běh %.0f ms → %.0f událostí/s" % [
		ne, m.stats.ero, m.stats.dep, m.stats.stale, m.stats.kept, m.stats.q_max, m.live(), init_ms, run_ms, ne / maxf(run_ms / 1000.0, 1e-6)])
	B.append("přepočet po události (TOK.update + přeplánování): %s; přeplánováno sloupců na událost průměr %.1f" % [_ms(m.stats.upd_ms), _sum(m.stats.resched) / maxf(m.stats.resched.size(), 1)])
	B.append("odnesená hmota: do tůní %.2f m³, přes okraj do mlhy %.2f m³" % [m.stats.to_pond_m3, m.stats.lost_m3])
	J.koryto = {"W": s1.W, "H": s1.H, "yc": s1.yc, "hm0": hm0, "hm": _hm(m), "prof": prof, "eff": Array(m.st.eff), "wall": Array(s1.wall)}
	# test B: kopání vynuluje odpočet (hráč), položení písku taky; přeplánuje se i po proudu
	var mc = make(s1, p)
	mc.run_until(2.0 * DAY)
	var cand := -1
	for x in range(8, 30):
		var i: int = x * s1.H + 3
		if mc.mode[i] == 1 and mc.re[i] > 0.0:
			mc._advance(i)
			if mc.R[i] < float(HY.mat(mc.top_mat(i))[1]) * 0.95: cand = i; break
	var tdig := 2.0 * DAY
	if cand >= 0:
		mc.now = tdig; mc._advance(cand)
		var r_before: float = mc.R[cand]; var due_before: float = mc.due(cand)
		var full_before := float(HY.mat(mc.top_mat(cand))[1])
		var nres: int = mc.stats.resched.size()
		mc.dig(cand, tdig)
		var full_new := float(HY.mat(mc.top_mat(cand))[1])
		var b1: bool = absf(mc.R[cand] - full_new) < 1e-9
		var due_new: float = mc.due(cand)
		var b2: bool = (mc.re[cand] == 0.0) or absf(due_new - (tdig + full_new / mc.re[cand])) < 1e-6 * due_new
		var resched: int = mc.stats.resched[-1] if mc.stats.resched.size() > nres else 0
		T.append("B kopání v %.0f h: sloupec %d měl zbývá %.0f z %.0f m³ (událost za %.1f h); po vykopání R = %.0f m³ = plný odpočet nového vrchu (%s), událost za %s; přeplánováno %d sloupců → %s" % [
			tdig / 3600.0, cand, r_before, full_before, (due_before - tdig) / 3600.0, mc.R[cand], "písek" if mc.top_mat(cand) == 3 else str(mc.top_mat(cand)),
			("%.1f h" % ((due_new - tdig) / 3600.0)) if due_new < INF else "— (rychlost pod prahem)", resched, "OK" if b1 and b2 and resched >= 1 else "CHYBA"])
		ok = ok and b1 and b2 and resched >= 1
		mc.run_until(tdig + 3600.0)
		mc._advance(cand)
		var t2: float = mc.now
		mc.place(cand, SC.DIRT, t2)
		var b3: bool = absf(mc.R[cand] - float(HY.mat(SC.DIRT)[1])) < 1e-9
		T.append("C položení hlíny v %.1f h: R = %.0f m³ = plný odpočet hlíny → %s" % [t2 / 3600.0, mc.R[cand], "OK" if b3 else "CHYBA"])
		ok = ok and b3
	else:
		T.append("B kopání: nenašel se sloupec s rozběhnutým odpočtem → CHYBA"); ok = false
	# test D: stejný běh 2× → stejné výšky (determinismus)
	var m2 = make(s1, p); m2.run_until(days * DAY)
	var same := _hm(m2) == _hm(m)
	T.append("D determinismus koryta 2× (%.0f dní): %s" % [days, "STEJNÉ OK" if same else "RŮZNÉ CHYBA"])
	ok = ok and same
	# ---------- 2) tůň se zanáší
	var pt: Dictionary = p.duplicate(); pt.e51_c0 = float(p.get("e51_c0_tun", 0.002))
	var s2 := SC.tun()
	var mt = make(s2, pt)
	var curve := {"t": [], "vol": [], "cols": [], "dmax": [], "sec": []}
	var tt := Time.get_ticks_usec(); var e2: int = mt.stats.events
	var p0 := _pond_info(mt)
	var t_gone := -1.0
	var tdays := []
	for k in 19: tdays.append(k * 5.0)
	for k in range(2, 13): tdays.append(k * 60.0)
	for d in tdays:
		mt.run_until(d * DAY)
		var pi := _pond_info(mt)
		curve.t.append(d); curve.vol.append(pi.vol); curve.cols.append(pi.cols); curve.dmax.append(pi.dmax)
		var sec := []
		for x in s2.W: sec.append([mt.hm[x * s2.H + 10], mt.st.fill[x * s2.H + 10]])
		curve.sec.append(sec)
		if pi.vol < 0.05 * p0.vol and t_gone < 0.0: t_gone = d
	var r2 := (Time.get_ticks_usec() - tt) / 1000.0
	B.append("")
	B.append("## 2 tůň %d × %d, přítok 2 l/s, c0 %.4f m³/m³ (+ nános z eroze nad tůní)" % [s2.W, s2.H, float(pt.e51_c0)])
	var half := -1.0
	for k in curve.t.size():
		if half < 0.0 and float(curve.vol[k]) <= 0.5 * p0.vol: half = float(curve.t[k])
	B.append("objem tůně %.2f m³ (%d sloupců, hloubka %.2f m) → po %.0f dnech %.2f m³ (%d sloupců); polovina do %s dní, zanesená (< 5 %%) do %s dní" % [
		p0.vol, p0.cols, p0.dmax, curve.t[-1], curve.vol[-1], curve.cols[-1], str(half) if half >= 0 else "—", str(t_gone) if t_gone >= 0 else "—"])
	B.append("události %d (nános %d, eroze %d, zastaralé %d), fronta max %d, běh %.0f ms; přepočet %s" % [mt.stats.events - e2, mt.stats.dep, mt.stats.ero, mt.stats.stale, mt.stats.q_max, r2, _ms(mt.stats.upd_ms)])
	J.tun = {"W": s2.W, "H": s2.H, "curve": curve, "hm0": Array(make(s2, pt).hm), "hm": _hm(mt)}
	# ---------- 4) protržení hráze
	var ph: Dictionary = p.duplicate(); ph.pit_drain_q = float(p.get("e51_pit_q", 0.02))
	var s3 := SC.hraz()
	var mh = make(s3, ph)
	var down: int = (s3.W - 3) * s3.H + 7
	var crest: int = s3.dam_x * s3.H + 7
	var hist := {"t": [], "q_down": [], "crest": [], "pond": [], "drain": [], "long": [], "long_t": []}
	var eff0: Array = Array(mh.st.eff)
	var q0: float = mh.st.eff[down]; var pond0 := _pond_info(mh)
	var t_breach := -1.0
	var th := Time.get_ticks_usec(); var e3: int = mh.stats.events
	var resch_before: int = mh.stats.resched.size()
	for k in 61:
		var d := k * 0.5
		mh.run_until(d * DAY)
		var pi := _pond_info(mh)
		var dr := 0.0
		for i in mh.W * mh.H: dr += mh.st.extra[i]
		if d in [0.0, 7.0, 14.0, 21.0, 28.0]:
			var lg := []
			for x in s3.W: lg.append([mh.hm[x * s3.H + 7], mh.st.fill[x * s3.H + 7]])
			hist.long.append(lg); hist.long_t.append(d)
		hist.t.append(d); hist.q_down.append(mh.st.eff[down]); hist.crest.append(mh.hm[crest]); hist.pond.append(pi.vol); hist.drain.append(dr)
		if t_breach < 0.0 and pi.vol < 0.05 * float(hist.pond[0]): t_breach = d
	var r3 := (Time.get_ticks_usec() - th) / 1000.0
	var big := 0
	for v in mh.stats.resched.slice(resch_before): big = maxi(big, int(v))
	B.append("")
	B.append("## 4 hráz z písku %d × %d, přítok 3 l/s, odtok tůně do podzemí pit_drain_q %.3f l/s · perm" % [s3.W, s3.H, float(ph.pit_drain_q)])
	B.append("před: tůň %d sloupců %.2f m³, odtok do podzemí %.2f l/s, po proudu %.2f l/s; koruna hráze z %d" % [pond0.cols, pond0.vol, hist.drain[0], q0, hist.crest[0]])
	B.append("po %.0f dnech: koruna z %d, tůň %.2f m³, odtok do podzemí %.2f l/s, po proudu %.2f l/s; tůň pod 5 %% objemu v %s dnech" % [
		hist.t[-1], hist.crest[-1], hist.pond[-1], hist.drain[-1], hist.q_down[-1], str(t_breach) if t_breach >= 0 else "— (nezmizela)"])
	B.append("události %d, největší přeplánování po jedné události %d sloupců, běh %.0f ms; přepočet %s" % [mh.stats.events - e3, big, r3, _ms(mh.stats.upd_ms)])
	J.hraz = {"W": s3.W, "H": s3.H, "hist": hist, "eff0": eff0, "eff": Array(mh.st.eff), "hm0": Array(make(s3, ph).hm), "hm": _hm(mh), "wall": Array(s3.wall), "down": down, "crest": crest}
	var e_ok: bool = float(hist.q_down[-1]) > q0 + 1e-6
	T.append("E protržení změní tok po proudu: %.2f → %.2f l/s → %s" % [q0, hist.q_down[-1], "OK" if e_ok else "CHYBA"])
	ok = ok and e_ok
	# ---------- 5) výkon
	var N := int(p.e51_perf_n)
	var s4 := SC.perf(N, int(p.world_seed))
	var tp := Time.get_ticks_usec()
	var mp = make(s4, p)
	var pi_ms := (Time.get_ticks_usec() - tp) / 1000.0
	var wetc := 0
	for i in N * N: if mp.wet(i): wetc += 1
	var live0: int = mp.live()
	tp = Time.get_ticks_usec()
	var nev: int = mp.run_until(INF, int(p.e51_perf_ev))
	var pr_ms := (Time.get_ticks_usec() - tp) / 1000.0
	B.append("")
	B.append("## 5 výkon %d × %d × 48, 16 pramenů" % [N, N])
	B.append("start (route + plánování všech) %.0f ms; mokrých sloupců %d, živých položek %d, fronta max %d" % [pi_ms, wetc, live0, mp.stats.q_max])
	B.append("%d událostí za %.0f ms → %.0f událostí/s (simulovaný čas %.1f dní); zastaralé %d, ponechané %d; přepočet %s" % [nev, pr_ms, nev / maxf(pr_ms / 1000.0, 1e-6), mp.now / DAY, mp.stats.stale, mp.stats.kept, _ms(mp.stats.upd_ms)])
	B.append("přeplánováno sloupců na událost průměr %.1f, max %d" % [_sum(mp.stats.resched) / maxf(mp.stats.resched.size(), 1), mp.stats.resched.max() if not mp.stats.resched.is_empty() else 0])
	# syntetická halda 1 M
	var NH := int(p.e51_halda)
	var hp := Heap.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 51
	var ts := PackedFloat64Array(); ts.resize(NH)
	for k in NH: ts[k] = rng.randf() * 1e7
	var th0 := Time.get_ticks_usec()
	for k in NH: hp.push(ts[k], k, 0)
	var push_ms := (Time.get_ticks_usec() - th0) / 1000.0
	th0 = Time.get_ticks_usec()
	var cyc := 100000
	for k in cyc:   # ustálený provoz: vyber nejbližší, naplánuj znovu (velikost fronty stejná)
		var e := hp.pop(); hp.push(float(e[0]) + rng.randf() * 1e5, int(e[1]), 0)
	var cyc_ms := (Time.get_ticks_usec() - th0) / 1000.0
	th0 = Time.get_ticks_usec()
	var last := -1.0; var sorted := true
	while hp.size() > 0:
		var e := hp.pop()
		if float(e[0]) < last: sorted = false
		last = float(e[0])
	var pop_ms := (Time.get_ticks_usec() - th0) / 1000.0
	B.append("syntetická halda %d položek: push všech %.0f ms (%.2f µs/položka), pop + push v ustáleném stavu %.2f µs, pop všech %.0f ms (%.2f µs), pořadí %s; paměť ~%.0f MB (16 B/položka)" % [
		NH, push_ms, push_ms * 1000.0 / NH, cyc_ms * 1000.0 / cyc, pop_ms, pop_ms * 1000.0 / NH, "OK" if sorted else "CHYBA", NH * 16.0 / 1048576.0])
	ok = ok and sorted
	T.append("F halda 1 M vybírá ve vzestupném pořadí → %s" % ["OK" if sorted else "CHYBA"])
	T.append("výsledek: %s" % ["VŠE OK" if ok else "CHYBA"])
	FileAccess.open(out_test, FileAccess.WRITE).store_string("\n".join(T) + "\n")
	FileAccess.open(out_bench, FileAccess.WRITE).store_string("\n".join(B) + "\n")
	FileAccess.open(out_json, FileAccess.WRITE).store_string(JSON.stringify(J))
	var all := T.duplicate(); all.append_array(B)
	return all
