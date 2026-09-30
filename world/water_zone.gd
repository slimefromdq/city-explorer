class_name WaterZone
extends Node3D
## Rectangular shallow water: fighters standing in it wade at reduced speed
## and kick up spray. (The park uses the heightfield instead; this is for the
## harbour shallows.)

var rect := Rect2()
var surface_y := -1.5
var slow_scale := 0.55
var _t := 0.0


func _physics_process(dt: float) -> void:
	_t -= dt
	for n in get_tree().get_nodes_in_group(&"fighters"):
		var f := n as Fighter
		if f == null or not f.alive:
			continue
		var p := f.global_position
		if rect.has_point(Vector2(p.x, p.z)) and p.y < surface_y - 0.25 and f.is_on_floor():
			f.slow(slow_scale, 0.12)
			if _t <= 0.0 and Vector2(f.velocity.x, f.velocity.z).length() > 2.0:
				VFX.spark(get_tree(), Vector3(p.x, surface_y, p.z), Vector3.UP, Color(0.75, 0.9, 1.0), 6, 3.0)
	if _t <= 0.0:
		_t = 0.25
