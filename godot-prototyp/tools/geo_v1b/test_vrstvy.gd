extends RefCounted
## Vrstvy: žádné křížení (z0 ≥ z1 předchozí, spojité od z = 0), definice ≥ 0,25 m, součet = výška tvaru (E81),
## mince E82 váže na vyska_tvar − 2 m (ne na vodu). Celé bloky 128 m, sloupce po kroku_xy.
const S = preload("res://scripts/v1/svet_fn.gd")
const VAPENEC := [5, 44, 49]
const EPS := 1e-6

func sken(svet, bloky: Array, krok_xy: float) -> Dictionary:
	var st := {"sloupcu": 0, "vrstev": 0, "krizeni": 0, "mezery": 0, "pod_025": 0, "nad_H4": 0, "souctu_zle": 0,
		"coin_sloupcu": 0, "coin_vapenec": 0, "coin_na_cili": 0, "min_def": 1e9, "pripady": []}
	var n := int(128.0 / krok_xy)
	for b in bloky:
		for i in n:
			for j in n:
				var x := int(b[0]) * 128.0 + (i + 0.5) * krok_xy
				var y := int(b[1]) * 128.0 + (j + 0.5) * krok_xy
				var hr: Array = svet.geo.hranice(x, y)
				var zt: float = float(svet.vyska_tvar(x, y))
				var Hgt := maxf(zt, 0.25)
				st.sloupcu += 1
				var z_prev := 0.0
				var suma_def := 0.0
				for k in hr.size():
					var e: Dictionary = hr[k]
					st.vrstev += 1
					if float(e.z1) <= float(e.z0) + 1e-12 or float(e.z0) < z_prev - EPS:
						st.krizeni += 1
						if st.pripady.size() < 5: st.pripady.append({"x": x, "y": y, "k": k, "z0": e.z0, "z1": e.z1, "prev": z_prev})
					elif float(e.z0) > z_prev + EPS:
						st.mezery += 1
					z_prev = float(e.z1)
					var d := float(e.definice_m)
					suma_def += d
					st.min_def = minf(st.min_def, d)
					if d < 0.25 - EPS: st.pod_025 += 1
					if d > 0.25 * Hgt + EPS: st.nad_H4 += 1
				if absf(suma_def - Hgt) > 1e-6: st.souctu_zle += 1
				if svet.geo.mince82(x, y) and zt - float(svet.p.p82_pod_m) >= 0.25:
					st.coin_sloupcu += 1
					var z := 0.0
					var z_top := -1.0
					for e in hr:
						z = float(e.z0) + float(e.definice_m)
						if int(e.id) in VAPENEC: z_top = z
					if z_top >= 0.0:
						st.coin_vapenec += 1
						if absf(z_top - (zt - float(svet.p.p82_pod_m))) < 1e-6: st.coin_na_cili += 1
	return st

func run(par: Dictionary, bloky: Array, krok_xy: float) -> Dictionary:
	var pa := par.duplicate(); pa["a1_hostitele"] = true; pa["a10_sum_hornin"] = true
	var pv := par.duplicate(); pv["a1_hostitele"] = false; pv["a10_sum_hornin"] = false
	var po := sken(S.new(pa), bloky, krok_xy)
	var pred := sken(S.new(pv), bloky, krok_xy)
	var ok: bool = po.krizeni == 0 and po.mezery == 0 and po.pod_025 == 0 and po.souctu_zle == 0
	print("vrstvy po:   ", po)
	print("vrstvy před: ", pred)
	print("vrstvy ", "PROŠLO" if ok else "SELHALO")
	return {"po": po, "pred": pred, "ok": ok}
