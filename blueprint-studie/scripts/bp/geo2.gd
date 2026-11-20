extends RefCounted
## Geologie v2 podle tabulky pořadí hornin (data/poradi_hornin.json, Gemini pro Jana [10]).
## Regionální deska (svět): tři zóny (plášť, krystalinikum, sedimenty) s vlnitými hranicemi; v každé zóně aktivní vrstvy
## v pořadí tabulky, tloušťka = váha × přítomnost (šum ve světových souřadnicích, freq = podíl plochy) → v daném místě
## jen podmnožina hornin, pořadí zachované, hranice spojité přes bloky.
## Tvar terénu (Jan 16:31): pod vyvýšenou částí blueprintu se hluboké zóny ZVEDNOU (zdvih u = vyhlazené převýšení nad
## surf_ref), sedimenty se nad zdvihem ztenčí (exp(−u/λ)) a povrch je prořízne; hora = jádro z krystalinika až k vrcholu,
## jen tenká suť / horniny hor podle výšky, sníh nahoře; kopec = mírný zdvih, sedimenty se ohnou přes něj;
## prohlubeň = vrstvy se prohnou dolů. Pak navázání na sousedy (Laplace) jako v1, takže švy zůstanou spojité.

const Mat = preload("res://scripts/kopie/mat.gd")
const BG = preload("res://scripts/kopie/block_gen.gd")
const H = preload("res://scripts/kopie/stable_hash.gd")
const Ore = preload("res://scripts/kopie/ore_v0.gd")
const HR = preload("res://scripts/bp/horniny.gd")

static var _nc := {}

static func _noise(seed: int, purpose: String, k: int, freq: float) -> FastNoiseLite:
	var key := "%d_%s_%d_%f" % [seed, purpose, k, freq]
	if _nc.has(key):
		return _nc[key]
	var n := FastNoiseLite.new()
	n.seed = H.noise_seed(seed, purpose, k)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 5.0   # m
	n.domain_warp_frequency = freq * 0.5
	_nc[key] = n
	return n

## regionální šum v METRECH: freq_m v 1/m, (xm, ym) světové souřadnice v m (Jan 16:42: nezávislé na rozlišení)
static func n01(seed: int, purpose: String, k: int, freq_m: float, xm: float, ym: float) -> float:
	return clampf(_noise(seed, purpose, k, freq_m).get_noise_2d(xm, ym) * 0.5 + 0.5, 0.0, 1.0)

const U := 0.5   # m – délková jednotka tabulek a řídicí mřížky (rozteč 0,5 m), NE rozlišení vzorkování

static func kind_of(shape: String) -> String:
	match shape:
		"hora", "hora_vyzdvizena": return "hora_v"
		"hora_zvrasnena": return "hora_z"
		"sopka": return "sopka"
	return "mirne"

## vyhlazený zdvih: převýšení nad surf_ref, rozmazané krabicovým filtrem (poloměr r, okraje bloku zrcadlí sloupec)
static func uplift(hm_f: PackedFloat64Array, ref: float, r: int) -> PackedFloat64Array:
	var u := PackedFloat64Array(); u.resize(256)
	for x in 16:
		for y in 16:
			var s := 0.0; var n := 0
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var xx := clampi(x + dx, 0, 15); var yy := clampi(y + dy, 0, 15)
					s += hm_f[xx * 16 + yy] - ref; n += 1
			u[x * 16 + y] = s / n
	return u

## nominální (regionální) vršky zón v bodě světa: [plášť, krystalinikum, sedimenty]
static func zone_tops(wx: float, wy: float, p: Dictionary) -> Array:
	var out := []
	for z in 3:
		out.append(float(p.zone_tops[z]) + float(p.zone_amp[z]) * (2.0 * n01(p.world_seed, "ZONE", z, 0.06, wx * U, wy * U) - 1.0))
	return out

## Profily deformace vrstev podle Janovy skicy (16:34, inspirace/skica-tvary-vrstev.jpg, ZDROJE [11]):
## mírné (louka, kopec, svah, prohlubeň): hranice j se posune o a_j · u, a_j roste od spodní k horní vrstvě
##   (vrstvy zhruba kopírují povrch, hluboko skoro rovně; u < 0 = prohnutí pod prohlubní);
## hora vyzdvižená (Janova představa řezu [12]): vršek krystalinika se v jádru zvedne až k povrchu (jádro z hluboké
##   horniny až k vrcholu), sedimenty nad ním se ztenčí exp(−u/λ) a povrch je prořízne → zbydou jen na úpatí; sníh nahoře;
## hora zvrásněná (Janova skica [11] vpravo) = antiklinála: všechny vrstvy se klenou nahoru celé (nic se neztenčí),
##   amplituda a_j · u klesá s hloubkou (horní vrstvy kopírují povrch, hluboké se klenou málo);
## sopka: všechny hranice se ke kráteru strmě zvedají a sbíhají pod vrchol (váha w(r) = (1 − r/R)^γ), uprostřed sopouch.
## E82 (Jan 2026-11-20 01:55): vápenec k hladině zhruba v p82_podil bloků, náhodně podle seedu bloku (stabilní hash).
static func coin82(seed: int, p: Dictionary) -> bool:
	return float(H.mix(seed, "P82_VAPENEC", 0) & 0xFFFF) / 65536.0 < float(p.get("p82_podil", 0.5))

## E82: cíl vršku vrstvy p82_vrstva (jeskynní vápenec) se zvedne na odhad hladiny = vyhlazený povrch − p82_pod_m (2 m: nad vápencem zůstane propustný kryt pro vsak);
## vrstvy nad ní, které by ležely pod tímto vrškem, se vyklíní (vršek = vršek vápence), pořadí zůstává. S p82_tesneni
## se vyklíní i nepropustné vrstvy nad vápencem (jílovec, jíl), aby voda z propustného krytu došla do vápence. Vrací počet
## zvednutých řídicích bodů. t = výstup targets (vršky všech vrstev v jednotkách U, pořadí HR.pool).
static func lift82(t: Array, hm_f: PackedFloat64Array, p: Dictionary) -> int:
	var id := HR.id_of(str(p.get("p82_vrstva", "cave_limestone")))
	var pool := HR.pool(p)
	var k5 := -1
	for k in pool.size():
		if int(pool[k].id) == id: k5 = k
	if k5 < 0 or k5 >= t.size(): return 0
	var hs := uplift(hm_f, 0.0, 1)
	var d := float(p.get("p82_pod_m", 1.0)) / U
	var seal := {}
	if bool(p.get("p82_tesneni", true)):   # nepropustné vrstvy nad vápencem (perm ≤ 0) se v bloku „ano“ vyklíní celé
		const VP = preload("res://scripts/kopie/voda_params.gd")
		var tab: Dictionary = VP.load_shared_table()
		for key in tab.materials:
			var e: Dictionary = tab.materials[key]
			if float(e.perm) <= 0.0: seal[int(e.id)] = true
	var n := 0
	for i in 256:
		var top := hs[i] - d
		if t[k5][i] < top:
			t[k5][i] = top; n += 1
			for j in range(k5 + 1, t.size()):
				t[j][i] = maxf(t[j][i], top)
		if seal.is_empty(): continue
		for j in range(k5 + 1, t.size()):
			if seal.has(int(pool[j].id)): t[j][i] = t[j - 1][i]   # mocnost 0, místo dostane vrstva nad ní
	return n
## E87: masiv vyzdvižené hory – výška povrchu (buňky, s surface_shift z p) v řídicím bodě světa (wx, wy v jednotkách U,
## střed bodu = slot · 16 + x + 0,5). Čistá funkce světa: dva bloky masivu se na švu potkají bez opravy a bez ohledu na pořadí.
static func massif87(wx: float, wy: float, p: Dictionary) -> float:
	var h: float = float(p.p87_zaklad) + float(p.p87_amp) * n01(p.world_seed, "MASSIF87", 0, float(p.p87_freq), wx * U, wy * U)
	h += float(p.p87_detail) * (2.0 * n01(p.world_seed, "MASSIF87D", 0, float(p.p87_dfreq), wx * U, wy * U) - 1.0)
	return minf(h + float(p.surface_shift), 61.0)

static func is87(shape: String, p: Dictionary) -> bool:
	return bool(p.get("p87_jadro_hory", false)) and kind_of(shape) == "hora_v"

## E87: šablona povrchu bloku masivu (16 × 16) = funkce masivu v řídicích bodech
static func massif87_block(slot: Vector2i, p: Dictionary) -> PackedFloat64Array:
	var o := PackedFloat64Array(); o.resize(256)
	for x in 16:
		for y in 16: o[x * 16 + y] = massif87(slot.x * 16 + x + 0.5, slot.y * 16 + y + 0.5, p)
	return o

## E87: zdvih a vyhlazený povrch z funkce masivu rozmazané krabicí VE SVĚTĚ (žádné opakování okrajů bloku)
static func uplift87(slot: Vector2i, p: Dictionary, ref: float, r: int) -> PackedFloat64Array:
	var u := PackedFloat64Array(); u.resize(256)
	for x in 16:
		for y in 16:
			var s := 0.0; var n := 0
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					s += massif87(slot.x * 16 + x + dx + 0.5, slot.y * 16 + y + dy + 0.5, p) - ref; n += 1
			u[x * 16 + y] = s / n
	return u

## E87: hranice vrstev čisté funkce masivu (cíl po průběžném maximu ≥ 0 = to, co dá pipeline bez napojení): pro virtuálního
## souseda při jemném vzorkování a jako cíl pro přenos odchylky přes šev
static func bounds87(t: Array) -> Array:
	var out := []
	var prev := PackedFloat64Array(); prev.resize(256)
	for k in t.size():
		var a := PackedFloat64Array(); a.resize(256)
		for i in 256: a[i] = maxf(float(t[k][i]), prev[i]) if k > 0 else maxf(float(t[k][i]), 0.0)
		out.append(a); prev = a
	return out

static func targets(slot: Vector2i, hm_f: PackedFloat64Array, shape: String, seed: int, p: Dictionary, sub := {}) -> Array:
	var kind := kind_of(shape)
	var ref := float(p.surf_ref)
	var m87 := is87(shape, p)
	var u := uplift87(slot, p, ref, int(p.uplift_blur)) if m87 else uplift(hm_f, ref, int(p.uplift_blur))
	var hs := uplift87(slot, p, 0.0, 1) if m87 else uplift(hm_f, 0.0, 1)   # vyhlazený povrch
	var zl := []
	for z in 3:
		zl.append(HR.pool_zone(HR.ZONES[z], p))
	var out := []
	for z in 3:
		for e in zl[z]:
			var a := PackedFloat64Array(); a.resize(256); out.append(a)
	var nl := out.size()
	var bn := BG.noise(int(p.world_seed), "BP_STRATA87", 0, 0.12, 3) if m87 else BG.noise(seed, "BP_STRATA2", 0, 0.12, 3)   # E87: šum vrstev ve světě
	var pm: Dictionary = p.profiles
	for x in 16:
		for y in 16:
			var i := x * 16 + y
			var wx := slot.x * 16 + x + 0.5; var wy := slot.y * 16 + y + 0.5   # střed řídicího bodu v jednotkách U
			var zt := zone_tops(wx, wy, p)
			var up := maxf(u[i], 0.0)
			var z0: float = zt[0]; var z1: float = zt[1]; var z2: float = zt[2]
			if kind == "hora_v":
				var f: Array = pm.hora_vyzdvizena   # [plášť ×u, krystalinikum na úbočí ×u, u začátku jádra, u plného jádra, buněk pod povrchem, λ sedimentů]
				z0 += float(f[0]) * up
				var flank := z1 + float(f[1]) * up
				var core := maxf(flank, (minf(hs[i], hm_f[i]) if m87 else hs[i]) - float(f[4]))   # E87: jádro nejvýš ke skutečnému povrchu
				z1 = lerpf(flank, core, smoothstep(float(f[2]), float(f[3]), up))
				z2 = z1 + (zt[2] - zt[1]) * exp(-up / float(f[5]))
			var bots := [0.0, z0, z1]; var tops := [z0, z1, z2]
			var j := 0
			for z in 3:
				var w := []
				var sum := 0.0
				var first := true
				for li in zl[z].size():
					var e: Dictionary = zl[z][li]
					var pr := HR.present(e, p, sub)
					if pr == 0:
						w.append(0.0); continue
					var thr := 1.0 - float(e.freq)
					var pres := 1.0 if pr == 2 else smoothstep(thr - 0.12, thr + 0.12, n01(p.world_seed, "PRES_" + e.key, 0, 0.09, wx * U, wy * U))
					var t := lerpf(float(e.thick[0]), float(e.thick[1]), n01(p.world_seed, "THICK_" + e.key, 0, 0.12, wx * U, wy * U))
					var wv := t * pres + (0.05 if first else 0.0)   # první přítomná hornina zóny = záloha, aby zóna nikdy nebyla prázdná
					first = false
					w.append(wv); sum += wv
				sum = maxf(sum, 1e-9)
				var acc := 0.0
				for li in zl[z].size():
					acc += w[li]
					var b: float = bots[z] + (tops[z] - bots[z]) * acc / sum
					var fj := float(j) / maxf(nl - 1, 1)
					if kind == "mirne":
						var m: Array = pm.mirne   # [a spodní vrstvy, a horní vrstvy]
						b += u[i] * lerpf(float(m[0]), float(m[1]), fj)
					elif kind == "hora_z":
						var m: Array = pm.hora_zvrasnena   # [a spodní vrstvy, a horní vrstvy, mocnina útlumu s hloubkou]
						b += u[i] * lerpf(float(m[0]), float(m[1]), pow(fj, float(m[2])))
					elif kind == "sopka":
						var sp: Array = pm.sopka   # [R, γ, podíl sbíhání spodní, horní, buněk pod povrchem]
						var r := Vector2(x - 7.5, y - 7.5).length()
						var wv := pow(clampf(1.0 - r / float(sp[0]), 0.0, 1.0), float(sp[1]))
						b += wv * maxf(hs[i] - float(sp[4]) - b, 0.0) * lerpf(float(sp[2]), float(sp[3]), fj)
					out[j][i] = b + float(p.strata_noise) * 0.5 * (bn.get_noise_3d(wx, wy, j * 7.0) if m87 else bn.get_noise_3d(x, y, j * 7.0))
					j += 1
	return out

## hornina hor podle typu blueprintu a relativní výšky rel = (z − surf_ref) / 21 (+ malý šum)
static func mountain_rock(kind: String, z: int, x: int, y: int, seed: int, p: Dictionary) -> int:
	var rel := (z - float(p.surf_ref)) / 21.0 + 0.06 * BG.noise(seed, "BP_MTN", 0, 0.2, 2).get_noise_3d(x, y, z)
	var last := -1
	for e in HR.mountain(p):
		if not (kind in e.types):
			continue
		last = int(e.id)
		if rel >= e.rel[0] and rel < e.rel[1]:
			return int(e.id)
	return last if last >= 0 else Mat.DIRT

## vyplnění sloupců x ∈ [x0, x1)
static func fill(cells: PackedByteArray, hm: PackedInt32Array, bs: Array, shape: String, seed: int, p: Dictionary, x0: int, x1: int) -> void:
	var prof := kind_of(shape)
	var kind := "nizina" if shape in ["louka", "prohlubeň"] else ("kopec" if prof == "mirne" else ("hora" if prof.begins_with("hora") else prof))
	# vyzdvižená hora nemá horskou kůži: nad vrstvami je hluboká hornina jádra (nejvyšší aktivní hornina krystalinika)
	var crys: Array = HR.layers(HR.ZONES[1], p)
	var core_id: int = int(crys[crys.size() - 1].id) if not crys.is_empty() else Mat.GRANITE
	var lay := HR.all_layers(p).map(func(e): return int(e.id))
	var nb := bs.size()
	var tk := 0 if kind == "nizina" else (1 if kind == "kopec" else 2)
	var vent := HR.special("vent", p)
	for x in range(x0, x1):
		for y in 16:
			var i := x * 16 + y
			var h := hm[i]
			var base := i * 64
			var top := h - 1
			var snow := (kind == "hora" or kind == "sopka") and top >= int(p.snowline)
			var grass := (not snow) and top < int(p.treeline)
			var soil := 0
			if grass:
				soil = int(p.soil) if kind == "nizina" else (1 if top < int(p.treeline) - 4 else 0)
			var skin := 0 if (kind == "nizina" or top <= int(p.surf_ref) + 1 or prof == "hora_v") else tk
			for z in 64:
				var m := Mat.AIR
				if z < h:
					var d := top - z   # 0 = povrchová buňka
					if snow and d < 2:
						m = Mat.SNOW
					elif grass and d == 0:
						m = Mat.GRASS
					elif grass and d <= soil:
						m = Mat.DIRT
					elif prof != "hora_v" and d < (2 if snow else (1 if grass else 0)) + soil + skin:
						m = mountain_rock(kind, z, x, y, seed, p)   # tenká suť / horniny hor podle výšky
					else:
						m = -1
						var zc := z + 0.5
						for k in nb:
							if zc < bs[k][i]:
								m = lay[k]; break
						if m < 0:
							m = Mat.DIRT if kind == "nizina" else (core_id if prof == "hora_v" else mountain_rock(kind, z, x, y, seed, p))
				cells[base + z] = m
			# sopouch: svislý kanál vulkanické horniny od dna až ke dnu kráteru (jen u sopky)
			if kind == "sopka" and not vent.is_empty():
				var r := Vector2(x - 7.5, y - 7.5).length()
				for z in h:
					if r < lerpf(float(vent.body.r), float(vent.body.r_top), float(z) / h):
						cells[base + z] = int(vent.id)

## ---------- zvláštní tělesa (ne vrstvy), ve světových souřadnicích → spojitá přes bloky
static func _centers(e: Dictionary, slot: Vector2i, p: Dictionary, demo: Array, reach: float) -> Array:
	var out := []
	var g := int(e.body.grid)
	var lo := Vector2(slot.x * 16 - reach, slot.y * 16 - reach); var hi := Vector2(slot.x * 16 + 16 + reach, slot.y * 16 + 16 + reach)
	for gi in range(floori(lo.x / g), floori(hi.x / g) + 1):
		for gj in range(floori(lo.y / g), floori(hi.y / g) + 1):
			var hsh := H.mix(p.world_seed, "BODY_" + e.key, gi * 7919 + gj)
			if float(hsh & 0xFFFF) / 65535.0 < float(e.freq) * float(p.body_freq_scale):
				var c := Vector2(gi * g + 6 + float((hsh >> 16) & 0xFF) / 255.0 * (g - 12), gj * g + 6 + float((hsh >> 24) & 0xFF) / 255.0 * (g - 12))
				out.append([c, hsh])
	for d in demo:
		out.append([Vector2(d[0], d[1]), H.mix(p.world_seed, "DEMO_" + e.key, int(d[0]) * 131 + int(d[1]))])
	return out.filter(func(c): return c[0].x > lo.x and c[0].x < hi.x and c[0].y > lo.y and c[0].y < hi.y)

static func bodies(cells: PackedByteArray, hm: PackedInt32Array, slot: Vector2i, p: Dictionary) -> Dictionary:
	var rep := {"pipe": 0, "dome": 0, "vein": 0, "contact": 0}
	var zone_of := PackedByteArray(); zone_of.resize(256); zone_of.fill(255)
	for e in HR.raw().rocks:
		var zi := HR.ZONES.find(e.zone)
		if zi >= 0 and e.kind == "layer": zone_of[int(e.id)] = zi
	var protect := [Mat.AIR, Mat.GRASS, Mat.DIRT, Mat.SNOW]
	# kimberlitový komín: svislá mrkev od z = 0 nahoru přes plášť a krystalinikum (vršek = vršek krystalinika + n)
	var pipe := HR.special("pipe", p)
	if not pipe.is_empty():
		for c in _centers(pipe, slot, p, p.demo_pipes, 4.0):
			for x in 16:
				for y in 16:
					var wx := slot.x * 16 + x + 0.5; var wy := slot.y * 16 + y + 0.5
					var zt: float = zone_tops(c[0].x, c[0].y, p)[1] + float(pipe.body.top_above_crystalline)
					var dd := Vector2(wx, wy).distance_to(c[0])
					for z in mini(int(zt), hm[x * 16 + y] - 1):
						var r := lerpf(float(pipe.body.r0), float(pipe.body.r1), z / zt)
						if dd < r and not (cells[(x * 16 + y) * 64 + z] in protect):
							cells[(x * 16 + y) * 64 + z] = int(pipe.id); rep.pipe += 1
	# solný dóm: od báze sedimentů nahoru (stonek), nahoře rozšířený klobouk; nahrazuje jen sedimenty
	var dome := HR.special("dome", p)
	if not dome.is_empty():
		for c in _centers(dome, slot, p, p.demo_domes, 6.0):
			var zb: float = zone_tops(c[0].x, c[0].y, p)[1]
			var zt := float(dome.body.top)
			for x in 16:
				for y in 16:
					var dd := Vector2(slot.x * 16 + x + 0.5, slot.y * 16 + y + 0.5).distance_to(c[0])
					for z in range(int(zb) - 2, mini(int(zt), hm[x * 16 + y] - 2)):
						var t := (z - zb) / maxf(zt - zb, 1.0)
						var r := float(dome.body.r_stem) if t < 0.65 else lerpf(float(dome.body.r_stem), float(dome.body.r_cap), sqrt((t - 0.65) / 0.35)) * (1.0 - 0.3 * pow(maxf(t - 0.9, 0.0) / 0.1, 2))
						var ci := (x * 16 + y) * 64 + z
						if dd < r and (zone_of[cells[ci]] == 2 or zone_of[cells[ci]] == 1 and t < 0.1):
							cells[ci] = int(dome.id); rep.dome += 1
	# pegmatitové žíly: tenké desky (roviny) v krystaliniku, omezené poloměrem extent
	var peg := HR.special("vein", p)
	if not peg.is_empty():
		for c in _centers(peg, slot, p, [], float(peg.body.extent)):
			for k in int(peg.body.planes):
				var rng := Ore.Rng.new(H.mix(c[1], "PLANE", k))
				var nrm := Vector3(rng.range_i(-100, 100), rng.range_i(-100, 100), rng.range_i(-30, 30)).normalized()
				var cz: float = 13.0 + rng.range_i(0, 12)
				var cp := Vector3(c[0].x + rng.range_i(-4, 4), c[0].y + rng.range_i(-4, 4), cz)
				for x in 16:
					for y in 16:
						for z in 64:
							var ci := (x * 16 + y) * 64 + z
							if zone_of[cells[ci]] != 1:
								continue
							var q := Vector3(slot.x * 16 + x + 0.5, slot.y * 16 + y + 0.5, z + 0.5) - cp
							if absf(q.dot(nrm)) < float(peg.body.half) and q.length() < float(peg.body.extent):
								cells[ci] = int(peg.id); rep.vein += 1
	# skarn: karbonáty do vzdálenosti `width` od granitoidů (v bloku)
	var sk := HR.special("contact", p)
	if not sk.is_empty():
		var around := PackedByteArray(); around.resize(256)
		var inn := PackedByteArray(); inn.resize(256)
		for k in sk.body.around: around[HR.id_of(k)] = 1
		for k in sk.body["in"]: inn[HR.id_of(k)] = 1
		var front := PackedInt32Array()
		var dist := PackedByteArray(); dist.resize(cells.size()); dist.fill(255)
		for ci in cells.size():
			if around[cells[ci]] == 1:
				dist[ci] = 0; front.append(ci)
		for step in int(sk.body.width):
			var nxt := PackedInt32Array()
			for ci in front:
				var x := ci / 1024; var y := (ci / 64) % 16; var z := ci % 64
				for d in 6:
					var nx: int = x + Ore.DX[d]; var ny: int = y + Ore.DY[d]; var nz: int = z + Ore.DZ[d]
					if nx < 0 or ny < 0 or nz < 0 or nx > 15 or ny > 15 or nz > 63:
						continue
					var n := (nx * 16 + ny) * 64 + nz
					if dist[n] == 255 and inn[cells[n]] == 1:
						dist[n] = step + 1; nxt.append(n)
			for n in nxt:
				cells[n] = int(sk.id); rep.contact += 1
			front = nxt
	return rep
