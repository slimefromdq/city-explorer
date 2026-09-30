class_name DamageNumbers
extends Node
## Floating combat text driven purely by Events, so it works for any fighter.

func _ready() -> void:
	Events.hit_resolved.connect(_on_hit)
	Events.popup.connect(_spawn)


func _on_hit(_attacker: Node3D, victim: Node3D, result: int, amount: float, pos: Vector3) -> void:
	var p := pos + Vector3.UP * 0.6
	match result:
		HitData.Result.HIT:
			_spawn(str(int(round(amount))), p, Color(1.0, 0.92, 0.5))
		HitData.Result.BLOCKED:
			_spawn("BLOCK", p, Color(0.5, 0.9, 1.0))
		HitData.Result.GUARD_BREAK:
			_spawn("GUARD BREAK!", p + Vector3.UP * 0.4, Color(1.0, 0.35, 0.3))
		HitData.Result.DODGED:
			_spawn("DODGE", (victim as Node3D).global_position + Vector3.UP * 2.1, Color(1.0, 0.9, 0.4))


func _spawn(text: String, pos: Vector3, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 40
	l.outline_size = 12
	l.modulate = color
	l.no_depth_test = true
	l.render_priority = 5
	scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
