extends SceneTree
## E90: test LOD 3 × 3 km (scripts/teren/lod90.gd). Bez --p90_lod=1 nic nestaví.
## Volby: --p90_lod=1 --out=cesta.json --shots=adresář (snímky přes xvfb, bez --headless) --hraci=x,y;x,y…
## Měří: shodu funkce s E49 hruby_teren, čas (funkce / síť / ArrayMesh) po úrovních, trojúhelníky, paměť (výšky, slupka,
## síť, RSS), díry na švech bez sešití a se sešitím, skok výšky přes hranici, přestavbu po kroku hráče o 16 m, odhad 1 m všude.
const L = preload("res://scripts/teren/lod90.gd")
const HT = preload("res://scripts/teren/svet/hruby_teren.gd")
const M = preload("res://scripts/teren/svet64/mereni.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

var p := {}
var f := {}
var r := {}

func _init() -> void:
	p = L.P.duplicate()
	for k in p:
		var v := _arg(k, "")
		if v != "": p[k] = (v == "1" or v == "true") if typeof(p[k]) == TYPE_BOOL else (int(v) if typeof(p[k]) == TYPE_INT else float(v))
	if not bool(p.p90_lod):
		print("E90: p90_lod vypnutý (výchozí), nic se nestaví. Zapni --p90_lod=1."); quit(); return
	_run.call_deferred()

func _run() -> void:
	T.reset()
	var tp: Dictionary = T.p
	f = L.fn(p, tp)
	r.parametry = p.duplicate()
	# 1) funkce = E49 hruby_teren (body 1 m, mapa 64 × 64, mimo sopku)
	var q := tp.duplicate(); q.s8_volcano = 0
	var e49: Dictionary = HT.run(int(p.p90_seed), q)
	var R := int(q.s8_tiles) * int(q.s8_px); var diff := 0; var mx := 0.0
	for x in R:
		for y in R:
			var d := absf(float(e49.hm[x * R + y]) - L.h49(f, x, y))
			mx = maxf(mx, d)
			if d > 0.0: diff += 1
	r.shoda_e49 = {"bodu": R * R, "jinak": diff, "max_bunky": mx}
	# 2) plán a stavba se sešitím
	var hraci := []
	for e in _arg("hraci", "700,700;760,730;2200,900;1500,2400").split(";"):
		var a := e.split(","); hraci.append(Vector2(float(a[0]), float(a[1])))
	r.hraci = hraci.map(func(v): return [v.x, v.y])
	var m0 := M.mem()
	var t0 := Time.get_ticks_usec()
	var pl := L.plan(p, hraci)
	var ms_plan := M.ms(t0)
	var po := {}   # úroveň → součty
	for l in 4: po[l] = {"ploch": 0, "sloupcu": 0, "tri": 0, "vrcholu": 0, "ms_fn": 0.0, "ms_sit": 0.0, "ms_mesh": 0.0, "B_vysky": 0, "B_slupka": 0, "B_sit": 0, "max_odchylka_m": 0.0}
	var meshes := {}
	t0 = Time.get_ticks_usec()
	for a in pl.plochy:
		var st := L.stavba(f, pl, p, a, true)
		var t1 := Time.get_ticks_usec()
		meshes[a.klic] = L.mesh(st)
		var s: Dictionary = po[int(a.lvl)]
		s.ploch += 1; s.sloupcu += st.n * st.n; s.tri += st.tri; s.vrcholu += st.V.size()
		s.ms_fn += st.ms_fn; s.ms_sit += st.ms_sit; s.ms_mesh += M.ms(t1)
		s.B_vysky += st.vrsky.size() * 4; s.B_slupka += st.slupka.size(); s.B_sit += st.V.size() * (12 + 12 + 16)
	var ms_all := M.ms(t0)
	var m1 := M.mem()
	# odchylka vršku od funkce (vzorek ploch) ≤ vq
	for a in pl.plochy.slice(0, 400) + pl.plochy.slice(pl.plochy.size() - 50):
		var c: float = a.c
		for k in 16:
			var x: float = a.o.x + (k + 0.5) * a.s / 16.0; var y: float = a.o.y + (15 - k + 0.5) * a.s / 16.0
			var cx := (floorf(x / c) + 0.5) * c; var cy := (floorf(y / c) + 0.5) * c
			po[int(a.lvl)].max_odchylka_m = maxf(po[int(a.lvl)].max_odchylka_m, L.h_m(f, cx, cy) - L.vrsek(f, c, a.vq, x, y))
	r.uroven = {}
	for l in 4: r.uroven[["0,25 m", "0,5 m", "1 m", "daleko 8 m"][l]] = po[l]
	var tot := {"ploch": 0, "sloupcu": 0, "tri": 0, "B": 0}
	for l in 4: tot.ploch += po[l].ploch; tot.sloupcu += po[l].sloupcu; tot.tri += po[l].tri; tot.B += po[l].B_vysky + po[l].B_slupka + po[l].B_sit
	r.celkem = {"ploch": tot.ploch, "sloupcu": tot.sloupcu, "tri": tot.tri, "MB_data_a_sit": tot.B / 1048576.0, "ms_plan": ms_plan, "ms_stavba": ms_all,
		"rss_pred_mb": m0.rss_mb, "rss_po_mb": m1.rss_mb, "peak_mb": m1.peak_mb, "detail_dlazdic": pl.detail.size(), "kousku": pl.kousky.size()}
	print("stavba: ", JSON.stringify(r.celkem))
	# 3) díry na švech (plochy v detailu + daleké dlaždice sousedící s detailem)
	t0 = Time.get_ticks_usec()
	var dd := {}
	for ses in [false, true]:
		var z := {"useku": 0, "s_dirou": 0, "plocha_m2": 0.0, "max_m": 0.0, "skok_max_m": 0.0, "ruzne_urovne": 0, "pary": {}}
		for a in pl.plochy:
			if int(a.lvl) == 3:
				var t := Vector2i(floori(a.o.x / pl.TM), floori(a.o.y / pl.TM))
				if not (pl.detail.has(t + Vector2i(1, 0)) or pl.detail.has(t + Vector2i(0, 1))): continue
			var h := L.diry(f, pl, p, a, ses)
			for k in ["useku", "s_dirou", "ruzne_urovne"]: z[k] += int(h[k])
			z.plocha_m2 += h.plocha_m2; z.max_m = maxf(z.max_m, h.max_m); z.skok_max_m = maxf(z.skok_max_m, h.skok_max_m)
			for pk in h.pary:
				if not z.pary.has(pk): z.pary[pk] = {"useku": 0, "s_dirou": 0, "plocha_m2": 0.0, "skok_max_m": 0.0, "dira_max_m": 0.0}
				var zp: Dictionary = z.pary[pk]; var hp: Dictionary = h.pary[pk]
				zp.useku += hp.useku; zp.s_dirou += hp.s_dirou; zp.plocha_m2 += hp.plocha_m2
				zp.skok_max_m = maxf(zp.skok_max_m, hp.skok_max_m); zp.dira_max_m = maxf(zp.dira_max_m, hp.dira_max_m)
		dd["se_sesitim" if ses else "bez_seseti"] = z
	r.svy = dd; r.svy.ms = M.ms(t0)
	print("švy: ", JSON.stringify(dd))
	# 4) krok hráče 0 o 16 m: změněné plochy + sousedé (sešití)
	var h2 := hraci.duplicate(); h2[0] = hraci[0] + Vector2(16, 0)
	var pl2 := L.plan(p, h2)
	var old := {}
	for a in pl.plochy: old[a.klic] = a.c
	var zmena := []
	for a in pl2.plochy:
		if not old.has(a.klic) or float(old[a.klic]) != float(a.c): zmena.append(a)
	var zk := {}
	for a in zmena: zk[a.klic] = true
	var soused := []
	for a in pl2.plochy:
		if zk.has(a.klic) or int(a.lvl) == 3: continue
		var kk := Vector2i(floori(a.o.x / pl2.KM), floori(a.o.y / pl2.KM))
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk: Vector2i = kk + dv
			if zk.has("k%d,%d" % [nk.x, nk.y]): soused.append(a); break
	t0 = Time.get_ticks_usec()
	var tri2 := 0
	for a in zmena + soused: tri2 += L.stavba(f, pl2, p, a, true).tri
	r.krok_16m = {"zmenenych_ploch": zmena.size(), "sousedu_k_preseti": soused.size(), "ms": M.ms(t0), "tri": tri2}
	print("krok: ", JSON.stringify(r.krok_16m))
	# 5) odhad: celá mapa po 1 m
	var c1: Dictionary = po[2]
	var us: float = (c1.ms_fn + c1.ms_sit + c1.ms_mesh) * 1000.0 / maxf(1.0, c1.sloupcu)
	var cols := pow(float(pl.T) * float(pl.TM), 2.0)
	r.odhad_1m_vsude = {"sloupcu": cols, "us_na_sloupec": us, "s": cols * us / 1e6, "tri": cols * float(c1.tri) / maxf(1.0, c1.sloupcu), "MB_sit": cols * float(c1.B_sit) / maxf(1.0, c1.sloupcu) / 1048576.0}
	var out := _arg("out", "")
	if out != "":
		var fo := FileAccess.open(out, FileAccess.WRITE); fo.store_string(JSON.stringify(r, " ", false)); fo.close()
	var sd := _arg("shots", "")
	if sd != "": await _shots(sd, pl, meshes, hraci)
	quit()

# ---------------------------------------------------------------- snímky
var cam: Camera3D
func _snap(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("uloženo ", path)

func _camera(c: Vector3, size: float, yaw := 45.0, pitch := -35.0) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	cam.size = size
	cam.transform = Transform3D(b, c + b.z * 4000.0)

func _shots(sd: String, pl: Dictionary, meshes: Dictionary, hraci: Array) -> void:
	DirAccess.make_dir_recursive_absolute(sd)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.74, 0.85, 0.94)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.7, 0.7, 0.75); env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 30, 0); sun.light_energy = 1.0; world.add_child(sun)
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.far = 20000.0; world.add_child(cam); cam.current = true
	var inst := {}
	for a in pl.plochy:
		var mi := MeshInstance3D.new(); mi.mesh = meshes[a.klic]; mi.material_override = mat; world.add_child(mi); inst[a.klic] = mi
	var mark := MeshInstance3D.new(); var cap := CapsuleMesh.new(); cap.height = 1.75; cap.radius = 0.25; mark.mesh = cap
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.9, 0.1, 0.6); mark.material_override = mm; world.add_child(mark)
	var h0: Vector2 = hraci[0]
	mark.position = Vector3(h0.x, L.h_m(f, h0.x, h0.y) + 1.0, h0.y)
	var TOT := float(pl.T) * float(pl.TM)
	var ref := float(f.ref) * 0.5
	_camera(Vector3(TOT / 2.0, ref, TOT / 2.0), TOT * 1.15)
	await _snap(sd.path_join("90_lod_mapa.png"))
	# okolí hráče 0 barevně po úrovních (přestavět detail s barvou úrovně)
	for a in pl.plochy:
		if int(a.lvl) < 3: inst[a.klic].mesh = L.mesh(L.stavba(f, pl, p, a, true, true))
	_camera(Vector3(h0.x, ref, h0.y), 260.0)
	await _snap(sd.path_join("90_lod_uroven_okoli.png"))
	_camera(Vector3(h0.x, ref, h0.y), 60.0)
	await _snap(sd.path_join("90_lod_uroven_detail.png"))
	# šev 0,25 / 0,5 m zblízka: najdi úsek hranice s největším skokem v okolí hráče 0
	var best := [-1.0, Vector3.ZERO]
	for a in pl.plochy:
		if int(a.lvl) != 0 or a.o.distance_to(h0) > 64.0: continue
		var h := L.diry(f, pl, p, a, false)
		if h.max_m > best[0]: best = [h.max_m, Vector3(a.o.x + a.s, 0, a.o.y + a.s / 2.0)]
	var sc: Vector3 = best[1]; sc.y = L.h_m(f, sc.x, sc.z)
	for ses in [false, true]:
		for a in pl.plochy:
			if int(a.lvl) < 3 and a.o.distance_to(Vector2(sc.x, sc.z)) < 48.0:
				inst[a.klic].mesh = L.mesh(L.stavba(f, pl, p, a, ses, true))
		_camera(sc, 14.0, 45.0, -30.0)
		await _snap(sd.path_join("90_lod_sev_%s.png" % ("seseno" if ses else "bez_seseti")))
	r.snimek_sev = {"max_dira_m": best[0], "bod": [sc.x, sc.y, sc.z]}
	print("šev snímek: ", r.snimek_sev)
