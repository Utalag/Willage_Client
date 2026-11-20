extends SceneTree
## E95: test zkušebního panelu bez obrazu. Spustí hru (main.tscn), každý přepínač zapne a vypne (číselný parametr nastaví
## se zapnutým rodičem), změří čas přestavby a otisk vody, po vypnutí ověří návrat na výchozí otisk. Pak dvojice
## přepínačů terénu, vše najednou a živé přepínače spolu. Chyby skriptu hledej ve výstupu (SCRIPT ERROR).
## --out=cesta.json (výchozí ../blueprint-studie/shots/e95/zkusebni_e95.json), --dvojice=0|1, --jen=klic,klic, --tb=klic,… (dvojice jen z těchto)
const PN = preload("res://scripts/game/zkusebni/panel.gd")
const P = preload("res://scripts/game/zkusebni/prepinace.gd")

var res := {"jednotlive": [], "dvojice": [], "kombinace": []}

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _initialize() -> void:
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()

func _ready_wait() -> void:
	while true:
		await process_frame
		if PN.aktivni != null and PN.regen_t0 == 0 and PN.aktivni.is_inside_tree(): break
	for i in 3: await process_frame

func _otisk() -> String:
	return PN.aktivni._otisk()

func _nastav(k: String, v) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var before := PN.posledni.duplicate()
	PN.aktivni.nastav(k, v, true)
	var sync_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await _ready_wait()
	var regen: bool = PN.posledni != before and PN.posledni.get("klic", "") == k
	return {"ms": float(PN.posledni.ms) if regen else sync_ms, "prestavba": regen, "otisk": _otisk()}

func _stav_regen(st: Dictionary, klic: String) -> Dictionary:
	PN.stav = st.duplicate()
	PN._sync_over()
	PN.aktivni.prestavba(klic)
	await _ready_wait()
	return {"ms": float(PN.posledni.ms), "otisk": _otisk()}

func _run() -> void:
	await _ready_wait()
	var start := _otisk()
	res.start_otisk = start
	print("E95 test: start otisk ", start)
	var jen := _arg("jen", "")
	var mid := func(e): return snappedf(lerpf(float(e.min), float(e.max), 0.5), float(e.get("krok", 1.0))) if e.t == "f" else int((int(e.min) + int(e.max) + 1) / 2)
	for e in P.SEZNAM:
		if jen != "" and not (e.k in jen.split(",")): continue
		var r := {"k": e.k, "cil": e.cil}
		if e.has("rodic"):
			var pv = true if P.zaznam(e.rodic).t == "b" else 1
			await _nastav(e.rodic, pv)
		var on_v = true
		if e.t == "f" or e.t == "i": on_v = mid.call(e)
		elif e.t == "o": on_v = e.hodnoty[e.hodnoty.size() - 1]
		var a: Dictionary = await _nastav(e.k, on_v)
		r.zap = a
		var b: Dictionary = await _nastav(e.k, PN.vychozi(e.k))
		r.vyp = b
		if e.has("rodic"):
			await _nastav(e.rodic, PN.vychozi(e.rodic))
		r.zpet_otisk = _otisk()
		r.zpet_ok = r.zpet_otisk == start
		print("E95 %s: zap %.0f ms (%s) otisk %s · vyp %.0f ms · zpět %s" % [e.k, a.ms, "přestavba" if a.prestavba else "za běhu", a.otisk, b.ms, "OK" if r.zpet_ok else "JINÝ " + r.zpet_otisk])
		res.jednotlive.append(r)
	if _arg("dvojice", "1") == "1":
		var tb := []
		for e in P.SEZNAM:
			if e.cil == "teren" and e.t == "b" and not e.has("rodic"): tb.append(e.k)
		tb.append("p94_hora_k")
		if _arg("tb", "") != "": tb = Array(_arg("tb", "").split(","))
		for i in tb.size():
			for j in range(i + 1, tb.size()):
				var st := {}
				for k in [tb[i], tb[j]]: st[k] = 1.5 if k == "p94_hora_k" else true
				var r: Dictionary = await _stav_regen(st, "%s+%s" % [tb[i], tb[j]])
				r.k = [tb[i], tb[j]]
				print("E95 dvojice %s + %s: %.0f ms otisk %s" % [tb[i], tb[j], r.ms, r.otisk])
				res.dvojice.append(r)
		var vse := {}
		for k in tb: vse[k] = 1.5 if k == "p94_hora_k" else true
		var rv: Dictionary = await _stav_regen(vse, "vše terénu")
		rv.k = "vše terénu"; res.kombinace.append(rv)
		print("E95 vše terénu: %.0f ms otisk %s" % [rv.ms, rv.otisk])
	# živé spolu (+ metry)
	var live := {"p89_meritko": true, "p90_lod": true, "p91_pruhlednost": true, "p91_mode": 3, "zk_rez": 1, "zk_rez_pos": 0.4, "p85_okraj": true, "p86_otoceni": true}
	var rl: Dictionary = await _stav_regen(live, "živé + metry")
	for i in 30: await process_frame
	PN.aktivni.nastav("zk_rez", 2); PN.aktivni.nastav("zk_rez_pos", 0.7)
	for i in 10: await process_frame
	rl.k = "živé + metry"; res.kombinace.append(rl)
	print("E95 živé + metry: %.0f ms otisk %s" % [rl.ms, rl.otisk])
	PN.aktivni.vse_vypnout()
	await _ready_wait()
	res.konec_otisk = _otisk()
	res.konec_ok = res.konec_otisk == start
	print("E95 konec: otisk ", res.konec_otisk, " ", "OK" if res.konec_ok else "JINÝ")
	var out := _arg("out", ProjectSettings.globalize_path("res://").path_join("../blueprint-studie/shots/e95/zkusebni_e95.json"))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	f.close()
	print("E95 zapsáno ", out)
	quit()
