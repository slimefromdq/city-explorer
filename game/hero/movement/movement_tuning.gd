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
@export var walk_speed := 8.5
@export var sprint_speed := 14.0
@export var crouch_speed := 4.5
## How fast you reach your target speed when pushing a direction.
## Lower = a heavier body that takes a moment to get going.
@export var ground_accel := 45.0
## How fast you stop when you let go.
@export var ground_brake := 32.0
## When you're moving FASTER than your run speed on the ground (e.g. landing out
## of a leap), you only shed the extra speed at this rate, so you skid.
@export var ground_overspeed_brake := 14.0
## Steps lower than this are walked over without jumping (curbs, single stairs).
@export_range(0.0, 0.6, 0.01) var step_height := 0.35

@export_group("Air")
## Steering strength in the air (lower = more committed jumps). Air steering
## can bend your path but never adds speed beyond what you already have (or
## your run speed), and never brakes momentum you didn't push against.
@export var air_accel := 9.0
## Gentle air resistance on horizontal momentum (m/s lost per second).
@export var air_drag := 1.0
@export var gravity := 22.0
## Gravity is multiplied by this while falling (above 1 = a little weightier on the way down).
@export var fall_gravity_mult := 1.25
@export var max_fall_speed := 50.0

@export_group("Jump")
## Upward speed at take-off. Peak height = jump_speed^2 / (2 * gravity), about 2.2 m.
@export var jump_speed := 9.8
## Grace period after walking off a ledge during which jump still works.
@export var coyote_time := 0.12
## A jump pressed this long before landing still fires on landing.
@export var jump_buffer := 0.12
## Letting go of jump early multiplies the remaining upward speed by this
## (short tap = short hop).
@export_range(0.0, 1.0, 0.05) var jump_cut := 0.6

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
@export var wall_kick_up_speed := 10.5
@export var wall_kick_out_speed := 4.5
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
@export var dash_distance := 7.5
## Share of the leap's HORIZONTAL speed you keep as momentum when it ends.
## With low air control this is what sends you flying.
@export_range(0.0, 1.0, 0.05) var dash_end_carry := 0.7
## Share of the leap's UPWARD speed you keep (a leap aimed up keeps rising a bit).
@export_range(0.0, 1.0, 0.05) var dash_end_vertical_carry := 0.6
## Brief low-gravity float right after the leap ends.
@export var dash_end_hang := 0.18
## Aim pitch limits (as the sine of the angle): looking straight down or up is clamped.
@export_range(-1.0, 0.0, 0.05) var dash_min_pitch := -0.6
@export_range(0.0, 1.0, 0.05) var dash_max_pitch := 0.95
## On the ground, the leap always lifts at least this much (so it never digs into the floor).
@export_range(0.0, 0.5, 0.01) var dash_ground_min_pitch := 0.12
## A press this long before the leap is allowed (e.g. mid-mantle) still fires.
@export var dash_buffer := 0.15
## How far behind your body centre the sigil appears.
@export var sigil_offset := 0.9

@export_group("Slide")
## Crouching while at least this fast on the ground slides instead (walk is 8.5,
## so you need to sprint or land with momentum).
@export var slide_min_speed := 10.0
## Speed lost per second while sliding on flat ground (crouch-walking brakes ~32).
@export var slide_friction := 4.0
## How strongly slopes speed you up (downhill) or slow you (uphill). 1 = full gravity.
@export_range(0.0, 1.5, 0.05) var slide_slope_mult := 0.8
@export var slide_max_speed := 28.0
## Below this speed the slide ends (into a crouch if still held).
@export var slide_end_speed := 5.0
## How fast you can bend a slide toward the stick, radians per second.
@export var slide_turn_rate := 1.2

@export_group("Dodge roll")
## A grounded, cheap, non-committal evade: short, fast, low to the ground,
## with a window of invulnerability. Two charges keep it from being spammed
## (which would make blocking pointless); a short cooldown spaces the two out.
@export var roll_charges := 2
## Seconds to refill one roll charge (refills one at a time).
@export var roll_recharge_time := 2.5
@export var roll_speed := 15.0
@export var roll_time := 0.36
## Invulnerable from roll_iframe_start to roll_iframe_end seconds into the roll.
@export var roll_iframe_start := 0.03
@export var roll_iframe_end := 0.26
@export var roll_cooldown := 0.4
## Share of roll speed kept as momentum when the roll ends.
@export_range(0.0, 1.0, 0.05) var roll_end_carry := 0.35
## A roll pressed this long before landing fires on landing.
@export var roll_buffer := 0.15

@export_group("Block")
## Movement speed multiplier while holding block.
@export_range(0.0, 1.0, 0.05) var block_move_scale := 0.45
## The first part of a block: a hit from the front in this window is a
## PERFECT block (no damage, no guard loss, attacker staggered, OnPerfectBlock).
@export var perfect_block_window := 0.15
## After letting go of block, a new perfect window needs this much time first,
## so mashing block isn't a strategy.
@export var perfect_block_rearm := 0.4
## Damage taken from a normal block (0.2 = 80% reduction).
@export_range(0.0, 1.0, 0.05) var block_damage_mult := 0.2
## Knockback taken while blocking, as a share of the full knockback.
@export_range(0.0, 1.0, 0.05) var block_knockback_mult := 0.3
## Total width of the protected front arc, in degrees.
@export_range(30.0, 360.0, 5.0) var block_arc_degrees := 120.0
@export var guard_max := 100.0
@export var guard_regen := 25.0
@export var guard_regen_delay := 1.0
## Emptying the guard meter breaks your guard: stunned for this long.
@export var guard_break_stun := 1.2

@export_group("Health and hits")
@export var max_health := 100.0
## Getting hit to zero health respawns you this many seconds later.
@export var death_respawn_delay := 0.6

@export_group("Facing")
## How quickly the body turns to face its travel direction.
@export var turn_speed := 12.0
