extends RefCounted
## Geologie V1.0, krok 3: vrstvy, mince E82, vnitřek sopky, napojení útvarů (1.7, 1.7.1, 1.8, 1.14).
## Čistá funkce v metrech, bez mřížky sousedů. cavity_one se nepoužívá.
const H = preload("res://scripts/stable_hash.gd")
const UT = preload("res://scripts/v1/utvary.gd")
const SUM = preload("res://scripts/v1/sum_hornin.gd")
const CESTA_PORADI := "res://data/teren/poradi_hornin.json"
const VZDUCH := 0
const PRUDUCH := 75
const JIL := [4, 12, 51]          # jíl / jílovec k vyklínění nad mincí
const VAPENEC := [5, 44, 49]      # jeskynní a hluboký vápenec, dolomit
const LAYER_KIND := { "layer": true, "soil": true, "seam": true }

# pásma 1.7.1, zdola nahoru
const PASMA := [
	{"jmeno": "spodek", "idx0": 0, "idx1": 12, "podil": 0.32},
	{"jmeno": "krystalinikum", "idx0": 13, "idx1": 25, "podil": 0.35},
	{"jmeno": "sedimenty", "idx0": 26, "idx1": 36, "podil": 0.25},
	{"jmeno": "svrchni", "idx0": 37, "idx1": 40, "podil": 0.08},
]

var svet
var utv
var sum                          # šum mocnosti podle horniny (A10), data/v1/sum_hornin_v1.csv
var katalog: Array = []           # položky úrovní 0–40
var podle_idx := {}
var perm0 := {}                   # id → bool (perm ≤ 0, těsnění E82)

func _init(s) -> void:
	svet = s
	_nacti_katalog()
	sum = SUM.new(svet, bool(svet.p.get("a10_sum_hornin", true)))
	utv = UT.new(svet, self)

func _nacti_katalog() -> void:
	var f := FileAccess.open(CESTA_PORADI, FileAccess.READ)
	if f == null:
		push_error("geo: nelze otevřít " + CESTA_PORADI)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for r in d.get("rocks", []):
		var idx := int(r.get("idx", -1))
		if idx < 0 or idx > 40: continue
		katalog.append(r)
		podle_idx[idx] = r
	# perm 0 z tabulky V1 (těsnění mince)
	var mt := FileAccess.open("res://data/materialy_v1.csv", FileAccess.READ)
	if mt != null:
		var hlava := mt.get_csv_line()
		var i_id := hlava.find("id")
		var i_p := hlava.find("propustnost_0_1")
		while not mt.eof_reached():
			var row := mt.get_csv_line()
			if row.size() <= maxi(i_id, i_p): continue
			if not String(row[i_id]).is_valid_int(): continue
			var ps := String(row[i_p]).strip_edges()
			if ps.is_valid_float() and float(ps) <= 0.0:
				perm0[int(row[i_id])] = true

func _u(ucel: String, i: int, j: int, k := 0) -> float:
	return svet._u(ucel, i, j, k)

## mince E82: 50/50 podle světového bloku 128 m (ne podle seedu blueprintu hry)
func mince82(x: float, y: float) -> bool:
	if not bool(svet.p.get("p82_vapenec", true)): return false
	var bx := floori(x / float(svet.p.rozmery.blok_m))
	var by := floori(y / float(svet.p.rozmery.blok_m))
	var h := H.mix(svet.sd, "P82_VAPENEC", bx * 7919 + by)
	return float(h & 0xFFFF) / 65536.0 < float(svet.p.get("p82_podil", 0.5))

func _zastupci(x: float, y: float, pasmo: Dictionary, w_bio: PackedFloat64Array, hr_map := []) -> Array:
	var ids_band := {}
	for r in katalog:
		var idx := int(r.idx)
		if idx < int(pasmo.idx0) or idx > int(pasmo.idx1): continue
		if not LAYER_KIND.has(String(r.get("kind", "layer"))): continue
		if not bool(r.get("active", true)): continue
		ids_band[int(r.id)] = r
	var vahy := {}
	# přítomnost a mocnost ze seedu (jako geo2.targets)
	for id in ids_band:
		var r: Dictionary = ids_band[id]
		var freq := float(r.get("freq", 0.5))
		var th: Array = r.get("thick", [1, 1])
		var t0 := float(th[0]); var t1 := float(th[1] if th.size() > 1 else th[0])
		var ix := int(r.idx)
		var pres := smoothstep(1.0 - freq - 0.12, 1.0 - freq + 0.12, _n01("V1_PRES", ix, x, y))
		var t := lerpf(t0, t1, sum.mocnost_n01(int(r.id), ix, x, y))
		vahy[id] = maxf(t * pres, 0.0)
	# mapa hornin kroku 2 (jednou pro sloupec)
	var hr: Array = hr_map if not hr_map.is_empty() else svet.horniny(x, y, w_bio)
	for e in hr:
		var id := int(e[0])
		if ids_band.has(id):
			vahy[id] = float(vahy.get(id, 0.0)) + float(e[1]) * 2.0
	# k_horniny: kontrast, k=1 identita
	var k := float(svet.p.get("klima_k_horniny", 1.0))
	if absf(k - 1.0) > 1e-12:
		for id in vahy.keys():
			vahy[id] = pow(maxf(float(vahy[id]), 1e-12), k)
	# záloha: aspoň jedna hornina pásma
	var suma := 0.0
	for id in vahy: suma += float(vahy[id])
	if suma <= 1e-12:
		# první aktivní vrstva pásma
		for r in katalog:
			var idx := int(r.idx)
			if idx < int(pasmo.idx0) or idx > int(pasmo.idx1): continue
			if not LAYER_KIND.has(String(r.get("kind", "layer"))): continue
			vahy[int(r.id)] = 1.0
			suma = 1.0
			break
	var arr: Array = []
	for id in vahy:
		arr.append([int(id), float(vahy[id]) / maxf(suma, 1e-12)])
	arr.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	var n := int(svet.p.get("zastupcu", 3))
	if n < 1: n = 1
	if arr.size() > n: arr = arr.slice(0, n)
	# vyklínění: velmi slabé zahodit
	var out: Array = []
	var s2 := 0.0
	for e in arr:
		if float(e[1]) < 0.06: continue
		out.append(e); s2 += float(e[1])
	if out.is_empty() and not arr.is_empty():
		out.append(arr[0]); s2 = float(arr[0][1])
	if s2 > 0.0:
		for e in out: e[1] = float(e[1]) / s2
	return out

func _n01(ucel: String, k: int, x: float, y: float) -> float:
	# pomalé pole 0–1 ze světového seedu, jedna oktáva 180 m (šum přítomnosti; bez FastNoise kvůli typům)
	return sum.oktava(ucel, k, x, y, 180.0)

## hranice vrstev v bodě (zdola nahoru): [{id, z0, z1, definice_m}, ...]
## Definice sleduje vyska_tvar; nahoře se ořízne skutečným povrchem (zbytky po ořezu).
func hranice(x: float, y: float, w := PackedFloat64Array()) -> Array:
	if w.is_empty(): w = svet.vahy(x, y)
	var z_tvar: float = float(svet.vyska_tvar(x, y))
	var z_pov: float = float(svet.vyska_w(x, y, w, true))
	var Hgt := maxf(z_tvar, 0.25)
	var min_t := 0.25
	var max_t := 0.25 * Hgt
	# podíly pásem (parametry, součet 1)
	var pod: PackedFloat64Array = PackedFloat64Array()
	var ps := 0.0
	for pas in PASMA:
		var klic := "pasmo_" + String(pas.jmeno)
		var v := float(svet.p.get(klic, pas.podil))
		pod.append(v); ps += v
	if ps <= 0.0: ps = 1.0
	var hr_map: Array = svet.horniny(x, y, w)
	var vrstvy: Array = []   # {id, thick} zdola
	for i in PASMA.size():
		var pas: Dictionary = PASMA[i]
		var band_h := Hgt * pod[i] / ps
		var reps: Array = _zastupci(x, y, pas, w, hr_map)
		for e in reps:
			var th := band_h * float(e[1])
			if th < min_t * 0.5: continue   # vyklíní v definici
			th = clampf(th, min_t, max_t)
			vrstvy.append({"id": int(e[0]), "thick": th})
	# doplnit / seškrábnout na Hgt bez vrstev pod min_t (1.7)
	var suma := 0.0
	for v in vrstvy: suma += float(v.thick)
	if vrstvy.is_empty():
		vrstvy.append({"id": 20, "thick": Hgt}); suma = Hgt
	if suma < Hgt:
		vrstvy[0].thick = float(vrstvy[0].thick) + (Hgt - suma)
	elif suma > Hgt:
		var extra := suma - Hgt
		for i in range(vrstvy.size() - 1, -1, -1):
			var can := float(vrstvy[i].thick) - min_t
			if can <= 0.0: continue
			var take := minf(can, extra)
			vrstvy[i].thick = float(vrstvy[i].thick) - take
			extra -= take
			if extra <= 1e-12: break
	_sluc_tenke(vrstvy, min_t)

	# mince E82: zvednout vápenec/dolomit na odhad hladiny − 2 m, jíl nad nimi vyklínit
	if mince82(x, y):
		_mince_zvedni(vrstvy, z_tvar)
		_sluc_tenke(vrstvy, min_t)

	# z tlouštěk souřadnice, oříznout skutečným povrchem
	var out: Array = []
	var z := 0.0
	for v in vrstvy:
		var z0 := z
		var z1 := z + float(v.thick)
		z = z1
		var d0 := z0
		var d1 := minf(z1, z_pov)
		if d1 <= d0: continue
		out.append({"id": int(v.id), "z0": d0, "z1": d1, "definice_m": float(v.thick)})
	return out

func _mince_zvedni(vrstvy: Array, z_tvar: float) -> void:
	var cil := z_tvar - float(svet.p.get("p82_pod_m", 2.0))
	if cil < 0.25: return
	var z := 0.0
	var i_vap := -1
	var z1_vap := 0.0
	for i in vrstvy.size():
		z += float(vrstvy[i].thick)
		if int(vrstvy[i].id) in VAPENEC:
			i_vap = i
			z1_vap = z
	if i_vap < 0 or z1_vap >= cil: return
	# prostor do cíle se bere z vrstev nad vápencem (součet mocností zůstane)
	var need := cil - z1_vap
	var min_t := 0.25
	var j := i_vap + 1
	while j < vrstvy.size() and need > 1e-9:
		var th := float(vrstvy[j].thick)
		# nenechat zbytek pod min_t: buď vzít vše, nebo nechat min_t
		var take := 0.0
		if th <= need + 1e-12:
			take = th
		elif th - need >= min_t:
			take = need
		elif th > min_t:
			take = th - min_t
		if take > 1e-12:
			vrstvy[j].thick = th - take
			vrstvy[i_vap].thick = float(vrstvy[i_vap].thick) + take
			need -= take
		j += 1
	# jíl a těsnění nad vápencem vyklíní; mocnost dostane vrstva nad ním, jinak vápenec
	j = i_vap + 1
	while j < vrstvy.size():
		var id := int(vrstvy[j].id)
		if id in JIL or perm0.has(id):
			var th := float(vrstvy[j].thick)
			vrstvy[j].thick = 0.0
			var kam := -1
			var k := j + 1
			while k < vrstvy.size():
				var idk := int(vrstvy[k].id)
				if not (idk in JIL or perm0.has(idk)):
					kam = k; break
				k += 1
			if kam >= 0:
				vrstvy[kam].thick = float(vrstvy[kam].thick) + th
			else:
				vrstvy[i_vap].thick = float(vrstvy[i_vap].thick) + th
		j += 1
	var ciste: Array = []
	for v in vrstvy:
		if float(v.thick) > 1e-9: ciste.append(v)
	vrstvy.clear()
	for v in ciste: vrstvy.append(v)


## sloučí vrstvy tenčí než min_t se sousedem (definice má mít aspoň 1 buňku)
func _sluc_tenke(vrstvy: Array, min_t: float) -> void:
	var guard := 0
	while guard < 64:
		guard += 1
		var i := -1
		for k in vrstvy.size():
			if float(vrstvy[k].thick) < min_t - 1e-12:
				i = k; break
		if i < 0:
			break
		if vrstvy.size() == 1:
			vrstvy[0].thick = maxf(float(vrstvy[0].thick), min_t)
			break
		var j := i - 1 if i > 0 else i + 1
		if i + 1 < vrstvy.size() and (i == 0 or float(vrstvy[i + 1].thick) >= float(vrstvy[i - 1].thick)):
			j = i + 1
		vrstvy[j].thick = float(vrstvy[j].thick) + float(vrstvy[i].thick)
		vrstvy.remove_at(i)
	var ciste: Array = []
	for v in vrstvy:
		if float(v.thick) > 1e-9:
			ciste.append(v)
	vrstvy.clear()
	for v in ciste:
		vrstvy.append(v)

func vrstva_mat(x: float, y: float, z: float, hr := []) -> int:
	if hr.is_empty(): hr = hranice(x, y)
	for e in hr:
		if z >= float(e.z0) and z < float(e.z1): return int(e.id)
	if not hr.is_empty() and z >= float(hr[hr.size() - 1].z1) - 1e-9:
		return int(hr[hr.size() - 1].id)
	return VZDUCH

## vnitřek sopky: průduch id 75 od kráteru po z=0, slupky lávy/popela; -1 mimo těleso
func sopka_mat(x: float, y: float, z: float) -> int:
	if z < 0.0: return VZDUCH
	var best := -1
	var br2 := 1e30
	for i in svet.sx.size():
		var dx: float = x - float(svet.sx[i]); var dy: float = y - float(svet.sy[i])
		var r2: float = dx * dx + dy * dy
		var R: float = svet.sR[i]
		if r2 < R * R and r2 < br2:
			br2 = r2; best = i
	if best < 0: return -1
	var s: Dictionary = svet.sopky[best]
	var r := sqrt(br2)
	var h0 := float(s.vyska_okoli)
	var kuz: float = float(svet._kuzel(best, r))
	var z_pov_kuz: float = h0 + kuz
	if z > z_pov_kuz + 0.05: return -1
	var rc := float(s.rc)
	var r_vent := maxf(float(svet.p.get("sopka_pruduch_r_m", 2.0)), rc * 0.35)
	# kráter: dno na ose = h0 + H − d
	var z_krater := h0 + float(s.H) - float(s.d)
	if r < r_vent and z <= z_krater + 0.05:
		return PRUDUCH
	if z < 0.0: return -1
	var lava := int(svet.p.get("sopka_lava_id", 7))
	var popel := int(svet.p.get("sopka_popel_id", 57))
	var sl := float(svet.p.get("sopka_slupka_m", 5.0))
	var hloubka: float = z_pov_kuz - z
	var k := int(floor(hloubka / maxf(sl, 0.5)))
	return lava if (k % 2) == 0 else popel

func bod(x: float, y: float, z: float) -> int:
	var w: PackedFloat64Array = svet.vahy(x, y)
	var z_pov: float = svet.vyska_w(x, y, w, true)
	if z > z_pov: return VZDUCH
	var sm := sopka_mat(x, y, z)
	if sm >= 0: return sm
	var hr: Array = hranice(x, y, w)
	var vm: int = vrstva_mat(x, y, z, hr)
	var um: int = int(utv.mat(x, y, z, vm, z_pov, hr))
	if um >= 0: return um
	return vm

## vyplní sloupec po kroku (hranice jednou): rychlé vzorkování pro testy
func vypln_sloupec(x: float, y: float, krok_z: float, zmax: float) -> PackedByteArray:
	var w: PackedFloat64Array = svet.vahy(x, y)
	var z_pov: float = float(svet.vyska_w(x, y, w, true))
	var hr: Array = hranice(x, y, w)
	var feats: Array = utv.features_u(x, y)
	var n := int(ceil(zmax / krok_z))
	var a := PackedByteArray(); a.resize(n)
	for iz in n:
		var z: float = (iz + 0.5) * krok_z
		if z > z_pov:
			a[iz] = VZDUCH
			continue
		var sm: int = sopka_mat(x, y, z)
		if sm >= 0:
			a[iz] = sm
			continue
		var vm: int = vrstva_mat(x, y, z, hr)
		var um: int = int(utv.mat_feats(feats, x, y, z, vm, z_pov, hr))
		a[iz] = um if um >= 0 else vm
	return a
