extends "res://tools/tenke_e81.gd"
## E82: vápenec k hladině v ~50 % bloků (mince podle seedu bloku, p82_vapenec). Části:
## --casti=podil,bloky,svy,kras --n=100 --out=cesta. Spouštět s --bp.p82_vapenec=true (část podil a bloky si přepínají samy).
const K75 = preload("res://scripts/voda/podzemi/kras75.gd")
const G2 = preload("res://scripts/teren/geo2.gd")
const DEN := 86400.0
const KINDS := ["louka", "kopec", "hora", "louka", "kopec", "sopka"]

func lime_id() -> int: return HR.id_of(str(T.p.get("p82_vrstva", "cave_limestone")))

## 1) podíl mincí „ano“ na seedech 1..1000 a na 1000 náhodných 31bitových seedech
func part_podil() -> Dictionary:
	var a := 0; var b := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 82
	for s in range(1, 1001):
		if G2.coin82(s, T.p): a += 1
		if G2.coin82(rng.randi() & 0x7FFFFFFF, T.p): b += 1
	var start := []
	for e in START.split(";"): start.append([e, G2.coin82(int(e.split(":")[2]), T.p)])
	print("podíl ano: seedy 1–1000 %d, náhodné %d; START %s" % [a, b, str(start)])
	return {"seedy_1_1000": a, "nahodne_1000": b, "start": start}

## statistika jednoho bloku: sloupce s vápencem v pásmu 1,0–2,0 m pod povrchem (odhad hladiny), vršek vápence pod povrchem
func lime_stats(b) -> Dictionary:
	var L := lime_id()
	var at := 0; var any := 0; var dsum := 0.0
	for ci in 256:
		var h := int(b.hm[ci]); var top := -1
		for z in range(h - 1, -1, -1):
			if b.geo[ci * 64 + z] == L: top = z; break
		if top < 0: continue
		any += 1; dsum += (h - 1 - top) * 0.5
		for z in range(maxi(h - 4, 0), maxi(h - 2, 0)):   # buňky 1,0–2,0 m pod povrchem
			if b.geo[ci * 64 + z] == L: at += 1; break
	return {"u_hladiny": at, "se_vapencem": any, "vrsek_pod_povrchem_m": dsum / maxi(any, 1)}

func geo_hash(blocks: Dictionary, order: Array) -> String:
	var a := PackedByteArray()
	for s in order: a.append_array(blocks[s].geo)
	return a.hex_encode().sha256_text().substr(0, 16)

## 2) jednotlivé bloky: n seedů × druh, s příznakem a bez; čas, podíl sloupců s vápencem u hladiny, determinismus
func part_bloky() -> Dictionary:
	var n := int(_arg("n", "100"))
	var res := {"ano": {"bloku": 0, "u_hladiny": 0, "se_vapencem": 0, "vrsek_m": 0.0}, "ne": {"bloku": 0, "u_hladiny": 0, "se_vapencem": 0, "vrsek_m": 0.0},
		"bez_priznaku": {"u_hladiny": 0, "se_vapencem": 0}, "ne_jine_nez_bez": 0, "ano_jine_nez_bez": 0, "ms_bez": 0.0, "ms_s": 0.0, "nedeterministicke": 0, "po_druzich": {}}
	var on0: bool = T.p.p82_vapenec
	for i in n:
		var seed := 1000 + i * 7
		var kind: String = KINDS[i % KINDS.size()]
		var spec := "0,0:%s:%d" % [kind, seed]
		var hs := {}
		for on in [false, true, true]:
			T.reset(); T.p.p82_vapenec = on
			var t0 := Time.get_ticks_usec()
			var g := gen_blocks(spec)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			var b = g[0][Vector2i(0, 0)]
			var h := geo_hash(g[0], g[1])
			if not on:
				res.ms_bez += ms; hs["bez"] = h
				var st0 := lime_stats(b)
				res.bez_priznaku.u_hladiny += st0.u_hladiny; res.bez_priznaku.se_vapencem += st0.se_vapencem
				continue
			if hs.has("s"):
				if hs["s"] != h: res.nedeterministicke += 1
				continue
			res.ms_s += ms; hs["s"] = h
			var yes := G2.coin82(seed, T.p)
			var key := "ano" if yes else "ne"
			var st := lime_stats(b)
			res[key].bloku += 1; res[key].u_hladiny += st.u_hladiny; res[key].se_vapencem += st.se_vapencem; res[key].vrsek_m += st.vrsek_pod_povrchem_m
			if h != hs["bez"]: res[key + "_jine_nez_bez"] += 1
			var pk := kind + "_" + key
			if not res.po_druzich.has(pk): res.po_druzich[pk] = [0, 0]
			res.po_druzich[pk][0] += 1; res.po_druzich[pk][1] += st.u_hladiny
	for k in ["ano", "ne"]: res[k].vrsek_m /= maxi(res[k].bloku, 1)
	T.p.p82_vapenec = on0
	print("bloky: ", JSON.stringify(res))
	return res

## ostrov 2 × 2 se smíšenými mincemi: seedy ano/ne/ne/ano
func mixed_spec(pattern: Array) -> String:
	var kinds := ["louka", "kopec", "louka", "louka"]
	var slots := ["0,0", "1,0", "0,1", "1,1"]
	var out := []
	var s := 500
	for i in 4:
		while G2.coin82(s, T.p) != pattern[i]: s += 1
		out.append("%s:%s:%d" % [slots[i], kinds[i], s]); s += 1
	return ";".join(out)

## 3) švy: skok funkcí na švu, materiál na švu proti uvnitř, profil vršku vápence od švu (ano blok vedle ne bloku), pořadí vložení
func svy(spec: String) -> Dictionary:
	T.reset()
	var g := gen_blocks(spec); var blocks: Dictionary = g[0]; var order: Array = g[1]
	wf = wf_all()
	var out := {"spec": spec}
	var jump := 0.0; var grad := 0.0
	var nk: int = T.world.slots[T.wslot(order[0])].bs.size()
	for pair in [[Vector2i(0, 0), Vector2i(1, 0), 0], [Vector2i(0, 1), Vector2i(1, 1), 0], [Vector2i(0, 0), Vector2i(0, 1), 1], [Vector2i(1, 0), Vector2i(1, 1), 1]]:
		var a: Vector2i = T.wslot(pair[0]); var c: Vector2i = T.wslot(pair[1]); var ax: int = pair[2]
		for t in 64:
			var u: float = (t + 0.5) * FN.BW / 64.0
			var S: float = (c.x if ax == 0 else c.y) * FN.BW
			var pA := Vector2(S - 1e-6, a.y * FN.BW + u) if ax == 0 else Vector2(a.x * FN.BW + u, S - 1e-6)
			var pB := Vector2(S + 1e-6, a.y * FN.BW + u) if ax == 0 else Vector2(a.x * FN.BW + u, S + 1e-6)
			var pI := pA - (Vector2(0.25, 0) if ax == 0 else Vector2(0, 0.25))
			for k in nk:
				jump = maxf(jump, absf(FN.boundary_m(wf, a, k, pA.x, pA.y) - FN.boundary_m(wf, c, k, pB.x, pB.y)))
				grad = maxf(grad, absf(FN.boundary_m(wf, a, k, pA.x, pA.y) - FN.boundary_m(wf, a, k, pI.x, pI.y)))
	out.skok_hranic_na_svu_m = jump; out.max_krok_0_25m_uvnitr_m = grad
	var seam := [0, 0]; var inner := [0, 0]
	for pair in [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(1, 1)]]:
		var A = blocks[pair[0]]; var B = blocks[pair[1]]
		for y in 16:
			for z in 64:
				var ma: int = A.geo[(15 * 16 + y) * 64 + z]; var mb: int = B.geo[(0 * 16 + y) * 64 + z]
				if ma == 0 and mb == 0: continue
				seam[1] += 1; if ma != mb: seam[0] += 1
				var mi: int = A.geo[(14 * 16 + y) * 64 + z]
				if ma == 0 and mi == 0: continue
				inner[1] += 1; if ma != mi: inner[0] += 1
	out.material_sev_proc = 100.0 * seam[0] / maxi(seam[1], 1); out.material_uvnitr_proc = 100.0 * inner[0] / maxi(inner[1], 1)
	# profil: vršek vápence pod povrchem (m) podle x přes šev (0,0)|(1,0) a (0,1)|(1,1), průměr přes y; buňky 0,5 m
	var L := lime_id()
	var prof := []
	for gx in 32:
		var dsum := 0.0; var cnt := 0; var lev := 0
		for row in 2:
			var s := Vector2i(gx / 16, row)
			var b = blocks[s]
			for y in 16:
				var ci: int = (gx % 16) * 16 + y
				var h := int(b.hm[ci])
				for z in range(h - 1, -1, -1):
					if b.geo[ci * 64 + z] == L:
						dsum += (h - 1 - z) * 0.5; cnt += 1
						if h - 1 - z <= 3: lev += 1
						break
		prof.append([gx, snappedf(dsum / maxi(cnt, 1), 0.01), cnt, lev])
	out.profil_x = prof
	out.mince = {}
	for e in spec.split(";"): out.mince[e] = G2.coin82(int(e.split(":")[2]), T.p)
	out.stats = {}
	for s in order: out.stats[str(s)] = lime_stats(blocks[s])
	var h1 := geo_hash(blocks, order)
	# pořadí vložení obráceně
	var parts := spec.split(";"); parts.reverse()
	T.reset()
	var g2 := gen_blocks(";".join(parts))
	var d := 0
	for s in order: d += _ndiff(blocks[s].geo, g2[0][s].geo)
	out.obracene_poradi_jinych_bunek = d
	T.reset()
	var g3 := gen_blocks(spec)
	out.znovu_stejny_hash = geo_hash(g3[0], g3[1]) == h1
	out.geo_hash = h1
	print("švy %s: skok %s m (krok uvnitř %.3f), materiál šev %.1f %% / uvnitř %.1f %%, obráceně jiných %d, znovu stejné %s, bloky %s" % [spec, String.num_scientific(jump), grad, out.material_sev_proc, out.material_uvnitr_proc, d, out.znovu_stejny_hash, JSON.stringify(out.stats)])
	print("  profil x [gx, vršek vápence pod povrchem m, sloupců, ≤1,5 m]: ", JSON.stringify(prof))
	return out

func part_svy82() -> Dictionary:
	var out := {}
	out.smiseny = svy(mixed_spec([true, false, false, true]))
	out.ano_ne = svy(mixed_spec([true, false, true, false]))
	out.start = svy(START)
	return out

## 4) kras E75 na ostrovech: rozpustná pásma na cestách těles, rychlost, první dutina, ve kterých blocích
func kras(spec: String, on := true, e67 := false, quiet := false) -> Dictionary:
	T.reset(); T.p.p75_kras = true; T.p.p82_vapenec = on
	if e67: T.p.p67_rezim = "pretok"; T.p.p67_okraj = true
	var g := gen_blocks(spec); var blocks: Dictionary = g[0]
	var t0 := Time.get_ticks_usec()
	var v := OV.new(); v.build(blocks)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var out := {"spec": spec, "voda_ms": ms, "pasem": v.kras.rate.size() if not v.kras.is_empty() else 0}
	var tot := 0.0; var per_slot := {}; var per_mat := {}
	var ug: Dictionary = v.ug
	var r: int = v.W / int(ug.W)
	for b in v.kras.get("rate", {}):
		var q := float(v.kras.rate[b]); tot += q
		var cc: int = ug.bcol[b]
		var gx: int = (cc / int(ug.W)) * r; var gy: int = (cc % int(ug.W)) * r
		var a := v.slot_of(gx * v.H + gy)
		var key := str(a[0]) + (" ano" if G2.coin82(int(blocks[a[0]].seed), T.p) else " ne") if blocks.has(a[0]) else "mimo"
		per_slot[key] = float(per_slot.get(key, 0.0)) + q
		var mk := jmeno(int(v.kras.mat[b]))
		per_mat[mk] = float(per_mat.get(mk, 0.0)) + q
	var ne := K75.next_event(v.kras) if not v.kras.is_empty() else [INF, -1]
	out.rychlost_m3_den = tot * DEN; out.po_blocich_m3_den = {}
	for k in per_slot: out.po_blocich_m3_den[k] = per_slot[k] * DEN
	out.po_materialech_m3_den = {}
	for k in per_mat: out.po_materialech_m3_den[k] = per_mat[k] * DEN
	out.prvni_dutina_dni = float(ne[0]) / DEN
	out.otisk_vody = v.hydro().otisk
	var bodies: Array = v.st.get("ug_bodies", [])
	out.teles = bodies.size(); var qin := 0.0
	for bd in bodies: qin += float(bd.q_in)
	out.pritok_l_s = qin
	out.pramenu = v.springs.size()
	if not quiet: print("kras %s: pásem %d, %s m³/den, bloky %s, materiály %s, 1. dutina %.1f dne, těles %d, přítok %.3f l/s, pramenů %d, voda %.0f ms" % [spec, out.pasem, String.num_scientific(out.rychlost_m3_den), JSON.stringify(out.po_blocich_m3_den), JSON.stringify(out.po_materialech_m3_den), out.prvni_dutina_dni, out.teles, qin, out.pramenu, ms])
	v.dispose()
	T.p.p75_kras = false
	return out

func part_kras() -> Dictionary:
	var out := {}
	for e67 in [false, true]:
		var m := "e67" if e67 else "e58"
		out[m] = {}
		out[m].start = kras(START, true, e67)
		out[m].smiseny = kras(mixed_spec([true, false, false, true]), true, e67)
		out[m].vse_ano = kras(mixed_spec([true, true, true, true]), true, e67)
		out[m].vse_ne = kras(mixed_spec([false, false, false, false]), true, e67)
	return out

## 5) mnoho ostrovů 2 × 2 s náhodnými seedy: rozpouštění v blocích ano / ne, s příznakem a bez, režim E58 a E67
func part_ostrovy() -> Dictionary:
	var n := int(_arg("ostrovu", "20"))
	var rng := RandomNumberGenerator.new(); rng.seed = 8282
	var kinds := ["louka", "kopec", "louka", "hora"]
	var specs := []
	for i in n:
		var a := []
		for sl in ["0,0", "1,0", "0,1", "1,1"]: a.append("%s:%s:%d" % [sl, kinds[rng.randi_range(0, 3)], rng.randi_range(1, 99999)])
		specs.append(";".join(a))
	var out := {}
	for e67 in [false, true]:
		for on in [false, true]:
			var key := "%s_%s" % ["e67" if e67 else "e58", "s" if on else "bez"]
			var agg := {"ostrovu_s_krasem": 0, "pasem": 0, "m3_den_ano": 0.0, "m3_den_ne": 0.0, "bloku_ano_s_krasem": 0, "bloku_ne_s_krasem": 0, "bloku_ano": 0, "bloku_ne": 0, "dutina_dni": []}
			for sp in specs:
				var r := kras(sp, on, e67, true)
				var yes := 0
				for e in sp.split(";"):
					if G2.coin82(int(e.split(":")[2]), T.p): agg.bloku_ano += 1
					else: agg.bloku_ne += 1
				if int(r.pasem) > 0: agg.ostrovu_s_krasem += 1
				agg.pasem += int(r.pasem)
				for k in r.po_blocich_m3_den:
					if k.ends_with(" ano"): agg.m3_den_ano += float(r.po_blocich_m3_den[k]); agg.bloku_ano_s_krasem += 1
					elif k.ends_with(" ne"): agg.m3_den_ne += float(r.po_blocich_m3_den[k]); agg.bloku_ne_s_krasem += 1
				if float(r.prvni_dutina_dni) < INF: agg.dutina_dni.append(snappedf(float(r.prvni_dutina_dni), 0.1))
			out[key] = agg
			print("ostrovy %s: %s" % [key, JSON.stringify(agg)])
	return out

func _init() -> void:
	if get_script().resource_path != "res://tools/vapenec_e82.gd": return
	T.reset()
	var out := {"p82": {"podil": T.p.p82_podil, "pod_m": T.p.p82_pod_m, "vrstva": T.p.p82_vrstva, "kraj": T.p.p82_kraj, "zapnuto": T.p.p82_vapenec}}
	var parts := _arg("casti", "podil,bloky,svy,kras,ostrovy").split(",")
	if "podil" in parts: out.podil = part_podil()
	if "bloky" in parts: out.bloky = part_bloky()
	if "svy" in parts: out.svy = part_svy82()
	if "kras" in parts: out.kras = part_kras()
	if "ostrovy" in parts: out.ostrovy = part_ostrovy()
	var path := _arg("out", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(out, "  ")); f.close()
	quit()
