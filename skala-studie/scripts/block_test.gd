extends RefCounted
## Režim `-- --block`: přístup C na celém bloku 32 × 32 × 64 (hora seed 7777, reliéf v2.2 z prototypu),
## měření (starý vs. řídký výpočet, LOD, úpravy) a snímky shots/26_skala_C_*.png.
## Přepínače: --kind=hora --bseed=7777 --chunk=16 --edits=18 --skip-old

const ResGen = preload("res://scripts/hora/res_gen.gd")
const Chunk = preload("res://scripts/chunk.gd")
const Nets = preload("res://scripts/nets_mesher.gd")
const RockVolume = preload("res://scripts/rock_volume.gd")
const Mat = preload("res://scripts/mat.gd")

var main  # main.gd (kamera, materiály, snímky)
var lines := []
var nodes := {}   # Vector3i chunk -> MeshInstance3D
var root: Node3D

func log_line(t: String) -> void:
	print("BLOK ", t)
	lines.append(t)

func run(m) -> void:
	main = m
	var A: String = main.arg("kind", "hora")
	var seed := int(main.arg("bseed", "7777"))
	var cell := Vector3(0.5, 0.5, 0.5)
	main.cell = cell
	var t0 := Time.get_ticks_usec()
	var g: Dictionary = ResGen.generate(A, seed, 32, 64, 0.5, 0.5)
	var cells: PackedByteArray = g.cells
	log_line("data %s %d 32×32×64: generování %.0f ms" % [A, seed, (Time.get_ticks_usec() - t0) / 1000.0])
	_count_cells(cells, 32, 32, 64)
	# data pro srovnávací benchmark v C# (csharp_bench/)
	var bf := FileAccess.open(ProjectSettings.globalize_path("res://csharp_bench/%s%d.bin" % [A, seed]), FileAccess.WRITE)
	if bf: bf.store_buffer(cells); bf.close()
	# --- dřív: nets_mesher.gd přes celou mřížku
	if not "--skip-old" in OS.get_cmdline_user_args():
		var ch := Chunk.new()
		ch.nx = 32; ch.nz = 32; ch.ny = 64; ch.cells = cells
		t0 = Time.get_ticks_usec()
		var old: ArrayMesh = Nets.build(ch, 7, cell)
		log_line("DŘÍV nets_mesher (celá mřížka): %.0f ms, trojúhelníků %d" % [(Time.get_ticks_usec() - t0) / 1000.0, old.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3])
	# --- teď: řídký výpočet po chuncích
	var vol := RockVolume.new()
	vol.chunk = int(main.arg("chunk", "16"))
	t0 = Time.get_ticks_usec()
	vol.setup(cells, 32, 32, 64, cell, 2.0)
	var t_setup := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var meshes := vol.build_all()
	var t_build := (Time.get_ticks_usec() - t0) / 1000.0
	log_line("TEĎ řídký výpočet: příprava %.0f ms, stavba %.0f ms (celkem %.0f ms), chunků %d, trojúhelníků %d" % [t_setup, t_build, t_setup + t_build, meshes.size(), vol.cnt.get("trojuhelniky", 0)])
	log_line("  smíšené bloky (okolí povrchu) %d, kandidátní krychle %d, vzorků se šumem %d z %d" % [vol.cnt.get("smisene_bloky", 0), vol.cnt.get("kandidatni_krychle", 0), vol.cnt.get("sum_noise", 0), vol.gx * vol.gy * vol.gz])
	log_line("  profil (ms): " + ", ".join(vol.prof.keys().map(func(k): return "%s %.0f" % [k, vol.prof[k] / 1000.0])))
	if vol.cnt.has("chybejici_quad"):
		log_line("  POZOR: chybějící quady %d" % vol.cnt.chybejici_quad)
	# druhý průchod: hustota už v mezipaměti → čistá cena meshování
	vol.prof.clear(); vol.cnt.clear()
	t0 = Time.get_ticks_usec()
	vol.build_all()
	log_line("  znovu se zaplněnou mezipamětí hustoty: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	# --- LOD: 1 vzorek na buňku
	var lod := RockVolume.new()
	t0 = Time.get_ticks_usec()
	lod.setup(cells.duplicate(), 32, 32, 64, cell, 1.0)
	var lm := lod.build_all()
	log_line("LOD 1 vzorek/buňku: %.0f ms, trojúhelníků %d" % [(Time.get_ticks_usec() - t0) / 1000.0, lod.cnt.get("trojuhelniky", 0)])
	# --- scéna
	root = Node3D.new()
	main.add_child(root)
	var mat: ShaderMaterial = main.rock_mat(true)
	for e in meshes:
		var mi := MeshInstance3D.new(); mi.mesh = e[1]; mi.material_override = mat
		root.add_child(mi); nodes[e[0]] = mi
	var W := 16.0
	main.get_node("Podlozka").visible = false
	main._cam(Vector3(W * 0.5, 14.0, W * 0.5), 40.0, 45.0, -30.0)
	await main._snap(main.dir() + "26_skala_C_blok.png")
	main._cam(Vector3(W * 0.5, 14.0, W * 0.5), 40.0, 225.0, -30.0)
	await main._snap(main.dir() + "26_skala_C_blok_zezadu.png")
	# LOD snímek
	root.visible = false
	var lroot := Node3D.new(); main.add_child(lroot)
	for e in lm:
		var mi := MeshInstance3D.new(); mi.mesh = e[1]; mi.material_override = mat; lroot.add_child(mi)
	main._cam(Vector3(W * 0.5, 14.0, W * 0.5), 40.0, 45.0, -30.0)
	await main._snap(main.dir() + "26_skala_C_lod.png")
	lroot.queue_free(); root.visible = true
	# detail + kopání: najdi viditelné místo na povrchu blízko středu přední strany
	var dig := _dig_spot(cells)
	var top: int = dig.y
	var focus := (Vector3(dig.x, top, dig.z) + Vector3(0.5, 0.5, 0.5)) * cell
	main._cam(focus, 8.0, 45.0, -38.0)
	await main._snap(main.dir() + "26_skala_C_detail.png")
	await main._snap(main.dir() + "26_skala_C_pred_kopanim.png")
	var times := []
	var nmax := int(main.arg("edits", "27"))
	var done := 0
	for depth in 3:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if done >= nmax: break
				var x: int = dig.x + dx; var z: int = dig.z + dz
				var y := _top(vol.cells, x, z) - 1
				if y < 1: continue
				var te := Time.get_ticks_usec()
				var dirty: Array = vol.set_cell(x, y, z, 0)
				for c in dirty:
					var am: ArrayMesh = vol.build_chunk(c)
					if nodes.has(c):
						nodes[c].mesh = am
					else:
						var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = mat; root.add_child(mi); nodes[c] = mi
				times.append([(Time.get_ticks_usec() - te) / 1000.0, dirty.size()])
				done += 1
	var tot := 0.0; var mx := 0.0; var chs := 0
	for t in times:
		tot += t[0]; mx = maxf(mx, t[0]); chs += t[1]
	log_line("KOPÁNÍ %d buněk: průměr %.0f ms/úprava, max %.0f ms, průměrně %.1f chunků na úpravu (chunk %d³)" % [times.size(), tot / maxf(times.size(), 1), mx, float(chs) / maxf(times.size(), 1), vol.chunk])
	await main._snap(main.dir() + "26_skala_C_po_kopani.png")
	var f := FileAccess.open(main.dir() + "26_skala_C_casy.txt", FileAccess.WRITE)
	for l in lines: f.store_line(l)

func _top(cells: PackedByteArray, x: int, z: int) -> int:
	for y in range(63, -1, -1):
		if cells[(x * 32 + z) * 64 + y] != 0:
			return y + 1
	return 0

## místo kopání: rovná plocha 5 × 5, na kterou je od kamery (+x, +z) vidět (nic vyššího před ní)
func _dig_spot(cells: PackedByteArray) -> Vector3i:
	var best := Vector3i(16, _top(cells, 16, 16), 16); var bs := -1e9
	for x in range(4, 28):
		for z in range(4, 28):
			var h := _top(cells, x, z)
			var flat := 0
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					flat += absi(_top(cells, x + dx, z + dz) - h)
			var block := 0
			for k in range(1, 8):
				if x + k < 32 and z + k < 32:
					block = maxi(block, _top(cells, x + k, z + k) - h)
			var sc := -flat * 10.0 - block * 20.0 + (x + z) * 0.3
			if sc > bs:
				bs = sc; best = Vector3i(x, h, z)
	return best

func _count_cells(cells: PackedByteArray, n: int, nzz: int, h: int) -> void:
	var solid := 0; var surf := 0
	for x in n:
		for z in nzz:
			for y in h:
				if cells[(x * nzz + z) * h + y] == 0: continue
				solid += 1
				var air := false
				for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
					var a: int = x + d.x; var b: int = y + d.y; var c: int = z + d.z
					if b < 0: continue
					if a < 0 or c < 0 or a >= n or c >= nzz or b >= h or cells[(a * nzz + c) * h + b] == 0:
						air = true; break
				if air: surf += 1
	log_line("buněk celkem %d, plných %d, povrchových (plná se vzduchem vedle) %d = %.1f %% plných" % [n * nzz * h, solid, surf, 100.0 * surf / maxf(solid, 1)])

func _tri(m: ArrayMesh) -> int:
	return 0 if m.get_surface_count() == 0 else m.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
