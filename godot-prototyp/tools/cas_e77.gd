extends SceneTree
## E77: časy událostí na ostrově (startovní bloky jako voda_e66): první naplnění tůně (hydro68.udalosti) a první eroze /
## nános E51 (eroze/mech.gd nad buňkami bloků), v herních sekundách, herních dnech a reálně podle faktoru času p71_cas.
## Volby: --bp.<klíč>=hodnota --out=cesta
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const MC = preload("res://scripts/voda/eroze/mech.gd")
const CH = preload("res://scripts/voda/cas_hry.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	BlockGen.gen_version = "bp"; T.reset()
	var blocks := {}
	for e in "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404".split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	var v := OV.new(); v.build(blocks)
	var f := CH.faktor(v.p)
	var ev: Array = H68.udalosti(v.st)
	var tp := INF; var nfill := 0
	for x in ev:
		if float(x[0]) >= 0.0: tp = minf(tp, float(x[0])); nfill += 1
	var n: int = v.W * v.H
	var cells := PackedByteArray(); cells.resize(n * 64)
	for s in blocks:
		var b = blocks[s]
		for x in 16:
			for y in 16:
				var gi: int = v.gi_of(s, x, y)
				for z in 64: cells[gi * 64 + z] = b.geo[(x * 16 + y) * 64 + z]
	var t0 := Time.get_ticks_usec()
	var mc = MC.new(v.p, v.W, v.H, 64, cells, v.wall, v.st.src)
	var mc_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var te: float = mc.q.top_time() if mc.q.size() > 0 else INF
	var wet := 0; var vol := 0.0; var qb := 0.0
	for r in v.st.get("ug_bodies", []):
		wet += Array(r.get("wet67", [])).size(); vol += float(r.get("volume_m3", 0.0)); qb += float(r.get("q_in", 0.0))
	var outs := 0; var outq := 0.0
	for u in v.st.get("under", []): outs += 1; outq += float(u.q)
	var bil: Dictionary = v.hydro().bilance
	var out := {"p71_cas": f, "prameny": v.springs.size(), "vystupy": outs, "vystupy_lps": outq, "mokra_pasma": wet, "objem_m3": vol, "pritok_teles_lps": qb,
		"okraj_lps": bil.okraj, "prameny_z_podzemi_lps": bil.prameny_z_podzemi, "chyba_bilance": bil.chyba_svet, "plny_ms": v.ms.get("celkem", 0.0), "souhrn": v.summary(), "tune_udalosti": ev.size(), "tune_plneni": nfill, "prvni_tun_s": tp, "prvni_tun_dni": CH.dny(tp), "prvni_tun_realne_min": CH.realne_min(tp, v.p),
		"eroze_aktivni": mc.live(), "prvni_eroze_s": te, "prvni_eroze_dni": CH.dny(te), "prvni_eroze_realne_min": CH.realne_min(te, v.p), "e51_ms": mc_ms, "otisk": v.hydro().otisk}
	print("E77 stav: prameny %d, výstupy %d (%.5f l/s), mokrá pásma %d, objem %.2f m³, přítok těles %.5f l/s, okraj %.5f l/s, chyba %s, plný %.0f ms" % [out.prameny, outs, outq, wet, vol, qb, bil.okraj, str(bil.chyba_svet), out.plny_ms])
	print("E77 p71_cas %.0f: první tůň %.1f s = %.4f herních dní = %.2f min reálně (%d událostí plnění); první eroze E51 %.0f s = %.2f herních dní = %.1f min reálně (%d aktivních), otisk %s" % [
		f, tp, out.prvni_tun_dni, out.prvni_tun_realne_min, nfill, te, out.prvni_eroze_dni, out.prvni_eroze_realne_min, out.eroze_aktivni, out.otisk])
	var path := _arg("out", "")
	if path != "": FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	v.dispose(); quit()
