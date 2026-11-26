extends RefCounted
## A1: žádný útvar v nehostiteli, nikdy v ornici / písku / spraši / jílu. Tabulku čte test nezávisle na kódu
## (vlastní parser JSON), takže nejde o kontrolu kódu jeho vlastní logikou.
const BL = preload("res://tools/geo_v1b/blok.gd")
const S = preload("res://scripts/v1/svet_fn.gd")
const PEG := 38
const TRIDA := {38: "zila", 8: "zila", 9: "zila", 47: "dome", 21: "pipe", 42: "skarn", 0: "kras"}

var hostitele := {}      # typ → {id: true}
var nikdy := {}
var min_hl := {}
var min_hostu := {}      # id minerálu → {id: true}

func _init() -> void:
	var tab: Dictionary = JSON.parse_string(FileAccess.open("res://data/v1/utvary_hostitele.json", FileAccess.READ).get_as_text())
	var kat: Dictionary = JSON.parse_string(FileAccess.open("res://data/teren/poradi_hornin.json", FileAccess.READ).get_as_text())
	var klic := {}
	var vrstvy := {}
	for r in kat.rocks:
		if int(r.idx) > 40: continue
		klic[String(r.key)] = int(r.id)
		if String(r.kind) in ["layer", "seam"]: vrstvy[int(r.id)] = true
	for k in tab.nikdy: nikdy[klic[k]] = true
	for typ in tab.typy:
		var h := {}
		var e: Dictionary = tab.typy[typ]
		if e.hosts is String:
			for id in vrstvy: h[id] = true
		else:
			for k in e.hosts: h[klic[k]] = true
		for id in nikdy: h.erase(id)
		hostitele[typ] = h
		min_hl[typ] = float(e.min_hloubka_m)
	hostitele["zila"] = hostitele["zila"]
	var mh: Dictionary = JSON.parse_string(FileAccess.open("res://data/teren/mineraly_hostitele.json", FileAccess.READ).get_as_text())
	for k in mh.minerals:
		var h := {}
		for hk in mh.minerals[k].hosts:
			if klic.has(hk): h[klic[hk]] = true
		min_hostu[int(mh.minerals[k].id)] = h

## projde bloky; vrátí počty buněk útvarů podle typu a porušení
func sken(svet, bloky: Array, krok_xy: float, krok_z: float) -> Dictionary:
	var st := {"bunek_tel": {}, "porus_nikdy": 0, "porus_host": 0, "porus_hloubka": 0, "porus_mineral": 0,
		"v_pude": {}, "podle_hostitele": {}, "pripady": [], "sloupcu": 0,
		"dome_v_pasmu": 0, "dome_mimo_pasmo": 0, "dome_nej": {"n": 0, "x": 0.0, "y": 0.0, "z": 0.0}}
	var dome_xy := {}
	var cb := func(x: float, y: float, z: float, b: Dictionary) -> void:
		var um: int = b.um
		if um < 0: return
		var typ: String = TRIDA.get(um, "")
		if typ == "": return
		var vm: int = b.vm
		st.bunek_tel[typ] = int(st.bunek_tel.get(typ, 0)) + 1
		var kl := "%s@%d" % [typ, vm]
		st.podle_hostitele[kl] = int(st.podle_hostitele.get(kl, 0)) + 1
		var zle := false
		if nikdy.has(vm):
			st.porus_nikdy += 1
			st.v_pude[typ] = int(st.v_pude.get(typ, 0)) + 1
			zle = true
		if not hostitele[typ].has(vm):
			st.porus_host += 1; zle = true
		if float(b.z_pov) - z < float(min_hl[typ]) - 1e-9:
			st.porus_hloubka += 1; zle = true
		if um in [8, 9] and not min_hostu[um].has(vm):
			st.porus_mineral += 1; zle = true
		if typ == "dome":
			var p0 := float(svet.p.get("pasmo_spodek", 0.32))
			var p1 := float(svet.p.get("pasmo_krystalinikum", 0.35))
			var p2 := float(svet.p.get("pasmo_sedimenty", 0.25))
			var p3 := float(svet.p.get("pasmo_svrchni", 0.08))
			var ps := maxf(p0 + p1 + p2 + p3, 1e-12)
			var zt := float(svet.vyska_tvar(x, y))
			var r := z / maxf(zt, 1e-6)
			if r >= (p0 + p1) / ps - 1e-9 and r <= (p0 + p1 + p2) / ps + 1e-9:
				st.dome_v_pasmu += 1
			else:
				st.dome_mimo_pasmo += 1
			var klic := "%d_%d" % [int(floor(x)), int(floor(y))]
			dome_xy[klic] = int(dome_xy.get(klic, 0)) + 1
			if int(dome_xy[klic]) > int(st.dome_nej.n):
				st.dome_nej = {"n": dome_xy[klic], "x": x, "y": y, "z": z}
		if zle and st.pripady.size() < 5:
			st.pripady.append({"typ": typ, "vm": vm, "x": x, "y": y, "z": z})
	for b in bloky:
		st.sloupcu += BL.prochod(svet, int(b[0]), int(b[1]), krok_xy, krok_z, 128.0, cb)
	return st

func run(par: Dictionary, bloky: Array, krok_xy: float, krok_z: float) -> Dictionary:
	var pa := par.duplicate(); pa["a1_hostitele"] = true; pa["dom_pasmo_sedimenty"] = true
	var pstary := par.duplicate(); pstary["a1_hostitele"] = true; pstary["dom_pasmo_sedimenty"] = false
	var pv := par.duplicate(); pv["a1_hostitele"] = false; pv["dom_pasmo_sedimenty"] = false
	var po := sken(S.new(pa), bloky, krok_xy, krok_z)
	var stary := sken(S.new(pstary), bloky, krok_xy, krok_z)
	var pred := sken(S.new(pv), bloky, krok_xy, krok_z)
	var ok: bool = po.porus_nikdy == 0 and po.porus_host == 0 and po.porus_hloubka == 0 and po.porus_mineral == 0
	var kousa: bool = pred.porus_host > 0     # test musí nad původním kódem selhat, jinak nic nekontroluje
	print("A1 po (dóm v sedimentech): tel ", po.bunek_tel, " | nikdy ", po.porus_nikdy, " host ", po.porus_host, " hloubka ", po.porus_hloubka, " minerál ", po.porus_mineral, " dóm v pásmu ", po.dome_v_pasmu, " mimo ", po.dome_mimo_pasmo, " nej ", po.dome_nej)
	print("A1 po (starý střed dómu):  tel ", stary.bunek_tel, " | host ", stary.porus_host, " dóm v pásmu ", stary.dome_v_pasmu, " mimo ", stary.dome_mimo_pasmo)
	print("A1 před (host_ok=true, starý střed): tel ", pred.bunek_tel, " | nikdy ", pred.porus_nikdy, " host ", pred.porus_host, " hloubka ", pred.porus_hloubka, " minerál ", pred.porus_mineral, " v půdě ", pred.v_pude)
	print("A1 ", "PROŠLO" if ok and kousa else "SELHALO", " (test kousá nad původním kódem: ", kousa, ")")
	return {"po": po, "stary_stred": stary, "pred": pred, "ok": ok and kousa, "kousa": kousa}
