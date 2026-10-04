class_name MovementTuning
extends Resource
## Every movement number in one place. The hero reads an instance of this
## (default_tuning.tres). Open that file in the Inspector to tweak the feel; no
## code changes needed. Make a copy of the .tres to try a variant side by side.
##
## Starting values are ported from the old Gunslinger prototype, which was
## already tuned for feel. Units are metres and seconds.

@export_group("Body")
## Capsule radius. Meridia's doorways and stairs were built for a slim
## person-sized capsule, so keep this around 0.3.
@export_range(0.2, 0.6, 0.01) var capsule_radius := 0.3
@export_range(1.2, 2.4, 0.05) var stand_height := 1.8
@export_range(0.8, 1.6, 0.05) var crouch_height := 1.1
## Steepest slope you can stand on, in degrees. Steeper ramps make you slide.
@export_range(20.0, 70.0, 1.0) var max_floor_angle := 46.0

@export_group("Ground")
@export var walk_speed := 9.0
@export var sprint_speed := 15.0
@export var crouch_speed := 4.5
## How fast you reach your target speed when pushing a direction.
@export var ground_accel := 70.0
## How fast you stop when you let go.
@export var ground_brake := 55.0
## Steps lower than this are walked over without jumping (curbs, single stairs).
@export_range(0.0, 0.6, 0.01) var step_height := 0.35

@export_group("Air")
## Steering strength in the air (lower = more committed jumps).
@export var air_accel := 26.0
@export var gravity := 28.0
## Gravity is multiplied by this while falling, so jumps feel snappy, not floaty.
@export var fall_gravity_mult := 1.35
@export var max_fall_speed := 55.0

@export_group("Jump")
## Upward speed at take-off. Peak height = jump_speed^2 / (2 * gravity), about 2 m.
@export var jump_speed := 10.5
## Grace period after walking off a ledge during which jump still works.
@export var coyote_time := 0.12
## A jump pressed this long before landing still fires on landing.
@export var jump_buffer := 0.12
## Letting go of jump early multiplies the remaining upward speed by this
## (short tap = short hop).
@export_range(0.0, 1.0, 0.05) var jump_cut := 0.5

@export_group("Mantle")
## Ledge heights (above your feet) that you can grab and pull up onto.
@export var mantle_min_height := 0.35
@export var mantle_max_height := 2.5
## How far in front of you the ledge check looks.
@export var mantle_reach := 0.75
## Base duration of the pull-up; taller ledges add a little.
@export var mantle_time := 0.28

@export_group("Wall kick")
## Jump while touching a wall in the air to kick off it, this many times per airtime.
@export var wall_kicks_per_air := 3
@export var wall_kick_up_speed := 11.5
@export var wall_kick_out_speed := 10.0
## After touching a wall you still count as "on the wall" for this long.
@export var wall_contact_grace := 0.18

@export_group("Facing")
## How quickly the body turns to face its travel direction.
@export var turn_speed := 18.0
