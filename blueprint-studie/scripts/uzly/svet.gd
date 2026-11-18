extends Node
## Uzel Svet: drží stav světa (sloty) a parametry studie. Parametry jdou ladit v Inspectoru i z příkazové řádky.

const W = preload("res://scripts/bp/world.gd")
const PR = preload("res://scripts/bp/params.gd")

@export var band := 4                 ## pás dorovnání povrchu (buňky)
@export var strata_band := 0          ## 0 = korekce vrstev přes celý blok
@export_enum("neumann", "zero") var free_face := "neumann"
@export var erosion := false
@export var budget_ms := 6.0          ## čas výpočtu na snímek při vkládání

var world = W.new()
var params := {}

func _ready() -> void:
	params = PR.defaults()
	params.band = band; params.strata_band = strata_band; params.free_face = free_face
	params.erosion = erosion; params.budget_ms = budget_ms
	PR.apply_args(params, OS.get_cmdline_user_args())

func reset() -> void:
	world = W.new()
