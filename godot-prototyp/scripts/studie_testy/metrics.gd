extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/metrics.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Metriky švů z BUNĚK (stejně pro všechny varianty): pro každý sloupec výška rozhraní I_k = počet buněk vrstev 0..k
## (čedič, žula, vápenec, jíl, písek; buňka rudy patří do vrstvy pod ní). Skok na švu = |I_k(a) − I_k(b)| pro dvojice
## přiléhajících sloupců přes stranu bloku; reference = stejný skok mezi sousedními sloupci uvnitř bloků.

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const R = preload("res://scripts/teren/region.gd")
const SD = preload("res://scripts/teren/sides.gd")
const HT = preload("res://scripts/teren/hostitele.gd")

## minerál s jediným hostitelem patří do vrstvy hostitele (měď → žula, ložiskový jíl → jíl), jinak do vrstvy pod ním
static func _host_layer(layers: Array) -> PackedInt32Array:
	var o := PackedInt32Array(); o.resize(256); o.fill(-1)
	var t := HT.table()
	for m in t:
		if t[m].host.size() == 1:
			o[m] = layers.find(t[m].host[0])
	return o

## layers = MaterialId vrstev zdola nahoru (v1: R.LAYERS, v2: aktivní vrstvy tabulky pořadí); ignore = nevrstvové buňky (půda, sníh …)
static func interfaces(cells: PackedByteArray, layers: Array = R.LAYERS, ignore: Array = [Mat.AIR, Mat.GRASS, Mat.DIRT]) -> Array:
	var K := layers.size()
	var lut := PackedInt32Array(); lut.resize(256); lut.fill(-1)
	for i in K:
		lut[layers[i]] = i
	var hl := _host_layer(layers)
	var out := []
	for k in K:
		var a := PackedInt32Array(); a.resize(256); out.append(a)
	for col in 256:
		var cur := -1
		var cnt := PackedInt32Array(); cnt.resize(K)
		for z in 64:
			var m := cells[col * 64 + z]
			var li: int = lut[m]
			if li < 0 and hl[m] >= 0:
				li = hl[m]
			if li >= 0:
				cur = li
			elif m in ignore:
				continue
			if cur >= 0:
				cnt[cur] += 1
		var acc := 0
		for k in K:
			acc += cnt[k]
			out[k][col] = acc
	return out

## slots: {Vector2i: {cells, hm}} → {seam: [průměr po k], seam_max, inner: [průměr po k], surf_seam, surf_inner, pairs}
static func seams(slots: Dictionary, hm_key := "hm", layers: Array = R.LAYERS, ignore: Array = [Mat.AIR, Mat.GRASS, Mat.DIRT]) -> Dictionary:
	var K := layers.size()
	var I := {}
	for s in slots:
		I[s] = interfaces(slots[s].cells, layers, ignore)
	var seam := PackedFloat64Array(); seam.resize(K)
	var smax := PackedInt32Array(); smax.resize(K)
	var inner := PackedFloat64Array(); inner.resize(K)
	var ns := 0; var ni := 0
	var ss := 0.0; var si := 0.0; var smx := 0
	for s in slots:
		var hm: PackedInt32Array = slots[s][hm_key]
		# uvnitř: dvojice (x, y)–(x + 1, y)
		for x in 15:
			for y in 16:
				var a := x * 16 + y; var b := (x + 1) * 16 + y
				for k in K:
					inner[k] += absi(I[s][k][a] - I[s][k][b])
				si += absi(hm[a] - hm[b]); ni += 1
		# šev s východním sousedem (V) a jižním (J), každý šev jednou
		for d in [1, 2]:
			var n: Vector2i = s + SD.DIRS[d]
			if not slots.has(n):
				continue
			var hn: PackedInt32Array = slots[n][hm_key]
			for t in 16:
				var o := SD.own(d, t); var q := SD.nb(d, t)
				var a := o.x * 16 + o.y; var b := q.x * 16 + q.y
				for k in K:
					var j := absi(I[s][k][a] - I[n][k][b])
					seam[k] += j; smax[k] = maxi(smax[k], j)
				var dj := absi(hm[a] - hn[b])
				ss += dj; smx = maxi(smx, dj); ns += 1
	for k in K:
		seam[k] /= maxi(ns, 1); inner[k] /= maxi(ni, 1)
	return {"layers": layers, "seam": seam, "seam_max": smax, "inner": inner, "surf_seam": ss / maxi(ns, 1), "surf_seam_max": smx,
		"surf_inner": si / maxi(ni, 1), "pairs": ns}

static func fmt(m: Dictionary) -> String:
	var a := []
	for k in m.layers.size():
		a.append("%s %.2f/%d (uvnitř %.2f)" % [HT.name_of(m.layers[k]), m.seam[k], m.seam_max[k], m.inner[k]])
	return "švy vrstev průměr/max: " + ", ".join(a) + " | povrch šev %.2f/max %d (uvnitř %.2f), dvojic %d" % [m.surf_seam, m.surf_seam_max, m.surf_inner, m.pairs]

static func mean_seam(m: Dictionary) -> float:
	var s := 0.0
	for k in m.layers.size():
		s += m.seam[k]
	return s / m.layers.size()

static func mean_inner(m: Dictionary) -> float:
	var s := 0.0
	for k in m.layers.size():
		s += m.inner[k]
	return s / m.layers.size()
