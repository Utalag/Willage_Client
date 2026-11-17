extends SceneTree
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const Veg = preload("res://scripts/veg.gd")
func _init() -> void:
	for kind in ["louka", "kopec", "hora", "piscina"]:
		var sc: Array[float] = []
		var t := 0.0
		for s in 20:
			var b := Block.new()
			b.kind = kind; b.seed = 7000 + s * 41
			BlockGen.build(b, [null, null, null, null])
			sc.append(Veg.mean_score(b.veg_summary)); t += b.gen_ms
		sc.sort()
		print("%s: skóre vegetace min %.2f med %.2f max %.2f, gen %.1f ms" % [kind, sc[0], sc[10], sc[19], t / 20])
	quit()
