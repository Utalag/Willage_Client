extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/horniny.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Tabulka pořadí hornin 0–63 (data/poradi_hornin.json, Gemini pro Jana [10]) a výběr aktivních hornin.
## Aktivní = "active" v tabulce, přepsatelné parametry rocks_on / rocks_off (seznam klíčů čárkami).

const PATH := "res://data/teren/poradi_hornin.json"
const ZONES := ["plast", "krystalinikum", "sedimenty"]

static var _raw := {}

static func raw() -> Dictionary:
	if _raw.is_empty():
		_raw = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
	return _raw

static func by_key(k: String) -> Dictionary:
	for e in raw().rocks:
		if e.key == k:
			return e
	return {}

static func active(e: Dictionary, p: Dictionary) -> bool:
	if e.key in p.get("rocks_off", []):
		return false
	if e.key in p.get("rocks_on", []):
		return true
	return e.active

## aktivní vrstvy zóny v pořadí tabulky (zdola nahoru)
static func layers(zone: String, p: Dictionary) -> Array:
	return raw().rocks.filter(func(e): return e.zone == zone and e.kind == "layer" and active(e, p))

## všechny aktivní vrstvy zdola nahoru (= pořadí hranic B v bloku)
static func all_layers(p: Dictionary) -> Array:
	var out := []
	for z in ZONES:
		out.append_array(layers(z, p))
	return out

## ZÁSOBA vrstev světa (Jan 16:46, klíny): výchozí aktivní + p.layer_pool (vrstvy, které smí blueprint zapnout).
## Všechny bloky mají hranice pro celou zásobu ve stejném pořadí; vrstva, kterou blok nemá, má mocnost 0.
static func pool_zone(zone: String, p: Dictionary) -> Array:
	return raw().rocks.filter(func(e): return e.zone == zone and e.kind == "layer" and (active(e, p) or e.key in p.get("layer_pool", [])))

static func pool(p: Dictionary) -> Array:
	var out := []
	for z in ZONES:
		out.append_array(pool_zone(z, p))
	return out

## má blok (podmnožina blueprintu sub = {on, off}) tuto vrstvu? on = vynucená přítomnost
static func present(e: Dictionary, p: Dictionary, sub: Dictionary) -> int:
	if e.key in sub.get("off", []): return 0
	if e.key in sub.get("on", []): return 2
	return 1 if active(e, p) else 0

static func mountain(p: Dictionary) -> Array:
	return raw().rocks.filter(func(e): return e.kind == "mountain" and active(e, p))

static func special(kind: String, p: Dictionary) -> Dictionary:
	for e in raw().rocks:
		if e.kind == kind and active(e, p):
			return e
	return {}

static func id_of(k: String) -> int:
	return int(by_key(k).id)

## ladicí paleta MaterialId → barva (horniny z tabulky, minerály z tabulky hostitelů)
static func palette() -> PackedColorArray:
	const HT = preload("res://scripts/teren/hostitele.gd")
	var pal := PackedColorArray(); pal.resize(256)
	for i in 256: pal[i] = Color(0, 0, 0, 0)
	for e in raw().rocks:
		if e.kind != "air":
			pal[int(e.id)] = Color(e.color)
	pal[1] = Color(0.56, 0.80, 0.47)   # tráva
	var t := HT.table()
	for m in t:
		if t[m].color != "":
			pal[m] = Color(t[m].color)
	return pal
