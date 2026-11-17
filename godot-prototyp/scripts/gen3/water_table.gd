extends RefCounted
## Sdílená tabulka vlastností vody (perm, por, res, ret) pro gen-v3 v prototypu.
## Jediný zdroj pravdy je ../sdilene/materialy_voda.json (vedle složky projektu, Jan 19:18). Když tam není
## (export, jiné umístění projektu), použije se kopie res://data/materialy_voda.json; `source()` řekne, která se načetla.
## Kopii obnoví `tools/sync_shared_table.sh`; `same_as_shared()` ji porovná se zdrojem (kontrola ve vektorech a benchi).

const SHARED_TABLE := "../sdilene/materialy_voda.json"
const BUNDLED := "res://data/materialy_voda.json"
static var _cache := {}
static var _source := ""

static func shared_table_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(SHARED_TABLE).simplify_path()

static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if (d is Dictionary and d.has("materials")) else {}

static func load_shared_table() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = _read(shared_table_path())
	_source = SHARED_TABLE
	if _cache.is_empty():
		_cache = _read(BUNDLED)
		_source = BUNDLED
	if _cache.is_empty():
		push_error("chybí sdílená tabulka materiálů (%s ani %s)" % [shared_table_path(), BUNDLED])
		_source = ""
	return _cache

static func source() -> String:
	load_shared_table()
	return _source

## true = kopie v projektu je stejná jako sdílený zdroj (nebo zdroj není k dispozici)
static func same_as_shared() -> bool:
	var a := _read(shared_table_path())
	return a.is_empty() or a == _read(BUNDLED)
