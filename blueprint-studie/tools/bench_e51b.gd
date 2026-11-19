extends SceneTree
## godot --headless --path . -s res://tools/bench_e51b.gd -- [--e51_perf_n=128 --e51b_ev=100]
## E51b: ms na událost na mapě perf (128²) + otisk stavu (hm, eff, fill, to, pw, extra, src2, log událostí) pro kontrolu shody
const B = preload("res://scripts/eroze51/beh51.gd")
const SC = preload("res://scripts/eroze51/scenare.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var N := int(p.e51_perf_n); var ev := int(p.get("e51b_ev", 100))
	var t0 := Time.get_ticks_usec()
	var mp = B.make(SC.perf(N, int(p.world_seed)), p)
	var init_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var per := []
	for k in ev:
		var t1 := Time.get_ticks_usec()
		if not mp.step(INF): break
		per.append((Time.get_ticks_usec() - t1) / 1000.0)
	var u: Array = mp.stats.upd_ms.duplicate(); u.sort(); var ps := per.duplicate(); ps.sort()
	var su := 0.0
	for x in u: su += x
	var sp := 0.0
	for x in per: sp += x
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256)
	var st: Dictionary = mp.st
	hc.update(PackedInt32Array(mp.hm).to_byte_array())
	for k in ["eff", "fill", "ain", "extra", "src2"]: hc.update(PackedFloat64Array(st[k]).to_byte_array())
	hc.update(PackedInt32Array(st.to).to_byte_array()); hc.update(PackedByteArray(st.pw))
	hc.update(var_to_bytes(mp.evlog)); hc.update(var_to_bytes(st.under))
	print("E51b %d² %d událostí: start %.0f ms | TOK.update průměr %.2f ms, medián %.2f, max %.2f | celá událost průměr %.2f ms, medián %.2f | otisk %s" % [
		N, per.size(), init_ms, su / maxf(u.size(), 1), u[u.size() / 2], u[-1], sp / maxf(per.size(), 1), ps[ps.size() / 2], hc.finish().hex_encode().left(16)])
	quit()
