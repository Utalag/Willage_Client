extends SceneTree
## ./run.sh svah56 [--s56_max_slope=1.0 --s56_paty=0.2 ...] → shots/bench_svah56.txt, shots/svah56.json (pro tools/shots_svah56.py)
const PR = preload("res://scripts/bp/params.gd")
const S = preload("res://scripts/svah56/beh56.gd")
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	var r := S.run_all(p)
	var L: PackedStringArray = r.L
	L.insert(0, "# E56 mírnější přechody (%s): s56_max_slope %.2f, pasy %d, hladit %d × %.2f, paty %.2f, hreben %.1f" % [Time.get_datetime_string_from_system(),
		float(p.s56_max_slope), int(p.s56_pasy), int(p.s56_hladit), float(p.s56_hladit_w), float(p.s56_paty), float(p.s56_hreben)])
	print("\n".join(L))
	FileAccess.open(ProjectSettings.globalize_path("res://shots/bench_svah56.txt"), FileAccess.WRITE).store_string("\n".join(L) + "\n")
	r.erase("L")
	FileAccess.open(ProjectSettings.globalize_path("res://shots/svah56.json"), FileAccess.WRITE).store_string(JSON.stringify(r))
	quit()
