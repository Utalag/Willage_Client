extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/tests.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Testy a měření bez okna: determinismus, pořadí, přesnost minerálů a hostitelé, švy (3 varianty), časy kroků, eroze.

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const W = preload("res://scripts/teren/world.gd")
const PL = preload("res://scripts/teren/pipeline.gd")
const SC = preload("res://scripts/studie_testy/scenario_data.gd")
const MT = preload("res://scripts/studie_testy/metrics.gd")
const NV = preload("res://scripts/studie_testy/naive.gd")
const BP = preload("res://scripts/teren/blueprint.gd")
const PR = preload("res://scripts/teren/params.gd")

static func build(p: Dictionary, seq := SC.sequence()):
	var w := W.new()
	for e in seq:
		PL.run_sync(w, e[0], e[1], p)
	return w

static func run_all(p0: Dictionary, out_path: String) -> PackedStringArray:
	var p := PR.v1(p0)
	var L := PackedStringArray()
	L.append("blueprint-studie – testy a měření (%s)" % Time.get_datetime_string_from_system())
	L.append("parametry: band %d, strata_band %d, free_face %s, drape %s, eroze %s" % [p.band, p.strata_band, p.free_face, str(p.drape), str(p.erosion)])
	# 1 hlavní běh + časy
	var t0 := Time.get_ticks_usec()
	var w = build(p)
	var tall := (Time.get_ticks_usec() - t0) / 1000.0
	L.append("\n## Vložení (naráz) – časy kroků ms")
	for s in w.order:
		var r: Dictionary = w.slots[s]
		var ms := []
		var tot := 0.0
		for k in r.ms:
			ms.append("%s %.0f" % [k, r.ms[k]]); tot += r.ms[k]
		var nb := 0
		for d in 4:
			if w.neighbour(s, d) != null and w.slots[s + preload("res://scripts/teren/sides.gd").DIRS[d]].order < r.order:
				nb += 1
		L.append("%d. %s %s seed %d (sousedů při vložení %d): celkem %.0f ms | %s" % [r.order + 1, str(s), r.bp.shape, r.bp.seed, nb, tot, ", ".join(ms)])
	L.append("celý sled %d bloků: %.0f ms" % [w.order.size(), tall])
	# 2 minerály
	L.append("\n## Minerály (cíl → umístěno, schodek; hostitel a jeho buněk v bloku)")
	var all_exact := true
	for s in w.order:
		var r: Dictionary = w.slots[s]
		var parts := []
		for m in r.rep.minerals:
			parts.append("%s %d→%d (schodek %d; v %s, %d buněk)" % [m.name, m.target, m.placed, m.shortfall, m.hosts, m.host_cells])
			if m.shortfall != 0: all_exact = false
		L.append("%s %s: %s | validátor %s %s | rarita (jen minerály) %.0f b." % [str(s), r.bp.shape, "; ".join(parts),
			"OK" if r.rep.valid.ok else "CHYBA", "" if r.rep.valid.ok else str(r.rep.valid.errors.slice(0, 2)), BP.rarity_points(r.bp)])
		var wr: Dictionary = r.rep.water
		L.append("   voda %d → póry %.0f, jezírko %.0f, odtok %.0f" % [wr.target, wr.pores, wr.pond, wr.runoff])
	L.append("všechny minerály přesně: %s" % ("ano" if all_exact else "NE"))
	# 3 hostitel chybí: kopec s 4000 mědi (žuly je méně) → schodek, nic mimo žulu
	var wneg := W.new()
	var rn: Dictionary = PL.run_sync(wneg, Vector2i(1, 1), BP.make("louka", 5, {Mat.COPPER: 4000, Mat.CLAY_DEPOSIT: 50}, 0), p)
	var cnt := PackedInt32Array(); cnt.resize(Mat.COUNT)
	for c in rn.cells: cnt[c] += 1
	L.append("\n## Nedostatek hostitele (louka 5, měď 4000 jen v žule, ložiskový jíl 50 jen v jílu)")
	for m in rn.rep.minerals:
		L.append("%s: cíl %d, umístěno %d, SCHODEK %d (hostitel %s měl %d buněk)" % [m.name, m.target, m.placed, m.shortfall, m.hosts, m.host_cells])
	L.append("žula po vtisknutí %d buněk (měď ji celou nahradila = nic jinde), validátor s hlášeným schodkem %s" % [cnt[Mat.GRANITE], "OK" if rn.rep.valid.ok else "CHYBA " + str(rn.rep.valid.errors.slice(0, 2))])
	# 4 determinismus
	L.append("\n## Determinismus (SHA-256 světa)")
	var h1: String = w.hash()
	var h2: String = build(p).hash()
	L.append("běh 1 %s\nběh 2 %s → %s" % [h1.left(16), h2.left(16), "STEJNÉ" if h1 == h2 else "RŮZNÉ!"])
	var seq := SC.sequence()
	var seq2 := [seq[1], seq[0], seq[2], seq[4], seq[3]]
	var h3: String = build(p, seq2).hash()
	L.append("jiné pořadí (2,1,3,5,4) %s → %s (očekávané: pořadí je součást vstupu)" % [h3.left(16), "stejné" if h3 == h1 else "jiné"])
	# 5 švy: 3 varianty
	L.append("\n## Švy (skok rozhraní vrstvy přes stranu bloku, buňky)")
	var m_bp := MT.seams(w.slots)
	var pn := p.duplicate(); pn["continue"] = false
	var wn = build(pn)
	var m_reg := MT.seams(wn.slots)
	var nv := {}
	for s in w.slots:
		nv[s] = NV.block(w.slots[s])
	var m_nv := MT.seams(nv)
	var raw := {}
	for s in w.slots:
		raw[s] = {"cells": w.slots[s].cells, "hm": w.slots[s].hm_raw}
	var m_raw := MT.seams(raw)
	L.append("A nezávislé gen-v3 (stejný povrch i počty): " + MT.fmt(m_nv))
	L.append("B regionální základ + charakter, bez navázání: " + MT.fmt(m_reg))
	L.append("C blueprint s navázáním (Laplace): " + MT.fmt(m_bp))
	L.append("průměr přes vrstvy: A %.2f, B %.2f, C %.2f; uvnitř bloků C %.2f (poměr šev/uvnitř C %.2f)" % [MT.mean_seam(m_nv), MT.mean_seam(m_reg), MT.mean_seam(m_bp), MT.mean_inner(m_bp), MT.mean_seam(m_bp) / maxf(MT.mean_inner(m_bp), 0.01)])
	L.append("povrch před dorovnáním (šablony): šev %.2f / max %d → po dorovnání %.2f / max %d" % [m_raw.surf_seam, m_raw.surf_seam_max, m_bp.surf_seam, m_bp.surf_seam_max])
	var ch := 0; var inner_ch := 0
	for s in w.order:
		var r: Dictionary = w.slots[s]
		for i in 256:
			if r.changed[i]:
				ch += 1
				var x := i / 16; var y := i % 16
				if mini(mini(x, 15 - x), mini(y, 15 - y)) >= p.band: inner_ch += 1
	L.append("změněných sloupců povrchu %d, z toho mimo pás %d" % [ch, inner_ch])
	# 5b sousedé jsou STARÉ bloky gen-v3 (vrstvy nejsou z regionu): hranice sousedů se odvodí z buněk (I_k)
	L.append("\n## Mezera mezi dvěma starými bloky gen-v3 (svah do (1,1), sousedé (0,1) a (2,1) z gen-v3)")
	for cont in [false, true]:
		var wl := W.new()
		for e in [SC.sequence()[0], SC.sequence()[1]]:
			var r0: Dictionary = w.slots[e[0]]
			var nvb := NV.block(r0)
			var I := MT.interfaces(nvb.cells)
			var bs := []
			for k in 5:
				var f := PackedFloat64Array(); f.resize(256)
				for i in 256: f[i] = I[k][i]
				bs.append(f)
			wl.commit({"bp": r0.bp, "slot": e[0], "hm": r0.hm, "hm_f": r0.hm_f, "hm_raw": r0.hm_raw, "changed": r0.changed,
				"bs": bs, "cells": nvb.cells, "water": PackedInt32Array(), "rep": {}, "ms": {}})
		var pc := p.duplicate(); pc["continue"] = cont
		PL.run_sync(wl, Vector2i(1, 1), SC.sequence()[2][1], pc)
		var ml := MT.seams(wl.slots)
		L.append("%s: %s | průměr %.2f" % ["s navázáním" if cont else "bez navázání", MT.fmt(ml), MT.mean_seam(ml)])
	# 5c silný vlastní charakter blueprintu (šum vrstev 2,5 buňky, drape ×1,5)
	var pk := p.duplicate(); pk.strata_noise = 2.5; pk.drape = p.drape.map(func(v): return v * 1.5)
	var mk := []
	for cont in [false, true]:
		var pc := pk.duplicate(); pc["continue"] = cont
		mk.append(MT.seams(build(pc).slots))
	L.append("\n## Silný vlastní charakter (strata_noise 2,5, drape × 1,5): bez navázání průměr %.2f, s navázáním %.2f (uvnitř %.2f)" % [MT.mean_seam(mk[0]), MT.mean_seam(mk[1]), MT.mean_inner(mk[1])])
	L.append("bez: " + MT.fmt(mk[0]))
	L.append("s:   " + MT.fmt(mk[1]))
	# 6 eroze
	L.append("\n## Volitelná hydraulická eroze (%d kapek na blok)" % p.droplets)
	var pe := p.duplicate(); pe.erosion = true
	t0 = Time.get_ticks_usec()
	var we = build(pe)
	var te := (Time.get_ticks_usec() - t0) / 1000.0
	var ems := []
	for s in we.order:
		var r: Dictionary = we.slots[s]
		ems.append("%s %.0f ms, Δ povrchu %.2f b." % [r.bp.shape, r.ms["povrch"], r.rep.erosion.mean_change])
	L.append("celý sled s erozí %.0f ms (bez %.0f ms); krok povrch: %s" % [te, tall, ", ".join(ems)])
	L.append("švy s erozí: " + MT.fmt(MT.seams(we.slots)))
	L.append("hash s erozí 2× stejný: %s" % ("ano" if we.hash() == build(pe).hash() else "NE"))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	return L
