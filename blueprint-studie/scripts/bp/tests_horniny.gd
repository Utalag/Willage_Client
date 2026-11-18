extends RefCounted
## Testy a měření geologie v2: časy, minerály podle hostitelů, determinismus, švy (3 varianty), zdvih pod horou.

const Mat = preload("res://scripts/kopie/mat.gd")
const W = preload("res://scripts/bp/world.gd")
const PL = preload("res://scripts/bp/pipeline.gd")
const SC = preload("res://scripts/bp/scenario_horniny.gd")
const MT = preload("res://scripts/bp/metrics.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const BP = preload("res://scripts/bp/blueprint.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const SD = preload("res://scripts/bp/sides.gd")

static func build(p: Dictionary, seq := SC.sequence()):
	var w := W.new()
	for e in seq:
		PL.run_sync(w, e[0], e[1], p)
	return w

## vrstvy pro metriku: aktivní vrstvy; ignorují se půda, sníh, horniny hor, tělesa
static func ignore(p: Dictionary) -> Array:
	var ig := [Mat.AIR, Mat.GRASS, Mat.DIRT, Mat.SNOW]
	for e in HR.raw().rocks:
		if e.kind in ["mountain", "pipe", "dome", "vein", "contact"]:
			ig.append(int(e.id))
	return ig

static func seams(w, p: Dictionary) -> Dictionary:
	return MT.seams(w.slots, "hm", HR.pool(p).map(func(e): return int(e.id)), ignore(p))

## Náhlé objevení / zmizení vrstvy (Jan 16:46): pro každou dvojici sousedních řídicích bodů a každou vrstvu zásoby
## mocnost z FUNKCE (bs, jednotky U = 0,5 m). „Náhlé“ = na jedné straně ≥ 1 (0,5 m), na druhé < 0,1. Šev vs. vnitřek.
## Navíc z buněk: vrstva má ve sloupci ≥ 2 buňky a v sousedním 0.
static func abrupt(w, p: Dictionary) -> Dictionary:
	var lay := HR.pool(p).map(func(e): return int(e.id))
	var K := lay.size()
	var res := {"seam_pairs": 0, "seam_abrupt": 0, "inner_pairs": 0, "inner_abrupt": 0, "seam_jump": 0.0, "inner_jump": 0.0,
		"seam_cells_abrupt": 0, "inner_cells_abrupt": 0}
	var th := func(rec, i: int, k: int) -> float:
		return rec.bs[k][i] - (0.0 if k == 0 else rec.bs[k - 1][i])
	var cc := func(rec, i: int, k: int) -> int:
		var n := 0
		for z in 64:
			if rec.cells[i * 64 + z] == lay[k]: n += 1
		return n
	var pair := func(ra, ia: int, rb, ib: int, key: String) -> void:
		res[key + "_pairs"] += 1
		for k in K:
			var a: float = th.call(ra, ia, k); var b: float = th.call(rb, ib, k)
			res[key + "_jump"] = maxf(res[key + "_jump"], absf(a - b))
			if maxf(a, b) >= 1.0 and minf(a, b) < 0.1: res[key + "_abrupt"] += 1
			var ca: int = cc.call(ra, ia, k); var cb: int = cc.call(rb, ib, k)
			if maxi(ca, cb) >= 2 and mini(ca, cb) == 0: res[key + "_cells_abrupt"] += 1
	for s in w.slots:
		var r = w.slots[s]
		for x in 15:
			for y in 16:
				pair.call(r, x * 16 + y, r, (x + 1) * 16 + y, "inner")
		for d in [1, 2]:
			var n: Vector2i = s + SD.DIRS[d]
			if not w.slots.has(n): continue
			for t in 16:
				var o := SD.own(d, t); var c := SD.nb(d, t)
				pair.call(r, o.x * 16 + o.y, w.slots[n], c.x * 16 + c.y, "seam")
	return res

static func fmt_abrupt(a: Dictionary) -> String:
	return "šev: dvojic %d, náhlých vrstev %d (z buněk %d), max skok mocnosti %.2f U | uvnitř: dvojic %d, náhlých %d (z buněk %d), max skok %.2f U" % [
		a.seam_pairs, a.seam_abrupt, a.seam_cells_abrupt, a.seam_jump, a.inner_pairs, a.inner_abrupt, a.inner_cells_abrupt, a.inner_jump]

## mocnost vrstvy (U) podél řezu y v bloku – profil klínu
static func klin_profile(w, p: Dictionary, y: int) -> PackedStringArray:
	var L := PackedStringArray()
	var pool := HR.pool(p)
	for i in SC.KLIN.size():
		var k := -1
		for j in pool.size():
			if pool[j].key == SC.KLIN[i]: k = j
		var vals := []
		for s in [Vector2i(0, 5), Vector2i(1, 5)]:
			var r = w.slots[s]
			for x in 16:
				var c := x * 16 + y
				vals.append("%.1f" % (r.bs[k][c] - (0.0 if k == 0 else r.bs[k - 1][c])))
		L.append("vrstva %d %s: %s" % [i + 1, pool[k].name, " ".join(vals.slice(0, 16)) + " | " + " ".join(vals.slice(16))])
	return L

## Test pravidla Jan 17:38: (1) BP.validate odmítne VODU + VZDUCH, (2) generátor pak nevytvoří žádnou dutinu a chybu nahlásí,
## (3) v každém bloku světa je nejvýš jedna dutina = nejvýš jedna souvislá oblast podzemního vzduchu (6-sousedství).
static func cavity_components(cells: PackedByteArray, hm: PackedInt32Array) -> int:
	var lab := PackedByteArray(); lab.resize(cells.size())
	var n := 0
	for c0 in cells.size():
		if lab[c0] != 0 or cells[c0] != Mat.AIR or c0 % 64 >= hm[c0 / 64]: continue
		n += 1
		var q := PackedInt32Array([c0]); lab[c0] = 1; var h := 0
		while h < q.size():
			var c := q[h]; h += 1
			var x := c / 1024; var y := (c / 64) % 16; var z := c % 64
			for d in [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]:
				var nx: int = x + d[0]; var ny: int = y + d[1]; var nz: int = z + d[2]
				if nx < 0 or ny < 0 or nz < 0 or nx > 15 or ny > 15 or nz > 63: continue
				var j := (nx * 16 + ny) * 64 + nz
				if lab[j] == 0 and cells[j] == Mat.AIR and nz < hm[nx * 16 + ny]:
					lab[j] = 1; q.append(j)
	return n

static func cavity_rule_test(w, p: Dictionary) -> PackedStringArray:
	var L := PackedStringArray()
	var both := BP.make("kopec", 909, {8: 10, 250: 60, 0: 90}, 120)
	var v := BP.validate(both)
	L.append("blueprint VODA 60 + VZDUCH 90: validace %s %s" % ["OK (CHYBA TESTU)" if v.ok else "ODMÍTNUT", str(v.errors.map(func(e): return e.code))])
	var wt := W.new()
	var r := PL.run_sync(wt, Vector2i(0, 0), both, p)
	var cav := cavity_components(r.cells, r.hm)
	L.append("generátor s takovým blueprintem: dutin %d, chyba v hlášení %s → %s" % [r.rep.cavities.size(), str(r.rep.blueprint.errors.map(func(e): return e.code)),
		"OK" if r.rep.cavities.is_empty() and cav == 0 and not r.rep.blueprint.ok else "CHYBA"])
	var only_w := BP.make("kopec", 909, {8: 10, 250: 60}, 120)
	var only_a := BP.make("kopec", 909, {8: 10, 0: 90}, 120)
	L.append("jen VODA: validace %s, jen VZDUCH: validace %s, bez dutiny: validace %s" % ["OK" if BP.validate(only_w).ok else "ODMÍTNUT",
		"OK" if BP.validate(only_a).ok else "ODMÍTNUT", "OK" if BP.validate(BP.make("louka", 1, {8: 5})).ok else "ODMÍTNUT"])
	var bad := 0
	var parts := []
	for s in w.order:
		var rec: Dictionary = w.slots[s]
		var k := cavity_components(rec.cells, rec.hm)
		parts.append("%s %d" % [str(s), k])
		if k > 1 or rec.rep.cavities.size() > 1: bad += 1
	L.append("souvislých podzemních dutin v blocích: %s → %s" % [", ".join(parts), "OK (každý blok 0 nebo 1)" if bad == 0 else "CHYBA: %d bloků má víc" % bad])
	return L

## ---------- nezávislost na rozlišení (Jan 16:42)
## Blok se navzorkuje funkcemi při n = 16 (buňka 0,5 m) a n = 32 (0,25 m). Jemný výsledek se zmenší většinou z 8 buněk
## a porovná s hrubým. Minerály: cíl N při 16, 8·N při 32.
static func downsample(fine: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray(); out.resize(16 * 16 * 64)
	for x in 16:
		for y in 16:
			for z in 64:
				var cnt := {}
				var best := -1; var bc := 0
				for dx in 2:
					for dy in 2:
						for dz in 2:
							var m := fine[((2 * x + dx) * 32 + 2 * y + dy) * 128 + 2 * z + dz]
							cnt[m] = cnt.get(m, 0) + 1
							if cnt[m] > bc or (cnt[m] == bc and m < best): bc = cnt[m]; best = m
				out[(x * 16 + y) * 64 + z] = best
	return out

static func resolution(w, p: Dictionary, slots: Array) -> Dictionary:
	var FN = load("res://scripts/bp/geo_fn.gd")
	var wf: Dictionary = FN.world_fn(w.slots)
	var out := {"rows": [], "c16": {}, "c32": {}}
	var tot := 0; var agree := 0; var agree_nomin := 0; var tot_nomin := 0; var solid_ok := 0; var any_child := 0
	for s in slots:
		var rec = w.slots[s]
		var info: Dictionary = FN.block_info(wf, s, rec.bp, p)
		var t0 := Time.get_ticks_usec()
		var c16: PackedByteArray = FN.sample_all(wf, info, 16)
		var m16: Array = FN.minerals(c16, 16, wf, info, rec.bp.minerals, rec.bp.seed)
		var t1 := Time.get_ticks_usec()
		var c32: PackedByteArray = FN.sample_all(wf, info, 32)
		var m32: Array = FN.minerals(c32, 32, wf, info, rec.bp.minerals, rec.bp.seed)
		var t2 := Time.get_ticks_usec()
		var same_pipe: bool = c16 == rec.cells
		var ds := downsample(c32)
		var a := 0; var an := 0; var tn := 0; var so := 0; var ac := 0
		var mins := {}
		for m in rec.bp.minerals: mins[int(m)] = true
		mins.erase(0); mins.erase(250)
		for i in c16.size():
			if ds[i] == c16[i]: a += 1
			if (ds[i] == 0) == (c16[i] == 0): so += 1
			if not mins.has(int(c16[i])):
				tn += 1
				if ds[i] == c16[i]: an += 1
			# hrubá hodnota je mezi 8 jemnými dětmi
			var x := i / 1024; var y := (i / 64) % 16; var z := i % 64
			var hit := false
			for dx in 2:
				for dy in 2:
					for dz in 2:
						if c32[((2 * x + dx) * 32 + 2 * y + dy) * 128 + 2 * z + dz] == c16[i]: hit = true
			if hit: ac += 1
		tot += c16.size(); agree += a; agree_nomin += an; tot_nomin += tn; solid_ok += so; any_child += ac
		var mtxt := []
		for j in m16.size():
			mtxt.append("%s %d/%d → %d/%d" % [m16[j].name, m16[j].placed, m16[j].target, m32[j].placed, m32[j].target])
		out.rows.append("%s %s: shoda %.1f %% (bez minerálů %.1f %%), pevné/vzduch %.2f %%, hrubá hodnota mezi 8 jemnými %.1f %% | 16 = buňky pipeline: %s | čas 16: %.0f ms, 32: %.0f ms | minerály 16 → 32: %s" % [
			str(s), rec.bp.shape, 100.0 * a / c16.size(), 100.0 * an / maxi(tn, 1), 100.0 * so / c16.size(), 100.0 * ac / c16.size(),
			"ANO" if same_pipe else "NE", (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, "; ".join(mtxt)])
		out.c16[s] = c16; out.c32[s] = c32; out.ds = out.get("ds", {}); out.ds[s] = ds
	out.total = "celkem: shoda %.1f %%, bez minerálů %.1f %%, pevné/vzduch %.2f %%, hrubá hodnota mezi jemnými %.1f %%" % [
		100.0 * agree / tot, 100.0 * agree_nomin / maxi(tot_nomin, 1), 100.0 * solid_ok / tot, 100.0 * any_child / tot]
	return out

static func _col(pal: PackedColorArray, m: int) -> Color:
	if m == 0: return Color(0.78, 0.88, 0.97)
	if pal[m].a > 0: return pal[m]
	return Mat.COLORS[m] if m < Mat.COLORS.size() else Color.MAGENTA

## řez y = polovina bloku přes řadu slotů: hrubý (×8), jemný (×4), rozdíl (červeně neshoda po zmenšení)
static func resolution_images(res: Dictionary, slots: Array, dir: String) -> void:
	var pal := HR.palette()
	var W := slots.size() * 16 * 8; var Hh := 64 * 8
	var a := Image.create(W, Hh, false, Image.FORMAT_RGB8)
	var b := Image.create(W, Hh, false, Image.FORMAT_RGB8)
	var c := Image.create(W, Hh, false, Image.FORMAT_RGB8)
	for si in slots.size():
		var s: Vector2i = slots[si]
		var c16: PackedByteArray = res.c16[s]; var c32: PackedByteArray = res.c32[s]; var ds: PackedByteArray = res.ds[s]
		for x in 16:
			for z in 64:
				var i := (x * 16 + 8) * 64 + z
				a.fill_rect(Rect2i((si * 16 + x) * 8, (63 - z) * 8, 8, 8), _col(pal, c16[i]))
				var bad := ds[i] != c16[i]
				var g := _col(pal, c16[i]).lerp(Color(0.5, 0.5, 0.5), 0.7)
				c.fill_rect(Rect2i((si * 16 + x) * 8, (63 - z) * 8, 8, 8), Color(0.9, 0.1, 0.1) if bad else g)
		for x in 32:
			for z in 128:
				b.fill_rect(Rect2i((si * 32 + x) * 4, (127 - z) * 4, 4, 4), _col(pal, c32[(x * 32 + 16) * 128 + z]))
	a.save_png(dir + "/_rozl16.png"); b.save_png(dir + "/_rozl32.png"); c.save_png(dir + "/_rozl_rozdil.png")


## podíl buněk v jádru hory (nad 46) podle zóny
static func core(cells: PackedByteArray, hm: PackedInt32Array) -> Dictionary:
	var z := {}
	for e in HR.raw().rocks:
		z[int(e.id)] = e.zone
	var cnt := {}
	var tot := 0
	for col in 256:
		for k in range(46, hm[col]):
			var m := cells[col * 64 + k]
			var zn: String = z.get(m, "minerál")
			if m == Mat.SNOW: zn = "sníh"
			cnt[zn] = cnt.get(zn, 0) + 1; tot += 1
	for k in cnt:
		cnt[k] = "%.0f %%" % (100.0 * cnt[k] / maxi(tot, 1))
	return cnt

static func run_all(p: Dictionary, out_path: String) -> PackedStringArray:
	var L := PackedStringArray()
	var lay := HR.all_layers(p)
	L.append("blueprint-studie – geologie v2 (tabulka pořadí hornin) – %s" % Time.get_datetime_string_from_system())
	L.append("aktivní vrstvy %d: %s" % [lay.size(), ", ".join(lay.map(func(e): return "%d %s" % [e.idx, e.name]))])
	L.append("tělesa: kimberlit (komín), pegmatit (žíly), skarn (kontakt), kamenná sůl (dóm); horniny hor aktivní %d; minerálů v tabulce %d" % [HR.mountain(p).size(), HT.table().size()])
	var t0 := Time.get_ticks_usec()
	var w = build(p)
	var tall := (Time.get_ticks_usec() - t0) / 1000.0
	L.append("\n## Vložení – časy kroků ms")
	for s in w.order:
		var r: Dictionary = w.slots[s]
		var ms := []
		var tot := 0.0
		for k in r.ms:
			ms.append("%s %.0f" % [k, r.ms[k]]); tot += r.ms[k]
		L.append("%d. %s %s: %.0f ms | %s | tělesa %s" % [r.order + 1, str(s), r.bp.shape, tot, ", ".join(ms), str(r.rep.bodies)])
	L.append("celý sled %d bloků: %.0f ms" % [w.order.size(), tall])
	L.append("\n## Minerály jen v povolených hostitelích (cíl → umístěno, schodek)")
	var nshort := 0; var nitems := 0
	for s in w.order:
		var r: Dictionary = w.slots[s]
		var parts := []
		for m in r.rep.minerals:
			nitems += 1
			if m.shortfall > 0: nshort += 1
			parts.append("%s %d→%d%s (v %s: %d b.)" % [m.name, m.target, m.placed, "" if m.shortfall == 0 else " SCHODEK %d" % m.shortfall, m.hosts, m.host_cells])
		L.append("%s %s: %s | validátor %s | rarita %.0f" % [str(s), r.bp.shape, "; ".join(parts), "OK" if r.rep.valid.ok else "CHYBA " + str(r.rep.valid.errors.slice(0, 2)), BP.rarity_points(r.bp)])
	L.append("položek %d, se schodkem %d (hostitel v bloku chybí nebo nestačí)" % [nitems, nshort])
	L.append("\n## Dutiny z materiálů VODA a VZDUCH (rezervoár, jeskyně): v bloku nic, nebo právě jedna (Jan 17:38)")
	L.append_array(cavity_rule_test(w, p))
	for s in w.order:
		var r: Dictionary = w.slots[s]
		for cv in r.rep.get("cavities", []):
			L.append("%s %s: %s %d→%d%s | kandidátů %d (%s) %s" % [str(s), r.bp.shape, cv.name, cv.target, cv.placed,
				"" if cv.shortfall == 0 else " SCHODEK %d" % cv.shortfall, cv.host_cells, cv.hosts, cv.reason])
		if r.rep.get("reservoir_cells", 0) > 0:
			L.append("%s voda v rezervoáru %d buněk (plné), validátor vody %s" % [str(s), r.rep.reservoir_cells, "OK" if r.rep.valid.ok else str(r.rep.valid.errors.slice(0, 3))])
	L.append("\n## Determinismus")
	var h1: String = w.hash()
	L.append("2 běhy: %s / %s → %s" % [h1.left(16), build(p).hash().left(16), "STEJNÉ" if h1 == build(p).hash() else "RŮZNÉ!"])
	L.append("\n## Švy vrstev v2 (průměr přes %d aktivních vrstev)" % lay.size())
	var mc := seams(w, p)
	var pn := p.duplicate(true); pn["continue"] = false
	var mb := seams(build(pn), p)
	# A: nezávislé bloky = každý blok vlastní seed světa, bez navázání
	var wa := W.new()
	for e in SC.sequence():
		var pa := pn.duplicate(true); pa.world_seed = H.mix(p.world_seed, "NEZAVISLE", e[0].x * 10 + e[0].y) & 0xFFFFFF
		PL.run_sync(wa, e[0], e[1], pa)
	var ma := seams(wa, p)
	L.append("A nezávislé bloky (vlastní deska každého bloku): průměr %.2f" % MT.mean_seam(ma))
	L.append("B společná deska + zdvih, bez navázání: průměr %.2f" % MT.mean_seam(mb))
	L.append("C společná deska + zdvih + Laplace: průměr %.2f, uvnitř bloků %.2f, povrch šev %.2f" % [MT.mean_seam(mc), MT.mean_inner(mc), mc.surf_seam])
	L.append("C podrobně: " + MT.fmt(mc))
	L.append("\n## Složení nad výškou 46 (jádro hory) podle zóny")
	L.append("hora vyzdvižená (0,0): " + str(core(w.slots[Vector2i(0, 0)].cells, w.slots[Vector2i(0, 0)].hm)))
	L.append("hora zvrásněná (1,2): " + str(core(w.slots[Vector2i(1, 2)].cells, w.slots[Vector2i(1, 2)].hm)))
	L.append("sopka (2,0): " + str(core(w.slots[Vector2i(2, 0)].cells, w.slots[Vector2i(2, 0)].hm)))
	var pf := p.duplicate(true); pf.profiles = {"mirne": [0.0, 0.0], "hora_vyzdvizena": [0.0, 0.0, 1000.0, 2000.0, 2.0, 1e9], "hora_zvrasnena": [0.0, 0.0, 1.0], "sopka": [9.0, 1.4, 0.0, 0.0, 1.5]}
	var wf = build(pf)
	L.append("bez deformace vrstev (srovnání, hora (0,0)): " + str(core(wf.slots[Vector2i(0, 0)].cells, wf.slots[Vector2i(0, 0)].hm)))
	L.append("švy bez deformace: C %.2f" % MT.mean_seam(seams(wf, p)))
	L.append("\n## Náhlé objevení / zmizení vrstvy na švech (hlavní sled, %d vrstev zásoby)" % HR.pool(p).size())
	L.append("s navázáním: " + fmt_abrupt(abrupt(w, p)))
	L.append("bez navázání (B): " + fmt_abrupt(abrupt(build(pn), p)))
	L.append("\n## Klín (skica Jana 16:49): levý blok 1,2,4,5,6,7 | pravý (nový) 1,3,5,6,7; taper %.1f m" % float(p.taper_m))
	var wk = build(p, SC.klin_sequence())
	L.append("s navázáním: " + fmt_abrupt(abrupt(wk, p)))
	L.append("bez navázání: " + fmt_abrupt(abrupt(build(pn, SC.klin_sequence()), p)))
	L.append("mocnost vrstev (U = 0,5 m) podél řezu y = 8, sloupce x 0–15 levého | 0–15 pravého bloku:")
	L.append_array(klin_profile(wk, p, 8))
	L.append("\n## Nezávislost na rozlišení: 16 × 16 × 64 (0,5 m) vs. 32 × 32 × 128 (0,25 m), jemný zmenšen většinou z 8")
	var rs := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	var rr := resolution(w, p, rs)
	L.append_array(rr.rows)
	L.append(rr.total)
	resolution_images(rr, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	return L
