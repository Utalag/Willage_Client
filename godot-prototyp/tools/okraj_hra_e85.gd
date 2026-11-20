extends SceneTree
## E85: herní kopání po 0,5 m (digging.gd) s p85_okraj: šachta na dno, obvodový sloupec, sloupec u vnitřního švu.
## Spuštění: godot --headless --path . -s tools/okraj_hra_e85.gd -- [--out=cesta]
const TerenBP = preload("res://scripts/teren/ostrov_teren.gd")

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="): return a.substr(k.length() + 3)
	return d

func dig_down(dg, island, g: Vector2i) -> Dictionary:
	var sl := Vector2i(floori(g.x / 16.0), floori(g.y / 16.0))
	var b = island.blocks[sl]; var ci: int = (g.x - sl.x * 16) * 16 + (g.y - sl.y * 16)
	var h0: int = b.hm[ci]; var n := 0; var last := ""
	for i in 80:
		var r: String = dg.dig(g)
		var h: int = b.hm[ci]
		if h == h0 - n: last = r; break
		n = h0 - h; last = r
		if h <= 0: break
	return {"sloupec": [g.x, g.y], "h0": h0, "h": int(b.hm[ci]), "vykopano_bunek": h0 - int(b.hm[ci]), "posledni": last}

func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var island = main.get_node("Island"); var dg = main.get_node("Digging")
	var keys: Array = island.blocks.keys(); keys.sort()
	var out := {"bloky": keys.map(func(k): return [k.x, k.y])}
	for on in [false, true]:
		TerenBP.p["p85_okraj"] = on
		var r := {}
		# blok s pravým sousedem a bez levého souseda
		var sl: Vector2i = Vector2i.ZERO
		for k in keys:
			if island.blocks.has(k + Vector2i(1, 0)) and not island.blocks.has(k + Vector2i(-1, 0)): sl = k; break
		var o := sl * 16
		var dy := 3 if on else 11
		r.blok = [sl.x, sl.y]
		r.sachta_stred = dig_down(dg, island, o + Vector2i(8, dy))
		r.obvod_x0 = dig_down(dg, island, o + Vector2i(0, dy))
		r.vnitrni_sev_x15 = dig_down(dg, island, o + Vector2i(15, dy))
		out["zapnuto" if on else "vypnuto"] = r
		print("hra okraj %s: %s" % ["zapnuto" if on else "vypnuto", JSON.stringify(r)])
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
