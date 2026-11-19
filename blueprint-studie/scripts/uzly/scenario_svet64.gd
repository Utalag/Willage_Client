extends Node
## Uzel ScenarioSvet64 (E50, --svet64): izo snímek světa 8 × 8 bloků v jemných buňkách (64 × 64 × 256 na blok).
## Negeneruje znovu: načte shots/svet64/ (tools/test_svet64.gd), takže render se měří odděleně od generování.
## Povrch = výšková síť ze spojitého povrchu (barva = vrch materiálu), voda z vodní mřížky, řezy na dvou okrajích ostrova
## (+x a +y) ukazují vrstvy v buňkách. Výstup shots/50_svet64_iso.png, čas do shots/bench_svet64_render.txt.

const HR = preload("res://scripts/bp/horniny.gd")

@export var views: NodePath
@export var ui: NodePath
@export var rig: NodePath
@export var legend: NodePath
@export var water_col := Color(0.22, 0.48, 0.93)
@export var spring_col := Color(1, 1, 1)
@export var under_col := Color(0.1, 0.9, 0.9)

var D := ""

func _rd(name: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(D + "/" + name)

## koryto je 1 sloupec široké → pro čitelnost obarvit i 4-sousedy
func _near(wat: PackedByteArray, Wv: int, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var qx: int = x + d.x; var qy: int = y + d.y
		if qx >= 0 and qy >= 0 and qx < Wv and qy < Wv and (wat[qx * Wv + qy] == 1 or wat[qx * Wv + qy] == 4): return true
	return false

func run() -> void:
	var t0 := Time.get_ticks_usec()
	D = ProjectSettings.globalize_path("res://shots/svet64")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(D + "/meta.json"))
	var S := int(meta.S); var NZ := int(meta.NZ); var Wv := int(meta.Wv); var c := float(meta.cell_m)
	var k := S / Wv
	var pal: Array = HR.palette()
	var hf := _rd("hf.f32").to_float32_array(); var top := _rd("top.u8")
	var wat := _rd("wat.u8"); var post := _rd("post.f32").to_float32_array(); var fill := _rd("fill.f32").to_float32_array()
	var cut := [_rd("cutx.u8"), _rd("cuty.u8")]
	var t_load := (Time.get_ticks_usec() - t0) / 1000.0
	var t1 := Time.get_ticks_usec()
	# výšková síť: vrchol v každém sloupci, výška = povrch po strži (vodní mřížka) nebo hladina tůně
	var V := PackedVector3Array(); V.resize(S * S)
	var C := PackedColorArray(); C.resize(S * S)
	for x in S:
		for y in S:
			var i := x * S + y; var wi := (x / k) * Wv + y / k
			var h: float = post[wi] * k if Wv > 0 else hf[i]
			var w := wat[wi]
			var col: Color = pal[top[i]] if top[i] < pal.size() else Color.GRAY
			if w == 2: h = maxf(h, fill[wi] * k); col = water_col.darkened(0.1)
			elif w == 1 or w == 4 or _near(wat, Wv, x / k, y / k): col = col.lerp(water_col, 0.8)
			elif w == 3: col = spring_col
			elif w == 5: col = under_col
			V[i] = Vector3((x + 0.5) * c, h * c, (y + 0.5) * c); C[i] = col
	var N := PackedVector3Array(); N.resize(S * S)
	for x in S:
		for y in S:
			var a := V[mini(x + 1, S - 1) * S + y] - V[maxi(x - 1, 0) * S + y]
			var b := V[x * S + mini(y + 1, S - 1)] - V[x * S + maxi(y - 1, 0)]
			N[x * S + y] = b.cross(a).normalized()
	var I := PackedInt32Array(); I.resize((S - 1) * (S - 1) * 6)
	var q := 0
	for x in S - 1:
		for y in S - 1:
			var i := x * S + y
			I[q] = i; I[q + 1] = i + S; I[q + 2] = i + 1; I[q + 3] = i + 1; I[q + 4] = i + S; I[q + 5] = i + S + 1; q += 6
	var mesh := ArrayMesh.new()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_COLOR] = C; arr[Mesh.ARRAY_INDEX] = I
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# řezy: svislé pásy stejného materiálu ve sloupci na okraji x = S (cut 0) a y = S (cut 1)
	var cv := PackedVector3Array(); var cc := PackedColorArray(); var cn := PackedVector3Array()
	for side in 2:
		var cells: PackedByteArray = cut[side]
		var nrm := Vector3(1, 0, 0) if side == 0 else Vector3(0, 0, 1)
		for t in S:
			var z0 := 0
			for z in NZ + 1:
				var m: int = cells[t * NZ + z] if z < NZ else -1
				if z < NZ and m == cells[t * NZ + z0]: continue
				var m0: int = cells[t * NZ + z0]
				if m0 != 0:
					var col: Color = (pal[m0] if m0 < pal.size() else Color.GRAY).darkened(0.12)
					var a0: Vector3; var a1: Vector3
					if side == 0: a0 = Vector3(S * c, 0, t * c); a1 = Vector3(S * c, 0, (t + 1) * c)
					else: a0 = Vector3(t * c, 0, S * c); a1 = Vector3((t + 1) * c, 0, S * c)
					var lo := Vector3(0, z0 * c, 0); var hi := Vector3(0, z * c, 0)
					for v in [a0 + lo, a1 + lo, a1 + hi, a0 + lo, a1 + hi, a0 + hi]: cv.append(v); cc.append(col); cn.append(nrm)
				z0 = z
	var arr2 := []; arr2.resize(Mesh.ARRAY_MAX)
	arr2[Mesh.ARRAY_VERTEX] = cv; arr2[Mesh.ARRAY_COLOR] = cc; arr2[Mesh.ARRAY_NORMAL] = cn
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat); mesh.surface_set_material(1, mat)
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	var Vn = get_node(views); Vn.clear(); Vn.add_child(mi)
	var t_mesh := (Time.get_ticks_usec() - t1) / 1000.0
	get_node(legend).clear(); get_node(ui).say(""); get_node(ui).get_node("Hud").visible = false
	var L := S * c
	get_node(rig).frame(Vector3(L * 0.5, 6.0, L * 0.5), L * 1.25)
	var t2 := Time.get_ticks_usec()
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/50_svet64_iso.png"))
	var t_draw := (Time.get_ticks_usec() - t2) / 1000.0
	var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/bench_svet64_render.txt"), FileAccess.READ_WRITE if FileAccess.file_exists("res://shots/bench_svet64_render.txt") else FileAccess.WRITE)
	f.seek_end()
	f.store_line("render izo (Godot, OpenGL na xvfb): načtení %.0f ms, síť %d + řezy %d trojúhelníků %.0f ms, vykreslení + uložení %.0f ms, celkem %.0f ms" % [
		t_load, I.size() / 3, cv.size() / 3, t_mesh, t_draw, (Time.get_ticks_usec() - t0) / 1000.0])
	print("shot svet64 iso")
