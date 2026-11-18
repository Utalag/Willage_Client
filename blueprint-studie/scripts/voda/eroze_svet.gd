extends RefCounted
## E47: eroze PO výpočtu vrstev na hotovém světě v2. Mění jen funkci povrchu hm_f (uloží hm_pre), hranice vrstev bs
## zůstávají (jsou absolutní ve výšce), buňky se znovu navzorkují funkcemi (geo_fn) → koryto odkryje hlubší vrstvy,
## nános = ero_deposit (štěrk/písek). Minerály a dutiny zůstanou, kde je ještě hornina; odnesené se spočítají.
## Režimy: "blok" (každý blok sám, zavřené okraje), "okraj" (každý blok sám, změna × smoothstep od švu → švy připnuté),
## "svet" (celý svět naráz na společné mřížce; jen když se svět generuje celý najednou),
## "strze" (E47b: celý svět naráz, strže podle průtoku + ponory + vodopády, strze.gd; výsledek v rep.strze).

const W = preload("res://scripts/bp/world.gd")
const FN = preload("res://scripts/bp/geo_fn.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const Mat = preload("res://scripts/kopie/mat.gd")
const EM = preload("res://scripts/voda/eroze_mrizka.gd")
const SZ = preload("res://scripts/voda/strze.gd")
const PRM = preload("res://scripts/voda/prameny.gd")
const UG = preload("res://scripts/voda/podzemi.gd")

static func _copy_world(src):
	var w = W.new()
	w.w = src.w; w.h = src.h
	for s in src.order:
		var r: Dictionary = src.slots[s].duplicate()
		r.hm_f = r.hm_f.duplicate(); r.hm = r.hm.duplicate(); r.cells = r.cells.duplicate()
		r.water = r.water.duplicate()
		w.slots[s] = r; w.order.append(s)
	return w

static func _weight(i: int, band: float) -> float:
	var x := i / 16; var y := i % 16
	var d := float(mini(mini(x, 15 - x), mini(y, 15 - y)))
	return smoothstep(0.0, band, d)

static func run(src, p: Dictionary, mode: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var w = _copy_world(src)
	var drops := int(p.get("ero_droplets", 3000))
	var band := float(p.taper_m) / FN.U
	var st := {}
	if mode == "strze":
		var GW: int = w.w * 16; var GH: int = w.h * 16
		var g := PackedFloat64Array(); g.resize(GW * GH); g.fill(float(p.surf_ref))
		var wall := PackedByteArray(); wall.resize(GW * GH); wall.fill(1)
		for s in w.order:
			var r: Dictionary = w.slots[s]
			for i in 256:
				var gi: int = (s.x * 16 + i / 16) * GH + s.y * 16 + i % 16
				g[gi] = r.hm_f[i]; wall[gi] = 0
		var mat_d := func(gi: int, d: int) -> int:   # materiál d buněk pod povrchovou buňkou
			var gx := gi / GH; var gy := gi % GH
			var r: Dictionary = src.slots[Vector2i(gx / 16, gy / 16)]
			var c := (gx % 16) * 16 + gy % 16
			return int(r.cells[c * 64 + clampi(int(r.hm[c]) - 1 - d, 0, 63)])
		var dd := int(round(float(p.strz_target_m) / 0.5))
		var mat_at := func(gi: int) -> int: return mat_d.call(gi, dd)
		var springs := []
		var q := PackedFloat64Array()
		if String(p.get("voda_zdroj", "plocha")) == "prameny":
			springs = PRM.find(g, GW, GH, wall, mat_d, p)
			q = PRM.src(springs, g, GW * GH)
		var ug := {}
		if not springs.is_empty() and bool(p.get("podzemi_vrstva", false)): ug = UG.ctx_world(src, p)
		st = SZ.run(g, GW, GH, wall, mat_at, p, q, ug)
		for sp in springs: sp.z = int(g[sp.gi])   # pramen zůstává buňkou na (zahloubeném) povrchu
		st.springs = springs
		st.mat_d = mat_d
		w.set_meta("strze", st)
		for s in w.order:
			var r: Dictionary = w.slots[s]
			r.hm_pre = src.slots[s].hm_f
			for i in 256:
				r.hm_f[i] = g[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16]
	elif mode == "svet":
		var GW: int = w.w * 16; var GH: int = w.h * 16
		var g := PackedFloat64Array(); g.resize(GW * GH); g.fill(float(p.surf_ref))
		var fixed := PackedByteArray(); fixed.resize(GW * GH); fixed.fill(1)
		for s in w.order:
			var r: Dictionary = w.slots[s]
			for i in 256:
				var gi: int = (s.x * 16 + i / 16) * GH + s.y * 16 + i % 16
				g[gi] = r.hm_f[i]; fixed[gi] = 0
		st = EM.run(g, GW, GH, int(p.world_seed), drops * w.order.size(), p, fixed)
		for s in w.order:
			var r: Dictionary = w.slots[s]
			r.hm_pre = src.slots[s].hm_f
			for i in 256:
				r.hm_f[i] = g[(s.x * 16 + i / 16) * GH + s.y * 16 + i % 16]
	else:
		for s in w.order:
			var r: Dictionary = w.slots[s]
			r.hm_pre = src.slots[s].hm_f
			var e: PackedFloat64Array = r.hm_f.duplicate()
			EM.run(e, 16, 16, int(r.bp.seed), drops, p)
			for i in 256:
				var k := 1.0 if mode == "blok" else _weight(i, band)
				r.hm_f[i] = r.hm_pre[i] + (e[i] - r.hm_pre[i]) * k
	var all_pre := PackedFloat64Array(); var all_post := PackedFloat64Array()
	for s in w.order:
		all_pre.append_array(w.slots[s].hm_pre); all_post.append_array(w.slots[s].hm_f)
	var keep := st
	st = EM.stats(all_pre, all_post)
	if mode == "strze": st.strze = keep
	var t1 := Time.get_ticks_usec()
	var lost := 0; var kept := 0; var opened := 0
	var wf := FN.world_fn(w.slots)
	for s in w.order:
		lost += _resample(w, wf, s, p, src.slots[s])
	st.ms_erode = (t1 - t0) / 1000.0
	st.ms_resample = (Time.get_ticks_usec() - t1) / 1000.0
	st.minerals_lost = lost
	st.mode = mode
	return {"world": w, "rep": st}

## nové buňky z funkcí; minerály a dutiny ze starých buněk zůstanou, kde je dál pevná hornina
static func _resample(w, wf: Dictionary, s: Vector2i, p: Dictionary, old: Dictionary) -> int:
	var r: Dictionary = w.slots[s]
	var info := FN.block_info(wf, s, r.bp, p)
	var cells := FN.sample_all(wf, info, 16)
	var mins := HT.table()
	var lost := 0
	var cav := {}
	for cv in old.rep.get("cavities", []):
		for c in cv.get("cells", []): cav[c] = true
	for c in cells.size():
		var o: int = old.cells[c]
		if mins.has(o):
			if cells[c] != Mat.AIR: cells[c] = o
			else: lost += 1
		elif cav.has(c) and cells[c] != Mat.AIR:
			cells[c] = Mat.AIR
	for i in 256:
		var h := 0
		for z in 64:
			if cells[i * 64 + z] != Mat.AIR: h = z + 1
		r.hm[i] = h
	r.cells = cells
	return lost
