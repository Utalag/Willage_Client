extends SceneTree
## E48: navzorkuje funkce povrchu a hranic vrstev hustě (n × n bodů na blok včetně okrajů) → shots/funkce.json
## godot --headless --path . -s res://tools/dump_funkce.gd -- [--fn_n=25]
const T = preload("res://scripts/bp/tests_horniny.gd")
const SC = preload("res://scripts/bp/scenario_horniny.gd")
const PR = preload("res://scripts/bp/params.gd")
const FN = preload("res://scripts/bp/geo_fn.gd")
const HR = preload("res://scripts/bp/horniny.gd")

const CASES := {"nizina": [Vector2i(2, 1)], "hora_vyzdvizena": [Vector2i(0, 0)], "hora_zvrasnena": [Vector2i(1, 2)],
	"sopka": [Vector2i(2, 0)], "jezero": [Vector2i(1, 0)]}

static func block(w, s: Vector2i, n: int) -> Dictionary:
	var wf := FN.world_fn(w.slots)
	var r: Dictionary = w.slots[s]
	var nl: int = r.bs.size()
	var surf := []; var bs := []
	for k in nl: bs.append([])
	for i in n:
		for j in n:
			var X := s.x * 8.0 + 8.0 * i / (n - 1); var Y := s.y * 8.0 + 8.0 * j / (n - 1)
			surf.append(FN.surface_m(wf, s, X, Y))
			for k in nl: bs[k].append(FN.boundary_m(wf, s, k, X, Y))
	return {"slot": [s.x, s.y], "shape": r.bp.shape, "surf": surf, "bs": bs}

func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var n := 25
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fn_n="): n = int(a.substr(7))
	var t0 := Time.get_ticks_usec()
	var w = T.build(p)
	var out := {"n": n, "ids": HR.pool(p).map(func(e): return int(e.id)), "pal": Array(HR.palette()).map(func(c): return c.to_html(false)), "cases": {}}
	for c in CASES:
		out.cases[c] = CASES[c].map(func(s): return block(w, s, n))
	var wk = T.build(p, SC.klin_sequence())
	out.cases["klin"] = [block(wk, Vector2i(0, 5), n), block(wk, Vector2i(1, 5), n)]
	FileAccess.open(ProjectSettings.globalize_path("res://shots/funkce.json"), FileAccess.WRITE).store_string(JSON.stringify(out))
	print("funkce.json: %d případů, %.1f s" % [out.cases.size(), (Time.get_ticks_usec() - t0) / 1e6])
	quit()
