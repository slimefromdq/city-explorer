class_name Sigil
extends Node3D
## The dash sigil: a VISUAL EFFECT ONLY. No collision, no gameplay.
##
## Lifecycle: play() draws it in over the dash startup, launch() holds it for a
## moment and then fades it out, and it frees itself when done. Restyle it by
## editing this scene (size, colour, light, sounds) or sigil.gdshader.

@export var radius := 1.1
@export var color := Color(0.45, 0.85, 1.0)
## How long it stays fully visible after the hero launches off it.
@export var hold_time := 0.08
@export var fade_time := 0.25
@export var spin_speed := 0.35
@export var flash_energy := 3.0

## True when the sigil was flattened against a wall/ceiling/floor behind the hero.
var clipped := false

enum Phase { IDLE, DRAWING, HOLDING, FADING }
var _phase := Phase.IDLE
var _t := 0.0
var _draw_time := 0.2
var _mat: ShaderMaterial

@onready var _disc: MeshInstance3D = $Disc
@onready var _light: OmniLight3D = $Flash
@onready var _draw_sound: AudioStreamPlayer3D = $DrawSound
@onready var _launch_sound: AudioStreamPlayer3D = $LaunchSound


func _ready() -> void:
	add_to_group(&"sigils")
	_mat = (_disc.material_override as ShaderMaterial).duplicate()
	_disc.material_override = _mat
	var quad := (_disc.mesh as QuadMesh).duplicate() as QuadMesh
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	_disc.mesh = quad
	_mat.set_shader_parameter(&"color", color)
	_light.light_color = color
	_draw_sound.stream = PlaceholderSfx.sweep("sigil_draw", 380.0, 900.0, 0.22, 0.35)
	_launch_sound.stream = PlaceholderSfx.sweep("sigil_launch", 900.0, 160.0, 0.3, 0.45, 0.55)
	_apply(0.0, 1.0)


## Point the sigil's face along `normal` (the quad's front is its local +Z).
func face(normal: Vector3) -> void:
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	global_basis = Basis.looking_at(-n, up)


func play(draw_time: float, p_clipped: bool) -> void:
	clipped = p_clipped
	_draw_time = maxf(0.01, draw_time)
	_phase = Phase.DRAWING
	_t = 0.0
	_draw_sound.play()


func launch() -> void:
	_phase = Phase.HOLDING
	_t = 0.0
	_apply(1.0, 1.0)
	_light.light_energy = flash_energy * 2.0
	_launch_sound.play()


func _process(dt: float) -> void:
	_t += dt
	_mat.set_shader_parameter(&"spin", Time.get_ticks_msec() / 1000.0 * spin_speed)
	match _phase:
		Phase.DRAWING:
			# If the leap never comes (shouldn't happen), stay drawn until launch().
			_apply(minf(1.0, _t / _draw_time), 1.0)
		Phase.HOLDING:
			if _t >= hold_time:
				_phase = Phase.FADING
				_t = 0.0
		Phase.FADING:
			var f := 1.0 - _t / fade_time
			_apply(1.0, maxf(0.0, f))
			if f <= 0.0:
				queue_free()


func _apply(progress: float, fade: float) -> void:
	_mat.set_shader_parameter(&"draw_progress", progress)
	_mat.set_shader_parameter(&"fade", fade)
	if _phase != Phase.HOLDING:
		_light.light_energy = flash_energy * progress * fade
