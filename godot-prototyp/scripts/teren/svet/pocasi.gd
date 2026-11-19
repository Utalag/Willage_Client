extends RefCounted
## KOPIE z blueprint-studie/scripts/svet8/pocasi.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E49 fáze 2: jednoduché počasí. Západní vítr (od x = 0): vlhkost vzduchu prší víc tam, kde terén stoupá (návětří),
## ubývá s deštěm a pomalu se doplňuje; za horami srážkový stín. Teplota klesá s výškou. Srážky 0..1 po rozmazání 3 × 3 (95. percentil = 1).

static func run(t: Dictionary, p: Dictionary) -> Dictionary:
	var R: int = t.R; var hm: PackedFloat64Array = t.hm
	var rain := PackedFloat64Array(); rain.resize(R * R)
	for y in R:
		var m := 1.0
		for x in R:
			var rise := maxf(hm[x * R + y] - (hm[(x - 1) * R + y] if x > 0 else hm[x * R + y]), 0.0)
			var r := m * (float(p.s8_rain_base) + float(p.s8_rain_oro) * rise)
			rain[x * R + y] = r
			m = clampf(m - r * float(p.s8_rain_use) + float(p.s8_rain_recharge), 0.0, 1.0)
	var bl := PackedFloat64Array(); bl.resize(R * R)
	var mx := 1e-9
	for x in R:
		for y in R:
			var s := 0.0; var n := 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var qx := x + dx; var qy := y + dy
					if qx >= 0 and qy >= 0 and qx < R and qy < R: s += rain[qx * R + qy]; n += 1
			bl[x * R + y] = s / n; mx = maxf(mx, s / n)
	var srt := Array(bl); srt.sort()
	mx = maxf(float(srt[int(srt.size() * 0.95)]), 1e-9)   # normalizace na 95. percentil (jinak návětří hor přebije vše)
	var temp := PackedFloat64Array(); temp.resize(R * R)
	for i in R * R:
		bl[i] = minf(bl[i] / mx, 1.0)
		temp[i] = clampf(1.0 - (hm[i] - 30.0) / 28.0, 0.0, 1.0)
	return {"rain": bl, "temp": temp}
