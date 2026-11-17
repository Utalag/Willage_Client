extends SceneTree
## Kalibrace prahů rarity-v2 (vážený průměr): prahy tak, aby podíl tříd odpovídal rarity-v1 na stejném vzorku.
const Mat = preload("res://scripts/mat.gd")
const Veg = preload("res://scripts/veg.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
func _cls(v: float, th: Array) -> int:
	var r := 0
	for i in th.size():
		if v >= th[i]: r = i
	return r
func _init() -> void:
	var m1: Array = []; var m2: Array = []; var v1: Array = []; var v2: Array = []
	for kind in ["louka", "kopec", "hora", "piscina"]:
		for bonus in [0.0, 0.12]:
			for s in 30:
				var b := Block.new()
				b.kind = kind; b.seed = 5000 + s * 37; b.ore_bonus = bonus
				BlockGen.build(b, [null, null, null, null])
				m1.append(Mat.score_of_v1(b.summary)); m2.append(Mat.score_of(b.summary))
				v1.append(Veg.mean_score_v1(b.veg_summary)); v2.append(Veg.mean_score(b.veg_summary))
	for pair in [["MAT", m1, m2, Mat.RARITY_THRESHOLDS_V1], ["VEG", v1, v2, [0.0, 1.8, 2.1, 2.5, 2.9]]]:
		var a: Array = pair[1]; var b2: Array = pair[2]; var th: Array = pair[3]
		var cnt := [0, 0, 0, 0, 0]
		for x in a: cnt[_cls(x, th)] += 1
		var srt := b2.duplicate(); srt.sort()
		var out := [0.0]; var acc := 0
		for c in range(0, 4):
			acc += cnt[c]
			out.append(srt[mini(acc, srt.size() - 1)] if acc < srt.size() else srt[-1] + 1.0)
		print(pair[0], " v1 třídy ", cnt, " v2 min %.2f med %.2f max %.2f" % [srt[0], srt[srt.size() / 2], srt[-1]], " -> prahy v2 ", out)
	quit()
