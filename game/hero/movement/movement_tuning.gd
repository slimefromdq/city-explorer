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

@export_group("Sigil leap (air dash)")
## How many leaps you can store. Charges refill one at a time.
@export_range(1, 6) var dash_charges := 2
## Seconds to recharge ONE charge.
@export var dash_recharge_time := 2.5
## Minimum gap between two leaps, even with charges left.
@export var dash_cooldown := 0.35
## The committed windup while the sigil draws itself in. You can't cancel it.
@export_range(0.05, 0.6, 0.01) var dash_startup := 0.2
## Gravity multiplier during the windup: the "hang in the air" tell.
@export_range(0.0, 1.0, 0.05) var dash_startup_gravity := 0.15
## How quickly your existing momentum bleeds away during the windup (per second).
@export var dash_startup_brake := 12.0
## How quickly vertical speed (rising or falling) bleeds away during the windup.
## Higher = a sharper mid-air stop.
@export var dash_startup_hang_brake := 25.0
@export var dash_speed := 32.0
## How far the leap carries you (its duration is distance / speed).
@export var dash_distance := 9.0
## Share of the leap speed you keep as momentum when it ends.
@export_range(0.0, 1.0, 0.05) var dash_end_carry := 0.45
## Brief low-gravity float right after the leap ends.
@export var dash_end_hang := 0.12
## Aim pitch limits (as the sine of the angle): looking straight down or up is clamped.
@export_range(-1.0, 0.0, 0.05) var dash_min_pitch := -0.6
@export_range(0.0, 1.0, 0.05) var dash_max_pitch := 0.95
## On the ground, the leap always lifts at least this much (so it never digs into the floor).
@export_range(0.0, 0.5, 0.01) var dash_ground_min_pitch := 0.12
## A press this long before the leap is allowed (e.g. mid-mantle) still fires.
@export var dash_buffer := 0.15
## How far behind your body centre the sigil appears.
@export var sigil_offset := 0.9

@export_group("Facing")
## How quickly the body turns to face its travel direction.
@export var turn_speed := 18.0
