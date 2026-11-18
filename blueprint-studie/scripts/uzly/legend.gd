extends PanelContainer
## Uzel Legenda: barevné čtverečky a názvy materiálů, které jsou vidět v řezu (pořadí podle tabulky hornin).

const HR = preload("res://scripts/bp/horniny.gd")
const HT = preload("res://scripts/bp/hostitele.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")
const Mat = preload("res://scripts/kopie/mat.gd")

@onready var grid: GridContainer = $Grid

func clear() -> void:
	for c in grid.get_children():
		c.queue_free()
	visible = false

## ids = MaterialId, které se mají ukázat
func show_ids(ids: Array) -> void:
	clear()
	var order := {}
	for e in HR.raw().rocks:
		if not order.has(int(e.id)): order[int(e.id)] = int(e.idx)
	ids.sort_custom(func(a, b): return order.get(a, 100 + a) < order.get(b, 100 + b))
	for m in ids:
		if m == Mat.AIR:
			continue
		var row := HBoxContainer.new()
		var sw := ColorRect.new(); sw.custom_minimum_size = Vector2(18, 18)
		sw.color = Mesher.PALETTE[m] if Mesher.PALETTE.size() > m and Mesher.PALETTE[m].a > 0 else Mat.COLORS[m]
		var lb := Label.new()
		var idx = order.get(m, null)
		lb.text = ("%d " % idx if idx != null and idx < 64 else "") + HT.name_of(m)
		lb.add_theme_font_size_override("font_size", 13)
		lb.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		row.add_child(sw); row.add_child(lb)
		grid.add_child(row)
	visible = true
