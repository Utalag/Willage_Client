extends CanvasLayer
## Uživatelské rozhraní: lišta kandidátů dole, panel úprav vpravo, nápověda vlevo nahoře.

signal candidate_picked(i: int)
signal settings_changed
signal confirm_pressed
signal cancel_pressed
signal building_picked(i: int)
signal tab_changed(k: int)

const Mat = preload("res://scripts/mat.gd")
const Veg = preload("res://scripts/veg.gd")

const KIND_NAMES := {"louka": "louka", "kopec": "kopec", "hora": "hora", "piscina": "písčina"}
const KIND_COLORS := {"louka": Color(0.56, 0.80, 0.47), "kopec": Color(0.78, 0.86, 0.50),
	"hora": Color(0.80, 0.68, 0.74), "piscina": Color(0.98, 0.89, 0.62)}
const SIDE_LABELS := ["Sever (S)", "Východ (V)", "Jih (J)", "Západ (Z)"]

var bar: HBoxContainer
var card_group := ButtonGroup.new()
var cards: Array[Button] = []
var panel: PanelContainer
var title_lbl: Label
var info_lbl: Label
var edit_box: VBoxContainer
var mirror_cb: CheckButton
var rot_lbl: Label
var shift_lbl: Label
var side_opts: Array[OptionButton] = []
var mat_grid: GridContainer
var rarity_lbl: RichTextLabel
var veg_lbl: RichTextLabel
var timing_lbl: Label
var save_btn: Button
var cancel_btn: Button
var hint_lbl: Label
var inv_lbl: RichTextLabel
var inv_panel: PanelContainer
var sbar: HBoxContainer
var bar_title: Label
var tab_btns: Array[Button] = []
var bcards: Array[Button] = []
var bgroup := ButtonGroup.new()
var delta_txt := ""
var _block = null
var _mute := false

func _style(bg: Color, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(2)
	return sb

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color(0.27, 0.22, 0.33))
	theme.set_stylebox("panel", "PanelContainer", _style(Color(1.0, 0.96, 0.97, 0.92)))
	theme.set_stylebox("normal", "Button", _style(Color(0.98, 0.88, 0.92), 10))
	theme.set_stylebox("hover", "Button", _style(Color(1.0, 0.80, 0.88), 10))
	theme.set_stylebox("pressed", "Button", _style(Color(0.95, 0.66, 0.80), 10))
	theme.set_stylebox("disabled", "Button", _style(Color(0.92, 0.90, 0.92), 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(st, "Button", Color(0.30, 0.22, 0.36))
		theme.set_color(st, "CheckButton", Color(0.30, 0.22, 0.36))
		theme.set_color(st, "OptionButton", Color(0.30, 0.22, 0.36))
	theme.set_stylebox("normal", "OptionButton", _style(Color(0.94, 0.90, 1.0), 8))
	theme.set_stylebox("hover", "OptionButton", _style(Color(0.90, 0.84, 1.0), 8))
	theme.set_stylebox("pressed", "OptionButton", _style(Color(0.86, 0.80, 1.0), 8))
	theme.set_stylebox("disabled", "OptionButton", _style(Color(0.92, 0.92, 0.92), 8))
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_color("font_disabled_color", "OptionButton", Color(0.55, 0.50, 0.58))
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_color("default_color", "RichTextLabel", Color(0.27, 0.22, 0.33))
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	# --- lišta dole
	var bar_panel := PanelContainer.new()
	bar_panel.anchor_left = 0; bar_panel.anchor_right = 1; bar_panel.anchor_top = 1; bar_panel.anchor_bottom = 1
	bar_panel.offset_left = 10; bar_panel.offset_right = -300; bar_panel.offset_top = -112; bar_panel.offset_bottom = -10
	root.add_child(bar_panel)
	var bv := VBoxContainer.new()
	bar_panel.add_child(bv)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	bv.add_child(th)
	var tg := ButtonGroup.new()
	for k in 2:
		var tb := Button.new()
		tb.text = ["Bloky", "Stavby"][k]
		tb.toggle_mode = true
		tb.button_group = tg
		tb.button_pressed = k == 0
		tb.add_theme_font_size_override("font_size", 13)
		var kk := k
		tb.pressed.connect(func(): show_tab(kk); tab_changed.emit(kk))
		th.add_child(tb)
		tab_btns.append(tb)
	bar_title = Label.new()
	th.add_child(bar_title)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bv.add_child(bar)
	sbar = HBoxContainer.new()
	sbar.add_theme_constant_override("separation", 8)
	sbar.visible = false
	bv.add_child(sbar)
	bar_panel.offset_top = -124
	show_tab(0)

	# --- panel vpravo
	panel = PanelContainer.new()
	panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_top = 0; panel.anchor_bottom = 1
	panel.offset_left = -282; panel.offset_right = -10; panel.offset_top = 10; panel.offset_bottom = -10
	root.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 5)
	panel.add_child(pv)
	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 19)
	pv.add_child(title_lbl)
	info_lbl = Label.new()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(info_lbl)

	edit_box = VBoxContainer.new()
	edit_box.add_theme_constant_override("separation", 4)
	pv.add_child(edit_box)
	edit_box.add_child(HSeparator.new())
	mirror_cb = CheckButton.new()
	mirror_cb.text = "Zrcadlení (F)"
	mirror_cb.toggled.connect(_on_mirror)
	edit_box.add_child(mirror_cb)
	rot_lbl = _stepper(edit_box, "Rotace (R)", func(d): _block.rot = (_block.rot + d + 4) % 4)
	shift_lbl = _stepper(edit_box, "Výška (+/−)", func(d): _block.shift = clampi(_block.shift + d, -4, 4))
	var sl := Label.new()
	sl.text = "Napojení stran"
	edit_box.add_child(sl)
	var sg := GridContainer.new()
	sg.columns = 2
	edit_box.add_child(sg)
	for i in 4:
		var l := Label.new()
		l.text = SIDE_LABELS[i]
		l.custom_minimum_size.x = 96
		sg.add_child(l)
		var ob := OptionButton.new()
		ob.add_item("Auto", 0)
		for n in range(1, 5):
			ob.add_item("Dorovnat %d" % n, n)
		ob.add_item("Ponechat", 5)
		ob.custom_minimum_size.x = 140
		var si := i
		ob.item_selected.connect(_on_side.bind(si))
		sg.add_child(ob)
		side_opts.append(ob)

	pv.add_child(HSeparator.new())
	var ml := Label.new()
	ml.text = "Materiály (buňky)"
	pv.add_child(ml)
	mat_grid = GridContainer.new()
	mat_grid.columns = 3
	mat_grid.add_theme_constant_override("v_separation", 1)
	pv.add_child(mat_grid)
	rarity_lbl = RichTextLabel.new()
	rarity_lbl.bbcode_enabled = true
	rarity_lbl.fit_content = true
	rarity_lbl.scroll_active = false
	pv.add_child(rarity_lbl)
	veg_lbl = RichTextLabel.new()
	veg_lbl.bbcode_enabled = true
	veg_lbl.fit_content = true
	veg_lbl.scroll_active = false
	pv.add_child(veg_lbl)
	timing_lbl = Label.new()
	timing_lbl.add_theme_font_size_override("font_size", 12)
	timing_lbl.modulate = Color(1, 1, 1, 0.75)
	pv.add_child(timing_lbl)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(spacer)
	var hb := HBoxContainer.new()
	pv.add_child(hb)
	save_btn = Button.new()
	save_btn.text = "Uložit (Enter)"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func(): confirm_pressed.emit())
	hb.add_child(save_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "Zrušit (Esc)"
	cancel_btn.pressed.connect(func(): cancel_pressed.emit())
	hb.add_child(cancel_btn)

	# --- nápověda
	var hp := PanelContainer.new()
	hp.position = Vector2(10, 10)
	root.add_child(hp)
	hint_lbl = Label.new()
	hp.add_child(hint_lbl)
	# --- inventář ostrova (kopání)
	inv_panel = PanelContainer.new()
	inv_panel.position = Vector2(10, 96)
	root.add_child(inv_panel)
	inv_lbl = RichTextLabel.new()
	inv_lbl.bbcode_enabled = true
	inv_lbl.fit_content = true
	inv_lbl.custom_minimum_size = Vector2(250, 0)
	inv_panel.add_child(inv_lbl)
	inv_panel.visible = false
	show_block(null, "", false)

func _stepper(parent: Control, label: String, apply: Callable) -> Label:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 96
	h.add_child(l)
	var minus := Button.new()
	minus.text = "  −  "
	h.add_child(minus)
	var v := Label.new()
	v.custom_minimum_size.x = 50
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var plus := Button.new()
	plus.text = "  +  "
	h.add_child(plus)
	minus.pressed.connect(_on_step.bind(apply, -1))
	plus.pressed.connect(_on_step.bind(apply, 1))
	return v

func _on_mirror(on: bool) -> void:
	if _mute or _block == null:
		return
	_block.mirror = on
	settings_changed.emit()

func _on_side(k: int, si: int) -> void:
	if _mute or _block == null:
		return
	_block.sides[si] = side_opts[si].get_item_id(k)
	settings_changed.emit()

func _on_step(apply: Callable, d: int) -> void:
	if _block == null:
		return
	apply.call(d)
	settings_changed.emit()

func set_candidates(list: Array) -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	for i in list.size():
		var b = list[i]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = card_group
		btn.custom_minimum_size = Vector2(150, 62)
		btn.text = "%s\n%s · %s" % [b.title, KIND_NAMES[b.kind], _seed_txt(b)]
		var col: Color = KIND_COLORS[b.kind]
		var sb := _style(col.lerp(Color.WHITE, 0.45), 10)
		if b.category == "unikátní":
			sb.border_color = Color(1.0, 0.70, 0.20)
			sb.set_border_width_all(3)
			btn.text = "★ " + btn.text
		elif b.category == "pevný":
			sb.border_color = Color(0.55, 0.65, 0.95)
		btn.add_theme_stylebox_override("normal", sb)
		var sp := sb.duplicate()
		sp.bg_color = col.darkened(0.05)
		sp.border_color = Color(0.85, 0.35, 0.60)
		sp.set_border_width_all(3)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("hover_pressed", sp)
		btn.add_theme_font_size_override("font_size", 13)
		btn.tooltip_text = "katalog: " + b.category
		var idx := i
		btn.pressed.connect(func(): candidate_picked.emit(idx))
		bar.add_child(btn)
		cards.append(btn)

func select_card(i: int) -> void:
	for k in cards.size():
		cards[k].set_pressed_no_signal(k == i)

## Ukáže blok v panelu; editable = náhled (lze upravovat a uložit)
func show_block(b, slot_txt: String, editable: bool, neighbors := [null, null, null, null]) -> void:
	_block = b if editable else null
	edit_box.visible = editable
	save_btn.visible = editable
	cancel_btn.visible = b != null and editable
	for c in mat_grid.get_children():
		c.queue_free()
	if b == null:
		title_lbl.text = "Ostrov Willage"
		info_lbl.text = "Vyber blok v liště dole. Kliknutím na blok ostrova zobrazíš jeho materiály."
		rarity_lbl.text = ""
		veg_lbl.text = ""
		timing_lbl.text = ""
		return
	title_lbl.text = b.title
	info_lbl.text = "Typ: %s · %s\nKatalog: %s\n%s" % [KIND_NAMES[b.kind], _seed_txt(b), b.category, slot_txt]
	_mute = true
	mirror_cb.button_pressed = b.mirror
	rot_lbl.text = "%d°" % (b.rot * 90)
	shift_lbl.text = "%+d" % b.shift if b.shift != 0 else "0"
	for i in 4:
		side_opts[i].select(side_opts[i].get_item_index(b.sides[i]))
		side_opts[i].disabled = neighbors[i] == null
		side_opts[i].tooltip_text = "bez souseda" if neighbors[i] == null else ""
	_mute = false
	save_btn.disabled = b.cells.is_empty()
	var total := 0
	for m in range(1, Mat.COUNT):
		total += b.summary[m]
	for m in range(1, Mat.COUNT):
		var n: int = b.summary[m]
		if n == 0:
			continue
		var sw := ColorRect.new()
		sw.color = Mat.COLORS[m]
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mat_grid.add_child(sw)
		var nl := Label.new()
		nl.text = Mat.NAMES[m]
		nl.custom_minimum_size.x = 120
		mat_grid.add_child(nl)
		var cl := Label.new()
		cl.text = "%d  (%.1f %%)" % [n, 100.0 * n / total]
		mat_grid.add_child(cl)
	var r0 := Mat.rarity_of(b.summary_orig)
	var r1 := Mat.rarity_of(b.summary)
	rarity_lbl.text = "Rarita materiálů (původní / aktuální):\n[color=#%s][b]%s[/b][/color] / [color=#%s][b]%s[/b][/color]  (%.3f → %.3f)%s" % [
		Mat.RARITY_COLORS[r0].darkened(0.3).to_html(false), Mat.RARITY_NAMES[r0],
		Mat.RARITY_COLORS[r1].darkened(0.3).to_html(false), Mat.RARITY_NAMES[r1],
		Mat.score_of(b.summary_orig), Mat.score_of(b.summary), delta_txt]
	var vt := "[b]Vegetace[/b] (zatímní)\n"
	var parts := []
	for i in range(1, Veg.COUNT):
		if b.veg_summary.size() > i and b.veg_summary[i] > 0:
			parts.append("%s %d" % [Veg.NAMES[i], b.veg_summary[i]])
	vt += ", ".join(parts) if parts.size() > 0 else "bez porostu"
	if b.veg_summary.size() > 0:
		var v0 := Veg.rarity_of(b.veg_summary_orig)
		var v1 := Veg.rarity_of(b.veg_summary)
		vt += "\nRarita vegetace (původní / aktuální):\n[color=#%s][b]%s[/b][/color] / [color=#%s][b]%s[/b][/color]  (%.2f)" % [
			Mat.RARITY_COLORS[v0].darkened(0.3).to_html(false), Mat.RARITY_NAMES[v0],
			Mat.RARITY_COLORS[v1].darkened(0.3).to_html(false), Mat.RARITY_NAMES[v1], Veg.mean_score(b.veg_summary)]
	veg_lbl.text = vt
	timing_lbl.text = "generování %.0f ms · mesh %.0f ms" % [b.gen_ms, b.mesh_ms]

func _seed_txt(b) -> String:
	return "seed „%s“" % b.title if b.category == "unikátní" else "seed %d" % b.seed

func show_tab(k: int) -> void:
	tab_btns[k].set_pressed_no_signal(true)
	bar.visible = k == 0
	sbar.visible = k == 1
	bar_title.text = "  vyber blok, najeď na zvýrazněné místo v mlze a klikni" if k == 0 else "  vyber stavbu, najeď na rovné místo (zelená) a klikni · R otočit · Esc zrušit"

func set_buildings(names: Array, colors: Array) -> void:
	for i in names.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = bgroup
		btn.custom_minimum_size = Vector2(150, 62)
		btn.text = names[i]
		var sb := _style(Color(colors[i]).lerp(Color.WHITE, 0.45), 10)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		var sp := sb.duplicate()
		sp.border_color = Color(0.85, 0.35, 0.60)
		sp.set_border_width_all(3)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_stylebox_override("hover_pressed", sp)
		btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		btn.pressed.connect(func(): building_picked.emit(idx))
		sbar.add_child(btn)
		bcards.append(btn)

func select_building(i: int) -> void:
	for k in bcards.size():
		bcards[k].set_pressed_no_signal(k == i)

func set_inventory(inv: PackedInt32Array, mode_txt: String, sel := -1) -> void:
	var parts := []
	var k := 0
	for m in range(1, Mat.COUNT):
		if inv[m] > 0:
			k += 1
			var t := "%d:[color=#%s]■[/color] %s %d" % [k, Mat.COLORS[m].darkened(0.2).to_html(false), Mat.NAMES[m], inv[m]]
			parts.append("[u][b]%s[/b][/u]" % t if m == sel else t)
	inv_lbl.text = "[b]Inventář ostrova[/b] %s\n%s" % [mode_txt, ", ".join(parts) if parts.size() > 0 else "prázdný"]
	inv_panel.visible = true

func set_hint(t: String) -> void:
	hint_lbl.text = t
