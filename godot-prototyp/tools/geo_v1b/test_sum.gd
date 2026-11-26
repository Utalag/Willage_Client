extends RefCounted
## A10: parametry šumu mocnosti podle horniny platí (tabulka čtená nezávisle), měřená amplituda a četnost
## zlomů odpovídají parametrům, řádek 180 m / 1,0 / 1 oktáva je bitově původní pole.
const S = preload("res://scripts/v1/svet_fn.gd")

func _legacy(svet, ucel: String, k: int, x: float, y: float) -> float:
	var s := 180.0
	var i0 := floori(x / s); var j0 := floori(y / s)
	var tx := x / s - i0; var ty := y / s - j0
	tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = svet._u(ucel, i0, j0, k); var b: float = svet._u(ucel, i0 + 1, j0, k)
	var c: float = svet._u(ucel, i0, j0 + 1, k); var d: float = svet._u(ucel, i0 + 1, j0 + 1, k)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

func _tabulka() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://data/v1/sum_hornin_v1.csv", FileAccess.READ)
	var h := f.get_csv_line()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 7 or not String(r[1]).is_valid_int(): continue
		out[int(r[1])] = {"key": r[0], "meritko_m": float(r[h.find("meritko_m")]), "amplituda": float(r[h.find("amplituda")]),
			"oktavy": int(r[h.find("oktavy")]), "persistence": float(r[h.find("persistence")])}
	return out

func run(par: Dictionary, delka_m := 8192.0, krok_m := 4.0) -> Dictionary:
	var chyb := 0
	var svet = S.new(par)
	var sum = svet.geo.sum
	var tab := _tabulka()
	var res := {"radky": {}, "chyby": []}
	# (a) parametry = tabulka, každá vrstvová hornina katalogu má řádek
	var bez := 0
	for r in svet.geo.katalog:
		if not (String(r.get("kind", "layer")) in ["layer", "seam", "soil"]): continue
		if not tab.has(int(r.id)): bez += 1; continue
		var p: Dictionary = sum.parametry(int(r.id))
		var t: Dictionary = tab[int(r.id)]
		for k in ["meritko_m", "amplituda", "persistence"]:
			if absf(float(p[k]) - float(t[k])) > 1e-12: chyb += 1; res.chyby.append("param " + String(r.key) + " " + k)
		if int(p.oktavy) != int(t.oktavy): chyb += 1; res.chyby.append("param " + String(r.key) + " oktavy")
	res["bez_radku"] = bez
	if bez > 0: chyb += 1
	# (b) měření podél řezu: rozsah, počet průchodů střední hodnotou, drsnost
	var n := int(delka_m / krok_m)
	for id in tab:
		var t: Dictionary = tab[id]
		var idx := 0
		for r in svet.geo.katalog:
			if int(r.id) == int(id): idx = int(r.idx)
		var v := PackedFloat64Array(); v.resize(n)
		var mn := 1e9; var mx := -1e9; var sm := 0.0
		for i in n:
			v[i] = sum.mocnost_n01(int(id), idx, 1000.0 + i * krok_m, 3000.37)
			mn = minf(mn, v[i]); mx = maxf(mx, v[i]); sm += v[i]
		var mean := sm / n
		var cross := 0; var rough := 0.0; var var_s := 0.0
		for i in n:
			var_s += (v[i] - mean) * (v[i] - mean)
			if i > 0:
				rough += absf(v[i] - v[i - 1])
				if (v[i] - mean) * (v[i - 1] - mean) < 0.0: cross += 1
		var a := float(t.amplituda)
		var ok_rozsah := mn >= 0.5 - a * 0.5 - 1e-9 and mx <= 0.5 + a * 0.5 + 1e-9
		var ok_zivy := (mx - mn) >= 0.35 * a        # není degenerované pole
		if not ok_rozsah or not ok_zivy:
			chyb += 1; res.chyby.append("rozsah " + String(t.key))
		res.radky[String(t.key)] = {"id": id, "meritko_m": t.meritko_m, "amplituda": a, "oktavy": t.oktavy, "persistence": t.persistence,
			"min": mn, "max": mx, "std": sqrt(var_s / n), "pruchodu_na_km": cross / (delka_m / 1000.0),
			"drsnost_na_4m": rough / (n - 1), "ok_rozsah": ok_rozsah, "ok_zivy": ok_zivy}
	# (c) řazení: slepenec (hrubý) členitější než jílová břidlice; víc oktáv = větší drsnost při stejném měřítku
	var rr: Dictionary = res.radky
	var hrub: Dictionary = rr["conglomerate"]; var jem: Dictionary = rr["shale"]
	var o1 := absf(float(hrub.pruchodu_na_km)) > float(jem.pruchodu_na_km) and float(hrub.std) > float(jem.std)
	res["slepenec_vs_jilovec"] = {"slepenec_std": hrub.std, "jilovec_std": jem.std, "slepenec_pruchodu_km": hrub.pruchodu_na_km, "jilovec_pruchodu_km": jem.pruchodu_na_km, "ok": o1}
	if not o1: chyb += 1; res.chyby.append("slepenec není členitější než jílovec")
	# drobný detail: střední |druhá diference| na ~20 m (první diference by oktávy nerozlišila: sklon každé oktávy je při
	# persistenci 0,5 a lakunaritě 2 stejný)
	var f1 := PackedFloat64Array(); var f3 := PackedFloat64Array()
	for i in n:
		f1.append(sum.fbm("V1_THICK", 5, 1000.0 + i * krok_m, 3000.0, 120.0, 1, 0.5))
		f3.append(sum.fbm("V1_THICK", 5, 1000.0 + i * krok_m, 3000.0, 120.0, 3, 0.5))
	var r1 := 0.0; var r3 := 0.0
	for i in range(5, n - 5):
		r1 += absf(f1[i] - 0.5 * (f1[i - 5] + f1[i + 5]))
		r3 += absf(f3[i] - 0.5 * (f3[i - 5] + f3[i + 5]))
	r1 /= (n - 10); r3 /= (n - 10)
	var o2 := r3 > r1 * 1.2
	res["oktavy_detail"] = {"1_oktava": r1, "3_oktavy": r3, "ok": o2}
	if not o2: chyb += 1; res.chyby.append("oktavy nezvyšují detail")
	# (d) legacy řádek je bitově původní pole a přepínač a10 = vše LEGACY
	var odlisnych := 0
	for i in 2000:
		var x := 17.3 + i * 7.9; var y := 4000.1 - i * 3.3
		var nova: float = sum.fbm("V1_THICK", 7, x, y, 180.0, 1, 0.5)
		if nova != _legacy(svet, "V1_THICK", 7, x, y): odlisnych += 1
	res["legacy_odlisnych"] = odlisnych
	if odlisnych > 0: chyb += 1; res.chyby.append("legacy řádek není původní pole")
	var pv := par.duplicate(); pv["a10_sum_hornin"] = false
	var sv2 = S.new(pv)
	var ne := 0
	for id in tab:
		if sv2.geo.sum.parametry(int(id)) != sv2.geo.sum.LEGACY: ne += 1
	res["vypnuto_ne_legacy"] = ne
	if ne > 0: chyb += 1
	# (e) parametry se uplatní v geologii: změna tabulky změní hranice (amplituda 0 pro všechny vs. tabulka vs. LEGACY)
	var zmen_leg := 0; var zmen_a0 := 0; var vz := 0
	var s_leg = sv2
	var pa0 = S.new(par)
	for id in pa0.geo.sum.tabulka: pa0.geo.sum.tabulka[id].amplituda = 0.0
	for i in 64:
		for j in 8:
			var x := 1000.0 + i * 16.0 + 0.5; var y := 3000.0 + j * 16.0 + 0.5
			var h1: Array = svet.geo.hranice(x, y)
			var h2: Array = s_leg.geo.hranice(x, y)
			var h3: Array = pa0.geo.hranice(x, y)
			vz += 1
			if str(h1) != str(h2): zmen_leg += 1
			if str(h1) != str(h3): zmen_a0 += 1
	res["uplatneni"] = {"vzorku": vz, "jiny_nez_legacy": zmen_leg, "jiny_nez_amp0": zmen_a0}
	if zmen_leg == 0 or zmen_a0 == 0: chyb += 1; res.chyby.append("parametry se v geologii neuplatnily")
	# křivky pro obrázek: pole mocnosti vybraných hornin podél 1,5 km a původní jediná oktáva 180 m
	var kriv := {}
	for kl in ["shale", "granite", "quartzite", "cave_limestone", "quartz_sandstone", "conglomerate"]:
		var id := 0
		var idx := 0
		for r in svet.geo.katalog:
			if String(r.key) == kl: id = int(r.id); idx = int(r.idx)
		var pts := []
		for i in 375: pts.append(sum.mocnost_n01(id, idx, 1000.0 + i * 4.0, 3000.37))
		kriv[kl] = pts
		kriv[kl + "_legacy"] = []
		for i in 375: kriv[kl + "_legacy"].append(_legacy(svet, "V1_THICK", idx, 1000.0 + i * 4.0, 3000.37))
	res["krivky"] = kriv
	res["chyb"] = chyb
	print("A10 řádků ", tab.size(), " bez řádku ", bez, " | slepenec vs jílovec std ", hrub.std, " vs ", jem.std, " | oktavy detail ", res.oktavy_detail,
		" | legacy odlišných ", odlisnych, " | uplatnění ", res.uplatneni, " | chyb ", chyb)
	print("A10 ", "PROŠLO" if chyb == 0 else "SELHALO")
	return res
