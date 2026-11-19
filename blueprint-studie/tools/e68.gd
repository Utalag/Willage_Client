extends SceneTree
## E68 test smyčky tůň → průsak → pramen → tůň. Mísa (tůň nad polopropustnou vrstvou, propustná zvodeň pod ní),
## kopec na okraji mísy s „komínem“ písku až k povrchu → pramen nad tůní teče zpět do tůně; přeliv tůně k okraji mapy.
## Povrch tok.gd (edge_out), podzemí ug_funkce (auto / E67 pretok). Měří kola do ustálení, bilanci po 4 kolech
## a po ustálení, analytickou kontrolu a otisk mezi běhy.
## Argumenty: --n=15 --zdroj=0.1 (l/s) --pit_q=0.07 --kola=200 --tol=1e-9 --rezim=auto|pretok --bp.<klíč>=… --out=
const PR = preload("res://scripts/bp/params.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const VS = preload("res://scripts/voda/voda_svet.gd")
const TOK = preload("res://scripts/voda/tok.gd")
const H68 = preload("res://scripts/hydro68/hydro68.gd")
const M0 := 9300   # nepropustná
const MS := 9301   # písek (těleso)
const MC := 9302   # polopropustná krycí vrstva (pod ponor_perm)

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

static func bp_args(p: Dictionary) -> Dictionary:
	var a := PackedStringArray()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--bp."): a.append("--" + s.substr(5))
	return PR.apply_args(p, a)

func _terrain(W: int) -> PackedFloat64Array:
	var m := W / 2; var hm := PackedFloat64Array(); hm.resize(W * W)
	var hx := m; var hy := m - 4   # vrchol kopce na vnitřní straně okraje mísy
	for x in W:
		for y in W:
			var r := sqrt(float((x - m) * (x - m) + (y - m) * (y - m)))
			var h := 10.0 + 0.4 * r if r <= 5.0 else 12.0 - 0.3 * (r - 5.0)
			var d := sqrt(float((x - hx) * (x - hx) + (y - hy) * (y - hy)))
			h += 4.0 * maxf(0.0, 1.0 - d / 2.5)
			hm[x * W + y] = snappedf(h, 0.01)
	return hm

func _build(W: int, p: Dictionary, zdroj: float, pit_q: float) -> Dictionary:
	var t := VS.table()
	t[M0] = [0.0, 0.0, 1.0, 0.0]; t[MS] = [0.8, 0.3, 1.0, 0.0]; t[MC] = [0.2, 0.3, 1.0, 0.0]
	var m := W / 2; var hm := _terrain(W); var n := W * W
	var pipe := m * W + (m - 3)   # komín písku k povrchu na svahu kopce nad tůní
	var c := F._new(W, W, 1.0, p)
	var mats := PackedInt32Array(); mats.resize(n)
	for x in W:
		for y in W:
			var gi := x * W + y
			var r := sqrt(float((x - m) * (x - m) + (y - m) * (y - m)))
			var h: float = hm[gi]
			var lst := []
			if x == 0 or y == 0 or x == W - 1 or y == W - 1: lst = [[0.0, h, M0]]
			elif gi == pipe: lst = [[0.0, 2.0, M0], [2.0, h, MS]]
			else: lst = [[0.0, 2.0, M0], [2.0, 8.0, MS], [8.0, h, MC if r <= 5.0 else M0]]
			c.wall[gi] = 0; c.h[gi] = h; c.cols[gi] = lst
			mats[gi] = MC if r <= 5.0 else M0
	F._finish(c)
	F.set_surface(c, W, PackedFloat64Array(), c.wall, 1.0)
	c._bfs_max = 20000; c._useD = false; c._useE = false; c._useI = false
	c.impl = F
	var src := PackedFloat64Array(); src.resize(n)
	src[(m - 1) * W + (m - 2)] = zdroj   # zdroj pod pramenem (pramen teče přes něj → stejná větev tůně)
	var L := TOK.losses(p, true); L.pit_q = pit_q
	var wall := PackedByteArray(); wall.resize(n)
	var st := TOK.make(hm, W, W, wall, mats, src, L, true)
	st.ug = c
	return st

func _run(W: int, p: Dictionary, zdroj: float, pit_q: float, kola: int, tol: float) -> Dictionary:
	var st := _build(W, p, zdroj, pit_q)
	var r := H68.full(st, kola, tol, kola > 4, kola > 4 and bool(p.get("p73_zrychleni", false)))
	var b := H68.bilance(st)
	var o := H68.otisk(st)
	var ponds := TOK.ponds(st, 0.25, 0.5, false)
	var dr := 0.0; var pq := 0.0
	for x in ponds:
		if not x["suchá"]: dr += float(x.drain_lps); pq += float(x.q_lps)
	var calls := int(st.ug.stats.solves)
	if _arg("ladit", "0") == "1":
		for u in st.under:
			var path := []; var i: int = int(u.exit); var g := 0
			while i >= 0 and g < 40: path.append([i / W, i % W, snappedf(st.hm[i], 0.01), snappedf(st.fill[i], 0.01)]); i = st.to[i]; g += 1
			print("výstup ", u, " cesta ", path)
	st.ug.clear(); st.clear()
	return {"skoky": r.get("skoky", 0), "kola": r.kola, "ustaleno": r.ustaleno, "zmena": r.zmena, "ms": snappedf(r.ms, 0.01), "bilance": b, "otisk": o,
		"tun_drain_kapacita": dr, "tun_pritok": pq, "volani_podzemi": calls}

func _init() -> void:
	var W := int(_arg("n", "15")); var zdroj := float(_arg("zdroj", "0.1")); var pit_q := float(_arg("pit_q", "0.07"))
	var kola := int(_arg("kola", "200")); var tol := float(_arg("tol", "1e-9"))
	var out := {}
	for rz in _arg("rezim", "auto,pretok").split(","):
		var p := PR.defaults()
		p.p52_rezim = "auto"; p.ponor_perm = 0.3
		if rz == "pretok": p.p67_rezim = "pretok"
		p = bp_args(p)
		var a := _run(W, p, zdroj, pit_q, 4, 0.0)
		var z := _run(W, p, zdroj, pit_q, kola, tol)
		var z2 := _run(W, p, zdroj, pit_q, kola, tol)
		out[rz] = {"4_kola": a, "ustaleni": z, "znovu_stejny_otisk": z.otisk == z2.otisk}
		for nm in ["4_kola", "ustaleni"]:
			var e: Dictionary = out[rz][nm]; var bb: Dictionary = e.bilance
			print("%-7s %-9s skoky %d kola %3d ustaleno %-5s změna %.9f | zdroje %.6f okraj %.6f průsak %.6f stěna %.6f do hloubky %.6f | prameny %.6f odtok tůní %.6f (kapacita %.6f, přítok tůně %.6f) | chyba svět %.9f povrch %.9f dolů %.9f nahoru %.9f podzemí %.9f | volání %d | %s ms %.1f" % [
				rz, nm, e.skoky, e.kola, str(e.ustaleno), e.zmena, bb.zdroje, bb.okraj, bb.podzemi_prusak, bb.podzemi_stena, bb.do_hloubky,
				bb.prameny_z_podzemi, bb.odtok_tuni, e.tun_drain_kapacita, e.tun_pritok, bb.chyba_svet, bb.chyba_povrch, bb.chyba_dolu,
				bb.chyba_nahoru, bb.chyba_podzemi, e.volani_podzemi, e.otisk, e.ms])
		print("%-7s otisk při opakování stejný: %s" % [rz, str(out[rz].znovu_stejny_otisk)])
	var f := FileAccess.open(_arg("out", "res://shots/e68/smycka.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true)); f.close()
	quit()
