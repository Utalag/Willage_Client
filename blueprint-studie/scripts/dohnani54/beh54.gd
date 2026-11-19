extends RefCounted
## E54 (Jan 22:52–22:59): vesnice na klientu / výprava na serveru → levné a deterministické.
##  1) dohnání: oblast, kterou nikdo nepozoroval, se při návratu dopočítá naráz z uloženého toku a časů událostí
##     (tůně, eroze, nános). Test: pozorovaná (po dnech) vs. nepozorovaná (jeden skok) → stejný stav, cena = jen události.
##  2) přepočet s ranným zastavením: po změně jen od místa po proudu, stop jakmile tok sedí s uloženým stavem
##     (TOK.update). Měří se dotčené sloupce vs. délka cesty po proudu.
##  3) vodní bilance po každém přepočtu (GPT review): kontinuita v každé buňce a celková bilance.
const B = preload("res://scripts/eroze51/beh51.gd")
const SC = preload("res://scripts/eroze51/scenare.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const DAY := 86400.0

static func _hash(m) -> String:
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256)
	hc.update(PackedInt32Array(m.hm).to_byte_array()); hc.update(PackedFloat64Array(m.R).to_byte_array()); hc.update(PackedFloat64Array(m.A).to_byte_array())
	for k in ["eff", "fill", "ain"]: hc.update(PackedFloat64Array(m.st[k]).to_byte_array())
	hc.update(PackedByteArray(m.st.pw)); hc.update(var_to_bytes(m.evlog))
	return hc.finish().hex_encode().left(16)

## kontinuita: ain_i = src + src2 + Σ eff přítoků; celkově Σ(src + src2) = Σ ztrát (ain − eff) + Σ eff bez odtoku (okraj)
static func balance(st: Dictionary) -> Dictionary:
	var W: int = st.W; var H: int = st.H; var n := W * H
	var inflow := PackedFloat64Array(); inflow.resize(n)
	for j in n:
		if st.wall[j] == 0 and st.to[j] >= 0: inflow[st.to[j]] += st.eff[j]
	var mx := 0.0; var sin := 0.0; var loss := 0.0; var out := 0.0; var under := 0.0
	for i in n:
		if st.wall[i] == 1: continue
		mx = maxf(mx, absf(st.ain[i] - st.src[i] - st.src2[i] - inflow[i]))
		sin += st.src[i] + st.src2[i]
		var l: float = st.ain[i] - st.eff[i]
		loss += l
		if st.extra[i] > 0.0: under += l
		if st.to[i] < 0: out += st.eff[i]
	return {"cell_max": mx, "in": sin, "loss": loss, "under": under, "infil": loss - under, "edge": out, "global": sin - loss - out}

static func run_all(p: Dictionary) -> PackedStringArray:
	var T := PackedStringArray(); var ok := true
	# ---- 1) dohnání: tůň se zanáší (E51 scénář 2) + koryto (scénář 1), 60 dní
	for nm in ["tun", "koryto"]:
		var pt: Dictionary = p.duplicate()
		if nm == "tun": pt.e51_c0 = float(p.get("e51_c0_tun", 0.002))
		var s: Dictionary = SC.tun() if nm == "tun" else SC.koryto()
		var days := float(p.get("e54_dni", 60.0))
		var a = B.make(s, pt)
		var t0 := Time.get_ticks_usec()
		var ea := 0
		for d in range(1, int(days) + 1): ea += a.run_until(d * DAY)   # pozorovaná: hráč tam je, „každý den“ se díváme
		var ms_a := (Time.get_ticks_usec() - t0) / 1000.0
		var b = B.make(SC.tun() if nm == "tun" else SC.koryto(), pt)
		t0 = Time.get_ticks_usec()
		var eb: int = b.run_until(days * DAY)   # nepozorovaná: jeden skok při návratu
		var ms_b := (Time.get_ticks_usec() - t0) / 1000.0
		var ha := _hash(a); var hb := _hash(b)
		var same := ha == hb
		ok = ok and same
		# tůně: hladina v čase z předpočítaných událostí plnění (bez simulace)
		var ponds := TOK.ponds(b.st, float(b.st.L.cell_m2), float(b.st.L.u_m), true)
		var pinfo := ""
		for pd in ponds:
			if pd.get("udalosti", []).is_empty(): continue
			var lv := 0; var ev: Array = pd.udalosti
			for e in ev:
				if float(e.cas_s) >= 0.0 and float(e.cas_s) <= days * DAY: lv += 1
			pinfo = "tůň %d sloupců: %d/%d vrstev plných za %.0f dní (z událostí plnění, bez simulace)" % [pd.cells.size(), lv, ev.size(), days]
			break
		T.append("1) dohnání %s %.0f dní: po dnech %d událostí %.0f ms | jeden skok %d událostí %.0f ms | eroze %d, nános %d, do tůně %.2f m³ | otisk %s / %s → %s%s" % [
			nm, days, ea, ms_a, eb, ms_b, int(b.stats.ero), int(b.stats.dep), float(b.stats.to_pond_m3), ha, hb, "STEJNÉ OK" if same else "RŮZNÉ CHYBA", (" | " + pinfo) if pinfo != "" else ""])
		T.append("   tiků po 1 s by bylo %d (žádné se nepočítají; cena = události)" % int(days * DAY))
	# ---- 2) ranné zastavení + 3) bilance: výkopy na mapě perf
	var N := int(p.get("e54_n", 128))
	var m = B.make(SC.perf(N, int(p.world_seed)), p)
	var st: Dictionary = m.st
	var b0 := balance(st)
	T.append("3) bilance po route (%d²): přítok %.2f l/s = ztráty %.2f (vsak %.2f, do podzemí %.2f) + okraj %.2f, zbytek %.9f, kontinuita max %.9f l/s" % [N, b0.in, b0.loss, b0.infil, b0.under, b0.edge, b0.global, b0.cell_max])
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.world_seed)
	var cand := []
	for i in N * N:
		if TOK.wet(st, i) and st.pw[i] == 0 and not TOK._border(st, i) and m.hm[i] > 2: cand.append(i)
	var rows := []; var worst_c := 0.0; var worst_g := 0.0
	for k in mini(int(p.get("e54_vykopu", 40)), cand.size()):
		var c: int = cand[rng.randi_range(0, cand.size() - 1)]
		# délka cesty po proudu (sloupce do okraje / tůně) = horní mez práce bez ranného zastavení
		var path := 0; var j := c
		while j >= 0 and path < N * N:
			j = st.to[j]; path += 1
		var n0: int = m.stats.upd_ms.size()
		m.dig(c, m.now + 60.0)
		var ms: float = m.stats.upd_ms[n0]
		var touched: int = int(m.stats.resched[n0])
		var bl := balance(st)
		worst_c = maxf(worst_c, bl.cell_max); worst_g = maxf(worst_g, absf(bl.global))
		rows.append([ms, touched, path])
	rows.sort_custom(func(a, b2): return a[0] < b2[0])
	var sm := 0.0; var st_t := 0.0; var sp := 0.0; var early := 0
	for r in rows:
		sm += r[0]; st_t += r[1]; sp += r[2]
		if r[1] < r[2] + 9: early += 1
	var nr := maxi(rows.size(), 1)
	T.append("2) ranné zastavení (%d výkopů v korytech %d²): přepočet průměr %.2f ms, medián %.2f, max %.2f | přeplánovaných sloupců průměr %.0f vs cesta po proudu %.0f sloupců | celkem buněk mapy %d" % [
		rows.size(), N, sm / nr, rows[rows.size() / 2][0], rows[-1][0], st_t / nr, sp / nr, N * N])
	var b1 := balance(st)
	var okb: bool = worst_c < 1e-6 and worst_g < 1e-6
	ok = ok and okb
	T.append("3) bilance po každém přepočtu: kontinuita max %.9f l/s, celková max %.9f l/s → %s (konec: přítok %.2f = ztráty %.2f + okraj %.2f)" % [worst_c, worst_g, "OK" if okb else "CHYBA", b1.in, b1.loss, b1.edge])
	T.append("výsledek: " + ("VŠE OK" if ok else "CHYBA"))
	return T
