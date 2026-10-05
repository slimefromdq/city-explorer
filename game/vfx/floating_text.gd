class_name FloatingText
extends Label3D
## A short text popup that rises and fades ("-12", "BLOCKED", "PERFECT!").
## This is how the game explains WHY something happened to you.

var _t := 0.0
var _life := 0.9
var _rise := 1.4


static func spawn(anchor: Node3D, text_value: String, pos: Vector3, color: Color, size := 56) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var f := FloatingText.new()
	f.text = text_value
	f.modulate = color
	f.font_size = size
	f.outline_size = size / 6
	f.pixel_size = 0.006
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	f.fixed_size = false
	var parent: Node = anchor.get_tree().current_scene if anchor.get_tree().current_scene != null else anchor.get_parent()
	parent.add_child(f)
	f.global_position = pos


func _process(dt: float) -> void:
	_t += dt
	position.y += _rise * dt * (1.0 - _t / _life)
	modulate.a = clampf(1.5 - 1.5 * _t / _life, 0.0, 1.0)
	if _t >= _life:
		queue_free()
