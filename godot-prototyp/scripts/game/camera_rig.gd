@tool
extends Node3D
## Kamera: ortografická izometrie kolem středu `center`, otáčení po 90° (Q/E), zoom kolečkem, posun WASD / šipkami
## a tažením prostředním nebo pravým tlačítkem. Dítě `Camera` je skutečný uzel Camera3D (projekce, size, near/far v Inspectoru).
## V editoru (@tool) se jen umístí podle yaw/pitch/center, aby náhled kamery odpovídal hře.

const Grass = preload("res://scripts/grass.gd")

@export var yaw := 45.0:
	set(v): yaw = v; _editor_place()
@export var pitch := -35.0:
	set(v): pitch = v; _editor_place()
@export var center := Vector3(16, 15.0, 16):
	set(v): center = v; _editor_place()
## UI kvůli posunu středu záběru do volné plochy (panel vpravo, lišta dole)
@export var ui_path: NodePath

@onready var cam: Camera3D = $Camera
var ui: CanvasLayer
var dragging := false

func _ready() -> void:
	ui = get_node_or_null(ui_path) as CanvasLayer
	if Engine.is_editor_hint():
		place()

func _editor_place() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		place()

func place() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0), EULER_ORDER_YXZ)
	cam.transform = Transform3D(basis, center + basis.z * 200.0)
	if Engine.is_editor_hint():
		return
	Grass.update_lod(cam.size)   # tráva C: řidší trsy při oddálení
	# střed scény do volné plochy (vpravo panel 290 px, dole lišta 112 px), aby popisky nezajížděly pod panel
	var k := cam.size / 800.0
	var ui_on: bool = ui != null and ui.visible
	cam.h_offset = 145.0 * k if ui_on else 0.0
	cam.v_offset = -56.0 * k if ui_on else 0.0

func pan(d: Vector2) -> void:
	var r := deg_to_rad(yaw)
	var right := Vector3(cos(r), 0, -sin(r))
	var fwd := Vector3(-sin(r), 0, -cos(r))
	center += right * d.x - fwd * d.y
	place()

## paprsek z kamery pod bodem obrazovky: [počátek, směr]
func ray(pos: Vector2) -> Array:
	return [cam.project_ray_origin(pos), cam.project_ray_normal(pos)]

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if v != Vector2.ZERO:
		pan(v * dt * cam.size * 0.8)

func _unhandled_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if e is InputEventMouseMotion:
		if dragging:
			pan(-e.relative * cam.size / 800.0)
	elif e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam.size = maxf(cam.size * 0.9, 18.0); place()
			MOUSE_BUTTON_WHEEL_DOWN: cam.size = minf(cam.size * 1.1, 160.0); place()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT: dragging = true
	elif e is InputEventMouseButton and not e.pressed:
		if e.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: yaw += 90; place()
			KEY_E: yaw -= 90; place()
