extends CanvasLayer
## E95 (zkušební větev zkusebni-vse, Jan 2026-11-20 11:23): panel přepínačů Bloků 2–4 na obrazovce, vlevo, sbalitelný.
## Každý ovládací prvek má bublinu (tooltip) česky. Seznam a texty: prepinace.gd.
## Přepínače terénu a vody se zapíšou do ostrov_teren.over a ostrov se přegeneruje znovu načtením scény (stav panelu,
## kamera a hodnoty zůstanou ve statických proměnných). E85 okraj a E86 platí hned, E90 / E91 / svislý řez jsou za běhu.
## Prázdný stav = výchozí hra beze změny.
const P = preload("res://scripts/game/zkusebni/prepinace.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const SR = preload("res://scripts/game/zkusebni/shader_rez.gd")
const LOD = preload("res://scripts/game/zkusebni/lod_okoli.gd")
const SP = preload("res://scripts/surface/surface_params.gd")

## odhad ceny do bublin (změřeno headless tools/zkusebni_e95.gd, viz blueprint-studie/shots/e95/)
const CENY := {"teren": "4–6", "lod": "1–3", "pruhl": "1–4", "rez": "1–4"}
const CASY := {}

static var stav := {}          # klíč → hodnota (jen to, co se liší od výchozí hry)
static var sbaleno := false
static var regen_t0 := 0       # µs; > 0 = probíhá přestavba (znovu načtení scény)
static var regen_klic := ""
static var kamera := {}
static var posledni := {}      # poslední přestavba: {klic, ms, otisk}
static var start_otisk := ""
static var aktivni = null      # běžící panel (pro testy)

signal hotovo(info: Dictionary)

var main: Node
var island: Node3D
var rig: Node3D
var cam: Camera3D
var ctrls := {}
var rows := {}
var body: Control
var head_btn: Button
var status: Label
var lod_info := {}
var _deb := 0.0
var _deb_klic := ""
var _acc := 0.0
var _mute := false

func _init() -> void:
	layer = 6
	name = "ZkusebniPanel"

# ---------------------------------------------------------------- hodnoty
static func vychozi(k: String):
	if P.VYCHOZI_JINE.has(k): return P.VYCHOZI_JINE[k]
	if k == "p89_meritko": return false
	var d: Dictionary = T.PR.defaults()
	d.merge(T.HRA, true)
	return d.get(k)

static func hodnota(k: String):
	return stav.get(k, vychozi(k))

static func _sync_over() -> void:
	var o := {}
	for k in stav:
		var e := P.zaznam(k)
		if e.get("cil", "") in ["teren", "zive"] and k != "p89_meritko": o[k] = stav[k]
	T.over = o

static func _rodic_on(e: Dictionary) -> bool:
	if not e.has("rodic"): return true
	var v = hodnota(e.rodic)
	if v == null: return false
	if v is bool: return v
	return float(v) > 0.0

# ---------------------------------------------------------------- start
func _ready() -> void:
	aktivni = self
	main = get_parent().get_parent()
	island = main.get_node("Island")
	rig = main.get_node("CameraRig")
	cam = rig.get_node("Camera")
	_build_ui()
	SP.inst().p89_meritko = bool(hodnota("p89_meritko"))
	if not kamera.is_empty() and bool(kamera.get("metry")) == bool(hodnota("p89_meritko")):
		rig.center = kamera.center; rig.yaw = kamera.yaw; cam.size = kamera.size; rig.place()
	_apply_live()
	var ot := _otisk()
	if start_otisk == "" and stav.is_empty(): start_otisk = ot
	if regen_t0 > 0:
		var ms := (Time.get_ticks_usec() - regen_t0) / 1000.0
		posledni = {"klic": regen_klic, "ms": ms, "otisk": ot}
		regen_t0 = 0
		print("E95 přestavba (%s): %.0f ms, otisk vody %s" % [regen_klic, ms, ot])
		_status("Přestavba (%s): %.1f s · otisk vody %s" % [regen_klic, ms / 1000.0, ot])
	else:
		_status("Otisk vody %s%s" % [ot, " (výchozí hra)" if stav.is_empty() else ""])
	_emit_later.call_deferred()

func _emit_later() -> void:
	await get_tree().process_frame
	hotovo.emit(posledni)

func _exit_tree() -> void:
	if aktivni == self: aktivni = null
	SR.disable()

func _otisk() -> String:
	var v = island.get("voda")
	if v == null: return "-"
	var h: Dictionary = v.hydro()
	return str(h.get("otisk", "-"))

# ---------------------------------------------------------------- UI
func _tip(e: Dictionary) -> String:
	var s: String = e.tip
	var c: String = CASY.get(e.k, "")
	for k in CENY:
		s = s.replace("{%s}" % k, c if c != "" else CENY[k])
	return s + "\n[%s]" % e.k

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.position = Vector2(10, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.16, 0.86); sb.set_corner_radius_all(10); sb.set_content_margin_all(8)
	root.add_theme_stylebox_override("panel", sb)
	add_child(root)
	var v := VBoxContainer.new()
	root.add_child(v)
	head_btn = Button.new()
	head_btn.flat = true
	head_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head_btn.tooltip_text = "Zkušební panel (E95, větev zkusebni-vse): přepínače Bloků 2–4 a svislý řez.\nKlik = sbalit / rozbalit. Najetím myší na řádek se ukáže, co přepínač dělá."
	head_btn.pressed.connect(func(): sbaleno = not sbaleno; _refresh())
	v.add_child(head_btn)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vh := get_viewport().get_visible_rect().size.y if get_viewport() else 800.0
	sc.custom_minimum_size = Vector2(370, clampf(vh - 300.0, 220.0, 620.0))
	v.add_child(sc)
	body = sc
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for g in P.SKUPINY:
		var gl := Label.new()
		gl.text = g
		gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		list.add_child(gl)
		for e in P.SEZNAM:
			if e.g == g: list.add_child(_row(e))
	var foot := HBoxContainer.new()
	var off := Button.new()
	off.text = "Vše vypnout"
	off.tooltip_text = "Vrátí všechny přepínače na výchozí hru (vypnuto). Pokud byl zapnutý přepínač terénu nebo vody, ostrov se přegeneruje (~%s s)." % CENY.teren
	off.pressed.connect(vse_vypnout)
	foot.add_child(off)
	list.add_child(foot)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(350, 0)
	status.add_theme_font_size_override("font_size", 12)
	v.add_child(status)
	_refresh()

func _row(e: Dictionary) -> Control:
	var tip := _tip(e)
	var h := HBoxContainer.new()
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	if e.has("rodic"):
		var pad := Control.new(); pad.custom_minimum_size = Vector2(18, 0); h.add_child(pad)
	var k: String = e.k
	match e.t:
		"b":
			var cb := CheckBox.new()
			cb.text = e.n
			cb.tooltip_text = tip
			cb.button_pressed = bool(hodnota(k))
			cb.toggled.connect(func(on): if not _mute: nastav(k, on))
			h.add_child(cb); ctrls[k] = cb
		"f", "i":
			var l := Label.new(); l.text = e.n; l.tooltip_text = tip; l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.custom_minimum_size = Vector2(150, 0); l.clip_text = true
			h.add_child(l)
			var val := Label.new(); val.custom_minimum_size = Vector2(44, 0); val.tooltip_text = tip; val.mouse_filter = Control.MOUSE_FILTER_PASS
			if e.t == "f":
				var s := HSlider.new()
				s.min_value = e.min; s.max_value = e.max; s.step = e.krok
				s.custom_minimum_size = Vector2(120, 0); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				s.tooltip_text = tip
				s.value = float(hodnota(k))
				val.text = _fmt(s.value)
				s.value_changed.connect(func(x): val.text = _fmt(x); if not _mute: nastav(k, x))
				h.add_child(s); ctrls[k] = s
			else:
				var sp := SpinBox.new()
				sp.min_value = e.min; sp.max_value = e.max; sp.step = 1; sp.tooltip_text = tip
				sp.value = int(hodnota(k))
				sp.value_changed.connect(func(x): if not _mute: nastav(k, int(x)))
				h.add_child(sp); ctrls[k] = sp
			h.add_child(val)
		"o":
			var l := Label.new(); l.text = e.n; l.tooltip_text = tip; l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.custom_minimum_size = Vector2(150, 0)
			h.add_child(l)
			var ob := OptionButton.new()
			ob.tooltip_text = tip
			for i in e.moznosti.size(): ob.add_item(e.moznosti[i], i)
			ob.selected = maxi(0, e.hodnoty.find(int(hodnota(k))))
			ob.item_selected.connect(func(i): if not _mute: nastav(k, e.hodnoty[i]))
			h.add_child(ob); ctrls[k] = ob
	rows[k] = h
	return h

func _fmt(x: float) -> String:
	return ("%.3f" % x).rstrip("0").rstrip(".").replace(".", ",")

func _refresh() -> void:
	head_btn.text = ("▸ " if sbaleno else "▾ ") + "Přepínače (zkušební E95)" + ("  · zapnuto %d" % stav.size() if stav.size() > 0 else "")
	body.visible = not sbaleno
	for k in rows:
		rows[k].visible = _rodic_on(P.zaznam(k))
	_mute = true
	for k in ctrls:
		var c = ctrls[k]; var e := P.zaznam(k)
		match e.t:
			"b": c.button_pressed = bool(hodnota(k))
			"f", "i": c.value = float(hodnota(k))
			"o": c.selected = maxi(0, e.hodnoty.find(int(hodnota(k))))
	_mute = false

func _status(s: String) -> void:
	if status: status.text = s

# ---------------------------------------------------------------- změny
## nastaví hodnotu (z UI i z testu) a provede, co je potřeba
func nastav(k: String, v, hned := false) -> void:
	var e := P.zaznam(k)
	if e.is_empty(): push_warning("E95: neznámý přepínač " + k); return
	var d = vychozi(k)
	if (v is float or d is float) and d != null: v = float(v)
	if d != null and str(v) == str(d): stav.erase(k)
	else: stav[k] = v
	_refresh()
	match e.cil:
		"teren":
			if k == "p89_meritko": SP.inst().p89_meritko = bool(v)
			_sync_over()
			if not _rodic_on(e): return
			if e.t == "b" or hned: prestavba(k)
			else: _deb = 0.6; _deb_klic = k
		"zive":
			_sync_over()
			T.ensure()
			T.p[k] = v
			_status("%s = %s (platí hned, bez přegenerování)" % [k, str(v)])
		"lod":
			if e.t == "b" or hned: lod_prestavba()
			else: _deb = 0.4; _deb_klic = "lod"
		"pruhl", "rez":
			_apply_shaders()

func vse_vypnout() -> void:
	var regen := false
	for k in stav:
		if P.zaznam(k).get("cil", "") == "teren": regen = true
	stav.clear()
	SP.inst().p89_meritko = false
	T.over = {}
	T.ensure()
	var d: Dictionary = T.PR.defaults(); d.merge(T.HRA, true)
	for k in ["p85_okraj", "p86_otoceni"]: T.p[k] = d.get(k)
	_refresh()
	_apply_live()
	if regen: prestavba("vše vypnout")
	else: _status("Vše vypnuto (bez přegenerování).")

## přegenerování ostrova: znovu načtení scény (hodnoty panelu, kamera zůstanou)
func prestavba(klic: String) -> void:
	_status("Přegenerovávám ostrov (%s)…" % klic)
	regen_t0 = Time.get_ticks_usec()
	regen_klic = klic
	kamera = {"center": rig.center, "yaw": rig.yaw, "size": cam.size, "metry": island.scale != Vector3.ONE}
	SR.disable()
	T.reset()
	get_tree().reload_current_scene.call_deferred()

func _apply_live() -> void:
	lod_prestavba()
	_apply_shaders()

func lod_prestavba() -> void:
	var old = island.get_node_or_null("LOD90_okoli")
	if old: old.free()
	lod_info = {}
	if not bool(hodnota("p90_lod")): return
	var prm := {}
	for k in ["p90_okoli", "p90_slupka", "p90_daleko_m", "p90_barvy"]: prm[k] = hodnota(k)
	lod_info = LOD.build(island, prm)
	if SR.on: SR.enable(main, island)
	_status("E90 LOD: %d ploch, %d trojúhelníků, %.1f s" % [lod_info.ploch, lod_info.trojuhelniku, lod_info.ms / 1000.0])
	print("E95 LOD: ", lod_info.ms, " ms, ", lod_info.trojuhelniku, " tri")

func _apply_shaders() -> void:
	var need: bool = bool(hodnota("p91_pruhlednost")) or int(hodnota("zk_rez")) > 0
	if need and not SR.on:
		var t0 := Time.get_ticks_usec()
		var n := SR.enable(main, island)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("E95 shadery: %d materiálů upraveno za %.1f ms" % [n, ms])
		_status("Upraveno %d materiálů (%.0f ms); první snímek přeloží shadery." % [n, ms])
	elif not need and SR.on:
		SR.disable()
	_update_uniforms()

func _feet() -> Vector3:
	var vp := get_viewport().get_visible_rect().size * 0.5
	var g = island.cell_at_ray(cam.project_ray_origin(vp), cam.project_ray_normal(vp))
	if g == null: return rig.center
	var s := Vector2i(floori(g.x / 16.0), floori(g.y / 16.0))
	var b = island.blocks.get(s)
	var hy := 16.0
	if b: hy = b.hm[(g.x - s.x * 16) * 16 + (g.y - s.y * 16)] * 0.5
	return island.global_transform * Vector3(g.x + 0.5, hy, g.y + 0.5)

func _update_uniforms() -> void:
	if not SR.on: return
	var prm := {}
	for k in ["p91_mode", "p91_r", "p91_cut_r", "p91_ceil"]: prm[k] = hodnota(k)
	SR.set_pruhl(bool(hodnota("p91_pruhlednost")), prm, _feet(), cam.global_transform.basis.z)
	SR.set_rez(island, int(hodnota("zk_rez")), float(hodnota("zk_rez_pos")), cam.global_position)

func _process(dt: float) -> void:
	if _deb > 0.0:
		_deb -= dt
		if _deb <= 0.0:
			if _deb_klic == "lod": lod_prestavba()
			else: prestavba(_deb_klic)
	if SR.on:
		_acc += dt
		if _acc > 1.0:
			_acc = 0.0
			SR.enable(main, island)   # nové uzly (vložený blok, vzhled T) + data řezu po kopání
		_update_uniforms()
