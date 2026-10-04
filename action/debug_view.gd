class_name ActionControllerDebugView
extends Node3D
## F3 toggles telemetry and probe geometry together. No probes drawn when off.
var player: ActionPlayerController
var label := Label.new()
var canvas := CanvasLayer.new()
var lines := ImmediateMesh.new()
var geometry := MeshInstance3D.new()


func _ready() -> void:
	add_child(canvas)
	canvas.add_child(label)
	label.position = Vector2(20, 96)
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	geometry.mesh = lines
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	geometry.material_override = mat
	add_child(geometry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"controller_debug"):
		player.debug_enabled = not player.debug_enabled


func segment(from: Vector3, to: Vector3, color: Color) -> void:
	lines.surface_set_color(color)
	lines.surface_add_vertex(from)
	lines.surface_add_vertex(to)


func _process(_dt: float) -> void:
	canvas.visible = player.debug_enabled
	geometry.visible = player.debug_enabled
	lines.clear_surfaces()
	if not player.debug_enabled:
		return
	label.text = "%s  |  %.1f m/s  |  velocity %s\nGrounded %s  |  surface %s\nAir %.2fs  |  since jump %.2fs\nDodge %d / 3  |  recharge %s\nAir dash %s  |  used %s  |  cooldown %.2f\nRunnable wall %s  |  mantle %s\nBlock %s  |  melee hit %d  %s" % [
		player.states.state_name(), player.horizontal_speed, player.velocity.snapped(Vector3.ONE * 0.1),
		player.grounded, player.surface_normal.snapped(Vector3.ONE * 0.01), player.time_since_leaving_ground,
		player.time_since_last_jump, player.dodge_charges.available(), player.dodge_charges.remaining,
		player.air_dash_available, player.movement.dash_used, player.movement.dash_cooldown_left,
		player.against_runnable_wall, player.mantle_target_available, player.is_blocking, player.combat.hit + 1, player.combat.phase]
	if not player.mantle_target_available:
		label.text += "\nMantle probe: " + player.parkour.mantle_rejection
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for probe in player.parkour.probes:
		segment(probe.from, probe.to, Color.YELLOW)
	var feet := player.global_position
	segment(feet + Vector3.UP * 0.2, feet + Vector3.DOWN * player.floor_snap_length, Color.GREEN)
	segment(feet, feet + player.surface_normal * 1.4, Color.CYAN)
	if not player.parkour.wall.is_empty():
		segment(player.parkour.wall.position, player.parkour.wall.position + player.parkour.wall.normal, Color.RED)
	if not player.parkour.mantle.is_empty():
		var target: Vector3 = player.parkour.mantle.target
		segment(target - Vector3.RIGHT * 0.25, target + Vector3.RIGHT * 0.25, Color.MAGENTA)
		segment(target - Vector3.FORWARD * 0.25, target + Vector3.FORWARD * 0.25, Color.MAGENTA)
	lines.surface_end()
