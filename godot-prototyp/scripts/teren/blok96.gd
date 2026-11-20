extends RefCounted
## E96 (Jan 2026-11-20 11:48 „Začneme generovat už celý jeden blok 128m“): ostrov = jeden blok 128 × 128 m z funkce světa.
## Herně je to 16 × 16 bloků po 8 m (256 × 256 sloupců po 0,5 m), takže geologie (pipeline blueprintu přes base_hm, E49),
## voda (ostrov_voda / E68), kopání, vegetace, povrch a kamera jsou stejné moduly jako dnes. Výška = lod90.h_m (E90) ve
## středech buněk, bez šablon. Příznak p96_blok128 (surface_params, výchozí vyp); bez něj se modul nepoužije.
## Parametry funkce (CLI --bp.<klíč>): p96_natazeni, p96_relief, p96_dlazdice_x/y (viz ostrov_teren.HRA).
const L = preload("res://scripts/teren/lod90.gd")
const J = preload("res://scripts/jednotky.gd")
const SP = preload("res://scripts/surface/surface_params.gd")
const BS := J.BS
const N := 16                       # bloků na stranu: 128 m / 8 m
const OFF := Vector2i(1, 1)         # svět studie: blok (0, 0) = slot (1, 1), kolem prstenec příkopu (mlhy)
const SIZE := N + 2
const STROP := 61.0                 # strop povrchu v buňkách (sloupec 64 buněk)

static func on() -> bool:
	return bool(SP.inst().p96_blok128)

## funkce světa E90 s parametry E96 (tp = parametry ostrov_teren.p, nese i surf_ref a s8_*)
static func fn(tp: Dictionary) -> Dictionary:
	var p: Dictionary = L.P.duplicate()
	p.p90_natazeni = float(tp.get("p96_natazeni", 4.0)); p.p90_relief = float(tp.get("p96_relief", 1.0))
	return L.fn(p, tp)

## počátek bloku 128 m ve světě (m)
static func origin_m(tp: Dictionary) -> Vector2:
	return Vector2(float(tp.get("p96_dlazdice_x", 7)), float(tp.get("p96_dlazdice_y", 4))) * 128.0

## výšky povrchu bloku slotu s (16 × 16, buňky, index x * 16 + y) ve středech buněk
static func heights(f: Dictionary, tp: Dictionary, s: Vector2i) -> Array:
	var o := origin_m(tp) + Vector2(s) * J.BLOK_M
	var out := []
	for x in BS:
		for y in BS:
			out.append(minf(L.h_m(f, o.x + (x + 0.5) * J.CELL_M, o.y + (y + 0.5) * J.CELL_M) / J.CELL_M, STROP))
	return out

## typ bloku (řídí jen geologii a minerály, povrch je z funkce): podle průměru a rozpětí výšky v buňkách
static func kind_of(h: Array) -> String:
	var lo := 1e9; var hi := -1e9; var s := 0.0
	for v in h: lo = minf(lo, v); hi = maxf(hi, v); s += v
	var mean := s / h.size()
	if mean >= 50.0: return "hora"          # ≥ 25 m
	if mean <= 33.0: return "piscina"       # ≤ 16,5 m (pánve jezer E49)
	if hi - lo >= 6.0: return "kopec"       # rozpětí ≥ 3 m v bloku 8 m
	return "louka"

## startovní bloky: [{slot, kind, seed, hm}] v pořadí vložení (po řádcích)
static func start(tp: Dictionary) -> Array:
	var f := fn(tp)
	var out := []
	for j in N:
		for i in N:
			var s := Vector2i(i, j)
			var h := heights(f, tp, s)
			out.append({"slot": s, "kind": kind_of(h), "seed": 9600 + j * N + i, "hm": h})
	return out

## sloty ostrova (bloky + prstenec mlhy)
static func slots() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(-1, N + 1):
		for y in range(-1, N + 1):
			out.append(Vector2i(x, y))
	return out

## místo startu: nejrovnější okno 9 × 9 sloupců (domek 4 × 4 m) v okruhu 24 m od středu; postava 3 m vedle.
## hm_at(g) = výška sloupce g (globální). Vrací {dum: sloupec, postava: sloupec}.
static func spawn(hm_at: Callable) -> Dictionary:
	var c := Vector2i(N * BS / 2, N * BS / 2)
	var best := c; var bs := 1 << 30
	for dx in range(-48, 49, 2):
		for dy in range(-48, 49, 2):
			var g := c + Vector2i(dx, dy)
			var lo := 1 << 30; var hi := -1
			for a in range(-4, 5):
				for b in range(-4, 5):
					var h: int = hm_at.call(g + Vector2i(a, b))
					lo = mini(lo, h); hi = maxi(hi, h)
			var sc := (hi - lo) * 1000 + absi(dx) + absi(dy)
			if sc < bs: bs = sc; best = g
	return {"dum": best, "postava": best + Vector2i(0, 7)}
