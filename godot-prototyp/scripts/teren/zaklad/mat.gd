extends RefCounted
## KOPIE z blueprint-studie/scripts/kopie/mat.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Materiály buněk: ID, názvy, pastelové barvy, skóre pro raritu a nosnost (pro budoucí fyziku).

enum { AIR, GRASS, DIRT, SAND, CLAY, LIMESTONE, GRANITE, BASALT, COPPER, IRON, SNOW, FOG, CLAY_DEPOSIT }
const COUNT := 13
## STUDIE: CLAY_DEPOSIT = ložiskový jíl (návrh Willage-backend 18:34), základní generování ID rud nikdy nevytváří.
## VIEW_CAVE = jen pro vykreslení jeskynního vzduchu ve studii (není v datech).
const VIEW_CAVE := 13
const VIEW_WET_DIRT := 14
const VIEW_WET_SAND := 15
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
	Color(0.78, 0.72, 0.95),  # jen zobrazení: jeskyně
	Color(0.42, 0.40, 0.55),  # jen zobrazení: mokrá hlína (gen-v3)
	Color(0.62, 0.78, 0.92),  # jen zobrazení: nasycený písek (gen-v3)
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
const RARITY_THRESHOLDS := [0.0, 15.9, 19.4, 26.1, 29.9]  # rarity-v2, tools/rarity_calib.gd: stejné podíly tříd jako v1 na 240 blocích (zatímní)

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

static func rarity_of(summary: PackedInt32Array) -> int:
	var sc := score_of(summary)
	var r := 0
	for i in RARITY_THRESHOLDS.size():
		if sc >= RARITY_THRESHOLDS[i]:
			r = i
	return r
