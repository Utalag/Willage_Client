extends RefCounted
## E95: E90 LOD krajina pod ostrovem jako náhled pásem (funkce světa E49, ne geologie ostrova).
## Svět 4 × 4 dlaždice po 128 m, „hráč“ = střed světa pod středem ostrova. Uzel je dítětem ostrova se scale (2, 1, 2)
## (buňka scény 1 × 0,5 = 0,5 m), takže s E89 (ostrov × 0,5 vodorovně) je krajina v metrech 1 : 1.
const L = preload("res://scripts/teren/lod90.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")

static func build(island: Node3D, prm: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var p: Dictionary = L.P.duplicate()
	p.p90_lod = true
	p.p90_dlazdic = 4
	for k in ["p90_okoli", "p90_slupka", "p90_daleko_m"]:
		if prm.has(k): p[k] = prm[k]
	T.ensure()
	var f := L.fn(p, T.p)
	var hrac := Vector2(256.0 + 8.0, 256.0 + 8.0)
	var pl := L.plan(p, [hrac])
	var V := PackedVector3Array(); var N := PackedVector3Array(); var C := PackedColorArray()
	var tri := 0
	for a in pl.plochy:
		var st := L.stavba(f, pl, p, a, true, bool(prm.get("p90_barvy", true)))
		V.append_array(st.V); N.append_array(st.N); C.append_array(st.C)
		tri += int(st.tri)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_COLOR] = C
	var m := ArrayMesh.new()
	if V.size() > 0: m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "LOD90_okoli"
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mi.material_override = mat
	mi.scale = Vector3(2.0, 1.0, 2.0)
	# střed ostrova (buňky) nad hráčem; povrch funkce pod hráčem 12 jednotek pod dnem ostrova
	var c: Vector2 = island.CENTER * 16.0
	var h := L.h_m(f, hrac.x, hrac.y)
	mi.position = Vector3(c.x - hrac.x * 2.0, -12.0 - h, c.y - hrac.y * 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(mi)
	return {"uzel": mi, "trojuhelniku": tri, "ploch": pl.plochy.size(), "ms": (Time.get_ticks_usec() - t0) / 1000.0}
