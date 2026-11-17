## KOPIE z lozika-studie/scripts/gen3_server.gd (gen-v3-study-4) pro prototyp; změny jen cesty preload.
extends RefCounted
## ZÁSTUPCE SERVERU pro gen-v3: katalog materiál -> tvar + parametry (celá čísla), sestavení a seřazení zásobníku.
## Pořadí rozhoduje server (Jan 18:58): výchozí od nejméně početného, shoda → MaterialId vzestupně (vzduch jeskyně = 0);
## recept může pořadí přepsat (order_override = seznam mat_id dopředu). Generátor zásobník NEŘADÍ.

const Mat = preload("res://scripts/mat.gd")
const S = preload("res://scripts/gen3/gen3_stack.gd")

## katalog: mat_id -> [shape, params…] (pořadí params podle S.SHAPES)
const CATALOG := {
	Mat.BASALT: [S.SHAPE_STRATUM, 25, 6],      # 19:19 (e): mocné vrstvy po sloupcích, vlna ±2,5 buňky na ~6 buněk
	Mat.GRANITE: [S.SHAPE_STRATUM, 30, 5],
	Mat.LIMESTONE: [S.SHAPE_STRATUM, 20, 7],
	Mat.DIRT: [S.SHAPE_LAYER, 200, -4, -1, 58982, 3276],     # varianta 2: hlína jen vrstva u povrchu (hloubka 1–4)
	Mat.SAND: [S.SHAPE_LAYER, 80, -6, -1, 52428, 6553],
	Mat.CLAY: [S.SHAPE_LAYER, 80, -7, -2, 52428, 6553],
	Mat.CLAY_DEPOSIT: [S.SHAPE_LAYER, 120, -10, -3, 52428, 6553],
	Mat.AIR: [S.SHAPE_CHAMBER, 60, 3, 44, 40632, 19660, 2, 1],
	Mat.COPPER: [S.SHAPE_VEIN, 18, 8, 40, 700, 80, Mat.GRANITE],   # 19:19 (c): měď v žule (porfyrová ložiska)
	Mat.IRON: [S.SHAPE_POCKET, 22, 4, 36, Mat.BASALT],             # 19:19 (c): železo v čediči
}
## přepínače pro srovnání (ablace v DENIKu): false = stav před 19:19
static var STRATA := true          # (e) kameny jako stratum; false = layer BFS (pásma 0–16 / 10–28 / 20–46)
static var ORE_IN_STONE := true    # (c) rudy s hostitelem; false = rudy jen do nepřiřazených buněk
const OLD_STONE := {Mat.BASALT: [S.SHAPE_LAYER, 400, 0, 16, 52428, 6553], Mat.GRANITE: [S.SHAPE_LAYER, 400, 10, 28, 52428, 6553], Mat.LIMESTONE: [S.SHAPE_LAYER, 400, 20, 46, 52428, 6553]}
static func cat(k: int) -> Array:
	if not STRATA and OLD_STONE.has(k):
		return OLD_STONE[k]
	var c: Array = CATALOG[k].duplicate()
	if not ORE_IN_STONE and (k == Mat.COPPER or k == Mat.IRON):
		c[c.size() - 1] = -1
	return c

## kameny jako vrstvy zdola nahoru (pořadí z receptu, 19:19 e); jdou za ostatní položky, vrstva nahoře pojme zbytek
const STRATA_ORDER := [Mat.BASALT, Mat.GRANITE, Mat.LIMESTONE]

## pořadí: (1) položky bez hostitele a bez stratum vzestupně podle počtu (shoda → MaterialId; order_override dopředu),
## (2) stratum v pořadí STRATA_ORDER (zdola nahoru), (3) rudy s hostitelem vzestupně podle počtu (hostitel už je rozmístěný).
static func build_stack(summary: Dictionary, order_override := []) -> Array:
	var ks := summary.keys().filter(func(k): return not (k is String) and summary[k] > 0)
	var grp := func(k) -> int:
		var c: Array = cat(k)
		if c[0] == S.SHAPE_STRATUM: return 1
		if (c[0] == S.SHAPE_POCKET and c[4] >= 0) or (c[0] == S.SHAPE_VEIN and c[6] >= 0): return 2
		return 0
	ks.sort_custom(func(a, b):
		var ga: int = grp.call(a); var gb: int = grp.call(b)
		if ga != gb:
			return ga < gb
		if ga == 1:
			return STRATA_ORDER.find(a) < STRATA_ORDER.find(b)
		var ia: int = order_override.find(a); var ib: int = order_override.find(b)
		if ia != ib:
			if ia < 0: return false
			if ib < 0: return true
			return ia < ib
		if summary[a] != summary[b]:
			return summary[a] < summary[b]
		return a < b)
	var items := []
	for k in ks:
		var c: Array = cat(k)
		items.append({"material": k, "count": summary[k], "shape": c[0], "params": c.slice(1)})
	return items

## 19:19 (d) KONTROLA SERVERU při vydání: Σ count položek bez hostitele == V − slupka (dřív stačilo ≤, od varianty 2 přesně),
## ruda s hostitelem ≤ počet hostitele, hostitel v zásobníku dřív; voda ≤ přidělení podle okraje (a).
static func check_stack(items: Array, v_free: int, water := 0, water_cap := -1) -> Array:
	var errs := []
	var tot := 0
	var cnt := {}
	for it in items:
		cnt[it.material] = cnt.get(it.material, 0) + int(it.count)
	var hosted := {}
	for it in items:
		var h: int = it.get("host", -1)
		if h >= 0:
			hosted[h] = hosted.get(h, 0) + int(it.count)
		else:
			tot += int(it.count)
	if tot > v_free:
		errs.append({"code": "world.summary_over_volume", "want_max": v_free, "got": tot})
	elif tot < v_free:
		errs.append({"code": "world.summary_under_volume", "want": v_free, "got": tot})
	for h in hosted:
		if hosted[h] > cnt.get(h, 0):
			errs.append({"code": "world.summary_host_overflow", "host": h, "host_count": cnt.get(h, 0), "ores": hosted[h]})
	if water_cap >= 0 and water > water_cap:
		errs.append({"code": "world.water_over_rim_allotment", "want_max": water_cap, "got": water})
	return errs

## 19:19 (a) přidělení vody podle nejnižšího okraje bloku (každý blok stabilní sám): odhad z povrchu a zásobníku,
## bez znalosti rozmístění. Póry propustné slupky pod okrajem: buňky s hloubkou d ∈ [2, D] (D = nejhlubší položka u povrchu)
## a z < okraj, × pórovitost hlíny × podíl propustných položek u povrchu × rezerva 0,8.
static func water_allotment(hm: PackedInt32Array, items: Array, por := 0.40, safety := 0.4) -> int:
	var rim := 64
	for x in 16:
		for y in 16:
			if x == 0 or y == 0 or x == 15 or y == 15:
				rim = mini(rim, hm[x * 16 + y])
	var dmax := 1
	var perm := 0; var near := 0
	for it in items:
		if it.get("lzMin", 0) < 0 or (it.shape != S.SHAPE_STRATUM and it.params.size() > 1 and it.params[1] < 0):
			var lzmin: int = it.params[1]
			dmax = maxi(dmax, -lzmin)
			near += int(it.count)
			if it.material == Mat.DIRT or it.material == Mat.SAND:
				perm += int(it.count)
	var cells := 0
	for h in hm:
		for d in range(2, dmax + 1):
			if h - d >= 1 and h - d < rim:
				cells += 1
	return int(floor(cells * por * (float(perm) / maxi(near, 1)) * safety))
