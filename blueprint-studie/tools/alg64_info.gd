extends SceneTree
## E64 V: rozbor sloupcových řetězců (kandidáti vertikální komprese) a symetrie CSR. Jen čte, nic nezapisuje mimo shots/e64.
const C = preload("res://scripts/podzemi52/cache.gd")
const F = preload("res://scripts/podzemi52/ug_funkce.gd")
const V = preload("res://scripts/svet64/voda64.gd")
const PR = preload("res://scripts/bp/params.gd")
const E := 1e-6
func _init() -> void:
	var p := PR.apply_args(PR.defaults(), OS.get_cmdline_user_args())
	p.p52_rezim = "auto"
	var nv := int(p.s64_voda_n); var nu := int(p.p52_ug_n)
	var d := C.load_data(ProjectSettings.globalize_path(String(p.p52_cache)))
	var Gs := V.grid(d.blocks, d.T, d.n, nv, false)
	var t0 := Time.get_ticks_msec()
	var c := F.from_world(C.world_of(d), d.blocks, d.n, nu, p)
	F.set_surface(c, Gs.W, Gs.hm, Gs.wall, 8.0 / nv)
	print("stavba ", Time.get_ticks_msec() - t0, " ms")
	var n: int = c.lo.size(); var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol; var body: PackedByteArray = c.body
	# reverzní CSR
	var indeg := PackedInt32Array(); indeg.resize(n)
	for j in nb.size(): indeg[nb[j]] += 1
	var asym := 0
	var nbody := 0; var chain := 0; var lat0 := 0
	for b in n:
		if body[b] == 0: continue
		nbody += 1
		var lat := 0; var up := 0; var dn := 0
		for j in range(ns[b], ns[b + 1]):
			var b2 := nb[j]
			var ok := false
			for j2 in range(ns[b2], ns[b2 + 1]):
				if nb[j2] == b: ok = true; break
			if not ok: asym += 1
			if body[b2] == 0: continue
			if bcol[b2] != bcol[b]:
				if minf(hi[b], hi[b2]) > maxf(lo[b], lo[b2]) + E: lat += 1
			elif hi[b2] <= lo[b] + E: dn += 1
			else: up += 1
		if lat == 0: lat0 += 1
		if lat == 0 and up <= 1 and dn <= 1 and indeg[b] == ns[b + 1] - ns[b]: chain += 1
	print("pásem %d, těleso %d, hran %d, asymetrických %d, bez bočních sousedů %d, vnitřní články řetězce %d (%.2f %%)" % [n, nbody, nb.size(), asym, lat0, chain, 100.0 * chain / maxf(nbody, 1)])
	quit()
