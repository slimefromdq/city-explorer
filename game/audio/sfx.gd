class_name Sfx
extends RefCounted
## Fire-and-forget 3D sounds: plays a stream at a position and cleans up.

static func play_at(anchor: Node3D, stream: AudioStream, volume_db := 0.0) -> void:
	if anchor == null or not anchor.is_inside_tree() or stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 8.0
	var parent: Node = anchor.get_tree().current_scene
	if parent == null:
		parent = anchor.get_parent()
	parent.add_child(p)
	p.global_position = anchor.global_position + Vector3.UP
	p.finished.connect(p.queue_free)
	p.play()


## Same, but at an exact world position (explosions, impacts).
static func play_at_pos(anchor: Node3D, pos: Vector3, stream: AudioStream, volume_db := 0.0) -> void:
	if anchor == null or not anchor.is_inside_tree() or stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 8.0
	var parent: Node = anchor.get_tree().current_scene
	if parent == null:
		parent = anchor.get_parent()
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
