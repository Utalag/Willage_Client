extends RefCounted
## Hostitelské horniny útvarů (A1, krok 3b). Čistá data: tabulka `data/v1/utvary_hostitele.json`
## (typ útvaru → klíče hornin z `poradi_hornin.json`, min. hloubka, seznam `nikdy`).
## Minerály v žíle ověřuje stávající katalog `teren/hostitele.gd` (`mineraly_hostitele.json`).
## Bez stavu světa: jen id horniny a hloubka pod povrchem. Přenositelné do C# beze změny struktury.
const CESTA := "res://data/v1/utvary_hostitele.json"
const CESTA_HORNINY := "res://data/teren/poradi_hornin.json"
const KAT_MINERALY = preload("res://scripts/teren/hostitele.gd")
const MAX_IDX := 40                    # vrstvy úrovní 0–40 (jako geo_vrstvy)

var povoleno := true                   # přepínač a1_hostitele (vypnuto = původní chování: vše povoleno)
var nikdy := {}                        # id → true: půda, písek, ornice (žádný útvar)
var typy := {}                         # typ → {hosts: {id: true}, min_hloubka_m: float}
var _klic_id := {}                     # klíč horniny → id
var _min_hostu := {}                   # id minerálu → {id horniny: true}

func _init(zapnuto := true) -> void:
	povoleno = zapnuto
	_nacti_horniny()
	_nacti_tabulku()
	for mid in KAT_MINERALY.table():
		var h := {}
		for hid in KAT_MINERALY.table()[mid].host: h[int(hid)] = true
		_min_hostu[int(mid)] = h

func _json(cesta: String) -> Dictionary:
	var f := FileAccess.open(cesta, FileAccess.READ)
	if f == null:
		push_error("hostitele_utvaru: nelze otevřít " + cesta)
		return {}
	return JSON.parse_string(f.get_as_text())

var _vrstvy_id := []                   # id všech hornin úrovní 0–40 typu layer / seam

func _nacti_horniny() -> void:
	for r in _json(CESTA_HORNINY).get("rocks", []):
		var idx := int(r.get("idx", -1))
		if idx < 0 or idx > MAX_IDX: continue
		_klic_id[String(r.key)] = int(r.id)
		if String(r.get("kind", "layer")) in ["layer", "seam"]:
			_vrstvy_id.append(int(r.id))

func _ids(klice: Array) -> Dictionary:
	var out := {}
	for k in klice:
		if not _klic_id.has(String(k)):
			push_error("hostitele_utvaru: neznámý klíč horniny " + String(k))
			continue
		out[int(_klic_id[String(k)])] = true
	return out

func _nacti_tabulku() -> void:
	var d := _json(CESTA)
	nikdy = _ids(d.get("nikdy", []))
	var t: Dictionary = d.get("typy", {})
	for typ in t:
		var e: Dictionary = t[typ]
		var h := {}
		if e.get("hosts") is String and String(e.hosts) == "*":
			for id in _vrstvy_id: h[id] = true      # všechny horniny kromě `nikdy`
		else:
			h = _ids(e.get("hosts", []))
		typy[String(typ)] = {"hosts": h, "min_hloubka_m": float(e.get("min_hloubka_m", 0.0))}

## smí útvar daného typu vzniknout v hornině `vrstva_id` v hloubce `hloubka_m` pod povrchem?
func je_hostitel(typ: String, vrstva_id: int, hloubka_m: float) -> bool:
	if not povoleno: return true
	if nikdy.has(vrstva_id): return false
	var e: Dictionary = typy.get(typ, {})
	if e.is_empty(): return false
	if hloubka_m < float(e.min_hloubka_m): return false
	return e.hosts.has(vrstva_id)

## smí minerál `mineral_id` (8 měď, 9 železo…) vzniknout v hornině `vrstva_id`? Neznámý minerál = ano.
func mineral_ok(mineral_id: int, vrstva_id: int) -> bool:
	if not povoleno: return true
	if not _min_hostu.has(mineral_id): return true
	return _min_hostu[mineral_id].has(vrstva_id)
