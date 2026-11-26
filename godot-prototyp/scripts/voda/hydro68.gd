extends RefCounted
## KOPIE z blueprint-studie/scripts/hydro68/hydro68.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E68: jednotný krok hydrologie povrch + podzemí nad stavem toku st (voda/tok.gd, st.ug = podzemí).
## Pořadí: terén / geologie (st.hm, st.mats, st.ug) → povrch (priority-flood + D8) ↔ podzemí (odtoky tůní → tělesa →
## prameny src2 / výstupy ve stěně) do ustálení → bilance → události → lokální přepočet (tok60.update s KOLA / TOL).
## Algoritmy se nemění, jen smyčka má počet kol a toleranci a výsledek se dá zkontrolovat (bilance, otisk).
## kola = 4, tol = 0 → bitově stejné jako tok.route / tok60.update.
const T = preload("res://scripts/voda/tok.gd")
const T60 = preload("res://scripts/voda/povrch/tok60.gd")
const LI = preload("res://scripts/voda/litry.gd")   # E94: jeden tvar l → m³
static var LADIT := false   # E68: výpis kol (ladění)

## plný výpočet jako tok.route, smyčka povrch ↔ podzemí nejvýš `kola` kol, konec při změně ≤ tol (l/s)
## cyklus = true: když se stav odtoků zopakuje (smyčka přepíná, např. pramen mezi dvěma tůněmi), skončí se v členu cyklu
## s nejmenším otiskem → stejný výsledek z plného i lokálního přepočtu bez ohledu na sudost počtu kol
static func full(st: Dictionary, kola := 4, tol := 0.0, cyklus := false, acc := false) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n: int = st.W * st.H
	var inside := PackedByteArray(); inside.resize(n); inside.fill(1)
	var seeds := PackedInt32Array()
	for i in n:
		st.fill[i] = st.hm[i]; st.eff[i] = 0.0
		if st.wall[i] == 0 and T._border(st, i): seeds.append(i)
	var order := T._flood(st, inside, seeds)
	for i in order: T._to(st, i)
	for k in range(order.size() - 1, -1, -1): T._cell(st, order[k])
	st.order = order
	var kol := 0; var zm := 0.0; var ust := false
	var cs := {"seen": {}, "list": []}
	var ah := {}
	for it in kola:
		var ox := {}
		for i in st.get("_xn", {}): ox[i] = [st.extra[i], st.src2[i]]
		var chg := T._apply_drains(st, null)
		kol += 1
		if LADIT:
			var bs := []
			for r in st.ug_bodies: bs.append([r.entries, snappedf(float(r.q_in), 1e-5), snappedf(float(r.out_q), 1e-5), bool(r.closed), r.out.slice(0, 1) + r.out.slice(3, 5) if not r.out.is_empty() else []])
			print("kolo ", kol, " změněno ", chg.size(), " tělesa ", bs, " výstupy ", st.under.map(func(u): return [u.from, u.exit, snappedf(float(u.q), 1e-5)]))
		if chg.is_empty(): ust = true; zm = 0.0; break
		zm = 0.0
		for i in chg:
			var o: Array = ox.get(i, [0.0, 0.0])
			zm = maxf(zm, maxf(absf(st.extra[i] - float(o[0])), absf(st.src2[i] - float(o[1]))))
		for k in range(order.size() - 1, -1, -1): T._cell(st, order[k])
		if tol > 0.0 and zm <= tol: ust = true; break
		if cyklus and T60.cyc_step(st, cs): break
		if acc and not T60.acc_step(st, ah).is_empty():   # E73: skok smyčky → povrch znovu
			for k in range(order.size() - 1, -1, -1): T._cell(st, order[k])
	T.pond_mask(st)
	var cy := int(cs.get("perioda", 0))
	var sk := int(ah.get("skoky", 0))
	st.kolo68 = {"kola": kol, "zmena": zm, "ustaleno": ust, "cyklus": cy, "skoky": sk}
	return {"ms": (Time.get_ticks_usec() - t0) / 1000.0, "cells": order.size(), "kola": kol, "zmena": zm, "ustaleno": ust, "cyklus": cy, "skoky": sk}

## lokální přepočet (tok60.update) se stejným počtem kol a tolerancí
static func update(st: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array, src_new: PackedFloat64Array, margin: int, kola := 4, tol := 0.0, cyklus := false, acc := false) -> Dictionary:
	var k0 := T60.KOLA; var t0 := T60.TOL; var c0 := T60.CYKLUS; var a0 := T60.ACC
	T60.KOLA = kola; T60.TOL = tol; T60.CYKLUS = cyklus; T60.ACC = acc
	var r := T60.update(st, ch, hv, src_new, margin)
	T60.KOLA = k0; T60.TOL = t0; T60.CYKLUS = c0; T60.ACC = a0
	r.merge(T60.KOLO, true)
	st.kolo68 = T60.KOLO.duplicate()
	return r

## společná bilance (l/s). Povrch: zdroje + prameny = okraj + ponory + odtoky tůní (+ konec mimo okraj).
## Spoj dolů: odtoky tůní = vstup podzemí + do hloubky bez tělesa. Podzemí: vstup = prameny + stěna + průsak.
## Svět: zdroje = okraj + ponory + stěna + průsak + do hloubky. Chyby ≠ 0 = neustálená smyčka nebo chyba.
static func bilance(st: Dictionary) -> Dictionary:
	var n: int = st.W * st.H
	var src: PackedFloat64Array = st.src; var s2: PackedFloat64Array = st.src2
	var ain: PackedFloat64Array = st.ain; var eff: PackedFloat64Array = st.eff; var ex: PackedFloat64Array = st.extra
	var zdroje := 0.0; var prameny := 0.0; var okraj := 0.0; var jinde := 0.0; var ponory := 0.0; var tune := 0.0
	for i in n:
		if st.wall[i] == 1: continue
		zdroje += src[i]; prameny += s2[i]
		if st.to[i] < 0:
			if T._border(st, i): okraj += eff[i]
			else: jinde += eff[i]
		var l: float = ain[i] - eff[i]
		if ex[i] > 0.0: tune += l
		else: ponory += l
	var ug_in := 0.0; var ug_pov := 0.0; var ug_stena := 0.0; var ug_vyv := 0.0; var ug_prusak := 0.0; var zavrena := 0
	for u in st.get("under", []):
		if String(u.typ) == "povrch": ug_pov += float(u.q)
		else: ug_stena += float(u.q)
		if String(u.typ) == "vyver74": ug_vyv += float(u.q)
	if st.get("ug") == null:
		ug_in = ug_stena
	else:
		for r in st.get("ug_bodies", []):
			if bool(r.closed): zavrena += 1; continue
			ug_in += float(r.q_in); ug_prusak += float(r.leak)
	var deep := float(st.get("lost_deep", 0.0))
	return {"zdroje": zdroje, "prameny_z_podzemi": prameny, "okraj": okraj, "konec_jinde": jinde, "ponory": ponory,
		"odtok_tuni": tune, "podzemi_vstup": ug_in, "podzemi_prameny": ug_pov, "podzemi_stena": ug_stena,
		"podzemi_prusak": ug_prusak, "podzemi_vyver74_ven": ug_vyv, "do_hloubky": deep, "zavrena_telesa": zavrena,
		"chyba_povrch": zdroje + prameny - okraj - jinde - ponory - tune,
		"chyba_dolu": tune - ug_in - deep,
		"chyba_nahoru": prameny - ug_pov,
		"chyba_podzemi": ug_in - ug_pov - ug_stena - ug_prusak,
		"chyba_svet": zdroje - okraj - jinde - ponory - ug_stena - ug_prusak - deep}

## otisk stavu hydrologie (fill, eff, to, extra, src2, výstupy podzemí) → 16 hex znaků
static func otisk(st: Dictionary) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	for k in ["fill", "eff", "extra", "src2"]: h.update((st[k] as PackedFloat64Array).to_byte_array())
	h.update((st.to as PackedInt32Array).to_byte_array())
	var us := PackedStringArray()
	for u in st.get("under", []): us.append("%d|%d|%.12f|%.9f|%s" % [int(u.from), int(u.exit), float(u.q), float(u.z), String(u.typ)])
	us.sort()
	h.update(("pod|" + "\n".join(us)).to_utf8_buffer())
	return h.finish().hex_encode().substr(0, 16)

## události plnění tůní seřazené podle času (pevné pořadí: čas, přeliv, hladina); cas_s < 0 = nenaplní se
static func udalosti(st: Dictionary, cell_m2 := 0.25, u_m := 0.5, l_na_m3 := LI.L_NA_M3) -> Array:
	var ev := []
	for x in T.ponds(st, cell_m2, u_m, true, l_na_m3):
		for e in x.udalosti: ev.append([float(e.cas_s), int(x.outlet), float(e.hladina_m), float(e.objem_m3)])
	ev.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	return ev
