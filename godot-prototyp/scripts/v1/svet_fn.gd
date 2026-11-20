extends RefCounted
## Generátor V1.0, krok 2: funkce světa I (docs/sjednoceni 2.1, 2.2, 1.4, 1.7.1, 1.13, 1.14).
## Jedna čistá funkce ve světových metrech (float64), bez mřížky sousedů a bez uložených buněk:
##   vyska(x, y)        → povrch v m (0 = dno sloupce, neutrální úroveň = sloupec / 2)
##   sloupec(x, y)      → {povrch_m, biom, biom_vahy, horniny, masiv, sopka, hranice (krok 3), hladina_m (krok 4)}
##   bod(x, y, z)       → id materiálu (krok 2: vzduch nad povrchem, pod ním převažující hornina z mapy hornin;
##                        vrstvy doplní krok 3 beze změny rozhraní)
## Pořadí 2.1: mapa biomů a hornin (hrubé body ze seedu na 4096 m) → reliéf z parametrů biomu → masiv E87 + podhůří
## → sopky. Žádné šablony povrchu, p94_hora_k ani omezovač E92 (1.4). Strop sklonu (1.13) se dodrží volbou efektivní
## amplitudy šumu (gradient šumu změřený při vytvoření světa), ne úpravou hotového povrchu.
## Převzato: vzorec reliéfu E49/E90 (lod90.h49: základní šum, hřbet (1 − |n|)²) – větev e96-blok128; masiv
## geo2.n01 (šum MASSIF87 / MASSIF87D, E87 ff97a9f) – jen v metrech a ve sloupci 128 m; kužel s kráterem E49
## (svet/hruby_teren.gd: c · (1 − r/R)^γ − kráter) zobecněný na parametry 1.14.
const R = preload("res://scripts/v1/rozmery.gd")
const H = preload("res://scripts/stable_hash.gd")
const BG = preload("res://scripts/teren/zaklad/block_gen.gd")
const G2 = preload("res://scripts/teren/geo2.gd")

const NIZINA := 0
const MOKRAD := 1
const PAHORKATINA := 2
const HORNATINA := 3
const SOPECNA := 4
const BIOMY := ["nížina", "mokřad", "pahorkatina", "hornatina", "sopečná oblast"]
const VZDUCH := 0

## výchozí parametry světa (vstupní data spolu se seedem, 1.13: ne konstanty v kódu)
static func vychozi() -> Dictionary:
	return {
		"seed": 49,
		"rozmery": R.vychozi(),
		"start_blok": [14, 14],          # levý dolní blok výchozího světa 3 × 3 (blok 128 m) v maximu 32 × 32
		# mapa biomů (varianta C, 2.1): hrubé body (rozteč), měkké Voroného váhy (šířka přechodu)
		"biom_roztec_m": 256.0, "biom_prechod_m": 192.0,
		"podil": [0.35, 0.10, 0.30, 0.20, 0.05],   # podíl ploch nížina / mokřad / pahorkatina / hornatina / sopečná
		# parametry členitosti podle biomu (1.13): posun nad neutrální úrovní, převýšení, vlnová délka, drsnost, strop sklonu
		"biomy": [
			{"posun_m": 0.0, "prevyseni_m": 3.0, "vlna_m": 160.0, "drsnost": 0.40, "strop_deg": 12.0, "hreben": false},
			{"posun_m": -1.5, "prevyseni_m": 1.2, "vlna_m": 120.0, "drsnost": 0.35, "strop_deg": 6.0, "hreben": false},
			{"posun_m": 5.0, "prevyseni_m": 10.0, "vlna_m": 140.0, "drsnost": 0.45, "strop_deg": 25.0, "hreben": false},
			{"posun_m": 8.0, "prevyseni_m": 24.0, "vlna_m": 360.0, "drsnost": 0.35, "strop_deg": 40.0, "hreben": true},
			{"posun_m": 2.0, "prevyseni_m": 3.0, "vlna_m": 150.0, "drsnost": 0.40, "strop_deg": 10.0, "hreben": false},
		],
		"oktav": 4,
		"rezerva_sklonu": 0.8,           # podíl stropu pro šum (zbytek pro přechody mezi biomy)
		# mapa hornin (1.7.1, 2.1): kde a kolik; zástupci podle biomu (id z materialy.csv, pásma 57–74 se nepoužívají)
		"horniny_roztec_m": 192.0, "horniny_prechod_m": 160.0, "zastupcu": 3,
		"horniny_biomu": [[54, 3, 52, 51], [12, 3, 54, 53], [52, 44, 45, 46, 49], [6, 37, 34, 41, 40, 39], [7, 26, 36]],
		# masiv E87 v hornatině (1.4, úkol 10): váha = smoothstep(m0, m1, váha hornatiny); výška = zdvih + amp · n01 + detail
		"masiv_m0": 0.35, "masiv_m1": 1.0, "masiv_zdvih_m": 8.0, "p87_amp_m": 12.0, "p87_freq": 0.008, "p87_detail_m": 0.75,
		"p87_dfreq": 0.05, "masiv_podil_stropu": 0.4, "masiv_podil_detail": 0.2,	# E87 mělo freq 0,03 / dfreq 0,25 (sloupec 32 m)
		"podhuri_m": 4.0, "podhuri_vlna_m": 48.0,   # podhůří v pásu přechodu masivu (4 · w · (1 − w))
		# sopky (1.14)
		"sopek": 2, "sopky_roztec_m": 384.0, "sopky_roztec_tol": 0.10, "sopka_vyska_min_m": 20.0, "sopka_vyska_max_m": 40.0,
		"sopka_sklon_deg": 17.0, "sopka_gamma": 1.5, "sopka_strop_deg": 35.0, "krater_r_podil": 0.12,
		"krater_hloubka_podil": 0.25, "sopka_rezerva_m": 5.0, "sopky_okraj_m": 320.0,
		"strop_povrchu_hladkost_m": 2.0,  # měkký strop povrchu = okraj sloupce − rezerva (hladké minimum, sklon nezvětší)
	}

# ---------------------------------------------------------------- stav (počítá se jednou ze seedu a parametrů)
var p: Dictionary
var sd: int
var sloupec_m: float
var neutral_m: float
var strop_povrchu_m: float
var svet_m: float
var bS: float; var bB: float; var bN: int    # rozteč / přechod / počet buněk mapy biomů na stranu (+ okraj 2)
var bx := PackedFloat64Array(); var by := PackedFloat64Array(); var bt := PackedByteArray()
var hS: float; var hB: float; var hN: int
var hx := PackedFloat64Array(); var hy := PackedFloat64Array(); var hc: Array = []   # hc[i] = PackedFloat32Array konc. podle biomu × zástupce
var rel_noise: Array = []           # FastNoiseLite podle biomu
var rel_posun := PackedFloat64Array(); var rel_amp := PackedFloat64Array(); var rel_hreben := PackedByteArray()
var tan_strop := PackedFloat64Array()
var gradient: Dictionary = {}       # změřený gradient šumů (na jednotku amplitudy, 1/m)
var m87_amp: float; var m87_det: float; var m87_zdvih: float
var pod_noise: FastNoiseLite; var pod_amp: float
var sopky: Array = []               # [{x, y, H, R, rc, d, gamma, vyska_okoli}]
var sx := PackedFloat64Array(); var sy := PackedFloat64Array(); var sR := PackedFloat64Array()
var tan_sopka: float
var hladkost: float

func _init(par := {}) -> void:
	p = vychozi()
	for k in par: p[k] = par[k]
	sd = int(p.seed)
	var rz: Dictionary = p.rozmery
	sloupec_m = float(rz.sloupec_m); neutral_m = sloupec_m * 0.5; svet_m = float(rz.svet_max_m)
	strop_povrchu_m = sloupec_m - float(p.sopka_rezerva_m)
	hladkost = float(p.strop_povrchu_hladkost_m)
	_mapa_biomu()
	_relief()
	_masiv()
	_sopky()
	_mapa_hornin()

# ---------------------------------------------------------------- hash → [0, 1)
func _u(ucel: String, i: int, j: int, k := 0) -> float:
	var h := H.mix(sd, ucel, ((i + 4096) << 24) ^ ((j + 4096) << 8) ^ k)
	return float(H.shr(h, 11)) / 9007199254740992.0   # 53 bitů

# ---------------------------------------------------------------- mapa biomů (hrubé body ze seedu na celé ploše)
func _mapa_biomu() -> void:
	bS = float(p.biom_roztec_m); bB = float(p.biom_prechod_m)
	bN = int(ceil(svet_m / bS)) + 4
	bx.resize(bN * bN); by.resize(bN * bN); bt.resize(bN * bN)
	var cum := PackedFloat64Array(); var s := 0.0
	for v in p.podil: s += float(v); cum.append(s)
	for a in bN:
		for b in bN:
			var i := a - 2; var j := b - 2
			var k := a * bN + b
			bx[k] = (i + 0.15 + 0.7 * _u("V1_BIOM_X", i, j)) * bS
			by[k] = (j + 0.15 + 0.7 * _u("V1_BIOM_Y", i, j)) * bS
			var u := _u("V1_BIOM_T", i, j) * s
			var t := 0
			while t < 4 and u >= cum[t]: t += 1
			bt[k] = t

## váhy biomů v bodě (5 čísel, součet 1): měkký Voronoi w_i = (1 − (d_i − d_min)/B)², spojitý v x, y
func vahy(x: float, y: float) -> PackedFloat64Array:
	var w := PackedFloat64Array(); w.resize(5)
	var ci := floori(x / bS) + 2; var cj := floori(y / bS) + 2
	var ds := PackedFloat64Array(); var ts := PackedByteArray()
	var dmin := 1e30
	for a in range(ci - 2, ci + 3):
		for b in range(cj - 2, cj + 3):
			if a < 0 or b < 0 or a >= bN or b >= bN: continue
			var k := a * bN + b
			var d := sqrt((x - bx[k]) * (x - bx[k]) + (y - by[k]) * (y - by[k]))
			ds.append(d); ts.append(bt[k])
			if d < dmin: dmin = d
	var sum := 0.0
	for n in ds.size():
		var q := 1.0 - (ds[n] - dmin) / bB
		if q > 0.0:
			w[ts[n]] += q * q; sum += q * q
	for t in 5: w[t] /= sum
	return w

# ---------------------------------------------------------------- reliéf z parametrů biomu (1.13)
## max |∇n| na jednotku frekvence, změřené na pevné sadě bodů (deterministické); n v [−1, 1]
static func _grad_sumu(n: FastNoiseLite, freq: float, vzorku := 8000) -> float:
	var g := 0.0
	var e := 0.001 / freq   # krok diference ≪ vlnová délka nejjemnější oktávy (0,02/f podhodnotilo gradient až 1,4×)
	for i in vzorku:
		var x := (float(i % 61) * 7.31 + float(i) * 0.137) / freq
		var y := (float(i / 61) * 5.77 + float(i % 7) * 0.71) / freq
		var gx := (n.get_noise_2d(x + e, y) - n.get_noise_2d(x - e, y)) / (2.0 * e)
		var gy := (n.get_noise_2d(x, y + e) - n.get_noise_2d(x, y - e)) / (2.0 * e)
		g = maxf(g, sqrt(gx * gx + gy * gy))
	return g   # 1/m

func _relief() -> void:
	var bi: Array = p.biomy
	rel_posun.resize(5); rel_amp.resize(5); rel_hreben.resize(5); tan_strop.resize(5)
	for t in 5:
		var b: Dictionary = bi[t]
		var f := 1.0 / float(b.vlna_m)
		var n := BG.noise(sd, "V1_RELIEF_%d" % t, 0, f, int(p.oktav))
		n.fractal_gain = float(b.drsnost)
		rel_noise.append(n)
		var g := _grad_sumu(n, f)
		var hreben := bool(b.hreben)
		var gk := g * (2.0 if hreben else 1.0)          # hřbet (1 − |n|)²: |∇| ≤ 2 |∇n|
		tan_strop[t] = tan(deg_to_rad(float(b.strop_deg)))
		var podil := float(p.rezerva_sklonu) * (1.0 - (float(p.masiv_podil_stropu) if t == HORNATINA else 0.0))
		var a_max := podil * tan_strop[t] / gk
		rel_amp[t] = minf(float(b.prevyseni_m), a_max)
		rel_posun[t] = float(b.posun_m)
		rel_hreben[t] = 1 if hreben else 0
		gradient["relief_%d" % t] = {"g_1_m": g, "amp_pozadovana_m": float(b.prevyseni_m), "amp_m": rel_amp[t]}

func _rel(t: int, x: float, y: float) -> float:
	var n: float = rel_noise[t].get_noise_2d(x, y)
	if rel_hreben[t] == 1:
		var rd := 1.0 - absf(n)
		return rel_posun[t] + rel_amp[t] * rd * rd    # E49/E90 hřbet
	return rel_posun[t] + rel_amp[t] * n

# ---------------------------------------------------------------- masiv E87 + podhůří
func _masiv() -> void:
	# E87 n01 = 0,5 · šum + 0,5 → |∇n01| = 0,5 |∇šum|; šumy z geo2 (domain warp) se změří stejně jako reliéf
	var na := G2._noise(sd, "MASSIF87", 0, float(p.p87_freq))
	var nd := G2._noise(sd, "MASSIF87D", 0, float(p.p87_dfreq))
	var ga := 0.5 * _grad_sumu(na, float(p.p87_freq))
	var gd := _grad_sumu(nd, float(p.p87_dfreq))           # detail · (2 n01 − 1) = detail · šum
	var rozpocet := float(p.rezerva_sklonu) * float(p.masiv_podil_stropu) * tan(deg_to_rad(float(p.biomy[HORNATINA].strop_deg)))
	var pd := float(p.masiv_podil_detail)
	m87_amp = minf(float(p.p87_amp_m), (1.0 - pd) * rozpocet / ga)
	m87_det = minf(float(p.p87_detail_m), pd * rozpocet / gd)
	m87_zdvih = float(p.masiv_zdvih_m)
	var fp := 1.0 / float(p.podhuri_vlna_m)
	pod_noise = BG.noise(sd, "V1_PODHURI", 0, fp, 3)
	var gp := _grad_sumu(pod_noise, fp)
	pod_amp = minf(float(p.podhuri_m), 0.5 * rozpocet / gp)
	gradient["masiv"] = {"g87_1_m": ga, "gdet_1_m": gd, "amp_pozadovana_m": float(p.p87_amp_m), "detail_pozadovany_m": float(p.p87_detail_m), "amp_m": m87_amp, "detail_m": m87_det,
		"podhuri_g_1_m": gp, "podhuri_amp_m": pod_amp}

func _vaha_masivu(wh: float) -> float:
	return smoothstep(float(p.masiv_m0), float(p.masiv_m1), wh)

func _masiv_h(x: float, y: float) -> float:
	return m87_zdvih + m87_amp * G2.n01(sd, "MASSIF87", 0, float(p.p87_freq), x, y) \
		+ m87_det * (2.0 * G2.n01(sd, "MASSIF87D", 0, float(p.p87_dfreq), x, y) - 1.0)

# ---------------------------------------------------------------- výška bez sopek a se sopkami
func _vyska_bez_sopek(x: float, y: float, w: PackedFloat64Array) -> float:
	var h := neutral_m
	for t in 5:
		if w[t] > 0.0: h += w[t] * _rel(t, x, y)
	var wm := _vaha_masivu(w[HORNATINA])
	if wm > 0.0:
		h += wm * _masiv_h(x, y)
		h += 4.0 * wm * (1.0 - wm) * pod_amp * pod_noise.get_noise_2d(x, y)
	return h

## kužel sopky (E49 zobecněno): r v m od středu
func _kuzel(i: int, r: float) -> float:
	var s: Dictionary = sopky[i]
	if r >= float(s.R): return 0.0
	var rc := float(s.rc)
	if r >= rc: return float(s.H) * pow((float(s.R) - r) / (float(s.R) - rc), float(s.gamma))
	var q := r / rc
	return float(s.H) - float(s.d) * (1.0 - q * q)

## hladké minimum se stropem povrchu: −k ln(e^(−h/k) + e^(−c/k)), gradient se nezvětší
func _smin(h: float) -> float:
	var c := strop_povrchu_m; var k := hladkost
	var m := minf(h, c)
	return m - k * log(1.0 + exp(-absf(h - c) / k))

func vyska(x: float, y: float) -> float:
	return vyska_w(x, y, vahy(x, y))

func vyska_w(x: float, y: float, w: PackedFloat64Array) -> float:
	var h := _vyska_bez_sopek(x, y, w)
	for i in sx.size():
		var dx := x - sx[i]; var dy := y - sy[i]
		var r2 := dx * dx + dy * dy
		if r2 < sR[i] * sR[i]: h += _kuzel(i, sqrt(r2))
	return _smin(h)

# ---------------------------------------------------------------- sopky (1.14)
func _sopky() -> void:
	var n := int(p.sopek); var d := float(p.sopky_roztec_m); var tol := float(p.sopky_roztec_tol)
	var okraj := float(p.sopky_okraj_m)
	var ts := tan(deg_to_rad(float(p.sopka_sklon_deg)))
	tan_sopka = tan(deg_to_rad(float(p.sopka_strop_deg)))
	var tan_rel := tan_strop[SOPECNA]
	var stred: Array = []
	for i in n:
		var c := Vector2.ZERO
		for pokus in 64:
			if i == 0:
				c = Vector2(okraj + _u("V1_SOPKA_X", i, pokus) * (svet_m - 2.0 * okraj), okraj + _u("V1_SOPKA_Y", i, pokus) * (svet_m - 2.0 * okraj))
			else:
				var uh := _u("V1_SOPKA_U", i, pokus) * TAU
				var dd := d * (1.0 + tol * 0.8 * (2.0 * _u("V1_SOPKA_D", i, pokus) - 1.0))
				c = Vector2(stred[i - 1]) + Vector2(cos(uh), sin(uh)) * dd
			var ok := c.x >= okraj and c.y >= okraj and c.x <= svet_m - okraj and c.y <= svet_m - okraj
			for q in stred:
				if c.distance_to(q) < d * (1.0 - tol): ok = false
			if ok: break
		stred.append(c)
	# sopka si bere bod mapy biomů své buňky (biom je zdrojem výskytu sopek, 2.1)
	for c in stred:
		var a := floori(c.x / bS) + 2; var b := floori(c.y / bS) + 2
		var k := a * bN + b
		bx[k] = c.x; by[k] = c.y; bt[k] = SOPECNA
	for i in n:
		var c: Vector2 = stred[i]
		var t := _u("V1_SOPKA_VEL", i, 0)
		var Hs := lerpf(float(p.sopka_vyska_min_m), float(p.sopka_vyska_max_m), t)
		var w := vahy(c.x, c.y)
		var h0 := _vyska_bez_sopek(c.x, c.y, w)
		var rezerva := 2.0 * rel_amp[SOPECNA] + 0.5
		var Hmax := strop_povrchu_m - h0 - rezerva
		var Hef := minf(Hs, Hmax)
		var Rz := Hef / ts                       # vodorovná délka svahu úpatí → okraj kráteru
		var rc := float(p.krater_r_podil) * Rz
		var gamma := minf(float(p.sopka_gamma), (0.95 * tan_sopka - tan_rel) / ts)
		var dk := minf(float(p.krater_hloubka_podil) * Hef, 0.5 * rc * (0.95 * tan_sopka - tan_rel))
		sopky.append({"x": c.x, "y": c.y, "H_seed": Hs, "H": Hef, "R": Rz + rc, "rc": rc, "d": dk, "gamma": gamma,
			"vyska_okoli": h0, "prumer_upati_m": 2.0 * (Rz + rc)})
		sx.append(c.x); sy.append(c.y); sR.append(Rz + rc)

# ---------------------------------------------------------------- mapa hornin (kde a kolik, 1.7.1)
func _mapa_hornin() -> void:
	hS = float(p.horniny_roztec_m); hB = float(p.horniny_prechod_m)
	hN = int(ceil(svet_m / hS)) + 4
	hx.resize(hN * hN); hy.resize(hN * hN)
	var hb: Array = p.horniny_biomu
	for a in hN:
		for b in hN:
			var i := a - 2; var j := b - 2
			hx[a * hN + b] = (i + 0.15 + 0.7 * _u("V1_HORN_X", i, j)) * hS
			hy[a * hN + b] = (j + 0.15 + 0.7 * _u("V1_HORN_Y", i, j)) * hS
			var c := PackedFloat32Array()
			for t in 5:
				var z: Array = hb[t]
				var s := 0.0; var row := PackedFloat32Array()
				for m in z.size():
					var u := _u("V1_HORN_C", i, j, t * 16 + m)
					row.append(u * u); s += u * u
				for m in z.size(): c.append(row[m] / s)
			hc.append(c)

## zastoupení hornin v bodě: [[id, podíl], …] seřazené sestupně (nejvýš „zastupcu“, podíly normalizované)
func horniny(x: float, y: float, w := PackedFloat64Array()) -> Array:
	if w.is_empty(): w = vahy(x, y)
	var hb: Array = p.horniny_biomu
	var ci := floori(x / hS) + 2; var cj := floori(y / hS) + 2
	var ks := []; var ds := PackedFloat64Array(); var dmin := 1e30
	for a in range(ci - 2, ci + 3):
		for b in range(cj - 2, cj + 3):
			if a < 0 or b < 0 or a >= hN or b >= hN: continue
			var k := a * hN + b
			var d := sqrt((x - hx[k]) * (x - hx[k]) + (y - hy[k]) * (y - hy[k]))
			ks.append(k); ds.append(d); dmin = minf(dmin, d)
	var konc := {}
	var sw := 0.0
	var wp := PackedFloat64Array()
	for n in ks.size():
		var q := maxf(0.0, 1.0 - (ds[n] - dmin) / hB)
		wp.append(q * q); sw += q * q
	for n in ks.size():
		if wp[n] <= 0.0: continue
		var c: PackedFloat32Array = hc[ks[n]]
		var o := 0
		for t in 5:
			var z: Array = hb[t]
			if w[t] > 0.0:
				for m in z.size():
					var id := int(z[m])
					konc[id] = float(konc.get(id, 0.0)) + w[t] * wp[n] / sw * c[o + m]
			o += z.size()
	var arr := []
	for id in konc: arr.append([id, konc[id]])
	arr.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return arr

# ---------------------------------------------------------------- rozhraní 2.2
func sloupec(x: float, y: float) -> Dictionary:
	var w := vahy(x, y)
	var biom := 0
	for t in 5:
		if w[t] > w[biom]: biom = t
	var s := -1
	for i in sx.size():
		if (x - sx[i]) * (x - sx[i]) + (y - sy[i]) * (y - sy[i]) < sR[i] * sR[i]: s = i
	var hr := horniny(x, y, w)
	var z := int(p.zastupcu)
	if hr.size() > z:
		hr = hr.slice(0, z)
		var sm := 0.0
		for e in hr: sm += float(e[1])
		for e in hr: e[1] = float(e[1]) / sm
	return {"povrch_m": vyska_w(x, y, w), "biom": biom, "biom_vahy": w, "horniny": hr,
		"masiv": _vaha_masivu(w[HORNATINA]), "sopka": s, "hranice": [], "hladina_m": NAN}

func bod(x: float, y: float, z: float) -> int:
	var w := vahy(x, y)
	if z > vyska_w(x, y, w): return VZDUCH
	var hr := horniny(x, y, w)
	return int(hr[0][0]) if not hr.is_empty() else VZDUCH

## lokální strop sklonu (tan) pro test 2: přechod patří strmějšímu biomu, v kuželu sopky strop sopky
func strop_tan(x: float, y: float) -> float:
	var w := vahy(x, y)
	var s := 0.0
	for t in 5:
		if w[t] > 0.0: s = maxf(s, tan_strop[t])
	for i in sx.size():
		if (x - sx[i]) * (x - sx[i]) + (y - sy[i]) * (y - sy[i]) < sR[i] * sR[i]: s = maxf(s, tan_sopka)
	return s

## počátek výchozího světa 3 × 3 (m)
func start_m() -> Vector2:
	var b: Array = p.start_blok
	return Vector2(float(b[0]), float(b[1])) * float(p.rozmery.blok_m)
