extends RefCounted
## Test Janova příkladu (19:48): pramen 1/t, prohlubeň 2 × 2 × 2 = 8, odtok 0,5/t → plná za 16 t, pak 0,5 do podzemí + 0,5 přepadem.
## Plus krajní případy: odtok ≥ přítok → nenaplní se (ponor), odtok 0 → plná za 8 t a vše přepadá. Jednotky: buňka 1, vrstva 1, průtok 1/t.

const TOK = preload("res://scripts/voda/tok.gd")
const HR = preload("res://scripts/bp/horniny.gd")

static func _case(pit_q: float) -> Dictionary:
	var W := 6; var H := 6
	var hm := PackedFloat64Array(); hm.resize(W * H); hm.fill(10.0)
	var pit := [2 * H + 2, 2 * H + 3, 3 * H + 2, 3 * H + 3]
	for i in pit: hm[i] = 8.0
	var wall := PackedByteArray(); wall.resize(W * H)
	var mats := PackedInt32Array(); mats.resize(W * H); mats.fill(HR.id_of("quartz_sandstone"))   # perm 0,5 ve sdílené tabulce
	var src := PackedFloat64Array(); src.resize(W * H); src[pit[0]] = 1.0
	var L := {"thr": 0.0, "cap": 0.0, "inf": 0.0, "perm_min": 0.3, "springs": true, "pit_q": pit_q}
	var st := TOK.make(hm, W, H, wall, mats, src, L, true)
	TOK.route(st)
	var pd: Dictionary = TOK.ponds(st, 1.0, 1.0, true, 1.0)[0]
	var edge := 0.0
	for e in TOK.edge_falls(st): edge += e.q
	var under := 0.0
	for u in st.under: under += u.q
	return {"pd": pd, "edge": edge, "under": under, "n_under": st.under.size()}

static func run_all() -> PackedStringArray:
	var L := PackedStringArray(); var ok := true
	L.append("# Test plnění prohlubně s propustností (Jan 19:48)")
	for c in [[0.25, 0.5, 16.0, 0.5, 0.5], [0.5, 1.0, -1.0, 0.0, 1.0], [0.0, 0.0, 8.0, 1.0, 0.0]]:
		var r := _case(c[0]); var pd: Dictionary = r.pd; var ev: Array = pd.udalosti
		var t: float = ev[-1].cas_s if not ev.is_empty() else -1.0
		var good: bool = absf(pd.drain_lps - c[1]) < 1e-6 and absf(pd.objem_m3 - 8.0) < 0.05 and (absf(t - c[2]) < 0.05 if c[2] > 0 else t < 0.0) \
			and absf(r.edge - c[3]) < 1e-6 and absf(r.under - c[4]) < 1e-6
		ok = ok and good
		L.append("odtok %.2f/t (perm 0,5 · %.2f · 4 buňky): objem %.3f, vrstvy %s → %s | přepad přes okraj %.2f, podzemí %.2f (vyvěračka ve stěně %d) | očekáváno: plná za %s, přepad %.1f, podzemí %.1f → %s" % [
			pd.drain_lps, c[0], pd.objem_m3, ", ".join(ev.map(func(e): return "%.0f @ %.3f t" % [e.hladina_m, e.cas_s])),
			"NENAPLNÍ SE (ponor)" if pd.nenaplni_se else "plná za %.3f t" % t, r.edge, r.under, r.n_under,
			"nikdy" if c[2] < 0 else "%.0f t" % c[2], c[3], c[4], "OK" if good else "CHYBA"])
	L.append("výsledek: %s" % ("VŠE OK" if ok else "CHYBA"))
	return L
