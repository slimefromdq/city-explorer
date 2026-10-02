extends SceneTree
## GPU-enabled profile of the actual viewer. Warm each view, then sample 180
## frames. PROFILE_OUT selects the JSON path; no headless FPS claims.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Profile requires a rendering window")
		quit(1)
		return
	var began := Time.get_ticks_msec()
	var scene = load("res://city/city_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var generation_ms := Time.get_ticks_msec() - began
	var cam: Camera3D = scene.get_node("FlyCamera")
	cam.set_process(false)
	scene.get_node("Help").hide()
	root.size = Vector2i(1600, 900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var report := {
		"date": "2026-10-01", "renderer": "Forward+", "warmup_frames": 60,
		"engine": Engine.get_version_info()["string"],
		"gpu": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(), "resolution": [1600, 900],
		"msaa": root.msaa_3d, "vsync": "disabled", "sample_frames": 180,
		"shadow_map": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"),
		"generation_ms": generation_ms, "views": []
	}
	var shots := [
		["overview", Vector3(800, 950, 1900), Vector3(800, 0, 570)],
		["skyline", Vector3(920, 150, 800), Vector3(920, 100, 325)],
		["station", Vector3(965, 70, 950), Vector3(762, 12, 850)],
		["park", Vector3(250, 160, 510), Vector3(500, 10, 270)],
		["street", Vector3(920, 5.5, 850), Vector3(780, 9, 850)]
	]
	for shot in shots:
		cam.position = shot[1]
		cam.look_at(shot[2])
		for i in 60:
			await process_frame
		var frame_times: Array[float] = []
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		var draw_calls := 0.0
		var previous := Time.get_ticks_usec()
		for i in 180:
			await process_frame
			var now := Time.get_ticks_usec()
			frame_times.append(float(now - previous) / 1000)
			previous = now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		frame_times.sort()
		cpu.sort()
		gpu.sort()
		var view := {"name": shot[0], "frame_ms_median": frame_times[90], "frame_ms_p95": frame_times[170], "render_cpu_ms_median": cpu[90], "render_gpu_ms_median": gpu[90], "draw_calls_mean": draw_calls / 180, "video_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576}
		report["views"].append(view)
		print("Profile ", view)
	var out := OS.get_environment("PROFILE_OUT")
	if out.is_empty():
		out = "res://tests/out/meridia-profile.json"
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write profile: %s" % out)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("Profile saved: ", out)
	quit()
