@tool
class_name GrassParams
extends "res://scripts/tunable_params.gd"
## Parametry trávy C (převzato ze studie trava-studie/scripts/params.gd, varianta C), teď jako Resource s @export
## (inspektor Godotu, předvolby .tres, ladicí okno). Vše laditelné z příkazové řádky `-- --grass.klic=hodnota`
## (např. -- --grass.tufts_tall=30 --grass.tuft_short_h=0.15), nebo za běhu inst().set_param(k, v).
## Výšky jsou × hrana buňky (prototyp: hrana 1, výška vrstvy 0,5). Staré API g("klic") zůstává.

static var _inst

static func inst():
	if _inst == null:
		_inst = load("res://scripts/grass_params.gd").new()
		_inst.apply_cli("grass")
	return _inst

static func parse_cli() -> void:
	inst()

static func g(k: String) -> float:
	return float(inst().get(k))

static func has(k: String) -> bool:
	return k in inst().param_names()

@export_group("Tráva C")
@export_range(0, 1, 1) var enabled := 1                ## 0 = původní vykreslení veg-v2, 1 = tráva C
@export_range(0.25, 2.0, 0.05) var cell_edge := 1.0    ## hrana buňky v jednotkách
@export_group("Vysoká / nízká tráva")
@export_range(1.0, 12.0, 0.5) var tall_patch := 4.0    ## velikost skvrn vysoké trávy (sloupců)
@export_range(0.0, 1.0, 0.05) var tall_louka := 0.55
@export_range(0.0, 1.0, 0.05) var tall_kopec := 0.40
@export_range(0.0, 1.0, 0.05) var tall_hora := 0.20
@export_range(0.0, 1.0, 0.05) var tall_piscina := 0.15
@export_group("Trsy")
@export_range(0.05, 1.0, 0.01) var tuft_tall_h := 0.30
@export_range(0.02, 0.6, 0.01) var tuft_short_h := 0.12
@export_range(0, 80, 1) var tufts_tall := 24
@export_range(0, 120, 1) var tufts_short := 50
@export_range(0.3, 3.0, 0.05) var tuft_w_tall := 1.0
@export_range(0.3, 3.0, 0.05) var tuft_w_short := 1.5
@export_range(0.0, 1.0, 0.01) var tuft_dry := 0.03
@export_range(0.0, 4.0, 0.1) var flowers_tall := 0.5
@export_range(0.05, 1.0, 0.01) var flower_h := 0.34
@export_range(0.05, 1.5, 0.01) var dry_h := 0.54
@export_group("Úroveň detailu")
@export_range(5.0, 120.0, 1.0) var lod_full_size := 20.0
@export_range(0.125, 1.0, 0.125) var lod_min := 0.125
@export_group("Vítr")
@export_range(0.0, 360.0, 1.0) var wind_dir_deg := 30.0
@export_range(0.0, 1.5, 0.01) var wind_strength := 0.35
@export_range(0.0, 1.5, 0.01) var wind_gust := 0.45
@export_range(0.0, 5.0, 0.05) var wind_speed := 1.6
@export_range(0.02, 1.0, 0.01) var wind_scale := 0.22
@export_group("Rozhrnování (stopa)")
@export_range(8.0, 96.0, 1.0) var trail_size := 32.0
@export_range(2, 32, 1) var trail_px := 12
@export_range(0.1, 1.5, 0.01) var trample_r := 0.42
@export_range(0.0, 3.0, 0.05) var trample_hold := 0.35
@export_range(0.1, 6.0, 0.05) var trample_recover := 1.6
@export_range(0.0, 1.6, 0.05) var trample_bend := 1.25

func rebuild_props() -> PackedStringArray:
	return PackedStringArray(["enabled", "cell_edge", "tall_patch", "tall_louka", "tall_kopec", "tall_hora", "tall_piscina",
		"tuft_tall_h", "tuft_short_h", "tufts_tall", "tufts_short", "tuft_w_tall", "tuft_w_short", "tuft_dry",
		"flowers_tall", "flower_h", "dry_h"])

func labels() -> Dictionary:
	return {
		"enabled": "Tráva C (0/1)", "cell_edge": "Hrana buňky", "tall_patch": "Skvrny vysoké trávy",
		"tall_louka": "Vysoká: louka", "tall_kopec": "Vysoká: kopec", "tall_hora": "Vysoká: hora", "tall_piscina": "Vysoká: písčina",
		"tuft_tall_h": "Výška vysokého trsu", "tuft_short_h": "Výška nízkého trsu", "tufts_tall": "Trsů/buňku vysoká",
		"tufts_short": "Trsů/buňku nízká", "tuft_w_tall": "Šířka vysokého", "tuft_w_short": "Šířka nízkého",
		"tuft_dry": "Podíl suchých", "flowers_tall": "Kvítků/buňku", "flower_h": "Výška květin", "dry_h": "Výška suché trávy",
		"lod_full_size": "Plná hustota do záběru", "lod_min": "Min. hustota (LOD)",
		"wind_dir_deg": "Směr větru (°)", "wind_strength": "Síla větru", "wind_gust": "Poryvy", "wind_speed": "Rychlost větru",
		"wind_scale": "Měřítko větru", "trail_size": "Okno stopy", "trail_px": "Rozlišení stopy", "trample_r": "Poloměr rozhrnutí",
		"trample_hold": "Doba položení (s)", "trample_recover": "Návrat (s)", "trample_bend": "Max. náklon",
	}
