extends SceneTree
## E62: dno hlavního tělesa (materiály, plocha propustného / nepropustného dna) pro poslední volání záznamu p58_tag
const C = preload("res://scripts/podzemi52/cache.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PR = preload("res://scripts/bp/params.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	var js = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://shots/alg58/calls_s%d_u%d%s.json" % [nv, nu, String(p.get("p58_tag", ""))])))
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var Gs := V.grid(d.blocks, d.T, d.n, nv, false)
	var ug := F.from_world(C.world_of(d), d.blocks, d.n, nu, p)
	F.set_surface(ug, Gs.W, Gs.hm, Gs.wall, 8.0 / nv)
	for k in js.calls:
		if float(k.q) <= 0.0 or not bool(k.get("final", true)): continue
		var ents := PackedInt32Array(); for e in k.e: ents.append(int(e))
		var excl := {}; for s in k.x: excl[int(s)] = true
		var r := F.solve(ug, ents, float(k.q), excl)
		print("vstupů %d q %.4f → režim %s, průsak %.4f, dno %s" % [ents.size(), float(k.q), r.get("rezim_tel", "?"), float(r.leak), str(r.get("dno", {}))])
	quit()
