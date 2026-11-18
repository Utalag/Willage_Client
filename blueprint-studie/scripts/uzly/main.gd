extends Node3D
## Kořen scény: jen spustí Scenario (logika je v uzlech Svet, Placer, BlockViews, Preview, UI, CameraRig, Scenario).

func _ready() -> void:
	await get_tree().process_frame
	$Scenario.run()
