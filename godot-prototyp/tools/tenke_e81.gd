extends "res://tools/hranice_e80.gd"
## E81: tenké vrstvy při převzorkování. Vrstva tenčí než buňka nesmí zmizet nebo se objevovat podle rozlišení.
## Pravda = funkce (ug_funkce.bands: pásma vrstev ve sloupci v metrech). Buňky = geo_fn.sample při 0,5 m (n 16) a 0,25 m
## (n 32), bez opravy a s opravou p81_tenke (konzervativní vzorkování). Části: --casti=vyskyt,voda,mineraly,ostrov --out=cesta
const UG = preload("res://scripts/voda/podzemi/ug_funkce.gd")
const BW := 8.0
const HR = preload("res://scripts/teren/horniny.gd")

static func jmeno(m: int) -> String:
	for e in HR.raw().rocks:
		if int(e.id) == m: return str(e.key)
	return str(m)

var wf := {}
var blks := {}        # slot ostrova → blok
var infos := {}       # [slot, zap] → info

func info2(b, on: bool) -> Dictionary:
	var key := "%s|%s" % [b.slot, on]
	if not infos.has(key):
		var p: Dictionary = T.p.duplicate(); p.p81_tenke = on
		var ws := T.wslot(b.slot)
		infos[key] = FN.block_info(wf, ws, T.world.slots[ws].bp, p)
	return infos[key]

## mocnost materiálu ve sloupci podle funkce: {mat: t}; jen vrstvy (info.lay)
func fn_thick(info: Dictionary, X: float, Y: float) -> Dictionary:
	var col := FN.column(wf, info, X, Y)
	var out := {}
	var lay := {}
	for m in info.lay: lay[int(m)] = true
	for bd in UG.bands(info, col, X, Y):   # jen kde funkce materiálu vrstvu opravdu dává (ne těleso, ne kryt)
		var m := int(bd[2])
		if not lay.has(m): continue
		var real := false
		for q in 5:
			if FN.material(info, col, X, Y, lerpf(float(bd[0]), float(bd[1]), (q * 2 + 1) / 10.0)) == m: real = true; break
		if real: out[m] = float(out.get(m, 0.0)) + float(bd[1]) - float(bd[0])
	return out

## mřížka ostrova 2n × 2n: index gx * 2n + gy
func grids(n: int, on: bool) -> Dictionary:
	var N := 2 * n; var nz := 4 * n; var c := BW / n
	var th := {}       # mat → PackedFloat32Array mocností (funkce)
	var cellp := {}    # mat → PackedByteArray výskyt v buňkách
	var k81 := {"pridano": 0, "posun": 0, "konflikt": 0, "kryt": 0, "odebrano": 0}
	var ms := 0.0
	for s in blks:
		var b = blks[s]
		var info := info2(b, on)
		info.erase("_k81")
		var t0 := Time.get_ticks_usec()
		var cells: PackedByteArray = FN.sample_all(wf, info, n)
		ms += (Time.get_ticks_usec() - t0) / 1000.0
		if info.has("_k81"):
			for k in k81: k81[k] += int(info._k81.get(k, 0))
		var ox: float = info.slot.x * BW; var oy: float = info.slot.y * BW
		for x in n:
			for y in n:
				var gi: int = (s.x * n + x) * N + s.y * n + y
				var t := fn_thick(info, ox + (x + 0.5) * c, oy + (y + 0.5) * c)
				for m in t:
					if not th.has(m):
						var a := PackedFloat32Array(); a.resize(N * N); th[m] = a
					th[m][gi] = t[m]
				var base := (x * n + y) * nz
				for z in nz:
					var m := int(cells[base + z])
					if th.has(m) or m in info.lay:
						if not cellp.has(m):
							var a2 := PackedByteArray(); a2.resize(N * N); cellp[m] = a2
						cellp[m][gi] = 1
	return {"n": n, "N": N, "th": th, "cell": cellp, "k81": k81, "ms": ms}

static func comps(pres: PackedByteArray, N: int) -> int:
	var seen := PackedByteArray(); seen.resize(N * N)
	var cnt := 0
	for i in N * N:
		if pres[i] == 0 or seen[i] == 1: continue
		cnt += 1
		var st := [i]; seen[i] = 1
		while not st.is_empty():
			var j: int = st.pop_back()
			var x := j / N; var y := j % N
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + d.x; var yy: int = y + d.y
				if xx < 0 or yy < 0 or xx >= N or yy >= N: continue
				var k := xx * N + yy
				if pres[k] == 1 and seen[k] == 0: seen[k] = 1; st.append(k)
	return cnt

## výskyt na jemné mřížce 64 × 64 (0,5 m → 2 × 2)
static func up(pres: PackedByteArray, N: int, NF: int) -> PackedByteArray:
	var r := NF / N
	var o := PackedByteArray(); o.resize(NF * NF)
	for i in NF * NF:
		o[i] = pres[(i / NF / r) * N + (i % NF) / r]
	return o

static func fpres(th: PackedFloat32Array, tmin: float) -> PackedByteArray:
	var o := PackedByteArray(); o.resize(th.size())
	for i in th.size(): o[i] = 1 if th[i] > tmin else 0
	return o

## šev ostrova: dvojice sloupců přes šev (x = N/2 − 1 | N/2, totéž v y) s jiným výskytem, proti dvojicím uvnitř bloku
static func seam(pres: PackedByteArray, N: int) -> Dictionary:
	var h := N / 2
	var sd := 0; var sn := 0; var idf := 0; var inn := 0
	for a in N:
		for b in N - 1:
			for dir in 2:
				var i: int = (b * N + a) if dir == 0 else (a * N + b)
				var j: int = ((b + 1) * N + a) if dir == 0 else (a * N + b + 1)
				var d := 1 if pres[i] != pres[j] else 0
				if b == h - 1: sn += 1; sd += d
				else: inn += 1; idf += d
	return {"sev": float(sd) / sn, "uvnitr": float(idf) / inn}

func part_vyskyt() -> Dictionary:
	var tmin := float(T.p.get("p81_min_m", 0.05))
	var G := {}
	for n in [16, 32]:
		for on in [false, true]: G["%d_%s" % [n, "s" if on else "bez"]] = grids(n, on)
	var NF := 64
	var out := {"tmin_m": tmin, "vrstvy": [], "souhrn": {}}
	var g16: Dictionary = G["16_bez"]; var g32: Dictionary = G["32_bez"]
	var tot := {}
	var mats: Array = g32.th.keys(); mats.sort()
	for m in mats:
		var t32: PackedFloat32Array = g32.th[m]
		var hist := [0, 0, 0, 0]   # 0–0,25 / 0,25–0,5 / 0,5–1 / > 1 m (sloupce 0,25 m, kde vrstva je)
		var tsum := 0.0; var tn := 0
		for v in t32:
			if v <= tmin: continue
			tn += 1; tsum += v
			hist[0 if v < 0.25 else (1 if v < 0.5 else (2 if v < 1.0 else 3))] += 1
		if tn == 0: continue
		var F64 := fpres(t32, tmin)
		var F16 := fpres(g16.th.get(m, PackedFloat32Array()) if g16.th.has(m) else PackedFloat32Array(), tmin)
		var e := {"mat": m, "jmeno": jmeno(m), "sloupcu_fn_025": tn,
			"mocnost_prumer_m": tsum / tn, "hist_025_05_1_vic": hist, "kusu_fn_025": comps(F64, NF), "kusu_fn_05": comps(F16, 32) if F16.size() == 32 * 32 else 0}
		var ref: Dictionary = {}
		for key in G:
			var g: Dictionary = G[key]
			var N: int = g.N
			var S: PackedByteArray = g.cell.get(m, PackedByteArray())
			if S.is_empty(): S.resize(N * N)
			var Fown := fpres(g.th.get(m, PackedFloat32Array()), tmin) if g.th.has(m) else PackedByteArray()
			if Fown.is_empty(): Fown.resize(N * N)
			var chyb := 0; var navic := 0; var tenke := 0; var tenke_chyb := 0
			var tt: PackedFloat32Array = g.th.get(m, PackedFloat32Array())
			for i in N * N:
				if Fown[i] == 1 and S[i] == 0: chyb += 1
				if Fown[i] == 0 and S[i] == 1: navic += 1
				if tt.size() > 0 and tt[i] > tmin and tt[i] < BW / g.n:
					tenke += 1
					if S[i] == 0: tenke_chyb += 1
			var Su := up(S, N, NF)
			ref[key] = Su
			e[key] = {"chybi": chyb, "navic": navic, "sloupcu_fn": Fown.count(1), "tenkych": tenke, "tenkych_chybi": tenke_chyb,
				"kusu": comps(S, N), "sev": seam(S, N)}
			for k in ["chybi", "navic", "tenkych", "tenkych_chybi"]:
				if not tot.has(key): tot[key] = {}
				tot[key][k] = int(tot[key].get(k, 0)) + int(e[key][k])
			tot[key]["kusu"] = int(tot[key].get("kusu", 0)) + int(e[key].kusu)
		# rozdíl mezi rozlišeními (jemná mřížka): kde 0,5 m a 0,25 m nesouhlasí o výskytu
		for on in ["bez", "s"]:
			var a: PackedByteArray = ref["16_" + on]; var b2: PackedByteArray = ref["32_" + on]
			var d := 0
			for i in NF * NF: d += 1 if a[i] != b2[i] else 0
			e["rozdil_05_025_" + on] = d
			tot["rozdil_" + on] = int(tot.get("rozdil_" + on, 0)) + d
		var fd := 0
		if F16.size() == 32 * 32:
			var F16u := up(F16, 32, NF)
			for i in NF * NF: fd += 1 if F16u[i] != F64[i] else 0
		e["rozdil_05_025_fn"] = fd
		tot["rozdil_fn"] = int(tot.get("rozdil_fn", 0)) + fd
		e["sev_fn_025"] = seam(F64, NF)
		tot["kusu_fn_025"] = int(tot.get("kusu_fn_025", 0)) + int(e.kusu_fn_025)
		tot["kusu_fn_05"] = int(tot.get("kusu_fn_05", 0)) + int(e.kusu_fn_05)
		out.vrstvy.append(e)
		print("vrstva %d: sloupců %d, průměr %.2f m, hist %s, kusů fn %d | 0,5 bez: chybí %d, navíc %d, kusů %d | 0,25 bez: chybí %d, navíc %d, kusů %d | 0,5 s: chybí %d, kusů %d | 0,25 s: chybí %d, kusů %d | rozdíl rozlišení bez %d, s %d, funkce %d" % [
			m, tn, tsum / tn, str(hist), e.kusu_fn_025, e["16_bez"].chybi, e["16_bez"].navic, e["16_bez"].kusu, e["32_bez"].chybi, e["32_bez"].navic, e["32_bez"].kusu,
			e["16_s"].chybi, e["16_s"].kusu, e["32_s"].chybi, e["32_s"].kusu, e.rozdil_05_025_bez, e.rozdil_05_025_s, e.rozdil_05_025_fn])
	for key in G:
		tot[key]["k81"] = G[key].k81; tot[key]["ms"] = G[key].ms
	out.souhrn = tot
	print("souhrn: ", JSON.stringify(tot))
	return out

## podzemí: tělesa (propustná pásma) z funkcí proti tělesům z buněk; počet souvislých těles a díry v tenké nepropustné vrstvě
static func _ncomp(c: Dictionary) -> Dictionary:
	var nb_b: int = c.body.size()
	var par := PackedInt32Array(); par.resize(nb_b)
	for i in nb_b: par[i] = i
	var f := func(x: int) -> int:
		while par[x] != x: x = par[x]
		return x
	for b in nb_b:
		if c.body[b] == 0: continue
		for j in range(c.ns[b], c.ns[b + 1]):
			var b2: int = c.nb[j]
			if c.body[b2] == 0: continue
			var r1: int = f.call(b); var r2: int = f.call(b2)
			if r1 != r2: par[r1] = r2
	var roots := {}
	var vol := 0.0
	for b in nb_b:
		if c.body[b] == 1:
			roots[f.call(b)] = true; vol += (float(c.hi[b]) - float(c.lo[b])) * float(c.A)
	return {"teles": roots.size(), "pasem": c.body.count(1), "objem_m3": vol}

func part_voda() -> Dictionary:
	var out := {}
	var perm := FN.impermeable()
	for n: int in [16, 32]:
		var N: int = 2 * n; var nz: int = 4 * n; var c: float = BW / n
		var p: Dictionary = T.p.duplicate(); p.ug_cell_m3 = c * c * c
		# z funkcí: pásma přímo
		var cf := UG._new(N, N, c, p)
		cf.depth_m = float(p.ug_hloubka) * c; cf.leak_m2 = float(p.ug_leak_q) / (c * c)
		var mats := {}; var tops := {}
		for on in [false, true]: mats[on] = PackedByteArray(); mats[on].resize(N * N * nz); tops[on] = PackedInt32Array(); tops[on].resize(N * N)
		var hole := {false: 0, true: 0}; var thin_imp := 0
		for s in blks:
			var b = blks[s]
			for on in [false, true]:
				var info := info2(b, on)
				var cells: PackedByteArray = FN.sample_all(wf, info, n)
				var ox: float = info.slot.x * BW; var oy: float = info.slot.y * BW
				for x in n:
					for y in n:
						var gi: int = (s.x * n + x) * N + s.y * n + y
						var base: int = (x * n + y) * nz
						var tp := 0
						var have := {}
						for z in nz:
							var m := int(cells[base + z])
							mats[on][gi * nz + z] = m
							if m != 0: tp = z + 1
							have[m] = true
						tops[on][gi] = tp
						var X: float = ox + (x + 0.5) * c; var Y: float = oy + (y + 0.5) * c
						var col := FN.column(wf, info, X, Y)
						var bl := UG.bands(info, col, X, Y)
						if not on:
							cf.wall[gi] = 0; cf.h[gi] = col.h; cf.cols[gi] = bl
						for bd in bl:
							var t := float(bd[1]) - float(bd[0])
							if perm.has(int(bd[2])) and t > 0.05 and t < c:
								if not on: thin_imp += 1
								if not have.has(int(bd[2])): hole[on] += 1
		UG._finish(cf)
		var wall := PackedByteArray(); wall.resize(N * N)
		var r := {"fn": _ncomp(cf), "tenka_nepropustna_sloupcu": thin_imp}
		for on in [false, true]:
			var cc := UG.from_cells(N, N, nz, mats[on], tops[on], wall, p)
			r["bunky_" + ("s" if on else "bez")] = _ncomp(cc)
			r["diry_" + ("s" if on else "bez")] = hole[on]
		out[str(n)] = r
		print("voda n=%d: %s" % [n, JSON.stringify(r)])
	return out

func part_mineraly() -> Dictionary:
	var out := {}
	for n in [16, 32]:
		for on in [false, true]:
			var key := "%d_%s" % [n, "s" if on else "bez"]
			var agg := {}
			for s in blks:
				var b = blks[s]
				var info := info2(b, on)
				var cells: PackedByteArray = FN.sample_all(wf, info, n)
				for rep in FN.minerals(cells, n, wf, info, T.world.slots[T.wslot(b.slot)].bp.minerals, int(b.seed)):
					var k := str(rep.name)
					if not agg.has(k): agg[k] = {"hostitel": 0, "cil": 0, "umisteno": 0, "schodek": 0}
					agg[k].hostitel += int(rep.host_cells); agg[k].cil += int(rep.target)
					agg[k].umisteno += int(rep.get("placed", 0)); agg[k].schodek += int(rep.get("shortfall", 0))
			out[key] = agg
			print("minerály %s: %s" % [key, JSON.stringify(agg)])
	return out

## celý ostrov z pipeline (0,5 m) s příznakem a bez: změněné buňky, otisk vody, výchozí hra beze změny
func part_ostrov() -> Dictionary:
	var out := {}
	var geo0 := {}
	for on in [false, true]:
		T.reset(); T.p.p81_tenke = on
		if on and _arg("jen_bez", "") != "": continue
		var g := gen_blocks(START); var bl: Dictionary = g[0]
		var v := OV.new(); v.build(bl)
		var h: Dictionary = v.hydro()
		var diff := 0; var hsh := PackedByteArray()
		for s in g[1]:
			hsh.append_array(bl[s].geo)
			if on: diff += _ndiff(geo0[s], bl[s].geo)
			else: geo0[s] = bl[s].geo.duplicate()
		var key := "s" if on else "bez"
		out[key] = {"otisk_vody": h.otisk, "geo_hash": hsh.hex_encode().sha256_text().substr(0, 16), "zmenenych_bunek": diff}
		print("ostrov %s: %s" % [key, JSON.stringify(out[key])])
		v.dispose()
	T.p.p81_tenke = false
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/tenke_e81.gd": return
	T.reset()
	var g := gen_blocks(START)
	blks = g[0]
	wf = wf_all()
	var out := {}
	var parts := _arg("casti", "vyskyt,voda,mineraly,ostrov").split(",")
	if "vyskyt" in parts: out.vyskyt = part_vyskyt()
	if "voda" in parts: out.voda = part_voda()
	if "mineraly" in parts: out.mineraly = part_mineraly()
	if "ostrov" in parts: out.ostrov = part_ostrov()
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
