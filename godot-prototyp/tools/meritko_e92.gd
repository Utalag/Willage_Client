extends SceneTree
## E92: test měřítka a mírnějších svahů – měření bez obrazu (headless).
##   godot --headless --path . -s res://tools/meritko_e92.gd -- --p92_svah=1 --out=/tmp/e92.json
## Bez --p92_svah=1 se nic nepočítá (příznak výchozí vypnutý). Varianty ostrova START: vyp, sklon 1,0 (45°), 0,6 (31°),
## 0,6 + vyhlazení 2×; voda ostrova (scripts/voda/ostrov_voda.gd) pro každou; blok 128 m z funkce E90 před / po.
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const S92 = preload("res://scripts/teren/svah92.gd")
const SPEC := [[Vector2i(0, 0), "louka", 101], [Vector2i(1, 0), "hora", 202], [Vector2i(0, 1), "kopec", 303], [Vector2i(1, 1), "louka", 404]]

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _island(over: Dictionary) -> Dictionary:
	BlockGen.gen_version = "bp"
	T.reset()
	for k in over: T.p[k] = over[k]
	var blocks := {}
	var t0 := Time.get_ticks_usec()
	var valid := []
	var p92 := []
	for e in SPEC:
		var b := Block.new()
		b.kind = e[1]; b.seed = e[2]; b.slot = e[0]
		BlockGen.build(b, [null, null, null, null])
		T.commit(b)
		blocks[b.slot] = b
		valid.append(b.gen3.valid.get("ok", b.gen3.valid.get("errors", "?")) if b.gen3.valid is Dictionary else b.gen3.valid)
		p92.append(b.bp_rec.rep.get("p92", {}) if b.bp_rec.has("rep") else {})
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# výšky ostrova 32 × 32 sloupců po 0,5 m (m)
	var W := 32
	var h := PackedFloat64Array(); h.resize(W * W)
	var hb := PackedFloat64Array(); hb.resize(256)
	for s in blocks:
		var b = blocks[s]
		for lx in 16:
			for ly in 16:
				h[(s.x * 16 + lx) * W + s.y * 16 + ly] = b.hm[lx * 16 + ly] * 0.5
				if s == Vector2i(1, 0): hb[lx * 16 + ly] = b.hm[lx * 16 + ly] * 0.5
	var v := OV.new()
	t0 = Time.get_ticks_usec()
	v.build(blocks)
	var vms := (Time.get_ticks_usec() - t0) / 1000.0
	var hora: Dictionary = S92.pata(hb, 16, 16, 0.5)
	var hm_all := []
	for x in W:
		var row := []
		for y in W: row.append(h[x * W + y])
		hm_all.append(row)
	return {"parametry": over, "generovani_ms": snappedf(gen_ms, 0.1), "validator": valid, "omezovac": p92,
		"ostrov": S92.stats(h, W, W, 0.5), "hora_blok": S92.stats(hb, 16, 16, 0.5), "hora_pata": hora,
		"voda_ms": snappedf(vms, 0.1), "voda": v.summary(),
		"podzemi_vystupy": v.st.get("under", []).map(func(u): return [String(u.typ), snappedf(float(u.z), 0.01), snappedf(float(u.q), 1e-4)]),
		"hm_m": hm_all}

func _init() -> void:
	if _arg("p92_svah", "0") != "1":
		print("E92: příznak p92_svah je vypnutý (výchozí) – nic se nepočítá")
		quit(); return
	var res := {}
	var vars := [["vyp", {}], ["s10", {"p92_svah": true, "p92_max_sklon": 1.0}], ["s06", {"p92_svah": true, "p92_max_sklon": 0.6}],
		["s06_hladit2", {"p92_svah": true, "p92_max_sklon": 0.6, "p92_hladit": 2}]]
	for vv in vars:
		var r := _island(vv[1])
		res["ostrov_" + vv[0]] = r
		print("%s: grad %s | %s | hora %s | voda %s" % [vv[0], r.ostrov.grad, {"p50": r.ostrov.sklon_p50, "p95": r.ostrov.sklon_p95, "max": r.ostrov.sklon_max, ">45": r.ostrov.nad_45_pct, "schod": r.ostrov.schod_max_m, "relief": r.ostrov.relief_m}, r.hora_pata, r.voda])
	# blok 128 m
	var t0 := Time.get_ticks_usec()
	var bt := S92.best_tile()
	print("dlaždice 128 m s největším převýšením: ", bt.tile, " převýšení (4 m) ", bt.relief_4m, " (", (Time.get_ticks_usec() - t0) / 1000, " ms)")
	res["blok128"] = {"dlazdice": [bt.tile.x, bt.tile.y], "prevyseni_4m": snappedf(bt.relief_4m, 0.01)}
	for vv in [["vyp", 0.0], ["s10", 1.0], ["s06", 0.6]]:
		t0 = Time.get_ticks_usec()
		var th := S92.tile_heights(bt.f, bt.tile, vv[1])
		var st := S92.stats(th.h, th.N, th.N, 0.5)
		var pa := S92.pata(th.h, th.N, th.N, 0.5)
		res["blok128"][vv[0]] = {"stats": st, "pata": pa, "omezovac": th.info, "ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)}
		print("blok128 %s: grad %s | %s %s %s" % [vv[0], st.grad, {"p50": st.sklon_p50, "p95": st.sklon_p95, "max": st.sklon_max, ">30": st.nad_30_pct, ">45": st.nad_45_pct, "schod": st.schod_max_m, "relief": st.relief_m}, pa, th.info])
	var outp := _arg("out", "")
	if outp != "":
		FileAccess.open(outp, FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	print("E92 měření hotovo")
	quit()
