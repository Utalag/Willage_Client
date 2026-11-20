extends SceneTree
## E94: dopad jednoho tvaru l → m³ (voda/litry.gd). Postaví vodu startovního ostrova (jako voda_e66) a vypíše plnou
## přesností časy naplnění tůní (hydro68.udalosti) a události podzemních těles; spustit na commitu před a po sjednocení
## a porovnat (--out=cesta, JSON se seznamy čísel jako text %.17g).
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const H68 = preload("res://scripts/voda/hydro68.gd")
const H = preload("res://scripts/stable_hash.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _flat(x, out: PackedStringArray, key := "") -> void:
	if x is Dictionary:
		var ks: Array = x.keys(); ks.sort()
		for k in ks: _flat(x[k], out, key + "/" + str(k))
	elif x is Array:
		for i in x.size(): _flat(x[i], out, key + "[%d]" % i)
	elif x is float:
		out.append("%s=%s" % [key, String.num_scientific(x)])
	elif x is int or x is bool or x is String:
		out.append("%s=%s" % [key, str(x)])

func _init() -> void:
	BlockGen.gen_version = "bp"
	T.reset()
	var blocks := {}
	for e in "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404".split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	var v := OV.new(); v.build(blocks)
	var out := PackedStringArray()
	_flat(H68.udalosti(v.st), out, "tune")
	for k in ["ug", "ug_res", "telesa", "podzemi"]:
		if v.get(k) != null: _flat(v.get(k), out, k)
	var r := {"radku": out.size(), "otisk_textu": H.hex(H.fnv1a64("\n".join(out))), "radky": out}
	var f := FileAccess.open(_arg("out", "/tmp/litry.json"), FileAccess.WRITE); f.store_string(JSON.stringify(r, " ")); f.close()
	print("radku ", out.size(), " otisk ", r.otisk_textu)
	quit()
