class_name StationComplex
extends Node3D
## Central Station: the concourse hall plus its shell, forecourt, platform level and transit.
## The node's origin is the hall centre on the hall floor (StationLayout.HUB in the world).
## Everything is built at runtime in _ready (nothing is saved into a scene).

const HALL := preload("res://concourse/ConcourseHall.tscn")

var hall: ConcourseHall


func _ready() -> void:
	name = "CentralStation"
	build()


func build() -> void:
	hall = _make_hall()
	add_child(hall)
	TerminalShell.build(self)
	Forecourt.build(self)


func _make_hall() -> ConcourseHall:
	var h: ConcourseHall = HALL.instantiate()
	h.hall_bays = 8
	h.dress_exterior = true
	h.build_collision = true
	h.entrance_arched = false
	h.entrance_height = StationLayout.TICKET_CEILING
	h.entrance_width = StationLayout.TICKET_HALF_W * 2.0
	h.vault_outer_color = Color(0.40, 0.45, 0.50)
	h.skylight_width = 3.0
	h.kiosk_bays = PackedInt32Array([3])
	# (sign, world x): wing doors; -1 = north wall (-Z)
	h.side_doors = PackedVector2Array([Vector2(-1, -20), Vector2(-1, 20), Vector2(1, 12)])
	h.lighting_enabled = false  # the city's sun lights the hall through its windows
	return h
