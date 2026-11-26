extends SceneTree
## Krok 5: čas GDScript geologie pro srovnání s C# (Willage.Gen.Nastroje `cas`).
## Segment 8 m (32 × 32 sloupců po 0,25 m, 512 buněk) na 4 místech; výpis ms + otisk (SHA-256 bajtů, 16 hex).
const SF = preload("res://scripts/v1/svet_fn.gd")
func _init() -> void:
	var t0 := Time.get_ticks_usec()
	var s = SF.new({})
	print("init_ms ", (Time.get_ticks_usec() - t0) / 1000.0)
	for o in [[1792.0, 1792.0], [1856.0, 1920.0], [2000.0, 1800.0], [2104.0, 2104.0]]:
		var t := Time.get_ticks_usec()
		var buf := PackedByteArray()
		for ix in 32:
			for iy in 32:
				buf.append_array(s.geo.vypln_sloupec(o[0] + (ix + 0.5) * 0.25, o[1] + (iy + 0.5) * 0.25, 0.25, 128.0))
		var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256); hc.update(buf)
		print("segment %d,%d ms %.0f otisk %s" % [o[0], o[1], (Time.get_ticks_usec() - t) / 1000.0, hc.finish().hex_encode().substr(0, 16)])
	quit()
