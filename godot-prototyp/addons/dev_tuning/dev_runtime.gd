extends CanvasLayer
## Ladicí okno (vývojový doplněk, NENÍ součástí hry ani exportu).
## Hra ho nezná: načte ho jen ParamRegistry.load_dev_addons() při `-- --dev`, pokud složka addons/dev_tuning existuje.
## Parametry najde přes Engine meta „dev_registry“ (cesta ke skriptu registru) → entries() = [{title, res}],
## stats() = ukazatele. Posuvníky se generují z @export vlastností (rozsah z @export_range, skupiny z @export_group).
## F1 = otevřít / zavřít, `-- --dev-panel` = otevřít hned po startu (screenshoty).
## Změna hodnoty: res.set_param(k, v) → hra hned přenese uniformy, tvar / pole / hustotu přestaví se zpožděním;
## „Aplikovat“ = přestavba hned. Předvolby: user://presety/<záložka>_<název>.tres.

const PRESET_DIR := "user://presety/"
var panel: PanelContainer
var tabs: TabContainer
var stats_lbl: Label
var preset_name: LineEdit
var preset_list: OptionButton
var reg
var entries: Array = []
var rows := {}          # res instance id -> {prop: [control, value label]}
var _acc := 0.0

func _ready() -> void:
	layer = 50
	var path: String = Engine.get_meta("dev_registry", "")
	if path == "":
		push_warning("ladicí okno: hra nezaregistrovala žádné parametry")
		return
	reg = load(path)
	entries = reg.entries()
	_build()
	panel.visible = "--dev-panel" in OS.get_cmdline_user_args()

func _input(e: InputEvent) -> void:
	if panel and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if panel == null or not panel.visible:
		return
	_acc += dt
	if _acc < 0.25:
		return
	_acc = 0.0
	var fps := Engine.get_frames_per_second()
	var t := "FPS %.0f   snímek %.1f ms   proces %.1f ms" % [fps, 1000.0 / maxf(fps, 0.01), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	var st: Dictionary = reg.stats()
	for k in st:
		t += "\n%s: %s" % [k, str(st[k])]
	t += "\nTrojúhelníků: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	stats_lbl.text = t

# ------------------------------------------------------------------ UI
func _build() -> void:
	panel = PanelContainer.new()
	panel.anchor_top = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left = 8; panel.offset_top = 8; panel.offset_right = 448; panel.offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.14, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "Ladicí okno (F1)"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)
	stats_lbl = Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	v.add_child(stats_lbl)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	_btn(hb, "Aplikovat", func(): _cur().request_rebuild() if _cur().has_method("request_rebuild") else null)
	_btn(hb, "Reset na výchozí", _reset)
	var hp := HBoxContainer.new()
	v.add_child(hp)
	preset_name = LineEdit.new()
	preset_name.placeholder_text = "název předvolby"
	preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.add_child(preset_name)
	_btn(hp, "Uložit předvolbu", _save)
	var hl := HBoxContainer.new()
	v.add_child(hl)
	preset_list = OptionButton.new()
	preset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_child(preset_list)
	_btn(hl, "Načíst předvolbu", _load)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for e in entries:
		tabs.add_child(_tab(e.title, e.res))
	tabs.tab_changed.connect(func(_i): _refresh_presets())
	_refresh_presets()

func _btn(parent: Node, text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(f)
	parent.add_child(b)
	return b

func _cur() -> Resource:
	return entries[tabs.current_tab].res

func _tab(title: String, res: Resource) -> Control:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var labels: Dictionary = res.labels() if res.has_method("labels") else {}
	var rb: PackedStringArray = res.rebuild_props() if res.has_method("rebuild_props") else PackedStringArray()
	var box: VBoxContainer = null
	var group := "Obecné"
	var r := {}
	rows[res.get_instance_id()] = r
	for p in res.get_property_list():
		if p.usage & PROPERTY_USAGE_GROUP:
			group = p.name
			box = null   # sekce vznikne až s první vlastností (prázdné skupiny Resource se nezobrazí)
			continue
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE):
			continue
		if box == null:
			box = _section(v, group)
		var pname: String = p.name
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := Label.new()
		l.text = labels.get(pname, pname) + (" ⟳" if pname in rb else "")
		l.tooltip_text = pname + ("  (mění tvar → přestavba)" if pname in rb else "")
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.custom_minimum_size.x = 170
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		var val = res.get(pname)
		match typeof(val):
			TYPE_BOOL:
				var cb := CheckBox.new()
				cb.button_pressed = val
				cb.toggled.connect(func(on): _apply(res, pname, on))
				row.add_child(cb)
				r[pname] = [cb, null]
			TYPE_COLOR:
				var cp := ColorPickerButton.new()
				cp.color = val
				cp.custom_minimum_size = Vector2(120, 20)
				cp.color_changed.connect(func(c): _apply(res, pname, c))
				row.add_child(cp)
				r[pname] = [cp, null]
			TYPE_INT, TYPE_FLOAT:
				var lo := 0.0; var hi := 1.0; var stp := 0.01
				if p.hint == PROPERTY_HINT_RANGE:
					var h: PackedStringArray = p.hint_string.split(",")
					lo = float(h[0]); hi = float(h[1])
					if h.size() > 2: stp = float(h[2])
				else:
					hi = maxf(absf(float(val)) * 4.0, 1.0)
				if typeof(val) == TYPE_INT: stp = maxf(stp, 1.0)
				var s := HSlider.new()
				s.min_value = lo; s.max_value = hi; s.step = stp
				s.value = val
				s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				s.custom_minimum_size.x = 140
				var vl := Label.new()
				vl.custom_minimum_size.x = 48
				vl.add_theme_font_size_override("font_size", 12)
				vl.text = _fmt(val)
				var is_int := typeof(val) == TYPE_INT
				s.value_changed.connect(func(x):
					var nv = int(round(x)) if is_int else x
					vl.text = _fmt(nv)
					_apply(res, pname, nv))
				row.add_child(s)
				row.add_child(vl)
				r[pname] = [s, vl]
			_:
				var x := Label.new()
				x.text = str(val)
				row.add_child(x)
	return sc

func _section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var b := Button.new()
	b.text = "▼ " + title
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	parent.add_child(b)
	var box := VBoxContainer.new()
	parent.add_child(box)
	b.pressed.connect(func():
		box.visible = not box.visible
		b.text = ("▼ " if box.visible else "▶ ") + title)
	return box

static func _fmt(v) -> String:
	return str(v) if typeof(v) == TYPE_INT else ("%.3f" % v).rstrip("0").rstrip(".")

func _apply(res: Resource, k: String, v) -> void:
	if res.has_method("set_param"):
		res.set_param(k, v)
	else:
		res.set(k, v)
		res.emit_changed()

## hodnoty ovládacích prvků podle Resource (po resetu / načtení předvolby)
func _sync(res: Resource) -> void:
	var r: Dictionary = rows.get(res.get_instance_id(), {})
	for k in r:
		var c = r[k][0]
		var v = res.get(k)
		if c is CheckBox: c.set_pressed_no_signal(v)
		elif c is ColorPickerButton: c.color = v
		elif c is HSlider:
			c.set_value_no_signal(v)
			r[k][1].text = _fmt(v)

func _reset() -> void:
	var res := _cur()
	if res.has_method("reset_defaults"):
		res.reset_defaults()
	_sync(res)

func _file(pn: String) -> String:
	return PRESET_DIR + "%s_%s.tres" % [entries[tabs.current_tab].title.to_lower(), pn.validate_filename()]

func _save() -> void:
	var n := preset_name.text.strip_edges()
	if n == "":
		n = Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(PRESET_DIR)
	var err := ResourceSaver.save(_cur().duplicate(), _file(n))
	print("ladicí okno: předvolba ", _file(n), " -> ", error_string(err))
	_refresh_presets()

func _refresh_presets() -> void:
	preset_list.clear()
	var d := DirAccess.open(PRESET_DIR)
	if d == null:
		return
	var pre: String = entries[tabs.current_tab].title.to_lower() + "_"
	for f in d.get_files():
		if f.begins_with(pre) and f.ends_with(".tres"):
			preset_list.add_item(f.trim_prefix(pre).trim_suffix(".tres"))

func _load() -> void:
	if preset_list.selected < 0:
		return
	var path := _file(preset_list.get_item_text(preset_list.selected))
	var r = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if r == null:
		push_warning("ladicí okno: nelze načíst " + path)
		return
	var res := _cur()
	if res.has_method("copy_from"):
		res.copy_from(r)
	_sync(res)
	print("ladicí okno: načteno ", path)
