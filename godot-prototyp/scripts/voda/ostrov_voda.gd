extends RefCounted
## E66: voda ostrova ze studie (devlog/voda-algoritmy.md). Déšť je jen vizuální, voda teče jen z PRAMENŮ (prameny.gd),
## povrch = uložené koryto (priority-flood + D8 + ztráty v ponorech, tůně s odtokem do podzemí, tok.gd), podzemí = funkce nad
## vrstvami v režimu auto + E64 (podzemi_ostrov.gd). Když se nic nemění, nic se nepočítá; po kopání se přepočítá jen okno
## kolem změny a cesta po proudu (tok60.update, E60 A+C).
##
## Mřížka = svět studie (SIZE × SIZE slotů po 16 sloupcích, sloupec = buňka 1 × 1, výšky v buňkách 0,5 m). Sloupce mimo
## ostrov (mlha) jsou PŘÍKOP s výškou voda_prikop_u (výchozí 0 = dno bloku): voda z okraje ostrova do něj spadne
## (vodopád do mlhy) a odteče přes okraj mapy (edge_out). Tak plovoucí ostrov přepadá všude po obvodu a moduly studie
## zůstávají beze změny (tok._border zná jen okraj mapy). Podzemí v mlze nepokračuje (stěna).

const T = preload("res://scripts/teren/ostrov_teren.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const TOK60 = preload("res://scripts/voda/povrch/tok60.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const V64 = preload("res://scripts/teren/svet64/voda64.gd")
const UGO = preload("res://scripts/voda/podzemi_ostrov.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")   # E68: jednotný krok povrch ↔ podzemí do ustálení (p68_hydro)
const GW = preload("res://scripts/voda/podzemi/gw74.gd")   # E74: hladina podzemní vody jako plocha gw(x, y) (p74_gw)
const K75 = preload("res://scripts/voda/podzemi/kras75.gd")   # E75: kras – eroze v podzemí po tělesech (p75_kras)
const BS := 16
const ROCK := 6   # materiál příkopu pro tok (žula, nepropustná)

var p := {}
var W := 0
var H := 0
var hm := PackedFloat64Array()
var wall := PackedByteArray()
var island := PackedByteArray()   # 1 = sloupec bloku ostrova, 0 = příkop (mlha)
var blocks := {}                  # slot ostrova → Block (jen bp)
var springs := []
var st := {}
var ug := {}
var falls := []                   # [{top, bot, q, drop_u, edge}] vodopády (edge = přes okraj ostrova do mlhy)
var ms := {}
var last_edit := {}
var _ugc79 = null                 # E79: funkční pásma podzemí z plného postavení (p79_chodby)
var _cav79 := {}                  # E79: podpis dutin sloupce gi → "počet|spodek|vršek" (jen sloupce s dutinou)
var gw := {}                      # E74: plocha podzemní vody (p74_gw), jinak prázdné
var full_otisk := ""              # E74: otisk posledního čerstvého plného výpočtu (check_full)
var full_gw := {}                 # E74: plocha z čerstvého plného výpočtu
var claims := {}                  # E74: obsazené výtoky (sloupec povrchu), přežijí přestavbu (p74_vyzvednout)
var kras := {}                    # E75: stav krasu (rozpuštěný objem a dutiny po pásmech), přežije přestavbu

func gi_of(s: Vector2i, x: int, y: int) -> int:
	var ws := T.wslot(s)
	return (ws.x * BS + x) * H + ws.y * BS + y

func slot_of(gi: int) -> Array:   # [slot ostrova, lx, ly]
	var gx := gi / H; var gy := gi % H
	return [T.islot(Vector2i(gx / BS, gy / BS)), gx % BS, gy % BS]

func _mat_d(gi: int, d: int, gen := false) -> int:
	if island[gi] == 0: return ROCK
	var a := slot_of(gi)
	var b = blocks[a[0]]
	var i: int = a[1] * BS + a[2]
	var z := clampi(int(b.hm_gen[i] if gen and not b.hm_gen.is_empty() else b.hm[i]) - 1 - d, 0, 63)
	return int(b.geo[i * 64 + z])

## uvolnit stav: výsledky podzemí drží Members.ctx = kontext → cyklus referencí; prázdný slovník ho rozbije
func dispose() -> void:
	if not ug.is_empty(): ug.clear()
	st.clear()
	ug = {}; st = {}

## plný výpočet (po vložení bloku); bl = Island.blocks
func build(bl: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	dispose()
	T.ensure()
	p = V64.scaled(T.p, 16)
	W = T.SIZE * BS; H = W
	blocks = {}
	for s in bl:
		if bl[s].gen == "bp" and not bl[s].geo.is_empty(): blocks[s] = bl[s]
	if _on85v():   # E85: obsazení výtoků je stav hry (hráč pramen vykopal / napojil) → z bloků, ne z historie instance
		for s in blocks:
			for ci in blocks[s].obsazeno85: claims[gi_of(s, int(ci) / BS, int(ci) % BS)] = true
	var n := W * H
	hm = PackedFloat64Array(); hm.resize(n)
	# příkop: dno voda_prikop_u se sklonem voda_prikop_sklon (buněk na sloupec) k okraji mapy. Bez sklonu by plochý
	# příkop neměl odtok dolů a okno lokálního přepočtu (tok60) by se zvětšovalo až na celou mapu.
	var h0 := float(p.get("voda_prikop_u", 0.0)); var sk := float(p.get("voda_prikop_sklon", 0.01))
	for i in n:
		var x := i / W; var y := i % W
		hm[i] = h0 - sk * mini(mini(x, y), mini(W - 1 - x, W - 1 - y))
	wall = PackedByteArray(); wall.resize(n)
	island = PackedByteArray(); island.resize(n)
	for s in blocks:
		var b = blocks[s]
		for x in BS:
			for y in BS:
				var gi := gi_of(s, x, y)
				hm[gi] = float(b.hm[x * BS + y]); island[gi] = 1
	var md := func(gi: int, d: int) -> int: return _mat_d(gi, d)
	var wall_isl := PackedByteArray(); wall_isl.resize(n)   # prameny jen na ostrově (kvantil vrcholů bez příkopu)
	for i in n: wall_isl[i] = 1 - island[i]
	springs = _springs76(wall_isl, md) if bool(p.get("p76_prameny", false)) else PRM.find(hm, W, H, wall_isl, md, p)
	var src := PRM.src(springs, hm, n)
	ms["prameny"] = (Time.get_ticks_usec() - t0) / 1000.0
	var dd := int(round(float(p.strz_target_m) / float(p.voda_cell_m)))
	var mats := PackedInt32Array(); mats.resize(n)
	var gen76 := bool(p.get("p76_prameny", false)) and bool(p.get("p76_mat_gen", true))   # E76: materiál pro ztráty podle povrchu při vygenerování (jako lokální přepočet po výkopu)
	for i in n: mats[i] = _mat_d(i, dd, gen76)
	st = TOK.make(hm.duplicate(), W, H, wall, mats, src, TOK.losses(p, true), true)
	st.claim74 = claims
	var t1 := Time.get_ticks_usec()
	ug = {}
	if bool(p.get("podzemi_vrstva", true)) and not blocks.is_empty():
		_ugc79 = {} if bool(p.get("p79_chodby", false)) else null
		ug = UGO.make(T.world, T.fine(blocks), p, W, st.hm, wall, float(p.voda_cell_m), _ugc79)
		_replay_digs(ug)
		if bool(p.get("p75_kras", false)):
			if kras.is_empty(): kras = K75.make(p)
			K75.apply(ug, kras)
		st.ug = ug
	if bool(p.get("p79_chodby", false)): _cav79 = _cav_all()
	ms["podzemí: pásma"] = (Time.get_ticks_usec() - t1) / 1000.0
	t1 = Time.get_ticks_usec()
	_route(st)
	var nc := _claims(-1)
	while not nc.is_empty():   # E74: obsazení napojením na koryto / tůň mění povrch → znovu (obsazení jen přibývá)
		_route(st); nc = _claims(-1)
	ms["povrch + podzemí: plný výpočet"] = (Time.get_ticks_usec() - t1) / 1000.0
	_gw()
	_kras_rates()
	_falls()
	ms["celkem"] = (Time.get_ticks_usec() - t0) / 1000.0

## E76: prameny jako uložené zdroje bloků. Bloky bez uložených pramenů (první postavení, nově vygenerovaný blok) je dostanou
## z hledání přes celý ostrov (stejně jako bez přepínače), ostatní (po výkopech, po načtení, výřez z průzkumného světa)
## berou uložené → nové postavení nezmění prameny jinde. Pořadí: podle sloupce (deterministické).
func _springs76(wall_isl: PackedByteArray, md: Callable) -> Array:
	var need := false
	for s in blocks:
		if blocks[s].prameny76 == null: need = true
	if need:
		var found := PRM.find(hm, W, H, wall_isl, md, p)
		var fresh := {}
		for s in blocks:
			if blocks[s].prameny76 == null: fresh[s] = true; blocks[s].prameny76 = []
		for sp in found:
			var a := slot_of(int(sp.gi))
			if fresh.has(a[0]): blocks[a[0]].prameny76.append([a[1], a[2], int(sp.z), float(sp.q), String(sp.druh)])
	var out := []
	for s in blocks:
		for e in blocks[s].prameny76:
			out.append({"gi": gi_of(s, int(e[0]), int(e[1])), "z": int(e[2]), "q": float(e[3]), "druh": String(e[4]), "aktivni": true})
	out.sort_custom(func(a, b): return int(a.gi) < int(b.gi))
	return out

## E76: vložení bloku (výřez z průzkumného světa nebo nový blok) LOKÁLNĚ: povrch sloupců bloku, prameny (uložené / hledání),
## materiály, podzemí znovu z funkcí vrstev (pásma se mění) a přepočet hydro68.update jen kolem sloupců bloku a švu.
## Blok už musí být ve světě studie (T.commit). Vrací časy.
func place76(b) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	blocks[b.slot] = b
	var ch := PackedInt32Array(); var hh := PackedFloat64Array(); var seen := {}
	for x in BS:
		for y in BS:
			var gi := gi_of(b.slot, x, y)
			hm[gi] = float(b.hm[x * BS + y]); island[gi] = 1; st.hm[gi] = hm[gi]
	for x in range(-1, BS + 1):   # sloupce bloku + prstenec švu (sousedé mohou téct jinam)
		for y in range(-1, BS + 1):
			var ws := T.wslot(b.slot); var gx := ws.x * BS + x; var gy := ws.y * BS + y
			if gx < 0 or gy < 0 or gx >= W or gy >= H: continue
			var gi := gx * H + gy
			if not seen.has(gi): seen[gi] = true; ch.append(gi); hh.append(hm[gi])
	var md := func(gi: int, d: int) -> int: return _mat_d(gi, d)
	var wall_isl := PackedByteArray(); wall_isl.resize(W * H)
	for i in W * H: wall_isl[i] = 1 - island[i]
	springs = _springs76(wall_isl, md) if bool(p.get("p76_prameny", false)) else PRM.find(hm, W, H, wall_isl, md, p)
	var src_new := PRM.src(springs, hm, W * H)
	var dd := int(round(float(p.strz_target_m) / float(p.voda_cell_m)))
	var gen76 := bool(p.get("p76_prameny", false)) and bool(p.get("p76_mat_gen", true))
	for gi in ch: st.mats[gi] = _mat_d(gi, dd, gen76)
	var t1 := Time.get_ticks_usec()
	var ms_ug := 0.0
	if bool(p.get("podzemi_vrstva", true)):
		if not ug.is_empty(): ug.clear()
		ug = UGO.make(T.world, T.fine(blocks), p, W, st.hm, wall, float(p.voda_cell_m))
		_replay_digs(ug)
		if bool(p.get("p75_kras", false)) and not kras.is_empty(): K75.apply(ug, kras)   # sloučení E75 + E76: dutiny krasu i v novém podzemí
		st.ug = ug
		st.ug_cache = {}
	ms_ug = (Time.get_ticks_usec() - t1) / 1000.0
	var t2 := Time.get_ticks_usec()
	_add_drains(ch, hh)
	var r := _update(ch, hh, src_new)
	_claim_update(-1)   # sloučení E74 + E76: obsazení výtoků po vložení (napojení na koryto / tůň)
	_falls()
	_gw()
	_kras_rates()
	var out := {"podzemi_ms": ms_ug, "povrch_ms": (Time.get_ticks_usec() - t2) / 1000.0, "celkem_ms": (Time.get_ticks_usec() - t0) / 1000.0,
		"zmenene_sloupce": ch.size(), "okno": r.get("window", 0)}
	ms["E76 vložení lokálně"] = out.celkem_ms
	return out

## E68: plný výpočet – p68_hydro = smyčka povrch ↔ podzemí do ustálení (nejvýš p68_kola, tolerance p68_tol), jinak tok.route
func _route(s: Dictionary) -> void:
	if bool(p.get("p68_hydro", false)): H68.full(s, int(p.get("p68_kola", 64)), float(p.get("p68_tol", 1e-9)), true, bool(p.get("p73_zrychleni", false)))
	else: TOK.route(s)

func _update(ch: PackedInt32Array, hh: PackedFloat64Array, src_new: PackedFloat64Array) -> Dictionary:
	if bool(p.get("p68_hydro", false)): return H68.update(st, ch, hh, src_new, int(p.tok_margin), int(p.get("p68_kola", 64)), float(p.get("p68_tol", 1e-9)), true, bool(p.get("p73_zrychleni", false)))
	return TOK60.update(st, ch, hh, src_new, int(p.tok_margin))

## podzemí se staví z funkcí vrstev (původní povrch) → dřívější výkopy (hm < hm_gen) se do něj přehrají
func _replay_digs(u: Dictionary) -> void:
	for s in blocks:
		var b = blocks[s]
		if b.hm_gen.is_empty(): continue
		for k in BS * BS:
			if b.hm[k] < b.hm_gen[k]:
				var gi := gi_of(s, k / BS, k % BS)
				UGO.F.touched(u, {}, PackedInt32Array([gi]), PackedFloat64Array([float(b.hm[k])]))
				u._digs.append([gi, float(b.hm[k])])

## vodopády: tok po D8 s průtokem ≥ práh koryta a spádem ≥ vodopad_m; z ostrova do příkopu = vodopád do mlhy
func _falls() -> void:
	falls = []
	var thr: float = st.L.thr
	var lim := float(p.vodopad_m) / float(p.voda_cell_m)
	var to: PackedInt32Array = st.to; var eff: PackedFloat64Array = st.eff; var h: PackedFloat64Array = st.hm
	for i in W * H:
		if island[i] == 0 or eff[i] < thr: continue
		var j := to[i]
		if j < 0: continue
		var edge := island[j] == 0
		var drop := h[i] - h[j]
		if edge or drop >= lim:
			falls.append({"top": i, "bot": j, "q": eff[i], "drop_u": drop, "edge": edge})

## hladina vody ve sloupci (buňky) nebo -1, když je sucho; tekoucí koryto = tenká vrstva nad povrchem
func level(gi: int) -> float:
	if st.is_empty(): return -1.0
	if st.fill[gi] > st.hm[gi] + 0.01: return st.fill[gi]
	if st.eff[gi] >= float(st.L.thr): return st.hm[gi] + 0.12
	return -1.0

func is_pond(gi: int) -> bool:
	return not st.is_empty() and st.fill[gi] > st.hm[gi] + 0.01

## změna terénu ve sloupci (kopání / položení): podzemí E64 (výkop), pak lokální přepočet povrchu tok60
func edit(s: Vector2i, lx: int, ly: int, new_h: int) -> Dictionary:
	if st.is_empty() or not blocks.has(s): return {}
	var gi := gi_of(s, lx, ly)
	var hv := float(new_h)
	var out := {"gi": gi}
	var t0 := Time.get_ticks_usec()
	if not ug.is_empty() and hv < st.hm[gi]:
		if not kras.is_empty():   # E75: dopočítat do teď, vynulovat odpočet pásem sloupce, materializovat buňky dutin
			var cc: int = UGO.F.col_of(ug, gi)
			out.kras = K75.on_dig(kras, float(kras.now), cc, float(ug.h[cc]), hv * float(ug.cm_s))
		out.ug = UGO.dig(ug, gi, hv)
	var t1 := Time.get_ticks_usec()
	var src_new: PackedFloat64Array = st.src
	for sp in springs:
		if sp.gi == gi:   # pramen se otevře / zavře podle volné buňky nad ním
			var h2: PackedFloat64Array = st.hm.duplicate(); h2[gi] = hv
			src_new = PRM.src(springs, h2, W * H)
			break
	var ch := PackedInt32Array([gi]); var hh := PackedFloat64Array([hv])
	if out.has("ug") and bool(out.ug.changed): _add_drains(ch, hh)
	var r := _update(ch, hh, src_new)
	_claim_update(gi)
	out.surf_ms = (Time.get_ticks_usec() - t1) / 1000.0
	if bool(p.get("p74_gw", false)):
		var tg := Time.get_ticks_usec()
		_gw()
		out.gw_ms = (Time.get_ticks_usec() - tg) / 1000.0
	out.surf = r
	_falls()
	if not pending(): _kras_rates()
	out.ms = (Time.get_ticks_usec() - t0) / 1000.0
	last_edit = out
	return out

## E79: podpis dutiny sloupce jako v ug_funkce.from_world (vzduch pod povrchem: počet, nejnižší, nejvyšší); "" = bez dutiny
func _cav_sig(b, ci: int) -> String:
	var cnt := 0; var zl := -1; var zh := -1
	var base := ci * 64
	for z in int(b.hm[ci]):
		if b.geo[base + z] == 0:
			cnt += 1; zh = z
			if zl < 0: zl = z
	return "" if cnt == 0 else "%d|%d|%d" % [cnt, zl, zh]

func _cav_all() -> Dictionary:
	var out := {}
	for s in blocks:
		for ci in BS * BS:
			var g := _cav_sig(blocks[s], ci)
			if g != "": out[gi_of(s, ci / BS, ci % BS)] = g
	return out

## E79 (p79_chodby): dávka změn buněk; zm = {slot: [ci, ...]} sloupce, kde se změnily buňky 0,5 m (bloky už jsou
## přepočtené, např. prekryv78.sync79). Když se změnila dutina některého sloupce (chodba, šachta pod povrchem) nebo výška
## sloupce (výkop i položení), podzemí se postaví znovu (funkční pásma z mezipaměti, znovu jen dutiny), přehrají se výkopy a
## lokální přepočet E68 dostane změněné sloupce, odtoky tůní a vývěry (jako vložení bloku E76). Jinak (jen položení na
## povrch, materiál) stará cesta edit() po sloupcích. Materiály pro ztráty a suché `to` jako plný výpočet.
func edit79(zm: Dictionary) -> Dictionary:
	if st.is_empty(): return {}
	var t0 := Time.get_ticks_usec()
	var cav := false; var vykop := false
	var all := []   # [slot, ci, gi]
	for s in zm:
		if not blocks.has(s): continue
		var b = blocks[s]
		for ci in zm[s]:
			var gi := gi_of(s, ci / BS, ci % BS)
			all.append([s, ci, gi])
			var g := _cav_sig(b, ci)
			if g != String(_cav79.get(gi, "")):
				cav = true
				if g == "": _cav79.erase(gi)
				else: _cav79[gi] = g
			if int(b.hm[ci]) != int(st.hm[gi]): vykop = true   # i položení: povrch podzemí (hs) a výkopy se musí shodovat s plným výpočtem
	var out := {"dutiny": cav, "vykop": vykop, "sloupcu": all.size()}
	var dd := int(round(float(p.strz_target_m) / float(p.voda_cell_m)))
	var gen76 := bool(p.get("p76_prameny", false)) and bool(p.get("p76_mat_gen", true))
	if (not cav and not vykop) or ug.is_empty():
		var n := 0
		var mch := PackedInt32Array(); var mhh := PackedFloat64Array()
		for e in all:
			var s: Vector2i = e[0]; var ci: int = e[1]; var gi: int = e[2]
			var b = blocks[s]
			var m := _mat_d(gi, dd, gen76)   # materiál pro ztráty jako plný výpočet (šachta může vykopat i buňku hm_gen − 1 − dd)
			var hm_ch := int(b.hm[ci]) != int(st.hm[gi])
			if m != st.mats[gi]:
				st.mats[gi] = m
				if not hm_ch: mch.append(gi); mhh.append(st.hm[gi])
			if hm_ch:
				hm[gi] = float(b.hm[ci])
				edit(s, ci / BS, ci % BS, int(b.hm[ci])); n += 1
				while pending(): step()
		if not mch.is_empty(): _update(mch, mhh, st.src); _falls()
		_dry_to79(all)
		out.cesta = "sloupce"; out.edit = n; out.materialy = mch.size()
		out.ms = (Time.get_ticks_usec() - t0) / 1000.0
		return out
	var ch := PackedInt32Array(); var hh := PackedFloat64Array()
	for e in all:
		var gi: int = e[2]
		hm[gi] = float(blocks[e[0]].hm[e[1]]); ch.append(gi); hh.append(hm[gi]); st.hm[gi] = hm[gi]   # jako place76
		st.mats[gi] = _mat_d(gi, dd, gen76)
	var src_new := PRM.src(springs, st.hm, W * H)
	var t1 := Time.get_ticks_usec()
	if not ug.is_empty(): ug.clear()
	ug = UGO.make(T.world, T.fine(blocks), p, W, st.hm, wall, float(p.voda_cell_m), _ugc79)
	_replay_digs(ug)
	st.ug = ug
	st.ug_cache = {}
	out.podzemi_ms = (Time.get_ticks_usec() - t1) / 1000.0
	var t2 := Time.get_ticks_usec()
	_add_drains(ch, hh)
	out.tune = _ponds79(ch, hh)
	# smyčka tůň → těleso → pramen začne jako plný výpočet od nuly (jinak se udrží pramen, který živí sám sebe)
	for u in st.get("under", []):
		for k in ["from", "exit"]:
			var i: int = int(u[k])
			if i >= 0: st.extra[i] = 0.0; st.src2[i] = 0.0
	var r := _update(ch, hh, src_new)
	if bool(p.get("p85_blok2", false)) or bool(p.get("p85_voda", false)):   # E85: obsazení výtoků (E74) a plocha gw jako plný výpočet
		var nc := _claims(-1)
		out.obsazeno85 = nc.size()
		while not nc.is_empty():   # nové obsazení mění povrch mimo okno → celé znovu jako build() (obsazení jen přibývá)
			_fresh85(); _route(st); nc = _claims(-1)
		_gw()
	_falls()
	_dry_to79(all)
	out.povrch_ms = (Time.get_ticks_usec() - t2) / 1000.0
	out.okno = r.get("window", 0)
	out.cesta = "dutiny"
	out.ms = (Time.get_ticks_usec() - t0) / 1000.0
	last_edit = {}
	return out

## E85: stav toku jako čerstvý TOK.make (H68.full začíná z extra / src2 předchozího stavu → jiný ustálený stav než plný
## výpočet; klíč mezipaměti řešení obsazení výtoků neobsahuje)
func _fresh85() -> void:
	var n := W * H
	for k in ["fill", "ain", "eff", "extra", "src2"]:
		var a := PackedFloat64Array(); a.resize(n); st[k] = a
	var t := PackedInt32Array(); t.resize(n); t.fill(-1); st.to = t
	var sk := PackedByteArray(); sk.resize(n); st.sink = sk
	for k in ["_xn", "under", "ug_bodies", "order"]: st.erase(k)
	st.ug_cache = {}

## E79: tůně nad tělesy, kterých se změna dotkla (pásma změněných sloupců v novém podzemí), jdou do přepočtu celé:
## jejich odtok do podzemí a hladina (kapacita E71) závisí na tělese, i když leží mimo okno změny. Vrací počet buněk.
func _ponds79(ch: PackedInt32Array, hh: PackedFloat64Array) -> int:
	var comps := {}
	for k in ch.size():
		var cc := UGO.col_of(ug, ch[k])
		for x in range(-1, 2):   # i sousední sloupce řídicí mřížky (chodba ve stěně sousedí s tělesem vedle)
			for y in range(-1, 2):
				var c2: int = cc + x * int(ug.H) + y
				if c2 < 0 or c2 >= int(ug.W) * int(ug.H): continue
				for b in range(ug.cs[c2], ug.cs[c2 + 1]):
					if ug.body[b] == 1: comps[ug.comp[b]] = true
	var seen := {}
	for i in ch: seen[i] = true
	var n := 0
	for i in W * H:
		if island[i] == 0 or seen.has(i) or not is_pond(i): continue
		var e := UGO.entry(ug, i)
		if e >= 0 and comps.has(ug.comp[e]): ch.append(i); hh.append(st.hm[i]); n += 1
	return n

## E79: lokální přepočet v suchu (tok60 „suché okolí“) nechá směr odtoku `to` beze změny; plný výpočet ho spočítá z fill.
## Suché buňky (eff 0) kolem změněných sloupců dostanou `to` znovu (stejná funkce jako plný výpočet), voda se nemění.
func _dry_to79(all: Array) -> void:
	var seen := {}
	for e in all:
		var gi: int = e[2]
		var x := gi / H; var y := gi % H
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx := x + dx; var qy := y + dy
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if seen.has(j) or wall[j] == 1 or st.eff[j] != 0.0: continue
				seen[j] = true
				TOK._to(st, j)

## výsledek podzemí se změnil → do přepočtu povrchu přidat odtoky tůní do podzemí a vývěry (beze změny výšky). Jinak by
## tok60 při výkopu v suchu nic nepřepočítal a změna podzemí by se na povrch nedostala.
func _add_drains(ch: PackedInt32Array, hh: PackedFloat64Array) -> void:
	var seen := {}
	for i in ch: seen[i] = true
	for u in st.get("under", []):
		for k in ["from", "exit"]:
			var i: int = int(u[k])
			if i >= 0 and not seen.has(i): seen[i] = true; ch.append(i); hh.append(st.hm[i])

func pending() -> bool:
	return not ug.is_empty() and UGO.pending(ug)

## krok R podzemí (pevný počet operací); po dokončení se povrch dopočítá kolem posledního výkopu
func step() -> bool:
	if not pending(): return false
	var more := UGO.step(ug)
	if not more and bool(ug._changed) and last_edit.has("gi"):
		var gi: int = last_edit.gi
		var ch := PackedInt32Array([gi]); var hh := PackedFloat64Array([st.hm[gi]])
		_add_drains(ch, hh)
		_update(ch, hh, st.src)
		_claim_update(gi)
		_falls()
		_gw()
	if not more: _kras_rates()
	return more

## E74 p74_vyzvednout: nové obsazení výtoků – výkop vedle (Chebyshev ≤ 1, dug ≥ 0) nebo napojení na koryto / tůň
## (výtok nebo jeho 8 sousedů má průtok ≥ práh koryta nebo je tůň). Vrací nově obsazené sloupce (seřazené).
func _claims(dug: int) -> PackedInt32Array:
	var nw := PackedInt32Array()
	if not bool(p.get("p74_vyzvednout", false)): return nw
	var thr: float = st.L.thr
	for u in st.get("under", []):
		if String(u.typ) != "vyver74": continue
		var e: int = u.exit
		if claims.has(e) or nw.has(e): continue
		var ex := e / H; var ey := e % H; var ok := false
		if dug >= 0 and absi(dug / H - ex) <= 1 and absi(dug % H - ey) <= 1: ok = true
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if ok: break
				var qx: int = ex + dx; var qy: int = ey + dy
				if qx < 0 or qy < 0 or qx >= W or qy >= H: continue
				var j := qx * H + qy
				if island[j] == 1 and (is_pond(j) or st.eff[j] >= thr): ok = true
		if ok: nw.append(e)
	nw.sort()
	for e in nw: claims[e] = true
	if not nw.is_empty(): _save85()
	return nw

## E85 (p85_voda / p85_blok2): obsazení výtoků do bloků (uloží se se záznamem bloku, plný výpočet a načtení je převezmou)
func _on85v() -> bool:
	return bool(p.get("p85_blok2", false)) or bool(p.get("p85_voda", false))

func _save85() -> void:
	if not _on85v(): return
	var per := {}
	for gi in claims:
		var a := slot_of(int(gi))
		if not blocks.has(a[0]): continue
		if not per.has(a[0]): per[a[0]] = []
		per[a[0]].append(int(a[1]) * BS + int(a[2]))
	for s in blocks:
		var l: Array = per.get(s, []); l.sort()
		blocks[s].obsazeno85 = PackedInt32Array(l)

func _claim_update(dug: int) -> void:
	var nc := _claims(dug)
	while not nc.is_empty():
		var ch := PackedInt32Array(); var hh := PackedFloat64Array()
		for e in nc: ch.append(e); hh.append(st.hm[e])
		_add_drains(ch, hh)
		_update(ch, hh, st.src)
		nc = _claims(-1)

## E74: ruční obsazení výtoku (zachycení pramene hráčem) → voda začne téct po povrchu
func claim(gi: int) -> void:
	if claims.has(gi): return
	claims[gi] = true
	_save85()
	var ch := PackedInt32Array([gi]); var hh := PackedFloat64Array([st.hm[gi]])
	_add_drains(ch, hh)
	_update(ch, hh, st.src)
	_claim_update(-1)
	_falls(); _gw()

## E74 p74_gw: plocha podzemní vody z výsledků těles
func _gw() -> void:
	if not bool(p.get("p74_gw", false)) or ug.is_empty(): gw = {}; return
	gw = GW.build(ug, st.get("ug_bodies", []))

## E75: rychlosti rozpouštění z aktuálních těles
func _kras_rates() -> void:
	if kras.is_empty() or ug.is_empty(): return
	K75.rates(ug, st.get("ug_bodies", []), kras)

## E75: kras do herního času t_end (s) nebo nejvýš max_ev událostí; každá událost → dutina +1 buňka, zpětná vazba do pásem
## a lokální přepočet (znovu vyřešit volání podzemí, E68 update kolem vstupů a výstupů). Vrací seznam událostí.
func kras_run(t_end: float, max_ev: int) -> Array:
	var evs := []
	if kras.is_empty(): return evs
	while evs.size() < max_ev:
		var ev := K75.next_event(kras)
		if float(ev[0]) > t_end or int(ev[1]) < 0: K75.advance(kras, t_end); break
		K75.advance(kras, float(ev[0]))
		K75.fire(kras, int(ev[1]))
		var t0 := Time.get_ticks_usec()
		var chb := K75.apply(ug, kras)
		_kras_local()
		evs.append({"t_s": float(ev[0]), "pasmo": int(ev[1]), "mat": int(kras.mat.get(int(ev[1]), -1)), "dutina_m3": float(kras.dut[int(ev[1])]), "zmenena_pasma": chb.size(), "ms": (Time.get_ticks_usec() - t0) / 1000.0})
	return evs

func _kras_local() -> void:
	for i in ug._calls.size():
		ug._res[i] = UGO.U._one(ug, ug._calls, i, UGO.U.has_flag(ug._var, "A"), UGO.U.has_flag(ug._var, "B"), UGO.U.has_flag(ug._var, "C"), ug._dz, ug._st)
	st.ug_cache = {}
	var ch := PackedInt32Array(); var hh := PackedFloat64Array()
	_add_drains(ch, hh)
	if ch.is_empty(): return
	_update(ch, hh, st.src)
	_falls()
	_gw()   # E74 + E75: dutina mění tělesa → plocha znovu
	_kras_rates()

## kontrola: stav po lokálních přepočtech = čerstvý plný výpočet (stejné výkopy přehrané do čerstvého podzemí). Vrací počet neshod.
func check_full() -> Dictionary:
	var n := W * H
	var st2 := TOK.make(st.hm.duplicate(), W, H, wall, st.mats, st.src, TOK.losses(p, true), true)
	st2.claim74 = claims.duplicate()
	if not ug.is_empty():
		var u2 := UGO.make(T.world, T.fine(blocks), p, W, st2.hm, wall, float(p.voda_cell_m))
		for d in ug._digs: UGO.F.touched(u2, {}, PackedInt32Array([d[0]]), PackedFloat64Array([d[1]]))
		if not kras.is_empty(): K75.apply(u2, kras)
		st2.ug = u2
	_route(st2)
	full_otisk = H68.otisk(st2)   # E74: přísnější kontrola (i extra, src2, výstupy podzemí)
	full_gw = GW.build(st2.ug, st2.get("ug_bodies", [])) if bool(p.get("p74_gw", false)) and st2.has("ug") else {}
	if st2.has("ug"): st2.ug.clear()   # cyklus Members.ctx (viz dispose)
	var bad := {"fill": 0, "eff": 0, "to": 0}
	for i in n:
		if st2.fill[i] != st.fill[i]: bad.fill += 1
		if st2.eff[i] != st.eff[i]: bad.eff += 1
		if st2.to[i] != st.to[i]: bad.to += 1
	return bad

## souhrn pro panel / log
func summary() -> Dictionary:
	if st.is_empty(): return {}
	var wet := 0; var pond := 0; var edge_q := 0.0; var nf := 0; var ne := 0
	for i in W * H:
		if island[i] == 0: continue
		if is_pond(i): pond += 1
		elif st.eff[i] >= float(st.L.thr): wet += 1
	for f in falls:
		if f.edge: ne += 1; edge_q += float(f.q)
		else: nf += 1
	var bodies: Array = st.get("ug_bodies", [])
	var outs := 0
	for u in st.get("under", []):
		if String(u.typ) != "okraj": outs += 1
	return {"prameny": springs.size(), "koryto_sloupcu": wet, "tun_sloupcu": pond, "vodopady": nf, "vodopady_okraj": ne, "okraj_lps": edge_q,
		"podzemni_telesa": bodies.size(), "vyvery": outs, "volani_podzemi": (ug._calls.size() if not ug.is_empty() else 0)}

## E68: společná bilance, otisk stavu a kola posledního přepočtu (jen hlášení, nic nemění)
func hydro() -> Dictionary:
	if st.is_empty(): return {}
	return {"bilance": H68.bilance(st), "otisk": H68.otisk(st), "kolo": st.get("kolo68", {})}
