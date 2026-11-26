extends SceneTree
## Svislé řezy před / po (krok 3b). Pro každý řez uloží dvě pole f32 [sloupců × vrstev z]: konečné id materiálu
## a id samotné vrstvy (bez útvarů), pro „před“ (a1 = a10 = vypnuto) i „po“ (zapnuto). Čte je tools/geo_v1b_grafy.py.
## godot --headless --path . -s tools/geo_v1b_rezy.gd -- --sekce=a10:1000,3000,1640,3000,1;a1:1920,2000,2048,2000,0.5 --z=0.5 --data=/tmp/k3b
const S = preload("res://scripts/v1/svet_fn.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _uloz(cesta: String, a: PackedFloat32Array) -> void:
	var f := FileAccess.open(cesta, FileAccess.WRITE)
	f.store_buffer(a.to_byte_array())

func _par(zaklad: Dictionary, s: String) -> Dictionary:
	var p := zaklad.duplicate()
	for e in s.split(",", false):
		var kv := e.split(":")
		var v := kv[1] != "0"
		match kv[0]:
			"a1": p["a1_hostitele"] = v
			"a10": p["a10_sum_hornin"] = v
			"dom": p["dom_pasmo_sedimenty"] = v
	return p

func _init() -> void:
	var dat := _arg("data", "/tmp/k3b")
	DirAccess.make_dir_recursive_absolute(dat)
	var kz := float(_arg("z", "0.5"))
	var meta := {}
	var par0 := {"seed": int(_arg("seed", "49"))}
	var sv := {
		"pred": S.new(_par(par0, _arg("pred", "a1:0,a10:0,dom:0"))),
		"po": S.new(_par(par0, _arg("po", "a1:1,a10:1,dom:1"))),
	}
	for sek in _arg("sekce", "").split(";", false):
		var q := sek.split(":")
		var c := q[1].split(",")
		var x0 := float(c[0]); var y0 := float(c[1]); var x1 := float(c[2]); var y1 := float(c[3]); var krok := float(c[4])
		var delka := Vector2(x1 - x0, y1 - y0).length()
		var n := int(delka / krok)
		var zmax := float(_arg("zmax", "64"))
		var nz := int(zmax / kz)
		for kl in sv:
			var svet = sv[kl]
			var fin := PackedFloat32Array(); fin.resize(n * nz)
			var lay := PackedFloat32Array(); lay.resize(n * nz)
			var zp := PackedFloat32Array(); zp.resize(n)
			for i in n:
				var t := (i + 0.5) / float(n)
				var x := lerpf(x0, x1, t); var y := lerpf(y0, y1, t)
				var w: PackedFloat64Array = svet.vahy(x, y)
				var z_pov: float = float(svet.vyska_w(x, y, w, true))
				zp[i] = z_pov
				var hr: Array = svet.geo.hranice(x, y, w)
				var feats: Array = svet.geo.utv.features_u(x, y)
				for iz in nz:
					var z := (iz + 0.5) * kz
					var id := 0; var vm := 0
					if z <= z_pov:
						var sm: int = svet.geo.sopka_mat(x, y, z)
						vm = svet.geo.vrstva_mat(x, y, z, hr)
						id = sm if sm >= 0 else vm
						if sm < 0:
							var um: int = int(svet.geo.utv.mat_feats(feats, x, y, z, vm, z_pov, hr))
							if um >= 0: id = um
					fin[i * nz + iz] = id
					lay[i * nz + iz] = vm if z <= z_pov else 0
			_uloz("%s/%s_%s_id.f32" % [dat, q[0], kl], fin)
			_uloz("%s/%s_%s_vrstva.f32" % [dat, q[0], kl], lay)
			_uloz("%s/%s_%s_povrch.f32" % [dat, q[0], kl], zp)
		meta[q[0]] = {"n": n, "nz": nz, "krok_m": krok, "krok_z": kz, "x0": x0, "y0": y0, "x1": x1, "y1": y1}
	var f := FileAccess.open(dat + "/rezy_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, " "))
	quit()
