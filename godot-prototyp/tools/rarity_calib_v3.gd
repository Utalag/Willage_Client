extends SceneTree
## Kalibrace prahů rarity-v2 pro gen-v3 (Jan 20:39, bod 3): stejný vzorek jako tools/rarity_calib.gd (4 recepty × bonus {0, 0,12} × 30 seedů),
## prahy pro gen-v3 tak, aby podíl tříd odpovídal gen proto s dosavadními prahy rarity-v2 (Mat.RARITY_THRESHOLDS_PROTO).
## Spuštění: godot --headless --path . -s res://tools/rarity_calib_v3.gd
const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
func _cls(v: float, th: Array) -> int:
	var r := 0
	for i in th.size():
		if v >= th[i]: r = i
	return r
func _sample(gv: String) -> Array:
	BlockGen.gen_version = gv
	var out := []
	for kind in ["louka", "kopec", "hora", "piscina"]:
		for bonus in [0.0, 0.12]:
			for s in 30:
				var b := Block.new()
				b.kind = kind; b.seed = 5000 + s * 37; b.ore_bonus = bonus
				BlockGen.build(b, [null, null, null, null])
				out.append([kind, bonus, Mat.score_of(b.summary)])
	return out
func _init() -> void:
	var pr := _sample("proto")
	var v3 := _sample("v3")
	var th_old: Array = Mat.RARITY_THRESHOLDS_PROTO
	var cnt := [0, 0, 0, 0, 0]
	for e in pr: cnt[_cls(e[2], th_old)] += 1
	var srt := []
	for e in v3: srt.append(e[2])
	srt.sort()
	var th := [0.0]; var acc := 0
	for c in range(0, 4):
		acc += cnt[c]
		# práh v polovině mezi sousedními skóre (robustnější než přímo hodnota), zaokrouhleno na 0,1
		var lo: float = srt[maxi(acc - 1, 0)]; var hi: float = srt[mini(acc, srt.size() - 1)]
		th.append(snappedf((lo + hi) * 0.5, 0.1) if acc < srt.size() else snappedf(srt[-1] + 1.0, 0.1))
	var c_old := [0, 0, 0, 0, 0]; var c_new := [0, 0, 0, 0, 0]
	for e in v3:
		c_old[_cls(e[2], th_old)] += 1; c_new[_cls(e[2], th)] += 1
	print("proto s prahy ", th_old, ": třídy ", cnt)
	print("v3 skóre min %.2f med %.2f max %.2f; se starými prahy třídy %s" % [srt[0], srt[srt.size() / 2], srt[-1], str(c_old)])
	print("-> prahy v3 ", th, ": třídy ", c_new)
	for kind in ["louka", "kopec", "hora", "piscina"]:
		for bonus in [0.0, 0.12]:
			var a := [0, 0, 0, 0, 0]; var b := [0, 0, 0, 0, 0]
			for i in pr.size():
				if pr[i][0] == kind and pr[i][1] == bonus:
					a[_cls(pr[i][2], th_old)] += 1; b[_cls(v3[i][2], th)] += 1
			print("  %s bonus %.2f: proto %s, v3 %s" % [kind, bonus, str(a), str(b)])
	quit()
