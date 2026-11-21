extends SceneTree
## Krok 2 (V1.0): testy funkce světa I podle 04-implementace-generatoru.md, krok 2, podbod Testy.
## --rezim=det   … test 5: SHA-256 mřížky výšek výchozího světa 3 × 3 po 0,25 m (středy buněk), pro dva procesy
## --rezim=sklony_svet … test 2 na celém maximu světa 4096 m: mřížka 4 m, sklon diferencí ±0,25 m v každém bodě
## --rezim=vse   … testy 1, 2, 3, 4, 6, 7 (spojitost, sklony, sopky, mapy, čas, klima)
## --rezim=klima_srovnani … mapy 4096 m stejný seed: mirne / poust / ledovec
## --klima=ID    … vynutit preset (výchozí mirne; ze_seedu = základ ze seedu)
## --out=adresář (JSON), --data=adresář (binární mřížky float32 pro grafy, mimo git), --seed=N
const S = preload("res://scripts/v1/svet_fn.gd")
const B = preload("res://scripts/v1/blok_v1.gd")

var out := {}
var data_dir := "/tmp/k2/data"

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _uloz_bin(jmeno: String, a: PackedFloat32Array) -> void:
	var f := FileAccess.open(data_dir + "/" + jmeno, FileAccess.WRITE)
	f.store_buffer(a.to_byte_array())

func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

func _init() -> void:
	var rezim := _arg("rezim", "vse")
	var od := _arg("out", "res://shots/krok02")
	data_dir = _arg("data", data_dir)
	DirAccess.make_dir_recursive_absolute(data_dir)
	var par := {"seed": int(_arg("seed", "49"))}
	var klima_arg := _arg("klima", "")
	if klima_arg != "": par["klima"] = klima_arg
	var t0 := Time.get_ticks_usec()
	var svet = S.new(par)
	out["init_ms"] = _ms(t0)
	out["seed"] = svet.sd
	out["gradient"] = svet.gradient
	out["sopky"] = svet.sopky
	out["biom_slouceni"] = svet.biom_slouceni
	out["parametry"] = {"biom_velke_oblasti": svet.p.biom_velke_oblasti, "biom_meritko_m": svet.p.biom_meritko_m,
		"biom_min_plocha_m2": svet.p.biom_min_plocha_m2, "detail_max_m": svet.p.detail_max_m,
		"sopka_od_okraje_startu_m": svet.p.sopka_od_okraje_startu_m, "start_blok": svet.p.start_blok,
		"klima": svet.p.klima, "klima_id": svet.klima_id, "klima_ze_seedu": svet.klima_ze_seedu,
		"klima_priklad": bool(svet.p.get("klima_priklad", false)), "podil": svet.p.podil,
		"klima_k_voda": svet.p.get("klima_k_voda", 1.0)}
	var chyb := 0
	if rezim == "klima_srovnani":
		chyb += _klima_srovnani(int(par.seed))
		var fk := FileAccess.open(ProjectSettings.globalize_path(od + "/" + _arg("jmeno", "klima_srovnani.json")), FileAccess.WRITE)
		fk.store_string(JSON.stringify(out, " "))
		quit(1 if chyb > 0 else 0); return
	if rezim == "det":
		chyb += _det(svet)
		var f := FileAccess.open(ProjectSettings.globalize_path(od + "/" + _arg("jmeno", "det.json")), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		quit(1 if chyb > 0 else 0); return
	if rezim == "sklony_svet":
		chyb += _sklony_svet(svet)
		var f3 := FileAccess.open(ProjectSettings.globalize_path(od + "/sklony_svet.json"), FileAccess.WRITE)
		f3.store_string(JSON.stringify(out, " "))
		quit(1 if chyb > 0 else 0); return
	chyb += _spojitost(svet)
	chyb += _sklony(svet)
	chyb += _sopky(svet)
	chyb += _mapy(svet)
	chyb += _klima_overeni(svet)
	_cas(svet)
	out["chyb"] = chyb
	var f2 := FileAccess.open(ProjectSettings.globalize_path(od + "/svet_v1.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(out, " "))
	print("chyb celkem: ", chyb)
	quit(1 if chyb > 0 else 0)

# ------------------------------------------------------------ test 5
func _det(svet) -> int:
	var o: Vector2 = svet.start_m()
	var t0 := Time.get_ticks_usec()
	var a: PackedFloat64Array = B.stredy(svet, o, 384.0, 0.25)
	var ms := _ms(t0)
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256); hc.update(a.to_byte_array())
	var hx: String = hc.finish().hex_encode()
	var mn := 1e9; var mx := -1e9
	for v in a: mn = minf(mn, v); mx = maxf(mx, v)
	out["det"] = {"sha256": hx, "otisk": hx.substr(0, 16), "bunek": a.size(), "ms": ms, "min_m": mn, "max_m": mx}
	print("det: ", hx.substr(0, 16), " ", a.size(), " buněk, ", ms, " ms")
	if _arg("uloz", "0") == "1":
		var f := PackedFloat32Array(); f.resize(a.size())
		for i in a.size(): f[i] = a[i]
		_uloz_bin("start_025.f32", f)
	return 0

# ------------------------------------------------------------ test 1
func _sev(a: PackedFloat64Array, b: PackedFloat64Array, n: int, osa: int) -> Dictionary:
	# a vlevo/dole, b vpravo/nahoře; osa 0 = šev kolmo na x (a poslední řádek i = n-1, b první i = 0)
	var mx := 0.0; var skok_pres := 0.0; var skok_uvnitr := 0.0
	for t in n:
		var ea: float; var eb: float; var a1: float; var b1: float
		if osa == 0:
			ea = a[(n - 1) * n + t]; eb = b[t]; a1 = a[(n - 2) * n + t]; b1 = b[n + t]
		else:
			ea = a[t * n + n - 1]; eb = b[t * n]; a1 = a[t * n + n - 2]; b1 = b[t * n + 1]
		mx = maxf(mx, absf(ea - eb))
		skok_pres = maxf(skok_pres, maxf(absf(eb - a1), absf(b1 - ea)))   # rozdíl o jeden krok přes šev (z obou bloků)
		skok_uvnitr = maxf(skok_uvnitr, maxf(absf(ea - a1), absf(b1 - eb)))
	return {"max_rozdil_m": mx, "max_krok_pres_sev_m": skok_pres, "max_krok_u_sevu_uvnitr_m": skok_uvnitr}

func _spojitost(svet) -> int:
	var st: Vector2 = svet.start_m()
	var bs: Vector2i = Vector2i(st / 128.0)
	var krok := 0.25
	var n := 513
	var bloky := {}
	var t0 := Time.get_ticks_usec()
	for i in 3:
		for j in 3:
			var b := bs + Vector2i(i, j)
			bloky[b] = B.rohy(svet, B.origin(svet, b), 128.0, krok)
	var ms_bloky := _ms(t0)
	var sevy := []; var mx := 0.0
	for i in 3:
		for j in 3:
			var b := bs + Vector2i(i, j)
			if i < 2:
				var r := _sev(bloky[b], bloky[b + Vector2i(1, 0)], n, 0); r["bloky"] = [b, b + Vector2i(1, 0)]; sevy.append(r); mx = maxf(mx, r.max_rozdil_m)
			if j < 2:
				var r := _sev(bloky[b], bloky[b + Vector2i(0, 1)], n, 1); r["bloky"] = [b, b + Vector2i(0, 1)]; sevy.append(r); mx = maxf(mx, r.max_rozdil_m)
	# segmenty 8 m prostředního bloku, každý zvlášť (33 × 33 rohů), proti sousedům i proti bloku
	var bc := bs + Vector2i(1, 1)
	var segs := {}
	t0 = Time.get_ticks_usec()
	for a in 16:
		for c in 16:
			segs[Vector2i(a, c)] = B.rohy(svet, B.origin(svet, bc) + Vector2(a, c) * 8.0, 8.0, krok)
	var ms_seg := _ms(t0)
	var smx := 0.0; var sproti_bloku := 0.0; var nsevu := 0
	var blok: PackedFloat64Array = bloky[bc]
	for a in 16:
		for c in 16:
			var s: PackedFloat64Array = segs[Vector2i(a, c)]
			if a < 15: smx = maxf(smx, _sev(s, segs[Vector2i(a + 1, c)], 33, 0).max_rozdil_m); nsevu += 1
			if c < 15: smx = maxf(smx, _sev(s, segs[Vector2i(a, c + 1)], 33, 1).max_rozdil_m); nsevu += 1
			for u in 33:
				for v in 33:
					sproti_bloku = maxf(sproti_bloku, absf(s[u * 33 + v] - blok[(a * 32 + u) * n + c * 32 + v]))
	# šev přes sopku 1: blok se středem sopky a soused vpravo
	var s0: Dictionary = svet.sopky[0]
	var vb := Vector2i(floori(float(s0.x) / 128.0), floori(float(s0.y) / 128.0))
	var va := B.rohy(svet, B.origin(svet, vb), 128.0, krok)
	var vc := B.rohy(svet, B.origin(svet, vb + Vector2i(1, 0)), 128.0, krok)
	var vs := _sev(va, vc, n, 0)
	# profil přes šev prostředního bloku (x = 256 m ve výchozím světě, y = střed), 20 m na každou stranu, z obou bloků
	var prof := {"x_m": [], "z_m": [], "blok": []}
	var bl: PackedFloat64Array = bloky[bs + Vector2i(0, 1)]; var br: PackedFloat64Array = bloky[bs + Vector2i(1, 1)]
	var jmid := 256
	for i in range(n - 81, n):
		prof.x_m.append(st.x + 128.0 + (i - (n - 1)) * krok); prof.z_m.append(bl[i * n + jmid]); prof.blok.append(0)
	for i in range(0, 81):
		prof.x_m.append(st.x + 128.0 + i * krok); prof.z_m.append(br[i * n + jmid]); prof.blok.append(1)
	out["spojitost"] = {"krok_m": krok, "sevu_bloku": sevy.size(), "max_rozdil_bloky_m": mx, "sevy": sevy,
		"sevu_segmentu": nsevu, "max_rozdil_segmenty_m": smx, "max_rozdil_segment_proti_bloku_m": sproti_bloku,
		"sev_pres_sopku": vs, "sev_pres_sopku_bloky": [vb, vb + Vector2i(1, 0)], "profil": prof,
		"ms_9_bloku_rohy_025": ms_bloky, "ms_256_segmentu_rohy_025": ms_seg}
	# pro sklony: rohy výchozího světa
	_rohy_start = bloky
	var ch := 0
	if mx != 0.0 or smx != 0.0 or sproti_bloku != 0.0 or float(vs.max_rozdil_m) != 0.0: ch = 1
	print("spojitost: bloky max ", mx, " m, segmenty ", smx, " m, segment↔blok ", sproti_bloku, ", přes sopku ", vs.max_rozdil_m)
	return ch

var _rohy_start := {}

# ------------------------------------------------------------ test 2
func _sklony_okna(svet, jmeno: String, mrizka: Callable, nx: int, krok: float, o: Vector2) -> Dictionary:
	# mrizka.call(i, j) → výška; sklon = centrální diference; strop = svet.strop_tan
	var hist := PackedInt64Array(); hist.resize(181)   # po 0,5° do 90°
	var vals := PackedFloat32Array()
	var mx := 0.0; var mx_pres := -1e9; var nad := 0; var n := 0; var kde := Vector2.ZERO
	for i in range(1, nx - 1):
		for j in range(1, nx - 1):
			var gx: float = (mrizka.call(i + 1, j) - mrizka.call(i - 1, j)) / (2.0 * krok)
			var gy: float = (mrizka.call(i, j + 1) - mrizka.call(i, j - 1)) / (2.0 * krok)
			var g := sqrt(gx * gx + gy * gy)
			var deg := rad_to_deg(atan(g))
			hist[mini(180, int(deg * 2.0))] += 1
			n += 1
			if (i % 4) == 0 and (j % 4) == 0: vals.append(deg)
			var x := o.x + i * krok; var y := o.y + j * krok
			if g > 0.0:
				var cap: float = svet.strop_tan(x, y)
				var pres := deg - rad_to_deg(atan(cap))
				if pres > mx_pres: mx_pres = pres; kde = Vector2(x, y)
				if pres > 0.0: nad += 1
			if deg > mx: mx = deg
	var cum := 0; var p50 := 0.0; var p95 := 0.0; var p99 := 0.0
	for b in 181:
		cum += hist[b]
		if p50 == 0.0 and cum >= n * 0.5: p50 = b * 0.5 + 0.25
		if p95 == 0.0 and cum >= n * 0.95: p95 = b * 0.5 + 0.25
		if p99 == 0.0 and cum >= n * 0.99: p99 = b * 0.5 + 0.25
	_uloz_bin("sklony_%s.f32" % jmeno, vals)
	return {"vzorku": n, "krok_m": krok, "p50_deg": p50, "p95_deg": p95, "p99_deg": p99, "max_deg": mx,
		"max_nad_stropem_deg": mx_pres, "kde_max_nad": kde, "vzorku_nad_stropem": nad, "hist_0_5deg": hist}

func _okno_vysky(svet, o: Vector2, delka: float, krok: float, tvar := false) -> PackedFloat64Array:
	if not tvar:
		return B.rohy(svet, o, delka, krok)
	var n := int(round(delka / krok)) + 1
	var outh := PackedFloat64Array(); outh.resize(n * n)
	for i in n:
		var x := o.x + i * krok
		for j in n:
			outh[i * n + j] = svet.vyska_tvar(x, o.y + j * krok)
	return outh

func _vzdalenost_od_ctverce(p: Vector2, a: Vector2, b: Vector2) -> float:
	var dx := 0.0
	if p.x < a.x: dx = a.x - p.x
	elif p.x > b.x: dx = p.x - b.x
	var dy := 0.0
	if p.y < a.y: dy = a.y - p.y
	elif p.y > b.y: dy = p.y - b.y
	return sqrt(dx * dx + dy * dy)

var _masiv_stred := Vector2.ZERO

func _sklony(svet) -> int:
	var res := {}
	var st: Vector2 = svet.start_m()
	var bs := Vector2i(st / 128.0)
	var n := 513
	# výchozí svět: přes bloky (0,25 m)
	var ok_n := 3 * 512 + 1
	var t0 := Time.get_ticks_usec()
	var get := func(i: int, j: int) -> float:
		var bi := mini(i / 512, 2); var bj := mini(j / 512, 2)
		var a: PackedFloat64Array = _rohy_start[bs + Vector2i(bi, bj)]
		return a[(i - bi * 512) * n + (j - bj * 512)]
	res["start"] = _sklony_okna(svet, "start", get, ok_n, 0.25, st)
	# okno přes sopku 1 a okno přes masiv (3 × 3 bloky = 384 m, 0,5 m)
	var s0: Dictionary = svet.sopky[0]
	var ov := Vector2(float(s0.x) - 192.0, float(s0.y) - 192.0)
	var av := _okno_vysky(svet, ov, 384.0, 0.5)
	res["sopka"] = _sklony_okna(svet, "sopka", func(i, j): return av[i * 769 + j], 769, 0.5, ov)
	var avt := _okno_vysky(svet, ov, 384.0, 0.5, true)
	res["sopka_tvar"] = _sklony_okna(svet, "sopka_tvar", func(i, j): return avt[i * 769 + j], 769, 0.5, ov)
	# masiv: bod mapy s největší váhou masivu (mřížka 32 m na celém světě)
	var best := -1.0
	for a in 128:
		for b in 128:
			var x := a * 32.0 + 16.0; var y := b * 32.0 + 16.0
			if x < 256.0 or y < 256.0 or x > 3840.0 or y > 3840.0: continue
			var w: PackedFloat64Array = svet.vahy(x, y)
			var m: float = svet._vaha_masivu(w[3])
			var sc := m * 1000.0 - Vector2(x, y).distance_to(Vector2(2048, 2048)) * 0.001
			if sc > best: best = sc; _masiv_stred = Vector2(x, y)
	var om := _masiv_stred - Vector2(192, 192)
	var am := _okno_vysky(svet, om, 384.0, 0.5)
	res["masiv"] = _sklony_okna(svet, "masiv", func(i, j): return am[i * 769 + j], 769, 0.5, om)
	var amt := _okno_vysky(svet, om, 384.0, 0.5, true)
	res["masiv_tvar"] = _sklony_okna(svet, "masiv_tvar", func(i, j): return amt[i * 769 + j], 769, 0.5, om)
	# celkový tvar výchozího světa (bez drobného detailu); ok_n = 3×512+1 rohů, ne n jednoho bloku (513)
	var start_tvar := PackedFloat64Array(); start_tvar.resize(ok_n * ok_n)
	for i in ok_n:
		for j in ok_n:
			start_tvar[i * ok_n + j] = svet.vyska_tvar(st.x + i * 0.25, st.y + j * 0.25)
	res["start_tvar"] = _sklony_okna(svet, "start_tvar", func(i, j): return start_tvar[i * ok_n + j], ok_n, 0.25, st)
	res["masiv_stred"] = _masiv_stred
	res["ms"] = _ms(t0)
	# kvantovaná výška (buňka 0,25 m) jen pro informaci: sklon přes 2 m z výšek zaokrouhlených na 0,25 m
	var qmax := 0.0
	for i in range(8, ok_n - 8, 4):
		for j in range(8, ok_n - 8, 4):
			var q := func(a, b): return roundf(get.call(a, b) / 0.25) * 0.25
			var gx: float = (q.call(i + 4, j) - q.call(i - 4, j)) / 2.0
			var gy: float = (q.call(i, j + 4) - q.call(i, j - 4)) / 2.0
			qmax = maxf(qmax, rad_to_deg(atan(sqrt(gx * gx + gy * gy))))
	res["start_kvantovano_025_pres_2m_max_deg"] = qmax
	var tol := 1.0
	res["tolerance_deg"] = tol
	out["sklony"] = res
	var ch := 0
	for k in ["start", "sopka", "masiv", "start_tvar", "sopka_tvar", "masiv_tvar"]:
		var r: Dictionary = res[k]
		print("sklony %s: p50 %.1f° p95 %.1f° max %.1f°, max nad stropem %.2f° (%d vzorků)" % [k, r.p50_deg, r.p95_deg, r.max_deg, r.max_nad_stropem_deg, r.vzorku_nad_stropem])
	# kritérium: celkový tvar pod váženým stropem; povrch s detailem se jen zaznamená
	for k in ["start_tvar", "sopka_tvar", "masiv_tvar"]:
		if float(res[k].max_nad_stropem_deg) > tol: ch += 1
	return ch

# ------------------------------------------------------------ test 3
func _sopky(svet) -> int:
	var r := {"pocet": svet.sopky.size(), "pocet_parametr": int(svet.p.sopek), "roztece_m": [], "sopky": []}
	var ch := 0
	if r.pocet != r.pocet_parametr: ch += 1
	var d := float(svet.p.sopky_roztec_m); var tol := float(svet.p.sopky_roztec_tol)
	for i in svet.sopky.size():
		for j in range(i + 1, svet.sopky.size()):
			var a: Dictionary = svet.sopky[i]; var b: Dictionary = svet.sopky[j]
			r.roztece_m.append(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)))
	# rozteč = vzdálenost k nejbližší jiné sopce
	for i in svet.sopky.size():
		var a: Dictionary = svet.sopky[i]
		var nej := 1e9
		for j in svet.sopky.size():
			if i == j: continue
			var b: Dictionary = svet.sopky[j]
			nej = minf(nej, Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)))
		var okraj: float = svet.strop_povrchu_m
		# vrchol: max výšky v kruhu rc + 3 m po 0,25 m; kráter: výška ve středu proti okraji
		var rc := float(a.rc)
		var vrchol := -1e9; var kde := Vector2.ZERO
		var k := int(ceil((rc + 3.0) / 0.25))
		for u in range(-k, k + 1):
			for v in range(-k, k + 1):
				var x := float(a.x) + u * 0.25; var y := float(a.y) + v * 0.25
				var h: float = svet.vyska(x, y)
				if h > vrchol: vrchol = h; kde = Vector2(x, y)
		var stred: float = svet.vyska(float(a.x), float(a.y))
		var r_vrcholu := kde.distance_to(Vector2(a.x, a.y))
		var hloubka := vrchol - stred
		var okoli := float(a.vyska_okoli)
		var st3: Vector2 = svet.start_m()
		var c3 := st3 + Vector2(192, 192)
		var e := {"x": a.x, "y": a.y, "H_m": a.H, "H_seed_m": a.H_seed, "prumer_upati_m": a.prumer_upati_m,
			"vrchol_m": vrchol, "strop_m": okraj, "pod_okrajem_sloupce_m": float(svet.sloupec_m) - vrchol,
			"krater_hloubka_m": hloubka, "krater_r_m": rc, "r_nejvyssiho_bodu_m": r_vrcholu, "nejblizsi_m": nej,
			"vyska_nad_okolim_m": vrchol - okoli,
			"vzdalenost_od_stredu_3x3_m": Vector2(a.x, a.y).distance_to(c3),
			"vzdalenost_od_okraje_3x3_m": _vzdalenost_od_ctverce(Vector2(a.x, a.y), st3, st3 + Vector2(384, 384))}
		var ok := vrchol <= okraj + 1e-9 and hloubka >= 1.0 and r_vrcholu <= rc + 1.0
		if svet.sopky.size() > 1: ok = ok and absf(nej - d) <= d * tol
		e["prošlo"] = ok
		if not ok: ch += 1
		# řez osou x přes střed, ±(R + 40) m po 0,5 m
		var rez := {"x_m": [], "z_m": []}
		var L := float(a.R) + 40.0
		var t := -L
		while t <= L:
			rez.x_m.append(t); rez.z_m.append(svet.vyska(float(a.x) + t, float(a.y))); t += 0.5
		e["rez"] = rez
		r.sopky.append(e)
		print("sopka %d: H %.1f m, vrchol %.2f m (strop %.1f), kráter %.2f m, nejbližší %.0f m, od středu 3×3 %.0f m (od okraje %.0f m), %s" % [i, a.H, vrchol, okraj, hloubka, nej, e.vzdalenost_od_stredu_3x3_m, e.vzdalenost_od_okraje_3x3_m, "OK" if ok else "CHYBA"])
	var nejbliz_okraj := 1e9
	var nejbliz_stred := 1e9
	for e2 in r.sopky:
		nejbliz_okraj = minf(nejbliz_okraj, float(e2.vzdalenost_od_okraje_3x3_m))
		nejbliz_stred = minf(nejbliz_stred, float(e2.vzdalenost_od_stredu_3x3_m))
	r["nejblizsi_od_okraje_3x3_m"] = nejbliz_okraj
	r["nejblizsi_od_stredu_3x3_m"] = nejbliz_stred
	# aspoň jedna sopka těsně u výchozího 3 × 3 (na obvodu nebo blíž)
	if nejbliz_okraj > float(svet.p.sopka_od_okraje_startu_m) + 20.0:
		ch += 1
		print("CHYBA: žádná sopka není u výchozího 3 × 3 (nejbližší od okraje %.0f m)" % nejbliz_okraj)
	out["sopky_test"] = r
	return ch

# ------------------------------------------------------------ test 4
func _mapa_svet(svet, tag: String, krok: float) -> Dictionary:
	var n := int(4096.0 / krok)
	var w5 := PackedFloat32Array(); w5.resize(n * n * 5)
	var hh := PackedFloat32Array(); hh.resize(n * n)
	var rgb := PackedFloat32Array(); rgb.resize(n * n * 3)
	var dom := PackedFloat32Array(); dom.resize(n * n)
	var t0 := Time.get_ticks_usec()
	for i in n:
		for j in n:
			var x := (i + 0.5) * krok; var y := (j + 0.5) * krok
			var w: PackedFloat64Array = svet.vahy(x, y)
			for t in 5: w5[(i * n + j) * 5 + t] = w[t]
			hh[i * n + j] = svet.vyska_w(x, y, w)
			var hr: Array = svet.horniny(x, y, w)
			var c := Color(0, 0, 0)
			for e in hr:
				var col: Color = _barvy.get(int(e[0]), Color(1, 0, 1))
				c += col * float(e[1])
			rgb[(i * n + j) * 3] = c.r; rgb[(i * n + j) * 3 + 1] = c.g; rgb[(i * n + j) * 3 + 2] = c.b
			dom[i * n + j] = float(hr[0][0])
	_uloz_bin("biomy_%s.f32" % tag, w5); _uloz_bin("vysky_%s.f32" % tag, hh); _uloz_bin("horniny_rgb_%s.f32" % tag, rgb)
	_uloz_bin("horniny_dom_%s.f32" % tag, dom)
	return {"n": n, "krok_m": krok, "ms": _ms(t0), "dom": dom, "w5": w5}

var _barvy := {}

## souvislé oblasti převažujícího biomu (4-sousedé) na mřížce vah
func _oblasti(w5: PackedFloat32Array, n: int, krok: float) -> Dictionary:
	var videl := PackedByteArray(); videl.resize(n * n)
	var plochy := []
	var typy := []
	for i in n:
		for j in n:
			var i0 := i * n + j
			if videl[i0] == 1: continue
			var typ := 0
			for t in 5:
				if w5[i0 * 5 + t] > w5[i0 * 5 + typ]: typ = t
			var fronta := PackedInt32Array(); fronta.append(i0)
			videl[i0] = 1
			var qi := 0
			var bunek := 0
			while qi < fronta.size():
				var cur := int(fronta[qi]); qi += 1
				bunek += 1
				var ci := int(cur / n); var cj := cur % n
				for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
					var ni: int = ci + int(d[0]); var nj: int = cj + int(d[1])
					if ni < 0 or nj < 0 or ni >= n or nj >= n: continue
					var nk := ni * n + nj
					if videl[nk] == 1: continue
					var nt := 0
					for t2 in 5:
						if w5[nk * 5 + t2] > w5[nk * 5 + nt]: nt = t2
					if nt != typ: continue
					videl[nk] = 1
					fronta.append(nk)
			plochy.append(float(bunek) * krok * krok)
			typy.append(typ)
	plochy.sort()
	var m := plochy.size()
	var soucet := 0.0
	for v in plochy: soucet += float(v)
	var med := 0.0
	if m > 0:
		var mid := int(m / 2)
		if m % 2 == 1: med = float(plochy[mid])
		else: med = 0.5 * (float(plochy[mid - 1]) + float(plochy[mid]))
	return {"ulomku": m, "median_plocha_m2": med, "median_prumer_m": sqrt(med) if med > 0.0 else 0.0,
		"prumer_plocha_m2": (soucet / m if m > 0 else 0.0), "prumer_prumer_m": (sqrt(soucet / m) if m > 0 else 0.0),
		"min_plocha_m2": (float(plochy[0]) if m > 0 else 0.0), "max_plocha_m2": (float(plochy[m - 1]) if m > 0 else 0.0),
		"krok_m": krok}

func _mapy(svet) -> int:
	var M = load("res://scripts/v1/materialy.gd")
	var tab: Dictionary = M.nacti()
	for id in tab.podle_id: _barvy[int(id)] = tab.podle_id[id].barva
	var res := {}
	var a := _mapa_svet(svet, "s%d_4096" % svet.sd, 8.0)
	var svet2 = S.new({"seed": svet.sd + 1})
	var b := _mapa_svet(svet2, "s%d_4096" % svet2.sd, 8.0)
	res["sopky_seed2"] = svet2.sopky
	res["biom_slouceni_seed_b"] = svet2.biom_slouceni
	res["oblasti_seed_a"] = _oblasti(a.w5, a.n, 8.0)
	res["oblasti_seed_b"] = _oblasti(b.w5, b.n, 8.0)
	# srovnání: stejné seedy s přepínačem biom_velke_oblasti (výchozí test běží s vypnutým)
	var av := _mapa_svet(S.new({"seed": svet.sd, "biom_velke_oblasti": true}), "s%d_4096_velke" % svet.sd, 8.0)
	var bv := _mapa_svet(S.new({"seed": svet2.sd, "biom_velke_oblasti": true}), "s%d_4096_velke" % svet2.sd, 8.0)
	res["oblasti_velke_seed_a"] = _oblasti(av.w5, av.n, 8.0)
	res["oblasti_velke_seed_b"] = _oblasti(bv.w5, bv.n, 8.0)
	print("oblasti výchozí seed %d: %d úlomků, medián √ %.0f m; seed %d: %d úlomků, medián √ %.0f m" % [
		svet.sd, res.oblasti_seed_a.ulomku, res.oblasti_seed_a.median_prumer_m,
		svet2.sd, res.oblasti_seed_b.ulomku, res.oblasti_seed_b.median_prumer_m])
	print("oblasti velké seed %d: %d úlomků, medián √ %.0f m; seed %d: %d úlomků, medián √ %.0f m" % [
		svet.sd, res.oblasti_velke_seed_a.ulomku, res.oblasti_velke_seed_a.median_prumer_m,
		svet2.sd, res.oblasti_velke_seed_b.ulomku, res.oblasti_velke_seed_b.median_prumer_m])
	# různé seedy: podíl buněk s jiným převažujícím biomem / horninou
	var n: int = a.n
	var jiny_b := 0; var jiny_h := 0; var podily := [0, 0, 0, 0, 0]
	for i in n * n:
		var ba := 0; var bb := 0
		for t in 5:
			if a.w5[i * 5 + t] > a.w5[i * 5 + ba]: ba = t
			if b.w5[i * 5 + t] > b.w5[i * 5 + bb]: bb = t
		podily[ba] += 1
		if ba != bb: jiny_b += 1
		if a.dom[i] != b.dom[i]: jiny_h += 1
	for t in 5: podily[t] = float(podily[t]) / (n * n)
	res["ruzne_seedy"] = {"seed_a": svet.sd, "seed_b": svet2.sd, "jiny_biom_podil": float(jiny_b) / (n * n), "jina_hornina_podil": float(jiny_h) / (n * n)}
	res["podil_biomu_mapa"] = podily
	res["podil_parametr"] = svet.p.podil
	res["ms_mapa_4096_po_8m"] = a.ms
	# plynulost: 8 příček přes celý svět po 1 m, max změna vah biomů a koncentrací hornin na 1 m
	var max_dw := 0.0; var max_dh := 0.0; var max_dz := 0.0
	for k in 8:
		var y := 256.0 + k * 480.0 + 0.37
		var pw: PackedFloat64Array = svet.vahy(0.5, y); var ph := _konc(svet, 0.5, y); var pz: float = svet.vyska(0.5, y)
		var x := 1.5
		while x < 4096.0:
			var w: PackedFloat64Array = svet.vahy(x, y)
			for t in 5: max_dw = maxf(max_dw, absf(w[t] - pw[t]))
			var hc := _konc(svet, x, y)
			for id in hc: max_dh = maxf(max_dh, absf(float(hc[id]) - float(ph.get(id, 0.0))))
			for id in ph: if not hc.has(id): max_dh = maxf(max_dh, float(ph[id]))
			var z: float = svet.vyska_w(x, y, w)
			max_dz = maxf(max_dz, absf(z - pz))
			pw = w; ph = hc; pz = z; x += 1.0
	res["plynulost"] = {"max_zmena_vahy_biomu_na_1m": max_dw, "max_zmena_koncentrace_horniny_na_1m": max_dh,
		"max_zmena_vysky_na_1m": max_dz, "mez_vahy_na_1m": 0.05, "mez_koncentrace_na_1m": 0.05}
	# výřez 3 × 3 po 1 m (biomy, horniny, výšky)
	var st: Vector2 = svet.start_m()
	var nn := 384
	var w5 := PackedFloat32Array(); w5.resize(nn * nn * 5)
	var rgb := PackedFloat32Array(); rgb.resize(nn * nn * 3)
	var hh := PackedFloat32Array(); hh.resize(nn * nn)
	for i in nn:
		for j in nn:
			var x := st.x + i + 0.5; var y := st.y + j + 0.5
			var w: PackedFloat64Array = svet.vahy(x, y)
			for t in 5: w5[(i * nn + j) * 5 + t] = w[t]
			hh[i * nn + j] = svet.vyska_w(x, y, w)
			var c := Color(0, 0, 0)
			for e in svet.horniny(x, y, w): c += _barvy.get(int(e[0]), Color(1, 0, 1)) * float(e[1])
			rgb[(i * nn + j) * 3] = c.r; rgb[(i * nn + j) * 3 + 1] = c.g; rgb[(i * nn + j) * 3 + 2] = c.b
	_uloz_bin("biomy_start.f32", w5); _uloz_bin("horniny_rgb_start.f32", rgb); _uloz_bin("vysky_start_1m.f32", hh)
	# okna sopky a masivu po 1 m (výšky) pro stínovaný reliéf
	for nm in ["sopka", "masiv"]:
		var c0: Vector2 = Vector2(svet.sopky[0].x, svet.sopky[0].y) if nm == "sopka" else _masiv_stred
		var o := c0 - Vector2(192, 192)
		var hw := PackedFloat32Array(); hw.resize(nn * nn)
		var mw := PackedFloat32Array(); mw.resize(nn * nn)
		for i in nn:
			for j in nn:
				var w: PackedFloat64Array = svet.vahy(o.x + i + 0.5, o.y + j + 0.5)
				hw[i * nn + j] = svet.vyska_w(o.x + i + 0.5, o.y + j + 0.5, w)
				mw[i * nn + j] = svet._vaha_masivu(w[3])
		_uloz_bin("vysky_%s_1m.f32" % nm, hw); _uloz_bin("masiv_vaha_%s_1m.f32" % nm, mw)
		res["okno_" + nm] = o
	# řez masivem (osa x přes střed, ±192 m po 0,5 m) s vahou masivu
	var rez := {"x_m": [], "z_m": [], "masiv": [], "hornatina": []}
	var t := -192.0
	while t <= 192.0:
		var x := _masiv_stred.x + t
		var w: PackedFloat64Array = svet.vahy(x, _masiv_stred.y)
		rez.x_m.append(t); rez.z_m.append(svet.vyska_w(x, _masiv_stred.y, w)); rez.masiv.append(svet._vaha_masivu(w[3])); rez.hornatina.append(w[3])
		t += 0.5
	res["rez_masiv"] = rez
	res["start_m"] = st
	out["mapy"] = res
	var ch := 0
	if max_dw > 0.05 or max_dh > 0.05: ch += 1
	if float(res.ruzne_seedy.jiny_biom_podil) < 0.2: ch += 1
	print("mapy: Δváha/m %.4f, Δhornina/m %.4f, Δz/m %.3f, jiný biom (seed+1) %.1f %%" % [max_dw, max_dh, max_dz, 100.0 * res.ruzne_seedy.jiny_biom_podil])
	return ch

func _konc(svet, x: float, y: float) -> Dictionary:
	var d := {}
	for e in svet.horniny(x, y): d[int(e[0])] = float(e[1])
	return d

# ------------------------------------------------------------ test 6
func _cas(svet) -> void:
	var r := {}
	var st: Vector2 = svet.start_m()
	var t0 := Time.get_ticks_usec()
	for i in 20000: svet.vyska(st.x + (i * 37 % 384) + 0.3, st.y + (i * 91 % 384) + 0.7)
	r["vyska_us"] = _ms(t0) * 1000.0 / 20000.0
	t0 = Time.get_ticks_usec()
	for i in 20000: svet.sloupec(st.x + (i * 37 % 384) + 0.3, st.y + (i * 91 % 384) + 0.7)
	r["sloupec_us"] = _ms(t0) * 1000.0 / 20000.0
	t0 = Time.get_ticks_usec()
	for i in 20000: svet.bod(st.x + (i * 37 % 384) + 0.3, st.y + (i * 91 % 384) + 0.7, 70.0)
	r["bod_us"] = _ms(t0) * 1000.0 / 20000.0
	for k in [0.25, 0.5, 1.0]:
		t0 = Time.get_ticks_usec()
		B.stredy(svet, st + Vector2(128, 128), 128.0, k)
		r["blok128_%s_ms" % str(k)] = _ms(t0)
	var s0: Dictionary = svet.sopky[0]
	t0 = Time.get_ticks_usec()
	B.stredy(svet, Vector2(floorf(float(s0.x) / 128.0), floorf(float(s0.y) / 128.0)) * 128.0, 128.0, 0.5)
	r["blok128_sopka_0.5_ms"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	B.stredy(svet, Vector2(512, 512), 3072.0, 4.0)
	r["mapa_3km_po_4m_ms"] = _ms(t0)
	r["e90_3km_ms"] = 4900.0
	r["init_ms"] = out.init_ms
	out["cas"] = r
	print("čas: ", JSON.stringify(r))

# ------------------------------------------------------------ test 2 na celém světě
func _sklony_svet(svet) -> int:
	var krok := float(_arg("krok", "4")); var e := 0.25
	var n := int(4096.0 / krok)
	var hist := PackedInt64Array(); hist.resize(181)
	var hist_t := PackedInt64Array(); hist_t.resize(181)
	var mx := 0.0; var mxp := -1e9; var kde := Vector2.ZERO; var nad := 0; var cnt := 0
	var mx_t := 0.0; var mxp_t := -1e9; var kde_t := Vector2.ZERO; var nad_t := 0
	var podle_biomu := [0.0, 0.0, 0.0, 0.0, 0.0]
	var podle_biomu_t := [0.0, 0.0, 0.0, 0.0, 0.0]
	var t0 := Time.get_ticks_usec()
	for i in n:
		for j in n:
			var x := (i + 0.5) * krok; var y := (j + 0.5) * krok
			var cap := rad_to_deg(atan(svet.strop_tan(x, y)))
			var gx_t: float = (svet.vyska_tvar(x + e, y) - svet.vyska_tvar(x - e, y)) / (2.0 * e)
			var gy_t: float = (svet.vyska_tvar(x, y + e) - svet.vyska_tvar(x, y - e)) / (2.0 * e)
			var deg_t := rad_to_deg(atan(sqrt(gx_t * gx_t + gy_t * gy_t)))
			var gx: float = (svet.vyska(x + e, y) - svet.vyska(x - e, y)) / (2.0 * e)
			var gy: float = (svet.vyska(x, y + e) - svet.vyska(x, y - e)) / (2.0 * e)
			var deg := rad_to_deg(atan(sqrt(gx * gx + gy * gy)))
			hist[mini(180, int(deg * 2.0))] += 1
			hist_t[mini(180, int(deg_t * 2.0))] += 1
			cnt += 1
			mx = maxf(mx, deg)
			mx_t = maxf(mx_t, deg_t)
			var w: PackedFloat64Array = svet.vahy(x, y)
			var bi := 0
			for t in 5: if w[t] > w[bi]: bi = t
			podle_biomu[bi] = maxf(podle_biomu[bi], deg)
			podle_biomu_t[bi] = maxf(podle_biomu_t[bi], deg_t)
			var pr := deg - cap
			if pr > mxp: mxp = pr; kde = Vector2(x, y)
			if pr > 0.0: nad += 1
			var pr_t := deg_t - cap
			if pr_t > mxp_t: mxp_t = pr_t; kde_t = Vector2(x, y)
			if pr_t > 0.0: nad_t += 1
	var cum := 0; var p50 := 0.0; var p95 := 0.0
	var cum_t := 0; var p50_t := 0.0; var p95_t := 0.0
	for b in 181:
		cum += hist[b]
		cum_t += hist_t[b]
		if p50 == 0.0 and cum >= cnt * 0.5: p50 = b * 0.5 + 0.25
		if p95 == 0.0 and cum >= cnt * 0.95: p95 = b * 0.5 + 0.25
		if p50_t == 0.0 and cum_t >= cnt * 0.5: p50_t = b * 0.5 + 0.25
		if p95_t == 0.0 and cum_t >= cnt * 0.95: p95_t = b * 0.5 + 0.25
	out["sklony_svet"] = {"krok_m": krok, "diference_m": e, "vzorku": cnt, "p50_deg": p50, "p95_deg": p95, "max_deg": mx,
		"max_podle_prevazujiciho_biomu_deg": podle_biomu, "max_nad_stropem_deg": mxp, "kde": kde, "vzorku_nad_stropem": nad,
		"hist_0_5deg": hist, "ms": _ms(t0),
		"tvar": {"p50_deg": p50_t, "p95_deg": p95_t, "max_deg": mx_t,
			"max_podle_prevazujiciho_biomu_deg": podle_biomu_t, "max_nad_stropem_deg": mxp_t, "kde": kde_t,
			"vzorku_nad_stropem": nad_t, "hist_0_5deg": hist_t}}
	print("sklony svět (s detailem): p50 %.1f p95 %.1f max %.1f, nad stropem max %.2f° (%d vzorků)" % [p50, p95, mx, mxp, nad])
	print("sklony svět (tvar bez detailu): p50 %.1f p95 %.1f max %.1f, nad stropem max %.2f° (%d vzorků), biomy %s, %.0f s" % [p50_t, p95_t, mx_t, mxp_t, nad_t, str(podle_biomu_t), _ms(t0) / 1000.0])
	return 1 if mxp_t > 1.0 else 0

# ------------------------------------------------------------ test 7 klima
func _otisk_vyrezu(svet, krok: float) -> Dictionary:
	var o: Vector2 = svet.start_m()
	var a: PackedFloat64Array = B.stredy(svet, o, 384.0, krok)
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256); hc.update(a.to_byte_array())
	var hx: String = hc.finish().hex_encode()
	var mn := 1e9; var mx := -1e9
	for v in a: mn = minf(mn, v); mx = maxf(mx, v)
	return {"sha256": hx, "otisk": hx.substr(0, 16), "bunek": a.size(), "min_m": mn, "max_m": mx, "krok_m": krok}

func _klima_overeni(svet) -> int:
	var chyb := 0
	if svet.klima_id != "mirne" or svet.klima_ze_seedu:
		print("klima: výchozí běh nemá mirne (id=", svet.klima_id, " ze_seedu=", svet.klima_ze_seedu, ")")
		chyb += 1
	var kw: PackedFloat64Array = svet.klima_vahy(svet.start_m().x + 192.0, svet.start_m().y + 192.0)
	var w0 := 0.0
	if svet.klima_idx >= 0 and svet.klima_idx < kw.size(): w0 = kw[svet.klima_idx]
	if absf(w0 - 1.0) > 1e-12:
		print("klima: háček vah není jednotný při mirne (", w0, ")")
		chyb += 1
	var t0 := Time.get_ticks_usec()
	var zakl := _otisk_vyrezu(svet, 1.0)
	var poust_a = S.new({"seed": svet.sd, "klima": "poust"})
	var poust_b = S.new({"seed": svet.sd, "klima": "poust"})
	var pa := _otisk_vyrezu(poust_a, 1.0)
	var pb := _otisk_vyrezu(poust_b, 1.0)
	var ms := _ms(t0)
	var zmena := pa.otisk != zakl.otisk
	var shoda := pa.sha256 == pb.sha256
	if not zmena:
		print("klima: poust nezměnila výřez (otisk ", pa.otisk, ")")
		chyb += 1
	if not shoda:
		print("klima: poust není deterministická: ", pa.otisk, " vs ", pb.otisk)
		chyb += 1
	out["klima"] = {"vychozi_id": svet.klima_id, "ze_seedu": svet.klima_ze_seedu, "mirne_1m": zakl,
		"poust_1m_a": pa, "poust_1m_b": pb, "poust_zmena": zmena, "poust_shoda": shoda, "ms": ms,
		"k_voda": svet.p.get("klima_k_voda", 1.0), "podil": svet.p.podil}
	print("klima: výchozí ", svet.klima_id, ", poust ", pa.otisk, (" ≠ " if zmena else " == "), "mirne ", zakl.otisk, ", 2× shoda=", shoda, " ", ms, " ms")
	return chyb

func _klima_srovnani(sd: int) -> int:
	var chyb := 0
	var ids := ["mirne", "poust", "ledovec"]
	var rec: Array = []
	for id in ids:
		var t0 := Time.get_ticks_usec()
		var s = S.new({"seed": sd, "klima": id})
		var init_ms := _ms(t0)
		var m: Dictionary = _mapa_svet(s, "s%d_4096_klima_%s" % [sd, id], 8.0)
		var ot := _otisk_vyrezu(s, 1.0)
		rec.append({"id": id, "nazev": s.p.get("klima_nazev", id), "priklad": bool(s.p.get("klima_priklad", false)),
			"podil": s.p.podil, "otisk_1m": ot, "init_ms": init_ms, "mapa_ms": m.ms,
			"k_prevyseni": float(s.p.biomy[3].prevyseni_m), "klima_k_voda": s.p.get("klima_k_voda", 1.0)})
		print("klima_srovnani: ", id, " otisk ", ot.otisk, " mapa ", m.ms, " ms")
	if rec[0]["otisk_1m"]["otisk"] == rec[1]["otisk_1m"]["otisk"]:
		print("klima_srovnani: poust má stejný otisk jako mirne"); chyb += 1
	if rec[0]["otisk_1m"]["otisk"] == rec[2]["otisk_1m"]["otisk"]:
		print("klima_srovnani: ledovec má stejný otisk jako mirne"); chyb += 1
	out["klima_srovnani"] = rec
	out["chyb"] = chyb
	return chyb
