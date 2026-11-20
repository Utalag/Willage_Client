extends RefCounted
## E66: síť vody ostrova z výsledku ostrov_voda.gd (jen vzhled). Tůně = hladina fill, koryto = tenká vrstva nad povrchem
## (šířka podle průtoku), vodopády = svislé pásy z horního do dolního sloupce; přes okraj ostrova pás do mlhy (dolů o
## mlha_m pod dno bloku) a pod ním obláček mlhy. Souřadnice = souřadnice ostrova (slot ostrova × 16 + sloupec, výška × 0,5 m).

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const CELL_H := J.CELL_M
const BS := J.BS
const TT = preload("res://scripts/teren/ostrov_teren.gd")

static func mats() -> Dictionary:
	var w := StandardMaterial3D.new()
	w.albedo_color = Color(0.30, 0.58, 0.92, 0.72)
	w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w.roughness = 0.15
	w.cull_mode = BaseMaterial3D.CULL_DISABLED
	var f := StandardMaterial3D.new()
	f.albedo_color = Color(0.85, 0.93, 1.0, 0.8)
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {"voda": w, "vodopad": f, "mlha": m}

static func _pos(v, gi: int) -> Vector2:
	var H: int = v.H
	var gx := gi / H; var gy := gi % H
	var o: Vector2i = TT.OFF * BS
	return Vector2(gx - o.x, gy - o.y)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for q in [a, b, c, a, c, d]: st.add_vertex(q)

## vrací {voda, vodopad, mlha} → ArrayMesh; slice_z ≥ 0 = řez (voda nad řezem se nekreslí)
static func build(v, slice_z := -1, mlha_m := 6.0) -> Dictionary:
	var sw := SurfaceTool.new(); sw.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sm := SurfaceTool.new(); sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nw := 0; var nf := 0; var nm := 0
	if not v.st.is_empty():
		var thr: float = v.st.L.thr
		for i in v.W * v.H:
			if v.island[i] == 0: continue
			var lv: float = v.level(i)
			if lv < 0.0: continue
			if slice_z >= 0 and lv > slice_z: continue
			var p := _pos(v, i)
			var y := lv * CELL_H
			var r := 0.5
			if not v.is_pond(i):   # koryto: šířka podle průtoku (√q), nejméně 0,3 sloupce
				r = clampf(0.15 + 0.12 * sqrt(v.st.eff[i] / maxf(thr, 1e-6)), 0.15, 0.5)
			_quad(sw, Vector3(p.x + 0.5 - r, y, p.y + 0.5 - r), Vector3(p.x + 0.5 + r, y, p.y + 0.5 - r), Vector3(p.x + 0.5 + r, y, p.y + 0.5 + r), Vector3(p.x + 0.5 - r, y, p.y + 0.5 + r))
			nw += 1
		for f in v.falls:
			if slice_z >= 0 and v.st.hm[f.top] > slice_z: continue   # řez: vodopád nad řezem se nekreslí
			var a := _pos(v, f.top); var b := _pos(v, f.bot)
			var y0: float = v.st.hm[f.top] * CELL_H
			var y1: float = (-mlha_m) if f.edge else v.st.hm[f.bot] * CELL_H
			var c := (a + b) * 0.5 + Vector2(0.5, 0.5)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x) * 0.35
			_quad(sf, Vector3(c.x - n.x, y0, c.y - n.y), Vector3(c.x + n.x, y0, c.y + n.y), Vector3(c.x + n.x, y1, c.y + n.y), Vector3(c.x - n.x, y1, c.y - n.y))
			nf += 1
			if f.edge:   # obláček mlhy pod vodopádem
				for k in 3:
					var s := 0.8 + 0.5 * k; var yy := y1 + 0.6 * k
					_quad(sm, Vector3(c.x - s, yy, c.y - s), Vector3(c.x + s, yy, c.y - s), Vector3(c.x + s, yy, c.y + s), Vector3(c.x - s, yy, c.y + s))
					nm += 1
		# E67: vývěry podzemní vody ve stěně ostrova (výstup „okraj“) = vodopád ze stěny do mlhy; slabší než
		# p67_min_vytok_render se nekreslí (voda v simulaci zůstává, jen se nezobrazí)
		var vmin := float(TT.p.get("p67_min_vytok_render", 0.0))
		for u in v.st.get("under", []):
			if String(u.typ) != "okraj" or float(u.q) < vmin: continue
			var gi: int = u.exit
			var y0 := float(u.z)
			if slice_z >= 0 and y0 / CELL_H > slice_z: continue
			var p := _pos(v, gi)
			var od := Vector2.ZERO
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var j: int = gi + dd.x * v.H + dd.y
				if j >= 0 and j < v.W * v.H and v.island[j] == 0: od = Vector2(dd); break
			var c := p + Vector2(0.5, 0.5) + od * 0.52
			var n := Vector2(-od.y, od.x) * clampf(0.08 + 0.6 * sqrt(float(u.q)), 0.08, 0.4)
			_quad(sf, Vector3(c.x - n.x, y0, c.y - n.y), Vector3(c.x + n.x, y0, c.y + n.y), Vector3(c.x + n.x, -mlha_m, c.y + n.y), Vector3(c.x - n.x, -mlha_m, c.y - n.y))
			nf += 1
			var s := 0.8
			_quad(sm, Vector3(c.x - s, -mlha_m, c.y - s), Vector3(c.x + s, -mlha_m, c.y - s), Vector3(c.x + s, -mlha_m, c.y + s), Vector3(c.x - s, -mlha_m, c.y + s))
			nm += 1
	var out := {"n_voda": nw, "n_vodopad": nf, "n_mlha": nm}
	for e in [["voda", sw, nw], ["vodopad", sf, nf], ["mlha", sm, nm]]:
		if e[2] > 0:
			e[1].generate_normals()
			out[e[0]] = e[1].commit()
		else: out[e[0]] = ArrayMesh.new()
	return out
