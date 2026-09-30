extends Node
## Renders viewpoints to tests/out/*.png. Run under xvfb:
##   xvfb-run -a godot --rendering-driver vulkan --fixed-fps 30 --resolution 1280x720 res://tests/screenshot.tscn

const SHOTS := [
	# name, teleport name (from city markers) or Vector3, yaw(deg), pitch(deg), optional action
	["start_plaza", "Start", 180.0, 6.0],
	["tower_up", Vector3(0, 0.1, -140), 0.0, 38.0],
	["belfry_view", "Clock belfry", 180.0, -16.0],
	["lookout_hill", "Lookout Hill", 200.0, -6.0],
	["lake_bridge", "Lake Bridge", 90.0, -6.0],
	["old_oak", "Old Oak crown", 30.0, -14.0],
	["library_hall", "Library hall", 180.0, 4.0],
	["library_dome", "Library dome", 180.0, -12.0],
	["metro_platform", "Metro platform", 0.0, 10.0],
	["metro_mezzanine", "Metro mezzanine", 90.0, -8.0],
	["chinatown", "Chinatown gate", 180.0, 4.0],
	["pagoda", "Pagoda top", 90.0, -14.0],
	["gas_station", "Highway deck", -90.0, 4.0],
	["rail", "Rail viaduct", 90.0, -3.0],
	["dash_streak", "Start", 180.0, 6.0, "dash"],
	["map", "Start", 180.0, 6.0, "map"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/out")
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("headless_test", true)
	add_child(main)
	await get_tree().process_frame
	main.controller.enabled = false
	var only := OS.get_environment("SHOTS").split(",", false)
	for s in SHOTS:
		if not only.is_empty() and not only.has(s[0]):
			continue
		var pos: Vector3
		if s[1] is String:
			for t in main.city.markers["tp"]:
				if t[0] == s[1]:
					pos = t[1]
		else:
			pos = s[1]
		main.teleport_player(pos, deg_to_rad(s[2]))
		main.rig.pitch = deg_to_rad(s[3])
		var p: Fighter = main.player
		if s.size() > 4 and s[4] == "map":
			main.hud.toggle_map()
			for i in 6:
				await get_tree().process_frame
		elif s.size() > 4:
			for i in 30:
				await get_tree().physics_frame
			p.bounty.add_streak(7)
			p.aim_yaw = deg_to_rad(s[2])
			p.aim_dir = Vector3(-sin(p.aim_yaw), 0.35, -cos(p.aim_yaw)).normalized()
			p.aim_point = p.global_position + p.aim_dir * 30.0
			p.loco.request_dash()
			p.hold_ability(0, true)
			p.press_ability(0)
			for i in 3:
				await get_tree().process_frame
		else:
			for i in 8:
				await get_tree().physics_frame
			for i in 8:
				await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://tests/out/%s.png" % s[0])
		print("saved ", s[0])
		if s.size() > 4 and s[4] == "map":
			main.hud.toggle_map()
	get_tree().quit()
