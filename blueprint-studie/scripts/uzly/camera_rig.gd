extends Node3D
## Uzel CameraRig: ortografická kamera, frame(střed, velikost, směr pohledu).

@onready var cam: Camera3D = $Camera3D

func frame(center: Vector3, size: float, dir := Vector3(0.9, 1.0, 1.3)) -> void:
	cam.size = size
	cam.position = center + dir.normalized() * 150.0
	cam.look_at(center, Vector3.UP)
