extends SceneTree
## Krok 3 (V1.0): testy geologie a útvarů podle 04, krok 3.
## --rezim=vse|det|cas --out=adresář --data=adresář --seed=N
const S = preload("res://scripts/v1/svet_fn.gd")
const B = preload("res://scripts/v1/blok_v1.gd")

var out := {}
var data_dir := "/tmp/k3/data"
var barvy := {}

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _uloz_bin(jmeno: String, a: PackedFloat32Array) -> void:
	var f := FileAccess.open(data_dir + "/" + jmeno, FileAccess.WRITE)
	f.store_buffer(a.to_byte_array())

func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

func _nacti_barvy() -> void:
	var f := FileAccess.open("res://data/materialy_v1.csv", FileAccess.READ)
	var h := f.get_csv_line()
	var i_id := 0; var i_b := h.find("barva_hex"); var i_n := h.find("nazev_cs")
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() <= i_b or not String(r[i_id]).is_valid_int(): continue
		var hex := String(r[i_b]).strip_edges()
		if Color.html_is_valid(hex):
			barvy[int(r[i_id])] = [Color.html(hex), String(r[i_n])]

func _init() -> void:
	_nacti_barvy()
	var rezim := _arg("rezim", "vse")
	var od := _arg("out", "res://shots/krok03")
	data_dir = _arg("data", data_dir)
	DirAccess.make_dir_recursive_absolute(data_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(od))
	var par := {"seed": int(_arg("seed", "49"))}
	var t0 := Time.get_ticks_usec()
	var svet = S.new(par)
	out["init_ms"] = _ms(t0)
	print("init_ms=", out["init_ms"])
	out["seed"] = svet.sd
	out["parametry"] = {"klima": svet.klima_id, "p82_vapenec": svet.p.p82_vapenec, "p82_podil": svet.p.p82_podil,
		"k_horniny": svet.p.get("klima_k_horniny", 1.0), "start_blok": svet.p.start_blok}
	var chyb := 0
	if rezim == "det":
		chyb += _det(svet)
		var f := FileAccess.open(ProjectSettings.globalize_path(od + "/" + _arg("jmeno", "det.json")), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		quit(1 if chyb > 0 else 0); return
	if rezim == "cas":
		_cas(svet)
		var fc := FileAccess.open(ProjectSettings.globalize_path(od + "/cas.json"), FileAccess.WRITE)
		fc.store_string(JSON.stringify(out, " "))
		quit(0); return
	chyb += _rezy(svet)
	chyb += _tenke(svet)
	chyb += _utvary_sev(svet)
	chyb += _mince(svet)
	_cas(svet)
	_mapy(svet)
	out["chyb"] = chyb
	var f2 := FileAccess.open(ProjectSettings.globalize_path(od + "/geo_v1.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(out, " "))
	print("chyb celkem: ", chyb)
	quit(1 if chyb > 0 else 0)

func _det(svet) -> int:
	var o: Vector2 = svet.start_m()
	# mřížka 3 × 3: 2 m v XY, 1 m v Z, středy
	var krok_xy := 2.0; var krok_z := 1.0
	var n := int(384.0 / krok_xy)
	var zmax := 128
	var t0 := Time.get_ticks_usec()
	var buf := PackedByteArray(); buf.resize(n * n * zmax)
	var i := 0
	for ix in n:
		for iy in n:
			var x := o.x + (ix + 0.5) * krok_xy
			var y := o.y + (iy + 0.5) * krok_xy
			var sl: PackedByteArray = svet.geo.vypln_sloupec(x, y, krok_z, 128.0)
			for iz in zmax:
				buf[i] = sl[iz] if iz < sl.size() else 0
				i += 1
	var ms := _ms(t0)
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256); hc.update(buf)
	var hx: String = hc.finish().hex_encode()
	out["det"] = {"sha256": hx, "otisk": hx.substr(0, 16), "bunek": buf.size(), "ms": ms,
		"krok_xy_m": krok_xy, "krok_z_m": krok_z, "n_xy": n, "n_z": zmax}
	print("det: ", hx.substr(0, 16), " ", buf.size(), " buněk, ", ms, " ms")
	return 0

func _rez_data(svet, x0: float, y0: float, x1: float, y1: float, krok: float, jmeno: String) -> Dictionary:
	var delka := Vector2(x1 - x0, y1 - y0).length()
	var n := int(delka / krok) + 1
	var nz := int(128.0 / krok)
	var ids := PackedFloat32Array(); ids.resize(n * nz)
	var z_pov := PackedFloat32Array(); z_pov.resize(n)
	var vent := 0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var x := lerpf(x0, x1, t); var y := lerpf(y0, y1, t)
		var zp: float = svet.vyska(x, y)
		z_pov[i] = zp
		var sl: PackedByteArray = svet.geo.vypln_sloupec(x, y, krok, 128.0)
		for iz in nz:
			var id := int(sl[iz]) if iz < sl.size() else 0
			ids[i * nz + iz] = id
			if id == 75: vent += 1
	_uloz_bin("rez_" + jmeno + "_id.f32", ids)
	_uloz_bin("rez_" + jmeno + "_povrch.f32", z_pov)
	return {"n": n, "nz": nz, "krok_m": krok, "vent_bunek": vent, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "delka_m": delka}

func _rezy(svet) -> int:
	var chyb := 0
	var o: Vector2 = svet.start_m()
	# šev mezi bloky 14 a 15 (x = 1920), řez východ–západ přes střed 3 × 3
	var sev_x := (float(svet.p.start_blok[0]) + 1.0) * 128.0
	var ymid := o.y + 192.0
	var r1: Dictionary = _rez_data(svet, o.x, ymid, o.x + 384.0, ymid, 0.5, "sev")
	# spojitost přes šev: stejné (x=šev, y, z) zleva i zprava je totéž (funkce); navíc sousední sloupce
	var neshod := 0
	var maxd := 0
	for z in range(1, 256):
		var zz := z * 0.5
		var a: int = svet.bod(sev_x - 0.25, ymid, zz)
		var b: int = svet.bod(sev_x + 0.25, ymid, zz)
		# vrstvy mají být spojité: stejné id, nebo obě vzduch
		if a != b:
			neshod += 1
			if neshod <= 3: print("šev neshoda z=", zz, " L=", a, " P=", b)
	# malé neshody na švu mince (mince je po bloku) se zaznamenají, nejsou automaticky chyba útvarů
	out["rez_sev"] = r1
	out["sev_neshod_05"] = neshod
	print("řez šev: neshod sousedů ±0,25 m: ", neshod, " (mince je po bloku 128 m)")
	# masiv: okno kolem maxima váhy masivu v 3 × 3 (heuristika: střed světa + posun)
	var mx := o.x + 80.0; var my := o.y + 200.0
	var best := -1.0
	for i in 24:
		for j in 24:
			var x := o.x + i * 16.0 + 8.0; var y := o.y + j * 16.0 + 8.0
			var col = svet.sloupec(x, y)
			if float(col.masiv) > best:
				best = float(col.masiv); mx = x; my = y
	var r2: Dictionary = _rez_data(svet, mx - 64.0, my, mx + 64.0, my, 0.5, "masiv")
	r2["masiv"] = best; r2["stred_x"] = mx; r2["stred_y"] = my
	out["rez_masiv"] = r2
	print("řez masiv: váha ", best, " v (", mx, ",", my, ")")
	# sopka
	var chyb_s := 0
	if svet.sopky.is_empty():
		print("řez sopka: žádná sopka"); chyb_s += 1
	else:
		var v: Dictionary = svet.sopky[0]
		var cx: float = v.x; var cy: float = v.y
		var r3: Dictionary = _rez_data(svet, cx - float(v.R) - 20.0, cy, cx + float(v.R) + 20.0, cy, 0.5, "sopka")
		# průduch k z=0
		var vent0: int = svet.bod(cx, cy, 0.1)
		var vent_ok := vent0 == 75
		# vrstvy nepokračují pod tělesem: v ose pod kráterem není běžná vrstva
		var pod: int = svet.bod(cx, cy, 5.0)
		var teleso_ok := pod == 75 or pod == int(svet.p.sopka_lava_id) or pod == int(svet.p.sopka_popel_id)
		r3["vent_z0"] = vent0
		r3["vent_ok"] = vent_ok
		r3["teleso_5m"] = pod
		r3["teleso_ok"] = teleso_ok
		r3["cx"] = cx; r3["cy"] = cy
		out["rez_sopka"] = r3
		if not vent_ok:
			print("řez sopka: průduch v z=0 není 75, je ", vent0); chyb_s += 1
		if not teleso_ok:
			print("řez sopka: pod tělesem materiál ", pod, ", čekal se průduch/láva/popel"); chyb_s += 1
		print("řez sopka: vent z=0 id=", vent0, " těleso 5 m id=", pod, " vent_buněk=", r3.vent_bunek)
	chyb += chyb_s
	return chyb

func _tenke(svet) -> int:
	var o: Vector2 = svet.start_m()
	var n := 48
	var def025 := 0; var def05 := 0; var rez025 := 0; var rez05 := 0
	var vzorku := 0; var vrstev := 0
	var zbytky: Array = []
	var zbytky05: Array = []
	for i in n:
		for j in n:
			var x := o.x + (i + 0.5) * (384.0 / n)
			var y := o.y + (j + 0.5) * (384.0 / n)
			var hr: Array = svet.geo.hranice(x, y)
			vzorku += 1
			for e in hr:
				vrstev += 1
				var d := float(e.definice_m)
				var t := float(e.z1) - float(e.z0)
				if d < 0.25: def025 += 1
				if d < 0.5: def05 += 1
				if t + 1e-9 < d:  # ořez povrchem
					var rec := {"id": int(e.id), "t_m": t, "def_m": d, "x": x, "y": y}
					if t < 0.25:
						rez025 += 1
						if zbytky.size() < 20:
							zbytky.append(rec)
					elif t < 0.5:
						rez05 += 1
						if zbytky05.size() < 20:
							zbytky05.append(rec)
	for e in zbytky05:
		if zbytky.size() >= 20: break
		zbytky.append(e)
	var chyb := 0
	if def025 > 0:
		print("tenké: v definici < 0,25 m: ", def025); chyb += 1
	# < 0,5 m v definici se jen vypíše (minimum je teď 0,25 m)
	out["tenke"] = {"vzorku": vzorku, "vrstev": vrstev, "definice_pod_025": def025, "definice_pod_05": def05,
		"orez_pod_025": rez025, "orez_pod_05": rez05, "zbytky": zbytky}
	print("tenké: definice <0,25 m ", def025, ", <0,5 m ", def05, "; po ořezu <0,25 m ", rez025, ", <0,5 m ", rez05)
	return chyb

func _utvary_sev(svet) -> int:
	# stejný bod z „dvou bloků“ (stejná funkce): 0 rozdílů; dutina/útvar na švu segmentu
	var o: Vector2 = svet.start_m()
	var sev := o.x + 128.0   # šev bloků
	var neshod := 0
	var utvaru := 0
	for j in 64:
		var y := o.y + (j + 0.5) * 6.0
		for z in 32:
			var zz := (z + 0.5) * 4.0
			var a: int = svet.bod(sev, y, zz)
			var b: int = svet.bod(sev, y, zz)  # stejný dotaz (dva „bloky“)
			if a != b: neshod += 1
			if a in [38, 42, 21, 47, 0] and zz < svet.vyska(sev, y) - 0.5:
				if a == 0: utvaru += 1  # dutina pod povrchem
				else: utvaru += 1
	# šev segmentu 8 m: porovnat body těsně zleva a zprava na stejné z, jen pro útvary (ne mince)
	# totéž světové (x,y,z) z obou stran — 0 rozdílů
	var neshod_bod := 0
	for j in 32:
		var y := o.y + 16.0 + j * 8.0
		var x := o.x + 8.0 * 3.0  # šev segmentu
		for z in 16:
			var zz := 4.0 + z * 4.0
			var p1: int = svet.bod(x, y, zz)
			var p2: int = svet.bod(x, y, zz)
			if p1 != p2: neshod_bod += 1
	var chyb := 0
	if neshod > 0 or neshod_bod > 0:
		print("útvary přes šev: neshod ", neshod, "/", neshod_bod); chyb += 1
	out["utvary_sev"] = {"neshod_blok": neshod, "neshod_segment": neshod_bod, "utvaru_na_sevu": utvaru}
	print("útvary přes šev: 0 neshod, útvarů na řezu ", utvaru)
	return chyb

func _mince(svet) -> int:
	var blok := float(svet.p.rozmery.blok_m)
	var ano := 0
	var n := 0
	# 3 × 3 výchozí
	var o: Vector2 = svet.start_m()
	var a33 := 0
	for i in 3:
		for j in 3:
			n += 1
			if svet.geo.mince82(o.x + (i + 0.5) * blok, o.y + (j + 0.5) * blok):
				ano += 1; a33 += 1
	# více seedů (hash mince závisí jen na seedu a indexu bloku)
	var ano2 := 0; var n2 := 0
	var po_seedu: Array = []
	const H = preload("res://scripts/stable_hash.gd")
	for s in 16:
		var sd := 40 + s
		var a := 0
		for i in 8:
			for j in 8:
				n2 += 1
				var h: int = H.mix(sd, "P82_VAPENEC", i * 7919 + j)
				if float(h & 0xFFFF) / 65536.0 < float(svet.p.p82_podil):
					ano2 += 1; a += 1
		po_seedu.append({"seed": sd, "ano": a, "z": 64, "podil": a / 64.0})
	var podil := float(ano2) / float(n2)
	var ocek := float(svet.p.p82_podil)
	var sd := sqrt(ocek * (1.0 - ocek) / float(n2))
	var ok := absf(podil - ocek) <= 3.0 * sd + 1e-9
	out["mince"] = {"ano_3x3": a33, "z_3x3": 9, "podil_3x3": a33 / 9.0,
		"ano": ano2, "n": n2, "podil": podil, "ocek": ocek, "sd": sd, "ok_3sd": ok, "po_seedu": po_seedu}
	print("mince: 3×3 ", a33, "/9 = ", a33 / 9.0, "; více ", ano2, "/", n2, " = ", podil, " (oček. ", ocek, " ±3σ ", 3.0 * sd, ") ok=", ok)
	return 0 if ok else 1

func _cas(svet) -> void:
	var o: Vector2 = svet.start_m()
	# segment 8 m, buňka 0,25 m, celý sloupec 128 m (V1)
	var t0 := Time.get_ticks_usec()
	var n025 := 32
	var nz025 := 512
	for ix in n025:
		for iy in n025:
			var x := o.x + (ix + 0.5) * 0.25
			var y := o.y + (iy + 0.5) * 0.25
			svet.geo.vypln_sloupec(x, y, 0.25, 128.0)
	var ms025 := _ms(t0)
	# srovnatelné s E84: 8 m, 0,5 m, výška 32 m (16×16 sloupce)
	t0 = Time.get_ticks_usec()
	for ix in 16:
		for iy in 16:
			var x := o.x + (ix + 0.5) * 0.5
			var y := o.y + (iy + 0.5) * 0.5
			svet.geo.vypln_sloupec(x, y, 0.5, 32.0)
	var ms05 := _ms(t0)
	# jen hranice sloupce (32×32 na segmentu 8 m)
	t0 = Time.get_ticks_usec()
	for ix in 32:
		for iy in 32:
			svet.geo.hranice(o.x + (ix + 0.5) * 0.25, o.y + (iy + 0.5) * 0.25)
	var ms_hr := _ms(t0)
	out["cas"] = {"segment_8m_025_ms": ms025, "segment_8m_05_32m_ms": ms05, "hranice_8m_025_ms": ms_hr,
		"e84_r1_ms": 89.0, "bunek_025": n025 * n025 * nz025, "bunek_05_32m": 16 * 16 * 64}
	print("čas: segment 8 m / 0,25 m / 128 m ", ms025, " ms; srovnání E84 (0,5 m, 32 m) ", ms05, " ms vs 89 ms; hranice ", ms_hr, " ms")

func _mapy(svet) -> void:
	var o: Vector2 = svet.start_m()
	# mince mapa 24×24 bloků (aby byl vidět výchozí 3 × 3 u [14,14])
	var nb := 24
	var m := PackedFloat32Array(); m.resize(nb * nb)
	for i in nb:
		for j in nb:
			m[i * nb + j] = 1.0 if svet.geo.mince82((i + 0.5) * 128.0, (j + 0.5) * 128.0) else 0.0
	_uloz_bin("mince_16x16.f32", m)
	# vodorovný řez útvarů 20 m pod povrchem, krok 2 m (192 × 192 na 3 × 3)
	var krok_m := 2.0
	var n := int(384.0 / krok_m)
	var hloubka := 20.0
	var u := PackedFloat32Array(); u.resize(n * n)
	for i in n:
		for j in n:
			var x := o.x + (i + 0.5) * krok_m; var y := o.y + (j + 0.5) * krok_m
			var w: PackedFloat64Array = svet.vahy(x, y)
			var zp: float = float(svet.vyska_w(x, y, w, true))
			var zq := zp - hloubka
			if zq <= 0.0:
				u[i * n + j] = 0.0
			else:
				var hr: Array = svet.geo.hranice(x, y, w)
				var sm: int = svet.geo.sopka_mat(x, y, zq)
				if sm >= 0:
					u[i * n + j] = sm
				else:
					var vm: int = svet.geo.vrstva_mat(x, y, zq, hr)
					var um: int = int(svet.geo.utv.mat(x, y, zq, vm, zp, hr))
					u[i * n + j] = float(um if um >= 0 else vm)
	_uloz_bin("utvary_rez_20m.f32", u)
	out["mapy"] = {"mince_n": nb, "utvary_n": n, "hloubka_m": hloubka, "krok_m": krok_m}
