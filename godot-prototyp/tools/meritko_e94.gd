extends SceneTree
## E94: kontrola převodu na scripts/jednotky.gd a měření rychlosti. Vygeneruje 4 startovní bloky (gen bp), postaví sítě
## kostek (Mesher), odkrytí (Discovery) a vegetaci (VegRender) a spočítá otisky výstupů (FNV-1a 64 přes vrcholy,
## buňky, transformace). Otisky se po každém kroku převodu nesmí změnit. Čas = nejlepší z R opakování (ms).
## Volby: --r=N (opakování, výchozí 10), --out=cesta (JSON).
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const Mesher = preload("res://scripts/mesher.gd")
const Discovery = preload("res://scripts/discovery.gd")
const VegRender = preload("res://scripts/veg_render.gd")
const H = preload("res://scripts/stable_hash.gd")
const J = preload("res://scripts/jednotky.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _h_mesh(m: ArrayMesh, h: int) -> int:
	for si in m.get_surface_count():
		var a := m.surface_get_arrays(si)
		h = H.fnv1a64_bytes(PackedFloat32Array(Array(a[Mesh.ARRAY_VERTEX]).map(func(v): return v.x) + Array(a[Mesh.ARRAY_VERTEX]).map(func(v): return v.y) + Array(a[Mesh.ARRAY_VERTEX]).map(func(v): return v.z)).to_byte_array(), h)
		if a[Mesh.ARRAY_COLOR] != null:
			h = H.fnv1a64_bytes(PackedColorArray(a[Mesh.ARRAY_COLOR]).to_byte_array(), h)
	return h

func _h_node(n: Node, h: int) -> int:
	if n is MultiMeshInstance3D:
		var mm: MultiMesh = n.multimesh
		var f := PackedFloat32Array()
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			f.append_array([t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z])
		h = H.fnv1a64_bytes(f.to_byte_array(), h)
	for c in n.get_children(): h = _h_node(c, h)
	return h

func _init() -> void:
	var R := int(_arg("r", "10"))
	BlockGen.gen_version = "bp"
	T.reset()
	var r := {"opakovani": R}
	var blocks := {}
	var t0 := Time.get_ticks_usec()
	for e in "0,0:louka:101;1,0:hora:202;0,1:kopec:303;1,1:louka:404".split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b
	r.gen_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var hc := H.FNV_OFFSET
	for s in blocks: hc = H.fnv1a64_bytes(blocks[s].cells, H.fnv1a64_bytes(blocks[s].hm.to_byte_array(), hc))
	r.otisk_bunky = H.hex(hc)
	# sítě, odkrytí, vegetace: nejlepší čas z R opakování, otisk z posledního
	var best := {"mesh": 1e9, "discovery": 1e9, "veg": 1e9}
	var hm_ := 0; var hd := 0; var hv := 0
	for k in R:
		hm_ = H.FNV_OFFSET; hd = H.FNV_OFFSET; hv = H.FNV_OFFSET
		var tm := 0.0; var td := 0.0; var tv := 0.0
		for s in blocks:
			var b: Block = blocks[s]
			var nbs := []
			var hms := []
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				nbs.append(blocks[s + d].cells if blocks.has(s + d) else null)
				hms.append(blocks[s + d].hm if blocks.has(s + d) else null)
			var a := Time.get_ticks_usec()
			var disc := Discovery.compute(b.cells, nbs, hms, b.hm)
			td += (Time.get_ticks_usec() - a) / 1000.0
			a = Time.get_ticks_usec()
			var m := Mesher.build(b.cells, nbs, -1, Color(1, 1, 1), PackedByteArray(), disc)
			tm += (Time.get_ticks_usec() - a) / 1000.0
			a = Time.get_ticks_usec()
			var vn := VegRender.build(b.veg)
			tv += (Time.get_ticks_usec() - a) / 1000.0
			hm_ = _h_mesh(m, hm_); hd = H.fnv1a64_bytes(disc, hd); hv = _h_node(vn, hv)
			vn.free()
		best.mesh = minf(best.mesh, tm); best.discovery = minf(best.discovery, td); best.veg = minf(best.veg, tv)
	r.cas_ms = best
	r.otisk_site = H.hex(hm_); r.otisk_odkryti = H.hex(hd); r.otisk_vegetace = H.hex(hv)
	# vnitřní smyčka: literál, konstanta z modulu, volání funkce modulu (1 000 000 převodů index → metry)
	var N := 1000000; var acc := 0.0
	var b0 := Time.get_ticks_usec()
	for i in N: acc += float(i & 63) * 0.5
	var t_lit := Time.get_ticks_usec() - b0
	const C := J.U_M
	b0 = Time.get_ticks_usec()
	for i in N: acc += float(i & 63) * C
	var t_const := Time.get_ticks_usec() - b0
	b0 = Time.get_ticks_usec()
	for i in N: acc += float(i & 63) * J.U_M
	var t_jconst := Time.get_ticks_usec() - b0
	b0 = Time.get_ticks_usec()
	for i in N: acc += J.i_m(i & 63, 16)
	var t_fn := Time.get_ticks_usec() - b0
	r.smycka_ns = {"literal": t_lit * 1000.0 / N, "konstanta_lokalni": t_const * 1000.0 / N, "J_konstanta": t_jconst * 1000.0 / N, "J_funkce": t_fn * 1000.0 / N, "_": int(acc) % 7}
	var js := JSON.stringify(r, " ", false)
	print(js)
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(js); f.close()
	quit()
