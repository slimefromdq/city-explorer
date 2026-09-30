class_name Hurtbox
extends Area3D
## The thing projectiles test against. Kept separate from the movement capsule
## so a slide can shrink the target without shrinking the body.

var fighter: Fighter
var _shape: CollisionShape3D
var _capsule := CapsuleShape3D.new()


func _init() -> void:
	collision_layer = Fighter.LAYER_HURTBOX
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	add_child(_shape)
	set_stance(false)


## Crouched targets are lower, so shots aimed at chest height go over them.
func set_stance(crouched: bool) -> void:
	var h := 0.95 if crouched else 1.9
	_capsule.radius = 0.5
	_capsule.height = maxf(h, 1.0)
	_shape.position = Vector3(0, h * 0.5, 0)


func set_active(on: bool) -> void:
	collision_layer = Fighter.LAYER_HURTBOX if on else 0
