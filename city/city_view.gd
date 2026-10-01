# CityView - the root of the 3D preview scene.
#
# One job: after the generator has built the city, point the camera at it.
# (Children run _ready before their parent, so the generator is already done here.)
extends Node3D

@onready var generator := $CityGenerator
@onready var camera := $FlyCamera


func _ready() -> void:
	if generator.city.is_empty():
		return
	var size: Vector2 = generator.map_size
	camera.frame(Vector3(size.x * 0.5, 0.0, size.y * 0.5), maxf(size.x, size.y))
