@tool
extends RefCounted
## Data jednoho bloku 16 × 16 × 64 buněk (+ volby vložení). Server by ukládal jen typ, seed, volby a změny.

const Mat = preload("res://scripts/mat.gd")

const BS := 16      # šířka / hloubka v buňkách
const BH := 64      # výška v buňkách
const CELL_H := 0.5 # buňka 1 × 1 × 0,5

var kind := "louka"         # recept: louka, kopec, hora, piscina
var seed := 0
var title := ""             # zobrazované jméno
var category := "běžný"     # běžný / pevný / unikátní
var ore_bonus := 0.0        # unikátní bloky mají bohatší žíly

# volby vložení (pořadí: zrcadlení, rotace, posun výšky, strany)
var mirror := false
var rot := 0                # 0..3 × 90°
var shift := 0              # -4..+4 buněk
var sides := PackedInt32Array([0, 0, 0, 0])  # S(sever) V J Z: 0 = auto, 1..4 = dorovnat n, 5 = ponechat
var edge_profiles := [null, null, null, null]  # při vložení: výšky hrany souseda (16) ve směrech S V J Z, null = bez souseda

var slot := Vector2i.ZERO
var hm := PackedInt32Array()     # výška povrchu (počet plných buněk) po všech úpravách
var hm_gen := PackedInt32Array() # výška povrchu při vygenerování (kopání ji nemění); gen-v3: kde se kreslí hladina water_lz
var cells := PackedByteArray()   # (x * BS + z) * BH + y
var discovered := PackedByteArray()  # 16 × 16 × 64, 1 = stěna u vzduchu spojeného s povrchem (jinak neutrální textura)
var summary := PackedInt32Array()       # aktuální počty buněk podle materiálu
var summary_orig := PackedInt32Array()  # stav při vložení (původní rarita)
var veg: Array = []                         # vegetace (samostatná vrstva), viz veg.gd
var veg_summary := PackedInt32Array()
var veg_summary_orig := PackedInt32Array()
var water := PackedInt32Array()        # gen-v3: voda v buňce, 4096 = plná buňka (v půdě nejvýš pórovitost); prázdné = bez dat vody
var gen := "proto"                     # který generátor blok vytvořil (BlockGen.gen_version)
var gen3 := {}                         # gen-v3: zásobník (hex, hash), voda (nalito / přidělení), schodek, validátor
var geo := PackedByteArray()          # E66 gen bp: plné MaterialId 0–255 (horniny, minerály) pro vzhled a vodu; cells = herní třída (scripts/teren/tridy.gd)
var bp_rec := {}                       # E66 gen bp: záznam bloku ve světě studie (bp, hm_f, bs, cells, water, rep)
var prameny76 = null                  # E76: uložené prameny bloku [[lx, ly, z, q, druh]] (z v buňkách), null = ještě nenalezené
var prenos76 := {}                     # E76: výřez z průzkumného světa {puvod: slot světa původu, dz: posun v buňkách}
var def78 := PackedByteArray()       # E78: pole materiálů 0,5 m hned po vygenerování (definice), prázdné = bez překryvu
var jemne78 := PackedByteArray()     # E78: živá mřížka 0,25 m (32 × 32 × 128), prázdná = ještě se nekopalo jemně
var def85 := PackedByteArray()       # E85 (p85_jemne): definice 0,25 m přímo z funkcí geo_fn, prázdná = zjemnění def78
var gen_ms := 0.0
var mesh_ms := 0.0

static func idx(x: int, z: int, y: int) -> int:
	return (x * BS + z) * BH + y

func get_cell(x: int, z: int, y: int) -> int:
	return cells[(x * BS + z) * BH + y]

func copy_settings_from(o) -> void:
	mirror = o.mirror; rot = o.rot; shift = o.shift; sides = o.sides.duplicate()

func recount() -> void:
	summary = PackedInt32Array()
	summary.resize(Mat.COUNT)
	for c in cells:
		summary[c] += 1
