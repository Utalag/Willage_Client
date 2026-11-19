extends SceneTree
## E70: malý případ jíl / písek pro dělení vody do stran (p70_prumer pomer vs harmonicky). Řada 5 sloupců (y = 1, řádky
## y = 0 a 2 jsou zeď, okraj zdi vypnutý): zdroj q do pásma prostředního sloupce x = 2, sousedé x = 1 a 3 mají dno o `dz`
## níž, krajní x = 0 a 4 ještě níž (okraj mřížky = výstup). Jedna propustná vrstva tloušťky 1 m na nepropustném podloží.
## Případ = materiály (střed, západ, východ); podíl vody, který odteče na západ / východ. Zkušební materiály: písek 0,833,
## „jíl“ jako těleso s perm 0,05 (ponor testu 0,01), skutečný vápenec 0,246 (kras). Výstup shots/e70/maly.json.
const PR = preload("res://scripts/bp/params.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const U = preload("res://scripts/alg58/ug58.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const IMP := 9100; const SAND := 9101; const CLAY := 9102; const LIME := 9103

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _ctx(mats: Array, prumer: String, dz: float) -> Dictionary:
	var p := PR.defaults()
	p.ponor_perm = 0.01; p.p52_rezim = "auto"; p.p67_rezim = "pretok"; p.p67_okraj = false; p.p67_prune = false
	p.p70_prumer = prumer; p.ug_hloubka_m = 2.0
	var W := 5; var H := 3
	var c := F._new(W, H, 1.0, p)
	var fl := [0.0, dz, 2.0 * dz, dz, 0.0]   # výška dna podle x
	var mx := [mats[1], mats[1], mats[0], mats[2], mats[2]]
	for x in W:
		var gi := x * H + 1
		var zb: float = 1.0 + fl[x]
		c.wall[gi] = 0; c.h[gi] = zb + 1.0; c.cols[gi] = [[0.0, zb, IMP], [zb, zb + 1.0, mx[x]]]
	F._finish(c)
	F.set_surface(c, W, PackedFloat64Array(), c.wall, 1.0)
	return c

func _init() -> void:
	var t := VS.table()
	t[IMP] = [0.0, 0.0, 1.0, 0.0]; t[SAND] = [0.833, 0.35, 1.0, 0.0]; t[CLAY] = [0.05, 0.5, 1.0, 0.0]; t[LIME] = [0.246, 0.05, 1.0, 0.0]
	var N := {SAND: "pisek", CLAY: "jil", LIME: "vapenec"}
	var dz := float(_arg("dz", "0.25")); var q := float(_arg("q", "1.0"))
	var cases := [[SAND, SAND, SAND], [SAND, SAND, CLAY], [CLAY, SAND, CLAY], [CLAY, CLAY, SAND], [LIME, SAND, LIME], [SAND, SAND, LIME]]
	var out := []
	for m in cases:
		var row := {"stred": N[m[0]], "zapad": N[m[1]], "vychod": N[m[2]]}
		for pr in ["pomer", "harmonicky"]:
			var c := _ctx(m, pr, dz)
			var e := F.entry(c, 2 * 3 + 1)
			var r: Dictionary = load("res://scripts/podzemi52/ug67.gd").solve(c, PackedInt32Array([e]), q, {})
			var wq := 0.0; var eq := 0.0; var tot := 0.0
			for o in r.outs67:
				tot += float(o[3])
				if int(o[2]) / 3 < 2: wq += float(o[3])
				else: eq += float(o[3])
			row[pr] = {"zapad": snappedf(wq, 1e-4), "vychod": snappedf(eq, 1e-4), "bilance_chyba": q - tot}
		out.append(row)
		print("%-8s | Z %-8s V %-8s | pomer Z %.3f V %.3f | harmonicky Z %.3f V %.3f | chyba %.12f / %.12f" % [row.stred, row.zapad, row.vychod,
			row.pomer.zapad, row.pomer.vychod, row.harmonicky.zapad, row.harmonicky.vychod, row.pomer.bilance_chyba, row.harmonicky.bilance_chyba])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/e70"))
	FileAccess.open("res://shots/e70/maly.json", FileAccess.WRITE).store_string(JSON.stringify({"dz": dz, "q": q, "pripady": out}, " "))
	quit()
