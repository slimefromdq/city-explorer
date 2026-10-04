class_name HeroModel
extends Node3D
## Placeholder body built from primitive meshes: a torso, a head and a visor
## that shows which way the hero faces. M3's outfit slots (head, top, bottom,
## tint) will replace these parts; nothing outside this script cares what the
## model looks like.

@export var body_color := Color(0.22, 0.32, 0.55)
@export var accent_color := Color(1.0, 0.62, 0.25)

var _parts := Node3D.new()
var _crouched := false


func _ready() -> void:
	add_child(_parts)
	var body_mat := _mat(body_color)
	var accent_mat := _mat(accent_color)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.25
	torso.mesh = cap
	torso.material_override = body_mat
	torso.position.y = 0.72
	_parts.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	head.mesh = sphere
	head.material_override = body_mat
	head.position.y = 1.55
	_parts.add_child(head)
	# The visor is on the -Z side: Godot's "forward".
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.1, 0.12)
	visor.mesh = box
	visor.material_override = accent_mat
	visor.position = Vector3(0.0, 1.58, -0.17)
	_parts.add_child(visor)
	var belt := MeshInstance3D.new()
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.3
	belt_mesh.bottom_radius = 0.3
	belt_mesh.height = 0.08
	belt.mesh = belt_mesh
	belt.material_override = accent_mat
	belt.position.y = 0.85
	_parts.add_child(belt)


## Squash the body while crouched so the short capsule is visible.
func set_crouched(on: bool) -> void:
	if on == _crouched:
		return
	_crouched = on
	_parts.scale = Vector3(1.0, 0.62, 1.0) if on else Vector3.ONE


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m
