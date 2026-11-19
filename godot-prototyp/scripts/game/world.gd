extends Node3D
## Prostředí scény: dítě `Environment` (WorldEnvironment – barva pozadí, ambientní světlo, tónování) a `Sun`
## (DirectionalLight3D se stíny). Obojí jsou skutečné uzly s parametry v Inspectoru (main.tscn).
## Za běhu tu běží čas větru trávy C (Grass.tick), postavičky volají Grass.touch.

const Grass = preload("res://scripts/grass.gd")

@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $Environment

func _process(dt: float) -> void:
	Grass.tick(dt)   # tráva C: čas větru a stopy
