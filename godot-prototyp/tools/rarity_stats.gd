extends SceneTree
## Statistika skóre rarity přes typy a seedy (kalibrace prahů). Spuštění: godot --headless --path . -s res://tools/rarity_stats.gd
const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
func _init() -> void:
	for kind in ["louka", "kopec", "hora", "piscina"]:
		for bonus in [0.0, 0.12]:
			var sc: Array[float] = []
			var t := 0.0
			for s in 30:
				var b := Block.new()
				b.kind = kind; b.seed = 5000 + s * 37; b.ore_bonus = bonus
				BlockGen.build(b, [null, null, null, null])
				sc.append(Mat.score_of(b.summary)); t += b.gen_ms
			sc.sort()
			print("%s bonus %.2f: min %.2f med %.2f max %.2f  (gen %.1f ms/blok)" % [kind, bonus, sc[0], sc[15], sc[29], t / 30])
	quit()
