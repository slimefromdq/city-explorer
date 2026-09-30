extends Node
## Renders viewpoints to tests/out/*.png. Run under xvfb:
##   xvfb-run -a godot --rendering-driver vulkan --resolution 1280x720 res://tests/screenshot.tscn

const SHOTS := [
	# name, player pos, yaw(deg), pitch(deg)
	["street", Vector3(-41, 0.1, 26), -90.0, -6.0],
	["avenue_tower", Vector3(-41, 0.1, 10), -18.0, 10.0],
	["deck", Vector3(-60, 9.6, 0), -90.0, -4.0],
	["underpass", Vector3(-12, 0.1, 0), 90.0, -2.0],
	["alley", Vector3(-82, 0.2, -25), 180.0, -4.0],
	["plaza", Vector3(24, 3.7, 66), 41.0, -5.0],
	["combat", Vector3(-26, 0.1, -1), -90.0, -3.0],
	["gas_roof", Vector3(106, 15.2, 0), 90.0, -8.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/out")
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("headless_test", true)
	add_child(main)
	await get_tree().process_frame
	main.controller.enabled = false
	for s in SHOTS:
		main.teleport_player(s[1], deg_to_rad(s[2]))
		main.rig.pitch = deg_to_rad(s[3])
		for i in 8:
			await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://tests/out/%s.png" % s[0])
		print("saved ", s[0])
	get_tree().quit()
