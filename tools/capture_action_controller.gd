extends SceneTree
## Optional rendered QA: godot --rendering-method gl_compatibility --fixed-fps 60
## --script res://tools/capture_action_controller.gd
## Captures the course and the air-dash anticipation pose into tests/out/.


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node3D = load("res://action/traversal_lab.tscn").instantiate()
	root.add_child(scene)
	scene.input.enabled = false
	for i in 20:
		await physics_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/out")
	root.get_texture().get_image().save_png("res://tests/out/action-controller-course.png")
	scene.player.reset_at(Vector3(0, 3.0, 8))
	scene.player.request(ActionPlayerStateMachine.Action.AIR_DASH)
	for i in 8:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/out/action-controller-startup.png")
	scene.player.reset_at(Vector3(0, 0.1, 8))
	for i in 12:
		await physics_frame
	scene.player.request(ActionPlayerStateMachine.Action.ATTACK)
	for i in 10:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/out/action-controller-melee.png")
	print("Action controller captures saved to tests/out")
	quit()
