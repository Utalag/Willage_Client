extends SceneTree
## Krok 1 (V1.0): test základů. Rozměry (1.1, 1.3, 1.4), verze Vmajor.minor (6.2), tabulka materiálů (1.6),
## otisk všeho pro determinismus mezi procesy. Výstup JSON (--out=cesta), souhrn na stdout, návratový kód 1 = chyba.
const R = preload("res://scripts/v1/rozmery.gd")
const V = preload("res://scripts/v1/verze.gd")
const M = preload("res://scripts/v1/materialy.gd")
const H = preload("res://scripts/stable_hash.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	var out := {}
	var chyb := 0
	var otisk := ""
	# 1) rozměry: všechny platné kombinace výšky a segmentu, plus záměrně neplatné
	var komb: Array = []
	for vy in R.VYSKY_SLOUPCE_M:
		for sg in R.SEGMENTY_M:
			var r := R.vychozi()
			r.sloupec_m = vy
			r.segment_m = sg
			var ch := R.over(r)
			var o := R.odvozene(r)
			komb.append({"sloupec_m": vy, "segment_m": sg, "chyby": ch, "odvozene": o, "bity_indexu": R.bity_indexu(r)})
			if not ch.is_empty(): chyb += 1
			otisk += JSON.stringify(o)
	out["platne"] = komb
	var spatne := [["blok_m", 100.0], ["blok_m", 96.0], ["sloupec_m", 48.0], ["segment_m", 12.0], ["bunka_m", 0.3],
		["jemna_m", 0.2], ["svet_max_m", 3000.0], ["svet_start_bloku", 64], ["slupka_bunek", 5]]
	var odm: Array = []
	for s in spatne:
		var r := R.vychozi()
		r[s[0]] = s[1]
		var ch := R.over(r)
		odm.append({"zmena": "%s=%s" % s, "odmitnuto": not ch.is_empty(), "duvod": ch})
		if ch.is_empty(): chyb += 1
	out["neplatne"] = odm
	# 2) index tam a zpět: segment 8 m, jemná 0,25 m, sloupec 128 m (32 × 32 × 512)
	var r0 := R.vychozi()
	var o0 := R.odvozene(r0)
	var n: int = o0.segment_jemnych
	var nz: int = o0.sloupec_jemnych
	var t0 := Time.get_ticks_usec()
	var ich := 0
	var cnt := 0
	for a in n:
		for b in n:
			for h in nz:
				var i := R.idx(a, b, h, n, nz)
				if i != cnt or R.idx_rozloz(i, n, nz) != Vector3i(a, b, h): ich += 1
				cnt += 1
	out["index"] = {"n": n, "nz": nz, "pocet": cnt, "chyb": ich, "bity": R.bity_indexu(r0), "ms": (Time.get_ticks_usec() - t0) / 1000.0}
	chyb += ich
	if R.bity_indexu(r0) != 19: chyb += 1   # 1.3: 128 m → 19 bitů
	# 3) verze
	var vt := [["V1.0", "V1.1", -1], ["V1.1", "V1.0", 1], ["V1.9", "V1.10", -1], ["V2.0", "V1.99", 1], ["V1.0", "V1.0", 0]]
	var vch := 0
	for t in vt:
		if V.porovnej(t[0], t[1]) != t[2]: vch += 1
	var chybne := ["1.0", "v1.0", "V1", "V1.0.0", "V-1.0", "V01.0", "V1.x", "V256.0", ""]
	for s in chybne:
		if V.platna(s): vch += 1
	if not V.kompatibilni("V1.0", "V1.7") or V.kompatibilni("V1.0", "V2.0"): vch += 1
	for s in ["V0.0", "V1.0", "V1.255", "V255.255"]:
		if V.z_u16(V.na_u16(s)) != s: vch += 1
	out["verze"] = {"aktualni": V.AKTUALNI, "u16": V.na_u16(V.AKTUALNI), "chyb": vch}
	chyb += vch
	otisk += V.AKTUALNI
	# 4) tabulka materiálů
	var t1 := Time.get_ticks_usec()
	var tab := M.nacti()
	var nac_ms := (Time.get_ticks_usec() - t1) / 1000.0
	var mch: Array = tab.get("chyby", [tab.get("chyba", "")])
	var perm_odch: Array = []
	for id in tab.ids:
		var m: Dictionary = tab.podle_id[id]
		if id < 0 or id > 255: mch.append("id %d mimo u8" % id)
		if not is_nan(m.K_m_s) and not is_nan(m.propustnost_0_1):
			var p := M.perm_z_k(m.K_m_s)
			if absf(p - m.propustnost_0_1) > 0.01: perm_odch.append({"id": id, "nazev": m.nazev, "tabulka": m.propustnost_0_1, "vzorec": snappedf(p, 0.001)})
		otisk += "%d|%s|%s|%s;" % [id, m.nazev, str(m.K_m_s), str(m.hustota_kg_m3)]
	out["materialy"] = {"pocet": tab.ids.size(), "chyby": mch, "perm_odchylky": perm_odch, "nacteni_ms": nac_ms}
	chyb += mch.size()
	out["otisk"] = H.hex(H.fnv1a64(otisk))
	out["chyb_celkem"] = chyb
	var p := _arg("out", "shots/krok01/zaklad_v1.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("zaklad_v1: chyb %d, otisk %s, index %d buněk %.1f ms, materiálů %d, odchylek perm %d" % [chyb, out.otisk, cnt, out.index.ms, tab.ids.size(), perm_odch.size()])
	quit(1 if chyb > 0 else 0)
