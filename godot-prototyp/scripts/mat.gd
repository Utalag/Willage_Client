@tool
extends RefCounted
## Materiály buněk: ID, názvy, pastelové barvy, skóre pro raritu a nosnost (pro budoucí fyziku).

enum { AIR, GRASS, DIRT, SAND, CLAY, LIMESTONE, GRANITE, BASALT, COPPER, IRON, SNOW, FOG, CLAY_DEPOSIT }
const COUNT := 13
## CLAY_DEPOSIT = ložiskový jíl (gen-v3, návrh Willage-backend 18:34); generátor proto ho nevytváří. FOG je v gen-v3 vnitřní UNSET.
const ORES := [COPPER, IRON, CLAY_DEPOSIT]

const NAMES := ["vzduch", "tráva", "hlína", "písek", "jíl", "vápenec", "žula", "čedič",
	"měděná ruda", "železná ruda", "sníh", "mlha", "ložiskový jíl"]

# pastelová paleta (kawaii směr)
const COLORS := [
	Color(0, 0, 0, 0),
	Color(0.56, 0.80, 0.47),  # tráva
	Color(0.66, 0.50, 0.40),  # hlína
	Color(0.98, 0.89, 0.62),  # písek
	Color(0.92, 0.62, 0.52),  # jíl
	Color(0.88, 0.82, 0.68),  # vápenec
	Color(0.80, 0.68, 0.74),  # žula
	Color(0.52, 0.55, 0.68),  # čedič
	Color(0.45, 0.85, 0.78),  # měď (malachit)
	Color(0.88, 0.45, 0.42),  # železo
	Color(0.97, 0.98, 1.00),  # sníh
	Color(0.95, 0.96, 1.00),  # mlha
	Color(0.96, 0.52, 0.36),  # ložiskový jíl (sytější než jíl z půdy)
]

# skóre za buňku (rarita bloku se počítá z průměrného skóre plných buněk)
const SCORE := [0.0, 1.0, 1.0, 1.5, 2.0, 2.0, 3.0, 3.0, 40.0, 25.0, 8.0, 0.0, 2.0]

# nosnost = kolik buněk nad sebou unese (-1 = neomezeně); zatím se nepoužívá
const LOAD := [0, 2, 2, 1, 2, -1, -1, -1, -1, -1, 0, 0, 2]

# mlha: nehratelná, nestavitelná, nekopatelná
static func playable(m: int) -> bool:
	return m != FOG and m != AIR

const RARITY_NAMES := ["běžná", "neobvyklá", "vzácná", "epická", "legendární"]
const RARITY_COLORS := [Color(0.60, 0.58, 0.62), Color(0.55, 0.85, 0.55), Color(0.45, 0.70, 1.0),
	Color(0.80, 0.55, 1.0), Color(1.0, 0.75, 0.30)]
# prahy průměrného skóre (kalibrováno na vygenerovaných blocích) – původní prostý průměr (rarity-v1)
const RARITY_THRESHOLDS_V1 := [0.0, 2.70, 2.78, 3.2, 3.5]
# rarity-v2 (Jan 2026-11-17): vážený průměr R = Σ(n·w·s) / Σ(n·w), w = váha z katalogu (výchozí s², dá se ladit), vzduch a mlha se nepočítají
const WEIGHT := [0.0, 1.0, 1.0, 2.25, 4.0, 4.0, 9.0, 9.0, 1600.0, 625.0, 64.0, 0.0, 4.0]
const RARITY_THRESHOLDS_PROTO := [0.0, 15.9, 19.4, 26.1, 29.9]  # rarity-v2 pro gen proto, tools/rarity_calib.gd: stejné podíly tříd jako v1 na 240 blocích (zatímní)
const RARITY_THRESHOLDS_V3 := [0.0, 16.9, 18.7, 19.0, 22.7]  # gen-v3 (Jan 20:39), tools/rarity_calib_v3.gd: stejné podíly tříd jako gen proto s prahy výše na týchž 240 blocích (zatímní)
static var rarity_gen := "v3"   # prahy podle generátoru (nastavuje BlockGen.gen_version)
static func thresholds() -> Array:
	return RARITY_THRESHOLDS_V3 if rarity_gen == "v3" else RARITY_THRESHOLDS_PROTO

static func score_of(summary: PackedInt32Array) -> float:
	var wsum := 0.0
	var s := 0.0
	for m in range(1, COUNT):
		if m == FOG:
			continue
		wsum += summary[m] * WEIGHT[m]
		s += summary[m] * WEIGHT[m] * SCORE[m]
	return s / maxf(wsum, 1e-9)

## původní prostý průměr (jen pro srovnání / kalibraci)
static func score_of_v1(summary: PackedInt32Array) -> float:
	var total := 0
	var s := 0.0
	for m in range(1, COUNT):
		if m == FOG:
			continue
		total += summary[m]
		s += summary[m] * SCORE[m]
	return s / maxf(total, 1.0)

static func rarity_of(summary: PackedInt32Array, th: Array = []) -> int:
	var sc := score_of(summary)
	var r := 0
	if th.is_empty():
		th = thresholds()
	for i in th.size():
		if sc >= th[i]:
			r = i
	return r
