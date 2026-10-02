class_name StationWalk
extends Node3D
## The walkable station scene: the whole city (generated at run time) with Central Station and the four
## shuttle lines, one sun, and a first-person walker who starts at the end of the main street, facing the
## station's forecourt. Run walk/StationWalk.tscn. WASD + mouse, Space jumps, Shift runs, Esc frees the mouse.

const CITY_GEN := preload("res://city/city_generator.gd")
const SPAWN := Vector3(962.0, 3.2, 850.0)

var city: Node3D
var walker: Walker
var ui: RideUI
var route_guide: CanvasLayer
var with_ui := true
var sun: DirectionalLight3D


func _ready() -> void:
	_environment()
	city = CITY_GEN.new()
	add_child(city)
	walker = Walker.new()
	walker.position = SPAWN
	walker.yaw = PI * 0.5
	add_child(walker)
	if with_ui:
		ui = RideUI.new()
		add_child(ui)
		ui.bind(city.transit, walker)
		route_guide = preload("res://walk/route_guide.gd").new()
		add_child(route_guide)
		route_guide.bind(city, walker)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var hint := Label.new()
		hint.text = "WASD move   Shift run   Space jump   Esc release mouse   M walking map\nFollow the teal Meridia Walk to the tower & lake; take the gold map branches to civic terraces."
		hint.position = Vector2(12, 10)
		var layer := CanvasLayer.new()
		layer.add_child(hint)
		add_child(layer)


## One sun for the whole scene: the hall has no light of its own, so its windows and skylight let in
## this directional light and the beams on the floor are this sun's shadows.
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_horizon_color = Color(0.62, 0.72, 0.82)
	mat.ground_horizon_color = Color(0.62, 0.72, 0.82)
	mat.ground_bottom_color = Color(0.1, 0.25, 0.42)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis(Vector3(0.866, 0, -0.5), Vector3(-0.354, 0.707, -0.612), Vector3(0.354, 0.707, 0.612)), Vector3(0, 500, 0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun)
