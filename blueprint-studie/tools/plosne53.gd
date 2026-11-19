extends SceneTree
## E53: ./run.sh plosne53 [--p53_n=64 ...] → shots/test_plosne53.txt, shots/bench_plosne53.json
const P = preload("res://scripts/bp/params.gd")
const B = preload("res://scripts/plosne53/beh53.gd")
func _init() -> void:
	var p: Dictionary = P.apply_args(P.defaults(), OS.get_cmdline_user_args())
	var t := B.tests(p)
	for l in t: print(l)
	var f := FileAccess.open("res://shots/test_plosne53.txt", FileAccess.WRITE); f.store_string("\n".join(t) + "\n"); f.close()
	if String(p.get("p53_jen", "")) != "testy":  # --p53_jen=testy jen testy
		var r := B.bench(p)
		print(JSON.stringify(r))
		var g := FileAccess.open("res://shots/bench_plosne53_n%d.json" % int(p.p53_n), FileAccess.WRITE); g.store_string(JSON.stringify(r, "  ")); g.close()
	quit()
