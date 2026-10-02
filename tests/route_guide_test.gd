extends SceneTree
## Real scene/UI integration: keyboard handling, resize, position and orientation.
## With rendering enabled, also saves large-window and small-window screenshots.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func _expect(ok: bool, label: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", label)
	if not ok:
		failures += 1

func _key(echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	event.keycode = KEY_M
	event.pressed = true
	event.echo = echo
	root.push_input(event)

func run() -> void:
	root.size = Vector2i(1600, 900)
	var scene := StationWalk.new()
	root.add_child(scene)
	await process_frame
	var guide = scene.route_guide
	var map = guide.panel
	var original_mouse := Input.mouse_mode
	_expect(not map.visible, "map starts closed")
	_key()
	await process_frame
	_expect(map.visible, "M opens walking map through viewport input")
	_expect(Input.mouse_mode == original_mouse and not RideUI.blocking, "map preserves mouse capture and train chooser state")
	_key(true)
	await process_frame
	_expect(map.visible, "held-key repeat does not close map")
	_expect(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "map allows mouse input to reach movement/train controls")
	_expect(map.stops.size() == 6, "map includes station, bridge, tower, park, museum and library")
	_expect(map.marker_on_map and map.MAP.has_point(map.marker_position), "spawn is visible on walking map")
	if DisplayServer.get_name() != "headless":
		await _capture("route-guide-large")
	# Put the walker at the actual library arrival and rotate its parent, as a
	# train does. The marker must follow global location and camera orientation.
	scene.walker.set_physics_process(false)
	var arrival: Node3D = scene.city.get_node("CivicAccess/LibraryArrival")
	var destination: Vector3 = arrival.transform * arrival.get_meta("arrival_end")
	var carriage := Node3D.new()
	scene.add_child(carriage)
	carriage.rotation.y = PI * 0.5
	scene.walker.reparent(carriage)
	scene.walker.global_position = destination
	scene.walker.global_rotation = Vector3.ZERO
	scene.walker.camera.rotation = Vector3.ZERO
	await process_frame
	await process_frame
	_expect(map.marker_position.distance_to(map.map_point(Vector2(destination.x, destination.z))) < 0.01, "marker follows reparented walker to library")
	_expect(map.marker_direction.distance_to(Vector2.UP) < 0.01, "marker uses world camera direction after reparenting")
	root.size = Vector2i(960, 640)
	await process_frame
	await process_frame
	_expect(map.size == root.get_visible_rect().size, "map follows resized viewport with project canvas scaling")
	if DisplayServer.get_name() != "headless":
		await _capture("route-guide-small")
	scene.walker.global_position = Vector3(-100, 3, -100)
	await process_frame
	await process_frame
	_expect(not map.marker_on_map, "off-map travel is reported instead of clamping marker to a false location")
	_key()
	await process_frame
	_expect(not map.visible and Input.mouse_mode == original_mouse, "M closes map without changing mouse capture")
	print("route_guide_test: ", "OK" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)

func _capture(name: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://tests/out/" + name + ".png")
	_expect(root.get_texture().get_image().save_png(path) == OK, "captured " + name)
