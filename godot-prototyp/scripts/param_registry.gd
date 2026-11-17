class_name ParamRegistry
extends RefCounted
## Registr laditelných parametrů a ukazatelů pro vývojové nástroje. Hra sem jen zapisuje, nástroje (např. doplněk
## addons/dev_tuning) najdou registr přes Engine meta „dev_registry“ (cesta ke skriptu) – hra o žádném nástroji neví.
## Vývojové doplňky: při `-- --dev` se načte každý `res://addons/*/dev_runtime.gd` (Node), pokud existuje.
## V exportu jsou doplňky vyřazené (export_presets.cfg exclude_filter), takže se nenačte nic.

const META_PATH := "dev_registry"   # Engine meta: cesta k tomuto skriptu (jen text – objekty v Engine meta padají při ukončení)

static var _params: Array = []      # [{title, res}]
static var _stats := {}             # název -> [WeakRef objektu, metoda] (lambdy ve statické proměnné padají při ukončení)

static func register(title: String, res: Resource) -> void:
	Engine.set_meta(META_PATH, "res://scripts/param_registry.gd")
	for e in _params:
		if e.res == res:
			return
	_params.append({"title": title, "res": res})

static func register_stat(name: String, obj: Object, method: StringName) -> void:
	Engine.set_meta(META_PATH, "res://scripts/param_registry.gd")
	_stats[name] = [weakref(obj), method]

static func entries() -> Array:
	return _params

static func stats() -> Dictionary:
	var out := {}
	for k in _stats:
		var o = _stats[k][0].get_ref()
		if o:
			out[k] = o.call(_stats[k][1])
	return out

static func load_dev_addons(root: Node) -> void:
	if not "--dev" in OS.get_cmdline_user_args():
		return
	var da := DirAccess.open("res://addons")
	if da == null:
		return
	for d in da.get_directories():
		var p := "res://addons/%s/dev_runtime.gd" % d
		if ResourceLoader.exists(p):
			var s = load(p)
			if s:
				var n = s.new()
				if n is Node:
					root.add_child.call_deferred(n)
					print("vývojový doplněk: ", p)
