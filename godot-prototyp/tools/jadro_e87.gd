extends SceneTree
## E87: jádro vyzdvižené hory přes více bloků. Scénáře masivu (2 × 2 ve dvou pořadích, masiv vedle kopce a louky, hřbet 3 × 1)
## bez a s p87_jadro_hory: skoky na švech (povrch, vršek jádra, hranice vrstev), sedlo masivu na švu, jádro na povrchu,
## vytlačené vrstvy, neshoda buněk přes šev, minerály, voda (E74 výchozí a E67), stejné buňky v jiném pořadí,
## 0,25 m (změna buněk bloku po přidání sousedů, krok na švu), čas generování, otisk buněk.
## Volby: --p87=0,1 --sc=masiv2x2,vedle,hreben --voda=1 --jemne=1 --out=cesta --bp.<klíč>=hodnota
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const OV = preload("res://scripts/voda/ostrov_voda.gd")
const FN = preload("res://scripts/teren/geo_fn.gd")
const HR = preload("res://scripts/teren/horniny.gd")
const SD = preload("res://scripts/teren/sides.gd")

const HV := "hora_vyzdvizena"
var SC := {
	"masiv2x2": ["0,0:%s:811;1,0:%s:812;0,1:%s:813;1,1:%s:814" % [HV, HV, HV, HV], "1,1:%s:814;0,1:%s:813;1,0:%s:812;0,0:%s:811" % [HV, HV, HV, HV]],
	"vedle": ["0,0:%s:811;1,0:%s:812;0,1:kopec:303;1,1:louka:404" % [HV, HV], "0,1:kopec:303;1,1:louka:404;0,0:%s:811;1,0:%s:812" % [HV, HV]],
	"hreben": ["-1,0:%s:821;0,0:%s:822;1,0:%s:823" % [HV, HV, HV], "1,0:%s:823;-1,0:%s:821;0,0:%s:822" % [HV, HV, HV]],
}

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func gen_blocks(spec: String) -> Array:   # [bloky, pořadí]
	var blocks := {}; var order := []
	for e in spec.split(";"):
		var a := e.split(":"); var xy := a[0].split(",")
		var b := Block.new(); b.kind = a[1]; b.seed = int(a[2]); b.slot = Vector2i(int(xy[0]), int(xy[1]))
		BlockGen.build(b, [null, null, null, null]); T.commit(b); blocks[b.slot] = b; order.append(b.slot)
	return [blocks, order]

func core_k() -> int:
	return HR.pool_zone(HR.ZONES[0], T.p).size() + HR.pool_zone(HR.ZONES[1], T.p).size() - 1

static func geo_hash(blocks: Dictionary) -> String:
	var ks := blocks.keys(); ks.sort()
	var hc := HashingContext.new(); hc.start(HashingContext.HASH_SHA256)
	for s in ks: hc.update(blocks[s].geo)
	return hc.finish().hex_encode().substr(0, 16)

func block_stats(b, kc: int) -> Dictionary:
	var r: Dictionary = b.bp_rec
	var mx := -1e9; var mean := 0.0; var core_top := 0; var inner_step := 0.0; var inner_sum := 0.0; var inner_n := 0
	for x in 16:
		for y in 16:
			var i := x * 16 + y; var h: float = r.hm_f[i]
			mx = maxf(mx, h); mean += h / 256.0
			if float(r.bs[kc][i]) >= h - 0.5: core_top += 1
			if x < 15:
				var d := absf(h - r.hm_f[i + 16]); inner_step = maxf(inner_step, d); inner_sum += d; inner_n += 1
			if y < 15:
				var d := absf(h - r.hm_f[i + 1]); inner_step = maxf(inner_step, d); inner_sum += d; inner_n += 1
	var short := 0; var placed := 0; var target := 0
	for m in r.rep.get("minerals", []): short += int(m.shortfall); placed += int(m.placed); target += int(m.target)
	return {"typ": b.kind, "max_u": mx, "prumer_u": mean, "jadro_na_povrchu": core_top, "krok_uvnitr_max_u": inner_step, "krok_uvnitr_prumer_u": inner_sum / inner_n,
		"mineraly": "%d/%d" % [placed, target], "schodek": short, "gen_ms": b.gen_ms}

func seam(A, B, d: int, kc: int) -> Dictionary:
	var ra: Dictionary = A.bp_rec; var rb: Dictionary = B.bp_rec
	var o := {"povrch_max_u": 0.0, "povrch_prumer_u": 0.0, "jadro_max_u": 0.0, "vrstvy_max_u": 0.0, "bunky_jinak": 0.0, "sev_vyska_prumer_u": 0.0,
		"jadro_na_povrchu_sev": 0, "vytlacene_sev": 0, "vytlacene_vnitrek": 0, "krok_dovnitr_prumer_u": 0.0,
		"jadro_dovnitr_max_u": 0.0, "vrstvy_dovnitr_max_u": 0.0, "bunky_dovnitr_jinak": 0.0}
	var in_n := 0; var in_d := 0
	var nl: int = ra.bs.size()
	var cells_n := 0; var cells_d := 0
	for t in 16:
		var a := SD.own(d, t); var c := SD.nb(d, t)
		var ia := a.x * 16 + a.y; var ib := c.x * 16 + c.y
		var a2: Vector2i = a - SD.DIRS[d]; var b2: Vector2i = c + SD.DIRS[d]
		var ds := absf(ra.hm_f[ia] - rb.hm_f[ib])
		o.povrch_max_u = maxf(o.povrch_max_u, ds); o.povrch_prumer_u += ds / 16.0
		o.krok_dovnitr_prumer_u += (absf(ra.hm_f[ia] - ra.hm_f[a2.x * 16 + a2.y]) + absf(rb.hm_f[ib] - rb.hm_f[b2.x * 16 + b2.y])) / 32.0
		o.sev_vyska_prumer_u += (ra.hm_f[ia] + rb.hm_f[ib]) / 32.0
		o.jadro_max_u = maxf(o.jadro_max_u, absf(ra.bs[kc][ia] - rb.bs[kc][ib]))
		if float(ra.bs[kc][ia]) >= ra.hm_f[ia] - 0.5: o.jadro_na_povrchu_sev += 1
		if float(rb.bs[kc][ib]) >= rb.hm_f[ib] - 0.5: o.jadro_na_povrchu_sev += 1
		var ia2 := a2.x * 16 + a2.y
		o.jadro_dovnitr_max_u = maxf(o.jadro_dovnitr_max_u, absf(ra.bs[kc][ia] - ra.bs[kc][ia2]))
		for z in mini(A.hm[ia], A.hm[ia2]):
			in_n += 1
			if A.geo[ia * 64 + z] != A.geo[ia2 * 64 + z]: in_d += 1
		for k in nl:
			o.vrstvy_dovnitr_max_u = maxf(o.vrstvy_dovnitr_max_u, absf(ra.bs[k][ia] - ra.bs[k][ia2]))
			o.vrstvy_max_u = maxf(o.vrstvy_max_u, absf(ra.bs[k][ia] - rb.bs[k][ib]))
			var tha: float = ra.bs[k][ia] - (0.0 if k == 0 else ra.bs[k - 1][ia])
			var thb: float = rb.bs[k][ib] - (0.0 if k == 0 else rb.bs[k - 1][ib])
			var tha2: float = ra.bs[k][a2.x * 16 + a2.y] - (0.0 if k == 0 else ra.bs[k - 1][a2.x * 16 + a2.y])
			if (tha < 0.05) != (thb < 0.05): o.vytlacene_sev += 1        # vrstva na jedné straně švu je, na druhé ne
			if (tha < 0.05) != (tha2 < 0.05): o.vytlacene_vnitrek += 1   # totéž o sloupec dovnitř (srovnání)
		var top := mini(A.hm[ia], B.hm[ib])
		for z in top:
			cells_n += 1
			if A.geo[ia * 64 + z] != B.geo[ib * 64 + z]: cells_d += 1
	o.bunky_jinak = float(cells_d) / maxf(cells_n, 1)
	o.bunky_dovnitr_jinak = float(in_d) / maxf(in_n, 1)
	return o

func seams(blocks: Dictionary, kc: int) -> Dictionary:
	var out := {}
	for s in blocks:
		for d in [1, 2]:
			var n: Vector2i = s + SD.DIRS[d]
			if blocks.has(n): out["%s|%s" % [s, n]] = seam(blocks[s], blocks[n], d, kc)
	return out

## 0,25 m: buňky bloku ze světa jen s bloky položenými do té doby proti celému světu; krok povrchu na švu proti uvnitř
func fine(blocks: Dictionary, order: Array) -> Dictionary:
	var out := {"zmena_po_sousedech": {}, "sev_krok_max_m": 0.0, "uvnitr_krok_max_m": 0.0, "hrube_jemne_max_m": 0.0}
	var all := {}
	for s in order: all[T.wslot(s)] = blocks[s].bp_rec
	var wf_all := FN.world_fn(all)
	var fine_h := {}
	var t0 := Time.get_ticks_usec()
	for k in order.size():
		var s: Vector2i = order[k]; var ws := T.wslot(s)
		var part := {}
		for j in k + 1: part[T.wslot(order[j])] = blocks[order[j]].bp_rec
		var wf_p := FN.world_fn(part)
		var rec: Dictionary = blocks[s].bp_rec
		var c1 := FN.sample_all(wf_p, FN.block_info(wf_p, ws, rec.bp, T.p), 32)
		var c2 := FN.sample_all(wf_all, FN.block_info(wf_all, ws, rec.bp, T.p), 32)
		var dn := 0
		for i in c1.size(): if c1[i] != c2[i]: dn += 1
		out.zmena_po_sousedech[str(s)] = dn
		var h := PackedFloat64Array(); h.resize(1024)
		for i in 1024:
			var z := 127
			while z >= 0 and c2[i * 128 + z] == 0: z -= 1
			h[i] = (z + 1) * 0.25
		fine_h[s] = h
		for x in 32:
			for y in 32:
				if x < 31: out.uvnitr_krok_max_m = maxf(out.uvnitr_krok_max_m, absf(h[x * 32 + y] - h[(x + 1) * 32 + y]))
				if y < 31: out.uvnitr_krok_max_m = maxf(out.uvnitr_krok_max_m, absf(h[x * 32 + y] - h[x * 32 + y + 1]))
				out.hrube_jemne_max_m = maxf(out.hrube_jemne_max_m, absf(h[x * 32 + y] - blocks[s].hm[(x / 2) * 16 + y / 2] * 0.5))
	out.ms_vzorek_32 = (Time.get_ticks_usec() - t0) / 1000.0 / maxf(order.size(), 1) / 2.0
	for s in fine_h:
		for d in [1, 2]:
			var n: Vector2i = s + SD.DIRS[d]
			if not fine_h.has(n): continue
			for t in 32:
				var a := Vector2i(t, 31) if d == 2 else Vector2i(31, t); var b := Vector2i(t, 0) if d == 2 else Vector2i(0, t)
				out.sev_krok_max_m = maxf(out.sev_krok_max_m, absf(fine_h[s][a.x * 32 + a.y] - fine_h[n][b.x * 32 + b.y]))
	return out

func water(blocks: Dictionary, e67: bool) -> Dictionary:
	if e67: T.p.p67_okraj = true; T.p.p67_rezim = "pretok"
	var v := OV.new(); var t0 := Time.get_ticks_usec(); v.build(blocks)
	var h: Dictionary = v.hydro()
	var o := {"ms": (Time.get_ticks_usec() - t0) / 1000.0, "otisk": h.otisk, "chyba_svet": h.bilance.chyba_svet, "souhrn": v.summary(), "zdroje": h.bilance.zdroje, "okraj": h.bilance.okraj}
	v.dispose()
	if e67: T.p.p67_okraj = false; T.p.p67_rezim = ""
	return o

func _init() -> void:
	BlockGen.gen_version = "bp"
	var res := {}
	for fl in _arg("p87", "0,1").split(","):
		var on := fl == "1"
		res["p87_" + fl] = {}
		for name in _arg("sc", "masiv2x2,vedle,hreben").split(","):
			var e := {}
			var geos := []
			for oi in 2:
				T.reset()
				T.p.p87_jadro_hory = on
				var g := gen_blocks(SC[name][oi])
				var blocks: Dictionary = g[0]; var order: Array = g[1]
				var kc := core_k()
				var bst := {}
				for s in blocks: bst[str(s)] = block_stats(blocks[s], kc)
				var r := {"poradi": SC[name][oi], "bloky": bst, "svy": seams(blocks, kc), "otisk_bunek": geo_hash(blocks)}
				geos.append(blocks)
				if oi == 0:
					if _arg("jemne", "1") == "1": r.jemne = fine(blocks, order)
					if _arg("voda", "1") == "1": r.voda = water(blocks, false); r.voda67 = water(blocks, true)
				e["poradi_%d" % oi] = r
				# výpis
				var sm: Dictionary = r.svy
				var ps := []
				for k in sm: ps.append("%s povrch %.2f/%.2f U (dovnitř %.2f), sedlo výška %.1f, jádro %.2f U (dovnitř %.2f), vrstvy %.2f U (dovnitř %.2f), jádro na povrchu %d/32, vytlačené %d (dovnitř %d), buňky jinak %.1f %% (dovnitř %.1f %%)" % [k, sm[k].povrch_max_u, sm[k].povrch_prumer_u, sm[k].krok_dovnitr_prumer_u, sm[k].sev_vyska_prumer_u, sm[k].jadro_max_u, sm[k].jadro_dovnitr_max_u, sm[k].vrstvy_max_u, sm[k].vrstvy_dovnitr_max_u, sm[k].jadro_na_povrchu_sev, sm[k].vytlacene_sev, sm[k].vytlacene_vnitrek, sm[k].bunky_jinak * 100.0, sm[k].bunky_dovnitr_jinak * 100.0])
				print("p87 %s %s pořadí %d otisk %s" % [on, name, oi, r.otisk_bunek])
				for s in bst: print("   blok %s %s: max %.1f U, průměr %.1f U, jádro na povrchu %d/256, krok uvnitř max %.2f U, minerály %s, schodek %d, %.0f ms" % [s, bst[s].typ, bst[s].max_u, bst[s].prumer_u, bst[s].jadro_na_povrchu, bst[s].krok_uvnitr_max_u, bst[s].mineraly, bst[s].schodek, bst[s].gen_ms])
				for l in ps: print("   šev ", l)
				if r.has("jemne"): print("   0,25 m: změna buněk po přidání sousedů %s, krok na švu max %.2f m, uvnitř max %.2f m, hrubé vs jemné max %.2f m, vzorek 32 %.0f ms/blok" % [str(r.jemne.zmena_po_sousedech), r.jemne.sev_krok_max_m, r.jemne.uvnitr_krok_max_m, r.jemne.hrube_jemne_max_m, r.jemne.ms_vzorek_32])
				if r.has("voda"): print("   voda E74: %s chyba %s otisk %s | E67: %s chyba %s otisk %s" % [str(r.voda.souhrn), str(r.voda.chyba_svet), r.voda.otisk, str(r.voda67.souhrn), str(r.voda67.chyba_svet), r.voda67.otisk])
			# stejné buňky v obou pořadích
			var diff := {}
			for s in geos[0]:
				var a: PackedByteArray = geos[0][s].geo; var b: PackedByteArray = geos[1][s].geo
				var n := 0
				for i in a.size(): if a[i] != b[i]: n += 1
				diff[str(s)] = n
			e.poradi_neshod_bunek = diff
			print("   pořadí 0 vs 1: neshod buněk po blocích %s" % str(diff))
			res["p87_" + fl][name] = e
	var path := _arg("out", "")
	if path != "": FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE).store_string(JSON.stringify(res, " "))
	quit()
