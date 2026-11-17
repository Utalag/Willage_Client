class_name TunableParams
extends Resource
## Základ laditelných parametrů (Resource s @export → editovatelné v inspektoru Godotu, ukládatelné jako .tres předvolby).
## - CLI: `-- --<prefix>.<klic>=hodnota` (barva jako r,g,b), např. -- --surface.dual_soft=0.1
## - set_param(k, v) změní hodnotu a vyšle param_changed(k); hra podle rebuild_props() buď jen přenese uniformy,
##   nebo (se zpožděním) přestaví dotčené bloky. request_rebuild() = okamžitá přestavba (tlačítko „Aplikovat“).
## - labels() = české popisky pro ladicí okno (vývojový doplněk, hra na něj neodkazuje).

signal param_changed(prop: String)
signal rebuild_requested

## seznam vlastností, jejichž změna vyžaduje přestavbu sítí / polí / instancí (přepiš v potomkovi)
func rebuild_props() -> PackedStringArray:
	return PackedStringArray()

## české popisky {vlastnost: "popisek"} (přepiš v potomkovi)
func labels() -> Dictionary:
	return {}

func needs_rebuild(prop: String) -> bool:
	return prop in rebuild_props()

func set_param(prop: String, v) -> void:
	if get(prop) == v:
		return
	set(prop, v)
	param_changed.emit(prop)

func request_rebuild() -> void:
	rebuild_requested.emit()

## názvy všech @export vlastností (pořadí jako ve skriptu)
func param_names() -> PackedStringArray:
	var out := PackedStringArray()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE:
			out.append(p.name)
	return out

## zkopíruje hodnoty z jiného Resource stejného typu (načtení předvolby, reset) a ohlásí změny
func copy_from(o: Resource) -> void:
	var any_rebuild := false
	for k in param_names():
		var v = o.get(k)
		if v != null and get(k) != v:
			set(k, v)
			param_changed.emit(k)
			any_rebuild = any_rebuild or needs_rebuild(k)
	if any_rebuild:
		request_rebuild()

func reset_defaults() -> void:
	copy_from(get_script().new())

## přepis z příkazové řádky: --prefix.klic=hodnota
func apply_cli(prefix: String) -> void:
	var names := param_names()
	var pre := "--" + prefix + "."
	for a in OS.get_cmdline_user_args():
		if not (a.begins_with(pre) and a.contains("=")):
			continue
		var kv := a.substr(pre.length()).split("=", true, 1)
		if not kv[0] in names:
			push_warning("neznámý parametr %s: %s" % [prefix, kv[0]])
			continue
		var old = get(kv[0])
		match typeof(old):
			TYPE_INT: set(kv[0], int(kv[1]))
			TYPE_BOOL: set(kv[0], kv[1] in ["1", "true", "ano"])
			TYPE_COLOR:
				var c := kv[1].split(",")
				if c.size() >= 3:
					set(kv[0], Color(float(c[0]), float(c[1]), float(c[2])))
			_: set(kv[0], float(kv[1]))
