extends SceneTree
## E88: velikost uložení jednoho bloku (louka 404, kopec 303, hora 808, písčina 606, bez sousedů): řídicí mřížka hm_f + 20 hranic vrstev
## jako f64 / f32 / pevná čárka 1/256 U (3 B) syrově a deflate, buňky 0,5 m (geo) syrově a deflate. Jen měření, nic nemění.
## Spuštění: cd godot-prototyp && godot --headless --path . -s res://../blueprint-studie/shots/e88/velikosti_e88.gd
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
func dfl(a: PackedByteArray) -> int: return a.compress(FileAccess.COMPRESSION_DEFLATE).size()
func _init():
	var out := []
	for spec in [["louka", 404, Vector2i(0,0)], ["kopec", 303, Vector2i(1,0)], ["hora", 808, Vector2i(0,1)], ["piscina", 606, Vector2i(1,1)]]:
		var b := Block.new(); b.kind = spec[0]; b.seed = spec[1]; b.slot = spec[2]
		BlockGen.build(b, [null, null, null, null]); T.commit(b)
		var r: Dictionary = b.bp_rec
		var f64 := PackedFloat64Array(); var f32 := PackedFloat32Array(); var q := PackedByteArray()
		var arrs := [r.hm_f] + Array(r.bs)
		var maxerr := 0.0
		for a in arrs:
			for v in a:
				f64.append(float(v)); f32.append(float(v))
				var qi := int(round(float(v) * 256.0)); maxerr = maxf(maxerr, absf(qi / 256.0 - float(v)))
				q.append(qi & 0xff); q.append((qi >> 8) & 0xff); q.append((qi >> 16) & 0xff)
		var g: PackedByteArray = b.geo
		out.append({"typ": b.kind, "vrstev": r.bs.size(), "hodnot": f64.size(), "f64": [f64.size()*8, dfl(f64.to_byte_array())], "f32": [f32.size()*4, dfl(f32.to_byte_array())], "fix24_1_256U": [q.size(), dfl(q), maxerr], "geo": [g.size(), dfl(g)], "gen_ms": b.gen_ms})
	print(JSON.stringify(out))
	quit()
