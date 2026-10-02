extends SceneTree
var stages: Array[float] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var launch = load("res://walk/Meridia.tscn").instantiate()
	root.add_child(launch)
	current_scene = launch
	await process_frame
	if launch.exploring or not launch.start_button.has_focus():
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/meridia-launch-menu.png"))
	launch.start_exploring()
	await process_frame
	await process_frame
	var walk: StationWalk
	for child in launch.get_children():
		if child is StationWalk:
			walk = child
	if walk == null:
		await process_frame
		for child in launch.get_children():
			if child is StationWalk:
				walk = child
	if walk == null:
		push_error("Launch did not start a walking scene")
		quit(1)
		return
	walk.loading_progress.connect(func(value: float, _text: String): stages.append(value))
	if not walk.ready_to_explore:
		await walk.exploration_ready
	var okay: bool = walk.city.generated and walk.walker != null and walk.city.get_node_or_null("LibraryWalk") != null and not launch.menu.visible and stages.size() >= 4 and stages[-1] == 1.0
	for i in range(1, stages.size()):
		okay = okay and stages[i] > stages[i - 1]
	print("meridia_launch_test: ", "OK" if okay else "FAILED", " stages=", stages)
	if DisplayServer.get_name() != "headless":
		walk.route_guide.panel.show()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/meridia-launch-ready.png"))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.keycode = KEY_F1
	event.pressed = true
	root.push_input(event)
	await process_frame
	await process_frame
	var returned: bool = current_scene != null and not current_scene.exploring and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	print("[PASS] returned to launch screen" if returned else "[FAIL] return to launch screen")
	quit(0 if okay and returned else 1)
