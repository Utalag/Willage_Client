extends SceneTree
## E69: test symetrie a referenční test podzemí (TODO Voda). Syntetický kontext nad pásmy ug_funkce (bez generátoru):
## čtverec N × N uvnitř prstence zdi, zdroj q (1 l/s) do vstupního pásma prostředního sloupce, vrstvy shora s propustností
## 1,0 / 0,8 / 0,6 / 0,4 / 0,2 (zkušební materiály 9001–9005 vložené do tabulky jen zde), pod nimi nepropustné podloží 9000.
## Tvary symetrické podle D4 kolem středu (hranice závisí jen na r = √(dx² + dy²)): plocha, kupole (dna klesají od středu),
## mísa (dna stoupají od středu). Řešiče: E67 pretok (+ O, se / bez slučování), E58 A+B+C a base (auto, jedna hladina).
## Měří: symetrii (8 transformací, max rozdíl po sloupcích a vrstvách), bilanci vstup = výstupy + průsak, profil po vrstvách.
## Parametry --n=21 --t=1.0 --sklon=0.25 --q=1.0 --ponor=0.1 --perm=1.0,0.8,0.6,0.4,0.2 --por=0.3 --tvary=plocha,kupole,misa
## --remizy=1 (E69 oprava remíz, 0 = chování E67b) --varianty=... Výstup shots/e69/vysledky.json.
const PR = preload("res://scripts/bp/params.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const U = preload("res://scripts/alg58/ug58.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const M0 := 9000
const E := 1e-6

## --bp.<klíč>=hodnota → parametry studie (E71)
static func bp_args(p: Dictionary) -> Dictionary:
	var a := PackedStringArray()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--bp."): a.append("--" + s.substr(5))
	return PR.apply_args(p, a)

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

var N := 21; var T := 1.0; var S := 0.25; var Q := 1.0; var PERM := []; var POR := 0.3

func _tab() -> void:
	var t := VS.table()
	t[M0] = [0.0, 0.0, 1.0, 0.0]
	for k in PERM.size(): t[M0 + 1 + k] = [float(PERM[k]), POR, 1.0, 0.0]

## kontext: tvar → sloupce [[lo, hi, mat]]; zeď = prstenec kolem N × N
func _ctx(shape: String, extra: Dictionary) -> Dictionary:
	var p := PR.defaults()
	p.ponor_perm = float(_arg("ponor", "0.1")); p.p52_rezim = "auto"; p.ug_hloubka_m = 2.0 * T
	p.p69_remizy = _arg("remizy", "1") == "1"
	p.p70_prumer = _arg("prumer", String(p.get("p70_prumer", "pomer")))   # E70
	p.merge(extra, true)
	p = bp_args(p)
	var W := N + 2; var m := W / 2; var nl := PERM.size()
	var c := F._new(W, W, 1.0, p)
	var rmax := sqrt(2.0) * (N / 2)
	for x in range(1, W - 1):
		for y in range(1, W - 1):
			var r := sqrt(float((x - m) * (x - m) + (y - m) * (y - m)))
			var g := 0.0
			if shape == "kupole": g = -S * r
			elif shape == "misa": g = S * r
			var zb := 1.0 + S * rmax + g
			var lst := [[0.0, zb, M0]]
			for k in nl:   # zdola: nejméně propustná (poslední) dole
				var lo := zb + k * T
				lst.append([lo, lo + T, M0 + nl - k])
			var gi := x * W + y
			c.wall[gi] = 0; c.h[gi] = zb + nl * T; c.cols[gi] = lst
	F._finish(c)
	F.set_surface(c, W, PackedFloat64Array(), c.wall, 1.0)
	c._bfs_max = 20000; c._useD = false; c._useE = false; c._useI = false
	return c

func _tf(dx: int, dy: int, i: int) -> Vector2i:
	match i:
		0: return Vector2i(dx, dy)
		1: return Vector2i(-dx, dy)
		2: return Vector2i(dx, -dy)
		3: return Vector2i(-dx, -dy)
		4: return Vector2i(dy, dx)
		5: return Vector2i(-dy, dx)
		6: return Vector2i(dy, -dx)
	return Vector2i(-dy, -dx)

## f: "dx,dy|klíč" → hodnota; max |f(k) − f(T k)| přes 7 netriviálních transformací, počet nesymetrických položek
func _sym(f: Dictionary) -> Dictionary:
	var mx := 0.0; var bad := {}
	for k in f:
		var a: PackedStringArray = k.split("|"); var d := a[0].split(",")
		var dx := int(d[0]); var dy := int(d[1])
		for i in range(1, 8):
			var v := _tf(dx, dy, i)
			var k2 := "%d,%d|%s" % [v.x, v.y, a[1]]
			var e := absf(float(f[k]) - float(f.get(k2, 0.0)))
			if e > 1e-9: bad[k] = true
			mx = maxf(mx, e)
	return {"max": mx, "nesym": bad.size(), "polozek": f.size()}

func _key(c: Dictionary, cc: int, tag: String) -> String:
	var m: int = int(c.W) / 2
	return "%d,%d|%s" % [cc / int(c.H) - m, cc % int(c.H) - m, tag]

func _lay(c: Dictionary, b: int) -> String:
	return "L%d" % (int(c.mat[b]) - M0) if int(c.mat[b]) > M0 else "m%d" % int(c.mat[b])

func _run(shape: String, label: String, solver: String, extra: Dictionary) -> Dictionary:
	var c := _ctx(shape, extra)
	var W: int = c.W; var m := W / 2
	var src := m * W + m
	var e := F.entry(c, src)
	var calls := [{"ents": PackedInt32Array([e]), "q": Q, "excl": {}, "x": [], "ex": {}, "final": true}]
	c._ents = {e: true}
	var st := {"builds": 0, "floods": 0, "results": 0, "fallback": 0, "exact": 0, "skipped": 0, "rebuilds": 0, "deltas": 0, "gone": 0, "reach": 0, "splits": 0}
	var t0 := Time.get_ticks_usec()
	var abc := solver == "ABC"
	var r: Dictionary = U._one(c, calls, 0, abc, abc, abc, 0.0625, st)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var fo := {}; var fw := {}; var fwt := {}
	var out := {"tvar": shape, "varianta": label, "vstup_pasmo": _lay(c, e), "ms": snappedf(ms, 0.01)}
	var oq := 0.0; var per_lay := {}; var cons := 0.0
	if r.has("outs67"):
		for o in r.outs67:
			oq += float(o[3])
			var kk := _key(c, int(o[2]), "%s@%s" % [String(o[1]), _lay(c, int(o[4])) if int(o[4]) >= 0 else "past"])
			fo[kk] = float(fo.get(kk, 0.0)) + float(o[3])
			var lk := (_lay(c, int(o[4])) if int(o[4]) >= 0 else "past") + " " + String(o[1])
			per_lay[lk] = snappedf(float(per_lay.get(lk, 0.0)) + float(o[3]), 1e-9)
		for i in r.wet67.size():
			var b: int = r.wet67[i]
			var kk := _key(c, int(c.bcol[b]), _lay(c, b))
			fw[kk] = float(fw.get(kk, 0.0)) + float(r.wetq67[i])
		var pits := []
		cons = float(r.get("leak67w", 0.0)); out.prusak_tok = snappedf(cons, 1e-12)
		for pt in r.pits67:
			var lk := float(pt.prusak_pouzit)   # E71: použitý průsak pasti (dřív min(přítok, průsak))
			cons += lk
			pits.append({"hladina": snappedf(pt.hladina, 1e-4), "pasem": pt.pasem, "typ": pt.typ, "q_in": snappedf(pt.q_in, 1e-9), "prusak": snappedf(lk, 1e-9), "dolu": snappedf(pt.dolu, 1e-9), "objem_m3": snappedf(pt.objem_m3, 1e-4)})
		out.pasti = pits; out.mokrych = r.wet67.size(); out.vystupu = r.outs67.size(); out.oriznuto = r.cut67
	else:
		oq = float(r.out_q); cons = float(r.leak)
		if not r.out.is_empty():
			var kk := _key(c, int(r.out[4]), String(r.out[3]))
			fo[kk] = oq
			out.vystup = {"z": snappedf(float(r.out[0]), 1e-4), "typ": r.out[3], "sloupec": kk.split("|")[0], "pasmo": _lay(c, int(r.out[2]))}
		out.hladina = snappedf(float(r.z_out), 1e-4); out.rezim_tel = r.get("rezim_tel", ""); out.uzavreno = r.closed
		out.vystupu = 0 if r.out.is_empty() else 1
	out.objem_m3 = snappedf(float(r.volume_m3), 1e-4)
	for cc in W * W:
		if float(c.wt[cc]) >= 0.0: fwt[_key(c, cc, "wt")] = float(c.wt[cc])
	out.bilance = {"vstup": Q, "vystupy": snappedf(oq, 1e-12), "prusak": snappedf(cons, 1e-12), "chyba": snappedf(Q - oq - cons, 1e-12)}
	out.symetrie = {"vystupy_lps": _sym(fo), "tok_lps": _sym(fw), "hladina_m": _sym(fwt)}
	out.vystupy_po_vrstvach = per_lay
	return out

func _init() -> void:
	N = int(_arg("n", "21")); T = float(_arg("t", "1.0")); S = float(_arg("sklon", "0.25")); Q = float(_arg("q", "1.0"))
	POR = float(_arg("por", "0.3"))
	for s in _arg("perm", "1.0,0.8,0.6,0.4,0.2").split(","): PERM.append(float(s))
	_tab()
	var V := {"pretok+O": ["pretok", {"p67_okraj": true, "p67_rezim": "pretok"}],
		"pretok+O bez slucovani": ["pretok", {"p67_okraj": true, "p67_rezim": "pretok", "p67_prune": false}],
		"E58 ABC+O": ["ABC", {"p67_okraj": true}], "E58 base+O": ["base", {"p67_okraj": true}]}
	var names := _arg("varianty", ",".join(V.keys())).split(",")
	var res := []
	for shape in _arg("tvary", "plocha,kupole,misa").split(","):
		for nm in names:
			var o := _run(shape, nm, V[nm][0], V[nm][1])
			res.append(o)
			print("%-7s %-24s bilance chyba %.12f (výstupy %.9f, průsak %.9f) | sym výstupy %.4f (%d) tok %.4f (%d) hladina %.4f (%d) | výstupů %d%s | %s" % [shape, nm,
				o.bilance.chyba, o.bilance.vystupy, o.bilance.prusak, o.symetrie.vystupy_lps.max, o.symetrie.vystupy_lps.nesym,
				o.symetrie.tok_lps.max, o.symetrie.tok_lps.nesym, o.symetrie.hladina_m.max, o.symetrie.hladina_m.nesym, o.vystupu, " ORIZNUTO" if o.get("oriznuto", false) else "", JSON.stringify(o.vystupy_po_vrstvach)])
	var tag := _arg("tag", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/e69"))
	FileAccess.open("res://shots/e69/vysledky%s.json" % tag, FileAccess.WRITE).store_string(JSON.stringify({"n": N, "t": T, "sklon": S, "q": Q, "perm": PERM, "ponor": _arg("ponor", "0.1"), "vysledky": res}, " "))
	quit()
