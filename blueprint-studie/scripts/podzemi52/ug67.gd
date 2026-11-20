extends RefCounted
## E67 (Jan 15:54–16:00): podzemní voda jako přetoky ve 3D nad pásmy ug_funkce (režim p67_rezim = "pretok").
## Voda od vstupu teče nejdřív DOLŮ (pásmo tělesa, které se dotýká zespodu ve stejném sloupci), jinak do stran do sousedních
## pásem s nižším dnem, rozdělená vahou perm × výška překryvu (jako D∞ na povrchu). Výstup ve výšce dna pásma (odkrytá stěna
## ostrova – p67_okraj, nižší povrch souseda) vezme celý průtok pásma. Stojatá voda („vana“) jen v uzavřené misce bez nižšího
## výstupu: priority-flood ze dna pasti (klíč max(hladina, spodek překryvu), výstupy F._outs) stoupá do prvního výstupu nebo
## do prahu, za kterým je pásmo s nižším dnem mimo past → past plná po práh, přebytek (průtok − průsak) teče dál od prahu.
## Pasti, které se při stoupání potkají, se spojí (fill-spill-merge). Ustálený stav, žádná simulace po krocích; časy plnění
## pastí = objem / čistý průtok. Pořadí: halda (hodnota, id) → výsledek nezávisí na pořadí sousedů ani vstupů.
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const CH = preload("res://scripts/voda/cas_hry.gd")   # E77: čas hry na jednom místě
const VS = preload("res://scripts/voda/voda_svet.gd")
const HP = preload("res://scripts/alg64/heap64.gd")
const E := 1e-6

static func _perm(c: Dictionary, b: int, t: Dictionary) -> float:
	var m: int = c.mat[b]
	if m == 0: return 1.0
	if c.has("perm75") and c.perm75.has(b): return maxf(float(c.perm75[b]), maxf(float(t.get(m, [0.0])[0]), 0.01))   # E75: krasová dutina v pásmu
	return maxf(float(t.get(m, [0.0])[0]), 0.01)

## pásmo tělesa přímo pod b ve stejném sloupci (dotýká se dna b), nejvyšší; -1 = žádné
static func _below(c: Dictionary, b: int) -> int:
	var cc: int = c.bcol[b]; var lo: float = c.lo[b]; var best := -1
	for b2 in range(c.cs[cc], c.cs[cc + 1]):
		if b2 == b or c.body[b2] == 0: continue
		if float(c.lo[b2]) < lo - E and float(c.hi[b2]) >= lo - E and (best < 0 or float(c.hi[b2]) > float(c.hi[best])): best = b2
	return best

## E71: hydraulická vodivost K (m/s) z propustnosti tabulky (mapování tabulky v4: perm = (log10 K + 9) / 6)
static func _kms(c: Dictionary, b: int, t: Dictionary) -> float:
	return pow(10.0, 6.0 * _perm(c, b, t) - 9.0)

## E71: zbývající kapacita rozhraní b → bl dolů (l/s): K_eff · A · spád 1 · 1000 · p71_cas; K_eff = K spodní vrstvy (pomer)
## nebo harmonický průměr K obou (p70_prumer = harmonicky)
static func _caprem(c: Dictionary, b: int, bl: int) -> float:
	var K: Dictionary = c._k71
	var k2 := _kms(c, bl, K.t)
	if bool(K.harm):
		var k1 := _kms(c, b, K.t); k2 = 2.0 * k1 * k2 / (k1 + k2)
	return maxf(k2 * float(K.sc) - float(K.capu.get(b, 0.0)), 0.0)

## E71 P: průsak protékané vody dnem do polopropustného materiálu pod pásmem (wq · A jako dno pasti v F._leak), nejvýš f
static func _seep(c: Dictionary, b: int, f: float) -> float:
	var K: Dictionary = c._k71
	var cc: int = c.bcol[b]; var lo: float = c.lo[b]
	for u in range(c.cs[cc], c.cs[cc + 1]):
		if u == b or absf(float(c.hi[u]) - lo) >= E or c.body[u] == 1: continue
		var w: float = c.wq[u]
		if w <= 0.0: continue
		var s := minf(f, w * float(c.A) - float(K.lku.get(b, 0.0)))
		if s <= 0.0: return f
		if float(c.get("_slu72", 0.0)) > 0.0:   # E72: drobný průsak / zbytek → do větší části
			s = _merge2(s, f - s, float(c._slu72))
			if s <= 0.0: return f
		K.lku[b] = float(K.lku.get(b, 0.0)) + s; K.wl = float(K.wl) + s
		return f - s
	return f

## E72: dělení f = a + b; když je menší část pod prahem a druhá je větší, připadne celá větší části (hmota zůstává).
## Vrací novou hodnotu a. Při rovnosti se nedělí nic (symetrie).
static func _merge2(a: float, b: float, pmin: float) -> float:
	if a < pmin and b > a: return 0.0
	if b < pmin and a > b: return a + b
	return a

## E72: výstupy < pmin se přičtou nejbližšímu silnému výstupu (q ≥ pmin; vzdálenost sloupců, pak větší q); shoda vzdálenosti
## i q → rovným dílem (symetrie). Když žádný silný není, všechno do největšího (shoda → rovným dílem). Hmota zůstává.
static func _merge_outs(c: Dictionary, outs: Dictionary, pmin: float) -> Array:
	var H: int = c.H
	var ks := outs.keys(); ks.sort()
	var strong := []; var weak := []
	for k in ks:
		if float(outs[k][3]) >= pmin: strong.append(k)
		else: weak.append(k)
	if weak.is_empty(): return [0, 0.0]
	if strong.is_empty():
		var mx := 0.0
		for k in ks: mx = maxf(mx, float(outs[k][3]))
		for k in ks:
			if float(outs[k][3]) >= mx * (1.0 - 1e-12): strong.append(k)
		weak = []
		for k in ks:
			if not strong.has(k): weak.append(k)
		var tot := 0.0
		for k in weak: tot += float(outs[k][3]); outs.erase(k)
		for k in strong: outs[k][3] = float(outs[k][3]) + tot / strong.size()
		return [weak.size(), -1.0]
	var add := {}; var dmax := 0
	for k in weak:
		var cw: int = outs[k][2]; var xw := cw / H; var yw := cw % H
		var best := []; var bd := -1; var bq := 0.0
		for k2 in strong:
			var cs: int = outs[k2][2]; var dx := cs / H - xw; var dy := cs % H - yw
			var d := dx * dx + dy * dy; var qq := float(outs[k2][3])
			if bd < 0 or d < bd or (d == bd and qq > bq * (1.0 + 1e-12)): best = [k2]; bd = d; bq = qq
			elif d == bd and qq >= bq * (1.0 - 1e-12): best.append(k2)
		for k2 in best: add[k2] = float(add.get(k2, 0.0)) + float(outs[k][3]) / best.size()
		dmax = maxi(dmax, bd)
	for k in weak: outs.erase(k)
	for k in add: outs[k][3] = float(outs[k][3]) + float(add[k])
	return [weak.size(), sqrt(float(dmax))]   # počet sloučených, největší vzdálenost (sloupce řídicí mřížky)

## E71: přičte průtok a vloží do haldy jen tehdy, když tam pásmo ještě nečeká (bez duplicit → méně kroků sestupu)
static func _qpush(c: Dictionary, qb: Dictionary, down, g: int, d: float) -> void:
	var was := float(qb.get(g, 0.0))
	qb[g] = was + d
	if was <= 0.0: down.push(float(c.lo[g]), g)

static func solve(c: Dictionary, entries: PackedInt32Array, q: float, ex: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var t := VS.table()
	var NB: int = c.lo.size()
	var trace := q <= 0.0
	var qe := q if not trace else 1.0
	var qb := {}                 # pásmo → průtok čekající na rozdělení
	var down := HP.new()         # sestup: nejvyšší dno první
	var ents := []
	for e in entries:
		if e >= 0: ents.append(e)
	for e in ents:
		qb[e] = float(qb.get(e, 0.0)) + qe / ents.size(); down.push(float(c.lo[e]), e)
	var wet := {}                # mokrá pásma sestupu (film u dna)
	var pit_of := {}             # pásmo → index pasti
	var pits := []               # {bands, level, q_in, leak, over, typ: "prah"|"vystup"|"nenaplni", tgt, out, merged}
	var outs := {}               # "typ|sloupec" (E71 K: "|z" navíc) → [z, typ, sloupec, q, pásmo]
	var qtot := {}               # celkový průtok mokrým pásmem (pro práh vykreslení větví)
	var prune := bool(c.get("prune67", true)) and not trace
	var pmin := float(c.get("prune67_min", 0.1))
	var remizy := bool(c.get("remizy69", true))
	var harm := String(c.get("prumer70", "pomer")) == "harmonicky"
	var kap := bool(c.get("kap71", true)) and not trace     # E71 K: kapacita průtoku dolů
	var prus := bool(c.get("prus71", true)) and not trace   # E71 P: průsak protékané vody
	var slu := prune and bool(c.get("slu72", true))         # E72: drobné větve kapacity / průsaku a výstupy < p67_prune_min slučovat
	c._slu72 = pmin if slu and bool(c.get("slu72p", true)) else 0.0   # E72: průsak protékané vody taky (p72_prusak)
	if kap: outs["_z71"] = true
	c._k71 = {"on": kap, "harm": harm, "sc": 1000.0 * CH.faktor(c) * float(c.A), "capu": {}, "lku": {}, "wl": 0.0, "t": t, "prus": prus}
	var guard := 0
	var gmax := 40 * NB + 1000
	var defer := []              # E71 K: dna pastí ve stejné výšce se zakládají až po ostatních pásmech té výšky (nezávislost na id)
	var deflo := 0.0
	while (down.size() > 0 or not defer.is_empty()) and guard < gmax:
		guard += 1
		if not defer.is_empty() and (down.size() == 0 or down.top_v() < deflo - E):
			for d in defer:
				if pit_of.has(int(d[0])): _pit_add(c, pits, _root(pits, int(pit_of[int(d[0])])), float(d[1]), qb, down, outs)
				else: _pit_fill(c, pits, pit_of, int(d[0]), float(d[1]), qb, down, outs, ex)
			defer = []
			continue
		var b := down.pop()
		var f := float(qb.get(b, 0.0))
		if f <= 1e-12: qb[b] = 0.0; continue
		qb[b] = 0.0
		if pit_of.has(b):
			_pit_add(c, pits, _root(pits, int(pit_of[b])), f, qb, down, outs)
			continue
		wet[b] = true
		qtot[b] = float(qtot.get(b, 0.0)) + f
		var lo: float = c.lo[b]
		var bl := _below(c, b)
		if kap and bl >= 0:   # E71 K: dolů nejvýš zbývající kapacita rozhraní, zbytek dál jako dosud (výstup / do stran / past)
			var dn := minf(f, _caprem(c, b, bl))
			if slu: dn = _merge2(dn, f - dn, pmin)   # E72: menší z větví (dolů / dál) < práh → do větší
			if dn > 0.0:
				c._k71.capu[b] = float(c._k71.capu.get(b, 0.0)) + dn
				_qpush(c, qb, down, bl, dn)
				f -= dn
			if f <= 1e-12: continue
		# 1) výstup ve výšce dna (stěna ostrova / nižší povrch souseda) – nejnižší, při shodě nejmenší sloupec
		var bo := []
		for o in F._outs(c, b, ex):
			if float(o[0]) <= lo + E and (bo.is_empty() or float(o[0]) < float(bo[0]) - E or (absf(float(o[0]) - float(bo[0])) <= E and int(o[2]) < int(bo[2]))): bo = o
		if not bo.is_empty():
			if prus: f = _seep(c, b, f)
			if f > 1e-12: _out_add(outs, bo, f, b)
			continue
		# 2) dolů
		if bl >= 0 and not kap:
			qb[bl] = float(qb.get(bl, 0.0)) + f; down.push(float(c.lo[bl]), bl); continue
		# 3) do stran do pásem s nižším dnem, váha perm × výška překryvu
		var cand := []; var ws := 0.0
		var k1 := _perm(c, b, t)
		for nb in F._nbrs(c, b):
			var b2: int = nb[0]
			if int(c.bcol[b2]) == int(c.bcol[b]) or float(c.lo[b2]) >= lo - E: continue
			var k2 := _perm(c, b2, t)
			if harm: k2 = 2.0 * k1 * k2 / (k1 + k2)   # E70: propustnost rozhraní = harmonický průměr obou materiálů
			var w := k2 * maxf(float(nb[2]) - float(nb[1]), 0.01)
			cand.append([b2, w]); ws += w
		if ws > 0.0 and prus:
			f = _seep(c, b, f)
			if f <= 1e-12: continue
		if ws > 0.0:
			cand.sort_custom(func(a, b3): return a[0] < b3[0])
			if prune and cand.size() > 1:   # E67b p67_prune: větve s podílem < p67_prune_min → do nejsilnější větve (hmota zůstává)
				var bi := 0
				for i in cand.size():
					if float(cand[i][1]) > float(cand[bi][1]): bi = i
				var top := {bi: true}
				if remizy:   # E69: větve se stejnou (největší) vahou jsou rovnocenné → přebytek rovným dílem všem (symetrie)
					for i in cand.size():
						if float(cand[i][1]) >= float(cand[bi][1]) * (1.0 - 1e-12): top[i] = true
				var moved := 0.0
				for i in cand.size():
					if not top.has(i) and f * float(cand[i][1]) / ws < pmin: moved += float(cand[i][1]); cand[i][1] = 0.0
				for i in top: cand[i][1] = float(cand[i][1]) + moved / top.size()
			for e in cand:
				var b2: int = e[0]
				if float(e[1]) <= 0.0: continue
				qb[b2] = float(qb.get(b2, 0.0)) + f * float(e[1]) / ws; down.push(float(c.lo[b2]), b2)
			continue
		# 4) dno pasti
		if kap: defer.append([b, f]); deflo = lo; continue
		_pit_fill(c, pits, pit_of, b, f, qb, down, outs, ex)
	outs.erase("_z71")
	var slo: Array = _merge_outs(c, outs, pmin) if slu else [0, 0.0]
	c.erase("_slu72")
	var r := _result(c, entries, q, trace, wet, pits, outs, t0, guard >= gmax)
	var wq := PackedFloat64Array()
	for b in r.wet67: wq.append(float(qtot.get(b, 0.0)) * (0.0 if trace else 1.0))
	r.wetq67 = wq
	r.leak67w = float(c._k71.wl)
	r.slouceno72 = slo[0]; r.slouceno72_d = slo[1]
	c.erase("_k71")
	return r

## kam steče voda z pásma s (bez průtoku): koncová pásma sestupu (dno pasti / pásmo s výstupem ve výšce dna)
static func _probe(c: Dictionary, s: int, ex: Dictionary) -> Array:
	var seen := {s: true}; var st := [s]; var term := []
	while not st.is_empty() and seen.size() < 200000:
		var b: int = st.pop_back()
		var lo: float = c.lo[b]
		var fl := false
		for o in F._outs(c, b, ex):
			if float(o[0]) <= lo + E: fl = true; break
		if fl: term.append(-1 - b); continue
		var bl := _below(c, b)
		if bl >= 0:
			if not seen.has(bl): seen[bl] = true; st.append(bl)
			continue
		var any := false
		for nb in F._nbrs(c, b):
			var b2: int = nb[0]
			if int(c.bcol[b2]) == int(c.bcol[b]) or float(c.lo[b2]) >= lo - E: continue
			any = true
			if not seen.has(b2): seen[b2] = true; st.append(b2)
		if not any: term.append(b)
	return term

static func _root(pits: Array, i: int) -> int:
	while int(pits[i].merged) >= 0: i = int(pits[i].merged)
	return i

static func _out_add(outs: Dictionary, o: Array, f: float, b: int) -> void:
	var k := "%s|%d" % [String(o[1]), int(o[2])]
	if outs.has("_z71"): k += "|%.4f" % float(o[0])   # E71 K: výstupy ve stejném sloupci v různé výšce (vrstvy) zvlášť
	if not outs.has(k): outs[k] = [float(o[0]), String(o[1]), int(o[2]), 0.0, b]
	outs[k][3] = float(outs[k][3]) + f

## průtok z pasti do jejího výstupu; E69: při remíze výstupů (p.outs) rovným dílem
static func _pit_out(outs: Dictionary, p: Dictionary, f: float) -> void:
	var ol: Array = p.get("outs", [p.out])
	for o in ol: _out_add(outs, o, f / ol.size(), -1)

## další průtok do už vyřešené pasti: přebytek nad průsakem jde za práh / do výstupu
static func _pit_add(c: Dictionary, pits: Array, i: int, f: float, qb: Dictionary, down, outs: Dictionary) -> void:
	var p: Dictionary = pits[i]
	if bool(c._k71.on):
		p.q_in = float(p.q_in) + f; _pit_dist(c, p, qb, down, outs); return
	var old := maxf(float(p.q_in) - float(p.leak), 0.0)
	p.q_in = float(p.q_in) + f
	p.lused = minf(float(p.q_in), float(p.leak))
	var dlt := maxf(float(p.q_in) - float(p.leak), 0.0) - old
	if dlt <= 1e-12: return
	if p.typ == "nenaplni": p.typ = String(p.get("typ_full", "uzavrena"))
	if not p.out.is_empty(): _pit_out(outs, p, dlt)
	elif int(p.tgt) >= 0:
		var g: int = p.tgt
		qb[g] = float(qb.get(g, 0.0)) + dlt; down.push(float(c.lo[g]), g)

## E71 K: svislý spoj člena pasti id dolů (pásmo tělesa pod ním) = průsak pasti, ne práh; [bl, kapacita, klíč floodu, odesláno]
static func _link_add(c: Dictionary, p: Dictionary, id: int, key: float) -> int:
	var bl := _below(c, id)
	if bl < 0: return -1
	var cap := _caprem(c, id, bl)
	if cap > 0.0: p.links.append([bl, cap, key, 0.0])
	return bl

## E71 K: rozdělení přítoku pasti: průsaky dolů po skupinách klíče floodu (nejníž první, uvnitř skupiny poměrně → symetrie),
## pak průsak do okolí (F._leak), zbytek přetéká výstupem / prahem. Už odeslané se nevrací (přítok jen roste).
static func _pit_dist(c: Dictionary, p: Dictionary, qb: Dictionary, down, outs: Dictionary) -> void:
	var lk: Array = p.links
	lk.sort_custom(func(a, b): return float(a[2]) < float(b[2]) - E or (absf(float(a[2]) - float(b[2])) <= E and int(a[0]) < int(b[0])))
	var rem := float(p.q_in)
	var i := 0
	while i < lk.size():
		var j := i; var dem := 0.0
		while j < lk.size() and absf(float(lk[j][2]) - float(lk[i][2])) <= E:
			if not p.inp.has(int(lk[j][0])): dem += float(lk[j][1])
			j += 1
		var take := minf(maxf(rem, 0.0), dem)
		var used := 0.0
		for k in range(i, j):
			var e: Array = lk[k]
			if p.inp.has(int(e[0])): used += float(e[3]); continue   # E72 oprava: už odeslaný průsak do pásma, které pak padlo do pasti, se nevrací
			var tg := float(e[1]) * take / dem if dem > 0.0 else 0.0
			var d := tg - float(e[3])
			if d > 1e-15:
				_qpush(c, qb, down, int(e[0]), d); e[3] = tg
			used += float(e[3])
		rem -= used
		i = j
	rem = maxf(rem, 0.0)
	p.lused = minf(rem, float(p.leak)); rem -= float(p.lused)
	var d2 := rem - float(p.get("osent", 0.0))
	if rem <= 1e-12:
		if p.typ != "nenaplni": p.typ_full = p.typ; p.typ = "nenaplni"
		return
	if p.typ == "nenaplni": p.typ = String(p.get("typ_full", "uzavrena"))
	if d2 <= 1e-12: return
	p.osent = rem
	if not p.out.is_empty(): _pit_out(outs, p, d2)
	elif int(p.tgt) >= 0:
		var g2: int = p.tgt
		_qpush(c, qb, down, g2, d2)

## priority-flood ze dna pasti b (jako F._solve_preliv), práh = pásmo s nižším dnem, dosažené shora
static func _pit_fill(c: Dictionary, pits: Array, pit_of: Dictionary, b: int, f: float, qb: Dictionary, down, outs: Dictionary, ex: Dictionary) -> void:
	var NB: int = c.lo.size()
	var cur := pits.size()
	var p := {"bands": PackedInt32Array(), "level": float(c.lo[b]), "q_in": f, "leak": 0.0, "typ": "", "tgt": -1, "out": [], "merged": -1, "floor": float(c.lo[b]),
		"links": [], "osent": 0.0, "lused": 0.0}
	var kap := bool(c._k71.on)
	pits.append(p)
	var h := HP.new()
	var od := []                 # výstupy jako položky haldy (id NB + i)
	var inp := {}
	p.inp = inp
	h.push(-float(c.lo[b]), b)
	var L := float(c.lo[b])
	while h.size() > 0:
		var key := -h.top_v()
		var id := h.pop()
		if id >= NB:
			p.out = od[id - NB]; L = maxf(L, key); p.typ = "vystup"
			if bool(c.get("remizy69", true)):   # E69: další výstupy ve stejné výšce (remíza) → přebytek se dělí rovným dílem
				var seen := {"%s|%d" % [String(p.out[1]), int(p.out[2])]: true}
				p.outs = [p.out]
				while h.size() > 0 and -h.top_v() <= key + E:
					var id2 := h.pop()
					if id2 < NB: continue
					var o2: Array = od[id2 - NB]; var k2 := "%s|%d" % [String(o2[1]), int(o2[2])]
					if not seen.has(k2): seen[k2] = true; p.outs.append(o2)
			break
		if inp.has(id): continue
		if pit_of.has(id):
			var j := _root(pits, int(pit_of[id]))
			if j != cur:
				if key >= float(pits[j].level) - E:   # spojení s dřívější pastí: její pásma do této, hladina stoupá dál
					var pj: Dictionary = pits[j]
					pj.merged = cur
					if kap: p.q_in = float(p.q_in) + float(pj.q_in) - float(pj.osent); p.links.append_array(pj.links)   # E71: odeslané průsaky jdou s pastí
					else: p.q_in = float(p.q_in) + float(pj.q_in) - maxf(float(pj.q_in) - float(pj.leak), 0.0)
					for b2 in pj.bands:
						inp[b2] = true; pit_of[b2] = cur; p.bands.append(b2)
						for o in F._outs(c, b2, ex):
							od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
						var bl2 := _below(c, b2) if kap else -1
						for nb in F._nbrs(c, b2):
							if not inp.has(int(nb[0])) and int(nb[0]) != bl2: h.push(-maxf(key, float(nb[1])), int(nb[0]))
					continue
				# práh do pasti s vyšší hladinou: přeteče do ní – ledaže ta přetéká zpět sem (vzájemný přeliv → spojit)
				var back := false
				if int(pits[j].tgt) >= 0:
					for tb in _probe(c, int(pits[j].tgt), ex):
						if inp.has(tb) or tb == b: back = true
				if back:
					var pj2: Dictionary = pits[j]
					pj2.merged = cur
					if kap: p.q_in = float(p.q_in) + float(pj2.q_in) - float(pj2.osent); p.links.append_array(pj2.links)   # E71: odeslané průsaky jdou s pastí
					else: p.q_in = float(p.q_in) + float(pj2.q_in) - maxf(float(pj2.q_in) - float(pj2.leak), 0.0)
					for b2 in pj2.bands:
						inp[b2] = true; pit_of[b2] = cur; p.bands.append(b2)
						for o in F._outs(c, b2, ex):
							od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
						var bl2 := _below(c, b2) if kap else -1
						for nb in F._nbrs(c, b2):
							if not inp.has(int(nb[0])) and int(nb[0]) != bl2: h.push(-maxf(key, float(nb[1])), int(nb[0]))
					L = maxf(L, float(pj2.level))
					continue
				p.tgt = id; p.typ = "prah"; L = maxf(L, key); break
		if id != b and float(c.lo[id]) < key - E:   # dno pod hladinou a pásmo do pasti nepatří → práh, přeliv dál
			var ret := true                         # ...ledaže by voda z něj stekla jen zpět do této pasti (pak k ní patří)
			for tb in _probe(c, id, ex):
				if not (inp.has(tb) or tb == b): ret = false; break
			if not ret:
				p.tgt = id; p.typ = "prah"; L = maxf(L, key); break
		inp[id] = true; pit_of[id] = cur; p.bands.append(id)
		L = maxf(L, key)
		for o in F._outs(c, id, ex):
			od.append(o); h.push(-maxf(key, float(o[0])), NB + od.size() - 1)
		var bl3 := _link_add(c, p, id, key) if kap else -1   # E71 K: spoj dolů = průsak pasti, ne práh
		for nb in F._nbrs(c, id):
			if not inp.has(int(nb[0])) and int(nb[0]) != bl3: h.push(-maxf(key, float(nb[1])), int(nb[0]))
	if p.typ == "": p.typ = "uzavrena"
	p.level = L
	var lk := 0.0
	for b2 in p.bands: lk += F._leak(c, b2, L)
	p.leak = lk
	if kap: _pit_dist(c, p, qb, down, outs); return
	p.lused = minf(float(p.q_in), lk)
	var over := maxf(float(p.q_in) - lk, 0.0)
	if over <= 0.0: p.typ_full = p.typ; p.typ = "nenaplni"; return
	if not p.out.is_empty(): _pit_out(outs, p, over)
	elif int(p.tgt) >= 0:
		var g: int = p.tgt
		qb[g] = float(qb.get(g, 0.0)) + over; down.push(float(c.lo[g]), g)

static func _result(c: Dictionary, entries: PackedInt32Array, q: float, trace: bool, wet: Dictionary, pits: Array, outs: Dictionary, t0: int, cut: bool) -> Dictionary:
	var comp := PackedInt32Array(); var vol := 0.0; var lake := 0.0; var leak := float(c._k71.wl); var zmin := INF
	var pl := []
	var qs := 1.0 if not trace else 0.0
	for i in pits.size():
		var p: Dictionary = pits[i]
		if int(p.merged) >= 0: continue
		var v := 0.0
		for b in p.bands:
			var top := minf(float(c.hi[b]), float(p.level)); var w := top - float(c.lo[b])
			comp.append(b); zmin = minf(zmin, float(c.lo[b]))
			if w > E:
				var pa: float = float(c.por[b]) * float(c.A)
				v += pa * w
				if int(c.mat[b]) == 0: lake += pa * w
				var cc: int = c.bcol[b]; c.wt[cc] = maxf(c.wt[cc], top)
		var e71 := bool(c._k71.on) or bool(c._k71.prus)
		var sent := 0.0
		for e in p.get("links", []): sent += float(e[3])
		vol += v; leak += (float(p.get("lused", 0.0)) if e71 else float(p.leak)) * qs
		var net := float(p.q_in) - (float(p.lused) + sent if bool(c._k71.on) else float(p.leak))
		pl.append({"hladina": float(p.level), "dno": float(p.floor), "pasem": p.bands.size(), "objem_m3": v, "typ": String(p.typ),
			"q_in": float(p.q_in) * qs, "cas_s": (v / (net * float(c.q_to_m3))) if net > 0.0 and not trace else -1.0, "bands": p.bands,
			"prusak_pouzit": float(p.get("lused", 0.0)) * qs, "dolu": sent * qs})
	var ol := []
	for k in outs: ol.append(outs[k])
	ol.sort_custom(func(a, b): return float(a[3]) > float(b[3]) or (float(a[3]) == float(b[3]) and int(a[2]) < int(b[2])))
	var oq := 0.0
	for o in ol: oq += float(o[3]) * qs
	var out := []
	var o67 := []
	for o in ol:
		var cs := F._col_s(c, int(o[2]), String(o[1]) == "okraj")
		o67.append([float(o[0]), String(o[1]), cs, float(o[3]) * qs, int(o[4])])
	if not ol.is_empty(): out = [float(ol[0][0]), 0, int(ol[0][4]), String(ol[0][1]), o67[0][2]]
	var wl := PackedInt32Array()
	for b in wet: wl.append(b)
	wl.sort()
	# stopa: sloupce navštívených pásem (mokrá + pasti); výkop zasáhne výsledek jen ve stopě nebo u ní (ug58.edit)
	var fp := PackedByteArray(); fp.resize(int(c.W) * int(c.H))
	for b in wl: fp[int(c.bcol[b])] = 1
	for b in comp: fp[int(c.bcol[b])] = 1
	var mem := F.Members.new(); mem.ctx = c; mem.id = c.comp[entries[0]] if not entries.is_empty() and entries[0] >= 0 else -1
	var zo := float(ol[0][0]) if not ol.is_empty() else (float(pl[0].hladina) if not pl.is_empty() else 0.0)
	var closed := ol.is_empty() and not (bool(c.get("prus73", false)) and not trace and q > 0.0 and leak >= q * (1.0 - 1e-9))   # E73: vše prosákne → těleso vodu přijímá
	var nf := (q - leak) <= 0.0
	return {"cells": comp.size() + wl.size(), "q_in": q, "leak": minf(leak, q), "zmin": zmin, "z_out": zo, "out": out, "events": [],
		"volume_m3": vol, "never_fills": nf, "out_q": oq if not closed else 0.0, "closed": closed, "lake_m3": lake, "members": mem,
		"path": wl, "lake": PackedInt32Array(), "comp_ids": comp, "rezim_tel": "pretok", "pits67": pl, "outs67": o67, "wet67": wl,
		"ms67": (Time.get_ticks_usec() - t0) / 1000.0, "cut67": cut, "_fp67": fp}
