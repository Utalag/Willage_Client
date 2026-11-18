extends CanvasLayer
## Uzel UI: popisek nahoře a panel s ukazatelem průběhu vkládání.

@onready var hud: Label = $Hud
@onready var panel: PanelContainer = $Prubeh
@onready var bar: ProgressBar = $Prubeh/Box/Bar
@onready var step: Label = $Prubeh/Box/Krok

func say(t: String) -> void:
	hud.text = t

func on_progress(f: float, label: String) -> void:
	panel.visible = f < 1.0
	bar.value = f * 100.0
	step.text = "Usazuji blok… " + label
