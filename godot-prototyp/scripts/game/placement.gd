extends Node
## Vkládání bloků: kandidáti v liště dole, náhled v mlze pod myší (klik místo zamkne), úpravy R / F / +− a strany
## v panelu, Enter vloží. Spotřebovaného kandidáta nahradí nový běžný blok (rng se seedem 2026).

signal hint_changed

const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const H = preload("res://scripts/stable_hash.gd")
const IslandS = preload("res://scripts/island.gd")

@export var island_path: NodePath
@export var ui_path: NodePath
@export var rng_seed := 2026
@onready var island = get_node(island_path)
@onready var ui = get_node(ui_path)

var rng := RandomNumberGenerator.new()
var candidates: Array = []
var sel := -1            # vybraný kandidát
var preview: Block = null
var locked_slot = null   # slot zvolený kliknutím

func _ready() -> void:
	rng.seed = rng_seed

func setup_candidates() -> void:
	candidates = [
		IslandS.make_block("louka", 1201, "Louka"),
		IslandS.make_block("louka", 1777, "Louka"),
		IslandS.make_block("kopec", 2302, "Kopec"),
		IslandS.make_block("hora", 1000, "Hora Prvního dne", "pevný"),
		IslandS.make_block("piscina", 4504, "Písčina"),
		IslandS.make_block("hora", H.named_seed("Grrrrův štít"), "Grrrrův štít", "unikátní"),
	]
	ui.set_candidates(candidates)

func _random_candidate() -> Block:
	var kinds := ["louka", "kopec", "hora", "piscina"]
	var k: String = kinds[rng.randi() % kinds.size()]
	var nm: String = {"louka": "Louka", "kopec": "Kopec", "hora": "Hora", "piscina": "Písčina"}[k]
	return IslandS.make_block(k, rng.randi_range(1000, 99999), nm)

func pick(i: int) -> void:
	sel = i
	var c: Block = candidates[i]
	preview = IslandS.make_block(c.kind, c.seed, c.title, c.category)
	locked_slot = null
	island.hide_preview()
	ui.show_block(null, "", false)
	ui.title_lbl.text = c.title
	ui.info_lbl.text = "Najeď na zvýrazněné místo v mlze a klikni."
	island.show_frames = true
	island.refresh_frames()
	hint_changed.emit()

func cancel() -> void:
	island.show_frames = false
	island.refresh_frames()
	sel = -1
	preview = null
	locked_slot = null
	island.hide_preview()
	ui.select_card(-1)
	ui.show_block(null, "", false)
	hint_changed.emit()

## náhled na slotu pod myší (s = slot nebo null)
func preview_at(s) -> void:
	if preview == null:
		return
	if s == null or not island.is_valid(s):
		if locked_slot == null:
			island.hide_preview()
		return
	if island.preview_block != null and island.preview_block.slot == s and island.preview_mi.visible:
		return
	preview.slot = s
	rebuild_preview()

## klik na platný slot: zamknout místo náhledu
func lock(s: Vector2i) -> void:
	locked_slot = s
	preview.slot = s
	rebuild_preview()

func rebuild_preview() -> void:
	if preview == null or not island.is_valid(preview.slot):
		return
	BlockGen.build(preview, island.neighbor_hms(preview.slot))
	island.show_preview(preview)
	var state := "zvoleno" if locked_slot != null else "náhled"
	ui.show_block(preview, "Místo %s (%s)" % [preview.slot, state], true, island.neighbor_hms(preview.slot))

func confirm() -> void:
	if preview == null or not island.is_valid(preview.slot) or island.preview_block == null:
		return
	var b := preview
	island.hide_preview()
	island.show_frames = false
	island.place(b)
	island.log_block(b)
	# kandidát se spotřeboval, na jeho místo přijde nový běžný blok
	candidates[sel] = _random_candidate()
	ui.set_candidates(candidates)
	sel = -1
	preview = null
	locked_slot = null
	ui.show_block(b, "Vložen na %s" % b.slot, false)
	hint_changed.emit()

## úprava náhledu (rotace, zrcadlení, výška) a přestavba
func edit(f: Callable) -> void:
	if preview == null:
		return
	f.call()
	rebuild_preview()
