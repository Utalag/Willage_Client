extends RefCounted
## Materiály buněk: ID, názvy, pastelové barvy, skóre pro raritu a nosnost (pro budoucí fyziku).

enum { AIR, GRASS, DIRT, SAND, CLAY, LIMESTONE, GRANITE, BASALT, COPPER, IRON, SNOW, FOG }
const COUNT := 12

const NAMES := ["vzduch", "tráva", "hlína", "písek", "jíl", "vápenec", "žula", "čedič",
	"měděná ruda", "železná ruda", "sníh", "mlha"]

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
]

# skóre za buňku (rarita bloku se počítá z průměrného skóre plných buněk)
const SCORE := [0.0, 1.0, 1.0, 1.5, 2.0, 2.0, 3.0, 3.0, 40.0, 25.0, 8.0, 0.0]

# nosnost = kolik buněk nad sebou unese (-1 = neomezeně); zatím se nepoužívá
const LOAD := [0, 2, 2, 1, 2, -1, -1, -1, -1, -1, 0, 0]

# mlha: nehratelná, nestavitelná, nekopatelná
static func playable(m: int) -> bool:
	return m != FOG and m != AIR

const RARITY_NAMES := ["běžná", "neobvyklá", "vzácná", "epická", "legendární"]
const RARITY_COLORS := [Color(0.60, 0.58, 0.62), Color(0.55, 0.85, 0.55), Color(0.45, 0.70, 1.0),
	Color(0.80, 0.55, 1.0), Color(1.0, 0.75, 0.30)]
# prahy průměrného skóre (kalibrováno na vygenerovaných blocích)
const RARITY_THRESHOLDS := [0.0, 2.70, 2.78, 3.2, 3.5]

static func score_of(summary: PackedInt32Array) -> float:
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
