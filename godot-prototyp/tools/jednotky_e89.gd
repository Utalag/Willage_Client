extends SceneTree
## E89: test modulu jednotek (scripts/jednotky.gd). Shoda s dnešními konstantami, tam a zpět pro hustoty 16 / 32 / 64 / 128,
## vnoření 0,5 ⊃ 0,25, svět ↔ (slot, místní), index buňky v obou konvencích os, převod l → m³ (dělení / násobení,
## na skutečných průtocích ostrova START), cena volání funkce proti výrazu. Výstup: JSON (--out=cesta), souhrn na stdout.
const J = preload("res://scripts/jednotky.gd")
const FN = preload("res://scripts/teren/geo_fn.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const Mesher = preload("res://scripts/mesher.gd")
const Island = preload("res://scripts/island.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	var r := {}
	T.reset()
	# 1) shoda s konstantami v kódu
	r.konstanty = {
		"U_M = geo_fn.U": J.U_M == FN.U, "BLOK_M = geo_fn.BW": J.BLOK_M == FN.BW, "VYSKA_M = geo_fn.BHT": J.VYSKA_M == FN.BHT,
		"bunka_m(16) = voda_cell_m": J.bunka_m(16) == float(T.p.voda_cell_m), "bunka_m(16) = Block.CELL_H": J.bunka_m(16) == Block.CELL_H,
		"nz(16) = Block.BH": J.nz(16) == Block.BH, "Mesher.CELL_H = Island.CELL_H": Mesher.CELL_H == Island.CELL_H,
		"bunka_m3(16) = 0,125 (podzemi.gd)": J.bunka_m3(16) == 0.125,
		"bunka_m3(16) = 1,0 (ug_funkce.from_cells výchozí)": J.bunka_m3(16) == 1.0,
		"scéna vodorovně m na jednotku": J.SCENA_DNES_M_NA_SC.x, "scéna svisle m na jednotku": J.SCENA_DNES_M_NA_SC.y,
		"postava m": J.hj_m(J.POSTAVA_HJ), "dveře m": J.hj_m(J.DVERE_HJ), "hj na blok": J.HJ_NA_BLOK, "hj na blok = bunka 32": J.bunka_m(32) == J.HJ_M}
	# 2) tam a zpět, vnoření
	var tz := {}
	for n in [16, 32, 64, 128]:
		var bad := 0; var badn := 0; var badi := 0
		for i in n:
			if J.m_na_i(J.i_stred_m(i, n), n) != i or J.m_na_i(J.i_m(i, n), n) != i: bad += 1
			for n2 in [16, 32, 64, 128]:
				var j := J.prevzorkuj_i(i, n, n2)
				if n2 >= n and J.prevzorkuj_i(j, n2, n) != i: badn += 1   # jemnější a zpět = stejná buňka
				if n2 < n and (i < j * (n / n2) or i >= (j + 1) * (n / n2)): badn += 1   # rodič obsahuje buňku
				if n2 > n:   # všechny podbuňky mají stejného rodiče
					for k in n2 / n:
						if J.prevzorkuj_i(j + k, n2, n) != i: badn += 1
		var nzz := J.nz(n); var step := 1 if n <= 32 else 97
		var cnt := 0
		for c in range(0, n * n * nzz, step):
			var v := J.idx_rozloz(c, n)
			if J.idx(v.x, v.y, v.z, n) != c: badi += 1
			cnt += 1
		tz[str(n)] = {"bunka_m": J.bunka_m(n), "nz": nzz, "tam_zpet_chyb": bad, "vnoreni_chyb": badn, "index_chyb": badi, "index_testu": cnt}
	r.hustoty = tz
	# 3) svět ↔ slot: náhodné body (i záporné sloty), shoda s hustotou 32 = herní jednotky
	var rng := RandomNumberGenerator.new(); rng.seed = 89
	var bad_s := 0; var bad_hj := 0
	for k in 200000:
		var x := rng.randf_range(-40.0, 40.0); var y := rng.randf_range(-40.0, 40.0)
		var a: Array = J.svet_na_slot(x, y, 32)
		var gx: int = a[0].x * 32 + a[1]
		if gx != J.m_hj(x): bad_hj += 1
		if a[1] < 0 or a[1] >= 32 or a[2] < 0 or a[2] >= 32: bad_s += 1
	r.svet = {"bodu": 200000, "mimo_blok": bad_s, "nesouhlasi_s_hj": bad_hj}
	# 4) index geo (x, y, z nahoru) = index Godot (x, z, y nahoru) pro všech 16 384 buněk
	var bad_g := 0
	for x in 16:
		for y in 16:
			for z in 64:
				if (x * 16 + y) * 64 + z != (x * Block.BS + y) * Block.BH + z or J.idx(x, y, z, 16) != (x * 16 + y) * 64 + z: bad_g += 1
	r.index_os = {"bunek": 16384, "chyb": bad_g}
	# 5) l → m³: dělení 1000 proti násobení 0,001 na skutečných průtocích ostrova START a na náhodných číslech
	BlockGen.gen_version = "bp"
	var blocks := {}
	for e in "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404".split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	var v := OV.new(); v.build(blocks)
	var eff: PackedFloat64Array = v.st.eff
	var nz_ := 0; var dif := 0; var maxrel := 0.0
	for q in eff:
		if q <= 0.0: continue
		nz_ += 1
		var a1 := q / 1000.0; var a2 := q * 0.001
		if a1 != a2: dif += 1; maxrel = maxf(maxrel, absf(a1 - a2) / a1)
	var dif_r := 0
	for k in 1000000:
		var q := rng.randf_range(0.0, 10.0)
		if q / 1000.0 != q * 0.001: dif_r += 1
	r.l_m3 = {"ostrov_prutoku_nenulovych": nz_, "ostrov_jinak": dif, "ostrov_max_relativne": maxrel, "nahodnych": 1000000, "nahodnych_jinak": dif_r}
	# 6) cena: výraz proti volání statické funkce (1 000 000 převodů)
	var N := 1000000; var acc := 0
	var t0 := Time.get_ticks_usec()
	for k in N: acc += floori(float(k) * 0.001 * 2.0)
	var t_inline := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for k in N: acc += J.m_na_i(float(k) * 0.001, 16)
	var t_fn := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for k in N: acc += ((k & 15) * 16 + ((k >> 4) & 15)) * 64 + (k & 63)
	var t_idx := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for k in N: acc += J.idx(k & 15, (k >> 4) & 15, k & 63, 16)
	var t_idxf := Time.get_ticks_usec() - t0
	r.cena_ns = {"m_na_i_vyraz": t_inline * 1000.0 / N, "m_na_i_funkce": t_fn * 1000.0 / N, "idx_vyraz": t_idx * 1000.0 / N, "idx_funkce": t_idxf * 1000.0 / N, "_": acc % 7}
	var js := JSON.stringify(r, " ", false)
	print(js)
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(js); f.close()
	quit()
